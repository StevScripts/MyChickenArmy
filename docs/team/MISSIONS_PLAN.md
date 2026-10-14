# Missions plan: fixed camps + random territories (draft, October 14, 2026)

Status: **approved October 14 with the recommended answers (§7). Step 1 and the core of
step 2 are built** (see "Built so far" at the end). Missions replace Invasions.

## 1. The idea in one paragraph

The fixed map stays the core game: each commander's lane of three camps, the Chicken King
in the middle, the Hill. Once a player has finished that core (beaten the King), the
island starts spawning **Missions** for them on its own: a unique enemy territory
appears somewhere on the island with a timer and a reward. The player sends their army
to conquer it before it disappears. Missions are the repeatable endgame loop next to
Rebirth: rebirth resets the camps, missions keep paying between rebirths.

## 2. What stays exactly as it is

- Lanes, the three camps per commander, the King at the center, the Hill, hold bonuses
  and the hold limit (`BattleService`, `CampaignRoute`, `laneCamps`, `TerritoryIncome`).
- The tutorial ("Take your Cluck Camp first"), the King unlock and Rebirth.
- Every saved field. Invasion ids stay internally (`operationId`, `research.operationWins`,
  `pendingOperationReward`, analytics names) so no save can fail to load.

## 3. How Missions play

1. **Unlock:** defeating the Chicken King once (or a Rebirth, which already counts) turns
   Missions on for that player. Research S15/S16/S17 stay the Veteran/Elite/Royal gates
   and now open harder mission pools instead of menu tabs.
2. **Spawning (server, per player):** a mission spawns about every **4 minutes** while the
   player is online, up to **2 waiting at once**. It drops on a random open patch of the
   island (`InvasionLayout.Pick`: no roads, camps, plots or props nearby, never close to
   another live mission). Each waits up to **6 minutes**, then packs up and leaves. The
   first one spawns 30 seconds after the unlock so the feature introduces itself.
3. **Seeing them:** each site gets a world marker with its name, a countdown and its
   reward. A small HUD tracker (top right) lists the active missions with timers. A
   spawn toast: "A Loyalist Watchtower appeared! 6:00". No menu; **the map is the menu**.
4. **Conquering:** the player orders the attack the same way as a camp (walk up and use
   the prompt, or tap the tracker entry). The army marches out, fights a finite roster
   and walks home, exactly like today's Invasion battle. Once the fight starts the site
   gets **3 minutes** (today's limit). A loss, a timeout or leaving the game: no reward,
   and the site fades away.
5. **Private per player:** other players can see your mission sites but cannot attack
   them (same as Invasions today). No griefing, no contest rules.
6. **Rewards:** paid on a win, through the existing pending-reward safety (`OperationRewards`)
   so a full wallet never loses cash. Each site type pays one of:
   - **Cash** (scaled to the player's egg income, e.g. 8–15 minutes of income, so it stays
     useful at every stage and after rebirths), or
   - **Free rolls** (the existing `hillRollCredits`), or
   - **A timed egg boost** (×1.5 egg cash for 5 minutes; new, client shows a HUD timer).
   Rare sites (about 1 in 10) pay double and glow gold. All numbers get tuned with
   `tests/ProgressionSimulation.luau` before launch.
7. **Difficulty:** each site rolls from the player's highest unlocked pool (Veteran, then
   Elite, then Royal); within a pool, enemy levels follow the player's rebirth rank, the
   same way camps scale (`enemyScale`). The marker shows the usual Should win / Close
   fight / Very tough verdict so players can skip ones they can't beat.

## 4. Mission sites: every area unique and good-looking

Six site **themes**, each with its own look, enemy flavor and reward:

| Theme | Look | Enemies | Reward |
|---|---|---|---|
| Loyalist Landing | today's airship drop and palisade camp | mixed loyalists | cash |
| Watchtower Fort | stone tower, wooden walls, gate, banners | Knights, Bucket tanks | cash |
| Supply Depot | crate stacks, cart, tarp tents, fence | fast, weak guards | free rolls |
| Crystal Mine | rock outcrop, glowing crystals, mine cart rails | Ice Ducks, Wizards | egg boost |
| Pirate Cove (beach only) | wrecked boat, palm trees, treasure chest | Pirates, Sailors | cash (rare: gold) |
| Dragon Roost | burnt ground, bone arch, nest with eggs | Dragon boss + guards | big cash |

**How each one stays unique (procedural, but art-directed):**
- **Hand-built hero pieces.** Each theme gets 2–3 polished centerpieces (the tower, the
  wreck, the crystal outcrop…) built by me in Studio in the camps' studded Plastic style,
  saved as templates in `ServerStorage.MissionKits.<Theme>` (Studio-owned, like the map).
  These carry the quality; they are designed, not random.
- **Modular props per theme:** 15–25 pieces each (wall segments, tents, crates, banners,
  rocks, fences, torches, flags, ground patches), also authored in Studio.
- **Seeded assembler (code):** a new `MissionSite.Build(theme, seed, frame)` picks one hero
  piece, lays out a footprint shape (circle, horseshoe or wedge), places walls and props
  with clearance and a few design rules (entrance faces the player's base, hero piece at
  the back, nothing on the army's approach lane), swaps between 2–3 palettes and adds a
  ground patch. The same seed always rebuilds the same site; different seeds never look
  alike. This extends today's `InvasionCamp` builder.
- **Studio generation tools** (`generate_procedural_model` / `generate_mesh`) may be tried
  for individual props; anything that doesn't match the studded style is rebuilt by hand.
- **Quality bar:** at most about 400 parts per site; anchored; no collisions except the
  walk surfaces the army needs; spawn animation (pieces rise out of the ground with
  TweenService) and the existing fade-out. I review every theme with screenshots from the
  player camera and you approve each one before it ships.

## 5. What changes in code

| Area | Change |
|---|---|
| `OperationService` | becomes the mission scheduler: per-player spawn timers, waiting sites, expiry; keeps the battle start/resolve code (extracted so attacks start from a waiting site) |
| `OperationCatalog` | becomes a theme + pool catalog (rosters per tier, reward kind, rarity); old encounter ids kept for saved wins |
| `InvasionCamp` → `MissionSite` | the seeded assembler using `ServerStorage.MissionKits` |
| `InvasionLayout` | reused as is; adds a "coast only" filter for Pirate Cove |
| `InvasionAirship` | kept for the Loyalist Landing theme |
| `OperationsPanel` + HUD Invasions icon | removed; replaced by the HUD mission tracker and world markers (`BaseController`) |
| `PlayerSession` / saves | additive fields only: mission clears per theme, egg boost end time. Nothing required at load |
| Analytics | new append-only events: MissionSpawned, MissionStarted, MissionWon, MissionExpired (bump `Schema.Version`) |
| Rebirth | unchanged; "Finish your mission first" replaces the Invasion wording |

## 6. Build order (each step playtested before the next)

1. **Server loop with placeholder art:** scheduler, waiting sites with today's Invasion camp,
   attack from a site, rewards, expiry. Studio check: spawn, attack, win, lose, expire,
   rejoin.
2. **HUD and markers:** tracker, toast, marker with timer/reward/verdict; remove the
   Invasions menu and icon.
3. **Art, one theme at a time:** kit + assembler for Watchtower Fort first (sets the
   pattern), then the other five. Screenshot review with you after each theme.
4. **Rewards and balance:** income-scaled cash, free rolls, egg boost; simulation plus a
   play session after the King and after a rebirth.
5. **Polish:** spawn/leave animations, audio cues, phone layout of the tracker, gamepad.

## 7. Decisions needed from you

1. Spawn rate and cap: every ~4 min, 2 waiting at once, 6 min lifetime. OK?
2. Private per player (my recommendation), or should other players be able to steal
   them?
3. Reward mix: cash / free rolls / timed egg boost. Any other kind you want (e.g. Fuse
   discount, a chicken)?
4. The six themes. Swap any?
5. Unlock at the first King win (my recommendation), or earlier?

## Built so far (October 14)

- **Server (`OperationService`):** per-player scheduler (first site 30 s after unlock,
  then every 240 s, at most 2 waiting, 360 s to live), sites placed with
  `InvasionLayout.Pick` away from every live site/battle, encounter pick weighted 3:1 toward
  the highest unlocked tier, 10% gold sites. A site is today's Invasion camp
  (`Mission_<id>` under `PetRollWorld.Missions`, attributes `MissionId`, `OwnerUserId`,
  `CommandTarget="mission:<id>"`, `Rare`) plus the airship drop; the open crates stay
  until the attack. `StartOperation {missionId}` sends the army; the loyalists appear,
  the 3-minute limit starts and the old Resolve/return flow runs. Reward: max(old replay
  cash, income × 8/12/15 min by tier), doubled on gold, then 2x Cash; first clears still
  set `operationWins` (banners). The old menu start is refused with a pointer to the island.
  Snapshot adds `missions` (id, name, tier, power, count, reward, rare, expiresIn) and
  `activeSite`. Analytics: `mission.spawn/expired/start/won/lost/timeout.<tier>`
  (`Schema.Version` 3).
- **Client:** `MissionTracker` (right-edge list in the old Invasions icon slot, tap to
  send; marker over each own site; "Loyalists landed" / "packed up and left" notices);
  `BaseController` gives own sites the normal walk-up Send Army prompt and points the
  objective marker and beam at the active mission, or at the next waiting one when there
  is no other goal. The Invasions HUD icon, menu entry and scout alert are retired.
- **Words:** research S16/S17 are "Elite/Royal Missions"; AGENTS glossary says Missions.
- **Checked in Studio Play** (session-only unlock, test profile): spawn, tracker, marker,
  send from the tracker, march, forced win (reward paid, army home, site fades), expiry
  with both notices, the automatic scheduler. Not checked: a real loss/timeout, phone,
  gamepad, two players at once.
- **Step 3 started: Watchtower Fort** (`MissionSite.luau` + `MissionKits/WatchtowerFort.luau`).
  Built in code (not Studio templates) so the kit is versioned and needs no place save.
  Seed (scrambled) picks hero piece (watchtower / twin towers with bridge / keep), wall
  layout (ring + gatehouse / horseshoe / two arms), stone (lavender / sandstone / slate),
  accent (purple ×2 / crimson) and 9–13 props from crates, barrels, weapon racks,
  dummies, braziers, cannons, hay, tents; braziers flank the entrance, banner poles the
  sides. Centre (r 12.5) and entrance lane stay clear. 259–328 parts. Staged reveal
  (ground, walls, hero, props, 0.3 s apart, dust puffs) instead of per-part tweens.
  Themes now roll 50/50 Loyalist Landing (airship) / Watchtower Fort. Screenshots:
  `assets/generated/mission-watchtower-fort-20261014/`. Checked in Play: 5 forts built,
  a real fight inside one (army won and walked home). **Awaiting owner approval**
  before the other four themes.
- **Next:** remaining themes (Supply Depot, Crystal Mine, Pirate Cove, Dragon Roost),
  then rewards (free rolls, egg boost) and enemy scaling with rebirth rank.
