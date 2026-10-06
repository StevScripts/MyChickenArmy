# Square-to-T Plot1 expansion — September 29, 2026

## October 6: matching expansion on all six plots

The user requested Plot1's full contents on all six plots. Plots2–6 now use
copies of its 96 × 131.853668-stud deck, square-to-T yard and expanding-fence
metadata. Their original entrance positions and rotations were preserved,
with separate `PlotIndex` values and `HOME N` labels. The stages below now apply
to every authored plot. This supersedes the older Plots2–6 uniform-expansion
geometry; capacity, prices, saved levels and gameplay code are unchanged.
Authored structural readback and runtime facility inspection passed, and a
full local place copy is saved. See [plot parity and recovery](PLOT_PARITY.md)
for verification scope.

## September 29 design and implementation record

Latest user correction: the starter yard must be square, then expand into the
T-shaped outline in the supplied screenshot. This supersedes the two earlier
rectangular iterations in RECTANGULAR_PLOT_EXPANSION.md.

Later September 29: the user enlarged the deck by 20 studs and requested that
only the last two expansion shapes change, with 100 chickens at full expansion.

## Current geometry

Plot1's ChickenYard uses `ExpansionShape="T"`. The editor displays the
30-by-30-stud starter. Its front stays fixed at the authored square's front,
currently Deck-local Z=-33.5. The center stays 30 studs wide, extending between
the stationary machines until Z=15.5.
Later purchases widen the back behind those machines. The last shape has a
30-by-49 stem joined to an 84-by-45 back section (total depth 94).
The deck is now 96 × 131.854 studs. Resizing moved its center by 10 local studs;
the yard derives its origin from the authored starter square so stages 0–5 keep
their existing world placement. Only levels 6 and 7 gain another 10 and 20 studs
of depth, respectively.

| Saved level | Center width | Total depth | Back section width × depth | Flock capacity |
| --- | ---: | ---: | --- | ---: |
| 0 | 30 | 30 | None; square | 25 |
| 1 | 30 | 36 | None | 30 |
| 2 | 30 | 42 | None | 35 |
| 3 | 30 | 49 | None | 40 |
| 4 | 30 | 57 | 48 × 8 | 45 |
| 5 | 30 | 63 | 60 × 14 | 50 |
| 6 | 30 | 79 | 72 × 30 | 75 |
| 7 | 30 | 94 | 84 × 45 | 100 |

`shared/HomePlotLayout.TeeYard` owns these stages, the eight-edge outline and
the usable interior. `server/PlotUpgradeService` applies the owned stage to the
runtime boundary and invisible yard anchor. Eight beams reuse the existing
dashed texture; collapsed shoulder edges are disabled before the T opens.
Each beam has separate endpoint attachments to keep the stripe flat on the
ground around every corner.

The outer fence still grows on every upgrade, from 76 × 71.68 to 88 × 120.68
studs. Its rectangular perimeter includes the fixed stations, while the inner
chicken boundary follows the T. Fence post sizes and the entrance opening stay
fixed. `ExpansionMaxBack=62.5` and `ExpansionLateDepth=20` preserve early fence
stages while adding the extra depth to the last two. The maximum rear fence has
3.43 studs of deck margin; the yard has 5.43. The user's enlarged deck and
foundation, machines, podiums, sign, spawn, grass, rocks and other scenery were
not moved by this change. Plots2–6 retained their earlier geometric expansion
in this September 29 operation; the October 6 parity operation above replaces
that geometry with matching copies of Plot1.

All seven upgrade prices, saved levels and camp-independent eligibility remain
unchanged. Capacity is now 25 → 30 → 35 → 40 → 45 → 50 → 75 → 100, shared by all
plots. `UpgradeCatalog.PlotCapacity` supplies both server capacity and the next
board preview. Saved inventory validation and visible flock limits support 100.
The deployed army maximum and paid army bonus are unchanged. No new profile
conversion or reset is introduced; saved levels 6 and 7 immediately gain their
new capacities, and the existing revision-11 conversion remains in place.

## Gameplay bounds

The T uses two connected interior rectangles, not its enclosing bounding box.
This keeps the cutouts beside the machines outside the yard. The existing
1.6-stud perimeter inset is retained, with a continuous passage through the neck.

- Home positions and roaming samples cover the actual interior by area. The
  home grid supports 100 distinct positions instead of repeating after 64.
- Roaming chooses straight trips that stay within the shape, returning a bird
  outside the yard to its nearest valid point.
- EggService clamps new drops to the real interior, including the back wings.
- EggRover keeps four passes. Outer passes cover only the wide back section;
  connecting and return paths pass through the neck instead of crossing the
  machine-side cutouts. Dock approaches use the same yard-origin offset to stay
  aligned with the stationary deposit stand after the deck resize. Intake sizing
  and payment logic are unchanged.

## Delivery and recovery

The Studio source still shows the square starter. During the earlier T iteration,
the maximum was briefly displayed as an editor preview, then restored. This
capacity update changes only fence expansion metadata and the yard's builder
note in authored assets; no source geometry was moved.

All 20 isolated groups in `tests/UpgradeBoardProgressionChecks.luau` passed with
freshly loaded, Rojo-synced source. They cover capacity offers and purchases at
every level, last-slot recruitment and no-charge overflow rejection, all 100
chickens surviving a save/load roundtrip, rejection of 101 without partial load,
legacy progress retention, 100 unique home positions, final-stage geometry and
vacuum paths. Geometry checks use temporary unparented synthetic objects and
the enlarged deck's measured dimensions. No live performance/playtest or real
player-data writes were performed. No save/publish, commit or push was performed.

`ServerStorage.RectangularPlotRecovery20260929` retains the earlier snapshots,
`Plot1BeforeTShape`, and the current `Plot1SquareStarter`. The square-to-T asset
operation has a Studio undo entry. Before-sources and the authored operation
are retained under `assets/rectangular-plot-20260929/`.

The seven modules edited for the capacity update were compared against Studio
before editing and their synced fingerprints matched before the checks. Local
recovery sources, geometry measurements, authored metadata operation and check
results are in `assets/plot-capacity-100-20260929/`. The older square snapshot
predates the user's deck enlargement; do not restore the whole plot from it.
Local code is saved; authored map edits still need a Studio place save.
