# Galaxy masking assets and checks

The four inert zero-alpha mesh templates are Studio-owned at
`ReplicatedStorage.PetRoll.GalaxyViewportAssets`. They are outside scripts-only
Rojo builds. `install-assets.luau` reproduces them in the canonical Edit place
without loading any third-party scripts. The existing Galaxy rig is unchanged.

Technique and demo geometry/textures: **6mikael6**, [ViewportFrame Masking](https://devforum.roblox.com/t/viewportframe-masking/2964839).
The reference place was downloaded and decoded for inspection; its scripts were
not executed. This implementation uses its zero-alpha plane technique with the
game's own chicken, local quality budget, pose synchronization and fallback.

The foreground atlas regions are derived from the game's exact Galaxy mesh
`90513010317322` and existing texture `88919583329083`. They preserve only the eyes
(including highlights) and beak. The wattle, legs and feet share the whole-body
galaxy effect in the same ViewportFrame. A different mesh must fall back until its
mask is authored.

- `quality-checks.luau`: deterministic quality policy checks using the local Luau CLI.
- `integration-checks.luau`: focused Studio Edit checks with temporary unparented
  models; static allocation, shared ownership, material restoration, cancelled
  loads and retained-image cleanup. No player profiles are involved.

New templates are installed in the open Edit place and preserved with the full
game in `MyChickenArmy-Galaxy-Integrated-20261002.rbxl`. This is a local place
snapshot, separate from Rojo script sync; it was not published to Roblox.
`galaxy-in-game.jpg` shows the actual yard actor with the masked tier selected for
the visual check. No asset upload is required by this setup.

The later Character2 clip correction is included in the same local place copy.
`galaxy-reference-match-a.jpg` and `galaxy-reference-match-b.jpg` show two running
phases of the corrected bright cloud/star field. Those historical shots suppressed
the external aura. The later VFX/overlap correction restores it alongside the mask
and hosts the viewport in a world-depth SurfaceGui instead of the screen overlay.

Reopened-place repair: the cloud place initially lacked these templates because
the first delivery only saved the local snapshot. The four templates were
restored to Pet Roll Test on October 2 and saved with Studio **Save to Roblox**.
Studio confirmed the save; this does not publish the experience. The asset folder
remains Studio-owned and must be preserved alongside the scripts when saving.
`galaxy-repaired-quality8.jpg` shows the real yard actor after this repair, using
the user's requested graphics level 8 and the unmodified runtime quality policy.
