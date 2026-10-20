#!/bin/zsh
# Second pass for the two transparent egg icons: the first pass dropped the egg's
# outline (EggValue) or the egg itself (EggPacking). Compares two models.
OUT=${0:A:h}
GEN=/Users/stevin/.claude/skills/chatgpt-image/scripts/gen.py
COINS="/Users/stevin/Documents/ChatGPT/My Chicken Army/assets/gold-coins-20261020"
OLD=/Users/stevin/Documents/ChatGPT/RobloxGameIdeas/pet-roll-prototype/assets/ui/upgrades-board-20260923
BASE="Game UI icon for the Roblox game My Chicken Army, in exactly the rendering style of the first reference image: chunky glossy cartoon illustration, heavy continuous near-black outer contour around EVERY object including the egg, thinner dark interior lines, dimensional vector-clean 2.5D look, upper-left lighting, saturated colors with crisp glossy highlights. The egg is warm cream-white with soft peach shading, a crisp white highlight and a thick near-black outline exactly like the egg in the first reference image; it must stay fully opaque. Every coin matches the second reference image: a thick dimensional cartoon gold coin with warm orange shadow planes, a raised rim and an embossed square blocky chicken head with comb and beak on its face, also with a thick near-black outline. No dollar signs, banknotes or paper money. Isolated on a genuine transparent background, about 80% canvas occupancy, complete unclipped silhouette with even padding. No text, numbers, card, frame, border, rays or background."
VALUE="Subject: the same large egg on the left as in the first reference image, and on the right, instead of the green banknote stack, a short slightly tilted stack of three thick gold chicken-crest coins overlapping the egg's lower right edge."
PACK="Subject: one big egg standing upright, slightly left of center and filling most of the height, with a small spill of three gold chicken-crest coins in front of its lower right: one coin standing on edge facing the viewer, two lying flat and overlapping. The egg is the main subject and is clearly visible."
for model in gpt-image-1.5 gpt-image-2; do
	python3 "$GEN" "$BASE $VALUE" --image "$OLD/MCA_Upgrade_EggValue_20260923.png" --image "$COINS/gold-coin.png" --model $model --quality high --background transparent --out "$OUT" --name "EggValueCoins-$model" &
	python3 "$GEN" "$BASE $PACK" --image "$OLD/MCA_Upgrade_EggSpeed_20260923.png" --image "$COINS/gold-coin.png" --model $model --quality high --background transparent --out "$OUT" --name "EggPackingCoins-$model" &
done
wait
