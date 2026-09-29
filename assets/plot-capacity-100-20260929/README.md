# Final plot stages and 100-chicken capacity — September 29

The user enlarged Plot1's deck to 96 × 131.854 studs and requested that the
normal stages stay fixed, only the last two fit the extra space, and the fully
expanded flock capacity reach 100.

- `before-*.luau`: seven local sources, compared against Studio before editing.
- `before-geometry.json`: enlarged deck and source starter geometry before this
  task changed any metadata. The user's enlargement is already included.
- `fit-final-stages.luau`: the executed Studio asset operation. It only changes
  fence expansion attributes and the yard's builder note, with a Studio undo entry.
- `check-results.json`: all 20 isolated checks passed against the synced sources.

The fixture is `tests/UpgradeBoardProgressionChecks.luau`; it accepts current
source strings by repository path, constructs fresh modules and fake services,
and destroys its temporary unparented geometry. It never accesses real players,
purchases or DataStores. Sources were checked for duplicate mapped copies,
compiled and compared by UTF-8 length plus Adler-32 before executing the fixture
through Studio Flow in canonical Edit mode. No Play session or performance test
was run. No place save, publish, commit or push was performed.

Contract: `docs/team/SQUARE_TO_T_PLOT_EXPANSION.md`. The local source is saved and
Rojo-synced; the authored metadata still needs a Studio place save. Preserve the
user's enlarged deck when reverting metadata. Older whole-plot recovery copies
predate that enlargement.
