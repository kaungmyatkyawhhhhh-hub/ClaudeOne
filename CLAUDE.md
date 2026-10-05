# ClaudeOne — Roblox game (Rojo project)

## How this repo is used
- The game is built in Roblox Studio on the owner's PC. Scripts in this repo
  are synced into Studio with Rojo (`default.project.json`).
- Cloud sessions **cannot** reach Roblox Studio: no playtesting, screenshots,
  or editing parts/UI built in Studio. Work only on code in `src/`, push it,
  and the owner pulls + syncs. Say clearly when something needs checking in Studio.
- The game is **GYM ARC**. The owner's design brief is `docs/DESIGN.md` (imported
  below; it was the local CLAUDE.md, build exactly what it says, follow its
  working style). Build history and open questions: `PROGRESS.md` (add an entry
  for every step you finish, same format). Code map: `docs/GAME_OVERVIEW.md`.
- **UI style is "clean minimal"** (described in `docs/DESIGN.md`): dark see-through
  panels, thin light borders, Montserrat, white/gray text, color only for plates,
  grades and rarity. `src/ReplicatedStorage/Shared/UI/Theme.luau` is the source of
  truth for the look: use Theme helpers, never hardcoded styles.
- **All game scripts live in `src/` and Rojo syncs them into Studio.** The repo
  is the source of truth for code: edit the files, never the scripts inside
  Studio (Rojo overwrites Studio-side script edits). Parts, models, lighting and
  `ReplicatedStorage.Remotes` are still built in Studio and are not in the repo.
- Local sessions (Claude Code on the owner's PC with the Roblox Studio tool):
  edit code in `src/` with `rojo serve` connected, and use Studio only to
  playtest and to build parts/models/UI-in-world. Commit and push code changes.
- `export/GymArc.rbxlx` is an old place snapshot (4 Oct 2026), kept as a backup.
- All UI is built in code from `ReplicatedStorage.Shared.UI.Theme`; StarterGui is
  empty. New UI must use Theme. All data writes go through `PlayerData`.

## Layout (`default.project.json`)
- `src/ServerScriptService` → `ServerScriptService` (`Main.server.luau` + `Server/` modules)
- `src/ReplicatedStorage/Shared` → `ReplicatedStorage.Shared` (Config, UI, Audio, ClientData)
- `src/StarterPlayerScripts` → `StarterPlayer.StarterPlayerScripts` (`*.client.luau`)
- File suffix = script type: `.server.luau` Script, `.client.luau` LocalScript, `.luau` ModuleScript.
- Rojo fully owns those three places: anything added there inside Studio is
  removed on the next sync. Add new scripts as files instead.
- `ReplicatedStorage.Remotes` is NOT synced (built in Studio). A new remote must
  be created in Studio by the owner, or created from code at server start.
- Keep `rokit.toml`'s Rojo version equal to the owner's Rojo Studio plugin (7.7.1).

## Checks (run before every push)
- `lune run tests/run_all` (logic tests, see `tests/README.md`).
- Compile every script: `luau-compile --null <file>` (Luau release `luau-ubuntu.zip`).
- Roblox type analysis: `rojo sourcemap default.project.json -o sourcemap.json`, then
  `luau-lsp analyze --platform roblox --sourcemap sourcemap.json --defs @roblox=globalTypes.None.d.luau src`
  (luau-lsp release + `scripts/globalTypes.None.d.luau` from its repo). Only lint warnings are expected.
- `rojo build . -o test.rbxl` must succeed.
- New server services go in `Main.server.luau`'s OPTIONAL_SERVICES list (started in protected calls).
- New remotes are created by the owning service at Start (Remotes is Studio-built and not synced).

## Conventions
- Luau, `.luau` extension. Use `--!strict` where practical.
- Server is authoritative: validate every RemoteEvent/RemoteFunction argument on the server.
- Get services with `game:GetService(...)`.
- Keep the owner's PROGRESS.md / task notes up to date if they add them.
- Gain popups (owner's popup fix, see "Game feel" in the brief): one small "+12" per rep beside the chest (main
  muscle only, no name), never stacked (new replaces old); secondary muscles only flash the HUD muscle list; every
  10 reps one slightly bigger "Set done · +[total] Chest". Respect the player's "Gain numbers" setting
  (On / Minimal = set popups only / Off), stored in `settings.gainNumbers`. Code: `gainPopup` in `MachineClient`.
- Stats labels must never disappear (owner's rule, see "Stats: live overlay" in the brief): label BillboardGuis
  are AlwaysOnTop, lines/dots are 2D; never hide or fade a label for walls, equipment or prompts (nudge it off a
  shown prompt instead). Test by walking behind the squat rack, the pull-up bar and a wall with Stats open.
- World geometry is built in Studio, never by game scripts (owner's rule): services find Studio-built pieces by
  name and only wire them (prompts, doors, machines). New areas: write a builder in `tools/builders`, run it once in
  Studio to make the parts, save the place (see `tools/bake.md`). Small runtime-only visuals (gain popups, cosmetic
  gear on characters, the skateboard, visiting legends, plates on bars) are fine in code.
- Studio testing: Workspace attribute `FreshPlayer` (boolean) = play as a new player on unsaved temporary data;
  `ReplayTutorial` = replay the tutorial on your own save.

@docs/DESIGN.md
