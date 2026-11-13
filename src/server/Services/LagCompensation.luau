local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hitbox = require(ReplicatedStorage.Shared.Combat.Hitbox)

local LagCompensation = {}

export type Snapshot = { Time: number, CFrames: { [string]: CFrame } }
export type Track = {
	Model: Model,
	Player: Player?,
	Parts: { [string]: BasePart },
	Sizes: { [string]: Vector3 },
	Buffer: { Snapshot },
	Head: number,
	Count: number,
}

local CAPACITY = math.ceil(Config.Netcode.HistoryHz * Config.Netcode.HistorySeconds) + 2
local tracks: { [Model]: Track } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function resolveParts(track: Track)
	local model = track.Model
	for _, name in Hitbox.TrackedParts do
		local part = track.Parts[name]
		if not part or part.Parent ~= model then
			local found = model:FindFirstChild(name)
			if found and found:IsA("BasePart") then
				track.Parts[name] = found
				track.Sizes[name] = found.Size
			else
				track.Parts[name] = nil
				track.Sizes[name] = nil
			end
		end
	end
end

function LagCompensation.Register(model: Model, player: Player?)
	local track: Track = {
		Model = model,
		Player = player,
		Parts = {},
		Sizes = {},
		Buffer = table.create(CAPACITY),
		Head = 0,
		Count = 0,
	}
	resolveParts(track)
	tracks[model] = track
	model.Destroying:Connect(function()
		tracks[model] = nil
	end)
end

function LagCompensation.Unregister(model: Model)
	tracks[model] = nil
end

function LagCompensation.Get(model: Model): Track?
	return tracks[model]
end

function LagCompensation.Tracks(): { [Model]: Track }
	return tracks
end

local function record(track: Track, time: number)
	resolveParts(track)
	local cframes = {}
	for name, part in track.Parts do
		if part.Parent then
			cframes[name] = part.CFrame
		end
	end
	track.Head = track.Head % CAPACITY + 1
	track.Buffer[track.Head] = { Time = time, CFrames = cframes }
	track.Count = math.min(track.Count + 1, CAPACITY)
end

function LagCompensation.Sample(model: Model, t: number): { [string]: CFrame }?
	local track = tracks[model]
	if not track or track.Count == 0 then
		return nil
	end
	local newest = track.Buffer[track.Head]
	if t >= newest.Time then

		local live = {}
		for name, part in track.Parts do
			live[name] = part.CFrame
		end
		return live
	end
	local older = newest
	for step = 1, track.Count - 1 do
		local index = (track.Head - step - 1) % CAPACITY + 1
		local snap = track.Buffer[index]
		if snap.Time <= t then
			local alpha = (t - snap.Time) / math.max(older.Time - snap.Time, 1e-4)
			local blended = {}
			for name, cf in snap.CFrames do
				local other = older.CFrames[name]
				blended[name] = if other then cf:Lerp(other, alpha) else cf
			end
			return blended
		end
		older = snap
	end
	return older.CFrames
end

function LagCompensation.RewindTime(player: Player, clientTime: number): number
	local n = Config.Netcode
	local current = now()
	local ping = 0
	pcall(function()
		ping = player:GetNetworkPing()
	end)
	local target = clientTime - ping * 0.5 - n.InterpolationDelay
	return math.clamp(target, current - n.MaxRewind, current)
end

function LagCompensation.Now(): number
	return now()
end

function LagCompensation.Start()
	local interval = 1 / Config.Netcode.HistoryHz
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < interval then
			return
		end
		accumulator = 0
		local t = now()
		for model, track in tracks do
			if model.Parent then
				record(track, t)
			end
		end
	end)
end

return LagCompensation
