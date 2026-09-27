# Egg quantity economy — September 26, 2026

Owner: Balance egg quantity and value, `01a0dc10-c6bd-7662-8fe8-6a2bf3ea0710`.
User authorized research, coordination with existing chats and implementation.

Implementation ownership (now released): Rules egg formulas; Config egg settings; EggService production;
PlayerSession production snapshots; OfflineCash rate; UpgradeService benefit text;
EggProcessorConfig throughput; EggView and EggController stack captions; narrow
AppController recruit/upgrade text; ArmyService recipe rate fields; MergeBrowser
rate row; ChickenBrowser home footer; related documentation and focused fixtures.
Preserve all existing dirty changes, especially AppController notification audio.
No autocollect-stand, combat, price, merge-rule, schema or live-profile edits.

Read-only coordination requested from the seller/collection and spawn/merge chats.
All inspected source copies matched disk before editing in canonical Pet Roll
Test, 96683186622050, instance:69i-u8j, Edit. Existing identical duplicates were
found for EggProcessorConfig, EggProcessor, OfflineCash and EggFeedback; integration
must account for every copy. Before sources: `/tmp/chicken-egg-quantity-20260926/before.json`.

Decision: shared base value $4, then $5/$6/$7/$8 with existing Egg Value levels.
Species and merge levels control quantity; speed/pass production boosts multiply
quantity. Preserve earned bag/queue/cash balances and paid receipt handling.
High quantities are represented by counted stacks with bounded world visuals.

## Completed

The seller/collection chat confirmed high-count batching and warned about legacy
earned-value preservation, offline quantity calculation and throughput. The
spawn/merge chat confirmed explicit eggs/sec fields and the approved three-input,
two-times-output tradeoff. The autocollect/audio chat released ownership and its
AppController Notify error-sound hook is preserved. Neither reviewing chat edited
files or Studio for this request.

Shared unit value, quantity-based production, rate snapshots and presentation are
implemented. Initial seller tiers are 4/16/64/256/1,024 with unchanged prices and
four upgrades. An optional preference question was sent; no response arrived
before proceeding with the stated recommended tuning. This is an implementation
choice, not a claim of explicit approval of those exact numbers.

Fourteen isolated Edit check groups passed; 22 sources compiled. One initial
fixture failure was a missing `suctionSerial` field in the fake vacuum, corrected
to match EggRover.new before the successful rerun. No gameplay source fix was
required by that fixture issue. Rojo build and Git whitespace checks passed.
Results and source hashes are under `assets/egg-quantity-20260926/`.

The existing Rojo connection synced all changed sources. The previously identical
duplicate EggProcessorConfig and OfflineCash copies became stale after sync;
both were moved intact to `ServerStorage.EggQuantityRecovery20260926`, with
OriginalPath attributes. Their synced copies remain in their original parents.
Readback confirms exactly one active copy of each, matching disk. No mapped
script source was written through MCP. Unchanged identical EggProcessor and
EggFeedback duplicates were not modified.

No Play/Stop, live-profile access, schema migration, checkout, asset upload,
Roblox Save/Publish, Git commit or push. Studio remains in Edit. A fresh Play is
needed for visual/perceptual review. The recovery folder is in the open Studio
place; Roblox saving is separate. Full contract and remaining seller/plot balance
limitations: [EGG_ECONOMY.md](../EGG_ECONOMY.md).
