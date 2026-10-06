# ClaudeOne — Roblox game

## How this repo is used
- The game is **GYM ARC**, built in Roblox Studio on the owner's PC. The owner's design brief is `docs/DESIGN.md`
  (imported below; build exactly what it says, follow its working style). Build history and open items:
  `PROGRESS.md` (keep it short and current). Code map: `docs/GAME_OVERVIEW.md`.
- No Rojo. Studio is the source of truth (edit through the MCP connection). GitHub is backup only (export changed
  scripts to src/). Never suggest or set up Rojo.
- After each finished piece of work, export the changed scripts from Studio into `src/` (`tools/export`, see below),
  then commit + push with a clear message.
- After any big change, remind the owner to **save/publish the place** in Studio. Never assume it's saved.
- Cloud sessions can't reach Studio: they can only edit `src/`, and the owner must copy those changes into Studio.
  Say so clearly.
- **UI style is "clean minimal"** (described in `docs/DESIGN.md`): dark see-through panels, thin light borders,
  Montserrat, white/gray text, color only for plates, grades and rarity. `ReplicatedStorage.Shared.UI.Theme` is the
  source of truth for the look: use Theme helpers, never hardcoded styles. StarterGui is empty; all UI is built in
  code from Theme. All data writes go through `PlayerData`.
- Monetization stays OFF (no gamepasses/products/badges created). No emojis in UI, no grunt sounds, no real
  people/brands/copyrighted art. The owner picks sound IDs; never pick new ones.
- Lighting: `Lighting.Technology` no longer exists; never set it. Use `LightingStyle = Realistic` and
  `PrioritizeLightingQuality = true` (already set in the place).
- `export/GymArc.rbxlx` is an old place snapshot (4 Oct 2026), kept as a backup.

## Layout of `src/` (mirrors the Explorer)
- `src/ServerScriptService` (`Main.server.luau` + `Server/` modules), `src/ReplicatedStorage/Shared` (Config, UI,
  Audio, ClientData), `src/StarterPlayer/StarterPlayerScripts` (`*.client.luau`).
- File suffix = script type: `.server.luau` Script, `.client.luau` LocalScript, `.luau` ModuleScript.
- `ReplicatedStorage.Remotes` is built in Studio; a new remote is created by its owning service at Start.
- Export: run `tools/export/receive.ps1` (localhost receiver), turn on HttpService, run `tools/export/Export.luau`
  in Studio's command bar (or via MCP), turn HttpService off again. Delete files in `src/` whose script no longer
  exists in Studio.

## Checks (run on the exported `src/` before every push)
- `lune run tests/run_all` (logic tests, see `tests/README.md`).
- Compile every script: `luau-compile --null <file>`.
- Roblox type analysis (only lint warnings expected): `luau-lsp analyze --platform roblox
  --defs @roblox=globalTypes.None.d.luau src`. Without a sourcemap, `require` paths aren't resolved, so
  cross-module types show as `any`; that's expected.
- Play in Studio and read Output: no new errors or warnings.
- New server services go in `Main.server.luau`'s OPTIONAL_SERVICES list (started in protected calls).

## Conventions
- Luau, `.luau` extension. Use `--!strict` where practical.
- Server is authoritative: validate every RemoteEvent/RemoteFunction argument on the server.
- Get services with `game:GetService(...)`.
- Keep the owner's PROGRESS.md / task notes up to date if they add them.
- Gain popups (owner's popup fix, see "Game feel" in the brief): one small "+12" per rep beside the chest (main
  muscle only, no name), never stacked (new replaces old); secondary muscles only flash the HUD muscle list; every
  10 reps one slightly bigger "Set done · +[total] Chest". Respect the player's "Gain numbers" setting
  (On / Minimal = set popups only / Off), stored in `settings.gainNumbers`. Code: `gainPopup` in `MachineClient`.
- Stats is a window (see "Stats window" in the brief): nothing floats around the player in the world. The body viewer
  shows a clone of the local character in a ViewportFrame; labels and dots are 2D, placed from the viewport camera.
- World geometry is built in Studio, never by game scripts (owner's rule): services find Studio-built pieces by
  name and only wire them (prompts, doors, machines). New areas: write a builder in `tools/builders`, run it once in
  Studio to make the parts, save the place (see `tools/bake.md`). Small runtime-only visuals (gain popups, cosmetic
  gear on characters, the skateboard, visiting legends, plates on bars) are fine in code.
- Studio testing: Workspace attribute `FreshPlayer` (boolean) = play as a new player on unsaved temporary data;
  `ReplayTutorial` = replay the tutorial on your own save.

## Art direction (every build follows this)
Theme: sunny beach-side fitness town. Stylized-realistic, warm, clean, premium. Kids audience, so it should feel
bright and inviting, not dark and empty.
Banned "slop" signs (check every build against this list):
- Plain single-part boxes used as buildings, furniture or objects
- Flat untextured surfaces, default gray, everything the same material
- Floating parts, gaps, z-fighting, parts clipping through each other
- Big empty floors/walls with nothing on them
- Gray void or a flat baseplate edge visible anywhere
- Every object the same size and lined up in a perfect grid
- Signs that are just a text box stuck on a wall
Every object is made of several parts with real detail: trims, frames, bevels/edges, bases, small props. Reuse
well-made templates (one great lamp used 30 times) instead of many bad ones.
Creator Store: allowed ONLY for meshes/models made by Roblox or trusted creators that match the style. Delete ALL
scripts inside any inserted model (free models can contain backdoors) and list what you inserted in the report.
Performance: StreamingEnabled on, reasonable part counts, MeshParts for repeated detail, CastShadow off on small
props. Must still run smoothly on a phone.

@docs/DESIGN.md
