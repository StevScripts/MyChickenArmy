# Retired checks (October 20, 2026 overhaul)

These `tests/` suites encode rules the overhaul retired, so they were moved here
instead of being rewritten during integration (lead session, Oct 20):

- `ResearchChecks`: timed research (now instant, run-scoped Upgrades tree nodes).
- `CashUpgradeChecks`, `UpgradeBoardProgressionChecks`: the 20-25 level cash tracks
  and the old board progression (now a few named tiers per family).
- `OpeningGrowthChecks`, `OpenRollChecks`: read `Config.RollCooldown`, which no
  longer exists (already stale before the overhaul).
- `OperationUnlockChecks`: research-based Mission tiers (now King clear / Rebirth
  5, 10, 15; covered by `tests/RebirthV2Checks.luau`).
- `RebirthChecks`: the Oct 15 Rebirth ladder (now Rebirth v2 with Gems; see
  `docs/team/OVERHAUL_CONTRACT_20261020.md`). Replaced by `tests/RebirthV2Checks.luau`.

Decisions: `docs/team/OVERHAUL_PLAN_20261020.md`.
