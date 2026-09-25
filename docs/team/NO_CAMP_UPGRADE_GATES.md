# Remove camp requirements from upgrades — September 25, 2026

Owner: root. Current user request removes camp/rank prerequisites from all available cash upgrades and makes the correction durable in agent/project guidance.

Runtime ownership: bounded PlayerSession and UpgradeService eligibility/snapshot changes, UpgradeCatalog's obsolete rank table, and ArmyService's rejected legacy promotion message. Other tasks' UI, notification, vacuum, chicken recovery and feedback changes were preserved. No new balancing curve, unlimited levels, camp routing change, merge enablement or schema change. Ownership released after completion.

Before editing, canonical Pet Roll Test 96683186622050, instance:k48-cgv, had an active Play session plus an Edit peer. The Edit peer reported not running. Current PlayerSession/UpgradeService/UpgradeCatalog sources matched local hashes and lengths. Before-copies are at `/tmp/chicken-no-camp-upgrades-20260925/`.

UpgradeService also had a 5,884-byte old duplicate lacking the current previews. Both versions were exported to `assets/upgrade-no-camps-20260925/before/`. After the corrected authoritative service synced, the verified old duplicate was preserved in `ServerStorage.UpgradeGateRecovery20260925.UpgradeService_Legacy5884`; source was not overwritten through MCP. All changes targeted the Edit tree; the active Play session was not stopped or edited.

Current rule: [UPGRADE_RULES.md](../UPGRADE_RULES.md). All three project AGENTS files, current README/product/design/architecture/upgrade-board guidance, the egg handoff and feedback plan, and project-start/UI skills now carry or link the correction. Dated historical evidence is labeled as superseded wherever old upgrade gates were prescribed. The earlier handoff instruction to preserve rank requirements was explicitly corrected.

Seven focused actual-module Luau checks pass with fake services, no Studio world or real saved profiles. They cover every current board upgrade at rank one/zero wins, direct menu owners, invariant prices across ranks, funds/stale-quote rejection, remaining access/plot/ready limits, rank-one maximum-upgrade data roundtrip, and Bigger Army. Tests are in `assets/upgrade-no-camps-20260925/checks.luau`.

No Play/Stop, live profile access, purchase, Roblox Save/Publish, Git commit or push. The separate cash-pad task later reported its Play session stopped and controls released. The next Play session loads the updated modules.

## Completion evidence

All seven focused checks passed again after the final message correction. Before-copy diffs show only the intended four runtime edits. Final Edit-tree source lengths and rolling hashes matched local files exactly:

| Module | Bytes | Hash |
| --- | ---: | ---: |
| PlayerSession | 31,247 | 819681967 |
| UpgradeService | 6,647 | 4279525925 |
| UpgradeCatalog | 776 | 1676441448 |
| ArmyService | 10,894 | 3991580204 |

A second, exact known-old UpgradeCatalog (741 bytes, hash 1595420473) still held RollSlotRanks. After confirming the corrected catalog, the old instance was preserved as `ServerStorage.UpgradeGateRecovery20260925.UpgradeCatalog_Legacy741` with its original path attribute. Exactly one active catalog remains. Both obsolete modules are kept outside active module lookup paths; no Source property was overwritten through MCP.

The seven-check fixture covers transaction behavior using actual modules with fake boundaries; it is not a visual or end-to-end gameplay test. No claim of live published availability is made.
