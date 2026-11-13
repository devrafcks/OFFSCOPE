local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)

local CombatState = {}

export type State = {
	Slot: string,
	Mag: number,
	Reserve: number,
	LastShot: number,
	LastMelee: number,
	ReloadEnd: number,
	EquipEnd: number,
	ScopeStart: number?,
	ReloadToken: number,
}

local states: { [Player]: State } = {}
local actionLimiter = RateLimiter.new(table.unpack(Config.Netcode.RemoteBudgets.Action))

local function fresh(): State
	return {
		Slot = "Sniper",
		Mag = Config.Sniper.MagSize,
		Reserve = Config.Sniper.ReserveAmmo,
		LastShot = 0,
		LastMelee = 0,
		ReloadEnd = 0,
		EquipEnd = 0,
		ScopeStart = nil,
		ReloadToken = 0,
	}
end

function CombatState.Get(player: Player): State
	local state = states[player]
	if not state then
		state = fresh()
		states[player] = state
	end
	return state
end

function CombatState.Reset(player: Player)
	states[player] = fresh()
	Remotes.Event("AmmoSync"):FireClient(player, states[player].Mag, states[player].Reserve)
	local character = player.Character
	if character then
		character:SetAttribute("Weapon", "Sniper")
		character:SetAttribute("Scoped", false)
	end
end

function CombatState.IsReloading(state: State): boolean
	return os.clock() < state.ReloadEnd
end

function CombatState.ScopeTime(state: State): number
	return if state.ScopeStart then os.clock() - state.ScopeStart else 0
end

function CombatState.MaxAdsAlpha(state: State): number
	if not state.ScopeStart then
		return 0.2
	end
	return math.clamp((os.clock() - state.ScopeStart) / Config.Sniper.Ads.Time + 0.25, 0, 1)
end

local function startReload(player: Player)
	local state = CombatState.Get(player)
	local s = Config.Sniper
	if state.Slot ~= "Sniper" or CombatState.IsReloading(state) or state.Mag >= s.MagSize then
		return
	end
	if not s.InfiniteReserve and state.Reserve <= 0 then
		return
	end
	state.ReloadEnd = os.clock() + s.ReloadTime
	state.ReloadToken += 1
	state.ScopeStart = nil
	local token = state.ReloadToken
	task.delay(s.ReloadTime, function()
		local current = states[player]
		if current ~= state or current.ReloadToken ~= token or current.Slot ~= "Sniper" then
			return
		end
		local need = s.MagSize - current.Mag
		local take = if s.InfiniteReserve then need else math.min(need, current.Reserve)
		current.Mag += take
		if not s.InfiniteReserve then
			current.Reserve -= take
		end
		Remotes.Event("AmmoSync"):FireClient(player, current.Mag, current.Reserve)
	end)
end

function CombatState.Init()
	Remotes.Event("Reload").OnServerEvent:Connect(function(player)
		if actionLimiter:Allow(player) then
			startReload(player)
		end
	end)

	Remotes.Event("Equip").OnServerEvent:Connect(function(player, slot)
		if not actionLimiter:Allow(player) or (slot ~= "Sniper" and slot ~= "Knife") then
			return
		end
		local state = CombatState.Get(player)
		if state.Slot == slot then
			return
		end
		state.Slot = slot
		state.ReloadToken += 1
		state.ReloadEnd = 0
		state.ScopeStart = nil
		state.EquipEnd = os.clock() + (if slot == "Knife" then Config.Knife.EquipTime else Config.Sniper.EquipTime)
		local character = player.Character
		if character then
			character:SetAttribute("Weapon", slot)
			character:SetAttribute("Scoped", false)
		end
	end)

	Remotes.Event("Scope").OnServerEvent:Connect(function(player, scoped)
		if not actionLimiter:Allow(player) or type(scoped) ~= "boolean" then
			return
		end
		local state = CombatState.Get(player)
		if scoped and state.Slot == "Sniper" and not CombatState.IsReloading(state) then
			state.ScopeStart = state.ScopeStart or os.clock()
		else
			state.ScopeStart = nil
			scoped = false
		end
		local character = player.Character
		if character then
			character:SetAttribute("Scoped", scoped)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		actionLimiter:Forget(player)
	end)
end

return CombatState
