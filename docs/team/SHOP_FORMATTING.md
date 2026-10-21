# Shop formatting — October 6, 2026

Reference: [user-supplied Mini War Shop recording](</Users/stevin/Desktop/Screen Recording 2026-10-06 at 3.17.50 AM.mov>),
18.820 seconds at 3456 × 2234.

The user requested the title formatting and compact card grouping shown in the
supplied Mini War Shop recording. The pass view around 4 seconds shows three
nearly square cards per row, approximately 1.1 width-to-height, with narrow
gutters of about 1% of section width. These are visual estimates, not recovered
reference properties.

## Presentation contract

- Arrange game passes three across with the same narrow horizontal and vertical
  gutters. Added offers extend the scrolling grid without changing card shape.
- Use compact centered Featured, Gamepasses and Cash headings with small
  flanking icons from the existing approved artwork. The Featured container
  wraps the existing Galaxy presentation without changing its banner internals.
- Group the wide featured cash pack directly above three smaller cash packs;
  use the same narrow gutters between the smaller packs and below the feature.
- Keep native Scale geometry, aspect constraints and TextScaled. Content and
  card padding stay internal. Recalculate section proportions and the existing
  explicit scroll canvas from the complete content height.

This supersedes the older two-column pass grid and 0.075 horizontal/0.04 vertical
spacing recorded in the September 30 catalog audit. The existing gold shared
header and seamless header/body shell remain. Preserve GalaxyCrateShop, current
offer contents and ordering, approved colors/artwork, and the native commerce
flow, including enabled-offer filtering, entitlement/policy checks, current
Roblox prices and unavailable/pending states. Preserve the Studio Test roll
status message already present in ShopBrowser.

Implemented in `src/client/ShopBrowser.luau`: three columns, 1.10 pass-card
aspect and 0.012 section-width gutters, with larger purchase buttons in the
small cash cards. The existing Rojo connection delivered the source to Studio;
source readback matched the local file. The active Play session was left
running, so a fresh session is needed to load the revised browser. Saved menu
previews were not regenerated during Play. No playtest or rendered-layout
comparison was performed.
