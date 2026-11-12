--!strict
-- ELO clássico. Times usam a média do time como rating de entrada.

local Config = require(script.Parent.Parent.Config)

local Elo = {}

function Elo.Expected(rating: number, opponent: number): number
	return 1 / (1 + 10 ^ ((opponent - rating) / 400))
end

function Elo.KFactor(matchesPlayed: number): number
	local r = Config.Ranked
	return if matchesPlayed < r.NewPlayerMatches then r.KFactorNew else r.KFactor
end

-- score: 1 vitória, 0 derrota, 0.5 empate
function Elo.Delta(rating: number, opponent: number, score: number, matchesPlayed: number): number
	local k = Elo.KFactor(matchesPlayed)
	return math.floor(k * (score - Elo.Expected(rating, opponent)) + 0.5)
end

function Elo.Apply(rating: number, delta: number): number
	return math.max(Config.Ranked.MinElo, rating + delta)
end

function Elo.Average(ratings: { number }): number
	if #ratings == 0 then
		return Config.Ranked.StartElo
	end
	local sum = 0
	for _, r in ratings do
		sum += r
	end
	return sum / #ratings
end

-- Soft reset de temporada: puxa todo mundo para perto do início.
function Elo.SoftReset(rating: number): number
	local r = Config.Ranked
	return math.floor(r.StartElo + (rating - r.StartElo) * r.SoftResetWeight + 0.5)
end

return Elo
