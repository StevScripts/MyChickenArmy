# Skill-tree motion — October 2, 2026

The user requested cleaner animations for the current unified skill tree using
the Roblox Game Feel skill. Scope is presentation in ResearchBrowser; node
positions, purchases, prices, research jobs, saved progress and rewards retain
their existing owners.

## Findings in the previous presentation

- Research and cash had separate opening queues with a 5%-to-full Back bounce.
  Revealing an already-visible cash question mark also reset it to 5% size.
- Node hover and press had no tactile response. Directly binding the shared
  button animation would compete with the existing reveal's Size tween.
- Each integer-second server timestamp reset the local fractional clock on every
  snapshot. The presentation estimate could move backward; progress was assigned
  directly at a quarter-second cadence.
- Close cancelled tint and outline tweens without settling their target colors.
  The unchanged-state cache could preserve a partially tinted node when reopening.
- Research completion created 30 screen-wide confetti pieces, with delayed cleanup
  surviving Close. Cash confirmations had no corresponding local completion pulse.

## Presentation contract

Input gets a small press response immediately. Only a confirmed purchase marks
the node owned and triggers its completion emphasis; the next branch reveals in
the same short sequence. Earned value and spendability always follow server state,
independently of cosmetic duration. Failed purchases keep their readable message.

Keep one size-animation owner per node. Retarget from the current size, use normal
TweenService tweens, and avoid restarting unchanged animation targets on snapshots.
Opening is one restrained outward wave from Start across both purchase types.
Research bars advance smoothly against their existing deadline. Reduced motion
keeps the same information and interactions without scale choreography.

Timing values are initial artistic tuning choices, not measurements from another
game. `ResearchBrowser.MOTION` contains the editable presentation constants:
opening starts at 88% over 0.24 seconds with a maximum 0.20-second outward delay;
hover is 102.5%, press is 96%, and confirmation peaks at 104.5%. Only the inner
visual scales, so hit targets and the native aspect layout stay stable.

Pan, pinch and wheel navigation keep direct input tracking. This polish does not
add camera motion, inertia or an animation framework. Existing Click/Error cues
use the shared AudioController and its Effects setting; no new sound asset or
success jingle is introduced.

## Focused checks

The synced 50,668-byte source compiled in Pet Roll Test. Focused runtime checks
used its disposable `studio-session` profile with temporary unmapped probes:

- Opening sampled from 0.88 to exactly 1 without overshoot. Mouse hover settled
  at 1.025, press at 0.96, release at 1.025, and pointer exit at exactly 1.
- Actual UI clicks purchased the two consecutive Roll Slot tiers (1 → 2 → 3).
  Both receipts marked the purchased node Completed. The next question-to-known
  reveal stayed between 1 and 1.025 rather than collapsing, including the next
  purchase while the previous successor was still settling.
- Closing 0.03 seconds into a presentation-only rejection flash and immediately
  reopening restored the exact white target rim and normal size.
- An active, server-started S1 research job advanced on 30 observed frames in a
  two-second sample, with zero progress or presentation-clock reversals while
  normal state snapshots continued.
- Dragging across nodes left the maximum visible node scale at exactly 1.
- Enabling reduced motion during opening settled the nodes at exactly 1.
  An isolated server-completion fixture still changed S1 to Completed and S2 to
  Available, with correct colors and no scale animation. Effects mute state was
  respected by the shared controller; no subjective audio mix claim is made.
- Source review covered cancellation ownership and controller/touch paths.
  This pass exercised desktop input, not physical touch or controller hardware.

Only presentation source and these notes changed for this motion pass. Existing
startup plugin warnings and an unrelated missing egg-deposit effect warning were
observed; no ResearchBrowser runtime error appeared. Play was stopped afterward;
temporary runtime probes and disposable progress were not persisted. No publish,
live-profile write, price change or economy-setting change was performed.
