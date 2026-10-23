# Headless simulation tools (Lune)

Run the repo's real server and shared modules outside Studio: economy fits, check
suites and `tests/ProgressionSimulation.luau` without a playtest. First used for the
October 20 overhaul cost fit (OVERHAUL_CONTRACT §10), the October 21 Rebirth pacing
(`docs/team/REBIRTH_PACING_20261021.md`) and the October 21 rarity pacing
(`docs/team/RARITY_PACING_20261021.md`).

## Setup

Download Lune 0.10.5 (`lune-<version>-macos-aarch64.zip` from
github.com/lune-org/lune/releases), unzip it next to these scripts or anywhere on PATH.
The binary is not committed.

## Scripts

- `harness.luau` — the fake DataModel (`ReplicatedStorage.PetRoll.Shared` = `src/shared`,
  `ServerStorage.PetRoll` = `src/server`, `ServerStorage.PetRollTests` = `tests`), a
  Park-Miller `Random`, service stubs and a `require` that loads each file with
  `luau.load`. Every entry script gets `Harness` (`require`, `Shared`, `Server`, `Tests`,
  `fs`, `serde`, `root`) and `ARGS`.
- `runsuite.luau <SuiteName>` — runs one `tests/*Checks.luau` suite and prints
  `SUMMARY <name> N passed M failed`. Run one suite per process. About a dozen older
  suites fail or throw headless on main (Studio-only parts or stale designs); compare
  against a `git archive HEAD` copy and count only differences.
- `odds_table.luau` — rarity odds per podium for every Luck tier, the Playtime +100%
  boost, Gold/Diamond/Prism rolls, Hill rolls and the 2x Luck pass, plus every
  rollable chicken's zero-Luck odds, level-1 price and income.
- `rarity_probe.luau key=value …` — ProgressionSimulation with the first offer and
  first recruit of every rarity, every Luck tier change, the offer counts and the Coins
  sources per seed. Any ProgressionSimulation option works (`profile=fast|casual`,
  `rollEverySeconds=4`, `hours=1`, `seeds=3`, `playMinutes=45 awayMinutes=1395`,
  `print=true` for the standard milestone table).

- `timeskip_probe.luau key=value …` — at every Rebirth, the Time Skip Coins, how many of
  the tree's tiers they buy and their share of the tree just lost and of the next rank.
- `cost_fit.luau costs=<json> out=<json> key=value …` — ProgressionSimulation with patched
  `Config.Rebirth.Costs`, writing played minutes per rank for a cost fit.
- `unlock_probe.luau key=value … out=<file.json>` — ProgressionSimulation plus, per seed, the
  tree and Gem board at every Rebirth (hexes owned, Coins spent), the first offer and first
  owned chicken per rarity, Luck tier changes and the first purchase of key hexes
  (Mutations IV, Mega Luck IV, all podiums…). The October 22 "unlock-everything" tables in
  `REBIRTH_PACING_20261021.md` come from it (3 fast, 2 casual, 3 daily 45-min and 2 daily
  2-hour seeds, `traceEvery=60`).

## Running

```bash
cd tools/sim && ./lune run harness.luau ../.. odds_table.luau
```

```bash
cd tools/sim && ./lune run harness.luau ../.. rarity_probe.luau profile=fast rollEverySeconds=4 hours=1 seeds=3
```

```bash
cd tools/sim && ./lune run harness.luau ../.. runsuite.luau LuckWindowChecks
```

macOS has no `timeout`; wrap long runs in `perl -e 'alarm 600; exec @ARGV' ./lune run …`.
A 40-hour fast seed takes about 150 s; the login model skips away time, so cost
follows minutes played. `GoldRushService.Multiplier()` stays 1 headless, so the
simulation's own Gold Rush model does not double count.
- `unlock_probe.luau key=value … out=<file.json>` — ProgressionSimulation plus, per seed, the tree
  and Gem board at every Rebirth (hexes owned, Coins spent), the first offer and first owned
  chicken per rarity, Luck tier changes and the first purchase of key hexes (Mutations IV,
  Mega Luck IV, all podiums…). The October 22 "unlock-everything" tables in
  `REBIRTH_PACING_20261021.md` come from it (3 fast, 2 casual, 3 daily 45-min and 2 daily
  2-hour seeds with `traceEvery=60`).
