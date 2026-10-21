# Reference parity pass (October 21, 2026): Drop a Fruit UX 1:1, Rebirth zero, ladder

Lead: session "Game UX and rebirth mechanics overhaul". Workers: eight Opus agents, one
area each, in their own worktrees (section 6). Stevin's request, from his third Drop a
Fruit recording (`~/Desktop/Screen Recording 2026-10-21 at 3.43.41 AM.mov`, 190 s):

> They're all very smooth and every single thing has a sound effect and animation and
> everything is lively. Look at the UX: everything is very cohesive and easy to read on a
> background. I'm still struggling with a darker background, having things readable and
> cohesive; right now they're all over the place. The rebirth value goes from 50,000 for
> number one to 1 million; our jump is too high, make the barrier to entry easier, but not
> super easy to get coins really fast. When a player rebirths all their money should go
> to zero; every time it's not doing that. Copy as much as you can, in the style of my
> game, the UX one-to-one, and keep iterating until it's perfect. Don't ask me for
> permission.

This file is the contract. Where it conflicts with an older rule or doc it wins; it does
not touch the glossary, the server-owns-money rule, save compatibility, or the game feel
contract (`GAME_FEEL_20261021.md`), which every worker builds on.

## 1. Reference material

Frames from the recording (1568 px wide, named by second) and the sound-event list:
`/Users/stevin/Documents/ChatGPT/My Chicken Army/output/2026-10-21-recording-3/`
(`frames/t<sec>s.png`, `frames/vac_NN.jpg` = 4 fps of the vacuum burst at 121–131 s,
`onsets2.txt` = detected sound events, `spectrogram.png`). Captures of OUR current
screens are in `current/` (hud.jpg, shop.jpg, upgrades.jpg; Edit-mode UI Lab renders of
the late-game preset). The October 20 systems guide and its crops remain at
`~/Documents/ChatGPT/My Chicken Army/output/2026-10-20-systems-guide/`.

| Second | What is on screen |
|---|---|
| t0, t114 | **Welcome Back!** popup: gold stud header with gift icon, red X; dark body; "OFFLINE EARNINGS:" + coin-stack art with rays + "+3.4M"; green **Claim!** and blue **Claim x2 / ONLY 24 (Robux)** |
| t3, t6, t118 | **Daily Rewards**: green header + calendar icon; 7 cards, 2 rows of 3 plus one tall Day 7 card; claimed card greyed with a big green check "Claimed!"; a chip under the window "Next reward in: 08:29:14". Banners above: "You earned 3,391,365 coins!" (gold coin icon, green text), "Come back later for your daily reward! Your fruits keep earning while you're away! (x3)" (red text), each on a dark translucent strip |
| t9, t17, t27 | **Upgrades tree** full screen over the blurred world with a dark tint (no panel). Owned hexes blue, next-affordable dark with a red "!" badge and a green price, unaffordable dark with a red price, locked grey "?" ghosts, orange "Open" hubs with red count badges, cyan Start. Tier numeral bottom-right of the icon, name above the hex, coin + price below. Tooltip card beside the hex: name, effect sentence with the number in green, coin price. Wide red **Close** button bottom centre (red **Back** in subtrees, t11/t13). Top-left keeps the Coins readout and the "8 Rolls Left" / "100 Rolls Left" dice counters; a buy shows "-2,850,000" in red beside the Coins (t15); a failed buy shows "You need 3,096,960 more Coin!" red banner (t27) |
| t33, t122 | Auto Roll board in the world (ours exists, S12b) |
| t39, t43 | **Fruits** (= My Army) window: "7/1000" at the header's right, "5/5 Equipped – coin 617 / 4.3 sec." line, equipped row above a divider, owned grid below; outside the window: Search box, red Sell, purple "Sort: Value/Rarity", green Equip Best. (Our My Army grid already copies his Pets reference 1:1; not reworked here.) |
| t47 | **Index**: left column of mutation tabs (Normal / Rotten / Invert / Golden / Diamond), progress "7 / 52", rarity sections with silhouettes "???" and "1/13" odds, right "Rewards" column (per-rarity progress, padlock, +5% Luck). Rewards are a new economy feature: style only this pass |
| t51, t158 | **Free Reward!** popup: blue header; "YOUR REWARD:" coin art "+99.3K Coin"; rows "1. Like the game – Like!", "2. Join the group – Join!", "3. Play 5 min – ✓"; white **Claim!**; banner "Playtime reward claimed!" (green) / "Keep playing to unlock this reward! (x2)" (red) |
| t57, t65, t67 | **Shop**: gold header; ONE horizontal rail of cards with a bottom scrollbar: Server Luck (green, "1x → 2x for 30m!", struck-through old price, R$40), Meme Fruit Pack (blue, pack art, 4 odds portraits "$37.5K/s 1%", three pills "R$80 Buy 1 / R$240 Buy 3 / R$640 Buy 8"), Advanced Pack (red, "%50 OFF!", struck price), VIP Pass (orange, crown, "Includes: 50% Coin, 50% Luck, Exclusive VIP Tag", R$120), 2x Luck Pass (green, clover, R$64), Time Skips as a 2×2 of small red cards (5m/15m/1h/4h with the Coins they pay and R$32/64/192/560) and a big "1 Day Time Skip!" card (R$1,600). A red **Gift!** button under the window's right edge |
| t81, t93 | Hovering the bottom-right **x9.2 / x6** boosts shows a breakdown list ("Luck: Upgrades x6, Luck Pass +0, Server Luck +0, VIP +0, Luck Boost +0%, Index +0%, Event +0%"; "Coin: Boost x8, Rebirth +1, VIP +0, Friends +0%, Hole +20%, …") |
| t97 | **Settings** popup: grey-blue header with gear; rows "Sound Effects / Coin, fruit and UI sounds" with a green ON / red OFF pill |
| t101 | **Updates** popup (blue header, book icon): "UPDATE 3!" and three coloured ribbons. Not built this pass |
| t130–t154 | **Vacuum**: counter "4 / 25" in a dark pill centred above the hotbar; prompt line "🖱 Collect (Hold)   E Throw (Hold)"; yellow suction swirl around the player; each fruit sucked in = one bright chime; coin floats "+3.6K", "+92" with a coin icon over the player; a green "+23,009" delta beside the Coins readout that fades; throwing into the hole = whoosh, brown poof, coin burst; "Blitz! Your plants drop 10 fruits each!" orange banner (t150) |
| all | **HUD**: left stack = wide gold **Shop** plate, then a 2×2 of square plates **Rebirth** (blue, "%100" tag = the current Rebirth bonus) / **Upgrade** (yellow-green, red count badge) / **Index** (green) / **Fruits** (blue-orange); every plate has a stud texture, an icon that pops above its top edge and a label at the bottom. Bottom-left: event timer line, candy row, **Coins bar** (dark translucent pill, coin icon, gold number), "Friend Boost: +0%" with a green +. Bottom-right: small boost icons with "x9.2" / "x6" under them. Right rail (x ≈ 0.94): "Free Reward! Claim!" gift (sunburst behind, wobbles), a ▶ arrow + rotating offer card ("x8 Meme Fruit Pack! ONLY 640", "5m Time Skip! ONLY 32", "VIP Pass! ONLY 120", "x2 Luck! ONLY 64"), "x10 Coin! ONLY 400" card. Top-right: round Settings gear, green check, Updates book. Top-centre: "Center" teleport (skipped) and the weather chip (skipped). Chicken labels "LVL 15 / Raspberry / coin 367" (ours: S18) |

Sounds (from `onsets2.txt` and the spectrogram): a music bed the whole time at about
-30 dBFS; UI chimes at -27 dB (13–17 s, tree hover/click); a whoosh on menu close/open
(31.9, 67.6, 121.6 s); a purchase pop + tone at 38 s; claim jingle tones at 76.6–77.4 s
(-14 dB, the loudest event); and from 115 s a dense cascade of short bright chimes
(centroid 10–12 kHz, 6–10 a second, -22 to -26 dB, slightly rising) while the vacuum
collects, with noise whooshes (155.8, 159.7, 170, 178.5 s) and low thuds (187–188 s) on
throws into the hole. Nothing in the reference is loud: every event cue sits well under
the claim jingle.

## 2. Decisions (lead, October 21; no confirm step)

### 2.1 One shell for every popup (readability on dark)
The reference reads on any background because of three rules. Every menu adopts them
through `UITheme` (P2 owns the helpers; other workers call them, never re-implement):
1. **Body**: near-black (`Theme.OverlayColors`) at about 25% transparency over the
   blurred world (`AppController:SetMenuBlur`, 18), 3 px black outline, square corners.
   Inner content areas are a slightly lighter translucent card with a 2 px dark stroke.
2. **Header**: full-width colour bar in the page colour with `UITheme.Studs` (88%
   transparent), the page icon in a square at the left, the title in white with a black
   stroke, a square red X at the right end (keeps `Theme.HeaderClose` pads).
3. **Text and buttons**: every label white Montserrat Bold with a black `UIStroke`
   (thickness ≈ 8% of the text height); secondary text light grey; Coins gold, shortfalls
   red, gains green, all with the stroke. Buttons are solid fills (purchase green, action
   blue, danger red, sort purple, claim white-on-light) with a 3 px black stroke, press
   shrink 95% / hover grow 105% (`BindButton`), Click cue.
No chrome-only text (no unstroked small grey text on dark). No per-device branches.

### 2.2 HUD layout 1:1 (P1)
Positions are the reference's, in Scale of a 16:9 screen (measured on 1568×1014 frames):
- Left stack, vertically centred at y ≈ 0.51: **Shop** plate x 0.014–0.133, h ≈ 0.07
  (wide), then a 2×2 of square plates (each ≈ 0.056 wide): row 2 **Rebirth** | **Upgrades**,
  row 3 **Index** | **My Army**. Plates: page colour + studs + black stroke; the icon
  overhangs the top edge; the label sits in the plate's lower third; badges are red circles
  at the top-right corner (Upgrades count; My Army shows nothing). Rebirth's plate carries
  the "+100%" style tag at its top-left ("x3" egg Coins is fine; glossary: "Rebirth 2").
- **My Army moves into the grid** (reference's Fruits slot). The space above the hotbar is
  freed for the vacuum counter (P6). Call Army / My Base keep expanding from the My Army
  button (to the right of the grid). This supersedes the October 20/21 "My Army above the
  hotbar" placement; Stevin asked for the reference layout.
- Bottom-left: the **Hill chip** takes the event-timer line (above the Coins bar); the
  **Coins bar** is a dark translucent pill (x 0.012–0.135, y ≈ 0.89–0.93) with the coin icon
  and a gold number; a green **"+N"** delta appears right of the pill on gains and fades
  (red "-N" on spends, as the tree shows); **Friend Boost: +0%** with the green + below.
  "Rebirth N" rank text stays above the pill as today.
- Bottom-right: boosts stay (BoostReadout) and get the reference's **hover/tap breakdown**
  panel (values from `state`/effects only; no new numbers).
- Right rail at x ≈ 0.94: **Free Reward gift** (FreeGiftController's HUD button, with the
  sunburst and wobble) on top, then the **chicken Robux offer** (`BuildChickenOffer`) as
  the ▶ carousel card, then one more product card that opens the Shop (reuse
  ShopCatalog; no new products). Cards show "ONLY <price>" with the Robux glyph.
- Top-right: Settings gear stays; the corner notice stays under it.
- Top-centre banners (`Theme.Notification`): text in the reference's colours (green =
  reward, red = refusal, orange = event) on a dark translucent strip, stacked, with the
  "(xN)" repeat counter. Gold Rush chip unchanged.
- Nothing device-specific; phones get the same layout (AGENTS.md "ONE UI layout").

### 2.3 Upgrades tree (P3)
Positions and the catalog stay. Change presentation only: backdrop = blurred world with a
dark tint (black, 35% transparency) instead of solid black (supersedes UPGRADES_SCREEN.md
"solid black": Stevin now wants the reference and finds black hard to read); hex states
exactly as in section 1 (owned keep the Army green, affordable-next = dark + red "!" +
green price, unaffordable = dark + red price, locked = grey "?"); name above / numeral in
the icon corner / price below; tooltip layout; wide red Close/Back at the bottom centre;
Coins readout + Gold/Diamond/Prism "N Rolls Left" counters top-left while open; the red
"-price" delta beside the Coins on a buy; the "You need N more Coins!" red banner on a
refused buy. Owned hexes stay green (art), everything else matches.

### 2.4 Rebirth: Coins visibly zero, Time Skip is a claim (P4)
Why Coins never read zero: `RebirthService.Rebirth` sets `coins = 0` and then credits
Time Skip (`timeSkipMinutes` of income) in the same transaction, so the first packet after
a Rebirth already shows thousands. Fix: the server stores the Time Skip Coins as a pending
reward (`session.timeSkipPending = {coins, rank}`, saved, additive, lenient; a new
Rebirth adds to an unclaimed one, never loses it) and the balance stays 0. After the
Rebirth celebration the client shows a **"Time Skip!"** popup in the Welcome Back style
("TIME SKIP: +N Coins", green Claim!); `ClaimTimeSkip` credits it through
`Credit(…, "rebirth")` (analytics source TimeSkip unchanged). The popup also shows on
join when a pending reward exists (Auto Rebirth while away, or a disconnect). The HUD
readout snaps to 0 (CountTo drops spends at once) and the Rebirth bar reads
"0 / 1,000,000" like the reference. Skip Rebirths are unchanged.

### 2.5 Rebirth ladder and income curve (P5)
Target: the early ladder feels like the reference's (R1 50K → R2 1M = 20×) while the
measured times stay where the October 21 fit put them, and Coins do not pour in faster.
Constraints for the re-fit (`tests/ProgressionSimulation.luau` with the Lune harness):
- `Config.Rebirth.Costs[1] = 5e4`, `Costs[2] = 1e6`; consecutive ratios between 3 and 20
  through R10 and between 1.1 and 3 after, monotone; 50 ranks stay.
- Time targets (fast nonstop medians): R1 ≈ 10 min, R2 ≈ 18–20 min, R5 ≈ 55 min, R10 ≈
  2.9 h, R20 ≈ 11 h, R30 ≈ 21 h, R50 ≈ 40 h; 45-min-a-day player R30 ≈ day 21 (see
  REBIRTH_PACING_20261021.md tables). Keep "no rank takes more than 2.5 h of play".
- The knobs are within-run income growth, not the ladder alone: Chicken Feed level growth
  (`Rules.EggRate`: 2× per level today), Feed prices, tree tier values/prices
  (`UpgradeCatalog`), the Rebirth egg multiplier (`RebirthService.Multiplier`, +100% a
  rank today), Time Skip minutes. Prefer the smallest set of changes that meets both.
- Never: rarer chickens earning less than common ones, changes to the 11 original tier
  species' stats, a `DataRevision` bump, or a tier-meaning change without a
  `TreeMigrations` step. Saved levels/tiers keep working; prices are live.
Deliver the new numbers, the before/after tables and the login-model check in
`REBIRTH_PACING_20261021.md` (new section) and pin them in `tests/RebirthV2Checks.luau`.

### 2.6 Yard collection feel (P6)
The vacuum counter "N / cap" is a dark pill centred above the hotbar (where My Army was);
the prompt line "Collect (Hold) · Unload (Hold)" sits under it with input glyphs (text
only changes by input; layout never does). Each egg entering the vacuum plays one short
bright chime (`EggPickup`/`Collect` cue, pitch rising across a streak, 0.07 s gap floor,
reset after 0.6 s idle) and a "+N" coin float over the player (budgeted); the Coins
readout gets the green "+N" delta (P1 builds the delta label; P6 feeds it through the
existing `ActionFeedback` path, one call). Unloading on the pad keeps the coin burst and
adds the whoosh. The suction swirl (WorldFeel) is yellow and reads from a distance.

### 2.7 Rewards popups (P7) and Shop (P8)
**Shop decision reversed (Stevin, October 21, 13:00): "I don't want to copy their side
scrolling shop though, keep my shop the same format as before." The P8 rail was merged and
then reverted on main (a9b56d5); the tabbed Shop (Crates / Passes / Coins, crate buy pill on
every offer, rounded cards, no odds screen on passes) stays. P8 is closed; the Shop only
inherits P2's shell.**

Offline = "Welcome Back!" 1:1 (no "Claim x2" unless a product exists; none does today, so
one green Claim!). Daily = the 7-card grid with the tall Day 7 and the "Next reward in"
chip. Playtime Rewards keep their 12 tiles but in the shell. Free Gift = "Free Reward!"
1:1 (our two rows: Like, Join; a Claim! white button). Shop = one horizontal card rail in
the reference's card families using ONLY our existing catalog (Galaxy Crate pack card
with the x1/x3/x10 pills and odds portraits, four passes as colour cards, Coin packs as
the 2×2 small cards + one big card, Rebirth Skip where it is on sale), a bottom
scrollbar, and the red "Gift!" button under the window that opens the Free Gift.
Prices come from the Marketplace as today; nothing new goes on sale.

### 2.8 Out of scope this pass
Weather, Center teleport, the Blitz tool, the hole, Updates popup, Index rewards, quests,
new products, server economy outside P4/P5, the tutorial, and the My Army grid.

## 3. Work split

| Id | Area | Owns (edit only these; small additive hooks elsewhere go in the hand-off) |
|---|---|---|
| P1 | HUD 1:1 | `client/HudController.luau`, `client/BoostReadout.luau`, `client/FriendBoost.luau`, `client/HillHud.luau` (chip slot only), `client/FreeGiftController.luau` (HUD button only), `client/CornerNotice.luau` (position only), `client/GoldRushController.luau` (chip position only) |
| P2 | Popup shell + conformance | `client/UITheme.luau` (ApplyPopupStyle, Header, Button/ActionButton/PriceButton, Notification, Label stroke helper), `client/AppController.luau` (blur for every menu, FitPanel), `client/MenuLayout.luau`, then the style pass on `client/IndexBrowser.luau`, `client/SellMenu.luau`, `client/AutoRollMenu.luau`, `client/OperationsPanel.luau`, the Settings rows (in AppController), `client/GemUpgradeGrid.luau` (shell only) |
| P3 | Upgrades tree presentation | `client/ResearchBrowser.luau`, `client/CashUpgradeNodes.luau`, `client/ResearchExtras.luau`, `client/ResearchAssets.luau` |
| P4 | Rebirth zero + Time Skip claim | `server/RebirthService.luau`, `server/PlayerSession.luau` (the new saved key + TUTORIAL-style list entry), `server/GameServer.luau` (`ClaimTimeSkip` request), `server/DataService.luau` only if the key needs it, `client/RebirthPanel.luau`, new `client/TimeSkipController.luau`, new `tests/TimeSkipClaimChecks.luau`, `docs/team/REBIRTH_SCREEN.md` |
| P5 | Ladder + income re-fit | `shared/Config.luau` (Rebirth block), `shared/Rules.luau`, `shared/UpgradeCatalog.luau` (values/prices), `shared/GemUpgradeCatalog.luau` (Time Skip minutes if needed), `server/RebirthService.luau` **Multiplier only** (coordinate with P4: that function is P5's), `tests/RebirthV2Checks.luau`, `tests/ProgressionSimulation.luau`, `docs/team/REBIRTH_PACING_20261021.md` |
| P6 | Yard collection feel | `client/VacuumController.luau`, `client/ToolController.luau`, `client/EggController.luau`, `client/EggFeedback.luau`, `client/ActionFeedback.luau`, `client/CoinBurst.luau`, `shared/CollectionFeel.luau`, `client/ChickenLabel.luau` (check only) |
| P7 | Rewards popups | `client/OfflineCashController.luau`, `client/DailyRewardController.luau`, `client/FreeGiftController.luau` (popup only), `client/PlaytimePanel.luau` |
| P8 | Shop rail (closed: Stevin keeps the old Shop format; branch unmerged) | – |

Shared-file contracts:
- `UITheme` is P2's. Workers who need a new shell helper before P2 lands write a small
  local function in their own file and name it in the hand-off; the lead lifts it.
- `HudController` is P1's. P4/P6/P7 do not edit it; the HUD already snaps to `state.coins`,
  floats gains (`QueueFloat`) and exposes `app.hud`. P6's green delta goes through
  `ActionFeedback`/`app.hud:QueueFloat` as it exists; P1 restyles that float into the
  beside-the-pill delta.
- `RebirthService`: P4 owns the transaction; P5 owns `Multiplier` and reads `Config`.
  Both touch nothing else there.
- `tests/RebirthV2Checks.luau` is P5's; P4 adds its own test file.
- Sounds: code plays cue names from GAME_FEEL §3 through `app:Cue`/`audio:Cue`; nobody
  edits the Studio sound library (the lead runs the recipe and volumes). New cue names
  go in the hand-off with a one-line description.

## 4. Acceptance (the lead checks in Studio after each merge)

- Phone (844×390), Tablet and PC UI Lab renders of every touched story: nothing clips,
  hit targets ≥ 48 px, all text stroked and readable over the bright test sky AND over a
  dark screenshot.
- Play pass: HUD at the reference positions; open/close every menu (blur + shell), buy a
  tree node (badge, delta, banner), vacuum 20 eggs (chimes, floats, counter), unload
  (burst + whoosh), Rebirth with a disposable profile ("Test as a new player" in Settings):
  balance reads 0, the Time Skip popup claims, the Rebirth bar reads 0 / 1,000,000.
- `RebirthV2Checks`, `TimeSkipClaimChecks`, `PlaytimeChecks`, `DailyChecks`,
  `FlockChecks` pass in a fresh Run-mode playtest (`solo_playtest mode=run` then
  `eval_server_runtime` requiring `ServerStorage.PetRollTests.<Suite>`).
- No new client or server errors in the runtime logs.

## 5. Iteration

Stevin asked to keep iterating until it matches. After each merge the lead captures the
screen next to the reference frame, lists differences, and sends them back to the same
worker (its branch stays alive). Workers keep their worktree until the lead says done.

## 6. How every worker works

1. You are in your own worktree on a branch from `main` ≥ 9fe4f48. Commit there; never
   on `main`; never push or publish. One writer per file: only your Owns list.
2. Read `AGENTS.md`, `docs/CODE_MAP.md`, `docs/team/GAME_FEEL_20261021.md` §1–3 and §6,
   this file, and your area's existing contract doc (REBIRTH_SCREEN.md,
   UPGRADES_SCREEN.md, PLAYTIME_REWARDS.md, OFFLINE_CASH.md, FREE_GIFT.md,
   SHOP_FORMATTING.md, VACUUM_IMPLEMENTATION.md, COLLECTION_TOOLS.md as relevant).
3. Study every reference frame for your screen (section 1 table) before designing;
   match layout, order, copy, states and what happens after an action. Only art changes.
   List unavoidable differences (policy, glossary, missing product) in your hand-off.
4. House rules: Scale geometry + aspect constraints + TextScaled, one layout for every
   device, TweenService for simple motion, the shared feel vocabulary (no private tween
   helpers), `UITheme.Studs` for studs, black-stroke chicken icons, glossary words
   (Coins, Army, Flock, Upgrades, Missions, "Rebirth N"; never "$"), server owns money.
5. Studio belongs to the lead. Do not run `rojo serve`, do not use Studio or Studio Flow
   tools, do not touch `ServerStorage`/`StarterGui`. Verify with: the analyzer on each
   changed file against a `git archive HEAD` baseline (memory: `local-luau-checks`:
   `~/.vscode/extensions/johnnymorganz.luau-lsp-1.70.1-darwin-arm64/bin/server analyze
   --platform=roblox --sourcemap=<scratch>/sourcemap.json --definitions=@roblox="~/Library/
   Application Support/Code/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.
   PluginSecurity.d.luau" <file>`, sourcemap from `rojo sourcemap default.project.json`),
   and `/Users/stevin/Documents/Projects/MyChickenArmy/.tools/rojo build
   default.project.json -o <scratch>/x.rbxlx`. Server/shared logic also runs headless with
   the Lune harness at `/private/tmp/claude-501/-Users-stevin-Documents-Projects-
   MyChickenArmy/5d50c550-9868-47d7-9181-17f6a37a0451/scratchpad/harness/` (copy it into
   your own scratchpad first; `lune run harness.luau <repoRoot> <entry.luau> [args]`).
6. Hand-off (your final message): branch + commits, files touched, what changed per
   reference frame, hooks you need in hot files, cues used, what to playtest, and any
   difference from the reference you could not close. Then stay available: the lead will
   send Studio findings for another round.
