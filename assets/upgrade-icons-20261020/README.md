# Upgrade icons — October 20, 2026 (overhaul session S6)

Chunky icons with a heavy black outline on a transparent background for the October 20
overhaul: the new Upgrades tree, the Gem Upgrades, the Gems currency and the new HUD pieces.
Made with the `chatgpt-image` skill (gpt-image-1.5, medium quality, 1024² transparent) and the
`chunky-simulator-icons` references. Plan: `docs/team/OVERHAUL_PLAN_20261020.md`, section S6.

**Status:** waiting for Stevin's review. Nothing is uploaded, nothing was done in Studio, and
no game code changed.

| File | What it is |
| --- | --- |
| `<Key>.png` | The 43 chosen 1024² masters, exactly as generated. |
| `upload/<Key>.png` | 512² upload copies made by `prepare.py`. |
| `review-sheet.png` | Every icon in a mock tree hex or Gem card, plus a 64 px strip on dark, Upgrades blue, bought green and light backgrounds. |
| `generate.sh` | Every prompt and reference image. |
| `prepare.py` | Builds the upload copies (see Clean-up). |
| `review_sheet.py` | Builds the review sheet. |

## Decisions (Stevin, October 20)

- **One icon per family.** Tiers are live text drawn by S9, not part of the art. Like the
  reference tree, the hex shows a big tier number and the name carries the Roman numeral
  ("Egg Speed II").
- **Same effect, same icon.** The Gem Upgrades Roll Speed, Extra Luck and Vacuum Capacity reuse
  the tree icons `RollSpeed`, `Luck` and `VacuumCapacity`. Rally keeps the horn already in the
  game (`Theme.Assets.Rally`, `rbxassetid://103846085793265`), so it needs no new upload.
- **All six current tree icons are replaced** so the set matches. The uploaded `cash*` ids in
  `ResearchAssets` keep working until S9 swaps them.
- **"Rainbow Machine"** is the working name for the tier above Diamond. The icon is a rainbow
  roll machine, so S12 can rename the node freely.

## Which icon goes where

| Group | Key | Used for |
| --- | --- | --- |
| Main tree | `EggSpeed` | Egg Speed I–IV |
| | `EggValue` | Egg Value I–IV |
| | `Luck` | Luck I–IV; Gem Upgrade Extra Luck |
| | `FlockSize` | Flock Size ladder |
| | `ArmySize` | Army Size I–IV |
| | `RollSlot` | Roll Slot I–VII |
| | `RollSpeed` | Roll Speed I–III; Gem Upgrade Roll Speed |
| | `GoldMachine` | Gold Machine |
| | `GoldRate` | Gold Rate I–II |
| | `DiamondMachine` | Diamond Machine |
| | `RainbowMachine` | The tier above Diamond (working name) |
| Category hexes | `OpenTools`, `OpenPlayer`, `OpenArmy` | The Tools, Player and Army Open hexes |
| | `Back` | Back hex |
| Tools | `EggVacuum` | Egg Vacuum tool hex (and the hotbar tool, if wanted) |
| | `VacuumCapacity` | Vacuum Capacity I–IV; Gem Upgrade Vacuum Capacity |
| | `VacuumRange` | Vacuum Range I–II |
| | `ChickenFeed` | Chicken Feed tool hex (and the hotbar tool), from the guide's feed-bag concept |
| Player | `WalkSpeed`, `ClickRange`, `OfflineTime` | Walk Speed, Click Range, Offline Time |
| Army | `Damage`, `Health`, `MarchSpeed`, `Armor`, `Recovery`, `BossDamage`, `Bounty`, `CaptureSpeed` | The Army subtree, one icon each |
| Gem Upgrades | `AutoRoll`, `CoinBoost`, `AutoRebirth`, `TimeSkip`, `MoreGems`, `KeepUpgrades`, `MutationLuck`, `OfflineCoins`, `ArmyPower`, `RebirthChickenOdds` | One icon each (plus the reused `RollSpeed`, `Luck`, `VacuumCapacity` and the Rally horn) |
| Currency and HUD | `Gems` | The Gems currency |
| | `FriendBoost` | Friend Boost line and its explanation |
| | `GoldRush` | Gold Rush countdown chip |

## Style

- **References.** Every prompt attaches `01-hud-navigation.png` (style) and the in-game Rally
  horn (outline weight). Chickens also attach the My Army chickens or soldiers icon, so they
  keep the game's boxy look and black stroke. Coins attach the gold coin, Gems the gem-pack
  screenshot, Auto Rebirth the Re-enlist icon, and Chicken Feed the guide's concept.
- **Modifiers** follow the reference tree's vocabulary. They are always bare symbols at the
  lower left, which keeps the lower right free for the tier number:
  - green plus = one more (Flock Size, Army Size, Roll Slot, More Gems)
  - green circular arrows = faster or more often (Egg Speed, Gold Rate, Capture Speed, Auto Roll)
  - green up arrows = more (Vacuum Capacity, Coin Boost, Army Power)
  - green fast-forward = Time Skip
- **Contrast.** Subjects avoid being mostly blue or mostly green, so they read on both the blue
  tree hexes and the bright green bought hexes. See the strip at the bottom of the sheet.
- **No text.** No words, numbers, prices or badges appear in any icon.

## Clean-up applied by `prepare.py`

The masters themselves are untouched; these fixes only go into the upload copies.

- **Every icon:**
  - the outer 6 px are cleared (one edit came back with a faint frame line);
  - specks of alpha 5 or less are dropped;
  - the artwork is trimmed and re-centred so its longest side fills 86% of the square;
  - the resize uses premultiplied alpha.
- **`OpenArmy`:** the generator keyed out the helmet's dark underside. That enclosed hole is made
  opaque again; its colour was intact.
- **`AutoRebirth`:** edits of the Re-enlist icon kept losing its heavy outline. A 22 px
  near-black stroke restores it and drops a stray hairline.

## Checks run

- **Upload copies:** all 43 are 512² RGBA, with transparent corners and 84–88% occupancy.
- **Holes:** a scan for see-through holes inside the artwork found only real gaps (gear and
  arrow centres, the first-aid kit handle, the ripple rings, gaps between legs).
- **Outlines:** checked on dark, blue, green and light backgrounds.
- **Not checked:** how the icons render in Studio or in a playtest.

## Regenerated during the pass

The rejected candidates were deleted:

- `EggVacuum`: added an unrequested green plus.
- `EggSpeed`: first a disc behind the arrows, then a see-through gap between the egg and its
  outline.
- `ClickRange`: the inside of the white glove came out transparent. It is now a yellow hand
  that matches the Player head.
- `FlockSize`: too busy (extra chickens, eggs and grass).
- `Health`: added an unrequested shield badge.
- `GoldRate`: drew a disc behind the arrows.
- `FriendBoost`, `OfflineTime`, `DiamondMachine`: redrawn with the heavy outline. Chickens must
  have a black stroke.
- `AutoRebirth`: see Clean-up.

In total, 58 image calls were made. Check the OpenAI usage page for the exact cost.

## Upload (lead)

After Stevin approves:

1. Upload `upload/*.png` (43 files) as group-owned Images, the same way as the gold coins
   (`assets/gold-coins-20261020/README.md`). `python3 prepare.py --rgba` also writes the raw
   RGBA bytes for the EditableImage path.
2. Record the asset ids in `upload-receipts.json` here.

The file keys are meant to be the registry keys in `ResearchAssets` / `UITheme`.

## Regenerating

1. Run `./generate.sh KEY...`. Candidates land in `raw/`.
2. Copy the chosen `raw/KEY-*.png` to `KEY.png`.
3. Run `python3 prepare.py KEY`, then `python3 review_sheet.py`.

Other modes:

- `./generate.sh variants` edits the chosen `EggVacuum`, `GoldMachine`, `RollSpeed` and `Gems`
  masters into their variants.
- `./generate.sh outline KEY...` redraws a master with the set's heavy outline.
