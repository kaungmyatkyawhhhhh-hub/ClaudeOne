# GYM ARC — Progress

Short and current (7 Oct 2026). Full history: `git log -p -- PROGRESS.md`. Code map: `docs/GAME_OVERVIEW.md`.

## MORNING REPORT (overnight run, 8 Oct)
Everything is in Studio and pushed; **File > Save to Roblox first** (new models, rebuilt treadmills, decor, uploaded ids).

- **Forearms + calves:** your character now uses **7 EditableMeshes (was 8)**: the front torso muscles and the snatched upper
  torso share one mesh. (The whole UpperTorso can't be one mesh: front 9,570 + back 17,908 triangles > the 20,000 limit.)
  The forearm / calf **stage meshes are wired but NOT in yet**: a script can't upload meshes ("CreateAssetAsync ... not
  available yet"). Until they're in, the old EditableMesh forearms / calves stay (they still don't fit on your character).
  **Your steps:** 1) Studio > File > Import 3D, pick all 28 OBJs in `limb_stages/meshes` (bulk import, "Import only as
  models" off is fine). 2) Drag them into Workspace (each keeps its file name, e.g. `RightLowerArm__Forearms__g040`).
  3) Command bar: paste and run `tools/limb_stages_setup.luau`; it prints "28 templates made". 4) Save. That's it: the
  code (`Shared/LimbStages`) turns on by itself (stage cross-fade, clothing, tint, scaling, NPCs / statue too). Tested with
  stand-in templates (cross-fade measured, sizes follow the 7'0" body), not with the real meshes.
- **Fits:** 6 tops x 4 colors (black, grey, white, an accent) in the Gear and Fits store, worn from the Wardrobe, prices
  150-400 coins in `Config/Cosmetics`. Classic Shirts drawn by `tools/clothing_templates.ps1` (`clothing_templates/`) and
  **already uploaded** (ids in Config): nothing to do. Known issue: at mass monster size bits of skin poke through on the
  biggest delts / biceps (`task2_fit_croppedhoodie_monster_known_issue.png`): the muscles' skin under-layer + shirt-layer trick
  (any classic shirt). The pump cover's sleeves end near the elbow.
- **Treadmill:** 2 working treadmills in the starter gym cardio corner (the 3rd stays decor): mph tiers, no stamina cost,
  light leg EXP, coins, sliding belt, run animation, saved distance, **Cardio King** at 10 km (`Machines.Cardio`). No uploads.
- **Shoulders widen with muscle** (k 0.4 / 1.15 / 1.4) and **look balance cap only inside groups** (in studs) are in too.
- **Map:** parts 20,982 before -> 21,081 after (+99 decor, nothing gameplay moved). Studio play solo on this PC (not the
  phone emulator; I can't run it): spawn **38.1 -> 43.9 FPS**, worst frame **227 -> 28 ms**; town 51.3 -> 48.8 FPS (25 -> 24 ms).
  Shadow-casting lights 18 -> 3 (one per room), 36 small props lost shadows / touch, 13 empty models removed, no exact
  duplicates found. StreamingEnabled was already on. Decor (each in a `Decor` folder): starter gym lockers, rolling
  whiteboard, sign-in clipboard; pro gym 2 wall TVs, smoothie counter, wood platform; plaza fountain
  (`tools/builders/Decor.luau`). Beach gym already had everything on the list (tower, net, surfboards, towels, umbrellas).
- **Couldn't do:** phone-size checks (the Studio viewport can't be resized from here), the phone emulator FPS, draw-call
  counts (not readable from scripts), merging parts into unions (risky for parts scripts find by name), uploading meshes.
- **TRY FIRST:** 1) the Gear and Fits store: buy a stringer and a cropped hoodie, look at them on your muscles. 2) the
  treadmill in the starter gym cardio corner (watch the belt, check the mph tiers, Cardio King). 3) train only Upper Chest
  or only Biceps and look at the lock + hint in the Muscles panel.
- **Screenshots:** task1a_merged_torso_7meshes, task1b_shoulders_7ft_{level0,halfway,max,monster},
  task1c_{upperchest_only_panel,upperchest_only_body,both_chest_maxed,biceps_only},
  task2_fit_{gymtee,stringer,pumpcover,compression,croppedhoodie,sleevelesshoodie}_{front,back} (pump cover front only),
  task2_fit_gymtee_level0, task2_fit_croppedhoodie_monster_known_issue, task3_treadmill_running,
  task4_before_{startergym,progym,beachgym,plaza}, task4_after_{startergym,progym,plaza_fountain}.
  (No forearm / calf stage shots: the meshes aren't uploaded yet.)

## Workflow (no Rojo)
- **Roblox Studio is the source of truth** (edit through the MCP connection); GitHub is a backup. Scripts are synced between
  Studio and `src/` (`tools/export` exports Studio -> `src/`; during build sessions `src/` is edited and pushed into Studio).
- After each piece: run the checks in CLAUDE.md, commit + push. **Save the place in Studio** after every session.
- World areas are built once from recipes in `tools/builders` (see `tools/bake.md`), then edited as normal parts.

## First thing to do
1. **File > Save to Roblox** (the muscle v8 data/scripts, poses, EXP, UI v7, skate and many fixes live only in the open place until saved).
2. Look at the new things yourself: skateboard, poses on the posing stage, the tiles/pills, EXP numbers, the red stat highlight and the rep flash.

## What exists (all built and tested in Studio unless noted)
- **Core:** player data + saving, 18 muscles, stamina, coins, genetics (reveal + reroll), height/Growth Spurts, titles, one
  reusable machine system with 12 weight tiers, shakes, economy, quests (Coach Dex), Muscle of the Day, legends, seasons,
  leaderboard wall, membership card, wardrobe, crews, arm wrestling, spotting, tutorial.
- **World:** starter gym, pro gym (Growth Spurt 2, glass door), beach gym, big town (street, plaza, park, beach, skate park,
  posing stage, shops), day lighting with night lamps, 14 NPC regulars (they walk, lift, strike poses).
- **EXP:** every number shown is EXP (total xp earned x `Muscles.ExpPerXp`); the first Growth Spurt needs exactly 50,000 per
  group. Levels still exist inside (saves/caps/machines). `tests/exp` checks it.
- **Muscles (v8):** real EditableMesh muscles that grow from the skin, wear the character's own Shirt/Pants, snatched-waist
  torso for everyone, red tint when hovered in Stats (blends ~40%, pulses 30-45%, keeps the shading) and a warm 35% flash on each rep (only muscles facing the camera, soft 4-row edge, clothing 15%, the torso under a muscle tints with it so it works at level 0; `MuscleRig.SetHighlight` / `MuscleRig.Flash`). No z-fighting: the torso sits 0.05 under the shells (push grows as the muscle emerges), barely-grown shells sink under it, and each muscle's skin edge snaps onto the torso (`MuscleMeshes.EdgeSnap`). Pipeline: `muscle_v8/` (local, git-ignored) -> `tools/gen_muscle_data`
  -> `ReplicatedStorage/MuscleData` -> `Shared/MuscleMeshes` -> `Shared/MuscleRig` -> `MuscleClient`. Keep `muscle_v8/`
  unzipped before running the generator (it empties MuscleData first).
- **Muscle v8-1 (7 Oct, "smooth, no seams" + spikes fix v2 + more definition):** border vertices grow with the average g of
  every muscle that shares them (`share`), normals come from the data (`nbase`/`nmax`, also the snatched torso's OBJ normals),
  muscles at 0 lie flat on the skin (no more tucking inside). New mesh Hamstrings_Shorts (UpperLegs unit). Muscle parts are
  SmoothPlastic (Plastic's grain followed the clothing UVs as a speckle) and sit 0.02 studs off the skin (`SKIN_LIFT`).
  Veins (`vein`) are wired at 0.4 while PUMPED at max; the full mass monster stage is still not built.
- **Obliques/serratus (7 Oct):** the serratus slips are part of the Obliques mesh (`muscle_v8/source/parts.py`), driven
  by the Obliques stat. The Crunch Bench now trains Obliques too (secondary, share 0.6), so they grow from the start
  (they count in the first Growth Spurt's Core goal; pacing still passes); Cable Woodchop (pro gym) trains them as main.
- **Poses:** `PoseData` + `PoseController` (from the poses package), `PoseClient` (name, facing, hit, release),
  `ShowOffService.SetPose` (server sets attribute `Pose`; judges score on the stage); statue + mirrors use `Shared/PoseApply`.
- **Skate:** `SkateClient` (momentum, carve, brake, ollie, side-on stance) + `SkateService` (board model).
- **UI v7:** 2-column colored 3D tiles on the left (`SideMenu`) with a fold arrow (phones: the tiles hang from the arrow
  at the top left, folded by default; no centre grid any more), top-bar pills (`TopBar`: coins; Quests, Daily, Settings),
  world stat labels with click-to-expand, hover glow, spring float and push-apart. Icons/colors in `Config/HudIcons`
  (set `image = "rbxassetid://..."` to use your own art). Look tokens in `Theme` (`Theme.Tile`, `Theme.TileFont`).

- **Start + menu (7 Oct):** `LoadingScreen` (ReplicatedFirst) until the menu scene has streamed in; menu shot = the
  `MenuCamera` part in `Gym.Entrance` (move it to reframe). `Gym.Entrance`, `Gym.StarterGym` and `Town.GymFront` are now
  Persistent Models (were Folders; the builders make Models too).

- **Treadmill (8 Oct, overnight):** 2 of the 3 cardio-corner treadmills in the starter gym are machines (`Config/Machines`
  Treadmill: speeds 2-13 mph as tiers, no stamina cost, gainScale 0.35, Quads + Hamstrings + a light touch of Calves under
  GoalShare); belt slats slide while running (MachineClient), run animation `POSE_ANIMS.Run`, distance in
  `stats.cardioMeters` (speed x `Machines.Cardio.MetersPerMph` per rep), title "Cardio King" at `Cardio.KingMeters` (10 km).
  Built with `GymKit.Treadmill` (Gyms builder updated).
- **Gym fits (8 Oct, overnight):** 6 classic-Shirt tops x 4 colors in the Gear and Fits store (new cosmetics slot "Fit",
  `Config/Cosmetics` Fits + FitTemplates, prices 150-400 coins), worn from the Wardrobe; `CosmeticService` puts a Shirt
  "GymArcFit" on the character, the muscles wear it. Images drawn by `tools/clothing_templates.ps1` into
  `clothing_templates/` and uploaded (ids in Config). Known issue: at mass monster size the skin under-layer pokes
  through on overhanging delts / biceps (the inner-part + cloth-part trick, any classic shirt).
- **Shoulders widen with muscle (8 Oct):** tall skinny players start with narrow shoulders (k 0.4 -> 1.15 -> 1.4), the frame
  on top, always wider than the hips (`Body.Widths.ShouldersOverHips`).
- **Look balance cap (8 Oct, reworked overnight):** only inside each group, in bulge studs (`Config/LookBalance` MaxGap 0.15 /
  MaxRatio 1.5, `Config/MuscleBulge` generated by `tools/gen_muscle_data`); applied in `BodyService.EncodeLevels` /
  `WidthFactors` and `MuscleClient`; lock + held-back bar + hint, one-time toast (`settings.lookCapHintSeen`, > 0.05 studs),
  rep flash when a cap lifts. `tests/lookbalance`. My addition: never below the groupmate's own look level, because muscles
  differ in natural size (Lats 0.42 studs vs Lower Back 0.12 at full look) and the pure stud rule would hold a balanced back
  at ~65% forever.

- **Golden ratio body (8 Oct):** longer legs, shorter torso, same height, on players, NPCs, mirror rigs and the statue
  (`BodyShape.ApplyProportions`, re-applied after every rescale).
- **Muscle data v8 final (8 Oct):** MuscleData regenerated from the latest `muscle_v8` (37 meshes): border "blend" weights
  (the old "share" averaging is gone), DeltCap shoulder balls (in the UpperArms meshes), the waist morph (start -> snatched),
  the aesthetic max data, per-mesh mass monster sizes and Growth Spurt widths (tall skinny players start with narrow hips that
  widen with muscle) (`BodyService.WidthFactors`,
  `BodyShape.ApplyWidths`; attributes FrameWidth / WaistWidth drive the torso taper). Studio hook `TestMachine` = a
  machine name puts you on it. Open: at mass monster the traps and triceps grow pointed tips (the manifest sizes 2.6 / 2.1
  plus the +12% push the max shape far out); lower `Muscles.Look.MonsterG` for them if they look too sharp.

- **Genetics scene (7 Oct):** a real gym around the reveal (`ReplicatedStorage.GeneticsSet`, from
  `tools/builders/GeneticsSet`): platform, J-hooks, plate tree, dim back wall with racks, soft depth of field. Camera
  tuning: `ReplicatedStorage.GeneticsCameraRig` (CamPitch / CamHeight attributes).

- **Equipment (7 Oct):** "M WEIGHTS" on every plate (templates rebuilt, 157 placed plates branded in place; those keep their old
  thickness, only bar/machine plates got thinner), end collars on bars, Leg Press + Hack Squat (2 + 2 starter, 1 + 1 pro),
  quests "Do 15 leg presses / hack squats", exercises line on the Muscles cards.

## Limits (found in Studio, not fixable here)
- A client can hold only **8 live EditableMeshes** (in Studio the 8th already fails with "memory budget"). Since 8 Oct your
  character uses **7** (was 8): torso front + snatched upper torso in ONE mesh, torso back, LowerTorso, upper arms 2, upper
  legs 2. Merging the whole UpperTorso into one mesh is impossible: front muscles 9,570 + back 17,908 triangles > the 20,000
  per-mesh limit. Forearms and calves move to STATIC stage meshes (`Shared/LimbStages`, `Config/LimbStages`): no EditableMesh
  at all, on every character, NPCs and the statue too. They need the 28 stage meshes uploaded (see the morning report); until
  then the old EditableMesh forearms / calves stay (and don't fit on your character).
- A script can't upload meshes yet ("CreateAssetAsync ... not available yet"), so the stage meshes must be imported by hand.
- A game script can't set a SurfaceAppearance image, and other people's clothing images can't be read into an EditableImage,
  so muscles wear clothing through a second textured part at 2% transparency. T-shirt graphics don't show on the snatched torso.
- Loading (7 Oct): `CreateMeshPartAsync` takes 0.3-1s per mesh, so `MuscleRig` builds 3 units side by side (`MAX_BUILDS`) on a
  time slice (`BUILD_MS`); NPCs/statue only get meshes once your own muscles are built (`MuscleClient` `OTHERS_WAIT`). Your
  muscles finish ~1-1.5s after the body swap (was ~4-5s). The progress mirror's "Now" body shows copies of your LIVE muscle
  meshes (a new rig there took your character's 8 meshes and your muscles vanished).
- Not built: rock "mass monster" skin (can't trigger: levels never pass the goal; textures would need uploading).

## Waiting on you
- **Sound ids** (you pick them; all in `Config/Sounds.luau`). Placeholders reusing other clips: `CrowdOoh`, `PumpFull`, `BigRep`,
  `PersonalRecord`, `Grew`, `LevelUp`, `Maxed`, `TitleUnlocked`, `TierUnlocked`, `GeneticsClank`, `OutOfStamina`, `RepTick`/`Click`,
  and the genetics reveal's `GeneticsSpin`, `GeneticsFlip`, `GeneticsPop`, `GeneticsShimmer`, `GeneticsBurst`, `GeneticsDrumRoll`,
  `GeneticsExplode`, `GeneticsBlessed`.
  No sound yet: skateboard rolling, sliding doors, store purchase, mirror opening. Area music only has Starter and Pro.
- **Badge ids:** Aesthetics God, Skyscraper, Defied Genetics have `badgeId = nil` in `Config/Titles.luau`.
- **Monetization ids** (stays OFF until you add them): 7 game passes, 3 products in `Config/Monetization.luau`.
- **DataStore name:** Studio saves to `"PlayerData_1"`. Tell me if it should be something else.
- Your own **HUD icon images** if you want to replace the built-in glyphs (`Config/HudIcons`).

## Not verified (needs a real device or a second player)
- Phones: Menu button + grid, stats labels, EXP text widths, skate controls, pose name panel (only the Studio phone layout was checked).
- 2-player features (spotting, high fives, crews, arm wrestling vs a player); muscles with 10+ players.
- Real layered (3D) clothing (a fake layered jacket hides the muscles correctly).
- DataStore: Studio sometimes gets `InternalServerError` after many quick test sessions; wait a minute and play again.

## Known issues
- Spurts after ~11 get a few minutes longer each (the permanent bonus hits the 5x cap).
- Part count: town ~16,100, gyms ~3,500; StreamingEnabled is on. If phones struggle: MeshPart templates for windows/trees.
- Cosmetic headbands can hide under big hair; ProximityPrompts only show when their part is on screen.
- Rep and set popups are big numbers now (about 3,000+ EXP at the start): easy to scale in `Muscles.ExpPerXp` if too loud.
- Traps: their outer edge reaches over the shoulder and can show as a thin shelf above the delt from low angles (in the muscle_v8 mesh, was there before the z-fight fix). Back at max: small skin gaps between lats / lower back / traps with stepped seams.
- The rep flash (warm white-orange) is hard to see on light skin under bright lights; it is clear on darker skin.

## Decisions (still in force)
- World pass (7 Oct, place only): small props cast no shadow (outside machines/NPCs), static parts have CanTouch off (no
  script uses touch), signs render within 120-400 studs by size, big town models use LevelOfDetail = StreamingMesh, test
  leftovers moved to `ServerStorage._Leftovers`. Grass under/around walk-in buildings is LeafyGrass (blades grew through
  the gym's back wall). Statue + pedestal in the hall's back-left corner (`ShowOff.Statue.Spot`), out of the spawn camera.
- NPCs are not solid on each client (`NpcLookClient`): the camera zoomed into your arm when one stood behind your bench.
- Gold (#F2C14E) only for big moments (BIG REP, NEW PR, PUMPED, maxed). PUMPED and BIG REP multiply outside the 5x cap.
- **No cap on stats** (owner's call): muscles keep growing past the Growth Spurt goal (`GrowthSpurts.GetLevelCap` is infinite); the diminishing factor is the only brake. "Defied Genetics" uses a 130% mark (`GetMasteryLevel`). Side effect: one strong muscle can lift its group's average, so a group can reach the goal with one muscle far ahead. XP per level = `20 + 2 x level`, BaseXp 34.
- **Group stats are sums, the look has room to grow** (owner's call, 7 Oct): a group's EXP = its muscles added up (goal shown
  as the same sum; quests/titles say "every muscle"); the look is full at 2x the goal's EXP and mass monster at 5x
  (`Muscles.Look`). The rock skin of the mass monster is still not built (textures would need uploading).
- NEW PR banner stays (small banner, not a window) although the design file lists PR popups as cut.
- Beach gym machines are Growth Spurt 1; racks/benches/pull-up bars there are normal starter machines.
- Phones/tablets are locked to landscape. "Phone" = touch without a keyboard (Studio: Workspace attribute `TestPhoneLayout`).
- NPC hair/clothes: Roblox-made catalog items only; nothing inserted from the Creator Store.
- The tile label font (Fredoka One) is the one exception to "Montserrat only", per the UI v7 brief.

## Pacing
- `GrowthSpurts.Targets = { 8, 15, 25, 35, 45 }` minutes; `tests/pacing.luau` plays 60 simulated players through 8 spurts
  (fails if a spurt is >10% off). Goal levels: 15, 47, 72, 103, 135, 157, then +18 each (shown as 50,000 / 304,118 /
  642,353 / 1,231,961 EXP ...). Retune with `lune run tests/pacing tune` if gains, tiers or stamina change.

## Studio test hooks (with Workspace attribute `FreshPlayer` = temporary new player)
`TestCoins`, `TestSpurts`, `TestMuscleShare` (0..6 x the goal, live; 2 = full look, 5 = mass monster), `TestMuscleIds`, `TestOpenMirror`, `TestPhoneLayout`,
`ReplayTutorial`, `TestGenetics` / `TestRerollGenetics` ("C,B,A,S,S,D" or "C,B,A,S,S,D,VTaper": six grades in group order, optional frame, for the first roll / the
next reroll), `TestGeneticsHold` (n = freeze the genetics reveal at plate n's moment, 7 = overall plate), `TestFlashSlow` (n = rep flash n times slower, for screenshots), `PoseDebug` (PoseController prints joints found/missing and playing tracks). Without FreshPlayer: `TestMuscleExp` (e.g. 2000000) = every muscle at that EXP on your own save, saving off for the session. Mouse-free machine tests: from the server context `Remotes.MachineState:FireClient(player, "Enter", model)`.
