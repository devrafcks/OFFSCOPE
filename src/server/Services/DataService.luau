--[[
	DataService — perfis com ProfileStore (session lock, reconcile, autosave).
	• Única fonte de verdade de moedas, inventário, ELO e passe.
	• No Studio sem API Services o ProfileStore usa mock sozinho (nada salva, tudo funciona).
	• Mudanças disparam um Sync em lote para o cliente (ProfileSync), nunca o perfil inteiro cru.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local Elo = require(Shared.Progression.Elo)
local Registry = require(script.Parent.Parent.Registry)

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local DataService = {}

DataService.ProfileLoaded = Signal.new()

local TEMPLATE = {
	Coins = Config.Data.StartingCoins,
	Xp = 0,
	Level = 1,
	Elo = Config.Ranked.StartElo,
	PeakElo = Config.Ranked.StartElo,
	EloMatches = 0,
	SeasonId = Config.Ranked.SeasonId,
	Stats = {
		Kills = 0,
		Deaths = 0,
		Headshots = 0,
		NoScopes = 0,
		Quickscopes = 0,
		LongShots = 0,
		Aerials = 0,
		Knives = 0,
		Wins = 0,
		Losses = 0,
		Matches = 0,
		LongestShot = 0,
		RankedWins = 0,
		RankedLosses = 0,
	},
	Inventory = {},
	Equipped = table.clone(Config.DefaultEquipped),
	Pass = {
		Season = Config.Pass.Season,
		Xp = 0,
		Prime = false,
		ClaimedFree = {},
		ClaimedPrime = {},
	},
	Daily = {
		Day = 0,
		Ids = {},
		Base = {},
		Claimed = {},
	},
	Settings = {
		Sensitivity = 1,
		AdsSensitivity = Config.Camera.DefaultAdsSensitivity,
		Fov = Config.Camera.HipFov,
		PerformanceMode = false,
		ShowFps = false,
	},
	PurchaseIdCache = {},
	StarterPackOwned = false,
	FirstJoin = 0,
}

local store = ProfileStore.New(Config.Data.ProfileStoreName, TEMPLATE)
local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local syncScheduled = false

local function keyFor(player: Player): string
	return Config.Data.KeyPrefix .. player.UserId
end

-- Migrações leves: temporada nova, passe novo, itens removidos do catálogo.
local function migrate(data)
	if data.SeasonId ~= Config.Ranked.SeasonId then
		data.Elo = Elo.SoftReset(data.Elo)
		data.EloMatches = 0
		data.PeakElo = data.Elo
		data.SeasonId = Config.Ranked.SeasonId
	end
	if data.Pass.Season ~= Config.Pass.Season then
		data.Pass = {
			Season = Config.Pass.Season,
			Xp = 0,
			Prime = false,
			ClaimedFree = {},
			ClaimedPrime = {},
		}
	end
	for category, itemId in data.Equipped do
		local item = Config.Cosmetics[itemId]
		if not item or (item.Pool ~= "default" and not data.Inventory[itemId]) then
			data.Equipped[category] = (Config.DefaultEquipped :: any)[category]
		end
	end
	for category, default in Config.DefaultEquipped do
		if data.Equipped[category] == nil then
			data.Equipped[category] = default
		end
	end
	if data.FirstJoin == 0 then
		data.FirstJoin = os.time()
	end
end

local function updateLeaderstats(player: Player, data)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local level = Instance.new("IntValue")
		level.Name = "Nível"
		level.Parent = folder
		local elo = Instance.new("IntValue")
		elo.Name = "ELO"
		elo.Parent = folder
		folder.Parent = player
	end
	(folder :: any)["Nível"].Value = data.Level
	;(folder :: any).ELO.Value = data.Elo
end

-- Visão pública do perfil para o próprio jogador.
local function publicView(data)
	return {
		Coins = data.Coins,
		Xp = data.Xp,
		Level = data.Level,
		Elo = data.Elo,
		PeakElo = data.PeakElo,
		EloMatches = data.EloMatches,
		Stats = data.Stats,
		Inventory = data.Inventory,
		Equipped = data.Equipped,
		Pass = data.Pass,
		Daily = data.Daily,
		Settings = data.Settings,
		StarterPackOwned = data.StarterPackOwned,
	}
end

local function flush()
	syncScheduled = false
	local remote = Remotes.Event("ProfileSync")
	for player in dirty do
		local profile = profiles[player]
		if profile and player.Parent == Players then
			remote:FireClient(player, publicView(profile.Data))
			updateLeaderstats(player, profile.Data)
		end
	end
	table.clear(dirty)
end

function DataService.MarkDirty(player: Player)
	dirty[player] = true
	if not syncScheduled then
		syncScheduled = true
		task.defer(flush)
	end
end

function DataService.Get(player: Player): any?
	return profiles[player]
end

function DataService.GetData(player: Player): any?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Espera o perfil carregar (ou o jogador sair). Retorna nil se não carregar.
function DataService.Wait(player: Player, timeout: number?): any?
	local deadline = os.clock() + (timeout or 30)
	while profiles[player] == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Mutação com sync automático: DataService.Update(player, function(data) data.Coins += 10 end)
function DataService.Update(player: Player, mutator: (data: any) -> ()): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	mutator(profile.Data)
	DataService.MarkDirty(player)
	return true
end

function DataService.AddCoins(player: Player, amount: number): boolean
	return DataService.Update(player, function(data)
		data.Coins = math.max(0, data.Coins + math.floor(amount))
	end)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(keyFor(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Não conseguimos carregar seus dados agora. Tente de novo em instantes.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Sua sessão foi aberta em outro servidor.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	migrate(profile.Data)
	if RunService:IsStudio() and Config.Studio.BonusCoins > 0 and profile.Data.Coins < Config.Studio.BonusCoins then
		profile.Data.Coins = Config.Studio.BonusCoins
	end

	profiles[player] = profile
	Registry.ProgressionService.RollDailyChallenges(player, profile.Data)
	DataService.MarkDirty(player)
	DataService.ProfileLoaded:Fire(player, profile.Data)
end

function DataService.Init()
	Remotes.Event("SaveSettings").OnServerEvent:Connect(function(player, settings)
		if type(settings) ~= "table" then
			return
		end
		DataService.Update(player, function(data)
			local s = data.Settings
			if type(settings.Sensitivity) == "number" then
				s.Sensitivity = math.clamp(settings.Sensitivity, 0.1, 5)
			end
			if type(settings.AdsSensitivity) == "number" then
				s.AdsSensitivity = math.clamp(settings.AdsSensitivity, 0.1, 2)
			end
			if type(settings.Fov) == "number" then
				s.Fov = math.clamp(math.floor(settings.Fov), 70, 110)
			end
			if type(settings.PerformanceMode) == "boolean" then
				s.PerformanceMode = settings.PerformanceMode
			end
			if type(settings.ShowFps) == "boolean" then
				s.ShowFps = settings.ShowFps
			end
		end)
	end)
end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		-- adiado um passo: outros handlers de saída (ex.: abandono de ranked) ainda gravam no perfil
		task.defer(function()
			local profile = profiles[player]
			profiles[player] = nil
			dirty[player] = nil
			if profile then
				profile:EndSession()
			end
		end)
	end)
end

return DataService
