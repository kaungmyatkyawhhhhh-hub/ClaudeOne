# GYM ARC (Roblox) - start here

Short on purpose: it is loaded every session. Read other files only when the task needs them.

## What to read, and when
- Game overview + status: Obsidian `C:\ObsidianOne\Claude+Obsidian\GYM ARC\00 GYM ARC Home.md` (the Index at its bottom lists every note).
- For a task, read ONLY the Feature / Bug / Config note(s) for that system (e.g. `Features\GYM ARC - Crews.md`). Never read the whole vault.
- `docs/DESIGN.md` (owner's full brief, big): read only the section you need, never the whole file.
- `PROGRESS.md`: never read it whole (it's very long). Search it (grep) for the section you need. Old entries go in `docs/PROGRESS_archive.md`; don't read that unless asked.
- The old long rules file is `docs/CLAUDE_full_old.md` (vault writing format, export, checks). Open it only when you need those details.
- If the owner says "do the prompt X", read `GYM ARC\Prompts\<X>.md` instead of asking them to paste it.

## Hard rules
- Studio is the source of truth (edit via MCP). No Rojo, never suggest it. GitHub `src/` is backup: export changed scripts (`tools/export`), commit, push.
- The owner also edits Studio by hand. Never undo or "fix" their changes; if something you planned conflicts with them, ask.
- After every task: remind the owner to File > Save to Roblox + Download a Copy to `Documents\GymArc_backups\GymArc_<date>.rbxl`.
- Kids' game, mostly phones: test 844x390 first, then 667x375, tablet, PC. Touch targets >= 44px, safe areas, nothing under the Roblox top bar.
- Server is authoritative; validate every remote. All data writes go through `PlayerData`.
- No emojis in UI. No real people, brands or copyrighted art. Grunts/screams ARE allowed.
- The owner picks sound IDs (or Claude picks only from Roblox's licensed library and lists them in the Sounds note).
- Never create passes/products/badges yourself; use only IDs the owner gives (list: vault `Monetization\GYM ARC - Monetization.md`).
- No growth spurt cooldown, no paid growth skips. Height cap 7'0".
- World geometry is built in Studio, not by game scripts (small runtime visuals are fine).
- Lighting: never set `Lighting.Technology`.
- Creator Store models: only trusted creators; delete every script inside them.

## UI (final kit: "BLACK + GOLD")
- Graphite panels, GothamBlack heavy italic titles, gold gradient (#FFF3C4 > #F6C75A > #C98A12), red only for the main CTA, teal for progress.
- One pulsing CTA per screen max. Owned = gold stamp. Use `Shared.UI.Theme` / `Shared.UI.Kit`, never hardcoded styles. UI is built in code.
- Chrome vs loud (owner, 23 Oct): chrome (anything you read, navigate or buy: menus, nav, HUD cards, pills, toasts) is quiet: dark graphite, thin dark outline, clean heavy italic labels, 10 px corners, no hex, no shine, no stroked chunky text, no gold borders (`Theme.SetChrome`). Loud (rarity colours, chunky stroked text, hex, glow) only on collectible tiles, roll reveals, evolutions and claim / equip / wear buttons. Gold = numbers, progress and ONE highlighted element per screen. Hex: ~18 px cells, panels 5%, collectible tiles 15-20%, else 0%, never on a child of a hexed parent.
- Top bar uses TopbarPlus. Left menu: vertically centered on the left, collapsible. Right cards: below the top bar, collapsible.
- Screen layout (owner, prompt 53): top bar = coins / LVL / daily / settings; under it on the right = SKIP; top centre = the one toast lane (toasts queue, one at a time); bottom centre = GO TO / Coach Dex dialog / stamina; right side = machine controls (one width, even gaps); left = left nav. Nothing in the middle of the screen except the world marker. While the tutorial runs only the tutorial shows (plus coins, LVL, left nav, machine controls).
- SHOP is never locked (owner, 23 Oct).

## Bodies
- Muscle/body system: read `Features\GYM ARC - Muscles and Bodies.md` before touching anything body-related (the owner changed the body himself in Oct; the note may need updating first).
- Every EditableMesh change costs ~40 ms: change muscle meshes rarely.

## Saving work (keep it short)
- Owner's new prompt: save it to `GYM ARC\Prompts\YYYY-MM-DD GYM ARC Prompt - <title>.md` first.
- When done: update only the notes for what changed (Feature/Bug/Config + today's Progress note + Home status), add new notes to the Index, commit the vault's `GYM ARC/` folder only. Never touch other games in the vault.
- Keep reports to the owner short and in plain English; list only what changed, what to test, and what needs his decision.
