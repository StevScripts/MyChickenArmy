# Native aspect UI — September 30

Three agents inspected every menu in the restored StarterGui.GUI.FRAMES (14
frames), plus HUD and OTHER. reference-gui.json is the read-only Studio property
export. The three *-audit.md files record exact inspected/adopted proportions
and content adaptations.

## Result

All eight current menus use native Scale Size/Position, UIAspectRatioConstraint
and TextScaled. No UIScale, UISizeConstraint, UITextSizeConstraint, CompactSize,
SizeLimits, viewport pixel layout or device breakpoint system remains in these
menus. Native lists/scrolling handle repeated content. Hover/pop/home animations
tween native Size/Position. The approved stud sheet is a square aspect-constrained
image cropped by a Frame; no per-stud geometry or replacement art was created.

Shop/Index use their source 1.481701612 aspect; Upgrades 2.93; Settings/Odds
1.543928; Offline Earnings 1.391571045. Army retains 1274/876 and its four columns
with inline inspector; Fuse retains its square three-input composition.
Reference proportions are converted from the old small FRAMES proxy to the
current full-screen container. Current content, artwork, callbacks and economy
remain authoritative. Offline uses the already-approved Shop cash illustration.

The restored GUI remains unchanged in StarterGui as a reference. The client
hides its PlayerGui clone so its unrelated HUD does not cover the game UI.
Current MenuLayouts settings remain editable; generated Preview children can
be rebuilt. Cleanup now uses a BindableEvent to avoid a saved BindableFunction
hanging after Studio restarts.

## Evidence and limits

- All edited client modules and MenuLayoutEditor compiled with Studio loadstring.
- Eight real-renderer previews generated with no PreviewError.
- Screens for all eight menus inspected in Edit mode.
- Five simulated viewport sizes × eight menus = 40 layout checks passed.
- Native scroll positions reached their canvas ends; no forbidden sizing
  components or offset Size/Position values in any generated menu tree.
- Maximum normalized geometry difference: 0.0000038413629503963875.
- HUD fixture checked outside commands, home collapse to exactly82%, and
  absence of forbidden sizing components. Settings is native top-right.
- layout-check.luau reproduces menu geometry/scroll checks; layout-results.json
  records them. Screen sizes were simulated, not physical-device tests.
- No Play session, purchases, player-data changes, Roblox save/publish,
  Git commit or push performed.

Code backups are in before/. The pre-migration Studio MenuLayouts clone was
placed in ServerStorage.UIAspectLayoutBefore20260930. Legacy edit previews and
reference assets were preserved. Local mapped scripts synced through Rojo.

Native constraint behavior was checked against the
[Roblox UIAspectRatioConstraint documentation](https://create.roblox.com/docs/reference/engine/classes/UIAspectRatioConstraint).

