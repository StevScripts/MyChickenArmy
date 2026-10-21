# October 20 overhaul: decisions and parallel sessions

Owner decisions settled with Stevin in chat on October 20, 2026 (lead session
"Clarifying questions for game changes"). Nothing here is implemented yet.
Where this file conflicts with an older dated rule in `AGENTS.md`, this file
wins; the lead adds a dated AGENTS.md paragraph during integration.

References:
- Reference game: **Drop a Fruit** (Together Studios, place 82132121666307).
  Systems guide built from Stevin's recordings:
  `~/Documents/ChatGPT/My Chicken Army/output/2026-10-20-systems-guide/`
  (`GUIDE.md`, the PDF, `screenshots/`, `details/`). Where the guide disagrees
  with this file, this file wins (the guide removes the Gem shop and Skip; Stevin
  kept them, and the Flock model below replaces the guide's "Army Size =
  equipped producers").
- Rebirth + Gems plan v2: https://claude.ai/artifact/CNzDiNzPkm8MCm7hQYa3G3
  (read it with the Artifact tool). Build it with all 13 "Still open"
  recommendations, changed as listed below.

## How every session works (read first)

1. **Confirm before you build.** Start by telling Stevin, in a few lines, what you
   will change, which files you will touch and what you will leave alone. Wait for
   his confirmation before editing anything.
2. Read `AGENTS.md`, `docs/CODE_MAP.md`, this file's Decisions and your own section.
3. Work on your own branch, `oct20/<id>-<slug>`, in its own worktree. If you were
   not started in one, run
   `git worktree add .claude/worktrees/oct20-<id> -b oct20/<id>-<slug> main`
   and work only there. Do not commit to `main`, push or publish.
4. Studio belongs to the lead. Do not run `rojo serve` into the canonical place and
   do not write in Studio. Read-only inspection is fine when no playtest is
   running. Ask the lead (SendMessage; find it with ListAgents) for Studio assets,
   uploads and playtests.
5. One writer per file: edit only the files in your **Owns** list. Hot shared
   files (`PlayerSession`, `Config`, `GameServer`, `AppController`,
   `HudController`) allow small additive edits in your own function or block.
   List each one in your hand-off; the lead merges.
6. If your section says **Ask Stevin for a reference first**, do that before you
   design the UI.
7. House rules still apply: the AGENTS.md glossary (Coins, Flock, Army, Upgrades,
   "Rebirth N", never "$"), one layout for every device, TweenService for simple
   motion, black-stroke chicken icons, `UITheme.Studs` for UI studs, server owns
   money and state.
8. Saves: new fields are additive and lenient. Never make an existing save fail to
   load; enforce new rules when the player acts.
9. Hand-off to the lead: branch, files touched, what to playtest, open questions.
   Run `rojo build` and any quick relevant `tests/` checks; say which you ran.

## Decisions

### Rebirth and Gems
- Plan v2 as written: Coins-only Rebirths from 50K (about 10 min to Rebirth 1,
  then every 8–30 min), 30 ranks, Gems = 40 + 10 × rank, Skip ("keep upgrades")
  at 49/99/199 R$ by rank band and hidden where paid random items are restricted,
  30 Veteran Corps Rebirth chickens (granted at the rank, plus a 1% podium
  chance), the reference screen copied 1:1 in the game's style (Army-green
  header, right panel titled "Gem Upgrades"), Coins reset to 2,400 plus Time Skip,
  camp/King progress kept with flags released, enemy scaling ×1 through Rebirth 2
  then +0.25 per rank by the attacker's rank, mutation unlocks Rainbow 1 /
  Shadow 5 / Cosmic 10, Veteran Missions at King clear or Rebirth 5, existing
  ranks kept with double Gems and their Rebirth chickens granted, phones locked
  to landscape.
- **Changed from plan v2:**
  - Rebirth resets the **entire Upgrades tree**: every Coins upgrade, including
    Flock Size, Army Size, Roll Slots, the tools and their upgrades, and the
    Gold/Diamond machines. Chicken levels bought with Chicken Feed reset; levels a
    chicken was rolled with stay. Kept: chickens, Index, mutations, rank, Gems,
    Gem Upgrades, passes.
  - Gem Upgrades: drop Fuse Discount; add **Auto Roll**, **Rally** and **Vacuum
    Capacity**. Copy the reference's first rows (Roll Speed, Extra Luck /
    Vacuum Capacity, Auto Roll); P0 re-fits rows and Gem prices.
  - Unlocks leave the tree: Auto Roll and Rally become Gem Upgrades, **Call Army is
    free for everyone**, and Mission tiers open by King clear or Rebirth rank.
  - Rebirth chickens are collected, not fused (Fuse is removed).

### Upgrades tree
- Rebuilt like Drop a Fruit's tree: a few named tiers per family (Luck I, II,
  III…) instead of 20–25 levels. Research merges into one ladder per family.
  Every node is an instant Coins purchase: no timers, no researchers, no Robux
  research skips.
- Removed nodes: researchers, research speed, formations, Fuse Machine, Call Army,
  Mission tiers, Auto Roll, Rally.
- "Open" category hexes lead to subtrees with a Back hex: **Tools** (Egg Vacuum
  with its capacity tiers; Chicken Feed), **Player**, and **Army** stats
  (proposed; confirm with Stevin).
- Red count badges show how many upgrades are affordable right now, respecting
  the starter reserve. They appear on the HUD Upgrades button and on each Open hex.
- Bought and maxed hexes use the bright Army green (#A3FF00 → #00D300). Prices
  stay gold.
- Tooltips show the name, the effect (current → next), the price and "Resets on
  Rebirth".
- Still no camp, rank or King gates (Sep 25 rule).
- Every node gets its own icon (GPT, chunky style, black outline).

Draft node list (S7 finalizes it in P0):
- **Main tree** (about 25 hexes around Start):
  - Egg Speed I–IV and Egg Value I–IV
  - Luck I–IV
  - Flock Size ladder from 3
  - Army Size I–IV
  - Roll Slot I–VII
  - Roll Speed I–III
  - Gold Machine → Gold Rate I–II → Diamond Machine → higher tier
  - The three Open hexes
- **Tools:** Vacuum Capacity I–IV, Vacuum Range I–II, Chicken Feed.
- **Player:** Walk Speed, Click Range, Offline Time.
- **Army:** Damage, Health, March Speed, Armor, Recovery, Boss Damage, Bounty,
  Capture Speed.

### Flock and storage
- Storage is unlimited, with a hidden safety cap of about 1,000 chickens per save.
- **Flock Size = how many chickens are out in the yard laying.**
  - It starts at 3 and grows in small steps (P0 sets the ladder).
  - The yard still grows in stages, but every build is instant. This retires the
    Oct 16 timed builds.
- **Only Flock chickens lay eggs**, online and offline.
  - The yard fills with your best egg layers that are home.
  - Players can pick by hand: Equip Best plus equip/unequip, like the reference's
    Fruits menu.
- **The Army is the player's pick** (Select Best = most powerful).
  - An Army chicken can also be a Flock layer.
  - While it marches out, the next best layer fills in until it returns.
- **My Army menu:**
  - Black background at transparency 0.1.
  - Formations and Stats are hidden for now behind a flag (code kept).
  - The inspector's Coins level-up button is removed; Chicken Feed replaces it.
    Ship both together.

### Collection
- Eggs are already 3D voxel MeshParts (`ReplicatedStorage.PetRoll.Assets.EggMeshes`,
  126 species, done Oct 20).
- Players **click/tap eggs** to collect them. Clicking is unlimited.
  - Clicked eggs go into the unlimited bag and are sold on the green pad.
  - The automatic walk-over pickup goes away.
  - Gamepad needs a path too.
- **Egg Vacuum:**
  - A hotbar tool given free when the Commander guide ends.
  - While equipped, it pulls in nearby eggs automatically until its capacity is full.
  - Capacity is shown in eggs ("carried / capacity") but sized in seconds of the
    Flock's current laying: 30 s to start, Tools tiers 45/60/90/120 s, Gem Vacuum
    Capacity +15 s per level. Partial stacks split. (Stevin, later Oct 20, after
    S7's P0 showed fixed egg counts stop mattering from about Rebirth 2.)
  - Unload it on the pad.
  - Capacity comes from Upgrades > Tools tiers (reset on Rebirth) plus the Gem
    Vacuum Capacity (kept).
- **Chicken Feed** (the upgrade tool):
  - Bought in Upgrades > Tools and re-bought after each Rebirth.
  - Equip it and walk to your own chicken at home. The prompt
    "Chicken · Lv 3 → 4 · 9,000 Coins" buys one level, using the server quote and
    the existing `ArmyService` upgrade path. Cap is Lv 10.
- **Selling eggs** gets a Pet Simulator-style coin burst:
  - 3D gold coins burst out of the pad, bounce, then fly into the player.
  - The Coins counter ticks up as each coin lands.
  - It is visual only; the server has already paid.

### Rolling
- **Roll camera:**
  - Push in during the shuffle.
  - Shake and zoom punch on Epic and up.
  - Slow orbit on Legendary, Mythic and Secret reveals.
  - A lighter version during Auto Roll.
  - Reduced motion respected. Built directly in Roblox (no Claude Design prototype).
- **Auto Roll** (now a Gem Upgrade):
  - Stop at a rarity.
  - Auto-recruit a chosen rarity or better when affordable.
  - Mutation-stop toggle.
  - Control from anywhere.
  - On a hit, hold the chicken on its podium and show a big alert; recruit from the
    menu or walk over.
  - Fix today's "Upgrade" stop rule.
  - **Stevin designs the HUD: ask for his reference first.**
- **Gold rolls:** tree nodes like the reference (Gold Machine, Gold Rate, Diamond
  Machine, a higher tier).
  - The machine shows a countdown, "N Rolls Left".
  - Each lever pull counts once, and on a special pull every podium gets it.
  - Gold gives a better result, Diamond better still, and the higher tier better
    again.
  - **The exact effect is open: ask Stevin for a reference first.**

### World, events, social
- **Mission sites ("drops"):**
  - Use the map's stud MaterialVariants ("Studs", "Studs 2x2 Plastic",
    "Weld 2x2 Plastic", as on the rest of `MyChickenArmyMap`) instead of the 80%
    black texture overlay in `MissionSite.Studify`.
  - Their arrow and beam show only until the player's first Mission win, and they
    obey "Next goal hints OFF".
- Remove the top army status text ("Marching to X", "Returning home"…). Keep the
  Hill info.
- **King of the Hill:**
  - A 10-second "The Hill is open!" cutscene, once per player ever, saved.
  - It plays on the first Hill round after the player is eligible (camps or King
    cleared, the same rule that shows the Hill HUD).
  - Hill VFX come from `ServerStorage.VFX["Weather VFX"]`. **Stevin picks them
    later; remind him.**
- **Gold Rush (2x Coins event):**
  - Every 20 minutes for 5 minutes, server-wide, with a countdown chip.
  - Gold sky, warm light, and gold sparkles and coins drifting in the air. Visual
    only; nothing to pick up.
  - Doubles all Coins (eggs, battles, Missions) and stacks with the 2x Coins pass.
  - Boosts count when Coins are paid (pad sale, end of a fight or Mission).
  - Never frozen into offline earnings, never applied to daily rewards or Robux
    Coin packs.
- **Friend Boost:**
  - "Friend Boost: +N%" under Coins, with a green + that opens an explanation and
    Invite Friends.
  - +10% per Roblox friend in the server, max +50%, on all Coins.
  - Computed on the server; excludes purchased Coins and refunds.

### Removals and monetization
- **Fuse is removed:** menu, prompt, research node, hints and Auto Fuse. No new
  Giants can be made.
  - Existing Giants and Colossals shrink to the normal maximum size but keep ×2 HP,
    ×1.5 damage and splash.
  - The one-Colossal limit still applies to them.
  - The lead removes the physical Fuse machines from the six plots in Studio.
- **Passes off sale:** Auto Collect Eggs (the robot vacuum goes away), Egg Magnet,
  Double NPC Bounty and Commander Banner. Auto Fuse is already off.
  - Take off any other pass a new unlockable makes pointless, after flagging it to
    Stevin.
  - Owners get a one-time Gems gift of about half the R$ price: 100 / 25 / 125 / 50.
  - Kept on sale: 2x Coins, 2x Egg Spawn, Bigger Army and 2x Luck.
  - Robux research skips are removed.
  - Pass-style perks become Coins upgrades.
- **Sell menu:** a separate menu for selling chickens (bulk select). **Stevin
  designs it: ask for his reference image first.**

### Later decisions (Oct 20, in the sessions; the contract docs have details)
- **Egg Vacuum** (S14): bought in Upgrades > Tools (about 500 Coins) and reset on
  Rebirth like Chicken Feed. This replaces "given free when the guide ends".
- **Old Giants and Colossals** (S13): become ordinary chickens with no size, name or
  stat perks, and no Colossal limit. The saved size is kept unused so it can be
  undone. This replaces "shrink but keep perks". See `FUSE_REMOVAL_AND_SELL.md`.
- **Rebirth screen** (S8): one tap, no hold. The screen stays open with confetti, and
  the reward chicken shows in colour once the Rebirth is affordable. See
  `REBIRTH_SCREEN.md`.
- **Upgrades screen** (S9): phones buy on tap with no card, every affordable hex gets
  a red "!", and the backdrop is solid black. See `UPGRADES_SCREEN.md`.
- **Gold rolls** (S12): Luck boosts ×2/×5/×10 for Gold/Diamond/Prism, every
  10/8/6 pulls with Gold Rate 0/I/II. Auto Roll stops at a typed "1 in X", and
  Rebirth chickens always stop it. See `AUTO_ROLL.md`.
- **Roll length** (S2 v2): `RollRevealSeconds` is 4. The reveal snaps out with a
  flash and speed lines; there is no orbit.
- **Economy** (S7): Time Skip pays minutes of the pre-Rebirth income. RecruitLevel
  ignores Feed levels. Rebirth chickens 25–30 stay stronger than the Cosmic Dragon.
  The Skip products are live (49/99/199 R$), and the four retired passes are off sale.
- **Friend Boost** (S4): the + button opens Roblox's invite list directly.
- **Guide** (S14): the first Collect goal is 20 eggs, a Flock Size I step comes before
  Army Size I, and the Rebirth Next goal shows only when it's ready.

### Existing players
- Old tree levels and research convert to the closest new tiers. This is the
  lead's default (Stevin said "idk"); S7 shows him the mapping when it confirms.
- Rebirth veterans are handled per plan v2.
- Never wipe progress and never fail a load.

### Release
- Ship in batches.
- Batch 1 is the independent wave-1 pieces, each shipped once ready and approved.
- Batch 2 is the linked core (tree, Rebirth, Flock, tools, economy, guide), shipped
  together.
- Stevin publishes (File → Publish to Roblox) and restarts servers.

## Rules this supersedes

The lead writes these into AGENTS.md as one dated Oct 20 paragraph.

- **Upgrade rules (Sep 25 onward):** research is no longer permanent, and the tree
  resets on Rebirth. The "no camp/rank gates" rule stays.
- **Later Sep 27 board review, Oct 7 Luck retune, Oct 8 growth:** the track lengths
  and prices are replaced by the new tiers and the P0 fit. The Oct 6 Luck window
  math stays.
- **Sep 29 Plot1 T / capacity 25–100 and Oct 16 timed builds:** Flock Size now
  means layers out in the yard, and builds are instant.
- **Sep 29 Roll Slot prices:** re-fit in P0. Eight podiums remain.
- **Sep 29 / Oct 15 chicken cash upgrades in the inspector:** replaced by Chicken
  Feed.
- **Sep 25 merging, Oct 6 Fuse research, Oct 14 Giants, Sep 28 Colossal sizes:**
  Fuse is gone. Existing Giants shrink and keep their perks.
- **Oct 15 Auto Roll research, Call Army research, Mission-tier research:** moved
  as above.
- **Oct 15 Rebirth ladder:** replaced by plan v2.
- **Oct 3 "vacuum deliveries get no player burst":** that was the robot. Unloading
  the hand vacuum on the pad is a manual sale and plays the coin burst.

## Sessions

| ID | Session | Wave | Size | Starts after |
| --- | --- | --- | --- | --- |
| S1 | Quick UI fixes | 1 | S | baseline commit |
| S2 | Roll camera | 1 | S–M | baseline commit |
| S3 | Coin burst on egg sales | 1 | S–M | baseline commit |
| S4 | Gold Rush + Friend Boost | 1 | M | baseline commit |
| S5 | Hill first-time cutscene | 1 | M | baseline commit |
| S6 | Icons | 1 | M (art) | baseline commit |
| S7 | Economy core (server) | 2 | L | baseline commit; others wait for its contract |
| S8 | Rebirth screen + Gems HUD | 2 | M–L | S7 contract |
| S9 | Upgrades screen | 2 | M–L | S7 contract, S1 merged |
| S10 | Flock, storage and My Army | 2 | L | S7 contract, S1 merged |
| S11 | Collection and tools | 2 | L | S7 contract, S3 merged |
| S12 | Auto Roll + Gold rolls | 2 | M–L | S7 contract, S2 merged |
| S13 | Fuse removal + Sell menu | 2 | M | S7 contract |
| S14 | Commander guide and Next goals | 3 | M | S7, S10, S11 merged |

Each session's prompt is the same three lines with its ID filled in:

```
You are session S<n> "<name>" of the My Chicken Army Oct 20 overhaul.
Read AGENTS.md, docs/CODE_MAP.md and docs/team/OVERHAUL_PLAN_20261020.md (the "How every session works" rules, the Decisions, and section S<n>).
Before editing anything, tell Stevin in a few lines what you'll change and which files you'll touch, then wait for his confirmation.
```

### S1 · Quick UI fixes (wave 1)
- **Goal:**
  - My Army background becomes black at transparency 0.1.
  - Hide My Army's Formations and Stats behind a flag.
  - Remove the top army status text.
  - Mission-site arrow and beam only until the first Mission win, obeying
    "Next goal hints OFF".
  - Mission sites use the map's stud MaterialVariants.
- **Owns:** `src/client/ChickenBrowser.luau` (background and flag only),
  `src/client/HudController.luau` (status text only),
  `src/client/CommanderGuide.luau`, `src/client/BaseController.luau`,
  `src/server/MissionSite.luau`.
- **Notes:**
  - Removing the status lets the "Next:" line show more often
    (`CommanderGuide:292`); check that reads well.
  - The first Mission win may already be tracked: see `TutorialGuide:156-161`.
  - Inspect the map's MaterialVariant use read-only before choosing variants per part.

### S2 · Roll camera (wave 1)
- **Goal:** the four camera moves in Decisions › Rolling, using TweenService. Keep
  your own slot-1 podium rule and no-menu rule, and respect reduced motion. Use
  the lighter version during Auto Roll (today it's skipped entirely).
- **Owns:** `src/client/RollPresentationController.luau`, plus an optional new
  client module for the camera.
- **Reuse:** the Cut/Dolly/Shake helpers in `IntroCutscene.luau:615-645`. Copy
  what you need; don't refactor IntroCutscene.

### S3 · Coin burst on egg sales (wave 1)
- **Goal:** the Pet Simulator-style deposit coin burst (Decisions › Collection).
  - Build the coins in code from the gold coin art (`docs/team/GOLD_COINS.md`).
    The unused `Assets.CashDrop` may help.
  - Cap the coin count for phones.
  - Reduced motion falls back to the existing "+N Coins" text.
- **Owns:** `src/client/ActionFeedback.luau`, `src/shared/CollectionFeel.luau`,
  and a new client `CoinBurst` module.
- **Note:** S11's hand-vacuum unload uses the same deposit path, so it gets the
  burst too.

### S4 · Gold Rush + Friend Boost (wave 1)
- **Goal:** both systems as specified in Decisions.
  - A server clock (new service) replicates the state and the next start time.
  - A client controller does the sky, light and particles. Build the particles in
    code, or ask the lead to copy pieces of `ServerStorage.VFX["Weather VFX"]` (for
    example Glow Dust or Stylized Sunshine) into ReplicatedStorage.
  - Apply the Gold Rush and Friend Boost factors **once**, in the authoritative
    earned path (`PlayerSession:EarnedAmount`).
  - Keep both out of the offline checkpoint (`OfflineCash.Rate`, `DataService`
    checkpoint).
  - Friend Boost line: a self-mounting module under the Coins readout. Invites go
    through `SocialService:PromptGameInvite`.
- **Owns:** new `GoldRushService` (server), new `GoldRushController` and
  `FriendBoost` (client), `src/server/OfflineCash.luau`, plus new blocks in
  `Config.luau`, `EarnedAmount` in `PlayerSession.luau`, and start lines in
  `GameServer`/`AppController`.

### S5 · Hill first-time cutscene (wave 1)
- **Goal:** the 10-second "The Hill is open!" cutscene (Decisions › World).
  - Save a flag such as `hillIntroSeen` the way `introSeen` is saved
    (`TutorialService:192-193`, `PlayerSession:926`).
  - Trigger it from `HillService` when a round opens for an eligible player who
    hasn't seen it.
  - Lock/Unlock, the black bars and SKIP, camera moves and Caption copy the small
    helpers from `IntroCutscene.luau:1068-1217`.
  - Wait for Stevin's Hill VFX choice. Placing VFX in Studio is the lead's job.
- **Owns:** a new client `HillIntro` module, `src/server/HillService.luau`,
  `src/server/TutorialService.luau`, and the saved key in `PlayerSession`.

### S6 · Icons (wave 1, art only)
- **Goal:** chunky icons with a black outline on a transparent background, made
  with the chatgpt-image skill. Use the chunky-simulator-icons references and the
  pipeline in `assets/generated/store-icons-20261014/generate.sh`.
- **Families:** one icon per upgrade family and node type. Tiers I/II/III reuse
  the family icon with a numeral, like the reference; confirm with Stevin.
  - Tree families from the draft node list, plus Back and the Tools, Player and Army
    Open hexes.
  - Tools: Egg Vacuum, Vacuum Capacity, Vacuum Range, Chicken Feed. The guide's
    `art/chicken-feed-concept.png` is the direction for Chicken Feed.
  - Roll upgrades: Gold Machine, Gold Rate, Diamond Machine, higher tier.
  - Gem Upgrades: Roll Speed, Extra Luck, Vacuum Capacity, Auto Roll, Coin Boost,
    Auto Rebirth, Time Skip, More Gems, Keep Upgrades, Rally, Mutation Luck,
    Offline Coins, Army Power, Rebirth Chicken Odds.
  - Currency and HUD: the Gem currency, Friend Boost, Gold Rush.
- **Output:** `assets/upgrade-icons-20261020/` with a review contact sheet for
  Stevin. After he approves, the lead uploads them through Studio Flow.
- **Owns:** that folder only.

### S7 · Economy core, server (wave 2: start first)
- **Goal:** plan v2 packages P0–P3, P6 and P7, plus the new tree data and the
  migrations.
- **First deliverable,** after Stevin confirms:
  `docs/team/OVERHAUL_CONTRACT_20261020.md`, covering:
  - saved fields and snapshot fields for every wave-2 session (the S7 save schema
    holds all of them);
  - request names;
  - the tree catalog shape and node ids;
  - the Gem Upgrade ids;
  - effect hooks.

  S8–S13 start when it exists.
- **Scope:**
  - **P0:** fit the costs in `tests/ProgressionSimulation.luau`. Model Flock-only
    production, the reset-everything Rebirth, Gem spending, tools and Gold Rush.
  - **Catalogs:** the new tree in `UpgradeCatalog` with research merged in.
    `ResearchCatalog`, `ResearchRules` and `ResearchService` become instant
    and run-scoped, or retire. Add `GemUpgradeCatalog`, `MutationCatalog` ranks,
    and Rebirth chickens in `PetCatalog` (fallback looks; models are a later art
    pass).
  - **Server:**
    - `RebirthService` (quote, reset manifest, rewards, Skip credit, Auto Rebirth,
      scaling).
    - New `GemUpgradeService`.
    - `UpgradeService` for instant buys.
    - `OperationService` (Mission tiers by King clear or rank).
    - `ArmyCommandService` (Call Army free).
  - **Monetization:** `ShopCatalog`, `CommerceService`, `ProductService`,
    `DataService`.
    - Skip products and credits.
    - The passes listed above go off sale.
    - Gems gifts for their owners.
    - Research skip products removed.
    - Product creation goes through `tools/monetization.py` with a dry run, and
      Stevin approves the live write.
  - **Migration** in `PlayerSession`/`DataService`:
    - old tree and research → closest new tiers;
    - plan v2 veterans;
    - removed-pass Gems;
    - every field additive and lenient.
  - **Analytics:** append-only (`AnalyticsSchema` version bump).
- **Owns:** everything named in Scope, plus `Config` (Rebirth and tree blocks),
  `GameServer` (new requests) and the save schema in `PlayerSession`.

### S8 · Rebirth screen + Gems HUD (wave 2)
- **Goal:** plan v2 P4. Build it to the plan's element spec:
  - `RebirthPanel` rebuilt;
  - a new `GemUpgradeGrid`;
  - a Gems counter above Coins;
  - Rebirth chicken silhouettes in the Index;
  - a `MenuLayout` entry and a LabStories story with `LateGameState.json`.

  The landscape lock is a Studio property; the lead sets it.
- **Owns:** `RebirthPanel`, new `GemUpgradeGrid`, `IndexBrowser`, the Rebirth entry
  in `MenuLayout`, `src/server/UIAuthoring/LabStories.luau`, Gem assets in `UITheme`,
  and the Gems hook in `HudController`.

### S9 · Upgrades screen (wave 2)
- **Goal:** the reference-style tree UI from Decisions › Upgrades tree.
  - Open category hexes with subtrees and a Back hex.
  - Tooltips, plus a deliberate Buy action on touch.
  - Red count badges in the screen and on the HUD Upgrades button.
  - Bright green for bought hexes.
  - The S6 icons.
  - The research timer and researcher UI removed.
  - Fix today's Auto Roll/L2 cell overlap.
- **Owns:** `ResearchBrowser`, `CashUpgradeNodes`, `ResearchAssets`,
  `ResearchExtras`, and the Upgrades badge hook in `HudController`.

### S10 · Flock, storage and My Army (wave 2)
- **Goal:** Decisions › Flock and storage.
  - Unlimited storage.
  - Flock Size as the number of layers out.
  - Only Flock chickens lay, online and offline.
  - Auto-best plus manual equip.
  - Backfill while the Army is out.
  - Yard stages with instant builds.
  - My Army gets an equipped strip and a storage grid.
  - Remove the inspector level-up button, shipped together with S11's Chicken Feed.
  - Remove the "Ready! Fuse 3" hint.
- **Owns:** `ChickenBrowser`, `ArmyService` (selection/equip),
  `EggService` (production only), `HomePlotLayout`, `WorldService` (yard stages),
  and the production/selection functions in `PlayerSession`.

### S11 · Collection and tools (wave 2)
- **Goal:** Decisions › Collection.
  - **Click/tap/gamepad egg collection.** Turn on `CanQuery` or add a hit box
    without breaking the voxel-egg efficiency rules, and add a server claim with a
    range check.
  - Remove walk-over pickup.
  - The hand **Egg Vacuum** tool: granted at guide end, automatic while equipped,
    capacity in eggs, unloads on the pad.
  - **Chicken Feed:** bought in Tools, prompts on your own home chickens.
  - A small tool dock.
  - Turn off the robot vacuum and the Auto Collect stand.
  - The held vacuum model: build it from parts, or ask the lead for a Studio model.
- **Owns:** `EggView`, `EggController`, `EggService` (collection only),
  `VacuumController`, `VacuumConfig`, `EggRover`, `AutoCollectStandController`,
  and new `ToolService`/`ToolController`/`ToolDock` modules.

### S12 · Auto Roll + Gold rolls (wave 2)
- **Goal:** Decisions › Rolling, except the camera.
  - The server Auto Roll loop rules (`RollService:65-102`, `GameServer:606-616`),
    unlocked by the Gem Upgrade.
  - The Gold/Diamond/higher-tier counter and its machine display.
  - What each special roll gives.
- **Ask Stevin for references first,** both for the Auto Roll HUD and for the Gold
  roll results.
- **Owns:** `RollService`, `RollStation`, the Auto Roll loop in `GameServer`, a new
  Auto Roll menu module, and `RollPresentationController` (after S2 merges).

### S13 · Fuse removal + Sell menu (wave 2)
- **Goal:**
  - Remove Fuse from `MergeBrowser`, `MergeStand`, `MergeSelection` and the fusion
    endpoints in `ArmyService`. Keep the save fields loadable.
  - No new Giants.
  - Existing Giants shrink but keep their perks: display scale only
    (`GiantChicken`, `ChickenGrowth`, `BlenderPetView`). `Rules.Stats` stays.
  - A bulk Sell menu with a server bulk-sell endpoint.
- **Ask Stevin for his Sell menu reference image first.**
- **Owns:** the files above, plus the sell endpoint in `ArmyService` and a new
  `SellMenu` module.

### S14 · Commander guide and Next goals (wave 3)
- **Goal:** rework `TutorialGuide`, `CommanderGuide` and `TutorialService` for the
  new loop:
  1. click eggs → sell on the pad → free roll → recruit;
  2. Flock and Army → Cluck Camp;
  3. the guide ends and the vacuum is granted;
  4. later tips: Chicken Feed and Vacuum Capacity in Upgrades > Tools.

  Next goals use the new Rebirth (50K) and drop Fuse. Keep the protected starter
  reserve.
- **Owns:** those three files and the guide targets in `BaseController` (after S1
  merges).

### Lead (this session)
- **Baseline:** commit after the two busy Chicken Army sessions go idle, then
  merge each branch in order.
- **Docs:** the dated AGENTS.md paragraph, plus docs updates (`CURRENT_GAME.md`,
  `CODE_MAP.md`, `UPGRADE_RULES.md`).
- **Studio work:**
  - remove the Fuse machines;
  - place the Hill VFX after Stevin picks;
  - Gold Rush assets;
  - icon uploads;
  - the landscape lock.
- **Release:** Studio playtests before each batch and release notes.
- **Stevin decides:** publishing and the Creator Dashboard pass changes. Some
  passes may already be off sale; check the dashboard.
