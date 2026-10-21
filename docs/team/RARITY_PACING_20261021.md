# Rarity pacing: how fast rare chickens come, Luck, and Playtime Coins (October 21, 2026)

Stevin, October 21, relaying a tester: "they unlocked rare chickens WAY too fast. You
should be hovering at common/uncommon/maybe a couple of rares at the start, but it
should be more. Also shouldn't Luck not be maxed out from the start? It should take a
bit. Also check if the Playtime rewards money is unbalanced."

This document is the measurement, the change that shipped the same day, and the levers
that were left alone. Numbers come from `tests/ProgressionSimulation.luau` run headless
with the committed tools in `tools/sim/` (`rarity_probe.luau` logs the first offer and
first recruit of every rarity, every Luck tier change, offer counts and Coins sources;
`odds_table.luau` prints the per-podium odds). It is a model, not a playtest: the buyer
recruits on payback (it buys fewer expensive chickens than real players; live data had
players taking 46% of Mythic offers), spends only 4% of its Coins on Luck while saving
for a Rebirth (real players buy Luck sooner), and claims Playtime tiles as they unlock.

## 1. What was wrong

### Luck strength

The window shift was `9 (M − 1) / (M + 2)` bands for Luck strength `M` (docs/team/
LUCK_WINDOW.md, written when the cash cap was x3 and twenty +0.10 levels). The
October 20 tree sells x1.25 … x10 in twelve tiers, so the same curve gave, per podium:

| Luck (price) | Strength | Shift | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|---|---|
| none | x1 | 0 | 60.0% | 22.0% | 14.0% | 3.0% | 0.95% | 0.059% |
| Luck I (800) | x1.25 | 0.69 | 46.3% | 22.0% | 24.6% | 4.2% | 2.66% | 0.21% |
| Luck II (4K) | x1.5 | 1.29 | 30.4% | 26.1% | 32.6% | 5.8% | 4.53% | 0.46% |
| Luck III (16K) | x2 | 2.25 | 6.0% | 27.8% | 44.6% | 11.3% | 8.64% | 1.56% |
| Luck IV (60K) | x3 | 3.60 | 6.0% | 2.2% | 43.5% | 20.1% | 21.9% | 6.1% |
| Super Luck IV (4M) | x5 | 5.14 | 6.0% | 2.2% | 1.4% | 29.6% | 41.8% | 18.4% |
| Mega Luck IV (150M) | x10 | 6.75 | 6.0% | 2.2% | 1.4% | 0.3% | 39.2% | 48.8% |

The 8-minute Playtime tile (+100% Luck for 5 min) doubles `M` the way a Gold roll does:
no Luck + tile = Luck III's row; Luck IV + tile (x6) = Legendary 49%, Mythic 28%.

### Luck prices against the economy

Rebirth 1 (50K) lands at 8–10 min, Rebirth 2 (62M) at 16–20 min, Rebirth 3 (1B) at
23–28 min. Against that, 800 / 4K / 16K / 60K / 250K / 600K / 1.5M / 4M / 10M / 25M /
60M / 150M meant the whole ladder was bought by minute 28–38 and re-bought within
1–5 minutes after every later Rebirth. "Maxed from the start" was literal.

### Playtime Coins

The twelve tiles were copied 1:1 from Drop a Fruit with one unit = one minute of steady
income, 53.5 minutes over the hour (+89% on top of egg income). Measured share of all
Coins: 21–23% for an engaged hour, 25–27% casual, 29–31% for two 30-minute visits a day
(REBIRTH_PACING_20261021.md). Amounts were computed when claimed, so saving the tiles
for the end of a visit (income is 10–100x higher by then) paid 10–100x more.

### Simulated first hour, live tuning (engaged: lever every 4 s, 3 seeds)

| | Seed 1 | Seed 2 | Seed 3 |
|---|---|---|---|
| Offers in hour one: Common / Rare / Legendary / Mythic / Secret | 798 / 326 / 2,997 / 7,027 / 284 | 801 / 314 / 2,761 / 7,175 / 275 | 783 / 185 / 3,011 / 7,417 / 340 |
| First Legendary owned | 12.8 min | 11.8 min | 11.8 min |
| First Mythic owned | 59.7 min | 17.4 min | 33.7 min |
| Luck IV / Super Luck IV / Mega Luck IV bought | 11.8 / 16.8 / 27.8 min | 11.8 / 17.8 / 29.8 min | 8.8 (III) / 14.8 / 29.0 min |
| Playtime share of Coins | 22% | 21% | 23% |

Casual (lever every 20 s): the same picture, Mythic offers 6,000–6,900 in the hour,
Mega Luck IV at 30–38 min, Playtime 25–27%. 45 min a day: Mega Luck IV on day 1 at
30–44 min, Playtime 16–18%, 97,000 Mythic offers in ten days.

## 2. What changed (shipped October 21)

1. **Luck strength curve.** `ChickenLuck.ShiftPerDecade = 2.25`: the favored range
   climbs 2.25 bands for every x10 of strength, `shift = min(9, 2.25 × log10(M))`.
   Everything else in the window math (10% stationary share, upward transport, top-band
   keep, monotone thresholds) is unchanged, and every bonus (Playtime tile, Gold x2,
   Diamond x5, Prism x10, Hill x3, 2x Luck pass, Extra Luck) still stacks through it.

   | Luck (price) | Strength | Shift | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
   |---|---|---|---|---|---|---|---|---|---|
   | none | x1 | 0 | 60.0% | 22.0% | 14.0% | 3.0% | 0.95% | 0.059% | 0.0007% |
   | Luck I (800) | x1.25 | 0.22 | 55.7% | 22.0% | 17.3% | 3.4% | 1.49% | 0.108% | 0.0013% |
   | Luck II (4K) | x1.5 | 0.40 | 52.1% | 22.0% | 20.1% | 3.7% | 1.93% | 0.147% | 0.0019% |
   | Luck III (16K) | x2 | 0.68 | 46.6% | 22.0% | 24.4% | 4.2% | 2.63% | 0.210% | 0.0027% |
   | Luck IV (60K) | x3 | 1.07 | 37.7% | 23.1% | 30.2% | 5.1% | 3.71% | 0.326% | 0.0048% |
   | Super Luck I (5M) | x3.5 | 1.22 | 32.5% | 25.2% | 31.9% | 5.6% | 4.29% | 0.419% | 0.0071% |
   | Super Luck II (50M) | x4 | 1.35 | 28.1% | 27.1% | 33.4% | 6.1% | 4.80% | 0.499% | 0.0091% |
   | Super Luck III (400M) | x4.5 | 1.47 | 24.1% | 28.8% | 34.8% | 6.5% | 5.24% | 0.570% | 0.0108% |
   | Super Luck IV (2B) | x5 | 1.57 | 20.6% | 30.2% | 36.0% | 6.9% | 5.64% | 0.633% | 0.0124% |
   | Mega Luck I (10B) | x6 | 1.75 | 14.5% | 32.8% | 38.1% | 7.5% | 6.33% | 0.743% | 0.0151% |
   | Mega Luck II (50B) | x7 | 1.90 | 9.4% | 35.0% | 39.8% | 8.0% | 6.91% | 0.835% | 0.0174% |
   | Mega Luck III (150B) | x8 | 2.03 | 6.0% | 35.3% | 41.5% | 8.8% | 7.47% | 0.981% | 0.0203% |
   | Mega Luck IV (400B) | x10 | 2.25 | 6.0% | 27.8% | 44.6% | 11.3% | 8.64% | 1.56% | 0.0295% |

   Stacks: no Luck + the Playtime tile (x2) = Luck III's row; Luck IV + tile (x6) =
   Mega Luck I's row; a Diamond roll at no Luck (x5) = Super Luck IV's row; a Prism
   roll (x10) = Mega Luck IV's row; Mega Luck IV + 2x pass + tile (x40) = Legendary
   21.9%, Mythic 6.2%; with a Prism roll on top (x400, shift 5.85) the podiums are
   mostly Legendary and Mythic, which is what a once-in-250-pulls roll should feel like.

2. **Luck prices.** Luck I–IV stay 800 / 4K / 16K / 60K (cycle 1–2). Super Luck I–IV
   are 5M / 50M / 400M / 2B and Mega Luck I–IV 10B / 50B / 150B / 400B: each about
   5–8% of the Rebirth cost of ranks 2, 3, 4, 5 and 7, 9, 12, 15–17 (62M, 1B, 8.6B, 36B,
   120B, 600B, 2.2T, 4.5–5.5T), so a tier is a real buy in that cycle and a cheap re-buy
   afterwards. The tree still resets on Rebirth and Keep Upgrades still keeps tiers.

3. **Playtime Coins.** One reference unit is 0.4 minutes of steady income: tiles pay
   0.4 / 0.6 / 1 / 2 / 2.4 / 3 / 5 / 7 minutes (21.4 over the hour, +36% on top of egg
   income). The reference's ratios, unlock times, boosts and Free Rolls are unchanged.
   A tile's amount is fixed the moment it unlocks (`PlaytimeService` `lockedCoins`,
   `session.playtime.locked`), so the panel's number is the number paid and claiming
   late pays no more. Locked tiles still show a projection of today's income.

## 3. Results after (same seeds)

| Engaged hour (lever every 4 s) | Seed 1 | Seed 2 | Seed 3 |
|---|---|---|---|
| Offers in hour one: Common / Rare / Legendary / Mythic / Secret | 1,958 / 4,471 / 789 / 135 / 1 | 2,059 / 4,356 / 763 / 136 / 2 | 1,978 / 4,575 / 814 / 140 / 2 |
| First Legendary owned | 15.0 min | 13.8 min | 12.0 min |
| First Mythic owned | 25.0 min | 15.0 min | 17.9 min |
| Luck IV / Super Luck I / Super Luck III bought | 12.8 / 19.8 / 49.8 min | 13.8 / 19.8 / 49.8 min | 11.8 / 20.0 / 48.8 min |
| Playtime share of Coins | 13% | 14% | 15% |

Legendary offers fell 73%, Mythic offers 98%, Secret offers from ~300 an hour to 1–2.
The podiums now hold Commons, Uncommons and Rares in the first ten minutes and Rares
with the odd Epic after Luck IV, which is the "hovering at common/uncommon/rare" feel.

Luck ladder timing (fast profile, lever every 8 s, 4 h; 45 min a day, 10 days):
Luck IV at 12–14 min, Super Luck I ~20 min, Super Luck II ~30 min, Super Luck III
~50 min, Super Luck IV 75–85 min (Rebirth 5), Mega Luck I 2–3 h (Rebirth 7–8), Mega
Luck II not inside 4 h. At 45 min a day: Mega Luck II on day 6, Mega Luck III day 7–8,
Mega Luck IV not by day 10 (Rebirth 14–15). The model's buyer is conservative; a player
who spends 10% of a cycle on Luck reaches x10 around Rebirth 12–15 (3.5–6 h nonstop,
day 8 casual). "It should take a bit" now means hours and days, not minutes.

Playtime share after: 13–15% engaged hour, 10–14% casual hour, 5% over four fast hours,
7% at 45 min a day (was 16–18%).

Side effect on Rebirth pacing (the ladder in REBIRTH_PACING_20261021.md was fitted with
the old Luck): fast profile Rebirth 5 at 59–63 min (was 48–50), Rebirth 7 at ~103 min
(was 73), Rebirth 10 at 3.9 h for one seed and not inside 4 h for the other (was 2.5 h).
At 45 min a day Rebirth 10 still lands on day 3–4, but ten days reach Rebirth 14–15
instead of 17–18. The cause is the Flock: its best layers used to be Mythics (344–480
base income) by Rebirth 5; now they are Legendaries (160–268) for longer, and the
Playtime cut takes another ~15% of income. The 30-hour fast-nonstop run is in §5.

## 4. What is unchanged, and the levers left for Stevin

- **Base odds and prices.** The zero-Luck bands (Oct 7) and the "1 in X" prices (Oct 15)
  are untouched: a Rare is on 14% of podiums from minute one and costs 8K–19K, which an
  opening player affords at about 4–8 min. Rebirth 2 hands out 62M at ~18 min while a
  Legendary costs 96K–530K and a Mythic 1.3M–4.7M, so the first Legendary and Mythic
  are still *owned* at 12–25 min for an engaged player even though they are *offered*
  10–50x less often. Making ownership slow too needs one of:
  - recruit prices that grow with Rebirth rank (the tree already has
    `UpgradeCatalog.RankPriceGrowth` for this idea; chickens would need the same in
    `Rules.RecruitPrice`, with refunds kept on the saved investment);
  - smaller Rare band budgets in `PetCatalog.LuckBands` (9 and 5 today), which changes
    every "1 in X" label and price;
  - fewer early podiums or a slower lever (Roll Slot II–IV cost 1K / 4K / 12K; the lever
    is free every 4 s, so eight podiums at zero Luck still show a 1-in-1,700 Mythic
    about four times an hour).
- **Daily streak, Hill rolls, Free Rolls, Gold/Diamond/Prism, 2x Luck, Extra Luck,
  Mutations:** unchanged; they stack through the new curve (table above).
- **Saves:** nothing saved changes. `session.luck` is still the tier; older tiers keep
  their number and gain the new, weaker strength. `session.playtime` is never saved.

## 5. Thirty hours nonstop (fast profile, lever every 8 s, 2 seeds), after the change

| Milestone | After (median) | Before (REBIRTH_PACING_20261021.md, shipped ladder) |
|---|---|---|
| Rebirth 5 | 59 min | 48 min |
| Rebirth 10 | 3.9 h | 2.6 h |
| Rebirth 15 | 8.8 h | 5.9 h |
| Rebirth 20 | 20.8 h | 10.6 h |
| Rank after 30 h | 21 and 24 | 30 at ~21 h |
| First Mythic owned | 45 min | 14–34 min |
| Playtime share of Coins | 7% | 16% |

Luck ladder in that run (the model's conservative buyer, first purchase):

| Tier | Seed 1 | Seed 2 |
|---|---|---|
| Super Luck IV (2B) | 1.4 h (Rebirth 5) | 1.3 h (Rebirth 5) |
| Mega Luck I (10B) | 2.8 h (Rebirth 8) | 2.2 h (Rebirth 7) |
| Mega Luck II (50B) | 5.7 h (Rebirth 11) | 5.2 h (Rebirth 11) |
| Mega Luck III (150B) | 8.4 h (Rebirth 13) | 7.6 h (Rebirth 13) |
| Mega Luck IV (400B) | not within 30 h | 23.5 h (Rebirth 21) |

So the retune roughly doubles the time to Rebirth 20 under the ladder that was fitted
with the old Luck curve: the Flock's best layers are Legendaries instead of Mythics for
hours longer, and Playtime Coins fell from 16% to 7%. The Rebirth ladder (Config.Rebirth
.Costs) is being re-fitted on top of this by the Rebirth balance session; fit against
these numbers, not the October 21 morning ones, and keep "more, not harder".

## Reproducing

```bash
cd tools/sim && ./lune run harness.luau ../.. odds_table.luau
```

```bash
cd tools/sim && ./lune run harness.luau ../.. rarity_probe.luau profile=fast rollEverySeconds=4 hours=1 seeds=3
```

```bash
cd tools/sim && ./lune run harness.luau ../.. rarity_probe.luau profile=casual playMinutes=45 awayMinutes=1395 hours=240 seeds=2
```

Checks: `tools/sim/runsuite.luau LuckWindowChecks` (9 of 10; the one failure predates
this change and expects zero-Luck odds without the Oct 14 top-band keep),
`PlaytimeChecks` (12 of 12, including the new "amount is fixed at unlock" check),
`ResearchRollingChecks` (8 of 9, the same pre-existing tooltip rounding mismatch as
before), `DailyChecks` and `RebirthV2Checks` all green.
