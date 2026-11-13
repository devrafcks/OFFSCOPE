--!strict

local Config = require(script.Parent.Parent.Config)

local Spread = {}

export type MoveState = {
	Speed: number,
	Grounded: boolean,
	Sliding: boolean,
	Sprinting: boolean,
	AdsAlpha: number,
}

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function Spread.MovementMultiplier(state: MoveState): number
	local s = Config.Sniper.Spread
	if not state.Grounded then
		return s.Air
	elseif state.Sliding then
		return s.Slide
	elseif state.Speed > s.WalkSpeedThreshold then
		return if state.Sprinting then s.Sprint else s.Walk
	end
	return 1
end

function Spread.Compute(state: MoveState): number
	local s = Config.Sniper.Spread
	local mult = Spread.MovementMultiplier(state)
	local hip = s.Base * mult
	local ads = state.AdsAlpha
	if ads <= s.QuickscopeStart then
		return hip
	end

	local scoped = s.AdsSpread * math.sqrt(mult)
	local t = smoothstep((ads - s.QuickscopeStart) / (1 - s.QuickscopeStart))
	return hip + (scoped - hip) * t
end

function Spread.Apply(look: Vector3, spreadDegrees: number, seed: number): Vector3
	if spreadDegrees <= 0 then
		return look.Unit
	end
	local rng = Random.new(seed)
	local theta = rng:NextNumber() * math.pi * 2
	local radius = math.rad(spreadDegrees) * math.sqrt(rng:NextNumber())
	local basis = CFrame.lookAt(Vector3.zero, look)
	return (basis * CFrame.Angles(0, 0, theta) * CFrame.Angles(radius, 0, 0)).LookVector
end

function Spread.ToPixels(spreadDegrees: number, fovDegrees: number, viewportHeight: number): number
	local half = math.tan(math.rad(fovDegrees) / 2)
	return math.tan(math.rad(spreadDegrees)) / half * (viewportHeight / 2)
end

return Spread
