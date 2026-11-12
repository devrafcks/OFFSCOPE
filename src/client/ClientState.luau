--[[
	ClientState — estado do cliente vindo do servidor (perfil, partida, fila) + flags locais.
	Controllers leem daqui e escutam os sinais; ninguém guarda cópia própria.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local ClientState = {}

ClientState.Profile = nil :: any
ClientState.Match = nil :: any
ClientState.Queue = nil :: any
ClientState.Vote = nil :: any
ClientState.UiOpen = false -- loja/menu aberto: libera o mouse e pausa a mira
ClientState.Settings = {
	Sensitivity = 1,
	AdsSensitivity = Config.Camera.DefaultAdsSensitivity,
	Fov = Config.Camera.HipFov,
	PerformanceMode = false,
	ShowFps = false,
}

ClientState.ProfileChanged = Signal.new()
ClientState.MatchChanged = Signal.new()
ClientState.QueueChanged = Signal.new()
ClientState.VoteChanged = Signal.new()
ClientState.SettingsChanged = Signal.new()
ClientState.UiOpenChanged = Signal.new()

function ClientState.SetUiOpen(open: boolean)
	if ClientState.UiOpen ~= open then
		ClientState.UiOpen = open
		ClientState.UiOpenChanged:Fire(open)
	end
end

function ClientState.Equipped(category: string): string
	local profile = ClientState.Profile
	local value = profile and profile.Equipped and profile.Equipped[category]
	return value or (Config.DefaultEquipped :: any)[category]
end

function ClientState.Owns(itemId: string): boolean
	local item = Config.Cosmetics[itemId]
	if item and item.Pool == "default" then
		return true
	end
	local profile = ClientState.Profile
	return profile ~= nil and profile.Inventory[itemId] == true
end

function ClientState.InMatch(): boolean
	return ClientState.Match ~= nil
end

function ClientState.SaveSettings(changes: { [string]: any })
	for key, value in changes do
		ClientState.Settings[key] = value
	end
	ClientState.SettingsChanged:Fire(ClientState.Settings)
	Remotes.Event("SaveSettings"):FireServer(changes)
end

function ClientState.Init()
	Remotes.Event("ProfileSync").OnClientEvent:Connect(function(profile)
		local first = ClientState.Profile == nil
		ClientState.Profile = profile
		if first and profile.Settings then
			for key, value in profile.Settings do
				ClientState.Settings[key] = value
			end
			ClientState.SettingsChanged:Fire(ClientState.Settings)
		end
		ClientState.ProfileChanged:Fire(profile)
	end)
	Remotes.Event("MatchState").OnClientEvent:Connect(function(state)
		ClientState.Match = state
		if state == nil then
			ClientState.Vote = nil
			ClientState.VoteChanged:Fire(nil)
		end
		ClientState.MatchChanged:Fire(state)
	end)
	Remotes.Event("QueueState").OnClientEvent:Connect(function(state)
		ClientState.Queue = state
		ClientState.QueueChanged:Fire(state)
	end)
	Remotes.Event("VoteState").OnClientEvent:Connect(function(state)
		ClientState.Vote = state
		ClientState.VoteChanged:Fire(state)
	end)
end

return ClientState
