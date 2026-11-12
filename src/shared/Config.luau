--[[
	OFFSCOPE — Config
	ÚNICO lugar de números de gameplay, economia, rede, strings de produto e IDs.
	IDs reais ficam 0 até o dono colar os valores do Dashboard (ver docs/produtos.md).

	Dica de playtest: mude um número aqui e dê Play — nada mais precisa mudar.
]]

local Config = {}

-- ─────────────────────────────────────────────────────────────── identidade
Config.Game = {
	Name = "OFFSCOPE",
	Tagline = "Uma bala. Sem mira. Só reflexo.",
	Version = "0.9.0",
}

-- ─────────────────────────────────────────────────────────────── places
-- 0 = não publicado. Com Match = 0 o jogo roda tudo "in-place" (lobby + partida no mesmo servidor).
Config.Places = {
	Lobby = 0,
	Match = 0,
}

Config.Studio = {
	-- No Studio, compras com ProductId 0 são simuladas (concede o item sem cobrar).
	SimulateRobuxPurchases = true,
	-- Moedas extras para testar a loja no Studio.
	BonusCoins = 50000,
	-- Mínimo de jogadores para começar uma partida no Studio (1 = testar sozinho contra ninguém).
	MinPlayersOverride = nil :: number?,
	-- Loga cada tiro no Output do servidor (parte, zona, rewind, desvio do spread). Só no Studio.
	DebugHits = false,
}

-- ─────────────────────────────────────────────────────────────── dados
Config.Data = {
	ProfileStoreName = "Offscope_Player_v1",
	KeyPrefix = "Player_",
	StartingCoins = 1500,
	PurchaseIdCacheSize = 100,
	LeaderboardStore = "Offscope_Elo_S1",
	LeaderboardRefresh = 90,
	LeaderboardSize = 10,
}

-- ─────────────────────────────────────────────────────────────── jogador
Config.Player = {
	MaxHealth = 100,
	RegenDelay = 6, -- s sem tomar dano para regenerar (só modos com respawn)
	RegenPerSecond = 18,
	SpawnProtection = 1.25, -- s imune após nascer (respawn)
	RespawnDelay = 3.2, -- inclui a killcam
	NormalizeAvatars = true, -- escala padrão para hitboxes justas
}

Config.Movement = {
	WalkSpeed = 16,
	SprintSpeed = 23,
	KnifeSpeedMultiplier = 1.1,
	AdsSpeedMultiplier = 0.55,
	JumpHeight = 6.5,
	Slide = {
		StartSpeed = 38,
		EndSpeed = 17,
		Duration = 0.8,
		Cooldown = 1.1,
		CameraDrop = 1.6,
		MinSprintTime = 0.12,
	},
}

Config.Camera = {
	HipFov = 95,
	ScopeFov = 30,
	DefaultSensitivity = 0.0032, -- rad por pixel de mouse
	DefaultAdsSensitivity = 0.55, -- multiplicador relativo ao FOV
	GamepadSpeed = 4.2, -- rad/s no stick cheio
	TouchSensitivity = 0.0055,
	PitchLimit = 88,
	SprintFovBonus = 6,
	SlideFovBonus = 9,
	LandingDip = 0.35,
}

-- ─────────────────────────────────────────────────────────────── armas
Config.Sniper = {
	Id = "Sniper",
	DisplayName = "Vanta-7",
	BoltTime = 0.95,
	MagSize = 5,
	InfiniteReserve = true,
	ReserveAmmo = 30,
	ReloadTime = 2.4,
	EquipTime = 0.42,
	Range = 1600,

	Damage = {
		Head = 100,
		Chest = 75,
		Stomach = 65,
		Limb = 50,
	},
	Falloff = {
		FullUntil = 220,
		MinAt = 450,
		MinMultiplier = 0.8,
		HeadIgnoresFalloff = true,
	},

	-- Spread em graus (raio do cone). Multiplicadores por estado.
	Spread = {
		Base = 0.25,
		Walk = 1.6,
		Sprint = 3.0,
		Slide = 2.4,
		Air = 7.0,
		WalkSpeedThreshold = 3, -- studs/s para contar como andando
		AdsSpread = 0.015,
		QuickscopeStart = 0.55, -- alpha de ADS a partir do qual o spread começa a cair
	},

	Ads = {
		Time = 0.34,
		Settle = 0.09,
		OutTime = 0.16,
		GlintAlpha = 0.6, -- a partir daqui os outros veem o brilho da luneta
		AutoUnscopeOnShot = true,
	},

	Recoil = {
		Pitch = 3.4, -- graus de kick na câmera
		Yaw = 0.7,
		Recovery = 9, -- velocidade de volta
		ViewmodelKick = 0.32,
	},

	TracerSpeed = 2200, -- só visual
}

Config.Knife = {
	Id = "Knife",
	DisplayName = "Faca",
	Range = 6.5,
	ConeDegrees = 50,
	BackDamage = 100,
	FrontDamage = 55,
	BackstabDot = 0.35, -- dot(look da vítima, direção atacante→vítima) acima disso = costas
	SwingTime = 0.48,
	QuickMeleeTime = 0.62,
	EquipTime = 0.22,
	HitDelay = 0.09, -- tempo do golpe até o hit (aplicado no cliente antes de mandar)
}

-- ─────────────────────────────────────────────────────────────── estilo / recompensas
Config.Style = {
	NoScopeMaxAds = 0.15,
	QuickscopeMaxScopeTime = 0.45,
	LongShotDistance = 150,
	TrickSpinDegrees = 300,
	TrickSpinWindow = 1.2,
}

Config.Rewards = {
	Kill = 25,
	Headshot = 15,
	NoScope = 20,
	Quickscope = 10,
	LongShot = 15,
	Aerial = 20,
	Spin = 50,
	Knife = 20,
	Backstab = 30,
	RoundWin = 10,
	MatchWin = 150,
	MatchLoss = 50,
	-- XP de conta / passe
	XpPerKill = 60,
	XpPerMatch = 200,
	XpWinBonus = 150,
	RangeKillCoins = 0, -- dummies não dão moedas (anti-farm)
}

Config.Levels = {
	BaseXp = 900,
	Growth = 1.08,
	MaxLevel = 200,
}

-- ─────────────────────────────────────────────────────────────── modos
export type ModeDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	TeamSize: number, -- 0 = FFA
	Players: number,
	RoundBased: boolean,
	ScoreToWin: number,
	TimeLimit: number,
	Ranked: boolean,
	BaseMode: string,
}

Config.Modes = {
	Duel = {
		Id = "Duel",
		DisplayName = "Duelo 1v1",
		Description = "Primeiro a 6 rounds. Uma vida por round.",
		TeamSize = 1,
		Players = 2,
		RoundBased = true,
		ScoreToWin = 6,
		TimeLimit = 75,
		Ranked = false,
		BaseMode = "Duel",
	},
	Duos = {
		Id = "Duos",
		DisplayName = "Duplas 2v2",
		Description = "Primeiro a 6 rounds. Elimine a outra dupla.",
		TeamSize = 2,
		Players = 4,
		RoundBased = true,
		ScoreToWin = 6,
		TimeLimit = 90,
		Ranked = false,
		BaseMode = "Duos",
	},
	Squads = {
		Id = "Squads",
		DisplayName = "Equipes 4v4",
		Description = "Mata-mata em equipe. 40 kills ou 8 minutos.",
		TeamSize = 4,
		Players = 8,
		RoundBased = false,
		ScoreToWin = 40,
		TimeLimit = 480,
		Ranked = false,
		BaseMode = "Squads",
	},
	FFA = {
		Id = "FFA",
		DisplayName = "Todos contra todos",
		Description = "8 jogadores. Primeiro a 20 kills.",
		TeamSize = 0,
		Players = 8,
		RoundBased = false,
		ScoreToWin = 20,
		TimeLimit = 480,
		Ranked = false,
		BaseMode = "FFA",
	},
	RankedDuel = {
		Id = "RankedDuel",
		DisplayName = "Ranked 1v1",
		Description = "Duelo valendo ELO. Primeiro a 6.",
		TeamSize = 1,
		Players = 2,
		RoundBased = true,
		ScoreToWin = 6,
		TimeLimit = 75,
		Ranked = true,
		BaseMode = "Duel",
	},
	RankedDuos = {
		Id = "RankedDuos",
		DisplayName = "Ranked 2v2",
		Description = "Duplas valendo ELO. Primeiro a 6.",
		TeamSize = 2,
		Players = 4,
		RoundBased = true,
		ScoreToWin = 6,
		TimeLimit = 90,
		Ranked = true,
		BaseMode = "Duos",
	},
} :: { [string]: ModeDef }

Config.ModeOrder = { "Duel", "RankedDuel", "Duos", "RankedDuos", "Squads", "FFA" }

Config.Match = {
	WarmupTime = 6, -- contagem antes do 1º round
	RoundFreezeTime = 3, -- congelado no spawn
	RoundEndTime = 3.5,
	MatchEndTime = 8,
	VoteTime = 20,
	VoteOptions = 2, -- + "Aleatório"
	ContinueAfterVote = true, -- false = sempre volta ao lobby
	MinPlayersToContinue = 2,
	AbandonGrace = 25, -- s esperando reconectar antes de dar W.O.
}

-- ─────────────────────────────────────────────────────────────── ranked
Config.Ranked = {
	SeasonId = 1,
	SeasonName = "Temporada 1 — Maré Baixa",
	StartElo = 1000,
	KFactorNew = 40, -- primeiras partidas
	KFactor = 24,
	NewPlayerMatches = 10,
	SoftResetWeight = 0.5, -- novoElo = StartElo + (elo − StartElo) × peso
	MinElo = 100,
	Tiers = {
		{ Name = "Recruta", MinElo = 0, Color = Color3.fromRGB(150, 128, 112) },
		{ Name = "Atirador", MinElo = 1050, Color = Color3.fromRGB(176, 190, 197) },
		{ Name = "Veterano", MinElo = 1200, Color = Color3.fromRGB(240, 196, 92) },
		{ Name = "Especialista", MinElo = 1400, Color = Color3.fromRGB(84, 214, 196) },
		{ Name = "Elite", MinElo = 1650, Color = Color3.fromRGB(164, 120, 255) },
		{ Name = "Lenda", MinElo = 1900, Color = Color3.fromRGB(255, 92, 92) },
	},
}

-- ─────────────────────────────────────────────────────────────── mapas
export type MapDef = {
	Id: string,
	DisplayName: string,
	Subtitle: string,
	Builder: string,
	Preset: string,
}

Config.Maps = {
	SlotSpacing = 6000, -- distância entre arenas in-place
	MaxConcurrentInPlace = 2,
	Order = { "Cais09", "Avenida11", "Posto47" },
	List = {
		Cais09 = {
			Id = "Cais09",
			DisplayName = "Cais 09",
			Subtitle = "Porto industrial · amanhecer",
			Builder = "Cais09",
			Preset = "Cais09",
		},
		Avenida11 = {
			Id = "Avenida11",
			DisplayName = "Avenida 11",
			Subtitle = "Centro urbano · noite de chuva",
			Builder = "Avenida11",
			Preset = "Avenida11",
		},
		Posto47 = {
			Id = "Posto47",
			DisplayName = "Posto 47",
			Subtitle = "Fronteira na serra · golden hour",
			Builder = "Posto47",
			Preset = "Posto47",
		},
	} :: { [string]: MapDef },
	KillPlaneDepth = -60, -- relativo à origem do slot
}

-- ─────────────────────────────────────────────────────────────── rede
Config.Netcode = {
	HistoryHz = 30,
	HistorySeconds = 1.0,
	MaxRewind = 0.45,
	InterpolationDelay = 0.1,
	HitboxPadding = 0.22,
	MaxOriginDistance = 10,
	LookSendHz = 12,
	BoltTolerance = 0.12,
	SpreadTolerance = 0.55, -- spread declarado pode ser até 55% do estimado no servidor
	AimConeDegrees = 30, -- direção do tiro vs. olhar replicado (só log)
	RemoteBudgets = { -- token bucket: { capacidade, recarga por segundo }
		Fire = { 4, 2 },
		Melee = { 4, 3 },
		Look = { 30, 20 },
		Action = { 20, 8 },
		Shop = { 10, 3 },
	},
}

Config.AntiCheat = {
	SpeedSampleInterval = 0.5,
	SpeedTolerance = 1.35,
	SuspicionLogThreshold = 10,
	KickThreshold = math.huge, -- sem kick automático no MVP (só log)
	HeadshotRatioSample = 40,
	HeadshotRatioSuspicious = 0.9,
	SnapDegreesSuspicious = 160,
	SnapWindow = 0.05,
}

Config.Matchmaking = {
	QueuePrefix = "Offscope_Q_",
	AssignmentMap = "Offscope_Assign",
	QueueEntryTtl = 120,
	PollInterval = 2,
	TeleportRetries = 3,
	TeleportRetryDelay = 2,
	LocalStartDelay = 3, -- s com a fila cheia antes de iniciar in-place
}

-- ─────────────────────────────────────────────────────────────── cosméticos
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

Config.Rarities = {
	Common = { Name = "Comum", Color = Color3.fromRGB(176, 186, 196), Order = 1 },
	Uncommon = { Name = "Incomum", Color = Color3.fromRGB(96, 214, 124), Order = 2 },
	Rare = { Name = "Raro", Color = Color3.fromRGB(70, 156, 255), Order = 3 },
	Epic = { Name = "Épico", Color = Color3.fromRGB(184, 104, 255), Order = 4 },
	Legendary = { Name = "Lendário", Color = Color3.fromRGB(255, 176, 56), Order = 5 },
}

Config.Categories = {
	Wrap = "Wraps",
	Charm = "Charms",
	Knife = "Facas",
	KillEffect = "Efeitos de kill",
	Finisher = "Finalizações",
	Reticle = "Retículos",
	Tracer = "Tracers",
}

export type CosmeticDef = {
	Name: string,
	Category: string,
	Rarity: Rarity,
	PriceRobux: number?,
	PriceCoins: number?,
	ProductId: number,
	Pool: string, -- "default" | "catalog" | "daily" | "pass" | "bundle"
	Visual: { [string]: any },
}

local C = Color3.fromRGB

-- Grupos de peça da arma: Body, Barrel, Stock, Scope, Mag, Accent
Config.Cosmetics = {
	-- ── wraps ─────────────────────────────────────────────
	wrap_factory = {
		Name = "Fábrica",
		Category = "Wrap",
		Rarity = "Common",
		ProductId = 0,
		Pool = "default",
		Visual = {
			Body = { C(46, 49, 54), "Metal" },
			Barrel = { C(32, 34, 38), "Metal" },
			Stock = { C(58, 54, 48), "SmoothPlastic" },
			Scope = { C(28, 30, 33), "Metal" },
			Mag = { C(40, 42, 46), "Metal" },
			Accent = { C(186, 150, 92), "Metal" },
		},
	},
	wrap_areia = {
		Name = "Areia",
		Category = "Wrap",
		Rarity = "Common",
		PriceRobux = 15,
		PriceCoins = 500,
		ProductId = 0,
		Pool = "catalog",
		Visual = {
			Body = { C(196, 172, 128), "SmoothPlastic" },
			Barrel = { C(52, 50, 46), "Metal" },
			Stock = { C(184, 160, 118), "SmoothPlastic" },
			Scope = { C(120, 104, 78), "Metal" },
			Mag = { C(164, 142, 104), "SmoothPlastic" },
			Accent = { C(60, 56, 50), "Metal" },
		},
	},
	wrap_grafite = {
		Name = "Grafite",
		Category = "Wrap",
		Rarity = "Common",
		PriceRobux = 15,
		PriceCoins = 500,
		ProductId = 0,
		Pool = "catalog",
		Visual = {
			Body = { C(70, 73, 79), "SmoothPlastic" },
			Barrel = { C(26, 27, 30), "Metal" },
			Stock = { C(54, 56, 61), "SmoothPlastic" },
			Scope = { C(36, 38, 42), "Metal" },
			Mag = { C(60, 62, 68), "SmoothPlastic" },
			Accent = { C(232, 96, 60), "SmoothPlastic" },
		},
	},
	wrap_oliva = {
		Name = "Oliva",
		Category = "Wrap",
		Rarity = "Common",
		PriceRobux = 15,
		PriceCoins = 500,
		ProductId = 0,
		Pool = "catalog",
		Visual = {
			Body = { C(92, 98, 66), "SmoothPlastic" },
			Barrel = { C(38, 40, 34), "Metal" },
			Stock = { C(84, 90, 60), "SmoothPlastic" },
			Scope = { C(52, 56, 42), "Metal" },
			Mag = { C(76, 80, 56), "SmoothPlastic" },
			Accent = { C(30, 30, 28), "Metal" },
		},
	},
	wrap_artico = {
		Name = "Ártico",
		Category = "Wrap",
		Rarity = "Common",
		PriceRobux = 15,
		PriceCoins = 500,
		ProductId = 0,
		Pool = "catalog",
		Visual = {
			Body = { C(226, 230, 234), "SmoothPlastic" },
			Barrel = { C(60, 64, 70), "Metal" },
			Stock = { C(210, 216, 222), "SmoothPlastic" },
			Scope = { C(170, 178, 186), "Metal" },
			Mag = { C(196, 202, 210), "SmoothPlastic" },
			Accent = { C(90, 170, 220), "SmoothPlastic" },
		},
	},
	wrap_floresta = {
		Name = "Floresta",
		Category = "Wrap",
		Rarity = "Uncommon",
		PriceRobux = 29,
		PriceCoins = 1000,
		ProductId = 0,
		Pool = "catalog",
		Visual = {
			Body = { C(84, 92, 58), "Fabric" },
			Barrel = { C(36, 38, 32), "Metal" },
			Stock = { C(78, 72, 50), "Fabric" },
			Scope = { C(60, 66, 44), "Metal" },
			Mag = { C(70, 64, 46), "Fabric" },
			Accent = { C(30, 30, 26), "Metal" },
			Texture = { Key = "camo_floresta", StudsPerTile = 1.4, Groups = { "Body", "Stock", "Mag" } },
		},
	},
	wrap_urbano = {
		Name = "Urbano",
		Category = "Wrap",
		Rarity = "Uncommon",
		PriceRobux = 29,
		PriceCoins = 1000,
		ProductId = 0,
		Pool = "catalog",
		Visual = {
			Body = { C(128, 132, 138), "Fabric" },
			Barrel = { C(34, 35, 38), "Metal" },
			Stock = { C(104, 108, 114), "Fabric" },
			Scope = { C(70, 72, 78), "Metal" },
			Mag = { C(92, 96, 102), "Fabric" },
			Accent = { C(20, 20, 22), "Metal" },
			Texture = { Key = "camo_urbano", StudsPerTile = 1.2, Groups = { "Body", "Stock", "Mag" } },
		},
	},
	wrap_deserto = {
		Name = "Deserto Digital",
		Category = "Wrap",
		Rarity = "Uncommon",
		PriceRobux = 29,
		PriceCoins = 1000,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Body = { C(198, 168, 120), "Fabric" },
			Barrel = { C(60, 52, 42), "Metal" },
			Stock = { C(176, 146, 102), "Fabric" },
			Scope = { C(140, 116, 82), "Metal" },
			Mag = { C(160, 132, 94), "Fabric" },
			Accent = { C(46, 40, 34), "Metal" },
			Texture = { Key = "camo_deserto", StudsPerTile = 1.0, Groups = { "Body", "Stock", "Mag" } },
		},
	},
	wrap_tundra = {
		Name = "Tundra",
		Category = "Wrap",
		Rarity = "Uncommon",
		PriceRobux = 29,
		PriceCoins = 1000,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Body = { C(206, 212, 216), "Fabric" },
			Barrel = { C(48, 52, 58), "Metal" },
			Stock = { C(176, 184, 190), "Fabric" },
			Scope = { C(120, 128, 136), "Metal" },
			Mag = { C(150, 158, 166), "Fabric" },
			Accent = { C(36, 40, 46), "Metal" },
			Texture = { Key = "camo_tundra", StudsPerTile = 1.3, Groups = { "Body", "Stock", "Mag" } },
		},
	},
	wrap_carbono = {
		Name = "Fibra de Carbono",
		Category = "Wrap",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Body = { C(30, 31, 34), "Fabric" },
			Barrel = { C(22, 22, 24), "Metal" },
			Stock = { C(30, 31, 34), "Fabric" },
			Scope = { C(24, 24, 26), "Metal" },
			Mag = { C(34, 35, 38), "Fabric" },
			Accent = { C(220, 48, 48), "Metal" },
			Texture = { Key = "wrap_carbono", StudsPerTile = 0.35, Groups = { "Body", "Stock", "Mag" } },
		},
	},
	wrap_hex = {
		Name = "Colmeia",
		Category = "Wrap",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Body = { C(36, 52, 62), "SmoothPlastic" },
			Barrel = { C(24, 26, 30), "Metal" },
			Stock = { C(30, 44, 54), "SmoothPlastic" },
			Scope = { C(26, 30, 34), "Metal" },
			Mag = { C(40, 58, 70), "SmoothPlastic" },
			Accent = { C(255, 196, 40), "Neon" },
			Texture = { Key = "wrap_hex", StudsPerTile = 0.8, Groups = { "Body", "Stock", "Mag" } },
		},
	},
	wrap_marmore = {
		Name = "Mármore Negro",
		Category = "Wrap",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Body = { C(34, 34, 38), "Marble" },
			Barrel = { C(196, 160, 90), "Metal" },
			Stock = { C(30, 30, 34), "Marble" },
			Scope = { C(196, 160, 90), "Metal" },
			Mag = { C(40, 40, 44), "Marble" },
			Accent = { C(230, 196, 120), "Metal" },
		},
	},
	wrap_pulso = {
		Name = "Pulso",
		Category = "Wrap",
		Rarity = "Epic",
		PriceRobux = 79,
		PriceCoins = 3000,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Body = { C(18, 20, 26), "SmoothPlastic" },
			Barrel = { C(14, 15, 18), "Metal" },
			Stock = { C(22, 24, 30), "SmoothPlastic" },
			Scope = { C(16, 18, 22), "Metal" },
			Mag = { C(20, 22, 28), "SmoothPlastic" },
			Accent = { C(0, 230, 255), "Neon" },
			Animated = { Kind = "Pulse", Colors = { C(0, 230, 255), C(120, 60, 255) }, Speed = 1.4 },
		},
	},
	wrap_magma = {
		Name = "Magma",
		Category = "Wrap",
		Rarity = "Epic",
		PriceRobux = 79,
		PriceCoins = 3000,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Body = { C(40, 30, 28), "CrackedLava" },
			Barrel = { C(26, 22, 20), "Metal" },
			Stock = { C(44, 32, 28), "CrackedLava" },
			Scope = { C(30, 24, 22), "Metal" },
			Mag = { C(48, 34, 30), "CrackedLava" },
			Accent = { C(255, 110, 30), "Neon" },
			Animated = { Kind = "Pulse", Colors = { C(255, 110, 30), C(255, 40, 20) }, Speed = 0.8 },
		},
	},
	wrap_estatica = {
		Name = "Estática",
		Category = "Wrap",
		Rarity = "Epic",
		PriceRobux = 79,
		PriceCoins = 3000,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Body = { C(120, 200, 255), "ForceField" },
			Barrel = { C(28, 30, 36), "Metal" },
			Stock = { C(120, 200, 255), "ForceField" },
			Scope = { C(30, 34, 40), "Metal" },
			Mag = { C(150, 220, 255), "ForceField" },
			Accent = { C(200, 240, 255), "Neon" },
			Underlay = C(22, 30, 44), -- peça sólida por baixo do ForceField
		},
	},
	wrap_aurora = {
		Name = "Aurora Austral",
		Category = "Wrap",
		Rarity = "Legendary",
		PriceRobux = 149,
		PriceCoins = 5000,
		ProductId = 0,
		Pool = "pass",
		Visual = {
			Body = { C(60, 255, 190), "ForceField" },
			Barrel = { C(20, 22, 30), "Metal" },
			Stock = { C(120, 120, 255), "ForceField" },
			Scope = { C(24, 26, 34), "Metal" },
			Mag = { C(200, 90, 255), "ForceField" },
			Accent = { C(60, 255, 190), "Neon" },
			Underlay = C(10, 16, 30),
			Animated = {
				Kind = "Cycle",
				Colors = { C(60, 255, 190), C(80, 140, 255), C(200, 90, 255), C(60, 255, 190) },
				Speed = 0.25,
			},
		},
	},

	-- ── charms ────────────────────────────────────────────
	charm_none = {
		Name = "Sem charm",
		Category = "Charm",
		Rarity = "Common",
		ProductId = 0,
		Pool = "default",
		Visual = { Kind = "None" },
	},
	charm_dado = {
		Name = "Dado da Sorte",
		Category = "Charm",
		Rarity = "Common",
		PriceRobux = 15,
		PriceCoins = 500,
		ProductId = 0,
		Pool = "catalog",
		Visual = { Kind = "Dice", Color = C(240, 240, 236), Pip = C(30, 30, 30) },
	},
	charm_cartucho = {
		Name = "Cartucho",
		Category = "Charm",
		Rarity = "Uncommon",
		PriceRobux = 29,
		PriceCoins = 1000,
		ProductId = 0,
		Pool = "pass",
		Visual = { Kind = "Bullet", Color = C(214, 170, 90) },
	},
	charm_placa = {
		Name = "Placa de Identificação",
		Category = "Charm",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = { Kind = "Tag", Color = C(190, 196, 204) },
	},
	charm_cubo = {
		Name = "Cubo Neon",
		Category = "Charm",
		Rarity = "Epic",
		PriceRobux = 79,
		PriceCoins = 3000,
		ProductId = 0,
		Pool = "daily",
		Visual = { Kind = "NeonCube", Color = C(255, 60, 160) },
	},

	-- ── facas ─────────────────────────────────────────────
	knife_padrao = {
		Name = "Faca de Campanha",
		Category = "Knife",
		Rarity = "Common",
		ProductId = 0,
		Pool = "default",
		Visual = { Blade = { C(176, 180, 186), "Metal" }, Handle = { C(34, 34, 36), "Rubber" }, Guard = { C(48, 48, 52), "Metal" } },
	},
	knife_carbono = {
		Name = "Carbono",
		Category = "Knife",
		Rarity = "Uncommon",
		PriceRobux = 29,
		PriceCoins = 1000,
		ProductId = 0,
		Pool = "daily",
		Visual = { Blade = { C(40, 40, 44), "Metal" }, Handle = { C(24, 24, 26), "Fabric" }, Guard = { C(210, 60, 50), "Metal" } },
	},
	knife_tanto = {
		Name = "Tanto Laqueado",
		Category = "Knife",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Shape = "Tanto",
			Blade = { C(220, 224, 230), "Foil" },
			Handle = { C(140, 24, 30), "SmoothPlastic" },
			Guard = { C(214, 170, 90), "Metal" },
		},
	},
	knife_neon = {
		Name = "Lâmina de Plasma",
		Category = "Knife",
		Rarity = "Epic",
		PriceRobux = 79,
		PriceCoins = 3000,
		ProductId = 0,
		Pool = "daily",
		Visual = {
			Blade = { C(0, 230, 255), "Neon" },
			Handle = { C(20, 22, 28), "SmoothPlastic" },
			Guard = { C(40, 44, 54), "Metal" },
			Glow = true,
		},
	},

	-- ── kill effects ──────────────────────────────────────
	fx_none = {
		Name = "Padrão",
		Category = "KillEffect",
		Rarity = "Common",
		ProductId = 0,
		Pool = "default",
		Visual = { Kind = "None" },
	},
	fx_faisca = {
		Name = "Faíscas",
		Category = "KillEffect",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = { Kind = "Sparks", Color = C(255, 200, 90) },
	},
	fx_papel = {
		Name = "Confete",
		Category = "KillEffect",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "pass",
		Visual = { Kind = "Confetti" },
	},
	fx_fumaca = {
		Name = "Cortina de Fumaça",
		Category = "KillEffect",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = { Kind = "Smoke", Color = C(70, 74, 82) },
	},
	fx_glitch = {
		Name = "Glitch",
		Category = "KillEffect",
		Rarity = "Epic",
		PriceRobux = 79,
		PriceCoins = 3000,
		ProductId = 0,
		Pool = "daily",
		Visual = { Kind = "Glitch", Color = C(0, 255, 200), Color2 = C(255, 0, 140) },
	},

	-- ── finalizações (kills de faca) ─────────────────────
	finisher_none = {
		Name = "Padrão",
		Category = "Finisher",
		Rarity = "Common",
		ProductId = 0,
		Pool = "default",
		Visual = { Kind = "None" },
	},
	finisher_corte = {
		Name = "Corte Lunar",
		Category = "Finisher",
		Rarity = "Epic",
		PriceRobux = 79,
		PriceCoins = 3000,
		ProductId = 0,
		Pool = "pass",
		Visual = { Kind = "Crescent", Color = C(200, 220, 255) },
	},

	-- ── retículos ─────────────────────────────────────────
	ret_padrao = {
		Name = "Ponto Branco",
		Category = "Reticle",
		Rarity = "Common",
		ProductId = 0,
		Pool = "default",
		Visual = { Color = C(255, 255, 255), Shape = "Dot" },
	},
	ret_ciano = {
		Name = "Ponto Ciano",
		Category = "Reticle",
		Rarity = "Common",
		PriceRobux = 15,
		PriceCoins = 500,
		ProductId = 0,
		Pool = "catalog",
		Visual = { Color = C(0, 235, 255), Shape = "Dot" },
	},
	ret_magenta = {
		Name = "Ponto Magenta",
		Category = "Reticle",
		Rarity = "Common",
		PriceRobux = 15,
		PriceCoins = 500,
		ProductId = 0,
		Pool = "catalog",
		Visual = { Color = C(255, 60, 170), Shape = "Dot" },
	},
	ret_cruz = {
		Name = "Cruz Fina",
		Category = "Reticle",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = { Color = C(120, 255, 140), Shape = "Cross" },
	},

	-- ── tracers ───────────────────────────────────────────
	tracer_padrao = {
		Name = "Padrão",
		Category = "Tracer",
		Rarity = "Common",
		ProductId = 0,
		Pool = "default",
		Visual = { Color = C(255, 236, 200), Width = 0.06 },
	},
	tracer_ouro = {
		Name = "Ouro",
		Category = "Tracer",
		Rarity = "Common",
		PriceRobux = 15,
		PriceCoins = 500,
		ProductId = 0,
		Pool = "catalog",
		Visual = { Color = C(255, 196, 60), Width = 0.07 },
	},
	tracer_plasma = {
		Name = "Plasma",
		Category = "Tracer",
		Rarity = "Rare",
		PriceRobux = 49,
		PriceCoins = 1800,
		ProductId = 0,
		Pool = "daily",
		Visual = { Color = C(120, 90, 255), Width = 0.09, Glow = true },
	},
} :: { [string]: CosmeticDef }

Config.DefaultEquipped = {
	Wrap = "wrap_factory",
	Charm = "charm_none",
	Knife = "knife_padrao",
	KillEffect = "fx_none",
	Finisher = "finisher_none",
	Reticle = "ret_padrao",
	Tracer = "tracer_padrao",
}

Config.DailyShop = {
	Slots = 6,
	Salt = 4747,
	-- A loja vira à meia-noite UTC.
}

-- ─────────────────────────────────────────────────────────────── passe
Config.Pass = {
	Season = 1,
	Name = "Passe — Temporada 1",
	Tiers = 30,
	XpPerTier = 1000,
	PrimeName = "Passe Prime — Temporada 1",
	PrimePriceRobux = 199,
	PrimeProductId = 0,
	-- Recompensas FIXAS por tier. Tiers sem item na faixa grátis dão moedas.
	FreeCoinsPerTier = 300,
	Free = {
		[5] = "wrap_oliva",
		[10] = "charm_cartucho",
		[15] = "wrap_tundra",
		[20] = "fx_papel",
		[25] = "ret_cruz",
		[30] = "wrap_floresta",
	} :: { [number]: string },
	PrimeCoinsPerTier = 150,
	Prime = {
		[1] = "wrap_carbono",
		[4] = "tracer_plasma",
		[8] = "charm_placa",
		[12] = "knife_carbono",
		[16] = "wrap_hex",
		[20] = "fx_faisca",
		[25] = "finisher_corte",
		[28] = "knife_tanto",
		[30] = "wrap_aurora",
	} :: { [number]: string },
}

Config.StarterPack = {
	Name = "Pacote Iniciante",
	PriceRobux = 49,
	ProductId = 0,
	Items = { "wrap_floresta", "wrap_urbano", "charm_dado" },
	BonusCoins = 0,
}

-- ─────────────────────────────────────────────────────────────── desafios diários
Config.DailyChallenges = {
	Count = 3,
	Pool = {
		{ Id = "noscope5", Text = "Faça 5 kills no-scope", Stat = "NoScopes", Goal = 5, Coins = 600 },
		{ Id = "hs8", Text = "Acerte 8 headshots", Stat = "Headshots", Goal = 8, Coins = 600 },
		{ Id = "knife3", Text = "Elimine 3 com a faca", Stat = "Knives", Goal = 3, Coins = 700 },
		{ Id = "long3", Text = "3 kills de longa distância", Stat = "LongShots", Goal = 3, Coins = 650 },
		{ Id = "win2", Text = "Vença 2 partidas", Stat = "Wins", Goal = 2, Coins = 800 },
		{ Id = "kills15", Text = "Faça 15 kills", Stat = "Kills", Goal = 15, Coins = 500 },
		{ Id = "air2", Text = "2 kills aéreas", Stat = "Aerials", Goal = 2, Coins = 750 },
	},
}

-- ─────────────────────────────────────────────────────────────── áudio
-- Chaves → ids. Vazio = usa o fallback local (rbxasset) ou fica mudo.
-- `tools/assets/upload.mjs` sobe os .wav de assets/audio e gera src/shared/AssetIds.luau.
Config.Audio = {
	SniperShot = { Volume = 0.9, Fallback = "rbxasset://sounds/impact_explosion_03.mp3", FallbackPitch = 2.1 },
	SniperShotDistant = { Volume = 0.55, Fallback = "rbxasset://sounds/impact_explosion_03.mp3", FallbackPitch = 1.7 },
	BoltCycle = { Volume = 0.6 },
	Reload = { Volume = 0.6 },
	DryFire = { Volume = 0.5, Fallback = "rbxasset://sounds/volume_slider.ogg", FallbackPitch = 0.6 },
	ScopeIn = { Volume = 0.35 },
	KnifeSwing = { Volume = 0.55 },
	KnifeHit = { Volume = 0.7, Fallback = "rbxasset://sounds/action_jump_land.mp3", FallbackPitch = 1.4 },
	HitBody = { Volume = 0.7, Fallback = "rbxasset://sounds/volume_slider.ogg", FallbackPitch = 1.2 },
	HitHead = { Volume = 0.9, Fallback = "rbxasset://sounds/volume_slider.ogg", FallbackPitch = 1.9 },
	KillConfirm = { Volume = 0.8, Fallback = "rbxasset://sounds/volume_slider.ogg", FallbackPitch = 0.8 },
	BulletWhiz = { Volume = 0.6 },
	ImpactConcrete = { Volume = 0.6, Fallback = "rbxasset://sounds/action_jump_land.mp3", FallbackPitch = 1.8 },
	ImpactMetal = { Volume = 0.6, Fallback = "rbxasset://sounds/action_jump_land.mp3", FallbackPitch = 2.4 },
	UiClick = { Volume = 0.45, Fallback = "rbxasset://sounds/volume_slider.ogg", FallbackPitch = 1 },
	UiBuy = { Volume = 0.6 },
	RoundStart = { Volume = 0.6 },
	RoundWin = { Volume = 0.7 },
	Countdown = { Volume = 0.5, Fallback = "rbxasset://sounds/volume_slider.ogg", FallbackPitch = 1.5 },
	AmbientHarbor = { Volume = 0.35, Fallback = "rbxasset://sounds/impact_water.mp3", FallbackPitch = 0.5 },
	AmbientCity = { Volume = 0.3 },
	AmbientMountain = { Volume = 0.3 },
	Footstep = { Volume = 0.4, Fallback = "rbxasset://sounds/action_footsteps_plastic.mp3", FallbackPitch = 1 },
}

-- ─────────────────────────────────────────────────────────────── UI
Config.UI = {
	KillFeedMax = 5,
	KillFeedLifetime = 6,
	ToastLifetime = 2.6,
	DamageNumberLifetime = 0.9,
}

return Config
