# GYM ARC — Progress

Short and current (13 Oct 2026). Full history: `git log -p -- PROGRESS.md`. Code map: `docs/GAME_OVERVIEW.md`.

## Rules
- No growth spurt cooldown. (Owner, 14 Oct: a player can do the next Growth Spurt as soon as they've earned it; checked:
  there is no timer, time check or config value for it anywhere, and the Skip Growth Cooldown product is removed.)

## 14 Oct: FINAL UI KIT "BLACK + GOLD" (owner's GYM_ARC_UI_final.md + gym_arc_ui_final mockups), screen by screen
- 1. Store (the reference frame) + the shared kit. Theme: graphite panels (vertical gradient #252226 -> #18161A ->
  #0D0C0E, 1px top hairline, soft dark edge, 14px), cards #232023 -> #141215 with a top highlight and a darker lip (11px),
  Montserrat Black Italic display font (GothamBlack has no italic face in Roblox; Montserrat's is built in and matches),
  Montserrat Medium body. Buttons: CTA Red / Gold (bevel, glossy top lip, dark lip, soft colored glow, diagonal shine
  streak that sweeps once when a window opens, Theme.Pulse every 1.6 s); every other style is quiet dark; inactive tabs
  FLAT; hover 1.04 / press 0.96. Kit.Modal: TITLE + tabs inside the panel header, coins pill (spec.coins) + quiet X on
  the right; 90% size, a soft dark vignette + light blur so the gym shows; the HUD coin counter hides while a window is
  open. Kit.Bar fat outlined + metallic fill, Kit.PricePill, Kit.GoldText, gold rank plates (Kit.GradeBadge).
  Store: hero tile (gold border + glow, BEST SELLER on Monetization.BestSeller = AutoLift, big art, gold name, red
  R$ CTA that pulses) + 3-column grid with price pills; OWNED = rotated gold stamp, tile art / name dimmed.
  Studio preview: Workspace TestStoreAll = true shows every item. Screenshots: ui_compare_final/04_store_*.
  Note: every window picks up the new materials now; the next steps fit Quests, Coaches, Physique, HUD, Lifting, title.
- 2. Quests (mockup 05): tabs DAILY / STREAK / GOALS. Rows: icon tile, quest in big italic caps, teal bar, gold coin
  reward; ready = gold border + glow, gold tile, red CLAIM (pulses); in progress = dark "1 / 2" pill (tap = where to go);
  claimed = faded + teal DONE. The swap button is a small badge on the tile. Right: ALL 3 BONUS card (big gold count,
  gold bar, bonus coins, CLAIM, "Resets in"). The small calendar left the Daily tab (Streak has it). Claims fire
  Kit.CoinBurst (coins fly to the counter + a gold sparkle burst). Window 620 wide. Tested a real claim (chest reps).
  Also: owner's music edit synced from Studio (each area back to one song, the owner's choice).
- 3. Coaches (mockup 06; the Trainers window, title COACHES, coins pill in the header): portrait in a dark box, the perk
  big ("+5%" + small "EXP"); coaching = tile 7% bigger, gold frame + glow, gold perk, "COACHING"; owned = quiet EQUIP;
  locked = gray veil + lock + coin price pill. Bottom: "Tap a coach to hire or swap · 1 / 1 active" + gold
  "R$ 99 · 2ND SLOT" CTA (pulses). Tested on a FreshPlayer save with TestCoins (hired two, one coaching).
- 4. Physique (mockup 07; the Stats window): title PHYSIQUE, tabs MUSCLES / LIFTS / GENES, LABELS ON/OFF next to the X.
  Left: body card on a dark red glow, big gold "71%" + PHYSIQUE / AESTHETIC (TAP TO GROW gold CTA takes its place when a
  spurt is ready; the old Growth Spurt row is gone). Right: the six groups best first, gold grade plate (Kit.GradeBadge),
  fat metallic bar in the grade color (S red, A gold, B teal, C gray), %. Forearms / Calves cards dropped (mockup).
- 5. HUD (mockup 01): left menu = dark glass tiles (graphite gradient, faint light border, white line icons, the Shop's
  gold, small italic caps labels, plain red dots; open panel = gold border). Top bar: bold italic caps (DAILY, QUESTS),
  "LVL 45" + a small gold bar toward the next level, plain red dots. Right column: tracker cards with body text and a
  plain teal bar (TODAY'S QUEST 1/3); the GROW tile is now a wide button: gold TAP TO GROW + "GROWTH SPURT N READY"
  (pulses) when ready, quiet "GROWTH SPURT N · 62%" before, "MAX HEIGHT" at 7'0". Bottom: the STAMINA panel (teal
  lightning, "250 / 250", fat teal bar; soft red when low). Fixed on the way: the level bar must be parented in Kit.Bar.
- 6. Lifting (mockup 02, MachineHud): the weight card top right (machine name + red muscle tag, quiet - / + squares,
  "315 LB", "Tier 12 / 12", BEST WEIGHT in gold text), the PUMP panel (gold flame, %, metallic gold bar; full = glow +
  "TAP TO PUMP!"), the big red "REP x3" CTA bottom right, a quiet "x STOP" bottom left (no longer above the stamina
  panel, HudBottom.TrainingRowLift 0). AUTO TRAIN sits under the card (only while Auto Lift is on sale).
- 7. Title screen (mockup 00, MenuClient): one graphite panel on the left (GYM white / ARC red logo, "Everyone starts
  tiny.", the red PLAY CTA with a pulse and one shine, gold SHOP + quiet UPDATES with the red news dot, a divider, the
  player row: headshot, name, "Level 46 · 7'0"", coins); bottom right a NEW tag with the newest update's name (opens the
  update notes). Loading screen unchanged.
- Settings: new "Reduce Motion" row (settings.reduceMotion On/Off): stops the UI's looping pulses and shines.
- Loading screen (mockup 00_loading): the logo IMAGE (Config/UI.Logo 84167052331251, uploaded from
  gym_arc_ui_3d_icons/logo.png; the title menu uses it too), gray tagline, the tip in a graphite tile with a gold TIP tag,
  "LOADING PLAYERS" heavy italic + gold percent, thick metallic red bar in a dark track, page dots (gold = current tip),
  quiet SKIP.
- Top bar = TopbarPlus v3.4.0 (ForeverHD, official Creator Store model 92368439343389, only the Icon module kept in
  ReplicatedStorage.Packages, unedited; READ_ME example script deleted). Shared/UI/TopBar wraps it (AddPill: Daily,
  Quests, Settings with notice counts), TopBarClient makes Coins / Height / Level; Height folds away when the icons don't
  fit. Our old TopBar ScreenGui is gone. Kit.UnderTopbar / Kit.OnTopbar: the right column, toasts, the weight card, the
  record banner, posing and arm wrestling headers start at TopbarInset.Max.Y + 8. Studio: the TestPhoneSize attribute is
  cleared (it squeezed the HUD inside the Device Emulator). Fixed a stray "5" typed into Analytics in Studio (it stopped
  the whole server from starting).
- Declutter (owner, 14 Oct): the right column shows ONE compact card (176 wide) by RightColumn.Priority: TAP TO GROW
  ready 100, posing competition 95, coach quest ready 80, today's quest 50, legend 40, coach quest going 20, Growth
  Spurt progress 10 (cards keep their own Visible = "wants to show"; CardPriority attribute). No MAX HEIGHT card. Stamina
  is a slim 280x34 bar 10 px from the bottom. Left menu: always centered (no top offset), no Quests tile (QUESTS is on
  the top bar; 8 tiles max), folds while a window is open (WindowOpen). Zone notes once per visit (60 s). Machine "!"
  markers only within 25 studs. No coach lines on screen while lifting.
- Lifting on mobile: REP 150x52 (REP 24 / xN 14) 10 px above Roblox's jump button (TouchGui JumpButton; while seated
  Roblox hides the touch controls, then 150 up), PUMP right above it (150 wide), STOP above the thumbstick, weight card
  184x86 under the top bar; a weight requirement gets its own line (cut with "...") and BEST WEIGHT moves under it.
  MachineClient now imports Kit (the record banner line needed it).
- Genetics rebuilt for phones (GeneticsClient, 82 KB 3D stage -> 24 KB panel): one centered 600-wide panel (header +
  DNA chip, OVERALL plate + gold word + View odds, 2-column group grid with fixed 46 px rows, Frame / Body chips that
  wrap, REROLL quiet + KEEP red, inline good-roll confirm, odds panel). Tested on the phone emulator (749x388) and the
  667x375 layout: reveal, confirm, reroll (UP / DOWN), odds. The 3D set (ReplicatedStorage.GeneticsSet,
  GeneticsCameraRig) is no longer used (left in the place).
- Physique fix: the rows, grades and total disagreed (bars = Growth Spurt goal progress, 100% for a maxed player;
  letters = genetics grades; total = average look). Now one number: group % = its muscles' progress to the full look
  (LookG clamped to 1), grade from it (S 90+, A 75+, B 55+, C 35+, D), total = average of the six; bars S red, A gold,
  B teal, C steel, D dark gray. LABELS switch = a small eye button in the body card's corner. The left menu folds while
  any window is open. Studio hook: Workspace TestOpenPanel = "Physique" opens it.
- Physique note (owner): under the total "Taller frame - more muscle to fill" (above the starting height); after a
  Growth Spurt, once, the toast "You grew! Your muscles have more room to grow." TestOpenPanel only works in Studio
  (RunService:IsStudio()).
- REP never moves (owner): its spot is worked out once from TouchGui's JumpButton (readable even while Roblox hides it
  on a seat; 12 px above it, right edges lined up; PC: bottom right), then only again when the screen size changes. No
  more 0.5 s re-checks or "jump hidden" fallback. REP 150x46, PUMP right above it.
- Genetics: the 3D stage is back (restored from git, before bdaf259; its set pieces never moved: ReplicatedStorage.
  GeneticsSet / GeneticsCameraRig). Phones frame it like a PC: the pose is worked out once on a virtual 1920x1080 screen
  (stage between 17% and 70% of the height), FieldOfView = max(PC FOV, the FOV that keeps the PC's horizontal view on
  this aspect). The labels under each plate are gone: GENETICS + DNA tokens on the top bar line, the rest in one
  final-kit bottom panel (Overall + six groups in a row, Frame / Body chips, View odds, REROLL quiet, KEEP red). Fixed an
  old bug on the way (the reveal reset a global spinFactor).
- Tested after Studio's Play unstuck: REP in the same spot on bench, squat rack, bench again and overhead press (591,181,
  133x40 at this phone's scale, 12 px over the jump button); the first try had measured the jump button before Roblox
  placed it (REP at the top), so only a jump button in the lower half of the screen counts. Genetics 3D on the phone
  emulator: stage between the top line and the bottom panel, nothing over it.
- World signs (owner): the arm wrestling tables get a small gold name pill (no diamond) + the OCCUPY prompt; the diamond
  only for machines, within 15 studs (was 12), fades when you sit. Signs: AlwaysOnTop off, MaxDistance 40, studs: sign
  name / prompt / simple pill, NPC name tags (code + the 15 baked in Workspace.NPCs), the posing stage marker, the RIVAL
  tag (now only while that rival's challenge is on, data.rivals[id] == "active"), crew tags, pose cards, rival and
  trainer bubbles. The starter arm table is at (18, 2, -31), 33 studs from the spawn (not at spawn).
- Stats overlay (owner): lines end on the exact body point every frame (Chest / Back = upper torso front / back centre,
  Core = lower torso front, Shoulders / Arms = the arm on the left column's side, Legs = the thigh on the right side; on
  the muscle mesh surface). Columns: Shoulders, Chest, Arms left; Back, Core, Legs right. A point facing away keeps a
  faded line. Standing still with the labels open turns you to face the camera. The real offset bug: on devices with
  insets (the emulator's phone) the full-screen gui is bigger than the 3D viewport, so the drawing layer is now placed
  over the viewport each frame. Top row never over the top bar. Studio hook TestOpenPanel = "Stats".
- PERFORMANCE baseline (14 Oct, BEFORE culling / LOD / streaming changes). Studio Play solo (1 player: Studio can't add
  more), Device Emulator view 974x584 (the emulator had been switched off the phone; no touch controls), quality
  Automatic, starter gym floor (0, 4, -20) looking down the gym, 16 NPCs, 5 s samples:
  - fps 26.5 / 40.8 / 29.8 (Studio is noisy), worst frame 81-142 ms, scene draw calls ~249, shadow draw calls ~720,
    triangles ~1.78 M, render CPU 23-36 ms, heartbeat 1.2 ms, physics 1.0 ms, instances ~109.8 k, primitives 24.5 k,
    moving 211-339, memory ~4.3 GB (Studio's own memory included), ping 1 ms (local).
  - the same frame with the NPCs hidden: fps 48.3, draw calls 114, shadow 615, triangles 411 k: the 16 NPCs are 77 %
    of the triangles (~86 k each) and 54 % of the draw calls.
- Step 1, culling: NpcCullingClient = ONE client manager, round-robin (max 4 NPCs a frame): Near (< 40 studs, on
  screen) every 0.1 s, everything on; Mid (40-100) every 0.5 s, particles at 35 %; Far (> 100 or off screen, 15 % viewport
  margin) every 2 s, animations frozen (AdjustSpeed 0, restored after), particles / beams / trails off. Arm wrestling
  opponents always Near; trainers stay TrainerFollowClient's (yours never freezes). Server: GymGoerService parks a
  regular (anchored, idle, no pathfinding) while no player is within 120 studs, checks every 2 s; a regular on a machine
  or held isn't parked; NPC roots stay server-owned. Same scene: tiers near 1 / mid 3 / far 12, 8 of 9 playing tracks
  frozen, draw calls ~211 (was ~249), triangles ~1.41 M (was ~1.78 M), fps 30-37 (Studio noise).
- Step 2, LOD: MuscleRig.SetLowDetail (every region "covered": the stage meshes hide, kept, the plain body shows; no
  clone / destroy) + MuscleClient: an NPC further than 60 studs goes low detail and hides its accessories
  (LocalTransparencyModifier), back under 50 (gap: no flicker). Never your character, other players, the statue or an
  arm wrestling opponent. (Replaces the 13 Oct "never a visible change by distance" for NPCs, owner's call.) Map pass in
  Studio (saved with the place): 238 meshes RenderFidelity Precise -> Automatic (+ TrainerModels / GeneticsSet),
  non-colliding meshes CollisionFidelity Box, CastShadow off on 491 small props (< 4 studs; machines, the arm table and
  characters keep theirs) and 15 NPC accessories. No aura VFX exist yet (nothing to cap). Same scene: fps 46.9 / 48.0
  (was 30-40), worst frame 24-26 ms (was 81-142), draw calls 125-146 (was ~249), triangles 476-682 k (was ~1.78 M);
  3 NPCs with muscles, 13 plain. Shadow draw calls still ~700: the gym's shadow-casting lights (next lever).
- Step 3, streaming: StreamingEnabled was already on. ModelStreamingMode: the 61 machines, the 16 NPCs (+ NpcService
  for legends / arm opponents), both arm tables, the posing stage, the smoothie bars / cart / menu = Atomic (code:
  MachineService, NpcService, builders GymKit / GymCat); Persistent only Gym.StarterGym, Gym.Entrance, Town.GymFront
  (spawn area). ProGymService streams around the spot outside before putting a locked player back (own task, the
  loop never waits); the other moves (machine sit / exit, spot slots) are a few studs from where you stand. Client audit
  (all 45 client scripts) + fixes: ProGymClient (door looked up again whenever it's gone, no infinite wait),
  MachineClient (a streamed-out machine lets go of its pose / tint / tables; "Enter" with no model finds yours; Plates /
  bar nil-safe; treadmill offsets cleared), MirrorClient (reflection restarts on a new Glass), TutorialClient (the
  step's machine looked up until it's here; Highlight under the camera), MachineSignsClient (old anchors swept),
  RivalClient (old tags removed), ArmWrestleClient (never set up twice). Low risk, left: PhotoModeClient spot boxes,
  MealClient auto-close.
  NOT SET (scripts can't write them, Properties panel only): Workspace StreamingTargetRadius 256, StreamingMinRadius 64,
  StreamOutBehavior Opportunistic, StreamingIntegrityMode PauseOutsideLoadedArea. With Studio's current values the
  whole map is on the client (61/61 machines at join), so stream-out isn't exercised until those are set.
  Walk test (Studio, 974x584): starter incline bench, pro lateral raise, beach bicep curl: sit + HUD + REP; arm tables
  (2 prompts each), posing stage, smoothie bars / cart / menu, mirror glass all present with prompts; pro door open for
  an unlocked player; no errors in Output. Not done: low graphics join (Studio's quality can't be set by script; the
  game's Low Graphics setting would change the owner's save), several players, a real phone.
  AFTER (same view, camera pinned, NPCs walking): fps 36-40 (47-48 right after LOD), worst frame 31-84 ms, draw calls
  152-191, shadow 607-614, triangles 0.78-1.18 M, render CPU 23-25 ms, instances ~109.3 k, memory ~4.9 GB (Studio).
  BEFORE: fps 27-41, worst 81-142 ms, draw calls ~249, shadow ~720, triangles ~1.78 M, render CPU 23-36 ms.
- Loading screen + menu music (owner): 118959016267248 (Config/Sounds.MenuMusic, repeated in LoadingScreen LOOK.Music),
  looping from the first frame (SoundService.MenuMusic), the same Sound through the menu (Audio.AdoptMenuMusic: the
  player's Music volume), faded out on Play (Audio.StopMenuMusic); the area music waits for it and starts under the
  fade. Tested: loading -> menu -> Play -> starter gym music.
- Saves past the height cap (owner): on load, once, a save with more Growth Spurts than the last one (6) gets +10,000,000
  shown EXP on every one of the 18 muscles (OVER_CAP_EXP / Muscles.ExpPerXp xp, levels recomputed) and its spurt count
  goes back to 6 (so it never runs twice; the x3.5 bonus of spurt 7 becomes x3.0). Tested on the owner's save (spurt 7):
  spurt 6, every muscle +10 M EXP, kept after rejoining, no second payout.
- DNA Tokens (owner): only 3 sources (Config/DNA): +1 per Growth Spurt (toast "+1 DNA Token" with the celebration),
  25,000 coins (Shop Items tile + Genetics REROLL choice; server ActionService.BuyDnaToken), the developer product
  "DNA Token" 3718499538 (Config/Products, ProcessReceipt once per PurchaseId, saved first). Removed: day-7 login token,
  the "Grind" quest token, legend token, the front desk 400-coin prompt. Genetics: gold token count; with no free reroll
  and no token, REROLL opens "25,000" / "R$ 99" (nothing spent without a tap). Studio hook: Workspace TestReceipt =
  "<productId>:<purchaseId>". Tested: spurt 0->1 gave exactly 1, coin buy 30,000 -> 5,000 (+1), second buy failed
  (toast + shake), test receipt +1 once, same id again and after rejoin: no second grant.
- Quest rerolls (owner): DailyQuests.FreeRerollsPerDay = 1 free a day (dq.swaps, saved with the day), then the "Quest
  Reroll" product 3718500732 (R$ 19, Config/Products). The picked quest is saved (dq.pendingReroll) before the client
  prompts; the reroll happens only in ProcessReceipt (DailyService.PaidReroll, once per PurchaseId); nothing left to swap =
  a credit (stats.questRerollCredits) used by the next reroll. Never the same quest or one of the other two; done /
  claimed quests can't be rerolled. Quests window: REROLL - FREE (gold) / REROLL - R$ 19 + "Free reroll in 5h 12m" in the
  bonus card; tap it, then a quest (its pill says REROLL). Studio: TestDayOffset = n days. Tested on the owner's save:
  claimed quest refused, free once, then BuyReroll, test receipt swapped exactly the picked quest once (sent twice),
  rejoin kept the free one used, next (fake) day the free one came back.
- Button ghost outline (owner's bug): the Depth layers (glow ring, top gloss, shine, hairline) sat inside the button's
  UIPadding (12 px sides + the bottom lip), so they were pushed off-centre. Theme.fitLayer now places every layer on the
  button itself (AnchorPoint 0.5, sizes from the full button: ring +6 px with corner +3, gloss / shine 2 px inside),
  re-fitted when padding changes. Press + pulse share ONE UIScale (Theme.ButtonScale: press x pulse NumberValues).
  Styles: Tab = active tab, gold fill only; Green = gold without the ring (EQUIP, buy tiles, toggles, choices); Gold /
  Red = the main CTA with the ring. No pulse on the 3 quest-row CLAIMs. Arm wrestle opponents: one dark card style (a
  rival too), difficulty colored under the name. Checked: menu, Store, arm wrestle picker, Titles, Physique, Quests,
  Genetics (Studio emulator 974x584; it can't be switched to 844x390 / PC from here).
- Machine panel (owner): the weight card is centred at 40% of the screen height, 16 px from the right safe edge
  (MachineHud.PanelCenterY / PanelRight; DeviceSafeInsets), PUMP / REP 10 px apart; if the card would come within 10 px of
  PUMP it shrinks to 0.9 and only then moves up just enough. - and + always show (greyed + ignored at the ends, they still
  take the tap so it never lifts). "+100" tiers (bodyweight machines) show "100 LB". BEST WEIGHT is a real gold button
  (no ring, up-arrow icon, 26 px visual inside a 44 px tap area) on the Tier line; AT BEST (flat, check, muted) when on the
  heaviest usable weight. Checked: Crunch Bench at 12/12 (AT BEST) and 10/12, Squat Rack, Flat Bench (974x584; the other
  emulator sizes can't be switched from here).
- Skating speed (owner's bug): the skate LinearVelocity had MaxForce 60000, which lost to the Humanoid's own grip on big
  characters (7'0" mass monster: 13.8 studs/s of 32). Now ForceLimitsEnabled = false (walls still stop the board).
  Config/Skate: top = (wheels speed or BaseSpeed 32) x (1 + 0.35 x (height / 4'0" - 1)), max 54; push / brake / coast /
  turn x the same factor (SkateFactor attribute); the board and its lift scale 0.85 (4'0") -> 1.3 (7'0"). No WalkSpeed
  slowdown by size exists; board parts don't collide (wheels sit on the ground at every size). Measured (flat road):
  | size | mass | target | reached | 95% at | 90-deg carve |
  | 7'0" mass monster, before | 29 | 32 | 13.8 | never | - |
  | 4'0" (spurt 0) | 10 | 32.0 | 32.0 | 2.02 s | 0.63 s |
  | 5'6" (spurt 3) | 15 | 36.2 | 35.6 | 1.93 s | 0.56 s |
  | 7'0" mass monster (spurt 6) | 29 | 40.4 | 40.7 | 1.93 s | 0.57 s |
- Stamina bar only while exercising (owner): HudBottom's bar sits in a CanvasGroup, GroupTransparency fades in 0.2 s on a
  machine (SetTraining), out 0.4 s 1.5 s after leaving; off a machine a jump of 10%+ of max (shake / refill) shows it 3 s.
  Never moves; the boost row keeps its own spot. Tested: walking hidden, on (0.00), off at 1.85 s, refill shown ~3 s.
- SKATE button (owner): Config/UI.SkateButton (the owner's skate_button.png, uploaded from Studio = the owner's own
  inventory 117777612617836; not found in Myanmar Builders Club). Square ImageButton, no background / stroke, "SKATE"
  label; skating: a slowly pulsing gold UIStroke ring + "SKATING". Touch: left of Roblox's jump button, its size, same
  centre height (measured per screen size); PC: bottom right + a "Q" chip (Q toggles). Hidden on a machine, the menu and
  under windows; outdoors only. Press 0.92 + bounce + click; start = whoosh + dust puff; one-time hint after 10 s walking
  outdoors (settings.skateHintSeen); new last tutorial step "Skate" (8 s). Old right-column button removed. Checked on
  PC (on / off / Q); touch placement not checked (the emulator can't be switched from here).
- Daily rewards DNA tokens (owner): Economy.Login.DnaTokens = { [4] = 1, [7] = 1 } on top of the coins (an allowed source:
  Config/DNA now lists 4 sources). DailyService pays it with the claim (the claim day is saved first: once per claim);
  "+1 DNA Token" toast; the grid shows the DNA token icon (Config/UI.ShopIcons.product_dna_token, uploaded from Studio =
  the owner's inventory 87375007150587; not in the group) with "+1" beside the coin on days 4 and 7. Tested with
  TestLoginDay 1..7 (claiming twice each day): +1 token on days 4 and 7 only, coins once per day.
- Store only showed Extra Trainer (owner's bug): no error and no broken loop; every other pass / product still had
  id = nil in Config/Monetization (the Store hides items without an id). Added the owner's ids with Roblox's names / prices
  as fallbacks (`price`), shop art (`art`) and tabs: PASSES 2x EXP, 2x Coins (new: BoostService coins x2), VIP, Aura Pack,
  Auto Rep, Extra Trainer; COINS Small / Medium / Large (+1,000 / +5,000 / +15,000, from their Roblox listings); BOOSTS
  Shake Bundle (3 shakes), Stamina Refill (to max), DNA Token. Skip Growth Cooldown has its id but stays hidden (`hidden`:
  the game has no Growth Spurt wait yet); Quest Reroll stays in the Quests window only. StoreClient: Roblox info fetched
  once at start per item (pcall, 3 tries, cached), Config fallbacks otherwise, id 0 = warning + skipped, OWNED passes
  stay listed with their stamp. Tested: all 12 items on 3 tabs with art + prices; test receipts: coins +1,000 once
  (same purchase id twice), shakes +3.
- Auras (owner): Config/Auras (13: Ember LVL 10, Frost LVL 25, Storm LVL 50, Golden 7'0", Titan every Coach quest; Aura
  Pack pass: Inferno, Blood Moon, Void, Neon, Galaxy; VIP: Royal; coins: Toxic 50,000, Shadow 150,000; owner's icons
  uploaded from Studio = owner inventory). AuraService (server): data.auras { owned, equipped }, earned auras kept forever
  (checked on join + every 10 s), pass auras while Pass_<key> is set (join + purchase finished), coin buys, the worn aura
  replicated as the "Aura" attribute. AuraClient: per player 3 layers on the upper torso's surface (glow + light / rising
  energy by style / sparks + a light column Beam), sized from the root; idle = glow at half, lifting = glow, 50% PUMP =
  layer 2, 100% / PUMPED = layer 3, PR = burst + AuraBurst sound (MachineService sets AuraBurst); others: off past 40
  studs, glow only from 20, nearest 8, Settings "Others' Auras" / Low Graphics; half rate on phones; no Highlights.
  UI: Titles > AURAS tab (preview card + tiles with EQUIP / EQUIPPED / price / AURA PACK / VIP / locked, Aura: Off);
  Store AURAS tab (tiles, VIEW AURAS opens the panel; Store 660 wide for 4 tabs). Tested: owner's save earned
  Ember / Frost / Storm / Golden, pass flags unlock the 6 pass auras, pump 0.3 / 0.6 / 1 = layers 1 / 2 / 3, PR burst,
  every aura screenshotted (screenshots/auras). Not done: a live 3D preview in the window (ViewportFrames don't draw
  particles), a 10-player phone FPS test (can't simulate players from here).
- Trainers don't collide with players (owner): TrainerFollowClient puts every trainer part in the "Trainers" collision
  group (registered by TrainerService, collides with nothing) + CanCollide / CanTouch / CanQuery off.
- Settings: "Others' Auras" row (11 rows: the grid scrolls).
- Stats overlay (owner): the "turn to face the camera" is gone (no AutoRotate toggling, no root CFrame, no camera change);
  lines to far-side body points are dashed (a stepped UIGradient) and fainter. Tested from behind and side-on after
  walking: the character never turns by itself.
- Trainers remake (owner): built from a HumanoidDescription (R15) with Roblox's free catalog hair (Brown Charmer, Lavender
  Updo; Lou buzz under a cap, Rex bald), a classic head carrying a Roblox face image (the description's dynamic head has
  a blank face and face images map wrong on it), our own clothing templates (tracksuit + joggers, tank + shorts, polo +
  black pants, stringer + shorts; drawn by scratchpad trainer_clothes.py, every template area filled), part-built props
  (whistle, headband + bottle, cap + clipboard, belt + wrist wraps), the static muscle stages ("MuscleG": 0.9 / 0.7 / 0.8
  / 1.8). TrainerFollowClient: coach idle drawn on the joints (breathing, weight shift; arms crossed / hands on hips /
  clipboard check; Motor6D or AnimationConstraint joints), a clap or fist pump every 3 reps, bubbles at most one per 10 s,
  other players' trainers frozen past 60 studs, the stages' skin layer hidden (it poked through the clothes at the lats).
  Portraits re-rendered (dark booth, same camera) and uploaded (Config/UI.Trainers). Not done: a "cheering while you lift"
  screenshot.
- Trainers' bare skin (owner: "only the clothes show"): hiding the stages' skin layer also hid the bare skin (see-through
  parts of a clothing image show nothing on these meshes). Each trainer's skin color is now painted under the clothes in
  his Shirt / Pants images (no see-through parts), new ids in Config/Trainers. Checked: Rex and Nia show skin where bare,
  clothes solid at the lats.
- Arm wrestling: one body per stool (owner). An NPC opponent's stool is reserved (Seat.Disabled, prompt off) while the
  NPC is on its way, sitting and doing the win slam; NPCs only go onto an empty stool; any non-player that gets onto a
  stool is unseated (SeatWeld broken). Prompts refresh when someone stands up late.

## 14 Oct: free machines, new main menu, avatar headshots, left menu centered (owner's "THREE FIXES" + headshot prompts)
- Machines are FREE: every weight opens with the main muscle's level alone (Progression.cost all 0, Machines.UsableTier
  ignores what was bought, server SelectTier / MaxWeight never charge). No price on signs, panel or goal lines. Tested:
  a new save with 38 coins went 45 -> 135 lb via BEST WEIGHT, coins never dropped. No refunds.
- Growth Spurt goals re-tuned for the faster weights (tests/pacing, all within 10%): 47/72/103/135/157 ->
  58/92/132/164/178 (spurt 1 stays 15: the EXP scale is tied to it).
- Main menu rebuilt to the NEW mockup 00_main_menu (MenuClient): art visible on the right + soft dark copy, centered left
  column (SEASON 1 · NOW LIVE, Luckiest Guy logo with a soft shadow, red rule + tagline, red PLAY with a drawn triangle,
  dark SHOP / UPDATES with a red news dot (Config/UI.UpdatesStamp, settings.updatesSeen), player card), v1.0 · Update 1.
- Kit.Headshot / Kit.ApplyHeadshot: real avatar headshots in a plain dark circle (letter fallback) on the menu card,
  leaderboards, posing vote, spot request card and crew rows (CrewService now sends userId).
- SideMenu vertically centered (AnchorPoint 0, 0.5; never above the top bar), "<" centered on its edge. Phone + PC checked.
Screenshots: ui_compare_v2/main_menu_*, left_menu_*, free_weights_new_save.

## 14 Oct: REP / PUMP bar, treadmill sounds, arm wrestling table (owner's "TWO FIXES" prompt)
- REP / PUMP: REP is a normal red button at the bottom right again (104 x 52, "REP x13"), and PUMP is a bar again (as
  before the redesigns): right above REP, dark track with a dark outline, gold fill with every tapped rep, flame + "PUMP".
  NEW: a full bar waits (it no longer starts PUMPED by itself and doesn't drain): it pulses "TAP TO PUMP!"; tapping it
  (or Space) starts PUMPED x2 (the bar drains with the seconds left, "PUMPED x2 6s"). Space with a bar that isn't full
  still gets you off the machine. Auto Lift pumps by itself when the bar is full. Server: MachineService action "Pump".
  Tested phone + PC: half / full / Space pump / Space leave; nothing overlaps (pump bar, REP, STOP TRAINING, stamina).
- Treadmill sounds: the treadmill never plays the lifting sounds now (no clank, plate knock, bar rattle, floor thud,
  plate slide, metal unlock clang). New Config/Sounds slots TreadmillLoop (loops on the belt while someone runs, 3D,
  quiet, fades out over 0.3 s) and TreadmillStep (soft footstep every stride, rate follows the speed): ids EMPTY for the
  owner to pick (silent until then). Other machines checked: barbells / sleds / cables clank; a bodyweight set with no
  plates (pull-ups or dips at BW) no longer clanks. Tested on a treadmill: only the soft rep tick played.
- Arm wrestling table moved off the spawn: from by the front door (13.4, -18.1) to (18, -31), right of the center aisle
  ~28 studs into the starter gym (Config/Social TableSpot updated; the table model moved in Studio).
Screenshots: ui_compare_v2/machine_hud_pump_half_phone, _full_phone, machine_hud_pumped_phone, machine_hud_treadmill_phone,
machine_hud_pump_pc.

## MORNING REPORT (14 Oct): the BIG UI + BUG RUN is done
**What's done:** all 5 Part 1 bugs (machine HUD, leaving a machine, floating text, pro gym door loop, broken tops),
every screen of the v2 mockups (main HUD, machine HUD, Shop, Quests with Daily / Rewards / Achievements, Trainers,
Stats, Titles, Smoothie bar, Settings, tutorial dialog, posing, arm wrestling, loading screen, main menu) plus Emotes and
Crew in the same window style, and the old colored left-menu tiles tidied (Shop first, badges, "<" fold, folds while
lifting). Everything is in Studio, exported to `src/` (all 140 scripts byte-checked), committed and pushed; logic tests
pass, every script compiles. Side-by-side screenshots: `screenshots/ui_compare_v2/` (phone 844x390 + PC).
**Nothing to upload:** all the images are uploaded (ids in `Config/UI`). The only pass with an id is Extra Trainer
(2032496303); the other passes / products stay hidden until you give their ids.
**Test these 3 first:**
1. New player (Workspace attribute FreshPlayer = true): loading screen -> menu -> PLAY -> genetics -> the Quests window
   with the Daily Reward -> the tutorial (coach dialog, SKIP TUTORIAL needs two taps). Then sit on the Flat Bench and
   leave with STOP TRAINING and with jump.
2. Trainers tile: tap a picture with not enough coins (shake + "Not enough coins"), then hire one (TestCoins = 2000 with
   FreshPlayer) and check the follower looks like his picture (cap / headband / visor / headphones).
3. Your own save (FreshPlayer = false): the menu pill (coins | LVL | height), SHOP and UPDATES, then PLAY: the camera
   should show your whole 7'0" character.
**Assumptions (please check):** the left menu's Poses tile opens Emotes; Stats (labels) and Muscles (the Stats window)
stay two tiles; AUTO on the machine panel only shows while the Auto Lift pass has an id; the mockup's "Coach Dante" is
our Coach Dex (Dante is the pro gym's 8'0" NPC); the mockup's "Other Screams" setting = "Others' Sounds" and "Other
Auras" is left out (no auras in the game); the Shop's Coins / Boosts / Auras tabs are left out (no coins for sale, no
auras); smoothie prices stay at the Config values (60 / 50 / 90 / 40), the mockup's numbers were examples; SKIP TUTORIAL
needs two taps and gives no reward, finishing the tutorial gives 50 coins (new); hiring a trainer works anywhere (the
Trainer Desk just opens the window); trainers have no names anywhere (their NPC name tags are gone too).
**Still open (small):** a few skin spots on the lower back under a top at big sizes (Wardrobe is off anyway); the
spotting popup, clothing store, rival card and mirror card use the new colors and buttons but weren't redrawn one by one.
**Studio test switches cleared:** TestStore, TestCoins, TestMuscleShare, TestPhoneSize; FreshPlayer is set to false.
**Please:** File > Save to Roblox, then File > Download a Copy to
`C:\Users\kaung\OneDrive\Documents\GymArc_backups\GymArc_2026-10-14.rbxl`, and check the new version in Version History.

## 13 Oct, evening: BIG UI + BUG RUN (owner's v2 prompt, Gym League style), DONE
The dark image-piece redesign (earlier today) is CANCELLED by the owner; its 9-slice pieces are gone from `Config/UI`.
**Left menu (owner's change of plan, mid-run):** the OLD colored tiles stay (not the 3D-icon tiles of the v2 mockups;
`menu_*.png` are uploaded but not used). Buttons and panels use the same rounded style and colored borders.

**Images uploaded** (from Studio, owner's account; the group had no copies): menu_*.png x8 (not used), trainer_exp /
stamina / coins / pump, menu_art. Ids in `Config/UI` (MenuIcons, Trainers, MenuArt). Extra Trainer pass id 2032496303 is
in `Config/Monetization` (so the Shop tile appears after the tutorial + 5 minutes, with that one pass).

**Part 1, bugs**
1. Machine HUD covered the player: rebuilt to mockup 02 (`Shared/UI/MachineHud`): weight panel on the right (AUTO TRAIN /
   AUTO ON, WEIGHT, Tier, - / +, BEST WEIGHT = the old MAX, UNLOCK + price in its place while a weight isn't bought),
   REP + PUMP circles bottom right, STOP TRAINING above the stamina bar, NEW PERSONAL RECORD! as text at the top. Nothing
   in the middle. AUTO shows only while Auto Lift is for sale (hidden now). DONE, tested phone size.
2. Couldn't leave a machine: cause = every tap, PUMP tap and Auto Lift tick is a MachineAction message, and the server's
   anti-spam limit (16/s) silently dropped "Leave" too. Leave now skips that limit (own small budget); the client re-asks
   every second until the server answers; the jump button / Space gets you off (Space no longer lifts; gamepads lift
   with R2 / X). Tested: all 22 machine types after 20 fast taps mid-rep, the bench with Auto Lift on + Space. DONE.
3. Floating text: the coach note, pump hint, level-up text and the tutorial pill are gone from the lift view. One hint at
   a time in the top band (`Notify.Hint` / `Notify.SetBand`), hidden after 4 s; the Settings "Tutorial Hints" toggle
   (settings.hints) turns hints off. Toasts stack under the top bar / band at the top center, newest on top, max 3. DONE.
4. Pro gym teleport loop: cause = the server's pro gym zone still had the pre-8-Oct size (MinX 37), so the strip by the
   door in the starter gym counted as inside and the "outside" spot (x 39.7) was in it too: standing there teleported you
   every 0.5 s. Now the zone is the pro gym's Floor part (x 45-113), the outside spot is 6 studs clear of it (asserted),
   a 1.5 s per-player debounce, and "Reach Growth Spurt 2 to enter the Pro Gym" at most every 3 s (the door's Blocker
   stays solid for locked players). Tested solo (by the door: no teleport; inside: put back once, stays). 2-player test
   not possible in Studio solo: the state is per player. DONE.
5. Wardrobe clothes (tops broken on the muscle body): three real causes, fixed (no parts hidden):
   a) The skin part and the shirt part are two MeshParts from one live mesh, and such a part is drawn relative to the
      mesh's bounds at the moment it was made: the skin part was made at the biggest (monster) shape, the shirt part later
      at the real shape, so the skin sat ~0.1 stud off and poked through every top (belly, chest, back). Now the shirt
      and color-layer parts are made together with the skin part (MuscleRig buildGroup spares) and reused.
   b) The forearm / calf stage meshes (and other players' body stages) were ONE solid part with the shirt image: a solid
      part ignores the image's transparency, so short sleeves drew BLACK forearms. Now a clothed stage is a hair
      see-through over a skin copy just inside it (LimbStages, BodyStages).
   c) ~2,000 torso / ~900 arm triangles cross a texture seam and smeared the image's see-through gaps (MuscleRig faceUVs).
   Also: the skin sits 3% inside (was 1.5%: speckles), and the waist band takes the fit's color under a gym fit.
   Tested: white tee at level 0 (front / back), cropped hoodie at half (front / back), white tee at mass monster
   (front / back), plus stringer / sleeveless hoodie on and off: no errors. Still open (small): a few skin-colored spots
   on the lower back at big sizes (not depth fighting, not the image, not seams, not the waist: cause not found yet).
   `Config/Features.Wardrobe = false` keeps the Wardrobe tile hidden and takes the tops off sale; on join anyone who owns
   tops gets them removed and their coins refunded once (CosmeticService refundFits, toast "Coins refunded").
   Screenshots: fit_bug_before_tee, fit_fix_level0_front / back, fit_fix_half_hoodie_front / back, fit_fix_mass_front / back.

**Part 2, panels** (each a Kit.Modal: tabs above, title + red icon, red X, blur):
- 10 Settings (done): 2 columns of rows, gold icon + name + ON (green) / OFF (gray): Music, Sound Effects, Others' Sounds
  (the mockup's "Other Screams": no screams in this game; mutes other players' lift sounds), Low Graphics (shadows and
  bloom / depth of field / sun rays off on this device), Tutorial Hints (= the coach hints toggle), Gain Numbers
  (On / Minimal / Off), Rep Flash, EXP Popups, Spot Requests. The mockup's "Other Auras" is left out (no auras yet).
  Screenshot: ui_compare_v2/10_settings_phone. Icons now preload when the game starts.
- 08 Titles (done): tabs All / Owned, count "x / 36", 4-column scrolling grid of cards: rarity word in its color, name,
  EQUIP (green) / EQUIPPED (gold, gold outline) when owned, a lock when not (secret = "???"); tapping a locked card shows
  how to earn it in a toast. Screenshot: ui_compare_v2/08_titles_phone.
- 05 Quests (done): one window for the Quests tile, the Quests pill, the Daily Reward pill and the Daily quests card.
  Daily tab = today's 3 quests (blue icon, bar "0/40", coins, CLAIM / GO / DONE, the once-a-day swap button), the
  "Complete all 3" gold bonus row, and the 7-day Daily Reward grid with CLAIM DAY N (today green, claimed ticked, later
  days dimmed). Rewards tab = the 7 days big + the streak rules (the Daily Reward pill opens it). Achievements tab = the
  Coach's quest chain (done / current with its bar / locked; after the chain his current repeat quest). GO closes the
  window and puts where to go in the top band. The old login calendar card and the quest-tracker hide toggle are gone
  (the Quests pill opens the window now; its badge counts quests ready to claim + a coach quest ready to hand in).
  The tutorial band now steps aside while any window is open. Screenshots: ui_compare_v2/05_quests_*.
- 07 Stats (done): the Muscles tile, the GROW tile (when not ready) and the machine body map open it. Muscles tab =
  your body card (the muscle figure lit by level, "101% SIZE", "Physique: Shredded"), 8 cards (Chest, Back, Shoulders,
  Arms, Legs, Core, Forearms, Calves: genetics grade badge + a bar in the grade's color with the % toward the Growth
  Spurt goal) and the Growth Spurt row (next height, x/6 groups, GROW!). Lifts tab = every open machine with its main
  muscle, heaviest weight lifted and weights bought. Genetics tab = the six grades with "Grows x1.20", frame and body
  type perks, overall word, OPEN GENETICS. "LABELS ON / OFF" in the window does the same as the Stats tile. The Growth
  Spurt moment is now a big gold line + "You're now 4'6". Gains x1.25 forever!" in the screen center (no duplicate
  toast). Fixed: the GROW tile did nothing when not ready (OpenStats had no listener). Screenshots: ui_compare_v2/07_*.
- 04 Shop (done): "Gym Store" window from the gold Shop tile (first in the menu, only after the tutorial + 5 minutes,
  only when something has an id). Tabs Passes / Items (only tabs that have something: today just Passes with Extra
  Trainer), a 3-column grid of cards (name, shop art, Robux price from Roblox or OWNED in gold) and the picked item big on
  the right with what it does and the green Robux button (the only thing that opens a purchase). The mockup's Coins /
  Boosts / Auras tabs are left out: the game sells no coins and has no auras. Studio test switch: Workspace attribute
  TestStore = true shows the Shop tile at once. Screenshot: ui_compare_v2/04_shop_phone.

**Part 3, Trainers (mockup 06, done):** four picture tiles (trainer_exp / stamina / coins / pump), no names anywhere: the
perk ("+5% EXP", "+10% Stamina", "+5% Coins", "+25% Pump") and a coin + price (300 / 450 / 600 / 800, Config/Trainers).
Tap: not hired = hire, anywhere (the Trainer Desk is no longer needed; not enough coins = the tile shakes + "Not enough
coins"); hired = "TAP TO EQUIP"; following = green outline + "FOLLOWING" (tap again = stop). Bottom: "Following 1/1" and
the gold "99 · 2ND SLOT" button (Extra Trainer pass 2032496303, price read from Roblox, hidden once owned). The followers
now look like their pictures (shirt colors painted on, part-built red cap / white headband / gold visor / black
headphones, no catalog clothes) and lost their name tags. Tested: not enough coins (shake + toast), hire with
TestCoins = 2000 (2,000 -> 1,700, FOLLOWING), the red-cap follower. Screenshots: ui_compare_v2/06_*.

- 09 Smoothie bar (done): the stall's prompt opens a "Drinks" window titled with the stall's name (Smoothie Bar / Smoothie
  Cart / Coconut Cart): one tile per drink (big colored icon tile, name, "+20% EXP · 5 min", green coin-price button;
  gray "Full" at the time cap). Drinks the stall doesn't sell stay gray with where to get them ("Beach only"). Not enough
  coins: shake + toast. Chicken & Rice is orange now (mockup). Prices stay as in Config/Meals (60 / 50 / 90 / 40; the
  mockup's numbers were only examples). Tested at the starter cart: Protein Shake bought (2,000 -> 1,940).
  Screenshot: ui_compare_v2/09_smoothie_bar_phone.
- 11 Tutorial dialog (done): the step's short line in the top band (gone after 4 s, as before), a green SKIP TUTORIAL
  under it (tap it twice: the first tap turns it gold "Tap again to skip" for 3 s, so a stray tap never wipes the
  tutorial; skipping gives no reward), and the Coach's pages in a dialog at the bottom: a live portrait of the Coach NPC,
  "Coach Dex · Reward (coin) 50", the words, "Tap to continue (1/2)" (Config/Onboarding `coach` per step). On a machine
  there is no dialog (it would cover the machine HUD; the band has the line). New: finishing the tutorial the normal way
  pays 50 coins (Onboarding.FinishCoins, ActionService). The Goal step now points at the Muscles window (Muscles window
  or the stat labels both count as "stats open"). The mockup says "Coach Dante": the game's coach is Coach Dex (Dante is
  the pro gym's 8'0" NPC), so it says Coach Dex. Screenshots: ui_compare_v2/11_*.
- 13 Arm wrestle (done): "YOU" and the opponent's name over one long bar (red = you from the left, blue = them from the
  right, split where the match stands), the gold timer between them (3-2-1 and GO! there too, then 0:08 counting down),
  a big round red TAP! button ("as fast as you can"; tapping anywhere still counts). Waiting at the table: the opponents
  as green / gold / red buttons (Easy / Medium / Hard · coins) and STAND UP. Result big in the middle (YOU WIN! gold /
  YOU LOSE red / DRAW) with the coins. Tested a match against Rocco. Screenshots: ui_compare_v2/13_*.
- 12 Posing (done): during a round, "POSING COMPETITION · Pose 2/3" and a timer at the top, the pose's name big in gold
  ("FRONT LAT SPREAD!"), the Judges panel on the right (each contestant's last card, best total first, "You" for you),
  and at the bottom a TIMING bar (the marker runs to the green: perfect in the middle, good in the light green; the
  same windows the old closing ring used) over a big red POSE! button. Its own gui (PosingRound), so the right column
  steps aside. Vote buttons and the result / vote notes in the new style. Tested with TestPosingComp: pose 1 and 2,
  judges' scores filled in. Screenshots: ui_compare_v2/12_*.

**Part 4, main menu + loading (mockups 00, done):**
- Loading screen (ReplicatedFirst, from the first frame; Roblox's default removed): black with the menu art on the right
  fading into the dark and a dim soft copy behind, the GYM ARC logo (GYM white, ARC red), "Everyone starts tiny.", a
  rotating "TIP:" line (Config/UI.LoadingTips), a red progress bar with the step ("Loading the game / Loading muscles /
  Loading the gym / Loading players... 64%") driven by game load, ContentProvider:PreloadAsync of every UI image, your
  save data + the world around you, then the other players' body meshes. SKIP top right after 5 s. It fades into the
  menu. (The barbell, plates and chalk dust of the old one are gone.)
- Main menu: the same art, the logo + tagline, a big green PLAY (breathes), a gold SHOP (players who finished the
  tutorial, only while something is for sale: plays and opens the Gym Store) and a blue UPDATES (a window with the update
  notes, Config/UI.Updates), and the pill "28,132 | LVL 38 | 7'0" (MAX)". The live gym tour, the white PLAY, the
  pointing hand, TITLES / SETTINGS and the chips are gone. PLAY puts the camera behind your character at a distance that
  fits your height (a 7'0" character filled the view before).
- Tested on the owner's real save (FreshPlayer off, nothing bought or claimed): loading, menu, UPDATES, PLAY.
  Screenshots: ui_compare_v2/00_*.

**Screens without a mockup:** Emotes (the Poses tile: a window with a 4 x 2 grid of pink icon cards) and Crew (tabs My
Crew / Top Crews, card rows with icon tiles, green CREATE, red LEAVE) now use the same window as the other menus. The
tutorial's skip button and coach dialog step aside while any window is open. The spotting popup, clothing store, rival
card, progress mirror card and prompts pick up the new colors, fonts and buttons through Theme (not redrawn one by one);
the machine signs and the world leaderboards are 3D and keep their look. Screenshots: ui_compare_v2/emotes_window_phone,
crew_window_phone.

**Main HUD (v2 look so far):** top bar pills (coins, height / 7'0", level; Daily Reward, Quests, gear), the old menu tiles
(Shop gold first, Stats, Muscles, Titles, Genetics, Poses, Crew, Quests, Trainers; Wardrobe hidden by
`Config/Features.Wardrobe = false`), "<" fold saved per player (settings.menuCollapsed), auto-folds while lifting, red
number badges; DAILY QUESTS card; gold GROW tile (READY tag; tap = grow, or opens Stats before that); big blue stamina bar
with the boost icons + timers above it (`Shared/UI/HudBottom`). Theme / Kit rebuilt (FredokaOne white text with a black
outline, Montserrat body, gradient buttons with a lighter colored border, dark panels, red X).
Choices: Emotes already exists as the Poses tile (same panel), so no second tile; the Stats, Muscles and Genetics tiles
stay separate (owner's old menu list). Screenshots: ui_compare_v2/01_main_hud_menu_phone, 02_machine_hud_phone.

## LATEST (13 Oct): new features run (owner's GYM_ARC_new_features.md): DONE, report

**Not saved to Roblox yet.** Owner: File > Save to Roblox, then File > Download a Copy to
`Documents\GymArc_backups\GymArc_2026-10-13.rbxl` (Claude can't do either). Builders run in Studio this run (saved only
with the place): PosingComp, Leaderboards, SmoothieCarts, Rivals, NightGlow, TrainerDesks.

**Per task** (details in the task sections below)
1. Posing Competition: done. 2. Daily quests + 7-day login streak: done. 3. Arm wrestling at every table + pro gym table:
done. 4. Leaderboards (six boards, three walls): done. 5. Smoothie bar (shakes & meals, starter / beach carts, pro bar
menu board): done. 6. NPC rivals Benny / Coral / Dante: done; rivals are an EXTRA goal (gyms already open by Growth
Spurt; the win card points to the next rival). 7. A) Victory wave added to the Poses panel (the four required poses
were already there); B) Personal Trainers (desks in all three gyms, 4 coaches, follow / stand beside your machine /
cheer / clap); C) day / night (20 min, lamps + shop windows + signs at night, gyms keep their lighting); D) photo mode
(mirrors + posing stage).
Not done / not possible from here: two-player tests (MCP play is solo only: e.g. seeing another player's trainer, rival
bubbles, posing votes); the phone emulator can't be driven (phone sizes checked with `TestPhoneLayout`); an FPS number
on a phone. Pets were replaced by Personal Trainers as the owner asked.

**FPS** (honest): no "before" number exists on the phone emulator (it can't be driven from MCP). Measured after all
tasks in Studio on this PC, same town view, engine render frame time: day 9.2 ms CPU / 10.8 ms GPU, night 8.7 ms CPU /
3.4 ms GPU (night costs nothing extra; none of the 207 night lights cast shadows). Studio showed 15 FPS only because a
background Studio window is throttled. Please check on your phone: town at night, a gym with two trainers.

**New Config values to tune**
- `Config/PosingComp` (every number of the competition), `Config/DailyQuests`, `Config/Economy` Login (7-day coins
  25/35/50/70/90/120/300, DNA token on day 7), `Config/Social` ArmWrestle (Npcs, PushPerTap, MaxTapsPerSecond, table
  spots), `Config/Leaderboards` (boards, refresh 90 s, top 100).
- `Config/Meals`: Items (price, seconds, effects, color, icon), MaxStack 3, Shops, PromptDistance 8, DrinkSeconds 2,
  SaveEvery 5.
- `Config/Rivals`: List (challenge machine + record lb / arm strength + taps, reward coins + title, lines, next),
  SetReps 10, SetGap 15, LoseLineEvery 30, BubbleSeconds 4.5, HoldSeconds 10, PromptDistance 8.
- `Config/DayNight`: Length 1200 s, DayShare 0.7, StartHour 9, Dawn 6 / Dusk 18, NightOutdoorAmbient, AmbientFade 1.5,
  WindowLitShare 0.6.
- `Config/PhotoMode`: Spots (path + range), Distance 9 (4..20), Pitch, DragSpeed, ZoomStep, FocusHeight.
- `Config/Trainers`: List (price, perk, look), Slots 1, ExtraSlotPass "ExtraTrainer", DeskDistance 8, RenderDistance 90,
  FollowBehind 3, FollowSide 2.6, WalkSpeed 15, CatchUpSpeed 26, TeleportDistance 45, StuckSeconds 2.5,
  CheerCooldown 9, CheerChance 0.35, BubbleSeconds 3, ClapSeconds 1.4, Cheers / SetDoneLines / RecordLines.
- `Config/ShowOff` Emotes: VictoryWave (2.6 s). `Config/Monetization`: ExtraTrainer pass (id nil = off).

**SoundId fields to fill:** none left empty. Every slot added this run (posing, daily, arm wrestling, ShopBuy,
DrinkShake, RivalWin, RivalLose, ...) got a licensed id in the "pick audios" pass; listen first to CrowdOoh,
RivalLose, DoorSlide, SkateGrind (the weakest fits). Trainers and photo mode reuse existing sounds (Whoosh, ShopBuy).

**TRY FIRST**
1. Town at night on your phone: set Workspace `TestClock` = 21 in Studio (or wait ~14 min): lamps, lit windows, glowing
   shop signs; walk into a gym: it should look the same as by day. Watch the FPS.
2. Personal trainer: Trainer Desk at the front left of the starter gym, hire the Rookie Coach (300), then bench: he
   stands beside you, cheers, claps at 10 reps; walk / run / skate away and see him follow or pop back.
3. Rival: talk to Benny in the starter gym, I'M IN, then a full set of 10 on the Flat Bench at 115 lb.
4. Photo mode at the gym mirror wall or the progress mirror: PHOTO, drag / zoom, pick Victory Wave, HIDE UI, tap.
5. Smoothie cart: buy a Protein Shake, leave the game and rejoin: the timer picks up where it was.

**Screenshots** (repo `screenshots/`, git-ignored; copies in the vault): posing_countdown_banner_arrow,
posing_3_contestants_score_cards, posing_vote_panel, posing_podium, posing_statue_champion, daily_quests_panel,
streak_popup_day1, streak_popup_day7, armwrestle_pick_opponent, armwrestle_vs_npc_live_bar,
armwrestle_vs_npc_phone_layout, armwrestle_win_screen, armwrestle_sign_occupy, leaderboards_starter_gym,
leaderboards_pro_gym, leaderboards_town_plaza, meals_shop_panel_starter_cart, meals_hud_timers, meals_drinking_shaker,
meals_coconut_cart_beach, rival_card_benny, rival_card_coral, rival_card_dante, rival_win_benny,
rival_card_phone_layout, emote_front_double_biceps, emote_front_lat_spread, emote_most_muscular, emote_side_chest,
emote_victory_wave, trainer_desk_starter, trainers_panel_hire, trainer_following, trainers_cheering_bench,
town_day_plaza, town_night_plaza, town_night_street, photo_mode_mirror, photo_mode_hidden_ui.

### Run notes
Sounds: the owner asked Claude to pick them ("pick audios for me"): every placeholder and new slot in `Config/Sounds` now
has a Roblox-licensed id (ProSoundEffects / APM only), plus Beach and Town area music (SettingsClient's area check now
knows the bigger gyms, the beach and the town). Weak fits to listen to first: CrowdOoh (a crowd surge; no licensed
"ooh" exists), RivalLose, DoorSlide (an elevator door), SkateGrind (a concrete grind). `Audio` skips an empty slot.

### Task 1: Posing Competition (done, tested solo)
- `Config/PosingComp` (every number), `Server/PosingCompService`, `PosingCompClient`, builder `tools/builders/PosingComp`
  (run: `Workspace.Town.PosingStage.Feature_PosingComp` = 6 taped marks, a 3-step podium, a scoreboard screen beside the
  stage), `Server/GameEvents` (a small event bus for the daily quests), stats `posingWins` / `posingEntries`, title
  "Posing Champion" (`stat posingWins >= 1`). The stage's old Montserrat backdrop text is Oswald / Nunito now.
- Flow: every 12 min a server-wide countdown (60 s; banner at the top of the right column, a marker over the stage and
  an arrow on a ring around the screen centre while it's off screen). Standing on the stage when it ends = in (max 6,
  closest first; never someone lifting or skating). Fewer than 2: NPC bodybuilders fill up to 3 (shirtless, own looks).
  Contestants get the crowd's camera; 3 poses (front double biceps, lat spread, most muscular): a ring closes on a big
  POSE button (Space / gamepad A too), the server times the tap (ping forgiven, capped 0.3 s), then the judges' card
  (1-10) goes up above every contestant. Score = 55% size + 25% balance + 20% timing. Watchers within 150 studs vote
  during the last pose (+0.5 a vote, max +2; never yourself). Podium for 10 s; coins 150 / 90 / 50 / 10; a winning
  player gets the title and becomes the statue (their own muscles, plaque "Posing champion") until the next round; an
  NPC win gives the statue back to the strongest lifter. Leaving the stage / reset / leaving = out, no reward.
- Studio hooks: `TestPosingComp` (start a countdown now), `TestPosingCountdown` (its seconds), `TestPosingWatch` (NPCs
  only, so a solo tester can vote).
- Tested (solo, FreshPlayer): countdown + marker/arrow, NPC fill, perfect taps (3 x 10 = 30, won), missed taps (8s), the
  cards, vote panel + vote counted, podium, title + 150 coins, statue + plaque, camera back to normal; no errors in
  Output. NOT tested: two real players (MCP play is solo only), phone emulator (can't be driven from here).
- Screenshots: posing_countdown_banner_arrow, posing_3_contestants_score_cards, posing_vote_panel, posing_podium,
  posing_statue_champion.

### Task 2: Daily quests + login streak (done, tested solo)
- `Config/DailyQuests` (pool of 12, 3 a day, bonus 150, 1 swap a day), `Server/DailyService`, `DailyClient`. Quests
  are picked per player per UTC day (reset 00:00 UTC; same list all day), at most one needing another player (spotting).
  Progress from `GameEvents`: MachineService fires "Rep" (with the main muscle's group; the treadmill fires
  "CardioMeters" instead), SpotService "Spot" (a session where the lifter did a rep), ArmWrestleService "ArmWrestleWon"
  (practice opponents count), PosingCompService "PosingEntered". Types: reps, groupReps, groups (3 different), cardio,
  spots, posing, armWins.
- UI: a new **Quests** tile in the side menu (owner: "one button on the HUD side bar"; tile color in `Config/HudIcons`)
  opens a panel beside the tiles: 3 quests with chunky bars, CLAIM +coins, SWAP (one a day, never swaps in a quest that
  needs another player), "Claim all 3: +150". Coach Dex's quests and the top-bar Quests pill are unchanged.
- **Login streak** replaces the old automatic streak (owner's rule: missing a day = back to day 1): `Config/Economy.Login`
  (25 / 35 / 50 / 70 / 90 / 120 / 300 coins; day 7 + a DNA token + stat loginWeeks = title "Dedicated"; then it starts
  over). Nothing is paid on join any more: the calendar card pops up after Play (after the genetics screen for new
  players) with CLAIM; the top-bar Daily pill (moved from RetentionClient to DailyClient) opens it, a dot when unclaimed.
  Old saves keep their `daily.lastDay`, so a player who played yesterday continues at day 1 of the new calendar.
- Studio hook: `TestLoginDay` (n = today's claim is calendar day n).
- Tested: day 1 popup + claim (+25), day 7 (300 coins, DNA token, Dedicated), chest reps counted to 50/50, claim
  (+60), unfinished claim refused, swap (and the second swap refused); no errors. Not tested: two players (spot quest),
  a real UTC midnight rollover (the 30 s check + the client's day check), phone emulator.
- Screenshots: daily_quests_panel, streak_popup_day1, streak_popup_day7.

### Task 3: Arm wrestling (done, tested solo vs NPCs)
- The arm wrestling already existed (one table, practice opponents, animation); it now runs at EVERY table tagged
  `ArmWrestleTable`: the starter gym's (by the front desk) and a new one in the pro gym (`ProGym.Feature_ArmWrestle.
  ArmWrestleTablePro`, open floor in front of the cable machines; builder `ArmWrestleTable.BuildPro`).
- Sitting down uses the machines' prompt: the stools' prompts are Custom style and `MachineSignsClient` draws the
  diamond ("ARM WRESTLING", the body icon with biceps + forearms in red, "1 v 1"), the key + OCCUPY and the floor outline.
- Two players = a match. Alone: pick an NPC (Rocco easy 8 coins, Tess medium 15, Big Lou hard 35) or wait for a
  player (the old auto practice opponent after 8 s is gone). 3-2-1 (ArmCountdown beeps, ArmGo whistle), then a big TAP
  button (tap anywhere / Space / gamepad A still work) for up to 8 s; the server caps taps at 15 a second.
- Strength (`Social.Strength`): biceps + forearms LOOK, 1 + 0.5 at the full look, capped (tests check a fast tapper
  can still beat Big Lou and big arms alone can't). Coins 15 / NPC coins for a win, 5 for everyone; +40 / +20 Biceps and
  Forearms XP (tiny next to a set). Beating Big Lou: stat `armKingWins` = title "Arm Wrestling King". Wins also count
  for the daily quest. Slam sound on the table (ArmSlam).
- Fixed on the way: a pin against an NPC could never happen (the NPC's push in the same tick took the full bar back to
  98%); a pin now counts the moment the bar is full. The result stays readable 4 s even after you're stood up. Phones:
  a narrower panel and a smaller TAP button (`TestPhoneLayout`).
- Not tested: two real players at one table (MCP play is solo).
- Screenshots: armwrestle_pick_opponent, armwrestle_vs_npc_live_bar, armwrestle_vs_npc_phone_layout,
  armwrestle_win_screen, armwrestle_sign_occupy.

### Task 4: Leaderboards (done, tested solo with example data)
- `Config/Leaderboards`, `Server/LeaderboardService`, `LeaderboardClient`, builder `tools/builders/Leaderboards`.
  Six boards, top 10: Biggest (average muscle look x100, "Size 142"), Strongest (heaviest weight ever lifted on any
  machine, lb; the treadmill doesn't count), Tallest (height, 7'0" max), Most reps today (store `LB1_RepsToday_<UTC
  day>`, counted from GameEvents into the save's `repsToday`), Posing wins, Arm wrestling wins. OrderedDataStores
  `LB1_<board>`; every 90 s (Config) each player's changed values are written (never for FreshPlayer / failed loads),
  each board's top 100 is read, the top 10's names looked up, and it's all published as JSON in
  `ReplicatedStorage.LeaderboardData`.
- Board walls (6 framed screens, "LEADERBOARDS" header with a light strip): starter gym front wall left of the hall door
  above the windows (fits between the window tops 8.35 and the cornice 15.7, clear of the poster and the speaker), pro
  gym front band above the glass, and a freestanding stand on posts at the north edge of the town plaza (clear of the
  corner tree / light pole / planter). Each in a `Feature_Leaderboards` folder.
- The client draws only the panels streamed in near you (on new data and when a panel streams in); headshots are
  `rbxthumb://` AvatarHeadShot images (no web calls); your name in light blue; under each board "You're #3!" in the top
  10, "Your rank: #23" inside the top 100, "Your rank: 100+" below. (Exact ranks past 100 would need a read per
  player; written down as a choice.) The older per-group wall above the front desk and the statue are unchanged.
- Studio hook: `TestLeaderboards` (example rows, nothing written). Tested: all three walls with example data, the
  real read path (empty new stores, no errors). Not tested: real data from several servers (needs a published game).
- Screenshots: leaderboards_starter_gym, leaderboards_pro_gym, leaderboards_town_plaza.

### Task 5: Shakes & meals / smoothie bar (done, tested solo)
- `Config/Meals`, `Server/MealService`, `MealClient`, builder `tools/builders/SmoothieCarts` (owner's answers 13 Oct).
  Stalls: the pro gym's smoothie bar (its counter, stools, fridge and blenders were already there from the Gyms
  builder; added a hanging menu board with the real items and prices, and the old counter card now lists them instead of
  made-up flavors), a smoothie cart in the starter gym (by the front windows) and a coconut cart on the sand by the beach
  gym entrance (`Feature_SmoothieBar` folders). Each has an invisible `OrderPoint` part in front of its counter (attribute
  MealShop) carrying the "Order" prompt (RequiresLineOfSight off), so the cart never blocks it.
- Items: Protein Shake (60 coins, +20% EXP, 5 min), **Energy Smoothie** (50, stamina refills 50% faster, 5 min; named so
  it isn't confused with the bag's Energy Shake), Chicken & Rice (90, +10% EXP and +10% refill, 10 min), Coconut Water
  (40, the beach cart only, treadmill distance x1.5, 5 min; new `cardio` boost in BoostService, MachineService uses
  it). They look different from the bag shake on purpose: a cup with a straw or a bowl icon in the item's own color (the
  bag shake keeps its white shaker icon).
- One boost per kind; buying again adds its time up to 3 purchases' worth, but only when the whole drink fits (otherwise
  the button reads FULL and nothing is charged: found in testing, the 4th buy took 60 coins for 2 seconds). HUD: a
  small pill per running boost in the right column ("Protein Shake 14:14"), from the player attributes `Meal_<id>`.
- Pause while away (owner approved): the time left is saved every 5 s (`data.meals`), restored on join (the HUD timers
  show at once). Found in testing: the periodic save could overwrite the paused times before the restore; it now waits
  for the restore. Drinking: a shaker in the item's color in the right hand for 2 s with the shake chug (everyone sees).
- Studio hook: `TestMealRejoin` (n = act out leaving for n seconds). Tested: every item bought (coins taken once each),
  the boosts multiply (EXP 1.2 x 1.1 = 1.32), timers count down, the cap and FULL, Coconut Water only at the beach cart,
  leave/rejoin (863 s left before, 862 s after 6 s away), the shaker, the prompt from the front; no errors.
  Note: Roblox's own prompt UI doesn't show in the MCP screenshots (it's there: checked with PromptShown).
- Screenshots: meals_shop_panel_starter_cart, meals_hud_timers, meals_drinking_shaker, meals_coconut_cart_beach.

### Task 6: NPC rivals (done, tested solo)
- `Config/Rivals`, `Server/RivalService`, `RivalClient`, builder `tools/builders/Rivals` (Benny and Coral in Workspace.NPCs;
  run it again after the NPCs / BeachNPCs builders, they clear every NPC with a Gym attribute).
- One rival per gym, original characters, numbers rising in the order the gyms open: **Benny** (starter gym) = a full
  set of 10 on the Flat Bench heavier than 95 lb, 150 coins + "Beat Benny" (Uncommon); **Coral** (beach gym) = win an
  arm wrestling match against her (strength 1.25, 8-9.5 taps/s; she joins the opponent list at every table once you
  accept), 300 coins + "Beat Coral" (Rare); **Dante** (pro gym, the existing 8'0" giant) = a full set on the Squat
  Rack heavier than 315 lb, 600 coins + "Beat Dante" (Epic). Copies of a machine in other gyms count.
- **Choice written down:** gyms already open by Growth Spurt (beach 1, pro 2), so beating a rival does NOT open a gym.
  Rivals are an extra goal; the win card points to the next rival and where/when he is ("Next rival: Coral at the beach
  gym (opens at Growth Spurt 1).").
- Flow: walk up to a rival, press **Challenge** (he stops and turns to you), the card shows his line, the challenge, his
  record vs your best, the reward (title plate in its rarity color), I'M IN / LATER. A set at or under his record, or a
  lost match, gets his kind line in a bubble over his head ("Close one! Come back stronger."); a win gets the win card
  (bottom, fades after 7 s) and his "Not bad, rookie." line. Saved per player (`data.rivals`, stats beatBenny / beatCoral
  / beatDante). Phones: a compact card (234 px tall).
- Size (one source): rivals are built from `Rivals.BuildSpec` (their look and scale in Config), the arm wrestling copy of
  Coral uses the same spec; NpcService.FreezeScale keeps every rival's size fixed (measured: unchanged while near and
  training, automatic scaling off). Dante keeps GymGoerService's giant shape.
- Also: the arm wrestling opponent picker now builds its buttons from the server's list (needed for Coral);
  `GymGoerService.Hold` (a regular stops and faces you); fixed a TutorialClient error (the path target turned nil while
  a path was computing, "attempt to index nil with 'Y'").
- Studio hook `TestRivalBeat` = rival id (wins his challenge for every player). Tested: all three cards, accept, a
  10-rep set at 45 lb (lose line), a set at 115 lb (Benny beaten, 150 coins, title), arm wrestling Coral picked and lost
  (her line), win cards, phone layout, sizes; no errors.
- Screenshots: rival_card_benny, rival_card_coral, rival_card_dante, rival_win_benny, rival_card_phone_layout.

### Task 7: emotes, personal trainers, day / night, photo mode (done, tested solo)
- **A) Emotes:** the Poses tile already had Front Double Biceps, Lat Spread, Most Muscular, Side Chest (one tap, everyone
  sees them); added **Victory wave** (arm high over the head, hand swinging; EmoteClient, `ShowOff.Emotes`). The panel
  turns into two columns on phones (8 buttons didn't fit the height).
- **B) Personal trainers** (instead of pets; the gym cat stays a gym NPC): `Config/Trainers`, `Server/TrainerService`,
  `TrainerClient` (panel + "Trainers" side tile), `TrainerFollowClient` (draws everyone's trainers), builder
  `tools/builders/TrainerDesks` (a desk at the front of the starter gym (left of the door, between the smoothie cart and
  the shake machine), the pro gym and inside the beach gym gate: counter, sign board, stool, props). Four coaches:
  Rookie Coach Sam +5% EXP 300, Cardio Coach Nia +10% refill 450, Money Coach Lou +5% coins 600, Pump Coach Rex pump
  fills 25% faster and lasts 25% longer 800 (new BoostService `pump`, MachineService tap). 1 slot; the Extra Trainer
  pass (`Config/Monetization`, id nil = off) adds a 2nd and the perks stack. Saved in `data.trainers`.
  Trainers are normal-size Robloxian coaches with a clipboard, built once at start (ReplicatedStorage.TrainerModels)
  and drawn locally by every client (plain parts, no EditableMesh, nothing collides); others' trainers past 90 studs
  aren't drawn. Following: behind and beside you, feet on the floor (ray), never through walls (ray), pops back when
  far or stuck. On a machine: a free hype spot or a free point around you, checked for room (found in testing: he stood
  against the next bench; now never inside a machine). Cheers in a bubble ("Push it!") with a cooldown, claps + "Great
  set!" every 10 reps (your own reps counted exactly), "New record!" on a personal record.
  Found in testing: the hair fell off the cloned coaches (no accessory weld): the templates now weld each accessory to
  its attachment. Bubbles are not always-on-top (Roblox screenshots skip those).
- **C) Day / night:** `Config/DayNight` (20 min, 70% daytime), `NightLightService` runs the clock (Workspace attribute
  DayStart), `DayNightClient` moves the sky on every client and fades only the OUTDOOR ambient (gyms keep their light).
  At night: the 207 street / wall lamps and string lights (as before), the shop windows and 278 of the town's 431
  windows (builder `tools/builders/NightGlow`, tags NightWindow / NightSign), and 28 gym / shop signs light themselves
  (SurfaceGui, no new lights). No new shadow lights.
- **D) Photo mode:** `Config/PhotoMode`, `PhotoModeClient`. A PHOTO button (camera icon) in the right column near the
  gym mirror walls, the clothing store mirror, the progress mirror and the posing stage. Hides every screen and Roblox's
  own buttons, prompts and machine signs, freezes walking, camera turns around you (drag) and zooms (wheel / pinch),
  never inside a wall; pose row; HIDE UI, then a tap anywhere ends it; X / Esc too. Found in testing: the mirror lookup
  picked the starter gym's second, smaller mirror panel (same name): every instance on the path is checked now.
- Studio hooks: `TestClock` (hours), `TestTrainers` ("RookieCoach,PumpCoach"), `TestTrainerSlots` (2), `TestPhotoMode`.
- Tested: hire at the desk (coins once, perk on), follow, both trainers on a bench (clear of parts, cheering), day and
  night views + render times, photo mode enter / pose / hide / exit, every emote; phone layouts of the trainer panel
  (316 px) and poses. No errors in Output.
- Screenshots: emote_front_double_biceps, emote_front_lat_spread, emote_most_muscular, emote_side_chest,
  emote_victory_wave, trainer_desk_starter, trainers_panel_hire, trainer_following, trainers_cheering_bench,
  town_day_plaza, town_night_plaza, town_night_street, photo_mode_mirror, photo_mode_hidden_ui.

## Before that (13 Oct): soft shutdown
- `Server/ShutdownService`: when Roblox closes a live server (after a publish: Creator Hub > Servers > "Shut down all
  servers" / "Migrate to latest update"), players get a small note ("The gym is updating..."), are teleported together into
  one reserved holding server, and after 6 s go back to a fresh public server on the new version. Saves run as before
  (BindToClose + leaving by teleport); the holding server runs ONLY this service (`Main` returns early), so it never
  loads data or takes a session lock; its loading screen says "Updating the gym / Taking you to the new version. Your
  progress is saved." Teleports retry (4 tries + TeleportInitFailed). Off in Studio. A private server's players come back
  to a public server.
- Tested in Studio: the note and the holding screen (via the `SoftShutdown` Workspace attribute); the teleports themselves
  only work in a live game (test after publishing: join, then "Migrate to latest update").

## Before that (13 Oct): 7'0" Growth Spurt cap + NPC size glitch
- **Cap:** `Config/GrowthSpurts.MaxHeightInches = 84` (`MaxHeight` kept as an alias). `GetHeight` clamps to it;
  `MaxSpurts()` = 6 (the spurt that lands on exactly 7'0"); `IsMaxed`; `Progress().maxed` makes `ready` false, so
  `PlayerData.GrowthSpurt` refuses on the server (nothing charged: a spurt never cost anything). Muscles keep growing.
  Saves hold only the spurt count, so a save past spurt 6 is shown and built at 7'0" with nothing else changed; Studio
  prints "past the height cap ... clamped to 7'0". Clamped this server: N" on load. `FormatHeight` adds " (MAX)" at 7'0"
  (menu profile, Muscles panel, top progress bar, mirror card, the Growth Spurt note).
- **Button at max:** the Muscles panel button reads "MAX GROWTH SPURT REACHED" (wraps to 2 lines, padded), greyed,
  `Interactable = false`; the top bar says the same and isn't tappable; the body-map widget says "Max". All switch live.
- **7'0" mass monster fits:** sauna doorway was 2.3 x 5.95 (builder `Sauna`, rebuilt): now 4.4 wide, open to the top
  plate (7.5 clear), two door leaves, sign + lantern moved beside it. Flat bench: big bodies slide toward the feet until
  the shoulders clear the J-hook uprights (`MachineService` clearUprights; a 4'0" player moves 0.02). Pull-up bars and
  hanging leg raise: uprights 7.8 apart (were 5.2 / 3.4), the left starter pull-up moved 1.2 left; hands stay on the grip
  span with the elbows a little forward (`bars.hangGrip`). Dips handles 3.5 apart (were 2.3; `Poses.Dip.handleX`).
  Builders `GymKit` / `Gyms` updated to match. Left as is (hidden or small): incline seat under the thighs (~0.4), dip
  calves touching the posts, leg-press rails under the body. Doors 7.9+, ceilings 16/18; camera follows the head (fits).
- **NPC size glitch (Dante skinny / suddenly huge) - causes found:**
  1. Roblox rebuilt NPC body parts from their scale values on every CLIENT the moment the NPC started walking
     (Humanoid.AutomaticScalingEnabled): Dante's torso went 5.75 -> 2.00 wide (skinny) until the next MuscleClient scan.
  2. The per-rep pump in MachineClient resized NPC body parts (it skipped live muscle meshes but not stage meshes); then
     `fixNpcBody` read the pumped size as a "Roblox rebuild" and multiplied it by his 2.88 width again: one pumped rep
     made his torso 17 studs wide and shorter each time (measured).
  3. The statue (and mirror rigs) lost the golden ratio on the server the same way when parented.
  Fix: automatic scaling is off once an NPC / the statue / mirror rigs are shaped (`NpcService.FreezeScale`), so nothing
  rebuilds them; `MuscleClient.restoreShape` puts back the server's exact replicated sizes (WidX / PropY / WidZ) on NPCs and
  other players, never re-widening and never writing attributes; the pump never resizes a shaped or meshed part (pumps
  show through the tint only); stage choice ignores PUMPED (no stage pop while training); other bodies keep their stages
  out to 180 studs (was 80), so the plain-body switch happens where they're a few pixels tall. Measured after: no client
  rescale while walking, a forced resize snaps back to the exact server size.
- Dante stays 8'0" (owner's 9 Oct rule: an NPC no player can reach); the cap is for players, the statue and mirror.

## Before that (9 Oct): MAX weight button
- Machine panel: a MAX button directly on top of the + button and in line with it (it sits in the + button's holder,
  scale-sized, so the left edge and width match exactly), a slight soft-yellow glow (yellow 10% toward white; owner's layout after a few rounds), 1/3
  of its height (16 px), a 3 px gap, a yellow background (bumper yellow at the + button's 0.55 transparency) with white
  14 px text; the - and + buttons sit 10 px lower (each in a same-size holder in the row). MachineClient, created without a new top-level local: the
  script is at Luau's 200-local limit. Screenshot max_button_above_plus. Server `MaxWeight` action (MachineService maxWeight): buys every next plate in order while the
  main muscle's level allows it and the coins cover it (same checks as UnlockTier), then selects the heaviest usable plate
  (Machines.UsableTier). The panel jumps there at once when nothing is bought, or when the purchases arrive.
- Tested (fresh player, ~225 coins, MidChest level 26-27, Flat Bench): MAX bought plates 2-6 (157 coins; plate 7 needs
  level 33) and showed 155 lb, tier 6; after two "-" steps, MAX went straight back to plate 6 without spending.

## Before that (9 Oct): Dante 8'0" (uncapped widths) + NPC upper traps (re-imported, in Studio)
- **Dante is 8'0"** (owner: an NPC no player can reach; players cap at 7'0"). Same width formula as players
  (BodyService.WidthFactors) with no cap for him: his made-up data carries `heightInches = 96` (targetHeight uses it;
  saves never have it), s = 96 / 48 = 2.0: shoulders (1 + 1.4 x 1) x 1.2 V-Taper = 2.88, hips 2.20, arms / legs /
  depth 1.90. Measured: height scale 1.60, UpperTorso 5.75 wide (server and client), hips 3.63. Screenshot giant_dante_8ft.
- **NPC / other-player upper traps**: the stage meshes were regenerated in Studio from the new muscle data (all 62 rewritten
  in Downloads\other_player_stages; only the 14 torso ones change) and src Config/BodyStages.luau has the new torso
  bounds. The owner re-imported the 14 files (reimport_torso_upper_traps); Config/BodyStages synced and
  tools/body_stages_setup run (it now replaces same-name templates): 14 torso templates replaced, 62 in the folder, none
  missing, import turn 180 (matches). Tested on frozen test copies at the full look and the mass monster, and on Dante:
  the traps rise from the neck to the shoulders, no clipping, no download errors (screenshots npc_upper_traps_back /
  _front, dante_upper_traps_back). Studio is left with Workspace TestMuscleShare = 2 for the owner's 2-player test
  (remove it afterwards).

## Before that (9 Oct): NPC body shapes lost on clients (the giant looked narrow)
- Found while widening Dante: Roblox rescales an NPC that has a height scale on EACH CLIENT and drops the server's
  shaping, so on players' screens Dante's body parts were plain (UpperTorso 2.00 wide instead of 4.91) and Kira, Ivy and
  Marcus lost the golden ratio; the stage meshes size from the body parts, so his shoulders looked narrow. Players were
  fine. Fix: `MuscleClient` (fixNpcBody, each scan, only NPCs it shows muscles on) re-applies the widths (the giant's new
  `BodyWidths` attribute: shoulders 2.46, hips 1.90, arms / legs / depth 1.674 = the mass monster widths at 7'0" with the
  V-Taper frame) and the proportions when the client's sizes differ from the server's markers (two numbers compared).
  Tested: every NPC matches the server on the client; Dante's chest stage is 6.92 wide (was 2.81), wider than a maxed
  player (screenshot giant_vs_maxed_player).

## Before that (9 Oct): upper traps
- The owner's upper traps never grew: the package's Traps only pushes the upper back out; the slope from the neck to the
  shoulders was a flat fan cap. `tools/gen_muscle_data` now gives the torso cap a ring halfway in (every 4th rim vertex:
  each torso half is 19,950 triangles, the limit is 20,000; four full rings broke the torso) and adds UPPER_TRAPS to the
  Traps muscle: up 0.13 studs at the full look (x the mass monster g), a little back, from beside the neck to the
  shoulders, fading out over the collarbones. Cap vertices get their normals from the cap. Regenerated MuscleData
  (torso + the arms' cap normals), synced; tested at the full look: screenshots upper_traps_back, upper_traps_front.
- Not done: other players' torso stage meshes (BodyStages OBJs) don't have it yet: regenerating them needs the owner to
  re-import the 14 BS_Torso files.

## Before that (9 Oct): arm wrestling animation + the giant regular (synced and tested in Studio)
- **Giant regular** (owner): Dante (pro gym) is 7'0" (the last Growth Spurt's height) with the mass monster physique,
  built like a maxed player (every muscle at 5.5x that spurt's goal, monster widths, V-Taper frame = the widest
  shoulders, golden ratio): measured UpperTorso 4.91 wide (Ivy 2.00), hips 3.14 (1.65). Shirtless in black gym shorts,
  bald (Shirt, Pants and hair removed, parts painted skin / shorts), so the Stage5 mass monster skin texture shows on
  him (tested: Stage5 on 10 parts; screenshot giant_dante_shirtless). `GymGoerService`
  GIANT / makeGiant, `NpcService.ApplyBody(npc, heightScale)`. Tested: height scale 1.40, monster stage meshes on.
  Screenshot giant_dante.
- **Arm wrestling animation**, new `ArmWrestleClient` (every client): both wrestlers sit facing each other, lean in,
  the right elbows toward their pads, hands clasped over the table, free hand on the peg; the hands swing toward the
  loser's side with the meter and shake; the winner slams the arm down, holds it, then pumps the fist. The grip sits a
  little above both wrestlers' shoulders (averaged) and is split by arm length, so a 4'0" player and a tall one still
  meet. The practice opponent now sits on the stool (legs posed). Screenshots armwrestle_grip, armwrestle_live,
  armwrestle_win_fistpump.
- Server (`ArmWrestleService`): publishes AwState / AwMeter / AwWinner on Workspace.ArmWrestleTable (meter at 10 Hz,
  rounded); a pin ends on the full meter; the rookie stays seated for the slam (2.5 s). Config: `Social.ArmWrestle`
  SeatedRootY, LiveAngle, PinAngle, AnimateDistance.
- Cheap for slow devices (owner at ~20 FPS): nothing runs unless someone is at the table AND it's within 70 studs of the
  camera; joints cached; no per-frame searches or new tables. The lighting pass now has only 4 shadow-casting lights
  (was 14; GymLighting re-run). Growth Spurt 0 start synced into Studio.

## Before that (9 Oct): release data reset + save-lock fix
- **Fresh data for the release**: player saves now live in the DataStore `GymArcDataStoreV1` (the old test saves stay
  untouched in `PlayerData_1`), so everyone starts over. New players start at Growth Spurt 0 (4'0"), muscles 0, 0 coins
  (`DataTemplate`; was Growth Spurt 6 for testing). The leaderboards (`LeaderboardV1_<group>`) and crews (`CrewsV1`,
  `CrewLeaderboardV1`) are fresh too, so test scores don't show on the wall or the statue.
- **"Your data is still saving from another server" kick** (owner's live account): a dead server's session lock blocked
  rejoining for 5 minutes. Now: dead locks expire after 180 s (live locks are refreshed by the 60 s autosave), the
  loader waits up to ~60 s instead of 30 s before kicking, a lock left by a Studio playtest never blocks a live
  server, sessions that don't save (Studio TestMuscleExp) still release their lock, and FreshPlayer playtests don't
  touch the real save at all. Tested: FreshPlayer starts at Growth Spurt 0 (4'0"), muscles 0, and leaves no entry in
  the new store.

## Before that (9 Oct): gym lighting pass
- New builder `tools/builders/GymLighting` (run in Studio; `Gyms.Build` now runs it at the end). Only lights and small
  light fixtures, no other geometry changed; Lighting service untouched (outdoors looks the same).
- **Starter gym**: pendants brighter and tighter (Brightness 9, Range 24, Angle 90: real warm pools; 2 of them
  cast shadows), 3 extra pendants over the centre aisle and leg machines, fills dimmer and less orange, high windows
  brighter, the neon sign's spill kept subtle. 9 warm wall washers (small black can lights on brackets) graze the brick
  on the west and back walls (`StarterGym.LightingPass`).
- **Pro gym**: spotlights brighter and tighter (Brightness 7, Angle 60; the fills were washing their pools out), fills
  and ceiling light bars toned down, 14 neutral wall washers on the east and back walls (`ProGym.LightingPass`).
- 109 lights in both gyms (was ~83), only 4 cast shadows (cut from 14 for the owner's ~20 FPS). Screenshots: lighting_before/after_starter, lighting_before/after_pro,
  lighting_wall_washer. Values are at the top of the builder to tweak.

## Before that (9 Oct): new loading screen and menu, matte machine signs
- **Loading screen** (`ReplicatedFirst/LoadingScreen`, rewritten): dark room, a soft overhead glow (stacked faint ovals),
  chalk dust drifting up, GYM ARC + tagline, a 2D barbell that loads with the game: 5 pairs of bumper plates (red, blue,
  yellow, green, white; heaviest inside) slide on with a clank (Config.Sounds Clank's id, pitch by plate), collars close,
  the bar lifts ("Let's lift"), then it fades. Rotating original tips. Same logic as before (MenuLoad / MenuReady, the
  body stage wait, 30 s give-up). Screenshot: loading_barbell.
- **Menu** (`MenuClient`, rewritten): a cinematic tour (entrance "Main Street", starter gym, pro gym, beach gym, skate
  park: slow dollies, depth of field + a little contrast on the camera, dips through black, a place caption bottom
  right; the next place streams in during the current one), a left column over a black fade (title, rule, tagline,
  profile for returning players, breathing PLAY with a light sweep, TITLES / SETTINGS, chips), rows slide in after the
  loading screen; the old separate player card is folded into the profile. Tested as a new and a returning player.
  Screenshots: menu_returning_main_street, menu_pro_gym, menu_skate_park. Shots are in MenuClient `PLACES` to reframe.
- **Machine signs are matte** (owner): the diamond was the Glass material, which mirrored the room; now SmoothPlastic,
  Reflectance 0 (same tint and transparency).

## Before that (9 Oct, after midnight): new spotting system (owner's 3-player test next)
- Replaces the old "Spot" prompt (SocialService keeps only the together bonus). `Config/Spotting` (all numbers),
  `SpotService` (server, remote `Spot`), `SpotClient`, spot types in `Config/Machines`, `tools/builders/SpotPoints`
  (run: spots on all 54 non-cardio machines, every hype spot clear with a view of the lifter), Settings "Spot requests".
- Flow: tap a lifter -> SPOT / X popup -> the lifter's card (ACCEPT / X, 8 s) -> the spotter stands at their spot (root
  anchored) and pushes by clicking / tapping anywhere (owner: no push button; F too), meter + EXIT; moving / jumping /
  EXIT / the lifter leaving / death / leaving the game end it. Boost by count x1.10..1.50 + 0.15 x clicking fraction;
  coins every 10 lifter reps (5, +3 while clicking); spotted reps still count for the Spotter title.
- Tested alone (it needs 2+ players for real): logic tests (`tests/spotting`: the boost table, spot types, layouts, tap
  rules with exact timings: 5 uneven taps/s = clicking, 2/s not, 20/s capped at 8, perfectly even taps never count);
  in play with server-sent example messages: request card (top left), spotter panel, hype pose, hands pose at a bench
  (hands under the bar), clicks on the world reach the server as pushes; no errors. NOT tested: two real players.
- Screenshots: spot_request_card, spot_spotter_panel_hype, spot_hands_bench_middle.
- **Spotter feel (owner: "more dopamine"):** a ring where you click (gold while boosting), a push tick climbing in pitch
  with the combo, a combo counter ("x23", gold from 10) that hops, milestones 10 / 25 / 50 / 100 / 200 (ding, gold
  flash, "COMBO 25" floats up), boost on = gold border + meter + "BOOSTING x1.35" + ding, a coins bar (a plate per lifter
  rep, gold when you pushed on it) with "Coins in 4 reps", a gold "ASSIST" over the lifter, payout = coins fly to the
  coins pill + "+8 COINS", and a wrap-up note ("12 reps spotted, +13 coins"). Server sends "Rep" every lifter rep.
  New sounds SpotPush / SpotBoostOn / SpotCombo / SpotAssist / SpotPayout are PLACEHOLDERS (existing ids): owner picks.
  Screenshots: spot_dopamine_combo_boost, spot_dopamine_payout.

## Before that (9 Oct, after midnight): the beach gym uses the real machines
- The 9 beach-only machines (Beach Curl, Beach Lateral Raise, Beach Shrug, 3 rows) are gone, configs too; in their spots
  copies of the real Bicep Curl, Lateral Raise and Shrugs (`GymKit.Pro`, same model / name / config / tiers / EXP /
  MachineId), done in place with `Town.RebuildBeachMachines()` (the Town builder builds them the same way). Weights,
  "NEW" tags and quests are shared with the pro gym (5 beach curl reps recorded `BicepCurl`). The beach squat racks,
  benches and pull-up bars already were the real ones. Pro gym checked: only real machines, no "Pro" copies; no "Beach"
  machine names left anywhere (prompts, signs, quests, the Muscles panel lists machine names from the config).
- Every beach machine has the model attribute `Gym = "Beach"`: `Machines.GymOpenAt` opens it with the beach gym (Growth
  Spurt 1), never later than its own gym, so the curls there open at 1 (in the pro gym at 2). Tested: at Growth Spurt 0
  "The beach gym opens at Growth Spurt 1."; at 6 you sit down. The Growth Spurt goal doesn't change (same muscles).
- Old saves: progress on BeachCurl / BeachRaise / BeachShrug moves to the real machine (`Machines.Renamed`, PlayerData;
  the higher tier wins). `TestMachine = "Beach/BicepCurl"` picks the beach copy without raising Growth Spurts.
- Stage meshes: the client checks the downloads again 6 s and 30 s after the first pass (a failure outside it was
  missed once). Screenshots: beach_real_machines_row, pro_same_machines.
- Not saved to Roblox yet (owner: File > Save to Roblox; the Studio window is titled "Place2").

## Before that (8 Oct, ~11 PM): other players' muscles as body stage meshes (ON; owner's 2-player test next)
- **Why:** a client holds at most 8 EditableMeshes, a hard COUNT (measured: plain, fixed-size, asset copies and a 200-
  triangle mesh all fail once 8 exist), and your own body uses 7. So nobody else can have live muscle meshes; LOD
  EditableMeshes don't help either. Also `AssetService:CreateAssetAsync` is still "not available yet" (no mesh upload from
  a script). Server side was already fine: `MuscleG` (+ Top, Shorts, SkinColor) on every Player, NPC and the statue.
- **Built:** `tools/gen_body_stages.luau` (runs in Studio with the game's own muscle data; receiver
  `tools/gen_body_stages_receive.ps1`) wrote `Downloads\other_player_stages\other_player_stages_torso.obj` (14 meshes) and
  `..._body.obj` (48): per region 7 stages (look 0, 0.2 .. 1.0, mass monster; the waist 6) with the region's muscles at that
  look; same coordinates, triangles and UVs (V flipped like the limb stage OBJs) as the live meshes; each <= 19,901
  triangles; validated (no NaN, faces in range). `Config/BodyStages` (generated: regions, pieces, each mesh's bounding box).
  `Shared/BodyStages`: per region the stage from the averaged look values (hysteresis), cross-fade 0.3 s, Shirt / Pants
  as TextureID, skin / top / gym-shorts colors, skin texture stage on skin pieces, tints, Growth Spurt scaling, the plain
  part hidden. `MuscleRig` uses it for every rig that isn't your own (players, NPCs, the statue); the mirror's "Day one"
  card wears look 0. Your own character is unchanged (live meshes). Previewed in Studio (look 0 / full / monster).
- **Imported and ON:** the owner imported the 62 one-mesh OBJs (Import 3D merges a multi-object OBJ into one "default"
  mesh, so the first 2-file import was thrown away); `tools/body_stages_setup.luau` moved all 62 into
  `ReplicatedStorage.BodyStages` (0 missing, sizes match, the importer's 180 degree turn is undone by `ImportTurn`). A
  client warns once in Output when any stage mesh is missing. Solo play check: NPCs within 80 studs wear the 9 stage
  parts with their own Shirt / Pants textures, plain parts hidden; your own character still on live meshes. Next: the
  owner's 2-player test (Clients and Servers). The place must be saved (File > Save to Roblox) to keep the templates.
- **Download hiccups:** in some play sessions ONE stage mesh fails to download ("MeshContentProvider ... could not fetch",
  a different one each time; the same mesh loads fine in Edit and in the next session), and the engine keeps the failure
  for the session. The client now preloads the 62 templates, warns once, shows the nearest stage that loaded instead (no
  hole), and fetches the failed one again (AssetService, 4 tries); a warning if it still fails. Tested with the Studio
  hook `TestBrokenStage` (Workspace attribute = a template name: acts as a failed download that never repairs).
  The 62 meshes download in batches of 6 behind the loading screen ("Loading players", the last 10% of the bar, at
  most 8 s after the menu is ready; measured ~5 s), so they are in before you see anyone.

## Before that (8 Oct, late night): machine diamond + prompt, red training tint, no back/neck accessories, bigger gyms, treadmills
Saved to Roblox (22:41 and 22:43); dated backup `Documents\GymArc_backups\GymArc_2026-10-08.rbxl` (via File > Download a
Copy). Not published yet: publish (Alt+P) to make it live. Next up (owner's later briefs, waiting for the OK on this
one): the beach gym uses the real machines, then the new spotting system (the second version of its boost table: by
spotter count, coins only).
- **Machine sign (`MachineSignsClient`, rewritten):** the nearest machine within 12 studs shows a floating glass diamond
  (square turned 45 degrees, dark tinted glass, thin glowing Neon border, slow bob) that turns smoothly toward the
  camera on BOTH axes. Its content (BodyFigure icon with the main muscle in red, the muscle name, the share in red) is a
  SurfaceGui on an upright face that turns with the glass, clipped to a safe square inside the border, text shrinking to
  fit (owner's bug: text spilled over the frame when the camera pitched). Name above and the prompt below are offset in
  screen space (never over the diamond): a square dark-glass key ("E" / gamepad / tap) and "OCCUPY", or "UNLOCK · 45
  COINS" when the next weight can be bought. Machine prompts are Custom style, 10 studs (MachineService). Glowing floor
  outline around the footprint, brighter when you stand in it. 12-60 studs: only "!" + "NEW" on unused machines.
  Hidden while you're on a machine. The old card and Roblox's wide "Use" panel are gone. Studio hook `TestSignCamera`
  (a Vector3: the sign faces that point, for screenshots from any angle).
- **Training tint is red** (255, 70, 70; the rep pulse lighter red), same softness / falloff (`MuscleRig` TINT).
- **No Back / Front / Neck accessories** on anyone (`AccessoryService`, new): removed on spawn, outfit change, body
  rebuild, for players, NPCs, legends, the statue. Hats, hair, face accessories stay.
- **Bigger gyms (~1.5x floor):** starter 88 x 85 (ceiling 16), pro 68 x 85 (ceiling 18), shared wall x 44.5, both to
  z -89. `Gyms.Map` spreads the old layout into the new rooms (wider walkways, more room between machines); Decor,
  NPCs, Seasons and the Config spots (re-rack spots, legend spot, Coach Dex, leaderboard, arm wrestling table, pro door
  outside spot) follow it. The town's gym fronts, roofs and boundary are rebuilt for the new size
  (`Town.RebuildGymExterior`); terrain cleared / lowered under the floors (grass blades grew through), 9 lawn trees /
  rocks removed. Leg Press / Hack Squat are now in the Gyms builder (were hand placed).
- **Pro gym premium:** chrome free-weight racks, wood platforms, a mirror wall across the back, rubber floor with a
  tile grid, linear LED lights + LED strips, warm spotlight pools, a smoothie bar corner by the glass door (counter,
  back bar with a drinks fridge, blenders, three stools), hanging zone signs (FREE WEIGHTS, MACHINES, CARDIO, STRETCH,
  SMOOTHIE BAR). `ProGymPolish` folded into the builder and deleted.
- **Treadmills:** the one "near the pro gym door" that didn't work was the starter gym's first treadmill: decoration
  only (no Machine tag, no prompt). All 3 starter treadmills are now real, the same premium model as the pro gym's.
  The run is a real running cycle on its own clock (stride rate / size follow the belt speed, knees lift, arms swing
  opposite, slight lean, bounce), not one stride per rep.
- **Plates the gym cat (owner, 8 Oct night):** "Plates pet" was the cat (named Plates), not the plate trees I first
  moved (they stay in the back-left corner). The cat and its round bed are now ONE model (`Workspace.NPCs.GymCat`:
  `Bed`, `HeadGroup`, `Tail`) lying in the starter gym's front-right corner just west of the towel rack, out of the
  walkway to the pro gym door; the old separate bed is deleted; the Gyms builder no longer makes a bed and the NPCs
  builder no longer moves the cat (`GymCat.Spot`). Idle: tail wag + a slow look-around (ShakeClient). Screenshot:
  gym_cat_on_bed_by_towel_rack.
- Checked in play: sign at every angle (below / above / side, the longest names), "!" only from the middle, red tint on
  bench reps, accessories gone (your guitar), both gyms, the run; no errors in Output. Screenshots: sign_angle_{below,
  above,side}, sign_diamond_*, gym_middle_only_bangs, training_tint_red_bench, accessories_hidden_back,
  {starter,pro}_gym_bigger_wide, pro_gym_smoothie_corner, starter_gym_back_corner, treadmill_run_stride{,2}.
- Tutorial text says "tap Occupy".

## Before that (8 Oct, 10 PM): bigger skate park, grinding, smooth quarter pipes
**Saved to Roblox (v302, 9:57 PM).**
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

**Backup:** done at 22:43 (see the LATEST section).

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
1. **Publish (Alt+P)**: everything saved tonight (arrows, skate park, machine signs, bigger gyms ...) is not live yet.
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
