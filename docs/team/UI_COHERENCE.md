# UI coherence — October 2, 2026

Status: complete in chat `01a0faf6-b32a-7ad1-9f6e-ab043336cb04`.
The Studio-control blocker is resolved. The final independent visual review
accepted the UI at **9.3/10**, with no meaningful visual blockers. Live phone
simulation and the final native layout checks are complete. Studio is stopped
in Edit mode, the device is reset to default/LandscapeLeft, and the temporary
device-simulator toolbar is off. Research has been told Studio is released.

## Ownership and scope

This pass owns changes in nine client modules: UITheme, ChickenBrowser,
MergeBrowser, IndexBrowser, ShopBrowser, ProgressionBrowser, MerchantDialogue,
OfflineCashController and AppController. It also updates generated previews in
`src/server/UIAuthoring/MenuLayoutEditor.luau`. Other dirty/untracked files
belong to concurrent work; preserve them.

The user authorized coordination with research chat
`01a0efd9-cf8c-7cc3-bbd6-c8c51ab656ca` (Initialize Chicken Army task).
Its new Research recording work is separate. Preserve its Research integration,
Formations navigation and Army stats. AppController's new FitContentCanvas
also handles its existing generic Formations/Operations rows.

No economy, progression, persistence, entitlement or transaction rules changed.
No purchases, sales or fusions were executed. No commit, push, publish or place
save was performed. Play used the session-only profile. One Select Best action
occurred during input calibration; it affected only that disposable session.
Temporary Fuse teleports and display fixtures were cleaned up.

## Final presentation changes

- Shared border hierarchy: shell 3, control 2, card 1.5, detail 1 logical pixels.
  Army selection remains 2.5 and equipped cards 2.
- Native text-relative strokes and TextScaled captions keep outlines and labels
  consistent. Render updates no longer disable caption fitting.
- Army retains square surfaces, four columns and the inline inspector. Search,
  sorting, stats and capacity pages share the same border/padding treatment.
  Card name and DPS bounds now leave clear space inside the lower border.
- Shared 1474:116 header, taller title bounds, inset close control and approved
  square stud-sheet crop. Wide controls have explicit authored crop ratios so
  studs stay consistent. Buttons use quieter studs, larger plus glyphs and
  shallower backing. Inventory has a subtle blue-black gradient.
- Only the approved full-sheet image `rbxassetid://93331178043153` is used.
  Existing approved chicken art and silhouette outlines remain.
- Settings save status fits in the initial viewport; Studio tools are reachable.
- Shop details hide underlying offers/status and Back restores them and their
  scroll position. Detail prose/outcomes use more compact rows.
- Offline receipt has an inner border, readable status and bottom spacing.
  Continue only dismisses it.
- The legacy GUI reference is disabled even if it arrives late. Its editable
  StarterGui contents remain preserved; PetRollGui remains the runtime root.

Saved menu Size, Position, AnchorPoint and aspect properties are preserved.
No UIScale, sizing constraints, viewport breakpoints or resize framework was
added. Army retains four columns/inline inspector and Fuse retains three inputs.

## Scroll correctness discovered in live phone checks

The previous fixture proved that scroll frames reached their calculated canvas
end. It did **not** prove that their last content was visible. Live phone checks
exposed AutomaticCanvasSize undercounting aspect-constrained content.

ShopSections, IndexGrid and AppController's generic Content now calculate native
Scale canvas extents from their authored widths, aspect ratios, padding and row
counts. No viewport measurements or frame loops are used. List gaps and Index's
top inset are normalized against that canvas to preserve their original visual
spacing. MenuLayoutEditor uses the same generic helper for generated previews.

Live iPhone 13 landscape end bounds:

| Window | Scroll position / maximum | Final content clearance |
|---|---:|---:|
| Shop | 534.841 / 534.841 | 15.04 px |
| Index | 588.705 / 588.705 | 3.66 px |

Shop's section gap remains 10.46 logical pixels in that view. Settings shows the
full Studio test-tools button at the end; Odds shows the complete Storm Wing row.
Shop details also shows its last outcome, rounding note and Back control.

## Design and judgment

Figma working page `499:4540`, Army frame `499:4541`, file
`4lJjZOqNhR8K7rfMbVIjaK`:
https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK?node-id=499-4541

Original masters remain untouched. Working-copy buttons and four card instances
were detached only where geometry overrides were needed. Text, artwork and
controls remain separately editable. Pass 7 includes the card caption spacing.

Evidence lives in `.dream-loop/ui-coherence/`:
`target.png`, `figma-army-pass-7.png`, `army-live-pass-7.jpg` and
`final-judge-pass-7.md`. Earlier judge scores were 8.5, 9.2 and 9.3.
The fresh final reviewer again scored 9.3/10 and accepted the supplied menus.
Minor fidelity gaps remain: stronger button studs than the generated target,
softer portrait rendering, and Figma checkmark/price-color differences. These
were assessed as non-blocking; saved geometry and approved art take precedence
over a literal generated-image match.

## Checks and evidence limits

Studio: Pet Roll Test, place `96683186622050`, instance `instance:b6m-h68`.
All ten edited sources matched local bytes/rolling hashes and compiled in Studio.
`source-manifest-pass-7.json` includes SHA-256 and readback comparison values.
Scoped `git diff --check` passed. Final screenshots used a fresh Play session.

The final native fixture covered 1920×1080, 1280×720, 1024×768, 844×390 and
390×844. All eight menu aspects held; maximum normalized drift was 0.0000023744.
No forbidden sizing instances or offsets were found. It now also asserts actual
last-content bounds for Shop, Index, Settings and Odds, beyond merely reaching
the calculated canvas end. See `layout-check-pass-7.luau` and
`layout-results-pass-7.json`. Temporary fixture container properties were restored.

Live simulation used iPhone 13 landscape (844×390; safe UI area 749×368) and
portrait (390×844). VirtualInput button clicks were observed arriving as Touch.
Scrolling used simulated wheel input, not a finger-drag gesture. This establishes
emulated interaction, not physical-phone usability or performance.

Current pass-7 screenshots include:
- Army desktop, phone landscape/portrait, and Army Stats landscape.
- Settings and Odds at their last rows.
- Shop cash-row end and details end.
- Index last row.
- Fuse and its empty matching-trio picker.
- Offline display-only receipt.

Use `army-stats-iphone-landscape-pass-7.jpg`, not the misnamed portrait Stats
capture. The initial pass-7 Index capture was made before portraits settled;
use `index-scroll-end-iphone-landscape-pass-7.jpg`. Unchanged Upgrades evidence
remains `upgrades-live-pass-3.jpg`. Older Army pass 2 and intermediate Shop/
receipt captures are historical, not final evidence.

Verified interactions include menu opening, Stats/Back, capacity plus, Luck
details, Shop Back restoring its offers, Fuse Add/picker, and receipt Continue.
The receipt fixture displayed $12,345 of example data without a server request
or balance change; its temporary controller was destroyed. It does not prove
the real payout or opening-blur lifecycle. Fuse used the real world prompt and
the player's temporary position was restored. Plot1 has no SellStand, so no live
merchant flow is claimed; MerchantDialogue compiled with its scaled outline.

The fixed-format portrait board fits but is very small. No claim of large touch
targets or full portrait usability is made. Changing that would require a separate
decision about the user's preserved layout policy.

The confirmed foreground desktop baseline from pass 6 measured 300 frames in
5.0164 seconds: 59.8 FPS, worst frame 33.37 ms. See
`foreground-fps-pass-6.json`. Pass 7 changes one-time native canvas calculations
and caption bounds, not animation/render loops. Two later focus attempts returned
approximately 15 FPS; foreground activation was not established, so those are
retained in `frame-sample-attempts-pass-7.json` and are not presented as a new
foreground benchmark. Physical-device performance remains unmeasured.

Pre-existing logs include the preserved FriendBoost reference handler expecting
ReplicatedStorage.Source and missing ReplicatedStorage.EggDepositEffects.
Neither was changed here.

## Recovery and continuation

Studio is released to the Research chat; do not restart or control its session
without coordinating. No further UI-coherence work is pending in this pass.

Original source backups are in `before/`; pass-7 backups are in `pre-pass-7/`.
Historical stale Studio sources are in `studio-pre-sync-20261002/`. Original
native menu properties are in `menu-layouts-before-live-pass.json`. These paths
are relative to the ignored evidence folder, not new runtime assets.
