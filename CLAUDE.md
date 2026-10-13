# ClaudeOne — Roblox game

## How this repo is used
- The game is **GYM ARC**, built in Roblox Studio on the owner's PC. The owner's design brief is `docs/DESIGN.md`
  (imported below; build exactly what it says, follow its working style). Build history and open items:
  `PROGRESS.md` (keep it short and current). Code map: `docs/GAME_OVERVIEW.md`.
- No Rojo. Studio is the source of truth (edit through the MCP connection). GitHub is backup only (export changed
  scripts to src/). Never suggest or set up Rojo.
- After each finished piece of work, export the changed scripts from Studio into `src/` (`tools/export`, see below),
  then commit + push with a clear message. Then update the Obsidian vault (see "Obsidian vault" below).
- After any big change, remind the owner to **save/publish the place** in Studio. Never assume it's saved.
- **After every task (owner's rule, 8 Oct): File > Save to Roblox, AND a dated backup copy** via File > Download a Copy
  (the cloud place has no "Save to File As") to `Documents\GymArc_backups\GymArc_<YYYY-MM-DD>.rbxl` (Documents is `C:\Users\kaung\OneDrive\Documents`; add `_2`,
  `_3` for more saves that day). Check the place's Version History (Creator Hub) shows the new version. The 8 Oct work
  was lost once because the place was never saved to Roblox.
- Cloud sessions can't reach Studio: they can only edit `src/`, and the owner must copy those changes into Studio.
  Say so clearly.
- **UI style: the owner's UI redesign** (13 Oct, `Downloads\GYM_ARC_UI_redesign.md` + the mockups; summary in
  `docs/DESIGN.md`): dark warm panels from 9-slice image pieces (`Config/UI`), red primary buttons, Oswald + Montserrat.
  `ReplicatedStorage.Shared.UI.Theme` (look) and `Shared.UI.Kit` (components) are the source of truth: use them, never
  hardcoded styles. StarterGui is empty; all UI is built in code. All data writes go through `PlayerData`.
- UI fonts: Oswald (titles, buttons, tabs, numbers; UPPERCASE titles / buttons) + Montserrat (body), per the redesign
  brief (`Shared.UI.UIFonts`).
- Monetization stays OFF (no gamepasses/products/badges created). No emojis in UI, no grunt sounds, no real
  people/brands/copyrighted art. Sound IDs (owner, 13 Oct: "pick audios for me"): Claude picks them, ONLY from Roblox's licensed
  library (creator ProSoundEffects for effects, APM Music for music; never user uploads), and lists every pick in
  `Config/Sounds` comments and the vault's Music and Sounds note so the owner can swap any.
- Lighting: `Lighting.Technology` no longer exists; never set it. Use `LightingStyle = Realistic` and
  `PrioritizeLightingQuality = true` (already set in the place).
- `export/GymArc.rbxlx` is an old place snapshot (4 Oct 2026), kept as a backup.

## Obsidian vault (owner's standing rule, 13 Oct): save everything there too
- Vault: `C:\ObsidianOne\Claude+Obsidian`. GYM ARC lives ONLY in its `GYM ARC\` folder. The vault also holds the owner's
  other games (Break A Bed, City Legends): never edit, move, rename or delete anything outside `GYM ARC\` (the one
  exception: the GYM ARC link line in `00-START-HERE.md`). Leave `.obsidian\` alone.
- The vault is a git repo synced by Obsidian Git (branch `master`, remote ProjectOne). After writing notes: commit only
  the `GYM ARC/` folder (`git add "GYM ARC"`) and push to `master`, per the vault's own `CLAUDE.md`.
- The vault is a copy: never move or delete anything from the repo or Downloads. Studio stays the source of truth,
  GitHub `src/` stays the backup.
- Layout of `GYM ARC\`: `00 GYM ARC Home.md` (what the game is, current status, what's next, open bugs, links);
  `Progress\` (one note per work session: `YYYY-MM-DD GYM ARC <short title>.md`); `Prompts\` (every prompt the owner
  sends, saved exactly as sent: `YYYY-MM-DD GYM ARC Prompt - <title>.md`); `Features\` (one note per system:
  `GYM ARC - <System>.md`, list in `GYM ARC - Features index`); `Bugs\` (one note per bug: `GYM ARC - Bug - <title>.md`,
  what happened / cause / fix / status open or fixed, list in `GYM ARC - Bugs index`); `Config\GYM ARC - Config values.md`
  (every tunable number and what it does); `Monetization\GYM ARC - Monetization.md` (the system + every pass / product: name,
  description, price, ID, status); `Sounds\GYM ARC - Music and Sounds.md` (the system + every SoundId / music slot,
  filled or empty); `Screenshots\` (copies of
  `screenshots/`, same file names); `Assets\GYM ARC - Assets.md` (meshes / textures / images with asset IDs).
- Writing: Markdown with frontmatter (`date`, `tags` with `gymarc` on everything plus `bug` / `feature` / `progress` /
  `prompt` etc., `status`). `[[wikilinks]]`; embed screenshots as `![[GYM ARC/Screenshots/<file>]]`. Note names must be
  unique across the whole vault (Break A Bed uses plain date names and "Settings", "Project Overview" ...), so every
  GYM ARC note name carries "GYM ARC". Short, plain English for a non-programmer, no emojis. Each note starts with
  "Back to [[00 GYM ARC Home|GYM ARC Home]]".
- When to save:
  - A new prompt from the owner: save it in `Prompts\` FIRST, then start working.
  - Every time PROGRESS.md is updated: write / update this session's Progress note plus the Feature, Bug, Config,
    Monetization and Sounds notes that changed; copy new screenshots into `Screenshots\`.
  - A morning report goes at the top of that day's Progress note too.
  - Keep `00 GYM ARC Home.md` up to date (status, next, open bugs).
- No duplicates, no dead links (owner, 13 Oct):
  - The "GYM ARC - Index" list at the bottom of `00 GYM ARC Home.md` names every GYM ARC note: it is the source of truth
    for names. Add each new note to it in the same edit; remove deleted ones.
  - Before creating a GYM ARC note, search the vault for an existing note on that topic (file names AND `aliases:` in
    frontmatter, e.g. `grep -ri "aliases:.*<word>"`). If one exists, update it instead of creating a new one. Planned
    parts of an existing system go in that system's note (a "Planned change" section), not a new note.
  - Only link to note names that exist (or create the note in the same step). Copy names exactly from the Index
    (case included). Aliases only help search, Obsidian still shows a link to an alias name as a missing note, so
    always link the real name.
  - When merging notes: keep one, move everything over (on disagreement the newer info wins, the old line goes under
    "History"), put the old names in the kept note's `aliases: [...]`, rewrite every link, then delete the duplicate.
  - Example `[[links]]` inside saved prompts go in a ```text block so they don't show as missing notes.
  - After writing notes, check: every `[[link]]` / `![[embed]]` in `GYM ARC\` must point to an existing file.

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
- Stats (see "Stats (final design)" in the brief): the Stats button toggles 2D labels around your character in the world
  (always visible, same size on screen, off by default); a Muscles button opens the full panel; on a machine a small
  body-map widget slides in. Never go back to a body-viewer window or a settings row for the labels.
- World geometry is built in Studio, never by game scripts (owner's rule): services find Studio-built pieces by
  name and only wire them (prompts, doors, machines). New areas: write a builder in `tools/builders`, run it once in
  Studio to make the parts, save the place (see `tools/bake.md`). Small runtime-only visuals (gain popups, cosmetic
  gear on characters, the skateboard, visiting legends, plates on bars) are fine in code.
- Bodies (see "Bodies and muscles" in the brief): everyone wears the Robloxian 2.0 body (`Config/Body`) and muscles are muscle v9 unified EditableMeshes (`MuscleRig`, only on your own character; everyone else wears the static body stage meshes, `Shared/BodyStages`, picked from their replicated look values) that wear the character's own Shirt/Pants and the skin texture stage (`Config/SkinStages`); never go back to blobs, per-player bodies, tiers or part scaling. Every EditableMesh change costs ~40 ms: change muscle meshes rarely (see "Performance" in the brief).
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
