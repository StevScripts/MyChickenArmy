# Re-enlist and Operations UI (October 13, 2026 redesign)

## October 14 Rebirth board (latest; supersedes the minimal Rebirth below)

Owner: "more information, coherent with the rest of the UI". Window .9 × .74, aspect 1.45,
in the Daily Rewards card style: a rank row (badge + "Rebirth 2" → badge + "Rebirth 3");
three studded cards (Egg Cash ×now → ×next "Forever", New Mutation in its catalog colour or
grey "None · Not this rank", Camps ×next "Tougher enemies"); a red RESETS strip ("Cash · Egg
upgrades · Luck · Camps · N chicken levels") and a green YOU KEEP strip ("Chickens · Giants ·
Research · Plot · Army size"); the cash progress bar beside the 2-second hold button. The HUD
Rebirth icon moved to the middle of the right edge (touch: y .6). Daily Rewards cards now use
small, subtle studs (opacity .07, `StudScaleWidth` 1.6). The Invasions screen is no longer
reachable (sites spawn on the island).

## October 14 final: minimal layout (third pass)

The second pass still felt cluttered. The owner asked for an uninstructed image-generator mockup
(`assets/generated/ui-gpt-reference-20261014/`) and its UX replaced both screens:

- **Rebirth** (window .6×.66, aspect 1.05): one inset box ("You will get", big "×N Eggs!", one gold
  line "+ Mutation mutations · camps ×N tougher", cash icon + "Cost: $X", green when affordable or
  padlock + "Defeat the Chicken King"); one red line "Resets Cash, upgrades, N chicken levels and
  camps. Chickens stay!"; the 2-second hold button ("Hold to Rebirth" / "Locked" / "Need $X more").
- **Invasions** (window .62×.72, aspect 1): Veteran/Elite/Royal tabs (padlock icon when locked);
  three wide invasion bars with a right chip (first-clear cash, CLEAR!, or padlock); a status row
  ("Enemy N · You N" + verdict chip, or the unlock requirement / saved pending reward); one big
  button (Defend / Defend again / Army busy / Leave / View in Upgrades). Enemy portraits, the
  Formations shortcut (still in the Army inspector) and reward chips were removed.

The two passes below are superseded.

## October 14 redesign (owner picks)

The owner rejected the October 13 layouts and picked references (saved in the Obsidian vault as
`UI References/` notes with `verdict: adopt`):

- **Rebirth** (`RebirthPanel.luau`): Arm Wrestle Simulator / Roller Skate Racing rows plus Steal a
  Brainrot's warning and tiles. Top: one red WARNING line built from the quote (`cashLevels` adds
  "and N bought chicken levels"). Three before → after rows with icons: Cash (now → starting
  cash, red), Eggs (×now → ×next, green), Rank (badge → next badge). "NEXT RANK BRINGS" tiles: the
  mutation from `unlockNext` (its catalog color) and the camp scale (`enemyScaleNext`). Bottom: cash
  bar (padlock icon while the King is required) beside the 2-second "Hold to Rebirth" button; the
  button says "Locked" or "Need $X more" when not eligible. Max rank: "Highest rank reached", no tiles.
- **Invasions** (`OperationsPanel.luau`): Anime Vanguards stage select. Columns: Select Tier (emblem,
  name, "Cleared: n/3" or Locked) with Formations under it; Select Invasion (number, name, green
  CLEAR! stamp, emblem watermark) with Defend / Defend again / Army busy / Leave under it; Invasion
  Info (enemy power, verdict, name, enemy army portraits, You vs Enemy bar, FIRST CLEAR REWARD, and a
  Rewards row: replay cash chip and tier banner chip). Locked tiers show the research requirement and
  View in Upgrades inside the info column.

Second pass the same day (owner: "text is cramped"): fewer, taller labels so TextScaled text grows.
Rebirth window .9×.74 at aspect 1.3; warning shortened ("Egg upgrades", "+ N chicken levels") with a
separate green "Your chickens, Giants and research stay!" line; tiles are wide icon + name + caption
cards. Invasions window .94×.72; column headings, "Invasion N" lines and the power bar removed; info
column = name, verdict badge, "You N · Enemy N", enemy army (×count), reward heading and two chips
(cash, banner); BOSS stamp on boss invasions; Leave has no countdown (the world marker shows it).

Server requests, hold-to-confirm, gamepad bindings and menu exclusivity are unchanged. Checked in
Studio Play on a desktop viewport with client-only sample data (locked, unlocked, cleared, eligible,
no-mutation and max-rank states); no phone or gamepad pass yet.

The sections below describe the superseded October 13 version.

Owner request: redesign both screens after looking at how other Roblox games present rebirths and
mission select. Art: `assets/generated/rebirth-ops-ui-20261013/` (ids in its README, keys in
`UITheme.Assets`).

## Reference patterns

- Rebirth screens (simulator UI kits): "rank N → N+1", big before → after reward pills, one red
  reset line, a progress bar toward the cost, one large action. Very little body text.
- Mission select (tower-defense map selects): tier tabs, a list of mission cards, a detail pane
  with art, rewards row and big Start/Leave.

## Re-enlist (`src/client/RebirthPanel.luau`)

Header icon = Re-enlist badge. Rank row (Recruit badge or Re-enlist badge → next rank), two pills
(Eggs ×now → ×next, Enemies ×now → ×next), one reset and one keep line, a cost bar
("$3.2B / $5B", or a padlock and "Defeat the Chicken King first"), then the 2-second hold button
whose disabled text is built from the quote ("Need $1.8B more"). Server failures show in the bar.
The Upgrades-screen hex and the HUD icon both open it.

## Operations (`src/client/OperationsPanel.luau`)

Its own popup; `AppController:OpenPage("Operations")` redirects here (the old
`ResearchExtras:RenderOperations` list is no longer reached). Tier tabs (emblem, name, cleared
count, padlock), three mission cards (emblem, name, power or ✓ Cleared), and a detail pane: enemy
squad portraits (`ChickenPortraits`, ×count and level, boss tile in red), your selected army power
against the enemy with a verdict (Should win / Close fight / Very risky), the reward chip (first
clear or replay), the tier banner line and one big Deploy (Replay, Army busy) or Leave while an
Operation runs. Locked tiers show the research requirement and View research. A successful
StartOperation closes the window. The HUD shortcut (`ResearchExtras`) is now an icon button.

Checked in disposable Studio playtests on a desktop viewport. Not checked: phone emulator,
gamepad navigation, real taps (studio-flow mouse injection does not reach GUI buttons).
