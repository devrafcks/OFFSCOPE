--[[
	LOBBY — "Base OFFSCOPE": hangar militar a céu aberto no meio da serra.
	Praça circular com os portais de fila, monólito com o logo e vitrines da arma,
	heliponto com helicóptero, pátio de carga, loja (Arsenal), quadro de ranking
	e o RANGE de treino a leste (alvos a 25/50/100/150/200/260 studs).
	Fora dos muros: pinheiros e montanhas — tudo Detail (sem colisão/sombra/tiro).

	Planta (vista de cima, +X → leste/range, +Z → norte/monólito):
	  z +90  ── muro norte ── [bosque]   [vitrine] MONÓLITO [vitrine]   [jipe + sacos de areia]
	  z +12          ARSENAL (x −74..−50)      ( praça com 6 portais )       → RANGE (x 120..404)
	  z −20  RANKING (x −98)
	  z −60  [HELIPONTO]            [spawn / drop zone]            [pátio de contêineres]
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapKit = require(script.Parent.MapKit)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelKit = require(ReplicatedStorage.Shared.Models.ModelKit)
local SniperBuilder = require(ReplicatedStorage.Shared.Models.SniperBuilder)
local WrapPainter = require(ReplicatedStorage.Shared.Cosmetics.WrapPainter)

local Lobby = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad
local C = Color3.fromRGB

export type Extras = {
	Pads: { [string]: CFrame },
	Dummies: { CFrame },
	MovingDummies: { { From: CFrame, To: CFrame, Period: number } },
	Plates: { BasePart },
	Board: BasePart,
	Kiosk: BasePart,
	SpawnCFrames: { CFrame },
}

local PAD_COLORS = {
	Duel = C(0, 220, 255),
	RankedDuel = C(255, 176, 56),
	Duos = C(120, 255, 160),
	RankedDuos = C(255, 92, 92),
	Squads = C(170, 120, 255),
	FFA = C(255, 255, 255),
}

Lobby.PadColors = PAD_COLORS

local PLAZA_CENTER = V(0, 0, 14)
local STEEL = C(46, 49, 54)
local STEEL_LIGHT = C(74, 78, 84)
local CONCRETE = C(116, 118, 122)
local WALL = C(82, 86, 92)
local HAZARD = C(240, 184, 40)
local OLIVE = C(78, 88, 62)
local ORANGE = C(236, 122, 38)
local HELIPAD_CENTER = V(-82, 0, -62)

-- áreas onde os pilares da marquise não entram (heliponto e pilhas de contêineres)
local function columnBlocked(x: number, z: number): boolean
	if (V(x, 0, z) - HELIPAD_CENTER).Magnitude < 27 then
		return true
	end
	for _, box in { { 94, 120, -90, -56 }, { 96, 120, 68, 90 } } do
		if x >= box[1] and x <= box[2] and z >= box[3] and z <= box[4] then
			return true
		end
	end
	return false
end

local function cylY(kit, height: number, diameter: number, position: Vector3, options)
	local opts = table.clone(options)
	opts.Shape = Enum.PartType.Cylinder
	return kit:Block(V(height, diameter, diameter), CF(position) * CFrame.Angles(0, 0, rad(90)), opts)
end

local function cylDetailY(kit, height: number, diameter: number, position: Vector3, options)
	local opts = table.clone(options)
	opts.Detail = true
	return cylY(kit, height, diameter, position, opts)
end

-- cilindro de a até b (eixo X do Cylinder alinhado ao segmento)
local function beam(kit, a: Vector3, b: Vector3, diameter: number, options)
	local opts = table.clone(options)
	opts.Shape = opts.Shape or Enum.PartType.Cylinder
	local length = (b - a).Magnitude
	return kit:Detail(V(length, diameter, diameter), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0), opts)
end

-- ── chão, muros e estrutura do hangar ────────────────────────────────────────
local function ground(kit)
	kit:Box(V(-120, -4, -90), V(120, 0, 90), { Name = "Plaza", Material = Enum.Material.Concrete, Color = CONCRETE, Reflectance = 0.04 })
	-- juntas de dilatação em placas de 20 studs
	for x = -100, 100, 20 do
		kit:Detail(V(0.3, 0.03, 180), CF(x, 0.02, 0), { Material = Enum.Material.SmoothPlastic, Color = C(96, 98, 102) })
	end
	for z = -80, 80, 20 do
		kit:Detail(V(240, 0.03, 0.3), CF(0, 0.02, z), { Material = Enum.Material.SmoothPlastic, Color = C(96, 98, 102) })
	end
	-- terreno de fora (some sob os muros; dá chão para o bosque e as montanhas)
	kit:Detail(V(2400, 1, 2400), CF(140, -0.6, 0), { Name = "Outside", Material = Enum.Material.Grass, Color = C(84, 98, 62), Folder = "Scenery" })
end

local function walls(kit)
	local wall = { Material = Enum.Material.Concrete, Color = WALL }
	kit:Box(V(-121, 0, -91), V(-120, 18, 91), wall)
	kit:Box(V(-120, 0, 90), V(120, 18, 91), wall)
	kit:Box(V(-120, 0, -91), V(120, 18, -90), wall)
	kit:Box(V(120, 0, 30), V(121, 18, 91), wall)
	kit:Box(V(120, 0, -91), V(121, 18, -30), wall)
	-- rodapé de segurança (amarelo + preto) e faixa de janelas
	local folder = "Hangar"
	local function trim(size: Vector3, cf: CFrame)
		kit:Detail(size + V(0, -0.4, 0), cf * CF(0, 0.2, 0), { Material = Enum.Material.SmoothPlastic, Color = HAZARD, Folder = folder })
		kit:Detail(size + V(0, -1.4, 0) + V(0.02, 0, 0.02), cf * CF(0, 1.1, 0), { Material = Enum.Material.SmoothPlastic, Color = C(24, 24, 26), Folder = folder })
	end
	trim(V(240, 1.6, 0.3), CF(0, 0.8, 89.8))
	trim(V(240, 1.6, 0.3), CF(0, 0.8, -89.8))
	trim(V(0.3, 1.6, 180), CF(-119.8, 0.8, 0))
	for _, z in { -90.6, 90.6 } do
		kit:Detail(V(236, 5, 0.3), CF(0, 12.5, z), { Material = Enum.Material.Glass, Color = C(150, 180, 200), Transparency = 0.5, Reflectance = 0.25, Folder = folder })
	end
	kit:Detail(V(0.3, 5, 176), CF(-120.6, 12.5, 0), { Material = Enum.Material.Glass, Color = C(150, 180, 200), Transparency = 0.5, Reflectance = 0.25, Folder = folder })
end

-- pilares em I + marquise com treliça e luz por baixo nos muros norte, sul e oeste
local function canopy(kit)
	local folder = "Hangar"
	local depth = 14
	local function column(x: number, z: number)
		if columnBlocked(x, z) then
			return
		end
		kit:Block(V(1.6, 22, 0.5), CF(x, 11, z), { Name = "Column", Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
		kit:Detail(V(0.5, 22, 1.6), CF(x, 11, z), { Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
		kit:Detail(V(2.6, 0.6, 2.6), CF(x, 0.3, z), { Material = Enum.Material.Metal, Color = STEEL_LIGHT, Folder = folder })
	end
	-- norte e sul
	for _, side in { -1, 1 } do
		local wallZ = side * 90
		local edgeZ = side * (90 - depth)
		kit:Detail(V(240, 1, depth), CF(0, 22.5, side * (90 - depth / 2)), { Name = "Canopy", Material = Enum.Material.Metal, Color = C(58, 62, 68), Folder = folder })
		kit:Detail(V(240, 1.4, 0.8), CF(0, 21.6, edgeZ), { Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
		local strip = kit:Detail(V(232, 0.2, 0.8), CF(0, 21.9, side * (90 - depth / 2)), { Material = Enum.Material.Neon, Color = C(255, 236, 200), Folder = folder })
		strip.Transparency = 0.15
		for x = -110, 110, 20 do
			column(x, edgeZ)
			-- treliça diagonal do pilar até o muro
			if columnBlocked(x, edgeZ) then
				continue
			end
			beam(kit, V(x, 14, edgeZ), V(x, 22, wallZ), 0.5, { Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
		end
	end
	-- oeste (sem cobrir a loja e o ranking por inteiro)
	kit:Detail(V(depth, 1, 152), CF(-120 + depth / 2, 22.5, 0), { Name = "Canopy", Material = Enum.Material.Metal, Color = C(58, 62, 68), Folder = folder })
	kit:Detail(V(0.8, 1.4, 152), CF(-120 + depth, 21.6, 0), { Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
	for z = -60, 60, 30 do
		column(-120 + depth, z)
	end
	-- luzes reais só em poucos pontos (custo)
	for _, x in { -60, 60 } do
		for _, side in { -1, 1 } do
			local holder = kit:Detail(V(6, 0.3, 2), CF(x, 21.7, side * (90 - depth / 2)), { Material = Enum.Material.Neon, Color = C(255, 236, 200), Folder = folder })
			kit:Light(holder, { Kind = "Surface", Face = Enum.NormalId.Bottom, Range = 22, Angle = 120, Brightness = 1.2 })
		end
	end
	-- banners pendurados na borda da marquise
	local bannerColors = { C(20, 21, 24), ORANGE, C(20, 21, 24) }
	for i, x in { -80, 0, 80 } do
		for _, side in { -1, 1 } do
			local z = side * (90 - depth) - side * 0.6
			kit:Detail(V(8, 12, 0.2), CF(x, 15, z), { Material = Enum.Material.Fabric, Color = bannerColors[i], Folder = folder })
			kit:Detail(V(8, 1.2, 0.25), CF(x, 10, z), { Material = Enum.Material.SmoothPlastic, Color = if i == 2 then C(20, 21, 24) else ORANGE, Folder = folder })
			kit:Detail(V(0.3, 0.3, 0.3), CF(x, 21.1, z), { Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
		end
	end
end

-- ── praça central ────────────────────────────────────────────────────────────
local function plaza(kit)
	local folder = "Plaza"
	local c = PLAZA_CENTER
	cylDetailY(kit, 0.12, 100, c + V(0, 0.04, 0), { Material = Enum.Material.Metal, Color = STEEL_LIGHT, Folder = folder })
	cylDetailY(kit, 0.14, 97, c + V(0, 0.06, 0), { Material = Enum.Material.Slate, Color = C(52, 55, 62), Folder = folder })
	local ring = cylDetailY(kit, 0.16, 64, c + V(0, 0.08, 0), { Material = Enum.Material.Neon, Color = ORANGE, Folder = folder })
	ring.Transparency = 0.6
	cylDetailY(kit, 0.18, 62, c + V(0, 0.09, 0), { Material = Enum.Material.Slate, Color = C(44, 47, 54), Folder = folder })
	-- emblema de mira no centro
	cylDetailY(kit, 0.2, 14, c + V(0, 0.1, 0), { Material = Enum.Material.SmoothPlastic, Color = C(230, 230, 226), Folder = folder })
	cylDetailY(kit, 0.22, 12, c + V(0, 0.11, 0), { Material = Enum.Material.Slate, Color = C(44, 47, 54), Folder = folder })
	cylDetailY(kit, 0.24, 2, c + V(0, 0.12, 0), { Material = Enum.Material.Neon, Color = ORANGE, Folder = folder })
	for _, angle in { 0, 90 } do
		kit:Detail(V(22, 0.22, 0.5), CF(c + V(0, 0.11, 0)) * CFrame.Angles(0, rad(angle), 0), { Material = Enum.Material.SmoothPlastic, Color = C(230, 230, 226), Folder = folder })
	end
	-- passarela do spawn até a praça
	kit:Detail(V(14, 0.1, 30), CF(0, 0.05, -49), { Material = Enum.Material.Slate, Color = C(60, 63, 70), Folder = folder })
	for _, x in { -7.2, 7.2 } do
		kit:Detail(V(0.5, 0.12, 30), CF(x, 0.06, -49), { Material = Enum.Material.SmoothPlastic, Color = HAZARD, Folder = folder })
	end
	for z = -60, -40, 5 do
		kit:Detail(V(5, 0.12, 0.8), CF(-2, 0.07, z) * CFrame.Angles(0, rad(-35), 0), { Material = Enum.Material.SmoothPlastic, Color = C(200, 200, 196), Folder = folder })
		kit:Detail(V(5, 0.12, 0.8), CF(2, 0.07, z) * CFrame.Angles(0, rad(35), 0), { Material = Enum.Material.SmoothPlastic, Color = C(200, 200, 196), Folder = folder })
	end
end

local function monolith(kit)
	kit:Box(V(-30, 0, 66), V(30, 2, 74), { Material = Enum.Material.Concrete, Color = C(40, 42, 46) })
	kit:Box(V(-28, 2, 70), V(28, 20, 72), { Material = Enum.Material.Slate, Color = C(26, 28, 32) })
	for _, x in { -29, 29 } do
		kit:Box(V(x - 1, 2, 69.5), V(x + 1, 21, 72.5), { Material = Enum.Material.Metal, Color = STEEL })
		local glow = kit:Detail(V(0.3, 17, 0.3), CF(x + (if x < 0 then 1.1 else -1.1), 11, 69.4), { Material = Enum.Material.Neon, Color = ORANGE })
		glow.Transparency = 0.1
	end
	kit:Sign(V(52, 10, 0.4), CF(0, 13, 69.7), Config.Game.Name, {
		Background = C(14, 15, 18),
		Color = C(255, 255, 255),
		Glow = true,
		LightRange = 26,
		Font = Enum.Font.GothamBlack,
		PixelsPerStud = 20,
	})
	kit:Sign(V(40, 2.6, 0.4), CF(0, 5.6, 69.7), Config.Game.Tagline, {
		Background = C(14, 15, 18),
		Color = C(255, 196, 60),
		Font = Enum.Font.GothamMedium,
	})
end

-- vitrines com o Vanta-7 pintado (mostra o que a loja vende, sem vender nada aqui)
local function displays(kit)
	local folder = "Displays"
	for _, entry in { { X = -46, Wrap = "wrap_aurora", Label = "AURORA AUSTRAL" }, { X = 46, Wrap = "wrap_magma", Label = "MAGMA" } } do
		local base = V(entry.X, 0, 66)
		kit:Block(V(10, 3, 6), CF(base + V(0, 1.5, 0)), { Name = "Pedestal", Material = Enum.Material.Slate, Color = C(30, 32, 36), Folder = folder })
		kit:Detail(V(10.2, 0.3, 6.2), CF(base + V(0, 3.05, 0)), { Material = Enum.Material.Metal, Color = STEEL_LIGHT, Folder = folder })
		local trimLight = kit:Detail(V(10.3, 0.2, 6.3), CF(base + V(0, 0.3, 0)), { Material = Enum.Material.Neon, Color = ORANGE, Folder = folder })
		trimLight.Transparency = 0.3
		kit:Detail(V(9.6, 4.6, 5.6), CF(base + V(0, 5.5, 0)), { Name = "Glass", Material = Enum.Material.Glass, Color = C(190, 214, 230), Transparency = 0.82, Reflectance = 0.15, Folder = folder })
		kit:Detail(V(9.8, 0.25, 5.8), CF(base + V(0, 7.9, 0)), { Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
		local built = SniperBuilder.Build("Lite")
		WrapPainter.Apply(built.Model, entry.Wrap, { Textures = true })
		ModelKit.Finalize(built.Model, built.Root, { Anchored = true })
		built.Model:ScaleTo(1.25)
		built.Model:PivotTo(kit.Origin * CF(base + V(0, 5.2, 0)) * CFrame.Angles(0, rad(90), 0) * CFrame.Angles(rad(8), 0, rad(-6)))
		for _, part in built.Model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		built.Model.Parent = kit:Folder(folder)
		kit:Sign(V(8, 1.2, 0.2), CF(base + V(0, 1.6, -3.1)), entry.Label, {
			Background = C(14, 15, 18),
			Color = C(255, 196, 60),
			Font = Enum.Font.GothamBold,
		})
		local lamp = kit:Detail(V(1, 0.3, 1), CF(base + V(0, 7.7, 0)), { Material = Enum.Material.Neon, Color = C(255, 244, 230), Folder = folder })
		kit:Light(lamp, { Kind = "Spot", Face = Enum.NormalId.Bottom, Angle = 70, Range = 10, Brightness = 3 })
	end
end

-- ── portais de fila ──────────────────────────────────────────────────────────
local function pads(kit): { [string]: CFrame }
	local result = {}
	local center = V(0, 0, 12)
	local count = #Config.ModeOrder
	for i, modeId in Config.ModeOrder do
		local t = (i - 1) / (count - 1)
		local angle = rad(-70 + 140 * t)
		local position = center + V(math.sin(angle) * 40, 0, math.cos(angle) * 26)
		local color = PAD_COLORS[modeId] or Color3.new(1, 1, 1)
		local cf = CF(position)
		kit:Block(V(0.6, 13, 13), cf * CF(0, 0.3, 0) * CFrame.Angles(0, 0, rad(90)), {
			Name = "Pad",
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
			Color = C(36, 38, 42),
		})
		local ring = kit:Detail(V(0.65, 12, 12), cf * CF(0, 0.32, 0) * CFrame.Angles(0, 0, rad(90)), {
			Name = "PadRing",
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Color = color,
		})
		ring.Transparency = 0.55
		ring:SetAttribute("Mode", modeId)
		kit:Detail(V(0.7, 9, 9), cf * CF(0, 0.34, 0) * CFrame.Angles(0, 0, rad(90)), {
			Name = "PadCore",
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
			Color = C(28, 30, 34),
		})
		kit:Light(ring, { Kind = "Point", Color = color, Range = 12, Brightness = 1 })

		-- portal: dois pilares + viga com neon, de frente para o centro da praça
		local facing = CFrame.lookAt(position, V(PLAZA_CENTER.X, 0, PLAZA_CENTER.Z - 40))
		local folder = "Gates"
		for _, side in { -1, 1 } do
			local post = facing * CF(side * 7.2, 5.5, 2)
			kit:Block(V(1.2, 11, 1.2), post, { Name = "GatePost", Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
			local strip = kit:Detail(V(0.25, 9, 0.25), post * CF(-side * 0.62, -0.5, -0.62), { Material = Enum.Material.Neon, Color = color, Folder = folder })
			strip.Transparency = 0.2
			kit:Detail(V(2, 0.6, 2), facing * CF(side * 7.2, 0.3, 2), { Material = Enum.Material.Metal, Color = STEEL_LIGHT, Folder = folder })
		end
		kit:Detail(V(15.6, 1.4, 1.4), facing * CF(0, 11.4, 2), { Material = Enum.Material.Metal, Color = STEEL, Folder = folder })
		local top = kit:Detail(V(14, 0.4, 0.3), facing * CF(0, 10.6, 1.25), { Material = Enum.Material.Neon, Color = color, Folder = folder })
		top.Transparency = 0.1
		result[modeId] = kit.Origin * cf
	end
	return result
end

-- ── heliponto ────────────────────────────────────────────────────────────────
local function helicopter(kit, at: CFrame)
	-- modelado em unidades "de projeto" e escalado: 1,8× deixa o helicóptero maior que um contêiner
	local k = 1.8
	local function S(x: number, y: number, z: number): Vector3
		return V(x * k, y * k, z * k)
	end
	local function P(x: number, y: number, z: number): CFrame
		return CF(x * k, y * k, z * k)
	end
	local folder = "Helipad"
	local body = { Material = Enum.Material.Metal, Color = OLIVE, Folder = folder }
	local dark = { Material = Enum.Material.Metal, Color = C(34, 36, 38), Folder = folder }
	local function block(size: Vector3, cf: CFrame, opts)
		return kit:Block(size, at * cf, opts)
	end
	local function detail(size: Vector3, cf: CFrame, opts)
		return kit:Detail(size, at * cf, opts)
	end
	-- fuselagem: cilindro + duas esferas (nariz e traseira)
	block(S(9, 5.6, 5.6), P(0, 4.4, 0) * CFrame.Angles(0, rad(90), 0), { Name = "Fuselage", Shape = Enum.PartType.Cylinder, Material = body.Material, Color = body.Color, Folder = folder })
	block(S(5.6, 5.6, 5.6), P(0, 4.4, -4.5), { Name = "Nose", Shape = Enum.PartType.Ball, Material = body.Material, Color = body.Color, Folder = folder })
	block(S(5.2, 5.2, 5.2), P(0, 4.5, 4.4), { Name = "Rear", Shape = Enum.PartType.Ball, Material = body.Material, Color = body.Color, Folder = folder })
	detail(S(4.9, 4.9, 4.9), P(0, 5.1, -5.6), { Material = Enum.Material.Glass, Color = C(30, 44, 56), Transparency = 0.15, Reflectance = 0.3, Shape = Enum.PartType.Ball, Folder = folder })
	detail(S(5.7, 0.5, 9.2), P(0, 3.2, 0), { Material = Enum.Material.Metal, Color = C(34, 36, 38), Folder = folder })
	detail(S(5.7, 0.6, 3), P(0, 4.6, 0.6), { Material = Enum.Material.SmoothPlastic, Color = ORANGE, Folder = folder })
	-- motor e mastro
	detail(S(3, 1.6, 5), P(0, 7.4, 1), dark)
	detail(S(0.6, 1.6, 0.6), P(0, 8.9, 0), dark)
	detail(S(1.6, 0.5, 1.6), P(0, 9.8, 0), dark)
	for i = 0, 3 do
		detail(S(0.9, 0.12, 15), P(0, 9.95, 0) * CFrame.Angles(0, rad(i * 45 + 12), 0), dark)
	end
	-- cauda
	beam(kit, (at * P(0, 5.6, 5)).Position, (at * P(0, 6.6, 16)).Position, 1.5 * k, { Material = Enum.Material.Metal, Color = OLIVE, Folder = folder })
	detail(S(0.4, 4, 2.4), P(0, 8, 16) * CFrame.Angles(rad(-15), 0, 0), body)
	detail(S(4, 0.3, 1.4), P(0, 6.5, 15.4), body)
	detail(S(0.15, 3.4, 0.4), P(0.4, 8.2, 16.4), dark)
	detail(S(0.15, 0.4, 3.4), P(0.4, 8.2, 16.4), dark)
	-- esquis
	for _, x in { -2.8, 2.8 } do
		beam(kit, (at * P(x, 0.35, -5.6)).Position, (at * P(x, 0.35, 5.6)).Position, 0.45 * k, dark)
		beam(kit, (at * P(x, 0.35, -5.6)).Position, (at * P(x, 0.9, -6.6)).Position, 0.45 * k, dark)
		for _, z in { -2.6, 2.6 } do
			beam(kit, (at * P(x, 0.4, z)).Position, (at * P(x * 0.6, 2.4, z)).Position, 0.35 * k, dark)
		end
	end
end

local function helipad(kit)
	local folder = "Helipad"
	local center = HELIPAD_CENTER
	cylDetailY(kit, 0.12, 46, center + V(0, 0.05, 0), { Material = Enum.Material.SmoothPlastic, Color = C(200, 200, 196), Folder = folder })
	cylDetailY(kit, 0.14, 44, center + V(0, 0.06, 0), { Material = Enum.Material.Asphalt, Color = C(46, 48, 52), Folder = folder })
	-- "H"
	for _, x in { -4, 4 } do
		kit:Detail(V(2, 0.16, 16), CF(center + V(x * 1.3, 0.08, 0)), { Material = Enum.Material.SmoothPlastic, Color = C(230, 230, 226), Folder = folder })
	end
	kit:Detail(V(10.4, 0.16, 2), CF(center + V(0, 0.08, 0)), { Material = Enum.Material.SmoothPlastic, Color = C(230, 230, 226), Folder = folder })
	for i = 0, 7 do
		local a = rad(i * 45)
		local light = kit:Detail(V(0.8, 0.3, 0.8), CF(center + V(math.cos(a) * 22.4, 0.15, math.sin(a) * 22.4)), { Material = Enum.Material.Neon, Color = C(120, 255, 140), Folder = folder })
		light.Transparency = 0.1
	end
	helicopter(kit, CF(center) * CFrame.Angles(0, rad(-55), 0))
end

-- ── pátio de carga e props militares ────────────────────────────────────────
local function sandbags(kit, center: Vector3, radius: number, fromDeg: number, toDeg: number)
	local folder = "Props"
	local step = 2.6 / radius
	for layer = 0, 2 do
		local offset = if layer % 2 == 0 then 0 else step / 2
		local a = rad(fromDeg) + offset
		while a <= rad(toDeg) do
			local pos = center + V(math.cos(a) * radius, 0.5 + layer * 0.95, math.sin(a) * radius)
			kit:Block(V(2.7, 1, 1.4), CF(pos) * CFrame.Angles(0, -a + rad(90), 0) * CFrame.Angles(0, 0, rad((layer * 37 + math.deg(a)) % 5 - 2)), {
				Name = "Sandbag",
				Material = Enum.Material.Fabric,
				Color = C(162, 146, 108):Lerp(C(138, 124, 92), (math.deg(a) * 13 % 10) / 10),
				Folder = folder,
				Shadow = false,
			})
			a += step
		end
	end
end

local function ammoCrate(kit, cf: CFrame)
	local folder = "Props"
	kit:Block(V(4, 1.8, 2.2), cf * CF(0, 0.9, 0), { Name = "AmmoCrate", Material = Enum.Material.Metal, Color = OLIVE, Folder = folder })
	kit:Detail(V(4.1, 0.25, 2.3), cf * CF(0, 1.5, 0), { Material = Enum.Material.Metal, Color = C(60, 68, 48), Folder = folder })
	kit:Detail(V(1.2, 0.4, 0.1), cf * CF(0, 1, -1.15), { Material = Enum.Material.SmoothPlastic, Color = HAZARD, Folder = folder })
end

local function cargoYard(kit)
	-- sudeste: contêineres empilhados (cobrem o canto e quebram a linha do muro)
	kit:Container(CF(108, 4.25, -70), C(56, 96, 64))
	kit:Container(CF(108, 12.75, -70) * CFrame.Angles(0, rad(4), 0), C(196, 110, 36))
	kit:Container(CF(98, 4.25, -76) * CFrame.Angles(0, rad(90), 0), C(40, 78, 120))
	kit:Container(CF(78, 4.25, -82) * CFrame.Angles(0, rad(90), 0), C(110, 112, 116))
	for i, cf in { CF(88, 0, -62), CF(92, 0, -60), CF(90, 4, -61), CF(70, 0, -70) } do
		kit:Crate(cf * CFrame.Angles(0, rad(i * 17), 0), 4)
	end
	for _, pos in { V(64, 0, -82), V(67, 0, -84), V(64, 0, -86) } do
		kit:Barrel(pos, C(40, 70, 120))
	end
	kit:Barrel(V(61, 0, -84), ORANGE)
	ammoCrate(kit, CF(80, 0, -58) * CFrame.Angles(0, rad(20), 0))
	ammoCrate(kit, CF(80, 1.8, -58) * CFrame.Angles(0, rad(28), 0))
	-- nordeste: jipe + barricada de sacos de areia + caixas de munição
	kit:Car(CF(96, 0, 66) * CFrame.Angles(0, rad(-115), 0), OLIVE)
	sandbags(kit, V(80, 0, 52), 9, 160, 290)
	ammoCrate(kit, CF(74, 0, 74) * CFrame.Angles(0, rad(-10), 0))
	ammoCrate(kit, CF(70, 0, 78) * CFrame.Angles(0, rad(15), 0))
	kit:Container(CF(110, 4.25, 78) * CFrame.Angles(0, rad(90), 0), C(142, 52, 38))
	-- sudoeste do spawn: caixotes ao lado do heliponto
	for i, cf in { CF(-56, 0, -80), CF(-52, 0, -82), CF(-54, 4, -81) } do
		kit:Crate(cf * CFrame.Angles(0, rad(i * 23), 0), 4)
	end
	for _, pos in { V(-60, 0, -74), V(-63, 0, -76) } do
		kit:Barrel(pos, C(150, 34, 44))
	end
end

-- canteiros com pinheiros e bancos (noroeste) + bancos perto do spawn
local function garden(kit)
	for i, pos in { V(-100, 0, 66), V(-82, 0, 76), V(-104, 0, 44), V(-64, 0, 80) } do
		kit:Box(pos - V(5, 0, 5), pos + V(5, 2, 5), { Material = Enum.Material.Concrete, Color = C(96, 98, 102), Folder = "Garden" })
		kit:Detail(V(9.4, 0.3, 9.4), CF(pos + V(0, 2.05, 0)), { Material = Enum.Material.Ground, Color = C(70, 56, 42), Folder = "Garden" })
		kit:Pine(pos + V(0, 2, 0), 18 + i * 2)
	end
	for _, spec in { { V(-88, 0, 56), 0 }, { V(-40, 0, -64), 0 }, { V(40, 0, -64), 0 } } do
		local pos, angle = spec[1], spec[2]
		local cf = CF(pos) * CFrame.Angles(0, rad(angle), 0)
		kit:Block(V(10, 0.5, 3), cf * CF(0, 1.6, 0), { Name = "Bench", Material = Enum.Material.WoodPlanks, Color = C(124, 92, 64), Folder = "Garden" })
		kit:Detail(V(10, 2, 0.4), cf * CF(0, 2.8, 1.4) * CFrame.Angles(rad(-10), 0, 0), { Material = Enum.Material.WoodPlanks, Color = C(124, 92, 64), Folder = "Garden" })
		for _, x in { -4.2, 4.2 } do
			kit:Detail(V(0.4, 1.6, 2.6), cf * CF(x, 0.8, 0), { Material = Enum.Material.Metal, Color = STEEL, Folder = "Garden" })
		end
	end
end

-- torres de holofote nos quatro cantos (treliça + cabeça; uma luz cada)
local function floodlights(kit)
	for _, spec in { { V(-104, 0, -76), V(0, 0, 0) }, { V(-104, 0, 76), V(0, 0, 0) }, { V(104, 0, 44), V(0, 0, 0) }, { V(-30, 0, -80), V(0, 0, 0) } } do
		local base, target = spec[1], spec[2]
		kit:Block(V(2, 30, 2), CF(base + V(0, 15, 0)), { Name = "LightTower", Truss = true, Material = Enum.Material.Metal, Color = STEEL_LIGHT, Folder = "Lights" })
		local headCF = CFrame.lookAt(base + V(0, 31, 0), target + V(0, 0, 0))
		kit:Detail(V(5, 3, 1.2), headCF, { Material = Enum.Material.Metal, Color = STEEL, Folder = "Lights" })
		local lens = kit:Detail(V(4.4, 2.4, 0.3), headCF * CF(0, 0, -0.7), { Material = Enum.Material.Neon, Color = C(255, 246, 226), Folder = "Lights" })
		kit:Light(lens, { Kind = "Spot", Face = Enum.NormalId.Front, Angle = 50, Range = 60, Brightness = 1.4 })
	end
end

-- ── cenário de fora: bosque e serra ─────────────────────────────────────────
local function scenery(kit)
	local folder = "Scenery"
	local rng = Random.new(47)
	local function pine(pos: Vector3, height: number)
		kit:Detail(V(height * 0.5, height * 0.06, height * 0.06), CF(pos + V(0, height * 0.25, 0)) * CFrame.Angles(0, 0, rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Wood,
			Color = C(78, 58, 42),
			Folder = folder,
		})
		local green = C(36, 58, 40):Lerp(C(58, 78, 48), rng:NextNumber())
		for layer = 0, 4 do
			local t = layer / 4
			local radius = (1 - t * 0.8) * height * 0.23
			kit:Detail(V(height * 0.17, radius * 2, radius * 2), CF(pos + V(0, height * (0.3 + t * 0.6), 0)) * CFrame.Angles(0, rng:NextNumber() * 6, rad(90)), {
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.LeafyGrass,
				Color = green,
				Folder = folder,
			})
		end
	end
	-- faixas de bosque ao redor do hangar (fora das barreiras)
	local function band(minV: Vector3, maxV: Vector3, count: number)
		for _ = 1, count do
			local pos = V(rng:NextNumber(minV.X, maxV.X), 0, rng:NextNumber(minV.Z, maxV.Z))
			pine(pos, rng:NextNumber(30, 54))
		end
	end
	band(V(-200, 0, 104), V(420, 0, 190), 46)
	band(V(-200, 0, -190), V(420, 0, -104), 46)
	band(V(-230, 0, -100), V(-136, 0, 100), 22)
	-- serra ao fundo: cada pico são duas cunhas costas-com-costas (cumeeira) + capa de neve
	local function peak(base: Vector3, width: number, height: number, depth: number, yaw: number, color: Color3)
		local cf = CF(base) * CFrame.Angles(0, yaw, 0)
		for _, side in { -1, 1 } do
			local half = cf * CF(0, height / 2, side * depth / 4) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
			kit:Detail(V(width, height, depth / 2), half, { Wedge = true, Material = Enum.Material.Rock, Color = color, Folder = folder })
			local cap = height * 0.28
			kit:Detail(V(width * 0.7, cap, depth * 0.28 / 2), cf * CF(0, height - cap / 2, side * depth * 0.28 / 4) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0), {
				Wedge = true,
				Material = Enum.Material.Snow,
				Color = C(234, 238, 244),
				Folder = folder,
			})
		end
	end
	for i = 1, 30 do
		local angle = (i / 30) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local distance = rng:NextNumber(700, 900)
		local center = V(140 + math.cos(angle) * distance, -2, math.sin(angle) * distance)
		local height = rng:NextNumber(120, 240)
		local color = C(84, 94, 104):Lerp(C(116, 124, 132), rng:NextNumber())
		-- cumeeira perpendicular à linha de visão + um pico menor ao lado
		local yaw = -angle + math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		peak(center, height * 1.1, height, height * 1.6, yaw + math.pi / 2, color)
		peak(center + V(rng:NextNumber(-90, 90), -2, rng:NextNumber(-90, 90)), height * 0.8, height * 0.62, height, yaw + math.pi / 2 + 0.5, color:Lerp(C(70, 80, 90), 0.3))
	end
end

-- ── range de treino (inalterado na jogabilidade) ─────────────────────────────
local function range(kit)
	local folder = "Range"
	-- corredor do range (x 120..400, z −30..30)
	kit:Box(V(120, -4, -30), V(404, 0, 30), { Material = Enum.Material.Concrete, Color = C(110, 106, 98), Folder = folder })
	kit:Box(V(120, 0, -31), V(404, 16, -30), { Material = Enum.Material.Concrete, Color = C(80, 80, 84), Folder = folder })
	kit:Box(V(120, 0, 30), V(404, 16, 31), { Material = Enum.Material.Concrete, Color = C(80, 80, 84), Folder = folder })
	kit:Box(V(400, 0, -31), V(404, 30, 31), { Material = Enum.Material.Ground, Color = C(110, 86, 60), Folder = folder }) -- barreira de terra
	-- linha de tiro com cabines
	kit:Box(V(126, 0, -30), V(127, 4, 30), { Material = Enum.Material.WoodPlanks, Color = C(130, 98, 66), Folder = folder })
	for z = -30, 30, 12 do
		kit:Box(V(118, 0, z - 0.3), V(127, 8, z + 0.3), { Material = Enum.Material.Concrete, Color = C(90, 90, 94), Folder = folder })
	end
	kit:Detail(V(0.2, 0.04, 60), CF(127.5, 0.02, 0), { Material = Enum.Material.SmoothPlastic, Color = C(240, 60, 40), Folder = folder })
	-- marcadores de distância
	for _, d in { 25, 50, 100, 150, 200, 260 } do
		local x = 127 + d
		kit:Detail(V(0.4, 0.05, 60), CF(x, 0.03, 0), { Material = Enum.Material.SmoothPlastic, Color = C(200, 200, 196), Folder = folder })
		kit:Sign(V(8, 3, 0.4), CF(x, 13, -25.5) * CFrame.Angles(0, rad(90), 0), `{d}`, {
			Background = C(20, 20, 24),
			Color = C(255, 196, 60),
			Face = Enum.NormalId.Front,
		})
	end
	kit:Sign(V(30, 4, 0.4), CF(140, 12, 29.5), "RANGE · TREINO DE NO-SCOPE", {
		Background = C(20, 20, 24),
		Color = C(255, 255, 255),
		Glow = true,
	})
	-- sacos de areia no fundo e luzes do range (só uma com sombra)
	for i, x in { 150, 230, 320 } do
		local lamp = kit:Detail(V(4, 0.4, 40), CF(x, 15.6, 0), { Material = Enum.Material.Neon, Color = C(230, 240, 255), Folder = folder })
		kit:Light(lamp, { Kind = "Surface", Face = Enum.NormalId.Bottom, Range = 22, Angle = 120, Brightness = 1.6, Shadows = i == 1 })
	end
	for x = 140, 390, 25 do
		kit:Detail(V(1, 1.4, 62), CF(x, 16.6, 0), { Material = Enum.Material.Metal, Color = C(60, 62, 66), Folder = folder })
	end
end

local function rangeTargets(kit): ({ CFrame }, { any }, { BasePart })
	local dummies = {}
	local moving = {}
	local plates = {}
	local lanes = { -24, -12, 0, 12, 24 }
	for i, d in { 25, 50, 100, 150, 200, 260 } do
		local x = 127 + d + 2
		local z = lanes[(i - 1) % #lanes + 1]
		table.insert(dummies, kit.Origin * CFrame.lookAt(V(x, 3, z), V(120, 3, z)))
		-- trilho com dummy em movimento (a cada duas distâncias)
		if i % 2 == 0 then
			local zr = lanes[(i + 1) % #lanes + 1]
			kit:Detail(V(1, 0.2, 24), CF(x + 6, 0.1, zr), { Material = Enum.Material.Metal, Color = C(60, 60, 64), Folder = "Range" })
			table.insert(moving, {
				From = kit.Origin * CFrame.lookAt(V(x + 6, 3, zr - 10), V(120, 3, zr - 10)),
				To = kit.Origin * CFrame.lookAt(V(x + 6, 3, zr + 10), V(120, 3, zr + 10)),
				Period = 2.4 + i * 0.4,
			})
		end
		-- placa de aço (gongo) — feedback sonoro
		local plate = kit:Block(V(0.4, 2.6, 2.6), CF(x + 1, 6.4, z + 5), {
			Name = "SteelPlate",
			Material = Enum.Material.Metal,
			Color = C(230, 230, 226),
			Folder = "Range",
		})
		plate:SetAttribute("Distance", d)
		kit:Detail(V(0.3, 5, 0.3), CF(x + 1, 2.5, z + 5), { Material = Enum.Material.Metal, Color = C(50, 50, 54), Folder = "Range" })
		table.insert(plates, plate)
	end
	return dummies, moving, plates
end

-- ── loja (Arsenal) e ranking ────────────────────────────────────────────────
local function kiosk(kit): BasePart
	kit:Box(V(-74, 0, 22), V(-50, 1, 42), { Material = Enum.Material.Marble, Color = C(220, 220, 216) })
	local counter = kit:Box(V(-70, 1, 26), V(-54, 4.2, 30), { Name = "ShopCounter", Material = Enum.Material.Metal, Color = C(26, 28, 32) })
	kit:Detail(V(16.2, 0.3, 4.2), CF(-62, 4.35, 28), { Material = Enum.Material.Wood, Color = C(120, 86, 58) })
	local counterGlow = kit:Detail(V(16.2, 0.2, 0.2), CF(-62, 1.3, 25.9), { Material = Enum.Material.Neon, Color = C(255, 176, 56) })
	counterGlow.Transparency = 0.2
	kit:Box(V(-74, 1, 40), V(-50, 14, 42), { Material = Enum.Material.Slate, Color = C(30, 32, 36) })
	kit:Box(V(-75, 14, 20), V(-49, 15, 42), { Material = Enum.Material.Metal, Color = C(40, 42, 46) })
	-- toldo listrado na frente
	for i = 0, 5 do
		kit:Detail(V(26 / 6, 0.2, 4), CF(-75 + 26 / 12 + i * 26 / 6, 14.3, 19) * CFrame.Angles(rad(-18), 0, 0), {
			Material = Enum.Material.Fabric,
			Color = if i % 2 == 0 then C(255, 176, 56) else C(24, 25, 28),
		})
	end
	kit:Sign(V(18, 3.4, 0.4), CF(-62, 11, 39.7), "ARSENAL · LOJA", {
		Background = C(14, 15, 18),
		Color = C(255, 176, 56),
		Glow = true,
	})
	for _, x in { -74.5, -49.5 } do
		kit:Box(V(x - 0.5, 1, 20), V(x + 0.5, 14, 21), { Material = Enum.Material.Metal, Color = C(40, 42, 46) })
	end
	-- rack de armas na parede do fundo
	for i, x in { -68, -64, -60, -56 } do
		local built = SniperBuilder.Build("Lite")
		WrapPainter.Apply(built.Model, ({ "wrap_areia", "wrap_carbono", "wrap_hex", "wrap_pulso" })[i], { Textures = true })
		ModelKit.Finalize(built.Model, built.Root, { Anchored = true })
		built.Model:ScaleTo(0.9)
		built.Model:PivotTo(kit.Origin * CF(x, 6, 39.4) * CFrame.Angles(0, 0, rad(90)) * CFrame.Angles(0, rad(90), 0))
		for _, part in built.Model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		built.Model.Parent = kit:Folder("Displays")
	end
	kit:Detail(V(18, 0.4, 0.8), CF(-62, 2.4, 39.4), { Material = Enum.Material.Metal, Color = STEEL })
	return counter
end

local function board(kit): BasePart
	kit:Box(V(-100, 0, -40), V(-96, 2, 0), { Material = Enum.Material.Concrete, Color = C(40, 42, 46) })
	local panel = kit:Block(V(1, 22, 36), CF(-98, 13, -20), { Name = "Leaderboard", Material = Enum.Material.SmoothPlastic, Color = C(14, 15, 18) })
	kit:Detail(V(1.4, 23, 0.6), CF(-98, 13, -38.3), { Material = Enum.Material.Metal, Color = STEEL })
	kit:Detail(V(1.4, 23, 0.6), CF(-98, 13, -1.7), { Material = Enum.Material.Metal, Color = STEEL })
	local top = kit:Detail(V(1.2, 0.4, 36), CF(-98, 24.3, -20), { Material = Enum.Material.Neon, Color = C(255, 176, 56) })
	top.Transparency = 0.2
	return panel
end

-- drop zone do spawn
local function dropZone(kit)
	kit:Detail(V(34, 0.1, 22), CF(0, 0.06, -46), { Material = Enum.Material.Slate, Color = C(50, 53, 60), Folder = "Plaza" })
	for _, x in { -17, 17 } do
		kit:Detail(V(0.6, 0.12, 22), CF(x, 0.07, -46), { Material = Enum.Material.SmoothPlastic, Color = HAZARD, Folder = "Plaza" })
	end
	for _, z in { -57, -35 } do
		kit:Detail(V(34, 0.12, 0.6), CF(0, 0.07, z), { Material = Enum.Material.SmoothPlastic, Color = HAZARD, Folder = "Plaza" })
	end
end

function Lobby.Build(origin: CFrame): (MapKit.BuiltMap, Extras)
	local kit = MapKit.new("Lobby", origin, 1)
	ground(kit)
	walls(kit)
	canopy(kit)
	plaza(kit)
	dropZone(kit)
	monolith(kit)
	displays(kit)
	local padCFrames = pads(kit)
	helipad(kit)
	cargoYard(kit)
	garden(kit)
	floodlights(kit)
	scenery(kit)
	range(kit)
	local dummies, moving, plates = rangeTargets(kit)
	local counter = kiosk(kit)
	local leaderboard = board(kit)
	kit:Barrier(V(-124, -4, -94), V(408, 60, -91))
	kit:Barrier(V(-124, -4, 91), V(408, 60, 94))
	kit:Barrier(V(-124, 59, -94), V(408, 62, 94))

	local spawnCFrames = {}
	for _, x in { -12, -4, 4, 12 } do
		for _, z in { -50, -42 } do
			table.insert(spawnCFrames, origin * CFrame.lookAt(V(x, 3, z), V(x, 3, z + 10)))
		end
	end
	local built = kit:Finish(-40)
	return built, {
		Pads = padCFrames,
		Dummies = dummies,
		MovingDummies = moving,
		Plates = plates,
		Board = leaderboard,
		Kiosk = counter,
		SpawnCFrames = spawnCFrames,
	}
end

return Lobby
