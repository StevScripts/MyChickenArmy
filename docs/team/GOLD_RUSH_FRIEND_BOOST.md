# Gold Rush and Friend Boost (October 20)

Owner decisions: `docs/team/OVERHAUL_PLAN_20261020.md` (Decisions › World, events,
social; session S4), plus Stevin's October 20 confirmations:

- **Gold Rush:** 2x Coins for 5 minutes every 20 minutes for the whole server. All
  servers share one wall clock, so rushes start at :00, :20 and :40 past the hour
  and changing servers gains nothing. It stacks with the 2x Coins pass. The gold
  sky and particles are visual only.
- **Friend Boost:** +10% Coins per Roblox friend in the same server, up to +50%.
  The server computes it. Purchased Coins and refunds are never boosted.
- **When boosts count:** when Coins are paid. That means selling on the pad and the
  end of a fight or Mission. Eggs carried in the bag and sold during a rush get 2x.
- **Offline earnings never include either boost.**

## Where Coins get the boosts

`PlayerSession:EarnedAmount(amount, source, steady)` multiplies the earned sources
(`eggs`, `battle`, `territory`) by `GoldRushService.Multiplier() × (1 + session.friendBoost)`,
next to the 2x Coins pass and the Rebirth egg multiplier.

- Mission rewards are captured with `battle` when the fight ends (`OperationService`)
  and credited later as `operation`, so they are boosted exactly once.
- These are never boosted: `sale` (chicken sales and refunds), `offline`, the `daily`
  credit, product grants and `debug`. `PackIncome` (Coin pack sizes) also leaves the
  boosts out.
- `steady = true` leaves both boosts out. `OfflineCash.Rate` uses it, so the
  `DataService` checkpoint never freezes a boost into offline earnings.
- Displays that go through `EarnedAmount` show the boosted values live: HUD income,
  "Lays eggs worth", egg values and "Bag … Worth". `GoldRushService` touches every
  session when a rush starts or ends, so these refresh at once.
- The daily login reward ("N minutes of income", `DailyService.Income`) uses the
  steady amount too (Stevin, October 20), so it is never boosted.

## Gold Rush clock (server)

- `Config.GoldRush = {Enabled, EverySeconds=1200, Seconds=300, OffsetSeconds=0, CoinMultiplier=2}`.
- `GoldRushService.Window(now)`: the scheduled window running at `now`, otherwise the
  next one. Time is `workspace:GetServerTimeNow()`.
- `GameServer:Start` calls `GoldRushService.Start(sessions, connections)`. The service
  steps four times a second. It publishes the running (or next) window as
  `ReplicatedStorage.PetRoll` attributes `GoldRushStartsAt` and `GoldRushEndsAt`, in
  server time.
- Until `Start` runs (isolated checks, `tests/ProgressionSimulation`), no rush is
  active and `Multiplier()` is 1. Simulations must model Gold Rush explicitly.
- `GoldRushService.StartNow(seconds)` starts a rush by hand; `0` ends it. **Studio
  test:** during a playtest, set the server's `workspace` attribute
  `PetRollGoldRushNow` to a number of seconds (or `true` for one normal rush).
  `false` or `0` ends it.

## Gold Rush presentation (`client/GoldRushController.luau`)

- **Chip:** lower right, above Camps held / Flock (above Auto Roll while that shows).
  It reads "Gold Rush in 14:32" in gold, then "2x Coins! 4:12" in bright gold with
  the coin breathing. Tapping it explains the event. It hides while a menu panel or
  a dialogue is open.
- **Start:** the notice "Gold Rush! 2x Coins for 5 minutes!" plays with the
  `GoldRush` sound if the audio library has one, otherwise `Victory`.
- **World:**
  - A warm `Lighting.PetRollGoldRushTint` ColorCorrectionEffect.
  - The map's Atmosphere tweens to gold (the gold sky) and back to its own values.
  - Gold sparkles (about 40/s) and drifting gold coins (about 7/s) come from
    ParticleEmitters on an invisible box under the camera that follows the focus.
- **Reduced motion:** the tint and sky change instantly, with no particles.
- Tuning constants sit at the top of the module.

## Friend Boost

- **Server (`server/FriendBoostService.luau`):**
  - When a player joins, it makes one `IsFriendsWithAsync` call per pair of players.
    Friend sets are dropped when a player leaves.
  - `Refresh` writes `session.friendBoost` (never saved, never reset with coins) and
    touches the session on a change. It also sets the Player attributes `FriendBoost`
    (0–0.5, read by the HUD) and `FriendBoostFriends` (the friend count; no client
    reads it today). It runs on every change and every second, so a profile that loads
    late still gets its boost.
  - In Studio, local test players (negative user ids) count as friends
    (`Config.FriendBoost.StudioTestPlayersAreFriends`).
- **HUD (`client/FriendBoost.luau`):**
  - "Friend Boost: +N%" with a green + under the Coins number, like the Drop a Fruit
    reference (`systems guide › details/friend-boost.png`).
  - It mounts into `HudController.friendBoostSlot`. The Coins block grew one row:
    number, Friend Boost, then the yard Bag line. Every element keeps its on-screen
    size.
  - The text turns green above 0%. A live increase pops it and shows "A friend is
    here!".
- **The + button:** opens Roblox's own friends invite list straight away. There is no
  popup of our own (Stevin, October 20: "no need for a second UI").
  - It calls `SocialService:CanSendGameInviteAsync`, then `PromptGameInvite` with an
    `ExperienceInviteOptions` message: "Invite friends! Each friend in your server
    gives you +10% Coins."
  - If the account can't send invites, it shows "Invites aren't available right now."

## Checks

- `tests/GoldRushFriendBoostChecks.luau`: wall-clock windows, earned versus steady
  amounts, unboosted sources, offline rate, Friend Boost cap, and that the boost is
  never saved.

## Follow-ups

- Analytics events (the schema belongs to S7).
- S6's Gold Rush icon should replace the coin on the chip once it's uploaded.
- An optional `GoldRush` sound in `SoundService.MyChickenArmyAudio`.
