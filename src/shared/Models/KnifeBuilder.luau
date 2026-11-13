local ModelKit = require(script.Parent.ModelKit)

local KnifeBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

export type Knife = { Model: Model, Root: BasePart }

function KnifeBuilder.Build(shape: string?): Knife
	local model = Instance.new("Model")
	model.Name = "Knife"

	local root = ModelKit.Part(model, { Name = "Root", Size = V(0.1, 0.1, 0.1), CFrame = CFrame.identity, Transparency = 1 })
	model.PrimaryPart = root

	local P = function(spec)
		return ModelKit.Part(model, spec)
	end

	P({ Name = "Handle", Size = V(0.15, 0.2, 0.6), CFrame = CF(0, 0, 0.1), Group = "Handle" })
	for i = 0, 2 do
		P({ Name = "HandleRing", Size = V(0.16, 0.21, 0.04), CFrame = CF(0, 0, -0.08 + i * 0.16), Group = "Guard" })
	end
	P({ Name = "Pommel", Size = V(0.17, 0.17, 0.08), CFrame = CF(0, 0, 0.43), Group = "Guard" })
	P({ Name = "Guard", Size = V(0.12, 0.36, 0.06), CFrame = CF(0, 0.02, -0.22), Group = "Guard" })

	if shape == "Tanto" then
		P({ Name = "Blade", Size = V(0.035, 0.22, 0.95), CFrame = CF(0, 0.03, -0.72), Group = "Blade" })
		P({
			Name = "BladeTip",
			Wedge = true,
			Size = V(0.035, 0.22, 0.26),
			CFrame = CF(0, 0.03, -1.32) * CFrame.Angles(0, 0, rad(180)) * CFrame.Angles(0, rad(180), 0),
			Group = "Blade",
		})
	else
		P({ Name = "Blade", Size = V(0.035, 0.2, 0.86), CFrame = CF(0, 0.02, -0.68), Group = "Blade" })
		P({ Name = "Spine", Size = V(0.045, 0.04, 0.7), CFrame = CF(0, 0.12, -0.6), Group = "Guard" })
		P({
			Name = "BladeTip",
			Wedge = true,
			Size = V(0.035, 0.2, 0.34),
			CFrame = CF(0, 0.02, -1.28) * CFrame.Angles(0, rad(180), 0),
			Group = "Blade",
		})
	end

	P({ Name = "Edge", Size = V(0.038, 0.035, 0.84), CFrame = CF(0, -0.07, -0.68), Group = "Blade", Reflectance = 0.15 })

	ModelKit.Attachment(root, "Tip", CF(0, 0.02, -1.45))
	ModelKit.WeldAll(model, root)
	ModelKit.Finalize(model, root, { Anchored = true })
	return { Model = model, Root = root }
end

return KnifeBuilder
