# Robot vacuum archive

October 20, 2026: the Auto Collect Eggs pass went off sale and its robot vacuum
was retired. Owners got Gems instead (S7). The held Egg Vacuum replaces it
(`docs/team/COLLECTION_TOOLS.md`).

These are the last sources before the change, kept for reference. They are
outside both Rojo mappings, so none of them runs:

- `EggRover.luau` (server route, suction and dock)
- `VacuumController.luau` (client robot presentation)
- `VacuumClips.luau` (Blender clip export)
- `VacuumConfig.luau` (robot tuning)
- `AutoCollectStandController.luau` (the pass stand's world purchase)

The Studio robot template `ReplicatedStorage.PetRoll.Assets.EggVacuum` and the
six authored stands in the plots stay in the place until they are removed in
Studio. Restoring the robot would also need its EggService paths
(`git show b70a45a:src/server/EggService.luau`).

October 21, 2026: the robot is back as the Auto Vacuum Tools upgrade
(`docs/team/AUTO_VACUUM.md`). `EggRover`, `VacuumClips` and the presentation
(`src/client/AutoVacuumController.luau`) were restored from these copies with a tank,
Range and speed; the pass and its stand stay retired.
