# Test method and evidence boundaries

All work targets Pet Roll Test 96683186622050 with Studio Flow. Local code is
Rojo-synced; mapped Source was never overwritten through MCP. The source manifest
and task-only diff separate this task from pre-existing dirty work.

`live-client.luau` walks the real avatar using Humanoid.MoveTo. `live-runs.luau`
resets disposable profiles and calls the normal server request validator, including
proximity, funds, offer IDs and cooldown checks. Real eggs, inventory, upgrades,
vacuum and cash-pad movement run at normal elapsed time. The avatar is placed at
spawn only when starting a fresh case. Walking targets have bounded timeouts;
these are automation limitations, not independently proven map defects.

The first six cases each last three minutes, with one seeded roll stream and the
real paid-luck distribution. Manual collection follows the same sweep for all
cases; therefore this does not isolate the human effort saved by Auto Collect.
The cash-pack case overlapped an initially attempted accelerated batch. That
batch was intentionally stopped at a result boundary after eight completed
simulations; its interruption error is not a game error. A separate cash-pack
repeat is used for the clean comparison. Initial 15 FPS samples are environment
limited and are not used as evidence that the game meets a 60 FPS target.
Native computer-use subsequently confirmed that the Mac was locked and could
not be unlocked automatically. The user was asked to unlock it while independent
economy and server work continued. Server heartbeat remained near 60 Hz.

`progression-simulation.luau` uses actual Session, RollService, UpgradeService,
ArmyService, EggService and OfflineCash modules with in-memory profiles and an
unparented sell pad. No DataService is involved. Movement is abstracted as a
perfect yard sweep every 20 seconds (60 for CasualFree), with three-second rolls.
The policy reinvests in affordable recruits and the better-return income upgrade,
then buys other tracks from surplus. It sells weaker reserves at capacity. It
does not simulate combat, discovery, mistakes, human attention or player retention.
All simulations assume Plot 1's six physically authored podiums. MergeEarly uses
the real triple-merge rule and Rookie merge cap, without inventing camp wins.

`idle-check.luau` compares stationary free and paid players for 60 seconds each.
`combat-check.luau` compares the same six owned birds against Cluck Camp using real
actors and normal battle stepping. Only avatar approach to the command is skipped;
the chicken march, fight and capture use elapsed wall time.
The first paid attempt occurred before the normal post-cancellation camp grace
expired. It was excluded, then repeated with continuous timing after the stress
bots were removed. The harness now waits for that reservation to clear.

`stress-setup.luau` creates an artificial maximum of 60 level-10 mixed chickens,
then six such profiles (360 chickens) on the live server. Five are test bots, not
five additional networked clients. This measures upper-bound server population
with one rendered Studio client, not real mobile or six-device networking.

RenderStepped samples, server GameServer.Step CPU timings, script-profiler captures
and instance/drop counts are recorded separately. Studio memory includes edit,
server, client and plugins in this process; it is not standalone-player memory.
The MicroProfiler baseline hit its event limit and reported inconsistent frame
timing units relative to RenderStepped; it is retained as diagnostic evidence,
not used for an FPS claim. See Roblox's [performance measurement guidance](https://create.roblox.com/docs/performance-optimization/identify).
The later stress phases returned no RenderStepped samples. Studio Flow reported
that the window had not rendered for several minutes, so those phases support
server measurements only. The final F8 screenshot/input recheck was unavailable.

The accelerated batch was resumed from completed seeds after adding periodic
yields to keep Studio inspectable and avoiding unnecessary SaleEligibility calls
for candidates that could not replace the already-found weakest eligible bird.
This preserves the selection rule and all real transaction validation. No game
performance change was made to accelerate the harness.

No real purchases, profile writes, game publication, Roblox save, Git commit or
push. Test results are observations and bounded policy experiments, not a claim
that every player finishes the game within a particular time.
