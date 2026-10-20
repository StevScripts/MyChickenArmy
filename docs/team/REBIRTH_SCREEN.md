# Rebirth screen and Gems HUD (October 20 overhaul, S8)

Client half of Rebirth plan v2 (package P4). The server half and every number come
from S7: [OVERHAUL_CONTRACT_20261020.md](OVERHAUL_CONTRACT_20261020.md) §6–8.
Decisions: [OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md).

## Owner rule: the UX is 1:1 to the reference

October 20, Stevin: "I want the UX 1:1 to this, obviously change it to my art style
but the UX should be 1:1 to mine." The reference is Drop a Fruit's Rebirth screen,
crops `details/c1-044.png`, `c3-024.png` and `c3-028.png` in
`~/Documents/ChatGPT/My Chicken Army/output/2026-10-20-systems-guide/`.
What that means in the build:

- **Rebirth is one tap**, and the button is always green. A refused tap shakes and
  says why ("Need 46,981 more Coins", "Bring your Army home first"). The old
  2-second hold and grey button are gone. It is greyed only at the top rank.
- **The screen stays open after a Rebirth.** Confetti falls, the Gems balance counts
  up and everything moves on to the next Rebirth. One toast lists the rewards:
  "Rebirth 2! · Corporal Cluck joined your Flock · +60 Gems · ×3 egg Coins".
- **The reward chicken is a black silhouette until the Rebirth is affordable**, then
  it shows in colour.
- **The Coins bar shows the real balance**, even past the cost ("214,880 / 200,000").
- **The Gem Upgrades title and balance scroll away with the cards**, as in the
  reference. Locked cards say "Locked!" and "Rebirth N needed" with a padlock.
  Hovering a card grows it and brightens its rim.
- Copy kept from the reference: "You will lose all Coins and Upgrades when you
  rebirth!", "Rebirth to Earn:", "Skip! KEEP UPGRADES".

Deliberate differences (decided earlier or required):
- Army-green header and the "Gem Upgrades" title (overhaul Decisions).
- Rank names follow the glossary: "Rebirth 2", not "LVL 2".
- The game's art: studded cards, Source Sans Bold with black outlines, the dark body,
  and purple for Gems.
- Skip! hides where paid random items are restricted (its Gems buy luck) and while
  its products are off sale. A bought Skip waits as a credit; its tag reads "Ready!"
  and a tap spends it.

## Layout

The window is `MenuLayout.Defaults.Rebirth`: 0.86 of the screen wide at 1.94:1.
Studio may author `StarterGui.PetRollGui.MenuLayouts.Rebirth`, and
`MenuLayout.CreateControls` adds the Frame. One layout serves every device, so
phones need the landscape lock.

Element positions are the plan's mock pixels (a 1710 × 883 window) and stay in the
code as numbers: `RebirthPanel.luau` (`rect`, `EARN`, `RANK`, `GEM_PANEL`) and
`GemUpgradeGrid.luau` (945-pixel panel, 430 × 153 cards, 178-pixel row pitch).

## Data and requests

- `state.rebirth` (contract §7). Used fields: `version`, `rank`, `nextRank`, `cost`,
  `coins`, `eligible`, `reason`, `armyHome`, `missionRunning`, `multiplierNow/Next`,
  `gemsNext`, `timeSkipMinutes`, `nextChicken`, `unlockNext`, `skip`.
  No price or reward is computed on the client.
- `state.gems`, `state.gemsEarned` and `state.gemUpgrades` (contract §8). A card
  shows the snapshot's `level`, `maxLevel`, `price`, `status` and `text`. Names and
  icon keys come from `GemUpgradeCatalog`.
- Requests:
  - `Rebirth {expectedRank}`, or `{expectedRank, useSkip=true}` to spend a credit.
  - `BuyGemUpgrade {upgradeId, expectedLevel, expectedPrice}`.
  - `SetAutoRebirth {enabled}`.
  - Buying Skip calls `CommerceController:Buy(state.rebirth.skip.productKey)`.
- The success messages of these requests are quiet (`AppController.QUIET_SUCCESS`);
  the screen shows its own feedback. Refusals still show the server's message.
- The Rebirth toast reads the result's `receipt` (`gems`, `species`, `skip`; the
  server also sends one for a spent Skip credit and for Auto Rebirth). Without a
  receipt it uses the last quote's `gemsNext` and `nextChicken`.

## HUD and Index

- **Gems counter:** a gem icon and a purple number sit just above the Coins. It shows
  once `gems` or `gemsEarned` is above zero, and "Rebirth N" and the Hill chip move
  up to make room (`HudController:BuildGems/UpdateGems/PlaceGems`).
- **HUD Rebirth button:** it shows once the Coins reach a quarter of the next cost, or
  once the player has a rank. Each new rank re-arms the "Rebirth ready" toast.
- **Index:** the Rebirth chickens (`PetCatalog.RebirthOrder`) come last. Locked ones
  are silhouettes captioned "Reach Rebirth N", with "Rebirth N" in the corner. Until
  the art pass adds their portraits, they use their `baseSpecies` picture.

## Art

S6's icons (`assets/upgrade-icons-20261020`) go into `Theme.GemArt` in `UITheme`,
one rbxassetid per key; the keys match S6's file names. Until then, `Theme.GemIcon`
draws a placeholder gem, and the cards borrow the nearest existing icon
(`GEM_ART_FALLBACK`).

## Preview

UI Lab stories:
- **Rebirth:** the late-game preset, a Rebirth 10 player who can afford Rebirth 11,
  with Maxed, Available, Unaffordable, Locked and the Auto Rebirth toggle.
- **Rebirth (first, not ready):** the reference's 3,019 / 50,000 screen.

The menu editor previews the same panel.
