--[[
	CharacterPoseController — corpos em 3ª pessoa.
	• Meu personagem: invisível para mim (a câmera fica dentro da cabeça; a viewmodel é a arma).
	• Os outros: braços e arma inclinam com o pitch replicado (atributo "Pitch", ~12 Hz),
	  suavizado localmente. Só C0 local dos ombros — o servidor não gasta nada com isso.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

local function poseOthers(dt: number)
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		if not character then
			continue
		end
		local target = (character:GetAttribute("Pitch") :: number?) or 0
		local value = smoothed[character] or target
		value += (target - value) * math.min(1, dt * 12)
		smoothed[character] = value
		local tilt = CFrame.Angles(math.clamp(value, -1.2, 1.2) * 0.85, 0, 0)
		for _, name in { "RightUpperArm", "LeftUpperArm" } do
			local arm = character:FindFirstChild(name)
			local shoulder = arm and arm:FindFirstChild(if name == "RightUpperArm" then "RightShoulder" else "LeftShoulder") :: Motor6D?
			if shoulder then
				-- C0 de "segurar a arma" que o servidor replicou como atributo
				local base = shoulder:GetAttribute("HoldC0") :: CFrame?
				if base then
					shoulder.C0 = base * tilt
				end
			end
		end
		local head = character:FindFirstChild("Head")
		local neck = head and head:FindFirstChild("Neck") :: Motor6D?
		if neck then
			local base = neck:GetAttribute("HoldC0") :: CFrame?
			if base then
				neck.C0 = base * CFrame.Angles(math.clamp(value, -1, 1) * 0.6, 0, 0)
			end
		end
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

	RunService.RenderStepped:Connect(function(dt)
		-- o TransparencyController padrão pode reescrever; garantimos todo frame (barato)
		local character = player.Character
		if character then
			for _, part in character:GetChildren() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
				end
			end
		end
		poseOthers(dt)
	end)
end

return CharacterPoseController
