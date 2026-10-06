# Six matching home plots — October 6, 2026

The user requested that all six plots have the same contents as Plot1. Plot1 is
the authored template; Plots2–6 now contain full copies positioned by their
existing entrance ramps. Each destination retains its own `PlotIndex` and
`HOME N` label. Plot1's geometry is unchanged.

## Authored scope

All six plots now have:

- A 96 × 131.853668-stud deck and the square-to-T yard/fence expansion metadata.
- Eight uniquely numbered roll podiums and the rolling lever.
- The Fuse Machine, instant egg-selling stand and AutoCollect stand/preview.
- Plot1's props and decorations.

The original entrance positions and rotations were preserved; the largest
measured entrance-position drift was less than 0.000018 studs. This changes
Studio-owned map assets only. It does not change scripts, gameplay rules,
prices, saved levels, balances or player data. In particular, eight authored
stands do not grant eight owned Roll Slots: the existing saved ownership and
cash purchases still control the visible/usable stands during play.

The [square-to-T expansion](SQUARE_TO_T_PLOT_EXPANSION.md) now describes all six
authored plots, and all six support the physical eight-podium maximum in
[the Roll Slot contract](EIGHT_ROLL_PODIUMS.md). This supersedes older notes that
Plots2–6 retain their previous footprint or have only one authored podium.

## Verification and local delivery

The root's structural readback passed for all six plots: each has 334 BaseParts,
120 object-reference properties and 671 descendants. Engine-maintained Humanoid
`Status` and `TouchInterest` objects are excluded from strict structure
comparison. The readback also confirmed unchanged source Plot1 geometry and
the preserved entrance alignment.

A read-only inspection during a session-only Studio preview confirmed the
server was ready and all six plots loaded with their own indices, the matching
deck and T-yard metadata, eight RollDisplay markers, one Fuse Machine, one egg
deposit and one AutoCollect stand each. This did not exercise transactions,
every expansion stage, army routes or six-player multiplayer behavior.

The full place was saved locally as
`assets/plot-parity-20261006/MyChickenArmy-Six-Matching-Plots-20261006.rbxl`.
No Roblox publication was performed. Structural and runtime evidence is saved
alongside the operation scripts in that directory.

## Recovery

`ServerStorage.PlotParityArchive20261006.OriginalPlots` preserves the original
Plots2–6, and `Plot1Template` in the same archive preserves the source template.
The authored operation has a Studio undo entry. The operation recipe, readback
and restore files are kept in `assets/plot-parity-20261006/`.
