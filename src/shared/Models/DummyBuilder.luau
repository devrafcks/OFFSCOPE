--[[
	DummyBuilder — veste um rig R15 como boneco de treino do estande:
	capacete laranja com viseira, colete com alvo no peito, cinto, joelheiras, botas
	e um suporte (poste + base) preso ao HumanoidRootPart.

	Tudo é decoração: Massless, sem colisão, sem query e sem toque — as hitboxes continuam
	sendo as partes do rig (Hitbox.TrackedParts), e o raycast do mundo já ignora o modelo
	inteiro de quem é rastreado pela LagCompensation.
]]

local DummyBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

local BODY = Color3.fromRGB(176, 182, 190)
local BODY_DARK = Color3.fromRGB(128, 134, 144)
local GEAR = Color3.fromRGB(50, 54, 60)
local GEAR_LIGHT = Color3.fromRGB(70, 75, 82)
local ORANGE = Color3.fromRGB(236, 122, 38)
local VISOR = Color3.fromRGB(14, 16, 20)
local WHITE = Color3.fromRGB(236, 234, 228)
local RED = Color3.fromRGB(212, 52, 46)
local STEEL = Color3.fromRGB(84, 88, 94)

type Spec = {
	Name: string,
	Size: Vector3,
	Offset: CFrame,
	Color: Color3,
	Shape: Enum.PartType?,
	Material: Enum.Material?,
	Reflectance: number?,
}

local function attach(model: Model, host: BasePart, spec: Spec): BasePart
	local part = Instance.new("Part")
	part.Name = spec.Name
	if spec.Shape then
		part.Shape = spec.Shape
	end
	part.Size = spec.Size
	part.CFrame = host.CFrame * spec.Offset
	part.Color = spec.Color
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.Reflectance = spec.Reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- disco com a face voltada para −Z local do host (frente do R15)
local function disc(model: Model, host: BasePart, name: string, diameter: number, thickness: number, offset: Vector3, color: Color3)
	attach(model, host, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = V(thickness, diameter, diameter),
		Offset = CF(offset) * CFrame.Angles(0, rad(90), 0),
		Color = color,
	})
end

local function part(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

function DummyBuilder.Dress(model: Model)
	-- corpo de manequim fosco, sem rosto
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			child.Color = if child.Name:find("Hand") or child.Name:find("Foot") then BODY_DARK else BODY
			child.Material = Enum.Material.SmoothPlastic
		elseif child:IsA("Decal") and child.Parent and child.Parent.Name == "Head" then
			child:Destroy() -- rosto: a viseira faz esse papel
		end
	end
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end

	local head = part(model, "Head")
	if head then
		local s = head.Size
		attach(model, head, { Name = "Helmet", Shape = Enum.PartType.Ball, Size = V(s.X * 1.2, s.X * 1.2, s.X * 1.2), Offset = CF(0, 0.08, 0.02), Color = ORANGE })
		attach(model, head, { Name = "Visor", Size = V(s.X * 0.86, 0.3, 0.12), Offset = CF(0, 0.06, -s.Z * 0.6), Color = VISOR, Reflectance = 0.25 })
		attach(model, head, { Name = "VisorTrim", Size = V(s.X * 0.9, 0.06, 0.1), Offset = CF(0, -0.12, -s.Z * 0.58), Color = GEAR })
	end

	local torso = part(model, "UpperTorso")
	if torso then
		local s = torso.Size
		local front = -s.Z / 2
		attach(model, torso, { Name = "PlateFront", Size = V(s.X * 0.8, s.Y * 0.74, 0.2), Offset = CF(0, 0.04, front - 0.06), Color = GEAR })
		attach(model, torso, { Name = "PlateBack", Size = V(s.X * 0.8, s.Y * 0.74, 0.2), Offset = CF(0, 0.04, s.Z / 2 + 0.06), Color = GEAR })
		attach(model, torso, { Name = "Cummerbund", Size = V(s.X + 0.08, 0.36, s.Z + 0.16), Offset = CF(0, -s.Y / 2 + 0.24, 0), Color = GEAR_LIGHT })
		for _, x in { -1, 1 } do
			attach(model, torso, { Name = "ShoulderStrap", Size = V(0.3, 0.12, s.Z + 0.34), Offset = CF(x * s.X * 0.27, s.Y / 2 + 0.02, 0), Color = GEAR })
		end
		for i, x in { -0.5, 0, 0.5 } do
			attach(model, torso, { Name = "Pouch" .. i, Size = V(0.4, 0.34, 0.16), Offset = CF(x, -s.Y / 2 + 0.3, front - 0.2), Color = GEAR_LIGHT })
		end
		-- alvo no peito (mira de referência no estande)
		local z = front - 0.17
		disc(model, torso, "TargetOuter", 0.9, 0.04, V(0, 0.18, z), WHITE)
		disc(model, torso, "TargetRing", 0.66, 0.04, V(0, 0.18, z - 0.012), RED)
		disc(model, torso, "TargetInner", 0.42, 0.04, V(0, 0.18, z - 0.024), WHITE)
		disc(model, torso, "TargetCenter", 0.18, 0.04, V(0, 0.18, z - 0.036), RED)
	end

	local lower = part(model, "LowerTorso")
	if lower then
		local s = lower.Size
		attach(model, lower, { Name = "Belt", Size = V(s.X + 0.06, 0.24, s.Z + 0.06), Offset = CF(0, 0.02, 0), Color = GEAR })
		attach(model, lower, { Name = "Buckle", Size = V(0.3, 0.18, 0.06), Offset = CF(0, 0.02, -s.Z / 2 - 0.05), Color = ORANGE })
	end

	for _, side in { "Left", "Right" } do
		local lowerLeg = part(model, side .. "LowerLeg")
		if lowerLeg then
			local s = lowerLeg.Size
			attach(model, lowerLeg, { Name = "KneePad", Size = V(s.X * 0.8, 0.5, 0.22), Offset = CF(0, s.Y / 2 - 0.22, -s.Z / 2 - 0.06), Color = GEAR })
		end
		local foot = part(model, side .. "Foot")
		if foot then
			local s = foot.Size
			attach(model, foot, { Name = "Boot", Size = V(s.X + 0.08, s.Y + 0.14, s.Z + 0.14), Offset = CF(0, 0.05, -0.04), Color = GEAR })
		end
	end

	-- suporte: poste atrás do quadril até uma base no chão (fica de pé quando o boneco cai)
	local root = part(model, "HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and humanoid and lower then
		local groundY = -(root.Size.Y / 2 + humanoid.HipHeight)
		local backZ = lower.Size.Z / 2 + 0.35
		local top = 0.2
		attach(model, root, { Name = "StandBase", Shape = Enum.PartType.Cylinder, Size = V(0.16, 2.8, 2.8), Offset = CF(0, groundY + 0.08, 0.2) * CFrame.Angles(0, 0, rad(90)), Color = STEEL, Material = Enum.Material.Metal })
		attach(model, root, { Name = "StandPole", Shape = Enum.PartType.Cylinder, Size = V(top - groundY, 0.22, 0.22), Offset = CF(0, (top + groundY) / 2, backZ) * CFrame.Angles(0, 0, rad(90)), Color = STEEL, Material = Enum.Material.Metal })
		attach(model, root, { Name = "StandArm", Size = V(0.18, 0.18, 0.5), Offset = CF(0, top - 0.1, backZ - 0.22), Color = STEEL, Material = Enum.Material.Metal })
	end
end

return DummyBuilder
