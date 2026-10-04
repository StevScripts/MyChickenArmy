# Galaxy-box asset update — October 4, 2026

Imported Dark Matter and enlarged the unique flying Dragon in the recovered My Chicken Army Studio place. This remains asset staging; the crate is disabled and its rewards are not connected.

## Dark Matter

- Template: `ReplicatedStorage.GalaxyCrateChickenAssets20261002.DarkMatter`.
- World display: `Workspace.DarkMatter`.
- Raw import: `ServerStorage.GalaxyBoxAssetBackup20261004.DarkMatter_Raw`.
- Source: `/Users/stevin/Documents/ChatGPT/My Chicken Army/output/blender/galaxy-feather-wings/exports/dark-matter.glb`.
- Uploaded with the native Studio importer to Kiru Experiences; model import, no package, zero-influence bones preserved, anchored, scene-origin pivot.
- 18 bones retained. Normalized model scale 0.6701631546; visible mesh dimensions 1.702215 × 3.059295 × 2.439394 studs.
- Transparent RootPart is the PrimaryPart at ground level, with RollBoxAttachment and a welded mesh. Local -Z is forward. AnimationController.Animator is ready for later use; source has no animation clips.
- Mesh: `129577825384151`. SurfaceAppearance color: `95940265023674`; normal: `117842521018362`; roughness: `117517959387234`; metalness: `121866529542906`. AlphaMode Transparency preserved; white mesh tint and Precise render fidelity.

## Unique Dragon

- Updated template: `ReplicatedStorage.GalaxyCrateChickenAssets20261002.DragonChickenFlight`.
- Uniformly enlarged 2.5× using Model:ScaleTo, from 4.367734909 to 10.919337273. Mesh height is now 8.75 studs; rest mesh dimensions 10.722733 × 8.75 × 4.427484.
- Original model retained at `ServerStorage.GalaxyBoxAssetBackup20261004.DragonChickenFlight_BeforeEnlargement` and in the October 3 local `.rbxm` backup.
- The original 23 bones and 73-key, 1.2-second native looping flight clip are preserved. Native Animator comparisons at five points in the cycle confirm translation offsets scale by 2.5 and rotations stay equivalent within float precision; see `animation-scale-check.json`.
- The normal-roll Dragon was not changed. Runtime animation publication and purchase/reward integration remain pending.

## Evidence and backup

- `Galaxy-Box-Updated-Lineup.jpg`: actual Studio viewport; left to right Dragon, Alien, Dark Matter, Astronaut. Alien retains its existing unnormalized imported size.
- `Dragon-Downstroke-Check.jpg`: actual Studio viewport at 0.6 seconds in the flight cycle.
- `MyChickenArmy-GalaxyBox-Updated-20261004.rbxl`: complete native local place backup saved after the changes and removal of the temporary screenshot stage.

Camera/UI state restored after capture. No mapped source edits, player-data changes, gameplay playtest, or experience publication.
