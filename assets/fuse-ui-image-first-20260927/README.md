# Image-led fuse UI revision

Only MergeBrowser presentation and Merge-specific AppController sizing changed in this pass. All server mechanics, MergeSelection and MergePresentation timing remain unchanged.

- Design target, reference screenshots, source prompt, native Figma screenshots and node ledger: `/Users/stevin/Documents/ChatGPT/My Chicken Army/assets/fuse-ui-image-first-20260927/`.
- Figma: page 434:885; ready 437:2024; picker 437:2135; result 437:2481.
- `ui-checks.luau`: disposable clones and UI objects; uses no real profile/transaction.
- `ui-checks.json`: six groups passed, including five layout sizes (900×850, 746×705, 390×720, 320×568, 700×320).
- Final Studio Edit compile/readback: MergeBrowser 26,976 bytes, polynomial hash 4233590291; AppController 40,377 bytes, hash 3334535819. Hash calculation is h=(h*31+byte) mod 2^32, starting at 0. Both matched source and compiled.
- `python3 tools/rojo.py build`: passed; this is a scripts-only package, not a map or live runtime test.
- Follow-up implementation check: started a fresh session-only Studio Play session from Edit. The existing authored machine prompt opened the new popup. The picker showed the eligible Camo trio; Add/Remove staged three exact IDs. One normal client/server fusion reduced the flock from 6 to 4, preserved the first staged ID at level 2, and removed the other two. A second immediate submission was suppressed while pending. Result: Camo Chick, Lv. 2, 16 eggs/s, 12.5 DPS. All test progress was disposable.
- `studio-ready.jpg`: final live UI after the portrait spacing and disabled-caption color corrections. `studio-result.jpg`: completed live server fusion. These are Studio viewport captures, not Figma renders. A fresh Play session verified the final portrait spacing; Play was stopped and Studio left in Edit. No physical-device or network-soak test is claimed.

Previous live mechanics evidence remains in `assets/fuse-flow-20260927/`. No publication, purchases, new Roblox asset uploads, real profile edits or unrelated code changes.
