# Rectangular Plot1 expansion — September 29, 2026

**Historical iteration.** Superseded by the user's square starter and T-shaped
maximum correction. Use [the current contract](SQUARE_TO_T_PLOT_EXPANSION.md).

The user enlarged Plot1's deck and requested a visibly longer chicken plot,
with only fencing, the boundary and plot dimensions changing. The enlarged
deck is authored only on Plot1. Plots2–6 retain their existing art and uniform
expansion behavior.

## Footprint and upgrades

Plot1's ChickenYard opts in with `ExpansionAxis="Depth"` and
`ExpansionStartDepth=18` and `ExpansionMaxDepth=74`. After the user's correction,
the authored boundary shows the small starter footprint: 36 studs wide and
18 deep. In Deck-local coordinates the front stays at Z=-23.5 and the fully
expanded rear reaches Z=50.5; X stays -18 to 18.

| Saved plot level | Width | Depth | Existing capacity |
| --- | ---: | ---: | ---: |
| 0 | 36 | 18 | 25 |
| 1 | 36 | 26 | 30 |
| 2 | 36 | 34 | 35 |
| 3 | 36 | 42 | 40 |
| 4 | 36 | 50 | 45 |
| 5 | 36 | 58 | 50 |
| 6 | 36 | 66 | 55 |
| 7 | 36 | 74 | 60 |

PlotUpgradeService applies the saved level to the runtime clone. It keeps the
front fixed while stretching depth, and supplies the same perimeter (with the
existing 1.6-stud inset) to chicken roaming and egg placement. The invisible
Yard anchor follows the boundary. Grass and decorations stay in their authored
positions instead of being scaled with the rectangular boundary.

The existing seven prices, +5 capacity per purchase, saved levels, profile
migration and no-camp-prerequisite rule are unchanged. This is a physical
footprint change, not a new progression track or save conversion. The editor
shows level zero; a fresh game applies the player's owned level. The maximum
is explicit metadata, so displaying the starter size does not cap future growth.

## Fencing and preserved objects

The outer fence now expands with every saved plot level too. Its starter size
is 76 by 71.68 studs (X=-38 to 38, Z=-48.18 to 23.5), keeping the fixed machines
inside. It grows to 88 by 100.68 studs (X=-44 to 44, rear Z=52.5) at level seven.
The front opening retains its previous X endpoints. Only rail lengths and
fence positions change; post sizes, fence height, thickness and materials remain
authored. The 31 matching posts added in the initial operation remain, keeping
spacing at most 5.5 studs at maximum expansion.

Only direct fence rail/post parts, Boundary.Beam and its attachments, and
Anchors.Yard were repositioned or resized. Nested decorative rocks/footings
inside the fence folders were excluded. The deck, foundation, all stations,
eight roll podiums, sign, spawn, entrance path and other scenery were not moved.

## Recovery and delivery

- Studio target: Pet Roll Test, 96683186622050, Edit.
- `ServerStorage.RectangularPlotRecovery20260929.Plot1Before` preserves the
  complete pre-change plot, and the geometry operation has a Studio undo entry.
- `Plot1BeforeStarterCorrection` in the same recovery folder preserves the
  first maximum-size edit. The starter correction has its own undo entry.
- A divergent legacy PlotUpgradeService duplicate was moved intact to
  `ServerStorage.RectangularPlotRecovery20260929.PlotUpgradeService_PreviousDuplicate`.
  The remaining mapped module matches the local source synced by Rojo.
- Local operation and pre-change source/geometry are in
  `assets/rectangular-plot-20260929/`.
- The authored result was displayed in the Edit viewport. No automated tests,
  Play/Stop, player-data writes, Roblox save/publish or Git commit/push were run.

Studio map edits need a place save. Local source and documentation are saved
on disk; the runtime upgrade path has not been playtested in this task.
