--!strict
-- Curva de XP da conta e do passe.

local Config = require(script.Parent.Parent.Config)

local Levels = {}

function Levels.XpForLevel(level: number): number
	local l = Config.Levels
	return math.floor(l.BaseXp * l.Growth ^ (level - 1) + 0.5)
end

-- Aplica XP ganho; retorna novo nível, XP dentro do nível e quantos níveis subiu.
function Levels.Add(level: number, xp: number, gained: number): (number, number, number)
	local maxLevel = Config.Levels.MaxLevel
	local ups = 0
	xp += gained
	while level < maxLevel and xp >= Levels.XpForLevel(level) do
		xp -= Levels.XpForLevel(level)
		level += 1
		ups += 1
	end
	if level >= maxLevel then
		xp = 0
	end
	return level, xp, ups
end

function Levels.PassTier(passXp: number): number
	local p = Config.Pass
	return math.clamp(passXp // p.XpPerTier, 0, p.Tiers)
end

return Levels
