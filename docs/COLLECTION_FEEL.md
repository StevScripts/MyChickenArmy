# Egg and cash feedback

Tune `src/shared/CollectionFeel.luau`, then restart Play. ModuleScripts are cached.

## Cash: authored Money particle burst

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
plays the authored Money burst and sound. Saved legacy processor cash uses its
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
