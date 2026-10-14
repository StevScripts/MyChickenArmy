# My Chicken Army: launch change plan (October 2026)

**Status:** proposed, nothing in this document is implemented yet.
**Written:** October 14, 2026, from the live analytics ledger, a read-only scan of all live saves, the repository source and the live Roblox store page.
**Companion reports:** [Chicken Army Endgame Gap](https://claude.ai/artifact/RXz7QyrKi75CoXxDddiwFT) (Mini War and Merge a Nuke comparison) and [Chicken Army Game Review](https://claude.ai/artifact/TEmVDAS8rqtewhawHyDLU1) (full review).

This is the single list of what changes before and after launch, why, exactly where in the code, what it does to saves, how to test it and how to tell it worked. Each change has an ID (P0.1, R1, and so on) so commits, tests and analytics can refer to it.

---

## Contents

1. [Why these changes](#1-why-these-changes)
2. [Summary of every change](#2-summary-of-every-change)
3. [Ground rules for every change](#3-ground-rules-for-every-change)
4. [Phase 0: store page and shop (no code)](#4-phase-0-store-page-and-shop-no-code)
5. [Phase 1A: unlock Operations by beating the King](#5-phase-1a-unlock-operations-by-beating-the-king)
6. [Phase 1B: rebirth ("Re-enlist")](#6-phase-1b-rebirth-re-enlist)
7. [Phase 1C: 7-day login streak](#7-phase-1c-7-day-login-streak)
8. [Phase 1D: Halloween event](#8-phase-1d-halloween-event)
9. [Phase 2A: mutations](#9-phase-2a-mutations)
10. [Phase 2B: yard raids](#10-phase-2b-yard-raids)
11. [What is deliberately not changing](#11-what-is-deliberately-not-changing)
12. [Release and rollout checklist](#12-release-and-rollout-checklist)
13. [How to tell it worked](#13-how-to-tell-it-worked)
14. [Decisions the owner still needs to make](#14-decisions-the-owner-still-needs-to-make)
15. [Sources](#15-sources)

---

## 1. Why these changes

Numbers are from the analytics ledger (7 days, live servers) unless marked. Eight tracked new players, all friends of the owner, so every number is directional.

| Finding | Evidence | Fixed by |
|---|---|---|
| New players finish the game in about an hour | 4 of 7 Oct 13 players beat the King; median at most 45 min of play, p90 at most 90 min | R1 rebirth, M1 mutations, X1 raids |
| Nothing to do after the King | 0 players have started an Operation; Elite and Royal Operations sit behind 8 h and 48 h research | O1 Operations unlock |
| Cash stops mattering | Friends hold $1.05B, $6.07B, $57.3B; whole research tree costs $858M; eggs earned $110B while research absorbed $72M | R1 rebirth (resets cash), X1 raids (non-inflating sink) |
| Mythics are no longer rare | Mythics were 3.6% of all offers (base 0.06%); 357 bought; 89.5% of offered Mythics were bought | M1 mutations |
| Nothing pulls players back tomorrow | 1 of 7 came back the next day; no daily reward, quest, streak or event | D1 streak, H1 Halloween |
| The store page is not launch-ready | Icon is the default grey placeholder; description is empty; genre is "All" | P0.1 to P0.3 |
| The main passes cannot be bought | 2x Cash, 2x Luck, Auto Collect Eggs, Bigger Army, 2x Egg Spawn and all four cash packs are off sale on Roblox | P0.4, P0.5 |
| A product sells a disabled feature | "Finish Processing Now" (100 Robux) is for sale while the egg processor is off | P0.6 |
| Crates are expensive for the market | 500 / 1,250 / 4,000 Robux against 99 to 399 in Mini War and Merge a Nuke | P0.7 |
| No PvP stakes | Home yards can never be touched; losing a territory only removes a live bonus | X1 raids |

**What is already good and must not regress:** the Commander guide (8 of 8 finish it, median at most 3 min), performance (60 fps median on phones and desktop), fusion and Giants, the existing saves (all 9 live saves load with the current code).

---

## 2. Summary of every change

| ID | Change | Phase | Effort | Save impact | Risk |
|---|---|---|---|---|---|
| P0.1 | Real game icon | 0 | Minutes | None | None |
| P0.2 | Game description | 0 | Minutes | None | None |
| P0.3 | Genre | 0 | Minutes | None | None |
| P0.4 | Put verified passes on sale | 0 | 1 hour incl. tests | None | Low |
| P0.5 | Put cash packs on sale | 0 | 30 min incl. tests | None | Low |
| P0.6 | Take Finish Processing Now off sale | 0 | Minutes | None | None |
| P0.7 | Cheaper single Galaxy Crate | 0 | Minutes | None | Low |
| O1 | Beating the King unlocks Veteran Operations; shorten S16 and S17 | 1 | 2 to 3 hours | None | Low |
| R1 | Rebirth ("Re-enlist") | 1 | 1 to 2 days | New field `rebirths` | Medium |
| D1 | 7-day login streak | 1 | Half a day | New field `daily` | Low |
| H1 | Halloween event chicken and decor | 1 | 1 day plus art | New catalog species | Low |
| M1 | Mutations | 2 | 2 to 3 days | New pet field `mutation` | Medium |
| X1 | Yard raids, eggs only | 2 | 1 to 2 weeks | New field `shield` | High (design) |

Phase 0 is done in the Creator Dashboard and can ship today. Phase 1 is the first week after launch. Phase 2 is weeks 2 and 3.

---

## 3. Ground rules for every change

These come from AGENTS.md and the October 9 save rule, plus one rollout hazard found while writing this plan.

### 3.1 Saves are real player data

- Every new saved value is an **additive field**. A missing field reads as its default (0, false, empty). Never bump `dataRevision` for an additive field and never reject a profile because a new field is missing.
- `PlayerSession:LoadData` must never return `false` for a malformed new field. Drop the bad value and use the default instead, exactly like `laneCamps` does ("malformed entries are dropped").
- Never write to the live DataStore (`DuckArmy_Pond_v2`, keys `player_<id>`) from Studio or a script without explicit owner approval for that specific change.

### 3.2 Old servers silently drop new fields (rollout hazard)

`PlayerSession:ToData` rebuilds the save from an explicit field list, and the pet list is rebuilt from an explicit field list too (`ToData` around line 524, `LoadData` around line 760). A server still running the previous build does not know `rebirths`, `daily`, `shield` or `pet.mutation`. If a player who rebirthed later joins an old server, that server saves the profile without those fields and **the progress is lost**.

**Required for every phase that adds a field:** after publishing, use Creator Dashboard → the experience → Servers → **Restart servers for updates** (or "Shut down all servers") so no old-build server survives. Do not rely on old servers emptying out on their own.

### 3.3 One writer per file

Another chat is working on the admin panel right now (`AdminService.luau`, `AdminConfig.luau`, `AdminCommands.luau`, `AdminPanel.luau`, and uncommitted edits to `PlayerSession.luau`, `GameServer.luau`, `WorldService.luau`, `LeaderboardService.luau`, `AppController.luau`, `UITheme.luau`). R1, D1, M1 and X1 all touch `PlayerSession.luau` and `GameServer.luau`. Commit or finish that work first, then start Phase 1.

### 3.4 Every change ships with

1. A focused test file in `tests/` that runs in Studio Edit mode against fresh module clones (the same pattern as `tests/LaneConquestChecks.luau`).
2. A run of `tests/PersistenceChecks.luau` and `tests/ProgressionSimulation.luau` to prove old saves still load and pacing still holds.
3. Analytics names added to `src/server/AnalyticsSchema.luau` before any event is recorded.
4. A short note in `docs/team/` for the feature, and a line in `docs/CURRENT_GAME.md`.

---

## 4. Phase 0: store page and shop (no code)

All of these are Creator Dashboard changes. None touches the repository except where noted.

### P0.1 Real game icon

**Now:** the icon API returns Roblox's default grey placeholder for universe 10765467283. The icon is what players see in search, favorites, friends' activity and several Home rows.

**Change:** upload a 512×512 icon in Creator Dashboard → My Chicken Army → Places/Experience → Basic Settings / Icon. If one was uploaded, check whether it is pending or rejected by moderation.

**Direction for the icon:** one helmeted chicken face filling most of the square, bold outline, bright background, readable at 50×50 px. Reuse the helmeted chicken from thumbnail 2 so the icon and thumbnails match.

**Done when:** `https://thumbnails.roblox.com/v1/games/icons?universeIds=10765467283&size=512x512&format=Png` returns your art, not the placeholder.

### P0.2 Game description

**Now:** empty.

**Change:** paste this (edit freely; keep it short, mobile shows only the first lines):

```
🐔 Raise chickens. Build an army. Conquer everything!

🥚 Collect eggs from your flock and sell them for cash
🎰 Pull the lever to recruit rarer chickens, all the way to Mythic
🧬 Fuse 3 matching chickens into a GIANT
⚔️ Send your army to capture camps and other players' land
👑 Defeat the Chicken King and rule the island

👍 Like the game and join the group for updates!
📱 Plays on mobile, tablet, desktop and console
```

When rebirth and raids ship, add lines for them. Only add "New updates every Saturday" if you will keep that promise.

### P0.3 Genre

**Now:** "All".

**Change:** set the genre to **Simulation**, subgenre **Tycoon** if offered (Mini War is "Simulation Tycoon", Merge a Nuke is "Simulation Incremental Simulator"). This lets Roblox place the game beside similar games.

### P0.4 Put verified passes on sale

**Now on Roblox:**

| Pass | passId | For sale | Price now | Proposed price (ShopCatalog) |
|---|---|---|---|---|
| Auto Collect Eggs | 1978713718 | No | none | 199 |
| 2x Cash | 1980764263 | No | none | 399 |
| 2x Egg Spawn | 1979943376 | No | none | 199 |
| Auto Merge | 1975401932 | No | none | 249 |
| Bigger Army | 1980638268 | No | none | 499 |
| 2x Luck | 1975521949 | No | none | 399 |
| Egg Magnet | 1980009442 | Yes | 49 | 49 |
| Commander Banner | 1975521947 | Yes | 99 | 99 |
| Double NPC Bounty | 1981040250 | Yes | 249 | 249 |

The in-game Shop already reads the live price and marks an off-sale item `offsale` (`src/client/CommerceController.luau` lines 57 to 59), so players currently see these as unavailable.

**Change:** put Auto Collect Eggs, 2x Cash, 2x Egg Spawn, Bigger Army and 2x Luck on sale at their proposed prices. **Keep Auto Merge off sale**: `Config.Features.AutoMerging` is false, so the feature does not exist.

**Verify before flipping each one** (Studio playtest with a test account that owns the pass, or the `TestCrate`-style entitlement path):
- 2x Cash: `PlayerSession:EarnedAmount` doubles `eggs`, `battle` and `territory` only. Confirm a deposit pays double and a cash pack does not.
- Auto Collect Eggs: the vacuum runs, delivers through the normal payout and does not trap the player or camera (the Oct 8 audit stall issue Codex owned). Confirm that fix is in.
- 2x Egg Spawn: production doubles, offline rate doubles (`OfflineCash.Rate` passes `DoubleEggSpawn`).
- Bigger Army: `PlayerSession:Capacity` adds `ShopCatalog.ArmyBonus` (5). Confirm Select Best and saved lineups respect it.
- 2x Luck: odds shown in Details match `Rules.Odds` with `paidMultiplier`. This is a paid random modifier: confirm the restricted-account treatment still applies.

### P0.5 Put cash packs on sale

| Product | productId | Coins | Proposed price |
|---|---|---|---|
| Pocket Cash | 3712929487 | 10,000 | 49 |
| Coop Stash | 3712929549 | 100,000 | 199 |
| Cash Sack | 3712929607 | 1,000,000 | 799 |
| Commander's Vault | 3712929634 | 10,000,000 | 2,499 |

Delivery already exists: `ProductService:_ProcessReceipt` adds `product.coins` atomically and checks the coin cap. The product descriptions on Roblox still say "Test product: unavailable until secure purchase delivery is enabled". **Change:** edit each description to say what it gives, then put it on sale. Test one purchase per product in a Studio test session before going live.

**Note for later:** these fixed amounts become tiny once players earn billions. After rebirth ships, consider packs that scale with income ("1 hour of your income") instead of fixed coins.

### P0.6 Take Finish Processing Now off sale

`Finish Processing Now` (productId 3714566216, 100 Robux) is for sale on Roblox, but `ShopCatalog.Products.FinishEggs.enabled` follows `EggProcessorConfig.Enabled`, which is false. Nothing in the game prompts it today, but a direct product link could still charge a player for nothing. **Change:** turn off "for sale" in the dashboard.

### P0.7 Cheaper single Galaxy Crate

| Product | Now | Proposed test |
|---|---|---|
| Galaxy Crate × 1 (3712929703) | 500 | 149 |
| Galaxy Crate × 3 (3712929865) | 1,250 | 399 |
| Galaxy Crate × 10 (3712929926) | 4,000 | 1,199 |

The client reads the buyer's live Marketplace price, so no code changes. Update `proposedPrice` in `src/shared/ShopCatalog.luau` to match, so the repository stays the record of intent. Watch `shop.prompt.OuterSpaceCrate1` against `robux.product.OuterSpaceCrate1` for a week and compare revenue, not just purchases.

---

## 5. Phase 1A: unlock Operations by beating the King

**ID:** O1. **Effort:** 2 to 3 hours. **Save impact:** none.

### Why

The nine Operations are the only content after the King, and no player has started one. Today the gate is research only: Veteran needs S15 (1 h), Elite needs S16 (8 h) and Royal needs S17 (48 h).

### Change

1. **Veteran Operations unlock when the King is first cleared**, in addition to the existing S15 research path. Either one is enough.
2. **Shorten the two later gates:** S16 Elite Operations from 28,800 s to 7,200 s (2 h); S17 Royal Operations from 172,800 s to 21,600 s (6 h). Prices stay the same. These are the only research timers that change in this plan (see section 11).

### Code

| File | Change |
|---|---|
| `src/server/OperationService.luau` line 52 | Replace `session.researchEffects.operations<definition.tier` with a helper `OperationService.Tier(session)` that returns `math.max(session.researchEffects.operations, if session.kingCleared then 1 else 0)`. |
| `src/server/OperationService.luau` line 160 | Report `tier=OperationService.Tier(session)` in the state snapshot so the client shows Veteran as open. |
| `src/shared/ResearchCatalog.luau` | S16 `duration=7200`, S17 `duration=21600`. Update the S15 description to "Unlock Veteran Operations early (also unlocked by defeating the Chicken King)". |
| Client Operations UI (the module that reads the Operations tier) | Locked text for Veteran becomes "Defeat the Chicken King or research Operations Board". |
| `src/shared/TutorialGuide.luau` `NextGoal` | After the first King clear, point the next goal at Veteran Patrol instead of leaving no goal. |

**Save safety:** research jobs already running keep their saved `finishAt`, so nobody loses time. `ResearchRules.Read` does not re-check durations on load.

### Tests (`tests/OperationUnlockChecks.luau`)

- A session with `kingCleared=true` and no S15 can start Veteran Patrol; Elite stays locked.
- A session with S15 and no King clear can still start Veteran Patrol (old path intact).
- A session with neither gets the locked message.
- S16 and S17 quotes are 2 h and 6 h before research speed bonuses.
- Re-run `tests/ResearchChecks.luau`.

### Done when

`feature.first.Operations` is above zero for the first cohort after release, and the median time from King clear to first Operation is under 10 minutes of play.

---

## 6. Phase 1B: rebirth ("Re-enlist")

**ID:** R1. **Effort:** 1 to 2 days plus tuning. **Save impact:** one new additive field. **This is the most important change in the plan.**

### 6.1 Why

Rebirth turns the one-hour route into a loop players climb again and again. Each rebirth wipes the inflated cash (fixing the economy), raises enemy strength (the route is no longer solved) and pays a permanent multiplier (progress still feels like progress). It also gives long research a purpose: research is kept, so it becomes the slow layer under the fast rebirth loop, the same shape Mini War and Merge a Nuke use.

### 6.2 Name and fantasy

**"Re-enlist"**: the commander re-enlists with a veteran army, earns a new rank and faces a stronger enemy. Ranks display as **Veteran I, Veteran II, Veteran III**, and so on, next to the player's name on the HUD, their flags and the leaderboard. Do not use the word "promotion": `session.promotion` already exists and means the old camp rank (it controls fusion level ceilings and recruit tier). Rebirth gets its own field.

### 6.3 Requirement and cost

To re-enlist the player must:
1. Have cleared the Chicken King **in the current run** (`kingCleared == true`).
2. Pay a cash cost that rises with each rank.

**October 13 owner retune (live config):** `BaseCost=5e9`, `CostGrowth=4`, `MaxRank=10`, `EnemyHealthPerRank=1.0` (one scale for health and damage). Costs $5B, $20B, $80B, $320B, $1.28T…; enemies ×2, ×3, ×4…; eggs unchanged (+0.25 per rank). The table below is the original proposal. `ProgressionSimulation` is broken on main (removed `AccrueIncome`), so this is a hand estimate, not a simulated one.

Starting table (must be confirmed with `tests/ProgressionSimulation.luau`, see 6.9):

| Re-enlist to | Cash cost | Egg multiplier after | Enemy strength after |
|---|---|---|---|
| Veteran I | $1B | 1.25× | 1.5× |
| Veteran II | $8B | 1.50× | 2.0× |
| Veteran III | $64B | 1.75× | 2.5× |
| Veteran IV | $500B | 2.00× | 3.0× |
| Veteran V | $4T | 2.25× | 3.5× |
| Veteran N (N > 5) | previous × 8 | +0.25 per rank | +0.5 per rank |

Formulas:
- `RebirthCost(r) = 1e9 * 8^(r-1)` for the rank being bought (r ≥ 1). Clamp below `CurrencyLimits.MaxCoins` (2^53 − 1, about 9e15), which allows about 18 ranks; cap ranks at 15 for safety.
- `RebirthMultiplier(r) = 1 + 0.25 * r` (Merge a Nuke uses +25% per rebirth).
- `EnemyScale(r) = 1 + 0.5 * r`.

Put these in a new `Config.Rebirth` block so tuning never needs code changes:

```lua
Rebirth = {
	Enabled = true,
	MaxRank = 15,
	BaseCost = 1e9,
	CostGrowth = 8,
	EggBonusPerRank = 0.25,
	EnemyHealthPerRank = 0.5,
	EnemyDamagePerRank = 0.5,
},
```

### 6.4 What resets and what stays

Field by field, against `PlayerSession`:

| Saved field | On re-enlist | Reason |
|---|---|---|
| `coins` | Reset to the starting balance (`$2,400`) | Removes inflation; the cost already spent most of it |
| `eggSpeedLevel` (Egg Laying Speed track) | Reset to 0 | The main income ladder is what gets re-climbed |
| `incomeLevel` (Egg Value track) | Reset to 0 | Same |
| `luck` (Luck track) | Reset to 0 | Same; research rolling luck stays |
| `firstWins`, `frontierWins`, `laneCamps` | Reset to empty | The route is replayed at the new enemy strength |
| `kingCleared` | Reset to false | The King must be beaten again to re-enlist again |
| `kingBountyPaid` | Reset to false | The King's full bounty pays once per rank |
| Held territory flags (live, not saved) | Released, as if unclaimed | The war restarts |
| `eggCarry`, yard egg drops | Cleared | They belong to the old economy |
| `offlineCash` checkpoint | Reset to now | So offline cash follows the new, lower income |
| `pets` (species, level, Giant size, favorites) | **Kept** | Chickens are the collection players care about |
| `discovered` (Index) | Kept | Collection is permanent |
| `research` (completed, running jobs, formations, Operation wins) | Kept | Research becomes the long-term layer |
| `plotSizeLevel`, `rollSlotsUnlocked`, `capacity` (Army Size) | Kept | Infrastructure; resetting it feels like punishment |
| `promotion`, `recruitTier` | Kept | Only ever goes up (`PlayerSession` line 401) |
| `tutorial` | Kept | The guide must never replay |
| `hillWins`, `hillRollCredits`, `hillChampion` | Kept | Earned in PvP |
| Passes, `crateCredits`, `purchaseReceipts`, `robuxSpent` | Kept | Paid items are never reset |
| `adminAssisted` | Kept | Leaderboard integrity |
| **New:** `rebirths` | +1 | The rank |

**Decision for the owner (section 14):** keeping chicken levels keeps income high after a re-enlist, which makes the first ranks fast. The simulation in 6.9 decides whether the costs need to rise to compensate. Resetting chicken levels is possible but would anger players more than any other choice in this plan.

### 6.5 Where the multiplier and scaling apply

| Effect | Where | Code |
|---|---|---|
| Egg income × `RebirthMultiplier` | Every egg cash credit and the displayed income | `PlayerSession:EarnedAmount(amount, source)` at line 154: multiply when `source == "eggs"`. Add `PlayerSession:RebirthMultiplier()`. |
| Offline cash × `RebirthMultiplier` | Offline receipts | `OfflineCash.Rate(session)`: multiply the final rate. |
| Camp defenders × `EnemyScale` (health and damage) | Your own lane uses your rank; another player's lane uses that owner's rank | `BattleService`, where defenders are built from `Progression.Roster(...)` (around lines 295, 395 and 746): give each defender a `combatStats` table with `hp` and `damage` multiplied. `Battle.luau` line 25 already prefers `pet.combatStats` when present. |
| Chicken King × `EnemyScale` | The attacker's rank | `KingEncounter.luau` line 10 (`hp = 2800, damage = 32`): multiply by the attacker's scale. |
| Camp odds text | Prompt ObjectText ("Should win · …") | The odds already use `Rules.Power(roster)`; pass the scaled roster so the text stays honest. |
| Kill cash | Unchanged | Kill cash is small; leave it. |
| The Hill, Operations | Unchanged | They have their own tuning. |

### 6.6 Server action

Add a `Rebirth` action to the router in `src/server/GameServer.luau` (next to `Promote` at line 239). The work lives in a new `src/server/RebirthService.luau`:

```lua
-- RebirthService.Quote(session) -> {rank, nextRank, cost, canAfford, eligible, reason, multiplierNow, multiplierNext, scaleNext}
-- RebirthService.Rebirth(session, expectedRank) -> ok, message
```

`Rebirth` must:
1. Refuse unless the profile is loaded and saving normally (`session.loaded`, no `saveLost`, not closing), the same guard every transaction uses.
2. Refuse if `expectedRank ~= session.rebirths` (stops a double tap from re-enlisting twice).
3. Refuse unless `kingCleared` and `coins >= cost`, and the army is home (no outgoing battle and no Operation in progress).
4. Apply every reset in 6.4 in one non-yielding block, then `session.rebirths += 1`.
5. Release held territories through the existing unclaim path so other players' boards update.
6. Call `session:RefreshArmy()`, `session:Touch()`, `world:UpdateSession(session)` and request a save immediately.
7. Record analytics (6.8) and return "Re-enlisted as Veteran N".

### 6.7 Client UI

- **Entry point:** a "Re-enlist" hex in the Upgrades/Research screen, placed after the cash tracks, plus a HUD toast the first time the player becomes eligible ("You can re-enlist as Veteran I"). The hex shows the cost, the current and next multiplier, and a short "you keep / you reset" list.
- **Confirmation:** a dedicated panel with two columns: **Keep** (chickens, Giants, research, Index, plot, roll podiums, army size, passes) and **Reset** (cash, egg speed, egg value, luck, camps, King). The confirm button is hold-to-confirm for 2 seconds. Never use `confirm()`.
- **Rank display:** "Veteran II" under the player name on the HUD, on captured flags (next to the portrait) and in the leaderboard row.
- **After re-enlisting:** a short celebration (reuse the King-clear burst) and the Commander guide line "Your army is stronger. So are the camps. Retake Cluck Camp."
- Files: a new `src/client/RebirthPanel.luau`; hook the hex in `src/client/CashUpgradeNodes.luau`; the rank label in `src/client/HudController.luau`.

### 6.8 Analytics

Add to `AnalyticsSchema.luau`:
- Counters: `rebirth.count`, `rebirth.rank.<N>` (first time a player reaches rank N), `act.Rebirth`, `act.Rebirth.fail`.
- Histograms: `rebirth.playSeconds.<N>` (play time when rank N was reached), `rebirth.cashAtRebirth`.
- Funnel: add onboarding step **20 Rebirth1** after step 19 King, recorded once per player.
- Profile: `profile.rebirths`.

### 6.9 Tuning with the simulation

Before shipping, extend `tests/ProgressionSimulation.luau` to simulate a free player from fresh start to Veteran III with the current economy, keeping chickens and research. Targets:

| Milestone | Target play time |
|---|---|
| First King clear | 45 to 90 min (today's measured value; do not change) |
| Veteran I | 1.5 to 3 h |
| Veteran II | 4 to 8 h total |
| Veteran III | 10 to 20 h total |

If the first ranks come too fast (likely, because chicken levels are kept), raise `CostGrowth` or `BaseCost` rather than resetting chickens.

### 6.10 Save field

```lua
-- PlayerSession:Reset()
self.rebirths = 0
-- PlayerSession:ToData()
rebirths = self.rebirths,
-- PlayerSession:LoadData(data): additive, never rejects
local rebirths = data.rebirths
if type(rebirths) ~= "number" or rebirths ~= rebirths or rebirths < 0 or rebirths % 1 ~= 0 then rebirths = 0 end
self.rebirths = math.min(rebirths, Config.Rebirth.MaxRank)
```

Remember the old-server hazard (3.2): restart all servers when this ships.

### 6.11 Leaderboard

Add a third board in `src/server/LeaderboardService.luau`: **Top Veterans** (highest `rebirths`, ties broken by Strongest Army power). Same OrderedDataStore pattern, key `..._Global_Rebirths_v1`. Admin-assisted profiles stay excluded.

### 6.12 Tests (`tests/RebirthChecks.luau`)

- Cannot re-enlist without a King clear, without enough cash, with the army away, or with a stale `expectedRank`.
- A successful re-enlist resets exactly the "Reset" rows in 6.4 and keeps exactly the "Kept" rows (compare full `ToData()` snapshots).
- The egg multiplier applies to deposits, displayed income and offline cash, and not to cash packs or chicken sales.
- Defenders on your lane use your scale; on another player's lane they use that owner's scale; the King uses the attacker's.
- Save/load round trip keeps `rebirths`; junk values load as 0; a profile with no field loads as 0.
- The tutorial never restarts after re-enlisting.
- Double tap: two `Rebirth` requests with the same `expectedRank` re-enlist once.

### 6.13 Done when

- At least 30% of players who beat the King re-enlist at least once (`rebirth.rank.1` against `onb.reach.19`).
- Median play time from King clear to Veteran I between 30 min and 2 h.
- `econ.balanceAtLeave` p90 drops below $10B.

---

## 7. Phase 1C: 7-day login streak

**ID:** D1. **Effort:** half a day. **Save impact:** one new additive field.

### Why

The only return trigger today is offline cash. 1 of 7 friends came back the next day. Merge a Nuke runs a 30-day daily reward; a 7-day loop is enough to start.

### Rules

- A "day" is a UTC day: `day = math.floor(os.time() / 86400)`. Server time only; the client never decides.
- On profile load (after the offline receipt is resolved), and again at the UTC day boundary for players who stay online:
  - If `daily.lastDay == today`: nothing.
  - If `daily.lastDay == today - 1`: `daily.streak += 1`.
  - Otherwise: `daily.streak = 1`.
  - Set `daily.lastDay = today` and grant the reward for `slot = ((daily.streak - 1) % 7) + 1`.
- `daily.best` keeps the longest streak, for display.

### Rewards

Cash rewards scale with the player's own income so they matter at every stage. `income` is `PlayerSession:Income()` per second including multipliers, with a floor of $10 per second so a new player still gets a useful amount.

| Day | Reward |
|---|---|
| 1 | 5 minutes of income |
| 2 | 10 minutes of income |
| 3 | 1 free lever roll (`hillRollCredits += 1`) |
| 4 | 20 minutes of income |
| 5 | 30 minutes of income |
| 6 | 2 free lever rolls |
| 7 | 60 minutes of income and 3 free lever rolls |

Free rolls reuse the Hill credit path (`HillService` line 117 already turns `hillRollCredits` into recruits when there is room). Do not grant Galaxy Crate credits: they are a paid random item with disclosed odds.

### Code

| File | Change |
|---|---|
| `src/server/DailyService.luau` (new) | `Check(session, now)`, `Grant(session, slot)`, day math, analytics. |
| `src/server/GameServer.luau` | Call `DailyService.Check` after a successful load and once per minute for online players (cheap; it exits early on the same day). |
| `src/server/PlayerSession.luau` | `daily = {streak = 0, lastDay = 0, best = 0}` in `Reset`, written in `ToData`, read in `LoadData` with every value clamped to an integer ≥ 0 and any junk replaced by the default. |
| `src/client/DailyRewardController.luau` (new) | A popup modeled on `OfflineCashController.luau`: a row of 7 days, today highlighted, the reward amount, one "Claim" button (the server has already granted it; the button only closes the popup and plays the effect). Shown after the offline receipt, never on top of it. |
| `src/server/AnalyticsSchema.luau` | `daily.claim.<1..7>`, `daily.streak` (count histogram), `daily.reset` (streak broken). |

### Tests (`tests/DailyChecks.luau`)

Same-day rejoin grants nothing; consecutive days advance; a missed day resets to 1; day 8 grants the day 1 reward; junk saved values load as defaults; rewards scale with income and respect the cash cap.

### Done when

D1 retention of the first post-release cohort is above the pre-release 1 of 7 (14%). With so few players, read it as a direction only.

---

## 8. Phase 1D: Halloween event

**ID:** H1. **Effort:** 1 day of code plus the chicken model. **Save impact:** a new catalog species (safe). **Deadline:** must be live before October 31, 2026 to be worth doing.

### Why

Every game in this week's Top Trending and Top Playing rows has a pumpkin in its title or icon. A small limited event is timely, gives players a reason to log in this week, and needs no new systems.

### Content

1. **Pumpkin Chicken**, a limited Epic-band chicken (same stats as Magma Chicken's band, `baseSpecies` Knight), with a pumpkin head. Display name "Pumpkin Chicken".
2. **Where it comes from:** while the event runs, each podium in a lever pull has a 2% chance to offer a Pumpkin Chicken instead of its normal draw. It is bought with cash like any offer.
3. **After the event:** the species stays owned forever and shows in the Index as "Limited (Halloween 2026)". It can no longer be rolled.
4. **Look:** pumpkins and orange lights around plots and camps (extend `tools/map/MapDecor.luau` with a pumpkin prop and a `Halloween` toggle), and a dusk lighting preset.
5. **Title and thumbnail:** rename to "[🎃] My Chicken Army" for the event and add one Halloween thumbnail. Rename back afterwards.

### Code

| File | Change |
|---|---|
| `src/shared/PetCatalog.luau` | Add `Pumpkin = {name = "Pumpkin Chicken", baseSpecies = "Knight", rarity = "Epic", weight = 0, limited = "Halloween2026", ...}`. Weight 0 keeps it out of normal odds, the same way crate-only chickens work. |
| `src/shared/Config.luau` | `Event = {Id = "Halloween2026", StartsAt = <unix>, EndsAt = <unix Nov 1 00:00 UTC>, Species = "Pumpkin", OfferChance = 0.02}`. |
| `src/server/RollService.luau` `Roll` | After each slot's normal draw, if the event is active and `rng:NextNumber() < OfferChance`, replace the species with the event species. Never on the starter roll, never on the forced first slot. |
| Odds display (Research / Details) | Show "Pumpkin Chicken: 2% per podium (event)" while active, so the odds stay disclosed. |
| Index UI | A "Limited" tag for species with `limited`. |
| Studio | The chicken model and texture (the art pipeline used for the other chickens). |

**Save safety:** adding a species is safe. If the species is ever removed from the catalog, the existing `unrecognizedPets` path keeps the raw entry and writes it back unchanged.

### Tests

Event off: the Pumpkin Chicken never appears in 10,000 simulated rolls. Event on: appears at about 2% per podium. A saved Pumpkin Chicken loads and saves after the event ends.

---

## 9. Phase 2A: mutations

**ID:** M1. **Effort:** 2 to 3 days plus VFX. **Save impact:** a new optional field on each chicken.

### Why

With Luck upgrades, Mythics stopped being rare: 3.6% of all offers, against 0.06% at base, and players bought 357 of them. The chase is over once a player owns the top tier. Steal An Egg and Merge a Nuke both use mutations as the long chase: a rare variant on top of any unit that multiplies its output and looks different. Merge a Nuke unlocks better mutation tiers through rebirth ranks, which ties M1 to R1.

### Mutation table

| Mutation | Egg production | Chance per offered chicken | Unlocks at |
|---|---|---|---|
| Golden | × 1.5 | 1 in 40 | Start |
| Rainbow | × 2 | 1 in 200 | Veteran I |
| Shadow | × 3 | 1 in 1,000 | Veteran III |
| Cosmic | × 5 | 1 in 5,000 | Veteran V |

- Mutations affect **egg production only**, never combat, so they cannot unbalance camps, the Hill or future raids.
- A mutation is rolled independently of species and Luck. Luck does not change mutation chances (keeps the odds simple to disclose).
- Galaxy Crate rewards never carry mutations (the paid pool's odds stay exactly as disclosed).

### Fusion rule

Fusion still needs three chickens of the same species, stars and level. Mutations do not need to match. The Giant takes the **best** mutation among its three inputs. This makes a Golden chicken worth fusing around and gives fusion a second purpose.

### Code

| File | Change |
|---|---|
| `src/shared/MutationCatalog.luau` (new) | The table above, `Order`, `Multiplier(id)`, `IsValid(id)`, `UnlockedFor(rebirths)`. |
| `src/server/RollService.luau` | Each offer gets `mutation` from `MutationCatalog.Roll(rng, session.rebirths)`; the offer price stays the species price. |
| `src/server/PlayerSession.luau` `AddPet` | Accept an optional mutation and store `pet.mutation`. |
| `src/server/PlayerSession.luau` `ToData` (line 524) | Write `mutation = pet.mutation`. |
| `src/server/PlayerSession.luau` `LoadData` (line 760) | Read `mutation`; if present but invalid, **drop it and keep the chicken**. Never reject the profile. |
| `src/server/PlayerSession.luau` `PetIncome` (line 349) and `DisplayedPetIncome` | Multiply by `MutationCatalog.Multiplier(pet.mutation)`. |
| `src/server/OfflineCash.luau` `Rate` | Include the multiplier in eggs per second. |
| `src/server/EggService.luau` `Lay` | Production follows `PetIncome`; check the yard drop count still respects `EggMaxDrops`. |
| `src/server/ArmyService.luau` fusion | Result mutation = best input mutation. |
| Client roll reveal, Index, My Army, Fuse picker | A mutation badge and a visual (gold shimmer, rainbow tint, dark aura, star particles) through `SpecialChickenVFX.luau`. |
| `src/server/AnalyticsSchema.luau` | `mutation.offer.<id>`, `mutation.buy.<id>`, `mutation.fuse.<id>`. |

**Old-server hazard (3.2) applies here more than anywhere:** an old server rebuilds every pet without `mutation` and erases it. Restart all servers on release.

### Tests (`tests/MutationChecks.luau`)

Odds within tolerance over 100,000 simulated offers; locked mutations never roll below their rank; fusion picks the best input; save round trip keeps mutations; an unknown mutation id loads as no mutation and keeps the chicken; income and offline cash include the multiplier; crates never carry a mutation.

---

## 10. Phase 2B: yard raids

**ID:** X1. **Effort:** 1 to 2 weeks. **Save impact:** a new optional field for shield time. **This is the change most likely to transform the game, and it carries the most design risk.**

### 10.1 Why

- **The #1 game on Roblox is Steal An Egg** (909K players and 8.0B visits on Oct 14, live since Jul 25). Steal a Brainrot is at 103K and Break and Steal an Egg at 99K. Your theme is eggs, but your home yards can never be touched.
- **It removes the solved strategy.** Opponents are real players whose armies keep growing.
- **It is a sink that does not feed inflation.** Stolen eggs leave the victim's yard without raising anyone's income.
- **It creates reasons to log in:** protecting your yard and taking revenge.
- **It creates a natural product,** the yard shield.
- **It is a twist, not a copy.** Roblox deprioritizes experiences that resemble existing ones (Tizzy, Video 10, 3:02). Every steal game has one player running in to grab something; here a whole army marches in. That keeps the army fantasy that makes this game different.

### 10.2 Rules (version 1: eggs only)

| Rule | Value | Why |
|---|---|---|
| Who can raid | Players who finished the Commander guide and beat Cluck Camp | New players learn the game first |
| Who can be raided | Online players in the same server who finished the guide and have at least 15 minutes of total play | Protects brand-new players |
| What is taken | Up to **20%** of the total value of uncollected eggs lying in the target's yard | Collecting often is the main defense, which makes the Auto Collect pass a defense too |
| Per-victim cooldown | The same attacker cannot raid the same victim again for **10 minutes** | No farming one player |
| After being raided | The victim gets a free **5-minute shield** | No pile-ons |
| After joining | Every player gets a free **10-minute shield** | Time to settle in |
| Revenge | For 5 minutes after being raided, the victim can raid the attacker back, ignoring the attacker's shield | Turns losses into a comeback story |
| Offline players | Cannot be raided. When a player leaves, their yard leaves with them, as in Steal a Brainrot | No losses while away |
| 2x Cash, rebirth multiplier | **Not applied** to stolen eggs | Passes must not amplify theft |

### 10.3 The raid itself

1. **Target:** a new target kind `yard:P` (P = plot index) next to the existing `camp:P:N` ids in `src/shared/CampaignRoute.luau`. Other players' yard gates get a "Raid" prompt with the same odds text as camps ("Close fight · 8 defenders · ~$1.2M in the yard").
2. **March:** the selected army marches using the existing route and travel code.
3. **Defense:** the victim's **home** chickens defend: the strongest chickens not deployed, up to the victim's army capacity, with their real combat stats (`Battle.luau` already builds units from pet records). The victim can also use Call Army to bring their deployed army home to help.
4. **Loot meter:** once the defenders are down, a 10-second loot meter fills (reuse the conquest meter UI, gold instead of red). If the victim's defenders recover or reinforcements arrive and win, the raid fails.
5. **Carry home:** on success the stolen egg drops are removed from the victim's yard (`EggService`), the army marches home carrying eggs (a visual egg on each chicken), and the value is credited to the attacker on arrival with a new cash source `raid`.
6. **Failure:** the army recovers exactly as after a lost camp fight.

### 10.4 Shield

- **Live field:** `session.shieldUntil` (server time).
- **Saved field:** `shield = {paidSecondsLeft = N}`. Only paid shield time survives a rejoin; free shields do not need saving.
- **Products** (new developer products; prices to test):

| Product | Robux | Effect |
|---|---|---|
| Yard Shield 30 min | 29 | +30 min of shield, stacking |
| Yard Shield 2 h | 79 | +2 h |
| Yard Shield 24 h | 249 | +24 h of real time; covers every session in that window |

Tizzy reports a 24-hour base lock became his top-selling product within days (Video 08, 4:30). The shield ticks down in real time even while the player is offline, so "24 h" means a day of protection, not 24 hours of play.

- A visible bubble over the protected yard, and a HUD timer for the owner.
- Raiding someone breaks your own **free** shield (so you cannot hide behind it while attacking) but not a paid one.

### 10.5 Private servers

Turn on free private servers (Creator Dashboard → Places → Access → Private Servers, price 0). Players who want to farm in peace can play with friends. Tizzy made private servers free for exactly this reason (Video 03, 9:00).

### 10.6 Code

| File | Change |
|---|---|
| `src/server/RaidService.luau` (new) | Eligibility, shields, cooldowns, revenge window, loot calculation, crediting, analytics. |
| `src/server/BattleService.luau` | New target kind `yard`; defenders built from the victim's home pets; loot meter instead of the conquest meter; no flags and no hold bonus for yards. |
| `src/shared/CampaignRoute.luau` | Parse and build `yard:P`. |
| `src/server/EggService.luau` | `EggService:Steal(victimSession, share) -> value`: removes the newest drops until the share is reached, never touching carried eggs or banked value. |
| `src/server/PlayerSession.luau` | `shieldUntil` (live) and `shield.paidSecondsLeft` (saved, additive, junk loads as 0). |
| `src/server/ProductService.luau` | Deliver shield products (additive, receipt-safe like coins). |
| `src/shared/ShopCatalog.luau` | Shield product definitions. |
| `src/client/BaseController.luau` | Raid prompt on other yards with odds and the shield state. |
| `src/client/HudController.luau` | "Stev is raiding your yard!" alert with an arrow and a Call Army shortcut; the revenge button; the shield timer. |
| `src/server/AnalyticsSchema.luau` | `raid.attempt`, `raid.win`, `raid.fail`, `raid.stolen` (cash), `raid.defended`, `raid.revenge`, `shield.free`, `shield.paid.<product>`. |
| `tutorial` | One Commander line after Cluck Camp: "Other commanders can raid your yard. Collect your eggs often." No new guide step. |

### 10.7 Version 2 (only after version 1 proves out)

**Chicken capture:** a successful raid can carry off **one reserve chicken** (never a favorite, never deployed, never the victim's only Mythic), shown as "captured" in the victim's Army menu. The victim has 10 minutes to win it back by raiding the captor; otherwise it moves to the captor. This is the "my pet got stolen" emotional hook the steal genre runs on (Tizzy, Video 01, 6:00: showing a pet get stolen in the opening creates attachment). It is also the riskiest change for young players, so it waits until version 1 data looks healthy.

### 10.8 Tests (`tests/RaidChecks.luau`)

Eligibility and protection for new players; per-victim cooldown; shields block raids and break correctly; revenge ignores the attacker's shield; loot never exceeds 20% of yard value and never touches carried or banked cash; 2x Cash and the rebirth multiplier do not apply to raid cash; leaving mid-raid ends it cleanly for both sides; paid shield time saves and loads; junk shield data loads as 0.

### 10.9 Done when

- At least 40% of players who beat Cluck Camp try a raid in their first two sessions.
- D1 and D7 retention rise compared with the pre-raid cohort, and session length does not drop for players who were raided (watch `raid.defended` against `raid.win`).
- Shield products sell. If nobody buys them, raids are not felt as a threat and the share can rise.

**Tuning knobs, all in a `Config.Raids` block:** share (20%), cooldowns, shield lengths, minimum play time for targets, loot meter seconds.

---

## 11. What is deliberately not changing

| Kept as it is | Why |
|---|---|
| **Research timers** (except S16 and S17 in O1) | Long timers work once players have something to do while waiting (Mini War runs nodes up to 120 h). Rebirth and raids provide that. |
| **The Commander guide** | 8 of 8 finish it, median at most 3 minutes. Only one raid line is added. |
| **The intro cutscene** | 5 of 8 skipped it, which is fine; it does not block anyone. |
| **Fusion rules and Giant sizes** | The strongest system in the game. Mutations build on it. |
| **Camp rosters at rank 0** | First-session pacing is measured and good; rebirth scaling only applies from Veteran I. |
| **Thumbnails** | Both read clearly. Add an event thumbnail for H1 and a raid thumbnail for X1. |
| **Research costs** | Rebirth resets cash, so research prices matter again in every run. |

---

## 12. Release and rollout checklist

For every phase:

1. All new and existing tests pass in Studio Edit mode (`PersistenceChecks`, `ProgressionSimulation`, the feature's own checks).
2. A Studio playtest with `PetRollPlaytestSessionOnly=true` (disposable session) walks through the feature on desktop and in the phone emulator.
3. Back up: note the current place version in Creator Dashboard → Places → Version History so you can roll back.
4. Publish from Studio.
5. **Restart all servers** (section 3.2) whenever the phase adds a saved field.
6. Within the first hour, check the analytics ledger: `health.loadFailures` must stay 0; the new events must appear; `topRejections` must not show a new error.
7. If anything breaks saves: roll back to the noted place version and restart servers. Additive fields mean a rollback loses only the new feature's data, never existing progress.

Suggested calendar:

| When | Ship |
|---|---|
| Today | Phase 0 (P0.1 to P0.7) |
| Day 1 to 2 | O1, then the trailer upload to YouTube and the game page |
| Day 3 to 5 | R1 rebirth (after the admin work is committed) |
| Day 5 to 6 | D1 streak |
| By Oct 24 | H1 Halloween (needs the model early) |
| Weeks 2 to 3 | M1 mutations, then X1 raids version 1 |

---

## 13. How to tell it worked

Compare cohorts that joined before and after each phase (`Report.Summary({version = ...})` or by date range). Wait for at least 100 non-friend new players per comparison before trusting retention.

| Question | Metric | Today |
|---|---|---|
| Do players come back? | `ret.d1`, `ret.d7` by cohort | 1 of 7 (D1) |
| Is there life after the King? | `feature.first.Operations`, funnel step 20 Rebirth1 | 0 Operations |
| Does cash still mean something? | `econ.balanceAtLeave` p90; research share of `econ.sinkTotal` | p90 over $10M; research 0.02% of sinks |
| Do the passes sell now? | `shop.prompt.<key>` against `robux.pass.<key>` | Only 3 passes sellable |
| Is the chase alive? | `mutation.offer.*`, `roll.offer.Mythic` share | Mythic 3.6% of offers |
| Are raids healthy? | `raid.win`, `raid.defended`, `shield.paid.*`, session length of raided players | Not built |
| Are phone players staying? | `session.seconds|Mobile` against `|Desktop` | Median ≤10 min against ≤30 min |

---

## 14. Decisions the owner still needs to make

1. **Rebirth: keep or reset chicken levels?** This plan keeps them. Resetting makes the loop longer but risks anger.
2. **Rebirth costs:** confirm the table in 6.3 after the simulation.
3. **Re-enlist name and rank titles:** "Re-enlist" and "Veteran I, II, III" are suggestions.
4. **Crate price test:** 149 / 399 / 1,199, or another ladder.
5. **Halloween:** is a Pumpkin Chicken model possible by about Oct 22? If not, skip H1 and spend the time on R1.
6. **Raids:** go or no-go on version 1 (eggs only), and whether version 2 (chicken capture) is ever acceptable for your audience.
7. **Weekly update day:** only promise one in the description if it will be kept.

---

## 15. Sources

- **Your data:** analytics ledger `AnalyticsReport.Summary({days = 7, env = "live"})` pulled Oct 14, 2026; read-only scan of all 9 live saves (`DuckArmy_Pond_v2`); repository source at commit `5777ea7` plus the working tree.
- **Roblox platform:** public APIs read Oct 14, 2026 (games, votes, icons, thumbnails, game passes, developer products, explore charts, search).
- **Fan wikis (unverified):** TechWiser and Sportskeeda (Mini War research tree), gcz.gg and mergeanuke.cc (Merge a Nuke rebirth), games.gg, TechWiser and allthings.how (Steal An Egg mutations), industry.co.id (October 2026 trends).
- **Creator claims (Tizzy RBLX transcripts):** Video 01 [FnsIL4zPCQg] 6:00 and 13:31; Video 02 [LZOohZHsJus] 16:01; Video 03 [nggNvUILQ1I] 7:32 and 9:00; Video 08 [zoz3PSMqets] 4:30 to 6:00; Video 10 [dUmh6GAvJ-E] 3:02 and 10:01. One creator's claims about his own games, not rules.
