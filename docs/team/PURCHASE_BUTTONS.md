# Purchase button presentation — September 25, 2026

The UI task owns client/UIMotion, UITheme, UpgradeBoardController and the button
presentation in EggProcessorController. Preserve the egg pad tuning and earlier
responsive UI changes. Other chicken rig/recovery changes are outside this task.

Chicken bump work released Studio controls; this task now owns the short focused
UI check window in Pet Roll Test 96683186622050, instance k48-cgv. Mapped sources
match disk; an additional stale UpgradeBoardController lacks motion and will be
preserved outside the runtime hierarchy. No purchases, publishing or profile edits.

## Complete — Studio controls released

Four client modules compile, match Studio and have one active copy each. The old
UpgradeBoardController is preserved in ServerStorage.PurchaseButtonRecovery20260925
and exported under assets/purchase-buttons-20260925. All 24 live purchase buttons
have shared motion bindings. Focused controller/tween checks passed 98 assertions,
including affordability boundaries, restoration, pending/MAX, mouse/tap callbacks,
reduced motion, and no requests on insufficient funds. Callbacks were exercised
with isolated signals and real tweens, not physical mobile hardware. Fixtures
were removed and Play stopped. No save, publish, commit or purchase was performed.
