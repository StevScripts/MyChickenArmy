# Offline cash

Implemented September 24, 2026. Cash only: no offline eggs, hatching, battles,
queue processing, purchases or new spawn rates.

- `src/shared/OfflineCashConfig.luau`: 2% efficiency, eight-hour cap, one-minute
  minimum, existing one-trillion-coin wallet ceiling.
- `src/server/OfflineCash.luau`: validated checkpoint, steady-state rate bounded
  by saved seller throughput, whole-coin reward calculation.
- `src/server/PlayerSession.luau`: revision-10 checkpoint roundtrip; transient
  already-paid `state.offlineCash` receipt. Missing old checkpoints default to zero.
- `src/server/DataService.luau`: frozen rate/time capture on save/release; award
  and consume the old interval in a saved payload before exposing the loaded
  session. Failed saves block play. Crash recovery starts after lease expiry.
- `src/client/OfflineCashController.luau`: one dismissible welcome-back receipt,
  shared UITheme, safe-area sizing, large-number fitting, keyboard
  and gamepad dismissal, repeated-state deduplication and cleanup.
- `src/client/AppController.luau`: controller construction, Receive and Destroy.

All owned birds count because battles do not persist across sessions. Existing
Egg Value, Egg Speed, Double Egg Spawn and Double Cash benefits are captured on
the server when saved. Paid benefits use that session's verified entitlements,
not a new purchase after returning. Seller/bag/vacuum balances are unchanged.
No claim remote or client-submitted timestamp/amount exists. Currency is already
saved before the UI says it was added.

Normal exit starts at departure; crash recovery conservatively starts at the
last saved lease expiry (180 seconds after the snapshot). A new/old profile's
first visit establishes its rate and earns no historical windfall. Standard
autosave and departure then establish the next interval. Session-only Studio
games do not persist or naturally earn offline rewards.

[Research and balance tables](</Users/stevin/Documents/ChatGPT/My Chicken Army/research/offline-cash-2026-09-24.md>)
explain why eight hours pays only 9.6 minutes of sustainable active income.
[Approved compact Figma receipt](https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK/my-chicken-army?node-id=359-3508)
is editable on page “03 • Game screens”.

## Compact receipt follow-up

The approved 448×394 composition is implemented in the receipt controller:
green Offline Earnings header, centered exact cash amount, saved-status text,
and one Continue action. The header and button both reuse the generated full
stud sheet through UITheme. The inset charcoal body and native outlined text
follow the Figma slots; SourceSans sizing is adjusted for Roblox's em metrics.
Continue only dismisses this already-paid receipt. Server rates and persistence
are unchanged by this presentation update.

Focused session-only Studio checks passed: receipt creation, real Continue
click, one click sound, repeated/zero receipts ignored, listener cleanup,
selection cleanup, and full trillion-coin amount fitting. Ordinary desktop
rendering and both loaded 672×672 stud sheets were inspected. Narrow text was
measured at panel widths 280, 296, 351 and 448; touch/gamepad input and actual
mobile viewport reflow were not exercised. Studio returned to Edit.

Pending: the exact 28×28 saved-check PNG/SVG has been exported locally, but its
Roblox image import is blocked by native computer-use controls returning
`noWindowsAvailable`. The icon URI is empty until import succeeds; status text
still renders. Do not call this a complete asset-fidelity pass. The Mac-unlock
request is pending. Recovery copies and checks are in
`assets/offline-cash/compact-ui/`.

An unrelated existing EggProcessorController binding reports a missing
InsetHighlight on the authored egg board; this receipt change does not edit
that controller or board.

## Verification and recovery

`assets/offline-cash/checks.luau` is a disposable Studio Edit fixture using fresh
module environments and fake DataStore/clock/session objects. Its 14 groups pass;
`check-results.json` includes their names and six actual-Luau balance scenarios.
New modules compile and Rojo packaging/whitespace checks pass. Isolated PC
startup and synthetic client receipt checks passed; no clipped ordinary desktop
text or duplicate popup. After the Mac was unlocked, the rendered receipt and
cash artwork were confirmed. Clicking Continue dismisses it, disconnects its
listeners and does not reopen on the same receipt. The trillion-coin edge case
exposed Roblox's TextWrapped/TextScaled coupling; measured single-line fitting
now follows the existing ChickenBrowser pattern. The final rendered
`+$1,000,000,000,000` amount fits at text size 52 with no clipped labels. All seven
affected runtime sources exactly matched Studio and compiled after the fix.
Keyboard dismissal uses AppController's existing InputBegan pattern; its final
interactive check was interrupted when the playtest ended externally. Gamepad
and device-emulated mobile input were not exercised. Studio is back in Edit.
No real saved player data was read or written by these checks.

The before-edit local/live source snapshot is `assets/offline-cash/source-baseline.json`.
Only bounded edits were made to existing files; preserve other tasks' edits when
reverting. Profile revision is 10; do not simply roll back the schema version
against profiles already saved by this implementation.

Code is stored locally and synced by the existing Rojo connection into Pet Roll
Test, place 96683186622050. Roblox Save/Publish and Git commit/push are separate
actions and were not performed by this task.
