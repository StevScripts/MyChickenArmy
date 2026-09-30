# Army uniform scale — September 29, 2026

The user's 1274×876 screenshot defines one fixed Army composition. MenuLayout
fits that reference canvas into the saved MyArmy Size/CompactSize bounds.
ChickenBrowser renders at reference dimensions and applies one UIScale.
Four cards per row, the side inspector, spacing and logical font sizes stay
constant as the whole menu changes size. The inspector's text fitting removes
ancestor scale from its measurement to avoid shrinking text twice.

Edit-mode checks used the real renderer and menu dimensions calculated for
1920×1080, 1280×720, 1024×768, 844×390 and 390×844 viewports. All retained four
equal columns, both panes, stable font sizes and normalized positions (largest
difference below 0.001 canvas pixels). See layout-results.json and the
reproducible edit-only layout-check.luau. These are simulated layout bounds,
not physical-device tests. All three edited Luau modules compiled in Studio.

The user's saved MyArmy Size was restored exactly after checks. PreviewMenu
is MyArmy. Existing size/position settings are preserved; its aspect constraint
now matches the screenshot. Local script changes synced with Rojo. No Roblox
save/publish, Git commit/push, transaction or profile change was performed.
Pre-change copies of the three code files are in before/.

