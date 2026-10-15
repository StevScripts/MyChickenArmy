# Chicken UI Lab

A Studio plugin for previewing the game's real UI in Edit mode, tweaking it with
Explorer/Properties, and saving the tweaks as a change list an agent applies to the
source. Similar in spirit to UI Labs, built for this project's single `PetRollGui`.

## Install

The plugin source is `tools/ui-lab/` (not part of the game sync). Build it into the
local Plugins folder, then restart Studio:

```
.tools/rojo build tools/ui-lab/default.project.json -o ~/Documents/Roblox/Plugins/ChickenUILab.rbxm
```

The toolbar shows **Chicken Army → UI Lab**. The plugin is a thin shell: stories and
sample data load from `ServerStorage.PetRoll.UIAuthoring` (synced by Rojo) on every
render, so code changes need **Reload stories**, not a reinstall.

## Use (Edit mode)

1. **Sample data**: Late game (Test everything), Starter sample, or a state you captured.
2. **Device**: PC 16:9, Phone 19.5:9 or Tablet 4:3 (a yellow outline marks the screen).
3. **Story**: HUD, My Army, Shop, Index, Upgrades tree, Fuse, Rebirth,
   Invasions/Missions, Daily reward, Offline earnings, Settings. The real client modules
   render under `StarterGui.PetRollGui.MenuLayouts.UILab` (hidden at runtime with
   MenuLayouts). The Lab turns on `StarterGui.ShowDevelopmentGui` while open and
   restores it on close.
4. **Easy edit** (on by default) bakes the preview into plain positions: it measures
   everything, removes layout helpers (UIListLayout, UIGridLayout,
   UIAspectRatioConstraint, UISizeConstraint, UIPadding, UIScale) and hoists invisible
   wrapper Frames into their parents, renumbering ZIndex so the draw order stays the
   same. It looks identical (checked: under 1 px drift on every story) but every element
   can be dragged and resized freely. Turn it off to inspect the exact code layout.
   The game code keeps its layouts; they are what make menus fit phones and lists scroll.
5. **Tweak** anything with Explorer/Properties or by dragging in the viewport
   (Select story in Explorer helps), optionally write a note, then **Save tweaks**.
6. Tell the agent: "apply my UI Lab tweaks". Save the place to keep unapplied tweaks.

Buttons are not clickable in Edit mode; test interactions in Play.

## Capture any game state (Play mode)

During Play the panel shows **Capture this state**. It saves the client's latest game
state as a named preset in plugin settings (up to 8). Stop Play and pick it under Sample
data. Delete captured presets from the same panel.

## How tweaks are stored

Each save adds `ServerStorage.UILab.Tweaks.<UTC stamp>_<story>` (StringValue, JSON;
attributes `Status`, `Story`, `Changes`):

```json
{"story":"Rebirth","preset":"Late game (Test everything)","device":"Phone","note":"…",
 "status":"new","changes":[
  {"kind":"changed","path":"Story/Reenlist/FRAMES/Reenlist/Header/Title","class":"TextLabel",
   "property":"TextColor3","from":"Color3.fromRGB(255,251,233) #FFFBE9","to":"Color3.fromRGB(255,0,0) #FF0000"}]}
```

`kind` is `changed`, `added` (with all props) or `removed`. Values are Luau literals.
Paths start at the story root and use instance names; repeated sibling names get `[n]`.
Records saved in Easy edit have `"mode":"easy"`: their `path` is the flattened path and
`originalPath` is where the element lives in the code-built tree; `screenRectBefore` /
`screenRect` give its place on the device screen as fractions (x, y, w, h). Apply easy
moves by matching the final screen rectangle in the code's own layout (adjust the
layout's padding/order/size, or replace that layout with explicit Scale positions when
the owner's arrangement no longer fits a list).

## Applying tweaks (agents)

1. Read records whose `Status` attribute is `new` (Studio MCP, Edit DataModel).
2. Find the code that builds each path: the story's module (`LabStories.luau` lists
   which) and the instance names in the path (grep the `Name` strings). Shared pieces
   (`UITheme.Header`, `HeaderClose`, buttons) change every menu; prefer the
   screen-specific call site unless the owner's note says "everywhere".
3. Menu outer Size/Position belongs to `StarterGui.PetRollGui.MenuLayouts.<Menu>`
   (Studio-owned) rather than code; see `docs/UI_EDITING.md`.
4. Follow AGENTS.md UI rules (single PetRollGui, Scale geometry, stud sheet, black
   chicken outline, TweenService). Re-render the story to confirm, then set the
   record's `Status` attribute to `applied` (keep the record).

## Files

- `src/server/UIAuthoring/Lab.luau`: mount/unmount, snapshot, diff, save.
- `src/server/UIAuthoring/LabStories.luau`: one adapter per screen (add new screens here).
- `src/server/UIAuthoring/LateGameState.json`: late-game state captured from Test everything.
- `tools/ui-lab/`: the plugin shell.
