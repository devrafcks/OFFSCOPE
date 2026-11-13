local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(Shared.Util.RateLimiter)
local Damage = require(Shared.Combat.Damage)
local Hitbox = require(Shared.Combat.Hitbox)
local Registry = require(script.Parent.Parent.Registry)

local MeleeService = {}

local limiter = RateLimiter.new(table.unpack(Config.Netcode.RemoteBudgets.Melee))

local function onMelee(player: Player, look: any, clientTime: any, quick: any)
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.5 or type(clientTime) ~= "number" or clientTime ~= clientTime then
		return
	end
	if not limiter:Allow(player) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not character or not humanoid or humanoid.Health <= 0 or not head or character:GetAttribute("Frozen") then
		return
	end

	local state = Registry.CombatState.Get(player)
	local isQuick = quick == true
	if not isQuick and state.Slot ~= "Knife" then
		return
	end
	local cooldown = if isQuick then Config.Knife.QuickMeleeTime else Config.Knife.SwingTime
	local nowClock = os.clock()
	if nowClock - state.LastMelee < cooldown * 0.85 then
		return
	end
	state.LastMelee = nowClock
	if isQuick then
		state.ReloadToken += 1
		state.ReloadEnd = 0
	end

	look = (look :: Vector3).Unit
	local origin = head.Position
	local rewind = Registry.LagCompensation.RewindTime(player, clientTime)
	local knife = Config.Knife
	local coneDot = math.cos(math.rad(knife.ConeDegrees / 2))
	local DamageService = Registry.DamageService

	local best: Model? = nil
	local bestDistance = math.huge
	local bestPoint = origin
	local bestSnapshot = nil

	for model, track in Registry.LagCompensation.Tracks() do
		if model == character or not model.Parent or not DamageService.CanDamage(player, model) then
			continue
		end
		local snapshot = Registry.LagCompensation.Sample(model, rewind)
		if not snapshot then
			continue
		end
		local nearest = math.huge
		local nearestPoint = origin
		for name, cframe in snapshot do
			local size = track.Sizes[name]
			if size then
				local d = Hitbox.PointOBBDistance(origin, cframe, size)
				if d < nearest then
					nearest = d
					nearestPoint = cframe.Position
				end
			end
		end
		if nearest > knife.Range then
			continue
		end
		local toTarget = nearestPoint - origin
		local dot = if toTarget.Magnitude > 0.01 then look:Dot(toTarget.Unit) else 1

		if dot < coneDot and nearest > 1.5 then
			continue
		end
		if nearest < bestDistance then
			best = model
			bestDistance = nearest
			bestPoint = nearestPoint
			bestSnapshot = snapshot
		end
	end

	if not best or not bestSnapshot then
		return
	end

	local params = Registry.HitscanService.WorldParams()
	local blocked = Workspace:Raycast(origin, bestPoint - origin, params)
	if blocked and blocked.Distance < (bestPoint - origin).Magnitude - 1.2 then
		return
	end

	local victimRoot = bestSnapshot.LowerTorso or bestSnapshot.Torso or bestSnapshot.UpperTorso
	local backstab = false
	if victimRoot then
		local victimLook = victimRoot.LookVector * Vector3.new(1, 0, 1)
		local toVictim = (victimRoot.Position - origin) * Vector3.new(1, 0, 1)
		if victimLook.Magnitude > 0.01 and toVictim.Magnitude > 0.01 then
			backstab = victimLook.Unit:Dot(toVictim.Unit) > knife.BackstabDot
		end
	end

	local result = DamageService.Apply({
		Attacker = player,
		Victim = best,
		Amount = Damage.Knife(backstab),
		Weapon = "Knife",
		Zone = "Chest",
		Distance = bestDistance,
		Origin = origin,
		HitPosition = bestPoint,
		Backstab = backstab,
	})

	if result.Applied then
		Remotes.Event("HitConfirm"):FireClient(player, {
			ShotId = -1,
			Hit = true,
			Zone = if backstab then "Head" else "Chest",
			Damage = result.Amount,
			Killed = result.Killed,
			Tags = result.Tags,
			Position = bestPoint,
			Target = best,
			Melee = true,
		})
		local fx = Remotes.Event("MeleeFx")
		for _, other in Players:GetPlayers() do
			fx:FireClient(other, player, bestPoint, backstab)
		end
	end
end

function MeleeService.Init()
	Remotes.Event("Melee").OnServerEvent:Connect(onMelee)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Forget(player)
	end)
end

return MeleeService
