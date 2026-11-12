--!strict
-- Mola amortecida (semi-implícita) para Vector3 — usada em sway, recoil e bob da viewmodel.

export type Spring = {
	Position: Vector3,
	Velocity: Vector3,
	Target: Vector3,
	Stiffness: number,
	Damping: number,
	Impulse: (self: Spring, force: Vector3) -> (),
	Step: (self: Spring, dt: number) -> Vector3,
}

local Spring = {}
Spring.__index = Spring

function Spring.new(stiffness: number, damping: number): Spring
	local self = {
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		Target = Vector3.zero,
		Stiffness = stiffness,
		Damping = damping,
	}
	return (setmetatable(self, Spring) :: any) :: Spring
end

function Spring:Impulse(force: Vector3)
	self.Velocity += force
end

function Spring:Step(dt: number): Vector3
	-- sub-passos fixos: estável mesmo com dt grande (hitch de frame)
	local remaining = math.min(dt, 0.1)
	local stepSize = 1 / 240
	while remaining > 0 do
		local h = math.min(stepSize, remaining)
		local force = (self.Target - self.Position) * self.Stiffness - self.Velocity * self.Damping
		self.Velocity += force * h
		self.Position += self.Velocity * h
		remaining -= h
	end
	return self.Position
end

return Spring
