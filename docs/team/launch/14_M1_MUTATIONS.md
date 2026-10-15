# Worker M1: mutations

**Branch:** `launch/m1-mutations` · **Worktree:** `~/Documents/Projects/mca-m1` · **Plan:** [`../LAUNCH_CHANGE_PLAN.md`](../LAUNCH_CHANGE_PLAN.md) §9
**Needs the foundation?** Yes. Start after the lead commits it.
**Ships in:** publish 2 (tomorrow). Take the time to get the visuals right.

## Why

With Luck upgrades, Mythics stopped being rare: 3.6% of all offers (base 0.06%), and players bought 357 of them. Once a player owns the top tier, the chase is over. Mutations add a rare variant on top of any chicken that multiplies its eggs and looks special. Better mutations unlock with rebirth ranks, so they also give rebirth a payoff.

## Files you own (only these)

- `src/shared/MutationCatalog.luau` (the foundation stub; you replace the body)
- `src/client/SpecialChickenVFX.luau` (mutation visuals; read how it applies effects to chicken models first)
- `src/client/RollPresentationController.luau` (the mutation badge in the roll reveal)
- `src/client/ChickenBrowser.luau` (the mutation badge in My Army and the Index; the admin-panel chat edited this file, so pull a clean `main` first)
- `src/client/MergeBrowser.luau` (the badge in the Fuse picker and the "result keeps the best mutation" line)
- `tests/MutationChecks.luau` (new)
- `docs/team/launch/handoff/M1.md` (new)

The foundation already did the shared work: `pet.mutation` is saved and loaded (invalid ids are dropped, never rejected), `AddPet(species, stars, mutation)`, `PetIncome` and `DisplayedPetIncome` multiply by `MutationCatalog.Multiplier`, `OfflineCash.Rate` multiplies per pet, `RollService` sets `offers[slot].mutation = MutationCatalog.Roll(rng, rebirths)` and passes it to `AddPet` on buy, fusion sets `a.mutation = MutationCatalog.Best({a, b, c}) or a.mutation`, every pet in the snapshot carries `mutation`, and the analytics names `mutation.offer.<id>`, `mutation.buy.<id>` and `mutation.fuse.<id>` are registered. **Don't edit any of those files.** If recording `mutation.offer` or `mutation.buy` needs a call inside RollService, write a "Request for lead" with the exact line.

## The catalog (`MutationCatalog.luau`)

```lua
MutationCatalog.Order = {"Golden", "Rainbow", "Shadow", "Cosmic"}
MutationCatalog.Defs = {
	Golden  = {name = "Golden",  multiplier = 1.5, chance = 1/250,   unlockRank = 0},
	Rainbow = {name = "Rainbow", multiplier = 2,   chance = 1/800,   unlockRank = 1},
	Shadow  = {name = "Shadow",  multiplier = 3,   chance = 1/3000,  unlockRank = 3},
	Cosmic  = {name = "Cosmic",  multiplier = 5,   chance = 1/12000, unlockRank = 5},
}
```

October 14 owner retune: Golden was 1/40 (Rainbow 1/200, Shadow 1/1000, Cosmic 1/5000);
Golden should be "pretty rare, but not the rarest". The Golden mutation now uses the
Golden Emperor appearance's glitter emitters 1:1 (`SpecialChickenVFX._attachMutation`).

Functions (signatures are fixed; others rely on them):

- `IsValid(id): boolean`: true only for ids in `Defs`.
- `Multiplier(id): number`: the def's multiplier, or 1 for nil or unknown.
- `Roll(rng, rebirths): string?`: one draw with `rng:NextNumber()`. Check the **rarest unlocked mutation first** (Cosmic, then Shadow, Rainbow, Golden), each with its own chance. Return the first hit, or nil. Locked mutations are skipped. Use exactly one `NextNumber()` call per mutation check so tests are deterministic.
- `Best(pets): string?`: the highest multiplier among the pets' `mutation` fields, or nil.
- `Rank(id): number`: for sorting (0 for nil).

Rules that must hold:

- Mutations change **egg production only**, never combat. Don't touch any combat stat.
- Luck does not change mutation chances.
- Galaxy Crate rewards never carry a mutation. Confirm `CrateService` calls `AddPet` without a mutation; if it doesn't, write a request for the lead.
- The Halloween event chicken (H1) can roll a mutation like any offer. That's fine.

## Visuals

Each mutation needs a look that reads at a glance on a phone, layered on the existing chicken art without hiding it:

| Mutation | Look |
|---|---|
| Golden | Warm gold tint on the body plus a soft sparkle |
| Rainbow | Slowly cycling hue tint plus colored sparkles |
| Shadow | Darkened body plus a thin purple-black aura |
| Cosmic | A starfield shimmer plus small orbiting star particles |

- Apply them in `SpecialChickenVFX.luau` the same way existing special-chicken effects are attached. Respect the existing effect budget (`RareChickenVFX`/`SpecialChickenVFX` cap how many effects run) and the reduced-motion setting.
- Chickens near the camera, in the yard and in the army should show the effect. Distant ones can drop the particles and keep the tint.
- Giants scale the effect with their size.

**Badges** (a small rounded tag with the mutation name in its color):

- Roll reveal (`RollPresentationController.luau`): the badge pops in after the species reveal, with a short extra flash for Rainbow and above.
- My Army and Index (`ChickenBrowser.luau`): a badge on the card, and "Eggs ×1.5 (Golden)" in the inspector.
- Fuse picker (`MergeBrowser.luau`): a badge on each input. Under the result preview: "Keeps the best mutation: Rainbow".

## Tests (`tests/MutationChecks.luau`)

1. `IsValid`, `Multiplier` and `Rank` for every id, nil and an unknown id.
2. Over 200,000 seeded `Roll` calls at rank 5, each mutation's rate is within 15% of its chance; at rank 0 only Golden ever appears.
3. `Best` picks the highest multiplier; a nil input is fine.
4. With the foundation hooks: a Golden chicken's `PetIncome` is 1.5 times a plain one; the offline rate includes it.
5. Fusion of Golden + plain + Rainbow produces a Rainbow Giant.
6. Save round trip keeps a mutation; `"Nope"` loads as no mutation and the chicken still loads.
7. A crate chicken has no mutation.

## How the lead verifies

Run `MutationChecks`, `FoundationChecks` and `PersistenceChecks`. In a disposable playtest, temporarily raise `Golden.chance` to 1 (local edit, not committed), roll, and check the badge, the yard look, the income in the inspector and a fusion. Then on a phone emulator, check that the effects read and FPS holds.

## Handoff

Commit on your branch and write `docs/team/launch/handoff/M1.md`: files changed, the tests, how to force a mutation for testing, performance notes, and requests for the lead.
