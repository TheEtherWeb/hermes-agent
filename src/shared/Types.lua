-- Monster Reincarnation – Shared Type Definitions (Luau)
-- All tables are documented here for cross-module clarity.

export type StatBlock = {
    Health    : number,
    Stamina   : number,
    Mana      : number,
    Strength  : number,
    Dexterity : number,
    Vitality  : number,
    Intellect : number,
    Instinct  : number,
    Presence  : number,
}

export type HiddenStats = {
    PoisonDmgDealt     : number,
    DarknessMinutes    : number,
    AmbushesSurvived   : number,
    CorpsesConsumed    : number,
    BoneKills          : number,
    SilkTraversals     : number,
    AcidStat           : number,
    SpellCasts         : number,
    HumanInvasions     : number,
    ManaAbsorbed       : number,
    AmbushesDone       : number,
    TrapsCrafted       : number,
    BeastsBonded       : number,
    SoldiersLed        : number,
    TerritoryConquered : number,
    ChiefsAsLt         : number,
}

export type PlayerProfile = {
    UserId         : number,
    DisplayName    : string,
    -- Base
    Race           : string,
    Origin         : string,
    FamilyId       : string,
    Evolution      : string,          -- current evolution node
    PowerLevel     : number,          -- sum of stats
    Stats          : StatBlock,
    HiddenStats    : HiddenStats,
    -- Resources
    Gold           : number,
    Inventory      : {[string]: number},   -- itemId → quantity
    Equipment      : {[string]: string},   -- slot → weaponId
    -- Progression
    GripMasteries  : {[string]: number},   -- gripType → XP
    SkillsUnlocked : {[string]: boolean},
    -- Social
    GuildId        : string?,
    GuildRank      : number,
    FactionRep     : {[string]: number},  -- factionId → rep value
    DynastyId      : string,
    Generation     : number,
    -- Flags
    IsDemon        : boolean,
    SoulCorruption : number,
    ActiveContract : string?,     -- contractId
    MentorId       : string?,
    MenteeIds      : {string},
    -- Meta
    PlayTime       : number,
    LastSaved      : number,
    DataVersion    : number,
}

export type WeaponRecord = {
    WeaponId       : string,
    Name           : string,
    BaseDamage     : number,
    BaseSpeed      : number,
    WeaponType     : string,   -- Sword, Dagger, Spear, etc.
    AllowedGrips   : {string},
    -- Components
    BladeId        : string,
    HiltId         : string,
    GuardId        : string,
    PommelId       : string,
    Runes          : {string},
    -- Persona
    PersonaLevel   : number,
    PersonaXP      : number,
    PersonaType    : string?,   -- Guardian, Berserker, etc.
    PersonaName    : string?,
    Affinities     : {[string]: number},
    -- Chronicle
    OriginalCrafter: number,   -- UserId
    OwnerHistory   : {number},
    Chronicle      : {ChronicleEntry},
    -- Meta
    CreatedAt      : number,
    TransferCount  : number,
}

export type ChronicleEntry = {
    Timestamp   : number,
    EventType   : string,   -- "Kill", "Craft", "Transfer", "Awaken", "Inherit"
    Description : string,
    ActorId     : number?,
}

export type GuildRecord = {
    GuildId      : string,
    Name         : string,
    Tag          : string,
    LeaderId     : number,
    Members      : {[number]: number},  -- UserId → GuildRank
    Score        : number,
    AllTimeScore : number,
    ScoreResetAt : number,
    BaseLocation : Vector3?,
    BaseRooms    : {DungeonRoom},
    AllyIds      : {string},
    EnemyIds     : {string},
    CreatedAt    : number,
    Motd         : string,
}

export type DungeonRoom = {
    RoomType  : string,
    SlotX     : number,
    SlotY     : number,
    SlotZ     : number,
    Level     : number,
    OwnerId   : string,   -- guildId or userId
}

export type ContractRecord = {
    ContractId  : string,
    DemonId     : number,
    HumanId     : number,
    Offer       : string,
    Demand      : string,
    ExpiresAt   : number,
    IsActive    : boolean,
    Progress    : {[string]: number},
}

export type DynastyRecord = {
    DynastyId   : string,
    Name        : string,
    Crest       : string,
    Generations : number,
    Score       : number,
    MemberIds   : {number},   -- active UserId per gen
    Heirlooms   : {string},   -- weaponIds
    Renown      : number,
}

export type FollowerRecord = {
    FollowerId  : string,
    Name        : string,
    SpeciesType : string,
    Role        : string,     -- Guard, Worker, Farmer, Crafter, Priest, Lieutenant
    Level       : number,
    XP          : number,
    Stats       : StatBlock,
    OwnerId     : number,
    DungeonId   : string,
    PatrolPath  : {Vector3}?,
}

export type AuctionListing = {
    ListingId   : string,
    SellerId    : number,
    ItemId      : string,
    ItemType    : string,   -- "weapon" | "material" | "cosmetic"
    Price       : number,
    Fee         : number,
    ListedAt    : number,
    ExpiresAt   : number,
    IsSold      : boolean,
    BuyerId     : number?,
}

export type TowerRun = {
    RunId       : string,
    GuildId     : string?,
    Players     : {number},
    CurrentFloor: number,
    HighestFloor: number,
    StartedAt   : number,
    CompletedAt : number?,
    Rewards     : {[string]: number},
}

return {}
