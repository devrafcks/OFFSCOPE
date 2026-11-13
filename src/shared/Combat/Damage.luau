--!strict

local Config = require(script.Parent.Parent.Config)

local Damage = {}

export type Zone = "Head" | "Chest" | "Stomach" | "Limb"

function Damage.FalloffMultiplier(distance: number): number
	local f = Config.Sniper.Falloff
	if distance <= f.FullUntil then
		return 1
	elseif distance >= f.MinAt then
		return f.MinMultiplier
	end
	local t = (distance - f.FullUntil) / (f.MinAt - f.FullUntil)
	return 1 + (f.MinMultiplier - 1) * t
end

function Damage.Sniper(zone: Zone, distance: number): number
	local base = (Config.Sniper.Damage :: any)[zone] :: number
	if zone == "Head" and Config.Sniper.Falloff.HeadIgnoresFalloff then
		return base
	end
	return math.floor(base * Damage.FalloffMultiplier(distance) + 0.5)
end

function Damage.Knife(backstab: boolean): number
	return if backstab then Config.Knife.BackDamage else Config.Knife.FrontDamage
end

return Damage
