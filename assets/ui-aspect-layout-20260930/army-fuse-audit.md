# Army and Fuse native layout audit

Inspected the full property export in `reference-gui.json`, under `StarterGui.GUI.FRAMES`.

| Reference frame | Inspected GuiObjects | Outer aspect | Layout evidence |
| --- | ---: | ---: | --- |
| DailyGifts | 54 | 1.5 | Centered shell; 16.25% title layer; 98%-wide body; horizontal native list with 1.5% spacing; aspect-constrained reward cards and square art. |
| Rebirth | 68 | 1.20092 | Centered shell; 16.25% title layer; body starts at 16.4%; stacked native lists and proportional reward/action rows. |
| GiftFrame | 16 | 1.39 | Proportional title, message and two actions; actions occupy 32.77% of width and 21.88% of height. |
| JoinGroupFrame | 27 | 1.65 | Proportional inline content, square illustrations and a native verification button; no device breakpoint layout. |
| DailyRewardFrame | 75 | None on outer frame | Native horizontal list, 0.75% spacing, seven aspect-constrained cards with aspect 0.7; proportional title and bottom action. |

Every inspected GuiObject in these five trees has zero Position and Size offsets. Every visible-content TextLabel uses TextScaled. Blank button surfaces generally do not. The source also has UIListLayout, decorative components and some UITextSizeConstraints; it does not use UIScale or UISizeConstraint in these five trees. No unrelated reward, rebirth, gifting or group feature was imported.

## Adoption

`ChickenBrowser.luau` uses the approved 1274:876 shape, four proportional chicken columns and the inline inspector. Toolbar, search, sale confirmation, stats, capacity page, portraits and labels use Scale properties and native aspect/text sizing. `MergeBrowser.luau` uses a square shell, three fixed input positions, proportional connectors, a three-column picker and proportional result/processing views. Selection, cash upgrades, sale validation and fusion requests remain in their existing owners.

The layout functions assign authored fractions directly. They do not measure a viewport, convert a rendered tree afterward, listen for size changes, or maintain a pixel canvas. No UIScale fields, UISizeConstraints, UITextSizeConstraints, pixel font fitting or device breakpoint branches remain in these two modules. The only offset positions follow the pointer during chicken dragging; the drag image itself has Scale sizing and a native aspect constraint. AbsolutePosition/AbsoluteSize remain only for input hit testing.

## Scrolling review and fixes

Army inventory, Army roster and Fuse picker use native vertical UIListLayouts with zero list padding. Each list child is a width-driven, aspect-constrained row; card spacing and the space below a row are part of its proportional geometry. Army rows contain four cards and Fuse rows contain three. This avoids coupling Scale-based grid cell heights or vertical padding to the changing automatic scroll canvas. CanvasSize has no pixel update callback, and AutomaticCanvasSize.Y determines the scroll extent.

This follows the documented native ownership: constraints determine constrained item size, while an automatic scrolling canvas follows descendant content. See [Roblox UIGridLayout documentation](https://create.roblox.com/docs/reference/engine/classes/UIGridLayout) and [ScrollingFrame documentation](https://create.roblox.com/docs/reference/engine/classes/ScrollingFrame). The row approach is an implementation choice to avoid a circular size dependency, not a claim that every scale-grid configuration is broken.

Both constructors now apply their native geometry before returning. Static review found no remaining reference to removed layout/UIScale fields. `git diff --check` passes for both modules. This worker did not operate Studio or run gameplay; visual and runtime verification belongs to the integrating task.
