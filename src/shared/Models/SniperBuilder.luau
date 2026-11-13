local ModelKit = require(script.Parent.ModelKit)

local SniperBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

export type Detail = "Full" | "Lite"

export type Sniper = {
	Model: Model,
	Root: BasePart,
	Bolt: Motor6D,
	Mag: Motor6D,
	CharmMount: Attachment,
}

local SCOPE_Y = 0.64

local function buildFrame(frame: Model, full: boolean)
	local P = function(spec)
		return ModelKit.Part(frame, spec)
	end

	P({ Name = "Receiver", Size = V(0.3, 0.34, 1.55), CFrame = CF(0, 0.2, -0.36), Group = "Body" })
	P({ Name = "ReceiverTop", Size = V(0.24, 0.08, 1.45), CFrame = CF(0, 0.4, -0.36), Group = "Body" })
	P({ Name = "Rail", Size = V(0.14, 0.05, 1.4), CFrame = CF(0, 0.465, -0.38), Group = "Accent" })
	P({ Name = "EjectionPort", Size = V(0.02, 0.14, 0.42), CFrame = CF(0.155, 0.27, -0.02), Color = Color3.fromRGB(14, 14, 16), Material = Enum.Material.Metal })

	P({ Name = "Handguard", Size = V(0.3, 0.3, 1.25), CFrame = CF(0, 0.18, -1.72), Group = "Body" })
	P({ Name = "HandguardBottom", Size = V(0.22, 0.08, 1.15), CFrame = CF(0, 0.0, -1.72), Group = "Body" })
	if full then
		for i = 0, 3 do

			P({ Name = "Slot", Size = V(0.31, 0.06, 0.14), CFrame = CF(0, 0.2, -1.3 - i * 0.28), Color = Color3.fromRGB(12, 12, 14), Material = Enum.Material.Metal })
		end
	end

	ModelKit.CylinderZ(frame, "Barrel", 2.5, 0.13, V(0, 0.26, -2.75), "Barrel")
	ModelKit.CylinderZ(frame, "BarrelBase", 0.4, 0.18, V(0, 0.26, -2.25), "Barrel")

	P({ Name = "Muzzle", Size = V(0.22, 0.2, 0.38), CFrame = CF(0, 0.26, -4.12), Group = "Accent" })
	if full then
		for i = 0, 2 do
			P({ Name = "MuzzlePort", Size = V(0.23, 0.05, 0.06), CFrame = CF(0, 0.26, -4.0 - i * 0.1), Color = Color3.fromRGB(10, 10, 12), Material = Enum.Material.Metal })
		end
	end

	P({ Name = "StockBody", Size = V(0.26, 0.4, 1.2), CFrame = CF(0, 0.08, 1.02), Group = "Stock" })
	P({ Name = "StockLower", Size = V(0.24, 0.18, 0.7), CFrame = CF(0, -0.18, 1.3) * CFrame.Angles(rad(-8), 0, 0), Group = "Stock" })
	P({ Name = "CheekRest", Size = V(0.22, 0.12, 0.62), CFrame = CF(0, 0.34, 1.0), Group = "Stock" })
	P({ Name = "ButtPad", Size = V(0.28, 0.62, 0.09), CFrame = CF(0, 0.0, 1.66), Group = "Accent", Material = Enum.Material.Rubber })
	P({ Name = "StockNeck", Size = V(0.22, 0.22, 0.32), CFrame = CF(0, 0.14, 0.34), Group = "Stock" })

	P({ Name = "Grip", Size = V(0.2, 0.52, 0.24), CFrame = CF(0, -0.2, 0.16) * CFrame.Angles(rad(-18), 0, 0), Group = "Stock" })
	if full then
		P({ Name = "TriggerGuard", Size = V(0.05, 0.04, 0.4), CFrame = CF(0, -0.1, -0.16), Group = "Body" })
		P({ Name = "TriggerGuardFront", Size = V(0.05, 0.16, 0.04), CFrame = CF(0, -0.03, -0.36), Group = "Body" })
		P({ Name = "Trigger", Size = V(0.035, 0.13, 0.04), CFrame = CF(0, -0.03, -0.12) * CFrame.Angles(rad(12), 0, 0), Group = "Accent" })
	end

	ModelKit.CylinderZ(frame, "ScopeTube", 1.5, 0.2, V(0, SCOPE_Y, -0.45), "Scope")
	ModelKit.CylinderZ(frame, "ScopeBell", 0.36, 0.32, V(0, SCOPE_Y, -1.32), "Scope")
	ModelKit.CylinderZ(frame, "ScopeTaper", 0.18, 0.26, V(0, SCOPE_Y, -1.08), "Scope")
	ModelKit.CylinderZ(frame, "Eyepiece", 0.34, 0.27, V(0, SCOPE_Y, 0.42), "Scope")
	ModelKit.CylinderY(frame, "TurretTop", 0.14, 0.13, V(0, SCOPE_Y + 0.15, -0.42), "Accent")
	if full then
		ModelKit.Part(frame, {
			Name = "TurretSide",
			Shape = Enum.PartType.Cylinder,
			Size = V(0.14, 0.13, 0.13),
			CFrame = CF(0.15, SCOPE_Y, -0.42),
			Group = "Accent",
		})
		for _, z in { -0.05, -0.85 } do
			P({ Name = "ScopeRing", Size = V(0.24, 0.12, 0.1), CFrame = CF(0, 0.53, z), Group = "Accent" })
		end

		ModelKit.Part(frame, {
			Name = "LensFront",
			Shape = Enum.PartType.Cylinder,
			Size = V(0.02, 0.28, 0.28),
			CFrame = CF(0, SCOPE_Y, -1.505) * CFrame.Angles(0, rad(90), 0),
			Color = Color3.fromRGB(40, 70, 110),
			Material = Enum.Material.Glass,
			Reflectance = 0.35,
			Transparency = 0.15,
			Group = "Lens",
		})
		ModelKit.Part(frame, {
			Name = "LensRear",
			Shape = Enum.PartType.Cylinder,
			Size = V(0.02, 0.23, 0.23),
			CFrame = CF(0, SCOPE_Y, 0.595) * CFrame.Angles(0, rad(90), 0),
			Color = Color3.fromRGB(20, 30, 40),
			Material = Enum.Material.Glass,
			Reflectance = 0.2,
			Transparency = 0.3,
			Group = "Lens",
		})

		for _, x in { -0.07, 0.07 } do
			P({ Name = "BipodLeg", Size = V(0.05, 0.05, 0.85), CFrame = CF(x, -0.07, -2.0), Group = "Accent" })
		end
		P({ Name = "BipodHinge", Size = V(0.2, 0.08, 0.1), CFrame = CF(0, -0.05, -2.38), Group = "Accent" })

		P({ Name = "Swivel", Size = V(0.04, 0.1, 0.1), CFrame = CF(0.17, 0.08, -1.25), Group = "Accent" })
	else
		P({ Name = "ScopeRings", Size = V(0.22, 0.12, 0.9), CFrame = CF(0, 0.53, -0.45), Group = "Accent" })
	end
end

local function buildBolt(bolt: Model, full: boolean): BasePart
	local base = ModelKit.CylinderZ(bolt, "BoltBody", 0.55, 0.13, V(0, 0.31, 0.12), "Accent")
	ModelKit.Part(bolt, {
		Name = "BoltArm",
		Size = V(0.3, 0.05, 0.05),
		CFrame = CF(0.17, 0.31, 0.3),
		Group = "Accent",
	})
	ModelKit.Part(bolt, {
		Name = "BoltKnob",
		Shape = Enum.PartType.Ball,
		Size = V(0.13, 0.13, 0.13),
		CFrame = CF(0.33, 0.29, 0.3),
		Group = if full then "Accent" else "Body",
	})
	if full then
		ModelKit.Part(bolt, { Name = "BoltShroud", Size = V(0.12, 0.12, 0.1), CFrame = CF(0, 0.31, 0.43), Group = "Body" })
	end
	return base
end

local function buildMag(mag: Model, full: boolean): BasePart
	local body = ModelKit.Part(mag, {
		Name = "MagBody",
		Size = V(0.22, 0.44, 0.44),
		CFrame = CF(0, -0.12, -0.6) * CFrame.Angles(rad(6), 0, 0),
		Group = "Mag",
	})
	if full then
		ModelKit.Part(mag, { Name = "MagPlate", Size = V(0.24, 0.05, 0.48), CFrame = CF(0, -0.355, -0.58), Group = "Accent" })

		ModelKit.Part(mag, {
			Name = "Round",
			Size = V(0.07, 0.07, 0.36),
			CFrame = CF(0, 0.11, -0.6),
			Color = Color3.fromRGB(196, 150, 70),
			Material = Enum.Material.Metal,
		})
	end
	return body
end

function SniperBuilder.Build(detail: Detail?): Sniper
	local full = (detail or "Full") == "Full"
	local model = Instance.new("Model")
	model.Name = "Vanta7"

	local root = ModelKit.Part(model, {
		Name = "Root",
		Size = V(0.2, 0.2, 0.2),
		CFrame = CFrame.identity,
		Transparency = 1,
	})
	model.PrimaryPart = root

	local frame = Instance.new("Model")
	frame.Name = "Frame"
	frame.Parent = model
	buildFrame(frame, full)
	ModelKit.WeldAll(frame, root)

	local boltModel = Instance.new("Model")
	boltModel.Name = "Bolt"
	boltModel.Parent = model
	local boltBase = buildBolt(boltModel, full)
	ModelKit.WeldAll(boltModel, boltBase)
	local boltMotor = ModelKit.Motor(root, boltBase, "BoltMotor")

	local magModel = Instance.new("Model")
	magModel.Name = "Mag"
	magModel.Parent = model
	local magBase = buildMag(magModel, full)
	ModelKit.WeldAll(magModel, magBase)
	local magMotor = ModelKit.Motor(root, magBase, "MagMotor")

	ModelKit.Attachment(root, "Muzzle", CF(0, 0.26, -4.33))
	local charm = ModelKit.Attachment(root, "Charm", CF(0.2, 0.04, -1.25))
	ModelKit.Attachment(root, "RightGrip", CF(0, -0.2, 0.16))
	ModelKit.Attachment(root, "LeftGrip", CF(0, 0.02, -1.75))
	ModelKit.Attachment(root, "ScopeEye", CF(0, SCOPE_Y, 1.05))
	ModelKit.Attachment(root, "BoltKnob", CF(0.33, 0.29, 0.3))
	ModelKit.Attachment(root, "MagWell", CF(0, -0.15, -0.6))

	ModelKit.Finalize(model, root, { Anchored = true })

	return {
		Model = model,
		Root = root,
		Bolt = boltMotor,
		Mag = magMotor,
		CharmMount = charm,
	}
end

function SniperBuilder.BoltTransform(progress: number): CFrame
	if progress <= 0 or progress >= 1 then
		return CFrame.identity
	end
	local lift, pull
	if progress < 0.2 then
		lift, pull = progress / 0.2, 0
	elseif progress < 0.5 then
		lift, pull = 1, (progress - 0.2) / 0.3
	elseif progress < 0.8 then
		lift, pull = 1, 1 - (progress - 0.5) / 0.3
	else
		lift, pull = 1 - (progress - 0.8) / 0.2, 0
	end

	return CFrame.new(0, 0, 0) * CFrame.Angles(rad(-65) * lift, 0, 0) * CFrame.new(-0.42 * pull, 0, 0)
end

return SniperBuilder
