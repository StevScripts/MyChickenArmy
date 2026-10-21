# Egg and cash feedback

Tune `src/shared/CollectionFeel.luau`, then restart Play. ModuleScripts are cached.

## Egg sales: coin burst (October 20)

Selling eggs on the green pad bursts gold coins out of the pad. They bounce, spin,
then fly into the player one after another, and the HUD Coins readout counts up as
each coin lands. It is presentation only: the server paid when the deposit happened.
Any non-robot deposit receipt with a pad position gets it, so the hand vacuum's
unload will too. Robot vacuum deliveries stay quiet.

- `client/CoinBurst.luau` builds each coin in code: a BillboardGui with the HUD coin
  image (`Theme.Assets.Coin`), 1.4 studs, not always-on-top. Every move is a
  TweenService tween. The coin's Attachment (under Terrain) slides across the pad
  while the gui's `StudsOffsetWorldSpace` rises and then drops with a Bounce ease.
  A Size squash fakes the spin. For the fly-in, the Attachment moves onto the
  HumanoidRootPart, so a walking player is followed without a frame loop.
- One coin per egg sold, 3 to 14 (7 on touch screens without a keyboard), and at
  most 28 (14) alive at once. A sale that can't get coins (budget, distance, no pad
  position) plays the Money burst below instead.
- `ActionFeedback:Deposit` holds the receipt's value as soon as the receipt
  arrives, before that snapshot reaches the HUD. Each landing coin releases an equal
  share; the last one carries the remainder. `HudController:ShownCoins` subtracts
  what is still held. Reset, teardown, reduced motion and a 4-second `HoldTimeout`
  release everything at once, so the readout always catches up.
- October 21 pickup, matched to Stevin's reference recording (a Pet Simulator–style
  coin pickup): coins arc up and over into the player in a quick stream. The first
  landing flashes a white ForceField bubble with a Neon glow and sparkles. The
  running "N [coin]" counter beside the player was removed the same day (Stevin:
  "I don't want to see the amount of money I made as the billboard gui"); the HUD
  Coins readout still counts up per coin.
- October 21 follow-up (Stevin: "the initial coins falling doesn't have sound and
  there's no VFX for when you just walk in"): stepping on the pad now flashes the
  pickup bubble and a gold ring at the player's feet at once. That works without the
  `ReplicatedStorage.EggDepositEffects` template, which this place doesn't have.
  A gold sparkle puff (`SpillPuff`) shoots up from the pad as the coins burst out,
  and the "CoinDrop" sound plays (`SoundService.MyChickenArmyAudio.Collection.CoinDrop`,
  Studio-owned, asset 134911555436784, alternate 133570405319995).
- Sounds: EggDeposit when the coins pop, CashTick (Money) on the first landing,
  then CoinPickup on each coin with a slightly rising, jittered pitch. CoinPickup
  (`SoundService.MyChickenArmyAudio.Collection.CoinPickup`, Studio-owned, asset
  71556378621665) and Money were the closest Creator Store matches to the
  reference's bright 8–14 kHz shimmer (spectra measured in Studio with
  AudioAnalyzer). A place without CoinPickup falls back to Collect. Alternates to
  try in its SoundId: 73063440685354, 7437419566.
- Reduced motion: no coins. The existing "+N" amount text and CashTick play, and
  the readout updates at once.

Tune `CollectionFeel.CoinBurst`: coin counts and budgets, `Size`, landing `Radius`
and `Spill`, pop `Height`, the `Rise/Fall/Rest/Fly` seconds and staggers, the
flip, the tick sound, `HoldTimeout`, the `Flash` bubble and the `SpillPuff`.

## Yard feel (October 21)

`CollectionFeel.Feel` holds the October 21 game-feel knobs for the yard
([GAME_FEEL_20261021.md](team/GAME_FEEL_20261021.md), F3). Presentation only.

- A laid egg plays `EggLay` (else a quiet Pop) with pitch variance and a tiny poof at
  the chicken, one per `LaySoundGap` within `LayRange`, and grows in from
  `LayPopFrom` with a Back overshoot on the existing settle curve (no per-egg tweens).
- A picked egg (click, tap, R2 or the vacuum) bursts `PickBurst` sparkles where it
  was, one per `PickBurstGap`.
- The held vacuum hums (`VacuumLoop`) and shimmers at the nozzle
  (`VacuumParticleRate`, fewer on touch) while it has room and an egg is in reach or
  flying in. Its bar fills with a flash and punches its count; full, it glows red,
  floats "Full!" and plays `VacuumFull` (else Collect at `VacuumFullPitch`).
- A confirmed Feed: `FeedChicken` crunch (else Collect) at the chicken, crumbs, a
  flash in the rarity colour, a hop (`HopHeight`/`HopSeconds` on Motor6D rigs; V3 rigs
  play their Victory clip) and `ChickenHappy` (else CombatKnockoutCluck at
  `HappyPitch`) after `HappyDelay`. The label floats "Level N!".
- Home chickens within `CluckRange` play `Cluck1/2/3`, one every `CluckGap`.
- A world prompt appearing ticks `UIHover` (`PromptShowGap`); using one rings the
  ground with a Click. My Base lands with a poof, ring, `Whoosh` and a white flash
  when the character jumps `ArrivalJump` studs in one frame.

Missing cues are silent; reduced motion keeps the state changes (fill, text, glow
ring) and drops loops, particles and the hop.

## Reference parity: collecting, the swirl and the pad sale (October 21, P6)

Contract: [REFERENCE_PARITY_20261021.md](team/REFERENCE_PARITY_20261021.md) §2.6, from
Stevin's third Drop a Fruit recording (frames t130–t154 and the 121–131 s vacuum burst).
Presentation only; the server still owns every egg, value and Coin. Knobs live in
`CollectionFeel.Feel` (and `CollectionFeel.CoinBurst` for the sale sounds).

**Each egg that arrives** (a click, tap, R2, mouse hold or the vacuum) plays one short
bright chime and floats its own "+N" with the coin over the player
(`EggController:Arrive`). This replaces the old accumulating "+N eggs · Worth" popup and
the root sparkle.

- Chime: `ChimeCue` ("EggPickup"), else `ChimeFallback` ("Collect"), else silent, through
  `app:Cue`. Pitch starts at `ChimePitch[1]` (0.9) and rises `ChimeStep` (0.04) per chime
  up to `ChimePitch[2]` (1.3); chimes are never closer than `ChimeGap` (0.07 s, also the
  voice cooldown under the `EggChime` voice key, `ChimeVoices` 4 at once), and the streak
  starts over after `StreakReset` (0.6 s) without an egg. `ChimeVolume` 0.22 applies while
  the cue has no `Leveled` attribute; `ChimeTail` 0.35 s trims it. Swap the two cue names
  if Collect turns out to be the brighter tick in Studio.
- Float: `WorldFeel:Text` with `coin=true`, budgeted by WorldFeel (28 desktop / 14 touch
  live effects). N is the server's value for that egg (`drop.value`/the receipt), never
  computed from rates. At most one float per `FloatGap` (0.12 s; `FloatGapTouch` 0.2 s on
  touch-only devices); eggs that land in between join the next float, so the floats add
  up to what was collected. `FloatSize` 26 px, `FloatSeconds` 0.8, `FloatRise` 1.8 studs,
  placed `FloatUp` 2.4 studs above the root and `FloatSide` 0.3–1.5 studs to the camera's
  right. Reduced motion keeps the float without the rise.
- Mouse hold: holding the left mouse button grabs the egg under the pointer every `MouseHoldRepeat` (0.12 s), like R2's hold (no "Get closer" tag on repeats).

**The suction swirl** (`VacuumController`): while eggs are in reach (or flying in) two
yellow ribbons sweep in from the player's sides into the nozzle: Beams from attachments
on the HumanoidRootPart (`SwirlRadius` 4.5 studs out, `SwirlHeight` -1.2) to an
attachment at the nozzle, `SwirlWidth` 2.6 at the outer end, body transparency
`SwirlTransparency` 0.35, a soft texture scrolling toward the mouth (`SwirlSpeed` 1.4) and
one looping tween swaying the curve between `SwirlCurve` 3 and 6 (`SwirlSway` 0.9 s each
way). The nozzle sparkles are gold now. Built once per tool and character and switched
on and off, so it costs nothing per egg; reduced motion turns it off with the hum.

**Selling on the pad** keeps the coin burst. New: a `Whoosh` as the sale starts
(`CoinBurst.WhooshPitch` 1.1, trimmed to `WhooshSeconds` 0.6) and one soft thud as the
first coin meets the floor (`ThudCue` "PodiumThump" at `ThudPitch` 0.85, else "Impact" at
`ThudFallbackPitch` 0.7, `ThudVolume` 0.3 while unleveled), timed `RiseSeconds +
FallSeconds × ThudShare` (0.36, the Bounce ease's first contact) after the launch. The
"+N Coins" float over the Coins readout stays HudController's: a held sale is queued by
the HUD when its balance rises with coins in flight and shown as the last coin lands; a
sale that was never held (reduced motion) is queued once by `ActionFeedback:SaleDelta`
with the receipt's value. The vacuum's egg bar is unchanged (between My Army and the
hotbar; [COLLECTION_TOOLS.md](team/COLLECTION_TOOLS.md)): the P6 pill above the hotbar
was reverted on Stevin's request (2f4daf1).

## Cash: authored Money particle burst

Since October 20, egg sales use the coin burst above. The Money burst stays for
chicken sales, daily rewards, the legacy cash claim and the coin burst's fallback.

Cash collection clones the user's `Money` Attachment from
`ReplicatedStorage.PetRoll.Assets.Money` into the local player's HumanoidRootPart.
The template was moved intact from `ReplicatedStorage.Money`; it remains
Studio-owned. Save the place separately to persist that asset move.

Each clone is centered on the root with an identity local CFrame, because the
imported template has an offset from its original authoring position. Every
descendant ParticleEmitter is disabled for continuous emission and receives one
`Emit(20)` call. The three current emitters are Spec1, Diamonds1 and Money.
Authored textures, colors and other particle settings remain intact; the shared
burst count overrides their individual EmitCount attributes. Debris destroys the
entire clone after one second, including any longer-lived particles.

This replaces the previous CashDrop curve in `Feedback:Cash`. The older
`ReplicatedStorage.PetRoll.Assets.CashDrop` template is retained. Existing cash
receipt routing, sale feedback and the quiet confirmation sound still use the
same presentation entry point; no server collection or currency logic changes.

The `Cash` section has these controls:

- `Count`: particles emitted by each emitter (20).
- `Lifetime`: seconds before the cloned attachment is destroyed (1).
- `Volume`: collection sound volume.

Edit the stored template in Studio to change its particles. Up to three bursts
can overlap. Reset, teardown, character destruction and reduced motion clear
active clones. Confirmation does not depend on effect completion. Reduced motion
uses the existing amount popup.

`Feedback:CashReward` groups exact receipt values. EggController owns receipt
and generation deduplication. The wallet always follows server snapshots;
presentation does not credit cash or change processing.

## Eggs and deposits

Egg pickups retain their existing curved flight and moving-player/nozzle tracking.
`CollectionFeel.Egg` contains those settings. Deposits use the user's
`ReplicatedStorage.EggDepositEffects` Attachment, cloned at the local player's
HumanoidRootPart with an identity local CFrame. Each of its 12 descendant
ParticleEmitters is disabled for continuous emission, then receives `Emit(3)`.
Debris destroys the clone after one second. The authored template stays in place
and unchanged. `CollectionFeel.Deposit.Count` and `Lifetime` hold these settings.
The old deposit egg-sprite flights are removed; there is no fallback to them.

The existing receipt grouping, sound and deposit confirmation remain. Player and
rover deposits both use this attachment; September 29 instant sales mark these deposits paid, so the same receipt also
plays the coin burst (October 20; the Money burst before that). The place currently
lacks `EggDepositEffects`; the burst warns once per session and the sale continues. Saved legacy processor cash uses its
separate confirmed recovery receipt at the deposit pad. Reset/teardown clears active deposit
clones, and reduced motion retains confirmation while suppressing the burst.

Edit EggPickup, EggDeposit and Money SoundIds in
`SoundService.MyChickenArmyAudio.Collection`. AudioController owns preloading,
bounded overlap and the existing Effects mute setting. See [AUDIO.md](AUDIO.md).

CashTick uses the user's Money sound (`rbxassetid://6809101819`), now moved intact
to `SoundService.MyChickenArmyAudio.Collection.Money`. Its editable SoundId is
the source of truth, with the authored 0.25 volume in `Cash.Volume` and normal
playback speed. The full 0.904-second clip
plays on confirmed cash receipts (and the existing sale cue); the old 0.7-second
cutoff was removed. AudioController retains Effects mute, overlap limits,
background preloading and Ended cleanup. Save the place to persist the asset move.

## Verification

The September 28 egg-deposit replacement passed an isolated Edit check through
the synced ActionFeedback source and actual EggDepositEffects attachment:
all 12 emitters execute the three-particle burst on the root, the clone is present
at 0.2 seconds and destroyed by 1.2 seconds with a one-second Debris lifetime,
and no old egg-sprite visual is created. Player/rover receipt routing, reset,
reduced motion and character-removal cleanup passed. The original attachment
remained unchanged. Both runtime modules compile and match disk through Rojo.
No Play/Stop or player-data operations were performed by this change.

The Money revision passed isolated Edit checks using the current ActionFeedback
source, the actual authored attachment, native ParticleEmitter emission and
Debris: root placement, three burst-only emitters, unchanged template, presence
at 0.25 seconds, destruction by 1.2 seconds, bounded repeats, reset, reduced-motion
confirmation and character removal. This is not a gameplay visual review.

Both changed runtime sources compile and match Studio through Rojo. A stale
duplicate CollectionFeel was preserved outside the runtime tree at
`ServerStorage.CashMoneyVFXRecovery20260925.CollectionFeel`; one current copy
remains active. No Play session was started or stopped, and no place save,
publish, upload or player-data change was made.

The Money sound follow-up passed a silent isolated Edit check through the actual
ActionFeedback and AudioController sources: cash confirmation selects the loaded
clip without fallback at volume 0.25/pitch 1, the old cutoff no longer fades it,
Effects mute blocks new voices, and destroying a voice clears its tracking.
An attempted native Ended timing check did not complete in Edit mode; full audible
playback and natural completion remain unverified in gameplay. The existing
Ended/deferred cleanup code is unchanged. No Play session was started.
