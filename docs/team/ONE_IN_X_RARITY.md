# "1 in X" rarity, rarity pricing and the Secret tier (October 15, 2026)

## Owner decision

Show every chicken's odds as "1 in X", keep the rarity names, and let price and power
follow each chicken's own rarity, so the rarest chickens cost a fortune (trillions at high
levels) and rarer is always better. A new **Secret** rarity sits above Mythic.

## Why

- Live data (Oct 13–15): chicken buys were ~0.3% of all cash spent, and 95–99.6% of every
  roll offer was affordable. Rarity barely mattered to price.
- Odds at zero Luck spanned 1 in 4 to 1 in 444,500 (≈125,000×), but price and income were
  flattened into 10 shared tiers (≈120×). A 1-in-444K chicken earned and cost the same as a
  1-in-121K one.

## Rules (`src/shared/PetCatalog.luau`, end of file)

- **Odds.** Luck's band table moved from `ChickenLuck` into `PetCatalog.LuckBands` so the
  catalog can compute `oneIn` (zero-Luck odds) per rollable chicken. `ChickenLuck` reads the
  same table and matches bands by `luckSignature`, the tier stats recorded before the
  premium. Odds are unchanged at every Luck level (verified identical to `ChickenLuck.Odds(0)`).
- **Income** = max(tier income × r^0.2, 4 × R^0.5), where R = odds relative to the basic
  Chicken and r = odds relative to the tier's most common member. Never below today's tier
  value, so no owned chicken is weakened.
- **HP / damage** × min(2, √(income gain)).
- **Price** = `Catalog.RarityPrice`: max(600 s of income, 2,400 × R^(0.25 + 0.17·log10 R)),
  × `SecretPricePremium` (5) for Secret. Commons stay near their old prices; Mythics are
  $1–5M at level 1; Galaxy Overlord ~$100M; Secret chickens ~$5.8B (≈$1.5T at level 9,
  ≈$3T at level 10, since recruit price doubles per level).
- **Secret** = `oneIn ≥ Catalog.SecretOneIn` (200,000): The First Hen, Rift Walker,
  Supernova. Same Giant size band as Mythic.
- **Protected species.** The 11 original tier species (Duck, Mallard, Chunky, Sailor, Bucket,
  Viking, Knight, Wizard, Dragon, IceDuck, StormDuck) keep their exact stats, because camps,
  the King and invasions are built from them. Only their price follows the curve. Kill
  bounties are keyed by tier, not price, so they don't change.
- Crate-only, limited, Hill and enemy-only chickens have no `oneIn` and are unchanged.

## Display

`Catalog.OneInText(species)` → "1 in 4", "1 in 129", "1 in 19,000" (3 significant figures).
Shown on the roll podium ("Mythic · 1 in 19,000"), in each Index card's corner and in the
Army inspector line.

## Save compatibility

Nothing saved changes. Stats are computed from the catalog at load; investments and refunds
keep their saved values (`Rules.HistoricalPrices` is untouched). Owned rare chickens become
stronger and earn more; none become weaker.

## Checks run

- Zero-Luck odds from the catalog match `ChickenLuck.Odds(0)` to 4e-16 for every chicken.
- `tests/LuckWindowChecks` 9/10 (band matching switched to `luckSignature`; the remaining
  failure predates this change: it expects zero-Luck odds without the Oct 14 TopBandKeep).
- `tests/ProgressionSimulation`, 3 seeds × 12 h, before → after: King 50 → 56 min,
  Rebirth 1 68 → 73 min, Rebirth 2 179 → 198 min, Rebirth 3 272 → 307 min. The model's
  payback-based buyer stops buying Mythics; real players bought 46% of Mythic offers.
- Studio playtest: Index shows the "1 in X" badges; no new errors.
