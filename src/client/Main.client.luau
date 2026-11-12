--[[
	OFFSCOPE — bootstrap do cliente.
	Init (ligações, nada que espere) → Start (loops e render steps). Ordem importa:
	estado → input → câmera/movimento → arma/efeitos/HUD → telas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

Remotes.Init()

local ClientState = require(script.Parent.ClientState)
local Controllers = script.Parent.Controllers

local ORDER = {
	"InputController",
	"CameraController",
	"MovementController",
	"ViewmodelController",
	"EffectsController",
	"HudController",
	"WeaponController",
	"EnvironmentController",
	"CharacterPoseController",
	"KillcamController",
	"MatchUiController",
	"ShopController",
	"MenuController",
}

ClientState.Init()

local modules = {}
for _, name in ORDER do
	modules[name] = require(Controllers:WaitForChild(name)) :: any
end

for _, name in ORDER do
	local controller = modules[name]
	if type(controller.Init) == "function" then
		local ok, err = pcall(controller.Init)
		if not ok then
			warn(`[{Config.Game.Name}] {name}.Init falhou:`, err)
		end
	end
end

for _, name in ORDER do
	local controller = modules[name]
	if type(controller.Start) == "function" then
		task.spawn(controller.Start)
	end
end
