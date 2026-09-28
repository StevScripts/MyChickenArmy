# My Army bottom-center HUD — September 27, 2026

User direction: replace the top My Army button with one standalone chicken icon at the bottom center, using the chunky-simulator-icons style and the supplied bottom-navigation screenshot as inspiration.

## Implemented, imported and verified in Play

September 28 completion: the user completed the soldier image import. `Theme.Assets.ArmyHud` now uses `rbxassetid://107457338807219`, verified through MarketplaceService as the `my-army-soldiers` Image owned by Kiru Experiences. A fresh Play session confirmed `IsLoaded=true` and visibly rendered the three helmet chickens centered between Call Army and My Base. Screenshot: `../army-commands-20260928/command-hud-in-studio.jpg`. Earlier upload failures below are historical; do not re-upload the successful asset. Companion icon IDs and behavior are recorded in `docs/team/ARMY_COMMANDS.md`.

- `my-army-chickens.png`: initial generated squad of three boxy white chickens.
- `my-army-soldiers.png`: final artwork, edited with the built-in image-generation tool so all three chickens wear green soldier helmets. Transparent RGBA PNG, 1254 × 1254, visible black silhouette outlines, no baked label or count.
- `ICON-PROMPT.md`: exact prompt and reference roles.
- `HELMETS-PROMPT.md`: exact soldier-helmet edit prompt.
- `HudController.before.luau`: source snapshot when preparing the change.
- `HudController.proposed.luau`: proposed complete module.
- `bottom-center-hud.patch`: reviewable change against that snapshot.

The applied layout uses the existing `UITheme.IconButton` and `TogglePage("Army")` action. Artwork sits over native My Army text, with the selected/deployed count on its own smaller line. The control is centered in the device-safe area and uses a smaller footprint on narrow/short screens. Existing status/objective copy remains at the top. Narrow-screen side counters use raised placement to reserve the bottom center. Shared hover/press/pop motion remains unchanged.

`Theme.Assets.ArmyHud` is reserved for the new uploaded image; the HUD falls back to `Theme.Assets.Army` until that asset exists. The existing Army popup asset remains unchanged. Apply the successful new upload only to the HUD-specific asset entry. The fallback helmet did not load in this session; InsertService reported that the existing asset was not trusted for this place. Do not treat the current fallback as a verified visible icon.

`src/client/HudController.luau` is applied through Rojo. Studio readback matched the local source exactly, and both HudController and UITheme compiled. PRODUCT.md and DESIGN.md in the design workspace now record the bottom-center direction. The saved before/proposed files and patch record the original implementation change. Unrelated dirty files were preserved.

Focused checks:

- Pet Roll Test, place 96683186622050, used its existing `PetRollPlaytestSessionOnly=true` setting. No saved player profiles were changed.
- In Play, native computer-use click on bottom-center My Army opened `Your Chickens!`; B opened/closed it. Native label and live `3/8` count appeared at the bottom center.
- Disposable UI fixture checked 1920×1080, 1280×720, 844×390, 390×844 and 320×568. The button remained centered and inside the screen, and the label fit. Selected `3/8` and deployed `2/8` count cases passed. The fixture was destroyed.
- Playtest stopped; Studio returned to Edit. Existing unrelated animation/asset access errors were observed.
- `git diff --check` passed for HudController.

Upload blocker: Studio Asset Manager's PNG import returned HTTP 401 / code 9002, `User is not authenticated`. No successful new asset ID was obtained. The user explicitly said not to log in, so no authentication or account changes were made. Studio's alternative property picker did not open reliably through computer use. A user-assisted Studio import/asset ID was requested. No new image is claimed to be live.

No place save/publish or Git commit/push was performed. Remaining work: successful Studio upload of `my-army-soldiers.png`, set `Theme.Assets.ArmyHud` to the returned usable image ID, then confirm the new image loads in Play.

## Recovery and later import attempt, 20:18–20:22

Recovered the user's missing Studio content into Pet Roll Test, including the eight new chickens and 40-display workbench, and saved a full local backup. Studio confirmed a cloud save at 20:18:23 under the note `Restore September 27 chicken work`; nothing was published. See `docs/team/SESSION_RECOVERY_20260927.md`.

Retried the PNG through Asset Manager in the reopened Studio session. The native file chooser selected this exact `my-army-soldiers.png`; after Open, computer-use calls to Studio repeatedly timed out, including an attempt to dismiss with Escape. Studio Flow still confirmed 40 chicken templates, 40 workbench displays, and the bottom-center HUD source. No successful image-upload receipt or asset ID was obtained. ArmyHud remains pending, and the fallback asset limitation above still applies. Do not repeat generation or roll back the restored game.
