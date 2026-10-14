# Worker H1: Halloween event

**Branch:** `launch/h1-halloween` · **Worktree:** `~/Documents/Projects/mca-h1` · **Plan:** [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §8
**Needs the foundation?** Yes. Start after the lead commits it.
**Ships in:** publish 2, and it must be live before **October 31, 2026**. It also needs a Pumpkin Chicken model the owner makes in Studio. If the owner says no model is possible by about Oct 22, stop and tell the lead.

## Why

Every game in this week's Top Trending and Top Playing rows has a pumpkin in its title or icon. A small limited event gives players a reason to log in this week and needs no new systems.

## Files you own (only these)

- `src/server/EventService.luau` (the foundation stub; you replace the body)
- `src/shared/PetCatalog.luau` (add one species)
- The client file that shows roll odds. Search for where odds are displayed (`ResearchBrowser.luau` or `ProgressionBrowser.luau`). You own **that one file**. Don't take `ResearchExtras.luau` (worker O1) or `ChickenBrowser.luau` (worker M1).
- `tools/map/MapDecor.luau` (pumpkin props)
- `tests/EventChecks.luau` (new)
- `docs/team/launch/handoff/H1.md` (new)

The foundation already added `Config.Event = {Enabled = false, Id = "Halloween2026", StartsAt = 0, EndsAt = 0, Species = "Pumpkin", OfferChance = 0.02}` and the RollService hook `species = EventService.MaybeReplace(session, species, rng, slot, now)` (never on the starter roll or a forced slot 1), plus the analytics names `event.offer.<id>` and `event.buy.<id>`. **Don't edit `Config`, `RollService` or other frozen files.** Put the real dates in your handoff as a "Request for lead": `StartsAt` is publish 2, `EndsAt = 1793491200` (2026-11-01 00:00 UTC). Confirm that timestamp yourself.

## 1. The species (`PetCatalog.luau`)

Add `Pumpkin`, modeled on the existing Epic entries that use `baseSpecies` (look at `Knight`, display "Magma Chicken"):

```lua
Pumpkin = {name = "Pumpkin Chicken", baseSpecies = "Knight", rarity = "Epic", weight = 0,
	limited = "Halloween2026", -- copy price, income, hp, damage, interval and size from Knight's band
	color = {255, 140, 26}},
```

- `weight = 0` keeps it out of normal odds, the same way crate-only chickens work. Check how weight-0 entries are kept out of `Rules.Draw` and the odds tables, and confirm that holds for this one.
- If `PetCatalog.Order` is used for the Index, add `Pumpkin` at the end of the Epic group. The Index must not break for players who don't own it.
- **Save safety:** adding a species is safe. If it is ever removed, the existing `unrecognizedPets` path keeps the raw save entry.

## 2. Event logic (`EventService.luau`)

```lua
EventService.Active(now): boolean
	-- Config.Event.Enabled and StartsAt <= now < EndsAt
EventService.MaybeReplace(session, species, rng, slot, now): string
	-- when Active: if rng:NextNumber() < OfferChance then return Config.Event.Species
	-- otherwise return species unchanged; never touches rng when inactive
```

Use exactly one `rng:NextNumber()` per call while active, so seeded tests are stable. Record `event.offer.Pumpkin` when it replaces. If `EventService` has no analytics handle, return a flag and write a request for the lead to record it in RollService.

## 3. Odds display

While the event is active, add one line to the odds view: **"Pumpkin Chicken (event): 2% per podium"**, in the Epic color, with "Limited until Nov 1". When inactive, show nothing. Paid and normal odds must stay correct; you only add a line.

## 4. Decor (`tools/map/MapDecor.luau`)

`MapDecor.luau` is a Studio command-bar script, not Rojo-synced; the lead runs it in Studio. Add:

- A blocky pumpkin prop to the prop kit, in the same voxel style as the existing props: orange body, darker ribs, green stem, an optional carved face with a warm `PointLight`.
- A `HALLOWEEN = true` option that scatters about 40 pumpkins near plots, camps and roads, using the same placement helpers, and stays clear of roads, plots, camps and the King arena like the other props.
- A separate `Decor_Halloween` folder, so the lead can delete it after the event without touching normal decor.

## 5. Model

You can't make the model, and the owner can't sync it from a worktree. In your handoff, write the exact spec for the owner: rig = the Knight (Magma Chicken) rig, an orange body, a carved pumpkin head piece replacing the comb, a green leaf stem, and the black silhouette stroke rule from `UI_EDITING.md`. Name it so it matches whatever rig lookup the catalog uses for `baseSpecies` variants. Find that lookup and name the expected path.

## Tests (`tests/EventChecks.luau`)

1. Inactive (disabled, before start, after end): 10,000 rolls never produce `Pumpkin`, and `rng` is not advanced.
2. Active: about 2% of replaced slots across 50,000 seeded calls (within 15%).
3. Starter and forced slots are never replaced (this checks the foundation hook; if it fails, report it).
4. `Pumpkin` never appears in normal odds tables or `Rules.Draw`.
5. A saved Pumpkin Chicken loads and saves after the event ends.

## How the lead verifies

Run `EventChecks`. Set `Config.Event` to active with a past start and future end locally, roll in a disposable playtest until a Pumpkin Chicken appears (or temporarily set `OfferChance = 1`), check the odds line, buy it, and see the model. Run `MapDecor` with `HALLOWEEN = true` and look at the map.

## Handoff

Commit on your branch and write `docs/team/launch/handoff/H1.md`: files changed, the Config dates request, the model spec for the owner, how to run the decor, and how to turn the event off.
