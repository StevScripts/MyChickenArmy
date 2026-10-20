# Upgrade icons — October 20, 2026 (overhaul session S6), v2

Icons for the October 20 overhaul: the new Upgrades tree, the Gem Upgrades, the Gems currency
and the new HUD pieces. Plan: `docs/team/OVERHAUL_PLAN_20261020.md`, section S6.

**Status:** Stevin approved v2 ("Alright this is perfect"). Two icons were added afterwards and
are on the review sheet for his look:
- `AutoRoll`, which replaces the v1 placeholder;
- `SellTrash`, the Sell menu marker that S13 asked for.

Both were made with the Codex CLI's built-in image tool, because the OpenAI API credits ran out.
Nothing is uploaded, nothing was done in Studio, and no game code changed.

## Why v2

Stevin's verdict on v1 (commit 8eb185d) was that the icons "don't look like the rest of the icons
in the game". v1 was anchored on the smooth Rally horn, and drifted into glossy clip art.

v2 follows DESIGN.md section 8 and the chunky-simulator-icons skill. Its main consistency
anchors are the approved in-game icons: the September 23 tree atlas and the October 2 research
icons. That family is voxel-built: chunky cubes and beveled blocks, bright flat colors, simple
per-face shading and a heavy near-black outline. Round things stay smooth and simple, like the
eggs, stopwatch and clover. `pilot-v2-vs-ingame.png` shows the first v2 pilots beside the
in-game icons.

## Files

| File | What it is |
| --- | --- |
| `<Key>.png` | The masters, exactly as generated: 1024² from the API, 1254² from Codex (`AutoRoll`, `SellTrash`). |
| `upload/<Key>.png` | 512² upload copies of the 34 new icons, made by `prepare.py` (see Clean-up). |
| `review-sheet.png` | Every node's icon in a mock tree hex or Gem card, with the in-game ones marked, plus a 64 px strip on four backgrounds. |
| `pilot-v2-vs-ingame.png` | The v2 pilots beside the in-game icons. |
| `generate.sh`, `prepare.py`, `review_sheet.py` | Prompts and references, upload copies, review sheet. |
| `codex/<Key>.prompt.txt` | The Codex CLI prompts for `AutoRoll` and `SellTrash`. |

## Decisions

- **Tier numbers are live text from S9, not part of the art.** As in the reference tree, the hex
  shows a big tier number and the name carries the Roman numeral ("Egg Speed II").
- **Same effect, same icon.** The Gem Upgrades Roll Speed, Extra Luck and Vacuum Capacity reuse
  the tree icons.
- **11 nodes keep their approved in-game icon (v2 change).** Earlier, Stevin agreed to replace
  all six tree icons. After his feedback, the in-game icons became the style source, and these
  nodes already have one that fits. They are uploaded already, so they need no new upload:

| Node | Icon in the game | Asset |
| --- | --- | --- |
| Egg Speed | Eggs + stopwatch (`cashEggSpeed`) | `rbxassetid://71023601644268` |
| Egg Value | Egg + gold coins (`cashEggValue`) | `rbxassetid://131663330897554` |
| Luck, Gem Extra Luck | Clover (`cashLuck`) | `rbxassetid://136683191941433` |
| Flock Size | Fenced yard with arrows (`cashPlotSize`) | `rbxassetid://137569434618832` |
| Army Size | Three chickens (`cashArmySize`) | `rbxassetid://92487563557623` |
| Roll Slot | Podium (`cashRollSlots`) | `rbxassetid://91702817085017` |
| Chicken Feed | Feed sack (research `feed`) | `rbxassetid://122007287446526` |
| March Speed | Boots (research `boots`) | `rbxassetid://137818969643923` |
| Health | First-aid kit (research `medkit`) | `rbxassetid://80368789706410` |
| Recovery | Bandage roll (research `bandages`) | `rbxassetid://120779534623977` |
| Rally (Gem) | Rally horn (`Theme.Assets.Rally`) | `rbxassetid://103846085793265` |

- **"Rainbow Machine"** is a working name for the tier above Diamond; S12 can rename the node.

## New icons (34)

| Group | Keys |
| --- | --- |
| Main tree | `RollSpeed` (also Gem Roll Speed), `GoldMachine`, `GoldRate`, `DiamondMachine`, `RainbowMachine` |
| Category hexes | `OpenTools`, `OpenPlayer`, `OpenArmy`, `Back` |
| Tools | `EggVacuum` (tool hex and hotbar tool), `VacuumCapacity` (also Gem Vacuum Capacity), `VacuumRange` |
| Player | `WalkSpeed`, `ClickRange`, `OfflineTime` |
| Army | `Damage`, `Armor`, `BossDamage`, `Bounty`, `CaptureSpeed` |
| Gem Upgrades | `AutoRoll`, `CoinBoost`, `AutoRebirth`, `TimeSkip`, `MoreGems`, `KeepUpgrades`, `MutationLuck`, `OfflineCoins`, `ArmyPower`, `RebirthChickenOdds` |
| Currency and HUD | `Gems`, `FriendBoost` (Friend Boost line), `GoldRush` (countdown chip) |
| Sell menu (S13) | `SellTrash`: the red trash can over a chicken card picked for sale. It goes in `Art.Trash` in `src/client/SellMenu.luau`. |

`AutoRebirth` is the Re-enlist icon (the in-game Rebirth button) with a gear added, so it pairs
with the Rebirth button.

## Style

- **References.** gpt-image-1.5, medium quality, 1024² transparent, via the chatgpt-image skill.
  - Voxel objects attach the in-game boots, first-aid kit and podium.
  - Round objects attach the in-game eggs + stopwatch, clover and boots.
  - Chickens add the in-game Army Size chickens (and the My Army soldiers for helmets).
  - Coins add the gold coin; Gems add the gem-pack reference.
  - In a two-icon test, gpt-image-1.5 matched the in-game outline weight better than
    chatgpt-image-latest.
- **Modifiers** are chunky bright-green symbols with a black outline at the lower left, like the
  in-game Flock Size arrows. The lower right stays free for the tier number.
  - plus = one more
  - circular arrows = faster or more often
  - up arrows = more
  - fast-forward = Time Skip
- **No text.** No words, numbers, prices or badges appear in any icon.

## Clean-up applied by `prepare.py`

The masters themselves are untouched; these fixes only go into the upload copies.

- **Every icon:**
  - the outer 6 px are cleared;
  - specks of alpha 5 or less are dropped;
  - the artwork is trimmed and re-centred so its longest side fills 86% of the square;
  - the resize uses premultiplied alpha.
- **Holes:** `Armor`, `MutationLuck` and `RainbowMachine` came back with see-through holes
  inside the outline: the breastplate's inside, the sparkle fills, the machine's slot and window.
  Their colour was intact, so only the alpha is restored.
- **Outlines:** every approved in-game icon has a heavy near-black contour about 2.2% of its
  longest side. Twenty-one new icons came back with thin, grey or coloured edges, so a contour
  of that width is laid under the art (`STROKE` in `prepare.py`). For `AutoRebirth` the same
  step also removes a stray hairline.

## Checks run

- **Upload copies:** all 34 are 512² RGBA, with transparent corners and 84–88% occupancy.
- **Holes:** a scan of the upload copies for see-through holes inside the artwork found only real
  gaps (arrow centres, the ripple ring, clock bells, the space inside the Rebirth ring, between
  falling coins and between legs).
- **Outlines:** the outer contour of every upload copy is now as dark as the in-game anchors'
  (the same measurement gives all in-game anchors 1.00, and every new icon 0.93–1.00). Checked
  by eye on dark, Upgrades blue, bought green and light backgrounds.
- **Not checked:** how the icons render in Studio or in a playtest.

## Upload (lead)

After Stevin approves:

1. Upload `upload/*.png` (34 files) as group-owned Images, the same way as the gold coins
   (`assets/gold-coins-20261020/README.md`). `python3 prepare.py --rgba` also writes the raw
   RGBA bytes for the EditableImage path.
2. Record the asset ids in `upload-receipts.json` here.

The 11 in-game icons above need no upload. The file keys are meant to be the registry keys in
`ResearchAssets` / `UITheme`.

## Regenerating

1. Run `./generate.sh KEY...`. Candidates land in `raw/`.
2. Copy the chosen `raw/KEY-*.png` to `KEY.png`.
3. Run `python3 prepare.py KEY`, then `python3 review_sheet.py`.

Other modes:

- `./generate.sh variants` edits the chosen `EggVacuum`, `GoldMachine`, `RollSpeed` and `Gems`
  masters into their variants. Auto Roll is the `RollSpeed` edit.
- `./generate.sh outline KEY...` redraws a master with a heavy outline.

Without API credits, use the Codex CLI. Its built-in `image_gen` runs on Stevin's ChatGPT plan
and supports transparency. Pass the prompt on stdin, because `-i` swallows a trailing argument.
Both icons were made on codex-cli 0.144.1 with `-m gpt-5.6-sol`, because that version rejected
the configured `gpt-6-astra`. The CLI is now 0.163.0, so the `-m` flag should no longer be needed.
The command used, from this folder:

```bash
codex exec -m gpt-5.6-sol -C "$PWD" --sandbox workspace-write -c model_reasoning_effort="medium" -i RollSpeed.png -i GoldRate.png -i ../research-20261002/icons/boots.png -i ../research-20261002/icons/medkit.png < codex/AutoRoll.prompt.txt
```

Each prompt tells Codex to copy its image to `raw/<Key>-codex.png`. Pick it the same way as an
API candidate. `SellTrash` attaches the boots, the first-aid kit and `EggVacuum.png`.

## Cost

- v1: 58 image calls.
- v2: 33 image calls (4 model-test calls, 6 pilot calls, 23 for the rest). The gpt-image-2 test
  and the first Auto Roll call returned errors and produced no image.
- Codex: two generations (`AutoRoll`, `SellTrash`) on the ChatGPT plan, not API credits.

Check the OpenAI usage page for the exact API cost.
