local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local ShotStyle = require(Shared.Combat.ShotStyle)
local Registry = require(script.Parent.Parent.Registry)

local DamageService = {}

DamageService.Killed = Signal.new()
DamageService.Damaged = Signal.new()

export type DamageInfo = {
	Attacker: Player,
	Victim: Model,
	Amount: number,
	Weapon: string,
	Zone: string?,
	Distance: number,
	Origin: Vector3,
	HitPosition: Vector3,
	AdsAlpha: number?,
	ScopeTime: number?,
	Airborne: boolean?,
	SpinDegrees: number?,
	Backstab: boolean?,
}

export type DamageResult = { Applied: boolean, Killed: boolean, Amount: number, Tags: { string }? }

local lastDamage: { [Model]: number } = {}

function DamageService.CanDamage(attacker: Player, victim: Model): boolean
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if attacker.Character == victim then
		return false
	end
	if Registry.CharacterService.IsProtected(victim) then
		return false
	end

	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local attackerContext = Registry.CharacterService.GetContext(attacker)

	if not victimPlayer then

		return victim:GetAttribute("Dummy") == true and attackerContext.Kind == "Lobby"
	end

	local victimContext = Registry.CharacterService.GetContext(victimPlayer)
	if attackerContext.Kind ~= "Match" or victimContext.Kind ~= "Match" then
		return false
	end
	if attackerContext.Match ~= victimContext.Match then
		return false
	end
	return attackerContext.Match:AreEnemies(attacker, victimPlayer)
end

function DamageService.Apply(info: DamageInfo): DamageResult
	local victim = info.Victim
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or not DamageService.CanDamage(info.Attacker, victim) then
		return { Applied = false, Killed = false, Amount = 0 }
	end

	local amount = math.max(0, math.floor(info.Amount))
	local before = humanoid.Health
	humanoid.Health = math.max(0, before - amount)
	lastDamage[victim] = os.clock()

	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	if victimPlayer then
		Remotes.Event("Damaged"):FireClient(victimPlayer, info.Origin, amount)
	end
	DamageService.Damaged:Fire(info, amount)

	if humanoid.Health > 0 then
		return { Applied = true, Killed = false, Amount = amount }
	end

	local tags = ShotStyle.Classify({
		Weapon = info.Weapon,
		Zone = info.Zone,
		Distance = info.Distance,
		AdsAlpha = info.AdsAlpha or 0,
		ScopeTime = info.ScopeTime or 0,
		Airborne = info.Airborne == true,
		SpinDegrees = info.SpinDegrees or 0,
		Backstab = info.Backstab,
	})

	DamageService.AnnounceKill(info, victimPlayer, tags)
	DamageService.Killed:Fire(info, victimPlayer, tags)
	return { Applied = true, Killed = true, Amount = amount, Tags = tags }
end

function DamageService.AnnounceKill(info: DamageInfo, victimPlayer: Player?, tags: { string })
	local attacker = info.Attacker
	local context = Registry.CharacterService.GetContext(attacker)
	local data = Registry.DataService.GetData(attacker)
	local equipped = data and data.Equipped or Config.DefaultEquipped

	local victimName = if victimPlayer then victimPlayer.DisplayName else (info.Victim:GetAttribute("DisplayName") or "Alvo")
	local entry = {
		Killer = attacker.DisplayName,
		KillerId = attacker.UserId,
		Victim = victimName,
		VictimId = if victimPlayer then victimPlayer.UserId else 0,
		Weapon = info.Weapon,
		Tags = tags,
		Distance = math.floor(info.Distance),
		KillerTeam = attacker:GetAttribute("Team"),
		VictimTeam = if victimPlayer then victimPlayer:GetAttribute("Team") else nil,
	}

	local audience: { Player }
	if context.Kind == "Match" then
		audience = context.Match:GetPlayers()
	else
		audience = { attacker }
	end
	local feed = Remotes.Event("KillFeed")
	for _, player in audience do
		feed:FireClient(player, entry)
	end

	if victimPlayer then
		Remotes.Event("Killed"):FireClient(victimPlayer, {
			Killer = attacker,
			KillerName = attacker.DisplayName,
			Origin = info.Origin,
			HitPosition = info.HitPosition,
			Weapon = info.Weapon,
			Tags = tags,
			Distance = math.floor(info.Distance),
			Wrap = equipped.Wrap,
			RespawnIn = if context.Kind == "Match" then context.Match:RespawnDelay() else 2,
		})
	end

	local effectId = if info.Weapon == "Knife" and equipped.Finisher ~= "finisher_none" then equipped.Finisher else equipped.KillEffect
	local effects = Remotes.Event("KillEffect")
	for _, player in audience do
		effects:FireClient(player, effectId, info.HitPosition, attacker)
	end
end

local function regenLoop()
	local step = 0.25
	while true do
		task.wait(step)
		local t = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if character and humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				if character:GetAttribute("Regen") and t - (lastDamage[character] or 0) >= Config.Player.RegenDelay then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Player.RegenPerSecond * step)
				end
			end
		end
		for model in lastDamage do
			if not model.Parent then
				lastDamage[model] = nil
			end
		end
	end
end

function DamageService.Start()
	regenLoop()
end

return DamageService
