--[[
	ArmsBuilder — braços da viewmodel (manga tática + luva).
	Cada braço é uma sub-montagem com um "Wrist" invisível ligado por Motor6D à Root da arma:
	animar o Transform do motor move mão + antebraço juntos (ferrolho, reload, faca).
]]

local ModelKit = require(script.Parent.ModelKit)

local ArmsBuilder = {}

local V = Vector3.new

export type Arm = { Model: Model, Wrist: BasePart, Motor: Motor6D }

local SLEEVE = Color3.fromRGB(46, 52, 48)
local CUFF = Color3.fromRGB(34, 38, 36)
local GLOVE = Color3.fromRGB(28, 28, 30)
local KNUCKLE = Color3.fromRGB(52, 52, 56)

--[[
	gripCFrame: onde a palma fica (no espaço da Root).
	elbowOffset: deslocamento do cotovelo em relação à mão (espaço da Root, +Z = para trás).
	side: 1 direita, −1 esquerda (espelha os dedos).
]]
function ArmsBuilder.Build(root: BasePart, name: string, gripCFrame: CFrame, elbowOffset: Vector3, side: number): Arm
	local model = Instance.new("Model")
	model.Name = name

	local worldGrip = root.CFrame * gripCFrame
	local wrist = ModelKit.Part(model, { Name = "Wrist", Size = V(0.1, 0.1, 0.1), CFrame = worldGrip, Transparency = 1 })

	-- mão: bloco da palma + dedos fechados + polegar
	local handCF = worldGrip * CFrame.new(0, 0.02, 0)
	ModelKit.Part(model, { Name = "Palm", Size = V(0.3, 0.22, 0.34), CFrame = handCF, Color = GLOVE, Material = Enum.Material.Fabric })
	ModelKit.Part(model, {
		Name = "Fingers",
		Size = V(0.3, 0.12, 0.22),
		CFrame = handCF * CFrame.new(-0.05 * side, -0.14, -0.06) * CFrame.Angles(math.rad(-25), 0, 0),
		Color = GLOVE,
		Material = Enum.Material.Fabric,
	})
	ModelKit.Part(model, {
		Name = "Knuckles",
		Size = V(0.31, 0.06, 0.26),
		CFrame = handCF * CFrame.new(0, 0.12, -0.02),
		Color = KNUCKLE,
		Material = Enum.Material.Rubber,
	})
	ModelKit.Part(model, {
		Name = "Thumb",
		Size = V(0.09, 0.09, 0.22),
		CFrame = handCF * CFrame.new(0.14 * -side, 0.04, -0.14) * CFrame.Angles(0, math.rad(18 * side), 0),
		Color = GLOVE,
		Material = Enum.Material.Fabric,
	})

	-- antebraço da mão até o cotovelo
	local wristPos = (handCF * CFrame.new(0, 0, 0.2)).Position
	local elbowPos = (root.CFrame * CFrame.new(gripCFrame.Position + elbowOffset)).Position
	local length = (elbowPos - wristPos).Magnitude
	local mid = (wristPos + elbowPos) / 2
	local forearmCF = CFrame.lookAt(mid, elbowPos)
	ModelKit.Part(model, { Name = "Forearm", Size = V(0.4, 0.38, length), CFrame = forearmCF, Color = SLEEVE, Material = Enum.Material.Fabric })
	ModelKit.Part(model, {
		Name = "Cuff",
		Size = V(0.43, 0.41, 0.16),
		CFrame = CFrame.lookAt(wristPos, elbowPos) * CFrame.new(0, 0, -0.08),
		Color = CUFF,
		Material = Enum.Material.Fabric,
	})
	ModelKit.Part(model, {
		Name = "Watch",
		Size = V(0.44, 0.12, 0.1),
		CFrame = CFrame.lookAt(wristPos, elbowPos) * CFrame.new(0, 0.02, -0.24),
		Color = Color3.fromRGB(20, 20, 22),
		Material = Enum.Material.Rubber,
	})
	-- manga continua para fora da câmera
	ModelKit.Part(model, {
		Name = "Sleeve",
		Size = V(0.46, 0.44, 1.4),
		CFrame = CFrame.lookAt(elbowPos, elbowPos + (elbowPos - wristPos).Unit) * CFrame.new(0, 0, -0.6),
		Color = SLEEVE,
		Material = Enum.Material.Fabric,
	})

	ModelKit.WeldAll(model, wrist)
	ModelKit.MakeVisual(model)
	model.Parent = root.Parent
	local motor = ModelKit.Motor(root, wrist, name .. "Motor")
	return { Model = model, Wrist = wrist, Motor = motor }
end

return ArmsBuilder
