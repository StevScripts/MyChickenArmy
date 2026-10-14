# Giant chicken fusion

## October 14 redesign (current rules)

Owner request: Giants felt pointless (every fusion made one, size did nothing, and
re-fusing a Giant was just another merge). Research: Pet Simulator 99 (10 copies make a
Golden, 10 Goldens a Rainbow, about +50% stronger), Merge a Mini Army (merging gives more
health, damage and income), Grow a Garden (rare heavy hatches have stronger abilities),
Bee Swarm Simulator (rare Gifted bees give a hive-wide bonus), Adopt Me (Neon is mostly
cosmetic plus trade value). Without trading, a special variant needs a real gameplay payoff.

| Rule | Value (`src/shared/GiantChicken.luau`) |
|---|---|
| Normal fusion | three matching chickens → one, +1 level, normal size |
| Giant chance | `BaseChance` 10% + `ChancePerLevel` 2% × input level (Lv1 12%, Lv5 20%, Lv9 28%) |
| Guarantee | the `PityLimit` (8th) fusion in a row without a Giant; saved `giantPity` (additive, junk reads 0) |
| Giant input | at least one Giant input → the result is a Giant (size ≥ largest input); guarantee unchanged |
| Three Giants | `ColossalFromGiantsChance` 25% → Colossal (20–27.5 studs, biased to 20), otherwise a Giant |
| Colossal input | stays Colossal |
| Giant combat | ×2 health, ×1.5 damage, stomp (splash) via `Rules.Stats(..., giantSize)`; power and Select Best include it |
| Colossal aura | +10% damage for every chicken on its side while it stands (`Battle:ApplyResearch`); still one Colossal per army |
| Sizes | ordinary Giants use the rarity bands below without the old fresh-Colossal tail |

Existing saved Giants keep their size and get the new perks. Fuse screen shows the odds and
the guarantee ("12% Giant chance · guaranteed in 3", "Stays a Giant", "3 Giants · 25% Colossal
chance"); the Army inspector shows "GIANT · ×2 HP ×1.5 dmg · stomp" or "COLOSSAL · army +10%
dmg". Analytics: `giant.fuse.<Fused|NewGiant|Giant|NewColossal|Colossal>`. Checks:
`tests/GiantChecks.luau`.

The sections below are the September 28 history (guaranteed Giants, size-only), kept for context.

Implemented September 28, 2026. Current size contract alongside
[MERGING.md](../MERGING.md); supersedes the earlier design-only note and
separate Giant-acquisition chance. Later September 28 feedback adds a cash fee
and smaller starting Giants; this supersedes the original 6-stud minimum and
full-range Common rolls.
Latest September 28 clarification makes 20+ stud Colossals rare and limits them
to one per player's army. Smaller Giants are not subject to that special cap.

## Guaranteed result and bounds

Every successful fusion of three matching chickens produces one Giant of the
same species and stars, one level higher. Existing recipe eligibility, merge
level caps and transaction protections remain in force.

The current global range is **4–27.5 studs**, measured along the largest dimension of
the visible chicken body in its rest pose. Uniform scaling preserves proportions.
Particles, nameplates and motion outside the rest pose are excluded. This is a
world-space length, not a scale multiplier.

Studio references were read as MIN 6×6×6 and MAX 20×20×20. Later user corrections
keep the maximum at **27.5**, but request starting Giants near 1.5× normal, around
4–5 studs. The ordinary starter body measures about 2.48 studs; the new 4-stud
floor is approximately 1.6× that model. These are absolute body sizes, not a
universal 1.5× multiplier for every species or level. Authored guides remain untouched.

There is no separate Giant roll, ordinary-sized successful outcome, acquisition
pity, paid size luck or link to the existing Luck upgrade. Catalog rarity is
the input chickens' size luck. Matching species means all three inputs already
share that rarity.

## Initial tuning

`src/shared/GiantChicken.luau` owns bounds, distribution and validation.
After validating the transaction, the server draws one uniform random number
`u` in [0, 1] and calculates:

```text
if u < 1 − colossalChance:
    q = u / (1 − colossalChance)
    ordinaryMax = 19.9 for Legendary/Mythic, otherwise rarityMax
    rolled size = rarityMin + (ordinaryMax − rarityMin) × q^exponent
else:
    q = (u − (1 − colossalChance)) / colossalChance
    rolled size = 20 + (rarityMax − 20) × q^2
rolled size = round to 0.1 studs (rolled size)
saved size  = max(rolled size, largest valid Giant size among the three inputs)
```

The tail branch applies only when `colossalChance > 0`. The ordinary 19.9 cap
prevents rounding from accidentally turning a non-Colossal roll into 20 studs.

| Input rarity | Ordinary band | Ordinary exponent | Colossal chance and band | Approximate fresh-roll average |
| --- | ---: | ---: | ---: | ---: |
| Common | 4–6 studs | 2.0 | 0% | 4.7 studs |
| Uncommon | 4.5–8 studs | 1.8 | 0% | 5.8 studs |
| Rare | 6–12 studs | 1.6 | 0% | 8.3 studs |
| Epic | 8–17 studs | 1.4 | 0% | 11.8 studs |
| Legendary | 11–19.9 studs | 3.0 | 1%: 20–22 studs | 13.3 studs |
| Mythic | 15–19.9 studs | 3.0 | 3%: 20–27.5 studs | 16.4 studs |

These are initial implementation weights, not measured player-economy outcomes.
Neighboring bands overlap. Higher rarity shifts outcomes upward; the largest
fresh outcomes require Mythic inputs. Common inputs cannot roll enormous early
Giants. Higher rarity does not guarantee its band maximum.
Averages describe fresh rolls before rounding/inheritance, rounded here to 0.1.
The squared tail keeps even successful Colossal rolls near 20 more often than
the maximum. About 0.11% of fresh Mythic fusions reach 27+ studs after rounding.
These are starting design choices, not observed live-player rates.

Re-fusing Giants never shrinks the largest input, even if another input ID
survives because it is equipped. Size does not stack multiplicatively or exceed
27.5. Old large Common Giants remain valid and retain their size on re-fusion;
new band caps apply to fresh rolls, not earned sizes. Normal level growth does not multiply an already saved Giant size.
Equip, spawn and rejoin do not reroll it.

## One Colossal per army

`Giant.IsColossal` uses saved size **>= 20 studs**, regardless of species or
rarity. Every successful fusion still makes a Giant; only that extreme size
class has the special army limit. Players may own several Colossals, while
smaller Giants can fill any normal army slot.

`PlayerSession.FilterArmyIds` applies the one-Colossal rule to automatic and
manual selection, lineup construction, save serialization and load. Select
Best chooses the strongest available Colossal according to existing combat
power ranking and fills remaining slots with other chickens. An older saved
manual lineup keeps its first Colossal in lineup order and drops only excess
selection entries; no owned chickens or saved sizes are deleted or reduced.

`ArmyService` rejects a manual list containing two Colossals before any write.
Buying an extra army slot skips conflicting Colossal reserves. Fusion refreshes
selection through the same filter, so a newly enlarged output cannot leave two
Colossals equipped. Existing stale-selection protections remain in force.

The inventory labels Colossals and offers **Replace Colossal** when the slot is
occupied. That action replaces the existing Colossal directly, preserving other
slots. Dragging one onto a different occupied or empty slot is blocked with a
short explanation. `ArmyReinforcements` also enforces the limit for each battle
side: a new Colossal waits until the old one completes its normal return and is
removed, including when the old unit is dead or respawning. Rapidly reversing a
swap reuses the existing unit. Ordinary reinforcements are unaffected.

## Economy and persistence

Giant size is visual. Existing income/egg quantity and combat formulas remain:
income doubles per level, while base HP/damage gain 25% per level. Three inputs
still become one, retaining the user's saved merge tradeoff. No extra Giant
combat, income, capacity or hit-range bonus was added.

Fusion costs `ceil(Rules.RecruitPrice(species, inputLevel) × 0.25)` cash,
minimum $1. `Config.Economy.FusionRecruitFraction` owns the fraction;
`Rules.MergePrice` owns calculation. Level-1 fees: Chicken $600, Brown Chicken
$1,200, Camo $2,400, Robo-Cluck $4,200, Golden Emperor $40,200 and Galaxy Overlord
$72,000. Each input level doubles that species' fee. These are our initial
prices, not claimed prices from the reference game.

The fee is 8.33% of the trio's combined normal recruit cost. It adds a cash goal
without charging another full chicken on top of the consumed copies. Prices do
not depend on the player's wallet, income upgrades or luck. Earning time still
depends on seller throughput, collection and the rest of the flock; these checks
do not establish retention or economy balance.

Server recipes include price. Clients submit `expectedPrice`; missing, stale or
forged quotes reject before mutation. Cash and the exact trio are validated
before one non-yielding deduction/consumption. Batches validate all quotes and
the combined cost before charging. Failed/replayed requests do not charge.
The service fee is not added to refundable chicken investment. Existing resale
and investment rules otherwise remain unchanged. Auto Merge stays off.

`PlayerSession` stores optional per-chicken `giantSize` in saved profiles,
snapshots and army lineups. Battle units, reinforcements and actor recovery
carry it. Missing fields preserve old chickens as ordinary chickens; old
high-level birds are not retroactively converted. A subsequent successful
fusion makes the result Giant.

Loading validates finite sizes in [4, 27.5]. Invalid optional values cause
profile-load validation to fail instead of accepting corrupt sizes. This
additive field neither resets profiles nor advances the existing data revision.
The size roll and inventory mutation happen together on the server without
yielding. Clients display the authoritative result.

## World and UI

`ChickenGrowth` scales art while keeping the walking root and navigation height
at ordinary chicken dimensions. Visual joints keep the feet grounded. This
avoids a 27.5-stud collision shell or pathfinding agent blocking ordinary routes.

The purple fuse UI and portraits are retained. Ready state identifies the input
rarity's size luck and the selected trio's actual possible range, including
size inheritance. Eligible Legendary/Mythic previews show the Colossal chance;
inherited Colossals show a guaranteed Colossal range or their fixed size. Fuse
shows the exact cash fee; insufficient cash disables
submission and shows the missing amount plus total price. September 28 popup
behavior closes the GUI on server-confirmed fusion success so the world garage
reveal remains visible, with no automatic result popup. Inventory
cards and world nameplates identify Giants or Colossals, and their detail line
shows the saved size.

The garage reveals only the actual owned output chicken. It fits the doorway,
exits far enough to clear the machine, then grows to its saved size outside from
1.85–2.4 seconds. TweenService owns position, scaling and glow, through temporary
value objects where Model properties cannot be tweened directly. At 2.6 seconds
the same actor resumes normal Humanoid walking toward its yard. There is no
fade-out copy or home respawn. Normal animation is paused during the scale reveal
and resumes for walking. World roaming/snapshot updates defer while MergeStand
temporarily owns its pose; army handoffs and home commands release that control.
Reset, interruption and destruction remove tween drivers without destroying a
surviving owned chicken. Authored machine geometry remains unchanged.

## Validation and evidence

- Eight new `tests/GiantFusionChecks.luau` checks passed: all rarities,
  distribution endpoints/order, largest-input inheritance, compatible saves,
  rejected transactions, all 40 catalog appearances, grounded growth/recovery,
  and battle spawn/respawn/snapshots.
- All eight existing `tests/MergeStandChecks.luau` transaction checks passed.
- Real session-only UI fusion changed a four-chicken flock to two and displayed
  the retained level-2 chicken at **20.4 studs**, with existing stats.
- A 27.5-stud physical chicken moved 11.09 studs toward a goal 12 studs away
  during the short movement sample, without becoming blocked.
- The final garage fixture measured a 27.500004-stud extent (floating-point
  tolerance), with its lowest point matching the entry floor within 0.000002
  studs. Interrupted and repeated reveals cleaned up birds, tracks and drivers.
  An earlier joint-placement bug was fixed before these checks.
- Evidence: `assets/giant-fusion-20260928/`. Result/world screenshots record the
  20.4-stud transaction; final max-size reveal geometry is in `checks.json`.

These are focused disposable Studio checks, not a physical-device or multiplayer
soak test. No persistent player profile was changed and nothing was published.
All 13 changed runtime sources compile and match the Studio Edit copies through
Rojo, with one active copy each. The scripts-only packaging build passes. Play
was stopped; Studio is back in Edit. A byte-identical duplicate of the new module
created during sync was preserved outside the active tree in
`ServerStorage.GiantFusionDuplicateRecovery20260928`.


### Later September 28 pricing and smaller-Giant verification

The earlier 20.4-stud Common result above documents the superseded distribution.
The retuned implementation passed 35 checks: eight Giant checks, eight existing
transaction checks, six staging checks, five new fee/compatibility checks and
eight UI checks. Coverage includes exact/insufficient cash, malformed and stale
quotes, whole-batch atomicity, replay protection, old large Giants, range
preview, cash-shortfall UI and five layout sizes.

A real session-only UI flow showed `Fuse · $600` and `Common size luck · 4–6
studs`. It changed the flock 4→2 and wallet $2,400→$1,800, producing a saved
level-2 **4.5-stud Giant** with unchanged combat/income formulas. Evidence:
`priced-ready.jpg`, `priced-result.jpg`, `priced-checks.json` and
`priced-ui-checks.luau` in the folder above. Play stopped; Studio is in Edit.

### Latest September 28 Colossal verification

The earlier Legendary/Mythic distribution is superseded by the rare tail above.
All **35 focused checks** passed for this revision: eight Colossal army checks,
eight Giant checks, five fee checks, eight merge transaction checks, four client
inventory checks and two fuse odds/inheritance UI checks. The odds check samples
10,000 evenly spaced quantiles per rarity, finding exactly 100 Legendary and
300 Mythic Colossals; this verifies the formula, not a live random population.

Coverage includes the 19.9/20 boundary, highest-power Select Best, multiple
smaller Giants, atomic manual rejection, explicit replacement, old save
normalization without losing owned birds, fusion and capacity purchases,
attacker/defender handoffs, rapid swap reversals, and a dead retiring Colossal
respawning home before replacement. Finite-contest spent lives remain spent.
Client fixtures check Replace Colossal, blocked drag targets, ordinary Giant
equip, Colossal unequip, desktop/compact controls, actual saved-size labels,
fresh 1%/3% previews and guaranteed inherited Colossals.

The desktop inventory was visually inspected with disposable fixture chickens;
requests stayed in fixture memory. Evidence: `colossal-checks.json`,
`colossal-ui-checks.luau`, `colossal-fuse-ui-checks.luau`,
`colossal-inventory.jpg` and `colossal-source-sync.json` in the same asset folder.
All seven sources changed for this revision compile and match their single
active Studio Edit copy. Packaging and `git diff --check` pass. Fixtures were
removed and Play stopped. No publish or persistent player-data changes.
