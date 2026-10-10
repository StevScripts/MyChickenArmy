# World leaderboards: October 9, 2026 (user decision)

Two all-time global boards on every home plot, replacing Most Cash and Chickens Defeated:

| Model | Board | Value | Store |
|---|---|---|---|
| `PlotN.Leaderboard1` | STRONGEST ARMY | `PlayerSession:BestArmyPower()`: `Rules.Power` of the top chickens within army size (auto-best, not the manual selection) | `<SaveName>_Global_ArmyPower_v1` |
| `PlotN.Leaderboard2` | TOP SUPPORTERS | `session.robuxSpent`: lifetime Robux spent in game | `<SaveName>_Global_RobuxSpent_v1` |

- **Robux tracking** (new saved field `robuxSpent`, display only, never a benefit):
  developer products add the receipt's `CurrencySpent` inside the purchase commit
  (`ProductService`); game passes add `GetProductInfo(...).PriceInRobux` when
  `PromptGamePassPurchaseFinished` reports a purchase (`CommerceService:_RecordPassSpend`).
  Purchases made before this update, or passes bought outside the game, are not counted.
- **Server** (`LeaderboardService`): writes changed values about once a minute and on leave
  (never a zero entry), reads the top 8, resolves display names, and publishes JSON to
  `ReplicatedStorage.PetRoll.Leaderboards.<Key>` (StringValues). Studio shows a local
  preview of players in the session.
- **Client** (`LeaderboardBoards`): draws a SurfaceGui (Left face, 500×750 canvas) on each
  board's `Screen` part as it streams in, using UITheme's header recipe (gradient, studs,
  inset highlight, outlined title) and 8 dark rows with gold/silver/bronze rank tiles,
  headshots and values; empty ranks are dim numbered slots and the local player's row is
  outlined. Title and ranks only (user: no subtitle, footer or helper text). The boards'
  old "MOST CASH" title billboards stay disabled.
- **Map**: the two boards were authored on Plot1 and copied to Plots 2–6 at the same
  Deck-relative position (verified within 0.001 studs). Save the place to keep them.
