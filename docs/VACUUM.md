# Egg vacuum

Auto Collect uses the user's Tripo vacuum. Nine original parts remain separate; no chicken/map art is replaced. Wheels rotate from actual travel and turning. The server drives alternating rows, claims only nearby eggs, carries them separately from the player, returns to the existing sell pad and pays once. Manual nearby egg pickup remains available.

October 3 feedback correction: automatic deliveries retain their payout, local
amount display and unload animation, but do not trigger the player's deposit or
cash burst/sound. Manual player deposits retain the normal cash effect.

October 3 solo Play validation: eight consecutive automatic unloads paid $2,576
with zero player Cash/DepositBurst calls or cash/deposit sound requests. A real
manual collection and sale paid $264 across three receipts and triggered two
grouped Money/sound calls. One further automatic unload paid $72. The separate
manual `EggDepositEffects` template is missing from the place; its burst warns,
while the Money template is present. Test profile and vacuum bypass were
session-only; Play was stopped and temporary instrumentation cleared. Evidence:
[`20261003-cash-feedback-loop.json`](../assets/egg-vacuum/validation/20261003-cash-feedback-loop.json).

Each trip covers four straight, parallel passes, alternating direction, then returns to the cash stand. Cargo never interrupts a pass. The route uses the current chicken-yard bounds, including plot-size upgrades; the rover's intake widens enough to cover its four strips. Manual collection range is unchanged. Disabling Auto Collect or leaving transfers earned cargo into the existing saved egg bag. This does not add offline collection. Cargo not yet autosaved has the same sudden-server-loss limitation as other unsaved pickups.

September 25: suction stays active on the outbound approach, all sweep passes,
and the entire return route. Minimum pickup radius is now 9 studs (previously
5.5); larger plots still expand it as needed. Suction also runs during the brief
dock settling window, then closes so in-flight pickups can finish and the
delivery cannot stall indefinitely. Parked/disabled robots do not claim eggs.

Eggs use the same arcing pickup motion as player collection, but their destination follows the moving nozzle. Late pickup packets retain a visible flight. In-game wheels have 35% larger diameter and 12% more width; their ground contact and distance-based rotation are adjusted together. The imported template and Blender source geometry remain intact; these size multipliers are editable in code.

On Plot1, the egg-processing board now queues vacuum deliveries and pays processed cash through its separate front pad. Plots without that board retain instant conversion. See [EGG_PROCESSOR.md](EGG_PROCESSOR.md) for the processing and Finish Now behavior.

## Test in Studio

On **Workspace**, add a Boolean attribute **TestEggVacuum** and set it true. Play in Pet Roll Test. Leave chickens home to produce eggs; walk away from the yard so manual pickup does not collect them first. The vacuum should sweep, suck eggs into its yellow nozzle, return to the left stand, unload, then repeat. Set the attribute false to test normal pass ownership. The bypass explicitly requires Studio and cannot grant it to public players.

Rover presentation currently renders for its owner, like the existing egg sprites. Other players' vacuum art is not replicated by this first pass.

## Tune in VS Code

- `src/shared/VacuumConfig.luau`: MoveSpeed (16 studs/second), PassCount (4), WheelDiameterScale (1.35), WheelWidthScale (1.12), minimum SuctionRadius (9), SuctionEdgePadding (1.5), PickupBatch (8), IdleSeconds, UnloadSeconds (0.8) and dock approach offsets. Intake increases with strip width; the wider overlap and larger pickup batch help collect eggs before the faster vacuum passes them. There is no cargo-capacity detour.
- `src/client/VacuumController.luau`, `MOTION`: snapshot blending, pose smoothing and pickup audio cadence.
- `src/shared/VacuumClips.luau`: generated pose data; edit/re-export Blender actions rather than hand-editing every sample.
- `src/server/EggRover.luau`: movement/state machine. `EggService.luau`: authoritative claims, cargo and payment. Never award coins from animation callbacks.

Changing cached ModuleScripts requires restarting Play. Rojo only syncs source; it does not refresh a running `require` automatically.

The September 25 continuous-pickup revision passed 15 isolated Edit checks in
`assets/egg-vacuum/tools/check_continuous_pickup.luau`: radius boundaries,
outbound/return/dock pickup, pending-flight drainage, exactly-once delivery and
disabled behavior. The user's existing Play session was left running; this was
not an end-to-end playtest, save or publish.

## Blender controls

Open `assets/egg-vacuum/source/EggVacuum-Animated.blend`. The original is preserved beside it as `Vacuum-Original.blend`; the animated file packs the source textures.

Timeline preview markers: **Idle** frame 1, **Move** 91, **Suction** 131, **Unload** 161. Four named action families `Vacuum_<clip>_<control>` remain editable. Body_Control moves the body/hose/socket; Nozzle_Control moves the head and green end caps. Wheel origins sit on their axles. The in-game wheel angles come from distance, avoiding wheel spin when parked.

Keep squash subtle: about 1% for idle, up to 4.5% vertical compression for suction, up to 3.5% nozzle widening. Ground clearance and wheel size should remain stable; do not squash the whole rig. Unloading tilts the body 5 degrees. Reduced Motion disables body/nozzle squash and particle effects while retaining functional travel and wheel movement.

After editing an action, run `assets/egg-vacuum/tools/export_clips.py` in Blender to update the game clips. `animate_blender.py` is the original creation recipe and expects the untouched Tripo scene; it is not the routine export command. Mesh/color changes require a new asset import, not only clip export.

## Saved asset provenance and checks

- Exact nine-part mesh data originated in the open Blender scene; original geometry retained (19,429 triangles total).
- `assets/egg-vacuum/export/receipts.json` records mesh and texture asset IDs uploaded for the game's group.
- Texture transport uses a maximum 1024-pixel side for Studio EditableImage; original full-resolution JPEGs remain packed in Blender and in `textures/`.
- `assets/egg-vacuum/export/checks.json` records the isolated server checks. They use fake sessions and no DataStore, purchases, or player-data resets.
- This feature does not publish the place or push to GitHub. Studio saves and runtime checks are recorded separately in `docs/team/VACUUM_IMPLEMENTATION.md`.
