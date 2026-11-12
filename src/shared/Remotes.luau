--!strict
--[[
	Remotes — lista única de RemoteEvents/Functions.
	O servidor cria as instâncias em ReplicatedStorage.Remotes; o cliente espera por elas.

	Regra da casa: o cliente NUNCA diz "acertei". Ele manda intenção (origem, direção, semente),
	o servidor decide.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- cliente → servidor
	"Fire", -- (origin, look, seed, spread, serverTime, adsAlpha, shotId)
	"Melee", -- (look, serverTime, quick)
	"Reload",
	"Equip", -- (slot: "Sniper" | "Knife")
	"Scope", -- (scoped: boolean)
	"Vote", -- (mapId)
	"SaveSettings", -- (settings table)
	"Queue", -- (modeId | nil)
	-- servidor → cliente
	"HitConfirm", -- { Zone, Damage, Killed, Target, ShotId, Tags }
	"ShotFx", -- (shooter, origin, hitPos, normal, material, tracerId, hitCharacter)
	"MeleeFx", -- (attacker, hitPos, backstab)
	"KillFeed", -- { Killer, Victim, Weapon, Tags, Distance, KillerTeam, VictimTeam }
	"Killed", -- (killcam data) para a vítima
	"Damaged", -- (fromPosition, amount) para a vítima
	"MatchState", -- snapshot do placar / estado
	"Toast", -- { Text, Kind, Coins }
	"ProfileSync", -- dados do perfil que o cliente pode ver
	"Environment", -- (presetId)
	"VoteState", -- { Options, Votes, EndsAt }
	"QueueState", -- { Mode, Count, Needed }
	"KillEffect", -- (effectId, position, killer) para todos por perto
	"AmmoSync", -- (mag, reserve) correção autoritativa
}

local FUNCTIONS = {
	"Shop", -- (action, payload) -> result
	"GetShop", -- () -> vitrine (loja diária, catálogo, passe)
}

local UNRELIABLE = {
	"Look", -- (pitch, yaw) ~12 Hz
}

local Remotes = {}

local folder: Folder

local function ensureFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			folder = existing :: Folder
		else
			local created = Instance.new("Folder")
			created.Name = "Remotes"
			for _, name in EVENTS do
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = created
			end
			for _, name in FUNCTIONS do
				local remote = Instance.new("RemoteFunction")
				remote.Name = name
				remote.Parent = created
			end
			for _, name in UNRELIABLE do
				local remote = Instance.new("UnreliableRemoteEvent")
				remote.Name = name
				remote.Parent = created
			end
			created.Parent = ReplicatedStorage
			folder = created
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder
end

function Remotes.Event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), `Remote desconhecido: {name}`)
	return ensureFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), `RemoteFunction desconhecida: {name}`)
	return ensureFolder():WaitForChild(name) :: RemoteFunction
end

function Remotes.Unreliable(name: string): UnreliableRemoteEvent
	assert(table.find(UNRELIABLE, name), `Unreliable desconhecido: {name}`)
	return ensureFolder():WaitForChild(name) :: UnreliableRemoteEvent
end

function Remotes.Init()
	ensureFolder()
end

return Remotes
