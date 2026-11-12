--!strict
--[[
	HoldPose — pose de "segurando a arma" + inclinação pelo pitch, aplicada por frame.
	Roda no cliente (o que os jogadores veem) e no servidor (para as hitboxes dos braços
	baterem com o que os clientes desenham).

	O servidor grava BaseC0/HoldC0 como atributos das juntas (CharacterService) e o
	atributo "Pitch" do personagem (~12 Hz). Aqui:
	• AnimationConstraint (avatar novo): Transform = Base⁻¹·Hold·tilt, todo frame, em
	  PreSimulation — depois do Animator, que senão recalcula o Transform e desfaz a pose.
	• Motor6D (rig clássico): C0 = Hold·tilt, só onde `posesMotors` deixar
	  (no servidor o C0 já vem replicado; no cliente, o próprio personagem também).
]]

local Players = game:GetService("Players")

local Joint = require(script.Parent.Joint)

local HoldPose = {}

local smoothed: { [Model]: number } = {}

local function apply(joint: Instance?, tilt: CFrame, allowMotor: boolean)
	if not joint then
		return
	end
	local base = joint:GetAttribute("BaseC0") :: CFrame?
	local held = joint:GetAttribute("HoldC0") :: CFrame?
	if not base or not held then
		return
	end
	if joint:IsA("Motor6D") and not allowMotor then
		return
	end
	Joint.ApplyHold(joint, base, held * tilt)
end

function HoldPose.Step(dt: number, posesMotors: (Player) -> boolean)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local target = (character:GetAttribute("Pitch") :: number?) or 0
		local value = smoothed[character] or target
		value += (target - value) * math.min(1, dt * 12)
		smoothed[character] = value
		local allowMotor = posesMotors(player)
		local tilt = CFrame.Angles(math.clamp(value, -1.2, 1.2) * 0.85, 0, 0)
		apply(Joint.Find(character:FindFirstChild("RightUpperArm"), "RightShoulder"), tilt, allowMotor)
		apply(Joint.Find(character:FindFirstChild("LeftUpperArm"), "LeftShoulder"), tilt, allowMotor)
		apply(Joint.Find(character:FindFirstChild("Head"), "Neck"), CFrame.Angles(math.clamp(value, -1, 1) * 0.6, 0, 0), allowMotor)
	end
	for character in smoothed do
		if not character.Parent then
			smoothed[character] = nil
		end
	end
end

return HoldPose
