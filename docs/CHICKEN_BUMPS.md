# Walking over low ground details

September 25, 2026. The prior watchdog/rebuild changes recovered stalled actors,
but did not fix their low physical clearance. The smallest level-one chicken's
collision box started about 0.152 studs above its feet. The authored yard lip
is approximately 0.301 studs above the plot deck, enough to catch that box.

`BlenderPetView.Create` now places a physical root at `size * 0.75` above the
feet instead of `size * 0.45`. The root's dimensions remain unchanged, giving
the smallest chicken about 0.658 studs of clearance. Its mesh joint offsets
keep the original visible pose and foot position. `PetView.CreateRig` does the
same for native fallback rigs, preserving their body pose and tag offset.
Previews keep the previous pivot. Existing growth and King scaling scale the
root, joints, FootOffset and HipHeight together.

This uses ordinary Humanoid ground following. Jumping remains disabled; no
per-frame lifts, movement teleports, collision disabling, or map edits were
added. Taller obstacles still require a route around them. A 0.60-stud step is
the tested low-step target for the smallest chicken, not a universal guarantee
for every mesh, overhang or arbitrary terrain configuration.

## Evidence

- Baseline experiment reproduced failure at 0.30 studs; the changed shell crossed
  0.30, 0.45 and 0.60 studs, with no jumping or recovery teleport. Both versions
  remained obstructed by taller test obstacles.
- Eleven final walking checks passed: 0.30/0.60 steps, slow/fast walks, angled
  and thin ridges, Mallard, level-ten growth, low overhang, tall wall, and the
  actual Plot 1 yard edge near the reported stuck reinforcement. Walkable routes
  passed outward and return legs, with no jumps or recovery teleports. Settled
  foot error stayed below 0.061 studs; synthetic floors were effectively zero.
- 102 before/after art comparisons passed: all 32 species at levels 1 and 10,
  their previews, and three native fallback recipes at both levels. Visible part
  positions and sizes stayed within 0.002 studs of the prior implementation.
- Results and reproducible walking fixture: `assets/chicken-bumps/`.

Roblox reference: [Humanoid HipHeight](https://create.roblox.com/docs/reference/engine/classes/Humanoid#HipHeight).

All 18 existing physical-recovery and combat-respawn regression checks also
passed with the new shell. Final Studio readback found one copy of each changed
module, matching disk and compiling. Rojo packaging and scoped diff checks pass.
Play was stopped and disposable fixtures/test modules removed. Studio controls
are released. No place save/publish, Git commit/push, asset upload, purchase or
saved player-data changes.

The baseline experiment file records the pre-change run and its temporary
raised-shell comparison; it expects the old rig code. Use `walking-checks.luau`
for the final implementation. All fixture runs require session-only Studio Play.
