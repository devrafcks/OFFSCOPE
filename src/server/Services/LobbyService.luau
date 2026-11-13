local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local DummyBuilder = require(Shared.Models.DummyBuilder)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)
local LobbyMap = require(ServerScriptService.Server.Maps.Lobby)

local LobbyService = {}

local built = nil :: any
local extras = nil :: any
local padGuis: { [string]: TextLabel } = {}
local padJoined: { [Player]: string } = {}
local dummyTemplate: Model? = nil
local boardGui: SurfaceGui? = nil

local PAD_RADIUS = 6.2

function LobbyService.SpawnInLobby(player: Player)
	if not extras or player.Parent ~= Players then
		return
	end
	Registry.CharacterService.SetContext(player, { Kind = "Lobby" })
	local spawns = extras.SpawnCFrames
	local cf = spawns[math.random(1, #spawns)]
	Registry.CharacterService.Spawn(player, cf, { Regen = true, Preset = "Lobby" })
end

local function buildPadGui(modeId: string, cf: CFrame)
	local anchor = Instance.new("Part")
	anchor.Name = "PadLabel_" .. modeId
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = cf * CFrame.new(0, 7, 0)
	anchor.Parent = built.Model

	local gui = Instance.new("BillboardGui")

	gui.Size = UDim2.fromScale(9, 3.6)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = anchor

	local mode = Config.Modes[modeId]
	local color = LobbyMap.PadColors[modeId] or Color3.new(1, 1, 1)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.5)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = color
	title.TextStrokeTransparency = 0.6
	title.Text = string.upper(mode.DisplayName)
	title.Parent = gui

	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.Position = UDim2.fromScale(0, 0.5)
	count.Size = UDim2.fromScale(1, 0.32)
	count.Font = Enum.Font.GothamMedium
	count.TextScaled = true
	count.TextColor3 = Color3.fromRGB(230, 230, 230)
	count.TextStrokeTransparency = 0.7
	count.Text = `0/{mode.Players} · pise para entrar`
	count.Parent = gui
	padGuis[modeId] = count
end

local function padLoop()
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			local context = Registry.CharacterService.GetContext(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if context.Kind ~= "Lobby" or not root then
				continue
			end
			local onPad: string? = nil
			for modeId, cf in extras.Pads do
				local offset = root.Position - cf.Position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= PAD_RADIUS and math.abs(offset.Y) < 6 then
					onPad = modeId
				end
			end
			local joinedViaPad = padJoined[player]
			if onPad and joinedViaPad ~= onPad then
				padJoined[player] = onPad
				Registry.MatchmakingService.Join(player, onPad)
			elseif not onPad and joinedViaPad then
				padJoined[player] = nil
				if Registry.MatchmakingService.ModeOf(player) == joinedViaPad then
					Registry.MatchmakingService.Leave(player)
				end
			end
		end
		for modeId, label in padGuis do
			local mode = Config.Modes[modeId]
			local queued = Registry.MatchmakingService.QueueCount(modeId)
			label.Text = if queued > 0 then `{queued}/{mode.Players} na fila` else `0/{mode.Players} · pise para entrar`
		end
	end
end

local function getTemplate(): Model?
	if dummyTemplate then
		return dummyTemplate
	end
	local description = Instance.new("HumanoidDescription")
	local orange = Color3.fromRGB(230, 120, 40)
	local gray = Color3.fromRGB(70, 74, 80)
	description.HeadColor = orange
	description.TorsoColor = gray
	description.LeftArmColor = gray
	description.RightArmColor = gray
	description.LeftLegColor = Color3.fromRGB(46, 48, 52)
	description.RightLegColor = Color3.fromRGB(46, 48, 52)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Lobby] não foi possível criar o rig dos dummies:", model)
		return nil
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	DummyBuilder.Dress(model)
	dummyTemplate = model
	return model
end

local function spawnDummy(cf: CFrame, label: string, mover: { From: CFrame, To: CFrame, Period: number }?)
	local template = getTemplate()
	if not template then
		return
	end
	local dummy = template:Clone()
	dummy.Name = "Dummy"
	dummy:SetAttribute("Dummy", true)
	dummy:SetAttribute("DisplayName", label)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = true
	root.Anchored = true
	dummy:PivotTo(cf)
	dummy.Parent = built.Model

	Registry.LagCompensation.Register(dummy, nil)

	local moveConnection: RBXScriptConnection? = nil
	if mover then
		local start = os.clock()
		moveConnection = RunService.Heartbeat:Connect(function()
			if humanoid.Health <= 0 then
				return
			end
			local t = (math.sin((os.clock() - start) / mover.Period * math.pi * 2) + 1) / 2
			dummy:PivotTo(mover.From:Lerp(mover.To, t))
		end)
	end

	humanoid.Died:Once(function()
		if moveConnection then
			moveConnection:Disconnect()
		end
		Registry.LagCompensation.Unregister(dummy)
		task.delay(1.6, function()
			dummy:Destroy()
			spawnDummy(cf, label, mover)
		end)
	end)
end

local function spawnDummies()
	for index, cf in extras.Dummies do
		local distance = ({ 25, 50, 100, 150, 200, 260 })[index] or 0
		spawnDummy(cf, `Alvo {Format.Meters(distance)}`, nil)
	end
	for _, mover in extras.MovingDummies do
		spawnDummy(mover.From, "Alvo móvel", mover)
	end
end

function LobbyService.RenderLeaderboard(board: { any })
	if not extras then
		return
	end
	if not boardGui then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Right
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.Parent = extras.Board
		local list = Instance.new("Frame")
		list.Name = "List"
		list.BackgroundTransparency = 1
		list.Size = UDim2.fromScale(1, 1)
		list.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 30)
		pad.PaddingLeft = UDim.new(0, 40)
		pad.PaddingRight = UDim.new(0, 40)
		pad.Parent = list
		boardGui = gui
	end
	local list = (boardGui :: SurfaceGui):FindFirstChild("List") :: Frame
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local function row(order: number, text: string, color: Color3, size: number, font: Enum.Font)
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, size)
		label.Font = font
		label.TextSize = size * 0.8
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = color
		label.Text = text
		label.Parent = list
	end
	row(0, "RANKING", Color3.fromRGB(255, 196, 60), 70, Enum.Font.GothamBlack)
	row(1, Config.Ranked.SeasonName, Color3.fromRGB(200, 200, 200), 34, Enum.Font.GothamMedium)
	if #board == 0 then
		row(2, "Jogue uma ranked para aparecer aqui.", Color3.fromRGB(160, 160, 160), 36, Enum.Font.Gotham)
	end
	for i, entry in board do
		row(i + 2, string.format("%02d   %s   ·   %d  %s", i, entry.Name, entry.Elo, entry.Tier), Color3.fromRGB(240, 240, 240), 40, if i <= 3 then Enum.Font.GothamBold else Enum.Font.Gotham)
	end
end

local function setupKiosk()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShop"
	prompt.ActionText = "Abrir loja"
	prompt.ObjectText = "Arsenal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = extras.Kiosk
end

function LobbyService.Init()
	if Registry.RoundService.Role() ~= "Lobby" then
		return
	end
	built, extras = LobbyMap.Build(CFrame.identity)
	for modeId, cf in extras.Pads do
		buildPadGui(modeId, cf)
	end
	setupKiosk()
	LobbyService.RenderLeaderboard({})

	Registry.DataService.ProfileLoaded:Connect(function(player)
		LobbyService.SpawnInLobby(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		padJoined[player] = nil
	end)
end

function LobbyService.Start()
	if not extras then
		return
	end
	task.spawn(spawnDummies)
	padLoop()
end

return LobbyService
