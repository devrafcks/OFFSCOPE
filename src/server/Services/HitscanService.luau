local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(Shared.Util.RateLimiter)
local Spread = require(Shared.Combat.Spread)
local Damage = require(Shared.Combat.Damage)
local Hitbox = require(Shared.Combat.Hitbox)
local Registry = require(script.Parent.Parent.Registry)

local HitscanService = {}

local fireLimiter = RateLimiter.new(table.unpack(Config.Netcode.RemoteBudgets.Fire))

local function finiteVector(v: any): boolean
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

local function finiteNumber(n: any): boolean
	return type(n) == "number" and n == n and n > -1e12 and n < 1e12
end

local function worldParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for model in Registry.LagCompensation.Tracks() do
		table.insert(ignore, model)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local effects = Workspace:FindFirstChild("Effects")
	if effects then
		table.insert(ignore, effects)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

HitscanService.WorldParams = worldParams

local function serverMoveState(character: Model, adsAlpha: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
	return {
		Speed = horizontal,
		Grounded = grounded,
		Sliding = false,
		Sprinting = horizontal > Config.Movement.WalkSpeed + 2,
		AdsAlpha = adsAlpha,
	}
end

export type CastResult = {
	Model: Model?,
	Part: string?,
	Zone: string?,
	Position: Vector3,
	Normal: Vector3,
	Material: Enum.Material?,
	Distance: number,
}

function HitscanService.Cast(origin: Vector3, direction: Vector3, rewindTime: number, shooter: Model?, filter: (Model) -> boolean): CastResult
	local range = Config.Sniper.Range
	local world = Workspace:Raycast(origin, direction * range, worldParams())
	local worldDistance = if world then world.Distance else range

	local bestT = math.huge
	local bestModel: Model? = nil
	local bestPart: string? = nil
	local padding = Config.Netcode.HitboxPadding

	for model, track in Registry.LagCompensation.Tracks() do
		if model == shooter or not model.Parent or not filter(model) then
			continue
		end
		local snapshot = Registry.LagCompensation.Sample(model, rewindTime)
		if not snapshot then
			continue
		end

		local center = snapshot.UpperTorso or snapshot.Torso or snapshot.Head
		if center then
			local toCenter = center.Position - origin
			local along = toCenter:Dot(direction)
			if along < -4 or along > worldDistance + 4 then
				continue
			end
			local closest = origin + direction * along
			if (center.Position - closest).Magnitude > 7 then
				continue
			end
		end

		local modelT = math.huge
		local modelPart: string? = nil
		local modelPriority = 0
		for name, cframe in snapshot do
			local size = track.Sizes[name]
			if not size then
				continue
			end
			local t = Hitbox.RayOBB(origin, direction, cframe, size, padding)
			if t and t <= worldDistance then
				local priority = Hitbox.ZonePriority[Hitbox.ZoneOf(name)]
				if priority > modelPriority or (priority == modelPriority and t < modelT) then
					modelT = t
					modelPart = name
					modelPriority = priority
				end
			end
		end
		if modelPart and modelT < bestT then
			bestT = modelT
			bestModel = model
			bestPart = modelPart
		end
	end

	if bestModel then
		return {
			Model = bestModel,
			Part = bestPart,
			Zone = Hitbox.ZoneOf(bestPart :: string),
			Position = origin + direction * bestT,
			Normal = -direction,
			Material = nil,
			Distance = bestT,
		}
	end
	return {
		Model = nil,
		Position = if world then world.Position else origin + direction * range,
		Normal = if world then world.Normal else -direction,
		Material = if world then world.Material else nil,
		Distance = worldDistance,
	}
end

local function onFire(player: Player, origin: any, look: any, seed: any, spread: any, clientTime: any, adsAlpha: any, shotId: any)

	if not (finiteVector(origin) and finiteVector(look) and finiteNumber(seed) and finiteNumber(spread)) then
		return
	end
	if not (finiteNumber(clientTime) and finiteNumber(adsAlpha) and finiteNumber(shotId)) then
		return
	end
	if not fireLimiter:Allow(player) then
		Registry.AntiCheatService.Flag(player, "FireRate", 1)
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not character or not humanoid or humanoid.Health <= 0 or not head then
		return
	end
	if character:GetAttribute("Frozen") then
		return
	end
	local CombatState = Registry.CombatState
	local state = CombatState.Get(player)
	local nowClock = os.clock()
	if state.Slot ~= "Sniper" or CombatState.IsReloading(state) or nowClock < state.EquipEnd - 0.1 then
		Remotes.Event("AmmoSync"):FireClient(player, state.Mag, state.Reserve)
		return
	end
	if nowClock - state.LastShot < Config.Sniper.BoltTime - Config.Netcode.BoltTolerance then
		Registry.AntiCheatService.Flag(player, "BoltTime", 1)
		return
	end
	if state.Mag <= 0 then
		Remotes.Event("AmmoSync"):FireClient(player, state.Mag, state.Reserve)
		return
	end
	state.LastShot = nowClock
	state.Mag -= 1

	if (origin - head.Position).Magnitude > Config.Netcode.MaxOriginDistance then
		Registry.AntiCheatService.Flag(player, "Origin", 2)
		origin = head.Position
	end

	look = (look :: Vector3).Unit
	local clampedAds = math.clamp(adsAlpha, 0, CombatState.MaxAdsAlpha(state))
	local minimum = Spread.Compute(serverMoveState(character, clampedAds)) * Config.Netcode.SpreadTolerance
	local usedSpread = spread
	if spread < minimum then
		Registry.AntiCheatService.Flag(player, "Spread", 0.5, string.format("%.3f<%.3f", spread, minimum))
		usedSpread = minimum
	end

	local direction = Spread.Apply(look, usedSpread, math.floor(seed))

	Registry.AntiCheatService.CheckAim(player, look)

	local rewind = Registry.LagCompensation.RewindTime(player, clientTime)
	local DamageService = Registry.DamageService
	local result = HitscanService.Cast(origin, direction, rewind, character, function(model)
		return DamageService.CanDamage(player, model)
	end)
	if Config.Studio.DebugHits and RunService:IsStudio() then
		print(
			string.format(
				"[Hit] %s → %s/%s t=%.2f rewind=%.3fs spread=%.3f° (cliente %.3f°) desvio=%.2f°",
				player.Name,
				tostring(result.Model and result.Model.Name),
				tostring(result.Part),
				result.Distance,
				Registry.LagCompensation.Now() - rewind,
				usedSpread,
				spread,
				math.deg(math.acos(math.clamp(direction:Dot(look), -1, 1)))
			)
		)
	end

	local confirm = { ShotId = shotId, Hit = false }
	if result.Model and result.Zone then
		local amount = Damage.Sniper(result.Zone :: any, result.Distance)
		local applied = DamageService.Apply({
			Attacker = player,
			Victim = result.Model,
			Amount = amount,
			Weapon = "Sniper",
			Zone = result.Zone,
			Distance = result.Distance,
			Origin = origin,
			HitPosition = result.Position,
			AdsAlpha = clampedAds,
			ScopeTime = CombatState.ScopeTime(state),
			Airborne = humanoid.FloorMaterial == Enum.Material.Air,
			SpinDegrees = Registry.AntiCheatService.SpinDegrees(player, Config.Style.TrickSpinWindow),
		})
		if applied.Applied then
			confirm = {
				ShotId = shotId,
				Hit = true,
				Zone = result.Zone,
				Damage = applied.Amount,
				Killed = applied.Killed,
				Tags = applied.Tags,
				Position = result.Position,
				Target = result.Model,
			}
		end
	end

	Remotes.Event("HitConfirm"):FireClient(player, confirm)
	local fx = Remotes.Event("ShotFx")
	local tracer = character:GetAttribute("Tracer") or Config.DefaultEquipped.Tracer
	local materialName = if result.Material then result.Material.Name else ""
	for _, other in Players:GetPlayers() do
		if other ~= player then
			fx:FireClient(other, player, origin, result.Position, result.Normal, materialName, tracer, result.Model ~= nil)
		end
	end
	if state.Mag <= 0 then
		Remotes.Event("AmmoSync"):FireClient(player, state.Mag, state.Reserve)
	end
end

function HitscanService.Init()
	Remotes.Event("Fire").OnServerEvent:Connect(onFire)
	Players.PlayerRemoving:Connect(function(player)
		fireLimiter:Forget(player)
	end)
end

return HitscanService
