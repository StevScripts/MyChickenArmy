# HUD and receipt reference audit

Inspected the read-only Studio export `reference-gui.json` from the restored `StarterGui.GUI`. These are observed properties, not inferred screenshot measurements. No reference scripts, products, or gameplay were copied.

The reference `FRAMES` parent is a small centered proxy: Size `(0.0658761561, 0.1204819307)`, Position `(0.5, 0.5)`, AnchorPoint `(0.5, 0.5)`. Its children therefore have Scale values greater than one. Copying those values directly into our full-screen parent would enlarge the menus incorrectly; `MenuLayout` translates the parent relationship once.

| Reference | Observed geometry and structure |
| --- | --- |
| OfflineEarnings | Centered, Scale Size `(5.01320982, 3.5)`, root aspect `1.391571045`. Header height `0.157142863`; bottom-anchored Main height `0.828571439`, aspect `1.679482222`. Main title height `0.120689653`; reward Size `(0.370244563, 0.637931049)`, aspect `0.974743485`; action holder Size `(0.4, 0.155172408)`, aspect `4.329331875`. Vertical list uses Scale padding `0.015`. |
| Settings | Scale Size `(6.25, 4.492000103)`, Position `(0.335, 0.5)`, centered anchor. Header height `0.133569866`; scrolling body height `0.853386760`; list padding `0.04`; setting row width `0.96`, height `0.141609877`. No root aspect constraint in the export; its icon has aspect `1`. |
| TrollMenu | Scale Size `(7.951607704, 5.565508842)`, centered anchor, root aspect `1.6`. Header height `0.16`; cards container Size `(0.88, 0.796887398)`, centered at `(0.5, 0.585912347)`. A native grid arranges the cards. |
| TimedRewards | Scale Size `(7.975065708, 5.954056263)`, centered anchor, root aspect `1.5`. Header height `0.18`; centered grid Size `(0.92, 0.68)` at `(0.5, 0.52)`; bottom bar Size `(0.92, 0.08)` at `(0.5, 0.97)`, bottom-center anchor. |
| HUD | Full-screen parent. LeftSide Size `(0.154203311, 0.424118459)`, Position `(0.010661534, 0.5)`, left-center anchor, aspect `0.647058845`. LeftDownSide is bottom-left anchored, aspect `4.870498657`; currency rows use aspect `5`. Side button groups use square aspect constraints and native list layouts. |
| OTHER | Full-screen parent. PlayerQuestions uses Size `(0.263504624, 0.036144577)` and aspect `12.953773499`, with Scale list padding `0.4`. Notification is top-center anchored at `(0.5, 0.8)`, Size `(0.334001333, 0.036144577)`. PopUp is centered with square aspect. |

Every exported GuiObject Size and Position in these six sections has zero offsets. Aspect constraints use `FitWithinMaxSize` and width as the dominant axis. Text is natively fitted: all nonempty Settings, TrollMenu, TimedRewards and HUD text is `TextScaled=true`. Offline has 13 scaled text objects plus two hidden button text placeholders; OTHER has 14 scaled text objects plus one button placeholder.

The four inspected FRAMES menus have no UIScale, UISizeConstraint or UITextSizeConstraint. For precision, the wider reference also contains 23 UITextSizeConstraints in HUD, nine in OTHER, and one UIScale at `OTHER.BuyTransition.Icon`; the current user request takes precedence and our owned replacements do not introduce them.

## Applied changes and review

- `OfflineCashController`: uses the reference receipt geometry, native Scale text and the existing cash art. The saved menu Frame's Size, Position, AnchorPoint and aspect remain authoritative through `MenuLayout.Apply`. Kept the current saved-receipt semantics and a single Continue dismissal; did not add the reference's paid doubling action.
- `HudController`: native Scale/aspect regions replace all device breakpoints and pixel sizing. Existing My Army, Call Army, My Base, Shop, Index and data readouts remain. Base presence still reduces My Army to exactly 82% of both dimensions and moves/shrinks the side buttons to zero using 320 ms Quad InOut native Size/Position tweens. The outer button owns home animation; the inner Visual owns hover and reward-pop animation. Transitioning side buttons remain non-interactable/non-selectable; focus returns to My Army.
- `MerchantDialogue`: copied PlayerQuestions width and row aspect, with Scale rows and native text fitting. Text reveal, choices and requests remain. Camera projection still updates position because this dialogue follows a moving world character; it does not resize or measure fonts each frame.
- Removed fixed text-measurement budgets from the HUD egg readout. Native TextScaled now fits the exact display value. Added `Theme.ScaleText` at owned menu/button boundaries so a later button caption synchronization cannot revert to unscaled text.
- Shared-motion review identified an integration issue: `Pop` can cache an already-hovered Visual size and conflict with the press tween. Reported to the shared `UIMotion` owner to register the resting size at bind time and coordinate pop/press channels. This is separate from the outer HUD home-state tween.

Scoped `git diff --check` passes. The three owned controllers contain no `fromOffset`, UIScale or TextService usage. This audit did not mutate Studio or perform a runtime playtest; runtime and visual checks belong to root integration.
