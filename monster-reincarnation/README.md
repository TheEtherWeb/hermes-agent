# Monster Reincarnation

A Roblox RPG where players start as weak monsters and evolve into rulers or calamities. Inspired by Deepwoken, Type Soul, Arcane Odyssey, and isekai fantasy.

## Project layout

This project is Rojo-compatible. Sync with `rojo serve` and open the resulting place in Roblox Studio.

```
default.project.json           Rojo project manifest
src/
  shared/                      ReplicatedStorage modules (data, types, remotes, util)
  server/                      ServerScriptService entry + Services/
  client/                      StarterPlayerScripts entry + UI/ + Controllers/
```

## Systems implemented

Every system from the design specification has a corresponding module:

| Design system              | Module                                            |
|----------------------------|---------------------------------------------------|
| Switch-grip combat         | `Services/CombatService.lua`, `Controllers/CombatController.lua` |
| Weapon persona             | `Services/WeaponPersonaService.lua`               |
| Weapon chronicle           | `Services/WeaponChronicleService.lua`             |
| Crafting / blacksmith      | `Services/CraftingService.lua`, `shared/WeaponComponents.lua` |
| Races / origins / families | `shared/Races.lua`, `Services/DataService.lua`    |
| Evolution trees            | `shared/EvolutionTrees.lua`, `Services/EvolutionService.lua` |
| Dynasty & inheritance      | `Services/DynastyService.lua`                     |
| Mentor / teaching          | `Services/MentorService.lua`                      |
| Guilds & ranks             | `Services/GuildService.lua`, `shared/RankData.lua`|
| Dungeons / world zones     | `Services/DungeonService.lua`, `shared/DungeonData.lua` |
| Lair building              | `Services/LairService.lua`, `shared/RoomData.lua` |
| Follower AI                | `Services/FollowerService.lua`, `shared/FollowerRoles.lua` |
| Demon contracts            | `Services/DemonContractService.lua`               |
| Factions / diplomacy       | `Services/FactionService.lua`, `shared/FactionData.lua` |
| Economy / marketplace      | `Services/EconomyService.lua`                     |
| Dungeon tower              | `Services/TowerService.lua`                       |
| Anti-exploit / persistence | `Services/AntiExploitService.lua`, `Services/DataService.lua` |
| Analytics                  | `Services/AnalyticsService.lua`                   |
| UI layering                | `client/UI/*.lua`                                 |

## Build & run

1. Install [Rojo](https://rojo.space/) 7.x.
2. `rojo build -o MonsterReincarnation.rbxlx` or `rojo serve` and connect Studio.
3. Publish to Roblox, enable HTTPService & Studio API access for DataStore writes.

## Monetization

Cosmetic-only. No power for purchase. See `Services/MonetizationService.lua`.
