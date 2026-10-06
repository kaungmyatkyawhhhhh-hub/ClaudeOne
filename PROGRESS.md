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

## In progress: fixes + muscles run (from GYM_ARC_fixes_muscles_prompt.md)
- **Part 1 (playtest fixes): done**, committed as "Part 1: ...".
  - Lighting: calmer afternoon (Brightness 2, Exposure -0.15, softer Bloom, warmer haze, ColorCorrection not washed
    out). Street/wall/string/flood lights are tagged `NightLight`: frosted glass and off by day, glowing at night
    (`NightLightService`, switches at 18:00 / 6:00 ClockTime; the place stays at 14:30).
  - Town: Main Street 4 lanes (20 wide) with 6-stud sidewalks, two avenues to a new Beach Road, side streets behind the
    shops, open plaza (clock post, carts), park (fountain, paths, playground, picnic area), parking lot with cars,
    sports court, ~30 buildings with back/side windows, boardwalks linking the skate park, beach gym and stage.
    ~16,100 parts in Workspace.Town (StreamingEnabled on).
  - Beach gym ~3x: 3 shades (2 slatted pergolas + shade sails, roofs at 15 studs, non-colliding) over 9 beach
    machines (3 of each), free weights (2 squat racks, 2 benches), calisthenics (2 pull-up bars + decor), tires/ropes/
    sled on sand. Area signs (beach gym, pro gym door) show the lock line only while locked (`AreaSignsClient`).
  - No Lift button: tap anywhere / click / Space. Slim pump bar above the machine panel, "PUMPED 6s" + glow,
    one-time "Tap to pump" hint (saved in `settings.pumpHintSeen`).
  - Body map: real proportions, right side under the quest panel (beside it on phones), folds into a "Stats" chip;
    training highlight clears on exit / machine switch / respawn / death (all four tested).
  - Top bars: Skate is a small button (hidden while lifting), quest panel fits, "Next" line readable and wraps;
    phones: machine panel left-aligned while lifting, notes top-left. Checked on Galaxy A06, iPad 10th, 1080p.
- **Part 2 (visible muscles): next.**

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

## Decisions made (fixes + muscles run)
- No day/night cycle exists, so the lamps are simply off now; they switch on automatically if the clock ever passes
  18:00 (a future night event or a day cycle needs no extra work).
- Portrait: the game stays locked to landscape. In the emulator's portrait mode the screen stays 705x338 landscape,
  so there is no portrait layout to break.
- Phones have only ~200 px on the right above the jump button, so there the body map sits beside the quest panel
  (left of it, under the Growth Spurt bar) instead of under it; PC and tablets have it under the quest panel.
- Corner notes on phones go top left (narrow, wrapped, max 2; 1 while lifting) because the right side under the
  column is the jump button and the bottom is the machine panel.
- Skate button only shows when you're not lifting (you can't skate on a machine).
- The beach gym's free-weight racks/benches and pull-up bars are the normal starter machines (open to everyone); the
  9 cable machines are the beach machines (Growth Spurt 1). Dip bars, monkey bars, rings, tires, ropes and the sled
  are decoration you can't use yet.
- Town parts went from ~7,700 to ~16,100. Windows were slimmed (4 parts each) and flowers/palm rings reduced to keep it
  down; if phones struggle, the next step is MeshPart templates for windows and trees.

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
