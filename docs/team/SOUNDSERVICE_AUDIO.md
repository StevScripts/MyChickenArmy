# Editable SoundService audio — September 26, 2026

User requested all game sounds organized in SoundService and editable by asset
ID in Studio. Scope: AudioController, removal of CollectionFeel's obsolete sound
ID table, audio documentation, and the new SoundService library. Preserve other
dirty files and the existing sound triggers, volume/pitch cues, pooling and mutes.
Cash-feedback ownership was released before this task.

Target: Pet Roll Test 96683186622050, instance:69i-u8j, Edit mode. AudioController
(6505 bytes/hash 2119515551) and CollectionFeel (1380/hash 361489644) each have
one active copy matching disk before editing. SoundService was empty. The only
authored Sound was ReplicatedStorage.PetRoll.Assets.Sounds.Money (6809101819).

Mapped source changes use Rojo. The SoundService library is Studio-owned and is
intentionally outside the scripts-only project mapping.

## Complete — ownership released

Created `SoundService.MyChickenArmyAudio` with Music, Interface, Collection,
Rolling, Combat and Fallbacks folders, plus Music/Effects mix groups. Fifteen
existing cues and a separately editable impact fallback are native Sound objects.
The user's Money instance moved intact to Collection.Money. Its CashTick role is
preserved via AudioCue; all existing IDs and gameplay trigger names are retained.

AudioController now uses authored sounds directly as templates and clones only
playback voices. SoundId edits trigger independent preloads; music replacement
preserves mute state, and stale load completion cannot restart an older track.
Blank SoundId suppresses a cue. Source names can change while AudioCue keeps
routing stable. Mutes affect local cloned mixer groups, whose volumes follow
the authored groups. Existing voice caps, pooling, spatial parents, contextual
volume/pitch, fallback behavior, Ended cleanup and duration limits remain.
Removed CollectionFeel's obsolete ID table; its other dirty changes remain.

38 silent isolated assertions passed using a disposable copy of the library and
bundled clips: authored cue uniqueness, Money preservation, edited ID playback,
blank ID, rename routing, contextual pitch/volume, group edit/mute restoration,
music replacement while disabled, template survival and listener/voice cleanup.
Test-helper issues (looking up a Sound after renaming it; exact comparison of a
float property) were corrected before the final passing run. No authored IDs
were changed by the checks. No Play session or audible playback review occurred.

Rojo build/diff checks passed. AudioController (7367 bytes/hash 2028496561) and
CollectionFeel (1159/hash 1216983037) compile and match Studio, one active copy
each. Final scene readback confirmed all 16 IDs, no playing source sounds, Money
removed from the old folder, and no test fixtures left behind.

Guide: docs/AUDIO.md. Migration/recovery recipe: assets/audio/organize_sounds.luau.
No uploads, purchases, publishing, place save, commits or pushes. The new
Studio-owned library must be saved with the place; local source/docs/recipe are
already saved. SoundService folder selected for the user in Explorer.

## Chicken purchase cue — September 26 follow-up

User added Collection.ChickenPurchase with SoundId 77584650945481, Volume 0.5
and PlaybackSpeed 1. Assigned AudioCue=ChickenPurchase and the authored Effects
group; preserved the SoundId/settings and all of the user's other sound edits.
ActionFeedback's successful Buy cue now uses this Sound instead of Pop, with no
pitch/volume override or old 0.85-second action cutoff. Existing purchase receipt
deduplication, feedback cooldown and Effects mute remain. Other action cues stay
unchanged. Updated the recovery recipe and sound guide; library now has 17 cues.

One active ActionFeedback copy matches disk (12705 bytes/hash 1077005336) and
compiles. A silent call-through check confirmed ChickenPurchase routing,
authored-setting preservation, repeated-call suppression and unchanged Income
audio. No live purchase, audible playback, Play/Stop, save or publish. The user's
current Play session remains running; restart Play to load the updated module.

## Error notification cue — September 26 follow-up

User added Collection.Error (87519554692663, volume 0.5, speed 1). Assigned the
stable Error AudioCue and Effects group without changing its ID/settings or any
other authored sounds. AppController.Notify plays it for false/explicit error
status, retaining authored volume and pitch. Other notification kinds and empty
messages stay silent. Repeated failed attempts use a shared ErrorNotification
voice and 0.25-second cooldown, respecting Effects mute. The library now has
18 cues; the audio guide, migration recipe and inventory check reflect this.

One active AppController matched disk (38653 bytes/hash 1294382901) and compiled.
A silent check of the actual Notify method confirmed false/explicit errors,
non-error/empty suppression, repeated-attempt routing and authored-setting
preservation. Existing dirty AppController work remains intact. No Play session,
real audio preview, place save or publish was performed for this change.
