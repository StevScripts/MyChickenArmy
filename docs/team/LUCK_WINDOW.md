# Moving Luck window — October 6, 2026 (retuned October 7 and October 21)

**October 21 update (Stevin, after a tester: "rare chickens way too fast", "Luck should
take a bit"):** the shift is now `s = min(9, ChickenLuck.ShiftPerDecade × log10(M))`
with `ShiftPerDecade = 2.25`: 2.25 bands for every x10 of strength (x2 = 0.68, x3 =
1.07, x10 = 2.25, the stacked x400 cap 5.85). The old `9 (M − 1) / (M + 2)` curve was
fitted for a x3 cash cap; with the October 20 tree's x1.25 … x10 tiers it put
Legendaries on 22% of podiums at Luck IV (60K Coins, twelve minutes in) and Mythics on
49% at Mega Luck IV. Super and Mega Luck prices moved to 5M … 400B so the ladder spans
Rebirth 2–17 instead of the first half hour. Current odds per tier, the simulation and
the untouched levers: `docs/team/RARITY_PACING_20261021.md`. The October 7 tables below
describe the old curve.

**October 7 update (user decision):** the opening Luck curve was far too strong.
One $1,920 purchase cut the basic Chicken from 16% to 2.5% and tripled
Legendary+ results, so new players mostly rolled chickens they could not afford.
Every cash Luck level now adds a flat +0.10 strength (cap 3.0×, shift 3.6), and
the rarity reset below makes rarer always mean stronger. Existing Luck levels
keep their saved number but carry the new, weaker strength.

Normal recruitment now moves a favored range toward stronger chickens as Luck
increases. This supersedes the flat Rare+ weight boost. `shared/ChickenLuck.luau`
owns the distribution; `Rules.Odds`, `Rules.Draw` and `Rules.LuckWindow` are the
shared entry points for authoritative offers, reel presentation and disclosure.

## Strength bands

The ten bands have base incomes 4, 8, 16, 28, 56, 96, 160, 268, 344 and 480.
Their fixed probability budgets are 38, 22, 22, 9, 5, 3, 0.7, 0.25, 0.05 and
0.01, normalized by 100.01. Their order also increases base combat power.

October 7 rarity reset: rarity now follows the bands. Bands 1–2 are Common, 3
Uncommon, 4–5 Rare, 6 Epic, 7–8 Legendary and 9–10 Mythic, so a rarer chicken
is always stronger. Appearances were re-ranked by how desirable their art is
(see `PetCatalog.luau`'s reset block and the design workspace's
`output/rarity-reset-20261007/proposed-tier-list.png`). Each catalog weight
equals that chicken's percent chance at Luck 0; the basic Chicken leads at 28%
and the first Mythic band starts near 1 in 1,667. Camp species and the
Galaxy Crate pool keep their tiers. A moved species takes its new tier's
legacy economy key, so prices, kill coins and refunds follow the tier.

Equal income, HP, damage, attack interval/windup and splash behavior share one
band. Existing catalog weights divide its budget between appearances. Adding a
matching appearance changes the split inside that band, never its probability.
A new stat profile needs an explicit band decision; missing profiles fail with
a named assertion instead of silently changing the economy. Zero-weight and
crate-exclusive chickens stay outside normal rolls.

## Probability movement

Cash Luck strength is +0.10 per level through level 20 (October 7; the
earlier +0.35 opening levels are retired). Multiply that strength by eligible paid
Luck (1 or 2) and `1 + rollingLuck` (highest research tier, currently up to 1).
Call the combined strength `M`. The continuous upward shift is:

`s = min(9, 2.25 * log10(M))` since October 21 (`ChickenLuck.ShiftPerDecade`); it was
`s = 9 * (M - 1) / (M + 2)` from October 6 to October 21.

Keep 10% of the original distribution stationary. Shift the remaining 90% up by
`s` bands, splitting fractional destinations between their neighboring bands
and collecting overflow in the strongest band. The dominant initial window is
bands 1–5 (95.99% of baseline mass). Its left pointer is `1 + s`, and its right
pointer is `min(10, 5 + s)`. The small tail ahead moves too. This is a weighted
favored range, not a uniform range or an eligibility gate. Displayed names round
outward to its enclosing bands; probabilities move even when those names stay
the same between purchases.

At zero Luck with no bonuses, the original probabilities are preserved exactly
within floating-point precision. The stationary component leaves every normal
chicken possible. Coupling the original band draw and fractional rounding draw
shows that increasing `s` never produces a weaker band; therefore every chance
of reaching a given strength threshold or higher is nondecreasing. An individual
middle-band species can become less common as stronger results take its place.

## Initial tuning (October 7, the old curve)

October 7 values with the `9 (M − 1) / (M + 2)` curve, verified in an isolated Studio
sandbox. The October 21 table in RARITY_PACING_20261021.md is current:

| Cash Luck | Paid | Research | Basic Chicken | Common | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|---|---|
| 0 | 1 | 0 | 28.0% | 60.0% | 14.0% | 3.0% | 0.95% | 0.06% |
| 1 | 1 | 0 | 20.7% | 54.2% | 18.4% | 3.5% | 1.67% | 0.13% |
| 2 | 1 | 0 | 13.8% | 48.9% | 22.6% | 4.0% | 2.34% | 0.19% |
| 10 | 1 | 0 | 2.8% | 6.0% | 44.6% | 11.3% | 8.64% | 1.59% |
| 20 | 1 | 0 | 2.8% | 6.0% | 43.5% | 20.1% | 21.87% | 6.31% |
| 20 | 2 | 1 | 2.8% | 6.0% | 1.4% | 0.3% | 31.85% | 58.25% |

Fresh players mostly see affordable chickens; stronger results still become
normal late, mainly through research and the verified pass.
These are distribution calculations, not measured earning rates or tested player
pacing: recruits still cost cash, and purchase/army choices matter. Assess pacing
in play before treating this initial tuning as final balance.

## Compatibility and presentation

No save migration, prices, track caps, camp requirements, recruit prices or
purchase validation change. Starter/debug offers and the restricted paid-pass
guarantee keep their separate rules. Already accepted offers retain their frozen
chance and Luck inputs. Crates and Giant/fusion size luck are unaffected.

The cash tree displays actual Epic+ current/next probabilities and a favored
range in tooltips. When Epic+ rounds to the same value, the node shows `Top`
and the tooltip explains the improving strongest-chicken chance instead. MAX
also shows that top chance. Existing Rare+ offer fields remain compatible. Research and
the pass describe **Luck strength**, not multiplied Rare+ weights or doubled
final chances. The shop still discloses individual before/after percentages.

## Focused checks

`tests/LuckWindowChecks.luau` covers the distribution invariants and an isolated
extra-skin catalog. `ResearchRollingChecks` covers roll/snapshot/shop agreement,
frozen offers, research and restricted-pass behavior. The Luck-specific checks in
`UpgradeBoardProgressionChecks` cover upgrade previews and modifier agreement.
Run these with fresh isolated module loading; a cached ModuleScript does not
re-evaluate when Rojo changes its Source.

October 6 verification: all 22 focused checks passed in isolated Edit-state
fixtures (11 distribution, 9 research/rolling, 2 selected upgrade checks). The
distribution matrix covers 294 cash/research/pass combinations; the extra-skin
fixture leaves production catalog state untouched. Late 19→20 upgrades retain
an improving top chance after Epic+ plateaus. All eight changed runtime modules
compile and match the local sources in Pet Roll Test through Rojo. Scripts-only
packaging and diff whitespace checks pass. No full playtest, visual layout pass,
real purchase, player-data change, explicit Studio save or publication was run.
The unrelated historical upgrade-board checks were not run.
