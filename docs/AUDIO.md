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

## October 21: Stevin's own sound library (current, supersedes the IDs below)

Later on October 21, 2026 Stevin replaced the game's sounds himself in
`SoundService.MyChickenArmyAudio` and said he likes them. That library is the
approved one: **do not re-source, restyle or re-level any sound** unless he asks.

- Snapshot: `assets/audio/library_20261021.json` (all 143 Sounds: path, cue,
  `SoundId`, Volume, PlaybackSpeed, Looped, PlaysWhen). 32 of the IDs appeared nowhere
  in the repo before, among them EggLay, LevelUp, VacuumFull, EggDeposit, CaptureTick,
  FlagRaise, MarchStart, MissionWin, PodiumThump, RollRare/Legendary/Mythic/Secret, the
  Upgrades NodeAdded/NodePop cues, the music tracks and several intro moments.
- Every Sound carries `OwnerApproved = "2026-10-21"`. `add_feel_sounds_20261021.luau`
  and `level_feel_sounds_20261021.luau` skip OwnerApproved Sounds entirely (checked in
  Studio Edit: both ran with 0 property changes); the other `add_*` recipes only create
  missing Sounds. A Sound added later without the attribute is treated as before.
- If an unsaved session loses his picks: `assets/audio/restore_library_20261021.luau`
  puts the snapshot back (instructions in the file), then save the place.
- The library is Studio-owned: it only persists when the place is saved.

The sections below record how the earlier IDs were chosen; the IDs they name are
history where the snapshot differs.

## October 21 game-feel cues

(The families and volumes below describe the first, v1 version of the recipe. The
"Pet Simulator-style restyle" section further down supersedes them: same cues, same
attributes, bubblier sounds and lower event levels.)

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

## October 21 Pet Simulator-style restyle

Later on October 21 Stevin set the target character for the whole cue set: Pet
Simulator 99 / X (BIG Games). Bright, bubbly, candy-like and satisfying: soft
pop/tock clicks, tiny blip hovers, bubbly pops for pickups, coin plings that rise in
pitch, sparkly shimmers, a pop-plus-sparkle egg-hatch feel for reveals, cash-register
chimes for purchases, crystal tings for Gems, a magical rising sparkle for level-ups,
boop notifications, whoosh-plus-fanfare for big events. Nothing harsh, sci-fi, wooden
or industrial. Sound-alikes only: never a Creator Store re-upload of Pet Simulator's own
audio (names like "Pet Sim X hatch"), because Roblox moderates those and they go silent
in the live game.

`assets/audio/add_feel_sounds_20261021.luau` is now the v2 (restyle) recipe. Paste it
into the Command Bar in canonical Edit mode and run it once. For each cue it:

- creates the Sound if missing, or fills a blank `SoundId`, as before;
- otherwise replaces the `SoundId` **only** when the Sound has no
  `Restyled = "PetSim-20261021"` attribute **and** its current id is one the recipe
  wrote earlier (the v1 id, or for the older `Click`, `Pop` and `SkillTree*` cues the
  id the first recipes set). Any other id is Stevin's own pick and is left alone
  (reported as "kept");
- before replacing, stores the old id in a `Previous` attribute and sets
  `Restyled = "PetSim-20261021"`, and sets the new `Volume` and `PlaybackSpeed`
  (pitch is part of the style: a few clips run at 1.1-1.3);
- keeps the `Alternate` attribute (a second verified id to try by hand).

Levels (Stevin, live listening): event cues (Gold Rush, Missions, Rebirth, reveals,
fanfares) stay under about 0.35 and must never startle; ambient and world cues (lays,
clucks) stay under about 0.25. Three cues are Stevin's own live picks, already in Studio
with a `Previous` attribute, and the recipe recognises them and never re-sources them:
`EggLay` = `rbxassetid://9116312491` (PSE "Lip Pops Dry Plosive Short Snaps 2", 0.45 s)
at Volume 0.14, because the cartoon plop sounded out of place; `GoldRushStart` =
`rbxassetid://9126076118` (PSE "Synth Sparkle Tone Burst Ding 15", 0.74 s) at Volume
0.22, because the rising power-up was too loud and startling; `GoldRushEnd` =
`rbxassetid://9116418035` (PSE "Magic Tone Falling Shimmer Flanged 3", 3.29 s) at
Volume 0.2.

Reruns change nothing: a Sound marked `Restyled` is skipped even if its id was edited
afterwards. To revert one cue, paste its `Previous` attribute back into `SoundId`
(and clear `Restyled` if you want a later recipe run to touch it again). The cues the
recipe deliberately leaves on their v1 sound are listed in the recipe header. Stevin's
own picks (Collection/Money, CoinPickup, CoinDrop, EggPickup, EggDeposit, Collect,
VFX/UI/Purchase, VFX/UI/Error, Combat/*, CallArmyWhistle, Intro/*, Music/*, and the
five tuned Rolling cues RollLever/RollTick/RollLand/RollReveal/RollRare) are never
touched by this recipe.

The library is Studio-owned; the scripts-only Rojo project intentionally does
not overwrite it. `assets/audio/organize_sounds.luau` is the initial migration
and recovery recipe, not the routine editing surface. Rerunning it preserves
existing SoundIds. `assets/audio/checks.luau` contains silent isolated checks
using a disposable cloned library.

## October 21 level pass (measured, not guessed)

Every game-feel cue was measured in Studio Edit with an `AudioPlayer → Wire →
AudioAnalyzer` chain (no device output wired, so the measurement is silent):
the peak level of each clip at Volume 1 over its length. Each Sound's Volume was
then set to `target ÷ measured peak` so the effective peak (peak × Volume) lands on
its family's target, and the Sound carries `MeasuredPeak`, `TargetPeak` and
`Leveled="Oct21-analyzer"` attributes. Targets: hover 0.09, count ticks 0.11, UI
clicks/pops/toggles 0.18–0.22, confirms/claims/notices 0.20–0.22, purchases 0.25–0.28,
reveal stingers/fanfares 0.25–0.28, chicken level-up 0.22, ambient clucks 0.10, egg
lay 0.05, vacuum loop 0.08. Stevin's own picks (Money, CoinPickup, CoinDrop, EggPickup,
EggDeposit, Collect, ChickenPurchase, Error, the Rolling lever/tick/land/reveal/rare
cues and his Gold Rush start/end) were not re-leveled.

Clips that measured near-silent (peak under 0.1 at Volume 1) were swapped for their
alternates and the old id kept in `Previous`: UIHover and SkillTreeHover → GladGhost6
`ui_hover_bubble_pop_02` (79315763728779); Lock → CoreKit `wood_toggle`
(90515507208380); Shimmer → `Glitter Sparkle Magic Sound` (117011707307950); Rebirth →
PSE `Magical Exit Sparkling Pass Bys Clinking Chimes 4` (9125635297); LevelUp →
`Chat Progress` (1293433423); PodiumThump → `bounce1` (138910257412285); RollMythic →
APM `Stunning Sting` (1836477530); EggLay → `Roblox GUI - Bubble` (17208204604) at
Volume 0.21 (effective peak 0.05: quiet on purpose). The loudest offenders before the
pass were SkillTreeOpen (0.85), SkillTreeNodeAdded (0.75), SkillTreeClose (0.53),
TierUp (0.42) and Pop (0.40).

`AudioController:Play` now ignores a caller's `volume` override for any Sound with the
`Leveled` attribute (pass `forceVolume=true` to insist), so screens cannot push a
leveled cue past its target; unleveled cues keep their contextual overrides. To
re-level after swapping a clip: measure its peak the same way and set Volume =
target ÷ peak, or clear `Leveled` to let code overrides apply again.

### Spectral pass (same day)

Each cue's spectrum (`AudioAnalyzer:GetSpectrum()`, 512 bins, 0–24 kHz) was summed
over its length into four bands: below 2 kHz, 2–6, 6–12 and above 12 kHz. A cue was
treated as piercing when more than a fifth of its energy sat above 12 kHz or most of
it above 6 kHz, and it was swapped for a warm clip of the same role (old id kept in
`Previous`): GoldRushStart → `crystal fx` 79130903404606 (74 % below 2 kHz, Volume
0.40, effective peak 0.07; the sparkle ding had 68 % above 12 kHz), Confirm → Roblox
GUI `Send` 17208399163 (Volume 0.55; `Success Correct` had 25 % above 12 kHz), GemGain
→ `gem collect` 11439707919 (Volume 0.33; `DiamondCollect` had 80 % above 6 kHz).
Kept bright by design: Shimmer, GoldRushEnd (falling shimmer), MutationHit (arcade
sparkle), CountTick (a 0.18 s tick at effective peak 0.11). Everything else is
dominated by energy below 2 kHz. The near-silent Roblox "RBLX UI" / "Roblox GUI"
hover clips and `UI_Tick` (peak ≤ 0.01) are unusable as cues.

### Reapplying the level pass; two later calls (Oct 21, evening)

Studio was reopened from a save made before the level pass, so the measured Volumes
and swaps were reapplied in the open session. `assets/audio/level_feel_sounds_20261021.luau`
is the durable copy: paste it into the Command Bar after the add recipe whenever
`VFX/UI/MenuOpen` has no `Leveled` attribute. Two later calls from Stevin are baked in:

- **Feed** is a normal chicken upgrade chime, not a munch: `FeedChicken` uses the TierUp
  clip (`Upgrade` 135996502799215) pitched 1.1 at Volume 0.22.
- **No whoosh on every UI tween:** `MenuOpen`, `MenuClose`, `SkillTreeOpen` and
  `SkillTreeClose` are the soft `Roblox GUI - Bubble` pop (17208204604; in at 1.05×, out
  at 0.85×, effective peaks 0.13 / 0.11), `TabSwitch` is `Roblox_UI_Bright_Click`, and the
  flyer/teleport `Whoosh` stays but at half its level (0.10). The Roblox UI whoosh ids are
  kept in each Sound's `Previous` attribute.
