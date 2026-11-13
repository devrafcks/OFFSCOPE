--!strict

local Config = require(script.Parent.Parent.Config)

local ShotStyle = {}

export type Input = {
	Weapon: string,
	Zone: string?,
	Distance: number,
	AdsAlpha: number,
	ScopeTime: number,
	Airborne: boolean,
	SpinDegrees: number,
	Backstab: boolean?,
}

ShotStyle.Order = { "Spin", "NoScope", "Quickscope", "Aerial", "Headshot", "LongShot", "Backstab", "Knife" }

ShotStyle.Labels = {
	Spin = "360",
	NoScope = "NO-SCOPE",
	Quickscope = "QUICKSCOPE",
	Aerial = "AÉREO",
	Headshot = "HEADSHOT",
	LongShot = "LONGA",
	Backstab = "PELAS COSTAS",
	Knife = "FACADA",
} :: { [string]: string }

ShotStyle.Colors = {
	Spin = Color3.fromRGB(255, 92, 210),
	NoScope = Color3.fromRGB(255, 196, 60),
	Quickscope = Color3.fromRGB(110, 210, 255),
	Aerial = Color3.fromRGB(150, 255, 170),
	Headshot = Color3.fromRGB(255, 84, 84),
	LongShot = Color3.fromRGB(200, 170, 255),
	Backstab = Color3.fromRGB(255, 140, 60),
	Knife = Color3.fromRGB(230, 230, 230),
} :: { [string]: Color3 }

ShotStyle.StatFor = {
	NoScope = "NoScopes",
	Quickscope = "Quickscopes",
	Headshot = "Headshots",
	LongShot = "LongShots",
	Aerial = "Aerials",
	Knife = "Knives",
	Backstab = "Knives",
} :: { [string]: string }

function ShotStyle.Classify(input: Input): { string }
	local style = Config.Style
	local tags = {}
	if input.Weapon == "Knife" then
		table.insert(tags, if input.Backstab then "Backstab" else "Knife")
		return tags
	end

	if input.SpinDegrees >= style.TrickSpinDegrees then
		table.insert(tags, "Spin")
	end
	if input.AdsAlpha < style.NoScopeMaxAds then
		table.insert(tags, "NoScope")
	elseif
		input.AdsAlpha >= Config.Sniper.Spread.QuickscopeStart
		and input.ScopeTime <= style.QuickscopeMaxScopeTime
	then
		table.insert(tags, "Quickscope")
	end
	if input.Airborne then
		table.insert(tags, "Aerial")
	end
	if input.Zone == "Head" then
		table.insert(tags, "Headshot")
	end
	if input.Distance >= style.LongShotDistance then
		table.insert(tags, "LongShot")
	end
	return tags
end

function ShotStyle.Coins(tags: { string }): number
	local rewards = Config.Rewards :: any
	local total = rewards.Kill :: number
	for _, tag in tags do
		total += rewards[tag] or 0
	end
	return total
end

return ShotStyle
