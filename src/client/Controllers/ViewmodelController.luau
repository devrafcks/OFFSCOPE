--[[
	ViewmodelController — braços + arma em 1ª pessoa (local, filhos da Camera).

	Nada de Tool no personagem (clipa na parede e mostra a cabeça). Tudo é procedural:
	pose = câmera × mistura(hip, ADS, corrida) × equip × reload × sway × bob × recoil,
	ferrolho e carregador por Motor6D.Transform, mão direita vai até o ferrolho,
	charm balança com mola. Wrap/charm/faca equipados reconstroem o modelo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Spring = require(Shared.Util.Spring)
local SniperBuilder = require(Shared.Models.SniperBuilder)
local KnifeBuilder = require(Shared.Models.KnifeBuilder)
local ArmsBuilder = require(Shared.Models.ArmsBuilder)
local CharmBuilder = require(Shared.Models.CharmBuilder)
local WrapPainter = require(Shared.Cosmetics.WrapPainter)
local ClientState = require(script.Parent.Parent.ClientState)
local MovementController = require(script.Parent.MovementController)

local ViewmodelController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local rad = math.rad
local CF = CFrame.new

local SCALE = 0.42
local IDENTITY = CFrame.new()

type Rig = {
	Model: Model,
	Root: BasePart,
	Bolt: Motor6D?,
	Mag: Motor6D?,
	RightArm: any,
	LeftArm: any?,
	Charm: any?,
	Muzzle: Attachment?,
	Eye: Attachment?,
	Knob: Attachment?,
	MagWell: Attachment?,
	StopAnimation: () -> (),
}

local sniper: Rig? = nil
local knife: Rig? = nil
local slot = "Sniper"
local hidden = false

-- entradas de animação (0..1), escritas pelo WeaponController
local anim = {
	Ads = 0,
	Bolt = 0, -- progresso do ciclo do ferrolho
	Reload = 0,
	Equip = 1,
	Swing = 0, -- golpe de faca
	Quick = 0, -- faca rápida a partir da sniper
	Inspect = 0,
}

local sway = Spring.new(90, 14)
local kick = Spring.new(150, 16)
local charmSpring = Spring.new(40, 3.2)
local bobPhase = 0
local sprintBlend = 0
local lastLook = Vector3.zAxis

local HIP = CF(0.62, -0.7, -1.28) * CFrame.Angles(0, rad(1.5), 0)
local SPRINT = CF(0.42, -0.95, -1.05) * CFrame.Angles(rad(-16), rad(36), rad(16))
local KNIFE_HIP = CF(0.78, -0.8, -1.15) * CFrame.Angles(rad(14), rad(-10), rad(-28))

local function scaledTransform(cf: CFrame): CFrame
	return cf - cf.Position + cf.Position * SCALE
end

local function attachment(root: BasePart, name: string): Attachment?
	return root:FindFirstChild(name) :: Attachment?
end

-- Transform que leva o pulso (C0) até um ponto da arma, mantendo a orientação da mão.
local function reachTransform(motor: Motor6D, target: Vector3): CFrame
	local c0 = motor.C0
	return c0:Inverse() * CF(target) * (c0 - c0.Position)
end

-- Luz curta presa na arma: em mapa noturno a viewmodel não vira uma silhueta preta.
-- Alcance pequeno (a viewmodel tem ~2 studs) para quase não iluminar o mundo.
local function addFillLight(root: BasePart, range: number)
	local light = Instance.new("PointLight")
	light.Name = "ViewmodelFill"
	light.Range = range
	light.Brightness = 3.2
	light.Color = Color3.fromRGB(255, 240, 222)
	light.Shadows = false
	light.Parent = root
end

local function destroyRig(rig: Rig?)
	if rig then
		rig.StopAnimation()
		rig.Model:Destroy()
	end
end

local function buildSniper(): Rig
	local built = SniperBuilder.Build("Full")
	local model = built.Model
	model.Name = "ViewmodelSniper"
	local stop = WrapPainter.Apply(model, ClientState.Equipped("Wrap"), { Textures = true, Animate = true })

	local root = built.Root
	-- mão direita fecha no punho (inclinado 18°), esquerda apoia por baixo do guarda-mão
	local rightGrip = (attachment(root, "RightGrip") :: Attachment).CFrame * CFrame.Angles(rad(-18), 0, 0) * CFrame.Angles(rad(-90), 0, 0)
	local leftGrip = (attachment(root, "LeftGrip") :: Attachment).CFrame * CF(0, 0.13, 0)
	local right = ArmsBuilder.Build(root, "RightArm", rightGrip, Vector3.new(0.5, -0.7, 1.5), 1, 0.12)
	local left = ArmsBuilder.Build(root, "LeftArm", leftGrip, Vector3.new(-1.3, -0.55, 1.45), -1, 0.19)
	local charmDef = Config.Cosmetics[ClientState.Equipped("Charm")]
	local charm = CharmBuilder.Attach(root, built.CharmMount, charmDef and charmDef.Visual)

	model:ScaleTo(SCALE)
	addFillLight(root, 5)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CastShadow = false
			part.CanQuery = false
			part.CanTouch = false
			part.CanCollide = false
		end
	end
	return {
		Model = model,
		Root = root,
		Bolt = built.Bolt,
		Mag = built.Mag,
		RightArm = right,
		LeftArm = left,
		Charm = charm,
		Muzzle = attachment(root, "Muzzle"),
		Eye = attachment(root, "ScopeEye"),
		Knob = attachment(root, "BoltKnob"),
		MagWell = attachment(root, "MagWell"),
		StopAnimation = stop,
	}
end

local function buildKnife(): Rig
	local knifeId = ClientState.Equipped("Knife")
	local def = Config.Cosmetics[knifeId]
	local built = KnifeBuilder.Build(def and def.Visual.Shape)
	local model = built.Model
	model.Name = "ViewmodelKnife"
	WrapPainter.PaintKnife(model, knifeId)
	local right = ArmsBuilder.Build(built.Root, "RightArm", CFrame.Angles(rad(-90), 0, 0) * CF(0, 0, 0.05), Vector3.new(0.35, -0.6, 1.5), 1, 0.09)
	model:ScaleTo(SCALE * 1.15)
	addFillLight(built.Root, 4)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CastShadow = false
			part.CanQuery = false
			part.CanCollide = false
		end
	end
	return {
		Model = model,
		Root = built.Root,
		RightArm = right,
		StopAnimation = function() end,
	}
end

function ViewmodelController.Rebuild()
	destroyRig(sniper)
	destroyRig(knife)
	sniper = buildSniper()
	knife = buildKnife()
	ViewmodelController.SetSlot(slot)
end

function ViewmodelController.SetSlot(newSlot: string)
	slot = newSlot
	if sniper then
		sniper.Model.Parent = if slot == "Sniper" and not hidden then camera else nil
	end
	if knife then
		knife.Model.Parent = if (slot == "Knife" or anim.Quick > 0) and not hidden then camera else nil
	end
end

function ViewmodelController.SetHidden(value: boolean)
	if hidden ~= value then
		hidden = value
		ViewmodelController.SetSlot(slot)
	end
end

function ViewmodelController.Set(key: string, value: number)
	(anim :: any)[key] = value
end

function ViewmodelController.Kick(strength: number)
	kick:Impulse(Vector3.new(rad(9) * strength * 10, rad(1.5) * (math.random() - 0.5) * 10, strength * 10))
end

function ViewmodelController.MuzzleCFrame(): CFrame
	if slot == "Sniper" and sniper and sniper.Muzzle and sniper.Model.Parent then
		return sniper.Muzzle.WorldCFrame
	end
	return camera.CFrame * CF(0.35, -0.3, -2)
end

-- ── curvas ─────────────────────────────────────────────────────────────────
local function bell(t: number, a: number, b: number): number
	-- 0 → 1 → 0 entre a e b
	if t <= a or t >= b then
		return 0
	end
	local x = (t - a) / (b - a)
	return math.sin(x * math.pi)
end

local function ramp(t: number, a: number, b: number): number
	return math.clamp((t - a) / (b - a), 0, 1)
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- golpe de faca: preparação → corte diagonal → retorno
local function swingPose(t: number): CFrame
	if t <= 0 then
		return CFrame.identity
	end
	local wind = smooth(ramp(t, 0, 0.22))
	local cut = smooth(ramp(t, 0.22, 0.48))
	local back = smooth(ramp(t, 0.6, 1))
	local raise = CF(0.25 * wind, 0.35 * wind, 0.1 * wind) * CFrame.Angles(rad(35) * wind, rad(-25) * wind, rad(-30) * wind)
	local slash = CF(-0.9 * cut, -0.45 * cut, -0.35 * cut) * CFrame.Angles(rad(-60) * cut, rad(55) * cut, rad(70) * cut)
	return (raise * slash):Lerp(CFrame.identity, back)
end

-- ── loop ───────────────────────────────────────────────────────────────────
local function update(dt: number)
	if not sniper or not knife then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- morto (ou personagem novo ainda sem Humanoid no respawn): só tira os modelos da tela.
	-- Não mexe em `hidden` — antes isso "travava" a arma escondida depois do respawn.
	if not humanoid or humanoid.Health <= 0 then
		if sniper.Model.Parent then
			sniper.Model.Parent = nil
		end
		if knife.Model.Parent then
			knife.Model.Parent = nil
		end
		return
	end

	local camCF = camera.CFrame
	local state = MovementController.State()

	-- sway pelo movimento do mouse/olhar
	local mouse = UserInputService:GetMouseDelta()
	local look = camCF.LookVector
	local turn = lastLook:Cross(look)
	lastLook = look
	sway.Target = Vector3.new(-mouse.Y * 0.0012, -mouse.X * 0.0012, 0) * (1 - anim.Ads * 0.85)
	local s = sway:Step(dt)
	sway.Target = Vector3.zero

	-- bob de passo
	local moving = state.Grounded and state.Speed > 1
	local speedFactor = math.clamp(state.Speed / Config.Movement.WalkSpeed, 0, 1.6)
	if moving then
		bobPhase += dt * (6 + speedFactor * 4)
	end
	local bobAmp = if moving then 0.028 * speedFactor * (1 - anim.Ads * 0.9) else 0
	local breathe = math.sin(os.clock() * 1.6) * 0.008 * (1 - anim.Ads)
	local bob = CF(math.sin(bobPhase) * bobAmp, math.abs(math.cos(bobPhase)) * bobAmp + breathe, 0)
		* CFrame.Angles(0, 0, math.sin(bobPhase) * bobAmp * 0.6)

	local k = kick:Step(dt)
	local recoil = CF(0, 0, k.Z * 0.03) * CFrame.Angles(k.X * 0.1, k.Y * 0.1, 0)
	local swayCF = CFrame.Angles(s.X, s.Y, s.Y * 0.6)

	local sprintAlpha = if MovementController.IsSprinting() and not MovementController.IsSliding() then 1 else 0
	local slideTilt = if MovementController.IsSliding() then CFrame.Angles(0, 0, rad(12)) else CFrame.identity

	if slot == "Sniper" or anim.Quick > 0 then
		local rig = sniper
		local eyeLocal = if rig.Eye then rig.Eye.CFrame else CF(0, 0.27, 0.44)
		local ads = CF(0, 0, -0.32) * eyeLocal:Inverse()
		local adsT = smooth(anim.Ads)
		sprintBlend += (sprintAlpha * (1 - anim.Ads) - sprintBlend) * math.min(1, dt * 10)
		local base = HIP:Lerp(ads, adsT):Lerp(SPRINT, sprintBlend)

		local equip = 1 - smooth(anim.Equip)
		local equipCF = CF(0, -0.9 * equip, 0.2 * equip) * CFrame.Angles(rad(-35) * equip, 0, rad(10) * equip)

		local reload = anim.Reload
		local reloadTilt = bell(reload, 0.02, 0.98)
		local reloadCF = CF(-0.1 * reloadTilt, 0.08 * reloadTilt, 0.05 * reloadTilt) * CFrame.Angles(rad(14) * reloadTilt, rad(-18) * reloadTilt, rad(28) * reloadTilt)

		local bolt = anim.Bolt
		local boltTilt = bell(bolt, 0, 1)
		local boltCF = CFrame.Angles(rad(-4) * boltTilt, 0, rad(10) * boltTilt)

		local inspect = bell(anim.Inspect, 0, 1)
		local inspectCF = CF(-0.35 * inspect, 0.12 * inspect, 0.25 * inspect) * CFrame.Angles(rad(18) * inspect, rad(-62) * inspect, rad(-24) * inspect)

		local quick = bell(anim.Quick, 0, 1)
		local quickCF = CF(0.2 * quick, -0.8 * quick, 0.3 * quick) * CFrame.Angles(rad(-30) * quick, rad(20) * quick, 0)

		rig.Root.CFrame = camCF * base * equipCF * reloadCF * boltCF * inspectCF * quickCF * slideTilt * swayCF * bob * recoil

		-- ferrolho + mão direita no ferrolho
		if rig.Bolt then
			rig.Bolt.Transform = scaledTransform(SniperBuilder.BoltTransform(bolt))
		end
		local handToBolt = smooth(bell(bolt, 0, 1) ^ 0.5)
		if rig.Knob then
			local knobPos = rig.Knob.Position
			local liftPull = SniperBuilder.BoltTransform(bolt)
			local target = knobPos + Vector3.new(0, liftPull.Position.Y, -liftPull.Position.X) * SCALE
			rig.RightArm.Motor.Transform = IDENTITY:Lerp(reachTransform(rig.RightArm.Motor, target), handToBolt)
		end

		-- carregador: sai, some, volta; mão esquerda acompanha
		if rig.Mag and rig.MagWell and rig.LeftArm then
			local out = bell(reload, 0.12, 0.72)
			rig.Mag.Transform = CF(0, -0.9 * SCALE * out * 2.2, 0.1 * SCALE * out)
			local handWeight = smooth(bell(reload, 0.08, 0.86))
			local target = rig.MagWell.Position + Vector3.new(0, -0.9 * SCALE * out * 2.2 - 0.12 * SCALE, 0)
			rig.LeftArm.Motor.Transform = IDENTITY:Lerp(reachTransform(rig.LeftArm.Motor, target), handWeight)
		end

		-- charm: pêndulo empurrado pelo giro da câmera
		if rig.Charm then
			charmSpring:Impulse(Vector3.new(turn.X * 60 + k.X * 0.5, 0, turn.Y * 60 + s.Y * 2))
			local c = charmSpring:Step(dt)
			rig.Charm.Motor.Transform = CFrame.Angles(math.clamp(c.X, -1.1, 1.1), 0, math.clamp(c.Z, -1.1, 1.1))
		end

		-- no scope cheio a luneta vira overlay de tela: esconde o modelo
		local fullyScoped = anim.Ads > 0.92
		local shouldShow = not hidden and (slot == "Sniper") and not fullyScoped
		local parent = if shouldShow then camera else nil
		if rig.Model.Parent ~= parent then
			rig.Model.Parent = parent
		end
	end

	if slot == "Knife" or anim.Quick > 0 then
		local rig = knife
		local equip = 1 - smooth(anim.Equip)
		local equipCF = CF(0.1 * equip, -0.7 * equip, 0) * CFrame.Angles(rad(-40) * equip, 0, 0)
		local swing = if anim.Quick > 0 then swingPose(anim.Quick) else swingPose(anim.Swing)
		local sprintCF = IDENTITY:Lerp(CF(0, -0.15, 0.1) * CFrame.Angles(rad(-10), rad(10), 0), sprintAlpha)
		rig.Root.CFrame = camCF * KNIFE_HIP * equipCF * sprintCF * swing * slideTilt * swayCF * bob
		local parent = if not hidden then camera else nil
		if rig.Model.Parent ~= parent then
			rig.Model.Parent = parent
		end
	elseif knife.Model.Parent then
		knife.Model.Parent = nil
	end
end

function ViewmodelController.Init()
	ClientState.ProfileChanged:Connect(function(profile)
		local equipped = profile and profile.Equipped
		if not equipped then
			return
		end
		local signature = `{equipped.Wrap}|{equipped.Charm}|{equipped.Knife}`
		if ViewmodelController._signature ~= signature then
			ViewmodelController._signature = signature
			ViewmodelController.Rebuild()
		end
	end)
end

function ViewmodelController.Start()
	ViewmodelController.Rebuild()
	player.CharacterAdded:Connect(function()
		ViewmodelController.SetHidden(false)
		anim.Equip = 0
	end)
	RunService:BindToRenderStep("OffscopeViewmodel", Enum.RenderPriority.Camera.Value + 2, update)
end

ViewmodelController._signature = ""

return ViewmodelController
