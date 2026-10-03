# Editing game audio in Studio

Open **SoundService → MyChickenArmyAudio** in Explorer. Select a Sound and change
its **SoundId** in Properties to `rbxassetid://YOUR_ASSET_ID`. Save the place in
Edit mode so it persists. No script edit is needed.

| Folder | Sounds |
| --- | --- |
| Music | BackgroundMusic |
| VFX / UI | Hover, Click, Pop, Purchase, Error |
| VFX / SkillTree | Hover, Purchase, Error, NodeAdded, NodePop, ResearchStarted, ResearchCompleted, ResearchSlotAdded, Open, Close |
| Collection | Collect, EggPickup, EggDeposit, Money |
| Rolling | RollLever, RollTick, RollLand, RollReveal, RollRare |
| Combat | Impact, Victory |
| VFX | Named chicken effect loops (Galaxy, Rainbow, Glitch, Magma, etc.) and GlitchBurst |
| Fallbacks | Tick, Impact (quiet substitutes while a sound loads) |
| Mix | Music and Effects SoundGroups for the overall mix |

Money is the original authored cash/sale sound, moved intact from
ReplicatedStorage.PetRoll.Assets.Sounds. Each Sound has a `Usage` attribute
describing where it plays and an `AudioCue` attribute used by the existing code.
Keep `AudioCue` unchanged when renaming a Sound or reorganizing its folder.

VFX/UI/Purchase plays on a confirmed chicken purchase or cash upgrade, using its authored volume
and playback speed. The generic Pop remains available for the other game cues.
Error plays for failed-action notifications (false or explicit error status),
using its authored volume/speed and the existing Effects mute. Rapid repeats
have a 0.25-second cooldown and replace the previous error voice.

UI and SkillTree sounds are independently editable. Existing Click, Pop, purchase
and error Sound objects retain their IDs/settings in VFX/UI; SkillTree Purchase
and Error start with copies of those IDs. New cues begin empty and remain silent
until configured. SkillTree/NodeAdded plays once for a progression reveal wave,
not for reopening the tree. **NodePop** plays once as each node starts its staggered
opening scale tween. Set its SoundId to a short pop/tick; it starts blank. Every
node triggers without the usual cooldown, with four overlapping voices and a
0.35-second tail limit. Closing or cancelling the tween cancels pending pops;
reduced motion skips the animated sequence and these pops. Existing Effects mute
and template Volume/PlaybackSpeed apply. ResearchSlotAdded is a separate cue for increased
researcher capacity, excluding the initial state load. Purchase/ResearchStarted
wait for successful server replies; denied purchases use Error. Hover supports
mouse and gamepad focus, including dynamically created buttons, respects hidden
and inactive controls, and is lightly throttled. `add_ui_sounds.luau` is the
idempotent authoring recipe; it preserves customized IDs on rerun.

The controller uses these actual Sound objects as templates. New effects pick
up a changed SoundId, and changing BackgroundMusic's ID replaces its playback
copy without turning music back on for a player who muted it. Blank SoundIds
silence their cue. Source Volume/PlaybackSpeed apply unless the calling effect
supplies an existing contextual override. SoundGroup volumes are editable and
remain respected after toggling Effects off/on.

`SoundService.PetRollAudio` appears during Play and contains temporary playback
copies and local mix groups. Edit **MyChickenArmyAudio**, not these copies.
Stop Play before making permanent edits; test-session changes are discarded by
Studio. New audio IDs must be available to this experience for playback.

Runtime owner: `src/client/AudioController.luau`. Egg/cash timing and contextual
volumes remain in `src/shared/CollectionFeel.luau`, which no longer stores IDs.

Chicken VFX sounds initially have empty SoundIds because these visuals previously
had no audio. Set their SoundIds under **MyChickenArmyAudio → VFX**. Each named
chicken cue loops spatially while its VFX are visible within 42 studs; GlitchBurst
is a separate one-shot synchronized with its breakup. Effects mute, Reduced Motion,
hiding, defeat, distance and destruction stop the loops. At most eight VFX loops
play together, reserving capacity for normal game sounds. Empty/missing VFX cues
never substitute clicks. Edited IDs replace an active loop; Volume/PlaybackSpeed
updates are respected. `SpecialChickenVFX` requests playback through the existing
AudioController supplied by DuckAnimator. `assets/audio/add_vfx_sounds.luau` can
restore the authoring placeholders without overwriting custom IDs.

October 3 delivery: 20 VFX templates authored and saved to Roblox (unpublished)
at 03:41:24 UTC. Scoped silent checks passed for blank/missing cues, spatial-loop
reuse, hiding, mute, eight-loop capacity and destruction, plus the actual
SpecialChickenVFX named-cue call. Four changed modules compiled and matched their
Studio copies by byte length/hash. No new audio asset was uploaded.
All existing gameplay triggers and spatial audio parents remain unchanged.

The library is Studio-owned; the scripts-only Rojo project intentionally does
not overwrite it. `assets/audio/organize_sounds.luau` is the initial migration
and recovery recipe, not the routine editing surface. Rerunning it preserves
existing SoundIds. `assets/audio/checks.luau` contains silent isolated checks
using a disposable cloned library.
