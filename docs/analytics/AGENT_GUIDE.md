# My Chicken Army analytics: agent guide

Written for AI agents first. If the user asks "how is the game doing", "where are
we losing players", "is onboarding broken", or anything stats-shaped, start here.
Built October 9, 2026 (schema version 1). Source of truth for every name:
`src/server/AnalyticsSchema.luau`.

## 1. Fast path: answer a stats question

1. Open Pet Roll Test (place 96683186622050) in Studio, Edit mode, with
   "Enable Studio Access to API Services" on. Use the studio-flow MCP:
   `get_connected_instances`, then `execute_luau` with the snippet in section 3.
2. Pull `Report.Summary({days = 7, env = "live"})`. Read `flags` first, then
   `onboardingFunnel`, `onboardingExits`, `cohorts`, `guideDwell`, `rolls`, `health`.
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
`onb[NN]` (play-seconds when step NN was first reached), `onbMax`, `rbx` (last
onboarding step sent to Roblox), `features[name]` (play-seconds at first use),
`ret[dN]` (retention marks), `purchases`, `robux` (estimate from launch prices),
`firstPurchase`, `lastSeen`. Concurrent writes merge with `Analytics.MergeProfile`.

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

## 4. Onboarding funnel

Only **tracked** players enter it: first seen by analytics with a fresh game save
(`starterArmy`, guide never started, no rolls/buys, no camp wins). Players who
existed before analytics launched are `preexisting`: counted everywhere else, never
in the funnel, cohorts or retention.

| NN | Step | Recorded when |
|---|---|---|
| 01 | Joined | PlayerAdded on a server |
| 02 | ProfileLoaded | Game save loaded (or Studio session ready) |
| 03 | IntroStarted | Client began the first-visit film (optional) |
| 04 | IntroEnded | Film finished/skipped, or client reported no film |
| 05 | ControlReady | Loading veil gone, player has control (TutorialSignal Ready) |
| 06 | FirstEgg | First egg picked up |
| 07 | Collect | Guide egg goal (40) reached |
| 08 | Sell | First egg deposit |
| 09 | Roll | First lever pull |
| 10 | Recruit | First recruit bought |
| 11 | Grow | Owns 4+ chickens |
| 12 | Expand | Army size 4+ |
| 13 | Select | 4+ chickens selected |
| 14 | Deploy | Army sent to a camp |
| 15 | Win | First camp captured |
| 16 | GuideComplete | Commander guide complete |
| 17 | Camp2 | Fort Roost first win |
| 18 | Camp3 | Ironbeak HQ first win |
| 19 | King | Chicken King first clear |

Rules that matter when reading it:

- A step counts once per player, ever (`profile.onb`), on the UTC day it happened.
  `onb.reach.NN` is "reached that day"; `x[cohortDay]["onb.NN"]` is the cohort view
  (of players who first joined on cohortDay, how many ever reached NN). Prefer the
  cohort view for conversion; the daily view mixes cohorts.
- The ledger records the real order. `onb.outOfOrder.NN` counts steps reached before
  their predecessor. Known cause: the BiggerArmy pass starts players at army size
  4+, so `12 Expand` fires in seconds for pass owners.
- Roblox auto-completes every earlier step when a later one is logged, so Analytics
  sends Roblox steps strictly in order. A missing step is passed over only if it is
  optional (03) and a later step happened, or after 3 later steps
  (`onb.robloxGapFill.NN`). The Roblox dashboard funnel is therefore canonical-order;
  the ledger is truth.
- `onb.t.NN` (seconds histogram) = cumulative play time since first join at the
  moment NN was reached. `onb.session.NN` = which session number it happened in.

### Where players quit

At session end, a tracked player who has not completed the guide records:
- `onb.exit.<guideStep>`: the Commander guide step on screen when they left
  (`TutorialGuide.Resolve` ids: Collect, Sell, Roll, Recruit, Grow, Expand, Select,
  Deploy, Win, RecoverCollect, RecoverSell, Complete, Skipped, None).
- `onb.exitFirstSession.<guideStep>`: same, first session only (the real FTUE loss).
- `onb.exitMax.NN`: furthest funnel step reached.
- `onb.exitDwell.<guideStep>` (seconds): how long they had been on that step.
- Roblox custom event `OnboardingExit` (value dwell; fields: guide step, MaxNN, S1/S2/S3+).

`guide.dwell.<step>` (all players) and `guide.enter.<step>` show how long each guide
step takes overall. A step with high dwell **and** a high share of exits is the
first suspect.

## 5. Name dictionary (ledger)

Players and sessions
- `players.joinAttempt`, `players.join` (profile resolved), `players.join.new|returning|tracked`
- `players.unique` (once per player per UTC day), `players.uniqueReturning`, `players.new` (tracked first sight), `players.preexisting`
- `players.sessionIndex` (count hist), `players.daysSinceFirst` (days hist), `players.leftBeforeReady`
- `session.count[.new|.returning]`, `session.count|Platform`, `session.seconds` (counter sum AND seconds hist), `session.seconds.new|returning`, `session.seconds|Platform`
- `server.minutes`, `player.minutes` (sum of players per minute sample), `server.peakPlayers` (max), `server.players` (count hist)

Cohorts and retention (`x[firstDay]`)
- `cohort.size` (tracked new players that day), `ret.dN` for N in 1,2,3,4,5,6,7,14,21,30,60,90 (returned exactly N UTC days later; counted once), `ret.anyLater`, `robux.payer`, `onb.NN`

Onboarding and guide: see section 4. Also `intro.started|finished|skipped|notShown`, `guide.skipped`, `ui.<signal>` (Help, Resume, Finish, TreeOpen, ArmyOpen, NodeInspect ...), `load.serverSeconds` (join to save loaded), `load.readySeconds` (join to control).

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
- `robux.purchases`, `robux.product.<key>`, `robux.pass.<key>`, `robux.estimate` (sum of launch `proposedPrice`, not actual revenue), `robux.stage.<Onboarding|Post|Untracked>`, `robux.firstPurchase` (+ `.playSeconds` hist), `shop.prompt.<key>` (PreparePurchase opened), `crate.open.<Rarity>`

Client, performance, health
- `client.platform.<P>`, `client.screen.<small|medium|large>`, `client.input.<touch|keyboard|gamepad>`
- `perf.fps|P`, `perf.fpsMin|P` (worst 1s window per minute), `perf.memMb|P`, `net.pingMs|P` (Player:GetNetworkPing × 1000)
- `server.frameMs`, `server.frameMaxMs` (per-minute averages/maxima of Heartbeat dt)
- `err.server`, `t["err.server"]["<script>: <message>"]`; `err.client`, `t["err.client"]` (our scripts only)
- `data.loadFail` (+ `t["data.loadFail"]` reasons)
- `analytics.robloxDropped`, `analytics.robloxError`, `analytics.ledgerFlushFail`, `analytics.profileLoadFail`, `analytics.profileSaveFail` (pipeline health; nonzero means numbers may be low)
- `loop.<Event>[.<result>]`, `loop.<Event>.seconds`: LoopTelemetry events (ArmyGrowth, ArmyDeployed, ArmyReturned, RecruitArrived, TerritoryCaptured, TerritoryIncome, TerritoryRetakeStarted, NPCWarning, IncomeContest*)

## 6. Journeys (sampled sessions)

Every session of a tracked player still in onboarding, plus ~5% of other sessions.
Fields: `u` (anonymous hash), `v` version, `p` platform, `n` session index, `new`, `tr`
(tracked), `s` session seconds, `pl` total play seconds, `stage` (Onb:<max step> or
Post/Untracked), `st` {NN = session second reached}, `ex` guide step at exit, `mx`
max step, `c` cash at exit, `pe` chickens, `r` rolls, `b` buys, `er` client errors,
`earned`, `rej` (rejections like "Buyx3"), `ping`, `fps`, and `trail`: up to 60
`{second, code}` entries. Codes: `onb:<Step>`, `guide:<step>`, an action name
(`Roll`, `Buy`, ... with `!` when rejected), `Camp1:firstWin`, `robux:<key>`,
`guideSkip`, `clientError`.

Read 10-20 trails of players who quit at the top exit step before proposing a fix.

## 7. Roblox Creator Dashboard map (what the user sees)

- Onboarding funnel: the 19 steps above, named "NN Step", field 1 = game version.
- Recurring funnels: `Roll` (Rolled → AffordableOffer → Recruited; first 30 rolls per
  session), `Shop` (Prompted → Purchased), `Camp` (Deployed → Won, one session id per
  player per camp).
- Progression path `MainRoute`: levels 1-4 (Cluck Camp, Fort Roost, Ironbeak HQ,
  Chicken King); Start on attack before first win, Complete on first win, Fail on loss.
- Economy currency `Cash` (sources batched every 2 min per player; sinks live).
- Custom events (30 of 100): TutorialService FTUE* and Conquest* events, plus
  `SessionEnded` (seconds; platform, stage, new/returning), `OnboardingExit`,
  `FeatureFirstUse`, `RobuxPurchase` (estimate; kind, key, stage), `ScriptError`
  (client), `ClientPerf` (fps; platform, fps bucket, version), `RollSummary`.

## 8. Reading the data well

- Minimum samples: ignore percentages from fewer than ~30 players; say "too early"
  instead. Report counts beside every percentage.
- Day funnel vs cohort funnel: use cohorts (`summary.cohorts[i].steps`) for
  conversion; a young cohort is still converting, so compare cohorts of equal age.
- Retention: `ret.dN` / `cohort.size`. A cohort's D7 is only final 8+ days after it.
- Release effects: split by `version`; the version string is `Config.Version`.
- Robux: `robux.estimate` uses launch prices; real revenue is on the dashboard.
- Starting heuristics (not Roblox guarantees): early adjacent step conversion below
  80% (steps 02-09) is worth a look; one guide step holding 30%+ of onboarding
  exits is the first suspect; D1 under 15% on a cohort of 50+ is weak; median FPS
  at or under 30 on a platform needs a perf pass; more than one script error per
  session is a bug hunt. `Report.Flags` implements these and names the numbers.
- Example narrow pull when the MCP truncates:
  `local s = Report.Summary({days = 7}); return HttpService:JSONEncode({f = s.flags, funnel = s.onboardingFunnel, exits = s.onboardingExits})`

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
