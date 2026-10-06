# GYM ARC — Progress

Short and current (7 Oct 2026, after the fixes + muscles run). Full history: `git log -p -- PROGRESS.md`.

## Workflow (no Rojo)
- No Rojo. **Roblox Studio is the source of truth** (edit through the MCP connection); GitHub is a backup.
- After each piece of work: export the changed scripts into `src/` (`tools/export`), run the checks in CLAUDE.md,
  commit + push. **Save/publish the place in Studio** after every session (nothing here can save it for you).
- World areas are built once from recipes in `tools/builders` (see `tools/bake.md`), then edited as normal parts.

## First thing to do
1. **File > Save to Roblox.** This run rebuilt the town, the beach gym, lighting and many scripts in the open place;
   none of it is saved yet. (`src/` and `tools/builders` have everything if Studio crashed.)
2. Play once on your own save (gym look, muscles), then Settings > Clothes > My avatar, then once with Workspace
   `FreshPlayer` on (small body, beach sign says "Opens at Growth Spurt 1"). See "Check these" below.

## Done
- Player data, saving, 18 muscles, stamina, coins, genetics, height, titles; one reusable machine system.
- Clean minimal Theme UI; menu; tutorial; Coach Dex quests; Muscle of the Day; shakes; economy; social; legends;
  seasons; leaderboard wall; membership card; wardrobe; pump/BIG REP lifting; 12 weight tiers; Growth Spurt pacing.
- Gyms: starter gym (2x, zones, 18 machines), pro gym behind a glass door (Growth Spurt 2), real plates, 8 NPC regulars.
- **Town (7 Oct):** 4-lane Main Street, two avenues, Beach Road, side streets, open plaza with clock post, park
  (fountain, paths, playground, picnic tables), parking lot with cars, sports court, ~30 detailed buildings, smoothie
  bar, Gear & Fits, beach, skate park, posing stage, all linked by sidewalks and boardwalks. Calmer afternoon lighting;
  outdoor lamps off by day, glowing at night (`NightLightService`).
- **Beach gym (7 Oct):** ~3x bigger, open air: 2 pergolas + shade sails over 9 beach machines (3 of each), free weights,
  calisthenics, tires/ropes/sled, entrance arch, rope fence, flags. Area signs show the lock line only while locked.
- **HUD (7 Oct):** no Lift button (tap anywhere / click / Space), slim pump bar above the machine panel with PUMPED
  timer and glow, one-time "Tap to pump" hint; body map with real proportions in the right column (folds to a
  "Stats" chip), training highlight always clears; small Skate button; readable Growth Spurt "Next" line; phone,
  tablet and 1080p layouts with nothing on the thumbstick or jump button.
- **Visible muscles (7 Oct):** everyone plays on one smooth Roblox-made base body ("Roblox 2.0" parts) with their own
  head, face, hair, accessories and skin color. Gym look (default): original tank top + shorts in one of 7 colors
  (picked from the UserId). 18 muscles are rounded shapes on the body (pecs, 3 delt heads, biceps, triceps, forearms,
  traps, lats, rhomboids, lower back, 2x3 abs, obliques, glutes, quads, hamstrings, calves), each sized by its own
  level in 6 steps toward the Growth Spurt goal; width growth is now tiny (no more block). Veins in 3 stages on
  forearms, biceps, triceps, front delts, calves (and abs/obliques when uncovered), stronger while PUMPED, pattern
  from the UserId. Settings > Clothes > My avatar keeps the avatar's own clothes. Same system on the mirror (Day one
  small, Now real), the live reflection, the marble statue (carved veins) and the NPCs (pro big + veins, starter
  medium). Growth Spurt resets the muscles and veins (height stays).

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
- **Muscles on a real phone with many players:** each body is ~45 parts at level 0 and ~110-140 maxed (veins only
  build within 90 studs). Fine in Studio; check frame rate on a low-end phone in a full server.
- **"My avatar" clothes with other avatars:** tested with your avatar (classic shirt + pants: the covered muscles stay
  hidden under the clothes and the torso/limbs thicken instead). Layered-clothing jackets/sweaters may clip a little
  over big shoulders; try a couple of avatars.
- **Emotes and the skateboard with muscles on:** the shapes are welded, so they follow every pose (checked lifting);
  give a flex emote and a skate a quick look.
- Phone **Menu button**: open and close it once on a real phone (the emulator's mouse tool can't click it there).
- Lifting on **pro gym machines** as a Growth Spurt 2+ player, and walking through the unlocked glass door.
- 2-player features (spotting, high fives, crews, arm wrestling vs a player) weren't retested.

## Known issues
- Spurts after ~11 get a few minutes longer each (the permanent bonus hits the 5x cap); fine for now.
- Part count: town ~16,100, gyms ~3,500, plus ~110 per strong player. StreamingEnabled is on; small props don't
  collide or cast shadows. If phones struggle: MeshPart templates for windows/trees, or fewer vein strands.
- Your avatar's shirt has no known main color, so with "My avatar" the chest/back/ab shapes are hidden (the torso
  just gets thicker). Shirts don't expose a color in Roblox; the gym look shows the full muscles.
- Cosmetic headbands can hide under big hair; ProximityPrompts only show when their part is on screen.
- The live mirror reflection shows your character and the room, not other players.

## Decisions made (fixes + muscles run)
- Base body: Roblox's own "Roblox 2.0" body parts (creator Roblox, checked with GetProductInfo), with classic
  proportions (body type 0). No Creator Store models were inserted.
- Gym look is the default for everyone (tank top + shorts colors picked from the UserId: 7 tops, 4 shorts). Shirts,
  pants, t-shirt graphics and layered clothing are removed in the gym look; hair, hats, face and neck accessories stay.
- Muscle size: 6 visible steps per muscle per Growth Spurt (step 0 = small/flat, mostly inside the body). Whole-body
  width/depth growth went from +25/30% to +6%, part thickening from 42% to 10% (or 32% under "My avatar" clothes).
- Veins: stages at 70% / 90% / 100% of the level cap (not the goal), so they only show on really strong muscles; thin
  (0.026-0.036 studs), low contrast, max 9 parts per muscle side and 90 per body; PUMPED makes them 25% thicker and a
  bit darker. Abs/obliques never show veins in the gym look (they're under the tank top).
- "Keep my avatar clothes": shirts cover torso and arms, pants cover hips and legs (classic clothing paints whole limbs).
- Statue: the strongest lifter is shown with every muscle maxed and full carved veins (their exact levels aren't
  loaded while they're offline).
- NPCs: pro regulars at the top step with stage-2 veins, starter regulars at step 3, no veins.
- No day/night cycle exists, so the lamps are simply off now; they switch on automatically if the clock ever passes
  18:00 (a future night event or a day cycle needs no extra work).
- Portrait: the game stays locked to landscape (in the emulator's portrait mode the screen stays landscape).
- Phones: the body map sits beside the quest panel (only ~200 px above the jump button); corner notes go top left
  (narrow, max 2, 1 while lifting); the machine panel is left-aligned while lifting.
- Skate button only shows when you're not lifting.
- Beach gym: racks, benches and pull-up bars there are normal starter machines (open to everyone); the 9 cable machines
  are the beach machines (Growth Spurt 1). Dip bars, monkey bars, rings, tires, ropes and the sled are decoration.
- Town parts went from ~7,700 to ~16,100; windows slimmed to 4 parts, fewer flowers/palm rings.

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
