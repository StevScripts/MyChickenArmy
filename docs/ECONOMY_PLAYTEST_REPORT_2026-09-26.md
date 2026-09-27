# Economy and playtest report — September 26, 2026

The free economy works, but I would not sign off on fairness yet. Plot assignments
give players different facilities, and paid income compounds into a substantial
progression and combat advantage. Server performance was reasonable in the tested
load; foreground client and mobile performance remain unverified.

The new **F8 → Studio Test Tools** controls let your main account ignore owned
passes, restore its real passes, or start fresh free, low-spend, cash-pack,
all-pass and all-item profiles. They apply only to disposable Studio sessions.
Fresh presets clear product-funded progress; ignoring passes alone retains the
current test flock and coins. See [test controls](ECONOMY_TEST_TOOLS.md).

## Three-minute live openings

These are scripted sessions in the actual running game, with normal walking,
server-validated purchases, eggs and payouts. They are not averages from human
players. Earned cash excludes starting grants; home income is the potential rate
with the flock at home, before time spent gathering or fighting.

| Fresh profile | Starting cash | Cash earned | Chickens at end | Home cash/sec |
| --- | ---: | ---: | ---: | ---: |
| Free | $2,400 | $3,916 | 6 | $28 |
| Low spend: 2x Egg Spawn | $2,400 | $8,839 | 6 | $70 |
| Small cash pack, no passes | $12,400 | $5,972 | 10 | $55 |
| All eight enabled passes | $2,400 | $18,094 | 8 | $200 |
| All passes + one of each cash pack | $11,112,400 | $245,530 | 29 | $4,992 |
| Casual free, longer gaps between collection | $2,400 | $2,252 | 5 | $24 |

The minimal-spend comparisons cover both a permanent benefit (2x Egg Spawn,
configured base price 199 Robux) and the smallest cash pack (49 Robux). Those are
catalog base prices, not live checkout quotes. No Robux was spent. “All items”
means the eight enabled passes and four cash packs, not disabled crates, Auto
Merge or the retired Finish Processing product. That deliberately extreme start
is not a typical spender forecast.

Every recorded wallet reconciled exactly: starting cash + paid-out earnings −
purchases = ending cash. Pending eggs and ready cash were kept separate. Casual
free ended with $1,880 uncollected, including $1,696 ready on the cash pad; the
lower wallet did not mean those eggs were lost.

The walking driver sometimes waited five seconds for a waypoint closer than the
Humanoid's stopping tolerance. This adds timing noise. The first cash-pack run
also overlapped an accelerated batch; the clean repeat above replaces it.

## Longer progression comparison

Completed **56 one-hour simulations: seven strategies × eight roll seeds**.
These use the actual economy modules with perfect collection every 20 seconds
(60 for casual), three-second rolls, and a fixed reinvestment policy. All start
on the six-podium Plot 1. They abstract walking and exclude combat, camp income,
human mistakes, discovery and attention. All-pass simulations use the allowed
paid-luck distribution; account policy can instead require guaranteed offers.
They are economy comparisons, not King-completion or human session-time predictions.

Median elapsed simulated time (minutes:seconds):

| Profile | 10 chickens | $1m earned | First Rare bought | First Mythic bought |
| --- | ---: | ---: | ---: | ---: |
| Free | 9:22 | 39:21 | 29:14 | 51:24 |
| 2x Egg Spawn | 4:48 | 19:31 | 12:32 | 24:55 |
| Small cash pack | 4:18 | 33:41 | 23:12 | 46:48 |
| All passes | 2:52 | 10:01 | 5:43 | 12:49 |
| All items | 0:19 | 1:41 | 0:07 | 2:02 |
| Casual free | 10:07 | 39:01 | 23:31 | 50:52 |
| Free, merge early | 25:52 | 51:31 | 44:42 | Not within 1h |

Across seeds, free reached $1m earned in **39:01–39:41**; 2x Egg Spawn
in **19:21–19:41**; all passes in **10:01–10:21**. These thresholds exclude
cash-pack grants. A Rare appearing in a roll does not mean the policy could
afford or chose to buy it immediately. These are observed strategy milestones,
not hard progression gates.

The same policy earned a median **$11.3m free**, **$141.9m with 2x Egg Spawn**,
and **$478.6m with all passes** over the hour. Paid progress compounds strongly;
the first-minute multiplier does not describe the eventual gap. Early merging
reduced the median to **$2.0m** and delayed ten chickens from 9:22 to 25:52.

Casual collection produced a similar one-hour result under this particular
policy, despite the weaker live opening. Larger batches change when the policy
buys upgrades versus recruits; that result is not evidence that collecting less
often always helps. Its movement/attention cost is absent from the model.

Raw [simulation results](../assets/economy-playtests-20260926/simulation-results.json)
and [median/range summaries](../assets/economy-playtests-20260926/simulation-summary.json)
retain all checkpoints and seeds. No simulated drop count exceeded 80.

## Additional live tests

**Stationary collection:** after 60 seconds, both free and all-pass wallets had
gained $0. Free had $960 in ground eggs. All passes had an active vacuum and $1,680
ready at the stand, plus cargo and ground eggs. Auto Collect delivers eggs but
does not claim the moving cash pad for an idle avatar. That matches the current
pass description's delivery scope, but it needs to be clear to buyers expecting
AFK cash.

**First camp, same six owned birds:** free deployed three chickens and captured
Cluck Camp in 36.4 seconds, earning $600 from six kills. All passes deployed six
and captured in 20.7 seconds, earning $1,200 from three kills. Avatar travel to
the command was excluded; chicken travel, fighting, respawns and capture were
timed normally. These are individual encounters, not combat averages. The initial
paid attempt hit the normal post-reset camp-clear grace and was excluded; the
accepted, continuously timed repeat is reported here.

**Purchase isolation:** all eight initial live checks and all ten isolated
current-module checks passed, plus the legacy Studio vacuum-bypass check. They
cover pass suppression, restoration, an in-flight ownership-refresh race,
repeatable cash grants, consumable clearing, preserved receipt acknowledgements,
non-Studio/persistent-profile rejection, no serialized override, and blocked
native checkout. Both live test batches had zero DataService profile entries.

## Fairness findings and recommended order

1. **Make plot facilities equivalent before changing prices.** Plot 1 has six
   physical roll podiums; each of Plots 2–6 has one. The physical limit correctly
   prevents extra Roll Slots purchases there. There is only one shared upgrade
   board: about 29 studs from Plot 1's spawn, versus 336–711 from the others. Only
   Plot 1 has the separate collection board; other plots use the deposit as the
   payout fallback. Players therefore face different progression limits and
   collection/travel effort. The authored map was not changed in this task.
2. **Decide the intended paid advantage explicitly.** Egg Spawn × Cash gives
   4× egg income for the same flock, before faster reinvestment and paid luck.
   The all-pass opening earned 4.62× free and finished at 7.14× its home income.
   Bigger Army adds five deployment slots; bounty × cash gives 4× ordinary NPC
   kill rewards. This goes well beyond convenience. It is a stronger fairness
   concern wherever players compete over shared territory.
3. **Make early economic choices legible.** A normal $2,400 Duck producing $4/s
   takes 600 seconds to repay itself before upgrades; the two paid income passes
   reduce that to 150 seconds. The special first recruit costs $600. A player who
   compares only balances can miss these differences and the cost of deploying
   their earners away from home. Cash-pad claims and reinvestment deserve clear
   onboarding.
4. **Explain the approved merge tradeoff.** Three equal chickens become one with
   twice one input's income: combined production falls by one third. This may be
   useful for slots and strength per deployed bird, but repeated early merging
   can slow the farm. Preserve the approved 2× income / 1.25× combat stats; show
   combined before/after output so a new player can make an informed choice.

No prices, cash-upgrade prerequisites, merge multipliers, physical plot limits or
paid rewards were retuned as part of this assessment. All available cash upgrades
remain purchasable from the start when affordable.

## Performance

The server was sampled for 45 seconds with 60 level-10 mixed chickens on one
plot, then 45 seconds with six such profiles: 360 chickens. Five profiles were
test bots, so this is a server population test with one connected client, not
six real clients or a mobile/network certification.

| Load | Mean GameServer.Step CPU | 95th percentile | Maximum | Median heartbeat |
| --- | ---: | ---: | ---: | ---: |
| Early casual free | 0.27 ms | 0.87 ms | 4.13 ms | 16.66 ms |
| 60 chickens | 0.50 ms | 2.55 ms | 5.58 ms | 16.85 ms |
| 360 chickens | 1.31 ms | 6.56 ms | 13.27 ms | 16.63 ms |

The 360-chicken sample had 30,929 Workspace instances. Each plot stayed at 79–80
ground drops despite millions of logical eggs, confirming that stacking bounded
the drop count in this stress case. These update timings leave room within a
16.7 ms server frame on this machine; they do not measure every engine task.

The server profiler points first to world/session updates, pet actors and egg
stepping if optimization becomes necessary. Do not sum nested profiler rows.
Current evidence does not justify a broad performance rewrite.

**Client limitation:** the Mac was locked. Early RenderStepped samples were about
15 FPS, and later stress phases supplied no render samples; Studio reported its
window was not rendering. Those observations cannot establish normal gameplay
FPS. Foreground desktop, actual mobile devices, six-client networking and a long
memory-soak test remain unmeasured. Studio's roughly 6.4–6.6 GB process memory
includes edit, server, client and plugins, so it is not per-player game memory.

## Evidence and delivery

Evidence is in [the test directory](../assets/economy-playtests-20260926/):
[method](../assets/economy-playtests-20260926/METHOD.md),
[first live batch](../assets/economy-playtests-20260926/live-results.json),
[repeat/idle/combat](../assets/economy-playtests-20260926/live-extra-results.json),
[plot audit](../assets/economy-playtests-20260926/plot-audit.json),
[stress timings](../assets/economy-playtests-20260926/stress-results.json),
[preset checks](../assets/economy-playtests-20260926/preset-check-results.json),
and profiler captures. Raw records retain excluded attempts and their limitations.

The five scoped production files compiled in Studio, matched their Rojo sources,
and the scripts-only Rojo build and whitespace check passed. No live-game errors
appeared in the final log window; a third-party plugin HTTP warning remained.
An earlier test-harness attempt used unavailable runtime loadstring and was
replaced with direct test functions; it was not a game failure.

Three pre-existing stale duplicate economy modules were exported and moved intact
into ServerStorage.EconomyPlaytestRecovery20260926; active mapped modules match
the current code. Retain that recovery folder until those copies are no longer
needed. Current code uses instant egg selling; older seller-throughput
documentation does not describe this tested version.

Play is stopped and temporary test bots, method hooks and profiles are discarded.
No real purchases, profile writes, Roblox save/publish, Git commit or push were
performed. The latest F8 visual recheck was blocked by the locked/non-rendering
window; the controls had an earlier visual inspection and the final source was
compiled and exercised through its server actions.
