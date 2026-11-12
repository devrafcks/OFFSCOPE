--[[
	CharacterPoseController — corpos em 3ª pessoa.
	• Meu personagem: invisível para mim (a câmera fica dentro da cabeça; a viewmodel é a arma).
	• Todos: braços e arma inclinam com o pitch replicado (atributo "Pitch", ~12 Hz),
	  suavizado localmente. Motor6D → C0; AnimationConstraint (avatar novo) → Transform por frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Joint = require(ReplicatedStorage.Shared.Util.Joint)

local CharacterPoseController = {}

local player = Players.LocalPlayer
local smoothed: { [Model]: number } = {}

local function hideOwn(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end
end

-- pose "segurando a arma" + tilt de pitch numa junta (Motor6D ou AnimationConstraint)
local function hold(joint: Instance?, tilt: CFrame, isSelf: boolean)
	if not joint then
		return
	end
	local base = joint:GetAttribute("BaseC0") :: CFrame?
	local held = joint:GetAttribute("HoldC0") :: CFrame?
	if not base or not held then
		return
	end
	-- Motor6D do próprio personagem já vem com o C0 replicado pelo servidor
	if isSelf and joint:IsA("Motor6D") then
		return
	end
	Joint.ApplyHold(joint, base, held * tilt)
end

local function poseCharacters(dt: number)
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if not character then
			continue
		end
		local target = (character:GetAttribute("Pitch") :: number?) or 0
		local value = smoothed[character] or target
		value += (target - value) * math.min(1, dt * 12)
		smoothed[character] = value
		local isSelf = other == player
		local tilt = CFrame.Angles(math.clamp(value, -1.2, 1.2) * 0.85, 0, 0)
		hold(Joint.Find(character:FindFirstChild("RightUpperArm"), "RightShoulder"), tilt, isSelf)
		hold(Joint.Find(character:FindFirstChild("LeftUpperArm"), "LeftShoulder"), tilt, isSelf)
		hold(Joint.Find(character:FindFirstChild("Head"), "Neck"), CFrame.Angles(math.clamp(value, -1, 1) * 0.6, 0, 0), isSelf)
	end
	for character in smoothed do
		if not character.Parent then
			smoothed[character] = nil
		end
	end
end

function CharacterPoseController.Start()
	local function onCharacter(character: Model)
		hideOwn(character)
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = 1
			elseif descendant:IsA("Decal") then
				descendant.Transparency = 1
			end
		end)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	RunService.RenderStepped:Connect(function()
		-- o TransparencyController padrão pode reescrever; garantimos todo frame (barato)
		local character = player.Character
		if character then
			for _, part in character:GetChildren() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
				end
			end
		end
	end)
	-- depois do Animator e antes da física: é aqui que o Transform das AnimationConstraints vale
	RunService.PreSimulation:Connect(poseCharacters)
end

return CharacterPoseController
