# Chicken received-hit feedback — October 6, 2026

Chickens receiving battle damage now get a red fill and outline that fade over
0.28 seconds with a Quad Out TweenService tween. This replaces the old white
0.11-second on/off flash. Final hits can flash during the existing defeat fade.
The effect is local, within the existing 120-stud feedback distance, and uses
Occluded depth so it does not show through scenery. Reduced Motion suppresses it.

`server/Battle.luau` increments a victim's `damageSerial` only when committed
damage reduces HP after armor and clamping. Snapshots include that serial.
`client/BattleController.luau` seeds the first observed serial and triggers on
increases within the same spawn. Several hits in one snapshot share a pulse;
attack windups, healing, stat rescaling, initial binding and respawn do not replay
damage. Combat calculations and reward rules are unchanged.

The controller replaces the previous pulse on another hit, disconnects completion
before cancellation, and destroys the tween/highlight on fade, release or respawn.
Reduced Motion clears a running pulse on the next existing render callback.
The flash uses native tweening; no new per-frame animation loop was added.

Validation: both local sources exactly matched their single Studio module before
fresh Play. Six isolated real-Battle checks passed: windup, committed hit, snapshot
serial, research health rescale, fully blocked damage and lethal damage. A live
session-only Cluck Camp encounter visibly flashed damaged chickens on both sides.
Pulse tweens were briefly paused for visual inspection, then resumed. Rojo build
and git diff --check passed. No saved profile, map, asset, price or release change.
These are focused Studio checks, not physical-device performance measurements.

Native APIs: [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
and [Tween completion/cancellation](https://create.roblox.com/docs/reference/engine/classes/TweenBase/Completed).
