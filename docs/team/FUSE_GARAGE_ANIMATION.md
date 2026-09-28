# Fuse garage animation — September 27, 2026

Complete; ownership released. Follow-up scope: `server/MergeStand.luau` and related evidence/docs. The user clarified that fusion should happen inside the closed garage and only the resulting chicken should emerge. This supersedes the earlier incoming-three-chicken sequence. The sectional door, accepted UI and saved transaction contract remain.

Use bounded TweenService segments, runtime-only backing sections, inward storage beneath the roof and exact reset/cleanup. No per-frame animation loop or authored model replacement.

Implemented four articulated sections with inward quarter-turn and concealment under the header; reverse closing; staggered chicken entry; purple completion pulse. Actual runtime full-cycle, interruption and repeat checks passed. Original CFrames and visibility/collision/query/touch settings restored exactly; 24 temporary pieces and all cosmetic birds cleaned up. Both modules compiled and matched Rojo. Screenshots and checks are in `assets/fuse-garage-animation-20260927/`. Play stopped; Studio is in Edit. No inventory/profile transaction or publication.

Current sequence: closed-door charge → sectional opening → one confirmed upgraded chicken exits and holds outside → door closes behind it → cosmetic output fades. Uses the actual result's species/stars/level, with a doorway fit for large variants. No outside input chickens. Closed charge, single output, correct level, outward travel, level-10 fit and complete/interrupted/repeated cleanup passed in the actual runtime stand. Current evidence: `result-exiting.jpg`, `result-exit-checks.json`. MergeStand compiled and matched (8,305 bytes; polynomial hash 3089724103). Test Play stopped; Studio is in Edit.
