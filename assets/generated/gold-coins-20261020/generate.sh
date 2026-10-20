#!/bin/zsh
# October 20, 2026 Cash -> Coins conversion: the art the user's coin set did not cover.
# In-game icons are transparent; store icons are square, opaque and circle-safe
# (Roblox crops game pass icons to a circle), like store-icons-20261014.
OUT=${0:A:h}
GEN=/Users/stevin/.claude/skills/chatgpt-image/scripts/gen.py
COINS="/Users/stevin/Documents/ChatGPT/My Chicken Army/assets/gold-coins-20261020"
OLD=/Users/stevin/Documents/ChatGPT/RobloxGameIdeas/pet-roll-prototype/assets/ui/upgrades-board-20260923
STORE=${OUT:h}/store-icons-20261014
MODEL=${MODEL:-gpt-image-1.5}

COIN_LOOK="Every coin must match the gold coin reference exactly: a thick dimensional cartoon gold coin with warm orange shadow planes, crisp upper-left highlights, a raised rim and an embossed square blocky chicken head with comb and beak on its face. No dollar signs, no banknotes, no paper money."

ICON="Game UI icon for the Roblox game My Chicken Army. Chunky glossy cartoon game illustration: exaggerated sturdy proportions, one strong simple silhouette, heavy continuous near-black outer contour, thinner dark interior lines, dimensional vector-clean 2.5D look, upper-left lighting, saturated colors with crisp glossy highlights. $COIN_LOOK Isolated on a genuine transparent background, about 80% canvas occupancy, complete unclipped silhouette with even padding. No text, letters or numbers, no card, frame, border, rays or background."

STORE_STYLE="Square Roblox store icon artwork for the game My Chicken Army. Chunky glossy cartoon game illustration in the style of the store icon reference: exaggerated sturdy proportions, one strong simple silhouette, heavy continuous near-black outer contour, thinner dark interior lines, dimensional vector-clean 2.5D look, upper-left lighting, saturated lively colors with crisp glossy highlights. Use the first reference image only for its rendering style, radial background treatment and framing; never copy its subject. Use the second reference image for the coin design and object. Background: a smooth bright radial gradient filling the whole square with soft light rays, in BGCOLOR. Keep the whole subject inside the central circle (about 72% of the width) so it survives a circular crop; nothing important near the corners. Any chicken is a chunky blocky white Roblox-style voxel chicken with a red comb, yellow beak and black stroke. $COIN_LOOK Absolutely no text, letters, words, titles or logos anywhere in the image unless this prompt explicitly quotes them; no price, no watermark, no frame, no border."

icon() { # name subject refs...
	local name=$1 subject=$2; shift 2
	local refs=(); for r in "$@"; do refs+=(--image "$r"); done
	python3 "$GEN" "$ICON Subject: $subject" "${refs[@]}" --model "$MODEL" --quality high --size 1024x1024 --background transparent --out "$OUT" --name "$name" &
}
store() { # name bgcolor subject refs...
	local name=$1 bg=$2 subject=$3; shift 3
	local refs=(); for r in "$@"; do refs+=(--image "$r"); done
	python3 "$GEN" "${STORE_STYLE//BGCOLOR/$bg} Subject: $subject" "${refs[@]}" --model "$MODEL" --quality high --size 1024x1024 --background opaque --out "$OUT" --name "$name" &
}

# Upgrades tree hex: Egg Value (replaces the egg + green banknotes icon).
icon EggValueCoins "Recreate the composition of the first reference image: the same large cream-white egg on the left, and on the right, instead of the green banknote stack, a short slightly tilted stack of three thick gold chicken-crest coins overlapping the egg's lower right edge. Keep the egg's shape, glossy shading and black outline." "$OLD/MCA_Upgrade_EggValue_20260923.png" "$COINS/gold-coin.png"
# Research Economy E4-E6 (Careful Packing, Farm Brand, Premium Packing) and the Rebirth egg card.
icon EggPackingCoins "One big cream-white egg standing upright slightly left of center, drawn in the same style as the eggs in the first reference image, with a small spill of three gold chicken-crest coins in front of its lower right: one coin standing on edge facing the viewer, two lying flat and overlapping." "$OLD/MCA_Upgrade_EggSpeed_20260923.png" "$COINS/gold-coin.png"

store DoubleCoins "bright emerald green" "one big thick gold chicken-crest coin in three-quarter view with two more coins tucked behind it, and a huge bold gold '2X' with a dark outline in the upper right." "$STORE/DoubleLuck-20261014-163326.png" "$COINS/gold-coin.png"
store PocketCoins "light sky blue" "a blocky white voxel chicken standing behind a small pile of three thick gold chicken-crest coins, like the coin pack reference, proudly showing them off." "$STORE/CommanderBanner-20261014-163325.png" "$COINS/pocket-coins.png"
store CoopStash "bright azure blue" "a red-orange drawstring sack bulging with gold chicken-crest coins with a few coins spilling out in front, like the sack reference." "$STORE/DoubleEggSpawn-20261014-163326.png" "$COINS/coin-stash.png"
store CoinChest "royal blue" "an open square dark-wood military supply chest with brass corners overflowing with gold chicken-crest coins, like the chest reference, with a blocky white voxel chicken peeking from behind it." "$STORE/CommanderBanner-20261014-163325.png" "$COINS/coin-chest.png"
store CommandersVault "deep royal blue with a warm golden glow" "a heavy open dark-iron commander vault with gold trim and a huge glowing pile of gold chicken-crest coins spilling out, like the vault reference, with a blocky white voxel chicken standing beside it." "$STORE/CommanderBanner-20261014-163325.png" "$COINS/commander-vault.png"
wait
