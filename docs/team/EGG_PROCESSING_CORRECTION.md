# Egg processing correction — September 27, 2026

Owner: Balance egg quantity and value (`01a0dc10-c6bd-7662-8fe8-6a2bf3ea0710`).
The user explicitly rejected instant sales. Preserve the fantasy of increasing
egg quantities and buying substantial processor-capacity upgrades. Their current
design question is whether that progression works without rebirth; do not silently
introduce a reset system or call the existing four upgrades a complete economy.

## Applied correction

- Kept rarity/level-based eggs/sec, one shared upgrade-defined egg value, exact
  stack counts and bounded visuals from the quantity implementation.
- Restored the saved queue, time-based processing, Selling Speed purchases,
  processor board controls, Finish Now and its original durable receipt behavior.
- Removed automatic seller retirement/refunds and 100,000-cash replacement logic.
  Existing levels, credits and batches remain intact on profile load.
- Restored the quantity-based offline rate capped by processor capacity.
- All plots use the queue; authored boards now exist on all six plots. The
  original board geometry, headline sizing, studs and deposit pads are retained.
- Preserved the newer movement-only cash collection rule and Studio purchase
  presets, as well as all unrelated merge/debug changes in commit 335d528.
- Fixed a reproduced one-coin rounding underpayment during partial uniform-value
  processing: 128 eggs at $4 now pay exactly $512. Mixed/legacy batch remainder
  still stays in the saved batch until processed; total value is conserved.

Rates remain 4 / 16 / 64 / 256 / 1,024 eggs/sec; prices remain
480 / 2,400 / 9,600 / 28,800. These restore the prior quantity baseline. Designing
the longer curve and its pacing is separate from reversing the unwanted behavior.
Available cash upgrades remain independent of camp, rank and rebirth.

## Evidence and boundaries

Seventeen focused Edit check groups passed against exact local/live source hashes:
the 32-species balance matrix, uniform values, high-volume bounded visuals,
manual/vacuum transfers, saved balances/credits, offline cap, all-six-plot queue
deposits, timed processing, upgraded rates and the retained cash-pad movement rule.
All 26 checked source modules compiled. Rojo packaging and whitespace checks passed.
Actual controller binding checks passed on temporary clones of all six authored
boards: 12 surfaces, owner-only balances, queue/rate labels, upgrade and Finish Now
routing to fake request handlers, and empty-queue disabling. Fixture clones were
removed afterward. This is a binding check, not a visual gameplay test.
The two existing OfflineCashConfig copies are byte-identical; no duplicate source
was overwritten through Studio. There was no Play session or real profile/checkout.

Fixtures, before-source recovery and hashes are in
`assets/egg-processing-correction-20260927/`. Source edits synced through Rojo.
Studio asset target: Pet Roll Test 96683186622050, instance:w6a-k5r, Edit.
The original board is recoverable in
`ServerStorage.EggProcessingCorrectionRecovery20260927.EggCollectionBoard`.
Nested Plot2–Plot6 copies bind through the existing authored-map path.
No Roblox Save/Publish, Git commit/push or live-profile changes were performed.
The source is on disk; board assets are in the open Studio Edit place.

## Design judgment

The production/processing loop can work with permanent progression. A processor
upgrade should create a useful period of spare capacity, and its cost must be
reachable at the player's current cash rate. A finite launch progression needs
a worthwhile destination; indefinitely extending play needs more meaningful goals
and content. Rebirth is one optional way to reuse progression, not a prerequisite
for this loop. Larger numerical increments alone do not establish good pacing.
