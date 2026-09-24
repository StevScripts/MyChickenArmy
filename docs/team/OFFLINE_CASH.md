# Offline cash — September 24, 2026

Owner: current root task. User scope: research comparable Roblox games, balance
offline cash only, design the return screen in Figma, implement. No offline eggs,
chickens, battles, purchases or publication.

Compact receipt follow-up: user approved Figma node 359:3508 and requested its
implementation. This task owns client/OfflineCashController and its receipt art
and documentation. UITheme remains read-only; use its generated full-sheet stud
image. AppController, UITheme and the receipt controller matched Studio before
editing. Recovery copies are in assets/offline-cash/compact-ui/. Focused visual
checks use session-only Studio and synthetic receipts, without awarding money.

Compact follow-up status: layout and receipt behavior implemented and locally
synced. Creation, mouse Continue, duplicate/zero receipts, cleanup and large
amount fitting pass. Exact Figma saved-check PNG/SVG are on disk; Roblox import
is pending because native Studio clicks return noWindowsAvailable. Its URI is
empty pending import. User was asked to unlock the Mac. Studio is Edit, no
playtest left running. Only this receipt controller and bounded docs were edited.

Writable runtime files: shared/OfflineCashConfig and Config (revision only);
server/OfflineCash, DataService and PlayerSession (offline state/snapshot only);
client/OfflineCashController and AppController (lifecycle hooks only). Paths are
under src/. Read-only dependencies: Rules, PetCatalog, EggProcessor, existing
UITheme and commerce. Preserve all pre-existing uncommitted edits.

Contract: data.offlineCash={at,rate}; server-calculated rate includes verified
production/cash benefits once and seller throughput. DataService consumes the
old interval and persists the wallet before exposing a playable loaded session.
state.offlineCash is a transient, already-paid receipt for a dismissible UI.
No claim remote. Existing egg balances are untouched.

Before editing: canonical Pet Roll Test 96683186622050, instance:k48-cgv, Edit.
Five relevant current sources exactly matched disk. Recovery:
assets/offline-cash/source-baseline.json. Rojo already serves localhost:34872.
Focused checks will use fake profiles/store/clock in Studio Edit; no real data.

Completed: server implementation, editable desktop/compact Figma board,
seven-game sourced research and balance tables. Fourteen fake-store/economy
groups pass; Rojo build and exact seven-source Studio compile/readback pass.
Desktop render, loaded cash art, Continue dismissal, no reopening and corrected
wallet-ceiling text fitting confirmed. Keyboard/gamepad and mobile interaction
not fully verified. Studio is Edit; source and Studio controls released. See
docs/OFFLINE_CASH.md and assets/offline-cash/check-results.json. This task did not
Save/Publish Roblox or commit/push Git; concurrent commit 4a8991b already included
the first implementation, which was preserved. Final text/input corrections and
documentation remain local changes.
