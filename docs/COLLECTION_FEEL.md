# Egg and cash feedback

Tune `src/shared/CollectionFeel.luau`, then restart Play. ModuleScripts are cached.

## Cash: supplied CashDrop script and asset

Cash collection clones the user's authored `CashDrop` ten times, preserving its
BillboardGui image and Trail. The original template was moved from `Workspace.CashDrop`
to `ReplicatedStorage.PetRoll.Assets.CashDrop`; it remains Studio-owned, not Rojo art.
Save the place separately to persist that asset move.

The supplied script's three waypoints are the player's starting position,
that position plus a random horizontal vector times 3 and 1 stud upward,
then that position plus the same vector times 6 and 2.5 studs downward.
The outward curve uses Exponential Out over 0.65 seconds. At 0.30 seconds,
the drops return to the player's then-current position over 0.30 seconds using
Exponential In, while the images fade with Quad In. Cleanup follows 0.05 seconds later.
The return destination is captured once, matching the supplied script.

`BezierTween` and the `CrashPart` collision group were absent. TweenService drives
a scalar along the quadratic curve instead; clones are anchored and have collision,
touch and query disabled. The outward driver is cancelled before the return starts
so the two phases do not fight over Position. No package or collision group was added.
One quiet coin sound still plays on confirmation; eggs and sound assets are unchanged.

The `Cash` section has these controls:

- `OutSeconds` / `InSeconds`: curve and return/fade durations.
- `ReturnDelay`: when to interrupt the curve and start returning.
- `Count`: number of template clones.
- `Volume`: collection sound volume.

Edit `Feedback:Cash` in `src/client/ActionFeedback.luau` to change the curve
waypoints and TweenService calls. Edit the stored template in Studio to change
its image, size or trail. Up to three groups can overlap. Completion destroys the
clones; reset, teardown and reduced motion cancel active tweens. Confirmation
does not depend on animation completion. Reduced motion uses an amount popup.

`Feedback:CashReward` groups exact receipt values. EggController owns receipt
and generation deduplication. The wallet always follows server snapshots;
presentation does not credit cash or change processing.

## Eggs and deposits

Egg pickups retain their existing curved flight and moving-player/nozzle tracking.
`CollectionFeel.Egg` contains those settings. `Deposit` controls grouped egg
flights into the seller. Deposits confirm eggs; processor cash is celebrated only
when the server confirms a separate cash claim.

`Sounds` selects EggPickup, EggDeposit and CashTick assets. AudioController owns
preloading, bounded overlap and the existing Effects mute setting.

## Verification

The supplied-script revision passed isolated Edit checks using actual native
tweens: ten authored clones with preserved image/trail attachment references,
confirmation, outward curve, interrupted curve, inward fade, return to a moved
root's captured position, completion, bounded repeats, reset, reduced-motion
interruption/confirmation, character removal and delayed teardown callbacks.
Cleanup checks allow deferred Destroying signals to run.
The two changed runtime sources compile and match Studio through
Rojo. No Play session was started or stopped; start a fresh Play session to review
the effect in gameplay. No place save, publish, upload or player-data change.
