# Chicken scenery collision — September 28, 2026

Scope: `server/AuthoredMap.luau` only, plus this record and focused collision evidence.
The smooth-following task owns ArmyCommandService and PetActor movement work;
this task does not edit either file or WorldService. No Studio Play/Stop ownership
is claimed by this task.

The runtime authored-map clone assigns ordinary scenery to `DuckScenery`, which
does not collide with the existing `DuckActors` group. Players retain collision
with those props. `WalkSurface` and `PlotGround` parts retain their existing
groups, along with direct Environment shore/sea parts and authored plot foundations.
Terrain is outside the cloned map and remains unchanged. Existing non-Default
collision assignments are preserved. No CanCollide, CanTouch, CanQuery, geometry,
rig, save, combat, or movement changes are made.

The pass runs before any gameplay actors are created. Runtime scenery copied
later from these classified templates inherits its group, including fusion
machines and their doors. New map walking surfaces should carry `WalkSurface`,
which is also the existing MapLayout ground-height contract. The legacy generated
fallback map is outside this authored-map pass.

This supersedes the old scenery-collision expectation in CHICKEN_BUMPS.md for
authored props; physical movement and recovery still use solid ground and retain
their existing handling of genuinely blocking geometry.

Complete; file and Studio inspection ownership released. The Rojo-synced module
compiled and matched local source. Focused Edit-mode checks passed across 6,090
cloned map parts: 5,357 previously solid scenery parts are now ignored by chickens,
all 61 marked walking surfaces retain their groups, and 77 solid ground/support
parts remain. Every part retained its original collision/touch/query flags, size
and CFrame. Actual raycast and overlap queries confirm chicken clearance ignores
props while player queries still see them. Runtime prop clones inherit the group.
The authored source map remained untouched; disposable fixtures and temporary
collision registration were cleaned up. See
`assets/chicken-prop-collisions-20260928/checks.luau` and `results.json`.

The exact reported recruit point (342.345, 4.792, -192.024) was also checked:
the DuckActors ray reaches Plot1.Deck at Y=2.36002 beneath the lever, while the
DuckPlayers ray still hits Plot1.Model.Spin.Level.LeverHousing.Part.

No physical walking Play test was run in this task. The coordinated following
task has been given the collision contract and can exercise walking in its next
Play session. No Play, player-data writes, save, publish, or Git commit/push.

Subsequent live-server report from the coordinated spawning chat
`01a0e9dc-acd2-72d2-b4c3-2b0d5a68b208`: in session-only Pet Roll Test,
instance `instance:9wo-7nm`, the exact recruit point's DuckActors ray hits Deck
at Y=2.360 and a ground-level 2.5 × 2.2 × 2.5 clearance box finds zero blockers.
DuckPlayers/Default rays still hit LeverHousing at Y=3.213 and their clearance
queries find all five lever parts. That chat performed read-only queries and
left WorldService spawn placement unchanged because the prop-collision change
resolves the identified obstruction. This is live collision-query evidence,
not a completed physical-walking test.

Subsequent physical-walking verification from the coordinated smooth-following
chat `01a0e9de-2c84-7653-8001-64c84f8474cc` passed: ordinary and 27.5-stud Colossal
chickens walked through a solid DuckScenery prop while supported by a Default
floor, without recovery. This closes the physical-walking gap above for that
fixture. The following task preserved server ownership and the existing ground
and collision methods, completed its checks, and released Studio in Edit.
See `docs/team/SMOOTH_FOLLOWING.md` for that task's evidence and scope.
