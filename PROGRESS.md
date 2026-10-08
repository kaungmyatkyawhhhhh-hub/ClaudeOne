# GYM ARC — Progress

Short and current (8 Oct 2026). Full history: `git log -p -- PROGRESS.md`. Code map: `docs/GAME_OVERVIEW.md`.

## LATEST (8 Oct, 10 PM): bigger skate park, grinding, smooth quarter pipes
**Saved to Roblox (v302, 9:57 PM); not published: publish (Alt+P) to make it (and the parking arrows) live.**
- **Bigger:** `Config/Town.SkatePark` 56 x 46 -> **84 x 64** (x -164..-80, z 174..238, same centre). New layout
  (`Town.luau` `buildSkatePark`, the old `SkateParkExtras` builder folded in and deleted): big quarter pipe (west), half
  pipe (back), quarter pipe (front east), fun box with a rail, two ledges with stripes, a kicker, a manual pad, a flat
  bar, a long rail (20 studs) and a low beginner rail, three painted discs, benches by the gate, 4 floodlights (range 56).
  Boardwalks to the two gates shortened (`Config/Town.Boardwalks`), 4 palms moved off the footprint (`PALMS` /
  `PALM_MOVES`). In the place: `require(_Builders.Town).RebuildSkatePark()` (only the park, its two boardwalks and the
  palms; the rest of the town keeps its hand fixes). Graffiti walls now Oswald (they were Montserrat).
- **Smooth quarter pipe sides:** the side walls were stacked boxes (looked like stairs). Each side is now a solid cheek
  whose top edge follows the curve (per slice a block + a wedge), 10 slices, the deck block as wide as the cheeks.
- **Grinding (`SkateClient`):** rails tagged `GrindRail` (the 2 rails, the fun box rail, the flat bar). Ollie onto one
  while rolling roughly along it (within ~63 degrees) and the board locks on: slides along the bar with light friction,
  steering ignored, sparks from the board, a lower crouch with arms out (others: a board on metal shows the grind pose);
  it ends at the bar's end, when slow, or when you jump. Tested (scripted ride, `TestSkateMove` hook): ollie at x -155,
  locked on at -146.8 with the feet exactly on the bar top (2.05), slid 17 studs at ~18 studs/s, rolled off the end; no
  errors. No grind sound yet (you pick sound ids). Screenshots: skatepark_new_above, quarterpipe_new_side, grind_rail.
- Not done: a screenshot of a rider mid-grind (the capture tool's delay kept missing the 1 s grind; try it yourself:
  Skate, roll along the long rail by the west quarter pipe, jump just before it).

## Before that (8 Oct, night): place lost, rebuilt from the repo, parking arrows
**Saved to Roblox (Version History 296-299, last 9:36 PM) and published once (v298, 9:34 PM, by the owner).**

**What happened.** The GYM ARC cloud place fell back to about 7 Oct 21:00: its last Save to Roblox before tonight was
7 Oct 9:54 PM, so all 8 Oct work (unified muscles, skin stages, machine cards, pro gym lifts ...) existed only in the
repo. New rule in CLAUDE.md: after every task Save to Roblox + a dated backup copy.

**First try (superseded): the autosave.** `80031260599632_AutoRecovery_2.rbxl` (8 Oct 8:50 PM, really the 7 Oct 21:00
state) was copied to `export/GymArc_recovered_2026-10-08.rbxl` (git-ignored), scripts and builders pushed into it. Dead
end: a local file can't play-test (no DataStore: PlayerData errors at load, the server never starts, every machine logs
"Infinite yield ... Plates"; that is where the "no Plates" warnings came from). That window can be closed without saving.

**The rebuild (in the real cloud place, Team Create):**
- Scripts: all 370 from `src/` (latest commit), byte-identical, 0 compile errors; 173 stale MuscleData modules (old v8
  per-muscle data) removed; new: `MachineSignsClient`, `Shared/LimbStages`, `Config/LimbStages`, `Config/SkinStages`,
  `UI/BodyFigure` + 142 MuscleData modules.
- Data: MuscleData regenerated from `Downloads\muscle_v9_unified.zip` and `Config/LimbStages` from `Downloads\limb_stages`
  (`tools/gen_muscle_data`, `tools/gen_limb_stages`): both identical to the repo.
- World, builders whose code changed since 7 Oct (re-run, they replace what they made): GymAssets (plate templates),
  Gyms (both rooms, 60 machines incl. 6 working treadmills, pec deck, pro equipment, NPC spots; keeps the Entrance and
  its MenuCamera), ProGymPolish, Decor (starter / pro / plaza fountain), GeneticsSet, SkinStages, the 28 limb stage
  templates (`tools/limb_stages_setup`, from the uploaded ids); `GymAssets.Replace` swapped all 157 placed plates;
  Leg Press x2 + Hack Squat x2 (starter) and 1 + 1 (pro) placed at their old spots (no builder); `GeneticsCameraRig`
  (CamPitch 8, CamHeight 0).
- NOT re-run (builder unchanged since 7 Oct and its output already there): Town, beach gym, posing stage, sauna, skate
  extras, sails, gym front poster, door frames, mirror, gym cat, NPCs + beach NPCs, arm wrestling table, leaderboard
  wall, statue pedestal, season decor. The town carries hand fixes no builder has (overlaps, sign distances, LOD).
- World pass redone: shadow-casting lights 18 -> 3 (starter pendant, pro spotlight, posing stage), shadow / touch flags
  of 17,774 parts copied from the 8 Oct play-test snapshot (`%LOCALAPPDATA%\Roblox\server.rbxl`), small new props
  without shadows, CanTouch off on 461 static parts (no script uses touch; Seats keep it). 21,281 parts.
- `MachineClient`: no WaitForChild without a timeout (`waitFor` helper: 5 s timed waits in a loop); a machine sets
  itself up once its load part and "Plates" both exist (ChildAdded), so a missing Plates gives no warning. The `Config`
  local was dropped (the script is at Luau's 200 top-level locals).
- Parking lot arrows (owner): the head was one right-angle wedge that read as a half head pointing back at the shaft;
  now two mirrored wedges make a symmetric head pointing the way of the shaft (+X). Fixed in the place and in the
  Town builder. Screenshots: parking_arrows_{before,fixed}.

**Checked in a solo play test** (fresh player, `TestMuscleShare` 2; the test attributes were removed afterwards):
- OK: no errors in Output the whole session; 60/60 machines got their Plates (300 plates); loading + menu + PLAY glide;
  tutorial steps advance; bench reps (tier 1 of 12, stamina segments, coins 25 -> 77, HUD split "Mid Chest 53% · Front
  Delts 21% · Triceps 26%", body-map widget, blue training tint); machine card on the nearest machine + "!" NEW on unused
  ones; genetics screen (gym set, DNA, labels, frame / body cards, reroll); EXP numbers; side menu + top bar; Coach Dex,
  a visiting legend (Chad Gainsworth), Muscle of the Day board, 12 regulars walking, titles over heads; prompts for
  spotting, arm wrestling, shop, posing, mirror, shakes; statue; sliding doors; your character with 7 live muscle
  meshes, the skin stage and the 4 limb stage meshes; the town.
- Rebuilt: both gyms and their machines, plates, leg press / hack squat, treadmills, genetics scene, skin and limb
  stages, decor.
- There but not tested: skateboard, poses on the stage, running on a treadmill, pro gym lifts, the Gear & Fits store,
  crews, wardrobe, mirror reflection, anything needing two players. Seasons: decor templates exist, no season was
  running.
- Noted: at 2x the goal (full look) the character is much bulkier than the brief's "lean V-taper"; same as the v9
  screenshots, so it is the muscle data, not the rebuild.
- Screenshots: rebuild_{menu,starter_gym,machine_plates,town,character_max,lifting_flatbench,machine_card,genetics}.

**Still to do by the owner:** the dated backup: **File > Download a Copy** (cloud places have no "Save to File As") to
`C:\Users\kaung\OneDrive\Documents\GymArc_backups\GymArc_2026-10-08.rbxl` (folder made). Publish (Alt+P) for the arrows.

- **Machine card (8 Oct, redesign):** the glowing diamond is gone: one small flat charcoal card over the nearest machine
  (see "Game feel" in the brief); the machine HUD shows the muscle split with percents. Screenshots: card_next_to_barbellrow_pc,
  card_middle_of_gym_pc. Phone-size screenshots not possible from here (Studio's viewport can't be resized).
- **Machine signs, EXP popups, training tint (8 Oct, late night):** see "Game feel" in the brief. New:
  `MachineSignsClient` (machine card + "!" / "NEW"), `Shared/UI/BodyFigure` (the body-map's shapes,
  shared), `Config/HudIcons.MuscleGroups` (group colors), `Muscles.FormatExpShort`, save fields `machinesUsed` and
  `settings.expPopups`, `MuscleRig.SetTraining` (the blue training tint; `MuscleRig.Flash` is now its rep pulse). The skin
  color layers (torso, arms) are OPAQUE now (a see-through overlay vanished behind Glass): drawn only while tinted, flat skin
  + the tint, the pulse is the layer part's Color (no mesh write). MachineClient is near Luau's 200-locals limit: new code
  there goes in tables (`ExpPops`, `bars.*`). Studio hook `TestPopupSlow` (n = popups live n times longer). Not done: phone
  size screenshots (the Studio viewport can't be resized from here); "Lat Pulldown" doesn't exist, the Pull-Up Bar
  (Lats) was used. Screenshots: sign_flatbench_close, sign_25_studs, sign_squatrack_lowceiling, exp_popups_flatbench,
  tint_flatbench_front, tint_pullup_{front,back}, tint_squat_front, tint_npc_on_bench, hover_red_still_works.
- **Fix (8 Oct, night): progress mirror + shorts.** Mirror: it showed your back (each part was turned by M*R*M, which
  keeps the way you face; now M*R*F = your front, facing you, flipped left / right like a real mirror) and a white box for
  a torso (a ViewportFrame honours vertex alpha even under a SurfaceAppearance, and the color layer's alpha 0 on skin made
  the copies see-through). While the reflection or the before / after card shows: `MuscleRig.SetMirrorMode` makes every
  vertex opaque (one color write per mesh on the way in / out; skin tints pause, the thighs' layer shows flat skin + the
  shorts in SmoothPlastic). The copies are every live mesh part (layers, clothing) with the skin stage, transparency kept
  in step, sized right; 120 px per stud (was 40: a blur) and a bit more key light. Your pose / animation is copied every
  frame. Shorts: the "puffy inner tube" was the color layer drawn ~1.7x too big. A MeshPart made from an EditableMesh scales
  the mesh by Size / ITS OWN MeshSize (= the mesh's bounds when that part was made); the layers and clothing were made
  later (smaller bounds) but given the inner part's Size. Each part is sized from its own MeshSize now (`sizeParts`; the
  mirror's `copySize`). Also: the shorts' layer is matte Fabric (was glossy SmoothPlastic), and under the shorts the
  thigh / glute growth eases to half (fabric over muscle, `MuscleMeshes` SHORTS.Hug 0.5, full growth on the lower thigh, one
  curve so the hem stays flush). Your avatar in Studio wears no Pants, so the black is the game's own gym shorts.
  Screenshots: mirror_front, mirror_three_quarter, mirror_card_now, shorts_{front,side,back}. Left: a small lip at the outer
  sides of the waistband (the waist piece's bottom edge is a hair wider than the thigh tops).
- **Fix (late 8 Oct): blocky arms / legs and the floating piece under the neck.** The "floating piece" was the package's
  separate upper traps shell: made for the old torso, it hovered over the unified torso's chest with a sawtooth gap at
  higher levels. Removed (generator `SKIP`, data, unit, code); the unified torso grows the traps itself (back and neck
  checked at max: no hole). The upper arms and legs were only built once a muscle in them grew, so at level 0 the plain
  blocky Robloxian parts showed: both are built from level 0 now, the legs no longer sink under the skin (on a thin leg
  the sink pushed them out the other side as spikes) and hide the plain upper legs (their shells cover the whole thigh).
  Your character: **7 live EditableMeshes** (torso front + back, 2 upper arms, 2 upper legs, waist), plain UpperTorso /
  LowerTorso / upper arms / upper legs at Transparency 1, forearms / calves the static stage meshes. The unified data is
  welded (0 duplicate vertices in torso, arms, legs) with averaged per-vertex normals. Screenshots: unified_front_{level0,
  half,max}, unified_back_max, before_fix_{max_floating_traps,level0_spiky_legs}.

- **Unified muscles (muscle v9):** the torso and both upper arms are ONE welded mesh each (the old torso / arm shells and the
  DeltCap balls are gone); every muscle moves its own vertices, so any mix (one muscle maxed, the rest 0) has no holes or
  cracks. The torso (39,600 triangles) is split into front / back halves (20,000 per mesh limit) that always update in the
  same frame; its open top is closed by a low dome. Highlight and rep flash tint by each muscle's weight.
- **Look balance cap removed** (Config/LookBalance, Config/MuscleBulge, the lock / held-back bar / hint / toast,
  tests/lookbalance, settings.lookCapHintSeen): each muscle shows its own look.
- **Skin stages:** all 15 images found in the group "Myanmar Builders Club" (ids in `Config/SkinStages`); the place IS owned
  by that group (id 33151111), so they load. `ReplicatedStorage.SkinStages` Stage1..5 (`tools/builders/SkinStages`). Stage by
  the overall look: 0 -> 1, half -> 2, full -> 3, mass monster -> 4 -> 5, swapping at the midpoint (preloaded, no white flash).
- **Forearms / calves stay the static stage meshes:** the freed slots were not enough. A play client holds at most 8
  EditableMeshes; your body uses 7 (torso front + back, 2 upper arms, 2 upper legs, waist).
- **Other players, NPCs, the statue: no mesh muscles** (they got none before either once the 8 were used: the budget is per
  client, and a MeshPart made from an EditableMesh goes blank when that mesh is freed, so they can't be "baked"). They wear
  the skin stage and the limb stages. The statue is marble (no skin stage).
- **Performance** (Studio play solo on your PC; Studio caps at 60 FPS and drops to 15 FPS whenever its window isn't in front,
  so judge FPS with Studio in front; "Lua" = all client script time per frame, the Studio Tag Editor plugin included):

  | Where | Before (old build) | v9 before fixes | After |
  |---|---|---|---|
  | Spawn | 60 fps, Lua ~2.3 ms | | 60 fps (p95 18 ms), Lua 2.2 ms |
  | Starter gym | 60 fps, Lua 2.3 ms | Lua 3.3 ms | 60 fps (p95 17.8 ms), Lua 2.0 ms |
  | Town plaza / street | 60 fps | | 60 fps (p95 17.8 ms), Lua 1.5-1.9 ms |
  | Pro gym | 60 fps | | 60 fps, game scripts ~1.6 ms |
  | **Reps on the bench** | | **22 fps, 100 ms spikes every rep** | **60 fps, worst frame 26 ms, 0 spikes** |
  | Near the gym door (mirror) | 22 fps | | 60 fps |

  The big one: **every change to an EditableMesh costs the engine ~40-60 ms of a frame**, whatever its size (measured with a
  2,000 triangle test mesh). Fixes: the rep flash / hover highlight write a color mask ONCE and fade with a part's
  Transparency; no per-rep mesh pump; looks move in 0.015 steps; one body region writes per frame; idle bodies don't touch
  their meshes; body parts under muscle meshes don't pump by Size; Box collision on the mesh parts; other lifters animate only
  near and on screen and move their bar + plates in one BulkMoveTo; the cat's tail only within 60 studs; the mirror only
  while on screen. World: CanTouch off on 380 static parts, CastShadow off on 236 small ones; 3 shadow-casting lights; no
  depth of field; StreamingEnabled on; nothing unanchored. No memory leak (90 s in the gym: instances and memory flat).
  Not measured: the phone emulator FPS (can't drive it from here).
- **Screenshots** (`screenshots/`): v9_max_{front,back,back_high}, v9_monster_{front,back}, v9_single_<muscle> (13),
  v9_neck_closeup, v9_hover_highlight_{chest,shoulders}, v9_rep_flash_mask, skin_{gym,outdoors}_{level0,half,max,monster}.
- **TRY FIRST:** bench a few sets (smooth now?), hover the stat labels (red tint), look at the skin up close at your level.

## Workflow (no Rojo)
- **Roblox Studio is the source of truth** (edit through the MCP connection); GitHub is a backup. Scripts are synced between
  Studio and `src/` (`tools/export` exports Studio -> `src/`; during build sessions `src/` is edited and pushed into Studio).
- After each piece: run the checks in CLAUDE.md, commit + push. **After every task: File > Save to Roblox + a dated
  backup copy** (File > Download a Copy -> `Documents\GymArc_backups\GymArc_<date>.rbxl`), and check Version History.
- Work in the cloud place (the "GYM ARC" Studio window), never a local .rbxl: a local file has no DataStore.
- World areas are built once from recipes in `tools/builders` (see `tools/bake.md`), then edited as normal parts.

## First thing to do
1. **File > Download a Copy** to `Documents\GymArc_backups\GymArc_2026-10-08.rbxl`, then **Publish (Alt+P)** for the arrow fix.
2. Look at the new things yourself: skateboard, poses on the posing stage, the tiles/pills, EXP numbers, the red stat highlight and the rep flash.

## What exists (all built and tested in Studio unless noted)
- **Core:** player data + saving, 18 muscles, stamina, coins, genetics (reveal + reroll), height/Growth Spurts, titles, one
  reusable machine system with 12 weight tiers, shakes, economy, quests (Coach Dex), Muscle of the Day, legends, seasons,
  leaderboard wall, membership card, wardrobe, crews, arm wrestling, spotting, tutorial.
- **World:** starter gym, pro gym (Growth Spurt 2, glass door), beach gym, big town (street, plaza, park, beach, skate park,
  posing stage, shops), day lighting with night lamps, 14 NPC regulars (they walk, lift, strike poses).
- **EXP:** every number shown is EXP (total xp earned x `Muscles.ExpPerXp`); the first Growth Spurt needs exactly 50,000 per
  group. Levels still exist inside (saves/caps/machines). `tests/exp` checks it.
- **Muscles (v9 unified, 8 Oct):** real EditableMesh muscles on your own character: unified torso (front + back halves) and
  upper arms, shell meshes covering the thighs, the snatched waist, static stage meshes for forearms / calves
  (`Shared/LimbStages`). They wear the character's own Shirt/Pants and the skin stage (`Config/SkinStages`); under a
  SurfaceAppearance vertex colors don't show, so tints and the thighs' gym shorts live on a thin color layer part over each
  skinned mesh. Red tint when hovered in Stats, warm flash on each rep (only muscles facing the camera; `MuscleRig.SetHighlight`
  / `MuscleRig.Flash`). Pipeline: `muscle_v8/` (the unzipped muscle_v9_unified package, local, git-ignored) ->
  `tools/gen_muscle_data` (also caps the open tops) -> `ReplicatedStorage/MuscleData` -> `Shared/MuscleMeshes` ->
  `Shared/MuscleRig` -> `MuscleClient`. Keep `muscle_v8/` unzipped before running the generator (it empties MuscleData first).
- **Obliques/serratus (7 Oct):** the serratus slips are part of the Obliques mesh (`muscle_v8/source/parts.py`), driven
  by the Obliques stat. The Crunch Bench now trains Obliques too (secondary, share 0.6), so they grow from the start
  (they count in the first Growth Spurt's Core goal; pacing still passes); Cable Woodchop (pro gym) trains them as main.
- **Poses:** `PoseData` + `PoseController` (from the poses package), `PoseClient` (name, facing, hit, release),
  `ShowOffService.SetPose` (server sets attribute `Pose`; judges score on the stage); statue + mirrors use `Shared/PoseApply`.
- **Skate:** `SkateClient` (momentum, carve, brake, ollie, side-on stance, grinding on `GrindRail` bars) + `SkateService`
  (board model). Skate park 84 x 64 (`Config/Town.SkatePark`, built by `Town.luau`).
- **UI v7:** 2-column colored 3D tiles on the left (`SideMenu`) with a fold arrow (phones: the tiles hang from the arrow
  at the top left, folded by default; no centre grid any more), top-bar pills (`TopBar`: coins; Quests, Daily, Settings),
  world stat labels with click-to-expand, hover glow, spring float and push-apart. Icons/colors in `Config/HudIcons`
  (set `image = "rbxassetid://..."` to use your own art). Look tokens in `Theme` (`Theme.Tile`, `Theme.TileFont`).

- **Start + menu (7 Oct):** `LoadingScreen` (ReplicatedFirst) until the menu scene has streamed in; menu shot = the
  `MenuCamera` part in `Gym.Entrance` (move it to reframe). `Gym.Entrance`, `Gym.StarterGym` and `Town.GymFront` are now
  Persistent Models (were Folders; the builders make Models too).

- **Treadmill:** `Config/Machines` Treadmill (2 in the starter gym, 4 in the pro gym): speeds 2-13 mph as tiers, no stamina
  cost, `trains = "Stamina"`: no muscle EXP (`Gains.PerRep` returns nothing), the distance run (`stats.cardioMeters`, speed x
  `Machines.Cardio.MetersPerMph` per rep) raises max stamina by 1 per `Stamina.Cardio.MetersPerPoint` (40 m), up to +150
  (`Stamina.MaxFor`; `PlayerData.RefreshMaxStamina` keeps the player's MaxStamina attribute, x Iron Lungs). Popups show
  metres, "Max stamina · N" when it goes up; not listed as a Legs exercise; its speeds still unlock with Quads. Belt slats
  slide while running, run animation `POSE_ANIMS.Run`, "Cardio King" at `Cardio.KingMeters` (10 km). Pro gym treadmills are
  the premium model (`GymKit.treadmillPro`: chrome uprights + side rails, motor hood with LED strip, angled console with a live
  speed / time / distance readout, cup holders, safety key).
- **Gym fits (8 Oct, overnight):** 6 classic-Shirt tops x 4 colors in the Gear and Fits store (new cosmetics slot "Fit",
  `Config/Cosmetics` Fits + FitTemplates, prices 150-400 coins), worn from the Wardrobe; `CosmeticService` puts a Shirt
  "GymArcFit" on the character, the muscles wear it. Images drawn by `tools/clothing_templates.ps1` into
  `clothing_templates/` and uploaded (ids in Config). Known issue: at mass monster size the skin under-layer pokes
  through on overhanging delts / biceps (the inner-part + cloth-part trick, any classic shirt).
- **Shoulders widen with muscle (8 Oct):** tall skinny players start with narrow shoulders (k 0.4 -> 1.15 -> 1.4), the frame
  on top, always wider than the hips (`Body.Widths.ShouldersOverHips`).
- **Golden ratio body (8 Oct):** longer legs, shorter torso, same height, on players, NPCs, mirror rigs and the statue
  (`BodyShape.ApplyProportions`, re-applied after every rescale).
- **Muscle data (8 Oct):** the waist morph (start -> snatched), the aesthetic max data, per-mesh mass monster sizes and Growth
  Spurt widths (tall skinny players start with narrow hips that
  widen with muscle) (`BodyService.WidthFactors`,
  `BodyShape.ApplyWidths`; attributes FrameWidth / WaistWidth drive the torso taper). Studio hook `TestMachine` = a
  machine name puts you on it. Open: at mass monster the traps and triceps grow pointed tips (the manifest sizes 2.6 / 2.1
  plus the +12% push the max shape far out); lower `Muscles.Look.MonsterG` for them if they look too sharp.

- **Genetics scene (7 Oct):** a real gym around the reveal (`ReplicatedStorage.GeneticsSet`, from
  `tools/builders/GeneticsSet`): platform, J-hooks, plate tree, dim back wall with racks, soft depth of field. Camera
  tuning: `ReplicatedStorage.GeneticsCameraRig` (CamPitch / CamHeight attributes).

- **Equipment (7 Oct):** "M WEIGHTS" on every plate. **8 Oct: plates look like the genetics plates** (`tools/builders/GymAssets`):
  stepped bevel edge, raised rim band, chrome hub + flange, groove ring, "M WEIGHTS" curved over and under the hub, the weight at
  9 and 3 o'clock, printed on both faces (drawn within 40 studs); `GymAssets.Replace` swapped all 157 placed plates. Also end collars on bars, Leg Press + Hack Squat (2 + 2 starter, 1 + 1 pro),
  quests "Do 15 leg presses / hack squats", exercises line on the Muscles cards.

- **Pro gym lifts (8 Oct):** every pro machine animates on the real equipment. Arm IK (`bars.armIK`, two-bone, elbow pole)
  puts the hands on the handles (it turns each arm part by its own bone direction: the Robloxian upper arm's elbow sits ~36
  degrees off the part's axis). New pose kinds in `Config/Poses` + `MachineService.bodyCFrame`: Sit (pec deck), Support (dips:
  straight arms on the handles), Thrust (hip thrust: upper back on the pad). `contract = true` poses rest relaxed and each rep
  goes relaxed -> contracted -> relaxed (curls, raises, shrugs, crunch, leg raise ...). Reverse fly is a **pec deck** now (seat,
  chest pad, swing arms). Cable machines (lateral raise, curl, pushdown, woodchop) have real cables that follow the handle
  (`Link` parts, `bars.updateLinks`). Pull-up and hanging leg raise grip the bar with IK. Studio hook: Workspace attribute
  `TestPoseDepth` (0..1) freezes your rep at that depth (screenshots).
- **Entrance lag fixed (8 Oct):** the progress mirror (16 studs from the gym door) re-set the Size of its 14 muscle copies
  every frame (a mesh part's Size never reads back equal), which re-processed the meshes: 22 FPS near the door -> 60 FPS.

## Limits (found in Studio, not fixable here)
- A client can hold only **8 live EditableMeshes** (even empty ones; in Edit mode 40+ fit), and your character uses 7.
  A MeshPart made from an EditableMesh shows nothing once that EditableMesh is destroyed (no baking), so other characters
  get no mesh muscles. The whole UpperTorso can't be one mesh: 39,600 triangles > the 20,000 per-mesh limit (front / back).
- A MeshPart made from an EditableMesh scales the mesh by Size / its own MeshSize, the mesh's bounds when that part was
  made (every part from the same mesh can differ). A ViewportFrame honours vertex alpha even under a SurfaceAppearance (the
  world ignores it there).
- **Every EditableMesh change costs ~40-60 ms of engine time** (positions or colors, any amount, measured 8 Oct). Changing a
  mesh part's Size every frame is also expensive (frame p50 57 ms); its Transparency or Color is cheap.
- A script can't upload meshes yet ("CreateAssetAsync ... not available yet"), so the stage meshes must be imported by hand.
- A game script can't set a SurfaceAppearance image, and other people's clothing images can't be read into an EditableImage,
  so muscles wear clothing through a second textured part at 2% transparency. T-shirt graphics don't show on the snatched torso.
- Loading (7 Oct): `CreateMeshPartAsync` takes 0.3-1s per mesh, so `MuscleRig` builds 3 units side by side (`MAX_BUILDS`) on a
  time slice (`BUILD_MS`); NPCs/statue only get meshes once your own muscles are built (`MuscleClient` `OTHERS_WAIT`). Your
  muscles finish ~1-1.5s after the body swap (was ~4-5s). The progress mirror's "Now" body shows copies of your LIVE muscle
  meshes (a new rig there took your character's 8 meshes and your muscles vanished).

## Waiting on you
- **Sound ids** (you pick them; all in `Config/Sounds.luau`). Placeholders reusing other clips: `CrowdOoh`, `PumpFull`, `BigRep`,
  `PersonalRecord`, `Grew`, `LevelUp`, `Maxed`, `TitleUnlocked`, `TierUnlocked`, `GeneticsClank`, `OutOfStamina`, `RepTick`/`Click`,
  and the genetics reveal's `GeneticsSpin`, `GeneticsFlip`, `GeneticsPop`, `GeneticsShimmer`, `GeneticsBurst`, `GeneticsDrumRoll`,
  `GeneticsExplode`, `GeneticsBlessed`.
  No sound yet: skateboard rolling, grinding on a rail, sliding doors, store purchase, mirror opening. Area music only has Starter and Pro.
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
- Performance (8 Oct): other lifters animate only within 80 studs of the camera and pump only within 45 (`Machines.ClientCull`); plate number labels draw within 60 studs, decor screens within 80; the starter gym pendants lost their invisible glow PointLights (20 fewer lights). In Studio the Tag Editor and Building Tools plugins cost more CPU than the game scripts: turn them off while play testing. Studio caps the frame rate at 15 when its window is not focused, so FPS can only be judged with Studio in front.
- Spurts after ~11 get a few minutes longer each (the permanent bonus hits the 5x cap).
- Part count: town ~16,100, gyms ~3,500; StreamingEnabled is on. If phones struggle: MeshPart templates for windows/trees.
- Cosmetic headbands can hide under big hair; ProximityPrompts only show when their part is on screen.
- Rep and set popups are big numbers now (about 3,000+ EXP at the start): easy to scale in `Muscles.ExpPerXp` if too loud.
- The rep flash (warm white-orange) is hard to see on light skin under bright lights; it is clear on darker skin.
- v9: on the rock skin stages a zigzag shows along the upper arm's UV seam; the traps' outline edges are faintly visible
  from some angles. The rep flash no longer has its 2% mesh pump (cost a ~50 ms frame on every rep).
- Fits: at mass monster size bits of skin poke through on the biggest delts / biceps (the shirt-layer trick, any classic shirt).
- Forearm / calf stages (v9): a slightly darker band at the top of each tube where it meets the upper arm / thigh, and the
  hover / flash tints the whole stage evenly (one MeshPart color, no soft edge).

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
  (`Muscles.Look`). The mass monster gets the rock skin stages 4-5 (`Config/SkinStages`).
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
`TestCoins`, `TestSpurts`, `TestMuscleShare` (0..6 x the goal, live; 2 = full look, 5 = mass monster), `TestMuscleIds` ("Biceps,Triceps", or with own shares "Abs=0.7,Lats=2"), `TestOpenMirror`, `TestPhoneLayout`,
`ReplayTutorial`, `TestGenetics` / `TestRerollGenetics` ("C,B,A,S,S,D" or "C,B,A,S,S,D,VTaper": six grades in group order, optional frame, for the first roll / the
next reroll), `TestGeneticsHold` (n = freeze the genetics reveal at plate n's moment, 7 = overall plate), `TestFlashSlow` (n = rep flash n times slower, for screenshots), `PoseDebug` (PoseController prints joints found/missing and playing tracks). Without FreshPlayer: `TestMuscleExp` (e.g. 2000000) = every muscle at that EXP on your own save, saving off for the session. Mouse-free machine tests: from the server context `Remotes.MachineState:FireClient(player, "Enter", model)`. `TestSkateMove` (a Vector3, set on the client) stands in for the stick while skating (scripted ride / grind tests; the MCP play session has no control scripts).
