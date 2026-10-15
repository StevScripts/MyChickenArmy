# Auto Roll (October 15)

Owner decision: a free research unlock (no game pass), stop-on-good only (no
auto-recruit), works anywhere.

- **Unlock:** research `AutoRoll` ($2,500, 60 s, prerequisite Lucky Feathers I,
  Rolling branch, hex q=1 r=-3), effect `autoRoll`.
- **Server:** `RollService:StepAuto` runs from `GameServer:Step` every 0.25 s for
  every loaded commander. It pulls the normal `Roll` whenever the lever is ready
  (skipped while the starter recruit is pending). It stops while an offer worth
  keeping waits on a podium (`RollService.Keeper`): any mutated offer, or the
  player's `stopAt` (`Config.AutoRollStops`: "Upgrade" = `OfferAdvice` says it
  fills or strengthens the army; or Rare/Epic/Legendary/Mythic and up). It
  announces the keeper once via `session.banner`. Recruiting it or pulling the
  lever lets it roll on. Offer analytics match manual rolls.
- **Saved:** `autoRoll={enabled,stopAt}` in the profile (missing or odd values
  fall back to off / "Upgrade"); `heldOffer` is session-only. Request
  `SetAutoRoll {enabled?, stopAt?}`, refused before the research.
- **Client:** a fourth button in the left column (Auto Roll, badge ON / PAUSED /
  OFF); the column grows to fit it once researched (`Hud:LayoutShortcuts`).
  Settings has the toggle and "Auto Roll stops at" (cycles). The roll camera zoom
  is skipped while Auto Roll is on. A one-time toast points at the button when
  the research completes.

Checked in a Studio playtest: unlocked → button visible with OFF; on with stop
at Mythic rolled every ~2.5 s; "Army upgrade" paused on a Mythic Kitsune Spirit
(banner + PAUSED badge) and held it; recruiting it resumed rolling.
