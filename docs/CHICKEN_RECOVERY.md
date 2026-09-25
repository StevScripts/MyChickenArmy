# Chicken movement and recovery

PetActor owns physical movement and repair. WorldService owns home wandering;
LiveBattleActors keeps the physical actor attached to the existing combat unit.
No recovery creates inventory, changes combat HP, pays kills, or edits a save.

## What changed

- Rebuild a missing/detached model, root, Humanoid or body, a disconnected body,
  an accidentally dead Humanoid, or an anchored rig. Preserve pet/unit/owner
  attributes, level, appearance, King crown/scale, and server physics ownership.
- Check idle actors too. Recover falls and large unexpected displacements to a
  previously grounded, clear position. A one-second repair cooldown prevents
  repeated rebuilds in the same tick. Explicit actor Destroy remains terminal.
- Validate safe ground with the chicken collision group and a clearance query;
  never recover directly to the requested combat destination. If no safe anchor
  exists, remain blocked rather than spawning into solid geometry or empty air.
- Retain path objects while following them. A blockage ahead invalidates the
  path; a blockage behind does not. Progress means getting closer to the current
  waypoint, so sideways jitter cannot keep the watchdog alive indefinitely.
- At most two concurrent path computations; all creation/computation failures,
  cancellation, replacement goals, destruction, and eight-second timeouts release
  their slots. Two failed attempts report blocked; a still-owned blocked actor
  retries after three seconds. Higher-level battle failure/return rules remain.
- Home wandering rejects obstructed destinations. Failed home walks recover to
  their reserved yard position. The straight-line travel estimate no longer
  cancels healthy detours; four seconds without progress or a hard deadline
  (at least 45 seconds, or three times the travel estimate) bounds them.

## Death and ownership rules

Gameplay HP is in Battle's unit record, separate from the physical Humanoid.
Owned chickens normally respawn at home after five seconds and walk back when
battle rules permit. A wiped front line can end the attack first. Locked finite
territory contests retain their existing no-extra-life rule. Ordinary NPC
camp defenders use the existing 10–15 second timer while fighting/capturing;
King/noRespawn units retain their exceptions.

Repairing a rig with unit HP zero does not reset its death timer or spawnSerial.
Normal gameplay respawns update the physical recovery anchor so the intended
home move is not mistaken for a physics fling. Home/battle transfers update the
cached parent, preventing repairs from recreating a second bird in the old owner.
Returning squads already had a 95-second fallback to the yard; it is preserved.

## Evidence and limits

Fixtures are isolated, session-only Studio tests; no real profile was changed.
`tests/ChickenRecoveryChecks.luau` covers live faults, movement, identity, combat
health/death timers, normal movement and a temporarily enclosed route.
`assets/chicken-recovery/path-checks.luau` injects asynchronous path failures,
timeout, saturation, cancellation, blocked events and sideways jitter in Edit.
The authored Plot 1 gate was walked outward and back through six actual route
legs, all arriving without recovery teleportation. During yard observation, a
healthy detour exceeding its old straight-line timeout was reproduced and fixed.
Final machine-readable results live beside the source recovery copies under
`assets/chicken-recovery/`.

Final result: 18/18 live checks and 6/6 asynchronous path checks pass. Over a
66-second final yard observation, the three home birds recorded 0, 1 and 3
blocked-route recoveries and were all moving at the final sample. This confirms
the fallback is used; it does not claim the authored scenery never obstructs a
chicken. No stale timeout recovery was recorded in that observation.

This is bounded recovery, not a claim that every future map or engine fault is
impossible. A completely removed floor/owner container cannot supply a safe
respawn point. Closed combat routes may still abort and return home; recovery
must not grant remote attacks, capture credit, extra lives or rewards. Dense
multi-player flock performance and every species/plot combination were not
exhaustively tested.

The path lifecycle follows [Roblox's blocked-path guidance](https://create.roblox.com/docs/characters/pathfinding).
Sources are edited locally and synced through Rojo; publishing is separate.
