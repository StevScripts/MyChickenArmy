# Research artwork

The six utility illustrations under `icons/` are original generated artwork used
in the editable Figma research map. `icons/research-hex-mask.png` and
`icons/research-hex-fill.png` are plain transparent hex geometry, with no text or controls
baked into them. The complete screen is not shipped as an image.

Imported October 2, 2026 through Studio Asset Manager under Kiru Experiences.
Names and Image asset types were confirmed with MarketplaceService. Runtime
references live in `src/client/ResearchAssets.luau`:

| Source | Registry key | Image ID |
|---|---|---|
| `icons/bandages.png` | `bandages` | 120779534623977 |
| `icons/boots.png` | `boots` | 137818969643923 |
| `icons/feed.png` | `feed` | 122007287446526 |
| `icons/medkit.png` | `medkit` | 80368789706410 |
| `icons/lab.png` | `lab` | 85565793294890 |
| `icons/rally.png` | `rally` | 106333000080346 |
| `icons/research-hex-mask.png` | `hexMask` | 117593460258785 |
| `icons/research-hex-fill.png` | `hexFill` | 103453394949472 |

Existing army/index/cash/magnet/egg art
is reused by its established uploaded ID. Studs always use UITheme.Studs and the
approved full-sheet image, never generated individual studs.

Design and review evidence is in the ignored `.dream-loop` directory. Release
status and source owners are in `docs/team/RESEARCH.md`.
