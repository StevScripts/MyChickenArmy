# Upgrade eligibility — no camp prerequisites

**October 6 plot parity:** all six authored home plots now have Plot1's
square-to-T yard/fence expansion, matching deck and eight roll podiums.
This replaces the earlier single-podium and uniform-expansion limits on
Plots2–6. Physical support is now the same on all six plots; purchased levels,
Roll Slot ownership, prices and server checks are unchanged. Authored
structural readback and runtime facility inspection passed, and a full local
place copy is saved. See [plot parity](team/PLOT_PARITY.md) for verification scope.

**October 4 starter-army protection:** fresh profiles begin with three free
level-1 `Duck` chickens, $2,400 and three deployment slots. The first free roll
guarantees the fourth level-1 chicken for $600. The server reserves that $600
until recruited and another $1,200 until effective army capacity reaches four.
The recruit and Army Size purchases may consume their respective reserves in
either order; other cash spending must leave the remaining reserve intact.
Neither purchase requires a guide step, camp or rank. Completing the guide
releases any remaining protection; skipping or rejoining does not. The guide
teaches egg collection/selling once before expansion, selection and deployment,
without requiring repeated funding trips. Existing saves retain their flock,
cash and cohort; legacy `emptyStart` saves keep their $600 first-recruit safeguard
without receiving the new free squad. See [the starter contract](team/COMMANDER_TUTORIAL.md).

**September 29 direction:** egg deposits now pay immediately with the existing Money
effect. Timed processing, Selling Speed and Finish Now are archived. Saved egg
balances, seller levels and paid finish credits remain compatible. This supersedes
the September 27–28 processing requirements. See [instant sales and restoration](team/INSTANT_EGG_SALES.md).

Current user direction, 25 September 2026: **Players can keep buying available upgrades whenever they can afford them. No upgrade requires visiting, attacking, conquering or unlocking a camp, earning a conquest rank, or progressing toward the King.**

The September 26 [egg quantity economy](EGG_ECONOMY.md) preserves this rule, all
upgrade counts and prices. Egg Value now sets one shared unit value and rarity
changes egg quantity. Selling Speed's throughput curve was initially retuned for
larger quantities. September 27
clarification explicitly retains this track and rejects instant sales. The later
September 27 instruction removes Selling Speed's maximum. September 28 replaces
the large opening purchases with gradual additions at every level: 4 / 5 / 6 /
7 / 8 / 9 / 11 / ... eggs/sec, with exponentially growing prices from $40.
No rebirth requirement or camp prerequisite is introduced.

The current price is ceil(40 * 1.20^level), and the added throughput is rounded
1.10^level. This supersedes the September 27 capacity-adjusted price curve.
Prices do not flatten at $1 trillion. CurrencyLimits defines the expanded
exact-integer wallet boundary. This remaining representation limit is explicit,
not a designed Selling Speed MAX tier; see the [current progression contract](team/GRADUAL_SELLING_SPEED.md).

This supersedes older documents, research proposals, screenshots, fixtures and code that attach upgrade availability to `promotion`, `firstWins`, `frontierWins`, rank capacity caps or `RollSlotRanks`. Do not restore those restrictions when updating UI, balancing the economy, rebuilding a board, or implementing feedback.

## What is available

The following existing cash tracks are independent of camp progress from the start:

- Individual chickens: cash purchases in My Army through level 10, when the owned chicken is home and affordable. Preserve existing egg/combat level rewards. Current triple fusion remains separate; see [chicken cash upgrades](team/CHICKEN_CASH_UPGRADES.md).
- Egg Speed: 25 purchases, up to 4.75× production before paid benefits. The first four prices and benefits are unchanged.
- Egg Value: 25 purchases, setting each newly earned egg to $4 + level (maximum $29). Already-earned eggs keep their value.
- Plot Size: seven purchases where the authored plot supports expansion, with capacities 25/30/35/40/45/50/75/100. The September 29 shape starts as a 30×30 square, extends its center, then widens behind the machines into a T (30×49 stem plus 84×45 back section). Only the final two stages gain depth after the user's deck enlargement; the authored square anchors all stages. Its outer fence also expands; the editor shows the square starter. All six authored plots use this shape as of October 6, superseding Plots2–6's earlier 80–120% uniform scaling. Prices and saved levels are unchanged; see [square-to-T expansion](team/SQUARE_TO_T_PLOT_EXPANSION.md).
- Army Size: every configured purchase from three to ten base deployment slots. Bigger Army remains an additional five slots.
- Luck: 20 purchases. The first four prices/bonuses are unchanged; later levels add 0.10 to Rare+ weights, reaching 4× weights (not 4× normalized probability).
- Roll Slots: seven cash purchases unlock one through eight podiums as of September 29, capped by the number physically authored for the assigned plot. The user's target is all eight in roughly 8–9 active F2P hours; initial tuning models 8.47 hours for its reference policy, not a guaranteed or measured player duration. All six authored plots have eight stands as of October 6; saved ownership still determines unlocked stands. See [eight podiums](team/EIGHT_ROLL_PODIUMS.md).
- Selling Speed: archived September 29. Its saved levels and former unlimited curve are preserved for restoration; there is no current purchase offer.

The September 25 change removed **camp prerequisites**, not track maxima. Later
September 27 requests separately removed Selling Speed's maximum and authorized
the reviewed capped board extension. Speed/Value extension prices grow 1.35× per
purchase, Luck 1.25×, rounded upward to whole thousands after the opening four.
September 29 Roll Slot purchases cost $1,200 / $4,800 / $120,000 / $6,000,000 /
$150,000,000 / $300,000,000 / $500,000,000. The former $600M sixth slot is superseded;
already-owned slots are retained. Army prices and paid benefits are unchanged.
See [the review and implementation record](team/UPGRADE_BOARD_PROGRESSION.md).
The smaller 25-capacity starting plot and one-time save conversion were subsequently
approved. Revision 11 maps old plot levels 0–4 to 3–7, preserving owned chickens
and next price. The later September 29 change increases the last two levels to
75/100 without another conversion. New profiles start at level zero. The first three prices
are $480 / $1,200 / $2,400, followed by the four unchanged existing prices.

## October 2 location change

The six world-board tracks now live as immediate cash purchases in the full-screen
upgrade tree. The physical board is archived. No research prerequisite, research
timer or researcher slot is added to these tracks. All prices, saved levels and
maxima remain unchanged. See [cash upgrades in the tree](team/CASH_UPGRADES_IN_TREE.md).

## Checks that remain

Keep server authority over loaded/closing/save-lost state, sufficient cash, existing track maxima, valid expected level/price, and actual plot/podium support. These purchases are now global; the retired board’s proximity/ownership check no longer applies. A missing authored capability is different from a camp requirement. UI must display the server's current offer and must not add a separate local rank lock.

Camp-route prerequisites, King access, rank milestones, existing combat encounters and rewards remain separate progression systems. The no-camp-upgrade change did not itself enable merging. The user subsequently authorized manual three-chicken merging on September 25; its separate existing progression rules are documented in `MERGING.md`. Historical rank metadata in Progression is not an instruction to gate cash upgrades.

Removing camp gates did not require a migration or refund/reset. The separately approved revision-11 plot conversion changes plot level numbers only; earned capacity, footprint, next price, balances, chickens and entitlements remain intact. The saved field layout and outer schemaVersion=1 remain unchanged. High upgrade levels in a rank-one profile are valid.

## Runtime owners

- `server/PlayerSession.luau`: `NextSlot` and `GlobalUpgrade` expose available cash upgrades without rank checks; `StarterRecruitPending`, `StarterArmyReserve` and `CanSpendCash` protect the saved opening budget. The snapshot reports the configured overall army capacity, not the old rank capacity. Rank banners no longer promise an army-slot unlock.
- `server/UpgradeService.luau`: cash offers have no board proximity, required-rank parameter or promotion check. Offers honor the remaining starter reserve, allowing Army Size to use its own earmark. Plot availability remains enforced.
- `shared/UpgradeCatalog.luau`: no `RollSlotRanks` field. Income reference bands used in fixed price calculations are tuning inputs, not eligibility requirements.
- `server/ArmyService.luau`: the rejected legacy promotion action no longer claims territories increase army capacity.
- Existing ArmyService, RollService, EggService and UI purchase paths consume these offers and preserve their remaining transaction safeguards.

## Historical September 25 verification

The board-access checks in this historical pass are superseded by the October 2
location change above.

Seven focused standalone Luau groups passed against the actual current modules with in-memory service/world boundaries: all board tracks at zero camp wins, legacy menu transactions, rank-independent offers/prices, insufficient-cash and stale-quote rejection, retained readiness/access/capability restrictions, rank-one save roundtrip at maximum upgrades, and additive paid army capacity.

Fixture: `assets/upgrade-no-camps-20260925/checks.luau`. It does not access Studio or real saved players. Historical test cases expecting rank-one income/army purchases to fail are superseded and must not drive a regression back to the old design. No broad historical suite was run.

This task did not operate Play/Stop. Updated source is confirmed in the Edit tree and takes effect in a fresh Play session; it does not replace already-required modules in an active session. Studio integration/recovery details are in [the task record](team/NO_CAMP_UPGRADE_GATES.md).
