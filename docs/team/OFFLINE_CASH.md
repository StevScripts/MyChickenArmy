# Offline cash — September 24, 2026

Owner: current root task. User scope: research comparable Roblox games, balance
offline cash only, design the return screen in Figma, implement. No offline eggs,
chickens, battles, purchases or publication.

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
