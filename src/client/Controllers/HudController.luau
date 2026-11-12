--[[
	HudController — HUD de combate.
	Retículo (ponto + anel que mostra o spread REAL), hitmarker, números de dano, munição com
	pips e barra do ferrolho, vida, indicador de direção do dano, kill feed, toasts de estilo
	e o overlay da luneta. Tudo em pt-BR, tudo leve (sem imagens externas).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Spread = require(Shared.Combat.Spread)
local ShotStyle = require(Shared.Combat.ShotStyle)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local HudController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local New = Theme.New
local C = Theme.Colors

local gui: ScreenGui
local refs = {} :: { [string]: any }
local weapon = { Slot = "Sniper", Mag = Config.Sniper.MagSize, Reserve = 0, Spread = 0.25, Ads = 0, Bolt = 0, Reload = nil :: number? }
local hitmarkerTime = -10
local hitmarkerKill = false
local hitmarkerHead = false
local fpsFrames = 0
local fpsClock = 0

-- ── construção ─────────────────────────────────────────────────────────────
local function buildCrosshair(parent: Instance)
	local root = New("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(200, 200),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local dot = New("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = root,
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.4 }),
	})
	local ring = New("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Parent = root,
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Name = "Stroke", Color = Color3.new(1, 1, 1), Thickness = 1.2, Transparency = 0.45 }),
	})
	-- forma "cruz" (cosmético)
	local cross = New("Frame", { Name = "Cross", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = root })
	for i, spec in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		New("Frame", {
			Name = "Arm" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, spec[1] * 9, 0.5, spec[2] * 9),
			Size = if spec[1] == 0 then UDim2.fromOffset(2, 8) else UDim2.fromOffset(8, 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = cross,
		})
	end
	-- hitmarker: 4 traços diagonais
	local hit = New("Frame", { Name = "Hitmarker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, Parent = root })
	for i, angle in { 45, 135, 225, 315 } do
		local r = math.rad(angle)
		New("Frame", {
			Name = "Tick" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(r) * 13, 0.5, math.sin(r) * 13),
			Size = UDim2.fromOffset(11, 2.5),
			Rotation = angle,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Parent = hit,
		})
	end
	refs.Crosshair = root
	refs.Dot = dot
	refs.Ring = ring
	refs.Cross = cross
	refs.Hit = hit
	refs.HitScale = New("UIScale", { Parent = hit })
end

local function buildScope(parent: Instance)
	local scope = New("Frame", { Name = "Scope", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = parent })
	local lens = New("Frame", {
		Name = "Lens",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = Color3.fromRGB(20, 40, 60),
		BackgroundTransparency = 0.94,
		ZIndex = 5,
		Parent = scope,
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		-- o "truque" do traço gigante: tudo fora do círculo fica preto
		New("UIStroke", { Name = "Mask", Color = Color3.fromRGB(4, 4, 6), Thickness = 2400, Transparency = 0 }),
	})
	-- sombra interna da borda
	New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = lens,
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 26, Transparency = 0.35 }),
	})
	-- retículo da luneta: linhas finas + mil-dots + postes grossos nas bordas
	local function line(size: UDim2, position: UDim2)
		New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = size, BackgroundColor3 = Color3.fromRGB(10, 10, 10), BorderSizePixel = 0, ZIndex = 6, Parent = lens })
	end
	line(UDim2.new(1, 0, 0, 1), UDim2.fromScale(0.5, 0.5))
	line(UDim2.new(0, 1, 1, 0), UDim2.fromScale(0.5, 0.5))
	line(UDim2.new(0.3, 0, 0, 5), UDim2.fromScale(0.15, 0.5))
	line(UDim2.new(0.3, 0, 0, 5), UDim2.fromScale(0.85, 0.5))
	line(UDim2.new(0, 5, 0.3, 0), UDim2.fromScale(0.5, 0.85))
	for i = -4, 4 do
		if i ~= 0 then
			line(UDim2.fromOffset(4, 4), UDim2.new(0.5, i * 22, 0.5, 0))
			line(UDim2.fromOffset(4, 4), UDim2.new(0.5, 0, 0.5, i * 22))
		end
	end
	New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.fromRGB(255, 40, 40),
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = lens,
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	refs.Scope = scope
	refs.ScopeMask = lens:FindFirstChild("Mask")
end

local function buildWeaponPanel(parent: Instance)
	local panel = New("Frame", {
		Name = "Weapon",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -28),
		Size = UDim2.fromOffset(250, 96),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	refs.WeaponName = Theme.Label({
		Text = "VANTA-7",
		FontFace = Theme.Fonts.Title,
		TextSize = 14,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = panel,
	})
	refs.Ammo = Theme.Label({
		Text = "5",
		FontFace = Theme.Fonts.Display,
		TextSize = 54,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, -54, 0, 56),
		Parent = panel,
	})
	refs.Reserve = Theme.Label({
		Text = "/ ∞",
		FontFace = Theme.Fonts.Title,
		TextSize = 20,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -50, 0, 38),
		Size = UDim2.fromOffset(50, 24),
		Parent = panel,
	})
	local pips = New("Frame", {
		Name = "Pips",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 74),
		Size = UDim2.fromOffset(150, 10),
		BackgroundTransparency = 1,
		Parent = panel,
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4) }),
	})
	refs.Pips = {}
	for i = 1, Config.Sniper.MagSize do
		refs.Pips[i] = New("Frame", {
			LayoutOrder = -i,
			Size = UDim2.fromOffset(6, 10),
			BackgroundColor3 = C.Brand,
			BorderSizePixel = 0,
			Parent = pips,
			New("UICorner", { CornerRadius = UDim.new(0, 2) }),
		})
	end
	local barBack = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 90),
		Size = UDim2.fromOffset(150, 3),
		BackgroundColor3 = C.Line,
		BorderSizePixel = 0,
		Parent = panel,
	})
	refs.Bar = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Text, BorderSizePixel = 0, Parent = barBack })
	refs.Status = Theme.Label({
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextSize = 13,
		TextColor3 = C.Brand,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -18),
		Size = UDim2.fromOffset(250, 16),
		Parent = panel,
	})
end

local function buildHealth(parent: Instance)
	local panel = New("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -28),
		Size = UDim2.fromOffset(260, 60),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	refs.HealthText = Theme.Label({ Text = "100", FontFace = Theme.Fonts.Display, TextSize = 40, Size = UDim2.fromOffset(90, 44), Parent = panel })
	Theme.Label({ Text = "VIDA", FontFace = Theme.Fonts.Title, TextSize = 12, TextColor3 = C.TextDim, Position = UDim2.fromOffset(84, 20), Size = UDim2.fromOffset(60, 16), Parent = panel })
	local back = New("Frame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.fromOffset(220, 5),
		BackgroundColor3 = C.Line,
		BorderSizePixel = 0,
		Parent = panel,
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	refs.HealthLag = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Bad, BorderSizePixel = 0, Parent = back, New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	refs.HealthBar = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Text, BorderSizePixel = 0, Parent = back, New("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	-- vinheta de vida baixa (gradiente nas bordas)
	local vignette = New("Frame", { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	for i, rotation in { 0, 90, 180, 270 } do
		local horizontal = rotation % 180 == 0
		New("Frame", {
			Name = "Edge" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = if rotation == 0 then UDim2.fromScale(0.5, 0.06) elseif rotation == 180 then UDim2.fromScale(0.5, 0.94) elseif rotation == 90 then UDim2.fromScale(0.96, 0.5) else UDim2.fromScale(0.04, 0.5),
			Size = if horizontal then UDim2.fromScale(1, 0.14) else UDim2.fromScale(0.08, 1),
			BackgroundColor3 = Color3.fromRGB(170, 0, 0),
			BorderSizePixel = 0,
			Parent = vignette,
			New("UIGradient", {
				Rotation = rotation + 90,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
	end
	refs.Vignette = vignette
end

local function buildFeed(parent: Instance)
	refs.Feed = New("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 90),
		Size = UDim2.fromOffset(460, 260),
		BackgroundTransparency = 1,
		Parent = parent,
		New("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.Toasts = New("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(520, 200),
		BackgroundTransparency = 1,
		Parent = parent,
		New("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.Indicators = New("Frame", { Name = "DamageIndicators", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	refs.Fps = Theme.Label({ Text = "", FontFace = Theme.Fonts.Mono, TextSize = 12, TextColor3 = C.TextDim, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(120, 14), Parent = parent })
end

-- ── API usada pelo WeaponController ────────────────────────────────────────
function HudController.SetSlot(slot: string)
	weapon.Slot = slot
	if refs.WeaponName then
		refs.WeaponName.Text = if slot == "Knife" then string.upper(Config.Knife.DisplayName) else string.upper(Config.Sniper.DisplayName)
	end
end

function HudController.SetWeapon(info)
	weapon = info
end

function HudController.OnShot()
	if refs.Ammo then
		refs.Ammo.TextColor3 = C.Brand
		Theme.Tween(refs.Ammo, 0.3, { TextColor3 = C.Text })
	end
end

function HudController.Hitmarker(zone: string?, killed: boolean, _melee: boolean)
	hitmarkerTime = os.clock()
	hitmarkerKill = killed
	hitmarkerHead = zone == "Head"
	refs.HitScale.Scale = if killed then 1.5 else 1.25
	Theme.Tween(refs.HitScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
end

function HudController.DamageNumber(position: Vector3, amount: number, zone: string?)
	if amount <= 0 then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local billboard = New("BillboardGui", {
		Size = UDim2.fromOffset(80, 30),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = anchor,
		Parent = gui,
	})
	local label = Theme.Label({
		Text = tostring(amount),
		FontFace = Theme.Fonts.Display,
		TextSize = if zone == "Head" then 26 else 20,
		TextColor3 = if zone == "Head" then Color3.fromRGB(255, 90, 90) else C.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		Parent = billboard,
	})
	Theme.Tween(billboard, Config.UI.DamageNumberLifetime, { StudsOffset = Vector3.new(0, 2.5, 0) })
	Theme.Tween(label, Config.UI.DamageNumberLifetime, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(billboard, Config.UI.DamageNumberLifetime + 0.1)
	Debris:AddItem(anchor, Config.UI.DamageNumberLifetime + 0.1)
end

local function chip(parent: Instance, text: string, color: Color3, order: number)
	local label = Theme.Label({
		Text = text,
		FontFace = Theme.Fonts.Title,
		TextSize = 13,
		TextColor3 = C.Ink,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent,
	})
	Theme.Corner(4).Parent = label
	Theme.Padding(0, 7).Parent = label
	return label
end

-- payload: { Kind, Text?, Tags?, Coins?, Distance? }
function HudController.Toast(payload)
	if not refs.Toasts then
		return
	end
	local row = New("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.2,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = refs.Toasts,
		Theme.Corner(8),
		Theme.Padding(5, 10),
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local scale = New("UIScale", { Scale = 0.7, Parent = row })
	local order = 0
	if payload.Tags then
		for _, tag in payload.Tags do
			order += 1
			chip(row, ShotStyle.Labels[tag] or tag, ShotStyle.Colors[tag] or C.Text, order)
		end
	end
	if payload.Text then
		order += 1
		Theme.Label({
			Text = payload.Text,
			FontFace = Theme.Fonts.Title,
			TextSize = 15,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			LayoutOrder = order,
			Parent = row,
		})
	end
	if payload.Distance and payload.Distance >= Config.Style.LongShotDistance * 0.6 then
		order += 1
		Theme.Label({ Text = Format.Meters(payload.Distance), FontFace = Theme.Fonts.Mono, TextSize = 13, TextColor3 = C.TextDim, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = order, Parent = row })
	end
	if payload.Coins and payload.Coins > 0 then
		order += 1
		Theme.Label({ Text = `+{payload.Coins}`, FontFace = Theme.Fonts.Display, TextSize = 15, TextColor3 = C.Coin, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = order, Parent = row })
	end
	if order == 0 then
		row:Destroy()
		return
	end
	Theme.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(Config.UI.ToastLifetime, function()
		Theme.Tween(row, 0.3, { BackgroundTransparency = 1 })
		for _, child in row:GetDescendants() do
			if child:IsA("TextLabel") then
				Theme.Tween(child, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
			end
		end
		Debris:AddItem(row, 0.35)
	end)
	-- no máximo 4 toasts
	local rows = {}
	for _, child in refs.Toasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(rows, child)
		end
	end
	if #rows > 4 then
		table.sort(rows, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		rows[1]:Destroy()
	end
end

local function addFeedEntry(entry)
	local mine = entry.KillerId == player.UserId or entry.VictimId == player.UserId
	local row = New("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundColor3 = if entry.KillerId == player.UserId then Color3.fromRGB(60, 46, 12) else C.Panel,
		BackgroundTransparency = if mine then 0.15 else 0.35,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = refs.Feed,
		Theme.Corner(6),
		Theme.Padding(4, 10),
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function teamColor(team: string?): Color3
		if team == "A" then
			return C.TeamA
		elseif team == "B" then
			return C.TeamB
		end
		return C.Text
	end
	Theme.Label({ Text = entry.Killer, FontFace = Theme.Fonts.Title, TextSize = 15, TextColor3 = teamColor(entry.KillerTeam), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 1, Parent = row })
	Theme.Label({
		Text = if entry.Weapon == "Knife" then "╾─" else "▬═─",
		FontFace = Theme.Fonts.Mono,
		TextSize = 14,
		TextColor3 = C.TextDim,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		LayoutOrder = 2,
		Parent = row,
	})
	local order = 2
	for _, tag in entry.Tags or {} do
		order += 1
		chip(row, ShotStyle.Labels[tag] or tag, ShotStyle.Colors[tag] or C.Text, order)
	end
	Theme.Label({ Text = entry.Victim, FontFace = Theme.Fonts.Title, TextSize = 15, TextColor3 = teamColor(entry.VictimTeam), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 100, Parent = row })

	local children = {}
	for _, child in refs.Feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > Config.UI.KillFeedMax then
		table.sort(children, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(Config.UI.KillFeedLifetime, function()
		if row.Parent then
			Theme.Tween(row, 0.4, { BackgroundTransparency = 1 })
			for _, child in row:GetDescendants() do
				if child:IsA("TextLabel") then
					Theme.Tween(child, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
				end
			end
			Debris:AddItem(row, 0.45)
		end
	end)
end

local function damageIndicator(fromPosition: Vector3)
	local camCF = camera.CFrame
	local toSource = (fromPosition - camCF.Position) * Vector3.new(1, 0, 1)
	local forward = camCF.LookVector * Vector3.new(1, 0, 1)
	if toSource.Magnitude < 0.1 or forward.Magnitude < 0.1 then
		return
	end
	local angle = math.deg(math.atan2(forward.Unit:Cross(toSource.Unit).Y, forward.Unit:Dot(toSource.Unit)))
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(260, 260),
		BackgroundTransparency = 1,
		Rotation = -angle,
		Parent = refs.Indicators,
	})
	local bar = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(70, 6),
		BackgroundColor3 = Color3.fromRGB(255, 60, 50),
		BorderSizePixel = 0,
		Parent = holder,
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Theme.Tween(bar, 1.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(holder, 1.3)
end

-- ── loop ───────────────────────────────────────────────────────────────────
local healthLag = 1

local function update(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local inCombat = humanoid ~= nil and humanoid.Health > 0

	refs.Crosshair.Visible = inCombat and weapon.Ads < 0.92 and not ClientState.UiOpen
	refs.Scope.Visible = inCombat and weapon.Slot == "Sniper" and weapon.Ads > 0.92
	if refs.Scope.Visible then
		refs.ScopeMask.Thickness = math.max(camera.ViewportSize.X, camera.ViewportSize.Y)
	end

	-- retículo: o anel mostra o cone real do tiro agora
	local reticle = Config.Cosmetics[ClientState.Equipped("Reticle")]
	local color = reticle and reticle.Visual.Color or Color3.new(1, 1, 1)
	local isCross = reticle ~= nil and reticle.Visual.Shape == "Cross"
	refs.Dot.BackgroundColor3 = color
	refs.Cross.Visible = isCross
	for _, arm in refs.Cross:GetChildren() do
		(arm :: Frame).BackgroundColor3 = color
	end
	local pixels = Spread.ToPixels(weapon.Spread, camera.FieldOfView, camera.ViewportSize.Y)
	local diameter = math.clamp(pixels * 2, 10, 180)
	local current = refs.Ring.Size.X.Offset
	local nextSize = current + (diameter - current) * math.min(1, dt * 20)
	refs.Ring.Size = UDim2.fromOffset(nextSize, nextSize)
	refs.Ring.Visible = weapon.Slot == "Sniper"
	local fade = 1 - weapon.Ads
	refs.Ring.Stroke.Transparency = 0.45 + (1 - fade) * 0.55
	refs.Dot.BackgroundTransparency = if weapon.Slot == "Knife" then 0.2 else 0

	-- hitmarker
	local since = os.clock() - hitmarkerTime
	local hitAlpha = math.clamp(since / (if hitmarkerKill then 0.45 else 0.25), 0, 1)
	local tickColor = if hitmarkerKill then Color3.fromRGB(255, 70, 70) elseif hitmarkerHead then Color3.fromRGB(255, 200, 70) else Color3.new(1, 1, 1)
	for _, tick in refs.Hit:GetChildren() do
		if tick:IsA("Frame") then
			tick.BackgroundTransparency = hitAlpha
			tick.BackgroundColor3 = tickColor
		end
	end

	-- munição
	local isKnife = weapon.Slot == "Knife"
	refs.Ammo.Text = if isKnife then "—" else tostring(weapon.Mag)
	refs.Reserve.Text = if isKnife then "" elseif Config.Sniper.InfiniteReserve then "/ ∞" else `/ {weapon.Reserve}`
	for i, pip in refs.Pips do
		pip.Visible = not isKnife
		pip.BackgroundColor3 = if i <= weapon.Mag then C.Brand else C.Line
	end
	if weapon.Reload then
		refs.Bar.Size = UDim2.fromScale(math.clamp(weapon.Reload, 0, 1), 1)
		refs.Bar.BackgroundColor3 = C.Brand
		refs.Status.Text = "RECARREGANDO"
	elseif weapon.Bolt and weapon.Bolt > 0 then
		refs.Bar.Size = UDim2.fromScale(weapon.Bolt, 1)
		refs.Bar.BackgroundColor3 = C.Text
		refs.Status.Text = ""
	else
		refs.Bar.Size = UDim2.fromScale(if isKnife then 0 else 1, 1)
		refs.Bar.BackgroundColor3 = C.Text
		refs.Status.Text = if not isKnife and weapon.Mag == 0 then "SEM MUNIÇÃO · R" else ""
	end

	-- vida
	local health = if humanoid then math.max(0, humanoid.Health) else 0
	local maxHealth = if humanoid then humanoid.MaxHealth else 100
	local ratio = health / math.max(maxHealth, 1)
	refs.HealthText.Text = tostring(math.ceil(health))
	refs.HealthText.TextColor3 = if ratio < 0.35 then C.Bad else C.Text
	refs.HealthBar.Size = UDim2.fromScale(ratio, 1)
	healthLag += (ratio - healthLag) * math.min(1, dt * 3)
	if healthLag < ratio then
		healthLag = ratio
	end
	refs.HealthLag.Size = UDim2.fromScale(healthLag, 1)
	local danger = math.clamp((0.45 - ratio) / 0.45, 0, 1) * (0.75 + math.sin(os.clock() * 5) * 0.25)
	for _, edge in refs.Vignette:GetChildren() do
		(edge :: Frame).BackgroundTransparency = 1 - danger * 0.8
	end
	refs.Health.Visible = inCombat
	refs.Weapon.Visible = inCombat

	-- fps
	fpsFrames += 1
	if os.clock() - fpsClock >= 0.5 then
		refs.Fps.Text = if ClientState.Settings.ShowFps then `{math.floor(fpsFrames / (os.clock() - fpsClock))} FPS` else ""
		fpsFrames = 0
		fpsClock = os.clock()
	end
end

function HudController.Gui(): ScreenGui
	return gui
end

function HudController.Init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
			if ok then
				break
			end
			task.wait(1)
		end
	end)

	gui = New("ScreenGui", {
		Name = "OffscopeHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildScope(gui)
	buildCrosshair(gui)
	buildWeaponPanel(gui)
	buildHealth(gui)
	buildFeed(gui)
	refs.Health = gui:FindFirstChild("Health")
	refs.Weapon = gui:FindFirstChild("Weapon")

	Remotes.Event("KillFeed").OnClientEvent:Connect(addFeedEntry)
	Remotes.Event("Toast").OnClientEvent:Connect(HudController.Toast)
	Remotes.Event("Damaged").OnClientEvent:Connect(function(fromPosition: Vector3)
		damageIndicator(fromPosition)
	end)
end

function HudController.Start()
	RunService.RenderStepped:Connect(update)
end

return HudController
