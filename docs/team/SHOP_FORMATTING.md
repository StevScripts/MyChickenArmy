# Shop formatting

## October 21, 2026: one horizontal card rail (reference parity, P8)

Contract: `docs/team/REFERENCE_PARITY_20261021.md` §2.7 (Stevin's third Drop a Fruit
recording, frames t57/t65/t67 in
`~/Documents/ChatGPT/My Chicken Army/output/2026-10-21-recording-3/frames/`). This
section supersedes the October 6 grid, the October 15 section tabs and the October 21
2x2 pass grid below. Only the existing catalog is on the rail; nothing new went on
sale and every price still comes live from the Marketplace (`CommerceController`).

**Window.** The reference window is 818 x 469 (`SHOP_ASPECT`); gold stud header with
the basket icon and the red X (`Theme.HeaderClose`, phone pad 1.65). Inside the body a
lighter translucent card (the shared popup look) holds ONE horizontal `ScrollingFrame`
("OfferRail") with a thin light scrollbar along its bottom. No section tabs.
Cards are 335/365 of the rail's height; widths are in card heights: 15/335 lead-in,
10/335 gaps, tall cards 245/335. `Browser:Layout()` places the visible columns from
the rail's own aspect (fixed by the window's constraint), so every device shows the
same rail at its own size and scrolls it sideways. Content count sets its length.

**Cards, left to right** (the reference opens on a tall green card beside the pack
column with the next card peeking in, and 2x Luck sits right before the 2x2):

| Ours | Reference card | Content |
|---|---|---|
| 2x Coins | Server Luck (tall green) | title plate, coin + "x2" on a sunburst, one benefit line, green R$ pill |
| Galaxy Crate (`GalaxyCrateShop`, 480 x 335) | Meme Fruit Pack | title plate, crate art top-right, the five rewards as black-stroke portraits with Coins/s above (coin icon, gold) and odds in the corner, green pills "R$ N / Buy 1 / Buy 3 / Buy 10" (Buy 10 caption cyan), disclosure line; "Open 1" / Studio "Test roll" pill on the crate art only with crate credits or in Studio |
| 2x Egg Spawn, Bigger Army | VIP Pass (tall orange) | as 2x Coins, in their approved colours |
| 2x Luck | 2x Luck Pass (tall green, clover) | "Gain 2x Luck to get better chickens!"; restricted accounts see "Guaranteed Offers!" |
| Pocket Coins, Coop Stash, Coin Chest, Commander's Vault | the 2x2 of small Time Skip cards (5m, 15m, 1h, 4h) | blue cards: title, pack art, the live payout beside the coin in gold, orange-gold R$ pill; the Vault carries "BEST VALUE!" (verified live prices) or "BIGGEST!" |
| Rebirth Skip (only when RebirthPanel shows Skip!) | 1 Day Time Skip (big, last) | purple tall card, "Rebirth N now and keep your upgrades!", R$ pill; a bought Skip reads "Ready!" and opens the Rebirth screen |

Our four coin packs pay 10 min / 45 min / 3 h / 10 h of income, the same idea as the
reference's four small Time Skips, so they take that 2x2 one-to-one. The reference's
big "1 Day" card has no product of ours; the Rebirth Skip takes the last slot when it
is on sale. Owned passes show a gold "Owned" pill; tapping one answers with the
Locked cue and a shake. The whole card is the button on passes, coin packs and the
Rebirth Skip (card hits are far above 48 px on a phone); the Galaxy pills grow their
hit areas upward with `Theme.PadHit` to 48 px.

**Gift!** A red button under the window's right edge (160 x 44 of 818 x 469) with the
gift box art opens the Free Gift popup through `app.freeGift:Open()`, the HUD gift's
call. It shows while the free chicken is unclaimed (the HUD gift's rule).

**Deep links.** `ShopBrowser:ScrollTo(key)` (alias `Show`) slides the rail to a card:
"Galaxy", any pass or coin-pack key, "RebirthSkip", a crate product key, or the old
section names "Passes", "Cash"/"Coins", "Crates". Today no other file calls it;
`app:OpenPage("Shop")` (ChickenBrowser, HUD) opens on the first cards.

**Feel.** Every open resets the rail to its start and reveals the cards one after
another (`Motion:Reveal`); cards and pills use `BindButton` (hover grow, press shrink,
shine; hover cue from the shared UI binding). A confirmed purchase punches the card,
throws confetti from it and plays `UIPurchase` (fallback `Claim`); a Rebirth Skip
credit arriving punches its pill with `Badge`; the Gift! button pops in. The menu
blur comes from `AppController:OpenPage`. Reduced motion settles every effect and
makes deep-link scrolls instant.

Not copied on purpose: struck-through "old" prices and "%50 OFF!" tags (our prices
have no earlier price; a fake discount would mislead), the reference's Server Luck,
Advanced Pack, VIP and 1 Day products (we sell no equivalents), and the separate
"Prices from Roblox" status line (pills already show "Check Roblox", "Check save" and
the other states; the Galaxy card keeps the Studio test-roll message).

---

## October 6, 2026 (historical)

Reference: [user-supplied Mini War Shop recording](</Users/stevin/Desktop/Screen Recording 2026-10-06 at 3.17.50 AM.mov>),
18.820 seconds at 3456 × 2234.

The user requested the title formatting and compact card grouping shown in the
supplied Mini War Shop recording. The pass view around 4 seconds shows three
nearly square cards per row, approximately 1.1 width-to-height, with narrow
gutters of about 1% of section width. These are visual estimates, not recovered
reference properties.

## Presentation contract

- Arrange game passes three across with the same narrow horizontal and vertical
  gutters. Added offers extend the scrolling grid without changing card shape.
- Use compact centered Featured, Gamepasses and Cash headings with small
  flanking icons from the existing approved artwork. The Featured container
  wraps the existing Galaxy presentation without changing its banner internals.
- Group the wide featured cash pack directly above three smaller cash packs;
  use the same narrow gutters between the smaller packs and below the feature.
- Keep native Scale geometry, aspect constraints and TextScaled. Content and
  card padding stay internal. Recalculate section proportions and the existing
  explicit scroll canvas from the complete content height.

This supersedes the older two-column pass grid and 0.075 horizontal/0.04 vertical
spacing recorded in the September 30 catalog audit. The existing gold shared
header and seamless header/body shell remain. Preserve GalaxyCrateShop, current
offer contents and ordering, approved colors/artwork, and the native commerce
flow, including enabled-offer filtering, entitlement/policy checks, current
Roblox prices and unavailable/pending states. Preserve the Studio Test roll
status message already present in ShopBrowser.

Implemented in `src/client/ShopBrowser.luau`: three columns, 1.10 pass-card
aspect and 0.012 section-width gutters, with larger purchase buttons in the
small cash cards. The existing Rojo connection delivered the source to Studio;
source readback matched the local file. The active Play session was left
running, so a fresh session is needed to load the revised browser. Saved menu
previews were not regenerated during Play. No playtest or rendered-layout
comparison was performed.
