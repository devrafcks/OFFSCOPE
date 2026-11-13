--!strict

local Config = require(script.Parent.Parent.Config)

local Ranks = {}

export type Tier = { Name: string, MinElo: number, Color: Color3, Index: number }

function Ranks.For(elo: number): Tier
	local tiers = Config.Ranked.Tiers
	local chosen = 1
	for index, tier in tiers do
		if elo >= tier.MinElo then
			chosen = index
		end
	end
	local tier = tiers[chosen]
	return { Name = tier.Name, MinElo = tier.MinElo, Color = tier.Color, Index = chosen }
end

function Ranks.Progress(elo: number): number
	local tiers = Config.Ranked.Tiers
	local current = Ranks.For(elo)
	local nextTier = tiers[current.Index + 1]
	if not nextTier then
		return 1
	end
	return math.clamp((elo - current.MinElo) / (nextTier.MinElo - current.MinElo), 0, 1)
end

return Ranks
