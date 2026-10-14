# Handoff R1-S: Re-enlist server

**Branch:** `launch/r1-rebirth-server`, from foundation `bec87ac`. **Owner decisions applied:** chicken levels are kept, the name is "Re-enlist", rank 0 is "Recruit" and ranks are "Veteran I, II, III...".

## What changed

Only my three files:

- `src/server/RebirthService.luau`: replaces the stub body.
- `tests/RebirthChecks.luau`: new.
- `docs/team/launch/handoff/R1-S.md`: this note.

### API

| Function | Behaviour |
|---|---|
| `Multiplier(rank)` | `1 + EggBonusPerRank * rank` |
| `EnemyScale(rank)` | `1 + EnemyHealthPerRank * rank` |
| `Cost(rank)` | `round(BaseCost * CostGrowth^(rank-1))` for whole ranks `1..MaxRank`, otherwise `nil` (rank 16 gives `nil`) |
| `Title(rank)` | `"Recruit"` at 0, otherwise `"Veteran " .. roman(rank)` (extra helper; R1-C can use the quote's `title` instead) |
| `Quote(session)` | Every field in the contract. Needs no `server`, has no loops, and is safe to build every snapshot |
| `Rebirth(session, expectedRank, server)` | The transaction below |

Ranks are clamped to `0..MaxRank`, and junk input counts as 0. Multiplier and EnemyScale stay in effect when `Enabled = false`. The switch only blocks new re-enlists, so players who already re-enlisted keep their bonus and their stronger enemies. If you'd rather have a full kill switch, tell me.

`reason`, in this order: `"Coming soon"`, `"Max rank reached"`, `"Defeat the Chicken King first"`, `"Need $X more"`, `"Bring your army home first"`. `src/shared` has no money formatter (the only one is client-side, in `UITheme`), so X is plain digits, rounded up. `armyHome` is `armyState == "Home"` with no `outgoing` and no `incoming`.

### Transaction order

1. **Writable session.** Refuses unless `loaded`, and refuses when `closing`, `saveLost` or `dataReleasing`.
2. **Stale rank.** Refuses when `expectedRank ~= session.rebirths`, with "Your rank changed. Try again." A missing `expectedRank` is refused the same way.
3. **Quote.** Refuses unless the quote is eligible and returns its `reason`. One exception: if the army is away because an Operation is running, the message is "Finish your Operation first."
4. **Army away.** Checks again:
   - An Operation is running (`server.battles.battles[session.outgoing].operationId`).
   - `session.defending` is set.
   - Any battle in `server.battles.battles` names the player as attacker or defender.
5. **Release territories.** Every camp, outpost and King flag the player holds goes through `server.battles:Unclaim(session, targetId, os.clock())`. The territory key is turned back into the target id with `CampaignRoute.CampId`. If Unclaim ever fails, the fallback is `battles:SetTerritoryOwner(key, nil)`. Then `RefreshTerritoryBonus()` runs so the territory egg bonus drops right away. The Hill (`income:1`) is left alone because it's HillService's timed round. Other players' flags on this player's lane are also left alone.
6. **Yard eggs.** `server.eggs:Release(session)` is the existing public path. It settles in-flight claims and rover cargo into the bag and drops the yard, and the next step lays a fresh yard. The bag is emptied in step 7.
7. **Reset, with no yields:**
   - `coins` goes to `Config.StartingCoins` ($2,400).
   - `eggSpeedLevel`, `incomeLevel` and `luck` go to 0.
   - `firstWins`, `frontierWins` and `laneCamps` become empty.
   - `campUnlocked = 1`. It isn't saved; it's derived from `firstWins`.
   - `kingCleared` and `kingBountyPaid` become false.
   - `eggCarry` becomes `{0, 0}`.
   - `rebirths` goes up by 1.
   - `offlineCash` becomes `{at = os.time(), rate = OfflineCash.Rate(session), maxSeconds}`, with `maxSeconds` computed the same way as `DataService:Capture`.
8. **Derived state.** Calls `RefreshArmy()` and `Touch()`. Research effects only read `research`, which is kept, so they don't need recomputing. I don't call `world:UpdateSession` myself because GameServer already does it after the router returns.
9. **Immediate save.** `task.spawn(server.data:Save(session, false))`, the same pattern as `DataService:Step`. Only runs when the session has a live DataService entry, so New Player Test sessions never save. See request 2.
10. **Analytics.** `LaunchCount "rebirth.count"`, `LaunchHist "rebirth.cashAtRebirth"` (coins before the reset), and `LaunchFirst "rebirth.rank.N"`. Only the first time, it also records `LaunchHist "rebirth.playSeconds.N"` with `PlaySeconds`. Each analytics call is skipped when there's no `server.analytics`. `act.Rebirth`, the sink, onboarding step 20 and `feature.first` are not duplicated.
11. **Result.** Returns `true, "Re-enlisted as Veteran N"`.

Everything else is untouched:
- `pets` and `discovered`
- `research`
- `plotSizeLevel`, `rollSlotsUnlocked` and `capacity`
- `promotion` and `recruitTier`
- `tutorial`
- the Hill fields
- crates, receipts, `robuxSpent` and `adminAssisted`
- `daily` and `eggProcessor`
- lifetime `passiveEarned` and `battleEarned`

The test compares every `ToData()` field before and after to check this.

### What I found in the foundation hooks

BattleService and KingEncounter take **one** scale, from `RebirthService.EnemyScale(rank)`, and apply it to both health and damage:
- Camp defenders use the lane owner's rank.
- The King court uses the attacker's rank.
- Prompt and target power is scaled by the same number.

So **`Config.Rebirth.EnemyDamagePerRank` is unused.** Both values are 0.5, so nothing changes today. A second hook only matters if you want to tune damage separately from health.

## Tests: `tests/RebirthChecks.luau`

Run it in a fresh Run-mode server:

```
require(game.ServerStorage.PetRollTests.RebirthChecks).Run()
```

It prints PASS/FAIL lines and returns `{name, passed, error}`. It uses isolated sessions, a stub world, stub analytics and a stub DataService. It also uses a real BattleService and EggService, but with no world root and no DataStore. There are nine checks:

1. Cost, multiplier and enemy scale match the table for ranks 1 to 5. Rank 16 is unavailable, and the titles and Roman numerals are right.
2. The quote has every contract field, and it's in `Snapshot().rebirth`.
3. Each refusal works and changes nothing:
   - disabled
   - max rank
   - no King clear
   - not enough cash ("Need $500 more")
   - army marching
   - Operation running
   - stale or missing `expectedRank`
   - `saveLost`
4. A full re-enlist:
   - Reset fields have their new values, and every other `ToData` key is deep-equal to before.
   - The tutorial is identical.
   - Own flags (own lane, a friend's lane and the King) are released, and the friend's flag stays.
   - The old yard is gone.
   - There was one immediate save, and its payload has `rebirths = 1`.
   - The analytics names were recorded.
   - The next quote asks for a new King clear.
5. The same `expectedRank` twice re-enlists once. The fresh rank then works.
6. After re-enlisting, a real `EggService:AcceptDeposit` pays ×1.25. Sale, battle, offline and robux sources stay flat (cash packs add `product.coins` directly in ProductService). The offline rate scales ×1.25.
7. Target power uses the right scale for the own lane (own rank), a friend's lane (the friend's rank) and the King (the attacker's rank). Live own-lane defenders carry scaled hp and damage, and the King boss in the friend's court has 2800 × the friend's scale.
8. The tutorial is unchanged, and the starter reserve and starter minimum stay at 0.
9. Save round trip: the post-rebirth `ToData` loads, and `rebirths`, the reset profile, research and the multiplier come back.

**Not run.** There's no Luau runtime or analyzer in this worktree, and I don't use Studio. `rojo build tests.project.json` packages fine, but that only proves packaging, not that the Luau runs.

## Requests for lead

1. **FoundationChecks will fail on two asserts now that the stub is real.** Please change them to use rank 0:
   - "With neutral stubs, income and offline rate match main" asserts `Rebirth.Multiplier(5)==1`.
   - "With neutral stubs, camp and King power match main" asserts `King.Definition(4,Rebirth.EnemyScale(3))` gives power 497 with no guard `combatStats`.
2. **A public save request in DataService (optional).** I start `server.data:Save` in a spawned task and read `data.entries[userId]` to make sure the entry belongs to this session. If an autosave is already running, Save refuses, and the new rank only reaches the store on the next autosave (up to 30 s) or on leave. A `DataService:RequestSave(session)` that saves now, or queues a save right after the running one, would close that gap. If you add it, swap `requestSave` in RebirthService for it.
3. **Fractional coins (small, PlayerSession).** `Credit` checks for a whole number *before* `EarnedAmount`. A ×1.25 or ×1.75 multiplier on an odd egg value now credits fractions such as 126.25. Saves still load, because `LoadData` rounds coins up. Still, a `math.floor` after `EarnedAmount` in `Credit` (or inside `EarnedAmount` when `source == "eggs"`) would keep the wallet whole. The quote rounds up its "Need $X" itself.
4. **The Hill is not released** on re-enlist (it's HillService's round, and Unclaim doesn't accept `income:1`). If you want it released, call `battles:SetTerritoryOwner("income:1", nil)` there, or ask me to.
5. **`EnemyDamagePerRank` is unused** (see above). Either remove it from Config or add a second scale to the hooks.

## Tuning note (worked out by hand, because ProgressionSimulation is broken)

The numbers come from the code:
- Per-chicken income is `income × 2^(level−1)` per second at Egg Speed 0 and Egg Value 0. For example, a level 8 Wizard makes $20.5K/s and a level 10 Golden Emperor makes $137K/s.
- Egg Speed is ×(1 + 0.15 × level).
- Egg Value is ×round(4 × (1 + 0.25 × level)) / 4.
- Both tracks share prices: $2,880, $63K, $484K, $1.81M, then ×1.6 per level. Getting to level 8 costs about $29M per track, level 17 about $2.2B per track, and maxing at 25 about $94B per track.

**A typical late player** has about 30 chickens averaging about $15K/s base (a mix of level 6 to 8 Wizards, Knights and Dragons), and about +30% from research. Right after re-enlisting:
- Income at upgrade level 0 is about 30 × 15K × 1.25 × 1.3 ≈ **$0.7M/s**.
- Level 8 on both tracks (×6.6, $58M) is affordable within about 2 minutes, which gives about $4.8M/s.
- About $4.4B more buys level 17 on both tracks (×18.6), which gives about $13.6M/s.
- Rebuilding the upgrades plus saving $8B comes to roughly **20 to 35 minutes**. The King re-clear adds a few minutes on top: at rank 1 the camps and the King are only 1.5× stronger, and a level 8 to 10 army beats Ironbeak HQ (about 290 power) and the King court (about 750) easily.

**Veteran II comes in well under an hour** for a typical late player, under 15 minutes for a strong flock of level 10 Legendaries, and about an hour for a weak flock (about $100K/s base).

After that, the cost grows ×8 per rank while income only gains +0.25× per rank, because the chickens and upgrades are already near their ceiling. Rough estimates:
- Veteran III: about 2 to 4 h.
- Veteran IV: about 15 to 30 h.
- Veteran V: days.

The curve starts too fast and then hits a wall.

Suggested starting point for ProgressionSimulation:
- `BaseCost` about 5e9 to 1e10.
- `CostGrowth` about 3 to 4.

Also, at 0.5× per rank the enemy scaling barely slows a kept level 10 army, so `EnemyHealthPerRank` can likely go to 1.0 or more without hurting anyone.
