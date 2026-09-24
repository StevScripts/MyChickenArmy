# Egg and cash feedback

September 24, 2026. Tune `src/shared/CollectionFeel.luau`, then restart Play.
ModuleScripts are cached; editing this file during Play is not hot reload.

Egg claims start from the current visible position, even when the packet is late.
The default flight lasts 0.40 seconds, with a short lift and a distance-limited
curve. Small clusters stagger by 0.04 seconds, capped at a 0.20-second start
window. The moving player or vacuum nozzle is followed every rendered frame.
Teleporting or losing the player resolves the visual. Arrival owns the pickup
pop, spark and receiving HUD pulse; exact popup totals use deduplicated server
receipts. A later receipt does not replay the arrival cue.

Egg deposits group for 0.08 seconds, with at most five representative sprites.
The basket contact callback owns the deposit sound and confirmation. Processor
deposits confirm eggs only. Instant-sale plots then start the cash sequence;
processor plots start it only on the separate cash-claim receipt.

Cash follows the user's `Screen Recording 2026-09-24 at 4.51.30 PM.mov`
reference (10.16 seconds; sampled across the full clip, then at 15 fps around
the first payments). Around 0.9–1.4 seconds, bundles spray outward around the
player with white streaks and a yellow flash; loose bills linger and shrink.
The previous flight into the HUD has been replaced.

Defaults: ten approved cash sprites plus twelve small green/gold bills, a
0.26-second outward burst, a 0.30-second flash and roughly 1.05 seconds of total
lifetime. White core trails have a faint gold fringe. A native layered star
and halo sit on the camera-facing side of the avatar with world occlusion.
These are authored estimates from the recording, not recovered source values.
The approved game cash illustration is retained; reference-game artwork is not
extracted for production use.

Payment sound and the HUD pulse occur at burst onset. The burst stays at its
world origin when the player moves away. At most three bursts coexist; dropping
old visuals never drops a confirmation. Dense receipts group by their exact
values. The normal wallet shows the authoritative total; reduced motion replaces
the burst with a compact exact-amount popup. Reference audio could not be heard
in this session, so the existing coin/sparkle mix is retained, timed to onset.

The wallet remains driven by authoritative snapshots throughout. Presentation
never credits money, changes carried eggs, or controls processing. Unchanged
wallet snapshots no longer restart the count animation, and a decrease in the
authoritative target interrupts a count-up immediately. Server settlement still
uses `Config.EggFlightSeconds`; the new visual duration is independent.

## Tuning

`CollectionFeel.Egg` controls duration, arc in studs, stagger, target smoothing,
teleport threshold, six repeating pitch steps, sound volume/cadence, five-voice
overlap, and HUD emphasis. `Deposit` controls grouping and basket contact.
`Cash` controls outward burst time, lifetime, radial spread in studs, bundle and
bill counts, trail width/lifetime, flash size/duration, volume and HUD emphasis.

`Sounds` holds the existing game audio IDs under dedicated EggPickup,
EggDeposit, CashTick and CashFinish roles. Pickup uses the short cartoon pop;
cash uses the coin cue plus a quieter sparkle layer. AudioController preloads
each cue independently. Voice limits retain overlapping tails and fade the
oldest at capacity. `fallbackCounts` and each active Sound's `Fallback` attribute
expose fallback use; a failed load never overwrites the configured template ID.
The existing Effects toggle mutes all these cues.

The relevant hooks are `Eggs:PickupCue`, `Feedback:Deposit`,
`Feedback:CashReward`, `Feedback:ShowCash`, `Feedback:ResetCollections`,
`Vacuum:PickupCue`, and `Theme.Motion:Pulse`. Receipt/generation deduplication
stays in EggController. Existing vacuum route/animation and seller logic remain
owned by their original systems.

## Verification and delivery

Reference revision: ActionFeedback and CollectionFeel matched Studio before
editing. 16 new isolated Edit checks passed: burst origin, immediate one-time
confirmation, particle budgets, outward motion, streak/flash duration, camera-side
flash visibility, world anchoring, shrink/cleanup, repeated payments, reduced
motion and generation reset. A temporary Edit preview with a block mannequin
was rendered and inspected; its scene was removed and original camera restored.
The new sources compiled and synced through Rojo. No live Play session or audio
listening assessment was performed. Temporary source snapshot, sampled reference
frames and checks: `/tmp/chicken-cash-reference-pv2rNn/`.

Initial egg/audio revision (the HUD cash-flight checks below are historical):

- All seven changed/new runtime modules compiled and matched canonical Studio
  through the existing Rojo connection, place 96683186622050.
- 32 isolated Edit-mode checks passed using a fake clock/frame signal, fake
  receipts and temporary instances. Covered late packets, moving targets, dense
  groups, replay, generation reset, collector routing, contact timing, exact
  cash totals, screen-coordinate math, interruption, sound overlap, mute,
  reduced motion, spring settling and wallet updates.
- All four sound IDs loaded successfully in Studio with their intended IDs.
  Readiness is not a subjective listening assessment.
- No Play session, player-data changes, purchases, uploads, place save, publish,
  commit or push was performed. The full rendered/audio experience remains for
  an in-game listen. Restart Play to load the new modules.

Temporary fixture and source recovery snapshot:
`/tmp/chicken-cash-feel-7cDHev/`. These are local temporary files, not a durable
place backup. The fixture never starts the game or touches player profiles.
