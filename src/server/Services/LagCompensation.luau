--[[
	LagCompensation — histórico de hitboxes para rewind (padrão RollbackHitbox).

	A 30 Hz guarda o CFrame de cada parte do corpo de cada alvo registrado (jogadores e dummies).
	Buffer circular de ~1 s. `Sample(model, t)` interpola entre os dois snapshots vizinhos.
	O relógio é workspace:GetServerTimeNow() — o mesmo que o cliente manda no tiro.
]]

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
	Head: number, -- índice do mais recente
	Count: number,
}

local CAPACITY = math.ceil(Config.Netcode.HistoryHz * Config.Netcode.HistorySeconds) + 2
local tracks: { [Model]: Track } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

function LagCompensation.Register(model: Model, player: Player?)
	local parts: { [string]: BasePart } = {}
	local sizes: { [string]: Vector3 } = {}
	for _, name in Hitbox.TrackedParts do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			parts[name] = part
			sizes[name] = part.Size
		end
	end
	tracks[model] = {
		Model = model,
		Player = player,
		Parts = parts,
		Sizes = sizes,
		Buffer = table.create(CAPACITY),
		Head = 0,
		Count = 0,
	}
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

-- Snapshot interpolado no instante `t` (clampado ao intervalo gravado).
function LagCompensation.Sample(model: Model, t: number): { [string]: CFrame }?
	local track = tracks[model]
	if not track or track.Count == 0 then
		return nil
	end
	local newest = track.Buffer[track.Head]
	if t >= newest.Time then
		-- mais novo que o último snapshot: usa a pose atual (mais precisa)
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
	return older.CFrames -- mais antigo disponível
end

-- Instante de rewind para um tiro enviado em `clientTime` por `player`.
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
