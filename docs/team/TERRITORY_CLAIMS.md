# Persistent territory claims — September 29, 2026

**October 6 update:** [the user's supplied conquest recording](CONQUEST_REFERENCE.md)
supersedes this page's eight-second explicit-unclaim recovery. Unclaim now
restores the native flag/guards immediately and a surviving army begins a fresh
continuous conquest. Persistent claims, ownership checks, preserved chicken lives
and vacancy grace remain. The historical verification below describes September 29.

The user's Mini War conquest request supersedes the automatic ownership release
on army withdrawal described in CAMP_RETARGETING.md. Current runtime ownership
remains server-session state; this change adds no saved-territory schema.

## Reference research

Primary source: [Mini War by M&M Community](https://www.roblox.com/games/131346454575416/Mini-War).
Firsthand gameplay was inspected visually and through timestamped transcripts:

- [AJPlays: Construction Yard](https://www.youtube.com/watch?v=mIGcoJde5u8&t=190s),
  3:10: separate native **E — Move Troops Here** and **R — Unclaim base** prompts.
  At 3:12, the released base has its native flag and hostile troops, while the
  player's surviving units remain nearby. At 3:53–4:03, those units capture the
  base again. Repeated unclaims also appear at 6:55–7:04 and later.
- [CashBlox gameplay](https://www.youtube.com/watch?v=z6GO4xMKG_I&t=629s),
  10:29–11:19: captured flags persist as the army proceeds to another base;
  15:03 describes another player taking a previously conquered base.
- [ItzVexo guide](https://www.youtube.com/watch?v=3sqhzCk4lMY&t=447s),
  7:24–7:47: conquest proceeds to a completed capture.
- [DinozaurPlays tips](https://www.youtube.com/watch?v=GGT8Pp11ftQ&t=624s),
  10:24–11:00: multiple conquered bases remain owned for territory benefits.

The separate commands, persistent claims and surviving troops are directly
observed. The exact Mini War recovery duration was **not** established. The
user specifically asked for gradual bar recovery, so My Chicken Army reuses
its existing `Config.CaptureSeconds` (8 seconds) for a fully released base.
Do not present that tuning as a measured Mini War value. Fan guides conflict
about unattended bases and were not used as authority. Direct Roblox-client
interaction was unavailable; the visual evidence came from gameplay videos.

## Behavior

- Moving to another camp, retreating, Call Army and Go Base leave the conquered
  flag/name in place. Claimed empty camps suppress their hostile garrison.
- Approach an owned camp, outpost or King arena and use **R — Unclaim Base**.
  **E — Move Troops Here** remains a separate order. Unclaim also works with no
  selected chickens and while the army is returning. Both are native prompts;
  the release prompt uses gamepad Y and native touch interaction.
- The server validates proximity and ownership. Repeating a release or trying
  to release another player's claim does nothing. Claim release removes current
  route passage, never saved first wins, money, chickens or upgrades.
- An empty released base restores its garrison and fills the red enemy-control
  bar over 8 seconds. A departing army must physically clear the site plus the
  existing 2-second vacancy grace; explicit release does not wait for that
  army to reach its next destination.
- Troops still stationed at (or traveling to) a released friendly base retain
  their identities, positions, health and recovery deadlines. Its garrison
  returns to their existing battle. Enemy control recovers while defenders
  survive; defeating them resumes ordinary capture from the remaining control.
- The original owner can return during recovery without resetting its meter.
  A successful recapture cancels the old recovery. A different attacking army
  keeps its ordinary capture rules. Existing active rival battles are preserved.
- Player departure clears that player's server-session flags and pending
  recoveries. Shared Supply Outpost income/contest rules remain separate.

## Ownership and verification

Runtime files: BattleService owns claims/recovery and snapshots; GameServer
validates the request's proximity; BaseController owns the two prompts;
BattleController renders the server's recovery meter with its existing tween.
WorldService's existing flag and garrison behavior is reused.

Focused checks: `tests/TerritoryClaimChecks.luau` and the updated
`tests/CampRetargetingChecks.luau`. Results and source before-copies live under
`assets/territory-claims-20260929/`. Test worlds/sessions are isolated and do not
load or save player profiles. Packaging is checked separately with Rojo.

Completed validation:

- All 27 isolated behavior groups passed (17 retargeting + 10 claim checks).
- A fresh `studio-session` playtest used real native R/E input. R removed the
  flag and restored three guards; the client received 35 intermediate control
  values, then 100%, with the existing meter's title/fill updating accordingly.
- E deployed three real chickens. Their normal march, combat and capture
  completed successfully: Holding, capture 8/8, owner restored, no living guards.
- R while Holding kept the same three physical player actors and spawned three
  hostile actors into the same encounter. The phase changed to Fight.
- Rojo packaging and scoped whitespace checks passed. One active copy of every
  changed runtime module matches local source and compiles in Studio.
- Play was stopped and the existing MyArmy authoring preview reopened. The
  pre-existing session-only attribute remained true; no saved profiles changed.

The viewport screenshot API omitted native prompts and PlayerGui billboards;
their visibility/events, keyboard activation, labels and fill values were
verified through the live client. Direct desktop capture was unavailable.
Screenshots did show the persistent flag and restored world defenders.

No publish, upload, Git push or saved-player-data change is part of this task.
