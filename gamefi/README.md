# GameFi Skeleton

Medium-size interface-first skeleton for an idle RPG + season quest + arena leaderboard game.

Scope of this phase:
- interfaces only
- events only
- data structs/enums only
- no business logic implementation

Standardization baseline:
- shared conventions: `CONVENTIONS.md`
- shared common structs: `CommonTypes.sol`
- unified user address naming: `player`

Level 3 baseline:
- per-module custom error library: `*Errors.sol`
- per-module storage key namespace library: `*StorageKeys.sol`

Modules:
- player
- hero
- item
- inventory
- quest
- battle
- season
- leaderboard
- guild
- economy
- matchmaking
- reward
