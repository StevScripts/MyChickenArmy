# Coins shortfall: Coins-pack checkout, gated (October 23, gated October 27, 2026)

October 23 owner request (Stevin): when a player can't afford something with Coins, don't
show an error. Open Roblox's purchase prompt for the closest Coins pack straight away, with
no game menu before it.

October 27 (retention package WS3, `docs/team/retention-20261027/WS3-coins-shortfall-prompt.md`,
live 1.25.0 data): that checkout is now for settled players only. Everyone else gets an
inline "You need N more Coins" hint. Switch back with `Config.CoinsPrompt.Mode = "Legacy"`.

## Why it is gated (October 27)

- 2,429 Coins-pack checkouts in two days, 3 bought (0.12%). Prompts a player chose
  converted at 32%.
- A prompted player saw 6.6 checkouts on average, 75% of first ones before minute 7.5 of
  play, where sessions are lost fastest (minutes 3–10 keep 85–90% a minute).
- 4.8% of sessions ended right after closing a checkout (`exits.action` RefreshShop), 5.6%
  on a failed podium Buy. Podium and Feed prompts fired on a stray E press (the lever also
  uses E).

## Gate

Server-owned: `CommerceService:CoinsPromptGate(session, need, now)`, with
`Config.CoinsPrompt`. The checks, in order; the first one that fails is the reason:

| Reason | Held back when |
|---|---|
| `Off` | `Mode = "Off"` (inline hints only, never a checkout) |
| `Tutorial` | the tutorial is not complete (Legacy: also under `LegacyEarned` 2,000 Coins earned) |
| `New` | under `MinPlaySeconds` (600) of lifetime play (`PlayerSession:PlaySeconds`) **and** no Rebirth 1 (`MinRebirths`) |
| `Cap` | `SessionCap` (2) auto-checkouts already opened this session |
| `Cooldown` | under `CooldownSeconds` (600) since the last one opened |
| `Small` | the gap is under `MinShortfallIncomeSeconds` (60) of steady income (`PlayerSession:PackIncome`, what packs pay from) |
| `Test` | a test session (Studio or "test as a new player"); checked last so Studio shows the real reason |

Otherwise `Open` (Legacy: `Legacy`, which skips New, Cap, Cooldown and Small: the exact
October 23 rule). The count and cooldown live in `session.coinsPromptLog`, a runtime field
of the session object, never saved. The clock is `workspace:GetServerTimeNow()`.

The client adds its own holds (`CommerceController:CoinsGate`): `Pending` (a purchase or
crate already open), `Busy` (`app:ModalBusy()` outside the Upgrades tree and the board, or
`app:BeatBusy()`), `Invite` (a friend invite in the last 60 s, `FriendBoost.lastInviteAt`).

## Which pack

Unchanged since October 23: the smallest Coins pack whose current payout
(`state.shop.cashPacks`, the same minutes-of-income amounts the Shop shows) covers the
missing Coins; when none does, the biggest. Only packs on sale
(`ShopCatalog.ProductOnSale`) count. The purchase goes through `PreparePurchase` and
`ProcessReceipt`; buying the pack does not buy the item.

## Flow

- **Server refusals.** `PlayerSession:CanSpendCash`, `RollService:Buy` (podium chicken)
  and `ArmyService.UpgradeChicken` (Chicken Feed) record `session.coinShortfall`. When the
  action fails with "Not enough coins…", `GameServer` replies with `shortCoins` (always),
  `coinsGate` (the gate's reason) and `needCoins` (only when the gate opens). That covers
  the Upgrades tree, Army Size, podium buys and Feed.
- **Client pre-checks.** The Upgrades tree's red hexes and the world upgrade board decide
  locally from the mirror `state.shop.coinsPrompt` (`eligible`, `reason`, `readyAt`,
  `income`, `minShortfallSeconds`, `hintSeconds`).
- **Checkout.** `CommerceController:BuyCoins(needed, fallback, source)` sends
  `PreparePurchase` with `source = "Shortfall"` and `need`. The server runs the gate
  again, allows only Coins packs (not crates or passes) for that source, and on success
  counts the checkout toward the cap and cooldown. The Shop, HUD offers and every other
  buy send no source and are never gated.

## What a held-back player sees

`CommerceController:HeldBack(short, source, anchor, reason, options)`:
- an **info toast** (no error sound), worded like the tutorial's `earn()` step:
  "You need 1,240 more Coins! Collect eggs and sell them on the green pad." or, when the
  eggs carried already cover it, "You need 1,240 more Coins! Sell your eggs on the green
  pad." (`CommerceController:ShortText`);
- a red **"Need 1,240"** float (`WorldFeel:Text`) over the podium or the fed chicken;
- **once a session**, when the reason is New, Cap or Cooldown and the gap is
  `ShopHintIncomeSeconds` (300) of income or more, the HUD Shop button glows
  (`Hud:HintShop(6)`, WS5; false while the Shop button is hidden). Never a checkout.

The Upgrades tree keeps its refusal (rim flash, Locked cue) with the same words; the board
keeps its card reject. If the server refuses an auto-checkout after all, the hint shows.

**Prompts while unaffordable.** The Feed prompt (`ToolController:UpdateTarget`) reads
"Need 1,240 more Coins" with a 0.5 s hold (`CoinsPrompt.UnaffordableHoldSeconds`, default
0.5 when the key is absent); affordable it reads "Feed · 9,000 Coins" and fires at once. The
podium Buy prompt does the same in `RollStation:Step` (applied by WS4).

## Analytics (schema 16)

Ledger: `shop.short.<source>` (Buy, UpgradeChicken, BuyUpgrade, Expand, BoardUpgrade,
Tree, Board), `shop.auto.gated.<reason>`, `shop.auto.prompt[.<key>]`,
`shop.auto.playSeconds` (lifetime play at each auto-checkout), `shop.<auto|intent>.result.
<bought|cancel>`, `shop.<auto|intent>.quit60` (session ended within 60 s of cancelling),
`robux.buy.<key>.playSeconds` and `robux.buy.<key>.<auto|intent>`. Client event
`coins.gated` ("<source>:<reason>") for decisions the client made alone. Report:
`AnalyticsReport.Summarize(...).coinsPrompt`. Targets: pack checkouts per session 1.59 →
≤ 0.25; sessions ending on a closed checkout 4.8% → ≤ 1.5%; failed podium Buys 46% → ≤ 25%.
Break-even guard: if Robux a day falls over 40% without a retention gain, set
`MinPlaySeconds = 300`.

## Rollback

`Config.CoinsPrompt.Mode`: `"Legacy"` is exactly October 23 (tutorial + 2,000 Coins earned,
no cap or cooldown); `"Off"` never opens an automatic checkout. Gems purchases and Rebirth
are unchanged.

Checks: `tests/CoinsPromptChecks.luau` (headless: `tools/sim` `runsuite.luau CoinsPromptChecks`).
