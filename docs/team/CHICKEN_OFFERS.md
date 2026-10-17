# Chicken offers: Robux ladder (October 16, 2026)

Owner request: cheap first purchase for many players, then bigger steps. Replaces the
unshipped Starter Pack idea. Six developer products, bought one after another.

| Step | Key | Robux | Chicken | Product ID |
|---|---|---|---|---|
| 1 | ChickenOffer1 | 9 | Chicken Jockey (Epic) | 3719084263 |
| 2 | ChickenOffer2 | 49 | Rainbow Rider (Legendary) | 3719084274 |
| 3 | ChickenOffer3 | 150 | Glitch Chicken (Mythic) | 3719084284 |
| 4 | ChickenOffer4 | 250 | Eclipse Chicken (Mythic) | 3719084303 |
| 5 | ChickenOffer5 | 500 | Rift Walker (Secret) | 3719084320 |
| 6 | ChickenOffer6 | 1,200 | Galaxy Overlord + Cosmic mutation (x5 eggs) | 3719084332 |

- **Catalog:** `ShopCatalog.Products.ChickenOffer1..6` (`chickenOffer` step, `species`,
  optional `mutation`, `image` = offer art) and `ChickenOfferOrder`. Products were created
  with `tools/monetization.py` (icons = the offer art).
- **Server:** `CommerceService:PreparePurchase` only allows the next step and needs a free
  Flock spot. `ProductService` always delivers a paid chicken (`investment=0`, so it never
  sells for cash), raises saved `chickenOfferStep` (0-6, never backwards) and
  `GameServer`'s `onGranted` hook walks it onto the plot. Guaranteed chickens, not random,
  so restricted accounts can buy them.
- **Client:** `HudController:BuildChickenOffer/UpdateChickenOffer`. The slot takes the Free
  Chicken spot once the free chicken is claimed; tapping opens Roblox's prompt directly.
  Solid white sunburst (`sunburst-white.png`, rbxassetid://90649675688974) tinted by an
  animated rainbow `UIGradient` (TweenService), green Robux price. Buying shows
  "<name> joined your Flock!" and the next step pops in; after step 6 the slot hides.
- **Art:** `assets/chicken-ladder-20261016/` - steps 2-6 keep the original portrait and add a
  light GPT-generated effect layer behind it (`fx/`, composites in `composite/`, uploads in
  `final/`).
- **Not testable in Studio:** real purchases (test sessions refuse them). The receipt path
  was verified with a stand-in profile.
