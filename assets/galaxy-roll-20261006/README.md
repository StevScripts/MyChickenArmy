# Galaxy crate shop and rolling — October 6, 2026

Implemented in Pet Roll Test (96683186622050), using the approved Figma banner 520:885 in file 4lJjZOqNhR8K7rfMbVIjaK. The supplied screen recording was sampled across its full duration and more densely through entrance/exit transitions. Original Figma artwork is preserved in art/; image-assets.json records group uploads.

## Rewards

| Chicken | Chance | Catalog ID |
| --- | ---: | --- |
| Astronaut | 40% | Astronaut |
| Alien | 30% | Alien |
| Galaxy | 20% | StormDuck |
| Dark Matter | 9% | DarkMatter |
| Cosmic Dragon | 1% | CosmicDragon |

These values are shared by the server reward pool, shop disclosure and client presentation. New species have zero normal-roll weight. Existing paid purchase receipt and policy checks remain authoritative. One confirmed crate credit opens one reveal; other purchased credits remain available through Open 1. Decorative reel cards use weighted sampling, and the server result fixes the winning card.

## Presentation

Native editable shop UI reproduces the Figma banner using its original images, approved full-sheet stud texture and shared UI theme. Reel timing: 0.65-second entry, 0.1-second settle, 8-second Quart slowdown, 2-second result hold, 0.5-second exit. Reduced motion displays the result for 1.4 seconds. Motion uses TweenService through UIMotion.

Prepared gameplay models live in ReplicatedStorage.PetRoll.ChickenAssets. The original staged models and world lineup are preserved. The three new block chickens use the existing 18-bone clip contract. The dragon preserves its 8.75-stud mesh height, ordinary gameplay collider, native flight and 1.4-second forward attack. Its physical Animator belongs to Humanoid; previews use AnimationController. Authoring-only duplicate clips are removed only from the gameplay clone. Dark Matter retains the existing scrolling UV material.

## Verification

- 20 isolated commerce fixture checks passed; no actual purchase or profile write.
- Server crate boundary samples produced all five expected rewards, consumed exactly one credit and rejected a second opening with no credits.
- Physical constructors and animation playback checked for all five models. Dragon animated 23 bones; attack displacement stayed X=0 and moved forward on -Z, then returned to flight.
- Dark Matter UV animation reported ready, 72 moving UVs and an advancing phase.
- Reel normal completion, reduced motion, busy rejection, cancellation and destruction passed. A first fixed-delay completion assertion was too early; the final event/deadline check passed.
- Winner centering differed from the marker by approximately 0.000027 pixels in the measured viewport.
- Both normal game bootstrap scripts were restored enabled after isolated tests.

See verification.json, check-commerce.luau, Shop-Preview.jpg and Reel-Preview.jpg. The screenshots are editor fixtures showing recorded launch prices; no purchase occurred.

## Saved state and listing activation

Full place backup: MyChickenArmy-Galaxy-Shop-Roll-20261006.rbxl. Source changes were selectively synced through Rojo on port 34875. No experience publish or Git push was performed.

After explicit user approval, all three existing developer products were activated in Safari on October 6: 500 Robux for one (3712929703), 1,250 for three (3712929865), and 4,000 for ten (3712929926). Their names now use Galaxy Crate and descriptions disclose the five reward odds. Managed pricing remains disabled. MarketplaceService independently confirmed IsForSale=true and UserBasePriceInRobux=500/1250/4000. This account receives a 20% Roblox Plus discount, so its returned PriceInRobux values are 400/1000/3200. Runtime uses these account-specific prices. No purchase or experience publication was performed during activation. See listing-activation.json.
