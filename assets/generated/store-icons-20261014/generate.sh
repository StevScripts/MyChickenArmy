#!/bin/zsh
# Roblox store icons for My Chicken Army passes and products (October 14, 2026).
# Square, opaque, circle-safe (Roblox crops game pass icons to a circle).
OUT=${0:A:h}
REF=/Users/stevin/.codex/skills/chunky-simulator-icons/references/screenshots
GEN=/Users/stevin/.claude/skills/chatgpt-image/scripts/gen.py

STYLE="Roblox store icon for the game My Chicken Army. Chunky glossy cartoon game illustration in the style of the reference: exaggerated sturdy proportions, one strong simple silhouette, heavy continuous near-black outer contour, thinner dark interior lines, dimensional vector-clean 2.5D look, upper-left lighting, saturated lively colors with crisp glossy highlights. Square canvas. Background: a smooth bright radial gradient filling the whole square with soft light rays, in BGCOLOR. Keep the whole subject inside the central circle (about 72% of the width) so it survives a circular crop; nothing important near the corners. Any chicken is a chunky blocky white Roblox-style voxel chicken with a red comb, yellow beak and black stroke. No words except the exact text requested; no price, no watermark, no frame, no border."

gen() { # name bgcolor reference subject
	local prompt="${STYLE//BGCOLOR/$2} Subject: $4"
	python3 "$GEN" "$prompt" --image "$REF/$3" --quality medium --size 1024x1024 --background opaque --out "$OUT" --name "$1" &
}

gen AutoCollectEggs "teal and cyan" 03-gamepass-cards.png "a chunky red and silver vacuum cleaner nozzle sucking up a swirl of white and golden eggs."
gen DoubleCash "bright green" 03-gamepass-cards.png "a thick bundle of green cash banknotes with a gold band, and a huge bold gold '2X' with a dark outline in the upper right."
gen DoubleEggSpawn "warm orange and yellow" 03-gamepass-cards.png "a happy blocky white chicken sitting on a big pile of eggs, with a huge bold gold '2X' with a dark outline in the upper right."
gen BiggerArmy "deep blue" 03-gamepass-cards.png "a squad of five blocky white chickens wearing green army helmets marching together, with a big bold green plus sign with a dark outline in the upper right."
gen DoubleLuck "lime green and gold" 03-gamepass-cards.png "a big glossy four-leaf clover with a golden horseshoe behind it, and a huge bold gold '2X' with a dark outline in the upper right."
gen EggMagnet "purple and pink" 03-gamepass-cards.png "a chunky red horseshoe magnet with silver tips pulling three white eggs toward it with motion lines."
gen CommanderBanner "royal purple" 03-gamepass-cards.png "a blocky white chicken portrait inside an ornate gold square frame topped with a gold crown, with a small red victory flag beside it."
gen DoubleBounty "red and orange" 03-gamepass-cards.png "a bulging brown money bag full of gold coins with a red bullseye target tag, and a huge bold gold '2X' with a dark outline in the upper right."
gen PocketCoins "light green" 05-cash-packs.png "a small stack of green cash banknotes with a gold band and two gold coins."
gen CoopStash "green" 05-cash-packs.png "a medium pile of green cash bundles with gold bands and a few gold coins."
gen ArmyChest "emerald green" 05-cash-packs.png "a big bulging cloth sack overflowing with green cash bundles and gold coins."
gen CommandersVault "gold and green" 05-cash-packs.png "a heavy open steel vault door with a huge glowing pile of green cash bundles and gold coins spilling out."
gen OuterSpaceCrate1 "deep space purple with stars" 02-shop-crates.png "one glowing purple and cyan galaxy mystery crate with star patterns and a gold question mark on the front."
gen OuterSpaceCrate3 "deep space purple with stars" 02-shop-crates.png "three glowing purple and cyan galaxy mystery crates stacked in a small pyramid, star patterns and gold question marks."
gen OuterSpaceCrate10 "deep space purple with stars" 02-shop-crates.png "a big heap of ten glowing purple and cyan galaxy mystery crates with star patterns, sparkles and gold question marks."
wait
