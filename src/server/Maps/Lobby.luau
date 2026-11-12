--[[
	LOBBY — "Base OFFSCOPE": praça de concreto polido, pads de fila em semicírculo,
	monólito com o logo, loja, quadro de ranking e o RANGE de treino a leste
	(alvos a 25/50/100/150/200/260 studs, dummies parados e em trilho).
]]

local MapKit = require(script.Parent.MapKit)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Lobby = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

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
	Duel = Color3.fromRGB(0, 220, 255),
	RankedDuel = Color3.fromRGB(255, 176, 56),
	Duos = Color3.fromRGB(120, 255, 160),
	RankedDuos = Color3.fromRGB(255, 92, 92),
	Squads = Color3.fromRGB(170, 120, 255),
	FFA = Color3.fromRGB(255, 255, 255),
}

Lobby.PadColors = PAD_COLORS

local function plaza(kit)
	kit:Box(V(-120, -4, -90), V(120, 0, 90), { Name = "Plaza", Material = Enum.Material.Concrete, Color = Color3.fromRGB(150, 152, 156), Reflectance = 0.06 })
	for x = -110, 110, 20 do
		kit:Detail(V(0.25, 0.03, 180), CF(x, 0.02, 0), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 122, 126) })
	end
	for z = -80, 80, 20 do
		kit:Detail(V(240, 0.03, 0.25), CF(0, 0.02, z), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 122, 126) })
	end
	-- paredes externas (vidro + concreto)
	local wall = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(70, 72, 78) }
	kit:Box(V(-121, 0, -91), V(-120, 18, 91), wall)
	kit:Box(V(-120, 0, 90), V(120, 18, 91), wall)
	kit:Box(V(-120, 0, -91), V(120, 18, -90), wall)
	kit:Box(V(120, 0, 30), V(121, 18, 91), wall)
	kit:Box(V(120, 0, -91), V(121, 18, -30), wall)
	for _, z in { -90.6, 90.6 } do
		kit:Detail(V(236, 6, 0.3), CF(0, 11, z), { Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 180, 200), Transparency = 0.55, Reflectance = 0.2 })
	end
	-- bancos e floreiras
	for _, x in { -80, -40, 40, 80 } do
		kit:Box(V(x - 5, 0, -62), V(x + 5, 1.6, -58), { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(120, 90, 64) })
		kit:Box(V(x - 4, 0, 70), V(x + 4, 2.4, 78), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(100, 100, 104) })
		kit:Detail(V(7.4, 2, 7.4), CF(x, 3.2, 74), { Material = Enum.Material.LeafyGrass, Color = Color3.fromRGB(60, 110, 60) })
	end
end

local function monolith(kit)
	kit:Box(V(-30, 0, 66), V(30, 2, 74), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(40, 42, 46) })
	kit:Box(V(-28, 2, 70), V(28, 20, 72), { Material = Enum.Material.Slate, Color = Color3.fromRGB(26, 28, 32) })
	kit:Sign(V(52, 10, 0.4), CF(0, 13, 69.7), Config.Game.Name, {
		Background = Color3.fromRGB(14, 15, 18),
		Color = Color3.fromRGB(255, 255, 255),
		Glow = true,
		LightRange = 26,
		Font = Enum.Font.GothamBlack,
		PixelsPerStud = 20,
	})
	kit:Sign(V(40, 2.6, 0.4), CF(0, 5.6, 69.7), Config.Game.Tagline, {
		Background = Color3.fromRGB(14, 15, 18),
		Color = Color3.fromRGB(255, 196, 60),
		Font = Enum.Font.GothamMedium,
	})
end

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
			Color = Color3.fromRGB(36, 38, 42),
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
			Color = Color3.fromRGB(28, 30, 34),
		})
		kit:Light(ring, { Kind = "Point", Color = color, Range = 12, Brightness = 1 })
		result[modeId] = kit.Origin * cf
	end
	return result
end

local function range(kit)
	local folder = "Range"
	-- corredor do range (x 120..400, z −30..30)
	kit:Box(V(120, -4, -30), V(404, 0, 30), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(110, 106, 98), Folder = folder })
	kit:Box(V(120, 0, -31), V(404, 16, -30), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(80, 80, 84), Folder = folder })
	kit:Box(V(120, 0, 30), V(404, 16, 31), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(80, 80, 84), Folder = folder })
	kit:Box(V(400, 0, -31), V(404, 30, 31), { Material = Enum.Material.Ground, Color = Color3.fromRGB(110, 86, 60), Folder = folder }) -- barreira de terra
	-- linha de tiro com cabines
	kit:Box(V(126, 0, -30), V(127, 4, 30), { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(130, 98, 66), Folder = folder })
	for z = -30, 30, 12 do
		kit:Box(V(118, 0, z - 0.3), V(127, 8, z + 0.3), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(90, 90, 94), Folder = folder })
	end
	kit:Detail(V(0.2, 0.04, 60), CF(127.5, 0.02, 0), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 60, 40), Folder = folder })
	-- marcadores de distância
	for _, d in { 25, 50, 100, 150, 200, 260 } do
		local x = 127 + d
		kit:Detail(V(0.4, 0.05, 60), CF(x, 0.03, 0), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(200, 200, 196), Folder = folder })
		kit:Sign(V(8, 3, 0.4), CF(x, 13, -25.5) * CFrame.Angles(0, rad(90), 0), `{d}`, {
			Background = Color3.fromRGB(20, 20, 24),
			Color = Color3.fromRGB(255, 196, 60),
			Face = Enum.NormalId.Front,
		})
	end
	kit:Sign(V(30, 4, 0.4), CF(140, 12, 29.5), "RANGE · TREINO DE NO-SCOPE", {
		Background = Color3.fromRGB(20, 20, 24),
		Color = Color3.fromRGB(255, 255, 255),
		Glow = true,
	})
	-- luzes do range (só uma com sombra)
	for i, x in { 150, 230, 320 } do
		local lamp = kit:Detail(V(4, 0.4, 40), CF(x, 15.6, 0), { Material = Enum.Material.Neon, Color = Color3.fromRGB(230, 240, 255), Folder = folder })
		kit:Light(lamp, { Kind = "Surface", Face = Enum.NormalId.Bottom, Range = 22, Angle = 120, Brightness = 1.6, Shadows = i == 1 })
	end
	-- teto aberto com vigas
	for x = 140, 390, 25 do
		kit:Detail(V(1, 1.4, 62), CF(x, 16.6, 0), { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 62, 66), Folder = folder })
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
			kit:Detail(V(1, 0.2, 24), CF(x + 6, 0.1, zr), { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 64), Folder = "Range" })
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
			Color = Color3.fromRGB(230, 230, 226),
			Folder = "Range",
		})
		plate:SetAttribute("Distance", d)
		kit:Detail(V(0.3, 5, 0.3), CF(x + 1, 2.5, z + 5), { Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 50, 54), Folder = "Range" })
		table.insert(plates, plate)
	end
	return dummies, moving, plates
end

local function kiosk(kit): BasePart
	kit:Box(V(-74, 0, 22), V(-50, 1, 42), { Material = Enum.Material.Marble, Color = Color3.fromRGB(220, 220, 216) })
	local counter = kit:Box(V(-70, 1, 26), V(-54, 4.2, 30), { Name = "ShopCounter", Material = Enum.Material.Metal, Color = Color3.fromRGB(26, 28, 32) })
	kit:Box(V(-74, 1, 40), V(-50, 14, 42), { Material = Enum.Material.Slate, Color = Color3.fromRGB(30, 32, 36) })
	kit:Box(V(-75, 14, 22), V(-49, 15, 42), { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 46) })
	kit:Sign(V(18, 3.4, 0.4), CF(-62, 11, 39.7), "ARSENAL · LOJA", {
		Background = Color3.fromRGB(14, 15, 18),
		Color = Color3.fromRGB(255, 176, 56),
		Glow = true,
	})
	for _, x in { -74.5, -49.5 } do
		kit:Box(V(x - 0.5, 1, 22), V(x + 0.5, 14, 23), { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 42, 46) })
	end
	return counter
end

local function board(kit): BasePart
	kit:Box(V(-100, 0, -40), V(-96, 2, 0), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(40, 42, 46) })
	local panel = kit:Block(V(1, 22, 36), CF(-98, 13, -20), { Name = "Leaderboard", Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(14, 15, 18) })
	return panel
end

function Lobby.Build(origin: CFrame): (MapKit.BuiltMap, Extras)
	local kit = MapKit.new("Lobby", origin, 1)
	plaza(kit)
	monolith(kit)
	local padCFrames = pads(kit)
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
