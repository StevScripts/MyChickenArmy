# WS3 — Robux checkout opening on a Coins shortfall

Plan only. No repo file was edited. Data: live 1.25.0, ledger days 2026-10-26 and
2026-10-27 (`raw125.json`, `summary125.json`, `journeys27.json` in `scratchpad/quit/`).
Queries were run with `python3 -I` over those files; the formulas are given beside each number.

---

## 1. Problem and evidence

### 1.1 The auto-prompt is nearly all of the Robux prompts, and almost none of them convert

| Prompt group (summary `ui.prompts.byKey` / `byResult`) | Shown | Bought | Conversion |
|---|---|---|---|
| Coins packs: PocketCoins 2,334 + CoopStash 64 + CommandersVault 24 + ArmyChest (Coin Chest) 7 | 2,429 | 3 (all PocketCoins) | **0.12%** |
| Everything else: RebirthSkip1 8, OuterSpaceCrate1 4, ChickenOffer1 3, ChickenOffer2 3, DoubleCash 1 | 19 | 6 | **32%** |
| All | 2,448 | 9 | 0.37% |

- 2,341 of the 2,448 PreparePurchase calls were PocketCoins (`robux.prompts.PocketCoins`). The Shop
  menu opened only 212 times over both days (`ui.menus` Shop opens), so nearly all Coins-pack prompts
  were the October 23 shortfall auto-prompt, not a player choosing a pack.
- Prompts the player chooses convert about 270 times better than auto-prompts (32% / 0.12%).
- Each prompted player sees **6.6 prompts on average**: 2,456 `feature.use.ShopPrompt` / 373
  `feature.first.ShopPrompt` over both days. On 10-27 it was 1,747 / 290 = 6.0.

### 1.2 The prompts arrive in the steepest part of the drop-off

First prompt, by **lifetime** play seconds (`feature.first.ShopPrompt` histogram, both days summed;
`Analytics:_Feature` uses `_Play`, which is lifetime play):

| Lifetime play at first prompt | Players | Cumulative |
|---|---|---|
| ≤ 3 min | 23 | 6% |
| ≤ 5 min | 142 | 38% |
| ≤ 7.5 min | 280 | **75%** |
| ≤ 10 min | 328 | 88% |
| > 10 min | 45 | 100% (n = 373) |

Survival per minute (summary `playtime.steps[].fromPrev`): minutes 3–10 keep only 84.8–90.5% of
sessions each minute. From minute 10 on, every minute keeps at least 91.5%, and most keep 93–96%.
The auto-prompt lands in minutes 3–7.5, where sessions are being lost fastest.

Why it lands there:
- The current gate is client-only: the tutorial is complete AND
  `passiveEarned + battleEarned ≥ 2,000` (`src/client/CommerceController.luau:13`, `:142-146`).
- New players cross 2,000 lifetime Coins at about minute 3–5. In `journeys27.json`, new sessions of
  180–300 s had a median of 1,894 Coins earned; 87% of new sessions of 300–600 s had ≥ 2,000.
- Rebirth 0 (median first use ≤ 5 min, `feature.first.Rebirth0`) sets Coins to 0
  (`src/server/RebirthService.luau:491`). Straight after it, every podium or Feed tap is a
  shortfall.
- In the seven new-player trails that contain a prompt, the first prompt came at 129, 144, 212, 220,
  221, 294 and 581 s.

### 1.3 Sessions end on the prompt or on a failed buy

`summary.exits.action` is the last action of each of the 1,530 sessions:
- `RefreshShop` was last in **73 sessions (4.8%)**. The client sends RefreshShop when a purchase
  prompt closes (`CommerceController.luau:341`). The only other sender is opening the Shop, and only
  one session ended with the Shop open (`exits.menu` Shop = 1). So these 73 are mostly
  "dismissed a Robux checkout, then left": 73 / 373 prompted players ≈ 20%.
- `Buy!` (a failed podium buy) was last in **86 sessions (5.6%)**.
- Together that is **10.4% of all sessions ending on a Coins-shortfall moment**.

Per event, a prompt is not much more likely to be a session's last action than other actions:
- prompts: 73 / 2,448 = 3.0%;
- successful buys: 259 / 4,253 = 6.1%;
- failed buys: 86 / 3,633 = 2.4%.

So the harm is not one prompt reliably ending the session. It is the dose: 6.6 full-screen modals
per player, during minutes 3–7. The ledger cannot tell us yet how many sessions an auto-prompt
ends. Section 5 adds that measure (`shop.auto.quit60`).

### 1.4 Podium buys fail often and re-trigger the prompt

- `act.Buy` attempts: 7,886. Failures: 3,633 (46%). `act.UpgradeChicken` (Chicken Feed) failures:
  1,341 + 1,849 = 3,190.
- The podium Buy is a server `ProximityPrompt` on E/tap with `HoldDuration` 0
  (`src/server/RollStation.luau:242-244`). The roll lever also uses E, and only the nearest prompt
  shows (comment at `RollStation.luau:292-294`). A player pressing E near the lever and a podium
  gets a Buy, often for a chicken they cannot afford.
- Feed is a client `ProximityPrompt` riding on the nearest chicken, also with `HoldDuration` 0
  (`src/client/ToolController.luau:216-231`). Walking through the yard with Feed equipped and
  pressing E fires a Feed request every press.
- `BuyCoins` refuses only while another checkout is open (`self.pending`,
  `CommerceController.luau:137-139`). It has no cooldown and no session cap. The next failed tap
  after a Cancel opens a new checkout, which fits the 6.6 prompts per player.
- 402 of 847 new-player journeys have `Buy` rejects; 1,817 rejects in total, all inside the first
  three minutes the trails cover.

### 1.5 Who buys (what the data can and cannot say)

- 9 purchases, 754 R$ (`robuxActual`), from 5 first-time payers.
  - Products: PocketCoins 3 × 49 = 147 R$, RebirthSkip1 90, OuterSpaceCrate1 450, ChickenOffer2 49,
    ChickenOffer1 18.
- `robux.stage`:
  - 5 purchases came before Rebirth 1 (bucket "Tutorial" = any `Ob:*` stage).
  - 4 came after Rebirth 1 ("Post"). Only about 62 players reached Rebirth 1 in two days
    (`features` Rebirth firstUses 62), so post-Rebirth-1 players buy far more often per player.
- First purchase, lifetime play seconds (`robux.firstPurchase.playSeconds`):
  ≤ 300 ×2, ≤ 450 ×1, ≤ 600 ×1, ≤ 2,700 ×1.
- Payers: High tier 4, Mid 1; Desktop 2, Tablet 2, Mobile 1; US 3, GB 1, NL 1; 598 of the 754 R$
  from Premium accounts.
- **Gap:** the ledger does not link a product to the play time of its buyer. The three early first
  purchases could be ChickenOffer1 (a 9 R$ HUD offer that new players see) or PocketCoins; the data
  cannot tell them apart. Section 5 adds per-product play-time histograms so the next read answers
  this. A one-off check is possible now: in Studio Edit, read `p/<uid>` analytics profiles
  (`robuxByKey`, `firstPurchase`, `play`, `rebirths`) for payers found by hand, using the
  player-lookup recipe in memory.

**Conclusion:**
- The mechanism suits committed players: post-Rebirth-1 players and returning players with real
  income, whose shortfalls are large and for whom a pack buys meaningful time.
- It does not suit a 4-minute ad player whose wallet Rebirth 0 just emptied, who taps E by
  accident, and who sees a 49 R$ modal six times.

---

## 2. Root cause in code

| Where | What it does now |
|---|---|
| `src/server/PlayerSession.luau:319-327` `CanSpendCash` | Sets `self.coinShortfall` and returns "Not enough coins." |
| `src/server/RollStation.luau` / `src/server/RollService.luau:265` `Buy` | Sets `coinShortfall`; message "Not enough coins. This offer will wait for you." |
| `src/server/ArmyService.luau:160` `UpgradeChicken` (Feed; GameServer reports FeedChicken as UpgradeChicken, `GameServer.luau:394`) | Sets `coinShortfall`. |
| `src/server/ArmyService.luau:220,242` (Army Size / Expand), `src/server/UpgradeService.luau:100,175,201` (tree, legacy board keys) | Use `CanSpendCash`, which sets `coinShortfall`. |
| `src/server/GameServer.luau:216` | Clears `coinShortfall` at the start of each action. |
| `src/server/GameServer.luau:385-387` | Turns any "not enough coins…" failure into reply `needCoins`. **No eligibility check on the server.** |
| `src/server/GameServer.luau:424` | `Send(... needCoins=needCoins)` |
| `src/client/AppController.luau:1052-1057` | Any reply with `needCoins` calls `commerce:BuyCoins`; on false it shows the message as an error toast with the error sound. |
| `src/client/ResearchBrowser.luau:948` (server refusal), `:1241-1243` (red hex pre-check, no server trip) | Call `BuyCoins`. |
| `src/client/UpgradeBoardController.luau:169-174` | World board pre-check calls `BuyCoins`. |
| `src/client/CommerceController.luau:12-13` | `COINS_PROMPT_EARNED = 2000`. |
| `src/client/CommerceController.luau:137-165` `BuyCoins` | Only gate: tutorial `guideCompleted` + 2,000 earned, test session, one prompt at a time. No cooldown, no cap, no minimum shortfall, no play-time or rank condition. Picks the smallest covering pack (`shop.cashPacks`); PocketCoins floor 10,000 Coins for 49 R$ (`ShopCatalog.luau:82`). |
| `src/client/CommerceController.luau:327-343` | Clears `pending` when the checkout closes, so the next shortfall prompts again at once. |
| `src/server/CommerceService.luau:318-358` `PreparePurchase` | Knows nothing about why the purchase was requested (no source). |
| `src/server/RollStation.luau:351-392` | Podium prompt stays enabled and E-instant while unaffordable; ActionText "Buy X · 1,240 Coins" whatever the balance. |
| `src/client/ToolController.luau:262-263` | Feed prompt "Feed · 9,000 Coins" whatever the balance. |

Side note (no change needed): `Analytics.luau:489` and `AnalyticsFunnels.luau:316` call
`CanSpendCash` as a probe, which sets `coinShortfall`. They run after `needCoins` is computed and
the field is cleared at the next action, so this is harmless.

---

## 3. Options and recommended design

Options considered:
- **A. Remove the auto-prompt.** Simplest, but against an owner request. Rejected.
- **B. Keep it and add only a cooldown.** Still prompts 4-minute players. Not enough.
- **C. Raise the earned threshold (2,000 → 50,000).** Earned Coins track ad cohorts badly: Rebirth 0
  pays ×1.5, and missions and offline income spike it. A play-time or rank gate matches the
  survival curve directly. Rejected as the only gate.
- **D (recommended).** A server-owned gate:
  - player qualifies by play time OR rank;
  - small shortfalls skip the prompt;
  - a per-session cap and a cooldown;
  - an inline "You need N more Coins" hint that points at eggs and the green pad whenever the
    prompt is held back;
  - accidental podium/Feed presses made deliberate;
  - one gentle Shop glow per session instead of a prompt for big early shortfalls.

### 3.1 Thresholds (new `Config.CoinsPrompt`)

```lua
-- October 27 (WS3, live 1.25.0 data): the Coins-shortfall checkout is for settled
-- players. docs/team/COINS_SHORTFALL_PROMPT.md "Gate".
CoinsPrompt = {
	Mode = "Gated",                 -- "Gated" | "Legacy" (Oct 23: tutorial + 2,000 earned, no limits) | "Off"
	MinPlaySeconds = 600,           -- 10 minutes of total play (PlayerSession:PlaySeconds) ...
	MinRebirths = 1,                -- ... or Rebirth 1 done
	LegacyEarned = 2000,            -- the October 23 earned gate, kept for Mode "Legacy"
	SessionCap = 2,                 -- auto-prompts per session (runtime only, never saved)
	CooldownSeconds = 600,          -- between auto-prompts, from the moment one opens
	MinShortfallIncomeSeconds = 60, -- no prompt when steady income covers the gap within a minute
	ShopHintIncomeSeconds = 300,    -- held-back shortfall of 5+ minutes of income -> Shop glow (once a session)
},
```

Why these values:
- **10 minutes of play, or Rebirth 1.**
  - Minute 10 is where per-minute survival rises above 91–93% (section 1.2). Prompting earlier hits
    the steep part.
  - It defers 88% of today's first prompts (328 of 373 came before 10 minutes).
  - It still reaches the 21% of sessions that pass 10 minutes, and all returning players: their
    lifetime play is already over 10 minutes after a first visit of that length.
  - Rebirth 1 is the "understood the loop" step, and post-Rebirth-1 players made 4 of the 9
    purchases.
  - `PlaySeconds` is saved lifetime play (counted only since the October 23 builds). Older players
    who undercount almost all have Rebirth 1 or more, so the OR covers them.
  - 15 minutes was considered. It is more conservative, but minutes 10–15 already keep 92–96% a
    minute, and it reaches fewer players. Use 900 as the dial if the 10-minute version still shows a
    high `shop.auto.quit60` (section 5).
- **SessionCap 2, Cooldown 600 s.** Takes the 6.6 prompts per player down to at most 2 per session,
  10 minutes apart: a second offer, never a nag. Counted per session, never saved; no save fields.
- **MinShortfallIncomeSeconds 60.** Offering 10 minutes of income to skip under 60 seconds of eggs
  is poor value and reads as a cash grab. The gap uses `PlayerSession:PackIncome()`, the same steady
  income the packs pay out from.
- **ShopHintIncomeSeconds 300.** Only a gap big enough for a pack to really help earns the one
  gentle Shop glow.

Gate reasons, in the order checked: `Off`, `Test`, `Tutorial`, `New` (fails play/rank), `Cap`,
`Cooldown`, `Small`. The first failing reason is returned, for analytics and the client.

### 3.2 What a held-back player sees (every shortfall path)

- **Toast:** `info` style, so no error sound (the toast stacks "(x2)" on repeats,
  `AppController:Notify`). The copy follows the tutorial's own `earn()` wording
  (`TutorialGuide.luau:226-243`):
  - eggs carried (`state.eggs.carriedValue`) ≥ shortfall: **"You need 1,240 more Coins! Sell your
    eggs on the green pad."**
  - otherwise: **"You need 1,240 more Coins! Collect eggs and sell them on the green pad."**
  - Numbers use `Theme.Money` (grouped); "Coin" when the shortfall is 1.
- **World float (podium and Feed only):** `WorldFeel:Text(position, "Need 1,240", {color =
  Theme.Tones.Short, size = 26, seconds = 1.1})` at the podium top or the fed chicken. It uses the
  shared budget and is reduced-motion aware. One emphasis per event: the toast is the text, the
  float is the place.
- **Upgrades tree / world board:** keep the existing refusal visuals (`Refuse` rim flash and Locked
  cue; board `Reject`) with the new toast copy.
- **Podium prompt, while unaffordable** (server, `RollStation:Step`):
  - ActionText **"Need 1,240 more Coins"**;
  - `HoldDuration = 0.5`, so a stray E press no longer fires a Buy;
  - when affordable: `HoldDuration = 0` and the usual "Buy X · 2,000 Coins".
  - The tutorial's held chicken is affordable by construction, so the tutorial is unaffected.
- **Feed prompt, while unaffordable** (client, `ToolController:UpdateTarget`): ActionText **"Need
  1,240 more Coins"** and `HoldDuration = 0.5`; when affordable, "Feed · 9,000 Coins" with 0.
- **Shop glow** (one per session; gate reason `New`, `Cap` or `Cooldown`; shortfall ≥ 300 s of
  income; HUD Shop button visible, i.e. after the tutorial):
  - the HUD Shop button gets `Theme.Motion:Glow` (gold) and `Bob` for 6 s; reduced motion: Glow
    only; no sound, no text;
  - if the player taps Shop within 20 s, the Shop opens scrolled to Coins
    (`ShopBrowser:ScrollTo("Cash")`).
  - This is the "gentle highlight" alternative to the prompt. It never opens a checkout.

### 3.3 What an eligible player sees

Unchanged from October 23: Roblox's checkout for the smallest covering pack, no menu first. It now
happens at most twice a session, 10 minutes apart, and only when the gap is over a minute of income.

---

## 4. Implementation steps

### 4.1 `src/shared/Config.luau` (shared file: add one top-level key only)
Add the `CoinsPrompt` table from section 3.1 next to `FreeGift`, with its dated comment.

### 4.2 `src/server/CommerceService.luau` (WS3 owns)

1. **`CommerceService:CoinsPromptGate(session, need: number?, now: number): (boolean, string)`**,
   checks in this order:
   - `Mode == "Off"` → `false, "Off"`.
   - `self:TestAllowed(session)` → `"Test"`.
   - `session.tutorial.guideCompleted ~= true` → `"Tutorial"` (same condition as today).
   - `Mode == "Legacy"`: `passiveEarned + battleEarned < LegacyEarned` → `"Tutorial"`, else
     `true, "Legacy"`. No cap, cooldown or Small check.
   - `(session.rebirths or 0) < MinRebirths and session:PlaySeconds() < MinPlaySeconds` → `"New"`.
   - `log = session.coinsPromptLog or {count = 0, readyAt = 0}`, stored lazily on the session
     object. It is runtime only: not added to Serialize/LoadData.
   - `log.count >= SessionCap` → `"Cap"`; `now < log.readyAt` → `"Cooldown"`.
   - `need` given and `need < session:PackIncome() * MinShortfallIncomeSeconds` → `"Small"`.
   - else `true, "Open"`.
   - `now` is `workspace:GetServerTimeNow()`, so the client mirror compares the same clock.
2. **`Snapshot`** adds `coinsPrompt = {eligible = <gate without need>, reason = <reason>, readyAt =
   log.readyAt, income = session:PackIncome(), minShortfallSeconds = cfg.MinShortfallIncomeSeconds,
   hintSeconds = cfg.ShopHintIncomeSeconds}`. This is a mirror for the client's local pre-checks;
   the server stays the authority.
3. **`PreparePurchase(player, session, key, productReady, jobId, source, need)`**: new trailing
   arguments.
   - If `source` is `"Shortfall"`:
     - re-run `CoinsPromptGate(session, need, now)`;
     - only coin packs (`definition.coins and not definition.crates`) may use this source;
     - on refusal, return `false, "Not enough coins."`. The client shows its fallback, the inline
       hint.
     - on success (after every existing check passes), set `log.count += 1` and
       `log.readyAt = now + CooldownSeconds`.
   - Any other or missing source keeps today's path, so Shop and HUD buys are never gated.
   - Clamp `need` to `0..Currency.MaxCoins`.

### 4.3 `src/server/GameServer.luau` (shared file: two small hunks)

1. **Lines 385-387**:
   ```lua
   local shortCoins = if not ok and type(session.coinShortfall)=="number" and type(message)=="string"
       and message:lower():find("^not enough coins") then math.ceil(session.coinShortfall) else nil
   local needCoins, coinsGate = nil, nil
   if shortCoins then
       local open, reason = self.commerce:CoinsPromptGate(session, shortCoins, workspace:GetServerTimeNow())
       coinsGate = reason
       if open then needCoins = shortCoins end
       self.analytics:CoinsShortfall(session, action, reason, shortCoins)
   end
   session.coinShortfall = nil
   ```
2. **Line 424**: also send `shortCoins = shortCoins, coinsGate = coinsGate`. `needCoins` is now
   present only when the server allows a checkout.
3. **Line 264**: pass `request.source` (accept only the string `"Shortfall"`) and
   `tonumber(request.need)` to `commerce:PreparePurchase`.

### 4.4 `src/client/CommerceController.luau` (WS3 owns)

1. Delete `COINS_PROMPT_EARNED`.
2. **`BuyCoins(needed, fallback)`** keeps its signature and false/true contract. Replace the
   tutorial/earned lines with the mirror:
   - read `shop.coinsPrompt`; return false unless `eligible == true`;
   - return false if `workspace:GetServerTimeNow() < readyAt`;
   - return false if `needed < income * minShortfallSeconds`.
   - Keep the `testAllowed`, `pending`, crate and pack checks.
   - Call `Prepare({..., source = "Shortfall", need = needed})`.
3. **`Prepare`**: send `source` and `need` in the PreparePurchase payload when present.
4. **New `Controller:ShortText(short: number): string`** returns the two copy lines from section
   3.2, using `state.eggs.carriedValue`. It lives here, not in the shared `TutorialGuide`, to stay
   out of WS5's file.
5. **New `Controller:HeldBack(short: number, source: string, anchor: Vector3?, reason: string?)`**:
   the single place for the held-back feedback.
   - `self.app:Notify(self:ShortText(short), "info")`.
   - If `anchor`: `self.app.worldFeel:Text(anchor, "Need " .. Theme.Money(short), {...})`.
   - Shop glow, once per session (`self.shopHinted`):
     - only if `reason` is `New`, `Cap` or `Cooldown`, `short >= income * hintSeconds`, and the HUD
       Shop shortcut is visible;
     - call `self.app.hud:HintShop(6)` (WS5 interface);
     - send client event `hint.shown` with detail `"ShopCoins"` (the name already exists).
   - For pre-check paths that never reach the server, send client event `coins.gated` with detail
     `"<source>:<reason>"` (new name, section 5). Server-reply paths are already counted on the
     server.
   - Reason precedence when the client decides alone: `Tutorial` (guide not done), `New`
     (`eligible` false), `Cooldown` (`readyAt`), `Small`.

### 4.5 `src/client/AppController.luau` (shared file: one hunk at lines 1052-1057)

```lua
local coinsOffered = not researchFeedback and not result.ok and type(result.needCoins)=="number"
    and self.commerce:BuyCoins(result.needCoins, result.message)
local heldBack = not researchFeedback and not result.ok and not coinsOffered and type(result.shortCoins)=="number"
if heldBack then
    self.commerce:HeldBack(result.shortCoins, result.action, self:ShortfallAnchor(result), result.coinsGate)
end
-- the existing Notify line also gets `and not heldBack`
```

- `ShortfallAnchor(result)` returns a position for the world float, or nil:
  - Buy: the podium `Top` of `Plot<plotIndex>`'s station whose `RevealedOfferId` matches the
    pending offer, or the nearest of the player's stations;
  - FeedChicken: `self.tools.target.part.Position`.
- The ResearchBrowser path is excluded by `researchFeedback`, as today.
- The existing shake on `CommandButton` failure (line 1092) stays.

### 4.6 `src/client/ResearchBrowser.luau` (WS3 edits two call sites only; flag if WS5 owns the file)
- **`:948`** (server refusal): when `needCoins` is absent but `shortCoins` is present, call
  `Refuse(self.app.commerce:ShortText(result.shortCoins), id)`. The tree keeps its rim flash.
- **`:1241-1243`** (red hex pre-check): when `BuyCoins` returns false and `short > 0`, call
  `self.app.commerce:HeldBack(math.ceil(short), "Tree", nil, <mirror reason>)` and keep
  `Refuse(..)` for the rim flash. To avoid two toasts, `HeldBack` takes an option
  `{silent = true}` so `Refuse` owns the toast, with `ShortText` as its text.

### 4.7 `src/client/UpgradeBoardController.luau`
- **`:171-174`**: on false, call `self:Reject(key)` and
  `self.app.commerce:HeldBack(short, "Board", <board card position or nil>)` instead of the plain
  Notify.

### 4.8 `src/server/RollStation.luau` (shared with WS4 if it touches the podium; one hunk in `Step`)
- In the offer branch (after `local price = …`, line ~376), with `short = price - (self.coins or 0)`:
  - `short > 0 and not self.storageFull` → ActionText `"Need " .. Currency.Grouped(short) .. " more
    Coins"` and `self.buyPrompt.HoldDuration = 0.5`;
  - otherwise → today's text and `HoldDuration = 0`.
- Write properties only on change, as the existing code does.
- `self.coins` is refreshed in `Sync` (`:290`). Check in Studio that `Sync` runs after an egg sale.
  If it does not, the text is briefly stale and harmless, because the server re-checks the real
  balance on Buy.

### 4.9 `src/client/ToolController.luau`
- **`UpdateTarget` (`:262-263`)**: with `short = (pet.upgradePrice or 0) - (state.coins or 0)`:
  - not maxed and `short > 0` → ActionText `"Need " .. Theme.Money(short) .. " more Coins"` and
    `prompt.HoldDuration = 0.5`;
  - else today's text and 0.
- Polling is already throttled (`POLL_SECONDS`).

### 4.10 `src/client/HudController.luau` (WS5 owns HUD staging; WS3 needs one method)
- **`Hud:HintShop(seconds)`**:
  - returns false if `self.shortcuts.Shop` is hidden or `self.quiet`;
  - otherwise `Theme.Motion:Glow(button.Visual, UIColors.Coins, 3)` plus
    `Theme.Motion:Bob(button.Visual, 0.04, 0.8)`, cancelled after `seconds`;
  - sets `self.shopHintUntil = os.clock() + 20`.
- The Shop button's existing click handler checks `shopHintUntil` and, after opening the Shop,
  calls `app.shopBrowser:ScrollTo("Cash")`.
- TweenService through UIMotion only (owner animation rule).

### 4.11 Docs and rules
- **`docs/team/COINS_SHORTFALL_PROMPT.md`**: add a dated "October 27 — Gate" section covering the
  thresholds, the reasons, held-back feedback, the prompt hold, the Shop glow, and the Mode
  rollback.
- **`AGENTS.md`**:
  - edit "Coins shortfall opens a Coins pack (October 23, owner request)" with one dated sentence:
    "Oct 27 (live data: 0.12% conversion, 6.6 prompts per prompted player, 75% before minute 7.5):
    only after 10 minutes of total play or Rebirth 1, at most twice a session, 10 minutes apart,
    never for a gap under a minute of income; otherwise an inline 'You need N more Coins' hint.
    `Config.CoinsPrompt`."
  - In the tutorial bullet, replace "never … before the tutorial is complete and 2,000 Coins were
    earned" with a pointer to the same rule.
  - AGENTS.md is shared: the integrator writes it once for all workstreams.

### 4.12 Save compatibility
No saved fields. `coinsPromptLog` is a runtime field on the session object. The gate reads the
existing `playSeconds`, `rebirths`, `tutorial`, `passiveEarned` and `battleEarned`.

---

## 5. Analytics, success metric, revenue risk

### 5.1 New names (append-only; bump `Schema.Version` once for the whole release, coordinated)

**Ledger counters and histograms:**

| Name | Meaning |
|---|---|
| `shop.short.<source>` | every Coins shortfall: source Buy, UpgradeChicken (Feed), BuyUpgrade, Expand, BoardUpgrade, Tree, Board |
| `shop.auto.gated.<reason>` | held back: Tutorial, New, Cap, Cooldown, Small, Test, Off |
| `shop.auto.prompt` / `shop.auto.prompt.<key>` | PreparePurchase with source Shortfall that succeeded |
| `shop.auto.playSeconds` (hist, seconds) | lifetime play at each auto-prompt |
| `shop.auto.result.bought` / `.cancel` | from the existing `prompt.result` client event, matched to the session's open auto-prompt key |
| `shop.intent.result.bought` / `.cancel` | the same for non-shortfall prompts |
| `shop.auto.quit60` / `shop.intent.quit60` | session ended ≤ 60 s after an auto (or intent) checkout closed with cancel |
| `robux.buy.<key>.playSeconds` (hist) | lifetime play at every purchase of each product; fills the "who bought" gap (section 1.5) |
| `robux.buy.<key>.auto` / `.intent` | whether that purchase followed an auto-prompt |

**Client event (`Schema.ClientEvents`, append):** `["coins.gated"] = "free"`, detail
`"<source>:<reason>"` for local pre-check paths. Server: count `shop.short.<source>` and
`shop.auto.gated.<reason>`, with sources and reasons validated against allowlists.

**Code:**
- `Analytics:CoinsShortfall(session, action, reason, short)`: new; the GameServer hook.
- PreparePurchase branch (`Analytics.luau:462-470`): read `request.source`; record
  `st.autoPrompt = {key = key, at = now}`.
- `prompt.result` (`Analytics.luau:761`): set `st.promptClosed = {auto = bool, at = now,
  cancel = bool}`.
- `Leave` (`Analytics.luau:898`): the quit60 counters.
- `_Purchase` (`:615`): the `robux.buy.*` counters.

**Report:** `AnalyticsReport.Summarize` gets a `coinsPrompt` section listing the above, plus
`autoPerSession = shop.auto.prompt / session.count`.

### 5.2 Targets (read 3 days after publish against the 1.25.0 baseline)

| Metric | 1.25.0 baseline | Target |
|---|---|---|
| Coins-pack prompts per session (`shop.prompt.PocketCoins+CoopStash+…` / `session.count`) | 2,429 / 1,530 = **1.59** | **≤ 0.25** |
| Prompts per prompted player (`feature.use/first.ShopPrompt`) | 6.6 | ≤ 2 |
| Share of first prompts before 10 min (`feature.first.ShopPrompt` hist) | 88% | ≤ 10% (intent buys only) |
| Sessions whose last action is `RefreshShop` (`exits.action`) | 73 / 1,530 = **4.8%** | **≤ 1.5%** |
| Sessions whose last action is `Buy!` | 86 / 1,530 = 5.6% | ≤ 3% (hold on unaffordable podium) |
| `act.Buy.fail / act.Buy` | 46% | ≤ 25% |
| Auto-prompt conversion (`shop.auto.result.bought / shop.auto.prompt`) | ≤ 0.12% | ≥ 1% |
| `shop.auto.quit60 / shop.auto.prompt` vs `shop.intent.quit60 / intent prompts` | n/a | auto ≤ intent + 5 points |
| Survival at 10 / 15 min (`playtime.steps`) | 20.9% / 15.1% | up (confounded with WS1/2/5; read the within-release metrics above first) |

**How to read:** run `AnalyticsReport` from Studio Edit (`docs/analytics/AGENT_GUIDE.md`) for the
new `Config.Version` days. Compare the `coinsPrompt` section, `ui.prompts`, `exits.action`, `robux`
and `robuxActual` with this file's baseline. Shared releases make overall survival a weak signal for
WS3 alone. The quit60 pair and the exit-action shares are WS3's own measure.

A/B was considered and rejected:
- detecting a 3-point move in 10-minute survival (21% → 24%) needs about 3,000 sessions per arm,
  roughly 6 days at the current ~1,100 new players a day;
- revenue cannot be tested with 9 purchases.
- Ship to everyone, and use `Mode` to roll back.

### 5.3 Revenue risk vs retention

- **Worst case:** all 3 PocketCoins purchases (147 R$ in 2 days, **19.5% of 754 R$**) came from
  players under 10 minutes and none comes back through the Shop or the later gated prompt.
  - That loses about 74 R$/day gross, about 52 R$/day after Roblox's 30% (about US$0.18/day at
    DevEx rates).
  - Even losing all 9 purchases would be 754 R$, about US$1.85, over two days.
- **Expected case:** much smaller than that.
  - 4 of 9 purchases were post-Rebirth-1, and those players keep the prompt.
  - Returning players keep it.
  - Intent products (chicken offers, Rebirth Skip, crates, which convert at 32%) are untouched.
  - The Shop stays one tap away and gets a glow for big gaps.
- **Retention side:**
  - 373 players a 2-day window (about 27% of unique players) are pulled out of play 6.6 times each
    during minutes 3–7.5.
  - 10.4% of sessions end on a shortfall moment.
  - Moving 10-minute survival by 1 point on about 1,100 new players a day is 11 more 10-minute
    players a day. Session length and D1 also drive Roblox's discovery for an 81%-ad audience.
- **Break-even guard:** if 3-day `robuxActual.total` falls more than 40% below the 1.25.0 daily rate
  (377 R$/day) AND neither `exits.action` RefreshShop nor 10-minute survival improved, set
  `MinPlaySeconds = 300` (keeping cap and cooldown) and re-read.

---

## 6. Verification

### 6.1 Headless (Lune harness in the scratchpad, per memory "Headless Luau with Lune")

Add `tests/CoinsPromptChecks.luau` (optional suite, `{name, passed, detail}` list). It uses a fake
session with `tutorial.guideCompleted`, `rebirths`, `playSeconds` and `coins`; `PackIncome` stubbed
to 10/s; `TestAllowed` stubbed false. Cases:
1. Tutorial not done → `false, "Tutorial"`.
2. Play 300 s, rebirths 0 → `"New"`; play 600 s → `true, "Open"`; play 0, rebirths 1 → `true`.
3. Two successful `PreparePurchase(... "Shortfall", 5000)` → third gate `"Cap"`; after the first,
   gate at `now + 599` → `"Cooldown"`, at `now + 600` → open.
4. need 500 with income 10/s (600 s of income) → open; need 500 with income 100/s → `"Small"`.
5. `Mode = "Legacy"`: earned 1,999 → `"Tutorial"`; 2,000 → open, with no cap after 5 prompts.
6. `Mode = "Off"` → `"Off"`.
7. `PreparePurchase` with source Shortfall for a non-coin product (`RebirthSkip1`) → refused.
   Without a source → unchanged behaviour.
8. GameServer reply shape: a failing podium Buy with play 0 carries `shortCoins` and
   `coinsGate = "New"` and no `needCoins`. With play 600 it also carries `needCoins`. Use the
   existing `tests/RebirthV2Checks.luau:165` pattern for `coinShortfall`.

Then:
- run the existing `tests/RebirthV2Checks.luau` (it asserts `coinShortfall`);
- run luau-lsp `analyze` on the touched files against a HEAD baseline (memory "Local Luau checks");
- run a Rojo build. The build checks packaging only, not runtime.

### 6.2 Studio playtest script (Solo; test sessions disable real checkouts)

1. Fresh profile ("test as a new player"). Do the tutorial, then Rebirth 0 (Coins → 0).
2. Walk to a podium with an unaffordable chicken.
   - Prompt reads "Need N more Coins" and shows a hold ring; a quick E tap does nothing.
   - Hold it: toast "You need N more Coins! Collect eggs and sell them on the green pad." (info
     colour, no error sound), and "Need N" floats over the podium.
   - `get_runtime_logs` / reply log: `shortCoins = N`, `coinsGate = "New"`, no `needCoins`.
3. Collect eggs worth more than the shortfall without selling, then hold Buy again. The toast now
   reads "…Sell your eggs on the green pad."
4. Sell. The podium prompt switches to "Buy X · P Coins", hold 0; Buy succeeds.
5. Equip Feed; stand by a chicken whose level costs more than the balance. Feed prompt reads "Need N
   more Coins" with a hold; holding gives the same toast and a float on the chicken.
6. Upgrades: tap a red hex. The rim flashes and the toast shows the new copy; no checkout.
   `ui.click` and `coins.gated` (`Tree:New`) reach the ledger (Studio uses `_Studio`).
7. Make the shortfall 5+ minutes of income (Admin: set Coins low and pick an expensive hex). The HUD
   Shop button glows and bobs for 6 s, once per session. Tapping it opens the Shop at the Coins
   section. A second big shortfall: no glow.
8. Raise `playSeconds` to 600 through the Admin/Debug command (or set `MinPlaySeconds = 0` in a
   local Config edit for the test only).
   - Shortfall replies now carry `needCoins`.
   - `BuyCoins` still returns false in the test session, so the fallback (held-back hint) shows.
   - To see the checkout path once, use Studio's own test-purchase flow on a non-test place copy;
     never on the live place.
9. Reduced motion on: the glow stays, the bob is off, and the world float follows WorldFeel's
   reduced-motion rule.
10. Phone emulation (one layout): the toast fits and the prompt text fits the native
    ProximityPrompt.

### 6.3 After publish
Section 5.2 reads at day 1 (sanity: `shop.auto.gated.New` dominates, `shop.auto.prompt` is small and
non-zero) and day 3 (targets).

---

## 7. Risks, owner-rule conflicts, rollback

- **Owner-rule conflict (explicit):** AGENTS.md "Coins shortfall opens a Coins pack (October 23,
  owner request)" says a shortfall "shows no error: Roblox's purchase prompt opens directly".
  - This plan keeps that for settled players (10 min / Rebirth 1, twice a session) and shows an
    inline hint, not an error, to everyone else.
  - Precedent: the tutorial bullet already gates it (tutorial + 2,000 Coins). This makes the gate
    stricter, based on the 1.25.0 data.
  - Recommended decisively, per "just do it".
  - **Compliant alternative**, if Stevin wants the literal rule back: `Mode = "Legacy"`, which is
    exactly October 23. A softer middle is `Mode = "Gated"` with `MinPlaySeconds = 0`, which still
    opens directly after the tutorial but with cap 2, the 10-minute cooldown and the small-gap rule.
- **"Never gate upgrades behind camps"**: unaffected. Nothing is gated; only the Robux prompt timing
  changes.
- **Player-facing words:** "Coins", "green pad", "Need … more Coins"; no "$", no "Tap/Press", no
  "cash". The prompt hold is native and input-agnostic.
- **One UI layout / Scale only:** no new layout. The glow uses the existing button.
- **Game feel:** UIMotion Glow/Bob, the WorldFeel Text budget, one emphasis per event,
  reduced-motion aware. The hold ring is Roblox's own.
- **Risk: the hold on unaffordable prompts feels sluggish.** Only unaffordable presses need the
  hold; affordable ones stay instant. If players complain, drop `HoldDuration` to 0.3.
- **Risk: stale podium text** (`self.coins` refreshed only in `Sync`). Harmless (server re-checks);
  verify in step 6.2-4.
- **Risk: losing the few early PocketCoins buyers.** Bounded at 147 R$ in 2 days (section 5.3);
  measured by `robux.buy.PocketCoins.playSeconds`.
- **Risk: two toasts for one tree refusal.** Handled with the `silent` option (4.6).
- **Rollback:** `Config.CoinsPrompt.Mode` set to `"Legacy"` (exact October 23 behaviour) or `"Off"`
  (inline hints only, never an auto-checkout). The podium/Feed hold is independent and can be
  turned off by setting the hold to 0 in both places; optionally add
  `CoinsPrompt.UnaffordableHoldSeconds = 0.5` so it is one key.

---

## 8. Files touched, interfaces, shared files

**WS3-owned:**
- `src/server/CommerceService.luau`: `CoinsPromptGate`, Snapshot `coinsPrompt`, PreparePurchase
  `source`/`need`.
- `src/client/CommerceController.luau`: gate mirror, `ShortText`, `HeldBack`, `source` in
  `Prepare`, `COINS_PROMPT_EARNED` removed.
- `src/client/UpgradeBoardController.luau`: held-back call.
- `src/client/ToolController.luau`: Feed prompt text and hold.
- `tests/CoinsPromptChecks.luau`: new, optional.
- `docs/team/COINS_SHORTFALL_PROMPT.md`: dated Gate section.

**SHARED (the integrator sequences these; one writer per file):**
- `src/shared/Config.luau`: new top-level `CoinsPrompt` (WS2 likely edits `Economy`; no overlap in
  keys).
- `src/server/GameServer.luau`: needCoins/shortCoins hunk at 385-387, reply at 424, PreparePurchase
  args at 264 (WS1/WS5 may touch other actions).
- `src/client/AppController.luau`: hunk at 1052-1057 plus `ShortfallAnchor` (WS5 likely edits
  render/popup ordering).
- `src/client/ResearchBrowser.luau`: two call sites, 948 and 1241-1243 (WS5 if the tree's tutorial
  or tip copy changes).
- `src/server/RollStation.luau`: podium prompt text and hold in `Step` (WS4 if podium presentation
  changes).
- `src/client/HudController.luau`: new `Hud:HintShop(seconds)` and a Shop-click scroll hook (**WS5
  owns HUD staging**; WS3 needs only this method, which must respect `self.quiet` and the tutorial
  stage).
- `src/server/Analytics.luau`, `src/server/AnalyticsSchema.luau`, `src/server/AnalyticsReport.luau`:
  append-only names, **one `Schema.Version` bump (15 → 16) for the whole release**; every WS adds
  names, so the integrator merges.
- `AGENTS.md`: dated edit of the October 23 section and the tutorial bullet (integrator writes once).

**Interfaces with other workstreams:**
- **WS2 (economy, price cliff):** podium and Feed prices set how often shortfalls happen. WS3's copy
  points to eggs and the pad. If WS2 changes `PackIncome` or the pack floors
  (`ShopCatalog.CashPackAmount`), the `Small` and `ShopHint` thresholds follow automatically,
  because both are in seconds of income.
- **WS5 (post-tutorial flow):**
  - `Hud:HintShop(seconds)` → bool, plus Shop-button visibility after the tutorial.
  - WS3's info toast must not land under a tip card. If WS5 introduces a queue, `HeldBack` uses it.
  - TutorialGuide's `earn()` copy and WS3's `ShortText` must stay worded alike ("Sell your eggs on
    the green pad").
- **WS4 (roll variety):** if WS4 edits `RollStation:Step` labels, merge the Need/hold branch into
  the same block.
- **WS6 (mobile performance):** negligible. Property writes happen only on change, and WorldFeel
  floats are budgeted.
- **WS1 / WS7:** no interface.
