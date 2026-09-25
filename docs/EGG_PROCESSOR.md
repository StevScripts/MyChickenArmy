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
available. Standing on it alternates the face down 0.18 studs and back up, with
each visual leg lasting the user's current 0.25 seconds. Leaving returns it over
the user's current 0.01 seconds. Circular Out easing is preserved. The existing
`$0`/cash label remains the non-color state cue.

Detection requires a grounded humanoid and a downward ray hitting the actual
pad, rather than merely entering the wider cash-claim bounds. One TweenService
tween repeats and reverses automatically while standing on the pad; there is no
custom animation clock or scripted character movement. Heartbeat checks
occupancy and color. Jumping, walking off,
character loss and ownership changes
release it; reduced motion keeps the face still. Unbinding restores authored
position and color. Tune `PAD_STEP_SECONDS` and `PAD_PRESS_DEPTH` in the controller.
Collection is server-owned and independent of tween speed. Stepping onto the
owned collector pays ready cash; staying grounded on it pays new ready cash at
most once per second. Horizontal movement is not required. Leaving, jumping or
losing the character stops collection. Re-entering cannot bypass the server's
one-second cooldown, and old `EggCashCollect` requests remain ignored.
Reduced-motion players collect while standing without seeing the pad animation.

Egg processing accumulates elapsed time and visits the queue only on whole-second
ticks: subtract the current selling rate from the queued count, capped by what
remains, and move those eggs' value to ready cash. Fractional frames no longer
recalculate batches. Slow frames catch up whole seconds without losing eggs;
idle time is not banked. Batch values, multipliers and saved-state format remain
unchanged.

The September 25 contact fix passed 19 focused Edit checks in
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
The SurfaceGui uses a 320 x 300 canvas (half the Figma reference resolution,
allowing the count to fill its label without hitting the native font-size cap).
EggSellingBoard fills it with Size
`{1,0},{1,0}`; layout positions and sizes use native Scale values. Labels use
`TextScaled`, including the count, with no headline UIScale or custom text-fit
attributes. Changing the root size now scales the layout together. Keep the
canvas near its authored size: an unnecessarily huge canvas can make native
text appear small because Roblox caps its font size.

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
the separate front pad pays ready cash on entry and at most once per second
while the player stands on it.
Other plots retain their current instant selling until boards are authored there.
If a rejoining player is assigned an older plot, saved queued eggs still process
and its owned sellpart permits claiming the saved proceeds.

Selling starts at 2 eggs/sec. Rates are 2 / 4 / 8 / 16 / 32; upgrade costs are
480 / 2,400 / 9,600 / 28,800 coins, from the earlier proposal. Configure these in
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
