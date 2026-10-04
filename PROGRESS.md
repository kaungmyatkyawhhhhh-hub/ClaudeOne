# GYM ARC — Progress log

> ## Morning summary (steps 4–7 done overnight)
> Everything below was built and playtested with no errors in Output.
>
> **Do first (1 minute):** Lighting → Technology → **Future** in Properties (scripts can't set it; the gym looks
> too dark without it).
>
> **Test in this order:**
> 1. **Join** → the genetics reveal plays (plates slam onto a barbell, then the overall plate stamps down). VIEW ODDS opens the odds. REROLL, then KEEP.
> 2. **Lift** a rep anywhere → "New title: Beginner Gains" and the title appears above your head.
> 3. **TITLES** button → Title Book: tap an owned title to equip it; locked ones show "???".
> 4. **STATS** (side button) → labels float next to your body in 3D (left groups on the left, right groups on the right), elbow lines to your body; keep walking. Goal panel top. GENETICS is now its own side button (see "Two redesigns" below).
> 5. **Body:** your chest/arms are visibly thicker than your core (muscle levels scale your body; height = 4'0").
> 6. **Growth Spurt:** max every trainable muscle (long; tuned for ~15–20 min of lifting) → GROWTH SPURT button →
>    taller, muscles reset, "GROWTH SPURT!" moment. I tested this with a script and restored your save afterwards.
>
> **Needs your decision:** Calves/Obliques aren't trainable in the starter gym; the spurt goal ignores them for now
> (step 5). Badges for the big titles need ids from the Roblox website (step 6). The popup-fix request from before
> never reached me (step 0).
>
> **Not started:** menu screen + first-5-minutes onboarding, coach quests, spotting/arm wrestling.

All game code lives in this repo under `src/` and Rojo syncs it into the Studio place (GYM ARC,
placeId 80031260599632). Parts, models, lighting and `ReplicatedStorage.Remotes` are built in Studio.
Shared config: `src/ReplicatedStorage/Shared/Config`. Server: `src/ServerScriptService` (`Main` + `Server/`).
Client: `src/StarterPlayerScripts`. UI look: `src/ReplicatedStorage/Shared/UI/Theme.luau`.

---

## Clean minimal UI: brief + restyle check (2026-10-04) ✅ (needs a visual check)

**Built**
- Checked every screen's code against the clean minimal Theme: machine HUD, stats overlay + goal panel,
  genetics reveal, Title Book, settings, side menu, corner notifications, overhead titles. All of them already
  use Theme panels, buttons, Montserrat and normal-case text; no tape labels, marker font, Oswald or ALL CAPS
  remain. (The restyle had been finished before the session limit hit; only the brief was still old.)
- `docs/DESIGN.md` (the brief) rewritten to describe clean minimal: UI design system, crisp text, side menu,
  overhead title, machine HUD, genetics layout and stats label style now match what the code does.
- Tidied leftovers in code (comments and two variable names that still said Oswald/tape/marker). No behavior change.
- All 30 scripts pass a Luau compile check.

**How to test**
- `git pull` (Rojo syncs the 3 changed scripts). Play and look at: machine HUD, STATS overlay, GENETICS screen
  (+ View odds), Title Book, Settings, a corner notification, your overhead title. Everything should look the same
  as before: dark see-through panels, thin light borders, white/gray Montserrat.
- Device Emulator (phone landscape) on the same screens.

**Assumptions**
- The Theme module is the source of truth for the new look; the brief was updated to match it, not the other way.
- Side menu "new" dots are white (as coded), not red as the old brief said.
- Stamina turns soft red under 15% only (the old yellow-under-40% step is gone in the code).
- 3D-only colors (chrome bar and warm light in the genetics ViewportFrame, the legendary shine) stay as constants in
  their scripts: they are lighting/material values, not UI style.

**Not verified**
- I can't see Studio from the cloud, so this was a code review only. Tell me if any screen still looks old.

---

## Scripts moved into Rojo (2026-10-04) ✅ (needs the switch-over below)

**Built**
- All 30 scripts copied from the place export into `src/`, unchanged. Verified: a Rojo build of the repo gives the
  same 30 scripts, same types, same places and byte-identical code as the place.
- `default.project.json` now maps `src/ServerScriptService` → ServerScriptService,
  `src/ReplicatedStorage/Shared` → ReplicatedStorage.Shared, `src/StarterPlayerScripts` → StarterPlayerScripts.
- README, CLAUDE.md and the docs updated: edit code in `src/`, never in Studio.

**How to test**
- Back up the place first (File → Save to File As… → `GymArc-backup.rbxl` somewhere outside the repo).
- `git pull`, `rojo serve`, Connect in Studio. Accept Rojo's changes if it asks.
- Delete the leftover `ReplicatedStorage.RojoShared` folder in Studio if it is still there.
- Play: everything should behave exactly as before (genetics, lifting, stats, titles, settings), no new errors in Output.

**Assumptions**
- Nothing was added to the scripts in Studio after the 4 Oct export (anything newer would be replaced by the repo version).
- `ReplicatedStorage.Remotes` stays Studio-built (not synced), so the remotes are untouched.

**Leftovers to delete (couldn't remove them from the cloud session)**
- `src/server`, `src/client`, `src/shared` (old Rojo test placeholders, no longer synced) and `export/scripts`
  (duplicate of `src/`).

---

## Two redesigns (2026-10-04): stats world labels, 3D genetics reveal, depth on all 2D UI ✅

Playtested with no errors in Output. CLAUDE.md updated (UI depth rule, side menu Genetics icon, section 6
Genetics, section 8 Stats). Screenshots: `screenshots/` in this folder (stats-walking.jpg,
stats-walking-back-expanded.jpg, stats-behind-squat-rack.jpg, genetics-mid-animation.jpg, genetics-final.jpg,
title-book-depth.jpg, machine-hud-and-toasts-depth.jpg).

**1. Stats: world-space labels (`StatsClient`, rewritten)**
- Each group label is a BillboardGui next to its body part, sized in studs plus a pixel floor for phones. No box:
  Oswald name + grade disc, bigger level number under it, thin dark text stroke.
- Placed every frame in camera space: Shoulders/Arms/Core always to the camera's left, Chest/Back/Legs always to
  the right, slightly lifted. Each side is stacked with a minimum gap (never overlaps or crosses), stays below the
  goal panel, and slides up if it would run off the bottom of the screen.
- Short chalk elbow lines to dots on the body; label and dot positions are lerped (no jitter).
- "needs work" in small red marker under the weakest group only (hidden on a tie).
- Tap a label → its sub-muscle labels appear around that body part with their own lines; tap again to collapse.
- Labels are not AlwaysOnTop, so prompts always draw over them, and a label that would sit on a shown prompt fades
  out. Labels are drawn at 35% of the body's distance (scaled so they look identical) and a raycast pulls a label in
  front of any equipment/wall between it and the camera, so racks and bars never hide them.
- The GENETICS button moved out of stats into the side menu (DNA icon).

**2. Genetics reveal in 3D (`GeneticsClient`, rewritten)**
- No panel: the world is blurred (DepthOfField "GeneticsBlur") and dimmed 50%; movement stays frozen while open.
- 3D barbell in a ViewportFrame (chrome bar, collar, sleeve), warm light from above, 3/4 camera angle.
- Six 3D bumper plates (plate colors, darker rim, chrome hub); better grade = bigger diameter.
  They slide onto the sleeve and slam against each other: clank pitched by grade, camera shake, chalk puff on S.
- The overall grade is a big 3D plate that drops in with a deep thud and a bigger shake, then the marker reaction.
- Oswald name + multiplier under each plate; frame and body stay as tape labels.
- Reroll: plates slide off (outermost first), the hero lifts out, the new set slams on.
- No reroll left → REROLL becomes a solid gray "NO DNA TOKENS" block that can't be tapped.
- The screen sits to the right of the side menu so the hero plate never covers the buttons.

**3. Depth on all 2D UI (`Theme.AddDepth`, `Theme.Panel`)**
- Soft drop shadow (three faint strokes, fading out toward the top), a 1px chalk highlight on the inner top edge
  (a faint dark shade along the bottom of chalk buttons), the steel border slightly lighter on top, and faint
  rubber flecks on mat panels. Frames and strokes only, no images.
- Applied to: all Theme buttons and tapes, side menu buttons, stats goal panel, genetics odds panel, machine HUD
  panel, Title Book panel + title cards, corner toasts.

**Bugs found and fixed while testing**
- `Theme.Fade` lost its saved values for labels that no script kept a reference to (Luau collected the
  weak-table key), so those labels faded back in as invisible (stats names vanished after a prompt fade).
  Saved values now live in attributes on the instances. This affects every faded UI in the game, for the better.
- Depth pieces were shrunk by a panel's UIPadding (stray lines inside tapes); they now offset the padding.

**How to test**
1. Play, press STATS, walk around and spin the camera: six labels stay beside your body, left/right of it, no
   overlaps. Walk next to the squat rack with the camera behind it: labels stay in front of the rack.
2. Walk up to a machine: the prompt appears and any label under it fades; walk away and it comes back.
3. Tap BACK: Lats/Traps/Rhomboids/Lower Back appear with lines; tap again to collapse.
4. Press the GENETICS side button: blur + 3D bar, plates slam on one by one, the big plate thuds in. REROLL →
   plates slide off and a new set slams on. With 0 tokens and no free reroll the button says NO DNA TOKENS.
5. Check depth: Title Book cards, machine HUD panel, toasts have soft shadows under them.

**Assumptions**
- ViewportFrames only support one directional light + ambient, so the "soft rim light" is approximated with a
  warm key light from above plus ambient fill; there's no true rim light.
- Grade letters sit on each plate's front edge (2D text over the 3D plate): SurfaceGuis don't render in
  ViewportFrames, and plates pressed together hide each other's faces.
- Labels draw at 35% of the body's distance (min 2.5 studs from the camera) so props don't hide them.
- On very short screens with a group expanded, the goal panel wins and the lowest label may touch the bottom edge.
- `DataTemplate` currently gives new saves test values (coins 9999, DNA tokens 999, Growth Spurt 10). I didn't set
  or change these; reset them before launch.

**Placeholders:** the clank/thud reuse the existing plate clank sound at lower pitch (no custom thud sound).

---

## Fix batch (2026-10-04): genetics, crisp text, stats overlay, side buttons, overhead title, gym lighting ✅

All six parts done in order and playtested with no errors in Output. New rules were added to CLAUDE.md
(Crisp text, Side menu buttons, Overhead title, the Genetics layout/reveal, Stats: live overlay, and the Starter gym lighting/palette).

**1. Genetics screen (`GeneticsClient`, rewritten)**
- Layout:
  - Tape "YOUR GENETICS" top left, DNA tokens top right.
  - Big overall bumper plate on the left with "OVERALL" and the marker reaction (S "genetic freak?!" … D "hard gainer... respect").
  - Six tall rounded plates on a barbell, with height by grade (S tallest, D shortest), and the group name and multiplier under each.
  - Frame and body as two tilted chalk tapes with their bonus beside them.
  - The gray cards and the odds text are gone. The underlined VIEW ODDS link opens a clean odds panel (grade discs with %, frame %, body %).
  - REROLL is an outline button and KEEP is solid chalk.
- Reveal:
  - The bar slides in.
  - Plates slam on left to right, 0.15s apart, each with a clank (pitched by grade) and a tiny camera shake. S plates puff chalk dust.
  - After a pause, the overall plate stamps down with a deep thud, then the reaction fades in.
- Reroll: the plates fly off, the screen waits for the server's new genetics, then the new set slams on.
- Slots size to the screen width, so the screen fits a 667×375 phone with no text overflow (checked).

**2. Crisp text (whole game)**
- `Theme.Text` now always uses a whole-number TextSize ≥ 14 and never TextScaled.
- New `Theme.Fade` fades each element's own transparency. It replaces every CanvasGroup fade, since CanvasGroups render text as an image and blur it. Converted: machine HUD (now just slides up), toasts, Title Book, genetics, stats.
- No screen-wide UIScale. The rotated "needs work" note on the machine HUD is now flat. The only remaining tilted text is 18px marker on tapes.
- Toast text uses Theme sizes. The machine HUD's UNLOCK button now sizes its text to fit (a 4-digit cost would have overflowed).

**3. Stats = live overlay (`StatsClient`, rewritten)**
- No camera takeover, freeze, blur or dim, so you can walk and turn the camera while it's open. The old unused DepthOfField effect was removed from Lighting.
- Labels:
  - Six compact, semi-transparent labels in fixed spots: Shoulders/Arms/Core on the left, Chest/Back/Legs on the right. They fade in together (0.2s) and never move or hide.
  - Only the leader lines move. They're smoothed (lerped) and only update while the overlay is open.
- Anchors:
  - Shoulders and Arms → whichever arm is on the left of the screen.
  - Legs → whichever leg is on the right.
  - Chest, Back and Core → the torso.
- Numbers update live, including while lifting.
- "needs work" shows only on the single weakest group (no tie), beside its label.
- Tap a label to open its sub-muscles in a small list under it. The list floats over the labels below, so nothing shifts; one list is open at a time.
- The goal panel sits at the top center. The columns are placed so they never overlap it, even when the GROWTH SPURT button shows.

**4. Side menu buttons (new `Shared.UI.SideMenu`)**
- Style:
  - 64×72 buttons, 12px corners, #1A1A1A at 15% transparency, 1.5px #2E2E2E border.
  - Chalk line icon over a small Oswald label: new Flex (flexing figure) and Trophy icons in `Icons`.
- Behavior:
  - Active: chalk background with a dark icon and label.
  - Red dot top right: STATS when a Growth Spurt becomes ready, TITLES when you unlock a title. It clears when you open them.
  - Press shrinks to 0.95. Stacked on the left middle with 8px gaps.
- Only STATS and TITLES exist; Bag and Crew will be added when those features exist.

**5. Overhead title (`TitleService.updateTag` + new `OverheadTitleClient`)**
- The billboard is sized in studs and sits above the head and name. MaxDistance is 60.
- Style: Oswald ALL CAPS in the rarity color with a thin dark stroke and a tiny plate disc in front. No tape or box. Secret titles use chalk text on a black disc so they stay readable.
- Legendary titles get a slow shine sweep every 4s.
- Your own title is drawn at 75% size and 40% transparent.

**6. Starter gym: moody, not dark**
- Lighting:
  - Warmer, brighter Ambient/OutdoorAmbient and ExposureCompensation 0.3; lighter atmosphere.
  - Pendants are warm #FFC98A with range 32 and angle 120 (wide, soft pools), plus a faint glow so the ceiling isn't pitch black.
  - 8 soft fill lights along the walkways.
- Room:
  - Floor is charcoal rubber #2B2B2B.
  - The harsh white window panels are now frosted, high basement windows with mullions.
- Sign and mirror: the bench-row lamps hang 1.3 studs higher so they no longer block the GYM ARC sign. Mirror reflectance went from 0.65 to 0.35 and is darker, and the sign glow was reduced, so there's much less red in the mirror.
- New center free-weight zone: a mat with a chalk border, 3 utility benches with dumbbell pairs, kettlebells and 2 lamps.
- Plates: the five plates leaning on walls are gone. Two plate trees were added (back-left corner and next to the crunch bench).
- Palette is brick, charcoal/black, chalk and warm light, with the red sign as the only neon:
  - Posters are black or chalk.
  - Dumbbell heads, mats, foam roller, gym bags and rope handles are black.
  - Shake cups are chalk and the SHAKES text is chalk.
  - Machine pads went from oxblood to near-black leather.
  - Bumper plates keep their colors.
- New entrance hall around the spawn (brick, lamp, frosted closed street doors), so the doorway no longer shows the empty baseplate.
- Checked with a simulated low-brightness filter: walls, floor and machines still read. The center mat was lightened so the black benches don't disappear.

**How to test**
- Join (or reset `onboarding.geneticsRevealed`) → watch the slam reveal. Open STATS → GENETICS → REROLL to see the fly-off.
- Open STATS and walk around: labels stay put, lines follow you. Tap SHOULDERS: the sub-list opens without moving the other labels.
- Lift on a machine with STATS open: the numbers tick up.
- Look at another player (2-player local test server) to see their full-size title. Equip a Legendary title to see the shine.
- Device Emulator → a phone in landscape: genetics, stats, machine HUD.

**Assumptions**
- The machine pads and the decor were recolored to fit the palette. Bumper plates (on machines, trees and wall racks) keep their colors because they're the plate color system.
- The entrance hall is a stand-in until the town hub exists. It can be deleted then (`Workspace.Gym.StarterGym.Entrance`).
- "Needs work" sits beside the label instead of under it, so the labels never shift.

**Not verified / limits**
- I can't drive Studio's Device Emulator. Instead, I rendered the genetics screen and machine HUD inside a 667×375 phone frame and ran an automatic text-overflow check (none). The stats overlay was checked by layout math.
- The legendary shine was confirmed by data (the gradient sweep runs), but my screenshots didn't catch it mid-sweep.
- Still needs your one-time step: Lighting → Technology → **Future**.
- Your save was backed up before the reroll test and restored after (C overall, Wide, Lean, 0 tokens). Verified in a fresh playtest.

---

## Step 0 — Popup fixes + breath instead of grunt

**Built**
- Grunt sound removed everywhere. New `Breath` sound (Pro Sound Effects "Candles Blow Out, Airy Breath, Exhale", 0.6s):
  plays at lockout only on heavy tiers (185 lb+) or under 40% stamina, 50% chance, never on back-to-back reps.
- CLAUDE.md Game feel section updated: no grunts on any machine, soft exhale rule written in.
- Gain popups: smaller (28px main, secondaries at 72%), secondary muscles nudged left/right so the three popups
  don't stack on top of each other, shorter float/fade.

**How to test**
- Get on the Flat Bench, lift. Popups should appear at chest/arms, main one centered, the other two to the sides.
- Switch to 185 lb+ or drain stamina below 40%: you'll occasionally hear a soft exhale at the top of a rep.

**Assumptions**
- I couldn't find your "popup fixes" message anywhere in our conversation or in CLAUDE.md, so I made best-guess fixes
  (smaller, no overlap, quicker). **Needs your decision:** tell me what you actually wanted changed.

**Broken / not verified**
- My screenshot tool doesn't capture BillboardGuis, so I verified popups by data only (created, sized 200x34, correct
  text and offsets), not visually.

---

## Step 2b — All 8 starter machines + starter gym room ✅

**Built**
- Starter gym room (`Workspace.Gym.StarterGym`): wood floor, brick walls, ceiling with 6 warm lamps, doorway
  facing the spawn.
- 7 new machine models from parts (no toolbox): Incline Bench, Overhead Press (rack + platform), Crunch Bench
  (plate on a stand), Squat Rack (power rack with J-hooks + safeties), Deadlift and Barbell Row (bar on jacks on
  a platform), Pull-Up Bar (plate belt hangs on a peg). The Flat Bench moved into its slot.
  Front row: Flat Bench, Incline Bench, Overhead Press, Crunch Bench. Back row: Squat Rack, Deadlift,
  Barbell Row, Pull-Up Bar.
- `Config.Machines`: all 8 machines with muscles from CLAUDE.md and tiers: Barbell, HeavyBarbell
  (squat/deadlift up to 405) and Bodyweight (BW, +10 ... +90 for pull-ups and crunches; panel shows "BW", "+10").
- `Config.Poses` + server: lie / stand / hang placement. The pull-up height comes from the character's arm length.
- Client pose system: one animation per pose using the R15 root, waist, shoulders, elbows, hips, knees and
  ankles: bench/incline arm flare, squat (bar rides on the upper back), deadlift hinge, overhead press,
  bent-over row, pull-up (body rises, plate belt at the hips), crunch (curl with knees up).
- The overhead-grip arm twist and angles were tuned by measuring hand positions in a playtest.

**How to test**
- Play, walk into the gym, use each machine (E / tap the prompt), tap to lift. Check that each pose looks right
  and the bar or plates stay in the hands, on the back (squat) or at the hips (pull-up belt).

**Assumptions**
- Pull-ups and crunches use bodyweight + added plates as their "weight tiers" (belt plates / plate on chest).
- Squat and deadlift go up to 405 lb; the other barbell lifts stop at 315 lb.
- Every rep starts and ends at the top (lockout). For pull-ups and crunches the rest position is the top
  (chin over bar / curled up), so the timing rules match the other lifts.
- Stamina cost: 6 for squat/deadlift, 4 for crunches, 5 for the rest.

**Broken / needs your decision**
- Poses are blocky approximations (Roblox R15, no custom animations). The hands sit ~0.6 studs under the
  pull-up bar at the top. They read fine, but a real animator would do better.
- Gains are not yet tuned for the 15–20 minute first Growth Spurt; that happens in step 5.
- Still open: Calves and Obliques can't be trained in the starter gym (see step 5).

## Step 3 — Theme + stats inspect mode ✅

**Built**
- Theme ("gym materials") was done earlier. Stats is now an in-world inspect mode (`StatsClient`), replacing the
  ViewportFrame screen, per your rework request. CLAUDE.md section 8 was rewritten to match.
- STATS button (chalk outline, left side) is always on screen. Opening tweens the camera (0.5s) to orbit in front of
  your real character, freezes movement, hides the machine panel, and adds a soft DepthOfField blur + slight dim.
- Drag/swipe orbits the camera (pitch clamped −20°..35°, smooth easing). EXIT (or STATS again) flies back.
- Labels: the 6 groups by default as dark 40%-transparent chips with chalk Oswald text, a big level number and a
  plate grade disc. Tap a group to expand its sub-muscles; tap again to collapse. Tap a sub-muscle for a card
  (level, grade, machines that train it) and a brief chalk highlight on that body part.
- Layout: side-and-sort with balancing (even columns), no overlaps, sorted by anchor height so lines never
  cross, thin chalk elbow lines. Muscles facing away from the camera are hidden.
- Weakest group chip outlined red; "needs work" tape under the weakest group (or the weakest muscle when its
  group is open).
- Also fixed: Studio playtests now take over a stale session lock immediately. Quick stop/start used to leave
  you on temporary, unsaved data for 5 minutes. Live servers keep the strict lock.

**How to test**
- Walk into the gym, press STATS. Drag left/right/up/down. Tap CHEST → Upper/Mid Chest appear. Tap MID CHEST →
  card + highlight. Turn around: Back shows up, Chest/Core hide. EXIT → camera returns, you can walk again.
- Check it on a phone in the Device Emulator. I could only test PC size; columns clamp to the screen edges.

**Assumptions**
- Only one group expands at a time (tapping another group switches).
- The bottom strip of 6 boxes from the old spec was dropped: the group chips around the body replace it, and
  the weakest group is outlined on its chip.
- Group dots sit at the average of that group's visible muscles. Arm/leg muscles anchor on the right limb.

## Starter gym fit-out ✅

**Built** (`Workspace.Gym.StarterGym`: Shell, Windows, Pendants, WallDecor, Props; layout written into CLAUDE.md)
- Room shrunk to 56x44, ceiling 13 with beams, pipes and ducts. Black rubber tile floor. Brick walls, 6 high windows.
- Zones: entrance (front desk, shake machine, fountain, chalkboard, cat bed), rack area on the left wall (squat,
  OHP, deadlift, row, all turned to face into the room), bench row facing the full mirror wall, pull-up/dip
  corner, dumbbell rack, stretching area. Clear center aisle.
- Wall decor: mirror wall, neon "GYM ARC" sign, 5 original text-only posters, Muscle of the Day chalkboard
  ("coming soon" until step 8), wall plate racks, hooks with belts and jump ropes, leaning plates.
- Lighting: 12 warm pendant spotlights with shadows, window light, neon glow, Atmosphere haze, softer bloom,
  warm `GymGrade` ColorCorrection, sun rays off.
- Plates are now bumper colors with chrome hubs; idle bars show a mix of loads/colors.
- ~340 parts total for the whole gym.

**Needs you**
- **Set Lighting → Technology to Future** in the Properties panel. Roblox blocks scripts from setting it. Until
  then the floor looks very dark, because the pendant spotlights barely light floors in the current lighting mode.

**Assumptions**
- The stretching area is tagged `Recovery = "StretchMat"` for the faster stamina refill later; it does nothing yet.
- Posters are text-only (no images) so nothing is copyrighted.



## Step 4 — Pump + body scaling ✅

**Built**
- `Server.BodyService` (server, so every player sees it):
  - Height from Growth Spurts via Roblox's BodyHeightScale (4'0" = 0.8 ... 7'0" = 1.4; 60 inches = 1.0).
  - Each group thickens its body parts as it levels: Chest/Back widen and deepen the UpperTorso, Shoulders add
    torso width + upper-arm thickness, Arms thicken upper/lower arms, Legs thicken legs, Core widens the
    LowerTorso. Up to +35% at the level cap. Joints (e.g. shoulders on a wider torso) and attachments
    (accessories) move with the parts so nothing detaches. Refreshes every 1.5s.
- Pump (client, from the Game feel step) now grows from the server's scaled size (`BaseSize` attribute), so
  the two don't fight.

**How to test**
- Lift until a group levels: that body part slowly thickens. Compare chest (level 25) vs core (level 0).

**Assumptions**
- Size is relative to the current Growth Spurt's level cap, so after a spurt you're taller but start thin again
  (muscles reset, as the brief says).
- Veins/abs/delt detail at high levels (section 14) isn't done: it needs texture/decal art. Placeholder: none.

**Note**
- Testing added XP to your dev save's Biceps/Triceps/Forearms (now about 24/40/24).

## Step 5 — Growth Spurts ✅

**Built**
- Goal: every group must reach the next spurt's level (50, 100, 175, 275, 400, then +150 each). Your level cap
  is that same number, so you reach the goal when all your trainable muscles are MAXED.
- `PlayerData.GrowthSpurt` (server-validated, via the new `PlayerAction` remote + `Server.ActionService`):
  muscles reset to 0, spurt count +1, +1 DNA Token. You get taller (BodyService rescales live, no respawn), and
  the permanent gains bonus (x1.25, x1.5, ...) applies through Gains.
- Inspect mode has a goal panel at the top: next spurt + height, 6 chunky blocks filling per group (yellow when
  met), "x/6 GROUPS AT LV n · GAINS xN AFTER", and a chalk GROWTH SPURT button when ready.
- Ready signal: a yellow dot on the STATS button + one corner notification.
- The moment: "GROWTH SPURT!" tape strip, chime, chalk burst, "You're now 4'6". Gains x1.25 forever!"
- Gains tuned toward the 15–20 minute first spurt: XP per level = 6 + level (1525 XP to reach 50), BaseXp 7.
  Math: 16 trainable muscles × 1525 = 24,400 XP. At ~1.1 s/rep with stamina breaks that's ~740 reps in 17 min,
  i.e. ~33 XP per rep across all trained muscles. This is an estimate: **please playtest the timing.**

**How to test**
- Lift on all 8 machines; open STATS to watch the goal fill. When ready, press GROWTH SPURT: you get taller,
  muscles reset, the panel moves to the next goal.
- I tested a full spurt by maxing muscles with a temporary script, then restored your save from a backup.

**Needs your decision**
- **Calves & Obliques:** no starter machine trains them, so the goal only counts muscles you can train right
  now (starter gym: Legs = Quads/Hamstrings/Glutes, Core = Abs). The stats chips still show the full average,
  so Legs/Core look lower than "met". Alternative: move Calf Raise + Cable Woodchop into the starter gym.
- Weight unlocks stay unlocked after a spurt (the brief doesn't say to reset them).

## Step 6 — Titles ✅

**Built**
- `Config.Titles`: 16 titles with data conditions (adding a title = adding an entry):
  Beginner Gains (first rep), Gym Rat (1,000 reps), Lock In (50-rep set), Glow Up (all groups 25+),
  Skipped Leg Day / Chicken Legs (chest/arms 2x legs), Boulder Shoulders (1.5x other groups), Greek Statue
  (all within 10%, 30+), Aesthetics God (all 45+), Late Bloomer (first spurt), Skyscraper (7'0"), Genetic Freak
  (S overall), Hard Gainer (D overall), Defied Genetics (max a D-grade group), Spotter (locked until spotting,
  step 9), No Days Off (secret: 500 reps in one visit).
- `Server.TitleService`: counts reps and sets (new `stats.totalReps` / `stats.bestSet` in the save), checks
  conditions after every validated rep, on join and after a Growth Spurt, grants titles, auto-equips your
  first one, and can award a linked badge.
- Equipped title shows above your head as a chalk tape strip (Permanent Marker) with a rarity disc.
- TITLES button under STATS opens the Title Book: rarity-ordered tape cards, locked ones show "???" with their
  rarity color, tap an owned title to equip (tap again to unequip). Corner note on unlock.

**How to test**
- Do one rep → "New title: Beginner Gains". Open TITLES, tap a title to equip; look at your head.

**Needs you**
- Badges: the biggest titles (Aesthetics God, Skyscraper, Defied Genetics) have a `badgeId = nil` slot. Create
  the badges on the Roblox website (I'm not allowed to) and paste the ids into `Config.Titles`.

**Assumptions**
- Cardio King and the legend physique titles aren't included: there's no cardio and no Legend NPCs yet.
- Physique titles use the full group levels (including untrainable Calves/Obliques), so Greek Statue and
  Aesthetics God can't be earned until those muscles are trainable (pro gym).
- Your dev save got Skipped Leg Day + Beginner Gains during testing.

## Step 7 — Genetics reveal / reroll ✅

**Built** (`GeneticsClient`, plus `Reroll` / `GeneticsSeen` actions in `Server.ActionService`)
- First join: the reveal opens automatically. The 6 group grades flip over one by one as bumper plate discs
  (with a tick sound and x-multiplier), then frame and body type (with what they do, generated from the config),
  then a big overall grade with a chime.
- Odds are always visible on the screen (grades per group, frame, body type, computed from the config weights).
- REROLL uses the free reroll first, then 1 DNA Token (server-validated), rerolls everything at once and replays
  the reveal. KEEP closes it and marks the reveal as seen (new `onboarding.geneticsRevealed` in the save).
- Inspect mode has a GENETICS button (bottom-left, with your overall grade disc) to reopen it any time.
- Movement is frozen and taps are blocked while it's open.

**How to test**
- Join: the reveal plays (your save is reset so you see it). Try REROLL (free), then KEEP.
- Open STATS → GENETICS to see it again; REROLL is greyed out with 0 DNA Tokens.

**Assumptions**
- DNA Tokens come from Growth Spurts for now (daily streak / store come later).
- Existing saves see the reveal once too (the flag is new).
- Your dev save was restored after testing (overall A, free reroll still available).
