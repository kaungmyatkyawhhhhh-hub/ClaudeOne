# GYM ARC — Progress

Short and current (7 Oct 2026). Full history: `git log -p -- PROGRESS.md`. Code map: `docs/GAME_OVERVIEW.md`.

## Workflow (no Rojo)
- **Roblox Studio is the source of truth** (edit through the MCP connection); GitHub is a backup. Scripts are synced between
  Studio and `src/` (`tools/export` exports Studio -> `src/`; during build sessions `src/` is edited and pushed into Studio).
- After each piece: run the checks in CLAUDE.md, commit + push. **Save the place in Studio** after every session.
- World areas are built once from recipes in `tools/builders` (see `tools/bake.md`), then edited as normal parts.

## First thing to do
1. **File > Save to Roblox** (the muscle v8 data/scripts, poses, EXP, UI v7, skate and many fixes live only in the open place until saved).
2. Look at the new things yourself: skateboard, poses on the posing stage, the tiles/pills, EXP numbers, the neon stat highlight.

## What exists (all built and tested in Studio unless noted)
- **Core:** player data + saving, 18 muscles, stamina, coins, genetics (reveal + reroll), height/Growth Spurts, titles, one
  reusable machine system with 12 weight tiers, shakes, economy, quests (Coach Dex), Muscle of the Day, legends, seasons,
  leaderboard wall, membership card, wardrobe, crews, arm wrestling, spotting, tutorial.
- **World:** starter gym, pro gym (Growth Spurt 2, glass door), beach gym, big town (street, plaza, park, beach, skate park,
  posing stage, shops), day lighting with night lamps, 14 NPC regulars (they walk, lift, strike poses).
- **EXP:** every number shown is EXP (total xp earned x `Muscles.ExpPerXp`); the first Growth Spurt needs exactly 50,000 per
  group. Levels still exist inside (saves/caps/machines). `tests/exp` checks it.
- **Muscles (v8):** real EditableMesh muscles that grow from the skin, wear the character's own Shirt/Pants, snatched-waist
  torso for everyone, neon glow when hovered in Stats. Pipeline: `muscle_v8/` (local, git-ignored) -> `tools/gen_muscle_data`
  -> `ReplicatedStorage/MuscleData` -> `Shared/MuscleMeshes` -> `Shared/MuscleRig` -> `MuscleClient`. Keep `muscle_v8/`
  unzipped before running the generator (it empties MuscleData first).
- **Poses:** `PoseData` + `PoseController` (from the poses package), `PoseClient` (name, facing, hit, release),
  `ShowOffService.SetPose` (server sets attribute `Pose`; judges score on the stage); statue + mirrors use `Shared/PoseApply`.
- **Skate:** `SkateClient` (momentum, carve, brake, ollie, side-on stance) + `SkateService` (board model).
- **UI v7:** 2-column colored 3D tiles on the left (`SideMenu`), top-bar pills (`TopBar`: coins; Quests, Daily, Settings),
  world stat labels with click-to-expand, hover glow, spring float and push-apart. Icons/colors in `Config/HudIcons`
  (set `image = "rbxassetid://..."` to use your own art). Look tokens in `Theme` (`Theme.Tile`, `Theme.TileFont`).

## Limits (found in Studio, not fixable here)
- A client can hold only **8 live EditableMeshes**; your character uses all 8 (snatched torso 2, front torso, back, upper
  arms 2, upper legs 2). Forearms, calves, other players, NPCs and the statue get little or no muscle unless a live server allows more.
- A game script can't set a SurfaceAppearance image, and other people's clothing images can't be read into an EditableImage,
  so muscles wear clothing through a second textured part at 2% transparency. T-shirt graphics don't show on the snatched torso.
- Loading (7 Oct): `CreateMeshPartAsync` takes 0.3-1s per mesh, so `MuscleRig` builds 3 units side by side (`MAX_BUILDS`) on a
  time slice (`BUILD_MS`); NPCs/statue only get meshes once your own muscles are built (`MuscleClient` `OTHERS_WAIT`). Your
  muscles finish ~1-1.5s after the body swap (was ~4-5s). The progress mirror's "Now" body shows copies of your LIVE muscle
  meshes (a new rig there took your character's 8 meshes and your muscles vanished).
- Not built: rock "mass monster" skin (can't trigger: levels never pass the goal; textures would need uploading).

## Waiting on you
- **Sound ids** (you pick them; all in `Config/Sounds.luau`). Placeholders reusing other clips: `CrowdOoh`, `PumpFull`, `BigRep`,
  `PersonalRecord`, `Grew`, `LevelUp`, `Maxed`, `TitleUnlocked`, `TierUnlocked`, `GeneticsClank`, `OutOfStamina`, `RepTick`/`Click`.
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

## Decisions (still in force)
- Gold (#F2C14E) only for big moments (BIG REP, NEW PR, PUMPED, maxed). PUMPED and BIG REP multiply outside the 5x cap.
- **No cap on stats** (owner's call): muscles keep growing past the Growth Spurt goal (`GrowthSpurts.GetLevelCap` is infinite); the diminishing factor is the only brake. "Defied Genetics" uses a 130% mark (`GetMasteryLevel`). Side effect: one strong muscle can lift its group's average, so a group can reach the goal with one muscle far ahead. XP per level = `20 + 2 x level`, BaseXp 34.
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
`TestCoins`, `TestSpurts`, `TestMuscleShare` (0..3 x the goal, live), `TestMuscleIds`, `TestOpenMirror`, `TestPhoneLayout`,
`ReplayTutorial`. Mouse-free machine tests: from the server context `Remotes.MachineState:FireClient(player, "Enter", model)`.
