# Owner checklist: Creator Dashboard (Phase 0)

You do these yourself; they need your Roblox login. About 45 minutes. Details and reasons are in [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §4.

Universe 10765467283, place 96683186622050, owned by the group Kiru Experiences.

## Store page

- [ ] **Icon (P0.1).** Upload a 512×512 icon. The live icon is Roblox's grey placeholder. If you already uploaded one, check whether moderation is holding it. Suggested art: the helmeted chicken from thumbnail 2, face filling the square, thick outline, bright background, readable at 50×50.
- [ ] **Description (P0.2).** Paste:

```
🐔 Raise chickens. Build an army. Conquer everything!

🥚 Collect eggs from your flock and sell them for cash
🎰 Pull the lever to recruit rarer chickens, all the way to Mythic
🧬 Fuse 3 matching chickens into a GIANT
⚔️ Send your army to capture camps and other players' land
👑 Defeat the Chicken King and rule the island

👍 Like the game and join the group for updates!
📱 Plays on mobile, tablet, desktop and console
```

  After publish 1, add: `🎖️ Re-enlist to become a Veteran and earn permanent bonuses` and `📅 Log in every day for streak rewards`.
- [ ] **Genre (P0.3).** Simulation (Tycoon subgenre if offered).
- [ ] **Trailer.** Upload `My-Chicken-Army-Trailer-v4.mp4` to YouTube (unlisted is fine) and add the link under the experience's Thumbnails & Videos.

## Passes (P0.4)

Put on sale only after the lead confirms each one works in the test pass (see [`02_LEAD.md`](02_LEAD.md) §6):

- [ ] Auto Collect Eggs (1978713718): 199
- [ ] 2x Cash (1980764263): 399
- [ ] 2x Egg Spawn (1979943376): 199
- [ ] Bigger Army (1980638268): 499
- [ ] 2x Luck (1975521949): 399
- [ ] **Leave Auto Merge (1975401932) off sale.** The feature is switched off.

## Developer products

- [ ] **Cash packs (P0.5).** Rewrite each description (it still says "Test product: unavailable until secure purchase delivery is enabled"), then put on sale: Pocket Cash 49, Coop Stash 199, Cash Sack 799, Commander's Vault 2,499.
- [ ] **Finish Processing Now (P0.6).** Product 3714566216: turn **off** sale. It sells a feature that is disabled.
- [ ] **Galaxy Crates (P0.7).** Test lower prices: 1 crate 149, 3 crates 399, 10 crates 1,199. Tell the lead so `ShopCatalog.proposedPrice` is updated to match.

## At publish time

- [ ] After every publish that adds saved data: **Servers → Restart servers for updates** (or Shut down all servers). Old servers erase new saved fields. See [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §3.2.
- [ ] Before publishing, write down the current version number in Version History so you can roll back.

## Decisions you need to make tonight

Answer these in the lead session before workers start (they're in [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §14):

1. Rebirth keeps chicken levels? (Plan says yes.)
2. Rebirth name and ranks: "Re-enlist" and "Veteran I, II, III"?
3. Is a Pumpkin Chicken model possible by about Oct 22? If not, H1 is cancelled.
