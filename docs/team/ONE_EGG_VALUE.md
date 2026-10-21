# One egg is one egg — October 21, 2026

Owner decision (Stevin): the game must stop counting millions of eggs when only a
few are on the ground. A chicken's strength raises **what each egg is worth**, not
how many eggs it lays. This supersedes the September 26 quantity economy in
[EGG_QUANTITY.md](EGG_QUANTITY.md) and the "Quantity and visuals" part of
[EGG_ECONOMY.md](../EGG_ECONOMY.md).

## Rule

- Every laying chicken lays one real egg every `Config.EggLaySeconds` (3 s).
  Egg Speed, Double Egg Spawn and production research shorten that
  (`Rules.LaySeconds(production)`), never below `Config.EggMinLaySeconds` (1 s).
- The egg carries every Coin the chicken earned since its last egg. Coins per
  second are unchanged: `Rules.EggRate x EggUnitValue x production` (EggRate is now
  a Coins rate in base-egg units, not an egg count).
- Every drop has `stack = 1`. When a chicken already has `Config.EggsPerChicken`
  eggs waiting (or the yard has `EggMaxDrops`), its next Coins go into an egg
  already on the ground: that egg is worth more, the count stays honest.
- Bag, vacuum and tutorial counts are real eggs. Vacuum capacity stays "seconds of
  the Flock's laying", now in real eggs (`EggService:LayingRate` = laying chickens /
  LaySeconds).

## Display

- No caption over eggs (Oct 21, Stevin: "Dont show how much an egg is worth on top of it");
  the worth shows only in the pickup pop-up and the sale coin counter.
- My Army cards and the inspector show Coins per egg (`pet.eggValue`); the Flock
  header and Army Info footer show Coins/s (`state.income`). The sort is "Best eggs".
- The recruit toast reads "Name · 12 Coins/egg at home".
- `flock.eggsPerSecond` and `homeEggsPerSecond` remain, now as real eggs/s.

## Compatibility

No save change. Old bags or vacuum cargo with large counts keep their count and
value until the next sale. The saved `research.eggValueRemainder` is no longer used
by laying (each layer keeps its own Coin fraction); it still loads.

## Checked

Headless Lune run of the real EggService: 3 Ducks lay 60 eggs a minute (about
11 Coins each), 20 maxed chickens at 9.5x production lay 20 eggs/s, Coins match the
old income minus the last unfinished egg, an unattended Dragon yard holds 5 eggs worth
the full two minutes. luau-lsp at or below the HEAD baseline; Rojo build passed.
Not run in Studio Play.
