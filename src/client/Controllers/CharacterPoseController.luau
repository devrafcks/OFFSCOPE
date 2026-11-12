--[[
	CharacterPoseController — corpos em 3ª pessoa.
	• Meu personagem: invisível para mim (a câmera fica dentro da cabeça; a viewmodel é a arma).
	• Todos: braços e arma inclinam com o pitch replicado (atributo "Pitch", ~12 Hz),
	  suavizado localmente. Motor6D → C0; AnimationConstraint (avatar novo) → Transform por frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HoldPose = require(ReplicatedStorage.Shared.Util.HoldPose)

local CharacterPoseController = {}

local player = Players.LocalPlayer

local function hideOwn(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
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
	-- (o Motor6D do próprio personagem já vem com o C0 replicado pelo servidor)
	RunService.PreSimulation:Connect(function(dt)
		HoldPose.Step(dt, function(other)
			return other ~= player
		end)
	end)
end

return CharacterPoseController
