# Egg selling board

Implemented September 24, 2026 from Figma `4lJjZOqNhR8K7rfMbVIjaK / 328:885`.

The Studio-owned `Workspace.MyChickenArmyMap["03_HomePlots"].EggCollectionBoard`
is beside Plot1, with `PlotIndex=1`. Its existing Screen.SurfaceGui contains the
editable Figma count, rate, upgrade price and green buttons. The existing
CollectionPart.TouchPart.SurfaceGui displays ready cash. Geometry is unchanged.
The client clones these surfaces into PlayerGui with the original Adornee so
the buttons receive input, and displays only the local owner's balances.

Manual egg bags and the existing vacuum deposit into the seller at the original
Plot1 sellpart. Depositing does not pay the wallet. Eggs process while online;
the separate front pad pays ready cash on entry, then rearms after leaving.
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
- Board inspected visually in Studio Edit. Large count uses native UIScale to
  preserve Figma's 176px headline despite TextSize's 100 limit. Long live counts
  shrink to fit the same area.
- Original board preserved in ServerStorage.EggCollectionBoardBefore20260924.
  Original in-scope sources are in assets/egg-board/before/source-baseline.json.
  Asset recipe: assets/egg-board/build.luau. Do not rerun it after manual visual
  edits without reviewing those edits; the Studio board is editable source art.
- No agent-started Play session, real checkout, publishing or Git commit/push.
  Native Save to Roblox was invoked, but no save toast/log confirmation was returned;
  cloud-save status is unconfirmed. The code is on disk and synced into Studio;
  authored surfaces are present in the open place.
