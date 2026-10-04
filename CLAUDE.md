# ClaudeOne — Roblox game (Rojo project)

## How this repo is used
- The game is built in Roblox Studio on the owner's PC. Scripts in this repo
  are synced into Studio with Rojo (`default.project.json`).
- Cloud sessions **cannot** reach Roblox Studio: no playtesting, screenshots,
  or editing parts/UI built in Studio. Work only on code in `src/`, push it,
  and the owner pulls + syncs. Say clearly when something needs checking in Studio.
- Much of the game (UI, machines, existing scripts) may still live only in the
  Studio place, not in this repo. Don't assume missing code doesn't exist —
  ask, or write code that finds instances defensively (`WaitForChild`).

## Layout
- `src/server` → `ServerScriptService.RojoServer` (Scripts: `*.server.luau`)
- `src/client` → `StarterPlayer.StarterPlayerScripts.RojoClient` (LocalScripts: `*.client.luau`)
- `src/shared` → `ReplicatedStorage.RojoShared` (ModuleScripts: `*.luau`)

- The Studio place already has hand-made `ServerScriptService.Server`,
  `ReplicatedStorage.Shared` and `ReplicatedStorage.Remotes` folders (e.g. a
  `PlayerData` ModuleScript). They are NOT synced; never map Rojo onto those names,
  or a sync would delete their contents.
- Keep `rokit.toml`'s Rojo version equal to the owner's Rojo Studio plugin (7.7.1).

## Conventions
- Luau, `.luau` extension. Use `--!strict` where practical.
- Server is authoritative: validate every RemoteEvent/RemoteFunction argument on the server.
- Get services with `game:GetService(...)`.
- Keep the owner's PROGRESS.md / task notes up to date if they add them.
