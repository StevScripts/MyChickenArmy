# Voxel eggs (October 20, 2026)

Owner request: replace the single shared egg sprite with a unique voxel egg for
every ownable chicken (126), so the yard shows who laid what.

## Contract

- Each egg on the ground shows its layer's egg: `EggArt.Image(drop.species)`.
  The server already sends `species` on every drop; nothing server-side changed.
- `src/shared/EggArt.luau` maps species id → uploaded `rbxassetid`. A species
  without an entry, or an image that is still loading or failed, shows the
  classic Chicken voxel egg (`EggArt.Fallback`).
- `EggArt.Scale = 1.3` keeps the egg body the same on-screen size as the old
  sprite (the voxel art leaves headroom for hats, wings and glow). Apply it
  wherever an egg BillboardGui is sized (`EggView`, the intro cutscene).
- Rarity ladder is baked into the art, never added at runtime:
  Common/Uncommon matte; Rare+ glossy highlight; Epic+ sparkles (1→4);
  Legendary+ coloured glow (stronger toward Secret).
- Loyalist guards are enemy-only and lay no eggs, so they have no egg art.
- `Config.EggSpriteImage` is no longer read by eggs; keep it until the old
  asset is confirmed unused elsewhere.

## Efficiency (all devices)

- Same instances per egg as before: one anchor Part, one BillboardGui, one
  ImageLabel. No particles, beams, tweens or per-frame work were added; glow
  and sparkles are pixels in the image.
- 256×256 PNGs, about 25–85 KB each (5.5 MB for all 126). A client downloads
  only the species actually laid near it, once per session (`EggView`
  `whenReady` cache), so a typical yard of 10–30 species is 0.5–2 MB.
- No atlas on purpose: an atlas would force every player to download every
  egg even though a yard holds only a few species.
- Preload goes through an ImageLabel: `ContentProvider:PreloadAsync` on a bare
  `rbxassetid://` string reports Failure for image assets (verified Oct 20).
- One layout for every device; nothing branches on input type.

## Regenerating art

```
cd assets/voxel-eggs-20261020
python3 build_eggs.py            # all 126 → png/ (512 review) + png256/ (game)
python3 build_eggs.py Cowboy     # one egg
```

Recipes: `render_eggs.py` (renderer + first eight test eggs),
`egg_parts.py` (patterns, marks, accessories), `egg_recipes.py` (the rest).
`chickens.csv` supplies rarity and main colour. After a re-render, upload the
changed `png256/<Id>.png`, update `asset_ids.json` and `EggArt.Images`.
A new chicken needs a recipe, an upload and an `EggArt` entry; until then it
lays the Chicken egg. Review canvas: claude.ai artifact "Voxel Chicken Eggs".
