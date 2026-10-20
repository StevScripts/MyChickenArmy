#!/bin/zsh
# Upgrade tree, Gem Upgrade, currency and HUD icons for the October 20 overhaul (session S6).
# Transparent 1024x1024 masters made with the chatgpt-image skill and the chunky-simulator-icons
# references. Every candidate lands in raw/; the chosen master is copied to <Key>.png.
#
#   ./generate.sh                 every base icon (variants need their chosen base first)
#   ./generate.sh EggSpeed Luck   only these keys
#   ./generate.sh variants        the edits of chosen bases (Vacuum*, *Machine, GoldRate, AutoRoll, MoreGems)
#   ./generate.sh outline KEY...  redraw chosen masters with the set's heavy outer outline
OUT=${0:A:h}
RAW=$OUT/raw
REPO=${0:A:h:h:h}
GEN=/Users/stevin/.claude/skills/chatgpt-image/scripts/gen.py
MODEL=${MODEL:-gpt-image-1.5}
BATCH=${BATCH:-9}

SKILL=/Users/stevin/.codex/skills/chunky-simulator-icons/references/screenshots
HUD=$SKILL/01-hud-navigation.png
GEMPACKS=$SKILL/04-gem-packs.png
HORN=$REPO/assets/generated/rally-icon-20261016/rally-horn-20261016-031355.png
CHICKENS=$REPO/assets/army-hud-20260927/my-army-chickens.png
SOLDIERS=$REPO/assets/army-hud-20260927/my-army-soldiers.png
COIN=$REPO/assets/gold-coins-20261020/upload/GoldCoin.png
REENLIST=$REPO/assets/generated/reenlist-icon-20261013/reenlist-20261013-231836-1.png
FEED="$HOME/Documents/ChatGPT/My Chicken Army/output/2026-10-20-systems-guide/art/chicken-feed-concept.png"

STYLE="Create one original game UI icon for the Roblox game My Chicken Army, shown on an upgrade-tree hex button. \
The attached images are style references: match their chunky glossy cartoon illustration family exactly. \
Exaggerated sturdy toy-like proportions, one strong simple silhouette, a heavy continuous near-black outer outline \
as thick as the outline on the attached red war horn, thinner dark local-color interior lines, broad clean cel-shaded \
planes, upper-left key light with darker lower-right faces, a few crisp glossy highlights, saturated lively colors. \
Dimensional vector-clean 2.5D cartoon look; not a flat pictogram, not a photoreal render, not soft clay. \
Do not copy the reference objects or any screenshot interface unless the subject asks for them. \
Composition: one isolated subject, centered by visual weight on a square canvas, filling about 80 percent of the \
canvas along its longest side, complete silhouette with even transparent padding, readable at 64 pixels. \
Keep the lower-right corner free of important detail. Add a plus sign, arrow, gear or other extra symbol only \
when the subject below asks for one. \
Background: fully transparent true alpha. No backdrop color, no floor, no cast shadow, no glow halo, no light rays, \
no card, no frame, no hexagon. No text anywhere: no letters, numbers, roman numerals, question marks, dollar signs, \
labels, prices, badges or watermarks."

CHICKEN="Every chicken is the game's boxy voxel chicken drawn like the attached My Army chickens: cube-shaped white \
body and cube head, small black square eyes with a white glint, a chunky yellow block beak, a red block wattle under \
the beak, orange blocky feet, and a clearly visible thick black stroke around the whole chicken silhouette."

COINS="Every coin is the game's gold coin from the attached coin image: a thick glossy gold disc with a raised boxy \
chicken-head emblem. Never a dollar sign, never banknotes."

GEMS="Gems are big faceted violet-purple crystals like the attached gem-pack screenshot: large flat facets, bright \
lavender upper facets, rich violet middle, deep purple lower facets and a few white glints."

EDIT="Edit the first attached image. Keep the same object, outline weight, colors, lighting, perspective, size and \
framing exactly, and keep the background fully transparent. No text, letters or numbers. Change only this:"

# Modifier symbols, always bare (no disc or badge behind them), lower left, like the reference tree.
BARE="with a thick black outline, at the lower left, slightly overlapping the subject, drawn as a bare symbol with no \
circle, disc or badge behind it"
PLUS="a bold bright-green plus sign $BARE"
CYCLE="a bold bright-green circular double arrow (two curved arrows chasing each other around a circle) $BARE"
UP="a big bold bright-green up arrow $BARE"
FASTFWD="a bold bright-green fast-forward double arrow $BARE"

jobs_started=0
throttle() { (( ++jobs_started % BATCH == 0 )) && wait }

gen() { # KEY "subject" reference...
	local key=$1 subject=$2; shift 2
	local args=() ref
	for ref in "$@"; do args+=(--image "$ref"); done
	python3 "$GEN" "$STYLE Subject: $subject" "${args[@]}" --model "$MODEL" --quality medium \
		--size 1024x1024 --background transparent --out "$RAW" --name "$key" &
	throttle
}

edit() { # KEY BASE "change" [extra reference...]  (BASE is a chosen master's key or an image path)
	local key=$1 base=$2 change=$3; shift 3
	[[ $base == */* ]] || base=$OUT/$base.png
	[[ -f $base ]] || { print -u2 "$key: choose $base first"; return }
	local args=() ref
	for ref in "$@"; do args+=(--image "$ref"); done
	python3 "$GEN" "$EDIT $change" --image "$base" --image "$HORN" "${args[@]}" --model "$MODEL" --quality medium \
		--size 1024x1024 --background transparent --out "$RAW" --name "$key" &
	throttle
}

icon() {
	case $1 in
	# Main tree
	EggSpeed) gen $1 "Egg Speed upgrade (chickens lay eggs faster). One big glossy cream-white egg tilted forward as if \
rushing ahead, filled with solid opaque warm cream shading right up to its black outline (no pale blue rim light), with \
three short solid black motion lines behind it, and $CYCLE." $HUD $HORN ;;
	EggValue) gen $1 "Egg Value upgrade (each egg is worth more Coins). One big glossy cream-white egg standing upright, \
with a short stack of three gold coins in front of its lower left side. $COINS" $COIN $HORN ;;
	Luck) gen $1 "Luck upgrade (better chicken rolls). One big glossy four-leaf clover facing forward: rich emerald green \
heart-shaped leaves with lime highlights and darker green inner lines, and a short curved stem." $HUD $HORN ;;
	FlockSize) gen $1 "Flock Size upgrade (more chickens laying eggs in the yard). A cheerful small chicken coop standing \
on its own: red pitched roof, cream walls and trim, and a dark arched doorway with the head of one boxy white chicken \
peeking out, and $PLUS. Keep it simple: no ground, no grass, no eggs, no other chickens. $CHICKEN" $CHICKENS $HUD ;;
	ArmySize) gen $1 "Army Size upgrade (more chickens in your army). Three boxy white chickens wearing olive-green army \
helmets standing close together, the middle one in front and slightly bigger, and $PLUS. $CHICKEN" $SOLDIERS $HORN ;;
	RollSlot) gen $1 "Roll Slot upgrade (one more roll podium). A chunky orange stepped podium block with beveled edges, \
topped by a round golden straw nest, with two small sparkles above the empty nest, and $PLUS." $HUD $HORN ;;
	RollSpeed) gen $1 "Roll Speed upgrade (rolls are faster). A chunky roll lever: a short dark steel lever arm angled up \
and to the right out of a rounded dark steel base, topped with a big glossy red ball knob, and a bold gold lightning bolt \
in front of the base at the lower left." $HUD $HORN ;;
	GoldMachine) gen $1 "Gold Machine (special gold rolls). A chunky boxy roll machine made of shiny gold, like a small \
toy gacha cabinet: a rounded gold box body, a round glass window on the front showing a glowing gold star, a red ball-knob \
lever on its right side, and two small sparkles." $HUD $HORN ;;
	# Category hexes
	OpenTools) gen $1 "Tools category button. A chunky red metal toolbox in three-quarter view with a silver handle on \
top, gold latches, and a big silver wrench lying across its lid." $HUD $HORN ;;
	OpenPlayer) gen $1 "Player category button. A blocky yellow toy-figure head shaped like a rounded cube, front view, \
with a simple friendly face: two black oval eyes and a small black smile, and a glossy highlight on its upper left." \
$HUD $HORN ;;
	OpenArmy) gen $1 "Army category button. One chunky olive-green army helmet in three-quarter view with a dark green \
strap band and a big shiny gold star on the front." $SOLDIERS $HORN ;;
	Back) gen $1 "Back button. One big chunky curved arrow that makes a U-turn and points to the left, glossy white with \
cool light-gray shading planes and a heavy black outline." $HUD $HORN ;;
	# Tools subtree
	EggVacuum) gen $1 "Egg Vacuum tool (a handheld vacuum that sucks up eggs). A chunky handheld vacuum gun in side \
three-quarter view: bright red plastic body with a pistol grip and a yellow trigger, a short wide silver nozzle pointing \
left, and a clear glass tank on top holding three small white eggs." $HUD $HORN ;;
	ChickenFeed) gen $1 "Chicken Feed tool (feed one of your chickens to level it up). Redraw the attached feed-sack \
concept as a finished icon: a chunky open golden-tan sack with a rolled-open rim, a heap of big golden corn kernels and \
a few brown pellets inside, a green army-supply band around its lower half, and a small boxy white chicken-head emblem \
with a red wattle and a black outline on the front." "$FEED" $HORN ;;
	# Player subtree
	WalkSpeed) gen $1 "Walk Speed upgrade (you walk faster). One chunky red and white sneaker in side view with a thick \
white sole, and three bold speed streaks trailing behind its heel." $HUD $HORN ;;
	ClickRange) gen $1 "Click Range upgrade (collect eggs from farther away). A chunky cartoon hand in solid opaque bright \
yellow, the same yellow as the attached yellow head icon, pointing down with its index finger as if tapping, with two bold \
orange ripple rings spreading flat around the fingertip. The hand is filled solid, with no see-through gaps." \
$OUT/OpenPlayer.png $HORN ;;
	OfflineTime) gen $1 "Offline Time upgrade (earn for longer while away). A glossy yellow crescent moon with a small \
red twin-bell alarm clock resting in its curve; the clock face has simple tick marks and hands, no numbers." $HUD $HORN ;;
	# Army subtree
	Damage) gen $1 "Army Damage upgrade. One chunky cartoon sword pointing up and slightly right: a wide shiny steel blade \
with a bright edge highlight, a gold crossguard, a red-wrapped grip and a round gold pommel." $HUD $HORN ;;
	Health) gen $1 "Army Health upgrade. One big glossy red heart with a bright pink-white highlight on its upper left \
and deep red lower-right shading. Only the heart: no badge, shield, plus sign or cross." $HUD $HORN ;;
	MarchSpeed) gen $1 "Army March Speed upgrade (the army marches faster). One chunky brown leather army combat boot \
with olive-green laces and a thick dark sole, with three bold speed streaks behind its heel." $HUD $HORN ;;
	Armor) gen $1 "Army Armor upgrade (chickens take less damage). A chunky steel breastplate (chest armor) in front \
view: shiny silver-gray metal with broad bevels, gold rivets and gold trim along its edges." $HUD $HORN ;;
	Recovery) gen $1 "Army Recovery upgrade (knocked-out chickens recover faster). A chunky white first-aid kit box with \
a rounded red handle on top, a red stripe around it and a big glossy red heart on the front." $HUD $HORN ;;
	BossDamage) gen $1 "Boss Damage upgrade (hit the Chicken King harder). A shiny gold king's crown with red gems and a \
jagged crack down its middle, with a steel sword stabbing down behind it." $HUD $HORN ;;
	Bounty) gen $1 "Bounty upgrade (more Coins from defeated enemies). A bulging brown cloth sack tied with a rope, \
overflowing with gold coins, with a red and white bullseye target tag hanging from the rope. $COINS" $COIN $HORN ;;
	CaptureSpeed) gen $1 "Capture Speed upgrade (capture camps faster). A waving red victory flag on a short wooden pole \
with a gold star on the flag, and $CYCLE." $HUD $HORN ;;
	# Gem Upgrades
	CoinBoost) gen $1 "Coin Boost upgrade (more Coins). A neat stack of four gold coins, and $UP. $COINS" $COIN $HORN ;;
	AutoRebirth) edit $1 $REENLIST "add a chunky silver gear with a thick black outline behind the shield's lower \
left, partly hidden by the shield. Keep the heavy black outer outline everywhere." ;;
	TimeSkip) gen $1 "Time Skip upgrade (instant Coins when you rebirth). A chunky red twin-bell alarm clock with a white \
face showing two black hands and simple tick marks, no numbers, and $FASTFWD." $HUD $HORN ;;
	KeepUpgrades) gen $1 "Keep Upgrades upgrade (keep some upgrades through a Rebirth). A chunky gold-rimmed shield with a \
deep purple center and a big bold green up arrow emblem on its face." $HUD $HORN ;;
	MutationLuck) gen $1 "Mutation Luck upgrade (more mutated chickens). One boxy voxel chicken whose white body shimmers \
with rainbow colors in soft bands of pink, yellow, green, cyan and violet, with glossy highlights, surrounded by four \
white-and-gold sparkle stars. $CHICKEN" $CHICKENS $HORN ;;
	OfflineCoins) gen $1 "Offline Coins upgrade (earn more while away). A glossy yellow crescent moon with a small pile of \
gold coins resting in its curve. $COINS" $COIN $HORN ;;
	ArmyPower) gen $1 "Army Power upgrade (stronger army). One boxy white chicken wearing an olive-green army helmet, \
standing heroically, surrounded by a fiery orange-red power aura, and $UP. $CHICKEN" \
$SOLDIERS $HORN ;;
	RebirthChickenOdds) gen $1 "Rebirth Chicken Odds upgrade (Rebirth chickens show up more often). One boxy white chicken \
wearing a dark green veteran beret with a small gold rank badge, with a glossy green four-leaf clover at the lower left \
and two sparkle stars. $CHICKEN" $CHICKENS $HORN ;;
	# Currency and HUD
	Gems) gen $1 "Gems currency. One big faceted violet gem in front view, a classic brilliant cut with a wide flat top \
table and a pointed bottom. $GEMS" $GEMPACKS $HORN ;;
	FriendBoost) gen $1 "Friend Boost (more Coins with friends in your server). Two boxy white chickens side by side, \
turned toward each other, giving each other a high five with raised wings, with a small burst of yellow sparkles where \
their wings meet. $CHICKEN" $CHICKENS $HORN ;;
	GoldRush) gen $1 "Gold Rush event (double Coins for everyone). A fluffy glossy golden cloud raining a shower of gold \
coins, with a few sparkles. $COINS" $COIN $HORN ;;
	# Variants: edits of a chosen base master
	VacuumCapacity) edit $1 EggVacuum "make the glass tank packed full of small white eggs, and add two stacked bold \
bright-green up arrows $BARE." ;;
	VacuumRange) edit $1 EggVacuum "add three bold yellow curved suction arcs with thick black outlines in front of the \
nozzle on the left, each wider than the last, like sonar waves." ;;
	GoldRate) edit $1 GoldMachine "add two curved bright-green arrows with thick black outlines chasing each other \
around an empty circle (a refresh symbol) at the lower left, overlapping the machine, exactly like the green arrows on \
the egg in the last attached image. Only the two arrow shapes: the middle of the circle shows the machine through it, \
and there is no ball, disc, sphere or badge behind the arrows." $OUT/EggSpeed.png ;;
	DiamondMachine) edit $1 GoldMachine "rebuild the machine body in sparkling pale icy diamond: white and very light cyan \
faceted crystal panels with bright white glints; the window shows a glowing white-blue diamond instead of the star. The \
lever knob stays red." ;;
	RainbowMachine) edit $1 GoldMachine "rebuild the machine body in glossy rainbow: panels in bands of red, orange, yellow, \
green, blue and purple with white glints; the window shows a glowing rainbow star. The lever knob stays red." ;;
	AutoRoll) edit $1 RollSpeed "remove the lightning bolt; add a chunky silver gear behind the lever base and $CYCLE." ;;
	MoreGems) edit $1 Gems "turn the single gem into a small heap of three of the same violet gems, and add $PLUS." ;;
	*) print -u2 "unknown icon: $1" ;;
	esac
}

BASES=(EggSpeed EggValue Luck FlockSize ArmySize RollSlot RollSpeed GoldMachine OpenTools OpenPlayer OpenArmy Back
	EggVacuum ChickenFeed WalkSpeed ClickRange OfflineTime Damage Health MarchSpeed Armor Recovery BossDamage Bounty
	CaptureSpeed CoinBoost AutoRebirth TimeSkip KeepUpgrades MutationLuck OfflineCoins ArmyPower RebirthChickenOdds
	Gems FriendBoost GoldRush)
VARIANTS=(VacuumCapacity VacuumRange GoldRate DiamondMachine RainbowMachine AutoRoll MoreGems)

# Outline fix: keep a chosen master as drawn and give it the set's heavy outer outline.
OUTLINE="add a heavy continuous near-black outer outline around the entire silhouette, as thick as the outline on \
the attached red war horn, and give every chicken a clearly visible black stroke. Keep every other detail the same."

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
