local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local AntiCheatService = {}

type LookSample = { Time: number, Pitch: number, Yaw: number }
type Record = {
	Looks: { LookSample },
	Score: number,
	Flags: { [string]: number },
	Kills: number,
	Headshots: number,
	LastPosition: Vector3?,
	LastSampleTime: number,
	GraceUntil: number,
	LastPitchSent: number,
}

local records: { [Player]: Record } = {}
local lookLimiter = RateLimiter.new(table.unpack(Config.Netcode.RemoteBudgets.Look))
local LOOK_HISTORY = 2.0

local function get(player: Player): Record
	local record = records[player]
	if not record then
		record = {
			Looks = {},
			Score = 0,
			Flags = {},
			Kills = 0,
			Headshots = 0,
			LastPosition = nil,
			LastSampleTime = 0,
			GraceUntil = 0,
			LastPitchSent = 0,
		}
		records[player] = record
	end
	return record
end

function AntiCheatService.Flag(player: Player, reason: string, weight: number, detail: string?)
	local record = get(player)
	record.Score += weight
	record.Flags[reason] = (record.Flags[reason] or 0) + 1
	if record.Score >= Config.AntiCheat.SuspicionLogThreshold then
		warn(`[AntiCheat] {player.Name} ({player.UserId}) score={record.Score} motivo={reason} {detail or ""}`)
	end
	if record.Score >= Config.AntiCheat.KickThreshold then
		player:Kick("Atividade suspeita detectada.")
	end
end

function AntiCheatService.Grace(player: Player, seconds: number?)
	local record = get(player)
	record.GraceUntil = os.clock() + (seconds or 2)
	record.LastPosition = nil
end

local function unwrap(delta: number): number
	return (delta + math.pi) % (2 * math.pi) - math.pi
end

function AntiCheatService.SpinDegrees(player: Player, window: number): number
	local looks = get(player).Looks
	local cutoff = os.clock() - window
	local total = 0
	local previous: LookSample? = nil
	for _, sample in looks do
		if sample.Time >= cutoff then
			if previous then
				total += math.abs(unwrap(sample.Yaw - previous.Yaw))
			end
			previous = sample
		end
	end
	return math.deg(total)
end

function AntiCheatService.LatestLook(player: Player): Vector3?
	local looks = get(player).Looks
	local last = looks[#looks]
	if not last then
		return nil
	end
	return CFrame.fromEulerAnglesYXZ(last.Pitch, last.Yaw, 0).LookVector
end

function AntiCheatService.CheckAim(player: Player, look: Vector3)
	local replicated = AntiCheatService.LatestLook(player)
	if not replicated then
		return
	end
	local angle = math.deg(math.acos(math.clamp(replicated:Dot(look), -1, 1)))
	if angle > Config.Netcode.AimConeDegrees then
		AntiCheatService.Flag(player, "AimCone", 1, string.format("%.0f°", angle))
	end

	local looks = get(player).Looks
	local n = #looks
	if n >= 2 then
		local a, b = looks[n - 1], looks[n]
		if b.Time - a.Time <= Config.AntiCheat.SnapWindow * 3 then
			local snap = math.deg(math.abs(unwrap(b.Yaw - a.Yaw)))
			if snap >= Config.AntiCheat.SnapDegreesSuspicious then
				AntiCheatService.Flag(player, "Snap", 0.5, string.format("%.0f°", snap))
			end
		end
	end
end

function AntiCheatService.RecordKill(player: Player, headshot: boolean)
	local record = get(player)
	record.Kills += 1
	if headshot then
		record.Headshots += 1
	end
	local sample = Config.AntiCheat.HeadshotRatioSample
	if record.Kills >= sample and record.Kills % 10 == 0 then
		local ratio = record.Headshots / record.Kills
		if ratio >= Config.AntiCheat.HeadshotRatioSuspicious then
			AntiCheatService.Flag(player, "HeadshotRatio", 3, string.format("%.0f%%", ratio * 100))
		end
	end
end

local function speedCheck()
	local ac = Config.AntiCheat
	local maxSpeed = math.max(Config.Movement.Slide.StartSpeed, Config.Movement.SprintSpeed * Config.Movement.KnifeSpeedMultiplier)
	while true do
		task.wait(ac.SpeedSampleInterval)
		local t = os.clock()
		for _, player in Players:GetPlayers() do
			local record = get(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or t < record.GraceUntil then
				record.LastPosition = nil
				continue
			end
			local position = root.Position
			if record.LastPosition then
				local elapsed = t - record.LastSampleTime
				local delta = position - record.LastPosition
				local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude / math.max(elapsed, 1e-3)
				if horizontal > maxSpeed * ac.SpeedTolerance + 6 then
					AntiCheatService.Flag(player, "Speed", 0.5, string.format("%.0f st/s", horizontal))
				end
			end
			record.LastPosition = position
			record.LastSampleTime = t
		end
	end
end

function AntiCheatService.Init()
	Remotes.Unreliable("Look").OnServerEvent:Connect(function(player, pitch, yaw)
		if type(pitch) ~= "number" or type(yaw) ~= "number" then
			return
		end
		if pitch ~= pitch or yaw ~= yaw or not lookLimiter:Allow(player) then
			return
		end
		local record = get(player)
		local sample = { Time = os.clock(), Pitch = math.clamp(pitch, -1.55, 1.55), Yaw = yaw }
		table.insert(record.Looks, sample)
		local cutoff = sample.Time - LOOK_HISTORY
		while record.Looks[1] and record.Looks[1].Time < cutoff do
			table.remove(record.Looks, 1)
		end

		local character = player.Character
		if character then
			local quantized = math.floor(sample.Pitch * 50 + 0.5) / 50
			if quantized ~= record.LastPitchSent then
				record.LastPitchSent = quantized
				character:SetAttribute("Pitch", quantized)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
		lookLimiter:Forget(player)
	end)
end

function AntiCheatService.Start()
	speedCheck()
end

return AntiCheatService
