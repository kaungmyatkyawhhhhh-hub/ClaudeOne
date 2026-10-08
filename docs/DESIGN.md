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
- Text: white #FFFFFF for main text, gray #B8B8BE for secondary text. Sentence case for body text; titles and button labels are UPPERCASE.
- Fonts (`Shared.UI.UIFonts`, owner's fonts brief): Oswald Bold for headings, titles, numbers, grades, stats and
  buttons; Nunito (Regular / SemiBold) for body text. Never Montserrat or Gotham. No other fonts (except the side menu
  tile labels), no handwritten/marker fonts, no tape labels.
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

## Side menu tiles (left middle) and top bar (UI v7, replaces the old 64x68 buttons)
- A 2-column grid of about 90px square tiles on the left edge, vertically centered, 8px gaps (smaller only on short screens
  so all fit). Each tile: a big white icon, a bold label at the bottom with a dark outline (Fredoka One: the one place that
  is not Oswald / Nunito), 10px corners, a colored border per tile, a slight 3D look (lighter top, darker bottom edge) and a
  bounce on hover and press. Tiles: Stats, Muscles, Titles, Genetics, Poses, Crew, Wardrobe (Store when monetization is on).
- Active tile: brighter face and a white border. Small white dot top-right when something is new; clears when opened.
- An arrow tab on the tiles' right edge (level with Genetics) slides them all out to the left and back, like a drawer (it
  points right while folded, waiting at the screen edge, left while open; a small dot on it while folded when a tile has something new). Tiles about 68px on PC (0.75x), 60px on phones.
- Phones: no grid. The same tiles sit under the coins pill at the top left, clear of the thumbstick; they start
  folded, fold again after picking one, and never share the screen with a side panel.
- Top bar (under the Roblox top bar): rounded pills with an icon and text. Coins on the left; Quests, Daily Reward and
  Settings on the right (icon only on narrow screens and phones). Hidden on the main menu, while training and behind full-width panels.
- Colors, icons and optional image ids for all of these live in `Config/HudIcons`; look tokens in `Theme.Tile`.

## Overhead title
- BillboardGui sized in studs (scales with distance), just above the head and the player's name, MaxDistance ~60.
- No box: Oswald in the rarity color with a thin dark text stroke and a tiny plate disc in front.
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
- Training tint (owner, 8 Oct; replaces the warm rep flash on the body): the whole time someone is on a machine, every
  muscle it trains is tinted RED, about RGB 255, 70, 70 (owner, 8 Oct night; was cool blue) (main ~55%, secondaries
  ~30%), soft edges, shading kept, both sides of the body; fades in 0.25 s / out 0.4 s. Each rep a quick ~0.2 s brighter
  (lighter red) pulse on top (BIG REP / PUMPED stronger). Muscles under the gym shorts keep the shorts. Same on the
  forearm / calf stages, NPCs on machines (their body parts) and the mirror. Stats hover is red too and wins while both.
  (The body-map widget still flashes warm.) Setting "Rep flash: On / Off" turns the rep pulse off.
- EXP popups (owner, 8 Oct): every rep a small popup per trained muscle around you: the muscle group's color chip
  (`Config/HudIcons.MuscleGroups`) + its real EXP ("+112", "+1.2K"); main bigger and warm red-orange, secondaries smaller
  and green, PUMPED / BIG REP gold; pop in with a bounce, drift up and out at random angles, fade over 0.8 s; at most 8 at
  once (the oldest go). Client only. Setting "Show EXP popups" On / Off (default On; Off = the old single "+N").
- Machine sign + prompt (owner, 8 Oct night, `MachineSignsClient`; replaces the flat card and Roblox's wide "Use" panel):
  only the NEAREST machine within 12 studs shows a floating glass diamond above it: a square slab turned 45 degrees, dark
  tinted glass (~0.3 transparent, matte: no reflections, owner 9 Oct) with a thin glowing white Neon border, a slow gentle bob, turning smoothly toward the
  camera (a 3D object). Above it the machine name (big bold white Oswald, dark stroke). Inside: our own white body icon
  (`Shared/UI/BodyFigure`) with the main muscle in red, the main muscle's name in bold white and its share in red ("53%").
  Main muscle only (the machine HUD shows the full split after you sit down). Below it the prompt: a small square
  dark-glass key ("E" on PC, the gamepad button, a tap button on touch) and "OCCUPY" under it ("UNLOCK · 45 COINS" when
  your next weight can be bought); the machines' ProximityPrompts use the Custom style, 10 studs. A glowing white
  rectangle (thin Neon strips, 0.05 high) on the floor around the machine's footprint, brighter while you stand inside it.
  Locked machines: a lock + "Growth Spurt N". Hidden while you're on a machine; the diamond also while the camera is
  within 4 studs. From 12 to 60 studs only the bouncing yellow "!" + "NEW" for machines you never did a rep on
  (`machinesUsed` in the save); nothing beyond. 0.2 s fades. One set of sign parts moved to the nearest machine.
- Machine look (owner, for map work): worn dark metal (DiamondPlate / Metal, darker, slightly rust-tinted), very dark
  padded seats (Fabric or SmoothPlastic), chunky realistic frames, no brand names (the plates' own "M WEIGHTS" stays).
- Muscle highlight (hovering a stat label): the muscles turn red (a tint on the normal material, no neon glow), only
  the ones facing the camera (fades out as a muscle turns away), so hovering Back from the front lights nothing.
- Chalk puff from the hands when getting on a machine; sweat drop particles under 25% stamina.
- The machine panel stays compact and low so it never covers the lift.

## 1. Muscles (18, in 6 groups)
Each sub-muscle has its own level. Group level = average of its sub-muscles (for the Growth Spurt goal and logic);
the EXP shown for a group is its muscles ADDED UP (Core = Abs + Obliques), and a group's goal is shown as the same sum.
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
Barbell Row (Rhomboids; Lats, Rear Delts, Biceps), Crunch Bench (Abs; Obliques),
Leg Press (Quads; Glutes, Hamstrings) and Hack Squat (Quads; Glutes, a light touch of Calves): plate-loaded, the sled /
carriage slides on its rail with the rep; 2 of each in the starter gym, 1 of each in the pro gym. A secondary under 20%
(the hack squat's calves) gains EXP but doesn't put that muscle into the Growth Spurt goal.
Every plate carries the gym brand "M WEIGHTS" on both faces (above the hub, a shade of the plate color); plates are
thin like calibrated plates so the heaviest tier fits the sleeves, with a collar at the end. The Muscles panel lists
each group's exercises.
Pro gym (unlocks at Growth Spurt 2): Dips (Mid Chest; Triceps, Front Delts), Lateral Raise (Side Delts),
Reverse Fly (Rear Delts; Rhomboids; on a pec deck, not a cable), Shrugs (Traps; Forearms), Leg Curl (Hamstrings), Hip Thrust (Glutes; Hamstrings),
Calf Raise (Calves), Bicep Curl (Biceps; Forearms), Tricep Pushdown (Triceps), Hanging Leg Raise (Abs; Forearms),
Cable Woodchop (Obliques; Abs).
Players only see muscle names on machines, never percentages.
Each machine has weight tiers (empty bar → max) unlocked by muscle level; plates visibly stack.

## 3. Gains formula
gains per rep = machine weight tier × genetics grade × frame/body bonus × Growth Spurt bonus × shake/server boost × diminishing factor
- Diminishing: higher muscle level = slower growth (weak muscles catch up fastest).
- Balanced bonus: small passive bonus if all 6 groups are close together.
- No cap on muscle levels or stats: a muscle keeps growing the more you train it (diminishing returns slow it down). The Growth Spurt only asks each group to reach its goal.
- Cap total stacked multipliers (around 5x max).

## 4. Stamina
Each rep uses stamina. Refills fast on its own; faster at recovery stations (stretch mat, foam roller, sauna);
instantly with an Energy Shake. Petting the gym cat = tiny refill.
Treadmills train stamina (owner, 8 Oct): running gives no muscle EXP; the distance run raises max stamina. All treadmills are the premium model (3 in the starter gym, 4 in the pro gym); the runner does a real running cycle on its own clock, its stride rate and size following the belt speed (owner, 8 Oct night).

## 5. Energy Shakes
Bought with coins (smoothie bar) or earned. Refill stamina + 50% gains for 30s. Flavors are cosmetic only.

## 6. Genetics (rolled on first join)
- Each of 6 groups gets a grade: D 0.75x (15%), C 0.9x (25%), B 1.0x (30%), A 1.2x (20%), S 1.5x (10%).
- Frame: Narrow (+10% Arms, 25%), Average (+5% all, 35%), Wide (+10% Back & Legs, 25%), V-Taper (+10% Shoulders & Lats, 15%).
- Body type: Lean (abs/detail show earlier, 33%), Balanced (+5% all, 34%), Stocky (abs later, +15% Legs/Back/Traps, 33%).
- Overall grade D-S shown on player card. One free reroll at start; +1 DNA Token per Growth Spurt.
- Reroll changes everything at once. Odds must be reachable on the reroll screen ("VIEW ODDS" panel).
- Opened from the Genetics side menu button (and automatically on first join). Its own dark 3D stage (client only,
  far above the town) seen by the real camera, so plates are real 3D parts with SurfaceGui letters and real shadows;
  movement is frozen and the side menu, top bar and right column step aside while it's open.
- Look: plates are wide and thin (all the same thickness; better grade a little wider), stepped bevel edge, raised
  rim, inset ring, chrome hub. Printed like a competition bumper plate on both faces, bold white: "M WEIGHTS" curved
  tight across the band above the hub (filling it) and upside down below it, the grade letter at 9 o'clock (upright)
  and 3 o'clock (turned 180), as big as the brand's letters and centred on the hole's height. No group name on the face (the label under the plate names it). Colors are the rank-tag colors
  made deeper (`Theme.GradePlates`). Loaded tight in grade order (best on the inside), a collar closes the sleeve.
- Scene (a real gym, not sci-fi): the bar rests on two black J-hook stands over a wooden olympic lifting platform (light
  wood centre, black rubber sides, steel edge) on dark rubber floor tiles with faint seams; the overall plate stands on
  its rim on a short black plate tree (scaled to it). Behind, out of focus (depth of field, far intensity 0.6): a dim
  brick wall with a squat rack, a dumbbell rack and plates leaning on the wall (`ReplicatedStorage.GeneticsSet`, baked
  by `tools/builders/GeneticsSet`). No particles, sparkles, neon signs or floating shapes.
- Light and shadows: one warm overhead spotlight on the platform is the only light with shadows; a faint fill, a cool
  rim and a dim warm glow on the back wall; the rest stays dark. Contact shadows replace the real ones on low graphics.
- Layout: the overall plate stands on the floor in the left part of the screen, placed and sized from the camera (about
  42% of the screen height, less where it doesn't fit), "Overall" and its word about 1.4x bigger under it. The bar group
  (bar ~28 degrees from straight-on; the camera looks down only ~8 degrees so the plates show a little top edge, tunable
  in Studio with the CamPitch / CamHeight attributes on `ReplicatedStorage.GeneticsCameraRig`; bigger plates packed tight with a steel microplate between every
  two) fills the right part. One row of labels: each right under its own plate (projected every frame), stacked name /
  grade circle in the plate's color / multiplier, all scaled down together when neighbours would touch (never 2 rows).
  One shadow source: real key-light shadows, or contact shadows on low graphics. The frame card has a small silhouette.
- DNA: a cyan and a magenta strand (opposite phase) with base-pair rungs every ~0.3 studs in the A/T/G/C colors (red,
  yellow, green, blue), glowing Beams plus three soft colored lights along the bar; one turn every 6 seconds.
- Spin: the plates turn slowly with the bar (one turn every 20 s), the overall plate on its centre (every 25 s); both
  pause during the reveal and ease back in over a second.
  Title "YOUR GENETICS" ("NEW GENETICS" after a reroll), DNA tokens top right (owner's call: caps here).
- Reveal (under 3 s): plates slide onto the sleeve about 0.2 s apart, best grade first, each with a clank (pitch by
  grade, small camera punch); S plates get one shine sweep. Then the collar, then the overall plate drops in with a
  thud and its word fades in. Tap / click (or Space) skips to the end.
- Meaning: one clean row of labels under the bar on ONE shared soft dark rounded panel (black, 55% see-through, 12px
  corners and padding, re-wrapped around the row every frame, faint dividers between labels):
  group name (white Oswald), the grade letter circle (2px ring in the grade color, dark fill) and the multiplier
  ("x1.50", white), all with a soft dark outline; "Overall" white too; nothing cut off at the edges. Tap / hover a plate for a small card ("Chest genetics
  A" / "Your chest grows 20% faster" + frame / body bonuses on that group). Frame and body type are two cards
  ("Frame: Narrow · +10% Arms"), centered, wrapping to two rows on phones. Overall word under the overall plate,
  capitalized, no "!": S "Genetic Freak", A "Blessed", B "Gifted", C "Average", D "Hardgainer".
- Reroll (secondary button, shows its cost: "Reroll · free" / "Reroll · 1 DNA token"; dimmed "No DNA tokens" when
  there is none) replays the reveal: plates that got better show a green up arrow + "upgrade", worse ones a small
  gray down arrow. A good roll (overall A or S, or any S plate) asks first, inline: "Replace your A genetics? You
  can't get them back." Keep = primary. A small underlined "View odds" link opens the odds panel.
- Sounds (placeholders until the owner picks ids): GeneticsClank, GeneticsShimmer, GeneticsThud, GeneticsThudLow.

## 7. Growth Spurts (rebirth system — never call it "sacrifice")
Players start at Growth Spurt 0, short (4'0"; owner, 9 Oct release). When all 6 groups hit the goal, Growth Spurt: muscles reset to 0, character gets taller,
permanent gains bonus. Example: 1 → 4'6" lvl 50 1.25x; 2 → 5'0" lvl 100 1.5x; 3 → 5'6" lvl 175 1.75x;
4 → 6'0" lvl 275 2x; 5 → 6'6" lvl 400 2.5x. Height caps ~7'0"; later spurts still give bonuses.
First Growth Spurt should be reachable in ~15-20 minutes.

## 8. Stats (final design)
- **Stats button = labels in the world.** Pressing it shows your stats as labels around your character (like the
  reference game); pressing it again hides them. Hidden by default. Thin white lines from small white dots on the body to
  each label; a label is a small dark see-through box with the name on top (white) and the number under it (light
  blue-white, with commas). Strength (total of all muscle levels) and Stamina above the head; the six groups around the
  body: Chest, Core, Legs on the camera's left, Shoulders, Back, Arms on its right. A maxed group shows its EXP like any
  other (no "Max" text). Compact (the whole set about 40% of the screen height), the same size on screen at any camera distance, stable
  while walking/jumping, never hidden behind walls, never over a machine's "E / Use" prompt.
  The labels lean a little with the camera's turn speed (yaw up to ~12 degrees, pitch ~8, half on phones, none with
  Reduced Motion) on a spring that settles flat; faked in 2D (the backing narrows and shades, box and text shift) so the
  text never rotates or blurs. Left and right columns lean opposite ways.
- While the labels are shown, a small **Muscles** button sits at the bottom center (above the machine panel while
  lifting). It opens the "Your muscles" panel.
- **"Your muscles" panel:** title, Growth Spurt bar + height + "x/6 groups at level y · gains x1.50 after", six group
  cards (grade badge, name, EXP, "Genetics x1.20", each muscle with a bar and its EXP, "Needs work" in soft
  red on the weakest group when there is no tie). On top of everything, the rest of the HUD is switched off behind it,
  everything fits (the cards scroll on short screens; one or two columns on phones). Close: X, Esc or a tap outside.
- **On a machine: a small body-map widget** slides in at the right (front and back silhouettes made of muscle shapes,
  glowing by level, gold outline when maxed, the muscles the machine trains pulse; Level + a small Growth Spurt bar).
  A "-" button folds it into a chip. It slides away when you leave. The highlight clears when you leave, switch machine,
  respawn or die. Proportions: torso 3 heads, legs 3.5, arms end at mid-thigh, about 1.4x wider than the old figures, a
  V from the shoulders (the player's frame width) to the waist. Each rep flashes the trained muscles warm on it too (main
  stronger, ~0.15s in / 0.35s out). Tapping it opens the Muscles panel.
- Phones: the labels step aside while lifting on short screens (the widget shows the stats then). Numbers update live.

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
Arm wrestling (Biceps, Forearms, Front Delts + tap speed; animated on every client, `ArmWrestleClient`: elbows on the pads, clasped hands swing with the meter, the winner slams and pumps a fist), spotting (see "Spotting" below), workout-together bonus,
crews (up to 8, tags, crew leaderboard), emotes (flex poses, high five, shake chug), statue of the strongest player,
wall leaderboards per muscle group (crown for #1), membership card (Bronze→Diamond), progress mirror,
shareable before/after snapshot.

## Spotting (owner's redo, 8-9 Oct; `Config/Spotting`, `SpotService`, `SpotClient`)
- Tap / click a lifter's body: a small popup "SPOT" / X. The lifter gets a small card "<name> wants to spot you"
  (ACCEPT / X, closes after 8 s); "Spot requests: On / Off" in Settings. Up to 5 spotters; more get "Spot full".
- Machine spot types (`Config/Machines` spotType): "hands" on the flat / incline bench, squat rack and overhead press
  (1 = middle, 2 = left + right, 3 = + middle, 4 = two each side, 5 = + middle; hands under the bar, following it each
  rep), "hype" on everything else (a loose half-circle in front of the lifter, clap / point / fist pump), none on cardio.
  Spots: attachments Spot_Left1/2, Spot_Right1/2, Spot_Middle, Hype_1..5 on every machine (`tools/builders/SpotPoints`).
- Boost (the lifter's gains) by spotter count: x1.10 / 1.20 / 1.30 / 1.40 / 1.50, plus 0.15 x (clicking spotters /
  spotters) (all clicking: 1.25 ... 1.65). Clicking = about 3+ pushes a second, stops ~1 s after; at most 8 count a
  second, perfectly even timing is ignored (auto-clickers).
- The spotter pushes by clicking / tapping ANYWHERE on the screen (owner, 9 Oct: no push button; F on a keyboard), with a
  segmented meter and EXIT; moving or jumping stops spotting too. The lifter sees "SPOTTED x1.35" (gold) and the
  spotters' names beside them, next to the EXP popups. Spotter reward: coins only, every 10 lifter reps (more while
  clicking). The lifter leaving releases everyone. All checks on the server.

## Bodies and muscles (v4)
- Everyone (players, NPCs, statue, mirrors) has the Robloxian 2.0 body (Roblox bundle 311, ids in `Config/Body`); the player's own body is always replaced, shapes are the same for all except the shoulder width from the genetics Frame (Narrow 0.9x, Average 1x, Wide 1.1x, V-Taper 1.2x: UpperTorso width + arms moved out, the muscle meshes taper back to the normal waist so it reads as a V). Head, face, hair, hats, face accessories, skin color and animations stay theirs. Nobody wears Back, Front or Neck accessories (owner, 8 Oct night: capes, backpacks, guitars, scarves hide the muscles): `AccessoryService` removes them from every player, NPC, legend and the statue on spawn, outfit change and body rebuild.
- Golden ratio proportions (muscle_v8 manifest "proportions"): torso (neck base -> navel) : legs (navel -> ankle) =
  1 : 1.618 at the same total height. Everything from the ankle to the navel is x1.08 taller, from the navel to the neck
  base x0.893; feet, head and arm length stay (they ride on the joints). Applied to every Robloxian rig on top of the
  Growth Spurt height (`Config/Body.Proportions`, `BodyShape.ApplyProportions`); muscles and the snatched torso follow
  their part's size, HipHeight grows with the legs, no gaps.
- Smooth borders at uneven levels: a border vertex follows its neighbouring muscles by the data's blend weights
  (g_v = (1 - sum w) * g_own + sum(w * g_other)), so a maxed muscle next to a flat one is a smooth slope.
- Unified muscles (muscle v9, 8 Oct): the torso and the upper arms are each ONE welded mesh (the whole skin of the part;
  per muscle a vertex list and its displacement): pos = base + waist morph + sum(look g x displacement) + veins, so any mix
  of levels (one muscle huge, the rest 0) is smooth with no holes. The torso's top opening is closed by a low dome; the
  torso grows the traps itself (the package's separate upper traps shell is NOT used: it floated over the chest). The
  legs are shell meshes that cover the whole thigh (quads, hamstrings, glutes + their shorts), forearms and calves are the
  static stage meshes. The arms and legs show from level 0 and every plain body part under a mesh is hidden, so no
  blocky Robloxian part shows. The waist tightens with the average growth.
- Max = a lean aesthetic V-taper (fitness model, not a bodybuilder); the mass monster sizes come from the manifest
  (mass_monster.g per mesh) plus 12% extra thickness.
- Widths by Growth Spurt (`Config/Body.Widths`, manifest growth_spurt_width): factor = 1 + k * (height / 4'0" - 1) per
  region (shoulders with the genetics frame on top, hips, arms, legs, torso depth); k goes from skinny (narrow
  shoulders and hips, thin arms and legs; shoulders k 0.4 -> 1.15 -> 1.4, always wider than the hips) to the maxed V-taper smoothly with the muscle progress and on to the mass monster;
  the hips (k 0.2 -> 0.7 -> 1.2) widen the LowerTorso, the shorts and the leg positions together, and the waist meets
  the LowerTorso at the same width. Lying poses are
  lifted by the extra torso depth so the back stays on the pad.
- Muscles are real EditableMesh muscles (muscle v9 unified): they wear the character's own classic Shirt/Pants (skin shows through see-through parts of the clothing; under layered 3D clothing they hide), each muscle's outline stays on the skin and only the bulge rises with its level (small pump on every 10th level, a Growth Spurt shrinks them). Aesthetic: V-taper, round delts, peaked biceps, clear abs.
- Only YOUR character has LIVE muscle meshes: a play client holds at most 8 EditableMeshes (a hard count, measured 8 Oct
  night: small, fixed-size and asset copies all count) and a mesh's MeshPart shows nothing once its EditableMesh is gone,
  and your body uses 7 (torso front + back, two upper arms, two upper legs, the waist). Other players, NPCs, the statue
  and the mirror's day-one body wear STATIC body stage meshes (owner, 8 Oct night; `Shared/BodyStages`,
  `Config/BodyStages`): per region (torso, upper arms, thighs with their gym shorts, waist) 7 stages (look 0, 0.2 .. 1.0,
  mass monster) made from the same muscle data, coordinates and UVs, so Shirt / Pants map the same way; each client picks
  the stage from the replicated `MuscleG` look values (the region's muscles averaged) and cross-fades on a change.
  Everyone's forearms / calves are the static stage meshes.
- Skin texture stages (`Config/SkinStages`, ReplicatedStorage.SkinStages Stage1..5, the owner's 15 images in the group
  inventory): the skin (muscle meshes and body parts not under the character's own clothing) wears a SurfaceAppearance
  tinted to the skin color: Stage1 at level 0, Stage2 about half, Stage3 at the full look, Stage4 then Stage5 through the
  mass monster stage, switching at the midpoint between two stages (with a little hysteresis). Under a SurfaceAppearance
  vertex colors don't show, so the hover highlight / rep flash on skin is a thin color layer over the mesh (a mask written
  once, faded by the layer's transparency); the thighs' gym shorts are on that layer too (matte Fabric).
- Shorts: under the shorts the thigh / glute muscles grow like fabric over muscle (about half the bulge; full growth on
  the bare lower thigh, one smooth curve so the hem sits flush). No ring, no puffy tube.
- Progress mirror (live reflection on the glass + the before / after card): shows YOUR front, facing you, flipped
  left / right like a real mirror, with your exact muscles (copies of your live muscle meshes), skin color and stage,
  clothing and accessories, moving with your pose and animation. While it shows, your meshes' vertex colors are opaque
  ("mirror mode": skin tints pause), because a ViewportFrame would draw the color layer's see-through alpha.
- The look (`Muscles.LookG`, by EXP compared with the current Growth Spurt goal): reaching the goal does not max the
  look (about two thirds); 2x the goal's EXP = the full aesthetic look; from 2x to 5x the muscles grow on to their mass
  monster size (muscle_v8 manifest `mass_monster.g`, veins come in with it); past 5x the look stays, the stats keep going.
- No look balance cap (removed 8 Oct, the unified meshes have no holes at uneven levels): each muscle's look is its own
  look value (plus pump).
- Performance (8 Oct): every change to an EditableMesh costs the engine ~40 ms of a frame whatever its size, so muscle
  meshes change rarely: a look moves in steps of 0.015, one body region per frame, tints fade with a part property; body
  parts under muscle meshes don't pump by size.
- Default look: shirtless with game shorts; the Wardrobe has Top (Shirtless/Tank/Sports) and shorts colors.

## 14. Visuals and feel
Pump effect (trained muscle temporarily bigger), body part scaling per group, veins/abs/delt detail at high levels,
trendy gym fits, skateboard, area music, satisfying weight sounds. Gym cat, NPC gym-goers (one of them, Dante in the pro gym, is a 7'0" mass monster; owner, 9 Oct), re-racking plates.
Pro gym (looks clearly better than the starter gym, realistic, not cluttered): darker premium interior, charcoal rubber floor with a tile grid, chrome free-weight racks on wood lifting platforms, a mirror wall across the back, linear LED ceiling lights and LED strips, spotlight pools over the machines, a smoothie bar corner (counter, back bar with a drinks fridge, stools) by the glass door, clean hanging zone signs (FREE WEIGHTS, MACHINES, CARDIO, STRETCH, SMOOTHIE BAR), Future lighting, light bloom/haze.
Starter gym: warm, old-school, brick walls.

## Starter gym layout (built)
- Size (8 Oct night, ~1.5x the floor area): starter 88 x 85 studs (x -44..44, z -89..-4), ceiling 16 (dark, exposed pipes/ducts/beams); pro gym 68 x 85 (x 45..113), ceiling 18; the shared glass wall at x 44.5. The layout keeps its zones; `Gyms.Map` spreads every spot (wider walkways, more room between machines). Door in the middle of the front wall.
- Floor: black rubber tiles everywhere; lifting platforms (wood center, rubber sides) under the squat rack,
  deadlift and barbell row.
- Zones, with a clear center aisle from the door to the bench row:
  - Entrance: front desk (right of the door) with towels, shake machine (left of the door), water fountain,
    Muscle of the Day chalkboard next to the desk, cat bed for the gym cat by the desk.
  - Rack area along the left wall, lifters facing into the room: Squat Rack, Overhead Press, Deadlift,
    Barbell Row. Wall plate racks between them, chalk bowl in front. The plate trees stand together in the back-left
    corner (owner, 8 Oct night: out of the walkway between the racks and the platforms).
  - Bench row facing the full mirror wall (back wall): Flat Bench, Incline Bench, Crunch Bench.
    Neon "GYM ARC" sign above the mirror.
  - Pull-up/dip corner (back right): Pull-Up Bar + dip station.
  - Dumbbell rack along the right wall; stretching area (mats, foam rollers, kettlebells) in the right middle.
- Walls: brick, original text-only motivational posters, hooks with belts and jump ropes, plates leaning
  against walls, small high windows with soft light.
- Lighting: Future lighting, warm hanging industrial pendants over each station with shadows between them,
  window light, the neon sign as an accent, subtle Atmosphere haze, light bloom, warm ColorCorrection.
  Lighting pass (owner, 9 Oct, `tools/builders/GymLighting`): tight bright pendant pools, small black wall-washer can
  lights grazing the brick (west and back walls); in the pro gym brighter tight spotlight pools with the fills turned
  down, neutral wall washers on the east and back walls.
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
The beach gym (opens at Growth Spurt 1) has NO machines of its own (owner, 8 Oct night): copies of the real machines
(same model, name, config, tiers, EXP and MachineId, so unlocked weights, the "NEW" tag and quests are shared with every
gym); only the surroundings are beachy. A copy opens with the beach gym, never later than its own gym
(`Machines.GymOpenAt`, model attribute `Gym`). No "Pro" copies in the pro gym either.
Start (owner, 9 Oct: as good as the genetics screen): a loading screen from the first frame (ReplicatedFirst): a dark
room with one soft overhead light and faint chalk dust drifting up, the GYM ARC title, and a BARBELL that loads as the
game loads: bumper plates in the grade colors (heaviest inside) slide onto both sleeves pair by pair with a clank, the
collars close, and when full the bar is lifted with a bounce before it fades; the step and a short rotating tip under
it. It stays until the area behind the menu has streamed in (RequestStreamAroundAsync, ~8s max; the gym building,
front and entrance are Persistent models) and the other players' stage meshes are in ("Loading players", 8 s max).
Menu: a slow cinematic tour (MenuClient PLACES): the entrance (the MenuCamera part in Gym.Entrance), the starter gym,
the pro gym, the beach gym, the skate park, each a slow dolly with soft depth of field, dissolving through black, a
small caption naming the place (never sky or baseplate). On the left over a dark fade (black, never colored): the big
GYM ARC title, a thin white rule, "Everyone starts tiny.", for returning players a profile (genetics grade badge, name,
membership, Growth Spurt + height, equipped title in its rarity color), a solid white PLAY button that breathes (a soft
glow) and catches a light sweep, TITLES / SETTINGS, small chips (streak, offline coins, Muscle of the Day); the rows
slide in one after another. Play: from another place it dips to black back to the entrance, the camera glides in
through the door to behind the character, then the HUD fades in.
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
