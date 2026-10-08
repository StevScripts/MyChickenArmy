# Conquest recording contract — October 6, 2026

The user's 149-second Mini War recording now guides ordinary camp, outpost and
King conquest. This supersedes the September 29 two-phase meter and gradual
**explicit unclaim** recovery in `TERRITORY_CLAIMS.md`. Failed attacks still use
the existing gradual enemy recovery; income contests and Operations retain
their own rules. Cash upgrades remain independent of conquest.

## Pre-release fixes: October 8, 2026

Owner direction "do what you think is best". Local source only: no Studio
playtest, save, publish or commit. A Rojo build packages; Luau was not run.

- **Armies come home after a win.** A main-route camp or King capture keeps the
  flag, holds for a 5-second victory moment (`VICTORY_LINGER_SECONDS` in
  `BattleService`), then uses the normal `ReturnHome` march, so deployed chickens
  lay eggs again. Route legs still advance; a stopped route now heads home instead
  of stranding the squad. The Supply Outpost (disabled) keeps its defended station.
- **No stationing on held ground.** Targets you own are unavailable ("Conquered")
  and the server refuses them ("You already hold X. Unclaim it to fight there
  again."). R Unclaim is unchanged and still restores the garrison against the
  same squad.
- **Shared King arena.** A challenger who does not own the King fights a full,
  fresh court (boss plus six guards); `LiveBattleActors` spawns the rigs because the
  owned arena has no idle ones. `kingCleared` and King ownership are granted only
  when that encounter's own boss is dead. The owner's army leaves after the victory
  moment, which frees the center after the normal vacancy grace.
- **King bounty.** The $48,000 boss bounty pays in full once per player; later
  boss kills pay `CombatRewards.BossRepeatFraction` (10%, like Operation replays).
  "Once" is saved `kingCleared` or an in-memory `kingBountyPaid` set on the first
  paid boss kill this visit. Persisting `kingBountyPaid` needs a PlayerSession save
  field (not yet done), so kill-boss-then-lose can repeat once per rejoin.
- **Fort Roost softened.** Level-1 Robo-Cluck, Mushroom Chicken and two Brown
  Chickens (power about 107, was about 146). Cluck Camp about 39, Ironbeak HQ about
  192 and the King about 497 are unchanged.
- **Prompt hints.** The E prompt's `ObjectText` now carries odds, defenders and
  bounty, for example "Close fight · 4 defenders · $100–520/kill" (this supersedes
  the empty `ObjectText` rule below). Unavailable targets show no prompt; a
  `CampLockedHeading` billboard states the reason ("Buy a chicken at your podium
  first", "Occupied by an army", "Your army is returning or defending"). The
  current target and held ground stay quiet.
- **Odds bands** (`TutorialGuide.Difficulty`, army power over garrison power):
  below 1.3x Very tough, 1.3x to 2x Close fight, 2x or more Should win. Defenders
  respawn every 10 to 15 seconds and capture needs every guard down at once, so an
  even power match usually loses. The starter four Chickens against Cluck Camp
  (1.33x) read Close fight; five level-1 Uncommons against Fort Roost (1.39x) read
  Close fight.
- **Funnel analytics** (production only, Studio keeps the local ring):
  `ConquestFirstWin` (step Camp1 to Camp3), `KingFirstClear` (step King) and
  `ConquestFailed` (Defeated, Draw, Blocked or Retreat before that target's first
  win, at most 20 per visit). Value is seconds since the order; detail adds the
  power-ratio band (Under1, 1To1.3, 1.3To2, 2Plus). Field 1 is
  `conquest-2-soft-roost`. Sent by `TutorialService.LogProgress`.

## Evidence and limits

Source: `/Users/stevin/Desktop/Screen Recording 2026-10-06 at 12.39.28 AM.mov`.
The complete recording was decoded into 8,128 timestamped frames, scanned for
image/color changes, reviewed through full-sequence contact sheets, and examined
at finer intervals around unclaims and the Garrison capture. The decoded-frame
index is authoritative; the container reports 8,129 packets, not 8,129 usable
images. Evidence lives in the design workspace's
`research/conquest-reference-20261006/`.

| Recording time | Observation | Implementation |
|---|---|---|
| 14.2–15.6 s | Camp unclaim immediately restores the native flag/guards; the same player troops fight again | Clear ownership immediately, preserve each chicken's life, start a fresh conquest |
| 31–37 s | Released Camp is recaptured; ownership persists while attention moves elsewhere | Session claims outlive army departure |
| 53–63 s | Deployment, march and combat precede/overlap a rising red meter | Physical living attackers inside the radius advance one continuous meter during combat |
| 61–85 s | Four-section red bar fills over roughly 24–25 seconds | `Config.ConquestSeconds=25`, retaining research capture bonuses |
| 83–86 s | Guards reappear near the end; the bar does not reset; completion follows the final fight | Respawns retain progress; full progress still requires no living defenders |
| 85.8–86.2 s | Green conquered status and a short victory announcement | Green owned marker/toast and local glow, ring and star burst |
| 133–136 s | Separate compact R Unclaim / E Move Troops controls; unclaim restores hostile troops | Native, action-only prompts centered in the camp per the latest user correction; no inactive status prompt over combat |

Twenty-five seconds is an observed pacing estimate, not a recovered internal
Mini War constant. Camera distance, upgrades, hidden combat parameters and
original effect assets are not recoverable from this clip. This implementation
recreates its visible conquest flow with Chicken Army's own map, chickens,
combat stats and rewards; it is not a claim of pixel-identical rendering.

## Runtime behavior

- Living, arrived, non-retiring chickens inside `CaptureRadius` advance capture.
  The avatar, dead chickens and distant reinforcements never count. Leaving the
  radius freezes progress. The server alone completes captures and pays rewards.
- Starting an ordinary camp/outpost/King attack transfers the existing patrol
  actors into combat at their current positions and facing. It does not replace
  or arrange them into a center formation. Idle patrol ownership is released,
  while normal death-respawn locations and the King's appearance remain intact.
- Camp defenders detect arriving troops within `Config.DefenderAggroRadius`
  (18 studs) and use the existing combat movement to walk toward them. Required
  road/exit waypoints still finish first. Nearby reinforcements join the fight;
  distant stragglers cannot rescue a wiped frontline. Detection does not grant
  capture progress outside `CaptureRadius`. Income and Operations are unchanged.
- The world meter reads **⚔ Conquering ⚔**, then the camp name, then a red bar
  split into four equal sections. It has no percent text or second drain/fill
  phase. The old camp title is suppressed while occupied or conquered.
- Victory swaps to a persistent green conquered label, white camp name and
  gold owner name. The existing authored flag's cloth turns green and displays
  the conquering player's avatar headshot on both sides; no second pole/flag is
  generated. The portrait and label remain after recall or another camp order.
  Unclaim clears the portrait and restores the original cloth colors. The same
  portrait behavior applies to the authored Chicken King throne flag.
- The player portrait/crown/"My army" billboard no longer follows troops.
  Owner portraits appear on conquered flags only, after server-awarded ownership.
- Explicit unclaim resets capture to zero and restores defenders. Player unit
  identities, positions, health and respawn deadlines survive the transition.
  An empty released camp restores idle guards after the existing vacancy grace.
- Native prompts display only usable commands, with empty `ObjectText` and short
  action copy. R sits above E when both apply. The October 6 follow-up centers
  their attachment in the camp, 2.5 studs above its command center.
  Range/ownership checks still use the server's original geometry.
  The current attacking target has no inactive E prompt or attack heading.
- Victory uses native TweenService tweens and one bounded ParticleEmitter burst.
  Reduced motion suppresses/clears the burst; existing audio settings still apply.
- First-win cash, route progression, Cluck fusion unlock, earned chickens, saved
  levels and all purchase eligibility are preserved. No reference civilian or
  money-multiplier reward was imported.

## Source ownership

`Battle` owns capture simulation; `BattleService` owns claims, unclaim and reward
transitions. `WorldBuilder`, `WorldService` and `KingArena` own persistent world
labels. `BattleController` renders snapshots; `BaseController` owns contextual
native prompts. `ConquestPresentation` and `UIColors` are shared visual values,
`UITheme` supplies the bar/toast style, and `ActionFeedback` owns temporary VFX.
`AppController` selects the conquest toast style for the server result text.

## Validation and delivery

- The guard-handoff follow-up passes five ownership/respawn checks plus the
  eight approach checks. Live camp and King attacks preserved all ten NPC
  actors/models with zero position or rotation change; the King retained its
  scale and crown. A live defeated guard reused its rig at the normal respawn
  line. Outposts are currently disabled; their transfer is fixture-tested.
  Evidence: `assets/guard-handoff-20261006/checks-result.json`.

- The centered-prompt/defender-approach follow-up passes eight focused fixtures.
  A live session recorded detection at 17.8 studs and all three guards walking
  about 3.8 studs toward attackers within 0.4 seconds, before taking damage.
  Capture stayed at zero outside the objective. Evidence:
  `assets/conquest-approach-20261006/`.

- 43 focused real-module fixtures passed: 16 conquest, 10 territory-claim and
  17 retargeting groups. Results: `assets/conquest-reference-20261006/checks-result.json`.
- Isolated `studio-session` gameplay completed normal marching, fighting,
  capture, defender respawns, unclaim and recapture. First live capture reached
  25/25 after approximately 25 seconds of capture occupancy. Its sampled history
  is saved alongside the checks.
- A later live run confirmed the compact meter, persistent owned camp name,
  absence of duplicate titles, no leftover capture meter after victory, continued
  ownership while redirecting to Camp 2, and reduced-motion effect cleanup.
- Desktop screenshots were inspected for native world UI. Studio Flow's viewport
  screenshot omits native billboards/prompts, so it is insufficient for that check.
- Rojo packaging and whitespace checks passed. Source readback/compilation and
  the final native E/R prompt check are recorded in the accompanying status file.

Playtest fixtures used temporary level-4 starter chickens with profile saving
disabled. No saved-player-data changes, publication, asset uploads, Git commit
or remote push are part of this change.
