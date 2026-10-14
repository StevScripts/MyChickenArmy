# Invasions (October 14, 2026; formerly Operations)

Owner feedback: Operations made no sense in the story. The army was teleported into a
cloned arena floating off the map and fought "random people". Owner decision: **Coastal
Invasions**, later (October 14) simplified to an airship drop in a random ring with no cutscene; menu name **Invasions**; **menu plus alerts**.

## Story

After the Chicken King falls, his loyalists want the throne back. Their airships land
somewhere on the island, and your army marches out to repel them. Veteran = scout landings,
Elite = the loyalist fleet, Royal = the King's armada, ending with "The King Returns".

## How it plays

1. Open **Invasions** (HUD icon on the right, Upgrades research node, or the guide).
2. Pick an invasion and press **Defend**. The server picks a **random open spot anywhere
   on the island** (`InvasionLayout.Pick`: island ground with no roads, camps, plots or
   props within 28 studs, scanned once and cached; never within 90 studs of another live
   Invasion; the plot's old fixed spot is only the fallback). It drops a glowing purple
   **ring** there (`InvasionZone<userId>`) and spawns the loyalist airship
   (`src/server/InvasionAirship.luau`, code-built, TweenService only), which flies in
   and hovers while the loyalists drop into the ring (`Catalog.Roster`).
3. No cutscene and no teleport (owner, October 14). The commander gets the normal guide
   beam plus an **"INVASION m:ss"** marker over the ring (`BaseController:UpdateObjective`),
   which outranks every other goal while the Invasion is active.
4. The army waits about 3.5 s, then marches out with the normal camp travel code,
   fights the finite roster and walks home through the normal Returning flow. Other
   players see the ring and the loyalists but cannot join.
   **Time limit: 3 minutes** (`OperationService.TimeLimit=180`). On time-out, Leave,
   a loss or the player leaving the game, there is no reward and the loyalists **fade
   away one by one** over about 8 s (`fadeInvaders`). After a win the fallen loyalists
   fade the same way. The ring disappears when the Invasion ends.
5. Rewards, first-clear tracking, banners, research gates (S15 "Coastal Watch", S16
   "Elite Invasions", S17 "Royal Invasions") and the King-clear unlock are unchanged.
   Only display names changed; ids (`operationId`, `StartOperation`, analytics names,
   `research.operationWins`) stay the same, so saves are unaffected.
6. Alerts: about 3 minutes after joining and every 10 minutes after that, while an
   Invasion is available, the guide is done and the army is home, a "Loyalist airships
   spotted" notice appears and the HUD Invasions icon pulses (client-only, cosmetic).

## Removed

The cloned King arena (`OperationService:CreateArena`), the character teleport, the
110-stud "stay at the arena" abort (an Invasion is now abandoned only if the player
leaves the game) and the teleport home.
