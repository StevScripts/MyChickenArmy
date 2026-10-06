# Fuse Machine unlock — October 5, 2026

New profiles unlock fusion after first capturing Cluck Camp. Older valid saves
without the new `fusionUnlocked` field preserve access. Fresh saves explicitly
store false; the saved first-win fact grants access and saves an earned true.
Only fusion has this prerequisite; cash upgrades retain their existing rules.

The machine reuses its native prompt with “Fuse Machine · Locked” / “Capture
Cluck Camp.” Pressing it while locked explains the requirement without opening
the menu. No new art, geometry, currency, price or fusion animation was added.

`check-unlock.luau` ran in Studio's server VM: all 53 assertions passed. These
use unsaved fake sessions, real server modules and unparented prompt fixtures.
They cover lock rejection without mutation, exact Cluck requirement, normal
fusion after unlock, persistence, old-save compatibility and prompt lifecycle.
Battle facts are synthetic in this fixture; it is not a real capture test.

The existing starter-army fixture passed all 87 assertions after its three
fusion-budget cases explicitly granted access, isolating those safeguards from
the new lock. The earlier live starter-army route captured Cluck Camp after one
collection/sale lesson; see ../tutorial-starter-army-20261004/ for that separate
observed route.

Seven edited runtime modules exactly matched their Studio Edit sources before
the fresh Play session. Rojo packaging and git diff --check passed. Studio used
the existing session-only flag and disposable Free profile; no real saved
profile was reset, and the experience was not published.

`live-probe.luau` is a temporary normal-LocalScript client harness, not mapped
production code. The one-shot Commander.Update wrapper restores itself as soon
as it captures the running app. Its control uses existing game requests.

The live client/server check rejected OpenMerge while locked, showed the lock
reason, and kept cash/chickens unchanged. Direct local menu entry was also
rejected. The existing Studio Debug Unlock command then supplied camp progress;
the prompt changed to Fuse Chickens and the normal OpenMerge request opened the
real menu. This positive UI check uses synthetic camp progress, not a new battle.
Native E input was attempted, but its activation was not independently proven;
the definitive live request checks used the existing client remote path.
Results: `validation.json`. The camera was restored and Studio returned to Edit,
removing temporary runtime fixtures. No physical-device test was performed.
