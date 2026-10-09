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

## Feathers, sparks, damage numbers and fight sounds — October 9, 2026

The user found fights flat ("the fighting animations play and the health bars show
but that's it"), approved a live Studio preview, then asked for it built in. They also
asked to drop the coin sound when a chicken knocks out an enemy ("doesn't fit in").

`client/CombatEffects.luau` (presentation only, driven by `BattleController` from the
server's battle snapshots, within the existing 120-stud nearby check):

- **Attack** (`attackSerial` changes): `CombatSwing`, pitch 1.25-1.45.
- **Hit** (`damageSerial` rises in the same spawn): 5 voxel feathers (8 on a big hit)
  burst and tumble down, a white-and-gold comic spark, a floating `-N` in the UI kit's
  lettering (white, dark outline; gold and larger when one hit takes at least 25% of
  `maxHp`), and `CombatHit`, pitch 0.95-1.2. The existing red highlight still plays.
- **Knockout** (HP reaches 0 while watched, not on binding an already-down unit):
  14 feathers, a smoke poof (`smoke_main.dds`), a big spark, `CombatKnockout` and
  `CombatKnockoutCluck` (the game's existing "chicken cluck" clip, 77584650945481,
  pitch 1-1.15; it replaced a boing at the user's request).
- The per-hit `Impact` sound was replaced by `CombatHit`; the kill-receipt `Collect`
  sound was removed (the `+$` number stays).
- Budgets: at most 70 feathers and 14 numbers at once; extra effects are skipped.
  Sounds sit at the fight (rolloff 8-42 studs) with per-cue cooldowns and 4 voices.
  Reduced Motion keeps sounds and static numbers but no feathers, sparks or smoke.

Validation: a real Cluck Camp fight in Studio produced hits, numbers, knockout poofs
and the existing rings with no errors; all four sounds loaded. The Combat Sounds were
added in Studio Edit (save the place).
