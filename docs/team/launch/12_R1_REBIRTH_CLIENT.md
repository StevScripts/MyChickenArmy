# Worker R1-C: rebirth ("Re-enlist"), client

**Branch:** `launch/r1-rebirth-client` · **Worktree:** `~/Documents/Projects/mca-r1c` · **Plan:** [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §6.7
**Needs the foundation?** Yes. Start after the lead commits it.
**Works with:** R1-S implements the server. You render `state.rebirth` and send the `Rebirth` action. Until R1-S merges, the stub quote says `eligible = false, reason = "Coming soon"`. Build for the full quote below anyway.

## Files you own (only these)

- `src/client/RebirthPanel.luau` (the foundation stub; you replace the body)
- `src/client/CashUpgradeNodes.luau` (adds the Re-enlist hex to the Upgrades/Research screen)
- `src/client/HudController.luau` (rank label and the "you can re-enlist" toast)
- `docs/team/launch/handoff/R1-C.md` (new)

**Do not edit `AppController.luau`.** The foundation already creates `RebirthPanel.new(app)` and calls `:Render(state)` on every state change. If you need another hook in AppController, write a "Request for lead".

Before you start, read `docs/UI_EDITING.md`, `docs/UI_RESPONSIVE.md`, `src/client/UITheme.luau` and `src/client/OfflineCashController.luau` (the closest existing popup). Match their look: square geometry, transparent near-black content, SourceSans type, black silhouette stroke on chicken art, the stud texture used consistently. Build in code with the UITheme helpers, the way OfflineCashController does. If the convention for this kind of panel is a Studio-authored frame, stop and write a request for the lead; you can't open Studio.

## The quote you receive (`state.rebirth`)

```lua
{enabled, rank, nextRank, title, nextTitle, cost, coins, kingCleared, armyHome,
 eligible, reason, multiplierNow, multiplierNext, enemyScaleNext}
```

`title` is "Recruit" at rank 0, then "Veteran I", "Veteran II" and so on.

## What to build

### 1. The Re-enlist hex (`CashUpgradeNodes.luau`)

Add one hex after the existing cash tracks, labeled **Re-enlist**, using the same node style:
- Locked (not `kingCleared`): greyed, with "Defeat the Chicken King".
- Not eligible for another reason: shows `reason` and a progress bar of `coins / cost`.
- Eligible: highlighted with the Army green accent. Tapping it opens the panel.
- When `enabled == false`, hide the hex entirely.

### 2. The panel (`RebirthPanel.luau`)

A centered panel, the same frame style as the offline receipt:

- **Title:** "Re-enlist as Veteran II" (from `nextTitle`).
- **Two columns.**
  - **Keep:** Chickens and Giants · Research · Index · Plot size · Roll podiums · Army size · Passes.
  - **Reset:** Cash · Egg Laying Speed · Egg Value · Luck · Camps and King.
- **Gains row:** "Eggs ×1.25 → ×1.50 forever" (from `multiplierNow` and `multiplierNext`) and "Enemies get stronger (×2.0)" (from `enemyScaleNext`).
- **Cost:** "Costs $8B" (`cost`), using the game's existing money formatter.
- **Confirm button:** hold to confirm for 2 seconds, with a fill bar that drains if released early. Never use `confirm()`. While not eligible, the button is disabled and shows `reason`.
- On confirm, send `{action = "Rebirth", expectedRank = state.rebirth.rank}` through the same request function other actions use (find how `AppController` or `HudController` sends `RequestAction`; for example, how `Promote` or `Expand` is sent).
- **Close button,** plus close on Escape and on success. Gamepad: select the confirm button first, matching how other panels set `GuiService.SelectedObject`.
- **On success** (the next state has a higher `rank`): close the panel, play the existing King-clear or celebration effect if one is reusable, and show a toast: "You are now Veteran II".

**Phone layout:** at a 375 × 812 viewport the two columns stack and the hold button stays at least 44 points tall. Follow `UI_RESPONSIVE.md`.

### 3. HUD (`HudController.luau`)

- **Rank label:** when `rank >= 1`, show the title ("Veteran II") next to the player's money or name, in the existing HUD text style. Hidden at rank 0.
- **Toast:** the first time `eligible` becomes true in a session, show "You can re-enlist as Veteran I. Open Upgrades." Use the existing notification call. Only once per session.

## Edge cases

- `state.rebirth` may be missing on the first state after join. Render nothing until it arrives.
- The quote changes as coins change. The progress bar must update without reopening the panel.
- If a `Rebirth` request fails, show the server's message in the panel and keep it open.
- Reduced motion (Settings): no fill animation flourish and no celebration burst.

## How the lead verifies

There are no automated UI tests here. The lead checks in a disposable playtest:

1. At rank 0 without a King clear, the hex is locked and says "Defeat the Chicken King".
2. After giving the test session a King clear and $1B, the hex lights up, the toast appears once, and the panel shows the right Keep, Reset, gains and cost.
3. Releasing the hold early does nothing. Holding for 2 seconds re-enlists, closes the panel and shows the HUD label.
4. Phone emulator (375 × 812): everything fits; the columns stack.

Write these steps, with what the lead should expect to see, in your handoff.

## Handoff

Commit on your branch and write `docs/team/launch/handoff/R1-C.md`: files changed, how the panel is opened and closed, the verify steps, and any request for the lead (especially AppController hooks).
