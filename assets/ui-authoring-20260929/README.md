# Saved menu sizing controls — September 29, 2026

The user requested editable Studio menus, thinner windows, exactly four Army
pets per row on every screen, and larger slightly overlapping Index portraits.

Eight native Frame controls now live under `StarterGui.PetRollGui.MenuLayouts`.
The existing single ScreenGui remains the only StarterGui root. Runtime reads
each Frame's Size, SizeLimits and CompactSize; Index also reads PortraitScale.
The manual editor utility draws the actual menu presenters with a display-only
fixture, watches size changes, and preserves controls when regenerating previews.
Startup removes only the PlayerGui copies of generated preview content.

[User editing guide](../../docs/UI_EDITING.md) explains the controls and the
one-line Command Bar action for reconnecting previews after restarting Studio.
The latest controls and generated previews are Studio-owned: save the full
place to retain them. The scripts-only Rojo build is not their asset backup.

## Evidence

- [Before sources](before.json) preserve the six previously inspected modules.
- [Checks](checks.json): seven menu open/close paths in PC Play, offline receipt
  bounds, exact four-column Army rows at five simulated menu sizes, editor
  control properties, one StarterGui ScreenGui and runtime preview cleanup.
- [Readback](readback.json): all nine changed/new code files matched Studio.
- [Runtime probe](runtime-probe.luau): disposable client presentation check.
- [Shop in Play](shop-play.jpg): thinner default with existing offers intact.

A native UDim uses float precision: the first Index test used exact equality
against its numeric attribute and failed on rounding. Retesting with a 1e-5
tolerance passed; no source change was needed for that assertion. Changing the
Shop width control to 0.58 produced 748.78 pixels, then its original 0.64 was
restored. The Fuse check temporarily supplied client stand eligibility for its
presentation and restored it; no fusion, purchase or server validation changed.

Rojo packaging and git diff whitespace checks passed. Army checks used the real
renderer in Edit mode at computed desktop/tablet/phone menu sizes, not physical
devices or a full device-emulator input sweep. PC Play used the already enabled
session-only flag. Existing egg-effect asset/plugin HTTP warnings remain outside
this change. Play was stopped and disposable probes disappeared; the persistent
Edit-mode preview helper remains active for the user, with no preview errors.
No saved progress, purchase, publishing, asset upload, Git commit/push or native
Save was performed.
