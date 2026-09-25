# Egg progression feedback

Implemented locally on 25 September 2026. This is the presentation pass from the [approved plan](</Users/stevin/Documents/ChatGPT/My Chicken Army/Cyber/EGG_FEEDBACK_PLAN.md>), not the earlier proposal to convert valuable chickens into additional logical eggs.

## Player-facing changes

Ground eggs retain the approved sprite and bounded physical appearance. Their color now takes a restrained accent from the same rarity palette used in the collection UI. Nearby settled eggs can display `Worth $…`; that text describes the server's pickup value, not money already in the wallet. Three is the maximum number of visible value captions, and overlapping captions are rejected in screen space. Faraway eggs, eggs still settling and eggs flying to a collector have no caption. Caption billboards preserve world occlusion.

A confirmed player pickup group now shows its actual egg count and its worth on separate lines, such as `+3 eggs` / `Worth $120`. Values and counts accumulate independently from the same confirmed receipt stream; one expensive egg remains one egg. The existing combo interval, flight, arrival cue and HUD pulse remain the presentation trigger. Repeated arrivals update the same popup. A direct-credit fallback instead shows the confirmed cash amount, including any prior carried value that the server includes in that receipt. Vacuum receipts continue into the existing vacuum presentation and are excluded from the player's pickup total.

On plots that require a deposit, the HUD now displays `Bag: 3 eggs · Worth $120`, including when the egg seller is enabled. Narrow layouts use two rows. The bag amount is taken directly from `carriedValue` and excludes vacuum cargo, queued eggs and ready cash. This does not claim that bag value has been paid.

A successful recruit acknowledgment includes its identity and its per-bird production potential, for example `Chicken · eggs $4/s at home`. Its existing selection classification is retained on the second line: Reserve, the before/after squad count for Added, or Replacement, with marching or deferred-until-contest context. The amount is a potential while at home, not an assertion that every purchase raises current home income by that amount. A replaced fighter may return to production, while a new fighter may leave it. Very narrow layouts first shorten the optional production wording; if it still cannot fit, they keep the chicken's full identity and assignment instead of clipping them.

Confirmed Egg Value and Egg Speed purchases use one existing notification with the server's before/after display values and a short explanation. The current first speed upgrade without a pass produces `Egg Speed: 2.4s → 2.09s` / `Each chicken lays more often`. The value is an interval per egg, not eggs per second. Egg Value explains that newly laid eggs are worth more; it does not promise an increase to eggs already on the ground. Authored board controls, purchase-button motion and cash-pad interaction are unchanged.

## Ownership and data contract

| Source | Presentation responsibility |
| --- | --- |
| [EggView.luau](../src/client/EggView.luau) | Existing egg sprite, rarity tint/trail color, per-pickup worth caption. |
| [EggController.luau](../src/client/EggController.luau) | Caption budget, confirmed count/value aggregation, one tweened pickup popup and cleanup. |
| [EggFeedback.luau](../src/client/EggFeedback.luau) | Small shared text-budget formatter. No game-state or reward calculations. |
| [HudController.luau](../src/client/HudController.luau) | Bag count/worth wording and responsive two-line fit. |
| [AppController.luau](../src/client/AppController.luau) | Request-correlated production-upgrade confirmation and recruit production wording. |

All displayed earnings originate in existing server snapshots. `EggService` already supplies the previewed payout value in `drop.value`, `carriedValue` and pickup receipt `value`, including any applicable Double Cash entitlement. The client does not multiply these fields again. `PlayerSession` supplies the recruit's `pet.income`, including applicable egg production modifiers. That field is prospective egg value per second while home; it is not seller-limited cash per second. The new presentation does not use a wallet delta to infer a transaction.

`BoardUpgrade` replies contain a request id and action, but no upgrade key. `AppController:Request` captures the existing server offer for Egg Value/Egg Speed under the outgoing id. Only its matching successful result can display the improved-value message. The comparison requires exactly one level of advancement; otherwise the existing server result text is used. Successful reply ids are retained for ten minutes so replayed replies do not repeat the new toast or the existing Income action/burst/card celebration. Unanswered presentation context expires after thirty seconds. Failures retain the existing failure notification. Routine snapshots and initial synchronization do not trigger this acknowledgment.

No server/shared economy source, profile schema, egg quantity, laying cadence, range, pickup cap, price, seller rate, entitlement, combat assignment or offline-cash rule was changed. `CollectionFeel` was left untouched: the live Edit tree contains duplicate identical copies, so this task does not introduce ambiguous tuning there. Existing unrelated uncommitted changes were preserved.

## Text fit and tuning

Whole values use the existing exact comma-separated currency formatting whenever they fit their available text budget. Large values use an explicit approximation marker, for example `Worth ≈$1.2T`, rather than cutting off digits or shrinking text below the existing readable sizes. K/M/B/T/Qa suffixes cover ordinary large displays; unusually long compact strings can use scientific notation with the same approximation marker. Exact receipt totals remain numeric internally. Recruit production keeps one decimal where needed, so a small fractional rate is not silently displayed as the previous whole rate.

| Control | Location | Initial value / unit |
| --- | --- | --- |
| Rarity tint strength | `EggView.RARITY_TINT` | 0.28 blend from white toward the existing rarity color. |
| Ground caption | `EggView.new` | 156 × 26 px, 18 px text, 1.45 studs above the anchor; native maximum distance 36 studs. |
| Nearby caption distance | `EggController.CAPTION_DISTANCE` | 22 studs from the player. This is not collection radius. |
| Caption count / refresh | `CAPTION_LIMIT`, `CAPTION_REFRESH` | Three visible captions, recomputed every 0.15 seconds. |
| Caption separation | `StepCaptions` | Reject pairs closer than 164 px horizontally and 34 px vertically. |
| Pickup group lifetime | `POPUP_HOLD`, `POPUP_FADE` | 0.7 seconds opaque, then 0.4 seconds fading after the latest arrival. |
| Pickup popup movement | `POPUP_OFFSET`, `POPUP_LIFT` | Starts 3.7 studs above the character, lifts by at most 0.5 studs; no lift under reduced motion. |
| Pickup text | `EggController:Start` | 300 × 64 px; count 30 px and worth 21 px. |
| Compact bag text | `HudController:Resize` | Two rows when the available width is below 420 px or in the existing short-touch layout; 44 px high at 18 px text. |

These are presentation defaults, not values measured from the reference game or proven perceptual optima. Changing them cannot alter the server's egg production or balances. The formatter uses the existing theme font and a small outline allowance when measuring text. No new font, palette, asset upload or stud construction was introduced.

## Source review and remaining observation

Manual source review covered:

- Confirmed receipt amounts are counted once within the existing rolling receipt-history window. Reset generations clear views, grouped values and receipt histories. The server retains receipts for three seconds; the client retains handled pickup ids for ten seconds, unchanged from the original implementation.
- Late pickup receipts still follow the existing short visual flight when a view exists; otherwise they use confirmed receipt feedback directly. No visual callback credits money or inventory.
- Repeated popup arrivals preserve accumulated count/value, cancel and destroy superseded native tweens, and disconnect their completion listener before replacement. Teardown cancels tweens before destroying the GUI.
- Character loss or replacement hides the active popup and clears its group. Confirmed receipts without a character do not create an orphan popup; authoritative HUD state remains available on subsequent updates.
- Reduced motion removes the new popup lift. Toggling the preference during a popup reuses the remaining lifetime instead of extending it. Existing mute handling, sound limits, arrival audio, flight/interruption logic and vacuum transfer logic were preserved.
- Rarity captions are hidden immediately on pickup flight. Missing root/camera clears their visibility. Their labels are destroyed with the egg anchor, and value strings are recalculated only when the supplied value changes.
- Upgrade requests consume their own context once; rejected or unmatched requests cannot invent a before/after benefit. A repeated successful Income receipt also suppresses the existing action, card pop and burst in that path.

This pass did not run automated tests, runtime fixtures, a Studio Play session, a visual/perceptual check, a Rojo build, asset uploads, Roblox saving/publishing or player-data operations. Local implementation and manual source review are complete; they do not establish that the motion, readability or sound mix has been observed in gameplay. Studio integration status is recorded separately by the root task in [the team record](team/EGG_PROGRESSION_FEEDBACK.md).

When runtime observation is separately authorized, focus on a dense yard, one expensive egg versus several cheap eggs, short landscape bag text with very large values, mixed player/vacuum pickups, repeated confirmations, character replacement and reduced-motion toggles. Confirm recruit and upgrade text at the narrowest supported layout without changing economy values to manufacture test outcomes.
