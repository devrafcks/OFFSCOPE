local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local Registry = require(script.Parent.Registry)

Remotes.Init()

local ORDER = {
	"DataService",
	"AntiCheatService",
	"LagCompensation",
	"CombatState",
	"CharacterService",
	"DamageService",
	"HitscanService",
	"MeleeService",
	"ProgressionService",
	"RankedService",
	"InventoryService",
	"MonetizationService",
	"TeleportServiceWrapper",
	"MapService",
	"RoundService",
	"MatchmakingService",
	"LobbyService",
}

local services = script.Parent:WaitForChild("Services")

for _, name in ORDER do
	Registry[name] = require(services:WaitForChild(name)) :: any
end

for _, name in ORDER do
	local service = Registry[name]
	if type(service.Init) == "function" then
		service.Init()
	end
end

for _, name in ORDER do
	local service = Registry[name]
	if type(service.Start) == "function" then
		task.spawn(service.Start)
	end
end

print(`[{Config.Game.Name}] servidor pronto · v{Config.Game.Version} · papel: {Registry.RoundService.Role()}`)
