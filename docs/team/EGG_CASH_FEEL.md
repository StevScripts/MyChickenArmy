# Egg and cash feedback — September 24, 2026

Owner: this task. Scope: client egg pickup, deposit, cash arrival, sounds and HUD
feedback. Files: `src/client/EggController.luau`, `ActionFeedback.luau`,
`AudioController.luau`, `VacuumController.luau`, `UIMotion.luau`; shared
`EggMotion.luau` and new `CollectionFeel.luau`; `docs/COLLECTION_FEEL.md`.
Existing vacuum and seller edits are preserved. No server files or economy settings.

Before editing, the eight inspected sources matched canonical Studio in Edit mode,
Pet Roll Test, place 96683186622050. Local source snapshot:
`/tmp/chicken-cash-feel-7cDHev/source-baseline.json` (temporary recovery file).
Implementation and focused review complete. All seven changed/new runtime
modules matched Studio through Rojo and compiled. 32 isolated Edit checks passed;
all four intended audio samples loaded. No live Play session or publication.
Tuning, ownership, checks and remaining perceptual review: `docs/COLLECTION_FEEL.md`.

Reference revision: user requested cash matching the September 24 4:51 PM
recording. Revised only ActionFeedback, CollectionFeel and these documents.
Cash now bursts outward at the player with white streaks, a gold flash and loose
bills. 16 focused Edit checks passed; temporary rendered preview inspected and
removed, camera restored. Audio reference was not heard. Sources synced via Rojo;
no Play, save, publish, asset upload or economy change.

Latest direction: simplify cash to ordinary tweens. Replaced the reference burst
with one rising/fading icon and one sound; removed cash trails, flash, loose bills
and spring pulse. Only ActionFeedback, CollectionFeel and documentation changed.
Seven focused Edit checks passed with native tweens. Existing Play was untouched.

Latest correction: cash must tween outward and then back into the player, not
rise/fade. Six icons now use two native tweens each, on character-local
Attachments so movement is followed automatically. Twelve focused Edit checks
passed, including phase order, moving targets and cleanup. Cash settings/docs
updated; egg behavior remains unchanged.

Latest supplied-script revision: replaced the six generated icons with ten clones
of the user's `Workspace.CashDrop`, moved intact to
`ReplicatedStorage.PetRoll.Assets.CashDrop`. Preserved its image, two attachments
and trail. Adopted the supplied random quadratic waypoints, Exponential Out curve
duration 0.65s, return start 0.30s, Exponential In return and Quad In fade 0.30s,
then cleanup. BezierTween/CrashPart were absent; native scalar tween supplies
the curve, clones are noncolliding, and outward motion is cancelled on return.
Only ActionFeedback, CollectionFeel, these docs and that template's parent changed.
Both runtime sources match Studio and compile. Isolated Edit checks passed for
authored clone preservation, both phases, return target, fade, repeats and cleanup.
No Play session, save, publish, upload or player-data change.
