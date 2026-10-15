# Chicken Jockey rider retexture (October 15, 2026)

**Owner request:** keep the rider's look, but swap the shirt and trouser colours and change the
texture a little.

## What changed

The September rider used Mojang's own `zombie.png`. Its source is recorded in
`pet-roll-prototype/assets/chicken-jockey-v3-minecraft-20260923/provenance.json`.

Those rider texels are now repainted from scratch by `paint_rider.py`. The script does not read
any source texture.

| Part | Before | After |
|---|---|---|
| Shirt | Cyan | Purple, with buttons and a neck opening |
| Trousers | Purple | Teal |
| Shoes | Grey | Brown |
| Skin | Original green | Brighter green, with its own patch pattern |
| Face | Original face | New face: brows, two-tone eyes and a small mouth |

## Unchanged

- The chicken part of the atlas.
- The mesh, bones, clips, and the roughness, normal and metal maps.

## Files

- `rider-64x32.png`: the new skin in the 64x32 box layout.
- `color.png`: the full 1024 atlas, with the rider area replaced.
- `portrait-Jockey.png`: the new outlined portrait.

## Studio and code

- **Color map:** `ChickenAssets.Jockey.Body.PBR.ColorMap` is now `rbxassetid://89701192938461`.
  It was `rbxassetid://104355427998983`.
- **Backup:** the previous SurfaceAppearance is kept in
  `ServerStorage.JockeyRetexture20261015.Jockey_BeforePBR`.
- **Portrait:** the new portrait is `rbxassetid://78700775884727`, mapped in
  `src/client/ChickenPortraits.luau`.
