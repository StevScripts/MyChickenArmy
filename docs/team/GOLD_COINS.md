# Gold Coins (October 20, 2026)

Owner decision: the earned currency is shown as gold **Coins**, not "Cash" with a
"$" prefix. It is a presentation change at 1:1 value. The saved `coins` field,
every price, payout, reserve, limit, product ID, pass and server check are unchanged.
Robux stays "R$".

## How amounts read

- **Coin image + number** where an icon fits: HUD wallet, Upgrades tree costs and
  balance, Rebirth cost bar, offline receipt, shop art, world pop-ups (deposit
  amount, NPC kill rewards) and roll podium price tags. These show `1,200`, never `$`.
- **Words** everywhere else (buttons, prompts, notices, tutorial lines, tooltips,
  server messages): `1,200 Coins`, `+500 Coins`, `12.5 Coins/s`, `100–520 Coins/kill`.
  Sentences use lowercase: "Not enough coins."
- Coin amounts are gold (`UIColors.Coins`, `UITheme.Colors.coins`); green stays for
  buy buttons, health bars and owned-camp markers (`UIColors.Money`).

## Helpers

| Side | Helper | Result |
| --- | --- | --- |
| Shared/server | `CurrencyLimits.Text(n)` | "1,200 Coins" (singular "1 Coin") |
| Shared/server | `CurrencyLimits.Rate(n)` | "0.6 Coins", "12.5 Coins", "1,234 Coins" for per-second rates |
| Shared/server | `CurrencyLimits.Grouped(n)` / `.Icon` | "1,200" / the coin image id |
| Client | `UITheme.Coins(n)` / `CompactCoins(n)` | "1,200 Coins" / "8.05B Coins" |
| Client | `UITheme.Money(n)` / `CompactMoney(n)` | number only, beside a coin image |
| Client | `UITheme.CoinIcon(...)` / `CoinAmount(...)` | coin image; centered coin + amount row for pop-ups |

`UITheme.Assets.Coin` reads `CurrencyLimits.Icon`; `Assets.Cash` is kept as an alias.

## Art (group-owned, Kiru Experiences)

Source art: `/Users/stevin/Documents/ChatGPT/My Chicken Army/assets/gold-coins-20261020/`.
Upload copies and receipts: `assets/gold-coins-20261020/` (`upload-receipts.json`).
Generated additions and prompts: `assets/generated/gold-coins-20261020/`.

| Use | Asset | Replaced |
| --- | --- | --- |
| Coin icon (HUD, costs, shop tab, 2x Coins card, particles) | 116489091471628 | 101788696120931 (cash bundle) |
| Pocket Coins / daily tier 1 / offline receipt | 107445346366690 | 105035750065002 |
| Coop Stash (coin sack) | 116335920476744 | 139457712564032 |
| Coin Chest (product key `ArmyChest`) | 132347263460940 | 110055873622600 |
| Commander's Vault square art | 138392235740834 | 103786010617501 |
| Commander's Vault featured card | 114439841862473 | 138029740866650 (bill overflow) |
| Upgrades tree Egg Value hex | 131663330897554 | 109589411633165 (egg + bills) |
| Research E4–E6 and Rebirth egg card | 109799576309561 | 74642843536793 (egg + bills) |

Shop: packs are **Pocket Coins, Coop Stash, Coin Chest, Commander's Vault** on blue
cards; the pass is **2x Coins** (green card, gold coin + native "x2"). The section is
"Coin Packs" and its tab "Coins".

## Studio-owned changes

- `ReplicatedStorage.PetRoll.Assets.Money`: the `Money` emitter shows the gold coin;
  `Spec1`/`Diamonds1` sparkles are gold. The unused `Assets.CashDrop` billboard image
  is the coin. Originals: `ServerStorage.CoinConversionBackup20261020`.
- The "MOST CASH" labels above the plot leaderboards are disabled billboards and were
  left alone. `StarterGui.GUI` and `StarterGui.MainGUI` are reference kits, not live UI.
- Generated `PetRollGui.MenuLayouts.*.Preview` children are refreshed by
  `require(game.ServerStorage.PetRoll.UIAuthoring.Open)()` after a sync.

## Roblox listings (Creator Dashboard)

The native purchase prompt shows the Marketplace name and icon, which source edits
cannot change. Store icons for the coin products: `assets/generated/gold-coins-20261020/`
(`DoubleCoins-20261020-final.png`, `PocketCoins-…`, `CoopStash-…`, `CoinChest-…`,
`CommandersVault-…`). Product IDs: Pocket Coins 3712929487, Coop Stash 3712929549,
Coin Chest 3712929607, Commander's Vault 3712929634; 2x Coins pass 1980764263.

## Kept on purpose

- Internal ids: `coins`, `CashUpgrade`, `EggCashCollect`, `OfflineCash*`, `CashPack`,
  `firstCash`/`replayCash`, `StoredCash`, instance names such as `CashIcon`, and admin
  commands `cash`/`setcash` (new aliases `coins`/`setcoins`).
- Analytics names (`Schema.Currency = "Cash"`, `rebirth.cashAtRebirth`, …) are append-only.
  Reject reasons are recorded from message text, so new rows read "Not enough coins…"
  beside older "Not enough cash" rows.
- Archived code (`archive/`, `EggProcessingArchive20260929`) and Studio backups.

## Roll back

Revert the October 20 commit, restore the eight old image ids above, and copy
`ServerStorage.CoinConversionBackup20261020.Money` back over `Assets.Money`.
