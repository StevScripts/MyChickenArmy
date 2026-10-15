# Rebirth ladder: 50 ranks, no walls (October 15, 2026)

## Owner request

The owner asked for more Rebirths without the "million → billion → trillion" walls, and for
something "fun, but challenging" that stays maintainable.

The previous ladder had 20 ranks. Rebirth 1 cost $50M and Rebirth 2 cost $1T, a ×20,000 jump.
A fast simulated player took about 1.7 h to cross that gap.

## Rule

Everything lives in `Config.Rebirth` and is read by `RebirthService.Cost`.

- **Ranks:** `MaxRank = 50`.
- **Rebirth 1–20:** the `Costs` list.
  - Each rank costs at most ×3.6 the one before.
  - The step eases to ×1.15 by Rebirth 20.
  - The list runs $50M, $180M, $620M, $2B, $5.9B, $17B, $44B, $110B, $260B, $560B, $1.2T,
    $2.2T, $4.1T, $6.9T, $11T, $17T, $23T, $31T, $39T, $45T.
- **Rebirth 21+:** each rank costs `CostStep` ($7.5T) more than the last.
  - That gives $52.5T, $60T … $270T at Rebirth 50.
  - Late steps are ×1.17 falling to ×1.03.
  - The coin cap (2^53 ≈ $9,000T) is far away.
- **Unchanged:** Rebirth 1 still needs the King. Each rank still adds +100% egg cash and +100%
  camp/King strength. Mutation unlocks are unchanged.

To extend the ladder, raise `MaxRank`; new ranks follow `CostStep` automatically. To make the
late game slower or faster, change `CostStep`.

## Save compatibility

- Saved ranks are untouched.
- Every saved rank is ≤ 20, so all are still valid under the new `MaxRank`.
- `PlayerSession.readRebirths` still clamps any rank above `MaxRank` down to the highest rank.
  It never resets a rank to zero.

## How the costs were fitted

The fit used `tests/ProgressionSimulation` in a Studio Run session, with one seed.

1. **Fit pass.** A scratch copy took each rank when its run reached a target length: 25 min,
   rising to 75 min. The balance at that moment became the rank's cost.
2. **Smoothing.** Early ranks follow geometric steps with shrinking ratios. Late ranks follow
   the near-linear trend of the fit, about +$7.5T per rank.
3. **Verify pass.** The real sim ran with the fixed ladder.

Verify results:

| Player | R1 | R10 | R20 | R30 | R50 | Early run | Late run (R30+) |
|---|---|---|---|---|---|---|---|
| Fast (defaults) | 68 min | 2.9 h | 7.5 h | 16 h | 36 h | 10–14 min | ~60 min |
| Casual | 90 min | 3.9 h | 9.5 h | 20 h | 44 h | 14–19 min | ~72 min |

The casual player uses: roll every 16 s, deposit every 120 s, camp 135 s, King and missions
225 s.

The sim is idealized: continuous greedy play, every fight is won, and there is no walking. Real
players will be slower.

## Open item

Camps and the King scale ×(rank+1). In the sim, the King stops being a winnable fight between
Rebirth 20 and 30. Rebirths 2+ need only cash, so progression continues. However, camps and the
King may become unwinnable late in the ladder. Slowing enemy growth past Rebirth 20 is an owner
decision and has not been made.
