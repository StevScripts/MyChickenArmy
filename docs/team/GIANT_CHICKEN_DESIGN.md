# Giant chicken design decisions

Recorded September 27, 2026. Design direction only; Giant rewards, persistence,
size rolls and stat bonuses are not implemented by this note. The live fusion
contract remains [MERGING.md](../MERGING.md).

## User decisions

- Giant acquisition through fusion should have at least a 20% chance. This
  supersedes the assistant's earlier 1–10% suggestions. The final chance above
  that floor is not yet specified.
- Giant sizes must stay within a deliberate minimum and maximum, rather than
  having an unbounded extreme-size roll.
- Higher-rarity chickens being fused increase the chance that the resulting
  Giant is toward the larger end of that range. This instruction concerns the
  conditional size distribution; it does not itself increase Giant acquisition
  chance by rarity.
- The user wants Giants to be common enough that players can have one. A
  guaranteed first Giant was suggested by the assistant; its trigger and any
  subsequent guarantee system have not been decided.

## User-scaled Studio references

Read from Pet Roll Test, place `96683186622050`, in Edit mode after the user
finished scaling the guides:

| Studio Part | Size X / Y / Z, studs | Purpose |
| --- | --- | --- |
| `Workspace.GiantSizeGuides.Giant_MIN` | 6 / 6 / 6 | Minimum Giant size reference |
| `Workspace.GiantSizeGuides.Giant_MAX` | 20 / 20 / 20 | Maximum Giant size reference |

These are authored spatial references, not scale multipliers. Preserve the
user's parts. Scale chicken meshes uniformly so their proportions stay intact;
do not stretch their three axes independently to fill a cube. Translating the
reference bounds to the chicken body, excluding particles and labels, needs to
be handled explicitly when implementation begins.

## Proposed distribution behavior

Use the current catalog order: Common, Uncommon, Rare, Epic, Legendary, Mythic.
For every fixed large-size threshold inside the approved range, the chance of
exceeding that threshold should increase with input rarity. Retain overlapping
outcomes: lower rarities may still roll a large Giant and high rarities are not
guaranteed the maximum. No exact weights or curve have been approved yet.

The current matching-species fusion recipe gives all three inputs the same
catalog rarity. Do not add rarity averaging or mixed-species fusion merely to
implement this rule.

Treat Giant acquisition and Giant size as separate stages. Once earned, size
should remain stable through ordinary equip, spawn and rejoin actions. Later
fusion inheritance, level-growth interaction, stat bonuses and save handling
need explicit implementation decisions; this note does not define them.

The existing garage reveal currently fits output models to its opening. The
approved large sizes need a deliberate reveal treatment rather than silently
using that temporary fitted model as the Giant's actual world size. Preserve
movement reliability when adapting physical actors.
