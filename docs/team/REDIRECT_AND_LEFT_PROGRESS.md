# Redirect anywhere and left progress (October 15)

Owner request: an army that is attacking, marching or returning can be sent to
any other target at once, and the place it leaves keeps its progress, which fades.

- **Redirect:** `BattleService:CanRedirect` now also allows an unresolved Mission
  battle (Travel/Fight/Capture). Camp → camp already worked; camp → Mission and
  Mission → Mission go through `OperationService:StartMission`, which carries the
  same birds and rigs over (fallen birds get up, since Missions never respawn).
  Leaving a Mission forfeits it (`Resolve(...,"Abandoned")`, no reward, site gone).
  A following army is released first (`ArmyCommandService:StartMission`).
  Defending your base and recovering still block orders.
- **Left progress:** when an army leaves a camp/outpost/King fight (new order or
  recall), `BattleService:LeaveProgress` stores the conquer bar and which guards
  were down. The bar drains to empty over `Config.LeftProgressDrainSeconds` (90 s
  for a full bar) and fallen guards stand back up one every
  `Config.LeftDefenderRespawnSeconds` (12 s). A fallen boss is back at once.
  The same commander's next attack there resumes what is left
  (`ResumeProgress`); anyone else starts fresh. Held in server memory only.
- **Display:** `Snapshots` adds a `territoryReclaim`/`abandoned` entry per camp
  with progress left; `BattleController` shows it only to that commander as
  "Progress fading · <camp> · N defenders regrouping".
- Defeat keeps its existing quick enemy reclaim (`EnemyReclaimSeconds`).

Checked in a Studio playtest: leave at 45% → bar draining (41.9%) with 1 guard
down → return resumes at 36% with that guard respawning in ~4 s; camp → Mission
and Mission → camp both carry all 3 birds, forfeiting the Mission.
