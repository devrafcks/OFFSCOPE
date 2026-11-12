--!strict
-- Tipos compartilhados entre cliente e servidor.

export type WeaponSlot = "Sniper" | "Knife"
export type Zone = "Head" | "Chest" | "Stomach" | "Limb"
export type Team = "A" | "B" | "FFA"

export type Equipped = {
	Wrap: string,
	Charm: string,
	Knife: string,
	KillEffect: string,
	Finisher: string,
	Reticle: string,
	Tracer: string,
}

export type PlayerSettings = {
	Sensitivity: number,
	AdsSensitivity: number,
	Fov: number,
	PerformanceMode: boolean,
	ShowFps: boolean,
}

export type Stats = {
	Kills: number,
	Deaths: number,
	Headshots: number,
	NoScopes: number,
	Quickscopes: number,
	LongShots: number,
	Aerials: number,
	Knives: number,
	Wins: number,
	Losses: number,
	Matches: number,
	LongestShot: number,
}

export type ProfileData = {
	Coins: number,
	Xp: number,
	Level: number,
	Elo: number,
	PeakElo: number,
	EloMatches: number,
	SeasonId: number,
	Stats: Stats,
	Inventory: { [string]: boolean },
	Equipped: Equipped,
	Pass: {
		Season: number,
		Xp: number,
		Prime: boolean,
		ClaimedFree: { [string]: boolean },
		ClaimedPrime: { [string]: boolean },
	},
	Daily: {
		Day: number,
		Ids: { string },
		Base: { [string]: number },
		Claimed: { [string]: boolean },
	},
	Settings: PlayerSettings,
	PurchaseIdCache: { string },
	StarterPackOwned: boolean,
	FirstJoin: number,
}

export type ShotTags = { string }

export type HitResult = {
	Target: Model,
	Part: BasePart,
	Zone: Zone,
	Position: Vector3,
	Distance: number,
}

export type KillInfo = {
	Killer: Player?,
	Victim: Player?,
	VictimModel: Model,
	Weapon: WeaponSlot,
	Tags: ShotTags,
	Distance: number,
	Origin: Vector3,
	HitPosition: Vector3,
}

return nil
