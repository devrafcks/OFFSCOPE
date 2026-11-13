local ModelKit = require(script.Parent.ModelKit)

local ArmsBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

export type Arm = { Model: Model, Wrist: BasePart, Motor: Motor6D }

local SLEEVE = Color3.fromRGB(88, 96, 74)
local SLEEVE_DARK = Color3.fromRGB(68, 75, 57)
local SEAM = Color3.fromRGB(56, 62, 46)
local GLOVE = Color3.fromRGB(140, 113, 80)
local GLOVE_PAD = Color3.fromRGB(58, 54, 50)
local STRAP = Color3.fromRGB(28, 28, 30)
local DEFAULT_SKIN = Color3.fromRGB(196, 150, 116)
local WATCH_FACE = Color3.fromRGB(16, 20, 22)

local function cylinderBetween(model: Model, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3): BasePart
	local length = (b - a).Magnitude
	return ModelKit.Part(model, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = V(length, diameter, diameter),

		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0),
		Color = color,
	})
end

local function ball(model: Model, name: string, position: Vector3, diameter: number, color: Color3): BasePart
	return ModelKit.Part(model, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = V(diameter, diameter, diameter),
		CFrame = CF(position),
		Color = color,
	})
end

function ArmsBuilder.Build(root: BasePart, name: string, gripCFrame: CFrame, elbowOffset: Vector3, side: number, barRadius: number?, skin: Color3?): Arm
	local model = Instance.new("Model")
	model.Name = name
	local r = barRadius or 0.14

	local hand = root.CFrame * gripCFrame
	local wrist = ModelKit.Part(model, { Name = "Wrist", Size = V(0.1, 0.1, 0.1), CFrame = hand, Transparency = 1 })

	local function at(x: number, y: number, z: number): CFrame
		return hand * CF(x, y, z)
	end

	ModelKit.Part(model, { Name = "Palm", Size = V(0.36, 0.17, 0.56), CFrame = at(0, -(r + 0.085), 0.02), Color = GLOVE })
	ModelKit.Part(model, { Name = "PalmPad", Size = V(0.28, 0.035, 0.42), CFrame = at(0, -(r + 0.18), 0.03), Color = GLOVE_PAD })
	ModelKit.Part(model, { Name = "Strap", Size = V(0.38, 0.06, 0.1), CFrame = at(0, -(r + 0.095), 0.27), Color = STRAP })

	local fx = side * (r + 0.04)
	for i, z in { -0.2, -0.07, 0.06, 0.19 } do
		local reach = if i == 1 then 1 elseif i == 4 then 0.8 else 1.05
		local length = 0.3 * reach
		ModelKit.Part(model, {
			Name = "Finger" .. i,
			Size = V(0.11, length, 0.11),
			CFrame = at(fx, -r - 0.04 + length / 2, z) * CFrame.Angles(0, 0, rad(-6 * side)),
			Color = GLOVE,
		})
		ball(model, "Fingertip" .. i, (at(fx - side * 0.01, -r - 0.04 + length, z)).Position, 0.11, GLOVE)
		ball(model, "Knuckle" .. i, (at(side * (r + 0.05), -(r + 0.06), z)).Position, 0.13, GLOVE_PAD)
	end

	local tx = -side * (r + 0.05)
	ModelKit.Part(model, {
		Name = "Thumb",
		Size = V(0.12, 0.12, 0.3),
		CFrame = at(tx, -r * 0.2, -0.06) * CFrame.Angles(rad(14), 0, 0),
		Color = GLOVE,
	})
	ball(model, "ThumbTip", (at(tx, -r * 0.1, -0.21)).Position, 0.12, GLOVE)
	ball(model, "ThumbBase", (at(tx * 0.85, -(r + 0.06), 0.14)).Position, 0.2, GLOVE)

	local palmCenter = at(0, -(r + 0.09), 0.1).Position
	local elbow = (root.CFrame * CF(gripCFrame.Position + elbowOffset)).Position
	local axis = (elbow - palmCenter).Unit
	local wristPos = palmCenter + axis * 0.26
	local forearmLength = (elbow - wristPos).Magnitude

	local skinColor = skin or DEFAULT_SKIN
	local roll = wristPos + axis * (forearmLength * 0.42)
	cylinderBetween(model, "GloveCuff", palmCenter + axis * 0.12, wristPos + axis * 0.08, 0.33, GLOVE)
	cylinderBetween(model, "SkinWrist", wristPos + axis * 0.02, wristPos + axis * (forearmLength * 0.22), 0.27, skinColor)
	cylinderBetween(model, "SkinForearm", wristPos + axis * (forearmLength * 0.2), roll + axis * 0.04, 0.32, skinColor)
	cylinderBetween(model, "RolledCuff", roll, roll + axis * 0.13, 0.42, SLEEVE_DARK)
	cylinderBetween(model, "RolledCuffLip", roll - axis * 0.015, roll + axis * 0.03, 0.4, SLEEVE)
	cylinderBetween(model, "ForearmSleeve", roll + axis * 0.1, elbow, 0.41, SLEEVE)
	ball(model, "Elbow", elbow, 0.42, SLEEVE)
	local mid = roll + (elbow - roll) * 0.5

	local up = hand.UpVector
	local seamOffset = (up - axis * up:Dot(axis)).Unit
	cylinderBetween(model, "Seam", roll + axis * 0.14 + seamOffset * 0.195, elbow + seamOffset * 0.2, 0.03, SEAM)
	ModelKit.Part(model, {
		Name = "Pocket",
		Size = V(0.2, 0.05, 0.26),
		CFrame = CFrame.lookAt(mid + seamOffset * 0.2, mid + seamOffset * 0.2 + axis, seamOffset)
			* CF(side * 0.02, 0, 0),
		Color = SLEEVE_DARK,
	})

	if side < 0 then
		cylinderBetween(model, "WatchBand", wristPos + axis * 0.1, wristPos + axis * 0.17, 0.31, STRAP)
		ModelKit.Part(model, {
			Name = "WatchFace",
			Size = V(0.14, 0.04, 0.12),
			CFrame = CFrame.lookAt(wristPos + axis * 0.135 + seamOffset * 0.155, wristPos + axis * 0.135 + seamOffset * 0.155 + axis, seamOffset),
			Color = WATCH_FACE,
			Reflectance = 0.15,
		})
	end

	cylinderBetween(model, "Sleeve", elbow - axis * 0.05, elbow + axis * 3, 0.45, SLEEVE)

	ModelKit.WeldAll(model, wrist)
	ModelKit.MakeVisual(model)
	model.Parent = root.Parent
	local motor = ModelKit.Motor(root, wrist, name .. "Motor")
	return { Model = model, Wrist = wrist, Motor = motor }
end

return ArmsBuilder
