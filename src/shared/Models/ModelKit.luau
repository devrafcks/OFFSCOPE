local ModelKit = {}

export type PartSpec = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Wedge: boolean?,
	Group: string?,
	Transparency: number?,
	Reflectance: number?,
}

local DEFAULT_COLOR = Color3.fromRGB(40, 42, 46)

function ModelKit.Part(parent: Instance, spec: PartSpec): BasePart
	local part: BasePart
	if spec.Wedge then
		part = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		if spec.Shape then
			p.Shape = spec.Shape
		end
		part = p
	end
	part.Name = spec.Name or "Part"
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.Color = spec.Color or DEFAULT_COLOR
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.Transparency = spec.Transparency or 0
	part.Reflectance = spec.Reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.Group then
		part:SetAttribute("Group", spec.Group)
	end
	part.Parent = parent
	return part
end

function ModelKit.CylinderZ(parent: Instance, name: string, length: number, diameter: number, position: Vector3, group: string?): BasePart
	return ModelKit.Part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0),
		Group = group,
	})
end

function ModelKit.CylinderY(parent: Instance, name: string, height: number, diameter: number, position: Vector3, group: string?): BasePart
	return ModelKit.Part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Group = group,
	})
end

function ModelKit.Attachment(parent: BasePart, name: string, worldCFrame: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = parent.CFrame:ToObjectSpace(worldCFrame)
	attachment.Parent = parent
	return attachment
end

function ModelKit.WeldAll(container: Instance, root: BasePart)
	for _, part in container:GetDescendants() do
		if part:IsA("BasePart") and part ~= root and not part:FindFirstChildOfClass("WeldConstraint") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

function ModelKit.Motor(root: BasePart, part: BasePart, name: string): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = root
	motor.Part1 = part
	motor.C0 = root.CFrame:ToObjectSpace(part.CFrame)
	motor.C1 = CFrame.identity
	motor.Parent = root
	return motor
end

export type FinalizeOptions = {
	Anchored: boolean?,
	Collide: boolean?,
	Shadows: boolean?,
	Query: boolean?,
}

function ModelKit.Finalize(model: Instance, root: BasePart, options: FinalizeOptions?)
	local opts = options or {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part == root and (opts.Anchored ~= false)
			part.CanCollide = opts.Collide == true
			part.CanTouch = false
			part.CanQuery = opts.Query == true
			part.CastShadow = opts.Shadows == true
			part.Massless = true
		end
	end
	root.Anchored = opts.Anchored ~= false
end

function ModelKit.MakeVisual(model: Instance)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Massless = true
		end
	end
end

return ModelKit
