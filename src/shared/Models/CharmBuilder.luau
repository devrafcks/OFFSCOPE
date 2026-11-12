--[[
	CharmBuilder — charms pendurados no swivel da arma.
	A Pivot (argola) é ligada por Motor6D ao attachment "Charm"; a viewmodel anima o balanço
	com uma mola (CFrame no Transform do motor).
]]

local ModelKit = require(script.Parent.ModelKit)

local CharmBuilder = {}

local V = Vector3.new
local CF = CFrame.new

export type Charm = { Model: Model, Pivot: BasePart, Motor: Motor6D }

local function body(model: Model, visual: { [string]: any })
	local kind = visual.Kind
	local color = visual.Color or Color3.fromRGB(220, 220, 220)
	if kind == "Dice" then
		ModelKit.Part(model, { Name = "Dice", Size = V(0.17, 0.17, 0.17), CFrame = CF(0, -0.36, 0), Color = color })
		for _, offset in { V(0.086, 0, 0), V(-0.086, 0.04, 0.04), V(-0.086, -0.04, -0.04), V(0, 0, 0.086) } do
			ModelKit.Part(model, {
				Name = "Pip",
				Shape = Enum.PartType.Ball,
				Size = V(0.035, 0.035, 0.035),
				CFrame = CF(V(0, -0.36, 0) + offset),
				Color = visual.Pip,
			})
		end
	elseif kind == "Bullet" then
		ModelKit.CylinderY(model, "Case", 0.2, 0.08, V(0, -0.38, 0)).Color = color
		local tip = ModelKit.Part(model, {
			Name = "Tip",
			Shape = Enum.PartType.Ball,
			Size = V(0.08, 0.12, 0.08),
			CFrame = CF(0, -0.25, 0),
			Color = Color3.fromRGB(180, 110, 70),
			Material = Enum.Material.Metal,
		})
		tip.Material = Enum.Material.Metal
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Case" then
				part.Material = Enum.Material.Metal
			end
		end
	elseif kind == "Tag" then
		ModelKit.Part(model, {
			Name = "Tag",
			Size = V(0.02, 0.26, 0.16),
			CFrame = CF(0, -0.38, 0),
			Color = color,
			Material = Enum.Material.Metal,
			Reflectance = 0.1,
		})
		ModelKit.Part(model, {
			Name = "Emboss",
			Size = V(0.025, 0.04, 0.11),
			CFrame = CF(0, -0.34, 0),
			Color = Color3.fromRGB(120, 124, 130),
			Material = Enum.Material.Metal,
		})
	elseif kind == "NeonCube" then
		local cube = ModelKit.Part(model, {
			Name = "Cube",
			Size = V(0.15, 0.15, 0.15),
			CFrame = CF(0, -0.36, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Color = color,
			Material = Enum.Material.Neon,
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 3
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = cube
	end
end

-- Retorna nil para "charm_none".
function CharmBuilder.Attach(weaponRoot: BasePart, mount: Attachment, visual: { [string]: any }?): Charm?
	if not visual or visual.Kind == "None" or visual.Kind == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Charm"

	local pivot = ModelKit.Part(model, {
		Name = "Pivot",
		Shape = Enum.PartType.Ball,
		Size = V(0.06, 0.06, 0.06),
		CFrame = CFrame.identity,
		Color = Color3.fromRGB(150, 150, 156),
		Material = Enum.Material.Metal,
	})
	ModelKit.Part(model, {
		Name = "Chain",
		Size = V(0.02, 0.24, 0.02),
		CFrame = CF(0, -0.14, 0),
		Color = Color3.fromRGB(150, 150, 156),
		Material = Enum.Material.Metal,
	})
	body(model, visual)

	-- move tudo para o mount
	local target = weaponRoot.CFrame * mount.CFrame
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = target * part.CFrame
		end
	end

	ModelKit.WeldAll(model, pivot)
	ModelKit.MakeVisual(model)
	model.Parent = weaponRoot.Parent
	local motor = ModelKit.Motor(weaponRoot, pivot, "CharmMotor")
	return { Model = model, Pivot = pivot, Motor = motor }
end

return CharmBuilder
