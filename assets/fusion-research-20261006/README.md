# Fuse Machine research — October 6, 2026

The user approved moving Fuse Machine access into the skill tree and requested
an Error when a locked player tries to use the machine.

`FuseMachine` is an Army node off Start, priced at $5,000 with a 120-second base
research duration. Position (-3, 4) adds it near the early Army nodes without
moving existing cash/research cells. It reuses the approved Merge icon.
Starting/cancelling research never grants access. Completion uses existing
research timing, quote, save and offline handling.

Locked use shows “Unlock the Fuse Machine in the skill tree first.” with the
existing error style/sound and opens the tree focused on FuseMachine. A delayed
failure does not replace a newer menu. No automatic purchase is made.

New camp victories no longer grant fusion. `fusionUnlockVersion=2` distinguishes
new saves from older earned access. Existing owners get only the FuseMachine
node marked complete, without changing balances, chickens or unrelated research.
Previously locked profiles remain locked. The standard server access gate,
fusion fee/recipe/Giant rules and cash-upgrade eligibility remain intact.

`checks.luau` runs disposable profiles and unparented native prompt instances.
`run-isolated.luau` loads current local sources through a separate require cache;
it never overwrites mapped Studio scripts or touches a live player's profile.
The old Studio PlayerSession source is retained in `before/`; its unsynced
tutorial egg-count changes already existed locally and were preserved.

Verification results and Studio synchronization status are recorded below.

## Verification

- 70 disposable server/save/prompt checks passed (`checks.json`). These include
  fresh locked use, no camp bypass across save/rejoin, research start/cancel/
  completion/offline completion, legacy access, malformed-save rejection, normal
  Giant fusion and independent cash-upgrade offers.
- 27 client method checks passed (`error-checks.json`), using actual OpenPage,
  Receive and OpenNode methods with table collaborators. The locked response
  emits one actionable error even alongside other feedback, and a delayed reply
  does not replace newer UI or submit research/purchases.
- Scripts-only Rojo packaging and scoped whitespace checks passed.

These checks used the latest local sources in a separate require cache. They did
not start/stop Play, mutate live players, write mapped Source, or publish. Actual
rendered toast/audio, gamepad assignment and visual tree layout were not tested.
Studio was already playing outside this chat; applying the changes there awaits
permission to stop that session and reconnect Rojo.
