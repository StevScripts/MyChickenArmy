# Map rearrangement QA — September 26, 2026

Owner: Initialize Chicken Army task, 01a0e0eb-d958-7cf1-b1a6-097ed750e530.
User requested live playtesting and continued fixes after rearranging the Studio map.

Own WorldBuilder/RollStation nested authoring bindings and narrow MapLayout/WorldService spatial binding fixes, with any further scope recorded here. Preserve authored positions, rotations, sizes and groupings. BattleService/Battle/BaseController/Config belong to the active camp-retargeting task and are not edited by this task.

Canonical Studio: Pet Roll Test 96683186622050, instance:w6a-k5r, Edit.
Play/Stop coordination requested with camp-retargeting chat; waiting for release.
PetRollPlaytestSessionOnly is true. Real purchases, profiles, save/publish and Git history are outside scope.

Before code inventory: all 103 local server/shared/client module hashes match Studio. Existing identical duplicates: PlotUpgradeService, OfflineCashConfig, EggFeedback. Source backups for initially scoped files are under assets/map-rearrangement-20260926/before/.

Initial finding: Plot1's Props, Spin and Anchors are under extra Model groups. Direct Props/Spin code indexing breaks boot; SpawnFrame ignores the moved authored spawn marker. Keep the user grouping and fix lookup at the owning modules.

Additional binding scope: PlotUpgradeService must use the remaining authored Boundary.Beam footprint when YardFloor is intentionally removed, and preserve/scalably move its beam attachments. The obsolete nested Anchors.Yard no longer matches the visible yard. Existing duplicate PlotUpgradeService copies must be preserved and reconciled after Rojo sync.

Camp-retargeting task completed its isolated checks and explicitly released Studio control. This map QA task now owns Play/Stop until completion.

## Stopped at user direction: “all good”

Studio Play stopped and controls/file ownership released. User layout/geometry/grouping was preserved. Local fixes Rojo-synced: recursive owner sign/roller/anchor lookup, moved authored spawn, visible boundary-derived yard bounds with attachment scaling, authored deck-derived world position, and nested Plot1 fuse-machine template reuse for other plots.

Live checks passed: clean server/client startup; normal walking to moved roller; starter purchase (3→4, cash 2400→1800); E lever roll; five yard walks; 486 eggs collected; sell pad deposited 1952 value instantly; cash-pad crossing paid 1952 (1800→3752); Plot Size purchase raised level to 1/scale 1.05; E at moved fuse machine opened the populated merge menu. A scripted fuse approach target was inside collision geometry and timed out 2.48 studs away, but the avatar was already within 1.95 studs of the button and the native prompt worked. This was a harness target issue, not a blocked interaction.

No game errors appeared in the reviewed log windows; the pre-existing third-party plugin HTTP permission warning remained. DataService entries stayed at zero. No real profile, purchases, save/publish, commit or push.

The user ended the pass before a merge transaction, camp marching/return, paid vacuum, or a fresh restart of the final WorldService position/template follow-up could be checked. Do not claim these paths passed. An initial inspection accidentally converted two runtime layout CFrames to strings; both were immediately restored before tests proceeded. A roll harness attempted to read an already-consumed offer ID; native E rolling was subsequently verified.

Preserved the stale, identical-before-edit PlotUpgradeService in ServerStorage.MapRearrangementRecovery20260926 after confirming the new synced copy. Its before-source remains in the local evidence directory. One active updated copy remains. Studio saving is separate.
