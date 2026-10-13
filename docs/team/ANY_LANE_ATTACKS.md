# Attacking any lane, Mini War style (October 13, 2026)

Owner decisions, made the same day in two steps. The second step ("copy Mini War as closely as possible") replaced the first draft's 1 → 2 → 3 order. Supersedes the "own lane only" and "saved wins never bypass a restored garrison" rules in older notes. Mini War details come from fan guides (allthings.how, techwiser), not the developer.

## Rules

- **Targets.** Any camp on any lane that currently has a commander: your own or another player's. Home plots stay safe. Open plots have no garrison and are not listed.
- **Order.** None. Any camp can be attacked directly. The one exception is the tutorial: until a commander has beaten any camp (or the King), only their own Cluck Camp can be attacked ("Take your Cluck Camp first").
- **Holding pays.** While your flag stands, a territory adds egg value to newly produced eggs: Camp 1 +5%, Camp 2 +15%, Camp 3 +20%, the King +25% (Mini War: Camp, Garrison, Military Base, City). Bonuses stack. The bonus is live only: it is never saved and never part of offline earnings, because holdings end when the player leaves.
- **Contested.** While another army is fighting or capturing on a territory you hold, that territory pays half (`ContestedShare`). Marching toward it does not count.
- **Hold limit.** 8 territories at once (camps and the King; the Hill does not count). Research raises it: Flag Bearers (H1, after Rapid Occupation, $5M, 2h) to 9 and Banner Legion (H2, $50M, 8h) to 10. At the limit, new captures are refused with "Unclaim one to take another". If a route leg reaches the limit mid-march, the camp counts as beaten but no flag is planted.
- **Another commander's camps.** Winning one puts your flag and portrait on it; the owner beats it to take it back.
- **Sending.** Orders work from home, mid-march, mid-fight, while holding, and while walking home after a win, recall or retreat (the army turns around where it stands). After a loss it recovers first.
- **King.** Opens once all three camps of any single lane are beaten, in any order (not a mix of lanes). An earlier King clear or a full home lane keeps it open. Until then a King order marches through your own unbeaten home camps first, and a King order given mid-fight at that first camp keeps the fight and then moves on.
- **Rewards.** First-win rewards, rank unlocks, the tutorial and the first-win funnel are own-lane only. Other lanes pay normal kill cash plus the hold bonus. Another lane's garrison uses its owner's rank.
- **Names.** Another commander's camps read "Stev's Cluck Camp" in prompts and messages. Prompts show what a camp pays ("· +15% eggs"); the HUD counter reads "Held 3/8 · +40% eggs".
- **Leaving.** When a lane's commander leaves, armies attacking that lane march home, every flag on it clears and saved records stay.

Not copied: Mini War's factories, civilians and market (they would replace the egg and roll loop). Its 30-minute raid events already exist here as the Hill.

## Target ids

`camp:N` is the commander's own lane (the tutorial relies on it). `camp:P:N` is camp N on plot P's lane. `CampaignRoute.Camp` parses both and `CampaignRoute.CampId` builds them. The client turns a camp model's `camp:N` into `camp:P:N` using `LaneOwnerIndex` on the camp or its lane folder. `WorldService:CanCommand` checks proximity to that lane's camp.

## Saved data

New additive field `laneCamps = {[laneOwnerUserId string] = bitmask}` (bit i-1 = camp i beaten). Loading never rejects a profile for it: malformed entries are dropped and at most 100 lanes are kept (the most beaten). The same day's first draft saved `laneWins` (highest camp, in order); it loads as camps 1..N.

Load fix: before this change a mid-march redirect could win Camp 2 or 3 before Camp 1, and a gap in `firstWins` made the profile fail to load. Revision 6+ `firstWins` now load sparse; free order makes gaps normal.

## Code

- `shared/Config.luau`: `Territories` (bonuses, contested share, limit).
- `shared/CampaignRoute.luau`: `Camp`, `CampId`, `Plan(target, ownCleared, outposts, {lanes, kingOpen})`.
- `server/BattleService.luau`: `CampTarget`, `LaneOwner`, `LaneCleared`, `KingOpen`, `RecordLaneWin`, `Started`, `HoldCount`, `HoldLimit`, `HoldBonus`, `RefreshTerritoryBonus` (every step), `CanTurnAround`, `TargetName`. `battle.plotIndex` is the lane being attacked.
- `server/PlayerSession.luau`: `laneCamps` save/load, live `territoryBonus`, shown income includes it.
- `server/EggService.luau`: live egg value multiplied by `1 + territoryBonus`.
- `shared/ResearchCatalog.luau` / `ResearchRules.luau`: H1, H2, effect `holdCap`.
- `client/BaseController.luau`, `client/HudController.luau`, `client/CashUpgradeNodes.luau` (H1 at 4,5; H2 at 3,6).

## Verification

`tests/LaneConquestChecks.luau` (11 checks) passed in Studio edit mode against fresh module clones: direct orders on any lane, the Cluck Camp-first gate, per-lane saves with no first win, owner retake, King per lane in any order, stacking and contested bonuses, the hold limit and research raise, turn-around and the post-loss block, the King keep-fight-then-onward order, lane closing on leave, and save/load (junk, 100-lane cap, draft field, old gap). Ordered, retargeting, research, territory, arrival, persistence and rules suites match their pre-change baselines (their remaining failures are stale outpost, Hill, "already hold" and Operation fixtures). A live playtest was not possible: Studio's playtest start returned "Unknown error".
