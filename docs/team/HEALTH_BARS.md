# Combat health bars — October 6, 2026

The user requested health bars similar to Mini War. The supplied
[reference frame](</Users/stevin/Documents/ChatGPT/My Chicken Army/style-guide/mini-war-reference/frames/frame-0192.jpg>)
shows a wide thin bright-green outlined bar, grey depleted track and centered
350/350 text. That value illustrates formatting; it is not a new stat target.

## Presentation contract

- Ordinary chickens and guards use 112 × 18 px bars with square corners, a black
  outline, grey track, subtle vertical fill gradient/rim, and centered white outlined
  SourceSansBold current / maximum HP.
- The King uses a 180 × 22 px bar below its existing name.
- Attackers (side A) remain bright green; defenders (side B) remain red. Keep
  the side distinction at low HP instead of switching colors by health ratio.
- Preserve fight-only visibility, 105-stud ordinary/180-stud King ranges,
  world occlusion, hidden home/dead bars and existing Giant-aware tag elevation.

## Data and implementation ownership

`shared/PetView.luau` owns the shared bar construction and display.
`shared/KingVisual.luau` retains the King's name and bar sizing.
`server/LiveBattleActors.luau` supplies real `unit.hp` and `unit.maxHp` to
PetView during publication and respawn. Physical Humanoid health is separate
from combat HP and must not supply the label.

Preserve combat calculations, damage/respawn state, player data, rewards and
the client's existing visibility controls. This is presentation work.

Implemented locally and delivered by the existing Rojo connection. The three
health-bar modules and the tutorial's no-Skip client source matched their
Studio Edit copies on readback. The active Play session was left running;
restart Play to load the changes. No tests, new playtest or rendered-layout
comparison were run, and nothing was published.
