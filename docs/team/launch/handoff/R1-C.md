# Handoff R1-C: Re-enlist client

**Branch:** `launch/r1-rebirth-client` (from foundation `bec87ac`). Studio was not opened, Rojo was not synced, nothing was pushed. Luau tooling (luau-analyze, selene) isn't installed here, so **no static analysis or runtime check was run**. I reviewed the code by reading it only. The first Studio sync is the first real compile.

Owner decisions applied: the name is "Re-enlist", ranks are "Veteran I, II, III…", rank 0 is "Recruit", and chicken levels are kept (the Keep column says "Chickens, levels and Giants").

## Files changed

| File | Change |
|---|---|
| `src/client/RebirthPanel.luau` | Replaces the stub. Draws the Re-enlist hex and the hold-to-confirm panel. Keeps `new`, `Render(state, result)` and `Destroy`, and adds `Open()` and a static `RebirthPanel.Title(rank)` (Roman-numeral fallback). |
| `src/client/CashUpgradeNodes.luau` | Adds the frozen descriptor `Cash.Reenlist = {id, name, icon, description}`. It is kept out of `Order`/`Nodes`/`ByKey` on purpose (see below). |
| `src/client/HudController.luau` | Adds the rank label above the cash readout and the once-per-session "you can re-enlist" toast (`Hud:UpdateRebirth`, called from `Hud:Update`). |
| `docs/team/launch/handoff/R1-C.md` | This note. |

## Where the hex lives (differs from the doc)

`CashUpgradeNodes.luau` is data only. The hexes are drawn by `ResearchBrowser.luau`, which I don't own. Adding Re-enlist to `CashNodes.Order` would make `ResearchBrowser:RenderCash` error, because it has no `upgradeKey` or tiers. Every map cell inside the default view is also already taken.

So `RebirthPanel` builds the hex itself, as an `ImageButton` named `ReenlistHex` parented to `app.research.root`. It is a fixed overlay in the top-right of the research screen (`AnchorPoint (1,0)`, `Position (0.985, 0.12)`) and stays put when the map pans or zooms. It uses the same art as the cash tiers (`hexMask`/`hexFill`, six halos, icon, title, progress bar and a top badge), and its icon is `ResearchAssets.army`. It is built lazily on the first `Render`, after `BuildUI` has created `app.research`.

Hex states:
- **Hidden:** `state.rebirth` is missing, or `enabled == false`.
- **Foundation stub** (no `kingCleared` field): locked grey, shows `reason` ("Coming soon"). Tapping shows that reason as a toast.
- **Locked** (`kingCleared == false`): grey, "Defeat the Chicken King". Tapping opens the panel, where the button is disabled with the server reason.
- **Progress** (King cleared, not eligible): dim green rim, shows `reason`, and a `coins / cost` bar that refreshes on every state packet.
- **Eligible:** solid Army-green fill, bright halos, "Tap to re-enlist", and a gentle TweenService pulse (repeat/reverse). There is no pulse with reduced motion.
- The top badge shows `nextTitle`. A `ReenlistState` attribute is set on the button for probes.

## How the panel opens and closes

- **Opens:** tap or click the hex, or press **L2** on a gamepad while the research screen is open (a small "L2" hint shows when a gamepad is connected). Code can also call `app.rebirthPanel:Open()`. Opening closes the research map or main panel, takes the `"rebirth"` menu blur and dismisses the offline receipt. With a gamepad, `GuiService.SelectedObject` goes to the hold button.
- **Closes:** the header X, Escape, or gamepad B. If the panel was opened from research, the map reopens (deferred, so the same key press doesn't also close the map). It also closes immediately if another menu or the research map opens on top of it.
- **On success** (the next packet's `rank` is higher): it closes without reopening research, plays `Victory`, shows the `UIMotion:Burst` in green (skipped with reduced motion), and toasts "You are now Veteran II". AppController's generic success toast still fires first; mine replaces it in the same frame.
- **On failure** (`result.action == "Rebirth"`, `ok == false`, matching request id): the panel stays open, shows the server message in red above the button, and resets the fill. AppController also raises its usual error toast.

## Panel contents

- **Header:** "Re-enlist as {nextTitle}", or "Re-enlist" when `nextTitle` is missing (max rank).
- **Keep column:** Chickens, levels and Giants · Research · Index · Plot size · Roll podiums · Army size · Passes.
- **Reset column:** Cash · Egg Laying Speed · Egg Value · Luck · Camps and King.
- **Gains:** "Eggs ×1.25 → ×1.50 forever" and "Enemies get stronger (×2.0)".
- **Cost:** "Costs $8B", using `UITheme.Number`, the compact formatter the research hexes use. A thin coins/cost bar shows while you can't afford it.
- **Hold button:** a `UITheme.ActionButton` with the full-sheet studs. A white fill tweens linearly for 2 seconds while held. Releasing early drains it with a 0.35 s tween, or instantly with reduced motion. The fill stays linear with reduced motion because it is the timer itself, but there is no flourish.
- **Sending:** after 2 s it sends `app:Request("Rebirth", {expectedRank = state.rebirth.rank})` and shows "Re-enlisting…". It unlocks after 10 s if no reply arrives (the server's `expectedRank` check rejects a repeat). While not eligible, the button is greyed and shows `reason`.
- **Input:** mouse and touch use `InputBegan` on the button plus a global `InputEnded`. Gamepad A is a CAS bind at priority 3000, used only while the hold button is selected; otherwise it passes.

## Layout and phone

- The panel follows `OfflineCashController`: a container in `app.other` with CoreUISafeInsets, a full-device backdrop, a `CanvasGroup` with the shared header, `BelowHeader`, an Army surface and `ApplyPopupStyle`/`ScaleText`. Everything uses Scale sizing with native aspect constraints, and there is no viewport code.
- If Studio authors `PetRollGui.MenuLayouts.Rebirth`, `MenuLayout.Apply` uses it. Otherwise the code default is Size (0.94, 0.66) with aspect 1.4, fit-within. That is about 998×713 on 1920×1080, about 352×251 on a 375×812 portrait phone, and about 327×233 on a landscape phone.
- **The columns do not stack at 375×812.** The panel has a fixed aspect ratio, so its inside layout is identical on every screen. Stacking would need a device breakpoint, and AGENTS.md / UI_RESPONSIVE.md forbid that (September 30 rule). On phones the panel fills about 94% of the width instead, and text keeps the shared 12 px floor.
- The hold button sits in a 0.6 × 0.16 area with a native `UISizeConstraint` MinSize Y of 44, so it stays at least 44 points tall. On the smallest landscape phone this minimum lets the button rise into the one-line error message area. Errors are rare, but check it.

## Verify steps for the lead (disposable playtest)

1. **Stub (before R1-S merges).** Open Upgrades (U). The top-right hex reads "Re-enlist", is grey and says "Coming soon". Tapping it gives a "Coming soon" info toast. No HUD rank label, no errors in output.
2. **Locked (R1-S merged, rank 0, no King).** The hex is grey with "Defeat the Chicken King". Tapping opens the panel: the header reads "Re-enlist as Veteran I", the button is grey and shows the server reason ("Defeat the Chicken King first"), and holding does nothing.
3. **Eligible.** Use Admin (F2) "Beat all camps and the King", then give at least $1B (`cash me 1b`; AdminCommands accepts k/m/b/t). With the army home:
   - the toast "You can re-enlist as Veteran I. Open Upgrades." appears once, and only once per session;
   - the hex turns solid green and pulses;
   - the panel shows the Keep and Reset lists above, "Eggs ×1.00 → ×1.25 forever", "Enemies get stronger (×1.5)" and "Costs $1B".
   Before the cash: the hex and panel bars track coins live, without reopening.
4. **Hold.** Releasing before 2 s drains the fill and nothing is sent. Holding for 2 s shows "Re-enlisting…", then the panel closes, the green burst and Victory sound play, the toast says "You are now Veteran I", and "Veteran I" appears above the cash readout (with a pop).
5. **Failure.** With the panel open and eligible, send the army out (or spend cash in another way), then hold. The server's reason shows in red in the panel, which stays open. With the army away, the quote already marks it ineligible, so the button shows the reason instead.
6. **Close paths.** X, Escape and gamepad B close the panel and return to the research map. Opening Army (B) while the panel is open replaces it. With a gamepad, the hold button is selected on open, A-hold works, and L2 on the research map opens the panel.
7. **Reduced motion** (Settings). No hex pulse, no panel scale/slide, instant drain, no burst. The hold fill is still linear for 2 s.
8. **Phone emulation, 375×812 and landscape.** The panel fits inside the safe area, the text is readable, and the hold button is at least 44 points tall. The columns stay side by side (see above). Check whether the hold button overlaps an error message in landscape.

## Requests for lead

1. **ResearchBrowser integration (optional, later).** It would be cleaner to give the hex a real map cell with D-pad navigation in `ResearchBrowser` (its `Navigate`/`Transform` only walk `displayOrder`). Until then, the fixed overlay plus L2 covers mouse, touch and gamepad.
2. **Blocking checks.** `BaseController.luau:554` and `CommanderGuide.luau:227` treat `app.offlineCash.gui` as a blocking popup. They may also want `app.rebirthPanel.gui ~= nil`, so world prompts and Commander lines don't run under an open Re-enlist panel.
3. **Commander line.** Plan §6.7 wants a guide line after re-enlisting: "Your army is stronger. So are the camps. Retake Cluck Camp." It belongs in `CommanderGuide`, which I don't own.
4. **Rank elsewhere.** Plan §6.7 also wants the rank on captured flags and leaderboard rows. Those are other files and are not done.
5. **Optional Studio layout.** To tune the panel size in Studio, add a `PetRollGui.MenuLayouts.Rebirth` Frame with a `UIAspectRatioConstraint`. `MenuLayout.Apply` picks it up automatically. Without it, the code default above applies.
6. **Icon.** The hex reuses the existing Army HUD icon. A dedicated Re-enlist icon (black-stroked, per AGENTS.md) could replace `CashUpgradeNodes.Reenlist.icon` later.

## Lead result (October 13, merged as b97ec14)

- Disposable playtest (desktop viewport): the hex shows on the Upgrades screen ("Tap to re-enlist", green) with a King clear and $1B; `Open()` shows the Keep/Reset panel with ×1.00 → ×1.25, ×1.5 enemies, $1B cost. An early release (0.8 s) sent nothing; a 2 s hold re-enlisted, closed the panel and showed "Veteran I" above the cash. No client errors.
- Not verified: studio-flow mouse injection does not reach GUI buttons in this Studio, so taps were driven through `Open/BeginHold/EndHold`. A real tap on the hex and the hold button, the phone emulator, gamepad L2 and reduced motion still need a hands-on check.
- Requests 1–6 are deferred (not needed for publish 1).
