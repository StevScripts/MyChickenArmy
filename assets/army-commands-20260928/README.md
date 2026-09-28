# Army command HUD images — September 28, 2026

Original transparent PNGs generated with the chunky-simulator-icons skill; prompts are preserved in `prompts.md`. Imported through the existing Pet Roll Test Studio session under Kiru Experiences. The user completed the soldier upload and supplied the IDs after native computer control failed.

| Button | Theme entry | Roblox Image ID | Source |
|---|---|---|---|
| Call Army | CallArmy | 125964672530167 | call-army.png |
| My Army | ArmyHud | 107457338807219 | ../army-hud-20260927/my-army-soldiers.png |
| My Base | MyBase | 76117843071069 | my-base.png |

MarketplaceService verified the names, Image asset type and creator before hookup. All three references are in `src/client/UITheme.luau`, synced by Rojo, and reported `IsLoaded=true` in a fresh session-only Play. `command-hud-in-studio.jpg` shows the finished row. Labels and the army count remain native editable text.

The earlier functional checks and button-click receipts are in `validation.json`; final image loading is in `asset-validation.json`. No saved-profile writes, place publication or Git push occurred. The Play test was stopped after verification.
