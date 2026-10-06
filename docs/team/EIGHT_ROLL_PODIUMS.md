# Eight roll podiums — September 29, 2026

## October 6: eight authored podiums on every plot

The user requested Plot1's full contents on all six plots. Plots2–6 now have
Plot1's eight uniquely numbered podiums and lever, with their original entrance
positions/rotations and individual plot labels preserved. All six therefore
support the physical eight-slot maximum. This supersedes the historical
one-podium limitation below; it does not grant unpurchased slots or change
prices, saved ownership or the October 2 hidden-stand behavior.
Authored structural readback and runtime facility inspection passed, and a
full local place copy is saved. See [plot parity and recovery](PLOT_PARITY.md)
for verification scope.

## September 29 implementation record

The user added eight authored stands to Plot1. Support now accepts up to eight
simultaneous offers through `Config.RollSlotsUnlocked=8`. Stored ownership still
limits active displays, and physical stands still limit each plot. New profiles
start with one; old profiles lacking the saved field retain the historical six,
instead of accidentally receiving the new maximum. Existing one-through-six
ownership is preserved; seven and eight serialize normally.

The two new stands were both named DisplayPodium7. The one nearest podium six,
at the inspected RollDisplay position (299.3721, 4.4920, -175.3151), was renamed
DisplayPodium8 in the Edit source. Geometry and placement were untouched.
Plot1 then ordered DisplayPodium, DisplayPodium2 through DisplayPodium8 uniquely.
Plots2–6 each had one RollDisplay and were left intact in this September 29
operation. The October 6 parity operation above replaces that limitation.

The user's follow-up replaces the $600M sixth-slot luxury goal with a target of
all eight slots in roughly 8–9 total active F2P hours from a fresh profile.
The implemented prices are:

| Slot unlocked | Cash price | Reference modeled total hours |
| --- | ---: | ---: |
| 1 | Included | 0 |
| 2 | $1,200 | 0.08 |
| 3 | $4,800 | 0.25 |
| 4 | $120,000 | 0.83 |
| 5 | $6,000,000 | 1.90 |
| 6 | $150,000,000 | 4.41 |
| 7 | $300,000,000 | 6.41 |
| 8 | $500,000,000 | 8.47 |

The sixth price is reduced by 75%; slots 2–5 retain their prices. Seven purchases
total $956,126,000. These are ordinary fixed cash prices, with no timer, camp,
rank, conquest, King, paid or rebirth prerequisite. Existing ownership is retained.

This is initial model-based tuning, not measured player pacing. The 48-seed
reference policy reserves 25% of deposits for slots and reinvests the rest in
recruiting, plot capacity, Luck, Egg Speed and Egg Value. It assumes rolls every
20 seconds, deposits every minute and 80% home production. Its median is 8.47
hours (10th–90th percentile 8.07–8.78). Focused and relaxed policies reach medians
of 5.75 and 10.90 hours. No passes, cash packs, offline income or combat rewards
are included. Fusion, army-upgrade spending and physical travel/collection are
not simulated. See the [tuning report](../../tuning/my-chicken-army-roll-slots/tuning-report.md)
for assumptions, reproduction and the follow-up measurement plan.

Source scope: Config, UpgradeCatalog and the legacy missing-field default in PlayerSession.
Authored scope: the single duplicate podium name. All pre-existing changes,
including instant egg sales and other client/workbench edits, are preserved.
Isolated checks: four podium checks in `assets/eight-roll-podiums-20260929/checks.luau`
and 18 current upgrade progression checks in `tests/UpgradeBoardProgressionChecks.luau`
passed. Results are saved alongside the podium fixture. The latter used fresh
sources matching local hashes, with in-memory player/store/world boundaries;
no real profile was loaded. A pre-existing divergent duplicate PlotUpgradeService
in Studio was excluded by exact-source matching and left untouched. Rojo build
passed; that verifies packaging, not a human playtest.
No Play/Stop, player-data change, Roblox save/publish or Git commit/push.
The authored rename needs a Studio place save; code is saved locally and Rojo-synced.

## Unpurchased stands hidden — October 2, 2026

Only owned rolling stands are visible during play. The included first stand stays
visible; additional authored DisplayPodium models start hidden and non-collidable.
RollStation now applies the existing owned-slot count to their actual art, not
only the offer's Unlocked attribute. A cash slot purchase restores the next
stand's original transparency, collision, touch/query and shadow properties.
Plot release hides the extra stands again for the next owner. The eight anchors,
physical slot limit, authored geometry, prices and saved ownership are preserved.

Six isolated Studio checks passed using an unparented clone of Plot1's real Spin
assembly and an in-memory session: construction, fresh ownership, an actual
UpgradeService slot transaction, eight-slot ownership, release and a new owner.
The live player's world/profile was untouched. Source compiled, matched local
readback and passed scoped whitespace checks. Evidence and the pre-change source
are in `.dream-loop/locked-roll-stands-20261002/`. Existing Play sessions need a
fresh start to load the updated module; Studio control is coordinated with the
Research chat. No persistent purchase, place save/publish or Git commit/push.
