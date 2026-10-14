# Worker R1-S: rebirth ("Re-enlist"), server

**Branch:** `launch/r1-rebirth-server` · **Worktree:** `~/Documents/Projects/mca-r1s` · **Plan:** [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §6
**Needs the foundation?** Yes. Start after the lead commits it.
**Works with:** R1-C builds the panel against the `Quote` fields below. Do not change their names without telling the lead.

## Why

Players beat the King in about 45 minutes and then have nothing to chase, while cash piles up into the billions. Re-enlisting resets the economy and the war, keeps the collection and research, and pays a permanent egg multiplier. Camps and the King get stronger each rank.

## Files you own (only these)

- `src/server/RebirthService.luau` (the foundation stub; you replace the body)
- `tests/RebirthChecks.luau` (new)
- `docs/team/launch/handoff/R1-S.md` (new)

The foundation already wired everything that touches shared files: the `rebirths` saved field, the `Rebirth` router action, the egg multiplier in `PlayerSession:EarnedAmount`, the enemy scaling hooks in `BattleService` and `KingEncounter`, and `state.rebirth = RebirthService.Quote(session)`. **Do not edit `PlayerSession`, `GameServer`, `BattleService`, `Config` or any other frozen file.** If you need a hook that isn't there, write a "Request for lead" in your handoff.

## API to implement

```lua
RebirthService.Multiplier(rank: number): number      -- 1 + Config.Rebirth.EggBonusPerRank * rank
RebirthService.EnemyScale(rank: number): number      -- 1 + Config.Rebirth.EnemyHealthPerRank * rank
RebirthService.Cost(rank: number): number            -- cash to reach `rank` (rank >= 1)
RebirthService.Quote(session): Quote
RebirthService.Rebirth(session, expectedRank: number?, server): (boolean, string)
```

Use `Config.Rebirth` for every number. `Enabled = false` must make `Quote` return `eligible = false, reason = "Coming soon"` and `Rebirth` refuse.

### Cost

`Cost(r) = Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ (r - 1)`, rounded to a whole number, for `1 <= r <= Config.Rebirth.MaxRank`. Ranks above `MaxRank` are unavailable.

| Rank | Cost | Multiplier | Enemy scale |
|---|---|---|---|
| 1 Veteran I | $1B | 1.25 | 1.5 |
| 2 Veteran II | $8B | 1.50 | 2.0 |
| 3 Veteran III | $64B | 1.75 | 2.5 |
| 4 Veteran IV | $512B | 2.00 | 3.0 |
| 5 Veteran V | $4.1T | 2.25 | 3.5 |

Enemy damage uses `EnemyDamagePerRank` the same way. If the hooks only pass one scale, the foundation applies it to both health and damage. Check the foundation code and say in your handoff what you found.

### Quote (R1-C renders exactly these fields)

```lua
{
	enabled = boolean,
	rank = number,              -- current rebirths
	nextRank = number?,         -- nil at MaxRank
	title = string,             -- "Recruit" at 0, otherwise "Veteran " .. roman(rank)
	nextTitle = string?,
	cost = number?,             -- cost of nextRank
	coins = number,             -- session.coins, for the progress bar
	kingCleared = boolean,
	armyHome = boolean,
	eligible = boolean,
	reason = string?,           -- why not eligible, shown in the panel
	multiplierNow = number,
	multiplierNext = number?,
	enemyScaleNext = number?,
}
```

`reason`, in priority order: `"Coming soon"` (disabled), `"Max rank reached"`, `"Defeat the Chicken King first"`, `"Need $X more"` (format with the existing money formatter in `src/shared` if there is one, otherwise plain digits), `"Bring your army home first"`.

### Rebirth transaction

`Rebirth(session, expectedRank, server)` must, in this order:

1. Refuse unless the session is loaded and writable. Copy the exact guard other transactions use (`session.loaded`, not closing, no `saveLost`). Search `ArmyService` or `RollService` for it.
2. Refuse if `expectedRank ~= session.rebirths` ("Your rank changed. Try again."), so a double tap can't re-enlist twice.
3. Refuse unless the quote is eligible. Use the quote's `reason` as the message.
4. Refuse while an Operation is running or the army is away (no outgoing battle). Find how `ArmyCommandService` or `BattleService` exposes this through `server` (`server.battles`, `server.operations`) and read it; don't change those files.
5. Release every territory the player holds, using the same server path the Unclaim action uses (`server.battles` has the unclaim logic; search for `UnclaimTerritory`). If that path can't be called without editing BattleService, add a "Request for lead" and release by the closest existing public function.
6. Apply the reset in one block with **no yields** (no `task.wait`, no DataStore calls):

| Field | New value |
|---|---|
| `coins` | the fresh-profile starting balance (find it where new profiles are created; it's $2,400 today) |
| `eggSpeedLevel`, `incomeLevel`, `luck` | 0 |
| `firstWins`, `frontierWins`, `laneCamps` | empty tables |
| `kingCleared`, `kingBountyPaid` | false |
| `eggCarry` | `{count = 0, value = 0}` |
| yard egg drops | cleared through the existing EggService path for clearing a yard; if none is public, list it as a request |
| `offlineCash` checkpoint | reset to now with the new rate, using `OfflineCash` helpers |
| `rebirths` | `+ 1` |

   **Kept, never touched:** `pets` (species, level, Giant size, favorites, mutation), `discovered`, `research` (completed, jobs, formations, operation wins), `plotSizeLevel`, `rollSlotsUnlocked`, `capacity`, `promotion`, `recruitTier`, `tutorial`, `hillWins`, `hillRollCredits`, `hillChampion`, `crateCredits`, `purchaseReceipts`, `robuxSpent`, `adminAssisted`, entitlements.
7. Recompute derived state: `session:RefreshArmy()`, research effects if they depend on anything reset, `session:Touch()`, then `server.world:UpdateSession(session)`.
8. Ask for an immediate save through the existing DataService path (search how other important transactions request one; if there's no public call, list it as a request).
9. Analytics through `server.analytics`, using names the foundation registered: count `rebirth.count`, first-time `rebirth.rank.<N>`, histogram `rebirth.playSeconds.<N>` and `rebirth.cashAtRebirth`, onboarding step 20 for rank 1, and the `act.Rebirth` success counter. Check how `Analytics` records counters and histograms and copy that.
10. Return `true, "Re-enlisted as " .. title`.

**Don't reset `promotion`.** It's the old camp rank and only goes up (PlayerSession line 401). Don't touch the tutorial: the guide must never replay.

## Tests (`tests/RebirthChecks.luau`)

1. `Cost`, `Multiplier` and `EnemyScale` match the table for ranks 1 to 5; rank 16 is unavailable.
2. Refusals: disabled, no King clear, not enough cash, army away, Operation running, stale `expectedRank`, max rank.
3. A successful re-enlist resets exactly the reset fields and keeps every kept field. Compare full `ToData()` snapshots before and after, field by field.
4. Two calls with the same `expectedRank`: only the first succeeds.
5. After re-enlisting, a deposit pays the new multiplier (through `EarnedAmount`) and a cash pack does not.
6. Camp defender power on the player's own lane is scaled by `EnemyScale(rank)`; on another player's lane by that owner's rank; the King by the attacker's rank.
7. The tutorial state is identical before and after.
8. Save round trip keeps `rebirths`.

## How the lead verifies

1. Run `RebirthChecks`, `FoundationChecks`, `PersistenceChecks`, `ProgressionSimulation`, `LaneConquestChecks`.
2. In a disposable playtest: give a test session the King clear and $1B (debug commands work in Studio sessions), re-enlist, confirm the reset, kept chickens and research, a stronger Cluck Camp, and higher income.

## Tuning note for the handoff

Run the numbers once by hand: with chickens kept, how fast does a typical late player (EggSpeed and EggValue at 0 again, chickens at their current levels) earn $8B? If Veteran II looks under an hour, say so. The lead tunes `Config.Rebirth` with `ProgressionSimulation`.

## Handoff

Commit on your branch and write `docs/team/launch/handoff/R1-S.md`: what you implemented, the test file, every "Request for lead", and your tuning note.
