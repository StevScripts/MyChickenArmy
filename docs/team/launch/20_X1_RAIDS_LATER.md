# X1 yard raids: not tonight

**Plan:** [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §10.

Raids are the change most likely to transform the game, and the one most likely to go wrong if rushed. They are left out of tonight's sprint on purpose.

## Why not tonight

- **They need tuning with real players.** The steal share (20%), cooldowns, shield lengths and new-player protection all decide whether raids feel exciting or cruel. No test file can answer that. It takes playtests with several real accounts in one server.
- **They touch the most shared code.** BattleService, EggService, PlayerSession, ProductService, the HUD and plot prompts. Running them beside four other workers would freeze half the codebase.
- **Your players are young.** Losing things to other players is the core of the steal genre, but a badly tuned version will make kids quit, not come back.
- **Rebirth and the streak should land first,** so you can measure what raids add on top.

## How to run it next week

1. **Design session (1 chat, about 1 hour).** Start from the plan §10 and answer the open questions with the owner: the share, cooldowns, free and paid shield lengths and prices, whether revenge ignores shields, and what new-player protection looks like. Output: `docs/team/RAIDS.md` with final numbers and a file ownership split.
2. **Foundation (lead).** The same pattern as tonight: shared hooks in `BattleService` (target kind `yard:P`), `EggService:Steal`, `PlayerSession` shield fields and `ProductService` delivery, all with neutral stubs, committed first.
3. **Workers in parallel.** `RaidService.luau` (rules, loot, shields); raid battle and loot meter; client prompts, alerts, the revenge button and the shield bubble; shield products and the shop.
4. **Multi-account playtest.** Two or three real accounts in one live private server before any public release.
5. **Release behind a switch.** `Config.Raids.Enabled`, turned on for a weekend, watching `raid.*` analytics and session length for players who got raided.
6. **Free private servers on** before raids go live, so players who don't want PvP have a place to farm.

Version 2 (capturing a reserve chicken) waits until version 1's data looks healthy.
