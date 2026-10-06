# GYM ARC — Roblox Gym Game (project brief)

Read this first. It is the agreed design from planning. Build exactly this; ask before adding features.
Working title: GYM ARC (tagline: "Everyone starts tiny.").

## Working style
- Don't stop to ask me questions unless you're truly blocked.
- If something is unclear, make the best choice based on this file and keep going.
- At the end of each step, list any assumptions you made so I can review them.
- Finish the whole step before stopping, then tell me exactly how to test it.
- One build step at a time. Don't start the next step until I say the current one works.

## Audience and style rules
- Players are mostly kids, many on mobile. Keep systems simple, big buttons, one-tap machines.
- Use REAL muscle and exercise names, but keep mechanics simple (plain level stats, no percentages shown).
- Must feel PREMIUM, not slop and not "AI-looking" (see UI design system below).
- No free toolbox models (backdoor risk + mismatched look).
- No big pop-ups. Notifications are small, in a corner, and fade out.
- No real people's names/likeness (no influencers, no lookalike/off-brand names). Original characters only.
- No dieting, calories or body-weight mechanics.
- CUT features (do not add): form-timing minigame, personal-record popups, power outage event, pets, space gyms.

## Technical rules
- Server-authoritative: all gains, coins, purchases validated on the server. Client only sends intent via RemoteEvents.
- Save all player data with DataStoreService (one table per player), with retries and session handling.
- Use a menu screen to cover data loading time.
- Modular code: shared config ModuleScripts for muscles, machines, titles, genetics, so adding content = adding a table entry.

## UI design system: "clean minimal" (ALL UI must follow this)
- One shared Theme ModuleScript (`Shared.UI.Theme`). Every UI reads from it. No hardcoded colors/fonts anywhere else.
- Panels: dark see-through (#0E0E10 at 55% transparency) with a thin 1px white border at 85% transparency.
  No glossy effects, no colorful gradients, no textures.
- Depth (via Theme.AddDepth / Theme.Panel / Theme.Button): a soft dark drop shadow under panels and buttons
  (stacked faint strokes, lighter toward the top). Frames and strokes only (no images) so it stays crisp.
- Corners: panels and buttons 10px, bar segments 3px, plate discs and icons fully round.
- Text: white #FFFFFF for main text, gray #B8B8BE for secondary text. Normal sentence case, no ALL CAPS.
- Font: Montserrat only, in three weights: Light (big calm numbers), Regular (normal text), SemiBold
  (important numbers and button labels). No other fonts, no handwritten/marker fonts, no tape labels.
- Color only means something: bumper plate colors for weight tiers, grades and rarity. Everything else is
  white/gray on dark.
- Progress bars are chunky segmented blocks (like stacked plates), not thin smooth bars.
- Grades and rarity use real bumper plate colors, shown as plate discs (circle with darker rim):
  D/common white #F4F1EA, C/uncommon green #2E9E4F, B/rare yellow #E8C21C (dark text),
  A/epic blue #1F5FBF, S/legendary red #D7262E. Secret titles: black plate #141414.
- Soft light red #FF8A8A marks "needs work" and very low stamina.
- Text over the 3D world gets a subtle dark outline (Theme.TextShadow) so it stays readable.
- Buttons: Primary = white fill at 85% transparency with a light border; Secondary = the dark see-through panel
  style. White SemiBold label, min 44px tall for mobile. Press = shrink to 0.95 with a very soft click.

## Crisp text (no blur, whole game)
- Minimum text size 14px. Whole-number TextSize only (Theme text sizes); no plain TextScaled in screen UI.
  (Only world-space UI may scale text: BillboardGuis sized in studs and SurfaceGuis on signs/posters.)
- Never use UIScale to scale whole screens (a press-shrink on a single button is fine).
- Don't rotate containers that hold text.
- Don't fade screens with CanvasGroups (they rasterize and blur text). Fade by tweening each element's
  transparency (Theme.Fade).

## Side menu buttons (left middle)
- 64x68, 10px corners, dark see-through panel style with the thin light border and soft shadow.
- White line icon (same style for all) above a small gray Montserrat label: Stats = flexing figure,
  Titles = trophy, Genetics = DNA strand, Settings = gear, Bag = gym bag, Crew = two people. No emojis.
- Active: the open menu's button gets a faint white fill, a brighter border and a white label.
- Small white dot top-right when something is new; clears when opened.
- Press = shrink to 0.95. Stacked vertically on the left middle, 8px gaps.
- Only show a button once its feature exists (Bag and Crew come later).

## Overhead title
- BillboardGui sized in studs (scales with distance), just above the head and the player's name, MaxDistance ~60.
- No box: Montserrat SemiBold in the rarity color with a thin dark text stroke and a tiny plate disc in front.
  Secret titles use white text (their plate is black).
- Legendary titles get a subtle slow shine every few seconds.
- The local player's own title is smaller and ~40% transparent so it never blocks their view.

## Machine HUD (shown while on a machine)
- Machine name in white SemiBold just above the panel (left aligned, text shadow).
- Weight selector: +/- buttons (line icons), big SemiBold weight number, "lb · tier N" in gray under it.
- Barbell graphic: plates use the bumper plate color for the current weight tier.
- Muscles this machine trains, in small muted text under the barbell.
- Stamina: chunky segmented white bar (10 segments); soft light red under 15%.
- Rep counter for the current set ("Reps ×12").
- "Exit" button instead of an X. Coin icon = simple white outline plate icon.
- Coach note: one small gray line under the panel (not rotated), based on the situation
  (low stamina, weight too light, first set, etc). 15+ short, original, funny lines. No famous quotes or
  real people's catchphrases. Changes at most every few sets, never every rep.
- Panel slides up when getting on a machine; stamina segments tween.
- Spacing scale 4/8/12/16/24 using UIPadding and UIListLayout/UIGridLayout. Never position by eye.
- Sizing: Scale-based with UIAspectRatioConstraint/UISizeConstraint; UITextSizeConstraint instead of
  plain TextScaled. Respect top bar and mobile safe areas.
- Motion: TweenService 0.2-0.3s (Quad Out) for menus; nothing pops in instantly.
- No emojis. Icons are simple white line icons only.
- Clean HUD while training: stamina bar, stats button, a few small icons. Everything else lives in menus.
- Test every screen in Studio's Device Emulator (phone, tablet, PC).

## Game feel (lifting must feel satisfying)
- Instant feedback: play the rep animation and effects on the client immediately on tap. The server still validates and applies gains.
- Weighty motion: lowering ~0.6s with ease-in-out, pressing ~0.35s with ease-out, 0.1s pause at lockout.
  Heavier tiers are slightly slower. Under 40% stamina, add arm shake and slow the press.
- The bar is attached to the hands and moves with the arms. Proper elbow bend using the R15 joints.
- Sounds: plate clank at lockout with random pitch (±5%), deeper for higher tiers; soft tick on rep count;
  a soft, short breath exhale at lockout only on heavy tiers or low stamina, never every rep.
  No grunts on any machine.
- Gains: per rep ONE small BillboardGui popup with only the main muscle's gain number ("+12", no muscle name),
  offset to the side of the chest so it never covers the bar (its whole path) or the face; pops in with a Back-out bounce, floats up and fades. No popups for secondary
  muscles: instead the muscle list in the machine HUD briefly flashes. Never stack popups: a new one replaces the
  old one. No "+N" numbers in the corner of the panel.
- Pump: the trained body part scales up slightly each rep with a small bounce, then slowly settles over time.
- Camera: tiny FOV punch on lockout for heavy tiers only.
- HUD: rep number bounces on increase, the drained stamina segment flashes, barbell plates jiggle on heavy reps.
- Every 10 reps: "set complete" beat with a chime, chalk puff particles and one slightly bigger
  "Set done · +[total] Chest" popup (total of the set's main-muscle gains, the main muscle's group name), replacing
  the rep popup. No big pop-up window.
- Setting "Gain numbers: On / Minimal / Off" in Settings: On = rep + set popups, Minimal = set popups only,
  Off = no gain popups (the chime, chalk and HUD flash stay). Default On, saved per player.
- Chalk puff from the hands when getting on a machine; sweat drop particles under 25% stamina.
- The machine panel stays compact and low so it never covers the lift.

## 1. Muscles (18, in 6 groups)
Each sub-muscle has its own level. Group level = average of its sub-muscles.
- Chest: Upper Chest, Mid Chest
- Shoulders: Front Delts, Side Delts, Rear Delts
- Back: Lats, Traps, Rhomboids, Lower Back
- Arms: Biceps, Triceps, Forearms
- Legs: Quads, Hamstrings, Glutes, Calves
- Core: Abs, Obliques

## 2. Machines (main muscle 100% + secondaries at ~30-60%)
Starter gym: Flat Bench (Mid Chest; Front Delts, Triceps), Incline Bench (Upper Chest; Front Delts, Triceps),
Squat Rack (Quads; Glutes, Lower Back), Deadlift (Lower Back; Hamstrings, Glutes, Traps, Forearms),
Overhead Press (Front Delts; Side Delts, Triceps), Pull-Up Bar (Lats; Biceps, Rear Delts),
Barbell Row (Rhomboids; Lats, Rear Delts, Biceps), Crunch Bench (Abs).
Pro gym (unlocks at Growth Spurt 2): Dips (Mid Chest; Triceps, Front Delts), Lateral Raise (Side Delts),
Reverse Fly (Rear Delts; Rhomboids), Shrugs (Traps; Forearms), Leg Curl (Hamstrings), Hip Thrust (Glutes; Hamstrings),
Calf Raise (Calves), Bicep Curl (Biceps; Forearms), Tricep Pushdown (Triceps), Hanging Leg Raise (Abs; Forearms),
Cable Woodchop (Obliques; Abs).
Players only see muscle names on machines, never percentages.
Each machine has weight tiers (empty bar → max) unlocked by muscle level; plates visibly stack.

## 3. Gains formula
gains per rep = machine weight tier × genetics grade × frame/body bonus × Growth Spurt bonus × shake/server boost × diminishing factor
- Diminishing: higher muscle level = slower growth (weak muscles catch up fastest).
- Balanced bonus: small passive bonus if all 6 groups are close together.
- Muscle level cap per Growth Spurt stage ("MAXED" glow when reached).
- Cap total stacked multipliers (around 5x max).

## 4. Stamina
Each rep uses stamina. Refills fast on its own; faster at recovery stations (stretch mat, foam roller, sauna);
instantly with an Energy Shake. Petting the gym cat = tiny refill.

## 5. Energy Shakes
Bought with coins (smoothie bar) or earned. Refill stamina + 50% gains for 30s. Flavors are cosmetic only.

## 6. Genetics (rolled on first join)
- Each of 6 groups gets a grade: D 0.75x (15%), C 0.9x (25%), B 1.0x (30%), A 1.2x (20%), S 1.5x (10%).
- Frame: Narrow (+10% Arms, 25%), Average (+5% all, 35%), Wide (+10% Back & Legs, 25%), V-Taper (+10% Shoulders & Lats, 15%).
- Body type: Lean (abs/detail show earlier, 33%), Balanced (+5% all, 34%), Stocky (abs later, +15% Legs/Back/Traps, 33%).
- Overall grade D-S shown on player card. One free reroll at start; +1 DNA Token per Growth Spurt.
- Reroll changes everything at once. Odds must be reachable on the reroll screen ("VIEW ODDS" panel).
- Opened from the Genetics side menu button (and automatically on first join). No panel behind it: the world
  is blurred (DepthOfField) and slightly dimmed; movement is frozen while it's open. Content stays clear of the
  side menu.
- Layout: "Your genetics" title top left, DNA tokens top right. The overall grade is the hero: a big 3D
  bumper plate on the left with "Overall" and a short reaction line under it
  (S "genetic freak?!", A "blessed!", B "solid start", C "grind time", D "hard gainer... respect").
- The six groups are real 3D bumper plates on a 3D barbell (ViewportFrame, chrome bar, warm light from above,
  3/4 camera angle). Plates are in the plate colors with a darker rim; better grades have a bigger diameter
  (S biggest, D smallest). The grade letter sits on each plate's front edge (2D text over the 3D plate, because
  SurfaceGuis don't render in ViewportFrames). Group name + multiplier under each plate.
  Frame and body type are two plain text lines ("Frame: Wide") with their bonus in gray beside them.
  Small underlined "View odds" link opens a clean odds panel. Reroll = secondary button, Keep = primary.
  When no reroll is available, Reroll turns into a dimmed "No DNA tokens" button (not tappable).
- Reveal: the empty bar is there; each plate slides onto the sleeve and slams against the last one, left to right
  (~0.15s apart), with a clank (pitch by grade) and a small camera shake; S plates puff chalk. After a pause the
  big overall plate drops in from above with a deep thud and a bigger shake, then the reaction line fades in.
  On reroll the plates slide off the bar (outermost first) and the hero lifts out, then the new set slams on.

## 7. Growth Spurts (rebirth system — never call it "sacrifice")
Players start short (~4'0"). When all 6 groups hit the goal, Growth Spurt: muscles reset to 0, character gets taller,
permanent gains bonus. Example: 1 → 4'6" lvl 50 1.25x; 2 → 5'0" lvl 100 1.5x; 3 → 5'6" lvl 175 1.75x;
4 → 6'0" lvl 275 2x; 5 → 6'6" lvl 400 2.5x. Height caps ~7'0"; later spurts still give bonuses.
First Growth Spurt should be reachable in ~15-20 minutes.

## 8. Stats window (replaced the live world labels, "stats v5")
- Nothing floats around the player in the world any more (no labels, lines or dots). Only the overhead title stays.
- The Stats button opens one window with two panels side by side, on top of everything: the rest of the HUD (quest
  panel, goal bar, notes, menu) is switched off behind it. Close with the X, Esc, or a tap outside the window.
- LEFT, "Your muscles": the Growth Spurt goal (and its button when ready), then the six group cards with grade badge,
  genetics multiplier, level and muscle bars. "Needs work" marks the weakest group only, and only when there's no tie.
  Levels at the cap show "Max" in soft gold. The cards always fit their muscles; the area scrolls on short screens.
- RIGHT, a body viewer ("Front" / "Back" title + toggle): a copy of the player's own character (their clothes, hair,
  accessories) in a ViewportFrame + WorldModel, centered and lit, facing you. Labels with thin lines to a small dot on
  the muscle, on both sides of the body, alternating down the body so lines never cross. Front: Chest, Shoulders,
  Biceps, Forearms, Abs, Obliques, Quads, Calves. Back (smooth 180° turn): Traps, Lats, Rhomboids, Lower Back, Rear
  Delts, Triceps, Glutes, Hamstrings, Calves. Each label: muscle name + level. Dragging turns the body a little and it
  springs back. Hover (PC) or tap a label to light up its row on the left, and the other way around.
- Phones and narrow screens: the two panels become two tabs ("Muscles" | "Body").
- Dark minimal style, color only for grade badges and "Max". Numbers update live while open.

## 9. Titles
Kept forever, one equipped above head, title book shows locked ones as "???" with rarity colors.
Never purchasable. Biggest ones linked to Roblox badges. Categories: physique patterns (Aesthetics God,
Boulder Shoulders, Skipped Leg Day, Chicken Legs, Greek Statue, etc.), activity (Gym Rat, Cardio King),
Growth Spurt (Late Bloomer, Skyscraper), genetics (Genetic Freak, Hard Gainer, Defied Genetics),
social (Spotter), trend slang (Lock In, Glow Up), legend physiques, and secret titles.
Conditions compare muscle groups (ratios) with a minimum level.

## 10. Legend NPCs (original characters only)
Spawn every 20-30 min for 3 min. One-time quest + reward, "Legends Met" list, matching physique titles.
Examples: Chad Gainsworth, Brody Pumpkins, Tank McFlex, Kyle Swole, Ricky Reps, Big Beefington, Tiny Tim Gains, Lance Lats.

## 11. Economy and retention
One currency (coins): from reps, quests, re-racking weights, arm wrestling, daily rewards.
Spent on shakes, weight unlocks, cosmetics, skateboard upgrades, DNA Tokens.
Offline gains (cap ~8h). Daily streak (missing a day only drops a few days back; DNA Token every 7th day).

## 12. Quests and events
Coach NPC quests, Muscle of the Day (2x one group, shown on a board), rush hour every 30 min,
seasonal events (summer beach, Halloween gym, winter sled pulls).

## 13. Social and showing off
Arm wrestling (Biceps, Forearms, Front Delts + tap speed), spotting (bench/squat), workout-together bonus,
crews (up to 8, tags, crew leaderboard), emotes (flex poses, high five, shake chug), statue of the strongest player,
wall leaderboards per muscle group (crown for #1), membership card (Bronze→Diamond), progress mirror,
shareable before/after snapshot.

## 14. Visuals and feel
Pump effect (trained muscle temporarily bigger), body part scaling per group, veins/abs/delt detail at high levels,
trendy gym fits, skateboard, area music, satisfying weight sounds. Gym cat, NPC gym-goers, re-racking plates.
Pro gym lighting: dark walls/floor, Future lighting, spotlight pools over machines, neon LED strips, light bloom/haze.
Starter gym: warm, old-school, brick walls.

## Starter gym layout (built)
- Size: 56 x 44 studs, ceiling 13 (low, dark, exposed pipes/ducts/beams). Door in the middle of the front wall.
- Floor: black rubber tiles everywhere; lifting platforms (wood center, rubber sides) under the squat rack,
  deadlift and barbell row.
- Zones, with a clear center aisle from the door to the bench row:
  - Entrance: front desk (right of the door) with towels, shake machine (left of the door), water fountain,
    Muscle of the Day chalkboard next to the desk, cat bed for the gym cat by the desk.
  - Rack area along the left wall, lifters facing into the room: Squat Rack, Overhead Press, Deadlift,
    Barbell Row. Wall plate racks between them, chalk bowl in front.
  - Bench row facing the full mirror wall (back wall): Flat Bench, Incline Bench, Crunch Bench.
    Neon "GYM ARC" sign above the mirror.
  - Pull-up/dip corner (back right): Pull-Up Bar + dip station.
  - Dumbbell rack along the right wall; stretching area (mats, foam rollers, kettlebells) in the right middle.
- Walls: brick, original text-only motivational posters, hooks with belts and jump ropes, plates leaning
  against walls, small high windows with soft light.
- Lighting: Future lighting, warm hanging industrial pendants over each station with shadows between them,
  window light, the neon sign as an accent, subtle Atmosphere haze, light bloom, warm ColorCorrection.
- Moody, not dark: warm Ambient/OutdoorAmbient raised a little, slightly higher ExposureCompensation, no
  pitch-black areas. Floor is dark charcoal rubber (~#2B2B2B) so light pools show. Pendants warm (~#FFC98A) with
  wide, soft pools spilling onto the floor; soft fill lights along walkways. No harsh white panels.
- Palette: brick, charcoal/black, chalk white, warm light, one neon accent (the red sign). Bumper plates keep
  their colors because they mean something. Plates live on plate trees and racks, never scattered on the floor.
- Windows are frosted high basement windows with soft light (never show the empty baseplate outside).
- Lamps never block the neon sign; keep the sign's reflection on the mirror subtle.
- Equipment: bumper plates in the tier colors on every bar (idle bars show a mix), chrome bars, J-hooks and
  safeties on racks, padded benches with visible legs.
- Props: chalk bowl, water fountain, towels, kettlebells, fan, speakers, trash cans, gym bags, cat bed.
- Performance: whole gym ~340 parts, simple shapes, small props don't collide or cast shadows.

## 15. World, menu, onboarding
Town hub: starter gym, pro gym, beach gym + posing stage, skate park, smoothie bar, clothing store.
Menu: gym camera pan, player character, Play, Titles, Wardrobe, Crew, Settings, offline gains/streak/Muscle of the Day info.
NO shop on menu. New players get a simplified menu.
First 5 minutes: genetics reveal → first lift (bench) → Beginner Gains title → stamina + free shake → squat rack
→ stats (inspect mode) → first quest → Growth Spurt goal shown. Taught with glowing paths and one-line coach messages.
No shop/gamepass prompts in the first 5 minutes.

## 16. Monetization (fair, never forced)
Gamepasses: 2x Gains, Auto Lift, Iron Lungs (bigger stamina), Fast Recovery, Shake Fridge, Gene Lock, VIP Gym.
Dev products: DNA Tokens, shake packs, Server Boost (2x for whole server 30 min, buyer named on a board).
Cosmetics, private servers. Everything paid is also earnable free. No fake urgency.

## Build order
1. Player data: 18 muscles, stamina, coins, genetics, height, titles, saving
2. One reusable machine script (config table per machine)
3. Theme module + stats inspect mode
4. Pump effect + body scaling
5. Growth Spurts
6. Titles
7. Genetics reveal/reroll screen
8. Coach quests + Muscle of the Day
9. Spotting + arm wrestling
Launch small but polished (starter gym, training, genetics, Growth Spurts, titles, stats); add the rest as updates.
