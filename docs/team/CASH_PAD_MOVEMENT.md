# Cash pad movement — September 26, 2026

The latest user request supersedes stationary auto-collection: each cash payout
requires horizontal movement while grounded on the owned cash pad. Stopping
leaves ready cash untouched until movement resumes. The existing one-second
ClaimReady cooldown and balance transfer remain unchanged.

Scoped changes: EggService ProcessAndClaim accepts server-observed root velocity;
Step supplies AssemblyLinearVelocity. X/Z speed must exceed 0.5 studs/sec so
vertical pad motion and small standing jitter cannot qualify. The client pad
tween uses the same threshold and releases when horizontal motion stops. No
client message grants cash and no minimum continuous walking timer was added.

Preserved all pre-existing quantity/instant-selling retirement changes. The
economy task was idle/interrupted at inspection; its retirement integration and
broader documentation are not completed or claimed by this task.

Twelve isolated checks passed using current disk sources and fake sessions,
pad/tweens (assets/egg-board/moving-contact-checks.luau). Both modules compile in
that fixture. No game-world mutation, saved profile, purchase or Play/Stop.

Studio's canonical Pet Roll Test instance w6a-k5r was running and its Edit sources
were older than the current quantity/retirement source on disk. No mapped Source
write or sync reconnect was attempted. Integrate the existing economy work via
Rojo before a fresh-session check; do not overwrite it with the old Studio code.
