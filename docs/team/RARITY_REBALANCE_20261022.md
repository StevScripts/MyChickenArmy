# Rarity rebalance and roll pool (October 22, 2026)

Stevin compared the Drop a Fruit Index: 52 fruits, 7–9 per rarity, each a steady step
rarer than the last. Then he made three decisions:
1. "Too many chickens on one level… move their rarities around": every rarity holds
   about the same number of chickens.
2. Narrow the roll pool, but every chicken with effects stays no matter what.
3. He picked the plain chickens that stay, in the Chicken Roster Picker
   (https://claude.ai/artifact/KX1ovFPFtyBTpTFuiXK4cF): Rubber Ducky, Cardboard Commando,
   Rooster, Bee Chicken, Cow Chicken, Crystal Chicken, Slime Squawker and Chicken Jockey.

## The roll pool: 78 chickens (was 118)

- **Counts:** Common 13, Uncommon 12, Rare 12, Epic 11, Legendary 10, Mythic 10, Secret 10.
  Before: 23 / 17 / 29 / 17 / 20 / 9 / 3.
- **Effect chickens, ten per rarity.** 70 rollable chickens have effects in their
  `ChickenAssets` template, counting the starter Chicken (64 with particles or beams;
  Zombie Hunter, Gamer, Neon and Aurora with a light only; Robo-Cluck's eye lights come
  from code). They were ranked by their old odds, with stronger effects breaking ties,
  and dealt ten to a rarity.
- **One ladder.** Inside a rarity each chicken is a steady step rarer than the one
  before. Each rarity's spread (`span` in `PetCatalog.RollPool`) was fitted so no chicken
  reads rarer than the next rarity's first. The list runs from 1 in 4 to 1 in 1.47M with
  no inversions.
- **Each rarity's share of rolls** follows the reference since the later October 22 change (next section).
- **The 11 original tier species never change tier or stats** (camps, the King and
  invasions use them). Rainbow Rider stays first in its band, so saved Veteran 13–15
  chickens keep loading at its exact income.

Real odds after the reference-like chances below:

| Rarity | Chickens, most common first (1 in X at zero Luck) |
|---|---|
| Common (13) | Chicken 4, Rooster 15, Rubber Ducky 15, Cardboard Commando 16, Pajama Chicken 16, Party Chicken 17, Piggy Chicken 18, Gamer Chicken 19, Donut Chicken 20, Painter Chicken 21, Popcorn Chicken 22, Miner Chicken 23, Bonsai Bantam 24 |
| Uncommon (12) | Bee Chicken 82, Cow Chicken 100, Zombie Hunter 120, Ironbeak Chicken 145, Detective Chicken 176, Mummy Chicken 212, Coral Reef Chicken 256, Castle Guard Chicken 309, Snowman Chicken 374, Honeycomb Chicken 452, Jungle Chicken 546, Lollipop Chicken 659 |
| Rare (12) | Robo-Cluck 974, Neon Chicken 1,080, Gladiator Chicken 1,210, Deepsea Diver 1,340, Rockstar Chicken 1,490, Slime Squawker 1,660, Crystal Chicken 1,660, Ghost Chicken 1,840, Steampunk Scratcher 2,050, Court Jester 2,280, Toxic Chicken 2,540, Frost Feather 2,820 |
| Epic (11) | Magma Chicken 11,000, Chicken Jockey 13,600, Aurora Chicken 16,700, Airship Captain 20,600, Mimic Chicken 25,300, Animatronic Chicken 31,200, Vampire Chicken 38,400, Yeti Chicken 47,300, Dragon Hatchling 58,200, Shadow Stalker 71,700, Storm Wing 88,200 |
| Legendary (10) | Golden Emperor 162,000, Witch Chicken 170,000, Jade Chicken 178,000, Stained Glass Chicken 187,000, Geode Chicken 196,000, Pharaoh Chicken 206,000, Rainbow Rider 207,000, Diamond Defender 217,000, Water Chicken 228,000, Solar Flare Chicken 239,000 |
| Mythic (10) | Glitch Chicken 306,000, Griffin Chicken 375,000, Dragon Knight 459,000, Kraken Chicken 561,000, Unicorn Chicken 687,000, Moon Chicken 840,000, Olympian Chicken 1,030,000, Valkyrie Chicken 1,260,000, Phoenix Chicken 1,540,000, Devil Chicken 1,880,000 |
| Secret (10) | The First Hen 2,030,000, Galaxy Overlord 2,540,000, Forest Guardian 3,170,000, Time Keeper 3,950,000, Eclipse Chicken 4,940,000, Kitsune Spirit 6,160,000, Mecha Chicken 7,690,000, Heavenly Chicken 9,610,000, Supernova Chicken 12,000,000, Rift Walker 15,000,000 |

## Reference-like chances (later October 22)

Stevin: "I want my chances to be similar to that other game… it was mostly common". In
the recording, about 11 single and 25 triple pulls (about 85 fruits) gave about 4 Rares,
all on golden or Blood Moon rolls, a handful of Uncommons and about 90% Commons. The
reference Index's odds, normalized, are Common 92.9%, Uncommon 6.3%, Rare 0.76%, Epic
0.043%, Legendary 0.005%, Mythic 0.001%, Celestial 0.0002%.

- **`PetCatalog.LuckBands` weights** now give those shares at zero Luck: Common 92.9%
  (the basic Chicken 28%), Uncommon 6.3%, Rare 0.76%, Epic 0.043%, Legendary 0.005%,
  Mythic 0.0016%, Secret 0.0002%. They were 60 / 22 / 14 / 3 / 0.95 / 0.06 / 0.0015.
  `RollPool` spans were re-fitted so the ladder still has no inversions.
- **Luck slides less: `ChickenLuck.ShiftPerDecade` is 0.35 (was 2.25).** With 93% of a
  roll in Common, the old slide turned most of it into Uncommon and Rare. On HEAD a
  simulated fast player's first hour was 21% Common and 36% Rare. Now it is 83%
  Common, 15% Uncommon and 2% Rare, and about 81% Common over three hours (0.6 gave 76%).
  Luck still matters most for rare chickens: x3 doubles Rare and triples Epic.
- **Values did not move.** Each chicken's price, income and power come from its
  `valueOneIn`: the value ladder (`valueSpan`, `valueTotal`, LuckBands `value`) is this
  morning's 78-chicken ladder. `oneIn` is the real chance shown in the Index and on
  podiums. `SecretOneIn` (200,000) and the price premium use the value odds. The only
  value change: The First Hen and Galaxy Overlord swapped places in Secret (The First
  Hen's level-1 income 1,385 → 1,282 and price 5.4B → 4.0B; Galaxy Overlord's price
  4.0B → 5.4B).
- **Rebirth finds** were re-picked on the new odds (`REBIRTH_SCREEN.md`): Ironbeak
  Chicken (Uncommon, 1 in 145) first, Mimic Chicken (Epic, 1 in 25,000) last. Rarer finds
  (The First Hen, Glitch Chicken, Storm Wing) stalled simulated players for hours.
- **Pace before the re-fit (3 fast seeds, 3 h, `rarity_probe`).** Fewer rare chickens
  meant slower income: Rebirth 1 at 12–15 min (HEAD 8–11), Rebirth 5 at 98–107 min
  (HEAD 53–67), rank 6–7 after 3 h (HEAD 9–10).

### Rebirth cost re-fit (October 23)

Stevin: "re-fit the Rebirth costs … so the Rebirth pace matches what it was before,
keeping the new chances." Tree prices stay flat (his October 22 rule), so only
`Config.Rebirth.Costs` moved. The flat-tree branch (`claude/heuristic-stonebraker-0624fc`:
the rank-priced tree reverted, its ladder and `tools/sim/fit.py`/`gaps.py`/`report.py`
kept) was merged first, so the target is the live economy with the old chances.

- **Method.** Eight fast 40 h seeds (401–408) of `tools/sim/cost_fit.luau` on the old
  chances give the target played minutes per rank. Each round moved ranks 3–49 by
  (target gap / measured gap)^0.8–1.0, smoothed over three ranks, inside the ratio bands
  (x3–20 to Rebirth 10, x1.1–3 after). Ranks past the last well-measured one keep the old
  ladder's steps, and a final round raised ranks 26–50. Gaps inflated by waiting on a
  find were replaced with their neighbours' ratio. Seven rounds in all.
- **Result.** Ranks 3–15 cost about 80% less, 16–50 37–68% less; Rebirth 1 and 2 are
  unchanged (50K, 1M). Rebirth 50 is 1.17e15 (was 3.13e15).

  | Rebirth (median played time) | Old chances (target) | New chances, old costs | New chances, re-fit |
  |---|---|---|---|
  | 1 | 12 min | 12 min | 12 min |
  | 5 | 58 min | 1.7 h | 1.0 h |
  | 10 | 3.0 h | 6.7 h | 2.9 h |
  | 15 | 5.6 h | not reached by 6 of 8 | 5.8 h |
  | 20 | 11.9 h | not reached by 7 of 8 | 11.5 h |
  | 30 | 22.3 h | not reached | 21.8 h |
  | 40 | 33.2 h | not reached | 31.7 h (6 of 8) |

  Minutes per rank: 21–30 61 (target 63), 31–40 66 (target 67), 41–50 57 (target 64,
  1–2 seeds each, noisy). Not run: casual, daily-login profiles and `unlock_probe`.

- **Checks:** RebirthV2 29/29 (first find Ironbeak, last Mimic, re-fit costs; the
  rank-priced tree check left with the flat-tree merge). LuckWindow 10/10 (opening
  budgets updated). Admin, Analytics, AutoRoll, Event, Hill and ResearchRolling match
  HEAD; ShopIndex fails the same 13 as on HEAD. luau-lsp: PetCatalog 110 diagnostics
  (HEAD 112), ChickenLuck 0.

## Retired from rolls (40)

`PetCatalog.RetiredFromRolls`. Weight 0 and `vaulted = true`; they stay in
`Catalog.Order`, so saves load them. Owned copies keep the exact level-1 rarity, income,
HP, damage and price they had before this change. The Index shows a retired chicken only
once the player has found it, with "Retired" in place of its odds. Mallard, Chunky and
Sailor still lead camps, the King and Missions.

Noob Chick, Brown Chicken (Mallard), Penguin, Chunky, Mushroom (Sailor), Cheesy, Camo,
Cactus Clucker, Zombie, Tiger, Skeleton, Pirate, Sir Clucks-a-Lot, Ninja, Hatchling,
Silkie, Speckled Hen, Bacon Hair Chick, Scarecrow, Sheep, Plushie, Crate Runner,
Lumberjack, Mailman, Raincoat, Skater, Sushi, Frog, Taco, Sunflower, Paratrooper,
Firefighter, Chef, Police, Doctor, Samurai, Cowboy, Archer, Royal Guard, Norse Raider.

## Rebirth finds

All are effect chickens (they always stay in the pool), each picked nearest the old
ladder's odds. See `REBIRTH_SCREEN.md`.

## Owned chickens that changed

A kept chicken that moved tier takes its new tier's stats (the October 7 pattern), and
its income and price follow its new odds. For example, Bonsai Bantam goes from Rare to
Common (32 → 9 Coins/s at level 1), and Phoenix goes from Legendary to Mythic.

## Checks run

- `tools/sim/odds_table.luau`: per-rarity shares match HEAD at every Luck tier (Galaxy
  Overlord's share moves from Mythic to Secret).
- `tests/RebirthV2Checks.luau` 30/30. Its Veteran check now asks that the mapped chicken
  still loads, not that it rolls (Veteran 1–2 load as Chunky).
- Same results as HEAD for Admin, Analytics, AutoRoll, Event, Hill, LuckWindow and
  ResearchRolling. ShopIndex fails the same 13 checks it fails on HEAD.
- `tools/sim/rarity_probe.luau profile=fast rollEverySeconds=4 hours=3 seeds=3`:
  Rebirth 1 at 9–12 min (HEAD 8–11) and Rebirth 5 at 56–62 min (HEAD 53–67). Rank 9–10
  after 3 h, as on HEAD. Every find was bought on sight with no wait.
- luau-lsp: PetCatalog, IndexBrowser and LabStories have the same diagnostics as HEAD.
- Not checked in Studio.
