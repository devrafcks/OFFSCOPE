local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Spring = require(Shared.Util.Spring)
local ClientState = require(script.Parent.Parent.ClientState)

local CameraController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local yaw = 0
local pitch = 0
local suspended = false
local adsAlpha = 0
local fovBonus = 0
local touchDelta = Vector2.zero
local touchId: InputObject? = nil
local lastLookSent = 0

local recoil = Spring.new(120, 18)
local dip = Spring.new(160, 14)
local shake = Spring.new(260, 20)

local align: AlignOrientation? = nil

function CameraController.GetYaw(): number
	return yaw
end

function CameraController.GetPitch(): number
	return pitch
end

function CameraController.SetAngles(newYaw: number, newPitch: number)
	yaw = newYaw
	pitch = newPitch
end

function CameraController.GetLook(): Vector3
	return CFrame.fromEulerAnglesYXZ(pitch, yaw, 0).LookVector
end

function CameraController.SetAds(alpha: number)
	adsAlpha = alpha
end

function CameraController.SetFovBonus(bonus: number)
	fovBonus = bonus
end

function CameraController.Kick(pitchDegrees: number, yawDegrees: number)
	recoil:Impulse(Vector3.new(pitchDegrees * 22, yawDegrees * 22, 0))
end

function CameraController.Dip(amount: number)
	dip:Impulse(Vector3.new(0, -amount * 26, 0))
end

function CameraController.Shake(amount: number)
	shake:Impulse(Vector3.new((math.random() - 0.5) * amount * 30, (math.random() - 0.5) * amount * 30, 0))
end

function CameraController.Suspend(value: boolean)
	suspended = value
	if not value then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end

function CameraController.IsSuspended(): boolean
	return suspended
end

local function ensureAlign(root: BasePart)
	if align and align.Parent and (align.Parent :: Instance).Parent == root then
		return
	end
	local attachment = root:FindFirstChild("OffscopeLook") :: Attachment?
	if not attachment then
		local created = Instance.new("Attachment")
		created.Name = "OffscopeLook"
		created.Parent = root
		attachment = created
	end
	local constraint = Instance.new("AlignOrientation")
	constraint.Name = "OffscopeAlign"
	constraint.Mode = Enum.OrientationAlignmentMode.OneAttachment
	constraint.Attachment0 = attachment
	constraint.RigidityEnabled = false
	constraint.Responsiveness = 200
	constraint.MaxTorque = math.huge
	constraint.Parent = attachment
	align = constraint
end

local function sensitivity(): number
	local settings = ClientState.Settings
	local base = Config.Camera.DefaultSensitivity * (settings.Sensitivity or 1)
	if adsAlpha > 0.01 then
		local fovRatio = camera.FieldOfView / (settings.Fov or Config.Camera.HipFov)
		local adsScale = 1 + ((settings.AdsSensitivity or 0.55) * fovRatio - 1) * adsAlpha
		return base * adsScale
	end
	return base
end

local function onRender(dt: number)
	if suspended then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	local uiOpen = ClientState.UiOpen
	UserInputService.MouseBehavior = if uiOpen then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = uiOpen

	if not uiOpen and humanoid.Health > 0 then
		local sens = sensitivity()
		local mouse = UserInputService:GetMouseDelta()
		yaw -= mouse.X * sens
		pitch -= mouse.Y * sens

		if touchDelta.Magnitude > 0 then
			local touchSens = Config.Camera.TouchSensitivity * (ClientState.Settings.Sensitivity or 1) * (sens / Config.Camera.DefaultSensitivity / (ClientState.Settings.Sensitivity or 1))
			yaw -= touchDelta.X * touchSens
			pitch -= touchDelta.Y * touchSens
			touchDelta = Vector2.zero
		end

		for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if state.KeyCode == Enum.KeyCode.Thumbstick2 then
				local v = Vector2.new(state.Position.X, state.Position.Y)
				if v.Magnitude > 0.15 then
					local magnitude = (v.Magnitude - 0.15) / 0.85
					local curved = v.Unit * magnitude ^ 1.8
					local speed = Config.Camera.GamepadSpeed * (ClientState.Settings.Sensitivity or 1) * (sens / Config.Camera.DefaultSensitivity / (ClientState.Settings.Sensitivity or 1))
					yaw -= curved.X * speed * dt
					pitch += curved.Y * speed * dt
				end
			end
		end
	end
	local limit = math.rad(Config.Camera.PitchLimit)
	pitch = math.clamp(pitch, -limit, limit)

	local r = recoil:Step(dt)
	local d = dip:Step(dt)
	local s = shake:Step(dt)
	recoil.Target = Vector3.zero

	local head = root.CFrame * CFrame.new(0, 1.5, 0)
	local offset = humanoid.CameraOffset + Vector3.new(0, d.Y, 0)
	local cf = CFrame.new(head.Position + offset)
		* CFrame.fromEulerAnglesYXZ(pitch + math.rad(r.X + s.X), yaw + math.rad(r.Y + s.Y), 0)
	camera.CFrame = cf

	local hipFov = ClientState.Settings.Fov or Config.Camera.HipFov
	local targetFov = hipFov + fovBonus
	targetFov += (Config.Camera.ScopeFov - targetFov) * adsAlpha
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 18)

	humanoid.AutoRotate = false
	ensureAlign(root)
	if align then
		align.CFrame = CFrame.fromEulerAnglesYXZ(0, yaw, 0)
	end

	local now = os.clock()
	if now - lastLookSent >= 1 / Config.Netcode.LookSendHz then
		lastLookSent = now
		Remotes.Unreliable("Look"):FireServer(pitch, yaw)
	end
end

local function onCharacter(character: Model)
	align = nil
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not root or not humanoid then
		return
	end

	local _, y, _ = root.CFrame:ToEulerAnglesYXZ()
	yaw = y
	pitch = 0
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			local fall = math.abs(root.AssemblyLinearVelocity.Y)
			CameraController.Dip(math.clamp(fall / 40, 0.1, 1) * Config.Camera.LandingDip)
		end
	end)
end

function CameraController.Init()
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.TouchStarted:Connect(function(input, processed)
		if processed or touchId then
			return
		end
		if input.Position.X > camera.ViewportSize.X * 0.4 then
			touchId = input
		end
	end)
	UserInputService.TouchMoved:Connect(function(input)
		if input == touchId then
			touchDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)
	UserInputService.TouchEnded:Connect(function(input)
		if input == touchId then
			touchId = nil
		end
	end)
end

function CameraController.Start()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	RunService:BindToRenderStep("OffscopeCamera", Enum.RenderPriority.Camera.Value + 1, onRender)
end

return CameraController
