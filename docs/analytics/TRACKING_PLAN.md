# Tracking plan, version 5 (October 16, 2026)

Owner request: track every part of the game so drop-offs and problems are visible from
data, mostly through funnels, plus per-player time played, Robux spent and device.
This plan extends the October 9 system (`docs/analytics/AGENT_GUIDE.md`); all names live
in `src/server/AnalyticsSchema.luau` (version 5). Everything stays observation only:
no gameplay change, every external call pcall-guarded, analytics failures never block a
request.

## 0. Ground rules

- **Privacy.** Key players by UserId only inside our own DataStores (as today). Never
  store names, display names, chat text or anything typed. Country is the Roblox
  region code from `LocalizationService:GetCountryRegionForPlayerAsync`. Account age
  and Premium are bucketed.
- **Device model is not available on Roblox.** We collect proxies that separate cheap
  and expensive devices: viewport size (mobile viewports identify the phone size class),
  safe-area insets (notch / Dynamic Island phones), memory in use, frame rate, saved
  graphics quality, input types and sensors. `AnalyticsPlayer.DeviceTier` turns them into
  Low / Mid / High. The Roblox Creator Dashboard already splits its own charts by
  platform, OS and country.
- **Limits.** Roblox: 10 funnels (we use 9: Onboarding, which carries the 15-step Onboarding funnel since schema 15, plus 8 recurring; schema 12 replaced Research with Upgrades; see ONBOARDING_FUNNEL.md), 100 custom events (35), 3 custom fields,
  8,000 field combinations, 120 + 20×CCU requests/min (budgeted per server). Ledger: top
  tables cap at 150 keys; detail strings are validated and length-capped; per-player
  profile stays small (session log keeps the last 10).
- **Append only.** New names only; bump `Schema.Version`; never rename or reorder.

## 1. What we answer with it

| Question | Where |
|---|---|
| Where do new players quit? | Onboarding funnel + exits (`ob.exit.NN`; schema 15, `docs/analytics/ONBOARDING_FUNNEL.md`), plus `lastExit` per player |
| Which features do players find, use and abandon? | Feature funnels (section 3) |
| Which menus do players open, how long, which buttons? | Client UI events (section 4) |
| Who pays, how much, on what device, from where? | Robux + segments (sections 5, 6) |
| Where in progression do players stall? | State snapshots + lifetime counters (section 7) |
| Is anything broken or slow? | Errors, rejections, saves, perf (section 8) |

## 2. Modules and owners (one writer per file)

| File | Owner | Role |
|---|---|---|
| `src/server/AnalyticsSchema.luau` | coordinator | every name (done first) |
| `src/server/Analytics.luau` | coordinator | integration: calls the two new modules, new public hooks |
| `src/server/AnalyticsFunnels.luau` (new) | worker A | feature funnel engine |
| `src/server/AnalyticsPlayer.luau` (new) | worker B | player profile, device, segments, Robux, snapshots |
| `src/client/AnalyticsClient.luau`, `src/client/AnalyticsUiObserver.luau` (new) | worker C | device report v2, UI observer, prompts, idle, event batching |
| `src/server/GameServer.luau`, `ProductService`, `CommerceService`, `DataService`, `HillService`, `RollService`, `PlotUpgradeService`/its caller, offline cash caller | worker D | server hooks (`ServerEvent`, real Robux) |
| `src/server/AnalyticsReport.luau`, `tools/analytics/pull_ledger.py`, `docs/analytics/AGENT_GUIDE.md`, `tests/AnalyticsChecks.luau` | worker E | reports, player table, docs, checks |

Client UI files (`AppController`, browsers, HUD) are **not** edited: another session is
animating them. The UI observer watches the PlayerGui tree instead (section 4).

## 3. Feature funnels (ledger, all players)

`Schema.FeatureFunnels` lists 22 funnels with their steps and triggers: Roll, RollSlots,
AutoRoll, Upgrades, Army, Route, Sell, Index, Shop, Crate, Pass, Rebirth, Mission, Daily,
Offline, Hill, Settings, Leaderboard, and since schema 12 Flock, Vacuum, Feed, GoldRolls,
Mutations, Gems, PlaytimeRewards (Research, Fuse, ChickenLevel and Plot were removed; see
AGENT_GUIDE.md section 13). For every step:

- `fun.<F>.s.<NN>`: sessions that reached step NN (once per session).
- `fun.<F>.p.<NN>`: players who reached it for the first time ever (profile `fun[F][NN]`).
- `fun.<F>.t.<NN>` (seconds hist): play seconds from the player's first step of that
  funnel to this step (time-to-convert).
- `fun.<F>.last.<NN>`: at session end, the furthest step of each funnel touched that
  session (where the funnel stalls).
- Cohort view: `x[firstDay]["fun.<F>.<NN>"]` for tracked players.
- Roblox dashboards for Upgrades (schema 12, was Research), Rebirth, Mission, Daily (`Schema.RobloxSteps`; Fuse left in schema 9).
- `FunnelDrop` custom event at session end for funnels that started but did not finish
  (sampled to stay in budget).

Steps may fire out of order (for example a Daily claim before the menu-open event
arrives); the ledger records what happened, the report shows adjacent conversion.

## 4. Client UI events

`AnalyticsClient` batches events every 15 seconds (and on idle/leave) into one
`ClientEvents` request; the server validates against `Schema.ClientEvents`.

- `menu.open` / `menu.close` (value = seconds open): every menu in `Schema.Menus`.
  Ledger: `ui.menu.open.<Menu>`, `ui.menu.dwell.<Menu>` hist, `MenuDwell` custom event.
- `ui.click`: every button press as `<Menu>/<ButtonName>` (sanitized; dynamic names
  such as GUIDs become `*`). Ledger counter `ui.click` + top table `ui.click`.
- `tab`, `inspect`: section switches and detail views inside menus.
- `prompt.shown` / `prompt.result`: Roblox purchase dialogs and whether the player
  bought or cancelled (MarketplaceService finished events). Cancels are the biggest
  monetization drop.
- `idle.start` / `idle.end`: no input for 120 s. Gives active vs AFK play time.
- `setting`: settings changed. `hint.shown/closed`: guide cards. `load.phase`: loading
  milestones. `leaderboard.view`, `camera.zoom`, `chat.sent` (count only), `emote`.

The observer finds menus by watching `Visible` on known root Frames under
`PlayerGui.PetRollGui` and buttons via `GuiButton.Activated` on descendants. Renaming a
menu or button changes its label only; gameplay is never affected.

### Ledger names for UI events (coordinator, `Analytics:ClientEvents`)

`ui.menu.open.<Menu>`, `ui.menu.dwell.<Menu>` (seconds hist), `ui.menu.blocked.<Menu>`,
`ui.click` (counter) + top `ui.click`, top `ui.tab`, top `ui.inspect`,
`ui.prompt.shown` + top `ui.prompt.shown`, `ui.prompt.bought` / `ui.prompt.cancel` + top
`ui.prompt.result` ("<key>:<result>"), `ui.idle.n` + `ui.idle.seconds` hist, top
`ui.setting`, top `ui.hint.shown` / `ui.hint.closed`, `ui.load.<phase>` seconds hist,
top `ui.leaderboard.view`, `ui.camera.zoom`, `ui.chat.sent`, `ui.emote`,
`ui.events.dropped`, `ui.events.rateLimited`. Server events: `sev.<name>`,
`sev.<name>.<detail>`, value hist `sev.<name>.v`.

## 5. Robux

- **Real amounts.** Product receipts carry `CurrencySpent`; passes use the price at
  purchase (cached `GetProductInfo`). Ledger `robux.actual` (sum), `robux.actual.n`,
  `robux.actual.<kind>.<key>`, segmented `robux.actual|<Platform>`,
  `robux.actual.tier.<Tier>`, `robux.actual.premium.<yes|no>`; payers
  `robux.payer.tier.<Tier>` / `robux.payer|<Platform>` counted at first purchase.
  The old `robux.estimate` stays for continuity.
- Profile: `robuxActual`, `robuxByKey[key]`, `purchases`, `firstPurchase`,
  `lastPurchase`, `firstPurchaseDevice`.
- Funnels Shop, Crate, Pass and prompt results (section 4).
- `RobuxSpend` custom event with the real amount.

## 6. Player profile and segments (`p/<userId>`, worker B)

Added fields (all optional; old profiles load unchanged):

- `dev`: `{platform, tier, vx, vy, inset, quality, mem, touch, kb, pad, accel, gyro,
  locale, sysLocale, reducedMotion}` from the first client report of the latest
  session; `devices[platform]` = sessions on that platform.
- `geo`: country region code; `age`: account-age bucket; `premium`; `followed`
  (joined by following a friend); `friendsInServer` (max seen); `joinSource`
  (teleport / follow / direct).
- `active`, `idle`: seconds active and AFK (from idle events).
- `life`: lifetime counters: rolls, buys, rareBuys, fuses, giants, chickenLevels,
  upgrades, research, rebirths, missionsWon, campsWon, earned, spent, robux,
  sold, crates; the full list is `AnalyticsPlayer.LifeKeys`.
- `snap`: progression snapshot at last exit (keys of `Schema.StateSnapshot`).
- `lastExit`: `{menu, guide, action, idleBefore, seconds, day, coins, stage}`.
- `log`: last 10 sessions `{day, hourUTC, s, platform, earned, robux, stage}`.
- Segment counters per day: `seg.session.tier.<Tier>`, `seg.session.premium.<yes|no>`,
  `seg.geo.<CC>` (top table), `seg.age.<bucket>`, hist `session.hourUTC`,
  `session.weekday.<0-6>`, `session.activeShare` (percent hist) and
  `seg.payer.session.<payer|non>`. Device at first report: `client.tier.<Tier>`,
  top tables `client.viewport` ("WxH", phones/tablets) and `client.locale`,
  `client.quality.<n>`, `client.inset.<yes|no>`.
- `PlayerSegment` and `DeviceProfile` custom events.

## 7. Progression snapshots

At every session end: `state.<name>` histograms for each `Schema.StateSnapshot` key
(rebirth rank, Egg Speed/Value, Luck, roll slots, plot level, army size, flock, research
count, camps and missions won, cash, power, best rarity owned, passes owned). Stalls show
as a bulge in one bucket together with exits.

## 8. Health

Existing: script errors (server/client), request rejections, load failures, perf, ping.
Added: `sev.data.saveFail` (+reason), `sev.remote.throttled.<Action>`, client
`load.phase` timings, `sev.battle.end.<kind:result>` durations.

## 9. Reports (worker E)

`Report.Summary` gains `featureFunnels` (per funnel: step counts, step-to-step
conversion, median time), `ui` (menus by opens and dwell, top buttons, prompt
cancel rate), `devices` (sessions and payers by tier/platform, viewport classes),
`robuxActual` (revenue, payers, ARPPU by segment), `stateSnapshots`, `serverEvents`.
`Report.Players({limit})` lists profiles (play time, Robux, device, country, last
exit) for "who are our spenders" questions. `pull_ledger.py` gains the same lite
fields. The guide documents every new name.

## 10. Verification

Coordinator runs a Studio solo playtest (session-only save) and drives: menus, roll,
buy, upgrade, research, fuse, shop prompt (Studio test purchase), Daily, then checks
`Analytics.Current` state, a manual `ledger:Flush()` to `PetRollAnalytics_v1_Studio`, and
`Report.Summary({env = "studio"})`. Worker E's checks run with fake stores. Roblox
AnalyticsService calls cannot be exercised in Studio (they appear in
`Analytics.Diagnostics`).
