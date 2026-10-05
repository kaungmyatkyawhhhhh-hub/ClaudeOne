# GYM ARC — Progress

Short and current (7 Oct 2026, after the overnight run). Full history: `git log -p -- PROGRESS.md`.

## Workflow (no Rojo)
- No Rojo. **Roblox Studio is the source of truth** (edit through the MCP connection); GitHub is a backup.
- After each piece of work: export the changed scripts into `src/` (`tools/export`), run the checks in CLAUDE.md,
  commit + push. **Save/publish the place in Studio** after every session (nothing here can save it for you).
- World areas are built once from recipes in `tools/builders` (see `tools/bake.md`), then edited as normal parts.

## First thing to do
1. **File > Save to Roblox.** The overnight run changed scripts, the whole map (gyms, town, terrain) and lighting in the
   open place; none of it is saved yet. (`src/` and `tools/builders` have everything if Studio crashed.)
2. Remove the Rojo plugin: Plugins > Manage Plugins (two versions installed, 7.4.4 and 7.7.1).
3. Play once on your own save, then once with Workspace `FreshPlayer` on. See "Check these" below.

## Done
- Player data, saving, 18 muscles, stamina, coins, genetics, height, titles; one reusable machine system.
- Clean minimal Theme UI; menu screen; tutorial; Coach Dex quests; Muscle of the Day; shakes; economy; social
  (spotting, arm wrestling, crews, emotes); legends; seasons; leaderboard wall; membership card; wardrobe.
- **Overnight, Session 1:** machines can be used again after Exit; mirror Day one/Now rigs fixed and the mirror glass
  reflects you; marble statue fixed; reps run on their own, tapping speeds them up and fills a PUMP meter (PUMPED = x2,
  8 s), BIG REP (x3, ~1 in 12), per-rep camera punch, level flash, NEW PR banner; always-visible Growth Spurt bar with a
  "next goal" line; body grows in clear steps with a "you grew" moment; 12 weight tiers per machine; Growth Spurts
  tuned to 8 / 15 / 25 / 35 / 45 minutes.
- **Session 2:** starter gym ~2x with zones and 18 machines; pro gym rebuilt next to it with real machines (weight
  stacks), lockers, podium, LEDs, behind a glass wall with a locked glass door (walk-in at Growth Spurt 2); real plate
  templates (number on the face) everywhere; 8 NPC regulars that walk to machines, lift, rest, drink, chat and yield
  to players; Coach Dex and legends idle and face players.
- **Session 3:** terrain everywhere (no baseplate/void), hills and trees around, sea to the horizon; main street with
  lamps and street props; plaza with fountain and string lights; ~20 detailed background buildings; gym exteriors
  (canopy, lit signs, street windows, pro glass front, roofs); smoothie bar and Gear & Fits rebuilt inside and out;
  beach, beach gym, posing stage, skate park (ramps work with the skateboard).
- **Session 4:** body map stats (front + back, 18 muscle shapes, brightness = level, gold outline = maxed, trained
  muscles pulse every rep, level + spurt bar under it, tap = full stats screen); compact icon menu (slim column on
  PC with hover labels, one Menu button on phones); layout zones (menu top left, Growth Spurt bar top center,
  quest + notifications top right, body map bottom left on PC / top left on touch screens, Lift button bottom
  right); checked on a small phone, a tablet and 1080p.

## In progress
- Nothing half-built.

## Waiting on you
- **Sound ids** (you pick them; all in `Config/Sounds.luau`). New placeholders that reuse other clips: `PumpFull`,
  `BigRep`, `PersonalRecord`, `Grew`. Older placeholders: `LevelUp`, `Maxed`, `TitleUnlocked`, `TierUnlocked`,
  `GeneticsClank`, `OutOfStamina`, `GeneticsThudLow`, `RepTick`/`Click`. No sound yet: skateboard rolling, sliding
  doors, store purchase, mirror opening. Area music only has Starter and Pro.
- **Badge ids:** Aesthetics God, Skyscraper, Defied Genetics have `badgeId = nil` in `Config/Titles.luau`.
- **Monetization ids** (stays off until you add them): 7 game passes, 3 products in `Config/Monetization.luau`.
- **DataStore name:** Studio saves to `"PlayerData_1"` (the repo once had `"PlayerData_xz"`). Kept; tell me if not.
- **Portrait:** phones/tablets are locked to landscape (`StarterGui.ScreenOrientation = LandscapeSensor`).

## Check these (things I couldn't fully verify)
- Phone **Menu button** (top left on phones): the emulator's mouse tool couldn't click it at that screen size, so open
  and close it once on a real phone or with your mouse in the Device Emulator.
- Lifting on **pro gym machines** as a Growth Spurt 2+ player (weight stack moving, poses) and walking through the
  unlocked glass door (my save is Growth Spurt 1; the locked door was tested).
- 2-player features (spotting, high fives, crews, arm wrestling vs a player) weren't retested.
- The new **XP numbers** (BaseXp 34, `20 + 2 × level`): play the first 8 minutes and see if it feels right.

## Known issues
- Spurts after ~11 get a few minutes longer each (the permanent bonus hits the 5x cap); fine for now.
- Big part count: town ~7,700 parts, gyms ~3,500. StreamingEnabled is on and small props don't collide or cast
  shadows, but test on a low-end phone; turn trees/buildings into MeshPart templates if it's slow.
- Cosmetic headbands can hide under big hair; ProximityPrompts only show when their part is on screen.
- The live mirror reflection shows your character and the room, not other players.

## Decisions made overnight
- NEW PR banner: the design file lists "personal-record popups" as cut, but the overnight prompt asked for a NEW PR
  banner, so it's in (a small banner, not a window). Easy to remove in `MachineClient` if you change your mind.
- Gold (#F2C14E) added to Theme, only for big moments (BIG REP, NEW PR, PUMPED, maxed outline).
- PUMPED and BIG REP multiply gains outside the 5x cap (they're earned by playing); shakes/genetics/spurt bonuses stay
  inside it. "Gain numbers": Minimal = set + BIG REP popups; NEW PR, level flash and "you grew" show in every mode.
- Muscles can go 30% past the Growth Spurt goal (`GrowthSpurts.CapOverGoal`) so a strong muscle helps its group.
- XP per level is `20 + 2 × level` (was `6 + level`, 3-4 levels per rep at the start); BaseXp 34.
- Tapping still fills the meter while resting; Auto Lift pass (off) just keeps tapping for you.
- Weight tiers renumbered (8 → 12); existing saves keep their tier number (a little lighter). Not migrated.
- One color per plate weight: 55 red, 45 blue, 35 yellow, 25 green, 10 white, 5 steel.
- Pro gym uses the same 12 tiers; its NPCs lift the top tiers so the glass view looks heavy.
- Cardio machines are recovery stations (`Stamina.Recovery.Cardio`), not a new training mechanic.
- Town footprint x -142..178 so the street runs past both gyms; `Config/Town` holds all positions.
- NPC hair/clothes: Roblox-made catalog items only (checked with GetProductInfo, creator "Roblox"); ids in
  `tools/builders/NPCs.luau`. **Creator Store: nothing inserted**; everything else is built from parts.
- Stats: the old world-space labels with lines are removed. The body map is bottom left on PC and top left on touch
  screens (the bottom left is the thumbstick there); on phones while lifting only the silhouettes show.
- Notifications stack just under the quest panel (top right) instead of in their own corner.
- Terrain: Roblox draws solid terrain ~2 studs above the filled height (water doesn't), so the Town builder fills 2
  studs low and clears everything above the ground under the gyms, streets and paving at the end.

## Pacing (how the Growth Spurt goals are set)
- Targets: `GrowthSpurts.Targets = { 8, 15, 25, 35, 45 }` minutes (1st, 2nd, 3rd, 4th, then every later one).
- `tests/pacing.luau` plays 60 simulated players through 8 spurts with the real configs. XP per rep = `BaseXp 34 ×
  tier gains × muscle share × min(genetics × spurt bonus × balanced × Muscle of the Day, 5) × quality ×
  1/(1 + level/50)`, quality = x2 while PUMPED, x3 on a BIG REP. 2.5 min of menu/tutorial before the first spurt.
- "Normal play with some tapping": half the sets tapped at 3 taps/s (1.05 s reps, 0.79 s PUMPED; the meter fills in
  ~5 s, then 8 s PUMPED), half on auto reps (1.05 s + 0.8 s gap); sets run until stamina is out, then a rest. About
  half of tapped reps end up PUMPED, so a tapped set gives ~1.5x an auto set; BIG REPs add ~17%.
- `lune run tests/pacing tune` solves each goal level: **15, 47, 72, 103, 135, 157, then +18**. Result (median
  minutes): 7.9, 14.6, 24.6, 34.7, 44.2, 44.2, 43.3, 43.7. The test fails if a spurt is more than 10% off.
