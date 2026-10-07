# GYM ARC — Progress

Short and current (6 Oct 2026, after fix list 3). Full history: `git log -p -- PROGRESS.md`.

## Workflow (no Rojo)
- No Rojo. **Roblox Studio is the source of truth** (edit through the MCP connection); GitHub is a backup.
- After each piece of work: export the changed scripts into `src/` (`tools/export`), run the checks in CLAUDE.md,
  commit + push. **Save/publish the place in Studio** after every session (nothing here can save it for you).
- World areas are built once from recipes in `tools/builders` (see `tools/bake.md`), then edited as normal parts.

## First thing to do
1. **File > Save to Roblox.** Fix list 3 changed scripts and map parts in the open place; none of it is saved yet.
2. Fill in the muscle body ids when you've picked the bodies (guide below), then play once and check the tiers.

## Muscle v7 (7 Oct 2026): REAL growth, replaces blobs/pieces/tiers/thickness (all removed)
- **Bodies:** everyone wears the Robloxian 2.0 body (`Config/Body`, bundle 311) as before. Skin is a plain color (the uploaded skin_color/skin_roughness images are NOT used: see limits).
- **Muscles:** `muscle_v7/` (kept locally, git-ignored; 23 MB) -> `tools/gen_muscle_data.luau` -> `ReplicatedStorage/MuscleData` (137 ModuleScripts, 3.7 MB of numbers) -> `Shared/MuscleMeshes` (loads/merges) -> `Shared/MuscleRig` (builds EditableMesh MeshParts welded to the body parts, vertex = base + (max-base)*g, tween 0.4s, pump on every 10th level, PUMPED +4%, hidden under 2%) -> `StarterPlayerScripts/MuscleClient` (every client builds the muscles of the characters it sees, within ~100 studs). `BodyService` only publishes numbers as attributes (`MuscleG`, `Top`, `Shorts`, `SkinColor`). NPCs get a preset `MuscleG`, the statue a full-grown marble one. Progress mirror screen and the live glass reflection show the muscles too.
- **Limits found in Studio (important):** (1) a client may hold only **8 live EditableMeshes**, and a MeshPart renders nothing once its EditableMesh is destroyed, so each visible muscle mesh costs one of the 8. The muscles of a body part are merged into one mesh (max 20,000 triangles each), so a full body needs ~10. `MuscleRig` has an allocator: your own torso, arms, legs, back (6 meshes) first, then the rest to nearby characters/the statue; calves and forearms are skipped when the budget is short. If a published game allows more meshes everything is built automatically. (2) EditableMesh geometry made on the server does not replicate (clients see boxes), so it is built on each client. (3) SurfaceAppearance (skin texture) can't be used with vertex colors, so the muscles are plain skin color with vertex colors.
- **Not done:** snatched-waist torso meshes (they would cost 2 more EditableMeshes), the rock "mass monster" skin (levels never exceed the goal, and rock textures need uploading), a fallback with imported meshes (needs you to upload meshes_base / meshes_max; ask if you want it), phone test with 10+ players.
- Hover highlight in Stats now paints the hovered muscle's faces neon red (per muscle). Test hooks: Workspace attributes `TestMuscleShare`, `TestMuscleIds`, `TestOpenMirror` (FreshPlayer).
- Screenshots `muscles_v7_*.png`: level 0/15/35/70/max (front/back/side), only arms, only chest, statue, progress mirror, live mirror, lifting, highlight.
- Other work this session: beach gym NPCs, NPC fall-state fix, pro gym floor/lighting polish (`tools/builders/ProGymPolish.luau`), skating pose, statue marble body.

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
  timer and glow, one-time "Tap to pump" hint; small Skate button; readable Growth Spurt "Next" line; phone, tablet
  and 1080p layouts with nothing on the thumbstick or jump button.
- **Fix list 3, part 1:** the generated (Blender) muscle meshes, the stage-swap code, the base body, the gym look
  outfit and the 18 muscle shapes/veins are all gone. Players and NPCs are their normal avatars with their own clothes
  again (`tools/meshes/` stays on disk only, ignored by git; `ServerStorage.BodyStages` deleted).
- **Fix list 3, part 2:** muscle body tiers with Marketplace ids (replaced by the blob muscles in v4).
- **Stats, final design (6 Oct):** replaces the body-viewer window (v5, still in git history) and the old world labels.
  (1) The Stats button toggles compact labels around your character in the world (off by default): Strength + Stamina
  above the head, Chest/Core/Legs left and Shoulders/Back/Arms right, "Max" in soft gold, lines to dots on the body, same
  size on screen, steps off the "E / Use" prompt. (2) While they show, a "Muscles" button sits at the bottom center and
  opens the "Your muscles" panel (goal + six cards that fit, the rest of the HUD switched off, X / Esc / tap outside).
  (3) On a machine a small body-map widget slides in at the right (front + back silhouettes with proper proportions,
  muscles glow by level, trained ones pulse, "-" folds it to a chip) and slides away on exit; the highlight clears on
  exit, machine switch, death and respawn (each tested). Screenshots `stats_final_*.png`. Brief section 8 and the
  CLAUDE.md rule were rewritten again.
- **Fix list 3, part 4:** new menu. PC: no toggle; 64px square buttons with a line icon and a small label (Stats,
  Titles, Genetics, Emotes, Crew, Wardrobe, Settings), 8px gaps, vertically centered on the left edge below the top
  bar; if they don't fit the height they wrap into 2 columns. Hover = slight grow + brighter; press = 0.95. Phones:
  one "Menu" button top left opens a centered grid of the same tiles (tap outside or pick one to close).
- **Sauna (6 Oct):** a wooden beach sauna east of the beach gym (`Workspace.Town.Sauna`, builder `tools/builders/Sauna.luau`):
  stamina refills 3.5x faster inside (`Stamina.Recovery.Sauna`). Seats on two bench tiers, a stove with steam, a path to
  the boardwalk. Stepping into any recovery station (sauna, stretching areas, cardio) shows one small note.
- **Skateboard upgrades (6 Oct):** 5 deck designs and 3 sets of faster wheels (34 / 38 / 42 vs 30) sold at Gear & Fits
  next to the other gear (new cosmetic slots Board and Wheels), used from the Wardrobe; changing them while skating
  rebuilds the board.
- **Map polish (6 Oct):** parking lot: cars scaled to 85% so they sit inside the stall lines with a gap, 5 removed so the
  rows aren't a full grid (14 cars). Skate park: the empty concrete got painted floor plates (mint, sunny, coral), a
  manual pad, a kicker, a flat bar and painted ledge stripes (`tools/builders/SkateParkExtras.luau`).
  Beach gym shade sails rebuilt as two smooth triangles with tie ropes (the stepped strips read as a wire outline from
  far away; `tools/builders/BeachGymSails.luau`).
- **Quality pass (6 Oct, 2nd hour):** removed 3 leftover test rigs (`_RS0`, `_RS3`, `_RS5`, white Blender bodies) that
  stood in the road in front of the gym in the saved place. Gym front: a framed, lit tagline poster with a planter on
  the bare brick wall right of the entrance (`tools/builders/GymFrontPoster.luau`).
  Tutorial bug fixed: at Coach Dex's desk, E picked the desk's "Buy DNA token" prompt or the arm wrestling stool
  instead of "Talk", so the "find Coach Dex" step couldn't be done with E. The DNA token prompt is now F (gamepad Y),
  the arm wrestling prompts reach 4.5 studs (were 7) and Dex's 8 (was 10, the gym cat's Pet prompt is near). A
  whole-map scan finds no other spots where two different same-key prompts compete. Full new-player run checked:
  genetics, bench, stamina, shake, squat rack, stats, Coach Dex quest, no errors.
- **Glass entrance doors (6 Oct):** the starter gym's double doors (`Workspace.Gym.Entrance`, the two `DoorGlass`
  panels) are see-through glass now (Glass, Transparency 0.6, RGB 200/215/225, Reflectance 0.1, no shadow). Frame,
  divider and push bars unchanged; they still slide open (tag `SlidingDoor`, `SlideX`). It's the only door built from
  this template (shop doors were already glass, town building doors are single decorative panels).
- **Fix list 3, part 5 (map):** the park's fountain ring path (28 overlapping slabs) and its 4 straight paths are now one
  part (CSG) with one continuous paving texture; path edge strips stop at the ring and sit clearly above the paving.
  All 13 umbrellas (plaza carts, smoothie bar patio, beach) got a solid 8-panel canopy with a valance and ribs
  (the old one was 8 flat slats that overlapped in the middle and looked like spokes from below). A whole-map scan
  found 10,761 pairs of parts showing a face on the same plane in the same spot; 4 passes nudged ~10,500 parts apart
  by 0.04 studs (grown by 0.04 on both sides where both faces were shared). Biggest groups: building facades (rails,
  cornices, planters), street (curbs/asphalt/paving, lamps), skate park (fence, ramps), starter gym shell (slabs,
  walls, seams), squat racks and platforms, posing stage, parked cars, plaza (compass inlay, benches, bike racks),
  beach gym, clothing store, pro gym shell and glass wall, posters and mirror frames. 1,325 pairs are left, all hidden
  or the same color: plates pressed together on bars and plate trees, the compass points crossing under the clock
  plinth, skate ramp slice sides, rack post caps. Recipe: `tools/builders/Fix3Overlaps.luau` (Town/TownKit updated).

## In progress
- Nothing half-built.

## Waiting on you
- (done in v4: everyone now has the Robloxian 2.0 body; the old tier ids are gone.)
- **Sound ids** (you pick them; all in `Config/Sounds.luau`). New placeholders that reuse other clips: `PumpFull`,
  `BigRep`, `PersonalRecord`, `Grew`. Older placeholders: `LevelUp`, `Maxed`, `TitleUnlocked`, `TierUnlocked`,
  `GeneticsClank`, `OutOfStamina`, `GeneticsThudLow`, `RepTick`/`Click`. No sound yet: skateboard rolling, sliding
  doors, store purchase, mirror opening. Area music only has Starter and Pro.
- **Badge ids:** Aesthetics God, Skyscraper, Defied Genetics have `badgeId = nil` in `Config/Titles.luau`.
- **Monetization ids** (stays off until you add them): 7 game passes, 3 products in `Config/Monetization.luau`.
- **DataStore name:** Studio saves to `"PlayerData_1"` (the repo once had `"PlayerData_xz"`). Kept; tell me if not.
- **Portrait:** phones/tablets are locked to landscape (`StarterGui.ScreenOrientation = LandscapeSensor`).

## Check these (things I couldn't fully verify)
- **Map after the overlap fix:** ~10,500 parts moved by 0.04 studs. I checked the park, plaza, smoothie bar, street,
  buildings, gym interior and a poster close up (no gaps, nothing looks shifted); give doors, machines and the skate
  park a quick look while playing.
- **DataStore:** near the end Studio got "InternalServerError" from UpdateAsync on `PlayerData_1` and the menu stayed
  on "Loading..." (a Roblox-side error, probably after many quick test sessions); the last tests ran with
  `FreshPlayer` (turned off again). If it happens to you, wait a minute and play again.
- **Stats on a real phone**: tested in Studio at 667x374 (phone landscape) and 536x405 with the phone layout switched on. On
  short screens (< 460px tall) the world labels step aside while you lift (the widget shows the stats instead). Check
  tapping the labels' Muscles button and the widget with real fingers.
- **Muscle body tiers** with the bodies you pick: tested with Roblox's "Man" torso + arms (clothes, hair and
  accessories stayed on, height kept). Check your bodies with layered clothing, emotes, the skateboard and lifting.
- Phone **Menu button + grid**: open it, pick a few buttons, tap outside to close, on a real phone or the Device Emulator.
- 2-player features (spotting, high fives, crews, arm wrestling vs a player) weren't retested.

## Known issues
- Spurts after ~11 get a few minutes longer each (the permanent bonus hits the 5x cap); fine for now.
- Part count: town ~16,100, gyms ~3,500. StreamingEnabled is on; small props don't collide or cast shadows. If phones
  struggle: MeshPart templates for windows/trees.
- Cosmetic headbands can hide under big hair; ProximityPrompts only show when their part is on screen.
- The live mirror reflection shows your character and the room, not other players.

## Decisions made (fix list 3)
- Part 1 removed the whole generated-muscle system (base body, gym look, muscle shapes, veins, stage meshes), not just
  the meshes, because you asked for normal avatars with their own clothes. Old saves that had a gym look outfit
  equipped just ignore it (the item no longer exists).
- Part 2: the "you grew" moment only plays when the body really changes (a tier with ids); with empty ids it stays
  quiet. A tier with no ids shows the highest filled tier below it. Tier progress counts each muscle up to the goal.
- Sauna: on the sand east of the beach gym (not inside a gym) so every player can use it from the start. Skate wheels
  are the only store gear with an effect, and only on skating speed (no gains). Prices: decks 80-150, wheels 150 / 400 / 900.
- Bug fixed: the progress mirror errored when opened (a helper from the muscle tiers work was missing). It opens
  again (Day one / Now).
- Studio test hooks: with `FreshPlayer` on, Workspace number attributes `TestCoins` (starting coins) and `TestSpurts`
  (start after that many Growth Spurts). Tested with them: a Growth Spurt 2 player walks through the pro gym glass door
  and lifts on the pro machines (Lateral Raise) with no errors.
- Part 4: buttons are 64px, not 56: "Wardrobe" is 60px wide at the 14px minimum text size. "Phone" = touch screen
  without a keyboard (Studio: Workspace attribute `TestPhoneLayout`); a small PC window keeps the PC menu. While lifting
  the PC menu keeps only Stats; phones hide the Menu button.
- Stats final: the labels are a 2D layer (not BillboardGuis): that keeps them the same size, always visible and jitter-free.
  Shared state: `UIBus.StatsLabels` (on/off), `UIBus.MusclesVisible`, `UIBus.OpenMuscles`, `UIBus.Training` (on a
  machine), `UIBus.CoverOpen` (a full panel is open: labels and the Muscles button step aside). The tutorial's "open
  Stats" step counts the labels turning on. A leftover saved `statsLabels` setting is dropped on the next settings save.
  The widget's muscle shapes are named after their muscle (handy for tests). Mouse-free Studio tests: from the server
  context fire `Remotes.MachineState:FireClient(player, "Enter", machineModel)` / `"Exit"`.
- Part 5: the nudge is 0.04 studs (invisible, but enough to stop flicker at any distance). Only anchored Parts
  (blocks and cylinders), never characters; same-color plain plastic is skipped (it can't flicker visibly).

## Decisions made (fixes + muscles run)
- No day/night cycle exists, so the lamps are simply off now; they switch on automatically if the clock ever passes
  18:00 (a future night event or a day cycle needs no extra work).
- Portrait: the game stays locked to landscape (in the emulator's portrait mode the screen stays landscape).
- Phones: corner notes go top left (narrow, max 2, 1 while lifting); the machine panel is left-aligned while lifting.
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


- **Big stat numbers:** `Muscles.DisplayScale = 150` / `Muscles.Shown()`: levels are SHOWN x150 (a rep gives about +1,000 at higher levels) (labels, Muscles panel, body-map widget, gain popups, goal text). Display only: goals, caps, saves and gains math are unchanged. Change the one number to tune.

- **Mirror live reflection (unverified visually):** MirrorClient's copy now has no Humanoid/Animator/joints at all, so it can't play its own pose; every part is placed from your real part every frame (RenderStepped) and it rebuilds when BodyVersion changes. I could not get a view of the glass in the test to confirm the 'frozen running pose' is gone: please test idle, walk, jump, emote near the mirror.

- **RankTag (rank badge):** `Theme.RankTag(grade, props)` / `Theme.SetRankTag(tag, grade)` replaces the colored letter circles: 24x20 rounded rect (4px), 1.5px border + Montserrat Bold letter in the rank color (S coral, A blue, B gold, C green, D gray), dark panel fill, faint glow on S only. Used on the Muscles panel cards, the genetics odds panel, the membership card and under each plate in the genetics reveal. The big 3D plates (and the overall hero plate) stay as physical plates by design. Screenshots rank_tag_*.png (only 'after' for the panel/reveal; before = the earlier genetics shot).

- **UI v7 part 1:** floating Muscles button removed; a Muscles tile in the left menu opens the Muscles panel, which is now frosted glass (white 0.85 fill, thin white border) with a BlurEffect (16, tweened, cleared on close). Screenshot ui_v7_after_frosted_panel.png.

- **Lag fixes:** tutorial path dots are re-placed every frame on the last computed path (fixed distances back from the target, only dots ahead of you show), path recompute 0.25s / 1 stud. Coach + legends turn to you on each client every frame (NpcLookClient, smooth ~0.25s settle) instead of a 4/s server loop.

- **UI v7 part 2 (labels):** world labels are now plain text (white name, pale blue number) on an almost invisible black rectangle hugging the text; 1px white lines from 6px dots end in a short horizontal underline under the label; labels follow on a soft spring (drift up to 50px, settle) with their own idle float. NOT done yet from the UI v7 brief: click-to-expand groups, hover highlights (blobs already carry MuscleName), 2-col tile styling (the left menu is already a 2-column grid), top-bar pills. Growth Spurt bar got an arrow that collapses it to its title row.

- **UI v7 part 3:** click a group label to expand its muscles (one open at a time, others glide down; click again collapses); hovering a group or a single muscle outlines/fills its blobs red (Highlight, 0.15s fade; tap on phones); clears when collapsed or Stats closes. Growth Spurt bar moved to the very top edge. STILL TODO: top-bar pills (coins, quests, daily reward, settings), tile restyle (bold outlined labels, 3D look, bounce), Shop tile (hidden anyway), an overlap push-apart pass, phone test of all of this.

- Stat label backings: 5px rounded corners, 1.5x wider. Left menu got a collapse arrow (folds all tiles away; arrow stays, panels beside the menu unaffected).

- **Mirror reflection fix (verified by numbers):** copy parts are now paired with your real parts by name path (the old index pairing could leave it frozen), and the copy has no Humanoid/joints (the earlier edit that was meant to do this had never applied). Test showed copy limb heights tracking the real ones during an emote.

- **Poses:** the Emotes menu is renamed Poses (tile + panel title); new poses Abs and thighs, Most muscular (crab) next to Double biceps, Lat spread, High five. Joint angles for the two new ones are a first guess: look at them in play and tell me what to adjust. Mirror reflection lighting made brighter (unverified by eye).

- Statue: built at the strongest player's height (Growth Spurts) and now real size (Scale 1, was 1.35). Entrance door leaves got slim dark frames that slide with the glass (`tools/builders/DoorFrames.luau`, already run in the open place). Mirror screen uses golden posing lighting.

- **NPCs:** regulars can't enter FallingDown/GettingUp/Ragdoll any more (they were getting stuck after the body swap). New **beach gym regulars** (Kai, Luna, Tomas, Zoe; Gym = "Beach") built by `tools/builders/BeachNPCs.luau` (already run in the open place) with NpcSpots under Town.BeachGym; GymGoerService walks them between the beach machines. Verified: they walk and use machines.

- **Pro gym polish:** `tools/builders/ProGymPolish.luau` (already run in the open place): charcoal rubber floor with a faint 4-stud tile grid (was a glossy near-black slab), podium rim a blue neon ring (was a blown-out white disc), softer warmer spotlights + 9 invisible ceiling fill lights, front curtain-wall glass lighter (0.55) with dark gunmetal mullions (were chalk-white on night-blue glass). Screenshots progym_before*/progym_after1.

- **Skate (less goofy):** riders now get a side-on skater stance on every client (body turned sideways on the board, knees bent deeper at speed, arms out, lean into turns and when accelerating) instead of running on the spot; speed ramps up over ~1.2s instead of jumping to 30; a little extra FOV at speed for you. Joint angles are a first pass: look at it riding and tell me what looks off. Wheels don't spin yet.

- **NPC fix (7 Oct):** regulars were lying on the floor stuck in FallingDown: the body was re-applied while they walked, and the earlier fix had also switched off GettingUp so they could never stand. Now: FallingDown/Ragdoll off, GettingUp on, the body is only re-applied if the place doesn't already have it, NPCs are dressed BEFORE they start walking, and the loop stands them back up if they ever fall. Verified: all 12 upright over 40s, most walking.

## Skate rework (7 Oct 2026)
- `SkateClient` rides the board: momentum (push up to the top speed, coast, brake by holding back), carving (turn rate falls with speed), hills speed you up/slow you down, walls stop you, Jump = ollie. Input = Humanoid.MoveDirection (works with keys, phone thumbstick, gamepad; the new Roblox PlayerModule has no GetControls), movement = a LinearVelocity on the root with WalkSpeed 0.
- Pose for every skater: side-on regular stance, bent knees (deeper at speed), feet flat on the deck, back-foot push cycle, toe/heel lean in carves, tuck + arms up in the air; the board tilts with carves and pops on ollies (BoardJoint Motor6D).
- `SkateService`: new board (maple deck with kicktails, grip, trucks, wheels, bearings), wheels on the ground and the deck top under the feet.
