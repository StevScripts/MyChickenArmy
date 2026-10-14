# Re-enlist and Operations UI (October 13, 2026 redesign)

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
