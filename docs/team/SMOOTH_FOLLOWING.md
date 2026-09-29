# Smooth army following — September 28, 2026

Implemented; file ownership released. Changes are limited to ArmyCommandService,
PetActor's following movement mode, shared FollowMotion, focused checks, and this
record. User approved coordination; the collision, spawn and fusion chats
explicitly released PetActor before these edits. Their separate map/fusion
changes are preserved. No economy, saved-player data or UI changes.

## Research and diagnosis

The previous formation controller runs every 0.2 seconds, uses player WalkSpeed
plus six regardless of formation error, and abruptly stops inside two studs.
PetActor throttles new MoveTo destinations to 0.18 seconds. Those are concrete
sources of delayed retargeting and a catch-up/stop cycle; they are not measured
network latency. The rigs already explicitly keep server network ownership.

Primary references reviewed:

- [Roblox engineer on MoveTo/CFrame and custom Move steering](https://devforum.roblox.com/t/setting-humanoid-cframe-breaks-movement/2486634/4), August 2023. Root CFrame writes abort MoveTo; continuous Move is the suggested custom controller route.
- [NPC waypoint stutter report and Roblox discussion](https://devforum.roblox.com/t/npc-moveto-has-a-stuttering-effect-whilst-using-pathfindingservice/3067241), July 2024. Arrival-event-driven waypoint transitions can visibly pause. This game already advances waypoints by distance, so blindly removing MoveToFinished is not its fix.
- [Client-owned Humanoid MoveTo jitter reproduction](https://devforum.roblox.com/t/humanoid-moveto-jitters-with-client-network-ownership/3946259), September 2025. First-party reproduction report, not a universal engine guarantee. Avoid splitting server commands and client physics ownership.
- [Client/server pet-follow discussion](https://devforum.roblox.com/t/should-my-pets-following-system-be-client-or-server/2494410), July–August 2023. Client-rendered cosmetic pets can avoid server visual updates; ownership and gameplay state stay authoritative. This game's existing physical chickens also enter combat, so cosmetic-only replacement would need a larger presentation/actor handoff.
- [Working formation example](https://devforum.roblox.com/t/pet-follow-system/1892399/5), July 2022. Demonstrates a centralized per-frame formation loop and delta-time motion. Its linear delta multiplier is an example, not a universal frame-independent filter.
- [Roblox Humanoid API](https://create.roblox.com/docs/reference/engine/classes/Humanoid#Move), checked against [the official source](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Humanoid.yaml): server Move requires server ownership; MoveTo has an arrival tolerance and ends when its root CFrame changes.
- [Network ownership documentation](https://create.roblox.com/docs/physics/network-ownership): physics ownership and visual responsiveness are separate from authoritative gameplay validation.
- [Community tutorial index](https://devforum.roblox.com/t/creating-a-reliable-pet-follow-system/365380) links [tutorial one](https://www.youtube.com/watch?v=x5ukWwTlA8Y) and [tutorial two](https://www.youtube.com/watch?v=zSu7LMvM4v0). YouTube fetches failed/throttled, so their footage/transcripts were not verified and no implementation claim relies on them.

## Chosen approach

Keep server-owned walking rigs and the existing recovery/path owner. Use a
continuous Humanoid:Move steering mode only while Following. Match leader
horizontal velocity and close formation error gradually; bound catch-up speed
and smooth steering using elapsed time. Keep formation heading when stationary
and turn it gradually while moving, avoiding a flock orbit whenever the player
turns in place. Membership synchronization and ground sampling can stay slower
than steering. Release must immediately cancel steering before home/battle
ownership resumes.

This is continuous collision-aware movement, so a fixed TweenService tween is
not suitable. No tween is restarted each frame, and no new animation framework
or physics-ownership transfer is introduced.

## Implementation and tuning

`ArmyCommandService:Step` updates steering on the existing server Heartbeat;
membership stays at 5 Hz and ground heights at 10 Hz. New slots sample ground
immediately. All selected IDs and Colossal limits still come from the session.
`FollowMotion` retains centered three-column rows and Giant-aware spacing. Its
named controls are 10/sec velocity response, 4/sec position correction,
0.5-stud rest radius, 300 degrees/sec formation turn rate and 0.75-stud/sec
leader deadband. Catch-up is capped at player WalkSpeed + 8, at most 48 studs/sec.
These are authored tuning values, not settings copied from another game.

`PetActor:Follow` sets a moving destination and leader velocity; `Step` owns the
actual Humanoid command alongside existing health, obstruction and path checks.
Intermediate path waypoints retain walking speed. Stop, Teleport, normal MoveTo,
home and combat handoffs clear continuous steering. Physical rig recovery keeps
the current follow destination and mode. A resting follower does not trigger
stuck recovery; a different-height destination still requires a usable route.

## Validation and limits

23 checks passed: eight frame-rate/formation math checks, eight army-command
checks (including consecutive-frame retargeting), and seven physical-actor
checks. The physical fixture compared the pre-change actor/controller with the
new implementation on the same disposable floor at a 16-stud/sec leader speed.
Across 240 steady-motion samples, the old controller had 46 samples below four
studs/sec. Both new ordinary and 27.5-stud Colossal followers had zero. Their
mean speed was 16.0005 studs/sec, with 0.0022 standard deviation versus 8.8905
for the baseline. Both settled 0.496 studs from their destination at zero speed,
with no recovery/replacement. These are controlled local measurements, not
multiplayer-network or player-retention evidence.

The physical checks also covered crossing a DuckScenery obstacle with solid
ground retained, server ownership, invalid inputs, Stop/MoveTo handoff and
recovery continuity. The final small cleanup resets recovery attempts when
entering Follow, checks vertical separation before considering a slot settled,
and removes cached heights for unequipped birds. The final command checks use
the exact latest source; final sources parse and the Rojo package build passes.

A live CallArmy request succeeded and an eight-chicken following squad was
observed in the client. Concurrent external Studio interaction changed the
session/player during the attempted controlled client walk, so it is not a
passed client smoothness benchmark. Raw per-render Position samples were also
intermittent and cannot isolate presentation interpolation from physics updates.
Rendered/network smoothness under latency remains unverified.

Evidence: `assets/smooth-following-20260928/checks.json`; reusable checks live in
`tests/FollowMotionChecks.luau`, `tests/FollowingActorChecks.luau` and
`tests/ArmyCommandChecks.luau`. `client-walk-check.luau` is a prepared harness,
not a completed result. Disposable physical fixtures and event listeners were
removed. The pre-existing session-only flag was retained. One byte-identical
Rojo duplicate of FollowMotion was preserved outside the active tree in
`ServerStorage.FollowingDuplicateRecovery20260928`. No publishing, persistent
profile writes, commits or pushes were performed by this task.
