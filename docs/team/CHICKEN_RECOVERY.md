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
