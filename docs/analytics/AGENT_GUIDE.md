# My Chicken Army analytics: agent guide

Written for AI agents first. If the user asks "how is the game doing", "where are
we losing players", "is onboarding broken", or anything stats-shaped, start here.
Built October 9, 2026 (schema version 1); version 5 (October 16, 2026) adds feature
funnels, client UI events, server events, real Robux, device/segment profiles and
state snapshots (section 11; plan: `docs/analytics/TRACKING_PLAN.md`). Source of
truth for every name: `src/server/AnalyticsSchema.luau`.

## 1. Fast path: answer a stats question

1. Open Pet Roll Test (place 96683186622050) in Studio, Edit mode, with
   "Enable Studio Access to API Services" on. Use the studio-flow MCP:
   `get_connected_instances`, then `execute_luau` with the snippet in section 3.
2. Pull `Report.Summary({days = 7, env = "live"})`. Read `flags` first, then
   `onboarding` (the 15-step Onboarding funnel, ledger `ob.*`, on Roblox's Onboarding
   dashboard, `docs/analytics/ONBOARDING_FUNNEL.md`; print it with
   `Report.OnboardingText({days = 7, env = "live"})`), `cohorts`, `guideDwell`, `rolls`, `health`.
   Feature drop-offs: `featureFunnels`; menus/buttons/prompts: `ui`; money:
   `robuxActual` and `devices`; who plays: `segments`; stalls: `stateSnapshots`,
   `exits`; save/battle health: `serverEvents` (section 11).
   "Who are our spenders": `Report.Players({env = "live", sortBy = "robux"})` (11.4).
3. For concrete stories, pull `Report.Journeys({day = "YYYY-MM-DD", env = "live",
   onlyOnboarding = true})` and read the `trail` of players who quit early.
4. Compare versions (`summary.versions`, or `Report.Summary({version = "..."})`)
   when a release might have caused a change.
5. Report findings with numbers and sample sizes. Say which flags are heuristics.

No Studio? `tools/analytics/pull_ledger.py` reads the same ledger through Open
Cloud (needs `ROBLOX_OPEN_CLOUD_KEY` with DataStore read access for universe
10765467283) and writes `analytics-data/ledger_<from>_<to>_<env>.json` with a lite summary.

## 2. What is collected, and where

Two outputs, both fed by `src/server/Analytics.luau` (observation only; it never
changes gameplay and every external call is pcall'd):

| Output | Who reads it | Latency | Notes |
|---|---|---|---|
| Roblox AnalyticsService | The user, on the Creator Dashboard | up to ~24h | Live servers only (Studio never sends). Rate-limited per server to 10 + 15×players requests/min (Roblox cap is 120 + 20×CCU per minute, experience-wide). Data rolls off 90 days after the last event. |
| Agent ledger (DataStores) | Agents, via Studio MCP or Open Cloud | ≤ 3 min (flush), plus BindToClose flush | `PetRollAnalytics_v1` (aggregates, journeys, rollups) and `PetRollAnalyticsPlayers_v1` (per-player profile). Studio writes to `*_Studio` twins. |

There is no API to read the Roblox dashboard back, which is why the ledger exists.

### Ledger keys (`PetRollAnalytics_v1`)

- `d/<YYYY-MM-DD>/<shard>`: daily aggregate (UTC day). `{schema, day, v = {[version] = bucket}, updated, writes}`.
  Each server always writes one shard (`hash(JobId) % 16`) every ~180s.
- `j/<YYYY-MM-DD>/<shard>`: sampled journeys `{list = {...}, dropped}`, capped at 60 per key.
- `r/<YYYY-MM-DD>`: rollup the Report writes for finished days (after 01:00 UTC the next day).
  Rebuild a suspicious rollup with `rollups = false`.
- Player store `PetRollAnalyticsPlayers_v1`, key `p/<userId>`: per-player profile (below).

### Bucket shape (one per day per game version)

```
c[name] = number            counters (sums: counts or cash amounts)
h[name][label] = count      histograms; label "leN" = value <= N, "gtN" = above the last edge
m[name] = number            maxima
t[table][key] = count       capped top tables (150 keys, overflow -> "(other)")
x[cohortDay][name] = number counters attributed to a player's first-join UTC day
```

Histogram edges per kind are in `Schema.Buckets` (seconds, ms, ping, fps, cash,
count, memory, days). Percentiles from the Report are upper bounds: `p50 = "le60"`
means the median is at most 60 and above the previous edge.

`name|Platform` suffixes split a metric by device: Desktop, Mobile, Tablet, Console, VR,
Unknown (Unknown = the client report had not arrived, usually under 8 seconds in).

### Per-player profile (`p/<userId>`)

`first` (unix), `firstDay` (only for tracked players), `firstVersion`, `tracked`,
`preexisting`, `lastDay`, `days` (active days), `sessions`, `play` (seconds),
`ob[NN]` (play-seconds when Onboarding funnel step NN was first reached), `obRbx` (last
Onboarding step sent to Roblox; profiles from schema 11-14 also keep the retired `tf`,
`tfSkip` and `tfRbx`, older ones `onb`, `onbMax` and `rbx`), `features[name]` (play-seconds at first use),
`ret[dN]` (retention marks), `purchases`, `robux` (estimate from launch prices),
`firstPurchase`, `lastSeen`. Concurrent writes merge with `Analytics.MergeProfile`.
Version 5 adds (all optional; older profiles lack them): `dev` {platform, tier, vx,
vy, inset, quality, mem, touch, kb, pad, accel, gyro, reducedMotion, locale,
sysLocale, input, os}, `devices[platform]`, `geo`, `age`, `premium`, `followed`,
`friendsInServer`, `joinSource`, `active`, `idle`, `life` (lifetime counters,
`AnalyticsPlayer.LifeKeys`), `snap` (state snapshot at last exit), `lastExit` {menu,
guide, action, idleBefore, seconds, day, coins, stage, at}, `log` (last 10 sessions
{day, hourUTC, s, platform, earned, robux, stage}), `robuxActual`, `robuxEstimate`
(AnalyticsPlayer's launch-price estimate; the v1 `robux` counts the same purchases),
`robuxByKey`, `lastPurchase`, `firstPurchaseDevice`; from AnalyticsFunnels
`fun[F][NN]` (play seconds at first reach), `funN` {buys, fuses, upgrades, levels,
missions, pur} (milestone counters) and `funRbx` {d, s} (Roblox funnel sessions sent).

## 3. Pulling from Studio (copy exactly)

Modules are cached per Studio session, so always load fresh:

```lua
local base, cache = getfenv(0), {}
local function freshRequire(m)
  if typeof(m) ~= "Instance" then return require(m) end
  if cache[m] ~= nil then return cache[m] end
  local fn, err = loadstring(m.Source, m:GetFullName()); assert(fn, err)
  setfenv(fn, setmetatable({script = m, require = freshRequire}, {__index = base}))
  local r = fn(); cache[m] = r; return r
end
local Report = freshRequire(game.ServerStorage.PetRoll.AnalyticsReport)
return Report.SummaryJSON({days = 7, env = "live"})
```

Options: `days` (default 7) or `from`/`to` (UTC `YYYY-MM-DD`), `env` (`"live"` or
`"studio"`), `version` (only that game version), `rollups` (false = always read
shards). Each uncached day costs up to 16 GetAsync calls and the Report waits for
the DataStore budget (~60/min in Edit), so a cold 7-day pull can take ~2 minutes;
finished days are then cached as rollups. The JSON can be large: return selected
fields (as in `docs/analytics/AGENT_GUIDE.md` §8 examples) when the MCP truncates.

`Report.Journeys({day, env, limit = 100, onlyOnboarding})` returns sampled sessions.

Live-server inspection in a Studio playtest: `require(game.ServerStorage.PetRoll.Analytics).Current`
through `eval_server_runtime` (Studio only) exposes `players[userId]` state,
`ledger.pending` and `ledger:Flush()`. `Analytics.Diagnostics` lists the Roblox calls
that would have been sent.

## 4. Onboarding = the Onboarding funnel (schema 15)

Since schema 15 (October 24, 2026) the only onboarding funnel is the 15-step Onboarding
funnel: `Schema.Onboarding`, ledger `ob.*`, Roblox's Onboarding dashboard, session stage
`Ob:<step>` / `Post` / `Untracked`. The step table, the four keys and how to read exits
are in `docs/analytics/ONBOARDING_FUNNEL.md`; read that page, not this one.

Only **tracked** players enter it: first seen by analytics with a fresh game save
(`Analytics.FreshSave`) that carries `introRebirth` (every save since the October 23
empty start). Players who existed before are counted everywhere else, never in the
funnel, cohorts or retention.

Where players quit: `ob.exit.NN` (a session ended with NN the furthest step, until step
15) and the `onboarding` flag, which names the adjacent pair that lost the most players.
`guide.dwell.<step>` (all players) and `guide.enter.<step>` still show how long each guide
step takes overall.

History: the schema 1-8 steps (`onb.*`) stopped recording in schema 12; the schema 11-14
Tutorial funnel (`tf.*`, `tf.exit.NN`, `tf.exitLesson.<id>`, custom event `TutorialExit`,
stage `Tut:<step>`) stopped in schema 15. Days before those versions still hold the old
keys in the ledger; the report does not read them.

## 5. Name dictionary (ledger)

Players and sessions
- `players.joinAttempt`, `players.join` (profile resolved), `players.join.new|returning|tracked`
- `players.unique` (once per player per UTC day), `players.uniqueReturning`, `players.new` (tracked first sight), `players.preexisting`
- `players.sessionIndex` (count hist), `players.daysSinceFirst` (days hist), `players.leftBeforeReady`
- `session.count[.new|.returning]`, `session.count|Platform`, `session.seconds` (counter sum AND seconds hist), `session.seconds.new|returning`, `session.seconds|Platform`
- `server.minutes`, `player.minutes` (sum of players per minute sample), `server.peakPlayers` (max), `server.players` (count hist)

Cohorts and retention (`x[firstDay]`)
- `cohort.size` (tracked new players that day), `ret.dN` for N in 1,2,3,4,5,6,7,14,21,30,60,90 (returned exactly N UTC days later; counted once), `ret.anyLater`, `robux.payer` (per-step cohort keys `tf.NN` / `onb.NN` exist only in days before schema 15)

Onboarding: `ob.reach.NN`, `ob.reach.NN|P`, `ob.t.NN`, `ob.exit.NN` (section 4, `ONBOARDING_FUNNEL.md`). Guide: `intro.started|finished|skipped|notShown`, `ui.<signal>` (Help, Resume, Finish, TreeOpen, ArmyOpen, NodeInspect ...), `load.serverSeconds` (join to save loaded), `load.readySeconds` (join to control).

Actions
- `act.<Action>` (succeeded), `act.<Action>.fail`; `t.reject["<Action> | <message>"]` (top rejection reasons, e.g. "Buy | Not enough cash")
- `feature.use.<Feature>`, `feature.first.<Feature>` (+ seconds hist of play time at first use). Features: Upgrades, Research, Fusion, ChickenLevel, Formations, Operations, Crate, SellChicken, PassToggle, Rally, CallArmy, ShopPrompt, Favorite, Attack, Territory.

Rolls
- `roll.count`, `roll.offer.<Rarity>`, `roll.offer.<Rarity>.affordable` (player could pay at roll time, reserve rules included), `roll.anyAffordable` / `roll.noneAffordable`, `roll.offer.guaranteed`, `roll.buy.<Rarity>`, `roll.rollsPerBuy` (count hist), `roll.perSession`
- Caveat: pass owners (2x Luck) skew rarity mix; there is no pass split yet.

Economy (currency "Cash")
- Sources `econ.src.<eggs|battle|operation|territory|sale|offline|robux|other>` (amount) and `.n` (events), `econ.srcTotal`
- Sinks `econ.sink.<sku>` and `.n`, `econ.sinkTotal`. SKUs: `Recruit:<Rarity>`, `Upgrade:<key>`, `Upgrade:Luck`, `Upgrade:Income`, `ArmySize`, `ChickenLevel`, `Fusion`, `Research`, `EggSeller`, `Operation`, `Other:<action>`
- `econ.balanceAtLeave`, `econ.sessionEarned` (cash hists). Debug credits are ignored.

Camps (main route; `Camp1` = Cluck Camp, `Camp2` Fort Roost, `Camp3` Ironbeak HQ, `King`)
- `camp.<C>.attempt`, `.attemptBeforeWin`, `.firstWin`, `.fail`, `.fail.<Defeated|Draw|Blocked|Retreat>`
- `camp.<C>.odds.<Under1|1To1.3|1.3To2|2Plus>.<firstWin|fail>` (army power / target power at launch)
- `camp.<C>.firstWin.seconds`, `camp.<C>.fail.seconds` (battle duration hists); failures are capped per user per server by BattleService

Robux
- `robux.purchases`, `robux.product.<key>`, `robux.pass.<key>`, `robux.estimate` (sum of launch `proposedPrice`, not actual revenue), `robux.stage.<Tutorial|Post|Untracked>` (`Tutorial` = any `Ob:*` stage since schema 15; `Onboarding` before 12), `robux.firstPurchase` (+ `.playSeconds` hist), `shop.prompt.<key>` (PreparePurchase opened), `crate.open.<Rarity>`

Client, performance, health
- `client.platform.<P>`, `client.screen.<small|medium|large>`, `client.input.<touch|keyboard|gamepad>`
- `perf.fps|P`, `perf.fpsMin|P` (worst 1s window per minute), `perf.memMb|P`, `net.pingMs|P` (Player:GetNetworkPing × 1000)
- `server.frameMs`, `server.frameMaxMs` (per-minute averages/maxima of Heartbeat dt)
- `err.server`, `t["err.server"]["<script>: <message>"]`; `err.client`, `t["err.client"]` (our scripts only)
- `data.loadFail` (+ `t["data.loadFail"]` reasons)
- `analytics.robloxDropped`, `analytics.robloxError`, `analytics.ledgerFlushFail`, `analytics.profileLoadFail`, `analytics.profileSaveFail` (pipeline health; nonzero means numbers may be low)
- `loop.<Event>[.<result>]`, `loop.<Event>.seconds`: LoopTelemetry events (ArmyGrowth, ArmyDeployed, ArmyReturned, RecruitArrived, TerritoryCaptured, TerritoryIncome, TerritoryRetakeStarted, NPCWarning, IncomeContest*)

## 6. Journeys (sampled sessions)

Every session of a tracked player before Onboarding step 15 (Rebirth 1), plus ~5% of
other sessions. Fields: `u` (anonymous hash), `v` version, `p` platform, `n` session
index, `new`, `tr` (tracked), `s` session seconds, `pl` total play seconds, `stage`
(Ob:<furthest Onboarding step id>, Post or Untracked; `Tut:` in schema 11-14 days,
`Onb:` before 12), `st` {NN = session second the Onboarding step was reached}, `ex` guide
step at exit, `mx` furthest Onboarding step, `c` cash at exit, `pe` chickens, `r` rolls, `b` buys, `er` client errors,
`earned`, `rej` (rejections like "Buyx3"), `ping`, `fps`, and `trail`: up to 60
`{second, code}` entries. Codes: `ob:<StepId>` (`tf:` before schema 15), `fun:<Funnel>.<Step>`, `guide:<step>`, an action name
(`Roll`, `Buy`, ... with `!` when rejected), `Camp1:firstWin`, `robux:<key>`,
`guideSkip`, `clientError`.

Read 10-20 trails of players who quit at the top exit step before proposing a fix.

## 7. Roblox Creator Dashboard map (what the user sees)

- Onboarding funnel: the 15 Onboarding steps (`docs/analytics/ONBOARDING_FUNNEL.md`),
  named "NN <label>", field 1 = game version, field 2 = platform, always sent in order
  (a later step of 11-15 sends the missing earlier ones first).
- Recurring funnels: `Roll` (Rolled → AffordableOffer → Recruited; first 30 rolls per
  session), `Shop` (Prompted → Purchased), `Camp` (Deployed → Won, one session id per
  player per camp).
- Progression path `MainRoute`: levels 1-4 (Cluck Camp, Fort Roost, Ironbeak HQ,
  Chicken King); Start on attack before first win, Complete on first win, Fail on loss.
- Economy currency `Cash` (sources batched every 2 min per player; sinks live).
- Version 5 funnels (9 of 10 dashboards with onboarding), sent from feature funnel
  steps through `Schema.RobloxSteps`, one Roblox funnel session per player per funnel
  per UTC day: `Upgrades` (Opened → Inspected → Bought; schema 12, replaces the dead
  `Research` dashboard), `Rebirth` (Eligible → Opened → Rebirthed), `Mission` (Spawned →
  Started → Won), `Daily` (Available → Opened → Claimed). `Fuse` left in schema 9.
- Version 6 `Playtime` funnel (9 of 10 dashboards with onboarding since schema 12): how long one
  session lasts since joining. Steps `10s 20s 30s 40s 50s 1m 2m … 95m`, one Roblox
  funnel session per game session. Roblox caps a funnel at 100 steps, so 96m–100m
  exist only in the ledger (section 12).
- Custom events (35 of 100): TutorialService FTUE* and Conquest* events, plus
  `SessionEnded` (seconds; platform, stage, new/returning), `TutorialExit` (schema 12-14;
  not sent since 15, name kept),
  `FeatureFirstUse`, `RobuxPurchase` (estimate; kind, key, stage), `ScriptError`
  (client), `ClientPerf` (fps; platform, fps bucket, version), `RollSummary`.
  Version 5: `PlayerSegment` (session minutes; device tier, payer state, platform),
  `RobuxSpend` (actual Robux; kind, key, device tier), `MenuDwell` (seconds; menu,
  platform, stage), `FunnelDrop` (furthest step index; funnel, step id, platform;
  sampled), `DeviceProfile` (memory MB; platform, tier, screen class).

## 8. Reading the data well

- Minimum samples: ignore percentages from fewer than ~30 players; say "too early"
  instead. Report counts beside every percentage.
- The onboarding funnel is a day-range funnel: the late steps of a young range are
  still converting, so compare ranges of equal length or split by `version`. Cohort
  rows carry retention only (no per-step cohort keys since schema 15).
- Retention: `ret.dN` / `cohort.size`. A cohort's D7 is only final 8+ days after it.
- Release effects: split by `version`; the version string is `Config.Version`.
- Robux: `robux.estimate` uses launch prices; since version 5 `robux.actual` records
  what was actually spent (before Roblox fees). Payouts are on the dashboard.
- Starting heuristics (not Roblox guarantees): the `onboarding` flag names the adjacent
  step pair that lost the most players (20+ joined; high when it loses 20%+), read its
  `exitsHere` and the journeys of players whose `mx` is the step before it; D1 under 15% on a cohort of 50+ is weak; median FPS
  at or under 30 on a platform needs a perf pass; more than one script error per
  session is a bug hunt. `Report.Flags` implements these and names the numbers.
  Version 5 flags: feature-funnel adjacent conversion under 50% with 30+ players at
  the previous step (medium for steps 2-3, low later: late steps are milestones such
  as Buys50 and are expected to be low); purchase-prompt cancel rate over 70% with
  20+ results; median FPS at or under 30 on a device tier (`perf.fps.tier.<T>`, when
  recorded) or platform; any `sev.data.saveFail`; 50+ dropped/rate-limited UI events
  that are 10%+ of UI events; a menu opened 50+ times (and at least once per two
  sessions) with median dwell in the first bucket (<= 5 s; the seconds buckets cannot
  resolve 3 s), which hints at accidental or confusing opens.
- Example narrow pull when the MCP truncates:
  `local s = Report.Summary({days = 7}); return HttpService:JSONEncode({f = s.flags, onboarding = s.onboarding})`,
  or just `return Report.OnboardingText({days = 7})`.

## 9. Changing the system safely

- Append only: never rename or reorder onboarding steps, funnel steps, counters or
  bucket labels. Add new ones and bump `Schema.Version`; mention it here with a date.
- New Roblox custom event names go in `Schema.CustomEvents` (cap 100; tests check it).
  Funnels: max 10 including onboarding. Economy: up to 20 transaction types, 100 SKUs
  (keep SKU suffixes bounded).
- Everything Analytics does must stay observation-only and pcall-guarded.
- Hooks: `GameServer` (join/load/leave/requests/snapshots/step/shutdown),
  `TutorialService` (Transport, onProgress, onIncome), `ProductService.onGranted`,
  `CommerceService.onPassPurchased`, `LoopTelemetry` sink, client
  `AnalyticsClient` (`ClientReport` request). Scaling knobs: `Schema.Shards`
  (raise, never lower) and `Schema.FlushSeconds`.
- Checks: `tests/AnalyticsChecks.luau` (fake stores, no live calls). The default
  Rojo project does not map tests; run them with the fresh loader by pasting the
  test source into `execute_luau`, or serve `tests.project.json`.

## 10. Verification log

- 2026-10-09: AnalyticsChecks 9/9 plus the onboarding-order check (5/5 rerun after the
  ordering change). Studio playtest: tracked fresh player, platform Desktop from the
  client report, onboarding steps and Roblox calls recorded, manual and BindToClose
  flushes to `PetRollAnalytics_v1_Studio`, `Report.Summary({env = "studio"})` and
  `Report.Journeys` read them back. Roblox AnalyticsService calls were not exercised
  (Studio cannot send them); the Open Cloud puller's request path is untested
  without a key.
- 2026-10-16 (version 5, coordinator): tests/AnalyticsChecks 13/13 in Studio (fresh loader). Studio
  playtest (session-only save, fresh profile): both parts loaded; first ClientReport carried every
  device field (tier High, quality, locale, input); ClientEvents batch reached the server (menu
  open/close + dwell, tab, setting, prompt cancel, click, hint, leaderboard view, load phases;
  a bogus name was dropped client-side); feature funnel steps Upgrades/Research/Shop/Army/
  Settings/Leaderboard recorded; rejected Roll/OpenMerge correctly not counted. Stop -> Leave
  -> BindToClose flush to the _Studio stores; Report.Summary({env = "studio"}) and
  Report.Players({env = "studio"}) read back funnels, ui, exits, segments, snap and lastExit.
  Not exercised: a real Robux receipt or pass purchase (CurrencySpent path), Roblox
  AnalyticsService sends (live servers only), state-derived steps needing progress (the
  test profile was fresh), Open Cloud --players.

## 11. Version 5 (October 16, 2026)

Plan and owners: `docs/analytics/TRACKING_PLAN.md`. Names below are ledger names; all
are append-only and live in `AnalyticsSchema.luau` (`FeatureFunnels`, `ClientEvents`,
`ServerEvents`, `DeviceTiers`, `StateSnapshot`, `Menus`, new bucket kinds `robux`,
`hour`, `accountDays`, `percent`).

### 11.1 New names

Feature funnels (`Schema.FeatureFunnels`, 25 funnels since schema 12: Roll, RollSlots,
AutoRoll, Upgrades, Army, Route, Sell, Index, Shop, Crate, Pass, Rebirth, Mission,
Daily, Offline, Hill, Settings, Leaderboard, and the overhaul's Flock, Vacuum, Feed,
GoldRolls, Mutations, Gems, PlaytimeRewards (section 13); NN = two-digit step index
inside the funnel. Research, Fuse, ChickenLevel and Plot were removed in schema 12)
- `fun.<F>.s.<NN>`: sessions that reached step NN (once per session)
- `fun.<F>.p.<NN>`: players reaching it for the first time ever (profile `fun[F][NN]`)
- `fun.<F>.t.<NN>` (seconds hist): play seconds from the player's first step of that funnel to this step
- `fun.<F>.last.<NN>`: at session end, the furthest step of each funnel touched that session
- `x[firstDay]["fun.<F>.<NN>"]`: cohort view (tracked players)
- Pipeline health: `fun.unknown`, `analytics.funnelError`, `analytics.partError`,
  `analytics.playerError`, `sev.unknown` (any nonzero raises a low `analytics` flag)
- Steps may fire out of order (a Daily claim before the menu-open event arrives), so
  a later step can exceed an earlier one; conversion is adjacent, player-based.

Client UI events (`Schema.ClientEvents`, batched by `AnalyticsClient`, validated server side)
- `ui.menu.open.<Menu>`, `ui.menu.dwell.<Menu>` (seconds hist), `ui.menu.blocked.<Menu>` (Menu from `Schema.Menus`, unknown = `Other`)
- `ui.click` (counter) + top `ui.click` ("<Menu>/<Button>"), top `ui.tab`, top `ui.inspect`
- `ui.prompt.shown` + top `ui.prompt.shown`, `ui.prompt.bought` / `ui.prompt.cancel` + top `ui.prompt.result` ("<key>:<result>")
- `ui.idle.n` + `ui.idle.seconds` hist (idle = no input for `Schema.IdleSeconds`)
- top `ui.setting`, top `ui.hint.shown` / `ui.hint.closed`, `ui.load.<phase>` (seconds hist)
- top `ui.leaderboard.view`, `ui.camera.zoom`, `ui.chat.sent` (count only, never content), `ui.emote`
- `ui.events.dropped`, `ui.events.rateLimited` (validation drops and the per-minute cap)
- Note: the older `ui.<signal>` counters (Help, Resume, TreeOpen ...) share the prefix.

Server events (`Schema.ServerEvents`, `Analytics:ServerEvent`)
- `sev.<name>`, `sev.<name>.<detail>`, value hist `sev.<name>.v`. Names contain dots
  (`data.saveFail`, `battle.end`, `mission.result`), details may too (`won.2`).
  Emitted as of October 16: `sev.offline.shown` / `sev.offline.claimed.auto` (both
  at load), `sev.plot.buildStart|buildDone.<level>`, `sev.research.complete.<node>`,
  `sev.eggs.deposit` (+ value hist), `sev.battle.end.<kind:result>` (Hill fights only,
  + duration hist), `sev.data.saveFail.<capture|lockLost|store_<code>|store>`,
  `sev.data.saveOk`, `sev.remote.throttled.<Action>`, `sev.hill.enter|hold|win|lost`,
  `sev.autoroll.stop.<reason>`, `sev.giant.result.<kind>`, `sev.unknown`.
  In the schema but never emitted (no source yet): `plot.buildSkip`, `merchant.open`;
  `egg.pickup`, `daily.shown` and `mission.result` only appear once a caller sends them.

Robux (real amounts)
- `robux.actual` (sum of Robux actually spent: receipt `CurrencySpent`, pass price at purchase), `robux.actual.n`
- `robux.actual.<kind>.<key>`, `robux.actual|<Platform>`, `robux.actual.tier.<Tier>`, `robux.actual.premium.<yes|no>`
- `robux.payer.tier.<Tier>`, `robux.payer|<Platform>`, top `robux.payer.geo`: counted once per player, at the first purchase
- `robux.purchase` (robux hist of purchase sizes)
- `robux.estimate` and the other version 1 Robux names stay for continuity.

Segments and devices
- `seg.session.tier.<Tier>` (counted at session end, so its total matches `session.count`;
  `Unknown` = no client report), `seg.session.premium.<yes|no>`, top `seg.geo` (region
  code), `seg.age.<bucket>`, `seg.join.<source>`, hists `seg.serverSize` and
  `seg.friendsInServer` (count)
- `seg.payer.session.<payer|non>`; hist `session.hourUTC` (hour buckets), `session.weekday.<0-6>`
  (UTC; expected to follow `os.date("!%w")`, 0 = Sunday: confirm in `AnalyticsPlayer`),
  `session.activeShare` (percent hist),
  `session.activeSeconds` / `session.idleSeconds`
- At the first client report: `client.tier.<Tier>`, top `client.viewport` ("<long>x<short>"),
  top `client.locale`, `client.quality.<n>`, `client.inset.<yes|no>`

State snapshots: hist `state.<name>` at every session end for each `Schema.StateSnapshot`
key (rebirths, eggSpeed, eggValue, luck, rollSlots, plotLevel, armySize, flock,
research, campsWon, missionsWon, coins, power, bestRarity, passes).

Exits: top `exit.menu` (menu open when the session ended, `None` if none) and top
`exit.action` (last action; `Action!` = the last action was rejected).

**Device tier caveat.** Roblox exposes no device model. `Low` / `Mid` / `High` come
from `AnalyticsPlayer.DeviceTier`, a proxy built from viewport size, safe-area insets,
memory in use, frame rate and saved graphics quality; `Unknown` means no client report
arrived. Treat tiers as "cheap vs expensive device" buckets, never as phone models.
The Creator Dashboard splits its own charts by platform, OS and country.

### 11.2 New Summary sections

- `featureFunnels`: list in schema order, each `{funnel, started, steps, worstStep, cohorts}`.
  Step rows `{id, nn, sessions, players, conversionFromPrev (% of previous step's
  players; nil when the previous step had 0), timeP50, timeP90, timeN, lastStepSessions}`.
  `worstStep` = lowest adjacent conversion with 20+ players at the previous step.
  `cohorts` = `[{cohort, size, steps = {NN = players}}]`.
- `ui`: `menus` (sorted by opens: `{menu, opens, blocked, dwellP50, dwellP90, dwellN}`),
  `clicks`, `topClicks` (30), `tabs`, `inspects`, `prompts` {shown, bought, cancel,
  cancelRate = cancel / (bought + cancel), byResult, byKey}, `idle` {n, p50, p90, ended},
  `settings`, `hints` {shown, closed}, `loadPhases` {phase = {p50, p90, n}},
  `leaderboards`, `cameraZoom`, `chatSent`, `emotes`, `events` {dropped, rateLimited}.
- `devices`: `byTier` / `byPlatform` rows `{segment, sessions, payers, revenue, arppu,
  payersPerSessionPct}`, `byPremium`, `sessionsByTier`, `firstReportByTier`,
  `fpsByTier` (only if `perf.fps.tier.<T>` exists), `viewports`, `locales`, `quality`,
  `inset`, `payersByGeo`, `newPayers`, `payerRate` (= new payers / unique players).
- `robuxActual`: `total`, `purchases`, `byKey` (sorted), `byKind`, `purchaseSize`
  (+ `purchaseSizeHist`), `newPayers`, `arppu`, `estimate`, `estimatePurchases`.
- `segments`: `geo` (top 30), `accountAge`, `premium`, `joinSource`, `hourUTC`, `weekday`,
  `serverSize` (+ hist),
  `friendsInServer` (+ hist), `payerSessions`, `activeShare` (+ hist), `activeSeconds`,
  `idleSeconds`, `activePct`, and `all` (every `seg.<group>.<value>` counter by group).
- `stateSnapshots`: `[{name, kind, p50, p90, n, hist}]`.
- `serverEvents`: `{[event] = {count, details = {[detail] = n}, value = {p50, p90, n}}}`.
- `exits`: `{menu, action}` top lists.

Reading Robux well: payers are counted at a player's first purchase, so a range's
`payers` are its new payers while revenue includes repeat buyers. ARPPU over a short
range therefore runs high; for "who pays" use `Report.Players`. `robuxActual.total`
is real spend; the Creator Dashboard's revenue is still the ground truth (after fees).

### 11.3 Example narrow pulls

```lua
local s = Report.Summary({days = 7})
return HttpService:JSONEncode({flags = s.flags, worst = (function()
  local out = {} for _, f in s.featureFunnels do out[f.funnel] = f.worstStep end return out end)(),
  prompts = s.ui.prompts, robux = s.robuxActual, tiers = s.devices.byTier})
```

### 11.4 Report.Players

`Report.Players({env = "live"|"studio", limit = 200, scan?, minRobux?, sortBy = "robux"|"play"|"lastSeen"})`
lists `p/<userId>` profiles from `PetRollAnalyticsPlayers_v1` (Studio: `_Studio`) with
`ListKeysAsync("p/")` and one `GetAsync` per key, waiting for the DataStore budget.
It reads `scan` keys (default `limit`) in key order, sorts them and returns the first
`limit` rows, so with more players than `scan` the list is not a global top list:
raise `scan` (one GetAsync each, ~60/min in Studio Edit) or use the Open Cloud
puller. `minRobux` compares with the larger of `robuxActual` and the estimate.

Row: `{userId, first, lastSeen, days, sessions, play, active, idle, robux (estimate:
max of `robux` and `robuxEstimate`), robuxActual, purchases, lastPurchase,
firstPurchaseDevice, platform, tier, os, input, geo, premium, age, joinSource,
friendsInServer, rebirths, tutorialMax (furthest Tutorial step, schema 12; was onbMax), lastExit, snap, life, funN}`. Result: `{env, sortBy, scanned, listComplete, listError, readFailures, count,
totals = {players, payers, revenue, revenueEstimate, play, payerRate, arppu, byTier,
byPlatform, byGeo}, players}`. `Report.PlayersJSON(options)` returns it encoded.
These rows identify players by UserId only; do not copy them outside our tools.

Open Cloud: `python3 tools/analytics/pull_ledger.py --days 1 --players
[--players-limit 200] [--players-sort robux]` writes `analytics-data/players_<env>.json`
(same row and totals shape). The key then also needs DataStore "list entry keys"
access. Its lite summary also gains `featureFunnels`, `robuxActual`, `devices` and
`uiPrompts`; the funnel step ids are copied in `FEATURE_FUNNELS` and must match the schema.

## 12. Version 6 Playtime funnel (October 20, 2026)

Where players drop off inside one session. `Schema.Playtime` lists 105 checkpoints
counted from PlayerAdded (load time included): every 10 s for the first minute, then
every minute up to 100 minutes. `Analytics:_Playtime` checks them once per second
and on leave. Index NNN is three digits (`001` = 10s, `006` = 1m, `105` = 100m).
- `play.start`: every join
- `play.s.<NNN>`: sessions that reached checkpoint NNN
- `play.last.<NNN>`: sessions whose last checkpoint was NNN (they left before the
  next one); `play.last.000` = left within 10 seconds
- Summary `playtime = {started, endedBeforeFirst, steps, biggestDrop}`; step rows
  `{label, seconds, sessions, ofStarted, fromPrev, endedHere}`; `biggestDrop` is the
  checkpoint with the most sessions ending right after it.
- Narrow pull: `local s = Report.Summary({days = 7}); return HttpService:JSONEncode(s.playtime)`
- Roblox dashboard `Playtime` gets checkpoints 1–100 (10s … 95m).
- `tools/analytics/pull_ledger.py` does not summarize it yet; read the `play.*`
  counters from the raw buckets there.

## 13. Version 12: old funnels removed, overhaul funnels added (October 21, 2026)

Stevin: "go through the existing funnels and get rid of any old ones and replace them
with the new funnels". The new seven-lesson tutorial already had its own funnel
(schema 11, `docs/analytics/TUTORIAL_FUNNEL.md`); schema 12 removes what no longer
matches the game:

| Removed | Why | Replaced by |
|---|---|---|
| `Schema.Onboarding` (`onb.*`, 20 steps), `OnboardingExit`, `guide.skipped` | lessons of the pre-overhaul guide (Grow, Expand, Select, Deploy…); hiding the guide was removed | the Tutorial funnel (`tf.*`, stage `Tut:<step>`, `TutorialExit`), itself replaced by the schema 15 Onboarding funnel (section 15) |
| Feature funnel `Research` and its Roblox dashboard | research merged into the instant Upgrades tree on October 20 | Roblox dashboard `Upgrades` (Opened → Inspected → Bought) |
| Feature funnel `Fuse` | Fuse removed October 20 | — |
| Feature funnel `ChickenLevel` (Army inspector) | levels are bought with Chicken Feed | `Feed` |
| Feature funnel `Plot` (timed builds, Max) | yard builds are instant; Flock is a tree family | `Flock` |

New feature funnels (ledger `fun.<F>.*`, same rules as section 11):

| Funnel | Steps (NN order) | Triggers |
|---|---|---|
| `Flock` | Tier1, Tier4, Tier6, Max | `effects.flockSize` reaches Flock Size I / IV / VI / the top tier |
| `Vacuum` | Owned, CapacityUp, RangeUp | `tools.eggVacuum`; `effects.vacuumCapacity`, `effects.vacuumRange` ≥ 1 |
| `Feed` | Owned, Fed, Fed10, MaxLevelUp | `tools.chickenFeed`; a FeedChicken level (reported as UpgradeChicken); 10 levels ever; `effects.feedMaxLevel` ≥ 1 |
| `GoldRolls` | GoldMachine, GoldRoll, DiamondMachine, DiamondRoll, PrismMachine, PrismRoll | `effects.goldMachine` ≥ 1/2/3; `goldRoll.pull.<Kind>` |
| `Mutations` | Unlocked, Offered, Bought | `effects.mutations` ≥ 1; `mutation.offer.*`; `mutation.buy.*` |
| `Gems` | Earned, Bought, Bought5 | `gems.earned`; `gemUpgrade.buy.*`; 5 Gem Upgrade levels ever (`funN.gemBuys`) |
| `PlaytimeRewards` | Claimed, Tile6, Tile12 | `playtimeReward.claim.<n>` (any, n ≥ 6, n = 12) |

Old days keep their `onb.*` and `fun.Research|Fuse|ChickenLevel|Plot.*` keys in the
ledger; nothing reads them, so compare those days through the raw buckets only.
Verified 2026-10-21 in Studio Edit: `tests/AnalyticsChecks.luau` 16/16 (updated for
schema 12), and a fake session reached every new funnel step with no `fun.unknown` or
`analytics.funnelError`.

## 14. Version 13: empty-start tutorial steps (October 23, 2026)

Stevin's empty start (`docs/team/COMMANDER_TUTORIAL.md`, top): no chickens, 0 Coins, six
cards, tips and a Rebirth 0 at 350 Coins. `Schema.TutorialFunnel` appends four steps (never
renamed or reordered): 25 `StartClaimed` (hard), 26 `PlotExpanded` (hard), 27 `CampTipShown`
(soft, client signal `CampTip`) and 28 `IntroRebirth` (hard). The hard egg steps 05–08 now
land after 09–10 for every new player (the lever comes first), so they show as gap fills.
New launch counter `rebirth0.count`; `RebirthService.RebirthIntro` pays its Gems through
`gems.earned` with source `Rebirth0`. The build label is `Config.Version =
"1.22.0-empty-start"`; compare it with `1.21.1-opening` by `version`. Details:
`docs/analytics/TUTORIAL_FUNNEL.md`. Checks: `tests/AnalyticsChecks.luau` (28 steps).

Version 14 (October 24): step 29 `RolledAgain` (hard, `tutorial.rollCount >= 2`), the
seventh card "Pull the lever again!"; `TutorialComplete` (18) now follows it. 29 steps.
Both are history since version 15 (section 15).

## 15. Version 15: the Onboarding funnel (October 24, 2026)

Stevin: "completely revamp the funnels section for the onboarding especially pls rn the
data is super messy just redo it all for here and record the new data only only go into
detail for a step when it matters I just need to see where players are leaving."
`Schema.Onboarding` (15 hard steps in play order, ledger `ob.*`) replaces the 29-step
Tutorial funnel (schema 11–14, `tf.*`: appended across three redesigns, steps 05–08 firing
after 09–10, soft steps, gap fills, dwell histograms, exit lessons) on Roblox's
Onboarding dashboard and as the session stage (`Ob:<step>` / `Post` / `Untracked`).
Everything about it, including the steps whose drop matters, is in
`docs/analytics/ONBOARDING_FUNNEL.md`.

- Steps: Joined, Loaded, Rolled, ChickenTaken, Egg1, Eggs3, Sold, StartClaimed,
  PlotExpanded, RolledAgain (= tutorial complete), Rebirth0, Chickens3, VacuumBought,
  CluckCampWon, Rebirth1. Each a saved or server fact, once per player ever.
- Keys per step, nothing more: `ob.reach.NN`, `ob.reach.NN|<platform>`, `ob.t.NN`
  (seconds hist from first join), `ob.exit.NN` (a session ended with NN the furthest
  step, `00` = none, until step 15).
- Dropped: dwell, first-session share, gap/skip counters, exit lessons, Roblox gap-fill
  counters, per-step cohort keys and the `TutorialExit` custom event (name kept, not
  sent). `Schema.TutorialFunnel` stays declared (append-only) and is not recorded.
- Tracked: fresh saves (`Analytics.FreshSave`) that carry `introRebirth` (the October 23
  empty start), the first time this version sees them; profile `ob[NN]`, `obRbx`.
- Roblox: the 15 steps strictly in order; when a later step of 11–15 is reached while an
  earlier one is missing, the missing ones are sent at that moment (not counted in the
  ledger).
- Report: `summary.onboarding = {joined, steps[15] {step, id, reached, ofJoined,
  ofPrevious, exitsHere, p50, n}, exitsNone, exitsTotal, biggestDrop}`;
  `Report.OnboardingText(options | summary)` prints it; the `onboarding` flag names the
  biggest drop (20+ joined). `tutorialFunnel`, `tutorialExits`, `tutorialExitLessons` and
  `cohorts[i].steps` are gone; `Report.PlayerRow.onboardingMax` replaces `tutorialMax`;
  `Report.Journeys({onlyOnboarding = true})` matches `Ob:` (and the old prefixes).
- `tools/analytics/pull_ledger.py` still summarizes `tf.*`; read `ob.*` from its raw
  buckets until it is updated.
- Verified 2026-10-24 headless (Lune harness): `tests/AnalyticsChecks.luau` 15/15. Not
  exercised: a Studio playtest or live Roblox sends.

## 16. Version 16: the retention package (October 27, 2026)

Build `1.27.0-retention`; `docs/team/RETENTION_PLAN_20261027.md` section 9 lists every
metric with its 1.25.0 baseline and target. Compare by `version`, new profiles, equal
ranges. New names (all in `AnalyticsSchema.luau`):
- Camps: `camp.CampN.ready` / `.ready.play`, `camp.<step>.firstWin.play` /
  `.firstSession`, `ui.AttackWarned` / `ui.AttackAnyway`; `Summary().camps` and
  `campWarnings`.
- Early economy: `econ.starterRecruit`, `econ.starterSaved`, `econ.buyGap.early|mid`,
  `econ.rate.m5|m10|m20` (bucket `rate`), `econ.buys.m10`.
- Coins prompt: `shop.short.<source>`, `shop.auto.gated.<reason>`, `shop.auto.prompt`,
  `shop.auto.playSeconds`, `shop.<auto|intent>.result.*` / `.quit60`,
  `robux.buy.<key>.playSeconds` / `.auto|.intent`, client `coins.gated`;
  `Summary().coinsPrompt`.
- Rolls: `luckyStart.forced.<Uncommon|Rare><n>`, `luckyStart.bought.*`,
  `luckyStart.guard.shown|rolledPast`, `roll.new.offer|bought`, `index.first.<rarity>`,
  `index.firstSeconds.<rarity>`, Roll funnel steps UncommonOrBetter / Found5 /
  LuckyRareSeen, snapshot `indexFound`.
- After the tutorial: journey `tl` (the last 15 trail entries past the 60-event cap),
  `cv`/`cs` (the card on screen at leave and its seconds), `hr` (HUD reveals);
  `post.card.enter.*`, `post.card.dwell.*`, `post.exit.*`, `post.exit.gap`,
  `post.sessionAfterCore`, `hud.reveal.*`, `hud.firstClick.*`; `Report.PostText`.
- Performance windows: `perf.fpsLoad|<platform>`, `perf.fpsPlay|<platform>` (the old
  `perf.fps|` is unchanged), `perf.fps.perfTier.<tier>`, `perf.tier.<tier>|`,
  `perf.demoted|`, `perf.critical|`, `perf.hitches|`, `perf.focusLost|`,
  `perf.frameMsP90|`, `ui.load.<phase>|<platform>`; journey `fl`/`fp`/`tier`/`fo`/`lr`;
  `Summary().perfTiers` and two Mobile flags.
- Social: server events `social.moment`, `social.visit`, `invite.prompt`; client
  `moment.seen`, `moment.missed`, `invite.sent`; the Social funnel;
  `seg.join.invite|notification`; journey `sv`, `fr`.

