local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local LightingPresets = require(Shared.Environment.LightingPresets)
local ClientState = require(script.Parent.Parent.ClientState)

local EnvironmentController = {}

local current = "Lobby"
local ambience: Sound? = nil

local function applySecondaryLights()
	local maps = Workspace:FindFirstChild("Maps")
	if not maps then
		return
	end
	local performance = ClientState.Settings.PerformanceMode == true
	for _, light in maps:GetDescendants() do
		if light:IsA("Light") and light:GetAttribute("Secondary") then
			light.Enabled = not performance
		end
	end
end

function EnvironmentController.Apply(presetId: string, tween: number?)
	current = presetId
	local preset = LightingPresets.Apply(presetId, { Performance = ClientState.Settings.PerformanceMode, Tween = tween })
	if ambience then
		ambience:Destroy()
		ambience = nil
	end
	if preset.Ambience then
		local sound = Audio.Create(preset.Ambience, { Looped = true })
		if sound then
			sound.Parent = game:GetService("SoundService")
			sound:Play()
			ambience = sound
		end
	end
	task.defer(applySecondaryLights)
end

function EnvironmentController.Current(): string
	return current
end

function EnvironmentController.Init()
	Remotes.Event("Environment").OnClientEvent:Connect(function(presetId: string)
		if presetId ~= current then
			EnvironmentController.Apply(presetId, 0)
		end
	end)
	ClientState.SettingsChanged:Connect(function()
		EnvironmentController.Apply(current, 0)
	end)

	task.spawn(function()
		local maps = Workspace:WaitForChild("Maps", 60)
		if maps then
			maps.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("Light") and descendant:GetAttribute("Secondary") and ClientState.Settings.PerformanceMode then
					descendant.Enabled = false
				end
			end)
		end
	end)
end

function EnvironmentController.Start()
	EnvironmentController.Apply("Lobby", 0)
end

return EnvironmentController
