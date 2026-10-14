# Invasions (October 14, 2026; formerly Operations)

Owner feedback: Operations made no sense in the story. The army was teleported into a
cloned arena floating off the map and fought "random people". Owner decision: **Coastal
Invasions, faked with an arrival scene**; menu name **Invasions**; **menu plus alerts**.

## Story

After the Chicken King falls, his loyalists want the throne back. Their airships land
beside your base, and your army marches out to repel them. Veteran = scout landings,
Elite = the loyalist fleet, Royal = the King's armada, ending with "The King Returns".

## How it plays

1. Open **Invasions** (HUD icon on the right, Upgrades research node, or the guide).
2. Pick an invasion and press **Defend**. The server spawns the loyalist airship
   (`src/server/InvasionAirship.luau`, code-built, TweenService only). It flies in from
   the sea to the landing zone beside your base (`src/shared/InvasionLayout.luau`, one
   measured spot per plot) and hovers while the loyalists drop (`Catalog.Roster`).
3. The invading player sees a 4.6 s camera shot of the arrival (skippable with any
   input; skipped with reduced motion). The commander stays where they are; nobody is
   teleported.
4. The army waits about 3.5 s, then marches out with the normal camp travel code,
   fights the finite roster, captures the landing zone and walks home through the
   normal Returning flow. A loss, a draw or Leave also walks home.
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
