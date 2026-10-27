# WS4 — Rolls that show something new (early-session discovery curve)

> **Lead note (Oct 27):** FavoredRolls 3 x 50% is adopted (conflict C1 in `docs/team/RETENTION_PLAN_20261027.md`).

Worker: WS4 research + plan, October 27, 2026. No repo files were edited.
Probe scripts (scratch, headless Lune, real modules):
`docs/team/retention-20261027/sims/ws4/discovery_probe.luau`
(plus `index_total.luau`, `power.luau` in the same folder). Run from `tools/sim`:
`<lune> run harness.luau ../.. <probe> trials=6000 pulls=40 [slots=2] [only=N] [ua=2 ra=8 uag=5 rag=10 win=40]`.

---

## 1. Problem and evidence

### 1.1 What a new player's pulls look like (live 1.25.0, Oct 26–27)

Ledger `rolls.byRarity` (all players, 59,521 podium offers): Common 89.1%, Uncommon 9.3%,
Rare 1.5%, Epic 0.1%. Buy rate per offer: Common 11.3%, Uncommon 21.6%, **Rare 61%**,
Epic+ ~300% (bought from Auto Roll holds). Players buy Rares when they see them; the
problem is that new players almost never see one.

`stateSnapshots.bestRarity`: 1,006 of 1,297 snapshots (78%) have a Common as the best
chicken owned. `rollSlots` p50 = 1: most players roll **one podium**, one offer per pull.

Pulls per new player (journeys27.json, 847 new sessions; `r` = whole-session pulls,
two of them are the tutorial's):

| Session length | n | Pulls (median) | Buys | Pets | Coins earned (median) |
|---|---|---|---|---|---|
| 2–4 min | 165 | 3 | 2 | 2 | 1,182 |
| 4–6 min | 82 | 5 | 3 | 3 | 2,471 |
| 6–8 min | 65 | 7 | 4 | 4 | 5,144 |
| 8–10 min | 44 | 9 | 5 | 5 | 7,302 |
| 10–13 min | 34 | 9.5 | 5 | 5 | 8,553 |
| 13–16 min | 16 | 11.5 | 6 | 6 | 15,483 |

Reach of post-tutorial pull k (share of the 484 sessions that finished the tutorial;
"minute" is a rough linear estimate from s·(2+k)/r):

| Post-tutorial pull | 1 | 2 | 3 | 5 | 7 | 8 | 10 | 12 |
|---|---|---|---|---|---|---|---|---|
| Reached by (of finishers) | 85% | 70% | 58% | 41% | 28% | 24% | 17% | 14% |
| ≈ minute of play | 2.3 | 3.0 | 3.8 | 5.0 | 6.2 | 6.9 | 7.9 | 8.4 |

So the median 5–10 minute player gets about **five post-tutorial pulls**, which today all
fall inside `FavoredRolls` (5 pulls, 60% basic Chicken on podium 1).

### 1.2 What those pulls contain today (real RollService, 1 podium, 6,000 players)

`discovery_probe.luau`, variant "TODAY" (FavoredRolls 5×60%, Luck 0, no buys):

| Post-tutorial pull | 1 | 2 | 3 | 5 | 8 | 10 | 15 | 20 | 40 |
|---|---|---|---|---|---|---|---|---|---|
| Saw an Uncommon+ | 3.1% | 5.6% | 8.5% | 13.5% | 30.7% | 40.4% | 58.6% | 71.1% | 93.3% |
| Saw a Rare+ | 0.4% | 0.6% | 1.0% | 1.6% | 4.3% | 5.8% | 9.6% | 12.9% | 25.9% |
| New species seen (cum.) | 0.29 | 0.57 | 0.85 | 1.37 | 3.10 | 4.08 | 6.04 | 7.55 | 11.32 |

- Median first Uncommon: **post-tutorial pull 13** (only 14% of finishers get that far).
- Median first Rare: **pull 87** on one podium (over 300 pulls: share Rare 0.77%). At the
  observed ~0.7–1 pull a minute that is more than an hour; essentially no first-session
  player sees a Rare.
- With FavoredRolls off, the first five pulls show 3.1 new species instead of 1.37:
  **FavoredRolls halves the variety of the median player's whole session.**

### 1.3 Commons feel identical, and nothing tells the player they differ

Real numbers (level 1, `power.luau`): basic Chicken power 13 / 4 Coins/s / 150 Coins;
Rooster 16 / 6 / 1,900; Bonsai Bantam 20 / 17 / 3,000; Bee (Uncommon) 30 / 18 / 3,400;
Robo-Cluck (Rare) 38 / 30 / 8,000; Crystal Chicken (Rare) 59 / 56 / 9,600.
A Rare lays 7–8× a basic Chicken and fights 3× harder; an Uncommon 4.5× / 2.3×. None of
this is visible on the podium: the tag shows name, "Common · 1 in 17" and a price.
`PlayerSession:OfferAdvice` already computes "Makes your army stronger" / "Lays eggs worth
N/s in your Flock" for every offer (RollStation.luau:299–301, PlayerSession.luau:720,
snapshot PlayerSession.luau:821) **but no code displays it** (grep: no client reader).

There is no "first find" moment anywhere: the reveal plays the same white ring and
`RollReveal` cue (0.32 volume) for every Common; a Rare plays `RollReveal` too (only Epic+
get stingers, RollPresentationController.luau:662); the recruit toast is the same for the
fifth basic Chicken and a brand-new species (AppController:TrackRecruit, line 290). The
Index count (IndexBrowser.luau:445) only shows inside the Index menu, which 50 of 847
new sessions opened.

### 1.4 Why pulls per session are low (lever time, walking or price?)

- **Not the lever.** The reveal is 4 s with no extra cooldown (RollService.luau:96–97).
  Post-tutorial gaps between consecutive pulls in the trails: p25 6 s, median 8 s,
  p75 15 s; 77% under 15 s, 3.5% over 60 s. Inside a burst players pull as fast as the
  lever allows.
- **Walking/attention.** Bursts are separated by egg collecting, selling and menus; the
  lever is at the base and its prompt reaches 8 studs. Session average ≈ 0.7–1 pull/min.
- **Price is why pulls feel pointless.** Non-basic Commons cost 1,900–3,000 Coins,
  Uncommons 3,400–4,500, Rares 8,000–13,100, while a new player earns ~1.2k by minute 3 and
  ~5k by minute 7. In the first ~3 minutes alone the trails hold 1,817 rejected "Buy"
  actions (2.1 per new player); 33% of finishers hit at least one "Not enough coins" in
  that window. Pulling again replaces the offer, so a pull has no reason to exist unless
  something exciting could appear. (Price levels are WS2's lane; see §8.)
- There is **no reason shown to pull again** (no counter, no goal) — the Gold Machine
  counter that gives that reason costs 25,000 Coins and is never seen in session 1.

## 2. Root cause in code

| Where | What | Effect |
|---|---|---|
| `src/shared/PetCatalog.luau:444–451` LuckBands | Common 92.9%, Uncommon 6.3%, Rare 0.76% (Oct 22 owner decision, Drop a Fruit shares) | Correct long-run, but no early-session shaping at all |
| `src/shared/ChickenLuck.luau:23` ShiftPerDecade 0.35 | Luck I–IV only lifts Rare+ 0.8% → 1.8% | Luck cannot rescue the first session (Luck 0 for 89% of snapshots) |
| `src/shared/Config.luau:14` FavoredRolls `{rolls=5, chance=0.6, species="Duck"}` | `RollService.favoredSpecies` (RollService.luau:34–46) forces the basic Chicken on podium 1 for post-tutorial pulls 3–7 (tutorial.rollCount < 2+5) | Covers the median player's entire session; halves new-species sightings |
| `src/server/RollService.luau:76` forced order `debugNext or ladder or favored or guaranteed` | No discovery guarantee exists | First Rare at pull ~87 |
| `src/server/RollStation.luau:242–253` | Tag = name / "Rarity · 1 in X" / price; `offerAdvice` computed, never shown | Differences invisible |
| `src/client/RollPresentationController.luau:111–126, 640–668` | Celebrate only rank ≥ 4; Rare uses the Common cue | First Rare feels like a Common |
| `src/client/AppController.luau:290–328` | Recruit toast has no first-find branch | No "NEW!" moment, no Index progress |
| `Config.RollSlotsUnlocked`/tree Roll Slot II 1,000 Coins | p50 one podium | One offer per pull (WS2/WS5 lever, not WS4's) |

## 3. Options considered and the recommended design

### 3.1 Options

1. **Raise base Uncommon/Rare shares.** Rejected: owner decision (Oct 22 "mostly common",
   Oct 23 every chicken its own odds); changes the whole economy and Rebirth-find pacing.
2. **Luck boost for new players** (e.g. x10 Luck for 10 minutes). Rejected: at
   ShiftPerDecade 0.35 even x10 only reaches Rare 2.7% a pull; first Rare still ~pull 35.
3. **Hidden pity timers with time gates** (tested: Rare at ≥8 pulls and ≥8 min). Works
   numerically, but it is invisible, so it does not make players pull, and a promise that
   depends on wall time cannot be shown honestly.
4. **Visible, pull-counted "Lucky Start" guarantees** that stop once the player owns the
   rarity, plus "NEW!" tags, the unused advice line and a first-find celebration.
   **Recommended.** It shapes only the first ~40 post-tutorial pulls, forces at most two
   Uncommons and two Rares per profile ever, shows the countdown like the Gold Machine
   counter (an owner-approved pattern) and leaves long-run shares intact.
5. **Retire FavoredRolls entirely.** Right if WS2 removes the price cliff (non-basic
   Commons ≤ ~500 Coins early). With today's prices the basic Chicken is the only
   affordable early recruit, so keep a smaller version (3 pulls × 50%).

### 3.2 Recommended design

**A. Lucky Start (server, `src/server/LuckyStart.luau`, new).** For empty-start profiles
(`introRebirth ~= nil`) after the tutorial completes (`guideCompleted` or `coreDone`, not
`guideSkipped`), count post-tutorial lever pulls `k` in a saved additive table
`luckyStart = {pulls, nextU, nextR, firesU, firesR}`.

- Uncommon guarantee: on pull `k >= nextU` (starts at **2**), if the player owns no
  Uncommon+ (Index `discovered`) and `firesU < 2`, podium 1 shows an **Uncommon** drawn
  by today's odds renormalised inside the Uncommon rarity (Bee 18% … Lollipop 3%).
- Rare guarantee: on pull `k >= nextR` (starts at **8**), if no Rare+ is owned and
  `firesR < 2`, podium 1 shows a **Rare** drawn the same way (Robo-Cluck 20%, Neon 16%,
  Gladiator 13% … Frost 2%; 77% of draws cost 8,000–8,500 Coins).
- Any natural Uncommon+ (resp. Rare+) offer on any podium, and every forced one, pushes
  the next guarantee to `k + 5` (resp. `k + 10`). Rare is checked first; one forced
  podium per pull.
- Window: post-tutorial pulls 1–40 (`Config.LuckyStart.Window`). After that, or once
  both rarities are owned, nothing is forced again. Saves without the field get a fresh
  table at load (only empty-start profiles ever use it).
- Precedence on podium 1: `debugNext > StarterLadder > paid DoubleLuck guarantee >
  Lucky Start > FavoredRolls > normal draw`. (Today the paid guarantee is after
  FavoredRolls; moving it ahead only matters for restricted 2x Luck owners in their first
  3 pulls and keeps the disclosed paid schedule intact.) If the paid guarantee takes the
  pull, Lucky Start waits one pull (counter reads "next Roll").
- Never applies to the starter roll, Auto Roll counts the same as a manual pull (Auto
  Roll is a Gem Upgrade, not in session 1), Playtime/Daily free rolls do not count.

**B. Visible countdown.** One extra row on the existing lever counter billboard
(`RollStation` `rollCounters`, the Gold Machine's "6 Rolls Left" display) with the Luck
clover icon (`rbxassetid://111087925336083`, Theme.Assets.Luck) in the rarity colour:
"Uncommon in 2 Rolls" → "Uncommon next Roll!" → (after it) "Rare in 6 Rolls" → "Rare next
Roll!". Hidden when nothing is pending. On the forced pull the podium shows the existing
special-roll tag in the rarity colour, "Lucky roll · Rare!" (ShowSpecialTag with kind
"Lucky"), so the shuffle builds anticipation.

**C. Roll-past guard.** A manual lever pull while podium N holds an unbought Lucky Start
offer, any unbought Rare+ during the Lucky Start window, or the next Rebirth find
(`RebirthChickens.Wanted`) is refused once per offer with: "Robo-Cluck (Rare) is still on
your podium! Pull again to roll past it." The second pull rolls. Auto Roll is exempt (it
has its own holds). Live field, never saved.

**D. FavoredRolls 3 × 50%** (`Config.Economy.FavoredRolls = {rolls=3, chance=0.5,
species="Duck"}`), Lucky Start wins over it. If WS2 prices non-basic Commons at
≤ ~500 Coins in the first session, set `rolls = 0` (retire).

**E. "NEW!" on the podium.** When the offer's species is not in the owner's Index, the
rarity line reads (RichText) `NEW! · Common · 1 in 17` with "NEW!" in gold. On a fresh
reveal on your own podium the client floats "NEW!" (WorldFeel:Text, gold) and plays the
"Badge" cue. 13 Commons + 12 Uncommons are all new early, so almost every non-basic pull
in session 1 is a small moment.

**F. Show the difference: the advice line.** A fourth tag line (owner only, it is the
owner's podium) from a reworked `PlayerSession:OfferAdvice`, Flock first because eggs are
the core loop:
1. Would lay now (Flock has room, or beats the weakest layer): "+18 Coins/s in your Flock"
   in green (`UIColors.Money`), the number = its laying rate minus the layer it replaces.
2. Else, if it beats the weakest Army chicken or fills a free Army slot: "Makes your Army
   stronger" / "Fills an Army slot" in green.
3. Else "Lays 6 Coins/s" in `UIColors.Muted`.
Whole numbers via `Currency.Rate` (Oct 23 rule).

**G. First-find celebration and Index progress.** `RollService:Buy` checks
`session.discovered[species]` before `AddPet`; the reply's `recruit` gains
`firstFind=true, found=n, total=m` (`IndexProgress.Count`, shared with IndexBrowser so the
numbers match; a fresh player reads "/83": 78 rollable + 4 crate + Hill Champion). The
client replaces the normal recruit toast with an "event" toast:
"NEW CHICKEN! Bee Chicken · Index 4/83", plays "Jingle" and pulses the chicken gold
(`base:PetPulse`). One emphasis per event (no confetti). WS5 may ping the Index button.

**H. Rarer reveals read rarer.** Rare reveals play the existing `RollRare` cue (today
`RollReveal`). The first reveal of a rarity the player has never owned, from Rare up, adds
`ScreenFeel:Celebrate(color, 1)` when the roll camera is not already presenting (today only
Epic+). Camera rules unchanged (zoom/flash only).

### 3.3 Simulated results (real RollService / Rules / ChickenLuck, 1 podium, Luck 0)

"Never buys" = guarantees re-fire up to the cap; "buys first seen" = stops after the first
of each rarity. Real players sit between.

| Variant | Uncommon+ seen by pull 2 / 5 | Rare+ seen by pull 5 / 8 / 10 | New species by pull 5 / 10 | Median first U / R pull |
|---|---|---|---|---|
| Today (Favored 5×60%) | 5.6% / 13.5% | 1.6% / 4.3% / 5.8% | 1.37 / 4.08 | 13 / 87 |
| Favored off, no pity | 13.1% / 30.6% | 4.0% / 6.6% / 8.1% | 3.10 / 5.33 | 10 / >40 |
| **Proposal, never buys** | **100% / 100%** | 2.5% / **100%** / 100% | 2.96 / 6.36 | **2 / 8** |
| Proposal, buys first seen | 100% / 100% | 2.5% / 100% / 100% | 2.92 / 5.98 | 2 / 8 |
| Today, 2 podiums | 18.3% / 40.1% | 5.2% / 10.1% / 12.8% | 4.06 / 7.55 | 7 / >40 |
| Proposal, 2 podiums, buys | 100% / 100% | 6.8% / 100% / 100% | 5.31 / 9.20 | 2 / 8 |

Mapped to play time with the live reach table (§1.1): the first Uncommon lands at about
minute 3 for the 70% of finishers who reach pull 2 (today 5.6% of them see one); the
first Rare at about minute 7 for the 24% who reach pull 8 (today 4.3%). The countdown
should raise pulls per session, which raises both reach numbers.

**Share impact (must stay ~unchanged).** Forced offers are capped at 2 Uncommon + 2 Rare
per profile ever (measured 0.93–0.97 of each when players buy the first one, 2.00 when
they never buy).

| Rarity share | Today, 300 pulls | Proposal buys, 300 | Proposal never buys, 300 | Today 40 | Proposal buys 40 |
|---|---|---|---|---|---|
| Common | 92.97% | 92.32% | 91.69% | 93.43% | 88.61% |
| Uncommon | 6.20% | 6.53% | 6.82% | 5.82% | 8.23% |
| Rare | 0.77% | 1.09% | 1.43% | 0.70% | 3.11% |
| Epic | 0.05% | 0.05% | 0.05% | 0.05% | 0.05% |

Over a first day (300+ pulls) the shift is a few tenths of a point and decays to zero;
Epic and up are untouched; Luck window math, LuckBands and every "1 in X" label are
unchanged. **The rarity shares themselves do not need to change.**

**Affordability (WS2 dependency).** At today's prices the guaranteed Uncommon (3,400–4,500)
arrives around minute 3 with ~1.2–2.5k earned, and the Rare (8,000–8,500 for 77% of draws)
around minute 7 with ~5k earned: both become a 3–6 minute saving goal. They are the best
early deals in the roster (Bee pays back in ~3 min of its own eggs vs Rooster ~5 min), so
saving for them speeds the economy. The roll-past guard keeps the offer from being lost
by an accidental pull, and the second guarantee (5 / 10 pulls later) catches players who
roll past anyway. If WS2 shortens that wait, good; WS4 does not require it.

## 4. Implementation steps

Order: (1) Config + LuckyStart + IndexProgress, (2) RollService, (3) PlayerSession save +
advice, (4) RollStation tag/counter, (5) GameServer wiring + analytics, (6) client, (7)
tests/probe/docs. Keep relative module paths; no formatting passes.

### 4.1 `src/shared/Config.luau`
- Line 14: `FavoredRolls = {rolls = 3, chance = 0.5, species = "Duck"},` with a dated
  comment (Oct 27, WS4: five favoured pulls covered the median player's whole session and
  halved new species; Lucky Start wins over it; set rolls = 0 once early Commons are cheap).
- Next to `RollRevealSeconds` (line ~144) add:
```lua
 -- October 27 Lucky Start (docs/team/LUCKY_START_20261027.md): after the tutorial, an
 -- empty-start profile's post-tutorial pull UncommonAt shows an Uncommon and RareAt a
 -- Rare on podium 1 unless one was offered already; a natural or forced offer moves the
 -- next one Again pulls later; at most MaxForced each; never once that rarity is owned
 -- or past Window pulls. Guard: the first manual pull past such an offer is refused once.
 LuckyStart={Enabled=true,UncommonAt=2,UncommonAgain=5,RareAt=8,RareAgain=10,MaxForced=2,
  Window=40,Guard=true,Icon="rbxassetid://111087925336083"},
 -- Podium tag extras: "NEW!" for chickens missing from the Index, and the advice line.
 Discovery={NewTag=true,Advice=true},
```

### 4.2 `src/server/LuckyStart.luau` (new, WS4 only)
Pure functions over a session; requires Config, PetCatalog, Rules, RebirthChickens.
- `RANK = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythic=6, Secret=7}`.
- `LuckyStart.Fresh()` → `{pulls=0, nextU=cfg.UncommonAt, nextR=cfg.RareAt, firesU=0, firesR=0}`.
- `LuckyStart.Read(saved)` → clamps each field with whole numbers (pulls 0..Window+1,
  next* 1..1000, fires* 0..MaxForced); non-table → `Fresh()`. Never rejects a save.
- `LuckyStart.Active(session)`: `cfg.Enabled and session.introRebirth ~= nil` and tutorial
  `guideCompleted or coreDone` and `guideSkipped ~= true` and `luckyStart.pulls < cfg.Window`.
- `LuckyStart.Owns(session, rank)`: any `session.discovered[id]` with `RANK[rarity] >= rank`.
- `LuckyStart.Due(session)` → `"Rare" | "Uncommon" | nil` for the next pull `k = pulls+1`:
  Rare if `not Owns(3) and firesR < MaxForced and k >= nextR`, else Uncommon likewise.
- `LuckyStart.Draw(session, rng, rarity, paidLuck, researchLuck)`: `Rules.Odds(...)`,
  sum odds of `Catalog.Order` ids whose rarity equals `rarity`, pick by
  `rng:NextNumber() * total` (Luck applies inside the rarity; the starter-only and
  crate-exclusive chickens have odds 0 already).
- `LuckyStart.Record(session, offers, forcedKind)`: when Active, `k = pulls + 1`;
  `pulls = k`; for every offer: rank ≥ 2 → `nextU = max(nextU, k + UncommonAgain)`;
  rank ≥ 3 → `nextR = max(nextR, k + RareAgain)`; if `forcedKind` → `fires*+= 1`.
- `LuckyStart.State(session)` → nil or `{kind, left = max(1, next - pulls)}` for the row
  and the snapshot (Rare first if its next is due sooner or Uncommon is owned/capped).
- `LuckyStart.GuardOffer(session)` → the first unbought offer (slot order) with
  `offer.lucky`, or (Active and rank ≥ 3), or `RebirthChickens.Wanted(session, species)`.
- `LuckyStart.CounterText(state)` → "Rare in 6 Rolls" / "Rare next Roll!" (1 → next).

### 4.3 `src/server/RollService.luau` (WS4 writes; WS2 supplies prices)
- `require(script.Parent.LuckyStart)`.
- `RollService:Roll(session, now, manual: boolean?)`:
  - After the cooldown check: if `manual and Config.LuckyStart.Guard` then
    `local keep = LuckyStart.GuardOffer(session)`; if `keep and session.rollPastWarned ~=
    keep.id` then `session.rollPastWarned = keep.id` and return `false,
    Catalog[keep.species].name .. " (" .. rarity .. ") is still on your podium! Pull again
    to roll past it."`. (`rollPastWarned` is live only.)
  - Compute `lucky = if not starter and not ladder and not guaranteed and
    LuckyStart.Active(session) then LuckyStart.Due(session) else nil`;
    `luckySpecies = lucky and LuckyStart.Draw(session, rng, lucky, paidLuck, researchLuck)`.
  - Compute `favored` only when `luckySpecies == nil`.
  - Move `guaranteed` above (it is already computed before the loop) and change line 76 to
    `forced = if slot==1 then session.debugNext or (ladder and ladder.species) or guaranteed
    or luckySpecies or favored else nil`.
  - Offer fields: `new = (not session.discovered[species]) or nil`, `lucky = if slot==1 and
    luckySpecies then lucky else nil`. A lucky offer's `chance` = 1 like `guaranteed`.
  - After the loop, before `session:Touch()`: `LuckyStart.Record(session, offers,
    if luckySpecies then lucky else nil)`; clear `session.rollPastWarned = nil`.
  - Price line untouched (WS2's).
- `RollService:Buy`: before `AddPet` take `local firstFind = not session.discovered[species]`;
  after it compute `found, total = IndexProgress.Count(session.discovered, Config.Event)`;
  add to the receipt: `firstFind = firstFind or nil, found = found, total = total`, and
  add `lucky = offer.lucky, new = offer.new` to `recruit.offer`.
- `StepAuto` keeps calling `self:Roll(session, now)` (no guard).

### 4.4 `src/shared/IndexProgress.luau` (new, WS4 only)
`IndexProgress.Count(found: {[string]: boolean}, eventOn: boolean): (number, number)`:
the exact rule now inline in IndexBrowser.luau:431–449 (visible = ever found, or not
vaulted and not (limited without the event); counts collected/total over
`Catalog.Order`). IndexBrowser then calls it for the Normal tab's numbers.

### 4.5 `src/server/PlayerSession.luau`
- `new` (near line 84): `self.luckyStart = LuckyStart.Fresh()`.
- Serialize (line ~912, beside `goldRolls`): `luckyStart = table.clone(self.luckyStart)`.
- Load (line ~1386): `self.luckyStart = LuckyStart.Read(data.luckyStart)` (additive; no
  DataRevision change; a missing field reads fresh).
- `OfferAdvice(species, level, mutation, army)` (line 720) → returns `(text, good)`:
  1. `rate = DisplayedPetIncome(species, 1, level, mutation)`; laying ids =
     `self:FlockIds()`; if `#flock < self:FlockSize()` gain = rate, else gain = rate −
     the weakest layer's `DisplayedPetIncome`; if gain ≥ 1 → `"+" .. Currency.Rate(gain) ..
     " Coins/s in your Flock", true`.
  2. Existing Army checks with capitalised words: "Fills an Army slot" / "Makes your Army
     stronger", true.
  3. `"Lays " .. Currency.Rate(rate) .. " Coins/s", false`.
- Snapshot (line ~921): `luckyStart = LuckyStart.State(self)` (nil when inactive).
  (No `require` cycle: LuckyStart requires only shared modules and RebirthChickens.)

### 4.6 `src/server/RollStation.luau`
- `offerLabel`: gui 340×120; add `line("Advice", 96, 24, 18)`; return it as a 5th value.
  Authored-plot scale layout (Sync block lines 62–69): Text 0–0.30, Rarity 0.30–0.52,
  PriceRow 0.52–0.78, Advice 0.78–1.0, all `TextScaled`.
- `rollCounters`: after the GoldRolls kinds, build one more row named "Lucky" (same
  look; icon `Config.LuckyStart.Icon`; LayoutOrder 0 so it sits on top).
- `Sync(session)`: `self.offerNew = Config.Discovery.NewTag and offer ~= nil and not
  session.discovered[offer.species]`; keep the existing `offerAdvice` call (now Flock
  first); `local lucky = LuckyStart.State(session)`; enable the counter gui when
  `#counters > 0 or lucky`; Lucky row text `LuckyStart.CounterText(lucky)`, colour
  `UIColors.Rarities[lucky.kind]`. Set attribute `RollLucky = offer and offer.lucky`.
- `Step`: `self.rarityLabel.RichText = true`; text = `(if self.offerNew then
  '<font color="#FFD630">NEW!</font>  ' else "") .. def.rarity .. " · " .. oneIn`;
  `self.adviceLabel.Text = if Config.Discovery.Advice then self.offerAdvice else ""`,
  colour `UIColors.Money` if `offerImprovesArmy` else `UIColors.Muted`. Clear it with
  the other labels while rolling/idle and in `Clear`; add "RollLucky" to the Clear list.

### 4.7 `src/server/GameServer.luau`
- Line ~302: `self.rolls:Roll(session, now, true)`.
- `CountOffers`: for each offer `if offer.lucky then LaunchCount("luckyStart.forced." ..
  offer.lucky .. "." .. session.luckyStart["fires" .. offer.lucky:sub(1,1)])`;
  `if offer.new then LaunchCount("roll.new.offer")`.
- Roll rejected by the guard (message ends "Pull again to roll past it."):
  `LaunchCount("luckyStart.guard.shown")`; a successful pull with `rollPastWarned` set
  before the call: `LaunchCount("luckyStart.guard.rolledPast")`.
- `CountRecruit`: `if offer.lucky then LaunchCount("luckyStart.bought." .. offer.lucky)`;
  `if recruit.firstFind then LaunchCount("roll.new.bought")` and
  `LaunchFirst("index.first." .. rarity)` + `LaunchHist("index.firstSeconds." .. rarity,
  play)` the first time per rarity.

### 4.8 Client
- `src/client/RollPresentationController.luau`
  - In the fresh-reveal branch (line ~645): if own station and
    `not (app.state.discovered or {})[species]` → `self.app.worldFeel:Text(record.foot +
    Vector3.new(0, 5.5, 0), "NEW!", {color = GOLD})` and `self:Cue("Badge")`.
    First-of-rarity flag: no discovered species of `def.rarity` → `self.reveal.first = true`.
  - Line 662: `stinger = if rank >= 4 then … elseif rank == 3 then self:Cue("RollRare",
    "RollReveal") else "RollReveal"`.
  - `Celebrate`: `if (rank >= 4 or (rank == 3 and reveal.first)) and not cameraHandles …`.
  - `ShowSpecialTag(record, kind)`: if `kind == "Lucky"` use `Config.LuckyStart.Icon`,
    text `"Lucky roll · " .. luckyRarity .. "!"`, colour `UIColors.Rarities[luckyRarity]`;
    call it where `RollSpecial` is read (lines 451/565) when the station has `RollLucky`.
    Reduced motion settles as today (TweenService only).
- `src/client/AppController.luau` `TrackRecruit` (line 290): if `recruit.firstFind` →
  text `"NEW CHICKEN! " .. name .. " · Index " .. recruit.found .. "/" .. recruit.total`
  + "\n" + classification, `self:Notify(text, "event")`, `self:Cue("Jingle")`,
  `self.base:PetPulse(id, C.gold)`; call `self.hud:PingIndex()` if WS5 provides it.
- `src/client/IndexBrowser.luau` lines 431–449: use `IndexProgress.Count`.

### 4.9 Player-facing copy (exact)
- Counter: "Uncommon in 2 Rolls", "Uncommon next Roll!", "Rare in 6 Rolls", "Rare next Roll!"
- Special tag: "Lucky roll · Uncommon!", "Lucky roll · Rare!"
- Podium rarity line: "NEW!  Common · 1 in 17"
- Advice: "+18 Coins/s in your Flock", "Fills an Army slot", "Makes your Army stronger",
  "Lays 6 Coins/s"
- Guard: "Robo-Cluck (Rare) is still on your podium! Pull again to roll past it."
- Toast: "NEW CHICKEN! Bee Chicken · Index 4/83"
- No "FREE", no "$", no "pets", no device verbs (AGENTS player-facing words).

## 5. Analytics (append-only, Schema.Version 15 → 16)

`src/server/AnalyticsSchema.luau` (one shared version bump for all WS; see §8):
- `LaunchCounters`: `["luckyStart.forced"]` (.<Uncommon|Rare>.<1|2>),
  `["luckyStart.bought"]` (.<kind>), `["luckyStart.guard"]` (.shown / .rolledPast),
  `["roll.new"]` (.offer / .bought), `["index.first"]` (.<rarity>, LaunchFirst).
- `LaunchHistograms`: `["index.firstSeconds"] = "longSeconds"` (.<rarity>).
- `FeatureFunnels` Roll: append `{id="UncommonOrBetter", trigger="recruited an Uncommon+
  chicken"}`, `{id="Found5", trigger="5 different chickens in the Index"}`,
  `{id="LuckyRareSeen", trigger="server:luckyStart.forced.Rare"}`;
  `src/server/AnalyticsFunnels.luau` Buy branch (line ~345): `rank >= Uncommon →
  named(self, st, "Roll", "UncommonOrBetter")`; Found5 from `#discovered >= 5`.
- State snapshot: append `indexFound` (count kind) beside `bestRarity`.

Compare by build version (`v`) in `AnalyticsReport` / journeys, tutorial finishers only:

| Metric | Today (est.) | Target |
|---|---|---|
| Finishers owning an Uncommon+ in session 1 | ~5% (probe: 13.5% even see one by pull 5) | ≥ 35% |
| Finishers owning a Rare+ in session 1 | ~1% | ≥ 10% |
| `index.firstSeconds.Uncommon` median | > 15 min | ≤ 7 min |
| Post-tutorial pulls per finisher (median) | ~4 | ≥ 6 |
| `bestRarity` le1 share (snapshots) | 78% | ≤ 60% |
| Survival 5 / 10 min (with WS2/WS5) | 36% / 21% | 40% / 24% |
| Guard: rolledPast / shown | — | ≤ 50% |
| Long-run `roll.offer` Rare share (all players) | 1.5% | 1.5% ± 0.3 pp |

## 6. Verification

Headless (Lune, `tools/sim`):
1. Copy the probe into the repo as `tools/sim/discovery_probe.luau`, switched from the
   scratch monkeypatch to the real `LuckyStart` module; expect the §3.3 table within
   ±1 pp (`trials=6000 pulls=40`, `pulls=300` share check).
2. New `tests/LuckyStartChecks.luau` (small): fresh session with two Ducks, guide done,
   pulls 1..40 with a fixed `debugRandom`: pull 2 is Uncommon unless pull 1 was; pull 8
   is Rare unless one was offered; owning a Rare stops Rare forcing; max 2 each; window
   ends at 40; `introRebirth = nil` never forces; `Read` of garbage/nil never errors; guard
   refuses the first manual pull past a Rare once and lets the second through; Auto Roll
   ignores the guard; `IndexProgress.Count` equals IndexBrowser's rule.
3. `runsuite.luau CommanderGuideChecks` (update line 164 to `rolls==3 and chance==0.5`),
   `AutoRollChecks`, `LuckWindowChecks`, `RecruitFeedbackChecks`, `FoundationChecks`;
   compare failures against a `git archive HEAD` baseline (README note: about a dozen
   suites already fail headless).
4. luau-lsp analyze on touched files against the HEAD baseline.

Studio playtest (the root agent, place 96683186622050, Edit state checked first):
1. Fresh profile (admin reset), play the eight cards. After card 8 the lever shows
   "Uncommon in 2 Rolls".
2. Pull once: a non-basic Common shows "NEW!  Common · 1 in X", the advice line, a gold
   "NEW!" float and the Badge cue. Counter "Uncommon next Roll!".
3. Pull: "Lucky roll · Uncommon!" tag during the shuffle, an Uncommon lands. Pull again
   without buying → guard message; pull again → rolls. Counter "Rare in 5 Rolls".
4. Pull to post-tutorial pull 8: green-blue Lucky tag, Rare lands with the RollRare cue and
   ScreenFeel celebration (no camera orbit). Admin-grant Coins and buy: toast "NEW
   CHICKEN! … · Index n/83", Jingle, gold pulse; Index menu shows the same n/83.
5. Rejoin: counter keeps its count. An old save (`introRebirth` nil): no counter, no
   guard except Rebirth finds. Phone emulation: the 4-line tag stays legible at 38 studs.

## 7. Risks, owner-rule conflicts, rollback

- **Rarity shares (Oct 22/23 owner decision).** Long-run unchanged; early pulls shift
  (first 40: Rare 0.7% → 3.1% for buyers). The change is bounded (≤ 2 + 2 forced offers per
  profile) and disclosed on the machine. State this in the doc and AGENTS entry.
- **FavoredRolls was Stevin's Oct 25 call.** Reduced from 5×60% to 3×50% on live data;
  he asked not to be asked. Retire fully if WS2 removes the price cliff.
- **"1 in X" honesty.** Labels stay zero-Luck odds; the counter tells the player which
  pulls are guaranteed. Rolls are free (no Robux), so paid random-item rules do not apply;
  the paid 2x Luck guarantee keeps priority.
- **Rebirth finds.** A guaranteed Uncommon is Ironbeak (Rebirth 1 find) 11% / Detective 9%
  of the time; a guaranteed Rare is Robo-Cluck (find 5) 20%, Gladiator 13%, Deepsea Diver
  11%, Rockstar 9%. Pre-finding them slightly speeds a few early Rebirths; acceptable.
- **Saving vs Rebirth 0.** The Rare goal (≈8,000) competes with the Rebirth 0 tip (1,700).
  WS5 orders tips; Rebirth 0 keeps chickens, so both can happen.
- **Guard friction.** One extra press, only during Lucky Start or for Rebirth finds.
- **Coins-shortfall prompt.** Trying to buy an unaffordable lucky offer may open the Robux
  Coins pack (after the tutorial and 2,000 Coins earned). WS3 decides; `offer.lucky` is
  readable from `session.offers` on the failed Buy.
- **Billboard size/perf.** One extra TextLabel per podium, RichText on one line, one
  counter row; WorldFeel/UIMotion budgets apply.
- **Rollback:** `Config.LuckyStart.Enabled=false` (no forcing, counter, Lucky tag or guard;
  saved counts kept), `Config.LuckyStart.Guard=false`, `Config.Discovery.NewTag/Advice=false`,
  `FavoredRolls={rolls=5, chance=0.6, species="Duck"}`. The saved `luckyStart` field is
  additive and ignored when disabled.

## 8. Files touched and interfaces

| File | Owner | Change |
|---|---|---|
| `src/server/LuckyStart.luau` | WS4 (new) | pity state, draw, record, guard, counter text |
| `src/shared/IndexProgress.luau` | WS4 (new) | Index found/total rule |
| `src/server/RollService.luau` | **WS4 writes** (shared with WS2) | species selection, precedence, guard, offer `new`/`lucky`, Buy `firstFind` receipt |
| `src/server/RollStation.luau` | **WS4 writes** (shared with WS2) | NEW tag, advice line, Lucky counter row, `RollLucky` attribute |
| `src/shared/Config.luau` | shared (WS2, WS4, others) | WS4: `FavoredRolls` values, `LuckyStart`, `Discovery` blocks |
| `src/server/PlayerSession.luau` | shared | `luckyStart` new/save/load, `OfferAdvice`, snapshot field |
| `src/server/GameServer.luau` | shared (WS3) | `Roll(…, true)`, analytics counts |
| `src/server/AnalyticsSchema.luau` | shared | version 16 names (one bump for all WS) |
| `src/server/AnalyticsFunnels.luau` | shared | Roll funnel steps |
| `src/client/RollPresentationController.luau` | WS4 | NEW float, Rare cue, first-rarity celebrate, Lucky tag |
| `src/client/AppController.luau` | shared (WS3, WS5) | `TrackRecruit` first-find toast |
| `src/client/IndexBrowser.luau` | WS4 | use `IndexProgress.Count` |
| `tests/CommanderGuideChecks.luau` | WS4 | favoured-pulls assertion |
| `tests/LuckyStartChecks.luau` | WS4 (new) | checks above |
| `tools/sim/discovery_probe.luau` | WS4 (new) | probe |
| `docs/team/LUCKY_START_20261027.md`, `AGENTS.md`, `docs/team/COMMANDER_TUTORIAL.md` | WS4 | contract + short rule + favoured-pull note |

**Split with WS2 (RollService / RollStation / Config).** WS2 owns prices: `PetCatalog`
`EarlyPrices`/overrides, `Config.Economy.StarterLadder`, the `price=` expression in
`RollService:Roll`, the podium price row text, Roll Slot tier prices. WS4 owns which
species are offered (selection block, `favoredSpecies`, Lucky Start, guard), the offer's
`new`/`lucky` fields, the rarity and advice lines and the counter row. One writer per
file: WS2 lands its RollService/RollStation edits first (or hands the exact lines to WS4),
then WS4 applies on top. Config: each WS edits only its own keys.

**Asks of other workstreams**
- WS2: keep "rarer = better early deal" (Bee pays back faster than Rooster today); if
  non-basic Commons fall to ≤ ~500 Coins in session 1, tell WS4 to set
  `FavoredRolls.rolls = 0`. Optional: a "have / price" progress on unaffordable podium
  offers (price row is WS2's) — strongest for lucky offers.
- WS3: decide whether a failed Buy on `offer.lucky` opens the Coins pack.
- WS5: optional `Hud:PingIndex()`; a "Save for your Rare!" tip can read
  `state.luckyStart` and the lucky offer on `state.offers`; order it against the Rebirth 0
  tip; Index button visibility after the tutorial.
- WS1: guaranteed chickens raise Army power early (Uncommon 30 vs Chicken 13; Rare 38–60);
  include them in Fort Roost pacing assumptions.
- WS6: one extra billboard line and counter row per podium; no new per-frame work.
- WS7: "NEW!"/Index n/83 and the visible Rare countdown are good ad-expectation hooks
  ("unlock rare chickens fast").
- Analytics: all WS append under one Schema.Version 16 bump in a single merge.
