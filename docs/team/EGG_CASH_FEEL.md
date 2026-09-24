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
