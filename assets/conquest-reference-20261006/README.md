# Conquest recording implementation — October 6

See [the behavior and source contract](../../docs/team/CONQUEST_REFERENCE.md).

- `checks.luau`: 16 isolated real-module conquest checks; execute in Studio Edit.
- `checks-result.json`: all 43 conquest, territory-claim and retargeting results.
- `live-capture-history.json`: first live capture and unclaim/recapture sequence.
- `status.json`: final native E/R, presentation, source-sync and delivery evidence.
- `before/`, `source-manifest.json`, `runtime-changes.patch`: recoverable snapshots
  and task diff. Existing unrelated edits in these files are preserved in the
  before snapshots; the task patch excludes them.

All gameplay checks used session-only fixtures. No player profile was loaded or
saved, and nothing was published, uploaded, committed or pushed.
