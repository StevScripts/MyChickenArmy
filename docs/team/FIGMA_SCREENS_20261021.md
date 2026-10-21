# Figma: the game's screens recreated from Studio (October 21, 2026)

Stevin asked for every current game UI recreated in Figma ("recreate all the current
game UI's into figma, to update the figma"), and that his own Sell screen be shown as
it is, not the reference game's. This page records what was built and how to redo it.

## Where

Figma file `my-chicken-army` (`4lJjZOqNhR8K7rfMbVIjaK`), page
**"14 • Game screens / from Studio 2026-10-21"**:

- Row of editable recreations, one 1920×1080 frame per UI Lab story, named
  `<Screen> / PC / from Studio 2026-10-21`: HUD, Shop, Upgrades tree, My Army, Chicken
  Index, Sell Chickens, Sell Chickens · confirm, Rebirth, Rebirth (first, not ready),
  Missions, Daily reward, Offline earnings, Settings, Auto Roll panel, Auto Roll
  banner, Playtime Rewards. Every Frame, gradient, stroke, corner, text and image is a
  real Figma node; image nodes are named `<RobloxName> ⟨assetId·tint⟩`.
- Below them, the Studio screenshot of each screen (`… · Studio screenshot`) for
  comparison.
- An **Icon library** frame with every image the screens use (230 images: 211 icons
  as `<assetId>_<tint>` plus 19 chicken previews cropped from the Index and My Army
  screenshots), extracted from Studio with alpha.

## How it was made (scratch pipeline, not committed)

1. Studio Edit, UI Lab: `Lab.Mount(story, LateGame preset, "Desktop")` for each story,
   then a Luau walk of the rendered tree posted to a local HTTP receiver as JSON:
   AbsolutePosition/Size, colours, transparency, UICorner, UIStroke, UIGradient,
   image id/tint/ScaleType/TileSize, text with the **fitted** TextScaled size
   (`TextService:GetTextSize` binary search), alignment, rotation, ViewportFrames.
   A fresh clone of `ServerStorage.PetRoll.UIAuthoring` bypasses the Edit require
   cache (stale `LabStories` otherwise).
2. A Python converter turns each dump into `use_figma` scripts (≤ 40 KB chunks):
   frames with fills/gradients (Roblox UIGradient rotation → `gradientTransform`),
   strokes, corner radii, clipping; text as Montserrat Bold (Figma has no Gotham)
   shrunk to the width Roblox measured; `TextShadow`/`TextFace` pairs become one text
   with a drop shadow; rotation is placed about the centre (Roblox) not the corner
   (Figma); an image with a UIGradient becomes a mask + gradient rectangle. Coordinates
   scale by 1920 / screen width.
3. Icons: every unique (asset, tint) rendered in Studio on black and white contact
   sheets, alpha recovered from the pair, trimmed to the visible bounds, uploaded
   with `upload_assets`; fills are applied per screen by walking the frame in the
   same pre-order as the specs (Fit → FIT, Crop/Stretch → FILL, Tile → TILE with
   `scalingFactor`). Chicken previews are crops of the screenshots.
4. Helper agents pasted the chunks; the lead verified with `get_screenshot`.

Tools live in the session scratchpad (`figma/convert.py`, `fills.py`, `recover.py`,
`dump.luau`, `AGENT_BRIEF.md`); see the memory note `figma-screens-pipeline-oct21`.

## Known differences from the game

- Font: Montserrat Bold stands in for Gotham SSm Bold; widths were matched per line,
  wrapped paragraphs are 92% size, so line breaks can differ.
- Rich text tags are stripped; outlines come from the game's own 8-copy portrait
  outlines or 0.1-px UIStrokes, so some text outlines look thinner than in Roblox.
- Image tint is baked into the exported PNG per tint; the Robux glyph in the HUD offer
  is a Roblox engine image and shows as text only.
- Measured at 1919×1078 (HUD, Sell, Sell confirm, Daily, Upgrades, Playtime) or
  1238×696 (the rest) and scaled; sub-pixel differences of a few px are possible.
- Main moved during the work (P1 HUD and P2 Sell merged and then reverted); the
  frames follow main at 13:52 (HUD/Sell as Stevin wanted them, pre-parity).

Re-running the pipeline after UI changes is about an hour; the Studio part needs the
Edit viewport free (UI Lab mounts and viewport captures), so coordinate with any
session rendering stories or playtesting.
