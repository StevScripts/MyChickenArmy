# Upgrade eligibility — no camp prerequisites

Current user direction, 25 September 2026: **Players can keep buying available upgrades whenever they can afford them. No upgrade requires visiting, attacking, conquering or unlocking a camp, earning a conquest rank, or progressing toward the King.**

This supersedes older documents, research proposals, screenshots, fixtures and code that attach upgrade availability to `promotion`, `firstWins`, `frontierWins`, rank capacity caps or `RollSlotRanks`. Do not restore those restrictions when updating UI, balancing the economy, rebuilding a board, or implementing feedback.

## What is available

The following existing cash tracks are independent of camp progress from the start:

- Egg Speed: all four purchases, up to the current 1.60× production-speed factor before paid benefits.
- Egg Value: all four purchases, up to the current 2× value factor before paid benefits.
- Plot Size: all four purchases where the authored plot supports expansion, up to its current 120% width / 60-chicken capacity.
- Army Size: every configured purchase from three to ten base deployment slots. Bigger Army remains an additional five slots.
- Luck: all four existing purchases at their current prices.
- Roll Slots: all configured purchases up to six active podiums, capped by the number physically authored for the assigned plot.
- Selling Speed: retains its existing cash-only purchases and seller-board ownership/proximity rules.

The user removed **camp prerequisites**, not the configured maximum level of each track. This change does not invent infinite levels, new benefit curves, additional map space or more podiums. Future additions can extend a track without adding a conquest requirement.

## Checks that remain

Keep server authority over loaded/closing/save-lost state, sufficient cash, existing track maxima, valid expected level/price, board ownership and proximity, and actual plot/podium support. A missing authored capability is different from a camp requirement. UI must display the server's current offer and must not add a separate local rank lock.

Camp-route prerequisites, King access, rank milestones, existing combat encounters and rewards remain separate progression systems. Merging remains disabled for release; this change does not enable dormant merge/individual-level upgrades. Historical rank metadata in Progression is not an instruction to gate cash upgrades.

Existing levels, balances, chicken ownership, investments, entitlements and save schema are preserved. There is no migration or refund/reset requirement for removing these gates. High upgrade levels in a rank-one profile are valid.

## Runtime owners

- `server/PlayerSession.luau`: `NextSlot` and `GlobalUpgrade` expose available cash upgrades without rank checks; the snapshot reports the configured overall army capacity, not the old rank capacity. Rank banners no longer promise an army-slot unlock.
- `server/UpgradeService.luau`: board offers have no required-rank parameter or promotion check. Plot availability remains enforced.
- `shared/UpgradeCatalog.luau`: no `RollSlotRanks` field. Income reference bands used in fixed price calculations are tuning inputs, not eligibility requirements.
- `server/ArmyService.luau`: the rejected legacy promotion action no longer claims territories increase army capacity.
- Existing ArmyService, RollService, EggService and UI purchase paths consume these offers and preserve their remaining transaction safeguards.

## Scope and verification

Seven focused standalone Luau groups passed against the actual current modules with in-memory service/world boundaries: all board tracks at zero camp wins, legacy menu transactions, rank-independent offers/prices, insufficient-cash and stale-quote rejection, retained readiness/access/capability restrictions, rank-one save roundtrip at maximum upgrades, and additive paid army capacity.

Fixture: `assets/upgrade-no-camps-20260925/checks.luau`. It does not access Studio or real saved players. Historical test cases expecting rank-one income/army purchases to fail are superseded and must not drive a regression back to the old design. No broad historical suite was run.

This task did not operate Play/Stop. Updated source is confirmed in the Edit tree and takes effect in a fresh Play session; it does not replace already-required modules in an active session. Studio integration/recovery details are in [the task record](team/NO_CAMP_UPGRADE_GATES.md).
