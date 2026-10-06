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

Native editable shop UI reproduces the Figma banner using its original images, approved full-sheet stud texture and shared UI theme. The current reel follows the user's recording: an empty tray bounces in over 1 second; cards enter after 0.9 seconds and travel with native Quart Out for 8.45 seconds, followed by a 1.5-second result hold and 1-second Back In exit. Cards enlarge continuously near the marker, reaching 1.25× at its center. The backdrop fades to 55% black over 0.65 seconds; the exit fade starts after the downward anticipation. Reduced motion displays only the result for 1.4 seconds. Travel uses TweenService through UIMotion; focus derives from the tweened card positions.

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

## Disposable Studio test roll

The current playtest uses PetRollPlaytestSessionOnly=true, so paid checkout correctly remains unavailable: temporary progress is not a writable saved profile. Shop now shows a separate Test roll button in this mode. It uses the configured server reward pool and normal reel, recruits a temporary chicken, and preserves existing crate credits. No Robux is charged; rewards reset on Stop. Saved/live sessions do not expose this test action, and ordinary paid checkout/opening guards remain intact.

Thirty client fixtures and ten server fixtures passed. An actual button click completed the reel and awarded Galaxy (StormDuck), increasing the temporary flock from three to four while crate credits remained zero and productReady remained false. The live playtest was left running with Shop open and Test roll enabled. See studio-test-verification.json and check-studio-crate.luau. The full local place backup above includes the test-roll changes; no experience publication was performed.

## Earlier motion polish — superseded by reference match

The previous Quart-Out curve covered only 0.293 card strides in its final two seconds, creating a near-stationary tail. The replacement starts during panel entry, joins acceleration/deceleration without a velocity jump, and keeps moving visibly until the landing. Tick sounds use the existing bounded three-voice overlap instead of destroying each previous tick. The winner grows gently over 0.28 seconds. Timings are editable in DEFAULT_TIMING at the top of src/client/GalaxyCrateRollPresentation.luau; restart Play after edits. These are local tuning choices, not claimed measurements from the reference game.

Six focused runtime checks passed: normal/busy/centering/monotonic movement, cancellation during each motion phase, reduced motion, zero-duration spin, and destruction. A real Test roll awarded Alien and completed in about 11.33 seconds, with matching server/reel reward and no reverse travel; sampled motion covered about 2.89 card strides within the final two seconds. See motion-polish-verification.json. No frame-rate improvement or subjective audio-quality claim is made. The updated full place was saved locally; no experience publication or paid purchase occurred.

## Current reference match

The user rejected the custom smoothing and requested the recording's motion. Sequential frame timestamps and native-frame extraction were used to remeasure the complete reel. The slow tail is intentional in this reference. A local template track fits a fourth-power remaining-distance curve with 0.146-pixel RMS error at half recording resolution, substantially closer than cubic or quintic candidates. The measured exit fits Back In over approximately one second. See reference-match/tail-fit.json and reference-match/reviewer/review.md for source observations; timestamps are approximate because the supplied video has variable frame durations.

The current implementation restores the empty entrance, delayed stream of cards, continuous marker focus, long slowdown, intact result hold, and downward anticipation before exiting upward. Borders and marker proportions were adjusted to the reference. Galaxy chicken artwork, configured odds and existing game audio remain the game's own.

Six focused lifecycle checks passed. A live Test roll awarded Astronaut with matching centered reward, 1.25× center emphasis, monotonic travel and an empty entrance. Without screenshot capture interrupting the render, the measured phases were 0.901 seconds to spin, 8.453 seconds of spin, 1.513 seconds of hold, and 1.035 seconds of exit (11.903 seconds total). A separate temporary still confirmed the corrected thin white card borders and rounded outlines, then was destroyed. See reference-match/verification.json. No claim of literal pixel or audio identity is made.

The final source was synced to Pet Roll Test and saved with the current full map in assets/plot-parity-20261006/MyChickenArmy-Six-Matching-Plots-20261006.rbxl. That later file, rather than the original Galaxy backup above, contains this reference-matching revision. No experience publication, paid purchase or persistent profile write occurred.
