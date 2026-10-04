# Instant egg sales — September 29, 2026

Implemented; file and Studio ownership released. The latest user request explicitly
archives processing time, Selling Speed and Finish Now. It supersedes the
September 27 correction and September 28 throughput tuning. No rebirth added.

## Current behavior

- Owned deposit pads pay player bags immediately; vacuum unloads use the same
  atomic server payout. Original earned values and Double Cash apply once.
- Manual paid deposit receipts use the existing ActionFeedback deposit and Money
  particles/sound. October 3 correction: automatic vacuum deliveries do not trigger
  player deposit/cash particles, sound or a fallback toast. They retain their
  server payout, rover-local amount and unload animation. A three-second receipt
  history preserves player/vacuum deposits between snapshots; client deduplication
  prevents replayed effects.
- All six original boards, including their separate cash pads, were moved intact
  to `ServerStorage.EggProcessingArchive20260929.Boards.Plot1` through `Plot6`.
  The six original egg deposit pads stay in the map.
- `EggProcessorConfig.Enabled=false` disables seller upgrades, Finish Now checkout,
  board UI binding/listeners and the processing delay. Shop copy no longer promises
  extra selling speed. The old code remains gated for easy restoration.
- Saved queued values finish without delay and pay with saved ready cash when the
  player reaches their owned deposit pad. Stationary contact works. If the wallet
  cannot fit the whole payout, the bag/cargo/legacy balance stays intact.
- Seller levels and finish credits remain saved. No refunds or arbitrary cash
  compensation were introduced. ProductService keeps recognizing old Finish Now
  receipts and retains its durable delivery/replay handling. Instant deposits do
  not consume saved finish credits.
- New offline checkpoints use full owned production × unit value × verified cash
  benefit × existing 2% efficiency. Existing checkpoint rates and eight-hour cap
  remain unchanged.

## Recovery

`archive/egg-processing-20260929/src` contains 13 exact pre-change source copies;
`manifest.json` records their SHA-256 hashes. Rojo maps these inert ModuleScripts
into `ServerStorage.EggProcessingArchive20260929.Code`. No archive script runs.
Active serializers and legacy receipt handling stay in their original modules.

To restore, only when requested:

1. Set `src/shared/EggProcessorConfig.luau` → `Enabled = true` through Rojo.
2. In Studio Edit, run the reviewed `archive/egg-processing-20260929/restore-boards.luau`.
   It checks all six saved OriginalParent paths and refuses to overwrite a board.
3. Start a fresh session. Queues, Selling Speed, Finish Now, pad behavior and the
   offline seller cap use the preserved implementation and saved levels.
4. Save the Studio place separately. Publishing remains a separate action.

Do not copy whole archived integration files over newer work; they are reference
snapshots. The enable switch is the normal restore path. Any already-paid eggs
remain paid, and restoration does not reverse wallet earnings.

## Evidence and boundaries

11 isolated Edit checks pass in `assets/instant-egg-sales-20260929/checks.luau`:
all six plot deposits, ownership/proximity/session guards, whole wallet headroom,
vacuum conservation, legacy balances, preserved levels/credits, inactive checkout,
offline rate/checkpoints, receipt deduplication, board startup, existing Money
routing and re-enabling the timed queue. Fixtures use fake sessions/services.
Rojo packaging passes. No Play session, real player data, purchase, publish,
Git commit or push. Source changes sync through the existing Rojo connection.
Native save was unavailable while the user interacted with Studio; the authored
board relocation currently exists in the open Edit place and needs a place save.

Pre-existing AppController, OfflineCashController, UIMotion, RollPresentationController
and workbench VFX changes were preserved. The prior responsive-receipt additions
in OFFLINE_CASH.md were preserved. Two duplicate copies of this task's new archive
were created during Rojo map synchronization; their 13 source copies matched and
were consolidated into one archive with the six original boards.

## Historical rejected September 26 implementation

The record below remains historical. The September 29 change above does not restore
its automatic refunds or cash compensation.

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
