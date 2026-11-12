--[[
	MapKit — vocabulário para construir mapas com Parts, materiais nativos e Terrain.

	Todo mapa do OFFSCOPE é código: dá para revisar num PR, gerar variações com semente e
	carregar só o mapa da partida (os outros nunca existem na memória).

	Regras de performance embutidas:
	  • Estrutura (piso, paredes, cobertura): colide, bloqueia tiro (CanQuery), projeta sombra.
	  • Detalhe (Detail): não colide, não bloqueia tiro, SEM sombra.
	  • Luz com sombra só quando pedida explicitamente (`Shadows = true`).
]]

local Workspace = game:GetService("Workspace")

local MapKit = {}
MapKit.__index = MapKit

export type Spawns = { A: { CFrame }, B: { CFrame }, FFA: { CFrame } }

export type Kit = typeof(setmetatable(
	{} :: {
		Model: Model,
		Origin: CFrame,
		Rng: Random,
		Spawns: Spawns,
		TerrainRegions: { { CFrame: CFrame, Size: Vector3 } },
		Lights: { Light },
	},
	MapKit
))

local V = Vector3.new
local CF = CFrame.new

function MapKit.new(name: string, origin: CFrame, seed: number): Kit
	local model = Instance.new("Model")
	model.Name = name
	local self = setmetatable({
		Model = model,
		Origin = origin,
		Rng = Random.new(seed),
		Spawns = { A = {}, B = {}, FFA = {} },
		TerrainRegions = {},
		Lights = {},
	}, MapKit)
	return self
end

function MapKit:Folder(name: string): Folder
	local existing = self.Model:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = self.Model
	return folder
end

export type BlockOptions = {
	Name: string?,
	Material: Enum.Material?,
	Color: Color3?,
	Transparency: number?,
	Reflectance: number?,
	Detail: boolean?, -- sem colisão/sombra/tiro
	Collide: boolean?,
	Shadow: boolean?,
	Shape: Enum.PartType?,
	Wedge: boolean?,
	Folder: string?,
	Truss: boolean?,
}

-- Bloco em coordenadas LOCAIS do mapa.
function MapKit:Block(size: Vector3, localCFrame: CFrame, options: BlockOptions?): BasePart
	local opts = options or {}
	local part: BasePart
	if opts.Truss then
		local truss = Instance.new("TrussPart")
		truss.Style = Enum.Style.AlternatingSupports
		part = truss
	elseif opts.Wedge then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		if opts.Shape then
			p.Shape = opts.Shape
		end
		part = p
	end
	part.Name = opts.Name or "Block"
	part.Size = size
	part.CFrame = self.Origin * localCFrame
	part.Anchored = true
	part.Material = opts.Material or Enum.Material.Concrete
	part.Color = opts.Color or Color3.fromRGB(120, 120, 120)
	part.Transparency = opts.Transparency or 0
	part.Reflectance = opts.Reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	if opts.Detail then
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
	else
		part.CanCollide = opts.Collide ~= false
		part.CastShadow = opts.Shadow ~= false
	end
	part.Parent = if opts.Folder then self:Folder(opts.Folder) else self.Model
	return part
end

-- Atalho: bloco de min..max (cantos) — fácil de ler em planta baixa.
function MapKit:Box(min: Vector3, max: Vector3, options: BlockOptions?): BasePart
	local size = V(math.abs(max.X - min.X), math.abs(max.Y - min.Y), math.abs(max.Z - min.Z))
	return self:Block(size, CF((min + max) / 2), options)
end

function MapKit:Detail(size: Vector3, localCFrame: CFrame, options: BlockOptions?): BasePart
	local opts = table.clone(options or {})
	opts.Detail = true
	return self:Block(size, localCFrame, opts)
end

-- Parede invisível de limite (bloqueia movimento, não bloqueia tiro nem aparece).
function MapKit:Barrier(min: Vector3, max: Vector3)
	local part = self:Box(min, max, { Name = "Barrier", Transparency = 1, Folder = "Bounds", Shadow = false })
	part.CanQuery = false
	return part
end

export type LightOptions = {
	Kind: string?, -- "Point" | "Spot" | "Surface"
	Color: Color3?,
	Range: number?,
	Brightness: number?,
	Shadows: boolean?,
	Angle: number?,
	Face: Enum.NormalId?,
}

function MapKit:Light(holder: BasePart, options: LightOptions?): Light
	local opts = options or {}
	local light: Light
	if opts.Kind == "Spot" then
		local spot = Instance.new("SpotLight")
		spot.Angle = opts.Angle or 80
		spot.Face = opts.Face or Enum.NormalId.Bottom
		light = spot
	elseif opts.Kind == "Surface" then
		local surface = Instance.new("SurfaceLight")
		surface.Angle = opts.Angle or 90
		surface.Face = opts.Face or Enum.NormalId.Bottom
		light = surface
	else
		light = Instance.new("PointLight")
	end
	light.Color = opts.Color or Color3.fromRGB(255, 220, 180)
	;(light :: any).Range = opts.Range or 24
	light.Brightness = opts.Brightness or 1.5
	light.Shadows = opts.Shadows == true
	light:SetAttribute("Secondary", opts.Shadows ~= true)
	light.Parent = holder
	table.insert(self.Lights, light)
	return light
end

function MapKit:Spawn(team: string, localPosition: Vector3, lookAt: Vector3)
	local cf = self.Origin * CFrame.lookAt(localPosition + V(0, 3, 0), V(lookAt.X, localPosition.Y + 3, lookAt.Z))
	table.insert((self.Spawns :: any)[team], cf)
	if team ~= "FFA" then
		table.insert(self.Spawns.FFA, cf)
	end
end

-- Placa com texto (neon, sinalização). Face frontal = −Z do bloco.
function MapKit:Sign(size: Vector3, localCFrame: CFrame, text: string, options: { [string]: any }?)
	local opts = options or {}
	local board = self:Block(size, localCFrame, {
		Name = "Sign",
		Material = opts.Material or Enum.Material.SmoothPlastic,
		Color = opts.Background or Color3.fromRGB(16, 16, 20),
		Detail = opts.Collide ~= true,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = opts.Face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.PixelsPerStud or 24
	gui.LightInfluence = if opts.Glow then 0 else 1
	gui.Brightness = if opts.Glow then 2.2 else 1
	gui.MaxDistance = opts.MaxDistance or 400
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = opts.Font or Enum.Font.GothamBlack
	label.TextColor3 = opts.Color or Color3.fromRGB(255, 255, 255)
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = label
	gui.Parent = board
	if opts.Glow then
		self:Light(board, { Kind = "Surface", Face = gui.Face, Color = opts.Color, Range = opts.LightRange or 14, Brightness = 1.2 })
	end
	return board
end

-- ── props reutilizáveis ─────────────────────────────────────────────────────

local CONTAINER_COLORS = {
	Color3.fromRGB(142, 52, 38), -- ferrugem
	Color3.fromRGB(40, 78, 120), -- azul
	Color3.fromRGB(56, 96, 64), -- verde
	Color3.fromRGB(196, 110, 36), -- laranja
	Color3.fromRGB(110, 112, 116), -- cinza
	Color3.fromRGB(198, 196, 186), -- branco sujo
	Color3.fromRGB(150, 34, 44), -- vermelho
}

-- Container de 40 pés (≈ 20 × 8.5 × 8 studs) com nervuras, portas e travas.
function MapKit:Container(localCFrame: CFrame, color: Color3?, detailed: boolean?): BasePart
	local c = color or CONTAINER_COLORS[self.Rng:NextInteger(1, #CONTAINER_COLORS)]
	local size = V(8, 8.5, 20)
	local body = self:Block(size, localCFrame, { Name = "Container", Material = Enum.Material.CorrodedMetal, Color = c, Folder = "Containers" })
	if detailed ~= false then
		local dark = c:Lerp(Color3.new(0, 0, 0), 0.25)
		for i = -4, 4 do
			self:Detail(V(8.15, 7.9, 0.35), localCFrame * CF(0, 0, i * 2.1), { Material = Enum.Material.CorrodedMetal, Color = dark, Folder = "Containers" })
		end
		-- portas (fundo +Z) e travas
		self:Detail(V(7.6, 7.8, 0.2), localCFrame * CF(0, 0, 10.05), { Material = Enum.Material.Metal, Color = dark, Folder = "Containers" })
		for _, x in { -1.4, 1.4 } do
			self:Detail(V(0.14, 7.6, 0.14), localCFrame * CF(x, 0, 10.2), { Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 62), Folder = "Containers" })
		end
		-- cantoneiras
		for _, x in { -3.9, 3.9 } do
			for _, z in { -9.9, 9.9 } do
				self:Detail(V(0.4, 8.6, 0.4), localCFrame * CF(x, 0, z), { Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 42), Folder = "Containers" })
			end
		end
	end
	return body
end

function MapKit:ContainerColor(): Color3
	return CONTAINER_COLORS[self.Rng:NextInteger(1, #CONTAINER_COLORS)]
end

-- Poça d'água: lâmina fina escura e reflexiva (o Realistic lighting faz o resto).
function MapKit:Puddle(localPosition: Vector3, width: number, depth: number)
	local part = self:Block(V(width, 0.05, depth), CF(localPosition + V(0, 0.03, 0)) * CFrame.Angles(0, self.Rng:NextNumber() * math.pi, 0), {
		Name = "Puddle",
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(26, 30, 36),
		Reflectance = 0.32,
		Transparency = 0.15,
		Detail = true,
		Folder = "Puddles",
	})
	return part
end

-- Poste de luz. `shadows` só nos que importam para a leitura do mapa.
function MapKit:StreetLamp(localPosition: Vector3, facing: Vector3, color: Color3?, shadows: boolean?)
	local pole = self:Block(V(0.6, 16, 0.6), CF(localPosition + V(0, 8, 0)), {
		Name = "LampPole",
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(46, 48, 52),
		Shape = Enum.PartType.Block,
		Folder = "Lamps",
	})
	pole.CastShadow = false
	local dir = (facing * V(1, 0, 1)).Unit
	local armCF = CFrame.lookAt(localPosition + V(0, 15.6, 0), localPosition + V(0, 15.6, 0) + dir) * CF(0, 0, -1.8)
	self:Detail(V(0.35, 0.35, 3.6), armCF, { Material = Enum.Material.Metal, Color = Color3.fromRGB(46, 48, 52), Folder = "Lamps" })
	local head = self:Detail(V(1.4, 0.4, 0.8), armCF * CF(0, -0.3, -1.6), {
		Name = "LampHead",
		Material = Enum.Material.Neon,
		Color = color or Color3.fromRGB(255, 214, 160),
		Folder = "Lamps",
	})
	self:Light(head, { Kind = "Spot", Face = Enum.NormalId.Bottom, Angle = 110, Range = 36, Brightness = 2.4, Color = color, Shadows = shadows })
	return pole
end

-- Pinheiro: tronco + 4 camadas cônicas aproximadas por cilindros achatados.
function MapKit:Pine(localPosition: Vector3, height: number)
	local trunk = self:Block(V(height * 0.55, 1.1, 1.1), CF(localPosition + V(0, height * 0.27, 0)) * CFrame.Angles(0, 0, math.rad(90)), {
		Name = "Trunk",
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(78, 58, 42),
		Shape = Enum.PartType.Cylinder,
		Folder = "Vegetation",
	})
	trunk.CastShadow = true
	local green = Color3.fromRGB(46, 70, 44):Lerp(Color3.fromRGB(70, 86, 52), self.Rng:NextNumber())
	for layer = 0, 3 do
		local t = layer / 3
		local radius = (1 - t * 0.7) * height * 0.22
		local y = height * (0.32 + t * 0.55)
		local disc = self:Block(V(height * 0.18, radius * 2, radius * 2), CF(localPosition + V(0, y, 0)) * CFrame.Angles(0, self.Rng:NextNumber() * 6, math.rad(90)), {
			Name = "Foliage",
			Material = Enum.Material.LeafyGrass,
			Color = green,
			Shape = Enum.PartType.Cylinder,
			Folder = "Vegetation",
		})
		disc.CanCollide = layer == 0
	end
	return trunk
end

-- Rocha: dois blocos rotacionados de basalto/pedra (cobertura de meia distância).
function MapKit:Rock(localPosition: Vector3, size: number)
	local material = if self.Rng:NextNumber() > 0.5 then Enum.Material.Rock else Enum.Material.Slate
	local color = Color3.fromRGB(108, 100, 92):Lerp(Color3.fromRGB(140, 132, 120), self.Rng:NextNumber())
	for i = 1, 2 do
		local s = size * (if i == 1 then 1 else 0.7)
		self:Block(V(s * 1.3, s, s * 1.1), CF(localPosition + V(0, s * 0.35, 0) + V(i * s * 0.3, 0, -i * s * 0.2)) * CFrame.Angles(
			self.Rng:NextNumber() * 0.6,
			self.Rng:NextNumber() * 6,
			self.Rng:NextNumber() * 0.6
		), { Name = "Rock", Material = material, Color = color, Folder = "Rocks" })
	end
end

-- Carro sedã low-poly (cobertura baixa).
function MapKit:Car(localCFrame: CFrame, color: Color3)
	local folder = "Vehicles"
	self:Block(V(6.4, 2.2, 13), localCFrame * CF(0, 1.9, 0), { Name = "CarBody", Material = Enum.Material.Metal, Color = color, Reflectance = 0.08, Folder = folder })
	self:Block(V(5.8, 2, 6.6), localCFrame * CF(0, 3.9, 0.6), { Name = "CarCabin", Material = Enum.Material.Metal, Color = color, Folder = folder })
	self:Detail(V(5.9, 1.6, 6.2), localCFrame * CF(0, 3.95, 0.6), { Material = Enum.Material.Glass, Color = Color3.fromRGB(20, 26, 34), Reflectance = 0.25, Transparency = 0.2, Folder = folder })
	for _, x in { -2.9, 2.9 } do
		for _, z in { -4.2, 4.2 } do
			self:Detail(V(1, 2.4, 2.4), localCFrame * CF(x, 1.2, z) * CFrame.Angles(0, 0, 0), {
				Material = Enum.Material.Rubber,
				Color = Color3.fromRGB(22, 22, 24),
				Shape = Enum.PartType.Cylinder,
				Folder = folder,
			})
		end
	end
	local lights = self:Detail(V(5.6, 0.5, 0.2), localCFrame * CF(0, 2.4, -6.55), { Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 246, 220), Folder = folder })
	lights.Name = "Headlights"
	self:Detail(V(5.6, 0.4, 0.2), localCFrame * CF(0, 2.5, 6.55), { Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 20, 30), Folder = folder })
end

-- Caixote / pallet com textura de madeira.
function MapKit:Crate(localCFrame: CFrame, size: number?)
	local s = size or 4
	return self:Block(V(s, s, s), localCFrame * CF(0, s / 2, 0), { Name = "Crate", Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 116, 76), Folder = "Props" })
end

function MapKit:Barrel(localPosition: Vector3, color: Color3?)
	return self:Block(V(3.6, 2.6, 2.6), CF(localPosition + V(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), {
		Name = "Barrel",
		Material = Enum.Material.Metal,
		Color = color or Color3.fromRGB(40, 70, 120),
		Shape = Enum.PartType.Cylinder,
		Folder = "Props",
	})
end

-- Escada (wedge) de min.Y até max.Y ao longo de `direction` (+Z local por padrão).
function MapKit:Ramp(localCFrame: CFrame, width: number, height: number, length: number, options: BlockOptions?)
	local opts = table.clone(options or {})
	opts.Wedge = true
	opts.Name = opts.Name or "Ramp"
	return self:Block(V(width, height, length), localCFrame * CF(0, height / 2, 0), opts)
end

--[[
	Escada de degraus sólidos (sem ambiguidade de orientação de wedge).
	`base` é o pé da escada (centro do 1º degrau no chão), `direction` é para onde ela sobe.
]]
function MapKit:Stairs(base: Vector3, direction: Vector3, width: number, rise: number, steps: number, options: BlockOptions?)
	local opts = table.clone(options or {})
	opts.Name = opts.Name or "Step"
	opts.Material = opts.Material or Enum.Material.DiamondPlate
	opts.Color = opts.Color or Color3.fromRGB(96, 98, 102)
	local dir = (direction * V(1, 0, 1)).Unit
	local stepRise = rise / steps
	local run = math.max(1.1, stepRise * 1.25)
	for i = 1, steps do
		local h = stepRise * i
		local center = base + dir * (run * (i - 0.5)) + V(0, h / 2, 0)
		self:Block(V(width, h, run), CFrame.lookAt(center, center + dir), opts)
	end
	return run * steps
end

-- Corrimão simples (detalhe) entre dois pontos locais.
function MapKit:Rail(a: Vector3, b: Vector3, color: Color3?)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	self:Detail(V(0.18, 0.18, length), CFrame.lookAt(mid, b), { Material = Enum.Material.Metal, Color = color or Color3.fromRGB(200, 170, 40), Folder = "Rails" })
end

-- ── Terrain ──────────────────────────────────────────────────────────────────

function MapKit:TerrainBlock(localCFrame: CFrame, size: Vector3, material: Enum.Material)
	local cf = self.Origin * localCFrame
	Workspace.Terrain:FillBlock(cf, size, material)
end

-- Marca uma região para limpar quando o mapa descarregar.
function MapKit:ClaimTerrain(localCenter: Vector3, size: Vector3)
	table.insert(self.TerrainRegions, { CFrame = self.Origin * CF(localCenter), Size = size })
end

function MapKit:ClearTerrain()
	for _, region in self.TerrainRegions do
		Workspace.Terrain:FillBlock(region.CFrame, region.Size, Enum.Material.Air)
	end
end

export type BuiltMap = {
	Model: Model,
	Spawns: Spawns,
	Cleanup: () -> (),
	KillY: number,
}

function MapKit:Finish(killY: number): BuiltMap
	self.Model.Parent = Workspace:FindFirstChild("Maps") or (function()
		local folder = Instance.new("Folder")
		folder.Name = "Maps"
		folder.Parent = Workspace
		return folder
	end)()
	return {
		Model = self.Model,
		Spawns = self.Spawns,
		KillY = self.Origin.Y + killY,
		Cleanup = function()
			self:ClearTerrain()
			self.Model:Destroy()
		end,
	}
end

return MapKit
