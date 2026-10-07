# Existing conquest flags — October 6, 2026

User request: show the conquering player's face on the existing authored flag
instead of generating another flag.

Implementation ownership: this task owns only `src/server/WorldBuilder.luau`,
the ArmyMarker lifecycle removal in `src/client/BattleController.luau`,
the two flag-presentation calls in `src/server/KingArena.luau`, and this contract
plus the flag paragraph in `CONQUEST_REFERENCE.md`. Other dirty work is preserved.

## Behavior

- Do not display the floating player portrait, crown or "My army" label above
  marching, fighting, holding or returning troops. BattleController no longer
  creates/feeds/steps ArmyMarkerController. Its historical module is retained
  inactive; saved cosmetic entitlements are untouched. The player's conquest
  portrait appears only on the base's authored flag after ownership is awarded.
- Commander Banner adds a gold frame and crown to that flag portrait. Its
  existing entitlement updates the decoration immediately while the base is
  owned; the shop description matches the new placement.
- Reuse `Flags` in all 18 authored camps and `Flag.ThroneFlag` in Chicken King.
  These inspected pennants each contain three thin-X cloth panels and a wooden
  pole/base. The largest panel carries a headshot on its Left and Right faces.
- Keep portrait proportions square and rotate each side upright for the authored
  panels' local-Z-up orientation. Surfaces remain occluded by normal world geometry.
- Tint cloth green while owned, preserve the pole/base, and restore original cloth
  colors on release. No authored geometry is moved, rebuilt or renamed.
- Keep the existing conquered/owner billboard. `OwnershipFlag` remains its internal
  container name, but no longer creates a `Pole` or `Flag` child.
- Use the authoritative conqueror UserId and Roblox's `AvatarHeadShot` thumbnail URI.
  Changing owners replaces the image immediately; unclaim removes both surfaces.
  There is no yielding thumbnail callback that can restore an old owner.
- Changes apply to disposable runtime scenery. The original map and earned home
  Operation banners are unchanged. If an authored flag is absent, camp ownership
  still shows its existing label without inventing replacement geometry.

Platform references: [thumbnail URIs](https://create.roblox.com/docs/projects/assets#rbxthumb)
and [SurfaceGui](https://create.roblox.com/docs/reference/engine/classes/SurfaceGui).

## Delivery status

The implementation is synced to Pet Roll Test (`96683186622050`). In a
session-only Studio playtest, an authored base flag showed the conqueror's
headshot, changed its Commander Banner trim when the entitlement changed, and
removed the portrait when ownership cleared. The playtest was stopped. Rojo
build and Studio source readback passed. No place save or publication was done.
