# Chicken movement and physical recovery — September 24, 2026

Owner: current root task. User requested fixes for stuck chickens and accidental
death/model loss, with an edge-case audit. Writable: server/PetActor,
WorldService, LiveBattleActors, targeted recovery checks and documentation.
KingArena/IdlePatrol/Battle remain dependencies unless a concrete integration
gap needs a bounded change. Preserve current egg processor, EggService,
GameServer and EDITING.md work.

Canonical place 96683186622050; relevant seven server modules each had exactly
one Studio copy and matched disk before editing. Existing session-only Play
was stopped for source sync. Recovery never creates owned pets, modifies a
profile, grants combat health, pays kills or changes the existing combat respawn
timers. Repairs belong to the same actor; explicit Destroy is terminal.

Completed: 18 live recovery/control checks and six injected path lifecycle
checks pass. The authored Plot 1 gate passed all six outward/return legs with
zero recovery teleports. A 66-second final home observation recorded bounded
blocked-route recoveries and all three birds moving. Healthy detours are no
longer cancelled merely for exceeding the straight-line time estimate.

Canonical Studio controls RELEASED: Play stopped, disposable test ModuleScript
and fixture folders removed. The next UI task may use Studio Play/device controls.
No Roblox save/publish, asset upload, Git commit/push or saved player-data change.
Details and limits: docs/CHICKEN_RECOVERY.md; results and before-source copies:
assets/chicken-recovery/.

Focus: bounded path requests/cancellation, temporary block retries, stuck home
fallbacks, idle and moving rig health, falls, and preserving battle identity,
health and death timers. No publishing or live player-data changes.

## Chicken-only slopes: October 9, 2026

Chickens collide only with walk surfaces and plot ground, so ledges were the one
thing that trapped them: the raised home deck's edge (about 1.3 studs, taller than
a chicken Humanoid can step) beside the 5-stud entrance ramp, and the island's
grass edge (about 2.5 studs above the beach). Following squads spread wider than
the ramp, and marches aim at a gate point that predates the enlarged deck, so
birds wedged against those edges until recovery kicked in.

`WorldBuilder.BuildChickenRamps` (per plot, all four deck sides, reaching the
lowest ground found beside each side) and `WorldBuilder.BuildIslandChickenRamps`
(96 segments placed at the measured grass edge) add invisible WedgeParts in the
`DuckRamps` collision group, which collides only with `DuckActors`. Players,
cameras and other groups pass through; they are not WalkSurfaces, so
`MapLayout.FootPosition` ignores them. The island builder also puts the
`MapBorder` walls back in the Default group so chickens cannot walk into the sea.

Studio checks (test rigs driven by `PetActor:MoveTo`): every deck side of Plots 1
and 4, beside the entrance ramp, a corner diagonal, a size-22 Giant, and the island
edge at several angles all arrive in 1.4-2.8 s both ways; with the deck slopes
disabled the same walk was still stuck after 5 s. A chicken sent past the border
stops at radius 509.5.
