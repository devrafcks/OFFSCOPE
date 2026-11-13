local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)
local InputController = require(script.Parent.InputController)
local CameraController = require(script.Parent.CameraController)

local MovementController = {}

MovementController.SlideStarted = Signal.new()

local player = Players.LocalPlayer

local sprinting = false
local sprintSince = 0
local sliding = false
local slideStart = 0
local slideDir = Vector3.zero
local lastSlideEnd = -10
local velocity: LinearVelocity? = nil
local cameraDrop = 0
local speedMultiplier = 1

local mobileSprintToggle = false

export type State = { Speed: number, Grounded: boolean, Sliding: boolean, Sprinting: boolean }

function MovementController.State(): State
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return { Speed = 0, Grounded = true, Sliding = false, Sprinting = false }
	end
	local v = root.AssemblyLinearVelocity
	return {
		Speed = Vector3.new(v.X, 0, v.Z).Magnitude,
		Grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
		Sliding = sliding,
		Sprinting = sprinting,
	}
end

function MovementController.IsSprinting(): boolean
	return sprinting
end

function MovementController.IsSliding(): boolean
	return sliding
end

function MovementController.SetSpeedMultiplier(multiplier: number)
	speedMultiplier = multiplier
end

function MovementController.StopSprint()
	sprinting = false
	mobileSprintToggle = false
end

local function frozen(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("Frozen") == true
end

local function endSlide()
	if not sliding then
		return
	end
	sliding = false
	lastSlideEnd = os.clock()
	if velocity then
		velocity.Enabled = false
	end
end

local function ensureVelocity(root: BasePart): LinearVelocity
	if velocity and velocity.Parent and velocity.Parent.Parent == root then
		return velocity
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "OffscopeSlide"
	attachment.Parent = root
	local constraint = Instance.new("LinearVelocity")
	constraint.Name = "SlideVelocity"
	constraint.Attachment0 = attachment
	constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	constraint.PrimaryTangentAxis = Vector3.xAxis
	constraint.SecondaryTangentAxis = Vector3.zAxis
	constraint.RelativeTo = Enum.ActuatorRelativeTo.World
	constraint.MaxForce = 60000
	constraint.Enabled = false
	constraint.Parent = attachment
	velocity = constraint
	return constraint
end

local function tryStartSlide()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or frozen() then
		return
	end
	local slide = Config.Movement.Slide
	if sliding or not sprinting or os.clock() - sprintSince < slide.MinSprintTime then
		return
	end
	if os.clock() - lastSlideEnd < slide.Cooldown or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	local v = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	slideDir = if v.Magnitude > 2 then v.Unit else (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	sliding = true
	slideStart = os.clock()
	local constraint = ensureVelocity(root)
	constraint.Enabled = true
	MovementController.SlideStarted:Fire()
	CameraController.Dip(0.25)
end

local function update(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local move = Config.Movement
	local isFrozen = frozen()

	local wantsSprint = InputController.IsHeld("Sprint") or mobileSprintToggle
	local forward = humanoid.MoveDirection:Dot((root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit) > 0.5
	local canSprint = wantsSprint and forward and humanoid.MoveDirection.Magnitude > 0.1 and speedMultiplier >= 1 and not isFrozen
	if canSprint and not sprinting then
		sprintSince = os.clock()
	end
	sprinting = canSprint or (sliding and sprinting)

	if sliding then
		local slide = move.Slide
		local t = (os.clock() - slideStart) / slide.Duration
		if t >= 1 or humanoid.FloorMaterial == Enum.Material.Air or isFrozen or humanoid.Health <= 0 then
			endSlide()
		elseif velocity then
			local speed = slide.StartSpeed + (slide.EndSpeed - slide.StartSpeed) * (t * t)
			velocity.PlaneVelocity = Vector2.new(slideDir.X * speed, slideDir.Z * speed)
		end
	end

	local walk = move.WalkSpeed * speedMultiplier
	if isFrozen then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = if sprinting then move.SprintSpeed * math.max(speedMultiplier, 1) else walk
		humanoid.JumpHeight = move.JumpHeight
	end

	local targetDrop = if sliding then move.Slide.CameraDrop else 0
	cameraDrop += (targetDrop - cameraDrop) * math.min(1, dt * 14)
	humanoid.CameraOffset = Vector3.new(0, -cameraDrop, 0)

	local bonus = if sliding then Config.Camera.SlideFovBonus elseif sprinting then Config.Camera.SprintFovBonus else 0
	CameraController.SetFovBonus(bonus)
end

local function onCharacter(character: Model)
	sliding = false
	sprinting = false
	velocity = nil
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.Movement.JumpHeight
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping and sliding then

				endSlide()
			end
		end)
	end
end

function MovementController.Init()
	InputController.Pressed:Connect(function(action)
		if action == "Slide" then
			tryStartSlide()
		elseif action == "Sprint" and InputController.IsHeld("Sprint") == true then

			local UserInputService = game:GetService("UserInputService")
			if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
				mobileSprintToggle = not mobileSprintToggle
			end
		end
	end)
end

function MovementController.Start()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	RunService:BindToRenderStep("OffscopeMovement", Enum.RenderPriority.Input.Value + 1, update)
end

return MovementController
