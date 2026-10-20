#!/bin/zsh
# Upgrade tree, Gem Upgrade, currency and HUD icons for the October 20 overhaul (session S6), v2.
# v2 (Stevin, Oct 20: "they don't look like the rest of the icons in the game"): every prompt is
# anchored on the approved in-game icons (the Sep 23 tree atlas and the Oct 2 research icons),
# following DESIGN.md section 8 and the chunky-simulator-icons skill. Transparent 1024x1024
# masters; every candidate lands in raw/ and the chosen one is copied to <Key>.png.
#
#   ./generate.sh                 every new base icon (variants need their chosen base first)
#   ./generate.sh EggVacuum Gems  only these keys
#   ./generate.sh variants        edits of chosen bases (Vacuum*, *Machine, GoldRate, AutoRoll, MoreGems)
#   ./generate.sh outline KEY...  redraw chosen masters with the set's heavy outer outline
#
# Not generated, because an approved in-game icon already covers the node (see README.md):
# EggSpeed, EggValue, Luck, FlockSize, ArmySize, RollSlot, ChickenFeed, MarchSpeed, Health,
# Recovery and Rally.
OUT=${0:A:h}
RAW=$OUT/raw
REPO=${0:A:h:h:h}
GEN=/Users/stevin/.claude/skills/chatgpt-image/scripts/gen.py
MODEL=${MODEL:-gpt-image-1.5}
BATCH=${BATCH:-9}

# Approved in-game icons: the main consistency anchors.
ATLAS="$HOME/Documents/ChatGPT/My Chicken Army/output/upgrades-concept/separate-icons"
RESEARCH=$REPO/assets/research-20261002/icons
BOOTS=$RESEARCH/boots.png
MEDKIT=$RESEARCH/medkit.png
PODIUM="$ATLAS/roll-slots.png"
EGGS="$ATLAS/egg-laying-speed.png"
CLOVER="$ATLAS/luck.png"
CHICKENS="$ATLAS/army-size.png"
SOLDIERS=$REPO/assets/army-hud-20260927/my-army-soldiers.png
COIN=$REPO/assets/gold-coins-20261020/upload/GoldCoin.png
REENLIST=$REPO/assets/generated/reenlist-icon-20261013/reenlist-20261013-231836-1.png
HORN=$REPO/assets/generated/rally-icon-20261016/rally-horn-20261016-031355.png
GEMPACKS=/Users/stevin/.codex/skills/chunky-simulator-icons/references/screenshots/04-gem-packs.png

STYLE="Create one original icon for the Roblox game My Chicken Army that belongs in the attached approved in-game \
icon set. Match those attached icons exactly: a toy-like Roblox look, bright clean saturated colors, simple shading \
with the lightest top faces, mid left faces and darker right faces, a few small crisp highlights, very little interior \
line work, no texture, no realistic materials, no heavy gloss, and a heavy continuous near-black outer outline of the \
same weight as the attached icons. Slight top-down three-quarter view, upper-left light. Draw only the one new subject \
described below, never the attached subjects. One isolated subject centered on a square canvas, about 80 percent of \
the canvas along its longest side, unclipped, readable at 64 pixels. Transparent background: no backdrop, floor, \
shadow, glow, rays, card or frame. No text, letters, numbers, prices or badges."
BLOCKY="Build it from chunky voxel cubes and beveled blocks with small square pixel details, like the attached boots, \
first-aid kit and podium."
SMOOTH="Keep its round forms smooth, simple and chunky like the attached eggs, stopwatch and clover, with the same heavy \
outline as the attached boots."
CHICKEN="Every chicken is the game's voxel chicken exactly like the attached chickens: white cube body and cube head, \
red block comb, yellow block beak, red block wattle, small black square eyes, orange block feet, and a thick black \
outline around the whole chicken."
COINS="Every coin is the game's gold coin from the attached coin image: a thick gold disc with a raised boxy chicken-head \
emblem. Never a dollar sign or banknotes."
GEMS="Gems are violet-purple crystals with large flat facets: bright lavender top facets, rich violet middle, deep \
purple lower facets."

# Modifier symbols, like the in-game Flock Size arrows: chunky, bright green, heavy black outline, lower left.
AT="with a thick black outline, at the lower left, slightly overlapping the subject, with no circle or badge behind it"
PLUS="a chunky bright-green blocky plus sign $AT"
CYCLE="a chunky bright-green circular double arrow (two curved arrows chasing each other around an empty circle) $AT"
UP="a chunky bright-green blocky up arrow $AT"
FASTFWD="a chunky bright-green blocky fast-forward double arrow $AT"

EDIT="Edit the first attached image. Keep the same object, outline weight, colors, lighting, perspective, size and \
framing exactly, and keep the background fully transparent. No text, letters or numbers. Change only this:"
OUTLINE="add a heavy continuous near-black outer outline around the entire silhouette, as thick as the outline on \
the attached boots, and give every chicken a clearly visible black stroke. Keep every other detail the same."

jobs_started=0
throttle() { (( ++jobs_started % BATCH == 0 )) && wait }

gen() { # KEY BLOCKY|SMOOTH "subject" extra-reference...
	local key=$1 build=$2 subject=$3; shift 3
	local look refs=()
	if [[ $build == BLOCKY ]]; then look=$BLOCKY; refs=($BOOTS $MEDKIT $PODIUM)
	else look=$SMOOTH; refs=($EGGS $CLOVER $BOOTS); fi
	local args=() ref
	for ref in $refs "$@"; do args+=(--image "$ref"); done
	python3 "$GEN" "$STYLE $look Subject: $subject" "${args[@]}" --model "$MODEL" --quality medium \
		--size 1024x1024 --background transparent --out "$RAW" --name "$key" &
	throttle
}

edit() { # KEY BASE "change" [extra reference...]  (BASE is a chosen master's key or an image path)
	local key=$1 base=$2 change=$3; shift 3
	[[ $base == */* ]] || base=$OUT/$base.png
	[[ -f $base ]] || { print -u2 "$key: choose $base first"; return }
	local args=() ref
	for ref in "$@"; do args+=(--image "$ref"); done
	python3 "$GEN" "$EDIT $change" --image "$base" --image "$BOOTS" "${args[@]}" --model "$MODEL" --quality medium \
		--size 1024x1024 --background transparent --out "$RAW" --name "$key" &
	throttle
}

icon() {
	case $1 in
	# Main tree
	RollSpeed) gen $1 BLOCKY "Roll Speed upgrade (rolls are faster). A chunky blocky roll lever: a short dark-gray block \
lever arm angled up and to the right out of a stepped dark-gray block base, topped with a big red cube knob, and a \
chunky gold blocky lightning bolt with a thick black outline at the lower left." ;;
	GoldMachine) gen $1 BLOCKY "Gold Machine (special gold rolls). A chunky blocky roll machine made of bright gold \
blocks, like a small toy gacha cabinet: a square window on the front showing a glowing gold star, a red cube-knob \
lever on its right side, and a small coin slot." ;;
	# Category hexes
	OpenTools) gen $1 BLOCKY "Tools category button. A chunky red blocky toolbox with a gray block handle on top, gold \
block latches, and a chunky gray blocky wrench lying across its lid." ;;
	OpenPlayer) gen $1 BLOCKY "Player category button. A classic yellow Roblox-style blocky figure head: a rounded \
yellow cube seen from the front with a simple friendly face of two black oval eyes and a small black smile." ;;
	OpenArmy) gen $1 BLOCKY "Army category button. One chunky olive-green army helmet built from stepped blocks, with a \
dark green strap band and a gold blocky star on the front." $SOLDIERS ;;
	Back) gen $1 BLOCKY "Back button. One chunky blocky white arrow that makes a U-turn and points to the left, white \
with light gray side faces and a heavy black outline." ;;
	# Tools subtree
	EggVacuum) gen $1 BLOCKY "Egg Vacuum tool (a handheld vacuum that sucks up eggs). A chunky blocky handheld vacuum \
gun in side three-quarter view: red block body with a yellow block trigger and grip, a short gray block nozzle pointing \
left, and a clear block tank on top holding three small white eggs." ;;
	# Player subtree
	WalkSpeed) gen $1 BLOCKY "Walk Speed upgrade (you walk faster). One chunky blocky red and white sneaker in side view \
with a thick white block sole, and three short chunky white speed streaks with black outlines behind its heel." ;;
	ClickRange) gen $1 BLOCKY "Click Range upgrade (collect eggs from farther away). A chunky blocky yellow Roblox-style \
hand pointing down with one finger as if tapping, with two chunky orange square ripple rings spreading flat around the \
fingertip." ;;
	OfflineTime) gen $1 SMOOTH "Offline Time upgrade (earn for longer while away). A chunky yellow crescent moon with a \
small red twin-bell alarm clock resting in its curve; the clock face has simple tick marks and hands, no numbers." ;;
	# Army subtree
	Damage) gen $1 BLOCKY "Army Damage upgrade. One chunky blocky voxel sword pointing up and slightly right: a wide \
light-gray steel blade made of stepped blocks, a gold block crossguard, a red block grip and a gold cube pommel." ;;
	Armor) gen $1 BLOCKY "Army Armor upgrade (chickens take less damage). A chunky blocky steel breastplate (chest \
armor) in front view: light-gray beveled metal blocks with gold block rivets and gold trim along its edges." ;;
	BossDamage) gen $1 BLOCKY "Boss Damage upgrade (hit the Chicken King harder). A chunky blocky gold king's crown with \
red square gems and a jagged crack down its middle, with a blocky steel sword stabbing down behind it." ;;
	Bounty) gen $1 BLOCKY "Bounty upgrade (more Coins from defeated enemies). A chunky blocky brown burlap sack tied with \
a rope, overflowing with gold coins, with a red and white square target tag hanging from the rope. $COINS" $COIN ;;
	CaptureSpeed) gen $1 BLOCKY "Capture Speed upgrade (capture camps faster). A chunky blocky red victory flag with a \
gold block star, waving on a short brown block pole, and $CYCLE." ;;
	# Gem Upgrades
	CoinBoost) gen $1 SMOOTH "Coin Boost upgrade (more Coins). A neat stack of four gold coins, and $UP. $COINS" $COIN ;;
	AutoRebirth) edit $1 $REENLIST "add a chunky silver gear with a thick black outline behind the shield's lower \
left, partly hidden by the shield. Keep the heavy black outer outline everywhere." ;;
	TimeSkip) gen $1 SMOOTH "Time Skip upgrade (instant Coins when you rebirth). A chunky red twin-bell alarm clock with \
a white face showing two black hands and simple tick marks, no numbers, and $FASTFWD." ;;
	KeepUpgrades) gen $1 BLOCKY "Keep Upgrades upgrade (keep some upgrades through a Rebirth). A chunky blocky gold \
shield with a deep purple center and a big chunky bright-green blocky up arrow emblem on its face." ;;
	MutationLuck) gen $1 BLOCKY "Mutation Luck upgrade (more mutated chickens). One voxel chicken whose white body \
shimmers with rainbow colors in soft bands of pink, yellow, green, cyan and violet, surrounded by four small white and \
gold square sparkles. $CHICKEN" $CHICKENS ;;
	OfflineCoins) gen $1 SMOOTH "Offline Coins upgrade (earn more while away). A chunky yellow crescent moon with a small \
pile of gold coins resting in its curve. $COINS" $COIN ;;
	ArmyPower) gen $1 BLOCKY "Army Power upgrade (stronger army). One voxel chicken wearing an olive-green army helmet, \
standing heroically, with a blocky fiery orange-red power aura around it, and $UP. $CHICKEN" $CHICKENS $SOLDIERS ;;
	RebirthChickenOdds) gen $1 BLOCKY "Rebirth Chicken Odds upgrade (Rebirth chickens show up more often). One voxel \
chicken wearing a dark green veteran beret with a small gold rank badge, with a chunky green four-leaf clover at the \
lower left and two small square sparkles. $CHICKEN" $CHICKENS ;;
	# Currency and HUD
	Gems) gen $1 SMOOTH "Gems currency. One big violet gem in front view, a classic brilliant cut with a wide flat top \
table and a pointed bottom. $GEMS" $GEMPACKS ;;
	FriendBoost) gen $1 BLOCKY "Friend Boost (more Coins with friends in your server). Two voxel chickens side by side, \
turned toward each other, giving each other a high five with raised wings, with a small burst of yellow square sparkles \
where their wings meet. $CHICKEN" $CHICKENS ;;
	GoldRush) gen $1 SMOOTH "Gold Rush event (double Coins for everyone). A chunky glossy golden cloud raining a shower \
of gold coins, with a few sparkles. $COINS" $COIN ;;
	# Variants: edits of a chosen base master
	VacuumCapacity) edit $1 EggVacuum "make the clear tank packed full of small white eggs, and add two stacked chunky \
bright-green blocky up arrows $AT." ;;
	VacuumRange) edit $1 EggVacuum "add three chunky yellow curved suction arcs with thick black outlines in front of \
the nozzle on the left, each wider than the last, like sonar waves." ;;
	GoldRate) edit $1 GoldMachine "add $CYCLE." ;;
	DiamondMachine) edit $1 GoldMachine "rebuild the machine body from pale icy diamond blocks: white and very light \
cyan faceted crystal cubes with bright white glints; the window shows a glowing white-blue diamond instead of the star. \
The lever knob stays red." ;;
	RainbowMachine) edit $1 GoldMachine "rebuild the machine body from glossy rainbow blocks in bands of red, orange, \
yellow, green, blue and purple; the window shows a glowing rainbow star. The lever knob stays red." ;;
	AutoRoll) edit $1 RollSpeed "remove the lightning bolt; add a chunky gray blocky gear behind the lever base and \
$CYCLE." ;;
	MoreGems) edit $1 Gems "turn the single gem into a small heap of three of the same violet gems, and add $PLUS." ;;
	*) print -u2 "unknown icon: $1" ;;
	esac
}

BASES=(RollSpeed GoldMachine OpenTools OpenPlayer OpenArmy Back EggVacuum WalkSpeed ClickRange OfflineTime Damage
	Armor BossDamage Bounty CaptureSpeed CoinBoost AutoRebirth TimeSkip KeepUpgrades MutationLuck OfflineCoins ArmyPower
	RebirthChickenOdds Gems FriendBoost GoldRush)
VARIANTS=(VacuumCapacity VacuumRange GoldRate DiamondMachine RainbowMachine AutoRoll MoreGems)

mkdir -p "$RAW"
if [[ $1 == outline ]]; then
	shift
	for key in $@; do edit $key $key "$OUTLINE"; done
	wait
	exit
fi
keys=(${@:-$BASES})
[[ $keys == variants ]] && keys=($VARIANTS)
for key in $keys; do icon $key; done
wait
