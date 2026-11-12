--[[
	WeaponController — máquina de estados da sniper e da faca no cliente.

	O tiro é PREVISTO aqui (som, flash, tracer, impacto, recoil na hora) e o servidor confirma.
	O cliente manda origem, olhar, semente e spread — o servidor reproduz a mesma direção com
	Spread.Apply e decide o hit. Hitmarker só aparece com a confirmação (HitConfirm).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Spread = require(Shared.Combat.Spread)
local Audio = require(Shared.Audio)
local Format = require(Shared.Util.Format)
local ClientState = require(script.Parent.Parent.ClientState)
local InputController = require(script.Parent.InputController)
local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)

local WeaponController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local rng = Random.new()

local S = Config.Sniper
local K = Config.Knife
local INSPECT_TIME = 2.6

local state = {
	Slot = "Sniper",
	Mag = S.MagSize,
	Reserve = S.ReserveAmmo,
	NextFire = 0,
	BoltStart = -10,
	ReloadStart = nil :: number?,
	EquipStart = 0,
	AdsAlpha = 0,
	AdsTarget = false,
	ScopeSent = false,
	ScopedAt = 0,
	AdsLockedUntil = 0,
	NextSwing = 0,
	SwingStart = -10,
	QuickStart = -10,
	InspectStart = -10,
	ShotId = 0,
	LastSpread = S.Spread.Base,
}

local function now(): number
	return os.clock()
end

local function alive(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function frozen(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("Frozen") == true
end

local function reloading(): boolean
	return state.ReloadStart ~= nil
end

local function equipping(): boolean
	local duration = if state.Slot == "Knife" then K.EquipTime else S.EquipTime
	return now() - state.EquipStart < duration
end

local function quickActive(): boolean
	return now() - state.QuickStart < K.QuickMeleeTime
end

local function boltCycling(): boolean
	return now() < state.NextFire
end

function WeaponController.Slot(): string
	return state.Slot
end

function WeaponController.AdsAlpha(): number
	return state.AdsAlpha
end

function WeaponController.Spread(): number
	return state.LastSpread
end

-- ── raycast local (previsão) ───────────────────────────────────────────────
local function localParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { camera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local effects = Workspace:FindFirstChild("Effects")
	if effects then
		table.insert(ignore, effects)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function isCharacterPart(instance: Instance): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- ── ações ──────────────────────────────────────────────────────────────────
local function sendScope(scoped: boolean)
	if state.ScopeSent ~= scoped then
		state.ScopeSent = scoped
		Remotes.Event("Scope"):FireServer(scoped)
		if scoped then
			state.ScopedAt = now()
			Audio.Play2D("ScopeIn", { Volume = 0.8 })
		end
	end
end

local function startReload()
	if state.Slot ~= "Sniper" or reloading() or state.Mag >= S.MagSize or not alive() then
		return
	end
	if not S.InfiniteReserve and state.Reserve <= 0 then
		return
	end
	state.ReloadStart = now()
	state.InspectStart = -10
	Remotes.Event("Reload"):FireServer()
	Audio.Play2D("Reload")
end

local function equip(slot: string)
	if state.Slot == slot or not alive() then
		return
	end
	state.Slot = slot
	state.EquipStart = now()
	state.ReloadStart = nil
	state.AdsTarget = false
	state.InspectStart = -10
	sendScope(false)
	Remotes.Event("Equip"):FireServer(slot)
	ViewmodelController.SetSlot(slot)
	HudController.SetSlot(slot)
end

local function shoot()
	if state.Slot ~= "Sniper" or not alive() or frozen() or ClientState.UiOpen then
		return
	end
	if equipping() or reloading() or boltCycling() or quickActive() then
		return
	end
	if state.Mag <= 0 then
		Audio.Play2D("DryFire")
		startReload()
		return
	end

	local look = CameraController.GetLook()
	local move = MovementController.State()
	local spread = Spread.Compute({
		Speed = move.Speed,
		Grounded = move.Grounded,
		Sliding = move.Sliding,
		Sprinting = move.Sprinting,
		AdsAlpha = state.AdsAlpha,
	})
	local seed = rng:NextInteger(1, 2147483646)
	local direction = Spread.Apply(look, spread, seed)
	local origin = camera.CFrame.Position
	state.ShotId += 1

	-- previsão local
	local result = Workspace:Raycast(origin, direction * S.Range, localParams())
	local hitPos = if result then result.Position else origin + direction * S.Range
	local muzzle = ViewmodelController.MuzzleCFrame()
	EffectsController.MuzzleFlash(muzzle, true)
	EffectsController.Tracer(muzzle.Position, hitPos, ClientState.Equipped("Tracer"))
	if result then
		local character = isCharacterPart(result.Instance)
		EffectsController.Impact(result.Position, result.Normal, result.Material.Name, character)
		if result.Instance.Name == "SteelPlate" then
			local distance = result.Instance:GetAttribute("Distance") or math.floor(result.Distance)
			Audio.Play3D("ImpactMetal", { Position = result.Position, Pitch = 0.55, Volume = 2 })
			HudController.Toast({ Kind = "Style", Text = `GONGO · {Format.Meters(distance :: number)}` })
		end
	end
	Audio.Play2D("SniperShot", { Pitch = 0.97 + rng:NextNumber() * 0.06 })

	CameraController.Kick(S.Recoil.Pitch * (1 - state.AdsAlpha * 0.4), (rng:NextNumber() - 0.5) * S.Recoil.Yaw * 2)
	CameraController.Shake(0.5)
	ViewmodelController.Kick(S.Recoil.ViewmodelKick)

	Remotes.Event("Fire"):FireServer(origin, look, seed, spread, Workspace:GetServerTimeNow(), state.AdsAlpha, state.ShotId)

	state.Mag -= 1
	state.NextFire = now() + S.BoltTime
	state.BoltStart = now() + 0.12
	if S.Ads.AutoUnscopeOnShot and state.Mag > 0 then
		state.AdsLockedUntil = state.NextFire - 0.05
	end
	task.delay(0.12, function()
		if state.Mag > 0 then
			Audio.Play2D("BoltCycle")
		end
	end)
	HudController.OnShot()
	if state.Mag <= 0 then
		task.delay(S.BoltTime * 0.6, startReload)
	end
end

local function swing()
	if state.Slot ~= "Knife" or not alive() or frozen() or ClientState.UiOpen or equipping() then
		return
	end
	if now() < state.NextSwing then
		return
	end
	state.SwingStart = now()
	state.NextSwing = now() + K.SwingTime
	Audio.Play2D("KnifeSwing", { Pitch = 0.95 + rng:NextNumber() * 0.1 })
	task.delay(K.HitDelay, function()
		Remotes.Event("Melee"):FireServer(CameraController.GetLook(), Workspace:GetServerTimeNow(), false)
	end)
end

local function quickMelee()
	if state.Slot ~= "Sniper" or not alive() or frozen() or ClientState.UiOpen or quickActive() then
		return
	end
	if now() < state.NextSwing then
		return
	end
	state.QuickStart = now()
	state.NextSwing = now() + K.QuickMeleeTime
	state.NextFire = math.max(state.NextFire, now() + K.QuickMeleeTime * 0.9)
	state.ReloadStart = nil
	state.AdsTarget = false
	sendScope(false)
	Audio.Play2D("KnifeSwing")
	task.delay(K.HitDelay + 0.06, function()
		Remotes.Event("Melee"):FireServer(CameraController.GetLook(), Workspace:GetServerTimeNow(), true)
	end)
end

local function inspect()
	if state.Slot ~= "Sniper" or reloading() or boltCycling() or state.AdsAlpha > 0.05 then
		return
	end
	state.InspectStart = now()
end

-- ── loop ───────────────────────────────────────────────────────────────────
local function update(dt: number)
	local t = now()
	local isAlive = alive()

	-- reload terminou (o servidor confirma via AmmoSync; aqui é a previsão)
	if state.ReloadStart and t - state.ReloadStart >= S.ReloadTime then
		state.ReloadStart = nil
		state.Mag = S.MagSize
	end

	-- ADS
	local wantsAim = InputController.IsHeld("Aim") and state.Slot == "Sniper" and isAlive and not ClientState.UiOpen
	local blocked = reloading() or quickActive() or equipping() or t < state.AdsLockedUntil
	state.AdsTarget = wantsAim and not blocked
	local rate = if state.AdsTarget then dt / S.Ads.Time else -dt / S.Ads.OutTime
	state.AdsAlpha = math.clamp(state.AdsAlpha + rate, 0, 1)
	sendScope(state.AdsTarget and state.AdsAlpha > 0.05)
	if state.AdsAlpha > 0.05 then
		state.InspectStart = -10
	end

	-- faca segurando o botão = golpes seguidos
	if state.Slot == "Knife" and InputController.IsHeld("Fire") then
		swing()
	end

	-- spread atual (retículo dinâmico)
	local move = MovementController.State()
	state.LastSpread = Spread.Compute({
		Speed = move.Speed,
		Grounded = move.Grounded,
		Sliding = move.Sliding,
		Sprinting = move.Sprinting,
		AdsAlpha = state.AdsAlpha,
	})

	-- velocidade: scope deixa lento, faca deixa rápido
	local multiplier = if state.Slot == "Knife" then Config.Movement.KnifeSpeedMultiplier else 1 + (Config.Movement.AdsSpeedMultiplier - 1) * state.AdsAlpha
	MovementController.SetSpeedMultiplier(multiplier)

	-- alimenta câmera, viewmodel e HUD
	CameraController.SetAds(state.AdsAlpha)
	local boltProgress = if t >= state.BoltStart and t < state.NextFire then math.clamp((t - state.BoltStart) / (S.BoltTime - 0.2), 0, 1) else 0
	if boltProgress >= 1 then
		boltProgress = 0
	end
	ViewmodelController.Set("Ads", state.AdsAlpha)
	ViewmodelController.Set("Bolt", boltProgress)
	ViewmodelController.Set("Reload", if state.ReloadStart then math.clamp((t - state.ReloadStart) / S.ReloadTime, 0, 1) else 0)
	local equipDuration = if state.Slot == "Knife" then K.EquipTime else S.EquipTime
	ViewmodelController.Set("Equip", math.clamp((t - state.EquipStart) / equipDuration, 0, 1))
	local swingT = (t - state.SwingStart) / K.SwingTime
	ViewmodelController.Set("Swing", if swingT >= 0 and swingT < 1 then swingT else 0)
	local quickT = (t - state.QuickStart) / K.QuickMeleeTime
	ViewmodelController.Set("Quick", if quickT >= 0 and quickT < 1 then quickT else 0)
	local inspectT = (t - state.InspectStart) / INSPECT_TIME
	ViewmodelController.Set("Inspect", if inspectT >= 0 and inspectT < 1 then inspectT else 0)

	HudController.SetWeapon({
		Slot = state.Slot,
		Mag = state.Mag,
		Reserve = state.Reserve,
		Reload = if state.ReloadStart then (t - state.ReloadStart) / S.ReloadTime else nil,
		Bolt = boltProgress,
		Spread = state.LastSpread,
		Ads = state.AdsAlpha,
	})
end

local function reset()
	state.Slot = "Sniper"
	state.Mag = S.MagSize
	state.Reserve = S.ReserveAmmo
	state.NextFire = 0
	state.ReloadStart = nil
	state.EquipStart = now()
	state.AdsAlpha = 0
	state.AdsTarget = false
	state.ScopeSent = false
	state.AdsLockedUntil = 0
	state.InspectStart = -10
	ViewmodelController.SetSlot("Sniper")
	HudController.SetSlot("Sniper")
end

function WeaponController.Init()
	InputController.Pressed:Connect(function(action)
		if action == "Fire" then
			if state.Slot == "Sniper" then
				shoot()
			else
				swing()
			end
		elseif action == "Reload" then
			startReload()
		elseif action == "Swap" then
			equip(if state.Slot == "Sniper" then "Knife" else "Sniper")
		elseif action == "Primary" then
			equip("Sniper")
		elseif action == "QuickMelee" then
			if state.Slot == "Knife" then
				swing()
			else
				quickMelee()
			end
		elseif action == "Inspect" then
			inspect()
		end
	end)

	Remotes.Event("AmmoSync").OnClientEvent:Connect(function(mag: number, reserve: number)
		state.Mag = mag
		state.Reserve = reserve
		if mag >= S.MagSize then
			state.ReloadStart = nil
		end
	end)

	Remotes.Event("HitConfirm").OnClientEvent:Connect(function(confirm)
		if not confirm or not confirm.Hit then
			return
		end
		HudController.Hitmarker(confirm.Zone, confirm.Killed == true, confirm.Melee == true)
		if confirm.Position then
			HudController.DamageNumber(confirm.Position, confirm.Damage or 0, confirm.Zone)
		end
		if confirm.Killed then
			Audio.Play2D("KillConfirm")
		elseif confirm.Zone == "Head" then
			Audio.Play2D("HitHead")
		else
			Audio.Play2D("HitBody")
		end
	end)
end

function WeaponController.Start()
	player.CharacterAdded:Connect(reset)
	reset()
	RunService:BindToRenderStep("OffscopeWeapon", Enum.RenderPriority.Input.Value + 2, update)
end

return WeaponController
