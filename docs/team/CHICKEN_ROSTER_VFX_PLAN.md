# Roster expansion VFX plan (October 15, 2026)

This plan covers effects for the 83 new chicken models in
`assets/chicken-roster-expansion-20261015/`.

**Built October 15** as native template effects plus a small burst/pulse hook. See
`CHICKEN_ROSTER_INTEGRATION.md` for exactly what shipped and the simplifications.

Each chicken's effect sketch also sits in its manifest entry (`vfxPlan`). The Blender scenes
include a few preview-only glow cubes (`preview_fx`). They show intent only, and none of them
are exported.

## 1. Use the systems we already have

| Need | Existing system | Notes |
|---|---|---|
| Looping particles (sparkle, smoke, stars) | `SpecialChickenVFX._anchor(name, bone, offset)` + `_emitter(anchor, key, color, rate, lifetime, size, speed, accel, transparency, light)` | Textures come from `ChickenAppearanceAssets.Textures` (`Glitter`, `Star`, `Smoke`, `Code`). Same pattern as the Golden Emperor glitter and the mutation auras. |
| Aura hugging the body | `SpecialChickenVFX._shell(...)` | Same as the Shadow and Cosmic mutation look. |
| Orbiting points (foxfire, shards, halo motes) | `_anchor` + `anchors[#anchors].orbit = {radius, height, start}` | Already drives the Cosmic orbit stars. |
| Hand-authored beams and particles | `ChickenVFX_Workbench` → `ChickenVFXPresets` → `RareChickenVFX` | Use this for complex looks (portal swirl, light shafts). |
| Simple motion (spin, pulse, flicker, bob) | TweenService with repeat/reverse | Required by AGENTS.md. No custom frame loops. |
| Lights | `PointLight`/`SpotLight` under an anchor attachment | Keep `Range` ≤ 8 and `Brightness` ≤ 2. Each light turns off with the emitters. |

**Rules for all of them:**
- Reduced motion and the existing `CullDistance = 110` turn everything off, as they do today.
- Particles are cosmetic only. No gameplay projectiles, no hitbox changes, no extra damage.
- **Budget per chicken:** at most 2 looping emitters, a combined `Rate` of 12 or less, 1 light
  and 1 tween group.
- Bursts tied to actions (Celebrate, Hit, Peck, Defeat) use `Emit(n)` with n ≤ 16. There is
  no looping rate for them.

**New hook needed:** today's special VFX only loop. Bursts need a call like
`Special:OnAction(name)` from `DuckAnimator`'s clip changes (Celebrate, Hit, Peck, Defeat,
Walk start). It's one small, client-only function that calls `emitter:Emit(n)`. It's the only
new runtime code this plan needs.

**Anchors:** the rig already has socket bones: `HatSocket`, `FaceSocket`, `BackSocket`,
`ChestSocket`, `WingSocket_L`/`_R`. Attach effects to those, or to Head/Body/Feet with an
offset, so they follow the animations. The offsets below are in Blender rig units. Multiply
by the species `unitScale` (0.67) and map Blender −Y (forward) to Roblox −Z, then fine-tune
in the workbench.

## 2. New particle textures to make

Generate each one image-first with the black-outline icon style. Transparent PNG, 64–128 px.

| Key | Used by |
|---|---|
| `Ember` | Phoenix, Dragon Hatchling, Dragon Knight, Pumpkin |
| `Flame` | Phoenix, Mecha thrusters, Kitsune foxfire |
| `Bubble` | Deepsea Diver, Coral Reef, Kraken |
| `Bat` | Vampire |
| `Zzz` | Pajama |
| `Confetti` | Party, Court Jester, Firework |
| `Note` (bell/jingle) | Court Jester, Gingerbread |
| `Sand` | Pharaoh, Time Keeper, Mummy dust |
| `Ink` | Kraken |
| `Spark` | Animatronic, Ironbeak, Castle Guard, Firework fuse |
| `Rune` | The First Hen |

`Glitter`, `Star` and `Smoke` already exist and cover the rest.

## 3. Per-chicken plan

Legend:
- **Loop:** always on while the chicken is visible.
- **Burst:** fires on an action via the new hook.
- **Tween:** a TweenService loop.

### Mythic (do first; effects are what sell these)

| Chicken | Effects |
|---|---|
| The First Hen | Tween: rune emission pulse (atlas emission on the skin material; Brightness 1→2.5, 2 s, reverses). Loop: `Sand` motes rising, gold, rate 3, Body shell. Burst Celebrate: `Rune` ring, 12. |
| Rift Walker | Loop: `Star` along the seam, magenta/cyan ColorSequence, rate 6, anchor Body (0, −1.2, 2.2). Tween: the 6 shard props orbit/bob (±0.15, 1.6 s). Burst Walk: `Smoke` void wisps (purple), 4. |
| Supernova | Tween: PointLight Brightness 1→2 pulse (warm white, Range 7). Loop: `Glitter` hot-white shell, rate 5. Burst Celebrate: `Star` radial burst, 16. |
| Time Keeper | Tween: wing clock hands rotate (minute 6 s/rev, hour 72 s/rev; hands are separate prop cuboids, so split them at import) and the head gear spins (4 s/rev). Loop: `Sand` falling inside the hourglass, rate 3, anchor Body (0, 0.75, 3.5). |
| Mecha | Loop: `Flame` thrusters under each boot, orange, rate 4 each, short lifetime (0.2–0.35). Tween: visor emission pulse. Burst Celebrate: thruster burst, 10 per boot. |
| Kitsune Spirit | Loop: 3 orbit anchors (radius 1.6, height 0.6), `Flame` foxfire in blue (90,170,255), rate 3 each (the only chicken allowed 3 emitters, since the orbit is its identity). Burst Walk: `Smoke` spirit wisps (white), 3. |
| Kingslayer | Loop: `Glitter` gold on the crown, rate 2, anchor HatSocket. Burst Celebrate: `Confetti` gold/purple, 14. |
| Ascendant | Tween: the two body halo rings rotate (opposite directions, 6 s/rev) and the head halo bobs. Loop: `Glitter` pearl shell, rate 4. Later, one extra ring per Rebirth (runtime toggle). |

### Legendary

| Chicken | Effects |
|---|---|
| Phoenix | Loop: `Ember` from the tail plume, rate 5, anchor BackSocket. Burst Walk: `Flame` trail, 3. Burst Defeat: `Flame` flare + `Ember` rise, 16. |
| Unicorn | Loop: `Glitter` pastel ColorSequence trail, rate 4, anchor Body back. Burst Celebrate: `Star` pastel burst, 12. Tween: horn emission shimmer. |
| Kraken | Burst Hit: `Ink` splash, 8. Loop: `Bubble` drips from the tentacles, rate 1.5. |
| Dragon Knight | Loop: eye glow (emission is already in the atlas) + `Ember` sparks, rate 2, FaceSocket. Burst Celebrate: `Smoke` from the horns, 6. |
| Geode | Light: purple PointLight (Range 5, Brightness 1). Loop: `Glitter` violet on the crystals, rate 3. Burst Hit: crystal shards (`Spark` tinted violet), 8. |
| Airship Captain | Tween: propeller spin (0.4 s/rev, Linear, infinite; the blades are one prop cuboid pair, so split at import). Loop: `Smoke` puffs from the pack, rate 0.6. |
| Pharaoh | Loop: `Sand` swirl around the feet, rate 3, Root anchor. Burst Celebrate: `Glitter` gold, 10. |
| Stained Glass | Light: soft PointLight that slowly cycles through the pane colors (Color tween, 6 s). Burst Celebrate: Workbench preset with 3 colored light-shaft Beams (0.6 s). |
| Moon | Light: pale-blue PointLight (Range 6, Brightness 0.8). Loop: `Star` twinkles on the wings, rate 2. |
| Witch | Loop: `Star` motes around the hat, rate 2, HatSocket. Burst Celebrate: green `Glitter` cauldron sparkle, 14. |
| Firework | Loop: `Spark` from the fuse tip, rate 6, HatSocket (0, 0, 0.5). Burst Celebrate: `Confetti` + `Star` firework burst above the head, 16. |

### Epic

| Chicken | Effects |
|---|---|
| Pumpkin | Light: warm flickering PointLight inside the carved face (Brightness tween 0.6↔1.1, 0.15–0.3 s, reverses; Range 5). Burst Celebrate: `Ember`, 8. |
| Animatronic | Tween: right-eye emission flicker (on/off, random 2–5 s gaps via a re-armed tween). Burst Hit: `Spark` from the neck wires, 6. |
| Vampire | Burst Celebrate: `Bat` swarm, 5 (spread 60°, upward). Loop: none. Faint red eye emission is already in the atlas. |
| Deepsea Diver | Loop: `Bubble` from the helmet valve, rate 2, HatSocket. Porthole glint: `Glitter`, rate 0.5. |
| Dragon Hatchling | Burst Peck: `Ember` puff from the beak, 5. Burst Celebrate: `Smoke` ring, 6. |
| Neon | Light: pink/cyan underglow PointLight (Color tween between the two, 2 s). Burst Hit: emission flicker tween (0.1 s × 3). |
| Gingerbread | Burst Celebrate: snowflakes (`Star` white), 10 + `Note` jingle, 3. |
| Royal Guard, Norse Raider | No VFX needed. Optional sound only (Norse war horn on Celebrate). |

### Rare and below

| Chicken | Effects |
|---|---|
| Zombie Hunter | Light: SpotLight from the chest lamp, forward, Angle 35, Range 8, Brightness 1.2. |
| Mummy | Light: green eye PointLight (Range 3). Burst Walk: `Sand` dust, 3. Burst Defeat: `Smoke` dust, 10. |
| Court Jester | Burst Celebrate: `Confetti`, 10 + `Note`, 2. |
| Ironbeak, Castle Guard | Burst Peck / Hit: `Spark`, 4. |
| Steampunk Scratcher | Loop: `Smoke` steam puff from the back pipe, rate 0.5. Tween: side gears rotate (3 s/rev, alternating directions). |
| Detective | Burst Celebrate: lens `Glitter` glint, 3. |
| Miner | Light: SpotLight from the headlamp, forward/down, Angle 40, Range 8. Burst Peck: `Spark`, 3. |
| Coral Reef | Loop: `Bubble`, rate 0.8. |
| Pajama | Loop (Idle only): `Zzz`, rate 0.5, HatSocket. |
| Party | Burst Celebrate: `Confetti`, 14. |
| Popcorn | Burst Hit: kernels (`Confetti` tinted cream/butter), 6. |
| Gamer | Tween: headset rings and wing-tip RGB Color3 cycle (Highlight-free; tween the emission color of a small separate glow part, 3 s loop). |
| Donut | Burst Celebrate: sprinkles (`Confetti`), 10. |
| Piggy | Burst Defeat: mud splat (`Smoke` brown), 6. |
| Everyone else (Hatchling, Silkie, Speckled Hen, Bacon Hair, Scarecrow, Crate Runner, Lumberjack, Cow, Sushi, Frog, Paratrooper, Firefighter, Chef, Samurai, Cowboy) | No VFX. Commons stay clean, which keeps rarity readable. Optional sounds: cowbell, ribbit, oink. |

### Round two (batches 7–9)

| Chicken | Effects |
|---|---|
| Eclipse (Mythic) | Tween: corona emission pulse. Loop: 2 orbit anchors with `Ember` flare wisps, rate 2 each. Loop: deep-red `Smoke` shell, rate 3. |
| Forest Guardian (Mythic) | Tween: mushroom glow pulse. Loop: green `Glitter` firefly motes, rate 3. Burst Celebrate: leaf burst (`Confetti` tinted green), 10. |
| Valkyrie (Legendary) | Tween: spear-tip glow pulse. Burst Peck: blue `Spark` trail, 4. Burst Celebrate: feather `Glitter`, 8. |
| Griffin (Legendary) | Burst Celebrate: white/brown feather burst, 10. Sound: screech. |
| Jade (Legendary) | Loop: green `Glitter` glint, rate 1.5. Burst Celebrate: gold `Glitter`, 8. |
| Olympian (Legendary) | Tween: lightning bolt glow pulse. Loop: small `Spark` arcs on the bolt, rate 2. Burst Celebrate: `Glitter` gold, 10. |
| Aurora (Legendary) | Tween: emission strength 1.5↔2.5 (4 s). Light: soft green PointLight. |
| Yeti (Epic) | Loop: pale-blue `Star` frost, rate 2. Burst Celebrate: breath puff (`Smoke` white), 4. |
| Mimic (Epic) | Burst Celebrate: lid snap (rotation tween on the split lid part) + gold `Glitter`, 10. |
| Gladiator (Epic) | Burst Hit: `Spark` from the shield, 4. |
| Ghost (Rare) | Set the MeshPart Transparency to about 0.25 at import. Tween: slow bob (±0.15, 2 s). Loop: cyan `Smoke` wisps, rate 2. |
| Rockstar (Rare) | Burst Celebrate: `Note`, 4. |
| Snowman (Rare) | Loop: white `Star` snowfall, rate 2. Burst Hit: snow puff, 6. |
| Painter (Uncommon) | Burst Celebrate: paint splat (`Confetti`), 10. |
| Doctor, Police, Archer, Rooster, Sheep, Plushie, Mailman, Raincoat, Skater, Taco, Sunflower | No VFX. Optional sounds and small extras are in each manifest entry. |

## 4. Build order for the VFX pass

1. Add the `OnAction` burst hook (client, small) and the 11 new textures.
2. Mythic and Legendary chickens first (16), then Epic (9), then Rare and below.
3. For each chicken:
   - add a branch in `SpecialChickenVFX` keyed by species ID, or a workbench preset for the
     beam-heavy ones (Stained Glass shafts, Rift Walker swirl);
   - play-test Idle, Walk, Peck, Hit, Defeat and Celebrate at army scale (10 chickens) and
     check the frame time.
4. Run the reduced-motion and cull-distance check per chicken.

Splitting the prop cuboids that need to move (Time Keeper hands, Airship Captain propeller,
Ascendant rings, Steampunk gears) happens at Studio import. The GLB keeps them in one
skinned prop mesh, so the integration step separates those cuboids into their own
MeshParts. They stay welded or bone-attached, so the six clips are unaffected.
