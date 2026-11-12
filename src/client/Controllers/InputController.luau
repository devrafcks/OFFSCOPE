--[[
	InputController — teclado/mouse, controle e toque num só lugar.
	Os outros controllers escutam AÇÕES ("Fire", "Aim"…), nunca teclas.

	PC:      LMB atirar · RMB scope · R recarregar · 2/Q faca ↔ sniper · V faca rápida
	         Shift correr · C/Ctrl slide · F inspecionar · Tab placar · B loja · M menu
	Controle: RT atirar · LT scope · X recarregar · Y trocar · RB faca rápida · L3 correr · B slide
	Toque:   botões na tela (sem aim-assist).
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ClientState = require(script.Parent.Parent.ClientState)

local InputController = {}

-- Pressed(action), Released(action)
InputController.Pressed = Signal.new()
InputController.Released = Signal.new()

local held: { [string]: boolean } = {}

local BINDINGS = {
	Fire = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	Aim = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
	Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonX },
	Swap = { Enum.KeyCode.Two, Enum.KeyCode.Q, Enum.KeyCode.ButtonY },
	Primary = { Enum.KeyCode.One },
	QuickMelee = { Enum.KeyCode.V, Enum.KeyCode.ButtonR1 },
	Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
	Slide = { Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB },
	Inspect = { Enum.KeyCode.F },
	Scoreboard = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect },
	Shop = { Enum.KeyCode.B },
	Menu = { Enum.KeyCode.M, Enum.KeyCode.ButtonStart },
	Play = { Enum.KeyCode.P },
}

-- Ações que não disparam com UI aberta (para não atirar clicando na loja)
local COMBAT = { Fire = true, Aim = true, Reload = true, Swap = true, QuickMelee = true, Slide = true, Inspect = true, Primary = true }

local TOUCH_LAYOUT = {
	Fire = { Title = "ATIRAR", Position = UDim2.new(1, -130, 1, -190) },
	Aim = { Title = "SCOPE", Position = UDim2.new(1, -215, 1, -125) },
	Reload = { Title = "R", Position = UDim2.new(1, -80, 1, -280) },
	Swap = { Title = "FACA", Position = UDim2.new(1, -170, 1, -290) },
	Slide = { Title = "SLIDE", Position = UDim2.new(1, -260, 1, -210) },
	Sprint = { Title = "CORRER", Position = UDim2.new(1, -300, 1, -110) },
}

function InputController.IsHeld(action: string): boolean
	return held[action] == true
end

local function handle(action: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		if COMBAT[action] and ClientState.UiOpen then
			return Enum.ContextActionResult.Pass
		end
		held[action] = true
		InputController.Pressed:Fire(action)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if held[action] then
			held[action] = false
			InputController.Released:Fire(action)
		end
	end
	-- Tab/B/M não devem engolir o input de outras UIs
	return if COMBAT[action] then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end

function InputController.Init()
	for action, inputs in BINDINGS do
		local touch = TOUCH_LAYOUT[action]
		ContextActionService:BindActionAtPriority("Offscope_" .. action, function(_, state)
			return handle(action, state)
		end, touch ~= nil, Enum.ContextActionPriority.High.Value, table.unpack(inputs))
		if touch then
			ContextActionService:SetTitle("Offscope_" .. action, touch.Title)
			ContextActionService:SetPosition("Offscope_" .. action, touch.Position)
		end
	end

	-- UI abriu: solta tudo que estava pressionado
	ClientState.UiOpenChanged:Connect(function(open)
		if open then
			for action, isHeld in held do
				if isHeld and COMBAT[action] then
					held[action] = false
					InputController.Released:Fire(action)
				end
			end
		end
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		for action, isHeld in held do
			if isHeld then
				held[action] = false
				InputController.Released:Fire(action)
			end
		end
	end)
end

return InputController
