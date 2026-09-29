 My Chicken Army!

The editable Luau code for **Pet Roll Test**, place **96683186622050**. Open this folder in VS Code. The original Studio map, chicken models and imported art stay in the existing place.

**Current upgrade rule:** available upgrades require cash, never camp visits, conquests or rank. Existing track maxima and authored plot limits remain. Read [UPGRADE_RULES.md](docs/UPGRADE_RULES.md); older rank-gated guidance is superseded.

## Start coding

1. Run **Terminal → Run Task → Rojo: Serve** in VS Code, or `python3 tools/rojo.py serve` in its terminal.
2. Open Pet Roll Test in Studio. In the Rojo plugin, connect to **localhost:34872** and review the code sync.
3. Edit a file under `src/` and save. Restart Play to try code that was already loaded.

Rojo 7.7.0 is pinned and installed into `.tools/`; the Python wrapper installs the same verified release on another machine. The Studio plugin is separate from the VS Code extension. If Rojo was just installed into Studio, reopen Studio after saving your place so the plugin loads.

| Folder | What you edit |
|---|---|
| `src/server/` | Battles, rolling purchases, eggs, profiles and server services |
| `src/client/` | UI, tweens, rolling presentation, local effects and input |
| `src/shared/` | Configuration, economy, chicken definitions and common helpers |
| `src/bootstraps/` | The existing server and client startup scripts |
| `src/animations/` | Exported chicken animation clip data |
| `tests/` | Existing optional checks; mapped only by `tests.project.json` |
| `archive/` | Backup/library/plugin scripts and preserved previous-local differences; normally outside sync; the explicit September 29 seller source backup is mapped into ServerStorage only |

Start with [where to edit each feature](docs/CODE_MAP.md), then [the editing and GitHub workflow](docs/EDITING.md).

## Important boundaries

- **Files → Studio:** Rojo is not a two-way backup. Export any manual Studio script edits before reconnecting.
- The project is restricted to Pet Roll Test and preserves unmapped Studio objects. Do not replace the map with a generated build.
- `python3 tools/rojo.py build` creates `build/MyChickenArmy-ScriptsOnly.rbxlx` for packaging checks. It intentionally lacks the authored map/models and is not a standalone playable game.
- `python3 tools/rojo.py sourcemap` updates editor navigation. Luau LSP and Rojo extensions are recommended in `.vscode/extensions.json`.
- Git stores code history. Saving/publishing the Roblox place is separate. No GitHub remote is configured by this migration.

## Migration

The live Studio export contains **327 scripts**: **120** in default sync, **21** optional test modules, and **186** archived/editor/library scripts. Sources were exported from the open place, not reconstructed from an old generated place. See [migration notes](docs/migration/README.md) and the exact path/hash manifest alongside them.

Rojo documentation: [existing-place migration](https://rojo.space/docs/v7/getting-started/existing-game/), [project mappings and preservation](https://rojo.space/docs/v7/project-format/).
