# Coins shortfall opens a Coins pack (October 23, 2026)

Owner request (Stevin): when a player can't afford something with Coins, don't show
an error. Open Roblox's purchase prompt for the closest Coins pack straight away, with
no game menu before it.

## Which pack

The smallest Coins pack whose current payout (`state.shop.cashPacks`, the same
minutes-of-income amounts the Shop shows) covers the missing Coins. When no pack
covers it, the biggest pack. Only packs that are on sale (`ShopCatalog.ProductOnSale`)
count: Pocket Coins, Coop Stash, Coin Chest, Commander's Vault.

The purchase still goes through `PreparePurchase` and the existing `ProcessReceipt`
delivery. Buying the pack does not buy the item; the player clicks the item again.

## Where it triggers

- **Server refusals.** `PlayerSession:CanSpendCash`, `RollService:Buy` (podium chicken)
  and `ArmyService.UpgradeChicken` (Chicken Feed) record `session.coinShortfall`.
  `GameServer` turns it into the reply's `needCoins` when the action fails with a
  "Not enough coins" message. That covers the Upgrades tree, Army Size, podium buys and
  Feed. `AppController` and `ResearchBrowser` call `CommerceController:BuyCoins`.
- **Client pre-checks.** The Upgrades tree's red (unaffordable) hexes and the world
  upgrade board open the prompt before sending anything to the server.

## When the old message still shows

`BuyCoins` returns false, and the caller shows its usual message, when:
- the session is a test session (Studio or "test as a new player"), where purchases
  are disabled;
- another purchase is already open;
- the hex is held for a reason other than Coins (a requirement or the starter reserve).

If the server refuses the pack (profile not ready, Coins near the cap), the original
"not enough Coins" message shows instead.

Gems purchases and Rebirth are unchanged.
