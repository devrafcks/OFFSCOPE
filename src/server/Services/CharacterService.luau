--[[
	CharacterService — nascer, morrer e "vestir" a arma em 3ª pessoa.

	• Contexto por jogador: Lobby ou Match. Quem decide o respawn é o dono do contexto.
	• Avatares normalizados (escala 1, partes de corpo padrão) → hitbox igual para todos.
	  Roupas, cores e acessórios continuam; acessórios nunca contam como hit.
	• Arma do mundo (Lite) presa na mão, com o wrap equipado; faca troca de lugar com a sniper.
	• Pose de segurar a arma: atributos BaseC0/HoldC0 nas juntas + HoldPose por frame
	  (cliente e servidor; Motor6D ou AnimationConstraint do avatar novo).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local HoldPose = require(Shared.Util.HoldPose)
local Joint = require(Shared.Util.Joint)
local SniperBuilder = require(Shared.Models.SniperBuilder)
local KnifeBuilder = require(Shared.Models.KnifeBuilder)
local ModelKit = require(Shared.Models.ModelKit)
local WrapPainter = require(Shared.Cosmetics.WrapPainter)
local Registry = require(script.Parent.Parent.Registry)

local CharacterService = {}

export type Context = { Kind: "Lobby" } | { Kind: "Match", Match: any }

CharacterService.Spawned = Signal.new()
CharacterService.Died = Signal.new()

local contexts: { [Player]: Context } = {}
local descriptions: { [Player]: HumanoidDescription } = {}
local spawnTokens: { [Player]: number } = {}

local WORLD_SCALE = 0.72
local KNIFE_SCALE = 0.8

-- ── contexto ─────────────────────────────────────────────────────────────────
function CharacterService.SetContext(player: Player, context: Context)
	contexts[player] = context
	player:SetAttribute("Context", context.Kind)
end

function CharacterService.GetContext(player: Player): Context
	return contexts[player] or { Kind = "Lobby" }
end

-- ── descrição normalizada ────────────────────────────────────────────────────
local function getDescription(player: Player): HumanoidDescription
	local cached = descriptions[player]
	if cached then
		return cached:Clone()
	end
	local description: HumanoidDescription
	local ok, result = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(math.max(player.UserId, 1))
	end)
	if ok and result then
		description = result
	else
		description = Instance.new("HumanoidDescription")
	end
	if Config.Player.NormalizeAvatars then
		description.HeightScale = 1
		description.WidthScale = 1
		description.DepthScale = 1
		description.HeadScale = 1
		description.BodyTypeScale = 0
		description.ProportionScale = 0
		description.Head = 0
		description.Torso = 0
		description.LeftArm = 0
		description.RightArm = 0
		description.LeftLeg = 0
		description.RightLeg = 0
	end
	descriptions[player] = description
	return description:Clone()
end

-- ── arma em 3ª pessoa ───────────────────────────────────────────────────────
-- Converte o espaço da arma (frente −Z, cima +Y) para o espaço da mão com o braço estendido.
local HAND_TO_WEAPON = CFrame.fromMatrix(Vector3.new(0, -0.15, -0.05), Vector3.xAxis, Vector3.new(0, 0, -1), Vector3.yAxis)
local BACK_OFFSET = CFrame.new(0, 0.1, 0.62) * CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(0, math.rad(90), 0)

local function handOf(character: Model): BasePart?
	return (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: any
end

local function torsoOf(character: Model): BasePart?
	return (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: any
end

local function setVisible(model: Instance, visible: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			if part:GetAttribute("BaseTransparency") == nil then
				part:SetAttribute("BaseTransparency", part.Transparency)
			end
			part.Transparency = if visible then part:GetAttribute("BaseTransparency") :: number else 1
		end
	end
end

local function weldTo(part0: BasePart, root: BasePart, c0: CFrame): Weld
	local weld = root:FindFirstChild("HoldWeld") :: Weld?
	if not weld then
		local created = Instance.new("Weld")
		created.Name = "HoldWeld"
		created.Part1 = root
		created.Parent = root
		weld = created
	end
	local w = weld :: Weld
	w.Part0 = part0
	w.C0 = c0
	w.C1 = CFrame.identity
	return w
end

local function refreshHold(character: Model)
	local sniper = character:FindFirstChild("WorldSniper") :: Model?
	local knife = character:FindFirstChild("WorldKnife") :: Model?
	local hand = handOf(character)
	local torso = torsoOf(character)
	if not (sniper and knife and hand and torso) then
		return
	end
	local knifeOut = character:GetAttribute("Weapon") == "Knife"
	local sniperRoot = sniper.PrimaryPart :: BasePart
	if knifeOut then
		weldTo(torso, sniperRoot, BACK_OFFSET)
	else
		weldTo(hand, sniperRoot, HAND_TO_WEAPON)
	end
	weldTo(hand, knife.PrimaryPart :: BasePart, HAND_TO_WEAPON)
	setVisible(knife, knifeOut)
end

function CharacterService.RefreshCosmetics(player: Player)
	local character = player.Character
	local data = Registry.DataService.GetData(player)
	if not character or not data then
		return
	end
	local equipped = data.Equipped

	local oldSniper = character:FindFirstChild("WorldSniper")
	if oldSniper then
		oldSniper:Destroy()
	end
	local oldKnife = character:FindFirstChild("WorldKnife")
	if oldKnife then
		oldKnife:Destroy()
	end

	local sniper = SniperBuilder.Build("Lite")
	sniper.Model.Name = "WorldSniper"
	WrapPainter.Apply(sniper.Model, equipped.Wrap, { Textures = false, Animate = false })
	ModelKit.Finalize(sniper.Model, sniper.Root, { Anchored = false })
	sniper.Model:ScaleTo(WORLD_SCALE)
	sniper.Model.Parent = character

	local knifeDef = Config.Cosmetics[equipped.Knife] or Config.Cosmetics[Config.DefaultEquipped.Knife]
	local knife = KnifeBuilder.Build(knifeDef.Visual.Shape)
	knife.Model.Name = "WorldKnife"
	WrapPainter.PaintKnife(knife.Model, equipped.Knife)
	ModelKit.Finalize(knife.Model, knife.Root, { Anchored = false })
	knife.Model:ScaleTo(KNIFE_SCALE)
	knife.Model.Parent = character

	character:SetAttribute("Wrap", equipped.Wrap)
	character:SetAttribute("Tracer", equipped.Tracer)
	refreshHold(character)
end

local function applyHoldPose(character: Model)
	local rightUpper = character:FindFirstChild("RightUpperArm")
	local leftUpper = character:FindFirstChild("LeftUpperArm")
	local right = Joint.Find(rightUpper, "RightShoulder")
	local left = Joint.Find(leftUpper, "LeftShoulder")
	-- BaseC0 guarda o original: respawn/reaplicação nunca acumula rotação
	local function pose(joint: Instance?, offset: CFrame)
		if not joint then
			return
		end
		local base = (joint:GetAttribute("BaseC0") :: CFrame?) or Joint.GetC0(joint)
		if not base then
			return
		end
		joint:SetAttribute("BaseC0", base)
		local hold = base * offset
		if joint:IsA("Motor6D") then
			Joint.SetC0(joint, hold) -- replica; AnimationConstraint é posado por frame no cliente
		end
		-- o cliente aplica o tilt de pitch em cima deste C0 (HoldC0 replica como atributo)
		joint:SetAttribute("HoldC0", hold)
	end
	pose(right, CFrame.Angles(0, math.rad(10), 0) * CFrame.Angles(math.rad(88), 0, 0))
	pose(left, CFrame.Angles(0, math.rad(-32), 0) * CFrame.Angles(math.rad(84), 0, 0))
	pose(Joint.Find(character:FindFirstChild("Head"), "Neck"), CFrame.identity)
end

-- ── spawn ────────────────────────────────────────────────────────────────────
export type SpawnOptions = {
	Frozen: boolean?,
	Protection: number?,
	Regen: boolean?,
	Team: string?,
	Preset: string?,
}

function CharacterService.Spawn(player: Player, cframe: CFrame, options: SpawnOptions?): Model?
	local opts = options or {}
	if player.Parent ~= Players then
		return nil
	end
	spawnTokens[player] = (spawnTokens[player] or 0) + 1
	local token = spawnTokens[player]

	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 4)
	end)

	local description = getDescription(player)
	local ok = pcall(function()
		player:LoadCharacterWithHumanoidDescriptionAsync(description)
	end)
	if not ok then
		pcall(function()
			player:LoadCharacterAsync()
		end)
	end
	if spawnTokens[player] ~= token then
		return nil -- outro spawn foi pedido enquanto este carregava
	end

	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return nil
	end

	Registry.AntiCheatService.Grace(player, 2)
	character:PivotTo(cframe)

	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.BreakJointsOnDeath = true
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0

	character:SetAttribute("Weapon", "Sniper")
	character:SetAttribute("Scoped", false)
	character:SetAttribute("Pitch", 0)
	character:SetAttribute("Frozen", opts.Frozen == true)
	character:SetAttribute("Regen", opts.Regen ~= false)
	character:SetAttribute("Team", opts.Team or "")
	character:SetAttribute("ProtectedUntil", if opts.Protection then os.clock() + opts.Protection else 0)

	applyHoldPose(character)
	CharacterService.RefreshCosmetics(player)
	Registry.LagCompensation.Register(character, player)
	Registry.CombatState.Reset(player)

	if opts.Preset then
		Remotes.Event("Environment"):FireClient(player, opts.Preset)
	end

	humanoid.Died:Once(function()
		CharacterService.Died:Fire(player, character)
		local context = CharacterService.GetContext(player)
		if context.Kind == "Match" then
			context.Match:OnPlayerDied(player, character)
		else
			task.delay(2, function()
				if player.Character == character and CharacterService.GetContext(player).Kind == "Lobby" then
					Registry.LobbyService.SpawnInLobby(player)
				end
			end)
		end
	end)

	character:GetAttributeChangedSignal("Weapon"):Connect(function()
		refreshHold(character)
	end)

	CharacterService.Spawned:Fire(player, character)
	return character
end

function CharacterService.SetFrozen(player: Player, frozen: boolean)
	local character = player.Character
	if character then
		character:SetAttribute("Frozen", frozen)
	end
end

function CharacterService.IsProtected(character: Model): boolean
	local untilTime = character:GetAttribute("ProtectedUntil")
	return type(untilTime) == "number" and os.clock() < untilTime
end

function CharacterService.IsAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Teleporta um personagem vivo (sem recarregar).
function CharacterService.Teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 3)
	end)
	Registry.AntiCheatService.Grace(player, 2)
	character:PivotTo(cframe)
end

function CharacterService.Init()
	Players.PlayerRemoving:Connect(function(player)
		contexts[player] = nil
		descriptions[player] = nil
		spawnTokens[player] = nil
	end)
	-- mesma pose dos clientes nas AnimationConstraints, para as hitboxes dos braços baterem
	-- (Motor6D fica com o C0 replicado: nada de escrever C0 60×/s pela rede)
	RunService.PreSimulation:Connect(function(dt)
		HoldPose.Step(dt, function()
			return false
		end)
	end)
end

return CharacterService
