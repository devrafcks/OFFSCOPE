--[[
	ShopController — o "Arsenal".
	Abas: Loja do dia (rotativa, igual em todos os servidores) · Catálogo (permanente) ·
	Inventário (equipar) · Passe (30 tiers, faixa grátis + Prime). Preview 3D real das armas
	via ViewportFrame com o mesmo builder do jogo. Preço em moedas E em Robux, sem caixa.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local Format = require(Shared.Util.Format)
local Levels = require(Shared.Progression.Levels)
local Catalog = require(Shared.Cosmetics.Catalog)
local DailyShop = require(Shared.Cosmetics.DailyShop)
local WrapPainter = require(Shared.Cosmetics.WrapPainter)
local SniperBuilder = require(Shared.Models.SniperBuilder)
local KnifeBuilder = require(Shared.Models.KnifeBuilder)
local CharmBuilder = require(Shared.Models.CharmBuilder)
local ModelKit = require(Shared.Models.ModelKit)
local Theme = require(script.Parent.Parent.UI.Theme)
local ClientState = require(script.Parent.Parent.ClientState)
local HudController = require(script.Parent.HudController)

local ShopController = {}

local player = Players.LocalPlayer
local New = Theme.New
local C = Theme.Colors

local gui: ScreenGui
local window: Frame
local content: ScrollingFrame
local refs = {} :: { [string]: any }
local currentTab = "Daily"
local isOpen = false
local busy = false
local stopAnimations: { () -> () } = {}
local inventoryFilter = "Wrap"

-- ── preview 3D ─────────────────────────────────────────────────────────────
local function frameModel(viewport: ViewportFrame, model: Model, distanceScale: number?)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * (distanceScale or 1.05)
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(distance * 0.55, distance * 0.25, distance * 0.8).Unit * distance, cf.Position)
end

local function preview(parent: Instance, item: Catalog.Item): ViewportFrame
	local viewport = New("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-1, -1.2, -0.6),
		Parent = parent,
	})
	local category = item.Category
	if category == "Wrap" then
		local sniper = SniperBuilder.Build("Full")
		table.insert(stopAnimations, WrapPainter.Apply(sniper.Model, item.Id, { Textures = true, Animate = true }))
		frameModel(viewport, sniper.Model, 0.9)
	elseif category == "Knife" then
		local knife = KnifeBuilder.Build(item.Visual.Shape)
		WrapPainter.PaintKnife(knife.Model, item.Id)
		frameModel(viewport, knife.Model, 0.95)
	elseif category == "Charm" and item.Visual.Kind ~= "None" then
		local holder = Instance.new("Model")
		local root = ModelKit.Part(holder, { Name = "Root", Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.identity, Transparency = 1 })
		local mount = ModelKit.Attachment(root, "Mount", CFrame.identity)
		CharmBuilder.Attach(root, mount, item.Visual)
		frameModel(viewport, holder, 1.2)
	else
		-- ícone tipográfico para efeitos/retículos/tracers
		viewport:Destroy()
		local color = item.Visual.Color or Config.Rarities[item.Rarity].Color
		local glyph = if category == "Reticle" then (if item.Visual.Shape == "Cross" then "+" else "•") elseif category == "Tracer" then "━━━" elseif category == "Finisher" then "◉" else "★"
		local tile = New("Frame", { Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1, Parent = parent })
		Theme.Label({ Text = glyph, FontFace = Theme.Fonts.Display, TextSize = 54, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = tile })
		return nil :: any
	end
	return viewport
end

-- ── ações ──────────────────────────────────────────────────────────────────
local function request(action: string, payload: { [string]: any }?)
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return Remotes.Function("Shop"):InvokeServer(action, payload or {})
	end)
	busy = false
	if not ok or type(result) ~= "table" then
		HudController.Toast({ Kind = "Error", Text = "A loja não respondeu. Tente de novo." })
		return
	end
	if result.Message then
		HudController.Toast({ Kind = if result.Ok then "Purchase" else "Error", Text = result.Message })
	end
	if result.Ok then
		Audio.Play2D(if action == "Equip" then "UiClick" else "UiBuy")
	end
end

-- ── cartões ────────────────────────────────────────────────────────────────
local function card(item: Catalog.Item, order: number, context: string)
	local rarity = Config.Rarities[item.Rarity]
	local owned = ClientState.Owns(item.Id)
	local equipped = ClientState.Equipped(item.Category) == item.Id
	local frame = New("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = C.PanelHi,
		BorderSizePixel = 0,
		Parent = content,
		Theme.Corner(10),
		Theme.Stroke(rarity.Color, if equipped then 2 else 1, if equipped then 0 else 0.55),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.PanelHi, C.PanelHi:Lerp(rarity.Color, 0.14)) }),
	})
	preview(frame, item)
	New("Frame", { Position = UDim2.fromOffset(12, 114), Size = UDim2.fromOffset(28, 3), BackgroundColor3 = rarity.Color, BorderSizePixel = 0, Parent = frame })
	Theme.Label({ Text = item.Name, FontFace = Theme.Fonts.Title, TextSize = 15, Position = UDim2.fromOffset(12, 122), Size = UDim2.new(1, -24, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	Theme.Label({ Text = `{string.upper(rarity.Name)} · {Config.Categories[item.Category] or item.Category}`, FontFace = Theme.Fonts.Body, TextSize = 11, TextColor3 = rarity.Color, Position = UDim2.fromOffset(12, 142), Size = UDim2.new(1, -24, 0, 14), Parent = frame })

	local buttons = New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -20, 0, 32),
		BackgroundTransparency = 1,
		Parent = frame,
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	if owned then
		local button = Theme.Button(if equipped then "EQUIPADO" else "EQUIPAR", if equipped then "Ghost" else "Primary", { Size = UDim2.fromScale(1, 1), TextSize = 13, Parent = buttons })
		button.Active = not equipped
		button.Activated:Connect(function()
			if not equipped then
				request("Equip", { ItemId = item.Id })
			end
		end)
	elseif context ~= "Pass" then
		local coinsOk = item.PriceCoins ~= nil and (item.Pool ~= "pass" or item.Rarity == "Legendary")
		if coinsOk then
			local affordable = ClientState.Profile and ClientState.Profile.Coins >= (item.PriceCoins :: number)
			local coin = Theme.Button(`◆ {Format.Number(item.PriceCoins :: number)}`, "Ghost", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 13, TextColor3 = if affordable then C.Coin else C.TextDim, Parent = buttons })
			coin.Activated:Connect(function()
				request("BuyCoins", { ItemId = item.Id })
			end)
		end
		if item.PriceRobux then
			local robux = Theme.Button(`R$ {item.PriceRobux}`, "Primary", { Size = if coinsOk then UDim2.new(0.5, -3, 1, 0) else UDim2.fromScale(1, 1), TextSize = 13, Parent = buttons })
			robux.Activated:Connect(function()
				request("BuyRobux", { ItemId = item.Id })
			end)
		end
	end
	return frame
end

local function clearContent()
	for _, stop in stopAnimations do
		stop()
	end
	table.clear(stopAnimations)
	for _, child in content:GetChildren() do
		if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- a aba Passe usa lista vertical; as outras, grade
local function setGrid(enabled: boolean)
	refs.Grid.Parent = if enabled then content else nil
	refs.List.Parent = if enabled then nil else content
end

-- ── abas ───────────────────────────────────────────────────────────────────
local function renderDaily()
	setGrid(true)
	local profile = ClientState.Profile
	if profile and not profile.StarterPackOwned then
		local banner = New("Frame", { LayoutOrder = 0, BackgroundColor3 = C.BrandDark, BorderSizePixel = 0, Parent = content, Theme.Corner(10) })
		New("UIGradient", { Color = ColorSequence.new(C.Brand, C.BrandDark), Parent = banner })
		Theme.Label({ Text = string.upper(Config.StarterPack.Name), FontFace = Theme.Fonts.Display, TextSize = 18, TextColor3 = C.Ink, Position = UDim2.fromOffset(14, 16), Size = UDim2.new(1, -28, 0, 22), Parent = banner })
		local names = {}
		for _, id in Config.StarterPack.Items do
			table.insert(names, (Catalog.Get(id) :: any).Name)
		end
		Theme.Label({ Text = table.concat(names, " + "), FontFace = Theme.Fonts.Body, TextSize = 13, TextColor3 = C.Ink, TextWrapped = true, Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -28, 0, 60), TextYAlignment = Enum.TextYAlignment.Top, Parent = banner })
		local buy = Theme.Button(`R$ {Config.StarterPack.PriceRobux}`, "Ghost", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 32), TextColor3 = C.Text, BackgroundColor3 = C.Ink, Parent = banner })
		buy.Activated:Connect(function()
			request("BuyStarter")
		end)
	end
	for index, id in DailyShop.Items() do
		local item = Catalog.Get(id)
		if item then
			card(item, index, "Daily")
		end
	end
	refs.Subtitle.Text = `A loja vira em {Format.Time(DailyShop.SecondsUntilReset())} (h:m)`
end

local function renderCatalog()
	setGrid(true)
	for index, item in Catalog.ByPool("catalog") do
		card(item, index, "Catalog")
	end
	refs.Subtitle.Text = "Camos e acessórios básicos, sempre à venda."
end

local function renderInventory()
	setGrid(true)
	local filters = New("Frame", {
		LayoutOrder = -1,
		BackgroundTransparency = 1,
		Parent = content,
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Wraps = true }),
	})
	for category, label in Config.Categories do
		local chip = Theme.Button(label, if category == inventoryFilter then "Primary" else "Ghost", { Size = UDim2.fromOffset(104, 28), TextSize = 12, Parent = filters })
		chip.Activated:Connect(function()
			inventoryFilter = category
			ShopController.Render()
		end)
	end
	local order = 0
	for _, item in Catalog.ByCategory(inventoryFilter) do
		if ClientState.Owns(item.Id) then
			order += 1
			card(item, order, "Inventory")
		end
	end
	refs.Subtitle.Text = "Clique para equipar. Tudo é só visual."
end

local function renderPass()
	setGrid(false)
	local profile = ClientState.Profile
	local passXp = if profile then profile.Pass.Xp else 0
	local tier = Levels.PassTier(passXp)
	local prime = profile ~= nil and profile.Pass.Prime

	local header = New("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, Parent = content })
	Theme.Label({ Text = string.upper(Config.Pass.Name), FontFace = Theme.Fonts.Display, TextSize = 20, Size = UDim2.new(1, -220, 0, 24), Parent = header })
	Theme.Label({ Text = `Tier {tier}/{Config.Pass.Tiers} · {passXp % Config.Pass.XpPerTier}/{Config.Pass.XpPerTier} XP`, FontFace = Theme.Fonts.Body, TextSize = 13, TextColor3 = C.TextDim, Position = UDim2.fromOffset(0, 28), Size = UDim2.fromOffset(400, 16), Parent = header })
	local primeButton = Theme.Button(if prime then "PRIME ATIVO" else `PRIME · R$ {Config.Pass.PrimePriceRobux}`, if prime then "Ghost" else "Primary", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(200, 40), Parent = header })
	primeButton.Activated:Connect(function()
		if not prime then
			request("BuyPrime")
		end
	end)

	local track = New("ScrollingFrame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 330),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		Parent = content,
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function cell(parent: Instance, tierIndex: number, track: string, y: number)
		local rewards = if track == "Free" then Config.Pass.Free else Config.Pass.Prime
		local itemId = rewards[tierIndex]
		local item = itemId and Catalog.Get(itemId)
		local claimed = profile and (if track == "Free" then profile.Pass.ClaimedFree else profile.Pass.ClaimedPrime)[tostring(tierIndex)]
		local unlocked = tierIndex <= tier and (track == "Free" or prime)
		local color = if item then Config.Rarities[item.Rarity].Color elseif track == "Prime" then C.Brand else C.Line
		local box = New("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(120, 130),
			BackgroundColor3 = C.PanelHi,
			BackgroundTransparency = if unlocked then 0 else 0.5,
			BorderSizePixel = 0,
			Parent = parent,
			Theme.Corner(8),
			Theme.Stroke(color, 1, if unlocked then 0.2 else 0.7),
		})
		local text = if item then item.Name else `◆ {if track == "Free" then Config.Pass.FreeCoinsPerTier else Config.Pass.PrimeCoinsPerTier}`
		Theme.Label({ Text = text, FontFace = Theme.Fonts.Title, TextSize = 13, TextColor3 = if item then color else C.Coin, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 16), Size = UDim2.new(1, -16, 0, 60), Parent = box })
		Theme.Label({ Text = if track == "Prime" then "PRIME" else "GRÁTIS", FontFace = Theme.Fonts.Title, TextSize = 10, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 12), Parent = box })
		if claimed then
			Theme.Label({ Text = "✓ RESGATADO", FontFace = Theme.Fonts.Title, TextSize = 11, TextColor3 = C.Good, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 14), Parent = box })
		elseif unlocked then
			local claim = Theme.Button("RESGATAR", "Primary", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(100, 28), TextSize = 12, Parent = box })
			claim.Activated:Connect(function()
				request("ClaimPass", { Tier = tierIndex, Track = track })
			end)
		end
	end
	for t = 1, Config.Pass.Tiers do
		local column = New("Frame", { LayoutOrder = t, Size = UDim2.fromOffset(120, 320), BackgroundTransparency = 1, Parent = track })
		Theme.Label({ Text = tostring(t), FontFace = Theme.Fonts.Display, TextSize = 16, TextColor3 = if t <= tier then C.Brand else C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 22), Parent = column })
		cell(column, t, "Free", 28)
		cell(column, t, "Prime", 166)
	end
	refs.Subtitle.Text = "Recompensas fixas. Sem caixa, sem sorte."
end

local RENDERERS = { Daily = renderDaily, Catalog = renderCatalog, Inventory = renderInventory, Pass = renderPass }

function ShopController.Render()
	if not isOpen then
		return
	end
	clearContent()
	RENDERERS[currentTab]()
	for tab, button in refs.Tabs do
		button.BackgroundColor3 = if tab == currentTab then C.Brand else C.PanelHi
		button.TextColor3 = if tab == currentTab then C.Ink else C.Text
	end
	local profile = ClientState.Profile
	refs.Coins.Text = `◆ {Format.Number(profile and profile.Coins or 0)}`
end

function ShopController.IsOpen(): boolean
	return isOpen
end

function ShopController.Open()
	if isOpen or ClientState.InMatch() then
		return
	end
	isOpen = true
	window.Visible = true
	local scale = window:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.95
	Theme.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	ClientState.SetUiOpen(true)
	ShopController.Render()
	Audio.Play2D("UiClick")
end

function ShopController.Close()
	if not isOpen then
		return
	end
	isOpen = false
	window.Visible = false
	clearContent()
	ClientState.SetUiOpen(false)
end

function ShopController.Toggle()
	if isOpen then
		ShopController.Close()
	else
		ShopController.Open()
	end
end

local function build()
	gui = New("ScreenGui", {
		Name = "OffscopeShop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = Theme.Panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.84),
		BackgroundTransparency = 0.03,
		Visible = false,
		Parent = gui,
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(1120, 700), Parent = window })
	New("UIScale", { Parent = window })

	Theme.Label({ Text = "ARSENAL", FontFace = Theme.Fonts.Display, TextSize = 30, Position = UDim2.fromOffset(28, 20), Size = UDim2.fromOffset(300, 34), Parent = window })
	refs.Subtitle = Theme.Label({ Text = "", FontFace = Theme.Fonts.Body, TextSize = 13, TextColor3 = C.TextDim, Position = UDim2.fromOffset(28, 56), Size = UDim2.fromOffset(600, 16), Parent = window })
	refs.Coins = Theme.Label({ Text = "◆ 0", FontFace = Theme.Fonts.Display, TextSize = 22, TextColor3 = C.Coin, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -76, 0, 26), Size = UDim2.fromOffset(240, 26), Parent = window })
	local close = Theme.Button("×", "Ghost", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(40, 40), TextSize = 26, Parent = window })
	close.Activated:Connect(ShopController.Close)

	local tabs = New("Frame", {
		Position = UDim2.fromOffset(28, 86),
		Size = UDim2.new(1, -56, 0, 38),
		BackgroundTransparency = 1,
		Parent = window,
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.Tabs = {}
	for index, spec in { { "Daily", "LOJA DO DIA" }, { "Catalog", "CATÁLOGO" }, { "Inventory", "INVENTÁRIO" }, { "Pass", "PASSE" } } do
		local button = Theme.Button(spec[2], "Ghost", { LayoutOrder = index, Size = UDim2.fromOffset(150, 36), TextSize = 13, Parent = tabs })
		button.Activated:Connect(function()
			currentTab = spec[1]
			ShopController.Render()
		end)
		refs.Tabs[spec[1]] = button
	end

	content = New("ScrollingFrame", {
		Position = UDim2.fromOffset(28, 136),
		Size = UDim2.new(1, -56, 1, -156),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
		Theme.Padding(4, 2),
	})
	refs.Grid = New("UIGridLayout", { CellSize = UDim2.fromOffset(196, 236), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	refs.List = New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
end

function ShopController.Init()
	build()
	ClientState.ProfileChanged:Connect(function()
		if isOpen then
			ShopController.Render()
		end
	end)
	ClientState.MatchChanged:Connect(function(match)
		if match then
			ShopController.Close()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenShop" then
			ShopController.Open()
		end
	end)
	-- contador da loja diária vivo
	RunService.Heartbeat:Connect(function()
		if isOpen and currentTab == "Daily" and refs.Subtitle then
			refs.Subtitle.Text = `A loja vira em {Format.Time(DailyShop.SecondsUntilReset() // 60)}`
		end
	end)
end

return ShopController
