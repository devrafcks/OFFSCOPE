--[[
	MenuController — UI do lobby: cartão de perfil (nível, XP, ELO, moedas), botões JOGAR /
	LOJA / CONFIGURAÇÕES, seletor de modos, status da fila, desafios do dia, configurações
	(sensibilidade, scope, FOV, desempenho, FPS) e a cola de controles.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local Format = require(Shared.Util.Format)
local Ranks = require(Shared.Progression.Ranks)
local Levels = require(Shared.Progression.Levels)
local Theme = require(script.Parent.Parent.UI.Theme)
local ClientState = require(script.Parent.Parent.ClientState)
local InputController = require(script.Parent.InputController)
local ShopController = require(script.Parent.ShopController)

local MenuController = {}

local player = Players.LocalPlayer
local New = Theme.New
local C = Theme.Colors

local gui: ScreenGui
local refs = {} :: { [string]: any }
local openModal: Frame? = nil

local MODE_ACCENT = {
	Duel = Color3.fromRGB(0, 220, 255),
	RankedDuel = Color3.fromRGB(255, 176, 56),
	Duos = Color3.fromRGB(120, 255, 160),
	RankedDuos = Color3.fromRGB(255, 92, 92),
	Squads = Color3.fromRGB(170, 120, 255),
	FFA = Color3.fromRGB(255, 255, 255),
}

-- ── modais ─────────────────────────────────────────────────────────────────
function MenuController.CloseModal()
	if openModal then
		openModal.Visible = false
		openModal = nil
	end
	ClientState.SetUiOpen(ShopController.IsOpen())
end

function MenuController.OpenModal(frame: Frame)
	if openModal == frame then
		MenuController.CloseModal()
		return
	end
	if openModal then
		openModal.Visible = false
	end
	ShopController.Close()
	openModal = frame
	frame.Visible = true
	local scale = frame:FindFirstChildOfClass("UIScale") or New("UIScale", { Parent = frame })
	local fit = Theme.FitScale(frame)
	scale.Scale = fit * 0.94
	Theme.Tween(scale, 0.22, { Scale = fit }, Enum.EasingStyle.Back)
	ClientState.SetUiOpen(true)
	Audio.Play2D("UiClick")
end

local function modal(name: string, title: string, size: Vector2): Frame
	local frame = Theme.Panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Theme.Fit(frame, size)
	Theme.Label({ Text = title, FontFace = Theme.Fonts.Display, TextSize = 26, Position = UDim2.fromOffset(26, 20), Size = UDim2.new(1, -100, 0, 32), Parent = frame })
	local close = Theme.Button("×", "Ghost", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(36, 36), TextSize = 24, Parent = frame })
	close.Activated:Connect(MenuController.CloseModal)
	return frame
end

-- ── perfil ─────────────────────────────────────────────────────────────────
local function buildProfileCard()
	-- coluna à esquerda, abaixo da área do chat do Roblox (que ocupa o canto superior esquerdo)
	refs.LeftColumn = New("Frame", {
		Name = "LeftColumn",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.55, 0),
		Size = UDim2.fromOffset(300, 278),
		BackgroundTransparency = 1,
		Parent = gui,
		Theme.List(nil, 12),
	})
	local card = Theme.Panel({ Name = "Profile", LayoutOrder = 1, Size = UDim2.fromOffset(300, 116), Parent = refs.LeftColumn })
	refs.Name = Theme.Label({ Text = player.DisplayName, FontFace = Theme.Fonts.Title, TextSize = 18, Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(200, 22), Parent = card })
	refs.Level = Theme.Label({ Text = "NÍVEL 1", FontFace = Theme.Fonts.Title, TextSize = 12, TextColor3 = C.TextDim, Position = UDim2.fromOffset(16, 36), Size = UDim2.fromOffset(120, 14), Parent = card })
	local xpBack = New("Frame", { Position = UDim2.fromOffset(16, 54), Size = UDim2.new(1, -32, 0, 4), BackgroundColor3 = C.Line, BorderSizePixel = 0, Parent = card, Theme.Corner(2) })
	refs.Xp = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Brand, BorderSizePixel = 0, Parent = xpBack, Theme.Corner(2) })
	refs.Tier = Theme.Label({ Text = "", FontFace = Theme.Fonts.Title, TextSize = 14, Position = UDim2.fromOffset(16, 68), Size = UDim2.fromOffset(200, 18), Parent = card })
	refs.Coins = Theme.Label({ Text = "◆ 0", FontFace = Theme.Fonts.Display, TextSize = 18, TextColor3 = C.Coin, Position = UDim2.fromOffset(16, 88), Size = UDim2.fromOffset(200, 20), Parent = card })
	refs.Profile = card
end

local function renderProfile(profile)
	if not profile then
		return
	end
	refs.Level.Text = `NÍVEL {profile.Level}`
	refs.Xp.Size = UDim2.fromScale(math.clamp(profile.Xp / Levels.XpForLevel(profile.Level), 0, 1), 1)
	local tier = Ranks.For(profile.Elo)
	refs.Tier.Text = `{string.upper(tier.Name)} · {profile.Elo} ELO`
	refs.Tier.TextColor3 = tier.Color
	refs.Coins.Text = `◆ {Format.Number(profile.Coins)}`
	MenuController.RenderChallenges(profile)
end

-- ── desafios do dia ────────────────────────────────────────────────────────
local function buildChallenges()
	local panel = Theme.Panel({ Name = "Challenges", LayoutOrder = 2, Size = UDim2.fromOffset(300, 150), Parent = refs.LeftColumn })
	Theme.Label({ Text = "DESAFIOS DO DIA", FontFace = Theme.Fonts.Title, TextSize = 12, TextColor3 = C.TextDim, Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(200, 14), Parent = panel })
	refs.ChallengeList = New("Frame", { Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 1, -40), BackgroundTransparency = 1, Parent = panel, Theme.List(nil, 8) })
	refs.Challenges = panel
end

function MenuController.RenderChallenges(profile)
	local list = refs.ChallengeList
	if not list or not profile or not profile.Daily then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, id in profile.Daily.Ids or {} do
		local challenge
		for _, c in Config.DailyChallenges.Pool do
			if c.Id == id then
				challenge = c
			end
		end
		if challenge then
			local progress = math.clamp((profile.Stats[challenge.Stat] or 0) - (profile.Daily.Base[id] or 0), 0, challenge.Goal)
			local done = profile.Daily.Claimed and profile.Daily.Claimed[id]
			local row = New("Frame", { LayoutOrder = index, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = list })
			Theme.Label({ Text = challenge.Text, FontFace = Theme.Fonts.Body, TextSize = 13, TextColor3 = if done then C.Good else C.Text, Size = UDim2.new(1, -70, 0, 16), Parent = row })
			Theme.Label({ Text = if done then "✓" else `{progress}/{challenge.Goal}`, FontFace = Theme.Fonts.Mono, TextSize = 12, TextColor3 = if done then C.Good else C.TextDim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(70, 16), Parent = row })
			local back = New("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.Line, BorderSizePixel = 0, Parent = row })
			New("Frame", { Size = UDim2.fromScale(progress / challenge.Goal, 1), BackgroundColor3 = if done then C.Good else C.Brand, BorderSizePixel = 0, Parent = back })
		end
	end
end

-- ── botões e fila ──────────────────────────────────────────────────────────
local function buildActions()
	local column = New("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(220, 200),
		BackgroundTransparency = 1,
		Parent = gui,
		Theme.List(nil, 10, Enum.HorizontalAlignment.Right),
	})
	local play = Theme.Button("JOGAR  [P]", "Primary", { LayoutOrder = 1, Size = UDim2.fromOffset(220, 56), TextSize = 22, Parent = column })
	local shop = Theme.Button("LOJA  [B]", "Ghost", { LayoutOrder = 2, Size = UDim2.fromOffset(220, 44), Parent = column })
	local settings = Theme.Button("CONFIGURAÇÕES  [M]", "Ghost", { LayoutOrder = 3, Size = UDim2.fromOffset(220, 44), Parent = column })
	play.Activated:Connect(function()
		MenuController.OpenModal(refs.PlayModal)
	end)
	shop.Activated:Connect(function()
		MenuController.CloseModal()
		ShopController.Toggle()
	end)
	settings.Activated:Connect(function()
		MenuController.OpenModal(refs.SettingsModal)
	end)
	refs.Actions = column

	local pill = Theme.Panel({
		Name = "Queue",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(440, 52),
		Visible = false,
		Parent = gui,
	})
	refs.QueueText = Theme.Label({ Text = "", FontFace = Theme.Fonts.Title, TextSize = 16, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -150, 1, 0), Parent = pill })
	local cancel = Theme.Button("SAIR DA FILA", "Ghost", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 34), TextSize = 13, Parent = pill })
	cancel.Activated:Connect(function()
		Remotes.Event("Queue"):FireServer(nil)
	end)
	refs.Queue = pill
end

local searchDots = 0
local function renderQueue(queue)
	refs.Queue.Visible = queue ~= nil and not ClientState.InMatch()
	if queue then
		local mode = Config.Modes[queue.Mode]
		searchDots = (searchDots % 3) + 1
		refs.QueueText.Text = `PROCURANDO {string.upper(mode and mode.DisplayName or "")} · {queue.Count}/{queue.Needed}{string.rep(".", searchDots)}`
	end
end

-- ── seletor de modos ───────────────────────────────────────────────────────
local function buildPlayModal()
	local frame = modal("PlayModal", "ESCOLHA O MODO", Vector2.new(820, 470))
	local grid = New("Frame", {
		Position = UDim2.fromOffset(26, 72),
		Size = UDim2.new(1, -52, 1, -96),
		BackgroundTransparency = 1,
		Parent = frame,
		New("UIGridLayout", { CellSize = UDim2.fromOffset(246, 170), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for index, modeId in Config.ModeOrder do
		local mode = Config.Modes[modeId]
		local accent = MODE_ACCENT[modeId] or C.Text
		local card = New("TextButton", {
			LayoutOrder = index,
			AutoButtonColor = false,
			BackgroundColor3 = C.PanelHi,
			BorderSizePixel = 0,
			Text = "",
			Parent = grid,
			Theme.Corner(10),
			Theme.Stroke(accent, 1, 0.6),
		})
		New("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = card })
		if mode.Ranked then
			local badge = Theme.Label({ Text = "RANKED", FontFace = Theme.Fonts.Title, TextSize = 11, TextColor3 = C.Ink, BackgroundColor3 = accent, BackgroundTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 14), Size = UDim2.fromOffset(64, 18), Parent = card })
			Theme.Corner(4).Parent = badge
		end
		local title = Theme.Label({ Text = string.upper(mode.DisplayName), FontFace = Theme.Fonts.Display, TextScaled = true, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 26), Parent = card })
		New("UITextSizeConstraint", { MaxTextSize = 22, Parent = title })
		Theme.Label({ Text = mode.Description, FontFace = Theme.Fonts.Body, TextSize = 13, TextColor3 = C.TextDim, TextWrapped = true, Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 0, 40), TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		Theme.Label({ Text = `{mode.Players} jogadores`, FontFace = Theme.Fonts.Mono, TextSize = 12, TextColor3 = accent, Position = UDim2.new(0, 16, 1, -32), Size = UDim2.fromOffset(160, 16), Parent = card })
		card.MouseEnter:Connect(function()
			Theme.Tween(card, 0.12, { BackgroundColor3 = C.PanelHi:Lerp(accent, 0.12) })
		end)
		card.MouseLeave:Connect(function()
			Theme.Tween(card, 0.12, { BackgroundColor3 = C.PanelHi })
		end)
		card.Activated:Connect(function()
			Remotes.Event("Queue"):FireServer(modeId)
			Audio.Play2D("UiClick")
			MenuController.CloseModal()
		end)
	end
	Theme.Label({
		Text = "Dica: pisar num pad do lobby também entra na fila.",
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.TextDim,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 26, 1, -14),
		Size = UDim2.fromOffset(500, 16),
		Parent = frame,
	})
	refs.PlayModal = frame
end

-- ── configurações ──────────────────────────────────────────────────────────
local function slider(parent: Instance, order: number, label: string, min: number, max: number, step: number, key: string, format: (number) -> string)
	local row = New("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = parent })
	Theme.Label({ Text = label, FontFace = Theme.Fonts.Title, TextSize = 14, Size = UDim2.new(1, -80, 0, 18), Parent = row })
	local valueLabel = Theme.Label({ Text = "", FontFace = Theme.Fonts.Mono, TextSize = 14, TextColor3 = C.Brand, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(80, 18), Parent = row })
	local track = New("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = C.Line, BorderSizePixel = 0, Parent = row, Theme.Corner(4) })
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Brand, BorderSizePixel = 0, Parent = track, Theme.Corner(4) })
	local knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C.Text, BorderSizePixel = 0, Parent = track, Theme.Corner(8) })

	local function show(value: number)
		local t = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(t, 1)
		knob.Position = UDim2.fromScale(t, 0.5)
		valueLabel.Text = format(value)
	end
	local dragging = false
	local function setFromX(x: number)
		local t = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local value = math.floor((min + (max - min) * t) / step + 0.5) * step
		show(value)
		return value
	end
	local pending: number? = nil
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			pending = setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			pending = setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if pending then
				ClientState.SaveSettings({ [key] = pending })
				pending = nil
			end
		end
	end)
	ClientState.SettingsChanged:Connect(function(settings)
		if not dragging and settings[key] then
			show(settings[key])
		end
	end)
	show(ClientState.Settings[key] or min)
end

local function toggle(parent: Instance, order: number, label: string, hint: string, key: string)
	local row = New("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = parent })
	Theme.Label({ Text = label, FontFace = Theme.Fonts.Title, TextSize = 14, Size = UDim2.new(1, -80, 0, 18), Parent = row })
	Theme.Label({ Text = hint, FontFace = Theme.Fonts.Body, TextSize = 12, TextColor3 = C.TextDim, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, -80, 0, 16), Parent = row })
	local button = Theme.Button("", "Ghost", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(64, 30), TextSize = 13, Parent = row })
	local function show(value: boolean)
		button.Text = if value then "LIGADO" else "DESLIG."
		button.TextColor3 = if value then C.Good else C.TextDim
	end
	button.Activated:Connect(function()
		ClientState.SaveSettings({ [key] = not ClientState.Settings[key] })
		Audio.Play2D("UiClick")
	end)
	ClientState.SettingsChanged:Connect(function(settings)
		show(settings[key] == true)
	end)
	show(ClientState.Settings[key] == true)
end

local function buildSettingsModal()
	local frame = modal("SettingsModal", "CONFIGURAÇÕES", Vector2.new(520, 470))
	local list = New("Frame", { Position = UDim2.fromOffset(26, 72), Size = UDim2.new(1, -52, 1, -90), BackgroundTransparency = 1, Parent = frame, Theme.List(nil, 8) })
	slider(list, 1, "Sensibilidade", 0.2, 3, 0.05, "Sensitivity", function(v)
		return string.format("%.2f", v)
	end)
	slider(list, 2, "Sensibilidade no scope", 0.2, 1.5, 0.05, "AdsSensitivity", function(v)
		return string.format("%.2f", v)
	end)
	slider(list, 3, "Campo de visão (FOV)", 80, 110, 1, "Fov", function(v)
		return `{math.floor(v)}°`
	end)
	toggle(list, 4, "Modo desempenho", "Desliga bloom, sun rays e luzes secundárias", "PerformanceMode")
	toggle(list, 5, "Mostrar FPS", "Contador no canto da tela", "ShowFps")
	-- sair no meio da partida (antes só dava na votação; um FFA de 8 min prendia o jogador)
	local leave = Theme.Button("SAIR DA PARTIDA", "Danger", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(240, 44),
		Visible = false,
		Parent = frame,
	})
	leave.Activated:Connect(function()
		Remotes.Event("Queue"):FireServer("leave")
		Audio.Play2D("UiClick")
		MenuController.CloseModal()
	end)
	refs.LeaveMatch = leave
	refs.SettingsModal = frame
end

-- ── cola de controles ──────────────────────────────────────────────────────
local function buildHints()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local text = if touch
		then "Arraste à direita para mirar · ATIRAR · SCOPE · FACA · SLIDE · CORRER"
		else "LMB atirar  ·  RMB scope  ·  SHIFT correr  ·  C slide  ·  Q faca  ·  V faca rápida  ·  R recarregar  ·  F inspecionar  ·  TAB placar"
	-- fundo escuro atrás do texto: legível sobre qualquer cenário (céu claro, neon, noite)
	local pill = New("Frame", {
		Name = "Hints",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = gui,
		Theme.Corner(14),
		Theme.Padding(0, 14),
	})
	Theme.Label({
		Text = text,
		FontFace = Theme.Fonts.Body,
		TextSize = 14,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		Parent = pill,
	})
	Theme.Fit(pill, Vector2.new(980, 28), 16)
	refs.Hints = pill
end

-- tela baixa (celular deitado): só o essencial, sem empilhar painéis sobre o jogo
local function isCompact(): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y < 600
end

local function renderVisibility()
	local inMatch = ClientState.InMatch()
	local compact = isCompact()
	for _, key in { "Profile", "Challenges", "Actions", "Hints" } do
		if refs[key] then
			refs[key].Visible = not inMatch and not (compact and (key == "Challenges" or key == "Hints"))
		end
	end
	if refs.LeaveMatch then
		refs.LeaveMatch.Visible = inMatch
	end
	if inMatch then
		MenuController.CloseModal()
	end
	renderQueue(ClientState.Queue)
end

function MenuController.Init()
	gui = New("ScreenGui", {
		Name = "OffscopeMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildProfileCard()
	buildChallenges()
	buildActions()
	buildPlayModal()
	buildSettingsModal()
	buildHints()

	ClientState.ProfileChanged:Connect(renderProfile)
	ClientState.QueueChanged:Connect(renderQueue)
	ClientState.MatchChanged:Connect(renderVisibility)
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(renderVisibility)
	end
	InputController.Pressed:Connect(function(action)
		if action == "Menu" then
			MenuController.OpenModal(refs.SettingsModal)
		elseif action == "Play" then
			-- o mouse fica travado no lobby (FPS): o atalho abre os modos e libera o cursor
			if not ClientState.InMatch() then
				MenuController.OpenModal(refs.PlayModal)
			end
		elseif action == "Shop" then
			if not ClientState.InMatch() then
				MenuController.CloseModal()
				ShopController.Toggle()
			end
		end
	end)
end

function MenuController.Start()
	renderVisibility()
	task.spawn(function()
		while true do
			task.wait(0.6)
			if ClientState.Queue then
				renderQueue(ClientState.Queue)
			end
		end
	end)
end

return MenuController
