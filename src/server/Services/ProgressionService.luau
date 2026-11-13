local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ShotStyle = require(Shared.Combat.ShotStyle)
local Levels = require(Shared.Progression.Levels)
local Registry = require(script.Parent.Parent.Registry)

local ProgressionService = {}

function ProgressionService.Toast(player: Player, payload: { [string]: any })
	Remotes.Event("Toast"):FireClient(player, payload)
end

local function today(): number
	return os.time() // 86400
end

function ProgressionService.RollDailyChallenges(player: Player, data)
	local day = today()
	if data.Daily.Day == day and #data.Daily.Ids > 0 then
		return
	end
	local pool = Config.DailyChallenges.Pool
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	local rng = Random.new(day * 31 + player.UserId)
	for i = #indices, 2, -1 do
		local j = rng:NextInteger(1, i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local ids = {}
	local base = {}
	for i = 1, math.min(Config.DailyChallenges.Count, #pool) do
		local challenge = pool[indices[i]]
		table.insert(ids, challenge.Id)
		base[challenge.Id] = data.Stats[challenge.Stat] or 0
	end
	data.Daily = { Day = day, Ids = ids, Base = base, Claimed = {} }
end

local function challengeById(id: string)
	for _, challenge in Config.DailyChallenges.Pool do
		if challenge.Id == id then
			return challenge
		end
	end
	return nil
end

local function checkDaily(player: Player, data)
	if data.Daily.Day ~= today() then
		ProgressionService.RollDailyChallenges(player, data)
		return
	end
	for _, id in data.Daily.Ids do
		local challenge = challengeById(id)
		if challenge and not data.Daily.Claimed[id] then
			local progress = (data.Stats[challenge.Stat] or 0) - (data.Daily.Base[id] or 0)
			if progress >= challenge.Goal then
				data.Daily.Claimed[id] = true
				data.Coins += challenge.Coins
				ProgressionService.Toast(player, {
					Kind = "Challenge",
					Text = `Desafio concluído: {challenge.Text}`,
					Coins = challenge.Coins,
				})
			end
		end
	end
end

function ProgressionService.AddXp(player: Player, data, amount: number)
	local level, xp, ups = Levels.Add(data.Level, data.Xp, amount)
	data.Level = level
	data.Xp = xp
	if ups > 0 then
		ProgressionService.Toast(player, { Kind = "Level", Text = `Nível {level}!` })
	end
	local passBefore = Levels.PassTier(data.Pass.Xp)
	data.Pass.Xp += amount
	local passAfter = Levels.PassTier(data.Pass.Xp)
	if passAfter > passBefore then
		ProgressionService.Toast(player, { Kind = "Pass", Text = `Passe: tier {passAfter} liberado` })
	end
end

local function onKill(info, victimPlayer: Player?, tags: { string })
	local attacker: Player = info.Attacker
	local context = Registry.CharacterService.GetContext(attacker)

	if not victimPlayer then

		if #tags > 0 then
			ProgressionService.Toast(attacker, { Kind = "Style", Tags = tags, Coins = Config.Rewards.RangeKillCoins, Distance = info.Distance })
		end
		return
	end
	if context.Kind ~= "Match" then
		return
	end

	Registry.AntiCheatService.RecordKill(attacker, table.find(tags, "Headshot") ~= nil)

	local coins = ShotStyle.Coins(tags)
	Registry.DataService.Update(attacker, function(data)
		data.Coins += coins
		data.Stats.Kills += 1
		for _, tag in tags do
			local stat = ShotStyle.StatFor[tag]
			if stat then
				data.Stats[stat] = (data.Stats[stat] or 0) + 1
			end
		end
		if info.Weapon == "Sniper" and info.Distance > data.Stats.LongestShot then
			data.Stats.LongestShot = math.floor(info.Distance)
		end
		ProgressionService.AddXp(attacker, data, Config.Rewards.XpPerKill)
		checkDaily(attacker, data)
	end)
	ProgressionService.Toast(attacker, { Kind = "Style", Tags = tags, Coins = coins, Distance = info.Distance })

	Registry.DataService.Update(victimPlayer, function(data)
		data.Stats.Deaths += 1
	end)
end

function ProgressionService.MatchResult(player: Player, won: boolean, roundsWon: number): (number, number)
	local coins = (if won then Config.Rewards.MatchWin else Config.Rewards.MatchLoss) + roundsWon * Config.Rewards.RoundWin
	local xp = Config.Rewards.XpPerMatch + (if won then Config.Rewards.XpWinBonus else 0)
	Registry.DataService.Update(player, function(data)
		data.Coins += coins
		data.Stats.Matches += 1
		if won then
			data.Stats.Wins += 1
		else
			data.Stats.Losses += 1
		end
		ProgressionService.AddXp(player, data, xp)
		checkDaily(player, data)
	end)
	return coins, xp
end

function ProgressionService.Init()
	Registry.DamageService.Killed:Connect(onKill)
end

function ProgressionService.Start()

	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			local data = Registry.DataService.GetData(player)
			if data and data.Daily.Day ~= today() then
				Registry.DataService.Update(player, function(d)
					ProgressionService.RollDailyChallenges(player, d)
				end)
			end
		end
	end
end

return ProgressionService
