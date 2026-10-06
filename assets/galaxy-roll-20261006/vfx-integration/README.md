# Galaxy lineup VFX integration — October 6

Copied the user's authored effects from `Workspace.GalaxyCratePreview` into the five existing `ReplicatedStorage.PetRoll.ChickenAssets` gameplay templates. The current mesh, texture, rig, flight and attack data remain on those templates. Their `VFXRevision` is `GalaxyLineup20261006`.

| Source display | Runtime species | Imported effects |
| --- | --- | --- |
| Astronaut | Astronaut | 5 particle emitters |
| Alien | Alien | 3 particle emitters |
| Galaxy | StormDuck | 6 particle emitters |
| DarkMatter | DarkMatter | 4 particle emitters |
| DragonChickenFlight | CosmicDragon | 11 particle emitters, 10 beams, 1 light |

Source particle/beam properties matched between Edit and the server before Play stopped. The client differed only by tiny replicated attachment rotation precision. Effects were copied as intact subtrees, preserving internal beam attachment references. The dragon's pasted `Central` beam carrier was located hundreds of studs away; its gameplay copy now sits at its mesh attachment and is noncolliding and massless. The existing factory attaches it to the moving shell. Normal chickens need no new carrier Parts.

`GalaxyDragonPetView` now records authored enabled states and disables effects for client ownership, matching `BlenderPetView`. `DuckAnimator` gives the dragon a `SpecialChickenVFX` owner. That owner uses `DragonChickenMesh` and only the imported effects, retaining the native dragon animator and material. Existing hide, defeat, reduced-motion, distance-culling and cleanup behavior applies.

Recovery copies are in `ServerStorage.GalaxyCrateVFXIntegration20261006.Before` and `.SourceLineup`. `integrate.luau` records the one-time asset operation and refuses to overwrite that recovery folder. Templates are Studio-owned assets; a scripts-only build does not contain this integration.

Five isolated physical models were created through the real factory without granting profile rewards. All imported effects enabled on the client. Each model moved approximately 7 studs; the dragon carrier stayed centered and every beam endpoint remained inside its model. Hidden, defeated, reduced-motion and distant states disabled all effects; restoring visibility reenabled them. Native FlightLoop continued playing. The temporary models were removed and the camera restored. See `verification.json`.

Saved locally in `assets/plot-parity-20261006/MyChickenArmy-Six-Matching-Plots-20261006.rbxl`. No experience publication, paid purchase or persistent player-data write occurred.
