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
  "Rebirth 2! · +60 Gems · ×3 egg Coins" (October 22: no chicken joins; see "Rebirth
  finds" below).
- **The chicken on the Coins bar is the one to FIND** (October 22, Stevin: "you had to
  find that chicken first"): a black silhouette captioned "Find to Rebirth" until it is
  in the Index, then in colour with "Found!". Ranks 1–15 each need theirs; the tile is
  hidden from Rebirth 16. See "Rebirth finds" below.
- **The Coins bar shows the real balance**, even past the cost ("214,880 / 200,000").
- **Money resets to zero** on a Rebirth (later October 20, Stevin; `RebirthService`),
  and it reads 0 (October 21 reference parity, P4; the bar shows "0 / 1,000,000" like
  the reference). Time Skip is no longer credited in the same transaction: the
  server saves its Coins as a claim (`timeSkipPending = {coins, rank}`) and, once the
  confetti has played, a **"Time Skip!"** popup in the Welcome Back style opens over
  the still-open Rebirth window ("TIME SKIP:", coin art, "+N Coins", "N min of egg
  Coins · Rebirth R", green Claim!). Claim! (or the X, Escape, B) sends
  `ClaimTimeSkip`; coins fly into the HUD and the readout counts up. An unclaimed
  reward is added to by the next Rebirth and offered again on join, after the
  offline receipt and the daily reward. A Skip Rebirth keeps the run, so it still
  pays its Time Skip at once. The toast says "Time Skip ready: +N Coins".
- **Big icons** (later October 20, Stevin: "the images are really small"). Card icons
  fill nearly the card height, and the reward tiles, price gems, coin and reward
  chicken are larger than the plan's mock.
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
  `gemsNext`, `timeSkipMinutes`, `nextChicken`, `unlockNext`, `skip`, and
  `timeSkipPending` (`{coins, rank}` or nil; the claim popup's amount).
  No price or reward is computed on the client.
- `state.gems`, `state.gemsEarned` and `state.gemUpgrades` (contract §8). A card
  shows the snapshot's `level`, `maxLevel`, `price`, `status` and `text`. Names and
  icon keys come from `GemUpgradeCatalog`.
- Requests:
  - `Rebirth {expectedRank}`, or `{expectedRank, useSkip=true}` to spend a credit.
  - `BuyGemUpgrade {upgradeId, expectedLevel, expectedPrice}`.
  - `SetAutoRebirth {enabled}`.
  - `ClaimTimeSkip` (no fields; October 21, P4): pays `state.rebirth.timeSkipPending`
    once. `TimeSkipController` sends it; a second claim is refused with an empty
    message (no notice).
  - Buying Skip calls `CommerceController:Buy(state.rebirth.skip.productKey)`.
- The success messages of these requests are quiet (`AppController.QUIET_SUCCESS`);
  the screen shows its own feedback. Refusals still show the server's message.
- The Rebirth toast reads the result's `receipt` (`gems`, `species`, `skip`,
  `timeSkipCoins`, `timeSkipPending`; the server also sends one for a spent Skip
  credit and for Auto Rebirth). Without a receipt it uses the last quote's `gemsNext`
  and `nextChicken`. `RebirthPanel.celebratingUntil` (about 2.2 s after the Rebirth)
  holds the Time Skip popup until the celebration has played.

## HUD and Index

- **No Gems on the HUD** (later October 20, S19). Stevin: "I only want it visible in
  the rebirth screen not with the coins." The Gem Upgrades balance is the only Gems
  readout; it follows `state.gems` on every packet, after a Rebirth and after a Gem
  purchase. "Rebirth N" and the Hill chip keep their places above the Coins. S8's
  counter (`HudController:BuildGems/UpdateGems/PlaceGems`) was removed; it is in
  commit ae94c9d.
- **HUD Rebirth button:** it shows once the Coins reach a quarter of the next cost, or
  once the player has a rank. Each new rank re-arms the "Rebirth ready" toast.
- **Index:** `PetCatalog.RebirthOrder` has been empty since October 21 (no Rebirth
  chickens are granted or offered). The finds are ordinary rollable chickens with their
  normal odds and portraits.

## Rebirth finds (October 22, owner decision)

Stevin: "the chickens that you get are chickens that you're supposed to find first
before you can rebirth. It's not chickens that you get … you had to have found it and
had to be in your index before you rebirth … it should be for every single rebirth,
maybe up to 15 … and after that it could just be the money."

- **Rule.** Rebirth N (1 ≤ N ≤ `Config.Rebirth.FindRanks`, 15) needs
  `PetCatalog.RebirthFinds[N]` in the Index: `session.discovered[species]`, set the
  first time the player owns one (a roll recruit, a Free Roll, a crate). Selling it
  later does not matter. From Rebirth 16 only the Coins count. Nothing is granted on a
  Rebirth any more (`RebirthChickens.Grant` is dormant; the receipt has no `petId`).
- **Server.** `RebirthChickens.Required(rank)`, `.Found(session, rank)` and
  `.Wanted(session, species)` (the next rank's missing find). `RebirthService.Quote`
  adds `find = {species, name, rarity, found}` (nil past rank 15) and refuses with
  "Find Robo-Cluck first" after the Coins check and before the army check, so the HUD
  badge, the "Rebirth ready" toast and Auto Rebirth all wait for the find. A paid Skip
  needs the find too. `RollService.Keeper` returns "rebirth" for the missing find, so
  Auto Roll stops on it ("Auto Roll found a Rebirth chicken!").
- **Screen.** `RebirthPanel:RenderChicken(quote, hasNext)` draws `quote.find`: name,
  silhouette (black) and "Find to Rebirth" in the rarity colour until found, then the
  portrait in colour and "Found!" in green, with one punch when the find lands while the
  screen is open. The Lab's `RebirthFirst` story shows Robo-Cluck unfound; the late
  preset shows the Dragon Knight found.
- **Checks.** `tests/RebirthV2Checks.luau` "Rebirth finds" (30/30 with the suite);
  the fixture pre-discovers every find so the older Rebirth tests still run.
  `ProgressionSimulation` buys the next rank's find on sight (assumption 10) and
  reports "Rebirth finds: N bought on sight, M min waiting with the Coins in hand".

### The ladder

Rarer every rank; picked with `tools/sim/` discovery probes (first podium offer per
species on 3 fast, 1 casual and 2 daily 45-minute seeds) so each one has been seen by
the time its Rebirth is affordable: with eight podiums every Epic–Mythic shows inside
the first 40 minutes; the Galaxy Overlord at about 40 min (fast) or day 1 (daily), the
First Hen at 1.3 h (fast) or day 1–2 (daily). The gate therefore bites at Rebirths 1–2
(one or two podiums, the Robo-Cluck first shows at 2–14 min against an 8-minute Rebirth
1) and on buying the find when it shows (prices are small against the ranks' costs:
Galaxy Overlord 100M at Rebirth 14's 25.9T, The First Hen 5.8B at Rebirth 15's 29.4T).

October 22 roll pool (`RARITY_REBALANCE_20261022.md`): the finds were re-picked from
chickens with effects, which always stay in the pool, each nearest the old ladder's odds
on the new 78-chicken ladder. A 3-seed fast probe (3 h) kept the pace: Rebirth 1 at
9–12 min (HEAD 8–11), Rebirth 5 at 56–62 min (HEAD 53–67), and every find was bought on
sight.

| Rebirth | Find | Rarity | 1 in (zero Luck) | Before October 22 |
|---|---|---|---|---|
| 1 | Robo-Cluck (`Bucket`) | Rare | 58 | 73 |
| 2 | Frost Feather (`Frost`) | Rare | 139 | Crystal Chicken, 160 |
| 3 | Mimic Chicken (`Mimic`) | Epic | 349 | Magma Chicken, 364 |
| 4 | Dragon Hatchling (`DragonHatchling`) | Epic | 529 | Chicken Jockey, 520 |
| 5 | Stained Glass Chicken (`StainedGlass`) | Legendary | 924 | Golden Emperor, 909 |
| 6 | Geode Chicken (`Geode`) | Legendary | 1,040 | Rainbow Rider, 1,000 |
| 7 | Pharaoh Chicken (`Pharaoh`) | Legendary | 1,160 | Water Chicken, 1,212 |
| 8 | Solar Flare Chicken (`SolarFlare`) | Legendary | 1,910 | Pharaoh, 2,857 |
| 9 | Glitch Chicken (`IceDuck`) | Mythic | 9,410 | Phoenix, 4,000 |
| 10 | Griffin Chicken (`Griffin`) | Mythic | 11,000 | Glitch Chicken, 7,771 |
| 11 | Dragon Knight (`DragonKnight`) | Mythic | 12,800 | Heavenly, 10,361 |
| 12 | Moon Chicken (`Moon`) | Mythic | 20,300 | Time Keeper, 18,995 |
| 13 | Olympian Chicken (`Olympian`) | Mythic | 23,700 | Mecha, 18,995 |
| 14 | Galaxy Overlord (`StormDuck`) | Secret | 367,000 | Mythic, 121,224 |
| 15 | The First Hen (`FirstHen`) | Secret | 428,000 | 444,489 |

Rebirth 8 is easier and 9 harder than before, because no Legendary is rarer than 1 in
1,910 now and Mythics start at 1 in 9,410.

### Simulation (the discovery probe's seeds, with and without the rule)

`tools/sim/unlock_probe.luau` with the find rule (fast 301–303 for 8 h, casual 321–322 for
8 h, 45 min a day 311–313 for 14 days) against the same seeds without it (`find_probe`,
October 22 morning). Wall-clock medians:

| Rebirth | Fast, before → after | Casual, before → after | 45 min a day, before → after |
|---|---|---|---|
| 1 | 8 → 9 min | 11 → 16 min | 5–6 → 12–15 min |
| 2 | 17 → 18 min | 19 → 22 min | 18–21 → 20 min |
| 3 | 25 → 25 min | 25 → 33 min | 25–27 → 25–31 min |
| 5 | 56 → 54 min | 63 → 67 min | day 2 → day 2 |
| 10 | 2.9 → 2.7 h | 3.2 → 3.0 h | day 4 → day 4 |
| 15 | 5.9 → 5.3 h | 6.1 → 5.6 h | day 7 → day 7 |

Time with the Coins in hand but the chicken missing: 1.5–5.8 min at Rebirth 1 (the
Robo-Cluck has to show on one or two podiums), 0.2 min at Rebirths 2–3, 0.2–2.5 min at
Rebirth 15 for the First Hen (two of eight seeds), nothing else. Each seed bought 10–14 of
its 15 finds on sight (the rest were already owned for their eggs). So the rule costs a
first-session player 5–9 minutes at Rebirth 1 and a few minutes at Rebirths 2–3; from
Rebirth 5 every find has been seen long before the Coins are there, and the chased
Legendaries and Mythics lay eggs, so Rebirths 10–15 come a little earlier. If the later
finds should bite, the lever is rarer picks: the two other Secrets (Rift Walker,
Supernova) first show at 1.5–1.8 h nonstop and on day 2 for the daily player.

Lab note: the `RebirthFirst` story renders with the late-game preset (the Starter
preset mounts but draws nothing, a pre-existing preset issue).

## Art

`Theme.GemArt` in `UITheme` holds one rbxassetid per key; the keys match S6's file
names. The ids come from `assets/upgrade-icons-20261020/upload-receipts.json`
(uploaded October 20; all approved). Extra Luck reuses the Luck tree icon and Rally
the war horn. A key with no art draws a placeholder gem (`Theme.GemIcon`).

## Preview

UI Lab stories:
- **Rebirth:** the late-game preset, a Rebirth 10 player who can afford Rebirth 11,
  with Maxed, Available, Unaffordable, Locked and the Auto Rebirth toggle.
- **Rebirth (first, not ready):** the reference's 3,019 / 50,000 screen.
- **Time Skip claim (after a Rebirth):** the claim popup, 10 minutes from Rebirth 3,
  in the Welcome Back window (`MenuLayouts.OfflineEarnings`).

The menu editor previews the same panel.
