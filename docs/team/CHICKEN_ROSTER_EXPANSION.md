# Chicken roster expansion: 50 new chickens (draft, October 15, 2026)

Status: **all ideas approved by the owner on October 15, plus the chat requests in §5b.
All 83 models (58 + round two's 25) are built in Blender and pass the export checks:
`assets/chicken-roster-expansion-20261015/` (see its README). The effect design is in
`CHICKEN_ROSTER_VFX_PLAN.md`. Nothing is imported into Studio or added to the catalog yet.**
Goal: grow from 46 chickens to 103 without lowering quality.

## 1. What we have today (46)

Each **strength band** below has fixed stats and a fixed share of every roll (see
`src/shared/ChickenLuck.luau`). A new chicken joins one band. It takes that band's stats,
so the band's total odds never change and only the chicken's share inside the band is new.
More members in a band means each one is a bit rarer to pull.

| # | Band (stats key) | Rarity | Roll share at Luck 0 | Current chickens | Count |
|---|---|---|---|---|---|
| 1 | Chicken (`Duck`) | Common | ~38% | Chicken, Noob Chick | 2 |
| 2 | Brown (`Mallard`) | Common | ~22% | Brown Chicken, Rubber Ducky, Penguin Chicken, Cardboard Commando | 4 |
| 3 | Chunky (`Chunky`) | Uncommon | ~22% | Chunky, Cheesy, Mushroom, Camo Chick, Bee, Honeycomb, Lollipop, Cactus Clucker | 8 |
| 4 | Robo (`Bucket`) | Rare | ~9% | Robo-Cluck, Zombie, Tiger, Jungle, Bonsai Bantam | 5 |
| 5 | Crystal (`Viking`) | Rare | ~5% | Crystal, Sir Clucks-a-Lot, Slime Squawker, Skeleton, Pirate | 5 |
| 6 | Magma (`Knight`) | Epic | ~3% | Magma, Frost Feather, Ninja, Shadow Stalker, Storm Wing, Chicken Jockey, Toxic · *Astronaut (crate), Pumpkin (Halloween)* | 7 + 2 |
| 7 | Shadow (`Wizard`) | Legendary | ~0.7% | Diamond Defender, Solar Flare, Golden Emperor, Water · *Alien (crate)* | 4 + 1 |
| 8 | Golden (`Dragon`) | Legendary | ~0.25% | Rainbow Rider | 1 |
| 9 | Glitch (`IceDuck`) | Mythic | ~0.05% | Glitch, Heavenly, Devil | 3 |
| 10 | Galaxy (`StormDuck`) | Mythic | ~0.01% | Galaxy Overlord · *Dark Matter, Cosmic Dragon (crate), Hill Champion (Hill)* | 1 + 3 |

The roll shares are approximate. `TopBandKeep` pushes part of band 10's share down into
band 9.

**Gaps:** bands 1, 8 and 10 have only one or two rollable chickens, so a whole rarity
shows the same bird. Common has 6 chickens in total. Camps and missions are fought with
the same 11 legacy looks (Robo, Crystal, Magma, Shadow…), so no zone has enemies of its
own.

**Off-limits themes:** Watermelon and Graffiti, which you excluded on September 22. Also
avoid names that clash with the mutations (Golden, Rainbow, Shadow, Cosmic) and with the
internal IDs (`Viking`, `Knight`, `Wizard`, `Dragon`, `Sailor`, `Bucket`…).

## 2. The plan in numbers

| Band | Rarity | Now | +New | After |
|---|---|---:|---:|---:|
| 1 Chicken | Common | 2 | 6 | 8 |
| 2 Brown | Common | 4 | 5 | 9 |
| 3 Chunky | Uncommon | 8 | 6 | 14 |
| 4 Robo | Rare | 5 | 6 | 11 |
| 5 Crystal | Rare | 5 | 6 | 11 |
| 6 Magma | Epic | 9 | 6 | 15 |
| 7 Shadow | Legendary | 5 | 5 | 10 |
| 8 Golden | Legendary | 1 | 4 | 5 |
| 9 Glitch | Mythic | 3 | 3 | 6 |
| 10 Galaxy | Mythic | 4 | 3 | 7 |
| **Total** | | **46** | **50** | **96** |

Section 5 adds 4 special (non-roll) chickens, which brings the total to **100**.

**Theme ladder:** each rarity should look as rare as it is.
- **Common:** farm life and everyday jokes, mostly texture only.
- **Uncommon:** food, hobbies and nature, with one small prop.
- **Rare:** jobs and costumes.
- **Epic:** elements and fantasy creatures.
- **Legendary:** royal and legendary materials, with a signature effect.
- **Mythic:** cosmic or mythic beings, with animated effects.

**Build tags:**
- **T:** texture only, like the September 22 skins. Fastest.
- **P:** fitted props weighted to existing bones.
- **V:** needs a Roblox-side effect (light, particles, tween). In Blender, effects are
  preview-only.

**Zone chickens (★):** their theme matches a camp, the King or a mission site. Section 4
explains how they'd show up there.

## 3. The 50 chickens

### Band 1: Common (Chicken stats), +6

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 1 | Hatchling (`Hatchling`) | Fluffy pale-yellow chick wearing the top half of its cracked egg as a cap (Head) | — | The egg game's "first chicken" | T+P |
| 2 | Speckled Hen (`Speckled`) | Black-and-white barred feathers (Plymouth Rock pattern) | — | A real breed, reads instantly | T |
| 3 | Silkie (`Silkie`) | Fluffy white coat, dark face, big poof pom on the head | — | Real breed, cutest silhouette in the game | T+P |
| 4 | Scarecrow Chicken (`Scarecrow`) | Burlap stitching, straw tufts at the wing tips, floppy straw hat | — | Farm theme | P |
| 5 | Pajama Chicken (`Pajama`) | Blue star-print pajamas, nightcap with pom (Head) | Optional "Zzz" while idle | Funny, cozy idle look | T+P(+V) |
| 6 | Bacon Hair Chick (`BaconHair`) | Classic Roblox bacon-hair strip on the head, plain body | — | Roblox meme, sits with Noob Chick | T+P |

### Band 2: Common (Brown stats), +5

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 7 | ★ Crate Runner (`CrateRunner`) | Tan cargo vest, small crate backpack (Body), cap | — | **Supply Depot** guard | P |
| 8 | Lumberjack Chicken (`Lumberjack`) | Red-black buffalo plaid, knit beanie | — | Strong pattern from far away | T+P |
| 9 | Party Chicken (`Party`) | Confetti speckles, striped cone party hat | Confetti burst on Celebrate | Win screens feel like a party | T+P+V |
| 10 | Cow Chicken (`Cow`) | Holstein spots, tiny horns, cowbell on the chest | — | Farm crossover | T+P |
| 11 | Piggy Chicken (`Piggy`) | Pink with a pig snout over the beak, curly tail (Body) | — | Farm crossover, kid-favorite | T+P |

### Band 3: Uncommon (Chunky stats), +6

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 12 | ★ Miner Chicken (`Miner`) | Hard hat with headlamp (Head), soot smudges, tiny pickaxe on a wing | Headlamp light | **Crystal Mine** worker | P+V |
| 13 | Sushi Chicken (`Sushi`) | Rice-white body, salmon slab on the back, nori band | — | Food line (Cheesy, Lollipop, Honeycomb) | T+P |
| 14 | Donut Chicken (`Donut`) | Pink frosting top half with sprinkles, golden dough bottom | — | Food line, bright icon | T |
| 15 | Popcorn Chicken (`Popcorn`) | Lumpy kernel texture, red-white striped wings | Kernels pop on Hit | Pun everyone gets | T+V |
| 16 | Gamer Chicken (`Gamer`) | Headset (Head), RGB-striped wing tips | Slow RGB color cycle | Players see themselves in it | T+P+V |
| 17 | Frog Chicken (`Frog`) | Green with bulging frog-eye bumps, lily pad hat | — | Nature line (Jungle, Bee, Mushroom) | T+P |

### Band 4: Rare (Robo stats), +6

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 18 | ★ Paratrooper Chicken (`Paratrooper`) | Olive jumpsuit, aviator goggles, parachute pack (Body) | — | **Loyalist Landing** airship drop | P |
| 19 | Firefighter Chicken (`Firefighter`) | Red helmet with badge, yellow reflective stripes | — | Job costume | T+P |
| 20 | Chef Chicken (`Chef`) | Tall toque, apron, wooden spoon on a wing | — | Dark-funny, very shareable | T+P |
| 21 | Detective Chicken (`Detective`) | Deerstalker cap, tan trench coat, magnifying glass on a wing | — | Job costume | T+P |
| 22 | ★ Coral Reef Chicken (`Coral`) | Coral-pink and teal patches, starfish on the head, barnacle bumps | — | **Pirate Cove** shallows | T+P |
| 23 | Mummy Chicken (`Mummy`) | Bandage-wrapped body, one glowing eye | Eye glow | Spooky line (Zombie, Skeleton) | T+V |

### Band 5: Rare (Crystal stats), +6

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 24 | ★ Castle Guard Chicken (`CastleGuard`) | Steel kettle helmet, crested tabard, small round shield on a wing | — | **Watchtower Fort** defender | P |
| 25 | ★ Court Jester (`Jester`) | Two-tone harlequin diamonds, jester hat with bells | Bell jingle on Celebrate | **Chicken King's Court** | T+P+V |
| 26 | ★ Ironbeak Chicken (`Ironbeak`) | Riveted iron beak, scar over one eye, dog tag | — | **Ironbeak HQ** camp mascot | T+P |
| 27 | Samurai Chicken (`Samurai`) | Red lacquer helmet with a gold crest, plated chest | — | Pairs with Ninja (Epic) | P |
| 28 | Cowboy Chicken (`Cowboy`) | Stetson, neck bandana, sheriff star | — | Classic costume | P |
| 29 | Steampunk Scratcher (`Steampunk`) | Brass goggles, copper gear back plate, rivets | Small steam puff | From the September 16 backlog | P+V |

### Band 6: Epic (Magma stats), +6

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 30 | ★ Deepsea Diver (`DeepseaDiver`) | Brass diving helmet with a round porthole, air hose | Bubble trail | **Pirate Cove**. From the September 16 backlog | P+V |
| 31 | ★ Dragon Hatchling (`DragonHatchling`) | Red-orange scales, eggshell shards on the head, nub horns | Ember puff on Peck | **Dragon Roost** nest | T+P+V |
| 32 | ★ Royal Guard Chicken (`RoyalGuard`) | Tall black bearskin hat, red coat, gold buttons | — | **Chicken King's Court** | P |
| 33 | Neon Chicken (`Neon`) | Black body with glowing pink and cyan outline seams | Emission glow | Pops at night and in Index cards | T+V |
| 34 | Vampire Chicken (`Vampire`) | Pale feathers, high-collar cape, tiny fangs | Bats on Celebrate | Spooky line, Epic level | P+V |
| 35 | Norse Raider (`NorseRaider`) | Horned iron helmet, braided beard, fur shoulder wrap | — | The Viking fantasy, under a non-clashing ID | P |

### Band 7: Legendary (Shadow stats), +5

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 36 | ★ Geode Chicken (`Geode`) | Rough grey rock shell, cracked open on the chest and wings to show glowing amethyst | Crystal glow | **Crystal Mine** treasure. Unlike Crystal (Rare) and Diamond | T+P+V |
| 37 | Pharaoh Chicken (`Pharaoh`) | Gold-and-blue striped headdress, gold collar | Sand swirl | Ancient-royal fantasy | P+V |
| 38 | ★ Airship Captain (`AirshipCaptain`) | Captain's hat, long coat, brass telescope, small propeller pack | Spinning propeller (tween) | **Loyalist Landing** commander | P+V |
| 39 | Stained Glass Chicken (`StainedGlass`) | Jewel-colored glass panes with black lead lines | Soft glow | Looks like nothing else in the game | T+V |
| 40 | Moon Chicken (`Moon`) | Pale silver with crater texture, crescent crest | Moon-glow halo | Night pair to Solar Flare | T+P+V |

### Band 8: Legendary (Golden stats), +4

Today Rainbow Rider is this band's only chicken.

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 41 | Phoenix Chicken (`Phoenix`) | Flame-gradient feathers, long fiery tail plume | Fire trail. Flare on Defeat | Ties into the Rebirth theme | T+P+V |
| 42 | ★ Dragon Knight (`DragonKnight`) | Dragon-scale armor, horned dragon-skull helmet | Ember eyes | **Dragon Roost** honor guard | P+V |
| 43 | Unicorn Chicken (`Unicorn`) | White with a pastel mane and a golden horn | Sparkle trail | Kid-favorite. Sits next to Rainbow Rider | P+V |
| 44 | ★ Kraken Chicken (`Kraken`) | Deep purple, tentacle "beard" on the head, sucker texture | Ink splash on Hit | **Pirate Cove** legend | T+P+V |

### Band 9: Mythic (Glitch stats), +3

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 45 | Time Keeper (`TimeKeeper`) | Clock-face wings, small hourglass on the back | Slow falling-sand particles | Mythic and mysterious | T+P+V |
| 46 | Mecha Chicken (`Mecha`) | Full white-red mech armor, visor, jet boots (Feet) | Thruster glow | The "final form" of Robo-Cluck | P+V |
| 47 | Kitsune Spirit (`Kitsune`) | White with red spirit markings, fox ears | Floating foxfire orbs | Spirit-mythic, unlike Heavenly and Devil | T+P+V |

### Band 10: Mythic (Galaxy stats), +3

Today Galaxy Overlord is this band's only rollable chicken.

| # | Name (`ID`) | Look and props | Effect | Hook | Build |
|---|---|---|---|---|---|
| 48 | The First Hen (`FirstHen`) | Ancient carved-stone hen, glowing golden runes, stone egg on the back | Rune pulse | The game's origin myth, "mother of all chickens" | T+P+V |
| 49 | Rift Walker (`RiftWalker`) | Split down the middle: normal feathers on one side, starry void on the other, glowing seam | Portal swirl | Top chase chicken, unlike Galaxy and Dark Matter | T+V |
| 50 | Supernova Chicken (`Supernova`) | White-hot core fading to orange rays | Pulsing light burst | Brightest chicken in the game | T+V |

## 4. Zone chickens: where you'd meet them

Fights already pull their stats from a band, so a camp or mission can swap an enemy's
**look** to a new chicken in the same band without changing difficulty. Players fight a
Kraken at Pirate Cove, then chase one in rolls.

| Zone | Chickens (band) |
|---|---|
| Ironbeak HQ (home camp) | Ironbeak Chicken (5) |
| Chicken King's Court | Court Jester (5), Royal Guard (6) |
| Loyalist Landing (mission) | Paratrooper (4), Airship Captain (7) |
| Watchtower Fort (mission) | Castle Guard (5) |
| Supply Depot (mission) | Crate Runner (2) |
| Crystal Mine (mission) | Miner (3), Geode (7) |
| Pirate Cove (mission) | Coral Reef (4), Deepsea Diver (6), Kraken (8) |
| Dragon Roost (mission) | Dragon Hatchling (6), Dragon Knight (8) |

Mission rosters reach Mythic stats at the Royal tier, but zone chickens stop at band 8. At
the highest tiers, the rosters mix zone looks with the existing Mythics.

**Your decision:** how players get zone chickens.
- **(a) Recommended:** normal rolls only. The zone just shows them off. No new mechanic.
- **(b)** A small drop chance on a mission win. The missions plan already asked whether
  you want "a chicken" as a reward kind. This is a new earn path, so it needs your OK.

## 5. Four special chickens (to reach 100)

These have zero roll weight, like Pumpkin and Hill Champion, so they never change roll
odds.

| Name (`ID`) | How it's earned | Look |
|---|---|---|
| Gingerbread Chicken (`Gingerbread`) | Christmas 2026 limited, Epic band (same pattern as Pumpkin) | Gingerbread body, white icing outlines, gumdrop buttons |
| Firework Chicken (`Firework`) | New Year 2027 limited, Legendary band | Night-blue with burst patterns. Firework pop on Celebrate |
| Kingslayer (`Kingslayer`) | **Needs your OK:** beat the Chicken King N times (like Hill Champion's wins) | The King's broken crown worn crooked, royal cape |
| Ascendant Chicken (`Ascendant`) | **Needs your OK:** reach Rebirth N | Pearl-white with orbiting halo rings, one ring per Rebirth |

## 5b. Player requests from in-game chat (added October 15)

You approved all 50 plus the four specials. Players then asked for FNAF, Bacon,
Resident Evil, Leon, Halloween and Witch chickens.

FNAF, Resident Evil and Leon are other companies' characters. On Roblox that risks
moderation or a takedown. Chica, FNAF's chicken animatronic, is the closest risk of all.
So each of these is an **original chicken with the same vibe**, with no names, logos or
signature outfits from those games.

| Name (`ID`) | Player ask | Band | Look and props | Effect |
|---|---|---|---|---|
| Pumpkin Chicken (`Pumpkin`, existing ID) | "What happened to the Halloween chicken?" | 6 Epic (Halloween limited) | Orange body, carved jack-o'-lantern head piece where the comb is, green leaf stem (Halloween spec in `launch/15_H1_HALLOWEEN.md`) | Warm glow inside the carved face |
| Witch Chicken (`Witch`) | Witch | 7 Legendary | Tall crooked purple hat with a buckle, star-patterned cloak, tiny broom on a wing | Green cauldron sparkles on Celebrate |
| Animatronic Chicken (`Animatronic`) | FNAF | 6 Epic | Worn pizza-party robot: scuffed plastic shell, visible jaw hinge, exposed wires at the joints, one flickering eye. Not Chica's yellow, not a bib, no cupcake | Eye flicker |
| Zombie Hunter (`ZombieHunter`) | Resident Evil / Leon | 5 Rare | Bomber jacket, tactical vest, swept hair fringe, flashlight on the vest. Sits next to Zombie Chicken | Flashlight beam |

**Bacon:** Bacon Hair Chick (#6) already covers this.

**Pumpkin:** the catalog entry and the event code exist, but there's still no authored
model, so it falls back to Magma Chicken's shape. The event ends November 1, and the
Halloween doc says the model is needed by about **October 22**. That's why it goes first.

**New total:** 46 + 50 + 4 specials + 3 player requests = **103 chickens**. That's 57
new models plus the Pumpkin remake.

## 5c. Round two: 25 more (owner request, October 15)

These spread across the strength bands. Bands 1–7 get 3 each, bands 8–9 get 2. They're
built as batches 7–9 with the same process, in the same package.

| Batch | Band | Chickens |
|---|---|---|
| 7 | 1 Common | Rooster, Sheep Chicken, Plushie Chicken |
| 7 | 2 Common | Mailman Chicken (★ Supply Depot), Raincoat Chicken, Skater Chicken |
| 7 | 3 Uncommon | Taco Chicken, Painter Chicken, Sunflower Chicken |
| 7 | 4 Rare | Snowman Chicken |
| 8 | 4 Rare | Police Chicken, Doctor Chicken (no red-cross emblem) |
| 8 | 5 Rare | Ghost Chicken, Archer Chicken (★ Watchtower Fort), Rockstar Chicken |
| 8 | 6 Epic | Yeti Chicken, Mimic Chicken (★ Pirate Cove), Gladiator Chicken |
| 8 | 7 Legendary | Olympian Chicken, Aurora Chicken |
| 9 | 7 Legendary | Jade Chicken |
| 9 | 8 Legendary | Griffin Chicken, Valkyrie Chicken |
| 9 | 9 Mythic | Eclipse Chicken, Forest Guardian |

New total after round two: **128 chickens**.

## 6. How we'd build them (per the art guide)

For each chicken:
1. Clone the approved rig from `Chicken-Expansion-v1.blend` into a new `Expansion_<ID>`
   scene.
2. Make a reference image and a palette.
3. Fit the props to the existing 18 bones (Head, Body, Wings, Feet).
4. Render the real model plus action poses for review.

Keep the 168 base vertices, the proportions, the weights and the six clips (Idle, Walk,
Peck, Hit, Defeat, Celebrate).

Deliver per chicken:
- an animated GLB with embedded textures
- a bind-pose FBX
- the `.blend`
- textures, preview renders and a manifest entry

Then run an export check: the skinned mesh is present, all six clips are there, and no
preview-only objects got exported.

Things to plan for:
- **Batches of ~10.** Start with the thin bands and the zone chickens, since missions are
  being built now:
  - **Batch 1:** Hatchling, Silkie, Speckled Hen, Crate Runner, Miner, Castle Guard,
    Phoenix, Unicorn, Kraken, The First Hen.
- **Complex props** (diving helmet, steampunk gear, mech armor) were deferred before for
  Tripo. All 3D generators are **off** in the Blender add-on right now, so those props
  would be hand-modeled in the same chunky low-poly style. Turn a generator on if you'd
  rather use one.
- **Effects** (glows, trails, particles) are previews in Blender. Each **V** chicken needs
  a matching Roblox-side effect at integration.
- **Icons:** every new chicken needs its Index and portrait icon with the black outline
  stroke.
- **Integration comes later** and is coordinated: Studio import into
  `ReplicatedStorage.PetRoll.ChickenAssets`, a `PetCatalog` variant line with a weight,
  and a `ChickenAppearanceAssets` entry. New IDs only, so no save risk.

## 6b. Build order (58 models, 7 batches)

| Batch | Why first | Chickens |
|---|---|---|
| 0 Halloween | Event deadline (model by ~Oct 22) | Pumpkin (remake), Witch, Animatronic, Zombie Hunter, Mummy, Vampire |
| 1 Thin bands + chase | Fills the one-chicken rarities | Hatchling, Silkie, Speckled Hen, Bacon Hair, Phoenix, Unicorn, Kraken, The First Hen, Rift Walker, Supernova |
| 2 Zone chickens | Missions are being built now | Crate Runner, Miner, Paratrooper, Coral Reef, Castle Guard, Court Jester, Ironbeak, Deepsea Diver, Dragon Hatchling, Royal Guard |
| 3 Legendary/Mythic | High-value pulls | Geode, Airship Captain, Dragon Knight, Pharaoh, Stained Glass, Moon, Time Keeper, Mecha, Kitsune Spirit |
| 4 Common/Uncommon | Mostly texture work, fast | Scarecrow, Pajama, Lumberjack, Party, Cow, Piggy, Sushi, Donut, Popcorn, Gamer, Frog |
| 5 Rare/Epic | Costume props | Firefighter, Chef, Detective, Samurai, Cowboy, Steampunk, Neon, Norse Raider |
| 6 Specials | Need their earn paths decided first | Gingerbread, Firework, Kingslayer, Ascendant |

**Per chicken:**
1. Reference image (`chatgpt-image`, using the approved base-chicken render as the
   reference) and a palette.
2. Clone the approved chicken into a new named scene.
3. Make the texture atlas and fit props to the existing bones.
4. Render the real model plus Walk, Peck and Celebrate poses.
5. Export the animated GLB and the bind-pose FBX, then run the export check.

**Per batch:**
- one `.blend`
- a lineup render
- the batch's manifest and export review

**Location:** `assets/chicken-roster-expansion-20261015/` in this repo. Blender works from a
staging copy (`~/.codex/artifacts/chicken-roster-expansion-20261015/`), the same way the
earlier packages did, and the results are copied into the repo.

**Not touched:** the canonical Studio place, `ChickenAssets`, the existing templates and
the catalog code. That integration is a separate, coordinated step.

## 7. Decisions for you

1. Approve, cut or swap any of the 50, especially the meme or dark-humor ones: Bacon Hair,
   Chef, Popcorn.
2. Zone chickens: (a) rolls only, or (b) a mission drop chance?
3. Which of the four special chickens to keep?
4. Is Batch 1 the right starting set?
