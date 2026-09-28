# Selling Speed continuation — September 27, 2026

User direction: there should be no maximum egg-processing speed. The previous
processing-restoration task is complete/idle. Initial continuation owned
EggProcessorConfig, EggProcessor, EggService and the related policy/tests.
The approved price correction additionally updates CurrencyLimits, PlayerSession,
OfflineCash, ArmyService sale headroom, ProductService/CommerceService wallet
checks and EggProcessorController's unsupported-price caption.
No message was sent to another chat. Existing dirty changes are preserved.

The four opening purchases are unchanged. Later levels use a quadratic rate
curve: `1024 * (level - 3)^2`, starting at level 5. This gives increasingly large
absolute upgrades without exponential overflow at high levels. There is no
configured final Selling Speed tier. Finite exact-integer level validation is
retained for safe save data; it is not a gameplay goal or a MAX tier.

## Approved pricing correction

The user approved the researched capacity-adjusted exponential price on September
27. For current level >= 4, `n = level - 4` and next purchase price is
`ceil(86400 * (n + 1)^2 * 1.10^n)`, with sub-coin floating noise near exact integers
removed. First continuation quotes: $86,400 / $380,160 / $940,896.
`ContinuationBasePrice` and `PriceGrowth` in EggProcessorConfig own the tuning.
Opening prices and all processing rates stay unchanged. The previous 3x curve
and $1-trillion price plateau below are superseded, not valid tuning defaults.

The wallet now uses shared `CurrencyLimits.MaxCoins = 2^53 - 1` (about $9.007
quadrillion) across saves, offline cash, cash-pad claims, paid-pack eligibility
and receipt delivery. Existing numeric save shape is unchanged; old saves still
load. Lifetime earned counters saturate at that representation boundary, so
repeated spending/earning cannot invalidate a save. Normal credits refuse overflow;
egg-pad money remains ready, chicken sales validate headroom before deleting
chickens, and paid receipts remain pending until the exact grant fits.

**Remaining technical limit:** this is not arbitrary-precision money. The first
unrepresentable quote is at current level 164 (26,543,104 base eggs/sec). It is
disabled as `Currency limit`, not sold at a flattened price or shown as MAX SPEED.
A genuinely unbounded money representation is separate future work; do not claim
this implementation eliminates every numerical ceiling. Rates have no authored
final tier. Queue/count/value bounds remain at 1e12 and are separate from wallets.
OfflineCash uses CurrencyLimits; the old OfflineCashConfig.MaxCoins field is now
unused compatibility data (its duplicate Studio copies are left untouched).

No rebirth or income-dependent pricing. Larger prices still need gameplay pacing
observation; the arithmetic does not establish a balanced infinite economy.

The server purchase quote, saved-level reader, current/next rate and offline
capacity share the config helpers. Existing board UI receives a next offer
instead of entering MAX SPEED. Ownership/proximity, stale quotes, affordability,
queue processing, Finish Now and moving-only cash collection remain intact.

No save wipe, schema shape change, rebirth, production cap change or other
upgrade-track extension. Old levels 0–4 retain their exact rates and prices.

## Verification — initial continuation (historical)

Six continuation check groups passed in `tests/EggProcessorContinuationChecks.luau`:
opening tiers, 30 successive purchases past the old cap, rejected invalid
transactions, profile roundtrip/invalid levels, value conservation and offline
capacity. The 17 existing processing-correction check groups also passed. All
checks used fake sessions and source strings matching local hashes; no real
profiles, checkout, Play/Stop or module-cache reuse.

The three changed runtime modules compile and match their Rojo-synced sources
in Pet Roll Test (96683186622050, instance:w6a-k5r, Edit). Before-edit sources also
matched. The broad fixture source inventory encountered an unrelated divergent
PlotUpgradeService duplicate; it was left untouched. Tests selected only
source copies matching local hashes, not arbitrary same-named modules. This is
not a claim that unrelated duplicates or full live startup were verified.

Git whitespace checks passed. No Roblox save/publish or Git commit/push. The
skill-guided change preserves the local server/config ownership rather than
adding a second purchase or progression system. Fresh Play is required to pick
up these modules; no gameplay pacing or device-performance test was performed.

## Verification — approved price correction

Thirteen focused groups passed with exact disk/Studio source hashes and isolated
fake sessions/services. They cover exact quotes, compounding versus capacity,
no $1T plateau, repeated purchases, stale quotes, high-balance save/load,
invalid numbers, cash claims, offline headroom, exact paid grants/replays/deferred
overflow, protected chicken sales, all current species, saved high levels and
queue/value/Finish Now preservation. Fixture remains
`tests/EggProcessorContinuationChecks.luau`.

Sixteen of the seventeen historical processing-restoration checks passed. The
remaining check stops at its obsolete hardcoded 32-species count, now 40 after
the other task's approved additions. Its economy assertions were reproduced
over the current catalog in the passing focused check; the historical fixture
was not rewritten. A fixture-only Commerce mock initially lacked a connection
signal; it was corrected to exercise purchase preparation without connecting
any real Marketplace event. No runtime fix was needed for that fixture failure.

All nine changed/new runtime modules compile and match Studio Edit through Rojo.
Readback found two byte-identical CurrencyLimits copies created by the current
sync setup; both match disk and compile. They were not moved/deleted. Recheck both
if changing that module later, as with the pre-existing OfflineCashConfig copies.
Rojo packaging and Git whitespace checks also passed.
No mapped source was written through MCP. Existing queue/value limits and unrelated
species, animation, fusion and VFX work remain unchanged. Data/monetization skill
checks kept the numeric save shape and the existing receipt owner/replay behavior.
No actual saved players, receipts, checkout, Play/Stop, Roblox save/publish or Git
commit/push. This does not establish live-session or mobile visual correctness.
