# Auto Vacuum (October 21, 2026)

Owner request (Stevin): instead of the old Auto Collect game pass, bring its robot back
as a tool in Upgrades > Tools, with tiers: a tank that only holds so many eggs, a
limited range, and so on. October 22 (Stevin): it is an ordinary Coins purchase that
costs more than the hand vacuum's last tier, not an eggs-vacuumed unlock.

## What the player sees

- Upgrades > Tools has a new branch above Back: **Auto Vacuum**, then three chains:
  **Auto Capacity I–IV**, **Auto Speed I–III** and **Auto Range I–III**.
- The Auto Vacuum hex is an ordinary Coins purchase: 250M, above Vacuum Capacity IV
  (100M), the hand vacuum's last tier, so the robot still comes "later into the game"
  after the hand vacuum. Its chains start above that price too.
- History: October 21 it opened after vacuuming `UnlockEggs` eggs with the hand vacuum
  (1,000, then 5,000, with the Egg Vacuum owned that run) through
  `UpgradeService.Requirement`. October 22 Stevin replaced that with the price; the
  requirement code and `UnlockEggs` are gone.
- Once bought, the robot (the Studio model `ReplicatedStorage.PetRoll.Assets.EggVacuum`
  with its Blender clips) drives the yard in straight passes and pulls in every ready egg
  within its Range. A meter over it reads "12 / 40" and turns red "Full!" when the tank
  is full; it then drives straight to the green pad and sells. Each sale floats "+N" Coins
  from the robot with a gold burst and the EggDeposit sound. It never celebrates on the
  player's HUD (ActionFeedback already skips `"rover"` deposits).
- Robot pickups don't chime or float "+N" over the player: those eggs pay when it sells.

## Numbers (`src/shared/AutoVacuumConfig.luau`, `UpgradeCatalog` Tools families)

| Family | Tiers (value, Coins) | Effect |
| --- | --- | --- |
| Auto Vacuum | unlock, 250M (Oct 22, was 20K) | `autoVacuum` |
| Auto Capacity | +10 s 400M, +20 s 1.5B, +40 s 6B, +60 s 25B (were 15K–1M) | `autoVacuumCapacity` (seconds) |
| Auto Range | +2 studs 600M, +4 3B, +6 12B (were 25K–600K) | `autoVacuumRange` |
| Auto Speed | +25% 500M, +50% 2.5B, +100% 10B (were 20K–500K) | `autoVacuumSpeed` |

- Tank: `(Seconds 20 + Auto Capacity) × EggService:LayingRate` eggs, never below
  `MinCapacity` 8 (30/40/60/80 s with the tiers). The held Egg Vacuum used the same
  model until October 21; it now holds a fixed egg count
  ([COLLECTION_TOOLS.md](COLLECTION_TOOLS.md)).
- Range: 5 studs flat from the nozzle plus the tiers (7/9/11). The route cuts the yard
  into strips two Ranges wide (2–10 passes), so more Range also means fewer, shorter
  trips.
- Speed: 8 studs/s × (1 + tier).
- All prices are drafts, untested against the pacing simulation. 250M sits between
  Rebirth 4 (400M) and Egg Value IV (250M); the top tiers sit with Mega Luck (10B–400B).
  Everything resets on Rebirth like the rest of the tree, and every tree price scales
  with Rebirth rank (`UpgradeCatalog.PriceScale`).

## Server (`EggRover`, `EggService`)

- `EggService:UpdateRover` runs every step while `researchEffects.autoVacuum >= 1` and the
  player owns their pad. A new Range or yard stage redraws the route the next time the
  robot stops at the pad empty; speed changes apply at once.
- States: Idle (waits `IdleSeconds` and for a ready egg) → Sweeping → Returning (at the
  end of the passes, or as soon as the tank is full) → Unloading → sale through
  `AcceptDeposit`, recorded as collector `"rover"`.
- Claims are made in `EggService:Claim` with collector `"rover"` and land in the robot's
  cargo in `Pay`. The robot's cargo is live only. `EggService:ParkRover` settles its
  claims and moves its cargo into the player's bag whenever the robot goes away
  (leaving, Rebirth through `EggService:Release`, losing the node), so an earned egg is
  never lost.
- `session.vacuumedEggs` is a saved, additive lifetime count of eggs that landed in the
  held Egg Vacuum (`Pay`, collector `"vacuum"`). Missing reads as 0; it never fails a
  load. Since October 22 it is only a stat (it no longer unlocks anything).
- Snapshot: `state.eggs.rover = {enabled, id, state, x, y, z, dx, dz, range, count,
  capacity, cargoCount, cargoValue, suctionSerial, unloadSerial}` (`{enabled=false}`
  without one).

## Client

- `AutoVacuumController` (restored from `archive/robot-vacuum-20261020`) draws the robot,
  its poses, wheel spin, nozzle sparks, tank meter and sale effects. `EggController`
  feeds it the snapshot, flies `"rover"` eggs into its nozzle and hands it rover deposits.
- `ResearchBrowser` shows a node's `requirement` in the tooltip and as the refusal.
- Icons: `assets/upgrade-icons-20261020/AutoVacuum*.png` (Codex CLI, from the robot
  render; prompts in `codex/`), uploaded October 21, ids in `upload-receipts.json` and
  `ResearchAssets`.

## Checked October 21

Rojo build and luau-lsp (no new errors beyond the usual strict inference noise). Studio
solo playtest on a fresh test profile: the locked hex and its message, the purchase, the
robot sweeping, filling, returning and selling (+1,200 Coins on its first trip), and the
robot parking its eggs into the bag when the node goes away. The test profile was put
back afterwards. Not checked: a full Rebirth with the robot mid-trip, the T-shaped yard
stages 6–7, phones.
