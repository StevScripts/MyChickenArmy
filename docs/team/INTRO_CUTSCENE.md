# First-visit intro cutscene, October 6, 2026

**Off since October 21** (Stevin: the funnel showed about 10% of new players leaving
before the film ended). `Config.Features.IntroCutscene = false`: new players go
straight to the tutorial, the client sends `IntroSkipped` (the funnel's Intro step
still completes), and `TutorialService.IntroPending` no longer holds their eggs.
Settings > Replay Intro is hidden while it's off. Set the flag back to `true` to
restore everything below.

A ~50 second story with five short captions (October 14; `Intro:Caption`), "One Chicken Isn't an Army", plays once for brand-new
`starterArmy` profiles as the loading veil fades. It sets up every Commander Cluck
step before the guide appears. Presentation only: no cash, chickens or progress
are granted, and Skip is available the whole time.

| Time | Scene | Tutorial step it sets up |
|---|---|---|
| 0 to 7s | The Island: aerial into the arena, then a low angle on a 2.6x King (new crown, dust, glint). | The long-term goal |
| 7 to 15s | The Dreamer: egg, glances, then a POV punch-in and speed-line rush from the hero's eyes to the King. "!" and Victory. | The goal, collect eggs |
| 15 to 22s | The Journey: out the gate, cut to the walk up to Cluck Camp. Footstep dust, fidgeting guards. | Cluck Camp location |
| 22 to 27s | The Bonk: nose to nose. Guards turn (surprised, then angry, puffed up); the hero puffs up furious with steam; 3/4 stare-down close-ups; an electric bolt between their eyes while the hero paws the ground; charge, peck, and the guard answers. Hit and launch on the same beat. | One chicken is not enough |
| 26 to 34s | Flight and crash: fast rise, hang, drop; trail, smoke, speed lines; bounce, dizzy stars; friends rush in. | The starter squad |
| 34 to 46s | The Missing Chicken: three in a row, a black "?" in the fourth spot; the hero dashes to the lever, pulls it, a mystery chicken bounces on the ticks and is revealed. | Roll, recruit, Army Size 4 |
| 46 to 50s | Squad complete: the new friend fills the gap, four Victory poses, confetti, hand-off. | Select four, deploy |

## Contract

- **Eligibility** is decided once, on the first loaded snapshot (`saved` or
  `studio-session`): `starterArmy`, no `introSeen`, no tutorial progress, three or
  more pets. Egg pickups during the loading veil cannot disqualify it.
  Established, legacy `emptyStart` and returning saves never see it.
- **Saving:** the client sends `TutorialSignal IntroStarted` once the scene
  resolves. `TutorialService` sets `tutorial.introSeen` (whitelisted in
  `PlayerSession` load) before the film ends, so a crash cannot loop it.
  `IntroFinished` / `IntroSkipped` log `FTUEIntroSeconds`.
- **Eggs wait for the film (October 9):** a brand-new profile's yard lays nothing
  until the film ends or is skipped. `TutorialService` sets a transient
  `session.introHoldUntil` when it first observes an intro-eligible profile
  (180s allowance for loading, reset to 90s on `IntroStarted`).
  `EggService:Produce` returns while `PlayerSession:EggsHeld` is true, so no eggs
  accrue and none arrive in a burst afterward. `IntroFinished` / `IntroSkipped`
  release it, and the client also sends `IntroSkipped` when it will not play the
  film (reduced motion, Studio skip). Nothing is saved; established and returning
  saves are never held.
- **Actors are local clones** in `Workspace.PetRollIntro`. The real starters, guards,
  King, character, chicken tags and live egg sprites are hidden locally and restored.
  `DuckAnimator` animates clones through `Moving`/`PreviewSpeed` and the
  `AttackSerial`/`HitSerial`/`VictorySerial`/`Defeated` attributes.
- **Frozen arena:** a conquest or a fight removes the live King and Royal Flock and
  recolors the flag. At world build, `KingArena:SnapshotIntroSet()` copies the idle
  arena into `ReplicatedStorage.PetRollIntroSet` (never drawn; ~365 parts; tags
  parked in an `IntroTags` attribute so no client manager adopts it). Films clone it
  locally over the hidden live arena (`Intro:StageArena`), stage the King from it,
  and delete it at the end, so every film shows the same idle King whatever the
  server state. Other players, their yard flocks and `Battles` are hidden for the
  film (`Intro:HideOthers`), including anything that spawns mid-film. Hidden GUIs
  collapse `MaxDistance` rather than toggling `Enabled`, so server changes during
  the film still land.
  Lens tests (`Intro:Ignored`) skip actors and effects in `PetRollIntro` but count the
  staged `Arena` clone's walls. The POV rush to the King also runs `Intro:ClearView`:
  any building piece (under 40 studs) still between its final approach and the King
  is hidden for that shot only and restored (`Intro:Show`) at the cut back to the hero.
- **Geometry** comes from the player's plot, lane and the arena at runtime, so all
  six plots get the same film. Cameras are pulled in front of props, slide out of
  scenery, and the POV, King, standoff and lever shots pick the first candidate view
  with a clear line to their chickens.
- **Hand-off:** HUD Shell, CoreGui, prompts, controls and the music loop are held
  until the film ends. The Commander guide's `Ready` timestamp waits for it.
- **Expressions:** the rigs' faces are painted, so `Intro:Brows` adds cartoon brows
  that ride the head bone (moods: neutral, happy, determined, angry, furious,
  surprised, shocked, worried via `Intro:Mood`), plus `Puff`, `Steam` and `Zap`.
- **Audio:** "A Military Action" starts with the film's first frame, at its 3s mark
  (the track is near-silent before that), and plays until the hit, silence for the gag, then "Forward
  Advance". Sound effects are one Sound per moment under
  `MyChickenArmyAudio.Intro/<scene>` (cue `Intro_<Name>`), so each moment's
  SoundId, Volume and PlaybackSpeed can be edited alone. Licensed
  ProSoundEffects/APM IDs; recipe: `assets/audio/add_intro_sounds.luau`.
- Reduced motion skips it. `Config.Features.IntroCutscene=false` disables it.
- **Replay:** Settings > Replay intro calls `Intro:Replay()` (mode `"replay"`): the same
  film with no `TutorialSignal`s. If the starters were sold or merged, any three home
  chickens play the parts.

## Editing and checking in Studio

- Timings and shots: `src/client/IntroCutscene.luau`, `Intro:Run` (one `self:Wait(t)`
  per beat). The October 14 owner decision removed the second (first-camp-win payoff)
  film: players kept seeing it again after the first camp. Only the intro plays.
- Every fresh Studio Play session is a new profile, so the film plays each time.
  Set `workspace.PetRollSkipIntro=true` (Studio only) to skip it while testing other work.
- Framing aid: during Play, set the client's `workspace.PetRollIntroPauseAt` to a
  second mark to hold the film there; change or clear it to continue.
- Occlusion audit: during Play, set the client's `workspace.PetRollIntroAudit=true`
  before the film starts, then read `require(IntroCutscene).AuditLog`. It lists every
  moment something solid sits between the lens and an on-screen actor, or the lens
  is inside scenery. Shots use `Intro:Pick` (first clear candidate view) and every
  cut/dolly slides out of scenery, so other plots' props are avoided automatically.
