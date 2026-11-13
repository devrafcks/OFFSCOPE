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

		local character = player.Character
		if character then
			for _, part in character:GetChildren() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 1
				end
			end
		end
	end)

	RunService.PreSimulation:Connect(function(dt)
		HoldPose.Step(dt, function(other)
			return other ~= player
		end)
	end)
end

return CharacterPoseController
