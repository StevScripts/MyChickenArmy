# Early economy: starter prices, Rebirth 0 keeps the tree, Army Size I 300 (October 27, 2026)

Retention package WS2. Plan and evidence: `docs/team/retention-20261027/WS2-early-economy.md`
(§9 is the combined check that set the final numbers); integration:
`docs/team/RETENTION_PLAN_20261027.md` (§3 C2, §4, §5).

The problem, from the Oct 26–27 ledger: after the tutorial the next Commons cost 1,900–3,000
against 4–18 Coins/s, 46% of Buy attempts failed for Coins, Rebirth 0 silently took back the
Egg Vacuum and Flock Size I, and a 3-slot Army could not reach Fort Roost. A typical new player
made a meaningful purchase every 69 s before minute 10 and was at 56 Coins/s at minute 10.

## The rules

| Change | Setting | Switch back |
|---|---|---|
| **Starter prices.** Empty-start profiles (`introRebirth ~= nil`) see every podium offer except the free starter roll and the tutorial ladder at `Rules.StarterPrice(list, owned)`: 25% of the catalog quote while they own 2 chickens, rising linearly to 100% at 20, rounded up to 5 Coins, never below 150 or above the catalog. The catalog (prices, income, `valueOneIn`) is untouched; this is the podium's quote, like `StarterLadder`. Prices stay whole and strictly rising along the odds order (`tests/StarterPriceChecks`). | `Config.Economy.StarterPrices = {Enabled, Fraction=0.25, FullAt=20, Floor=150, Step=5}` | `Enabled = false` |
| **Rebirth 0 keeps the Upgrades tree and Feed levels.** It still costs 1,700, sets Coins to 0, empties carried eggs and vacuum cargo, resets Gold roll counts, releases camps, pays +30 Gems and x1.5. Ranks 1–50 still reset the run. | `Config.Rebirth.Intro.KeepTree = true` | `false` (the Oct 23 reset) |
| **Army Size I costs 300** (was 1,200). II stays 6,000 (lead, combined check); III 25,000, IV 90,000. Flat for every rank; tier meaning unchanged, so no `TreeMigrations` step. | `UpgradeCatalog` `ArmySize` tiers | the one number |
| **"+N Coins/s" float.** A Coins purchase that raised steady income floats a gold "+N Coins/s" over the HUD Coins readout (summed, at most one a second, never negative, no sound). | the AppController hook | remove the hook line |

Example quotes at 2 owned chickens: Chicken 150 (floor = catalog), Rooster 475 (list 1,900),
Rubber Ducky 500, Bonsai 750, Bee 850, Lollipop 1,125. At 8 owned 50%, at 14 owned 75%, from
20 owned the list price. A sale refunds 50% of the price paid (`investment` is the price), so
nothing can be minted. Rebirth finds and event offers use the same quote; WS3's `needCoins`
follows the offer price automatically.

## Where it lives

| File | What |
|---|---|
| `src/shared/Rules.luau` | `Rules.StarterPrice(listPrice, owned)` (pure; Wave 0) |
| `src/shared/UpgradeCatalog.luau` | Army Size I 300 |
| `src/server/RebirthService.luau` | `RebirthIntro` skips `keptTree` and `resetFeedLevels` when `KeepTree`; `introQuote` carries `keepTree` and the short `resets`/`keeps` lists |
| `src/client/RebirthPanel.luau` | Rebirth 0 keep tile "Chickens & Upgrades", warning "You will lose all your Coins!" (both only when `quote.keepTree`) |
| `src/server/GameServer.luau` | replies to `Buy`, `BuyUpgrade`, `FeedChicken`, `UpgradeChicken`, `RebirthIntro`, `Expand`, `Income`, `Luck` that spent Coins carry `income = {before, after}` (whole steady Coins/s, `DailyService.SteadyIncome`); `econ.*` analytics |
| `src/client/ActionFeedback.luau` | `Feedback:IncomeGain(before, after)` (`UIMotion` Float from `hud.cashReadout`) |
| `src/client/AppController.luau` | one hook in the result block |
| `src/server/RollService.luau`, `src/server/RollStation.luau` | **WS4 applies these** (below) |

### The podium hunks (WS4 applies them in its files)

1. `RollService:Roll`, the offer's price: `list = Rules.RecruitPrice(species, level)`;
   `price = starter and StarterRecruitPrice or (slot == 1 and ladder) and ladder.price or
   (session.introRebirth ~= nil) and Rules.StarterPrice(list, session:Count()) or list`; the
   offer carries `listPrice = list` only when `price < list` and it is neither the starter nor
   the ladder step.
2. `RollService:Buy` charges `offer.price` as today and returns `listPrice` (and `price`) in the
   receipt's `offer` table: `GameServer:CountRecruit` counts `econ.starterRecruit` and
   `econ.starterSaved` from them.
3. Storage receipt: a recruit that neither lays nor joins the Army reads "In storage. Grow your
   Flock in Upgrades so it lays eggs." while a next Flock tier exists, else "In storage."
4. `RollStation`: a third `PriceRow` label "ListPrice" (RichText, ~20 px, muted grey, same
   stroke) shows `<s>1,900</s>` after the gold starter price when `offer.listPrice > price`;
   cleared while rolling, idle and on Clear. The buy prompt stays "Buy Rooster · 475 Coins".
   No "Sale", "FREE" or "%".

Until WS4 merges, `tests/ProgressionSimulation` and `tools/sim/first_session_probe.luau` apply
the same quote to any offer still at its list price, so both stay right before and after.

## Analytics (Schema 16, observation only)

Empty-start profiles in their first 20 minutes of play: `econ.buyGap.early|mid` (seconds since
the previous Coins purchase, ≤600 s / 600–1,200 s of play), `econ.rate.m5|m10|m20` (steady
Coins/s when play first passes 5/10/20 min, recorded only by the session that crossed it),
`econ.buys.m10` (Coins purchases by 10 min, from a session that began in the first minute);
`econ.starterRecruit` / `econ.starterSaved` (counters, from the recruit receipt once WS4 carries
`listPrice`). Session-only fields `econLastBuyAt`, `econBuys`, `econMarks`; nothing is saved.

Targets (plan §5.3): `econ.buyGap.early` p50 ≤ 60 s, `econ.rate.m10` p50 ≥ the 80 bucket,
`econ.buys.m10` p50 ≥ 8, failed podium Buys 46% → ≤ 25% (with WS3), Recruited10/Recruited 16% →
≥ 30%.

## Simulations

`tools/sim/first_session_probe.luau` (30 seeds, 30 min, live settings plus a WS4 Lucky Start
approximation until `LuckyStart.luau` exists):

| Profile | First Fort Roost win p50 / p90 | Coins/s at 5 / 10 min | Power at 5 / 10 | Purchase gap before min 10 |
|---|---|---|---|---|
| Pre-package build (`starter=false keepTree=false strength=1 favoredSpec=5x0.6 tree=ArmySize:1:1200 guided=false lucky=false`) | 28.6 (17/30) / never | 18 / 56 | 38 / 44 | 69 s |
| Typical, follows the readiness card | **8.2 / 10.1** | 38 / 153 | 68 / 106 | 48 s |
| Typical, ignores it (`guided=false`) | 9.1 / 12.4 | 48 / 170 | 55 / 94 | 48 s |
| Engaged | 7.4 / 8.7 | 34 / 435 | 64 / 126 | 23 s |

Army Size I is bought at minute 2.7 (guided) / 5.1 (unguided), was 15.1.

`tests/ProgressionSimulation` (16 seeds, played minutes, medians). Its camps now fight at
`Config.CampLadder.Strength` and it attacks at explicit ratios (`campRatio = 1.3`, `missionRatio
= 2.0`, the old band edges, WS1 §6.1):

| Rebirth | Fast: before (plan §9.4) → package | Casual: before (plan §9.4) → package |
|---|---|---|
| 1 | 12.2 → 11.5 (−6%) | 13.5 → 13.9 (+3%) |
| 5 | 67.2 → 63.4 (−6%) | 72.5 → 71.8 (−1%) |
| 10 | 188.5 → 185.0 (−2%) | 190.7 → 189.1 (−1%) |

With `campRatio = 1.0 missionRatio = 1.3` (attacking at the new bands' edges, as the plan's §9.4
run did) the package reproduces §9.4 exactly: fast 10.1 / 60.6 / 185.2, casual 11.7 / 69.2 /
193.1. Without Lucky Start (this branch alone): fast 11.0 / 61.5 / 183.3, casual 12.2 / 71.0 /
191.0. Every rank stays inside the fit's ±7%; no Rebirth cost re-fit.

Re-run both before changing any of these numbers:

```bash
cd tools/sim && ./lune run harness.luau ../.. first_session_probe.luau profile=typical
cd tools/sim && ./lune run harness.luau ../.. first_session_probe.luau profile=engaged
```

**Live rule (plan §4):** if the median first Fort Roost win comes before minute 8, Fort Roost
strength goes to 0.70; after minute 13, to 0.50. If Rebirth 1 should come later,
`StarterPrices.FullAt = 15` gives back about a minute.
