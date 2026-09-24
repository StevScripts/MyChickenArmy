# Rojo migration — September 24, 2026

## Result

The active script source of truth is now this repository, `/Users/stevin/Documents/Projects/MyChickenArmy`. The VS Code folder was empty before migration. Sources came from connected **Pet Roll Test**, place **96683186622050**, universe **10765467283**, in Edit mode at **2026-09-24T05:18:51Z**.

| Scope | Count | Treatment |
|---|---:|---|
| Active gameplay/presentation/animation scripts | 120 | Exact live-source export, default Rojo mapping |
| Existing test ModuleScripts | 21 | Preserved under tests; optional tests.project.json only |
| Recovery, library, plugin and editor scripts | 186 | Preserved under archive; no automatic sync |
| **Total Studio scripts** | **327** | Every source accounted for in source-manifest.json |

The default build contains 118 ModuleScripts, one Script and one LocalScript at their original Studio paths. Both bootstraps remain enabled with Legacy RunContext. No gameplay code was refactored, renamed, reformatted or rebalanced.

## Current Studio wins over old local files

Four entries differed from the previous source checkout: Progression (rank pools), HudController (navigation positioning), ChickenPortraits (one trailing newline), and Jockey clip data (full clip versus a local alias). Current Studio bytes are used. The previous copies are retained under `archive/previous-local/`, with diffs in `previous-local-differences.json`.

An additional previous-local recovery utility, RestorePlayableChickenAssets, was not present in live Studio. It is preserved offline in the same archive, not silently introduced into the game.

## Safety boundary

`default.project.json` is a partial scripts project. Workspace, StarterGui, authored models, mesh/texture libraries, remotes, service settings and backups are not taken over. Mapped containers use `$ignoreUnknownInstances: true`. `servePlaceIds` restricts sync to the canonical place. Existing non-source script children and unrelated Studio objects are not intentionally removed.

Rojo is a one-way source workflow. Stop competing Studio/MCP script writers before connecting. Future code work belongs in this repository; the old pet-roll-prototype sources are historical, not a second active source of truth.

## Verified

- All 327 files match the original live export by SHA-256.
- Default Rojo build has exactly the expected 120 script paths/classes and source bytes.
- Optional build has exactly 141 scripts, adding only the 21 historical checks.
- Both project mappings preserve unknown instances and omit Workspace/StarterGui.
- Source map generation and VS Code configuration parsing pass.
- A separate read-only reviewer independently checked source hashes, generated mappings, bootstrap settings and tooling configuration.
- Rojo 7.7.0 was downloaded from its official release with its published SHA-256 verified; project-local CLI, local Studio plugin and VS Code Luau LSP are installed. The Rojo VS Code extension was already installed.
- Local Rojo serving starts on localhost:34872. The test server is stopped after verification, so the VS Code Serve task can own that port.

No gameplay test suite was run: script bytes are unchanged. The Studio plugin has **not yet been connected**, and live editing has not been smoke-tested. Save/reopen Studio to load the new local plugin, run the VS Code **Rojo: Serve** task, and connect the plugin to **localhost:34872**. Inspect the first sync before accepting it.

## Recovery and save state

- Full raw Studio-source export: local ignored `.migration/studio-source.json` (contains sources/metadata, not map geometry).
- Every exported source is also retained as an ordinary file with its manifest/hash, suitable for Git history.
- Previous local checkpoint: `Documents/ChatGPT/RobloxGameIdeas/pet-roll-prototype/backups/team-20260924T051727981436Z-before-rojo-migration-20260924`. Its generated recovery place is not an exact full Studio backup.
- Local Git repository initialized on main; no GitHub remote created and nothing pushed.
- No Studio source/geometry mutations, Roblox Save/Publish, real purchases or player-data changes were performed by this migration.

`python3 tools/check_migration.py` is an original-snapshot check. After deliberate edits it is expected to report source drift; it is not the normal CI command for future changes. Use the Rojo build task to check future packaging, and focused gameplay checks for behavior.

## Documentation used

- [Rojo project format](https://rojo.space/docs/v7/project-format/): place allowlist, explicit mappings and unknown-instance preservation.
- [Rojo sync details](https://rojo.space/docs/v7/sync-details/): script naming, metadata and sync limitations.
- [Rojo installation](https://rojo.space/docs/v7/getting-started/installation/): CLI and Studio plugin setup.
- [Pinned Rojo 7.7.0 release](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0): binaries/checksums in tools/rojo-release.json.
