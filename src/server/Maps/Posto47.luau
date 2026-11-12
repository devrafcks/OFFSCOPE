--[[
	POSTO 47 — posto de fronteira num vale de serra, golden hour.

	Terreno de verdade (Terrain:WriteVoxels com heightmap suave por ruído):
	  • fundo do vale plano com a ESTRADA DE TERRA (lane mais longa do jogo, ~400 studs)
	  • encostas de grama seca e rocha, pinheiros, pedras de meia distância
	Construções: posto de controle no meio, hangar ao norte, bunkers, torres de vigia
	nos spawns (A oeste, B leste), barragem ao fundo (cenário).
]]

local Workspace = game:GetService("Workspace")

local MapKit = require(script.Parent.MapKit)

local Posto47 = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

local HALF_X = 220
local HALF_Z = 152
local MIN_Y = -8
local MAX_Y = 72
local RES = 4
local SEED = 47

-- curva suave da estrada
local function roadZ(x: number): number
	return 7 * math.sin(x / 62)
end

-- áreas niveladas para construções (x0, x1, z0, z1)
local FLAT = {
	{ -72, -2, 22, 78 }, -- hangar
	{ -104, -76, -56, -26 }, -- bunker oeste
	{ 76, 104, -56, -26 }, -- bunker leste
	{ 104, 136, 28, 58 }, -- bunker norte
	{ -196, -150, -44, 44 }, -- base A
	{ 150, 196, -44, 44 }, -- base B
	{ 46, 74, 40, 64 }, -- torre central
}

local function flatWeight(x: number, z: number): number
	local best = 0
	for _, r in FLAT do
		local dx = math.max(r[1] - x, 0, x - r[2])
		local dz = math.max(r[3] - z, 0, z - r[4])
		local d = math.sqrt(dx * dx + dz * dz)
		best = math.max(best, 1 - math.clamp(d / 14, 0, 1))
	end
	return best
end

local function heightAt(x: number, z: number): number
	local d = math.abs(z - roadZ(x))
	local h: number
	if d < 26 then
		h = math.noise(x / 30, z / 30, SEED) * 0.6
	else
		local edge = d - 26
		h = edge ^ 1.25 * 0.26
		h += math.noise(x / 46, z / 46, SEED + 1) * 7 * math.min(1, edge / 30)
		h += math.noise(x / 14, z / 14, SEED + 2) * 1.4 * math.min(1, edge / 20)
	end
	-- montes nas pontas do vale: fecham a visão lá longe
	local endRise = math.max(0, math.abs(x) - 205) * 0.9
	h += endRise
	local w = flatWeight(x, z)
	h = h * (1 - w)
	return math.clamp(h, -2, MAX_Y - 6)
end

Posto47.HeightAt = heightAt

local function terrain(kit)
	local terrainService = Workspace.Terrain
	terrainService:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(150, 140, 82))
	terrainService:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 98, 72))
	terrainService:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(118, 110, 102))
	terrainService:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(98, 80, 62))

	local origin = kit.Origin.Position
	local region = Region3.new(origin + V(-HALF_X, MIN_Y, -HALF_Z), origin + V(HALF_X, MAX_Y, HALF_Z)):ExpandToGrid(RES)
	local size = region.Size / RES
	local nx, ny, nz = math.floor(size.X + 0.5), math.floor(size.Y + 0.5), math.floor(size.Z + 0.5)
	local minCorner = region.CFrame.Position - region.Size / 2

	local materials = table.create(nx)
	local occupancy = table.create(nx)
	for ix = 1, nx do
		local mx = table.create(ny)
		local ox = table.create(ny)
		for iy = 1, ny do
			mx[iy] = table.create(nz, Enum.Material.Air)
			ox[iy] = table.create(nz, 0)
		end
		materials[ix] = mx
		occupancy[ix] = ox
	end

	for ix = 1, nx do
		local wx = minCorner.X + (ix - 0.5) * RES - origin.X
		for iz = 1, nz do
			local wz = minCorner.Z + (iz - 0.5) * RES - origin.Z
			local h = heightAt(wx, wz)
			local d = math.abs(wz - roadZ(wx))
			-- inclinação aproximada
			local slope = math.abs(heightAt(wx + RES, wz) - h) + math.abs(heightAt(wx, wz + RES) - h)
			local surface: Enum.Material
			if d < 8 and math.abs(wx) < 205 then
				surface = if math.noise(wx / 9, wz / 9, 3) > 0.25 then Enum.Material.Mud else Enum.Material.Ground
			elseif slope > 5.5 or h > 34 then
				surface = Enum.Material.Rock
			elseif h > 18 or math.noise(wx / 20, wz / 20, 9) > 0.35 then
				surface = Enum.Material.Ground
			else
				surface = Enum.Material.Grass
			end
			for iy = 1, ny do
				local y0 = minCorner.Y + (iy - 1) * RES - origin.Y
				local fill = math.clamp((h - y0) / RES, 0, 1)
				if fill > 0 then
					occupancy[ix][iy][iz] = fill
					materials[ix][iy][iz] = if h - y0 > 8 then Enum.Material.Rock else surface
				end
			end
		end
	end

	terrainService:WriteVoxels(region, RES, materials, occupancy)
	kit:ClaimTerrain(V(0, (MIN_Y + MAX_Y) / 2, 0), V(HALF_X * 2 + 8, MAX_Y - MIN_Y + 8, HALF_Z * 2 + 8))
end

local function at(x: number, z: number): Vector3
	return V(x, heightAt(x, z), z)
end

local function checkpoint(kit)
	local folder = "Checkpoint"
	local z = roadZ(0)
	-- guarita
	kit:Box(V(-6, 0, z - 20), V(4, 9, z - 12), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(196, 190, 176), Folder = folder })
	kit:Box(V(-7, 9, z - 21), V(5, 10, z - 11), { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 40, 36), Folder = folder })
	kit:Detail(V(10.2, 2.6, 0.2), CF(-1, 5.5, z - 11.9), { Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 180, 200), Transparency = 0.5, Folder = folder })
	kit:Sign(V(10, 2.4, 0.4), CF(-1, 12, z - 16), "POSTO 47", { Background = Color3.fromRGB(20, 40, 30), Color = Color3.fromRGB(240, 232, 200), Collide = false })
	-- cancela e barreiras
	kit:Block(V(1, 4, 1), CF(4.6, 2, z - 9), { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 60), Folder = folder })
	for i = 0, 5 do
		kit:Detail(V(3, 0.5, 0.5), CF(4.6, 3.6, z - 7.5 + i * 3) * CFrame.Angles(0, rad(90), 0), {
			Material = Enum.Material.SmoothPlastic,
			Color = if i % 2 == 0 then Color3.fromRGB(220, 40, 40) else Color3.fromRGB(240, 240, 240),
			Folder = folder,
		})
	end
	for _, spec in { { -20, -6 }, { -20, 6 }, { 20, -2 }, { 24, 8 } } do
		kit:Block(V(1.6, 3.2, 8), CF(spec[1], 1.6, z + spec[2]), { Name = "Barrier", Material = Enum.Material.Concrete, Color = Color3.fromRGB(170, 166, 156), Folder = folder })
	end
	-- sacos de areia
	for i = 0, 6 do
		kit:Block(V(3.4, 1.4, 1.8), CF(-14 + i * 3.5, 0.7 + (i % 2) * 0.1, z + 15), { Name = "Sandbag", Material = Enum.Material.Fabric, Color = Color3.fromRGB(150, 130, 96), Folder = folder })
		if i % 2 == 0 then
			kit:Block(V(3.4, 1.4, 1.8), CF(-12.3 + i * 3.5, 2.1, z + 15), { Name = "Sandbag", Material = Enum.Material.Fabric, Color = Color3.fromRGB(140, 122, 90), Folder = folder })
		end
	end
	-- mastro
	kit:Block(V(0.4, 20, 0.4), CF(-12, 10, z - 16), { Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 200, 200), Folder = folder })
	kit:Detail(V(0.1, 3, 5), CF(-12, 18, z - 13.5), { Material = Enum.Material.Fabric, Color = Color3.fromRGB(40, 110, 70), Folder = folder })
	local lamp = kit:Detail(V(1.2, 0.4, 1.2), CF(-1, 8.6, z - 16), { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 170), Folder = folder })
	kit:Light(lamp, { Kind = "Point", Range = 20, Brightness = 1.2 })
end

local function hangar(kit)
	local folder = "Hangar"
	local metal = { Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(112, 118, 104), Folder = folder }
	kit:Box(V(-66, -1, 30), V(-8, 0.4, 72), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(120, 118, 110), Folder = folder })
	-- arco aproximado por segmentos
	local span = 58
	local radius = 22
	for i = 0, 8 do
		local a0 = rad(i * 20)
		local a1 = rad((i + 1) * 20)
		local p0 = V(math.cos(a0) * radius, math.sin(a0) * radius, 0)
		local p1 = V(math.cos(a1) * radius, math.sin(a1) * radius, 0)
		local mid = (p0 + p1) / 2
		local length = (p1 - p0).Magnitude + 0.4
		local cf = CF(V(-37, 0.4, 51) + V(0, mid.Y, mid.X)) * CFrame.Angles(-math.atan2(p1.Y - p0.Y, p1.X - p0.X), 0, 0)
		kit:Block(V(span, 1, length), cf, metal)
	end
	-- parede do fundo (norte) e laterais baixas; frente aberta para a estrada
	kit:Box(V(-66, 0.4, 72), V(-8, 20, 73), metal)
	-- interior: caixas e um caminhão
	kit:Box(V(-54, 0.4, 44), V(-40, 9, 64), { Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 80, 60), Folder = folder })
	kit:Box(V(-54, 9, 44), V(-40, 12, 52), { Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 80, 60), Folder = folder })
	kit:Crate(CF(-26, 0.4, 60), 5)
	kit:Crate(CF(-20, 0.4, 62), 4)
	kit:Crate(CF(-24, 5.4, 61), 3.6)
	kit:Crate(CF(-30, 0.4, 40), 4)
	local lamp = kit:Detail(V(3, 0.4, 3), CF(-37, 21, 52), { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 190), Folder = folder })
	kit:Light(lamp, { Kind = "Point", Range = 34, Brightness = 1.4, Color = Color3.fromRGB(255, 220, 180), Shadows = true })
end

local function bunker(kit, x: number, z: number, facing: number)
	local folder = "Bunkers"
	local concrete = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(132, 128, 118), Folder = folder }
	-- base 16 × 12, seteiras de 1.4 de altura
	local f = CF(x, 0, z) * CFrame.Angles(0, rad(facing), 0)
	kit:Block(V(16, 4, 1.2), f * CF(0, 2, -6), concrete)
	kit:Block(V(16, 1.6, 1.2), f * CF(0, 6.2, -6), concrete)
	kit:Block(V(1.2, 7, 12), f * CF(-8, 3.5, 0), concrete)
	kit:Block(V(1.2, 7, 12), f * CF(8, 3.5, 0), concrete)
	kit:Block(V(10, 7, 1.2), f * CF(-3, 3.5, 6), concrete)
	kit:Block(V(17.6, 1.4, 13.6), f * CF(0, 7.7, 0), concrete)
	kit:Block(V(16, 0.4, 12), f * CF(0, 0.2, 0), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(100, 98, 92), Folder = folder })
end

local function watchtower(kit, base: Vector3)
	local folder = "Towers"
	local wood = { Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 84, 58), Folder = folder }
	for _, dx in { -4, 4 } do
		for _, dz in { -4, 4 } do
			kit:Block(V(1, 18, 1), CF(base + V(dx, 9, dz)), wood)
		end
	end
	kit:Block(V(10, 0.8, 10), CF(base + V(0, 18, 0)), { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(130, 100, 70), Folder = folder })
	for _, side in { V(0, 0, -5), V(0, 0, 5), V(-5, 0, 0), V(5, 0, 0) } do
		local horizontal = math.abs(side.X) > 0
		kit:Block(if horizontal then V(0.5, 3, 10) else V(10, 3, 0.5), CF(base + side + V(0, 19.9, 0)), wood)
	end
	kit:Block(V(11, 0.6, 11), CF(base + V(0, 25, 0)), { Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(90, 96, 84), Folder = folder })
	for _, dx in { -4.8, 4.8 } do
		for _, dz in { -4.8, 4.8 } do
			kit:Detail(V(0.4, 6, 0.4), CF(base + V(dx, 22, dz)), wood)
		end
	end
	kit:Block(V(1.4, 18.4, 1.4), CF(base + V(0, 9.2, 5.4)), { Truss = true, Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 60), Folder = folder })
	local lamp = kit:Detail(V(1, 1, 1), CF(base + V(0, 24, 0)), { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 210, 150), Folder = folder })
	kit:Light(lamp, { Kind = "Point", Range = 16, Brightness = 1 })
end

local function nature(kit)
	-- pedras de meia distância perto da estrada (cobertura do mid)
	local rockSpots = { -150, -128, -112, -64, -40, 36, 58, 118, 140, 162 }
	for i, x in rockSpots do
		local side = if i % 2 == 0 then 1 else -1
		local z = roadZ(x) + side * kit.Rng:NextNumber(12, 22)
		kit:Rock(at(x, z), kit.Rng:NextNumber(3.5, 6))
	end
	-- pinheiros nas encostas (fora das lanes)
	local planted = 0
	local attempts = 0
	while planted < 70 and attempts < 400 do
		attempts += 1
		local x = kit.Rng:NextNumber(-200, 200)
		local z = kit.Rng:NextNumber(-140, 140)
		local d = math.abs(z - roadZ(x))
		if d > 32 and flatWeight(x, z) < 0.1 then
			local h = heightAt(x, z)
			kit:Pine(V(x, h - 0.5, z), kit.Rng:NextNumber(20, 34))
			planted += 1
		end
	end
	-- cerca de fronteira (postes ao longo da encosta sul)
	for x = -190, 190, 12 do
		local z = -92
		local p = at(x, z)
		kit:Block(V(0.4, 7, 0.4), CF(p + V(0, 3.5, 0)), { Material = Enum.Material.Metal, Color = Color3.fromRGB(90, 92, 94), Folder = "Fence" })
		kit:Detail(V(12, 5, 0.1), CF(p + V(6, 4, 0)), { Material = Enum.Material.Fabric, Color = Color3.fromRGB(120, 124, 128), Transparency = 0.75, Folder = "Fence" })
	end
	-- barragem ao fundo (cenário, fora do limite)
	kit:Box(V(250, -10, -150), V(264, 80, 150), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(176, 172, 162), Folder = "Dam", Shadow = true })
	for z = -140, 140, 20 do
		kit:Detail(V(1, 90, 3), CF(249.5, 35, z), { Material = Enum.Material.Concrete, Color = Color3.fromRGB(150, 146, 136), Folder = "Dam" })
	end
end

local function bounds(kit)
	kit:Barrier(V(-210, -10, -100), V(-205, 110, 100))
	kit:Barrier(V(205, -10, -100), V(210, 110, 100))
	kit:Barrier(V(-210, -10, -104), V(210, 110, -100))
	kit:Barrier(V(-210, -10, 100), V(210, 110, 104))
	kit:Barrier(V(-210, 109, -104), V(210, 112, 104))
end

local function spawns(kit)
	for _, dz in { -14, -4, 6, 16 } do
		kit:Spawn("A", V(-176, 0, roadZ(-176) + dz), V(0, 0, 0))
		kit:Spawn("B", V(176, 0, roadZ(176) + dz), V(0, 0, 0))
	end
	for _, p in { V(-37, 0.4, 50), V(90, 0, -41), V(-90, 0, -41), V(120, 0, 43), V(0, 0, 18), V(60, 0, 52) } do
		kit:Spawn("FFA", p, V(0, 0, 0))
	end
end

function Posto47.Build(origin: CFrame): MapKit.BuiltMap
	local kit = MapKit.new("Posto47", origin, SEED)
	terrain(kit)
	checkpoint(kit)
	hangar(kit)
	bunker(kit, -90, -41, 0)
	bunker(kit, 90, -41, 0)
	bunker(kit, 120, 43, 180)
	watchtower(kit, V(-178, 0, 30))
	watchtower(kit, V(178, 0, -30))
	watchtower(kit, V(60, 0, 52))
	nature(kit)
	bounds(kit)
	spawns(kit)
	return kit:Finish(-12)
end

return Posto47
