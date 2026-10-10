# King of the Hill — October 10, 2026

User request: players' armies occupy a place other players can fight for, a cash
boost that grows the longer you hold it, a timer about every five minutes, and a
goal. Modeled on Mini War (shared map, held ground pays a money bonus, attackers
fight the holder's troops instead of NPCs). The user chose: the King's arena is the
Hill, 5-minute rounds with 5-minute breaks, a Hill Roll per round won and a Hill
Champion chicken at 10 wins, rendered as a crowned gold copy of the classic Chicken.

## How it plays

- **Clock** (`Config.Hill`): the first round opens 2 minutes after a server starts,
  then 5 minutes of Hill and 5 minutes of break repeat. A round waits to open
  until any King fight in the arena has finished. New King fights are refused for
  the last 45 seconds of a break and during a round ("The Hill opens in 0:40").
- **Hill Guards:** an empty Hill is held by Ironbeak HQ-strength NPCs
  (`IncomeOutpost.NeutralRoster`). There's no unlock, so army strength is the gate.
- **Holding:** a capture makes you the holder. Rivals who attack fight your chickens.
  NPC raiders (`RaidRoster`) test a holder about 2.5 minutes in. Captures
  get 30 seconds of protection. A failed attacker waits 60 seconds.
- **Boost:** the holder earns, as cash every tick, what their chickens on the Hill
  would lay at home, plus **+10% per minute held, up to +50%** of the whole farm's
  income (all owned chickens). Double Cash applies through the normal `territory`
  credit source. The boost resets when the Hill changes hands and pauses during a
  contest.
- **Winning:** when the round ends, the player who held the Hill the most seconds
  (at least 15) wins. They get `hillWins + 1` and one **Hill Roll**, a free
  chicken drawn from the normal roll odds with +2.0 extra Luck strength
  (`RollLuckBonus`). Its investment is 0, so selling it refunds nothing.
- **Hill Champion:** at 10 total wins the player receives the Hill Champion once
  (Mythic, weight 0, Galaxy Overlord stats with Dark Matter's 101 damage). A full
  flock keeps rolls and the Champion owed (`hillRollCredits`) until there's room.
- **Close:** live contests resolve as cancelled, every Hill army marches home and
  the flag clears. The King returns once those armies have left the arena.

## Code

| Piece | Where |
| --- | --- |
| Clock, boost, winner, rewards, per-player HUD snapshot | `src/server/HillService.luau` |
| Fights, raids, holder, payout hook, King lock, open/close | `BattleService` (`HillRate`, `HillKingLock`, `OpenHill`, `CloseHill`; the existing `income:1` contest) |
| Payout slice with a per-tick rate | `TerritoryIncome.Step(session, dt, rateOverride)` |
| Arena presentation: Hill Guards, flag text, timer sign, prompt target swap | `KingArena:SetHillMode`, `KingArena:SetHillStatus` |
| `income:1` world calls routed to the arena | `WorldService` (`IncomeFrame`, `CanCommand`, `SetIncomeBusy`, `SetTerritoryOwner`, `SetHillMode`, `SetHillStatus`) |
| Saved fields | `PlayerSession`: `hillWins`, `hillRollCredits`, `hillChampion` (additive; missing = 0/false) |
| Chicken | `PetCatalog.HillChampion` (`hillExclusive`), `ChickenAppearanceAssets.HillChampion`, Studio model `ReplicatedStorage.PetRoll.ChickenAssets.HillChampion` |
| HUD | `HudController:UpdateTerritory` ("Holding the Hill · +30% farm · 2:41"); prompt hint in `BaseController:CommandFor` |
| Index | "Win the Hill 10 times" caption in `IndexBrowser` |
| Telemetry | `HillRoundWon` loop event (userId, seconds, wins, round) |
| Checks | `tests/HillChecks.luau`; `IncomeTerritoryChecks` disables the Hill clock to test the contest engine alone |

The Champion model is Studio-owned: the Duck mesh with its SurfaceAppearance tinted
gold (255,196,48), a 5-part gold crown placed on `Original_HatSocket`, and the
Golden Emperor's sparkle attachment. It has no captured portrait, so menus use the
live model preview (`ChickenPreview`).
