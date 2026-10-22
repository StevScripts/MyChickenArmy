# Mission territories: held sites and Loyalist guards (October 15, 2026)

**Later October 15 owner decision (supersedes stationing):** a won site disappears at once,
like before (`OperationService:Resolve` calls `RemoveSite`), and the army walks home. No flag,
holding, contests or hold bonus happen; that code stays dormant. Guards and the site life remain.

Owner request: each spawning mission territory (Scout Landing … The King Returns) gets its own
guard chickens. A conquered territory stays on the island like a camp instead of vanishing.

## Rules

**Lifetime.** A site lasts `OperationService.LifeSeconds` (900 s = 15 minutes) from when it
appears. This replaces the old 6-minute wait.

**Guards.** While nobody holds a site, its own Loyalist guards stand in it.
- They are enemy-only species: never rolled, offered, owned or shown in the Index.
- Rolled chickens never guard a site.
- Each guard has exactly the stats of the chicken it replaced, so power and rewards are
  unchanged.
- The roster is listed in `OperationCatalog.Encounters`. The art is in `LOYALIST_GUARDS.md`.

**Winning against the guards.**
- The conquest reward is `OperationCatalog.Reward` (October 22): minutes of steady egg income
  by tier, capped at a share of the next Rebirth's cost (3% / 4% / 5%), doubled on gold sites.
  The old fixed replay floor (250K–250M) is gone. See `MISSION_REWARDS_20261022.md`.
- The army then stays stationed at the site under a conquest flag (`Battle:Hold`).
- The army does not walk home.

**Taking a held site.** Any other player with the tier unlocked can attack it.
- The attackers fight the holder's stationed chickens at their current health. There are no
  respawns.
- The winner holds the site, and the beaten army recovers at its base.
- If a commander leaves the game mid-fight, the other side keeps or takes the site.

**Reward once per site.** Each player is paid at most once per site (`site.rewarded`). Two
armies trading a site back and forth earn nothing extra. The prompt shows "already rewarded".

**Holding pays a percentage.** A stationed army adds egg value while it holds:
- `Config.Territories.MissionBonus` = Veteran +5%, Elite +8%, Royal +10%.
- While under attack it pays `ContestedShare` (half).
- This goes through the same `session.territoryBonus` as camps.
- Held sites count toward the territory hold limit.

**Leaving before 15 minutes.** If the holder recalls, sends the army elsewhere, or leaves the
game, the flag goes down and the guards move back in after `GuardReturnSeconds`. The site can
then be conquered again.

**After 15 minutes.**
- A site held by a player's army stays as long as that army holds it, including after a
  successful takeover.
- It packs up the moment no player holds it: the holder leaves, or only the guards remain.
- A guard fight still running at the deadline finishes first:
  - A win stations the army and keeps the site.
  - A loss removes the site.

## Code

**`OperationService`** owns everything about sites:
- Site record: `holder`, `holderName`, `holdBattle`, `busy`, `rewarded`.
- Functions: `SetHolder`, `Vacate`, `RemoveSite`, `Conquered`, `Station`, `ResolveContest`,
  `Release`, `Recall`, `SendHome`, `HoldBonuses`, `HoldCount`.
- `MissionList` now also reports `holder`, `yours`, `busy` and `rewarded`. For a held site,
  `power` and `count` describe the stationed army.

**`BattleService` hooks:**
- `ReturnHome`: a stationed army recalls; a defender has to finish the fight.
- `Attack` redirect: leaving a held site releases it.
- `HoldCount`.
- `RefreshTerritoryBonus`.
- `CancelPlayer`: it keeps an encounter that was handed to the other commander.

**Client:**
- `MissionTracker` markers show "Held by …", "Your Army is defending!" and "Leaving soon".
- `BaseController:MissionCommand` explains held, busy and already-rewarded sites.

**Bosses:** `KingVisual.Apply(model, scale, crownless)` keeps the boss scale but skips the
generic crown, because the Dragon Commander and Armada King wear their own headgear.

## Checks run

Run in a Studio Run-mode server (October 15):
- The server boots.
- Spawned 1:1, 1:3, 2:3 and 3:3 sites showed only Loyalist guards with a 15-minute timer.
- Both bosses were crownless authored meshes.

**Not finished:** the scripted two-player test (win → station → takeover → recall). The
stand-in army did not walk from its fake base, and the owner then started a Play session, so
the run was stopped. Holding, takeover, recall and expiry still need a live check with real
players.
