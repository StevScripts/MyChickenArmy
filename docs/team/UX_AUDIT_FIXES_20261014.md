# UX audit fixes, October 14, 2026

A full-game UX audit (Studio playtest as a fresh free player and with Test everything,
plus code reviews) found the game hard to read for four reasons: too much on screen at
once, several names for one concept, overlapping power sources, and no guidance after
the Cluck Camp tutorial. This pass fixes the presentation and wording problems. It does
not change prices, odds, saves or owner rules in AGENTS.md.

## Player-facing glossary

| Use | Never in player text |
|---|---|
| Army (selected fighters), My Army | squad, troops, fighters, lineup |
| Flock (all owned chickens) | — |
| chickens | pets, animals, ducks |
| Camp (enemy site); base (the player's home) | outpost; "base" for a camp |
| Cash | coins |
| Fuse, Auto Fuse | merge, merging, merge stand |
| Upgrades (the tree screen) | "research screen", "View research" |
| Invasions | Operations |
| Rebirth 1, Rebirth 2… ("No rebirths yet" at 0) | Recruit, Veteran I… (Veteran/Elite/Royal are Invasion tiers only) |
| Should win / Close fight / Very tough (`TutorialGuide.Difficulty`) | Very risky |
| Device-neutral verbs: use, open, walk to | Press E, Tap, Click |

Internal ids (`Duck`, `Reenlist`, `Operations`, `Merge`, `E7`…) are unchanged.

## What changed

- **One menu at a time.** `AppController:CloseOtherMenus(keep)` closes the main panel, the
  Upgrades tree, Invasions, Rebirth, Daily and the offline receipt. Every menu calls it
  when opening (Rebirth can no longer open on top of Invasions).
- **Top of the screen.** The Commander card stays visible; toasts sit below it. An error
  toast is not replaced by a later success. Routine successes (Select Best, Set Army,
  Call Army, Go Base) are quiet. Army status hides while a lesson card shows. The King of
  the Hill banner shows only near the Hill or when your army is there; elsewhere a compact
  "Hill fight 3:38" chip.
- **HUD.** "Camps held 0/8" (was "Held"), compact cash from $1M ($8.05B), Call Army hidden
  until researched, Army menu titled My Army.
- **Upgrades tree.** "Upgrades" title, square X like other menus, OWNED badge and dark
  fill on finished nodes. The Farm / Army / Rolls / Command jump tabs were removed
  later the same day at the user's request (clutter); drag, zoom and X/Home recentering remain.
- **Progression traps.** A Rebirth keeps Veteran Invasions open (`OperationService.Tier`).
  The King's 45-second pre-Hill lock is removed (`Config.Hill.KingLockSeconds=0`); the
  round itself still uses the arena, and the refusal says when the King opens.
- **After the tutorial.** `Guide.NextGoal` adds hints (never gates): research the Fuse
  Machine, buy Egg Value when a camp is Very tough, take a rival's camp after the King,
  Rebirth progress, and Invasions after a King clear or Rebirth.
- **Tutorial.** The Auto Collect pass pauses during the Collect and Sell lessons, so
  passholders still learn to collect and sell.
- **World.** "Fuse Machine · Locked / Research it in Upgrades" sign; Auto Collect stand
  text no longer overlaps; empty podiums say "Pull the lever to roll"; Giant/Colossal
  particle aura is calm at home and full in battle; intro has five captions.
- **Shop and economy text.** Cash packs pay N minutes of current income (10/45/180/600),
  never less than their old amount, and the Shop shows the live payout. Galaxy Crate
  buttons go ×1, ×3, ×10. Leaderboard2 shows TOP REBIRTHS (Robux spent is still recorded,
  not displayed). Fuse Machine, Double Bounty and Invasion copy now match current rules.
  Research E7/E8 are "Long Reach"/"Longer Reach" (the Egg Magnet name belongs to the pass).
  `OperationCatalog.Power` includes the 1.35× splash factor like `Rules.Power`.
- **Fuse UI.** "Fusing is the only way to get Giants · one guaranteed in N", and a
  "Win more camps to fuse past Lv X" hint when the rank cap hides matching chickens.

## Rebirth pacing (owner decision needed)

`tests/ProgressionSimulation.luau` now runs again (free player, every attack wins, 30 s
ticks). Results with the live config ($5B ×4):

| Milestone | Simulated | Plan 6.9 target |
|---|---|---|
| First King clear | 50 min | 45–90 min |
| Rebirth 1 | 1.75 h | 1.5–3 h |
| Rebirth 2 | 2.2 h | 4–8 h |
| Rebirth 3 | 2.6 h | 10–20 h |

Raising `CostGrowth` to 10, 16 or 25 only moves Rebirth 2 to 2.4–2.7 h, because income
right after a Rebirth is about 500× the first run's (chickens, cash levels, Giants,
research and plot are all kept). Hitting the targets needs a structural choice, for
example resetting chicken cash levels on Rebirth or a much larger Rebirth-scaled cost.
Not changed in this pass.

## Not changed on purpose

- Cash upgrades, prices, odds, saves, research values and the Hill/King shared arena.
- Creator Dashboard work (icon, description, passes on sale, product descriptions,
  retiring Finish Processing Now and keeping Auto Merge off sale) is the owner's.

## Studio state

The open place was several commits behind and had 25 duplicate modules (two copies with
one name, so `require` could load either). All 212 mapped scripts were written to match
the repo, three missing Invasion modules were created, and the extra copies were moved to
`ServerStorage.DuplicateScriptBackup_20261014`. Nothing was published or saved.

## Rebirth changes (later October 14, owner decision)

- Rebirth opens only from the HUD Rebirth button; its hex is gone from the Upgrades tree
  (`RebirthPanel` no longer builds it; `CashUpgradeNodes.Reenlist` removed).
- Only Rebirth 1 needs a Chicken King clear (`RebirthService.Quote` `kingRequired`);
  later ranks need cash and the army at home.
- Each rank adds +100% egg cash (`Config.Rebirth.EggBonusPerRank=1.0`: ×2, ×3, ×4…).
- The panel names the mutation the next rank unlocks (`quote.unlockNext`: Rainbow at 1,
  Shadow at 3, Cosmic at 5), and the completion toast repeats it.
- Rebirths show in the Roblox player list (`leaderstats.Rebirths`).
- The Next-goal hint points at the HUD button, not Upgrades.

Simulation with these rules (cost $5B ×4): Rebirth 1 at 1.74 h, Rebirth 2 at 2.03 h,
Rebirth 3 at 2.30 h, Rebirth 5 by 3 h. Post-rebirth income is high enough that a
cost-growth change alone cannot reach the 4–8 h / 10–20 h targets; resetting chicken cash
levels on Rebirth is the structural lever. Not changed.

## Rebirth pacing fix (October 14, owner request)

- Chickens record levels bought with cash (`pet.cashLevels`, set in
  `ArmyService.UpgradeChicken`, carried through fusion as the inputs' maximum, saved as
  an optional field; a missing or bad value loads as none). Rebirth removes exactly those
  levels and lowers the refund value to match (`RebirthService` `resetCashLevels`).
  Fused and rolled levels, Giants, sizes and mutations stay. Levels bought before this
  change were never counted, so they stay too. The Quote reports `cashLevels` for the panel.
- Costs come from `Config.Rebirth.Costs`: $5B, $5T, $100T, $500T, $1.2Q, $2Q, $3Q,
  $4.2Q, $6Q, $8.5Q (all under the coin cap).
- Simulation (`tests/ProgressionSimulation.luau`, one free-player seed): Rebirth 1 at
  1.85 h, Rebirth 2 at 4.3 h (target 4–8 h). Rebirth 3 was not reached within 20 h at
  $300T (cash $231T and rising); at the chosen $100T it should land inside the 10–20 h
  band, but that exact run was not repeated.
- `tests/RebirthChecks.luau` updated for the new costs, ×2 egg bonus, Rebirth names and
  cash-level reset: 10/10 pass in Studio Edit against fresh module clones.
