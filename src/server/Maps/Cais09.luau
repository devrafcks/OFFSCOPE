--[[
	CAIS 09 — porto industrial ao amanhecer.

	Planta (vista de cima, +X → leste, +Z → mar):
	   z +95  ~~~~~~~~ água ~~~~~~~~  [ NAVIO — spawn B, convés y=10 ]
	   z +52  ─────── borda do cais ────── escadas de embarque (x −50 / +30)
	   z +40  ═════ A RETA DO CAIS (lane longa, 340 studs) ═════  guindaste x −20
	   z +30  ┌──────── pátio de containers (corredores + vãos de faca) ────────┐
	   z −88  └─────────────────────────────────────────────────────────────────┘
	          escritório (spawn A) x −172..−140                armazém x 105..170
]]

local MapKit = require(script.Parent.MapKit)

local Cais09 = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

local CONCRETE_WET = Color3.fromRGB(88, 88, 90)
local STEEL = Color3.fromRGB(70, 72, 76)
local SAFETY = Color3.fromRGB(214, 168, 36)

local function pier(kit)
	-- laje principal do cais (concreto molhado, leve reflexo)
	kit:Box(V(-178, -8, -96), V(178, 0, 52), { Name = "Pier", Material = Enum.Material.Concrete, Color = CONCRETE_WET, Reflectance = 0.04 })
	-- faixas de pintura e juntas de dilatação
	for x = -170, 170, 34 do
		kit:Detail(V(0.4, 0.04, 148), CF(x, 0.02, -22), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(70, 70, 72) })
	end
	kit:Detail(V(356, 0.05, 1.2), CF(0, 0.03, 49.5), { Material = Enum.Material.SmoothPlastic, Color = SAFETY })
	-- defensas de borracha e cabeços de amarração na borda
	for x = -168, 168, 16 do
		kit:Block(V(1.4, 1.6, 1.4), CF(x, 0.8, 50.8), { Name = "Bollard", Material = Enum.Material.Metal, Color = Color3.fromRGB(36, 38, 40), Shape = Enum.PartType.Block })
		kit:Detail(V(3, 3, 1), CF(x + 8, -2.5, 52.4), { Material = Enum.Material.Rubber, Color = Color3.fromRGB(20, 20, 22) })
	end
	-- estacas aparentes
	for x = -170, 170, 20 do
		kit:Detail(V(14, 2.2, 2.2), CF(x, -12, 51) * CFrame.Angles(0, 0, rad(90)), {
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(70, 74, 72),
			Shape = Enum.PartType.Cylinder,
		})
	end
	-- poças
	for _ = 1, 34 do
		kit:Puddle(V(kit.Rng:NextNumber(-165, 165), 0, kit.Rng:NextNumber(-85, 46)), kit.Rng:NextNumber(3, 9), kit.Rng:NextNumber(2, 6))
	end
end

local function water(kit)
	kit:TerrainBlock(CF(0, -18, 150), V(560, 33, 200), Enum.Material.Water)
	kit:TerrainBlock(CF(0, -36, 150), V(560, 4, 200), Enum.Material.Sand)
	kit:ClaimTerrain(V(0, -18, 150), V(570, 44, 210))
end

local function office(kit)
	local folder = "Office"
	local wall = { Material = Enum.Material.Brick, Color = Color3.fromRGB(122, 78, 62), Folder = folder }
	local trim = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(170, 166, 158), Folder = folder }
	-- pisos e laje
	kit:Box(V(-172, 0, -88), V(-140, 0.4, -56), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(96, 94, 90), Folder = folder })
	-- laje do 2º andar com vão para a escada (x −169..−155, z −87..−80)
	kit:Box(V(-172, 10.6, -80), V(-140, 11.4, -56), trim)
	kit:Box(V(-155, 10.6, -88), V(-140, 11.4, -80), trim)
	kit:Box(V(-172, 10.6, -88), V(-169, 11.4, -80), trim)
	kit:Box(V(-173, 21.4, -89), V(-139, 22.4, -55), trim)
	-- paredes (com vãos de porta e janela)
	kit:Box(V(-173, 0, -89), V(-172, 21.4, -55), wall) -- oeste
	kit:Box(V(-172, 0, -89), V(-140, 21.4, -88), wall) -- sul
	-- norte: janelas no 2º andar
	kit:Box(V(-172, 0, -57), V(-140, 4, -56), wall)
	kit:Box(V(-172, 8, -57), V(-140, 15, -56), wall)
	kit:Box(V(-172, 19, -57), V(-140, 21.4, -56), wall)
	for x = -170, -146, 8 do
		kit:Box(V(x, 4, -57), V(x + 2, 8, -56), wall)
		kit:Box(V(x, 15, -57), V(x + 2, 19, -56), wall)
	end
	-- leste: porta grande no térreo
	kit:Box(V(-140, 0, -88), V(-139, 21.4, -78), wall)
	kit:Box(V(-140, 9, -78), V(-139, 21.4, -66), wall)
	kit:Box(V(-140, 0, -66), V(-139, 21.4, -56), wall)
	-- vidros
	for x = -168, -144, 8 do
		kit:Detail(V(6, 4, 0.2), CF(x + 1, 6, -56.5), { Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 180, 200), Transparency = 0.55, Reflectance = 0.2, Folder = folder })
	end
	-- escada interna até o 2º andar
	kit:Stairs(V(-168, 0.4, -84), V(1, 0, 0), 4, 10.2, 10, { Folder = folder })
	-- letreiro
	kit:Sign(V(18, 3, 0.4), CF(-156, 18, -55.6) * CFrame.Angles(0, rad(180), 0), "CAIS 09 · ADMINISTRAÇÃO", {
		Background = Color3.fromRGB(26, 40, 60),
		Color = Color3.fromRGB(240, 240, 230),
		Font = Enum.Font.GothamBold,
	})
	local lamp = kit:Detail(V(2, 0.3, 2), CF(-156, 10.4, -72), { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 236, 200), Folder = folder })
	kit:Light(lamp, { Kind = "Point", Range = 26, Brightness = 1.3, Color = Color3.fromRGB(255, 226, 190), Shadows = true })
	-- móveis (cobertura interna)
	kit:Box(V(-164, 0.4, -70), V(-156, 3.6, -66), { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 84, 60), Folder = folder })
	kit:Box(V(-166, 11.4, -76), V(-160, 14.6, -68), { Material = Enum.Material.Metal, Color = Color3.fromRGB(80, 90, 96), Folder = folder })
end

local function containerYard(kit)
	local rows = { -80, -60, -38, -16, 6, 24 }
	for rowIndex, z in rows do
		local x = -118
		while x <= 70 do
			-- corredor norte-sul no meio e "buracos" aleatórios = rotas de flanco
			local corridor = math.abs(x + 12) < 12
			local skip = corridor or kit.Rng:NextNumber() < 0.2
			if not skip then
				local height = if rowIndex == #rows then 1 else kit.Rng:NextInteger(1, 3)
				local color = kit:ContainerColor()
				for level = 1, height do
					local tint = if kit.Rng:NextNumber() < 0.4 then kit:ContainerColor() else color
					local offset = (kit.Rng:NextNumber() - 0.5) * 0.6
					kit:Container(CF(x + 10 + offset, 4.25 + (level - 1) * 8.5, z) * CFrame.Angles(0, rad(90), 0), tint, level == height or level == 1)
				end
			end
			x += 24
		end
	end
	-- escada de acesso ao topo de uma pilha (ângulo alto, exposto)
	kit:Block(V(1.2, 17, 1.2), CF(-60, 8.5, -33.3), { Truss = true, Material = Enum.Material.Metal, Color = SAFETY, Folder = "Containers" })
end

local function warehouse(kit)
	local folder = "Warehouse"
	local panel = { Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(96, 102, 104), Folder = folder }
	kit:Box(V(105, 0, -88), V(170, 0.3, -20), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(92, 90, 86), Folder = folder })
	-- paredes
	kit:Box(V(170, 0, -89), V(171, 24, -19), panel) -- leste
	kit:Box(V(104, 0, -89), V(171, 24, -88), panel) -- sul
	-- oeste: duas portas de 14
	kit:Box(V(104, 0, -88), V(105, 24, -80), panel)
	kit:Box(V(104, 14, -80), V(105, 24, -66), panel)
	kit:Box(V(104, 0, -66), V(105, 24, -46), panel)
	kit:Box(V(104, 14, -46), V(105, 24, -32), panel)
	kit:Box(V(104, 0, -32), V(105, 24, -20), panel)
	-- norte (de frente para a reta): uma porta
	kit:Box(V(104, 0, -21), V(130, 24, -20), panel)
	kit:Box(V(130, 14, -21), V(146, 24, -20), panel)
	kit:Box(V(146, 0, -21), V(171, 24, -20), panel)
	-- telhado com claraboias
	kit:Box(V(103, 24, -90), V(172, 25, -60), panel)
	kit:Box(V(103, 24, -50), V(172, 25, -18), panel)
	kit:Detail(V(69, 0.3, 10), CF(137.5, 24.5, -55), { Material = Enum.Material.Glass, Color = Color3.fromRGB(180, 200, 210), Transparency = 0.5, Folder = folder })
	-- nervuras externas
	for z = -86, -22, 4 do
		kit:Detail(V(0.4, 24, 0.5), CF(171.3, 12, z), { Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 76, 78), Folder = folder })
	end
	-- prateleiras (racks) com caixas: corredores internos
	for _, z in { -78, -62, -46 } do
		for _, x in { 116, 134, 152 } do
			kit:Box(V(x - 6, 0.3, z - 2), V(x + 6, 9, z + 2), { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 70, 130), Folder = folder })
			kit:Crate(CF(x - 3, 9, z), 3.6)
			if kit.Rng:NextNumber() > 0.4 then
				kit:Crate(CF(x + 2.5, 9, z), 3.4)
			end
		end
	end
	-- passarela (catwalk) com escada
	kit:Box(V(150, 10, -88), V(170, 11, -37), { Material = Enum.Material.DiamondPlate, Color = STEEL, Folder = folder })
	kit:Stairs(V(160, 0.3, -24), V(0, 0, -1), 4, 10.5, 10, { Folder = folder })
	kit:Rail(V(150, 13.5, -88), V(150, 13.5, -38), SAFETY)
	-- luzes de teto (uma com sombra)
	for i, z in { -76, -54, -32 } do
		local lamp = kit:Detail(V(3, 0.4, 1), CF(130, 23.4, z), { Material = Enum.Material.Neon, Color = Color3.fromRGB(230, 240, 255), Folder = folder })
		kit:Light(lamp, { Kind = "Spot", Face = Enum.NormalId.Bottom, Range = 30, Angle = 100, Brightness = 2, Color = Color3.fromRGB(220, 232, 255), Shadows = i == 2 })
	end
	-- empilhadeira
	kit:Box(V(110, 0.3, -18), V(116, 5, -10), { Material = Enum.Material.Metal, Color = SAFETY, Folder = folder })
	kit:Box(V(110.5, 5, -16), V(115.5, 9, -11), { Material = Enum.Material.Metal, Color = Color3.fromRGB(30, 30, 32), Transparency = 0.2, Folder = folder })
	kit:Detail(V(0.6, 10, 5), CF(118, 5, -14), { Material = Enum.Material.Metal, Color = Color3.fromRGB(30, 30, 32), Folder = folder })
end

local function ship(kit)
	local folder = "Ship"
	local hull = { Material = Enum.Material.Metal, Color = Color3.fromRGB(46, 30, 32), Folder = folder }
	kit:Box(V(-92, -12, 60), V(72, 9, 94), hull)
	-- faixa vermelha de linha d'água e branca do convés
	kit:Detail(V(164.4, 2, 34.4), CF(-10, -1, 77), { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 30, 30), Folder = folder })
	kit:Detail(V(164.4, 0.6, 34.4), CF(-10, 8.4, 77), { Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 220, 214), Folder = folder })
	-- proa (degraus de blocos afinando)
	for i = 1, 5 do
		local w = 34 - i * 6
		kit:Box(V(-92 - i * 5, -12 + i * 1.5, 77 - w / 2), V(-87 - i * 5, 9, 77 + w / 2), hull)
	end
	-- convés
	kit:Box(V(-116, 9, 61), V(71, 10, 93), { Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(110, 106, 98), Folder = folder })
	-- amurada
	kit:Box(V(-116, 10, 92.4), V(71, 12.6, 93), hull)
	kit:Box(V(-116, 10, 61), V(-60, 12.6, 61.6), hull)
	kit:Box(V(-40, 10, 61), V(20, 12.6, 61.6), hull)
	kit:Box(V(40, 10, 61), V(71, 12.6, 61.6), hull)
	-- superestrutura (ponte de comando)
	local white = { Material = Enum.Material.Metal, Color = Color3.fromRGB(226, 224, 216), Folder = folder }
	kit:Box(V(44, 10, 64), V(68, 30, 90), white)
	kit:Detail(V(24.4, 3, 26.4), CF(56, 26, 77), { Material = Enum.Material.Glass, Color = Color3.fromRGB(40, 60, 80), Reflectance = 0.3, Transparency = 0.1, Folder = folder })
	kit:Box(V(52, 30, 72), V(60, 44, 80), { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 40, 36), Folder = folder }) -- chaminé
	-- carga no convés (cobertura do spawn B)
	for _, spec in { { -70, 70 }, { -70, 84 }, { -44, 84 }, { -12, 70 }, { 14, 84 } } do
		kit:Container(CF(spec[1], 14.25, spec[2]) * CFrame.Angles(0, rad(90), 0))
	end
	-- escadas de embarque (do cais até o convés)
	for _, x in { -50, 30 } do
		kit:Stairs(V(x, 0, 50.4), V(0, 0, 1), 6, 10, 9, { Folder = folder, Material = Enum.Material.DiamondPlate, Color = STEEL })
		kit:Rail(V(x - 3, 2.6, 50.4), V(x - 3, 12.6, 61), SAFETY)
		kit:Rail(V(x + 3, 2.6, 50.4), V(x + 3, 12.6, 61), SAFETY)
	end
end

local function crane(kit)
	local folder = "Crane"
	local yellow = { Material = Enum.Material.Metal, Color = Color3.fromRGB(206, 160, 34), Folder = folder }
	for _, x in { -32, -8 } do
		for _, z in { 31, 50 } do
			kit:Box(V(x - 1.2, 0, z - 1.2), V(x + 1.2, 40, z + 1.2), yellow)
		end
		kit:Box(V(x - 1.2, 38, 28), V(x + 1.2, 41, 130), yellow) -- lança sobre o navio
	end
	kit:Box(V(-33, 41, 26), V(-7, 48, 40), { Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 220, 214), Folder = folder }) -- casa de máquinas
	-- plataforma de tiro a y=24 (vertical do mapa) + escada de marinheiro
	kit:Box(V(-32, 24, 30), V(-8, 25, 34), { Material = Enum.Material.DiamondPlate, Color = STEEL, Folder = folder })
	kit:Rail(V(-32, 27.5, 30), V(-8, 27.5, 30), Color3.fromRGB(220, 60, 40))
	kit:Block(V(1.4, 24, 1.4), CF(-20, 12, 33.4), { Truss = true, Material = Enum.Material.Metal, Color = Color3.fromRGB(206, 160, 34), Folder = folder })
	-- contraventamentos (detalhe)
	for _, x in { -32, -8 } do
		kit:Rail(V(x, 4, 31), V(x, 20, 50), Color3.fromRGB(190, 146, 30))
		kit:Rail(V(x, 20, 31), V(x, 36, 50), Color3.fromRGB(190, 146, 30))
	end
	-- spreader pendurado sobre a água
	kit:Detail(V(8, 2, 20), CF(-20, 28, 70) * CFrame.Angles(0, rad(90), 0), { Material = Enum.Material.Metal, Color = SAFETY, Folder = folder })
	for _, dx in { -6, 6 } do
		kit:Detail(V(0.15, 10, 0.15), CF(-20 + dx, 34, 70), { Material = Enum.Material.Metal, Color = Color3.fromRGB(30, 30, 30), Folder = folder })
	end
end

local function lane(kit)
	-- cobertura baixa (barreiras new jersey) alternada ao longo da reta
	for i, x in { -128, -84, -44, 6, 52, 92, 136 } do
		local z = if i % 2 == 0 then 36 else 44
		kit:Block(V(8, 3.2, 1.6), CF(x, 1.6, z), { Name = "Barrier", Material = Enum.Material.Concrete, Color = Color3.fromRGB(160, 156, 148) })
		kit:Detail(V(8.05, 0.5, 1.65), CF(x, 2.6, z), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(200, 60, 40) })
	end
	-- postes (2 de 6 com sombra)
	for i, x in { -150, -90, -30, 30, 90, 150 } do
		kit:StreetLamp(V(x, 0, 30), V(0, 0, 1), Color3.fromRGB(255, 200, 150), i == 2 or i == 5)
	end
	-- pallets e barris espalhados
	for _ = 1, 10 do
		local x = kit.Rng:NextNumber(-165, 165)
		local z = kit.Rng:NextNumber(-90, -84)
		kit:Barrel(V(x, 0, z), if kit.Rng:NextNumber() > 0.5 then Color3.fromRGB(40, 70, 120) else Color3.fromRGB(150, 40, 30))
	end
	for _, spec in { { -132, -40 }, { -126, -4 }, { 98, 20 }, { 60, -86 } } do
		kit:Crate(CF(spec[1], 0, spec[2]), 4)
		kit:Crate(CF(spec[1] + 4.2, 0, spec[2] + 0.4), 4)
		kit:Crate(CF(spec[1] + 2, 4, spec[2]), 3.6)
	end
end

local function bounds(kit)
	kit:Barrier(V(-182, -10, -100), V(-178, 90, 100))
	kit:Barrier(V(178, -10, -100), V(182, 90, 100))
	kit:Barrier(V(-182, -10, -100), V(182, 90, -96))
	kit:Barrier(V(-182, -10, 94), V(182, 90, 98))
	kit:Barrier(V(-182, 89, -100), V(182, 92, 100)) -- teto
	-- borda do cais: impede cair no vão entre cais e navio (deixa as escadas livres)
	kit:Barrier(V(-178, 0, 52.3), V(-54, 6, 53))
	kit:Barrier(V(-46, 0, 52.3), V(26, 6, 53))
	kit:Barrier(V(34, 0, 52.3), V(178, 6, 53))
end

local function spawns(kit)
	-- A: escritório (oeste)
	for _, z in { -46, -32, -18, -4 } do
		kit:Spawn("A", V(-158, 0.4, z), V(0, 0, 10))
	end
	-- B: convés do navio
	for _, x in { -24, -2, 22, 2 } do
		kit:Spawn("B", V(x, 10, 77), V(0, 0, 0))
	end
	-- FFA extras
	for _, p in { V(-12, 0, -60), V(-12, 0, 10), V(140, 0.3, -40), V(80, 0, -90), V(-100, 0, 40), V(120, 0, 40) } do
		kit:Spawn("FFA", p, V(0, 0, 0))
	end
end

function Cais09.Build(origin: CFrame): MapKit.BuiltMap
	local kit = MapKit.new("Cais09", origin, 909)
	water(kit)
	pier(kit)
	office(kit)
	containerYard(kit)
	warehouse(kit)
	ship(kit)
	crane(kit)
	lane(kit)
	bounds(kit)
	spawns(kit)
	return kit:Finish(-6)
end

return Cais09
