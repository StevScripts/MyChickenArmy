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
- **Each rarity's share of rolls is unchanged** at every Luck tier: these are the band
  totals, the October 21 levers. The only exception is Galaxy Overlord, which now counts
  as Secret. Uncommon's 22% is split twelve ways between Common's and Rare's ranges, so
  Uncommons sit close together (1 in 52–58).
- **The 11 original tier species never change tier or stats** (camps, the King and
  invasions use them). Rainbow Rider stays first in its band, so saved Veteran 13–15
  chickens keep loading at its exact income.

| Rarity | Chickens, most common first (1 in X at zero Luck) |
|---|---|
| Common (13) | Chicken 4, Rooster 29, Rubber Ducky 30, Cardboard Commando 31, Pajama Chicken 35, Party Chicken 36, Piggy Chicken 38, Gamer Chicken 40, Donut Chicken 41, Painter Chicken 43, Popcorn Chicken 45, Miner Chicken 46, Bonsai Bantam 48 |
| Uncommon (12) | Bee Chicken 52, Cow Chicken 52, Zombie Hunter 53, Ironbeak Chicken 53, Detective Chicken 54, Mummy Chicken 54, Coral Reef Chicken 55, Castle Guard Chicken 55, Snowman Chicken 56, Honeycomb Chicken 57, Jungle Chicken 57, Lollipop Chicken 58 |
| Rare (12) | Robo-Cluck 58, Neon Chicken 61, Gladiator Chicken 65, Deepsea Diver 69, Rockstar Chicken 73, Slime Squawker 77, Crystal Chicken 104, Ghost Chicken 111, Steampunk Scratcher 117, Court Jester 124, Toxic Chicken 132, Frost Feather 139 |
| Epic (11) | Magma Chicken 230, Chicken Jockey 255, Aurora Chicken 283, Airship Captain 314, Mimic Chicken 349, Animatronic Chicken 387, Vampire Chicken 429, Yeti Chicken 476, Dragon Hatchling 529, Shadow Stalker 586, Storm Wing 651 |
| Legendary (10) | Golden Emperor 658, Witch Chicken 737, Jade Chicken 825, Stained Glass Chicken 924, Geode Chicken 1,040, Pharaoh Chicken 1,160, Rainbow Rider 1,360, Diamond Defender 1,520, Water Chicken 1,710, Solar Flare Chicken 1,910 |
| Mythic (10) | Glitch Chicken 9,410, Griffin Chicken 11,000, Dragon Knight 12,800, Kraken Chicken 14,900, Unicorn Chicken 17,400, Moon Chicken 20,300, Olympian Chicken 23,700, Valkyrie Chicken 27,700, Phoenix Chicken 32,300, Devil Chicken 37,600 |
| Secret (10) | Galaxy Overlord 367,000, The First Hen 428,000, Forest Guardian 499,000, Time Keeper 582,000, Eclipse Chicken 680,000, Kitsune Spirit 793,000, Mecha Chicken 925,000, Heavenly Chicken 1,080,000, Supernova Chicken 1,260,000, Rift Walker 1,470,000 |
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
