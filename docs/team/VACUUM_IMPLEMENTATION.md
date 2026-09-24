# Egg vacuum — September 24, 2026

Approved: replace Auto Collect with a row-sweeping vacuum; include a Studio-only test switch. Vacuum delivers eggs to the existing deposit stand. Preserve the existing stand's cash behavior; a timed processing economy is a separate feature. No prices, spawn rates, manual collection radius, or product IDs change.

Source: this repo, not the legacy pet-roll-prototype scripts. Original Blender model backed up in assets/egg-vacuum/source. Root is the only Studio/Blender integrator. Built-in worker roles used with legacy role guidance; that guidance's old repository routing is superseded by this repository.

## Ownership
- Root: Blender model, animation authoring/export, asset import, src/shared/VacuumClips.luau, documentation, integration and focused review.
- Server worker: src/server/EggService.luau, new src/server/EggRover.luau, new src/shared/VacuumConfig.luau, src/shared/ShopCatalog.luau only. Server state, row routing, claims, cargo and unload.
- Client worker: src/client/EggController.luau, new src/client/VacuumController.luau only. Renderer lives inside EggController's lifecycle; no AppController edits needed.

## Shared contract
VacuumConfig: ModelScale=4.2 (Blender meters to Roblox studs); TemplateName='EggVacuum'; NozzleOffset=Vector3.new(0,0.32,-1.86); WheelRadius=0.677. Additional editable server motion/sweep/suction/cargo/test settings supplied by server worker. Studio test enabled only with RunService:IsStudio() AND workspace:GetAttribute('TestEggVacuum')==true (not enabled in production). Normal access uses AutomaticEnabled('AutoCollectEggs').

Egg snapshot adds rover={enabled,id,state,x,y,z,dx,dz,cargoCount,cargoValue,suctionSerial,unloadSerial}; states Idle/Sweeping/Returning/Unloading. Position is floor/root position, forward=(dx,0,dz). Server nozzle matches CFrame.lookAt(root,root+forward)*NozzleOffset. Timestamp-free targets client interpolates. No unbounded queue or per-egg remotes.

Claimed egg drops and receipts have collector='rover' or 'player' and optional targetX/targetY/targetZ fallback. Rover pickups go to separate cargo, not the player's bag. Receipt confirms a claim exactly once; cash is credited only once at the stand. Teardown/toggle off preserves cargo in the existing saved egg bag; no data schema migration needed. No claim crosses plot ownership. In-flight claims settle before unloading. Manual eggs only fly to a nearby player; rover eggs only fly to the nozzle.

Template: ReplicatedStorage.PetRoll.Assets.EggVacuum (Model), anchored noncolliding parts, no scripts. Mesh parts named Body, WheelLeft, WheelRight, Nozzle, Hose, Socket, NozzleLeft, NozzleRight, Support. Model origin ground, forward -Z, rest scale authored at ModelScale=4.2. Body/Hose/Socket share body transform; nozzle and caps share nozzle transform; wheels spin around local X. Per-part attributes RestCFrame(CFrame) and RestSize(Vector3) may be used; root renderer captures template rest poses.

VacuumClips module (root authors) contains fps=30, sampleSpace='root-delta', clips={Idle,Move,Suction,Unload}. Each clip {duration,loop,frames={{time,body={cf={12 CFrame numbers},scale={x,y,z}},nozzle={cf={12 numbers},scale={x,y,z}}},...}}. CFrames are root-local deltas in studs; client composes rootCF * pose.cf * restCFrame. Body/nozzle scale should be applied about each part group's pivot using exported pivots table; exact data will be sent to client worker. Wheel rotation is runtime distance-driven, not clock-driven. Smooth clip/state transitions, reduced-motion support. No new camera motion.

## Review
Focused PC smoke: correct template/materials, wheels turn, idle/suction/unload states, row sweep stays in yard, nearby manual collection and robot claims cannot duplicate, carried value survives toggle/disconnect, exactly one stand payout. Rojo package check plus targeted runtime. Save local Blender/code and place; no publish.

## Initial integration evidence (superseded by the revision below)
- Original and animated Blender masters saved; four action families exported. Nine mesh and nine texture assets imported to the game group; template at ReplicatedStorage.PetRoll.Assets.EggVacuum.
- All 120 existing active Studio script hashes still matched the migration snapshot before sync.
- Isolated Studio Edit checks passed 25 assertions, including a full rotated sweep (42.9 seconds simulated, 12 endpoints) and capacity resume; no DataStore calls. Rojo build and sourcemap succeeded.
- Pet Roll Test was saved to Roblox at 2026-09-24 19:10:09 UTC; Studio logged `Saved new changes in "Pet Roll Test" to Roblox.` Reopening the same place confirmed the nine-part vacuum template survived the save. This was Save to Roblox, not Publish.
- Before connection, all 120 active script hashes were compared again and still matched the migration baseline. No unsynced Studio script changes were overwritten.
- Live Rojo connection and PC Play smoke remain pending. CLI serves localhost:34872. The plugin is loaded and offers the project connection; Computer Use coordinate clicks failed with `noWindowsAvailable`. The user was asked to dismiss the older recovery dialog and click Connect.
- Isolated client renderer checks passed 53 assertions against the actual imported nine-part template, including wheel axes, moving interpolation, authored squish, reduced motion, unload deduplication and cleanup. These are Edit-mode fixture checks, not an end-to-end PC playtest.
- Animated GLB export verified: nine meshes and one synchronized Scene animation (eight channels).

## Four-pass revision — completed September 24, 2026

- User requested bigger wheels, three or four swift straight passes across the current chicken yard, visible egg flights into the vacuum, then a trip to the cash stand. Implemented four passes at 12 studs/second. The rover completes every pass before depositing; the old cargo-capacity detour and resume behavior are removed.
- Wheel diameter is 1.35 times the imported size, width 1.12 times. Runtime offsets preserve ground contact and body clearance; distance-driven rotation uses the enlarged radius. The original Blender asset and Studio template remain unchanged.
- Rows and intake coverage use the current plot yard bounds, including plot-size upgrades. Eggs share the player's `EggMotion.Flight` arc and follow the moving nozzle. Late rover packets retain a visible pickup animation.
- Connected Rojo and verified the new source in canonical Pet Roll Test (place 96683186622050). Preserved the concurrent upgrade-board changes. No mapped Studio source was edited outside Rojo.
- Actual PC Play completed repeated Idle → Sweeping → Returning → Unloading cycles. Complete observed trips took 23.1–23.3 seconds on the current yard. Deliveries exceeded the old 40-egg limit (including 66 eggs), with payment only at the stand. Observed six animated egg flights approaching within 0.615 studs of the nozzle; the arc rose to world Y 4.959. Game server and client started without runtime errors; unrelated plugin HTTP warnings remained.
- Focused Edit fixtures passed 32 server assertions and 57 renderer assertions. Server coverage includes all eight row endpoints, rotated and expanded yards, no capacity interruptions, claim exclusivity, cargo preservation and exactly-once delivery. Renderer coverage includes enlarged wheels, ground contact, suction, unloading and cleanup. Results: `assets/egg-vacuum/export/checks.json` and `runtime.json`. Rojo build and diff whitespace check passed.
- Restored the default camera, stopped Play, removed temporary fixtures and restored the Studio test override to off. Saved Pet Roll Test to Roblox at **2026-09-24 19:45:46 UTC**, confirmed by Studio's `Saved new changes in "Pet Roll Test" to Roblox.` log. This was a normal Save, not a release publish. Player persistence remained in Studio session-only mode during the check.

## Pickup reach and speed tuning — September 24, 2026

- Increased speed from 12 to 16 studs/second, minimum suction radius from 3.4 to 5.5 studs, strip edge padding from 0.3 to 1.5 studs, and rover pickup batch from 4 to 8. Manual pickup and egg values are unchanged. Preserved the newly added egg-processing queue integration.
- Rojo readback confirmed the settings in canonical Pet Roll Test. A focused Edit-mode simulation used the current rover movement and collection limits with 80 settled eggs spread over the yard, including all corners: all 80 were collected in four passes; the simulated dock arrival/unload readiness took 18.4 seconds. Temporary fixture objects were removed. This is a synthetic coverage check, not a new full PC playtest.
