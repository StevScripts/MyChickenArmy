# Economy playtests — September 26, 2026

Owner: Run Chicken Army economy playtests, 01a0df83-b96e-7640-8b02-c942e4265162.
Completed; source and canonical Studio ownership released.
Changed CommerceService session-only overrides, DebugService presets, narrow
GameServer wiring, the EggService Studio bypass guard, and AppController F8 test
controls; new evidence/report files. Other existing edits retained.
No real purchases, profile writes, publish, save, commit or push requested.

Current source uses instant egg selling; older seller-throughput sections in
EGG_ECONOMY and UPGRADE_RULES predate the latest implemented change.
Before sources matched except three stale duplicate economy modules in Studio.
Evidence and before-copies: assets/economy-playtests-20260926/.

Results: docs/ECONOMY_PLAYTEST_REPORT_2026-09-26.md.
Controls: docs/ECONOMY_TEST_TOOLS.md.
Seven three-minute opening runs (one excluded/repeated), two idle checks,
free/paid camp checks with a clean paid repeat, 60/360-chicken server loads,
56 one-hour accelerated simulations across seven strategies and eight seeds.
Eight live guards, ten isolated checks and the legacy vacuum guard passed.
Build, scoped source compilation and Rojo readback passed; final-integration.json
records exact hashes. Studio is back in Edit. Temporary runtime profiles and bots
were discarded; zero DataService entries in both live batches.

Three stale duplicate economy modules were exported then moved intact into
ServerStorage.EconomyPlaytestRecovery20260926. Preserve that recovery folder.
No real purchases, profile writes, Roblox save/publish, Git commit or push.
Foreground FPS and final UI screenshot could not be measured because the Mac was
locked and Studio stopped rendering. Reported performance conclusions cover the
server workload, not mobile or six real networked clients.
