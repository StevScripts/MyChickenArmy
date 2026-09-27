# Disposable purchase and economy tests

In Studio, enable the workspace attribute `PetRollPlaytestSessionOnly` before
starting Play. It is already enabled in the current Pet Roll Test place.
Open **F8 → Studio Test Tools** (also reachable through Settings).

| Control | Current-session behavior |
| --- | --- |
| Ignore all owned passes | Disables every paid pass benefit while retaining test progress. |
| Use my account's passes again | Restores Roblox-verified ownership for this session. |
| Fresh free player | Starting $2,400, three starter chickens, no paid benefits or consumables. |
| Fresh low spend | Same fresh start with only 2x Egg Spawn. |
| Fresh cash pack | Same fresh start plus one $10,000 Pocket Cash grant, no passes. |
| Fresh all enabled passes | Fresh start with all eight currently enabled passes, no cash packs. |
| Fresh all items | All enabled passes plus one of each enabled cash pack: $11,112,400 starting cash total. |

Fresh presets replace the disposable flock, coins, upgrades and route progress.
They clear crate/retired-product credits and restore the normal automatic-toggle
defaults. They retain receipt acknowledgements. Each fresh click restarts the
preset instead of accumulating another grant.

No Robux is spent. Native checkout is blocked in disposable Studio sessions.
These controls never alter actual Roblox ownership, load or write a real profile,
or serialize an entitlement override. Stop Play to discard the test. A new Play
session starts with account ownership again until a preset is selected. For a
free-player run, select the fresh free preset before measuring.

Disabled Auto Merge, paid crates and retired Finish Processing are not enabled
by “all items.” Consumable cash already spent cannot meaningfully be subtracted
from arbitrary progress; use a **fresh** preset to remove product-funded progress.
“Ignore passes” deliberately keeps the current flock and coins.

An active purchase preset also suppresses the separate `TestEggVacuum` bypass,
so free mode stays free even if that older Studio attribute is enabled.
Double Luck still follows the actual account's verified paid-random policy.

Server owners: `CommerceService` applies effective benefits separately from
verified ownership; `DebugService` creates disposable starts; `GameServer`
passes its commerce owner to the debug service. The F8 rows reuse AppController's
existing themed controls. Ordinary player progression and prices are unchanged.
