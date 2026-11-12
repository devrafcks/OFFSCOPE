--!strict
-- Interseção raio × OBB (slab method) e mapeamento de parte → zona de dano.

local Hitbox = {}

export type Zone = "Head" | "Chest" | "Stomach" | "Limb"

local ZONES: { [string]: Zone } = {
	Head = "Head",
	UpperTorso = "Chest",
	Torso = "Chest", -- R6
	LowerTorso = "Stomach",
}

-- Partes que entram no histórico de hitbox (R15 + R6). Acessórios nunca contam.
Hitbox.TrackedParts = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"Torso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

-- Prioridade quando dois OBBs empatam na distância (cabeça ganha).
Hitbox.ZonePriority = { Head = 4, Chest = 3, Stomach = 2, Limb = 1 } :: { [string]: number }

function Hitbox.ZoneOf(partName: string): Zone
	return ZONES[partName] or "Limb"
end

--[[
	Retorna a distância `t` ao longo do raio até entrar no OBB, ou nil.
	`direction` deve ser unitário. `padding` aumenta o OBB em todas as faces (lag/feel).
]]
function Hitbox.RayOBB(origin: Vector3, direction: Vector3, cframe: CFrame, size: Vector3, padding: number?): number?
	local half = size * 0.5 + Vector3.one * (padding or 0)
	local o = cframe:PointToObjectSpace(origin)
	local d = cframe:VectorToObjectSpace(direction)

	local tMin = -math.huge
	local tMax = math.huge
	local origins = { o.X, o.Y, o.Z }
	local dirs = { d.X, d.Y, d.Z }
	local halves = { half.X, half.Y, half.Z }

	for axis = 1, 3 do
		local oa, da, ha = origins[axis], dirs[axis], halves[axis]
		if math.abs(da) < 1e-8 then
			if oa < -ha or oa > ha then
				return nil
			end
		else
			local inv = 1 / da
			local t1 = (-ha - oa) * inv
			local t2 = (ha - oa) * inv
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return nil
			end
		end
	end

	if tMax < 0 then
		return nil
	end
	return math.max(tMin, 0)
end

-- Distância de um ponto até o OBB (0 se dentro). Usada na faca.
function Hitbox.PointOBBDistance(point: Vector3, cframe: CFrame, size: Vector3): number
	local p = cframe:PointToObjectSpace(point)
	local half = size * 0.5
	local dx = math.max(math.abs(p.X) - half.X, 0)
	local dy = math.max(math.abs(p.Y) - half.Y, 0)
	local dz = math.max(math.abs(p.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

return Hitbox
