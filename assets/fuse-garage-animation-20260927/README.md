# Sectional fuse garage animation

**Current sequence:** the user corrected the original entry animation. Fusion now charges behind the closed door and one upgraded chicken emerges facing outward, holds on the platform, then fades. No three chickens entering from outside. `result-exiting.jpg` is the current Studio image; `result-exit-checks.json` confirms closed charging, one correctly leveled output, inside-to-outside movement, high-level doorway fit and normal/interrupted/repeated cleanup. Current MergeStand: 8,305 bytes, polynomial hash 3089724103, compiled and matched to Studio. Earlier incoming-bird images/checks below are historical.

The actual authored door contains 21 parts, including one tall solid backing and four decorative horizontal sections. `MergeGate` creates 24 temporary pieces, retaining the trim/hinges and dividing only the plain backing. Each section rises, rotates inward through three TweenService CFrame segments, then hides within the housing. Closing reverses the sequence; resetting restores every original property.

- `door-turning.jpg`: live Studio screenshot during a slower 4-second diagnostic opening to inspect the bend.
- `door-open.jpg`: live Studio screenshot after the production 0.55-second opening.
- `chickens-entering.jpg`: production `Celebrate` sequence with three cosmetic chickens staggered by 0.08 seconds.
- `checks.json`: live runtime measurements and successful normal, interrupted and repeated celebration resets. These calls invoked the real runtime stand presentation; they did not consume player inventory.
- `MergeStand.before.luau`: exact pre-task source for comparison/recovery.

Source readback: MergeGate 5,035 bytes, polynomial hash 3354589252; MergeStand 7,256 bytes, hash 2074019726 (h=(h*31+byte) modulo 2^32, initial 0). Both compiled and matched Studio. No animation errors appeared in the observed runtime output. Existing unrelated plugin HTTP warnings remain. Studio test session stopped; authored machine and player profiles unchanged.

Animation uses normal Roblox [TweenService CFrame/property tweens](https://create.roblox.com/docs/reference/engine/classes/TweenService); no custom per-frame interpolation.
