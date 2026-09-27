# Egg selling board

Implemented September 24, 2026; compact revision from Figma
`4lJjZOqNhR8K7rfMbVIjaK / 328:844`.

The Studio-owned `Workspace.MyChickenArmyMap["03_HomePlots"].EggCollectionBoard`
is beside Plot1, with `PlotIndex=1`. Its existing Screen.SurfaceGui contains the
editable count, rate, purple Finish Now and green inline-price Upgrade button. The existing
CollectionPart.TouchPart.SurfaceGui displays ready cash. Geometry is unchanged.
The client clones these surfaces into PlayerGui with the original Adornee so
the buttons receive input, and displays only the local owner's balances.

## Cash pad feedback

`src/client/EggProcessorController.luau` owns local pad presentation. The owner's
pad turns grey at zero ready cash and returns to its authored green when cash is
available. Moving horizontally on it alternates the face down 0.18 studs and back up, with
each visual leg lasting the user's current 0.25 seconds. Leaving returns it over
the user's current 0.01 seconds. Circular Out easing is preserved. The existing
`$0`/cash label remains the non-color state cue.

Detection requires a grounded humanoid and a downward ray hitting the actual
pad, rather than merely entering the wider cash-claim bounds. One TweenService
tween repeats and reverses automatically while moving on the pad; there is no
custom animation clock or scripted character movement. Heartbeat checks
occupancy, horizontal movement and color. Stopping, jumping, walking off,
character loss and ownership changes
release it; reduced motion keeps the face still. Unbinding restores authored
position and color. Tune `PAD_STEP_SECONDS` and `PAD_PRESS_DEPTH` in the controller.
Collection is server-owned and independent of tween speed. As requested on
September 26, every payout requires being grounded on the owned collector and
currently moving horizontally faster than 0.5 studs/sec. Standing still does not
collect, even after the cooldown expires or more cash arrives. Vertical pad
travel and small standing jitter do not count. Moving again permits collection,
still at most once per second; re-entry cannot bypass that cooldown. Leaving,
jumping or losing the character stops collection. Old `EggCashCollect` requests
remain ignored. Reduced motion suppresses animation, not the movement requirement.

The September 26 movement-only change passed 12 isolated checks against current
disk sources using fake sessions, pad contact and tweens. The fixture is
`assets/egg-board/moving-contact-checks.luau`. It covers stationary/new cash,
movement/resumption, vertical-only travel, jitter, cooldown, airborne/off-pad,
one-time payout and animation/reduced-motion behavior. No Play/Stop or real
profile operation was performed. At handoff Studio instance `w6a-k5r` had a
running session and older pre-quantity/pre-retirement sources; sync and fresh
runtime verification remain pending. Historical fixtures expecting stationary
auto-collection are superseded, not evidence for the new behavior.

Egg processing accumulates elapsed time and visits the queue only on whole-second
ticks: subtract the current selling rate from the queued count, capped by what
remains, and move those eggs' value to ready cash. Fractional frames no longer
recalculate batches. Slow frames catch up whole seconds without losing eggs;
idle time is not banked. Batch values, multipliers and saved-state format remain
unchanged.

Historical evidence (stationary behavior below was superseded September 26):
the September 25 contact fix passed 19 focused Edit checks in
`assets/egg-board/contact-checks.luau`: entry, standing, cooldown/re-entry,
ownership, airborne/off-pad rejection, whole-second processing and value
conservation. A fresh session-only Play also verified a real stationary R15
character on the authored pad: 40/40 grounded samples, 0.18-stud visual travel,
and two ready balances paid exactly once through an isolated session ledger.
Sources match their single Studio copies and compile. Play stopped; authored
geometry and saved profiles were untouched. The older movement-only checks are
historical evidence for the superseded interaction.

## Compact surface layout

The compact Figma arrangement is implemented on the existing shortened board:
cyan title, small Finish Now above the queue, large count, speed row and Upgrade.
The current user-authored SurfaceGui uses PixelsPerStud sizing at 60, so
CanvasSize is ignored. The user's layout and other controls are preserved.
On September 25, the queue headline was corrected to match the supplied Figma
reference: SourceSansBold, TextSize 100, TextScaled false, and a native child
`FigmaTextScale` UIScale of 1.375. Its reciprocal Size adjustment preserves the
original on-screen label rectangle and center; only the rendered number grows.
The visible outline remains the same thickness. Other labels retain TextScaled.

To tune the number in Studio, select
`Screen.SurfaceGui.EggSellingBoard.Content.QueuedCount` and adjust TextSize, or
its `FigmaTextScale.Scale` child to exceed Roblox's TextSize ceiling. Keep
TextScaled false: native auto fitting still caps the number at 100 rendered
pixels on this canvas even with a UIScale. The controller captures the authored
TextSize when binding, shrinks only overlong counts to the actual available
width including the outline, and restores the headline size for shorter counts.
It no longer resets the number to the legacy 88 px / 253 px fitting rule.

The corrected `10,000` has 323 px text bounds in its unchanged 509.813 px row,
approximately the reference's 63% width. The Studio screenshot confirms the
visual result; all other GuiObject Position/Size/AnchorPoint values match the
before-copy. Actual controller rendering was checked with zero, 10,000, six-digit,
billion and trillion counts, then 10,000 again. No Play session was needed.
Recovery: `ServerStorage.EggQueueTypographyBefore20260925`; the bounded asset
recipe and original controller are under `assets/egg-board/queue-typography-20260925/`.

The controller updates the inline upgrade price and native caption layers.
Existing transactions, Finish Now routing, cash-pad behavior and builder geometry
are preserved. Shared UITheme colors, square controls and the approved cropped
stud-sheet image remain in use.

All authored GuiObject Position/Size properties on the board (including cash
display and the three stud sheets) now have zero offsets. The sheets opt into
UITheme's `StudScaleWidth` mode so runtime rebinding preserves scale sizing and
square cropping. Other screens keep their existing texture sizing. Pre-conversion
images remain in `EggSellerCompactBackup20260924.BeforeScaleStudTextures`.

Fourteen focused Edit checks passed for the compact controller integration before
the final native-scale simplification (bindings, live values, pending/max states,
upgrade/Finish Now routing, ownership, count fitting and pad teardown). Those
earlier count-fitting checks are not evidence for the later TextScaled layout.
The final scale layout was inspected in the Studio viewport; no Play session was
started.

The prior SurfaceGui is recoverable under
`ServerStorage.EggSellerCompactBackup20260924.SurfaceGui`; the user's intermediate
layout is preserved there as `BeforeNativeScale`.
`assets/egg-board/compact-studio.luau` records the compact authoring recipe and
refuses to overwrite an existing migration. No save or publish was invoked for
this compact revision.

Manual egg bags and the existing vacuum deposit into the seller at the original
Plot1 sellpart. Depositing does not pay the wallet. Eggs process while online;
the separate front pad pays ready cash at most once per second
while the player is grounded and moving horizontally on it.
Other plots retain their current instant selling until boards are authored there.
If a rejoining player is assigned an older plot, saved queued eggs still process
and its owned sellpart permits claiming the saved proceeds.

Under the September 26 [quantity economy](EGG_ECONOMY.md), selling starts at
4 eggs/sec. Rates are 4 / 16 / 64 / 256 / 1,024; upgrade costs remain
480 / 2,400 / 9,600 / 28,800 coins. Configure these in
`src/shared/EggProcessorConfig.luau`. Double Egg Spawn doubles seller throughput;
Double Cash applies once, when ready cash is claimed. Board purchases check
ownership, distance, current level and price on the server.

Finish Now uses existing developer product **3714566216**. Native Roblox checkout
shows its current price (80 Robux when inspected). The sole ProductService receipt
handler finishes all currently queued eggs into the pad's ready balance and saves
that state with the receipt. Replayed receipts cannot finish a subsequent queue.
If a receipt arrives after the queue emptied, a saved finish credit completes the
next deposited batch so the paid benefit is retained. No eggs in the yard, bag or
vacuum are included in a nonempty queue's Finish Now grant.

PlayerSession persists bounded batches, fractional progress, ready raw value,
seller level and deferred finish credits. Profile revision 9 rejects older code
that cannot retain these fields; old profiles load with an empty level-zero seller.
Batch compaction preserves total count and value. No offline production or selling
is added. Processing, deposits and cash transfers never depend on GUI animation.

## Evidence and recovery

- Source files matched Studio before editing; all 14 modified/new runtime files
  matched Studio again after Rojo sync. No mapped source was written through MCP.
- Nine focused Edit fixtures passed: integer value conservation, bounded backlog,
  profile roundtrip/validation, owner restriction, separate cash claim/rearm, and
  vacuum deposits, upgrade transactions, live GUI/button routing, and Finish Now
  receipt replay/failed-save/deferred-credit behavior. Fake sessions and
  fake purchase storage only; no real profiles or purchases. Fixture is
  `assets/egg-board/checks.luau`.
- Relevant new server/client modules compiled; Git whitespace check passed.
- Original board inspected visually in Studio Edit. The initial 800px layout used
  UIScale for its headline; the compact revision above replaces that with native
  TextScaled and scale-based layout.
- Original board preserved in ServerStorage.EggCollectionBoardBefore20260924.
  Original in-scope sources are in assets/egg-board/before/source-baseline.json.
  Asset recipe: assets/egg-board/build.luau. Do not rerun it after manual visual
  edits without reviewing those edits; the Studio board is editable source art.
- No agent-started Play session, real checkout, publishing or Git commit/push.
  Native Save to Roblox was invoked, but no save toast/log confirmation was returned;
  cloud-save status is unconfirmed. The code is on disk and synced into Studio;
  authored surfaces are present in the open place.
# Purchase button presentation — September 25, 2026

Upgrade and Finish Now retain their shared UIMotion hover/press/shine behavior.
Only Upgrade changes its face gradient to UITheme.UnaffordableGradient when
cash is below upgradePrice; it restores the authored gradient at affordability.
Finish Now retains its original gradient regardless of the player's cash.
Pending/MAX eligibility and purchase routing are unchanged. Focused cash-state
and animation checks passed; evidence is in assets/purchase-buttons-20260925.
