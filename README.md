# ClaudeOne

GYM ARC, a Roblox game. **Roblox Studio is the source of truth** for scripts and builds; this repo is a backup.
After each piece of work, every changed script is exported from Studio into `src/` (see `tools/export`) and pushed.

## Layout (mirrors the Studio Explorer)

| Folder | In Studio |
|---|---|
| `src/ServerScriptService` | `ServerScriptService` (server scripts) |
| `src/ReplicatedStorage/Shared` | `ReplicatedStorage > Shared` (shared modules) |
| `src/StarterPlayer/StarterPlayerScripts` | `StarterPlayer > StarterPlayerScripts` (client scripts) |

File names give the script type: `Name.server.luau` Script, `Name.client.luau` LocalScript, `Name.luau` ModuleScript.

- `tools/export`: exports Studio scripts into `src/`.
- `tools/builders`: one-time recipes that built world areas in Studio (see `tools/bake.md`). Not run by the game.
- `tests`: logic tests for the config modules (`lune run tests/run_all`).
- `docs/DESIGN.md`: the design brief. `PROGRESS.md`: status and open items.
