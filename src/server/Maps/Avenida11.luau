--[[
	AVENIDA 11 — centro urbano à noite, logo depois da chuva.

	Planta (+X leste, +Z norte):
	   z +84  ── beco dos fundos (escadas de incêndio → telhados) ──
	   z +40  [prédios]  [HALL atravessável x −40..20]  [telhado A]=ponte=[telhado B]
	   z +14  ─── calçada norte ───            boca do METRÔ (x −118..−110)
	   z ±14  ═══════ A AVENIDA (lane de no-scope, 360 studs) ═══════  ônibus parado, táxi batido
	   z −14  ─── calçada sul ───               boca do METRÔ ↘ túnel por baixo da avenida
	   z −40  [prédios]           [ESTACIONAMENTO aberto x 40..130]
	Spawns: A oeste (x −165), B leste (x +165).
]]

local MapKit = require(script.Parent.MapKit)

local Avenida11 = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

local ASPHALT = Color3.fromRGB(34, 35, 38)
local SIDEWALK = Color3.fromRGB(92, 92, 96)
local WARM = Color3.fromRGB(255, 196, 130)
local COOL = Color3.fromRGB(170, 200, 255)

local function ground(kit)
	-- avenida (asfalto molhado: reflexo leve)
	kit:Box(V(-182, -2, -14), V(182, 0, 14), { Name = "Avenue", Material = Enum.Material.Asphalt, Color = ASPHALT, Reflectance = 0.07 })
	-- faixas: tracejado central e bordas
	for x = -176, 176, 12 do
		kit:Detail(V(6, 0.04, 0.4), CF(x, 0.02, 0), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(220, 190, 70) })
	end
	for _, z in { -12.6, 12.6 } do
		kit:Detail(V(364, 0.04, 0.35), CF(0, 0.02, z), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(200, 200, 196) })
	end
	-- faixa de pedestres
	for i = -5, 5 do
		kit:Detail(V(2, 0.04, 24), CF(60 + i * 3.4, 0.02, 0), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(210, 210, 206) })
	end

	-- calçadas + praças (com os poços do metrô em x −118..−110)
	local side = { Material = Enum.Material.Pavement, Color = SIDEWALK, Reflectance = 0.03 }
	-- norte: z 14..40, poço em z 24..40
	kit:Box(V(-182, -2, 14), V(-118, 0.6, 40), side)
	kit:Box(V(-110, -2, 14), V(182, 0.6, 40), side)
	kit:Box(V(-118, -2, 14), V(-110, 0.6, 24), side)
	-- sul: z −40..−14, poço em z −40..−24
	kit:Box(V(-182, -2, -40), V(-118, 0.6, -14), side)
	kit:Box(V(-110, -2, -40), V(182, 0.6, -14), side)
	kit:Box(V(-118, -2, -24), V(-110, 0.6, -14), side)
	-- meio-fio
	for _, z in { -14.2, 14.2 } do
		kit:Detail(V(364, 0.65, 0.5), CF(0, 0.3, z), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(130, 128, 124) })
	end
	-- poças na avenida e nas calçadas
	for _ = 1, 40 do
		local z = kit.Rng:NextNumber(-12, 12)
		kit:Puddle(V(kit.Rng:NextNumber(-170, 170), 0, z), kit.Rng:NextNumber(3, 10), kit.Rng:NextNumber(2, 5))
	end
	for _ = 1, 14 do
		local z = if kit.Rng:NextNumber() > 0.5 then kit.Rng:NextNumber(16, 36) else kit.Rng:NextNumber(-36, -16)
		local p = kit:Puddle(V(kit.Rng:NextNumber(-170, 170), 0.6, z), kit.Rng:NextNumber(2, 6), kit.Rng:NextNumber(2, 4))
		p.Name = "Puddle"
	end
end

local function subway(kit)
	local folder = "Metro"
	local tile = { Material = Enum.Material.CeramicTiles, Color = Color3.fromRGB(196, 200, 196), Folder = folder }
	local dark = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(70, 72, 74), Folder = folder }
	-- túnel de passagem (x −124..−104, z −26..26, y −12..−2)
	kit:Box(V(-124, -13, -26), V(-104, -12, 26), { Material = Enum.Material.Granite, Color = Color3.fromRGB(110, 108, 104), Folder = folder })
	kit:Box(V(-125, -13, -26), V(-124, -2, 26), tile)
	kit:Box(V(-104, -13, -26), V(-103, -2, 26), tile)
	kit:Box(V(-124, -13, -27), V(-104, -2, -26), tile)
	kit:Box(V(-124, -13, 26), V(-104, -2, 27), tile)
	-- faixa de cor nas paredes
	for _, x in { -123.9, -104.1 } do
		kit:Detail(V(0.2, 1.2, 52), CF(x, -7, 0), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(30, 110, 200), Folder = folder })
	end
	-- pilares e catracas (cobertura de faca)
	for _, z in { -14, 0, 14 } do
		kit:Box(V(-115.5, -12, z - 1), V(-112.5, -2, z + 1), dark)
	end
	for i = 0, 3 do
		kit:Box(V(-122 + i * 2.6, -12, 6), V(-121.2 + i * 2.6, -9.6, 8.5), { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 154, 160), Folder = folder })
	end
	-- luzes fluorescentes (uma com sombra)
	for i, z in { -18, -4, 10, 22 } do
		local tube = kit:Detail(V(1, 0.3, 6), CF(-114, -2.3, z), { Material = Enum.Material.Neon, Color = Color3.fromRGB(220, 240, 255), Folder = folder })
		kit:Light(tube, { Kind = "Point", Range = 18, Brightness = 1.6, Color = Color3.fromRGB(210, 230, 255), Shadows = i == 2 })
	end
	-- escadas (sul sobe para −Z, norte sobe para +Z)
	kit:Stairs(V(-114, -12, -24), V(0, 0, -1), 7, 12.6, 12, { Folder = folder, Material = Enum.Material.Granite, Color = Color3.fromRGB(120, 118, 112) })
	kit:Stairs(V(-114, -12, 24), V(0, 0, 1), 7, 12.6, 12, { Folder = folder, Material = Enum.Material.Granite, Color = Color3.fromRGB(120, 118, 112) })
	-- paredes dos poços e guarda-corpo
	for _, zr in { { -40, -24 }, { 24, 40 } } do
		kit:Box(V(-119, -12, zr[1]), V(-118, 0.6, zr[2]), tile)
		kit:Box(V(-110, -12, zr[1]), V(-109, 0.6, zr[2]), tile)
		kit:Rail(V(-118.5, 3.4, zr[1]), V(-118.5, 3.4, zr[2]), Color3.fromRGB(170, 170, 176))
		kit:Rail(V(-109.5, 3.4, zr[1]), V(-109.5, 3.4, zr[2]), Color3.fromRGB(170, 170, 176))
	end
	-- totens "M"
	for _, z in { -34, 34 } do
		kit:Block(V(0.6, 9, 0.6), CF(-120, 5.1, z), { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 44), Folder = folder })
		kit:Sign(V(2.6, 2.6, 0.5), CF(-120, 10.6, z) * CFrame.Angles(0, rad(90), 0), "M", {
			Background = Color3.fromRGB(20, 90, 200),
			Color = Color3.fromRGB(255, 255, 255),
			Glow = true,
			LightRange = 10,
		})
	end
end

-- Prédio com fachada de janelas para a avenida (`faceZ` = lado da fachada: +1 norte do prédio, −1 sul).
local function building(kit, xMin: number, xMax: number, zMin: number, zMax: number, height: number, faceZ: number, style: number)
	local folder = "Buildings"
	local palettes = {
		{ Enum.Material.Concrete, Color3.fromRGB(96, 98, 104) },
		{ Enum.Material.Brick, Color3.fromRGB(110, 72, 60) },
		{ Enum.Material.Plaster, Color3.fromRGB(150, 146, 136) },
		{ Enum.Material.Slate, Color3.fromRGB(62, 64, 70) },
	}
	local palette = palettes[(style - 1) % #palettes + 1]
	kit:Box(V(xMin, 0, zMin), V(xMax, height, zMax), { Name = "Building", Material = palette[1], Color = palette[2], Folder = folder })
	-- platibanda
	kit:Detail(V(xMax - xMin + 0.6, 1, zMax - zMin + 0.6), CF((xMin + xMax) / 2, height + 0.5, (zMin + zMax) / 2), {
		Material = Enum.Material.Concrete,
		Color = palette[2]:Lerp(Color3.new(0, 0, 0), 0.3),
		Folder = folder,
	})
	-- janelas por andar na fachada
	local faceZPos = if faceZ > 0 then zMax + 0.08 else zMin - 0.08
	local width = xMax - xMin
	for floorY = 8, height - 4, 5 do
		kit:Detail(V(width - 2, 2.6, 0.14), CF((xMin + xMax) / 2, floorY, faceZPos), {
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(18, 22, 30),
			Reflectance = 0.25,
			Folder = folder,
		})
		-- algumas janelas acesas (cidade viva à noite)
		local x = xMin + 2
		while x < xMax - 4 do
			local w = kit.Rng:NextNumber(2.5, 5)
			if kit.Rng:NextNumber() < 0.32 then
				local tint = if kit.Rng:NextNumber() > 0.3 then WARM else COOL
				kit:Detail(V(w, 2.2, 0.16), CF(x + w / 2, floorY, faceZPos + 0.02 * faceZ), {
					Material = Enum.Material.Neon,
					Color = tint:Lerp(Color3.new(0, 0, 0), kit.Rng:NextNumber(0.35, 0.65)),
					Folder = folder,
				})
			end
			x += w + 1.2
		end
	end
	-- marquise no térreo
	kit:Detail(V(width, 0.6, 3), CF((xMin + xMax) / 2, 5.6, faceZPos + faceZ * 1.5), { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 46), Folder = folder })
end

local function lobbyHall(kit)
	local folder = "Hall"
	-- térreo atravessável (z 40..72), com andares acima
	local marble = { Material = Enum.Material.Marble, Color = Color3.fromRGB(200, 196, 188), Folder = folder }
	kit:Box(V(-40, 0, 40), V(20, 0.8, 72), marble)
	kit:Box(V(-41, 12, 39), V(21, 46, 73), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(82, 86, 92), Folder = folder })
	kit:Box(V(-41, 11, 39), V(21, 12, 73), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(60, 62, 66), Folder = folder })
	-- paredes laterais
	kit:Box(V(-41, 0, 40), V(-40, 11, 72), { Material = Enum.Material.Marble, Color = Color3.fromRGB(60, 56, 54), Folder = folder })
	kit:Box(V(20, 0, 40), V(21, 11, 72), { Material = Enum.Material.Marble, Color = Color3.fromRGB(60, 56, 54), Folder = folder })
	-- pilares
	for _, x in { -28, -10, 8 } do
		for _, z in { 48, 64 } do
			kit:Box(V(x - 1, 0.8, z - 1), V(x + 1, 11, z + 1), { Material = Enum.Material.Marble, Color = Color3.fromRGB(230, 226, 218), Folder = folder })
		end
	end
	-- recepção (cobertura)
	kit:Box(V(-18, 0.8, 54), V(-2, 4.4, 58), { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(80, 54, 40), Folder = folder })
	kit:Detail(V(16, 0.3, 4.2), CF(-10, 4.55, 56), { Material = Enum.Material.Marble, Color = Color3.fromRGB(30, 30, 32), Folder = folder })
	-- vidro da fachada com portas abertas
	for _, xr in { { -40, -26 }, { -14, 2 }, { 12, 20 } } do
		kit:Detail(V(xr[2] - xr[1], 10, 0.3), CF((xr[1] + xr[2]) / 2, 5.8, 40.2), {
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(160, 190, 210),
			Transparency = 0.6,
			Reflectance = 0.25,
			Folder = folder,
		})
	end
	-- luz quente do hall (sombra: é close-quarters)
	local lamp = kit:Detail(V(8, 0.3, 8), CF(-10, 10.8, 56), { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 226, 180), Folder = folder })
	kit:Light(lamp, { Kind = "Point", Range = 34, Brightness = 1.8, Color = Color3.fromRGB(255, 214, 170), Shadows = true })
	kit:Sign(V(26, 3.4, 0.4), CF(-10, 9, 39.6), "EDIFÍCIO AURORA", {
		Background = Color3.fromRGB(14, 14, 18),
		Color = Color3.fromRGB(255, 226, 170),
		Glow = true,
		Font = Enum.Font.Garamond,
	})
end

local function rooftops(kit)
	local folder = "Rooftops"
	building(kit, 40, 80, 40, 72, 24, -1, 3)
	building(kit, 86, 126, 40, 72, 24, -1, 1)
	-- pisos de telhado com parapeito (cobertura)
	for _, xr in { { 40, 80 }, { 86, 126 } } do
		kit:Box(V(xr[1], 24, 40), V(xr[2], 25, 72), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(70, 72, 76), Folder = folder })
		kit:Box(V(xr[1], 25, 40), V(xr[2], 28, 41), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(86, 88, 92), Folder = folder })
		-- caixa d'água / ar-condicionado
		kit:Box(V(xr[1] + 6, 25, 56), V(xr[1] + 14, 31, 64), { Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(110, 114, 118), Folder = folder })
		kit:Box(V(xr[2] - 12, 25, 50), V(xr[2] - 6, 28, 54), { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 152, 156), Folder = folder })
	end
	-- ponte entre telhados
	kit:Box(V(80, 24.4, 52), V(86, 25, 58), { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 80, 56), Folder = folder })
	kit:Rail(V(80, 27, 52), V(86, 27, 52), Color3.fromRGB(150, 150, 156))
	kit:Rail(V(80, 27, 58), V(86, 27, 58), Color3.fromRGB(150, 150, 156))
	-- escadas de incêndio no beco (escada de marinheiro até o telhado)
	for _, x in { 44, 122 } do
		kit:Block(V(1.4, 25, 1.4), CF(x, 12.5, 72.8), { Truss = true, Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 46), Folder = folder })
	end
	-- beco dos fundos
	kit:Box(V(-182, -2, 72), V(182, 0.2, 86), { Material = Enum.Material.Asphalt, Color = Color3.fromRGB(28, 28, 30), Reflectance = 0.04, Folder = folder })
	for _, x in { -30, 30, 100, 150 } do
		kit:Box(V(x - 3, 0.2, 78), V(x + 3, 5, 84), { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 80, 50), Folder = folder }) -- caçamba
	end
	local bulb = kit:Detail(V(0.8, 0.8, 0.8), CF(64, 9, 73), { Material = Enum.Material.Neon, Color = WARM, Folder = folder })
	kit:Light(bulb, { Kind = "Point", Range = 22, Brightness = 1.4, Color = WARM })
end

local function parking(kit)
	local folder = "Parking"
	kit:Box(V(40, -2, -100), V(130, 0.4, -40), { Material = Enum.Material.Asphalt, Color = Color3.fromRGB(44, 44, 48), Reflectance = 0.05, Folder = folder })
	for x = 44, 126, 9 do
		for _, z in { -52, -88 } do
			kit:Detail(V(0.3, 0.04, 14), CF(x, 0.42, z), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(200, 200, 196), Folder = folder })
		end
	end
	local carColors = {
		Color3.fromRGB(150, 20, 24),
		Color3.fromRGB(26, 28, 32),
		Color3.fromRGB(200, 200, 204),
		Color3.fromRGB(30, 60, 120),
		Color3.fromRGB(110, 112, 116),
	}
	for x = 48, 122, 9 do
		for _, z in { -52, -88 } do
			if kit.Rng:NextNumber() < 0.62 then
				kit:Car(CF(x + 0.5, 0.4, z) * CFrame.Angles(0, if z > -70 then 0 else rad(180), 0), carColors[kit.Rng:NextInteger(1, #carColors)])
			end
		end
	end
	-- guarita e cancela
	kit:Box(V(36, 0.6, -36), V(40, 8, -30), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(180, 176, 168), Folder = folder })
	kit:Detail(V(14, 0.4, 0.4), CF(47, 4, -34), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(220, 40, 40), Folder = folder })
	-- muro com vãos (borda leste/oeste)
	kit:Box(V(39, 0.4, -100), V(40, 4, -60), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(120, 118, 112), Folder = folder })
	kit:Box(V(130, 0.4, -100), V(131, 4, -44), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(120, 118, 112), Folder = folder })
	for i, x in { 60, 110 } do
		kit:StreetLamp(V(x, 0.4, -70), V(1, 0, 0), Color3.fromRGB(255, 180, 110), i == 1)
	end
end

local function street(kit)
	-- ônibus parado (cobertura grande no meio da lane) e táxi batido
	local bus = { Material = Enum.Material.Metal, Color = Color3.fromRGB(30, 110, 150), Folder = "Vehicles" }
	kit:Box(V(4, 0.6, -10), V(36, 10, -2), bus)
	kit:Detail(V(30, 2.4, 8.2), CF(20, 7, -6), { Material = Enum.Material.Glass, Color = Color3.fromRGB(20, 26, 34), Reflectance = 0.3, Folder = "Vehicles" })
	kit:Sign(V(6, 1.2, 0.3), CF(3.8, 8.6, -6) * CFrame.Angles(0, rad(90), 0), "11 CENTRO", {
		Background = Color3.fromRGB(10, 10, 10),
		Color = Color3.fromRGB(255, 160, 40),
		Glow = true,
		LightRange = 6,
	})
	kit:Car(CF(-62, 0, 5) * CFrame.Angles(0, rad(28), 0), Color3.fromRGB(230, 180, 20))
	kit:Car(CF(-140, 0, -9) * CFrame.Angles(0, rad(90), 0), Color3.fromRGB(26, 28, 32))
	kit:Car(CF(96, 0, 9) * CFrame.Angles(0, rad(-90), 0), Color3.fromRGB(200, 200, 204))
	kit:Car(CF(140, 0, -8) * CFrame.Angles(0, rad(84), 0), Color3.fromRGB(120, 20, 24))

	-- banca de jornal, ponto de ônibus, floreiras
	kit:Box(V(-82, 0.6, 18), V(-74, 8, 24), { Material = Enum.Material.Metal, Color = Color3.fromRGB(30, 80, 50), Folder = "Props" })
	kit:Box(V(10, 0.6, -21), V(26, 0.9, -17), { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 62, 66), Folder = "Props" })
	kit:Detail(V(16, 0.3, 4), CF(18, 8.4, -19), { Material = Enum.Material.Glass, Color = Color3.fromRGB(160, 190, 210), Transparency = 0.4, Folder = "Props" })
	for _, x in { 10.5, 25.5 } do
		kit:Detail(V(0.3, 7.6, 0.3), CF(x, 4.6, -20.8), { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 62, 66), Folder = "Props" })
	end
	for _, spec in { { -150, 30 }, { -40, -30 }, { 150, 30 }, { 140, -30 }, { -170, -30 } } do
		kit:Box(V(spec[1] - 3, 0.6, spec[2] - 2), V(spec[1] + 3, 3.4, spec[2] + 2), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(110, 108, 104), Folder = "Props" })
		kit:Detail(V(5.6, 1.6, 3.6), CF(spec[1], 4, spec[2]), { Material = Enum.Material.LeafyGrass, Color = Color3.fromRGB(40, 70, 40), Folder = "Props" })
	end

	-- postes dos dois lados (4 com sombra)
	local i = 0
	for x = -160, 160, 45 do
		i += 1
		kit:StreetLamp(V(x, 0.6, 16), V(0, 0, -1), WARM, i == 2 or i == 6)
		kit:StreetLamp(V(x + 22, 0.6, -16), V(0, 0, 1), WARM, i == 4 or i == 8)
	end

	-- semáforos
	for _, spec in { { 50, 15.5 }, { 70, -15.5 } } do
		kit:Block(V(0.5, 12, 0.5), CF(spec[1], 6.6, spec[2]), { Material = Enum.Material.Metal, Color = Color3.fromRGB(30, 30, 32), Folder = "Props" })
		local box = kit:Detail(V(1, 3, 1), CF(spec[1], 11, spec[2]), { Material = Enum.Material.Metal, Color = Color3.fromRGB(24, 24, 26), Folder = "Props" })
		box.Name = "TrafficLight"
		kit:Detail(V(0.7, 0.7, 0.2), CF(spec[1], 11.9, spec[2] - 0.5), { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 40, 40), Folder = "Props" })
	end
end

local function signs(kit)
	local specs = {
		{ "FARMÁCIA 24H", V(-150, 14, 39.6), Color3.fromRGB(60, 255, 140), 0 },
		{ "HOTEL ÍRIS", V(-80, 22, 39.6), Color3.fromRGB(255, 70, 200), 0 },
		{ "BAR 11", V(150, 12, -39.6), Color3.fromRGB(255, 120, 40), 180 },
		{ "LAVANDERIA", V(-60, 12, -39.6), Color3.fromRGB(80, 220, 255), 180 },
		{ "CINE ODEON", V(-150, 20, -39.6), Color3.fromRGB(255, 220, 90), 180 },
	}
	for _, spec in specs do
		kit:Sign(V(#spec[1] * 1.3 + 4, 3.6, 0.4), CF(spec[2]) * CFrame.Angles(0, rad(spec[4]), 0), spec[1], {
			Background = Color3.fromRGB(8, 8, 10),
			Color = spec[3],
			Glow = true,
			LightRange = 18,
		})
	end
end

local function bounds(kit)
	kit:Barrier(V(-186, -14, -104), V(-182, 100, 90))
	kit:Barrier(V(182, -14, -104), V(186, 100, 90))
	kit:Barrier(V(-186, -14, 86), V(186, 100, 90))
	kit:Barrier(V(-186, -14, -104), V(186, 100, -100))
	kit:Barrier(V(-186, 99, -104), V(186, 102, 90))
end

local function spawns(kit)
	for _, z in { -8, 6, 24, -28 } do
		kit:Spawn("A", V(-168, 0.6, z), V(0, 0, z))
		kit:Spawn("B", V(168, 0.6, z), V(0, 0, z))
	end
	for _, p in { V(-10, 0.8, 60), V(85, 0.4, -70), V(-114, -12, 0), V(100, 25, 64), V(0, 0.6, 30), V(-60, 0.6, -30) } do
		kit:Spawn("FFA", p, V(0, p.Y, 0))
	end
end

function Avenida11.Build(origin: CFrame): MapKit.BuiltMap
	local kit = MapKit.new("Avenida11", origin, 1111)
	ground(kit)
	subway(kit)
	-- quarteirão norte (fachada para −Z, avenida ao sul)
	building(kit, -182, -128, 40, 72, 48, -1, 2)
	building(kit, -124, -44, 40, 72, 62, -1, 4)
	lobbyHall(kit)
	rooftops(kit)
	building(kit, 130, 182, 40, 72, 40, -1, 3)
	-- quarteirão sul (fachada para +Z)
	building(kit, -182, -122, -100, -40, 54, 1, 1)
	building(kit, -106, -40, -100, -40, 36, 1, 2)
	building(kit, -36, 36, -100, -40, 70, 1, 4)
	parking(kit)
	building(kit, 134, 182, -100, -40, 44, 1, 3)
	street(kit)
	signs(kit)
	bounds(kit)
	spawns(kit)
	return kit:Finish(-30)
end

return Avenida11
