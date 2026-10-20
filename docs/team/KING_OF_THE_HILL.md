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
  during a round only (October 14: `KingLockSeconds=0`, the 45-second pre-round lock is removed; the Hill and King share one arena, so the round itself still locks it). The refusal names the wait ("The Hill fight is using the arena — the King opens in 2:10").
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
| Arena presentation: Hill Guards, flag text, prompt target swap | `KingArena:SetHillMode` |
| `income:1` world calls routed to the arena | `WorldService` (`IncomeFrame`, `CanCommand`, `SetIncomeBusy`, `SetTerritoryOwner`, `SetHillMode`) |
| Saved fields | `PlayerSession`: `hillWins`, `hillRollCredits`, `hillChampion` (additive; missing = 0/false) |
| Chicken | `PetCatalog.HillChampion` (`hillExclusive`), `ChickenAppearanceAssets.HillChampion`, Studio model `ReplicatedStorage.PetRoll.ChickenAssets.HillChampion` |
| HUD | `src/client/HillHud.luau` (see below), driven from `HudController:UpdateTerritory`; prompt hint in `BaseController:CommandFor` |
| Index | "Win the Hill 10 times" caption in `IndexBrowser` |
| Telemetry | `HillRoundWon` loop event (userId, seconds, wins, round) |
| Checks | `tests/HillChecks.luau`; `IncomeTerritoryChecks` disables the Hill clock to test the contest engine alone |

The Champion model is Studio-owned: the Duck mesh with its SurfaceAppearance tinted
gold (255,196,48), a 5-part gold crown placed on `Original_HatSocket`, and the
Golden Emperor's sparkle attachment. It has no captured portrait, so menus use the
live model preview (`ChickenPreview`).

## HUD (October 10, Mini War event pattern)

The user rejected a world sign over the arena and pointed at Mini War's event UI
(a big outlined boss title with a wide percentage bar top-center, a warm world
tint, and a small icon plus countdown at bottom-left). `HillHud` follows it with
the game's own `Theme.Display` lettering and `Theme.SegmentedBar`:

- **During a round (top-center, no panel):** the "slim boss bar" the user picked
  from three in-game mockups (A slim bar, B studded plate, C scoreboard): an
  outlined title, a square studded meter on the kit's slate conquest track that
  drains over the round with the clock inside it, and one short line under it. The title and bar
  follow the player's situation: KING OF THE HILL / MARCHING TO THE HILL (gold),
  CAPTURING THE HILL (red), YOU HOLD THE HILL (Army green, "+30% farm income · You
  lead 1:12"), HILL UNDER ATTACK! (red). A subtle warm `ColorCorrectionEffect`
  (`Lighting.PetRollHillTint`) fades in for the round.
- **Between rounds (bottom-left):** a helmet icon chip "Hill in 3:12" just above
  the cash readout.
- **Who sees it:** players who have won all home camps or cleared the King, or who
  took part in a round or have won one. It hides under menus and dialogue.
- **Top-slot rules while the title shows:** the Commander's quiet next-goal line
  waits (lessons still show), the army status line hides, and toasts drop from 24%
  to 30% screen height.
- Studio playtest verified: chip, idle, marching, capturing and holding states,
  status/toast clearance, and a full round with the winner's Hill Roll.

## First-time film (October 20)

Owner decision (`OVERHAUL_PLAN_20261020.md` › World): a 10-second "The Hill is
open!" film, once per player ever. Presentation only.

- **Who and when:** the first round that opens after the player has won all camps
  or cleared the King (the HUD rule), unless they already have a Hill win or the
  Champion. `HillService.IntroDue` marks them in `Open`, sends `hill.intro` in their
  snapshot and skips their "The Hill is open!" toast. Joining mid-round waits for
  the next round.
- **Waiting:** `src/client/HillIntro.luau` starts at the round's first free moment
  (no menu, popup, dialogue, crate, roll zoom or first-visit film) and never in the
  last 15 seconds. If the round ends first, it tries again next round.
- **Saving:** the client sends `TutorialSignal HillIntroStarted` as the film starts.
  `TutorialService` sets `tutorial.hillIntroSeen` (whitelisted in the `PlayerSession`
  load; missing = false), so a crash cannot loop it. The agent ledger counts it as
  `ui.HillIntroStarted`.
- **Shots** on the live arena, from the player's side: 0–3.6 s a high descent with
  the gold title; 3.6–6.8 s a low pass by the Hill Guards, "Send your Army to the
  Hill"; 6.8–9.6 s a push-in on the capture point, "Hold it longest to win a Hill
  Roll"; a fade, then the HUD returns. The bars, SKIP, caption and the HUD, CoreGui,
  prompt, control and music holds are copies of `IntroCutscene`'s. It plays
  "Forward Advance" and the cues `Intro_KingAppears` and `Intro_CrownGlint`.
- **Reduced motion:** each move becomes a held shot at its end framing; bars and
  captions appear without motion.
- **Hill VFX:** effects in `ReplicatedStorage.PetRoll.Assets.HillVFX` (Studio-owned;
  the lead copies them from `ServerStorage.VFX["Weather VFX"]`). October 20 pick:
  **Cyberpunk Sparks** (warm orange embers and streaks). Each child stands centred
  on the arena floor unless it has `KeepPosition=true`, and plain Parts that only
  hold emitters are never drawn. They show locally for the whole round to the Hill
  HUD's audience and during the film (`ROUND_VFX` in `HillIntro` limits them to
  the film). No folder means no VFX.
- **Testing:** in a Studio Play (a fresh profile; `workspace.PetRollSkipIntro=true`
  skips the first-visit film), run `/a king me`, then `/a hill open`.
  `tests/HillChecks.luau` covers the due, saved, old-save and break cases.
