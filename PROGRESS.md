# GYM ARC — Progress

Short and current. Older sections (before 15 Oct): `docs/PROGRESS_archive.md`. Full history: `git log -p -- PROGRESS.md`. Code map: `docs/GAME_OVERVIEW.md`.

## Current (19 Oct)
- OWNER CHANGES (made by hand in Studio, documented, not changed; vault: Progress "2026-10-19 GYM ARC Owner changes"):
  MuscleData/Index monsterG (own live muscles' mass monster size, e.g. Rhomboids 3.2, Quads 0.6, SideDelts 0.8; the
  static gmon stage meshes and Config/Muscles Look.MonsterG keep the old sizes; the file is generated, so
  tools/gen_muscle_data would overwrite it); Config/Body.Widths Maxed shoulders 0.85 hips 0.65, MassMonster shoulders
  1.05 hips 1.1; Config/Genetics frames Wide 1.05x, V-Taper 1.1x; Config/Titles Beat Benny Rare, Beat Coral Epic,
  Beat Dante Legendary; Config/Sounds three songs per area + new ids; CLAUDE.md shortened (old: docs/CLAUDE_full_old.md).
- Unchanged: UI, MuscleRig / BodyStages / LimbStages code, the 84 low-poly stage MeshIds (match StageMeshBackup.new).
- Committed with it: the 15 Oct Top crews member view (CrewService / CrewClient), never committed before.
- INNER QUAD BULGE (prompt 2): Shared/MuscleMeshes QUADS shapes the quad growth in LoadGroup (inner / front quads: full
  up to 25% of the bare thigh, none from 60% up and under the shorts; the outer sweep kept), so your live body, the mirror
  copy and anything made from the data are fixed. Stage meshes: tools/quad_fix_stage_corrections.luau (exact rebuild of the
  old stages, max error 0) + tools/quad_fix_lowpoly.py moved the owner's low-poly thighs -> 24 OBJs in
  Downloads\gym_arc_meshes_lowpoly_quadfix\other_player_stages (g000 unchanged). WAITING: owner imports them; then run
  tools/quad_fix_stage_setup.luau + tools/quad_fix_patch_config.py <bounds.json>, add the MeshIds to StageMeshBackup (DONE 19 Oct).
  Found: at mass monster the hamstrings (owner's 2.8) push a lump between the knees (owner decides).
- PROMPTS 2-5 (19 Oct afternoon): (2) owner imported the fixed thighs; tools/quad_fix_stage_setup.luau applied 24, Config/
  BodyStages + StageMeshBackup (new / lowpoly) updated: DONE. (3) MirrorService + ShowOffService build the "Now" rig / statue
  with BodyService.ApplyFrame (saved values; statue via new PlayerData.Peek, champion's copy kept); Studio TestStatueMe.
  Crews: CrewNamesV1 claims (unique name / tag, any case), empty crews deleted (record, score, claims), leader notice on
  join; tools/crew_names_backfill.luau ran: ARAQ313 -> [SRT1] (mosa_ali; SRT313 by cort keeps SRT9). (4) MuscleMeshes
  UPPER_TRAPS slope on the Traps growth (live body done); 12 fixed low-poly torso OBJs in
  Downloads\gym_arc_meshes_lowpoly_trapsfix\other_player_stages: WAITING for the owner's import, then
  tools/upper_traps_stage_setup.luau + tools/quad_fix_patch_config.py <that bounds.json>. (5) Top crews view tested phone +
  PC; deleted crew header keeps its name.
- TRAPS YOKE + ROUND DELTS (prompt 7, 19 Oct evening): MuscleMeshes shape layers (data.shapes[muscle], drawn by MuscleRig
  applyUnified + gen_body_stages with MonsterG("<muscle>@shape") = ShapeMonsterG: Traps 1.35, delts 1.6): UPPER_TRAPS yoke
  (the data's Traps fade in the top band) and DELTS ellipsoid caps on the arm tops (the data's delts fade under the cap);
  normals of reshaped areas recomputed (fitNormals). Index monsterG SideDelts 0.8 -> 1.5. Stage meshes: tools/
  reshape_stage_corrections.luau (exact rebuild, error 0) -> 24 low-poly OBJs in Downloads\gym_arc_meshes_lowpoly_shoulderfix
  (torso + arms, same triangle counts; includes the upper traps fix, the trapsfix folder is outdated). WAITING: owner
  imports (superseded by the backfix set, prompt 8). Seen: owner's
  Rhomboids 3.2 makes pointed flaps at mass monster (not changed).
- BACK FILL + ADDUCTORS (prompt 8, 19 Oct night): MuscleMeshes BACK (Rhomboids / LowerBack shape layers filling the back
  to its smoothed ridge minus a spine groove) and ADDUCTORS (LoadGroup merged.shape, drawn with Quads@shape by MuscleRig
  applyRange / gen_body_stages: straight inward only, fades out 62-90% of the bare thigh). Owner mid-task: arms / upper
  chest looked weird -> DELTS cap smaller (CapFrom -0.12, Down 0.46), yoke FrontShare 0.15. Stage meshes: 48 low-poly OBJs
  in Downloads\gym_arc_meshes_lowpoly_backfix (torso, arms from the owner's low-poly; thighs from the quadfix set; every
  fix of the day). DONE 19 Oct night: owner imported; tools/body_stage_setup.luau +
  tools/quad_fix_patch_config.py ran, StageMeshBackup.Reshape19Oct.
- Queue (owner, 19 Oct, vault Prompts 2-5): inner quad bulge, mirror / statue width + duplicate crew tags, upper traps
  missing, top crews member view test.

- BODY LAG (20 Oct, prompt 13): cause = your own live body rewritten up to 20x/s during the 0.4 s growth tween on every
  level-up (fresh player training: 8-26 writes/s, each a 65-90 ms frame, ~33 FPS on PC). MuscleRig: one write round at most
  every WRITE_EVERY = 1 s, no tween, rig:Pulse no longer pumps the mesh -> 0-5 writes/s, ~46 FPS. MuscleClient: low-end
  (FPS < 40 for 5 s, or graphics quality 1-3; Studio: Workspace TestLowEnd) -> own body shows the BodyStages meshes past
  15 studs (MuscleRig SetFarLook; back under 12). All 90 stage templates low-poly (no wrong-folder imports), now Box
  collision. Left: gym light shadows (~700 shadow draw calls). Vault: Progress "2026-10-20 GYM ARC Body lag".
- PROMPT 15 (20 Oct): Shared/VFX/BodyPump (own character Model:ScaleTo +3.5%, 0.15 s up / 0.4 s down, gold Highlight
  flash + spark burst; others: flash + sparks only) on the 10-level pump (MuscleClient) and pose hits (PoseClient);
  MuscleRig Pulse / PulseModel removed. BlobShadowClient: soft blob (rbxassetid://76083127218780) under every body,
  raycast to the floor. Shared/LowEnd (IsLowEnd / IsPhone) used by MuscleClient + new LightShadowsClient (all light
  Shadows off on phone / low-end). Place already had only 5 shadow lights (main spots). Graphics level 1 draws no shadows
  at all; on PC most shadow draws are the sun (GlobalShadows, not changed: owner decides).
- TRAPS TEXTURE + BACK SHAPE (20 Oct, prompt 15b): MuscleMeshes applyCapPatch (MuscleData UpperTorso__Unified__cap: top
  cap re-meshed, same 51 ids / 300 tri slots) + applyUVPatch (UpperTorso__Unified__uvfix + _1.._5: surface-following
  texture map, per-face corners in data.faceUV, MuscleRig draws them without the seam rule) + addBackSculpt (BACK_BELLIES
  smooth union, spine groove, lat flare; data Traps / Rhomboids / LowerBack / Lats give way on the back; old back fill
  removed; ShapeMonsterG Lats 1.3). Torso load ~340-470 ms (was ~215). 14 low-poly torso OBJs (g000..gmon, same counts)
  in Downloads\gym_arc_meshes_lowpoly_trapsback (tools/torso_back_stage_corrections.luau + torso_back_lowpoly.py).
  WAITING: owner imports, then tools/torso_back_stage_setup.luau + quad_fix_patch_config.py <bounds.json> --with-g000.
  Vault: Progress "2026-10-20 GYM ARC Traps texture and back".

- BETA TESTER BADGE (20 Oct, prompt 16): BetaBadgeService (OPTIONAL_SERVICES in Main): PlayerAdded -> UserHasBadgeAsync,
  then AwardBadge (pcall, one retry after 5 s, own thread, skipped in Studio); on award PlayerEvent "BetaBadge" ->
  RetentionClient gold toast after the menu. Config/Titles BETA_BADGE_ENABLED = true, BETA_BADGE_ID = 471600537426484.

## Rules
- No growth spurt cooldown. (Owner, 14 Oct: a player can do the next Growth Spurt as soon as they've earned it; checked:
  there is no timer, time check or config value for it anywhere, and the Skip Growth Cooldown product is removed.)

## Workflow (no Rojo)
- **Roblox Studio is the source of truth** (edit through the MCP connection); GitHub is a backup. Scripts are synced between
  Studio and `src/` (`tools/export` exports Studio -> `src/`; during build sessions `src/` is edited and pushed into Studio).
- After each piece: run the checks in CLAUDE.md, commit + push. **After every task: File > Save to Roblox + a dated
  backup copy** (File > Download a Copy -> `Documents\GymArc_backups\GymArc_<date>.rbxl`), and check Version History.
- Work in the cloud place (the "GYM ARC" Studio window), never a local .rbxl: a local file has no DataStore.
- World areas are built once from recipes in `tools/builders` (see `tools/bake.md`), then edited as normal parts.

## Waiting on you
- **Sound ids** (you pick them; all in `Config/Sounds.luau`). Placeholders reusing other clips: `CrowdOoh`, `PumpFull`, `BigRep`,
  `PersonalRecord`, `Grew`, `LevelUp`, `Maxed`, `TitleUnlocked`, `TierUnlocked`, `GeneticsClank`, `OutOfStamina`, `RepTick`/`Click`,
  and the genetics reveal's `GeneticsSpin`, `GeneticsFlip`, `GeneticsPop`, `GeneticsShimmer`, `GeneticsBurst`, `GeneticsDrumRoll`,
  `GeneticsExplode`, `GeneticsBlessed`.
  No sound yet: skateboard rolling, grinding on a rail, sliding doors, store purchase, mirror opening. Area music only has Starter and Pro.
- **Badge ids:** Aesthetics God, Skyscraper, Defied Genetics have `badgeId = nil` in `Config/Titles.luau`.
- Monetization is ON (owner's ids in `Config/Monetization.luau`; vault Monetization note).
- **DataStore name:** Studio saves to `"PlayerData_1"`. Tell me if it should be something else.
- Your own **HUD icon images** if you want to replace the built-in glyphs (`Config/HudIcons`).

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

## Studio test hooks (with Workspace attribute `FreshPlayer` = temporary new player)
`TestCoins`, `TestSpurts`, `TestMuscleShare` (0..6 x the goal, live; 2 = full look, 5 = mass monster), `TestMuscleIds` ("Biceps,Triceps", or with own shares "Abs=0.7,Lats=2"), `TestOpenMirror`, `TestPhoneLayout`,
`ReplayTutorial`, `TestGenetics` / `TestRerollGenetics` ("C,B,A,S,S,D" or "C,B,A,S,S,D,VTaper": six grades in group order, optional frame, for the first roll / the
next reroll), `TestGeneticsHold` (n = freeze the genetics reveal at plate n's moment, 7 = overall plate), `TestFlashSlow` (n = rep flash n times slower, for screenshots), `PoseDebug` (PoseController prints joints found/missing and playing tracks). Without FreshPlayer: `TestMuscleExp` (e.g. 2000000) = every muscle at that EXP on your own save, saving off for the session. Mouse-free machine tests: from the server context `Remotes.MachineState:FireClient(player, "Enter", model)`. `TestSkateMove` (a Vector3, set on the client) stands in for the stick while skating (scripted ride / grind tests; the MCP play session has no control scripts). `TestSignCamera` (a Vector3, client) = the point the machine sign faces (angle screenshots).
- Removed the "Skip Growth Cooldown" product (3718306447) on the owner's request: its Config/Monetization entry and its
  shop icon (Config/UI.ShopIcons.product_skip_growth_cooldown). Nothing else referenced it (no Store or ProcessReceipt
  code by name). It was never on sale (hidden).
- AURA VFX (owner's module, 14 Oct): Shared/VFX/AuraVFX is the owner's AuraVFX.lua with the TEX table filled (8 textures
  uploaded from Studio = owner's inventory; flipbooks 1024x1024). The old aura effect code in AuraClient is gone.
  AuraService also puts the worn aura's preset (Config/Auras `vfx`) on the character as "EquippedAura" (again on respawn);
  AuraClient: every player, Destroy + Build on a change / respawn; power 0.15 idle, PumpMeter while lifting (1 while
  PUMPED); Burst on a PR (AuraBurst attribute, + the sound) or the pump reaching 100%; LOD own 0, others 0 < 40 studs,
  1 to 90, 2 beyond or with Others' Auras Off / Low Graphics; Titles AURAS tab = try-on on your own character at power 1
  ("AuraPreview" local attribute). Rebuilt when the body's size changes by >25% (AuraVFX sizes from the body once: it was
  built before the muscle meshes loaded and came out too narrow). Textures preloaded on join (first build showed blank
  cards). Tuned: shadow preset a bit lighter (invisible in the dark gym). Checked all 13 at 100%, golden at idle / 50% /
  burst, 7'0" and a 6-stud NPC. Screenshots: screenshots/auras_v2/. FPS: Studio driven over MCP runs ~11 fps either way,
  so no meaningful number; budget instead ~90 live particles per full aura (x0.6 on phones), others past 40 studs ~10.
- ENDLESS STAMINA (owner, 14 Oct; was Stamina Refill, same product 3718306417, renamed in the Creator Hub): 15 min of no
  stamina drain per purchase, stacking to 60 (Monetization.Effects.EndlessStaminaMinutes / MaxMinutes). Saved as
  data.endlessStamina = seconds left; StaminaService counts it down every second only for players in the game, so leaving
  keeps the rest. While > 0 PlayerData.UseStamina costs nothing and keeps stamina full (lifting, treadmills, Auto Rep).
  Granted only in ProcessReceipt (the same step that records the PurchaseId and saves before answering Granted; a repeated
  id grants nothing). UI: a gold lightning chip with the countdown first in the boosts row; the stamina bar turns gold with
  a slow shine and an infinity sign before the number (HudBottom, "EndlessStaminaUntil" attribute). Store: new name, text,
  icon (96813280646116, uploaded from Studio; search_asset can't see the owner's own uploads), BOOSTS tab; the buy button
  reads "Full: 60 min" when another 15 min wouldn't fit (the server caps it too). Hero name in the Store shrinks to fit.
  Tested: 2 buys = 30 min, same PurchaseId again = no change, 40 lift requests (27 reps) kept stamina 250/250, leave +
  rejoin 27 s later kept the time (1746 -> 1736 s), cap at 60.0 min. NOTE: the owner's own save got 60 min from the test
  receipts. Screenshots: screenshots/endless_stamina/.
- AURA VFX v2 (owner's updated AuraVFX.lua + new flame_flipbook_4x4, 14 Oct): the module is the owner's file unchanged
  except the TEX ids (new flame 90041400001838, the other 7 kept). Flames / glow / smoke sit behind the body (ZOffset), the
  ground ring lives in Terrain and raycasts to the floor (flat under the bench). My earlier extras inside the module are
  gone (the shadow tint, the Textures export): the preload list moved to Config/Auras.VFXTextures (keep in step with TEX).
  Nothing else adds aura effects: the gold PUMPED Highlight on the trained muscles (MachineClient) is skipped while an
  aura is worn or previewed. Screenshots: screenshots/auras_v3/ (8 auras x front / side / bench at full power, + bench
  without an aura: the pale skin there is the bench light, not the aura). Shadow stays very faint in the dark gym.
- INVENTORY (owner, 14 Oct; was the Titles tile/window, TitlesClient): tile INVENTORY with the owner's backpack line icon
  (Config/UI.Icons.backpack 101113089317721, uploaded from Studio; no group copy found by search_asset); window INVENTORY
  with tabs TITLES | AURAS | ITEMS, the last tab saved as settings.inventoryTab. ITEMS: Energy Shakes (count + DRINK),
  DNA Tokens (count + "Use in Genetics" -> UIBus.OpenGenetics), and the running boosts with timers (2x EXP, 2x Coins, VIP,
  Endless Stamina, Energy Shake, Server Boost, smoothie bar drinks). UIBus.OpenInventory(tab, auraId) (OpenTitles is an
  alias); the Store's Auras tab and the aura toast point to it. The old All / Owned title filter is gone (titles show all).
- TEXT FIT (owner's bug, 14 Oct): Kit.Fit(label, max, min, lines) sizes text with TextService to the largest size that
  fits its box (mockup px, so the same on every screen): names one line (two only if they can't fit at 10), unlock text
  wrapped up to 2 lines in the body font and sentence case; 8 px padding from every card edge; "..." only as a last
  resort. (TextScaled was tried first: it fell to the minimum size for every name.) Checked every title / aura / item /
  boost label at the phone (1.0), small phone (0.79) and PC (2.27) window scales: all fit.
- AURA VFX v3 (owner's body-hugging AuraVFX.lua, 14 Oct): the module is the owner's file with only the TEX ids filled
  (new: rim 138347218007327, wisp 136758735885193, lightning 80590302550492, smoke 113405238797101, ember 76009392745145,
  droplet 137490039482038; kept: flame / spark / ring / ground). Uploaded from Studio = owner's inventory (search_asset
  in the group finds none). Emitters sit on the 10 largest visible body parts (muscle meshes included); AuraClient
  rebuilds a player's aura when a body part is added / removed (muscle meshes arriving, a stage swap, a Growth Spurt),
  batched 0.6 s, at most every 1.5 s. Leftovers: none of the v1/v2 pieces (AuraVFX folder / AuraVolume / AuraCore) exist
  any more; Config/Auras.VFXTextures (preload) updated to the v3 ids. Studio-only test hook: the local "AuraPreviewPower"
  attribute sets the try-on's power (idle screenshots). Screenshots: screenshots/auras_v4/ (13 auras x idle / full x
  front / side on the 7'0" mass-monster body, + Inferno while benching). FPS: Studio driven over MCP runs ~15 fps with
  or without auras (no real phone number possible; the emulator can't be switched here): 10 NPC auras at full power =
  418 emitting emitters (about 40 per body), no measurable change; mid LOD the same.

## 15 Oct: MAIN MENU + LOADING SCREEN, new art (owner)
- Art: Config/UI.MenuArt = 124549460345839 (gym_arc_thumbnail2_nologo_1920x1080.png; Roblox keeps 1024x576), logo
  UI.Logo3D = 86034269506160 (gym_arc_logo_3d.png, 432x354), red glow = UI.SoftGlow (the aura glow_soft). Uploaded from
  Studio = owner's inventory (search_asset finds no copy in the user / group scopes).
- Both screens: the art covers the screen, sized from the viewport and pinned to the RIGHT edge (a wide phone crops top
  and bottom a little, an iPad crops the empty left side: the character is always whole); a black gradient over the
  left 40%; the 3D logo top left (32% of the height) with a soft red glow; old menu_art + blurred copies + fade gone.
- Menu (MenuClient): MenuBackground ScreenGui (full screen) + MenuScreen (safe area); tagline, PLAY, then SHOP
  (returning players, while for sale) / SETTINGS (new: opens Settings over the menu) / NEWS (the update notes, red dot),
  stacked left of the plate; player card bottom left. The bottom-right NEW pill is gone (NEWS is in the column; the
  pill sat over the character's feet).
- Loading (LoadingScreen): tip tile, step + percent, bar and dots along the bottom left (320 mockup px wide).
  Studio-only Workspace attribute TestHoldLoading = true keeps it up (screenshots).
- Checked at 844x390, 667x375, iPad 1024x768, 1920x1080 (Workspace TestPhoneSize): screenshots/menu_art_v2/. Play
  fades both away, HUD in, no errors. Note: the 1024x576 art is a little soft on a 1920x1080 PC.

## 15 Oct: LOW-POLY BODY STAGES (owner's Blender meshes, imported by the owner)
- The 91 imported models (Workspace) gave the new MeshIds; 84 stage templates (ReplicatedStorage.BodyStages torso /
  arms / leg skin / shorts, LimbStages forearms / calves) now use them via MeshPart:ApplyMesh (a script can't write
  MeshId). Size, Box collision, Automatic render, colour, no texture: unchanged (checked). BS_Waist stays old; your own
  live muscle meshes untouched. The 7 BS_UpperTraps meshes have no template in the game (the torso grows the traps),
  so they're only recorded. The imported copies in Workspace are deleted.
- Roll back: Config/StageMeshBackup (old + new MeshId per template, how to apply).
- Triangles per body (stage meshes): ~123k before (torso 19,950 x2, arm 13,728 x2, leg skin 6,676 + shorts 4,498 x2,
  forearm / calf 8,256 x4) -> 30.9k after (torso 4,986 x2, arm 3,432 x2, leg skin ~2,000 + shorts ~1,350 x2, forearm /
  calf ~1,800 x4), about 4x fewer. Body triangles drawn at the spawn view: 200k for 4 bodies before (55.5k each in that
  view) -> 286k for 10 bodies after (30.9k each); more NPCs were in range in the second run.
- FPS / frame time (Studio, MCP-driven, ~15 fps either way: no meaningful change measurable here): before 15.0 fps,
  render CPU 16.5 ms, GPU 9-12 ms; after 14.8 fps, render CPU 23 ms, GPU 12-16 ms (10 NPC bodies drawn vs 4). Draw
  calls can't be read by a script. A phone test is the real check.
- Look: every stage g000 .. gmon front + back on an NPC copy (Kai: shirt + shorts): clothing and skin map the same, no
  seam gaps; very slightly flatter shading. Screenshots: screenshots/lowpoly_stages/ (before_* / after_*).
- Owner's bug "everyone's clothes disappear when I look through the glass": a Glass-material part hides see-through
  parts behind it, and clothed stage pieces are 2% see-through (their skin shows through the shirt image's gaps). The 56
  see-through Glass parts (windows, doors, the pro gym glass wall, jars, bottles...) are SmoothPlastic now (+ a little
  reflectance; attribute WasGlassMaterial). Mirrors (5% see-through) and solid glass kept Glass.

## 15 Oct: the queued requests (in progress)
- Machine signs (MachineSignsClient): the floor outline's height is measured ONCE per machine (a ray down ignoring all
  characters, NPCs, trainers and signs, collidable floor only), anchored; the diamond keeps a fixed height and drops
  under anything above it (part boxes, since lamps are often not queryable). OCCUPIED (red, dimmed key, does nothing)
  while a player (UserId) or an NPC (Occupant) is on it; MachineService now disables the prompt while an NPC lifts.
  NOT YET PLAY-TESTED (Studio's Play got stuck).
- Coach Dex: built like Dante (GymGoerService.makeCoach: 7'6", mass monster, V-taper, shirtless, black shorts, bald,
  warm brown skin, our own stern bearded face on a classic head: 116883309844476, drawn by
  scratchpad dex_face.py), anchored with his soles on the floor. CoachDexClient poses him: leaning on the counter
  (lean 40, shoulders 55, elbows 75), breathing, weight shift, shoulder roll / neck crack every ~10 s, head tracking within
  15 studs (clamped 70 / 30, eases back), nod at 8 studs, pointing on Talk; culled past 100 studs / off screen.
  NpcLookClient no longer turns him. Booth (tools/builders/CoachDesk.luau, run in Studio): protein tub, shaker,
  clipboard, whistle, a hanging gold COACH DEX sign under the desk lamp, a warm spotlight (no shadows). Pose checked
  in play; head tracking / nod / point not yet seen in play.
- Right-side cards (RightColumn): a drawer with a graphite tab (gold chevron) on its left edge; folds right (0.25 s Quad
  Out), saved as settings.rightCollapsed; red dot + one pulse when a ready card appears while folded; folds on a
  machine (tab hidden if it would touch the weight panel). NOT YET PLAY-TESTED.
- Coach Dex checked in play (15 Oct): head tracking now works (his joints are AnimationConstraints, not Motor6Ds: the
  client skipped them; it also finds his joints again after the server rebuilds his body). Lean made smaller (14 deg,
  fists on the counter) and his spot moved 0.5 studs to the counter: the 40 deg lean showed the top of the torso mesh.
  Head follows you within 15 studs, nod when you come close, right arm points when you Talk. Tutorial portrait waits for
  his finished body (classic head + muscle meshes) and frames head + shoulders from further back. Screenshots:
  screenshots/coach_dex/ (front, 3/4, head following, nod, point, next to Dante, portrait).

## 15 Oct: PERFORMANCE PART 2 (measured first)
Measured in a Studio play session at the starter gym (client and server in one Studio; MCP-driven Studio is pinned near
15 fps and timings swing about +-2 ms, so only big effects can be seen; a phone test is still the real check).
Baseline: render CPU 10.3 ms, GPU 6.0 ms, script heartbeat 1.1 ms, physics 1.1 ms; server 60 Hz, 0.34 ms of work;
network ~0.1 KB/s; 23,686 parts, 1,690 shadow casters, 140 lights on (5 with shadows), 689 SurfaceGuis, 36 emitting
particle emitters, 38 ScreenGuis (12 shown, 3,162 GUI objects), 18 sounds (2 playing).

Top 10 costs (largest first), and what happened:
1. Body mesh triangles (~123k per body): DONE 15 Oct, owner's low-poly meshes (~31k).
2. Shadows: switching GlobalShadows off cut render CPU 10.8 -> 7.4 ms (the one clear signal). CastShadow off on 314
   more parts (under 5 studs, or see-through) outside the NPCs: 1,690 -> 1,376 casters. Buildings keep theirs (look).
3. Part count / draw calls (Town 16,790 parts; hiding it: render CPU -1.4 ms): NOT changed. Merging parts changes the
   build (owner's art rule) and the whole town sits within 256 studs of the spawn; the lever is StreamingTargetRadius
   128-160 (owner's call, Studio Properties).
4. All 46 client scripts together: heartbeat 1.22 -> 0.53 ms and render CPU -2.4 ms when all were switched off; per-frame
   callbacks already exit early when idle (part 1). Nothing worth splitting out.
5. SurfaceGuis (689): switching all off showed no clear change; 65 had no draw distance -> MaxDistance 100.
6. Lights (140): no measurable change switched off; only 5 cast shadows. Not changed.
7. Particles (36 emitting): no clear change; auras already have distance LOD. Not changed.
8. Post effects (Bloom, ColorCorrection, Blur): no clear change. Not changed (owner's lighting look).
9. Memory: Lua heap ~1.2 GB and GUI ~300 MB in Studio (client + server + Studio in one process; not a phone number).
   Not changed without a phone reading.
10. Network / server / data: server 0.34 ms a frame, ~0.1 KB/s; reps rate-limited on the server (Gains.RepCooldown);
   saves: UpdateAsync once a minute per player, spread out and budget-aware, plus leave + BindToClose. Not changed
   (the brief says 3-5 min; one a minute is within DataStore limits and loses less on a crash).
Not done here: a 10-player test and real phone numbers (needs the owner's device or Studio's Device emulator by hand:
Ctrl+F6 MicroProfiler, F9 Developer Console).
- Bug (owner, 15 Oct: "the growth spurt button disappeared"): at the 7'0" cap both the right-side Growth Spurt card and
  the Stats panel button were hidden, and below the cap the card lost to Today's Quest (one card at a time, lowest
  priority). Now the card always shows under the current card; at the cap it reads "MAX GROWTH SPURT / Reached · 7'0""
  greyed (the brief), and the Stats panel shows a greyed "Max Growth Spurt reached" button that does nothing.
- Fresh-player test (15 Oct, FreshPlayer): genetics -> KEEP -> HUD with "GROWTH SPURT 1 · 0%"; with TestMuscleShare 1 the
  card turns gold TAP TO GROW, one tap = Growth Spurt 1 (4'6", +1 DNA token, Late Bloomer, card "GROWTH SPURT 2 · 0%").
  Fixed on the way: (1) the Quests window opened by itself on join (the unclaimed daily reward), on the Daily quests tab
  and during the tutorial: it now waits for the tutorial to be done and opens the Streak (reward) tab, never while
  lifting. (2) A leftover Studio test switch (Workspace TestStore = true) showed the Shop to brand-new players; cleared,
  and TestStore / TestBrokenStage now only work in Studio. Leftover TestAuraFull cleared.
  Genetics screen: owner, 15 Oct: keep the 3D stage (the 14 Oct single-panel design is dropped; DESIGN.md updated).

## 15 Oct: ONBOARDING FUNNEL (owner: steps 13 and 14 both "First Growth Spurt")
- Cause: the funnel was built from Config.Onboarding's step list, and on 14 Oct the Skate step was added. Before that,
  step 13 was "First Growth Spurt"; after it, 13 = "Tutorial done" and 14 = "First Growth Spurt". The dashboard kept the
  old name for 13, so "13: 77" was mostly players finishing (or skipping) the tutorial and "14: 11" the real first Growth
  Spurts. Old code: Analytics.luau (FUNNEL built from Onboarding.Steps), step 13 logged from ActionService
  TutorialStep / SkipTutorial (Analytics.TutorialStep(Done)), step 14 from ActionService GrowthSpurt (line 23,
  Analytics.GrowthSpurt when growthSpurts becomes 1).
- Now (ServerScriptService/Server/Analytics.luau): a FIXED numbered list (new steps only at the end); each step logged
  once per player EVER and in order (data.analytics.funnel = highest step logged, saved); a tutorial step counts when
  completed; SKIP logs step 13 without the skipped steps; new step 14 "Growth Spurt goal reached" (so the gap between
  reaching the goal and pressing the button shows). Checked with a fresh player: 1-5, 13, 14, 15 in order, repeats
  (going back, a second skip, a second spurt) log nothing. Renamed steps start a fresh funnel in the dashboard.
- Why few reach the first Growth Spurt: it needs every muscle group at its goal (~15-20 min of training, by design),
  costs nothing, no errors seen. Until today the Growth Spurt card was hidden behind Today's Quest until ready (now always
  shown with its %); once ready it's the gold TAP TO GROW card on the right (and in Stats). Step 14 vs 15 will now show
  whether players reach the goal but don't press.

| # | Step name | What triggers it |
|---|---|---|
| 1 | 01. Joined (new player) | data loaded for a player with no Growth Spurt yet |
| 2 | 02. Genetics kept | KEEP on the genetics screen (GeneticsSeen) |
| 3 | 03. Tutorial: walked to the Flat Bench | tutorial step 1 (GoBench) completed |
| 4 | 04. Tutorial: first rep | step 2 (FirstLift) completed |
| 5 | 05. Tutorial: stamina ran low | step 3 (Stamina) completed |
| 6 | 06. Tutorial: drank the free shake | step 4 (Shake) completed |
| 7 | 07. Tutorial: got on the Squat Rack | step 5 (GoSquat) completed |
| 8 | 08. Tutorial: 3 squats | step 6 (SquatLift) completed |
| 9 | 09. Tutorial: opened Stats | step 7 (OpenStats) completed |
| 10 | 10. Tutorial: talked to Coach Dex | step 8 (Coach) completed |
| 11 | 11. Tutorial: saw the Growth Spurt goal | step 9 (Goal) completed |
| 12 | 12. Tutorial: skate tip | step 10 (Skate) completed |
| 13 | 13. Tutorial finished or skipped | tutorial done, or SKIP TUTORIAL |
| 14 | 14. Growth Spurt goal reached | every muscle group at its goal (checked every 5 s) |
| 15 | 15. First Growth Spurt done | the first Growth Spurt (+ custom event FirstGrowthSpurt = minutes since first join) |

## 15 Oct: MACHINE HUD phone vs PC layout (owner: some phones got the PC layout)
- Cause (MachineHud.measure): the layout came from ONE read of UserInputService.TouchEnabled, and on a touch screen the
  REP / STOP spots came only from Roblox's jump button; with no jump button found (hidden, not made yet, a custom
  control scheme) the PC corner values were used.
- Now `MachineHud.LayoutMode()`: short side under 500 points = always phone; else PreferredInput (Touch = phone, else
  pc); without PreferredInput: TouchEnabled and not KeyboardEnabled = phone. Re-checked live (PreferredInput,
  LastInputType, screen size). A phone with no jump button uses a fixed bottom-right spot (TouchLift 150) and keeps
  checking for the real button. If the weight card still overlaps PUMP it shrinks (to 0.6 at least); ScreenInsets =
  DeviceSafeInsets. F9 shows `[GYM ARC] HUD layout = phone, reason = ...` once per change.
- Studio-only test switches (Workspace): TestInput = "Touch" / "TouchKeyboard" / "KeyboardAndMouse", TestNoJump = true,
  TestPhoneSize (Vector2). Tested on the Flat Bench: touch with no jump button (phone, fixed spot), PC (corners),
  844x390 + keyboard (phone, small screen), 1024x768 tablet touch (phone). Screenshots: screenshots/2026-10-15_hud_*.
  A real phone with a jump button still needs the owner's check (Studio has no TouchGui).

## 15 Oct: ROBUX STORE slow on a phone (owner: about 10 minutes)
- Cause: not the window. The Shop tile only appeared after the tutorial AND `StoreAfterMinutes` (5) minutes of play,
  counted again in EVERY session from the menu, so every player waited 5+ minutes each time they joined (with the menu
  and the loading screen that is easily ~10 minutes on a phone). Also the server checked the passes one after another.
- Fix: the 5 minutes count from the player's FIRST join only (data.meta.firstJoin), so only a brand-new player waits;
  the window still builds once from Config (name, text, price, art) and opens / closes with show / hide; GetProductInfo
  runs in the background, all at once, at most 1 retry after 5 s, only to update a changed price; the server checks
  every pass in parallel at join and sets `PassesChecked`; until then only a PASS shows "..." on its buy button;
  the shop pictures are preloaded (ContentProvider:PreloadAsync) once the game has loaded.
- Measured in Studio (owner's save): before = Shop tile after 300 s of play every session (+ up to 5 s polling);
  after = Shop tile 0.0 s after PLAY, Store open 0.10 s (the open pop), second open 0.10 s. Pending "..." checked
  (screenshots/2026-10-15_store_pass_pending.jpg). A slow-network phone test is still the owner's (Studio can't throttle).

## 15 Oct: THREE FIXES (owner): menu fill, right cards under the top bar, plain mirrors
- Menu / loading screen. Causes: the background was sized in PIXELS from the camera (974 of 974.4 here; on a phone that
  resized or rotated after joining, more), and the size listener was tied to the first camera object; the logo started
  at the very top, under Roblox's top-left buttons; the loading screen gui had no ScreenInsets set. Now: both
  backgrounds (Frame + art) are UDim2.fromScale(1, 1) at (0, 0), ScaleType Crop, ScreenInsets None, IgnoreGuiInset;
  the logo starts at TopbarInset.Max.Y + 8 with the column (tagline, PLAY, buttons) under it; the logo shrinks to fit
  and the player card moves beside the buttons when there's no room under them; re-laid out on every size / top bar
  change (and the loading screen follows a replaced camera). Checked 10 screen sizes in a row (844x390, 667x375,
  932x430, 1024x768, 800x360, 1180x820, 740x360, 896x414, 1366x1024, back): covered every time, logo at 66 under the
  58 px top bar, no overlaps. (A first-frame crash in the new loading-screen code was caught and fixed in testing.)
- Right cards. Cause: Kit.UnderTopbar measured the column's AbsolutePosition, which reads 0 before the gui is laid out;
  when nothing re-measured it afterwards (no scale change, as on phones) the cards sat at ~8 px, over Daily / Quests /
  the gear. Now a frame placed straight in its ScreenGui (every Kit.Root) is measured from the gui's ScreenInsets, not
  its position: the drawer starts at TopbarInset.Max.Y + 8 (66 px) on PC and at 844x390; the tab moves with it. The
  "MAX GROWTH SPURT · Reached 7'0"" card is gone from the HUD at the cap (ProgressClient); Stats keeps its greyed button.
- Mirrors. The live reflection (MirrorClient: SurfaceGui + ViewportFrame + mirrored copies + a render-step loop) is
  deleted. Every mirror (the progress mirror's Glass, the MirrorPanel mirrors in the starter gym, pro gym and clothing
  store) is plain: SmoothPlastic #7D8B98, Reflectance 0.2, no transparency, no scripts (builders Mirror / GymKit match).
  The progress mirror's before / after card still works (it builds its own bodies; lit like the gym when it opens).
  Measured at the progress mirror (Studio, same spot): reflection ON render CPU 49 ms + GPU 16-20 ms a frame, ~11.5
  FPS; OFF render CPU 7.3 ms + GPU 2.4-7 ms, 15 FPS (Studio's window caps the FPS number; the render times are the
  real saving).
- Screenshots: screenshots/2026-10-15_{menu_before_logo_under_buttons, loading_pc_after, loading_phone_after,
  menu_phone_after, hud_before_max_card, hud_pc_right_after, hud_phone_right_after, mirror_card_still_works,
  mirror_wall_plain, mirror_progress_plain}.jpg. Still to check on a real phone: join several times and rotate.
