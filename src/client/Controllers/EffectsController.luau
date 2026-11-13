local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)

local EffectsController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"

local folder: Folder? = nil
local holes: { BasePart } = {}
local MAX_HOLES = 40

local METAL = { Metal = true, CorrodedMetal = true, DiamondPlate = true, Foil = true }

local function getFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local found = Workspace:FindFirstChild("Effects") :: Folder?
	if not found then
		local created = Instance.new("Folder")
		created.Name = "Effects"
		created.Parent = Workspace
		found = created
	end
	folder = found
	return found :: Folder
end

local function fxPart(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = getFolder()
	return part
end

local function anchorAt(position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	return attachment
end

local function burst(position: Vector3, normal: Vector3, props: { [string]: any }, count: number, lifetime: number?)
	local attachment = anchorAt(position)
	attachment.WorldCFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(math.rad(-90), 0, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LightEmission = 0.2
	emitter.Rate = 0
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, lifetime or 2)
end

function EffectsController.Tracer(from: Vector3, to: Vector3, tracerId: string?)
	local def = Config.Cosmetics[tracerId or ""] or Config.Cosmetics[Config.DefaultEquipped.Tracer]
	local visual = def.Visual
	local distance = (to - from).Magnitude
	if distance < 1 then
		return
	end
	local width = visual.Width or 0.06

	local line = fxPart(Vector3.new(width * 0.6, width * 0.6, distance), CFrame.lookAt((from + to) / 2, to), visual.Color)
	line.Transparency = 0.55
	TweenService:Create(line, TweenInfo.new(0.16), { Transparency = 1 }):Play()
	Debris:AddItem(line, 0.2)

	local streakLength = math.min(28, distance)
	local streak = fxPart(Vector3.new(width, width, streakLength), CFrame.lookAt(from, to), visual.Color)
	if visual.Glow then
		local light = Instance.new("PointLight")
		light.Color = visual.Color
		light.Range = 8
		light.Brightness = 2
		light.Parent = streak
	end
	local travel = distance / Config.Sniper.TracerSpeed
	local start = os.clock()
	local direction = (to - from).Unit
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / math.max(travel, 1e-3), 1)
		local head = from + direction * (distance * t)
		local tail = head - direction * math.min(streakLength, distance * t)
		streak.Size = Vector3.new(width, width, math.max((head - tail).Magnitude, 0.1))
		streak.CFrame = CFrame.lookAt((head + tail) / 2, head)
		if t >= 1 then
			connection:Disconnect()
			streak:Destroy()
		end
	end)
end

function EffectsController.MuzzleFlash(cf: CFrame, firstPerson: boolean?)
	local flash = fxPart(Vector3.new(0.5, 0.5, 0.5) * (if firstPerson then 0.6 else 1), cf * CFrame.Angles(0, 0, math.random() * math.pi), Color3.fromRGB(255, 214, 140))
	flash.Shape = Enum.PartType.Ball
	flash.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Range = if firstPerson then 14 else 18
	light.Brightness = 4
	light.Shadows = false
	light.Parent = flash
	local cone = fxPart(Vector3.new(0.18, 0.18, 1.4) * (if firstPerson then 0.6 else 1), cf * CFrame.new(0, 0, -0.5), Color3.fromRGB(255, 236, 190))
	cone.Transparency = 0.3
	TweenService:Create(flash, TweenInfo.new(0.05), { Transparency = 1, Size = flash.Size * 1.8 }):Play()
	TweenService:Create(cone, TweenInfo.new(0.04), { Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.06), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.1)
	Debris:AddItem(cone, 0.1)

	burst(cf.Position, cf.LookVector, {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(190, 190, 190)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.6) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(15, 15),
		Drag = 3,
		LightEmission = 0,
	}, 3)
end

function EffectsController.Impact(position: Vector3, normal: Vector3, materialName: string?, character: boolean?)
	if character then

		burst(position, normal, {
			Texture = SPARK,
			Color = ColorSequence.new(Color3.fromRGB(255, 220, 160)),
			Size = NumberSequence.new(0.25, 0),
			Lifetime = NumberRange.new(0.12, 0.25),
			Speed = NumberRange.new(8, 16),
			SpreadAngle = Vector2.new(50, 50),
			LightEmission = 1,
		}, 8)
		return
	end
	local isMetal = materialName ~= nil and METAL[materialName] == true
	if isMetal then
		burst(position, normal, {
			Texture = SPARK,
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 110)),
			Size = NumberSequence.new(0.2, 0),
			Lifetime = NumberRange.new(0.15, 0.35),
			Speed = NumberRange.new(14, 28),
			SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, -60, 0),
			LightEmission = 1,
		}, 14)
		Audio.Play3D("ImpactMetal", { Position = position, Pitch = 0.9 + math.random() * 0.2 })
	else
		burst(position, normal, {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(150, 140, 126)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2.2) }),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(30, 30),
			Drag = 4,
			LightEmission = 0,
		}, 6)
		burst(position, normal, {
			Texture = SQUARE,
			Color = ColorSequence.new(Color3.fromRGB(90, 84, 76)),
			Size = NumberSequence.new(0.12, 0.05),
			Lifetime = NumberRange.new(0.4, 0.7),
			Speed = NumberRange.new(10, 20),
			SpreadAngle = Vector2.new(45, 45),
			Acceleration = Vector3.new(0, -80, 0),
			LightEmission = 0,
		}, 8)
		Audio.Play3D("ImpactConcrete", { Position = position, Pitch = 0.9 + math.random() * 0.2 })
	end

	local hole = fxPart(Vector3.new(0.02, 0.32, 0.32), CFrame.lookAt(position + normal * 0.01, position + normal) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(16, 15, 14), Enum.Material.SmoothPlastic)
	hole.Shape = Enum.PartType.Cylinder
	table.insert(holes, hole)
	if #holes > MAX_HOLES then
		local old = table.remove(holes, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(10, function()
		if hole.Parent then
			TweenService:Create(hole, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			Debris:AddItem(hole, 1.6)
		end
	end)
end

function EffectsController.KillEffect(effectId: string, position: Vector3)
	local def = Config.Cosmetics[effectId]
	local kind = def and def.Visual.Kind or "None"
	local visual = def and def.Visual or {}
	if kind == "Sparks" then
		burst(position, Vector3.yAxis, {
			Texture = SPARK,
			Color = ColorSequence.new(visual.Color),
			Size = NumberSequence.new(0.5, 0),
			Lifetime = NumberRange.new(0.4, 0.9),
			Speed = NumberRange.new(10, 26),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -40, 0),
			LightEmission = 1,
		}, 40, 2)
	elseif kind == "Confetti" then
		local colors = { Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 255, 140) }
		for _, color in colors do
			burst(position + Vector3.new(0, 1, 0), Vector3.yAxis, {
				Texture = SQUARE,
				Color = ColorSequence.new(color),
				Size = NumberSequence.new(0.22),
				Lifetime = NumberRange.new(1.2, 2),
				Speed = NumberRange.new(10, 18),
				SpreadAngle = Vector2.new(70, 70),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-300, 300),
				Acceleration = Vector3.new(0, -30, 0),
				Drag = 1.5,
				LightEmission = 0.3,
			}, 14, 3)
		end
	elseif kind == "Smoke" then
		burst(position, Vector3.yAxis, {
			Texture = SMOKE,
			Color = ColorSequence.new(visual.Color),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) }),
			Lifetime = NumberRange.new(1.4, 2.2),
			Speed = NumberRange.new(2, 6),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 2,
			LightEmission = 0,
		}, 18, 3)
	elseif kind == "Glitch" then
		for i = 1, 10 do
			local offset = Vector3.new(math.random() - 0.5, math.random() * 1.2, math.random() - 0.5) * 4
			local cube = fxPart(Vector3.one * (0.3 + math.random() * 0.6), CFrame.new(position + offset), if i % 2 == 0 then visual.Color else visual.Color2)
			cube.Transparency = 0.1
			TweenService:Create(cube, TweenInfo.new(0.5 + math.random() * 0.4, Enum.EasingStyle.Quad), { Transparency = 1, CFrame = cube.CFrame + Vector3.new(0, 3, 0), Size = Vector3.one * 0.05 }):Play()
			Debris:AddItem(cube, 1)
		end
	elseif kind == "Crescent" then
		local arc = fxPart(Vector3.new(0.1, 6, 6), CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.random() * 6, math.rad(30)), visual.Color)
		arc.Shape = Enum.PartType.Cylinder
		arc.Transparency = 0.2
		TweenService:Create(arc, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(0.05, 12, 12) }):Play()
		Debris:AddItem(arc, 0.6)
	end
end

local glints: { [Model]: BillboardGui } = {}

local function makeGlint(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "ScopeGlint"
	gui.Size = UDim2.fromScale(1.6, 1.6)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = 2000
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.35, 0.35)
	core.BackgroundColor3 = Color3.fromRGB(255, 255, 240)
	core.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = core
	core.Parent = gui
	for _, rotation in { 0, 90 } do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(1, 0.06)
		ray.Rotation = rotation
		ray.BackgroundColor3 = Color3.fromRGB(255, 250, 220)
		ray.BorderSizePixel = 0
		ray.BackgroundTransparency = 0.25
		ray.Parent = gui
	end
	return gui
end

local function updateGlints()
	local myPos = camera.CFrame.Position
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if not character or not head then
			continue
		end
		local scoped = character:GetAttribute("Scoped") == true and character:GetAttribute("Weapon") == "Sniper"
		local gui = glints[character]
		if scoped then

			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local pitch = (character:GetAttribute("Pitch") :: number?) or 0
			local facing = if root then (root.CFrame * CFrame.Angles(pitch, 0, 0)).LookVector else head.CFrame.LookVector
			local toMe = (myPos - head.Position).Unit
			local visible = facing:Dot(toMe) > 0.9
			if visible then
				if not gui then
					gui = makeGlint()
					gui.Adornee = head
					gui.StudsOffset = Vector3.new(0.3, 0.2, 0) + facing * 0.8
					gui.Parent = getFolder()
					glints[character] = gui
				end
				local pulse = 0.85 + math.sin(os.clock() * 9) * 0.15
				local distance = (myPos - head.Position).Magnitude
				local scale = math.clamp(distance / 40, 1, 7) * pulse
				gui.Size = UDim2.fromScale(1.6 * scale, 1.6 * scale)
				gui.Enabled = true
			elseif gui then
				gui.Enabled = false
			end
		elseif gui then
			gui:Destroy()
			glints[character] = nil
		end
	end
	for character, gui in glints do
		if not character.Parent then
			gui:Destroy()
			glints[character] = nil
		end
	end
end

local function thirdPersonMuzzle(shooter: Player): CFrame?
	local character = shooter.Character
	local weapon = character and character:FindFirstChild("WorldSniper")
	local root = weapon and (weapon :: Model).PrimaryPart
	local muzzle = root and root:FindFirstChild("Muzzle") :: Attachment?
	return if muzzle then muzzle.WorldCFrame else nil
end

local function onShotFx(shooter: Player, origin: Vector3, hitPos: Vector3, normal: Vector3, materialName: string, tracerId: string, hitCharacter: boolean)
	local muzzle = thirdPersonMuzzle(shooter)
	local from = if muzzle then muzzle.Position else origin
	if muzzle then
		EffectsController.MuzzleFlash(muzzle, false)
	end
	EffectsController.Tracer(from, hitPos, tracerId)
	EffectsController.Impact(hitPos, normal, materialName, hitCharacter)

	local distance = (camera.CFrame.Position - origin).Magnitude
	Audio.Play3D(if distance > 160 then "SniperShotDistant" else "SniperShot", { Position = origin, RollOff = 1400, Pitch = 0.96 + math.random() * 0.08 })

	local dir = (hitPos - origin)
	local length = dir.Magnitude
	if length > 1 then
		local along = math.clamp((camera.CFrame.Position - origin):Dot(dir.Unit), 0, length)
		local closest = origin + dir.Unit * along
		if (closest - camera.CFrame.Position).Magnitude < 7 and shooter ~= player then
			Audio.Play3D("BulletWhiz", { Position = closest })
		end
	end
end

function EffectsController.Init()
	Remotes.Event("ShotFx").OnClientEvent:Connect(onShotFx)
	Remotes.Event("MeleeFx").OnClientEvent:Connect(function(attacker: Player, position: Vector3, backstab: boolean)
		if attacker ~= player then
			Audio.Play3D("KnifeHit", { Position = position })
		end
		EffectsController.Impact(position, Vector3.yAxis, nil, true)
		if backstab and attacker == player then
			Audio.Play2D("HitHead", { Pitch = 0.8 })
		end
	end)
	Remotes.Event("KillEffect").OnClientEvent:Connect(function(effectId: string, position: Vector3)
		if (camera.CFrame.Position - position).Magnitude < 600 then
			EffectsController.KillEffect(effectId, position)
		end
	end)
end

function EffectsController.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 / 20 then
			accumulator = 0

			updateGlints()
		end
	end)
end

return EffectsController
