# Worker D1: 7-day login streak

**Branch:** `launch/d1-daily` · **Worktree:** `~/Documents/Projects/mca-d1` · **Plan:** [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §7
**Needs the foundation?** Yes. Start after the lead commits it.

## Why

1 of 7 new players came back the next day. Offline cash is the only return reason today. A 7-day streak is the cheapest return trigger to add.

## Files you own (only these)

- `src/server/DailyService.luau` (the foundation stub; you replace the body)
- `src/client/DailyRewardController.luau` (the foundation stub; you replace the body)
- `tests/DailyChecks.luau` (new)
- `docs/team/launch/handoff/D1.md` (new)

The foundation already added the saved field `session.daily = {streak, lastDay, best}`, the live field `session.dailyGranted`, the snapshot `state.daily = {streak, lastDay, best, granted}`, the call `DailyService.Check(session, os.time(), server)` after load and every 60 s, and the analytics names `daily.claim.<1..7>`, `daily.streak` and `daily.reset`. **Do not edit `PlayerSession`, `GameServer`, `AppController` or the schema.**

## Server rules (`DailyService.Check(session, now, server)`)

- `today = math.floor(now / 86400)` (a UTC day, server time only).
- If `session.loaded` is false, or the profile isn't writable, return without changes. Copy the guard other transactions use.
- If `session.daily.lastDay == today`: return.
- If `session.daily.lastDay == today - 1`: `streak += 1`. Otherwise `streak = 1`, and record `daily.reset` when the old streak was 2 or more.
- `lastDay = today`; `best = math.max(best, streak)`.
- `slot = ((streak - 1) % 7) + 1`; grant the reward below.
- Set `session.dailyGranted = {slot = slot, streak = streak, cash = amount, rolls = rolls, day = today}` so the client can show it.
- `session:Touch()` and `server.world:UpdateSession(session)`.
- Record `daily.claim.<slot>` and a `daily.streak` histogram value through `server.analytics`.

### Rewards

`income` = cash per second from `session:Income()` passed through `session:EarnedAmount(..., "eggs")` (so 2x Cash and the rebirth multiplier count). Floor it at **$10 per second** so brand-new players still get something useful.

| Slot | Cash | Free lever rolls |
|---|---|---|
| 1 | 5 min of income | 0 |
| 2 | 10 min | 0 |
| 3 | 0 | 1 |
| 4 | 20 min | 0 |
| 5 | 30 min | 0 |
| 6 | 0 | 2 |
| 7 | 60 min | 3 |

- Cash: add with the existing earn path that respects the coin cap (look for how `PlayerSession` credits coins with a headroom check, around lines 375 to 382). Never exceed `CurrencyLimits.MaxCoins`. Analytics should count it as an economy source; use the closest existing source name, or `other`.
- Free rolls: `session.hillRollCredits += rolls`. `HillService` (line 117) already turns these into recruits when the flock has room. Read it to confirm.
- Never grant Galaxy Crate credits. They're a paid random item with disclosed odds.

Keep the reward table at the top of `DailyService` as a constant so it's easy to tune.

## Client (`DailyRewardController.luau`)

- `:Render(state)`: when `state.daily.granted` holds a day you haven't shown yet (track the last shown `day` locally), show the popup.
- **Wait for the offline receipt.** If `OfflineCashController` is showing its receipt, wait until it closes. Read how it exposes that; if it doesn't, wait about 1.5 s after the receipt is gone, and write a request for the lead if you need a proper hook.
- **Popup:** the same frame style as the offline receipt. Title "Day 3 streak!". A row of 7 day tiles, with done days ticked, today highlighted and future days dim; each tile shows its reward ("5 min cash", "1 roll"). Below the tiles, today's reward in large text ("+$1.2M" or "+1 free roll"). One button, "Collect". The server has already granted the reward, so the button only closes the popup and plays the existing cash or pop effect.
- **October 14 redesign (owner reference image, a Roblox "Daily Rewards" card grid):** header "Daily Rewards"; Days 1–6 as two rows of three studded cards and a tall rainbow Day 7 card ("Insane!") on the right. Cash days are orange/blue, roll days purple. Each card: "Day N", reward art over rays, the reward ("+$X" in green, "+N Free Rolls" in gold; today shows the granted cash, other days estimate minutes × the HUD income), and a status: earlier days are dimmed with a green check and CLAIMED, today has a green "Collect!" (closes, as before), tomorrow shows a live countdown to the next UTC day, later days say "Not Ready". Today's card breathes unless reduced motion is on. This replaces the single row, the big amount line and the separate Collect button.
- **Phone layout:** at 375 wide, the 7 tiles fit in one row (shrink them) or wrap into two rows of 4 and 3.
- Reduced motion: no tile bounce.

## Tests (`tests/DailyChecks.luau`)

Use fixed `now` values (no real clock):

1. First ever check: streak 1, slot 1, cash granted.
2. A second check the same day grants nothing.
3. The next day: streak 2. Skipping a day resets to 1 and records `daily.reset`.
4. Day 8 grants slot 1 again; `best` keeps 8.
5. Slot 3 adds 1 to `hillRollCredits`; slot 7 adds 3 rolls plus cash.
6. Cash scales with income, uses the $10 per second floor, and never exceeds the cap.
7. An unloaded or closing session is untouched.

## How the lead verifies

Run `DailyChecks` and `FoundationChecks`. Then playtest: set the test session's `daily.lastDay` to yesterday, rejoin, and confirm the popup appears after the offline receipt with the right reward, and that coins rose by that amount.

## Handoff

Commit on your branch and write `docs/team/launch/handoff/D1.md`: files changed, the tests, the verify steps, and any request for the lead.
