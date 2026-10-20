# Voxel eggs (October 20, 2026)

Owner request: every ownable chicken (126) lays its own egg, and the eggs are
real 3D voxel models, not images (the first image pass was rejected the same
day: "I want the actual 3d models of the eggs into the game").

## Contract

- Each egg on the ground is a clone of
  `ReplicatedStorage.PetRoll.Assets.EggMeshes[drop.species]` (Studio-owned
  MeshPart templates; Rojo ignores that folder). Missing species use `Duck`.
- The server already sends `species` on every drop; nothing server-side changed.
- A template's mesh origin is the egg's bottom centre and the mesh scales about
  it. `EggHeight` (1.75 studs, the old sprite's egg) is an attribute. The child
  `Glow` MeshPart (Neon, emissive voxels) shares the body's CFrame and scales
  with it. Legendary+ templates carry a `Sparkle` ParticleEmitter (1.5/3/5 per
  second for Legendary/Mythic/Secret).
- `EggView` turns each egg's decorated front toward the camera with a small
  per-egg twist; bottom stays on the ground while lay/stack/pickup scales play.
- Fallback: if `EggMeshes` is absent (scripts-only build), eggs use the baked
  256px images in `src/shared/EggArt.luau` (also kept for future UI icons).
  Preload those through an ImageLabel; a bare content string reports Failure.
- Loyalist guards are enemy-only and lay no eggs, so they have no egg models.

## Efficiency (all devices)

- One MeshPart per egg (two for the 60 species with glowing voxels); no welds,
  lights, Highlights or per-egg tweens. Anchored, CanCollide/CanTouch/CanQuery
  off, CastShadow off, box collision, `RenderFidelity` Automatic (engine LOD)
  for bodies. Glow parts are Precise so small faces never drop out.
- Greedy-meshed voxels: 1,000–2,800 triangles per egg, about 1,450 on average.
  The yard caps at `Config.EggMaxDrops` (80), so the worst case is ~120k
  triangles near the player, falling with distance through LOD. Eggs farther
  than `Config.EggSpriteMaxDistance` stop animating (existing EggController rule).
- Meshes download once per species per session, only for species that lay
  near the player.
- One layout for every device; nothing branches on input type.

## Regenerating

```
cd assets/voxel-eggs-20261020
python3 build_eggs.py [Id ...]      # images: png/ (review) + png256/ (fallback)
python3 export_meshes.py [Id ...]   # mesh/<Id>.json greedy quads
python3 -m http.server 8765 --bind 127.0.0.1   # then, in Studio Edit (MCP):
#   require(<EggMeshBuilder.luau as a temp ModuleScript>).Build({{id=..., rarity=...}}, "http://127.0.0.1:8765/mesh/")
```

`EggMeshBuilder.luau` publishes each egg with `AssetService:CreateAssetAsync`
and replaces its template. Save the place afterwards; templates live only in
the place file. Recipes: `render_eggs.py`, `egg_parts.py`, `egg_recipes.py`;
`chickens.csv` supplies rarity and main colour. A new chicken needs a recipe, a
mesh build and (optionally) a fallback image; until then it lays the Chicken egg.
Review canvas: claude.ai artifact "Voxel Chicken Eggs".
