# Loyalist guards (October 15, 2026)

There are 26 enemy-only chickens, one set per mission territory. They are built on the approved
rig with the six clips, through the same pipeline as the roster expansion.

- **Art:** `assets/loyalist-guards-20261015/`. It holds GLB+FBX, textures, previews, the tier
  lineups, the source specs `loyal.py` and `l1`–`l3.py`, runtime meshes, asset receipts and
  the VFX installer.
- **Studio:** `ReplicatedStorage.PetRoll.ChickenAssets.Loyal*` (153 templates total). The
  staging copies are in `ServerStorage.RosterExpansionImport20261015`.
- **Code:**
  - `PetCatalog.Loyalists`: each guard is cloned from the final stats of its role, with
    `enemyOnly = true`, zero weight and not in `Order`.
  - `ChickenAppearanceAssets`.
  - `src/animations/Loyal*.luau`.
  - `OperationCatalog` rosters.

Shared look: each guard wears the King's crimson and gold crown crest. Each tier has its own
palette:
- **Veteran:** iron and crimson.
- **Elite:** shadow navy and violet.
- **Royal:** ivory, gold and crimson.

| Territory | Guards (stats of) |
|---|---|
| Scout Landing | Crate Scout (Bucket), Spyglass Scout (Viking) |
| Iron Drop | Drop Trooper (Bucket), Anvil Brute (Knight) |
| Veteran Assault | Veteran Sergeant (Knight), Assault Lancer (Viking), Mortar Hen (Wizard) |
| Shadow Battery | Shadow Bulwark (Bucket), Shadow Gunner (Wizard), Night Captain (Knight) |
| Iron Fleet | Fleet Marine (Knight), Deck Raider (Viking), Frost Gunner (IceDuck) |
| Dragon Commander | Honor Guard (Knight), Ember Adept (Wizard), boss Dragon Commander |
| Royal Vanguard | Vanguard Paladin (Knight), Glacier Lancer (IceDuck), Crimson Drake Knight (Dragon) |
| Crown's Shield | Crown Shieldbearer (IceDuck), Royal Warden (Dragon), Storm Herald (StormDuck) |
| The King Returns | King's Frost / Flame / Thunder Guard (IceDuck / Dragon / StormDuck), boss Armada King |

The bosses keep their authored `combatStats` overrides, and their stats are unchanged.

**Effects:** 18 guards have effects (embers, violet glows, frost, storm sparks, the king's gold
glitter). They are installed by `roblox/loyal_vfx.luau` and use the existing `RosterBurst` and
`RosterPulse` lifecycle.

**Portraits:** none were made. Guards never appear in the Index or inventory.

**Checks:**
- All 26 exports passed the pipeline review: 18 joints, 6 clips, embedded images, no unweighted
  vertices.
- All 26 imported without errors.
- In a Studio Run server, spawned sites used only these guards.
