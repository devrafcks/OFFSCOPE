local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {

	"Fire",
	"Melee",
	"Reload",
	"Equip",
	"Scope",
	"Vote",
	"SaveSettings",
	"Queue",

	"HitConfirm",
	"ShotFx",
	"MeleeFx",
	"KillFeed",
	"Killed",
	"Damaged",
	"MatchState",
	"Toast",
	"ProfileSync",
	"Environment",
	"VoteState",
	"QueueState",
	"KillEffect",
	"AmmoSync",
}

local FUNCTIONS = {
	"Shop",
	"GetShop",
}

local UNRELIABLE = {
	"Look",
}

local Remotes = {}

local cached: Folder? = nil

local function ensureFolder(): Folder
	if cached then
		return cached
	end
	local folder: Folder
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
	cached = folder
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
