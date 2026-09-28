# Immediate egg sales — September 26, 2026

**REJECTED by the user September 27. Do not implement or rerun this plan.**
Processing and purchase behavior have been restored; no retirement payouts should
run. Current record: [EGG_PROCESSING_CORRECTION.md](EGG_PROCESSING_CORRECTION.md).
The remainder records the abandoned work, not the approved economy.

Owner: Balance egg quantity and value, `01a0dc10-c6bd-7662-8fe8-6a2bf3ea0710`.
User approved quantity production, shared egg value and immediate batch selling
on every plot, retiring Selling Speed and Finish Now while preserving purchases.

Files: EggService, EggProcessor, OfflineCash, PlayerSession retirement settlement,
ProductService legacy receipts, CommerceService and GameServer retired purchase
routing, ShopCatalog, EggProcessorConfig, EggProcessorController, related docs
and focused fixtures. Studio scope: existing seller board labels/controls and
copies at the corresponding deposit location for the remaining authored plots.
Keep all other dirty changes. No new prices, combat/merge changes or publishing.

Before sources matched all live copies in canonical Pet Roll Test 96683186622050,
instance:69i-u8j, Edit. EggProcessor has two identical copies; account for both
during integration. Snapshot: `/tmp/chicken-instant-eggs-20260926/before.json`.

Compatibility: retained selling levels refund the historical cash cost once.
Unused Finish Now credits and late undelivered receipts receive 100,000 cash
each; preserve pending compensation at the wallet ceiling. Existing delivered
receipt IDs stay acknowledged without another reward. No live profiles accessed.
