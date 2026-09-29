# Offline cash

**September 29 direction:** egg deposits now pay immediately with the existing Money
effect. Timed processing, Selling Speed and Finish Now are archived. Saved egg
balances, seller levels and paid finish credits remain compatible. This supersedes
the September 27–28 processing requirements. See [instant sales and restoration](team/INSTANT_EGG_SALES.md).

Implemented September 24, 2026. Cash only: no offline eggs, hatching, battles,
queue processing, purchases or new spawn rates.

- `src/shared/OfflineCashConfig.luau`: 2% efficiency, eight-hour cap, one-minute
  minimum, existing one-trillion-coin wallet ceiling.
- `src/server/OfflineCash.luau`: validated checkpoint, steady-state rate bounded
  by production (with the archived seller cap only when re-enabled), whole-coin reward calculation.
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

September 29: new checkpoints use total owned eggs/sec × shared unit value ×
verified cash benefit × 2% efficiency. Selling Speed no longer caps this rate.
The eight-hour cap and recorded rates of existing checkpoints are unchanged.

Historical September 26 quantity-economy correction: the rate sums each species/level's actual
eggs/sec, caps that total by seller eggs/sec and multiplies by the shared egg unit
value before the existing paid benefit and efficiency. It no longer estimates
egg quantity from the number of chickens. Existing frozen checkpoints retain their
recorded rate until consumed. See [EGG_ECONOMY.md](EGG_ECONOMY.md).

Normal exit starts at departure; crash recovery conservatively starts at the
last saved lease expiry (180 seconds after the snapshot). A new/old profile's
first visit establishes its rate and earns no historical windfall. Standard
autosave and departure then establish the next interval. Session-only Studio
games do not persist or naturally earn offline rewards.

[Research and balance tables](</Users/stevin/Documents/ChatGPT/My Chicken Army/research/offline-cash-2026-09-24.md>)
explain why eight hours pays only 9.6 minutes of sustainable active income.
[Approved compact Figma receipt](https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK/my-chicken-army?node-id=359-3508)
is editable on page “03 • Game screens”.

## September 29 responsive receipt and blur

The receipt now has a transparent body and input shield over the shared world
blur, replacing the old black backdrop and inset charcoal panel. It retains the
green studded header and Continue button. A bounded 560 × 440 composition (plus
eight pixels around the fading canvas) reflows to the safe viewport. The reward
amount fits its own text bounds without a separate 1.25× text scale. Short
screens keep Continue at least 52 pixels tall and scroll only the content above
it. A native check glyph replaces the unimported saved-check image.

UIMotion's ordinary TweenService tracks fade the canvas in over 0.22 seconds,
slide it up 18 pixels and scale it from 0.94 to 1 over 0.28 seconds. Dismissal
fades/scales/slides out over 0.16 seconds, then destroys the receipt. Repeated
clicks do not restart dismissal; replacing a receipt and teardown remove it
immediately. Reduced motion applies the final state without travel or scaling.

AppController owns one client BlurEffect for both main pages and this separate
receipt. Opening the next menu keeps blur active; closing the last one tweens
it out. Continue still only dismisses already-saved cash. This styling change
has not been playtested or visually validated; older evidence below predates it.

## Historical compact receipt follow-up

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
