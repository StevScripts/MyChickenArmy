# Editing game audio in Studio

Open **SoundService → MyChickenArmyAudio** in Explorer. Select a Sound and change
its **SoundId** in Properties to `rbxassetid://YOUR_ASSET_ID`. Save the place in
Edit mode so it persists. No script edit is needed.

| Folder | Sounds |
| --- | --- |
| Music | BackgroundMusic |
| VFX / UI | Hover, Click, Pop, Purchase, Error; October 21 game-feel cues MenuOpen, MenuClose, TabSwitch, Toggle, Locked, Select, Equip, Unequip, Lock, Unlock, Confirm, Claim, Jingle, CountTick, Badge, Shimmer, Whoosh, Fanfare, Rebirth, GemGain, GoldRushStart, GoldRushEnd, NoticeIn |
| VFX / SkillTree | Hover, Purchase, Error, NodeAdded, NodePop, ResearchStarted, ResearchCompleted, ResearchSlotAdded, Open, Close; October 21 UpgradeMax, TierUp |
| Collection | Collect, EggPickup, EggDeposit, Money; October 21 EggLay, VacuumLoop (Looped), VacuumFull, FeedChicken, LevelUp, Cluck1, Cluck2, Cluck3, ChickenHappy |
| Rolling | RollLever, RollTick, RollLand, RollReveal, RollRare; October 21 RollEpic, RollLegendary, RollMythic, RollSecret, MutationHit, AutoRollHit, PodiumThump |
| Combat | Impact, Victory, plus fight feedback `CombatHit`, `CombatSwing`, `CombatKnockout`, `CombatKnockoutCluck` (recipe: `assets/audio/add_combat_sounds.luau`; played by `client/CombatEffects.luau`, positioned at the fight). Kills no longer play `Collect`. October 21 MarchStart, CaptureTick, MissionAppear, MissionWin, MissionLose, FlagRaise. |
| MyChickenArmyAudio root | CallArmyWhistle |
| Intro / 1_Island … 8_CampPayoff | First-visit cutscene: one Sound per moment, grouped by scene (AudioCue `Intro_<Name>`). Volume and PlaybackSpeed are read from each Sound. Recipe: `assets/audio/add_intro_sounds.luau`. |
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

Call Army plays the existing `MyChickenArmyAudio.CallArmyWhistle` only after the
server accepts the command. Its playback volume is 0.18 instead of the authored
0.5; the Effects mute and mix still apply. The old HUD click does not accompany
the whistle. A locked or rejected command does not sound the whistle.

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

## October 21 game-feel cues

The October 21 game-feel pass (`docs/team/GAME_FEEL_20261021.md` §3) adds 48 cues;
`assets/audio/add_feel_sounds_20261021.luau` authors them. Paste the file into the
Command Bar in canonical Edit mode and run it once (loadstring is disabled in Studio).
It creates each missing Sound under VFX/UI, VFX/SkillTree, Collection, Rolling or
Combat with Name = cue, attributes `AudioCue` = cue and `Usage`, a free Creator Store
`SoundId` that passed a preload check (IsLoaded, TimeLength) on October 21, a starting
`Volume`, `PlaybackSpeed` 1, the Mix.Effects group, and `Looped` only on VacuumLoop.
It also fills the blank `VFX/UI/Hover` (`UIHover`). Reruns fill blank or missing
cues only; a customised SoundId is skipped and the summary says so. Each Sound also
carries an `Alternate` attribute naming a second verified id to try by hand.

Families, by the recipe's design note: UI ticks, swipes and pops come from Roblox's
own free "Roblox GUI" / "RBLX UI" set; locks, toggles, thumps, flags and the Rebirth
boom are ProSoundEffects foley; stingers, fanfares, bugles and the loser sting are
APM; clucks are real-ish Creator Store chicken clips (play with `pitchVariance`).

| Cue | Plays for | Volume |
| --- | --- | --- |
| UIHover, CountTick | Hover/focus tick; count-up ticks (0.05 s, pitchVariance) | 0.20-0.22 |
| MenuOpen, MenuClose, TabSwitch, Toggle | Menu/panel open and close, tab change, switches | 0.30-0.40 |
| Locked | A locked or unaffordable control: soft nope, not Error | 0.35 |
| Select, Equip, Unequip, Lock, Unlock | Card marking, Army join/leave, chicken lock toggles | 0.35-0.45 |
| Confirm, Claim, Jingle | Confirm bars, reward claims, short success jingle | 0.45 |
| Badge, NoticeIn, Shimmer, Whoosh | Badge appears, corner notice, sparkle sweep, flyers/slides | 0.30-0.35 |
| Fanfare, Rebirth, GemGain, GoldRushStart, GoldRushEnd | Big win, Rebirth boom, Gems, Gold Rush start/end | 0.45-0.60 |
| EggLay, VacuumLoop, VacuumFull, FeedChicken, LevelUp | Lay plop, vacuum hum loop (0.20), bar-full ding, feed crunch, level-up | 0.20-0.50 |
| Cluck1-3, ChickenHappy | Ambient and happy clucks, spatial via `PlayAt`, pitchVariance | 0.25 |
| RollEpic, RollLegendary, RollMythic, RollSecret | Tiered reveal stingers; RollReveal/RollRare are unchanged | 0.50-0.60 |
| MutationHit, AutoRollHit, PodiumThump | Mutation tag, Auto Roll stop banner, podium landing | 0.40-0.50 |
| UpgradeMax, TierUp | A track reaches MAX; a tier bought | 0.45-0.50 |
| MarchStart, CaptureTick, MissionAppear, MissionWin, MissionLose, FlagRaise | Army sets off (bugle), conquest ticks, Mission appear/win/lose, flag up | 0.30-0.50 |

To retune, change `Volume`, `PlaybackSpeed` or `SoundId` on the Sound in Explorer
and save the place; the controller reads templates live. To try the alternate, paste
the id from the `Alternate` attribute into `SoundId`. A cue no code calls yet just
sits in the library; clearing a `SoundId` silences that cue (`audio:Has` goes false).

The library is Studio-owned; the scripts-only Rojo project intentionally does
not overwrite it. `assets/audio/organize_sounds.luau` is the initial migration
and recovery recipe, not the routine editing surface. Rerunning it preserves
existing SoundIds. `assets/audio/checks.luau` contains silent isolated checks
using a disposable cloned library.
