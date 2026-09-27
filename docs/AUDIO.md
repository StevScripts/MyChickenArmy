# Editing game audio in Studio

Open **SoundService → MyChickenArmyAudio** in Explorer. Select a Sound and change
its **SoundId** in Properties to `rbxassetid://YOUR_ASSET_ID`. Save the place in
Edit mode so it persists. No script edit is needed.

| Folder | Sounds |
| --- | --- |
| Music | BackgroundMusic |
| Interface | Click, Pop |
| Collection | Collect, EggPickup, EggDeposit, Money, ChickenPurchase, Error |
| Rolling | RollLever, RollTick, RollLand, RollReveal, RollRare |
| Combat | Impact, Victory |
| Fallbacks | Tick, Impact (quiet substitutes while a sound loads) |
| Mix | Music and Effects SoundGroups for the overall mix |

Money is the original authored cash/sale sound, moved intact from
ReplicatedStorage.PetRoll.Assets.Sounds. Each Sound has a `Usage` attribute
describing where it plays and an `AudioCue` attribute used by the existing code.
Keep `AudioCue` unchanged when renaming a Sound or reorganizing its folder.

ChickenPurchase plays on a confirmed chicken purchase, using its authored volume
and playback speed. The generic Pop remains available for the other game cues.
Error plays for failed-action notifications (false or explicit error status),
using its authored volume/speed and the existing Effects mute. Rapid repeats
have a 0.25-second cooldown and replace the previous error voice.

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
All existing gameplay triggers and spatial audio parents remain unchanged.

The library is Studio-owned; the scripts-only Rojo project intentionally does
not overwrite it. `assets/audio/organize_sounds.luau` is the initial migration
and recovery recipe, not the routine editing surface. Rerunning it preserves
existing SoundIds. `assets/audio/checks.luau` contains silent isolated checks
using a disposable cloned library.
