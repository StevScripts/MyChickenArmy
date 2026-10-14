# Lead session: integrator playbook

You are the only session that touches `main`, Studio, Rojo sync, merging, tests and publishing. Read AGENTS.md, [`00_START_HERE.md`](00_START_HERE.md) and [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) first.

Your job tonight, in order:

1. Make sure `main` is clean (§1).
2. Start worker O1 (§2).
3. Build and commit the **foundation** (§3). This is the critical path: four workers wait on it.
4. Create the worktrees and start the workers (§4).
5. Merge and test each handoff (§5).
6. Run the shop checks for the owner (§6).
7. Publish (§7).

---

## 1. Clean `main` first

Another chat has uncommitted work across `PlayerSession.luau`, `GameServer.luau`, `LeaderboardService.luau`, `AppController.luau`, `ChickenBrowser.luau`, `MergeBrowser.luau`, `UITheme.luau`, `LeaderboardBoards.luau` and docs, plus new `Admin*` files. **Do not edit until the owner confirms that work is committed.** Then:

```bash
git -C ~/Documents/Projects/MyChickenArmy status --short   # must be empty, except docs/team/launch/
```

Commit `docs/team/LAUNCH_CHANGE_PLAN.md` and `docs/team/launch/` first so every worktree has the docs.

## 2. Start worker O1 immediately

O1 touches none of the foundation files, so it can start before the foundation:

```bash
cd ~/Documents/Projects/MyChickenArmy
git worktree add ../mca-o1 -b launch/o1-operations main
```

The owner opens a session in `~/Documents/Projects/mca-o1` with the prompt from [`00_START_HERE.md`](00_START_HERE.md), using `10_O1_OPERATIONS.md`.

---

## 3. The foundation (do this yourself, about 1 to 1.5 hours)

**Purpose:** add every shared hook and saved field in one commit, with neutral stubs, so the game behaves **exactly as before** and workers never need to edit a shared file. After this commit, the shared files below are frozen until merging starts. Only you edit them.

**Frozen shared files:** `PlayerSession.luau`, `GameServer.luau`, `OfflineCash.luau`, `BattleService.luau`, `KingEncounter.luau`, `RollService.luau`, `ArmyService.luau`, `Config.luau`, `AnalyticsSchema.luau`, `AppController.luau`.

### F1. Stub modules (new files)

Create each with its final API and neutral behaviour. Workers replace the bodies.

`src/server/RebirthService.luau`

```lua
--!strict
-- Re-enlist (rebirth). Foundation stub: neutral until worker R1-S fills it in.
local RebirthService = {}
function RebirthService.Multiplier(_rank: number): number return 1 end
function RebirthService.EnemyScale(_rank: number): number return 1 end
function RebirthService.Quote(session)
	return {rank = session.rebirths or 0, eligible = false, reason = "Coming soon"}
end
function RebirthService.Rebirth(_session, _expectedRank, _server) return false, "Coming soon" end
return RebirthService
```

`src/server/DailyService.luau`: `function DailyService.Check(_session, _now, _server) end`.

`src/shared/MutationCatalog.luau`: `Multiplier(_id) -> 1`, `Roll(_rng, _rebirths) -> nil`, `Best(_pets) -> nil`, `IsValid(_id) -> false`, `Order = {}`.

`src/server/EventService.luau`: `Active(_now) -> false`, `MaybeReplace(_session, species, _rng, _slot, _now) -> species`.

`src/client/RebirthPanel.luau` and `src/client/DailyRewardController.luau`: `new(app)` returning an object whose `:Render(state)` does nothing.

`RebirthService` must never `require` `PlayerSession` (PlayerSession requires it; a cycle would break loading).

### F2. `Config.luau`

Add two blocks (values from the plan; tuning later is config-only):

```lua
Rebirth = {Enabled = true, MaxRank = 15, BaseCost = 1e9, CostGrowth = 8,
	EggBonusPerRank = 0.25, EnemyHealthPerRank = 0.5, EnemyDamagePerRank = 0.5},
Event = {Enabled = false, Id = "Halloween2026", StartsAt = 0, EndsAt = 0, Species = "Pumpkin", OfferChance = 0.02},
```

### F3. `PlayerSession.luau`

1. **Fields in `Reset`:** `self.rebirths = 0` and `self.daily = {streak = 0, lastDay = 0, best = 0}`. Also `self.dailyGranted = nil` (live only, the reward granted this session, for the popup).
2. **`ToData`:** write `rebirths = self.rebirths` and `daily = table.clone(self.daily)`. In the pet list (around line 524) add `mutation = pet.mutation`.
3. **`LoadData`** (additive, never return false for these):
   - `rebirths`: an integer from 0 to `Config.Rebirth.MaxRank`; anything else becomes 0.
   - `daily`: a table whose `streak`, `lastDay` and `best` are non-negative integers; any bad value becomes 0.
   - Each pet (around line 760): `mutation = if MutationCatalog.IsValid(pet.mutation) then pet.mutation else nil`. **Never reject the chicken or the profile for a bad mutation.**
4. **`AddPet(species, stars, mutation)`:** store `mutation` when `MutationCatalog.IsValid(mutation)`. All existing callers keep working because the argument is optional.
5. **`EarnedAmount`** (line 154): when `source == "eggs"`, multiply by `RebirthService.Multiplier(self.rebirths)`. Keep the DoubleCash logic as it is. `OfflineCash.Rate` already routes through `EarnedAmount(raw, "eggs")`, so offline cash picks the multiplier up automatically.
6. **`PetIncome`** (line 349) and **`DisplayedPetIncome`** (line 355): multiply by `MutationCatalog.Multiplier(pet.mutation)`. `DisplayedPetIncome` takes species, stars and level today; add an optional `mutation` argument and pass it from the call sites in `Snapshot`.
7. **`Snapshot`:** add `rebirth = RebirthService.Quote(self)`, `daily = {streak = self.daily.streak, lastDay = self.daily.lastDay, best = self.daily.best, granted = self.dailyGranted}`, and `mutation = pet.mutation` on every pet entry (around line 455 to 466) and in the selected-army list (around line 330).

### F4. `OfflineCash.luau`

In `Rate`, multiply each pet's `Rules.EggRate(...)` by `MutationCatalog.Multiplier(pet.mutation)`. Do not add the rebirth multiplier here; `EarnedAmount` already applies it.

### F5. `RollService.luau`

In `Roll`, after each slot's species is chosen (around lines 29 to 40):
- `species = EventService.MaybeReplace(session, species, rng, slot, now)`, except for the starter roll and for a forced slot-1 species.
- `offers[slot].mutation = MutationCatalog.Roll(rng, session.rebirths or 0)`, except for the starter roll.

In `Buy` (line 73): `session:AddPet(species, 1, offer.mutation)`.

### F6. `ArmyService.luau` fusion

In the fusion result (around lines 223 to 236, where input `a` becomes the Giant): `a.mutation = MutationCatalog.Best({a, b, c}) or a.mutation`. With the stub, `Best` returns nil, so nothing changes.

### F7. `BattleService.luau` and `KingEncounter.luau`: enemy scaling hook

- `KingEncounter.Definition(_rank, scale)`: multiply the boss `hp` and `damage` by `scale` (default 1) and give each guard a `combatStats` scaled the same way (`Rules.Stats` times `scale`). Scale the reported `power` too, so prompt odds stay honest.
- In `BattleService`, wherever camp defenders are built from `Progression.Roster(...)` (around lines 296, 335, 395 and 739 to 746): wrap each defender with `combatStats` scaled by `RebirthService.EnemyScale(rank)`, where `rank` is the lane owner's `rebirths` (your own lane: the attacker; another lane: `self:LaneOwner(plot)`). For the King, use the attacker's rank. Scale the power used for prompt odds the same way.
- `Battle.luau` line 25 already prefers `pet.combatStats` when present, so `Battle.luau` needs no change.
- With the stub, `EnemyScale` returns 1 and every fight is unchanged.

### F8. `GameServer.luau`

- **Router** (next to `Promote`, around line 239): `elseif action == "Rebirth" then ok, message = RebirthService.Rebirth(session, request.expectedRank, self)`.
- **After a successful profile load** (after `self.analytics:Loaded(session)`, around line 378): `DailyService.Check(session, os.time(), self)`.
- **In `Step`** (line 444): once every 60 seconds, call `DailyService.Check` for each loaded session, to catch the UTC day boundary for players who stay online.

### F9. `AppController.luau`

Create `RebirthPanel.new(self)` and `DailyRewardController.new(self)` where the other controllers are created, and call `:Render(state)` on both wherever `StateChanged` renders the other controllers. Both are no-ops until the workers fill them in.

### F10. `AnalyticsSchema.luau`

Register every name the workers will record, so no worker edits the schema:

- Rebirth: `rebirth.count`, `rebirth.rank.<N>`, `rebirth.playSeconds.<N>`, `rebirth.cashAtRebirth`, `act.Rebirth`, `act.Rebirth.fail`, onboarding step `20 Rebirth1`, profile `rebirths`.
- Daily: `daily.claim.<1..7>`, `daily.streak`, `daily.reset`.
- Mutations: `mutation.offer.<id>`, `mutation.buy.<id>`, `mutation.fuse.<id>`.
- Event: `event.offer.<id>`, `event.buy.<id>`.

Follow how the schema declares names with suffixes; if it validates names, make sure these pass.

### F11. Foundation tests (`tests/FoundationChecks.luau`)

1. A profile without the new fields loads with `rebirths = 0`, `daily = {0, 0, 0}` and no mutations.
2. Junk values (`rebirths = -3`, `rebirths = "x"`, `daily = 5`, `pet.mutation = "Nope"`) load as defaults and **the profile and every chicken still load**.
3. A save round trip keeps `rebirths`, `daily` and a valid `mutation` (temporarily stub `IsValid` to accept a test id).
4. With all stubs neutral, income, offline rate, roll offers, fusion results and camp and King power equal the values before the foundation. Compare against a snapshot taken on `main` before your edits.

Then run `tests/PersistenceChecks.luau`, `tests/ProgressionSimulation.luau`, `tests/RulesAndBattles.luau`, `tests/LaneConquestChecks.luau` and `tests/ResearchChecks.luau`. Fix anything you broke.

Commit: `Launch foundation: rebirth/daily/mutation/event hooks with neutral stubs`.

**The foundation is safe to publish on its own.** It changes no behaviour.

---

## 4. Worktrees for the workers

**Preferred: spawn the workers yourself.** Launch each worker as a background subagent with worktree isolation (`isolation: "worktree"`), giving it the start prompt from [`00_START_HERE.md`](00_START_HERE.md) with its own doc. They run in parallel while you keep integrating, and the owner doesn't have to open sessions by hand. Start O1 as soon as `main` is clean, and the other workers right after the foundation commit. Workers must not spawn agents of their own.

**Fallback: manual worktrees** if subagents aren't available. The owner opens one session per folder:

```bash
cd ~/Documents/Projects/MyChickenArmy
git worktree add ../mca-r1s -b launch/r1-rebirth-server main
git worktree add ../mca-r1c -b launch/r1-rebirth-client main
git worktree add ../mca-d1  -b launch/d1-daily main
git worktree add ../mca-m1  -b launch/m1-mutations main
git worktree add ../mca-h1  -b launch/h1-halloween main
```

The owner opens one session per folder with the start prompt from [`00_START_HERE.md`](00_START_HERE.md). Tell R1-C what R1-S's quote fields will be (they're in both docs already).

**Only you run `rojo serve`, and always from the main checkout** (`~/Documents/Projects/MyChickenArmy`). A worker running Rojo from its worktree would overwrite Studio with half-finished code.

## 5. Merge and test loop

Merge in this order as handoffs arrive: **O1 → R1-S → R1-C → D1**, then tomorrow **M1 → H1**.

For each branch:

1. Read the handoff note in `docs/team/launch/handoff/<ID>.md`.
2. Check the branch only edited its listed files: `git diff --stat main...launch/<branch>`. Send it back if it touched a frozen file.
3. `git merge --no-ff launch/<branch>` on `main`. Resolve any conflict yourself.
4. Rojo is already syncing from `main`; confirm Studio picked up the change.
5. Run the worker's test file plus `FoundationChecks`, `PersistenceChecks` and `ProgressionSimulation` in Studio Edit mode.
6. Playtest in a disposable session (`PetRollPlaytestSessionOnly = true`) on desktop and in the phone emulator, following the worker's "how to verify" section.
7. Note the result in the handoff file and commit.

If a branch fails, send the exact failure back to that worker's session. Don't fix their files yourself unless it's a one-line fix, and note it if you do.

## 6. Shop checks for the owner (P0.4 and P0.5)

Before the owner puts passes on sale, verify in a disposable playtest with entitlements forced on, or through the existing test path:

| Pass or product | Check |
|---|---|
| 2x Cash | A deposit pays double; a cash pack and a chicken sale do not |
| Auto Collect Eggs | The vacuum runs, delivers through the normal payout, and never traps the player or camera |
| 2x Egg Spawn | Production and offline rate double |
| Bigger Army | Capacity +5; Select Best and saved formations respect it |
| 2x Luck | Odds in Details match `Rules.Odds` with the paid multiplier; the restricted-account treatment still applies |
| Cash packs | `ProductService:_ProcessReceipt` grants coins exactly once per receipt and respects the cap |

Tell the owner which ones passed.

## 7. Publish

**Publish 1 (tonight):** Phase 0 dashboard changes, foundation, O1, R1-S, R1-C, D1. Before publishing:

1. The owner notes the current place version in Version History.
2. The full test list passes on `main`.
3. Publish from Studio.
4. **Servers → Restart servers for updates.** Old servers erase `rebirths`, `daily` and `mutation` (see [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §3.2).
5. For the next hour, read the analytics ledger: `health.loadFailures` must stay 0, `act.Rebirth` and `daily.claim.*` should appear, and `topRejections` must show no new errors.

**Rollback:** revert the place to the noted version in Version History, then restart servers. Additive fields mean a rollback loses only the new features' data, never existing progress.

**Publish 2 (tomorrow):** M1 and H1 after a longer playtest, then restart servers again.

## 8. After the sprint

- Remove the worktrees: `git worktree remove ../mca-o1` and so on, then delete merged branches.
- Update `docs/CURRENT_GAME.md` with the new systems.
- Add the Top Veterans leaderboard (plan §6.11). It's left out tonight because `LeaderboardService.luau` belonged to the admin-panel chat.
