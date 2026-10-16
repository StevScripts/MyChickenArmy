# Timed yard builds (October 16, 2026, owner decision "Option A")

## Decision

Flock capacity is the mid-game brake, the way Mini War paces with build times.
The first two Flock Size expansions (25 → 30 → 35) stay instant so the first ten
minutes stay easy. From Flock 40 up, the player pays up front and builders take
real time; the new capacity applies when they finish. Rebirth cost and the King are
unchanged.

## Rules

- `UpgradeCatalog.PlotBuildSeconds[level]` is the build time for purchase `level`
  (0 = instant). Prices stay in `UpgradeCatalog.PlotPrices`.
- One build at a time. While building, the Flock Size offer has `unlocked=false`,
  `building={level,startedAt,finishAt}` (wall-clock seconds) and a requirement text.
- `UpgradeService:Buy` charges the price and saves `session.plotBuild =
  {level, startedAt, endsAt}`. `PlayerSession:CompletePlotBuild(now)` raises
  `plotSizeLevel` once `now >= endsAt`, and sets the banner. GameServer calls it every
  wall-clock second and `LoadData` calls it on join, so offline time counts.
- Rebirth keeps the yard (and any build in progress), as before.

## Save compatibility

`plotBuild` is additive and lenient. It is kept only when it targets
`plotSizeLevel + 1` with a numeric end time; anything else is ignored, never rejected.
Saved `plotSizeLevel` values are unchanged.

## Presentation

- Upgrades: the Flock Size hex shows "Building → N", a progress bar and the time left
  instead of a price; the card says how long builders take before buying.
- World: a "Builders at work · Flock N in m:ss" billboard over the owner's yard
  (`PlotUpgradeService:SetBuild`), removed when the build ends or the owner leaves.

## Numbers

Build times by purchase: 25→30 instant, 30→35 instant, 35→40 2 min, 40→45 5 min,
45→50 10 min, 50→75 25 min, 75→100 60 min. Prices are unchanged
($480 / $1,200 / $2,400 / $2,880 / $63,000 / $725,760 / $3,628,800): the simulation showed
the proposed raises ($6K … $120M) changed pacing by under 3%, because mid-game income
dwarfs them, so build time does the braking and the existing price rule stands.

## Checks run

`tests/ProgressionSimulation`, 3 seeds × 12 h, free player, buying the yard whenever the
flock is full and the price is affordable (median minutes):

| Milestone | Before | Timed builds |
|---|---|---|
| Income at 10 min | $228/s | $228/s |
| Income at 30 min | $14.7K/s | $14.0K/s |
| Income at 60 min | $495K/s | $171K/s |
| Flock 50 | 29 | 44 |
| Flock 75 | 30 | 69 |
| Flock 100 | 40 | 130 |
| Chicken King | 35 | 34 |
| Rebirth 1 | 53 | 53 |
| Rebirth 2 | 174 | 187 |
| Rebirth 3 | 278 | 292 |

Edit-mode checks: two instant buys, then a timed buy; a second buy is refused while
building; early completion is refused; save → load keeps an in-progress build, completes a
finished one, and ignores junk or mismatched builds without rejecting the profile.
Studio playtest: the hex showed "Building → 40" with timer and bar, the yard sign counted
down, and the yard grew when the build ended.

## Not done (needs owner approval)

Robux "Finish building" products and a 2x Build Speed pass would be new live
Creator Dashboard items; they were not created.
