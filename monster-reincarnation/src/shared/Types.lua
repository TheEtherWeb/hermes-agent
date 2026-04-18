--!strict
-- Shared Luau type aliases. Imported by services to keep signatures honest.

export type StanceName = "TwoHand" | "OneHand" | "DualWield" | "SpellGrip"

export type Stats = {
	Health: number,
	Stamina: number,
	Mana: number,
	Strength: number,
	Dexterity: number,
	Vitality: number,
	Intellect: number,
	Instinct: number,
	Presence: number,
}

export type HiddenStats = {
	AmbushesSurvived: number,
	PoisonsConsumed: number,
	DarknessAdapted: number,
	SpellsCast: number,
	CorpsesEaten: number,
	BeastsBonded: number,
	AmbushLanded: number,
	TrapsBuilt: number,
}

export type WeaponPersona = {
	level: number,
	xp: number,
	awakenedBranch: string?,  -- e.g. "Guardian", "Berserker", "Spiderkiss"
	titles: { string },
}

export type ChronicleEntry = {
	ts: number,
	kind: string,            -- "kill" | "dungeon" | "transfer" | "fusion" | "rename" | "inherit"
	text: string,
	playerUserId: number?,   -- owner at the time
	generation: number?,
}

export type Weapon = {
	id: string,              -- UUID
	templateId: string,      -- resolved recipe name
	components: { [string]: string }, -- blade/hilt/guard/pommel/runes -> material ids
	baseStats: { [string]: number },
	quality: string,         -- "poor"|"fair"|"good"|"fine"|"excellent"
	persona: WeaponPersona,
	chronicle: { ChronicleEntry },
	ownerUserId: number?,
	bondedBloodline: string?,
}

export type InventoryItem = {
	id: string,
	kind: "material" | "weapon" | "consumable" | "token" | "decor",
	templateId: string,
	qty: number,
	data: { [string]: any }?,
}

export type Contract = {
	id: string,
	demonUserId: number,
	hostUserId: number,
	offer: { kind: string, value: any },
	demand: { kind: string, value: any },
	expiresAt: number,
	penaltyKind: string,
	state: "pending" | "active" | "fulfilled" | "breached" | "expired",
}

export type Profile = {
	userId: number,
	bloodlineId: string,
	generation: number,
	race: string,
	origin: string,
	familyName: string,
	level: number,
	xp: number,
	stats: Stats,
	hidden: HiddenStats,
	stanceMastery: { [string]: number },
	inventory: { InventoryItem },
	equippedWeaponId: string?,
	gold: number,
	guildId: string?,
	guildRank: number,
	factions: { [string]: number },
	corruption: number,
	dungeonId: string?,
	followers: { string },
	heirlooms: { string },
	createdAt: number,
	updatedAt: number,
}

export type Guild = {
	id: string,
	name: string,
	tag: string,
	leaderUserId: number,
	officers: { number },
	members: { [number]: { rank: number, joinedAt: number } },
	score: number,
	baseLocationId: string?,
	createdAt: number,
}

export type MarketListing = {
	id: string,
	sellerUserId: number,
	item: InventoryItem,
	price: number,
	listedAt: number,
	expiresAt: number,
}

return {}
