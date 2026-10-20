# Fuse archive (October 20, 2026)

Fuse was removed in the October 20 overhaul (see
`docs/team/FUSE_REMOVAL_AND_SELL.md`). These are the exact pre-removal sources, kept
for reference only. They are not in either Rojo project and none of them runs.

- `src/client`: `MergeBrowser`, `MergeSelection`, `MergePresentation` (the menu).
- `src/server`: `MergeStand`, `MergeGate` (the machine) and `ArmyService` as it was
  before its fusion endpoints were removed.
- `src/shared`: `GiantChicken` with the fusion odds, size bands and pity rules.
- `tests`: the Fuse and Giant checks retired with them.

Restoring Fuse is a deliberate owner decision: it needs these modules back, their
`AppController`/`GameServer`/`WorldService` wiring, `Config.Features.Merging`, a
research or tree unlock and the physical machines in Studio. Do not copy these files
over current integration files without comparing changes.
