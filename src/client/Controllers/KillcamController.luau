--[[
	KillcamController — 3 s na "visão" de quem te matou.
	MVP honesto: a câmera vai para a cabeça do killer (posição ao vivo), olhando para onde você
	caiu, com o tracer do tiro reprisado, DoF leve (o único lugar onde DoF liga) e um cartão
	com nome, arma, distância e tags de estilo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ShotStyle = require(Shared.Combat.ShotStyle)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)

local KillcamController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local New = Theme.New

local DURATION = 3
local card: Frame? = nil
local token = 0

local function buildCard(data)
	if card then
		card:Destroy()
	end
	local frame = Theme.Panel({
		Name = "Killcam",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(440, 96),
		Parent = HudController.Gui(),
	})
	Theme.Label({
		Text = "ELIMINADO POR",
		FontFace = Theme.Fonts.Title,
		TextSize = 12,
		TextColor3 = Theme.Colors.TextDim,
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.fromOffset(200, 14),
		Parent = frame,
	})
	Theme.Label({
		Text = data.KillerName or "?",
		FontFace = Theme.Fonts.Display,
		TextSize = 28,
		Position = UDim2.fromOffset(18, 28),
		Size = UDim2.fromOffset(300, 32),
		Parent = frame,
	})
	local weaponName = if data.Weapon == "Knife" then Config.Knife.DisplayName else Config.Sniper.DisplayName
	local wrap = Config.Cosmetics[data.Wrap or ""]
	Theme.Label({
		Text = `{weaponName}{if wrap then " · " .. wrap.Name else ""} · {Format.Meters(data.Distance or 0)}`,
		FontFace = Theme.Fonts.Body,
		TextSize = 14,
		TextColor3 = Theme.Colors.TextDim,
		Position = UDim2.fromOffset(18, 62),
		Size = UDim2.fromOffset(300, 18),
		Parent = frame,
	})
	local tags = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(160, 70),
		BackgroundTransparency = 1,
		Parent = frame,
		New("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4) }),
	})
	for _, tag in data.Tags or {} do
		local chip = Theme.Label({
			Text = ShotStyle.Labels[tag] or tag,
			FontFace = Theme.Fonts.Title,
			TextSize = 12,
			TextColor3 = Theme.Colors.Ink,
			BackgroundColor3 = ShotStyle.Colors[tag] or Theme.Colors.Text,
			BackgroundTransparency = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			Parent = tags,
		})
		Theme.Corner(4).Parent = chip
		Theme.Padding(0, 6).Parent = chip
	end
	local scale = New("UIScale", { Scale = 0.85, Parent = frame })
	Theme.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	card = frame
end

local function play(data)
	token += 1
	local myToken = token
	local killer: Player? = data.Killer
	local victimPos: Vector3 = data.HitPosition or camera.CFrame.Position
	local origin: Vector3 = data.Origin or victimPos + Vector3.new(0, 4, 10)

	CameraController.Suspend(true)
	ViewmodelController.SetHidden(true)
	camera.CameraType = Enum.CameraType.Scriptable
	buildCard(data)

	local dof = Lighting:FindFirstChild("OffscopeDof") :: DepthOfFieldEffect?
	if dof then
		dof.FocusDistance = math.clamp((origin - victimPos).Magnitude, 10, 400)
		dof.InFocusRadius = 25
		dof.Enabled = true
	end

	-- um instante na própria morte, depois corta para o killer
	local start = os.clock()
	local replayed = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if myToken ~= token then
			connection:Disconnect()
			return
		end
		local t = os.clock() - start
		local headPos = origin
		local head = killer and killer.Character and killer.Character:FindFirstChild("Head") :: BasePart?
		if head then
			headPos = head.Position
		end
		if t < 0.6 then
			-- câmera "cai" e olha para o atirador
			local from = victimPos + Vector3.new(0, 2.5 - t * 1.5, 0)
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(from, headPos), 0.15)
			camera.FieldOfView += (60 - camera.FieldOfView) * 0.1
		else
			if not replayed then
				replayed = true
				EffectsController.Tracer(headPos + (victimPos - headPos).Unit * 2, victimPos, nil)
			end
			local back = (headPos - victimPos).Unit
			local eye = headPos + back * 2.2 + Vector3.new(0, 0.6, 0)
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, victimPos), 0.2)
			camera.FieldOfView += (45 - camera.FieldOfView) * 0.08
		end
	end)

	task.delay(math.min(DURATION, (data.RespawnIn or DURATION) + 0.2), function()
		if myToken ~= token then
			return
		end
		KillcamController.Stop()
	end)
end

function KillcamController.Stop()
	token += 1
	if card then
		local frame = card
		card = nil
		Theme.Tween(frame, 0.2, { BackgroundTransparency = 1 })
		task.delay(0.2, function()
			frame:Destroy()
		end)
	end
	local dof = Lighting:FindFirstChild("OffscopeDof") :: DepthOfFieldEffect?
	if dof then
		dof.Enabled = false
	end
	CameraController.Suspend(false)
	ViewmodelController.SetHidden(false)
end

function KillcamController.Init()
	Remotes.Event("Killed").OnClientEvent:Connect(play)
	player.CharacterAdded:Connect(function()
		KillcamController.Stop()
	end)
end

return KillcamController
