--[[
	RankedService — ELO por partida ranked e leaderboard global (OrderedDataStore).
	Times usam a média do time adversário como oponente. Casual nunca mexe no ELO.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Elo = require(Shared.Progression.Elo)
local Ranks = require(Shared.Progression.Ranks)
local Registry = require(script.Parent.Parent.Registry)

local RankedService = {}

export type Entry = { UserId: number, Name: string, Elo: number, Tier: string }

local orderedStore: OrderedDataStore? = nil
local cachedBoard: { Entry } = {}
local nameCache: { [number]: string } = {}

local function store(): OrderedDataStore?
	if orderedStore then
		return orderedStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Data.LeaderboardStore)
	end)
	if ok then
		orderedStore = result
	end
	return orderedStore
end

local function eloOf(player: Player): number
	local data = Registry.DataService.GetData(player)
	return if data then data.Elo else Config.Ranked.StartElo
end

--[[
	teams: { A = {Player}, B = {Player} }, winner: "A" | "B" | nil (empate)
	Retorna { [Player] = delta }
]]
function RankedService.ApplyMatch(teams: { [string]: { Player } }, winner: string?): { [Player]: number }
	local averages = {}
	for team, players in teams do
		local ratings = {}
		for _, player in players do
			table.insert(ratings, eloOf(player))
		end
		averages[team] = Elo.Average(ratings)
	end

	local deltas: { [Player]: number } = {}
	for team, players in teams do
		local opponent = if team == "A" then averages.B else averages.A
		local score = if winner == nil then 0.5 elseif winner == team then 1 else 0
		for _, player in players do
			Registry.DataService.Update(player, function(data)
				local delta = Elo.Delta(data.Elo, opponent or Config.Ranked.StartElo, score, data.EloMatches)
				data.Elo = Elo.Apply(data.Elo, delta)
				data.EloMatches += 1
				data.PeakElo = math.max(data.PeakElo, data.Elo)
				if score == 1 then
					data.Stats.RankedWins = (data.Stats.RankedWins or 0) + 1
				elseif score == 0 then
					data.Stats.RankedLosses = (data.Stats.RankedLosses or 0) + 1
				end
				deltas[player] = delta
				task.spawn(RankedService.Submit, player.UserId, data.Elo)
			end)
		end
	end
	return deltas
end

-- Abandono no meio de uma ranked conta como derrota (senão sair "salvaria" o ELO de quem está perdendo).
function RankedService.ApplyAbandon(player: Player, opponents: { Player }): number?
	local ratings = {}
	for _, opponent in opponents do
		table.insert(ratings, eloOf(opponent))
	end
	local opponentElo = if #ratings > 0 then Elo.Average(ratings) else Config.Ranked.StartElo
	local applied: number? = nil
	Registry.DataService.Update(player, function(data)
		local delta = Elo.Delta(data.Elo, opponentElo, 0, data.EloMatches)
		data.Elo = Elo.Apply(data.Elo, delta)
		data.EloMatches += 1
		data.Stats.RankedLosses = (data.Stats.RankedLosses or 0) + 1
		applied = delta
		task.spawn(RankedService.Submit, player.UserId, data.Elo)
	end)
	return applied
end

function RankedService.Submit(userId: number, elo: number)
	local s = store()
	if not s or userId <= 0 then
		return
	end
	pcall(function()
		(s :: OrderedDataStore):SetAsync(tostring(userId), math.floor(elo))
	end)
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else `#{userId}`
	return nameCache[userId]
end

function RankedService.Refresh(): { Entry }
	local s = store()
	if not s then
		return cachedBoard
	end
	local ok, pages = pcall(function()
		return (s :: OrderedDataStore):GetSortedAsync(false, Config.Data.LeaderboardSize)
	end)
	if not ok or not pages then
		return cachedBoard
	end
	local board = {}
	for _, row in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(row.key) or 0
		table.insert(board, {
			UserId = userId,
			Name = nameFor(userId),
			Elo = row.value,
			Tier = Ranks.For(row.value).Name,
		})
	end
	cachedBoard = board
	return board
end

function RankedService.Board(): { Entry }
	return cachedBoard
end

function RankedService.Start()
	while true do
		RankedService.Refresh()
		local lobby = Registry.LobbyService
		if lobby and lobby.RenderLeaderboard then
			lobby.RenderLeaderboard(cachedBoard)
		end
		task.wait(Config.Data.LeaderboardRefresh)
	end
end

return RankedService
