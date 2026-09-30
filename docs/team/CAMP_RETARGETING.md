# Camp retargeting — September 26, 2026

September 29: the automatic loss of ownership on withdrawal below is superseded
by [persistent territory claims](TERRITORY_CLAIMS.md). Moving/recalling an army
now preserves the flag. Explicit Unclaim Base restores enemies with gradual
control recovery. Actor handoff and physical vacancy protection still apply.

Completed; file ownership and Studio controls released. Scope: BattleService command/reservation lifecycle,
Battle arrival signal, BaseController command eligibility, Config respawn grace,
focused isolated checks and this record. Preserve other tasks' existing changes.
No save schema, economy, upgrade gates, map, asset or commerce changes.

Canonical Studio: Pet Roll Test 96683186622050, instance:w6a-k5r, Edit/not running.
Before editing, the relevant mapped modules each had one copy and matched local
source lengths/hashes. Rojo owns source writes; Studio Flow is used for inspection
and isolated checks. No publishing, purchases, asset uploads or real player-data
changes. Before-copies: /tmp/chicken-camp-routing-before/.

User contract: redirect an ongoing attack to another camp without recreating or
healing the army; reject duplicate orders to its current target. Cleared main
camps remain empty behind forward progress. Retreating to an earlier camp starts
the abandoned camps' two-second respawn delay only on physical arrival; living
stragglers still prevent enemies spawning on top of the army.

## Implemented contract

- Manual camp orders from an existing Traveling, Fighting/Capture or Holding
  encounter go directly to the requested camp, even if the current camp is
  unfinished. This follows the user's immediate-switch description. Orders from
  home and automatic campaign steps still follow earlier camps in order; King
  requirements and shared Supply Outpost contest/defender locks remain intact.
- Duplicate current-target, invalid, foreign-reserved and returning/defending
  orders are rejected without changing the existing encounter.
- The existing actor transfer carries health, dead-chicken recovery deadlines,
  reinforcements and retiring birds. Pending attacks are cancelled and the
  adopted models' attack flags are published immediately. Earned kills drain
  once before the old encounter is removed; abandoning it grants no conquest.
- The server records actual arrival in Battle's travel step. Reservations follow
  the army through successive orders. Cleared main camps below its current
  camp remain empty, including while the army attacks the King.
- On retreat to an earlier camp, higher camps wait for arrival, vacancy and
  Config.CampRespawnGrace (now two seconds). Reordering during travel or during
  the delay cancels the old release schedule. Released camps lose temporary
  passage/ownership but retain the player's earned progression.
- Camp commands remain visible while traveling/fighting. Their availability
  comes from the same server order/reservation rules.

## Evidence and handoff

All 17 focused groups in `tests/CampRetargetingChecks.luau` pass using fresh
source loads in Studio Edit, isolated sessions and stub worlds. Actor-transfer
coverage uses real LiveBattleActors with disposable, unparented model wrappers;
it does not simulate live Humanoid/pathfinding physics. Results are saved in
`assets/camp-retargeting-20260926/check-results.json`. Historical
OrderedConquestChecks expectations that cleared camps repopulate behind a
forward push are superseded by this user request; that historical suite was
not run.

Final readback: one active copy of each module, matching local bytes/hash and
compiling successfully:

| Module | Bytes | Hash |
| --- | ---: | ---: |
| BattleService | 56081 | 1559482228 |
| Battle | 25744 | 425962660 |
| Config | 5090 | 1559021695 |
| BaseController | 24543 | 247007784 |

`git diff --check` passes for the four runtime files. Existing Config and
BaseController edits were preserved. No Play/Stop, save/publish, purchases,
uploads, commits or saved-player-data changes were performed.

Isolated checks are finished. Studio remained Edit/not running at final
readback. The map rearrangement QA task tracked in
`docs/team/MAP_REARRANGEMENT_QA.md` may take Play/Stop control for its authorized
fresh-session checks. This task has no remaining Studio operations or processes.
