# Queue headline fidelity — September 25, 2026

Goal: match the supplied Figma 10,000 headline while preserving the user's current seller-board layout.

Figma source: `4lJjZOqNhR8K7rfMbVIjaK`, frame `328:844`, count `328:886`. Design context confirms Source Sans Pro Bold at 112 px in a 528 × 124 slot. The supplied reference image shows the digits occupying about 63% of the row.

Studio's current board uses PixelsPerStud 60 (CanvasSize is ignored). Its TextScaled count was capped at 100, with 234 × 100 text bounds in a 509.813 × 169.375 label. A hidden clone probe established that UIScale does not bypass this ceiling when TextScaled is true. Fixed TextSize plus UIScale does.

Applied `apply.luau` once in canonical Edit. QueuedCount now uses native TextSize 100, TextScaled false, TextWrapped false and FigmaTextScale 1.375. Reciprocal label sizing preserves its effective rectangle and original position `(43.6064, 198.3543)` on the surface. Text bounds are 323 × 137; its native outline keeps the original four-pixel visible thickness. All other GuiObject Position, Size and AnchorPoint properties matched the complete before-copy. No geometry, studs, buttons, transactions or data changed.

The controller now captures the authored headline size on Bind instead of forcing 88 px and a hard-coded 253 px width. Overlong counts fit the actual scaled width with room for the outline; shorter counts restore the authored size. Final local and single Studio controller source matched at 10,435 bytes / rolling hash 1363166696.

Evidence:
- Viewed the final Studio screenshot against the supplied Figma reference; the number has the intended prominence and stays centered.
- Called the actual updated controller's Render in Edit on a temporary disabled GUI clone and fake app state: 0, 10,000, 999,999, 1,000,000,000, 1,000,000,000,000, then 10,000 again. All text plus outlines fit; restored 10,000 uses TextSize 100 and 323 px text width.
- Temporary controller/GUI/probe clones were removed. Real profiles and balances were never accessed or changed. No Play/Stop, Save, Publish, commit or push by this task.
- Temporarily disabled the previously enabled MCA_Tune_Army_Desktop for the board screenshot and immediately restored Enabled=true. The five other tuning previews remained disabled; all were preserved.

Recovery: full pre-change SurfaceGui is `ServerStorage.EggQueueTypographyBefore20260925`; `controller-before.luau` is the exact pre-change controller. The recipe refuses repeat application. Source art remains in the current Studio Edit place; save the place through the normal workflow to persist authored assets.

Ownership released: EggProcessorController, the authored QueuedCount label, and EGG_PROCESSOR documentation.
