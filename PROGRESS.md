# GYM ARC — Progress

Short and current. The full build history (test steps, numbers, reasoning for each step) is in git:
`git log -p -- PROGRESS.md` or any commit before 6 Oct 2026.

## Workflow
- **Roblox Studio is the source of truth** for scripts and builds.
- **GitHub is a backup:** after each piece of work every script is exported from Studio into `src/`
  (`tools/export`, mirrors the Explorer), then committed and pushed.
- **Save/publish the place in Studio after every session.** Studio edits (scripts, builds, lighting) exist only in
  the open place until it's saved.
- World areas were built once from recipes in `tools/builders` (see `tools/bake.md`); edit them as normal parts.

## Test first (6 Oct 2026)
1. **Save the place** (this session changed scripts, the sea, the baseplate and `StarterGui.ScreenOrientation`).
2. Fresh-player run: Workspace `FreshPlayer` attribute on → Play → genetics (corner messages now wait until you
   press Keep) → tutorial on the bench: stamina should now visibly drop while lifting → only every 5th main-muscle
   level shows a corner message.
3. Phone check (Device Emulator, any phone, landscape): genetics screen (side menu hides, names don't overlap),
   Title Book / clothing store / mirror (header below the top bar), get on a machine (side menu shows only Stats,
   top left).
4. Walk to the beach: the sea now starts at the sand (it used to sit under the grass).

## Done
- Player data: 18 muscles, stamina, coins, genetics, height, titles; DataStore saves with session locks, UpdateAsync.
- One reusable machine system: 8 starter machines, 11 pro gym machines, 3 beach machines, Sled Pull (winter).
- Clean minimal Theme UI; Stats live overlay (labels always visible, sub-muscles, Growth Spurt goal).
- Game feel: rep animation, weighty motion, pump, body scaling, gain popups + "Gain numbers" setting, sounds.
- Growth Spurts (taller, permanent bonus), titles + Title Book, genetics reveal/reroll (3D barbell).
- Menu screen + first-5-minutes tutorial; Coach Dex quests; Muscle of the Day.
- Energy Shakes, stretching mat, gym cat; economy (streak, offline coins, re-racking, DNA tokens, rush hour).
- Spotting, lifting together, arm wrestling; crews; emotes; leaderboard wall, statue, membership card.
- Legend NPCs; seasonal events (Halloween, Winter, Summer); area music.
- Town hub: smoothie bar, clothing store + Wardrobe (gear on the character), skate park + skateboard, beach gym +
  posing stage, progress mirror (before/after screen).
- Launch readiness: remote rate limits and prompt distance checks (`Server/Guard`), safer purchase saves, fewer
  shadow lights, analytics onboarding funnel.
- All world areas are real Studio builds (pro gym, town, sea, mirror, cat, NPCs, leaderboard wall, statue pedestal,
  arm wrestle table, season decor). Scripts only find and wire them.
- Workflow switch: Studio = source of truth, `tools/export` writes scripts back into `src/`.
- Phone layouts (landscape): genetics, Title Book, clothing store, mirror, machine HUD; game locked to landscape.
- Growth Spurt pacing: 18.5 / 25 / 35 / 45 minutes (1st / 2nd / 3rd / 4th+), see "Pacing" below.

## In progress
- Nothing half-built. Next candidates: a 2-player playtest pass, Stats labels on a real phone.

## Open / waiting on you
- **Sound ids** (you're picking them). Every sound is in `Config/Sounds.luau`. Placeholders that reuse another clip:
  `LevelUp` (Set-complete ding, pitched up), `Maxed` and `TitleUnlocked` (Growth Spurt bell, pitched up),
  `TierUnlocked` and `GeneticsClank` (plate clank), `OutOfStamina` (breath), `GeneticsThudLow` (floor thud),
  `RepTick` and `Click` (same button click). No sound at all yet: skateboard rolling, sliding doors, buying in the
  clothing store (uses Click), mirror opening (uses Whoosh). Area music only has Starter and Pro; the town, beach
  and skate park play whatever was last playing.
- **Badge ids:** Aesthetics God, Skyscraper, Defied Genetics have `badgeId = nil` in `Config/Titles.luau`.
- **Monetization ids** (stays off until you add them): 7 game passes and 3 developer products in
  `Config/Monetization.luau`, all `id = nil`. With no ids the Store button never shows.
- **DataStore name:** Studio's `PlayerData` saves to `"PlayerData_1"`; the repo had `"PlayerData_xz"`. I kept
  Studio's. If that wasn't a deliberate reset, saves made under the old name won't load. Tell me if it should go back.
- **Portrait:** I locked phones/tablets to landscape (`StarterGui.ScreenOrientation = LandscapeSensor`); the machine
  HUD, Stats labels and genetics barbell are landscape designs. Set it back to `Sensor` if you want portrait, and
  I'll lay the screens out for it.

## Known issues
- Spurts after the 11th get a few minutes longer each (the permanent bonus hits the 5x multiplier cap). Fine for now;
  lower `ExtraPerStage.requiredLevel` or raise `Gains.MaxMultiplier` if it matters.
- ProximityPrompts only show when their part is on screen (Roblox behaviour): the mirror on the hall's side wall
  needs you to face it.
- Cosmetic headbands can hide under very big hair accessories.
- On short phone screens a corner message can briefly sit over the right-column pills (rush hour, shake).
- Not playtested this session: 2-player features (spotting, high fives, crews, arm wrestling vs a player) and lifting
  on pro gym machines (locked for a new player; needs a Growth Spurt 2 save).
- Stats world labels on phones weren't checked on a real device (Studio screenshots can't draw them).

## Overnight run (6-7 Oct 2026, from GYM_ARC_overnight_prompt.md)
**The place was NOT saved by me** (the MCP connection has no save). Everything below is live in the open Studio
place and backed up in `src/`; please File > Save to Roblox first thing.
- Session 0 (Rojo removal): done. Repo files were already gone (default.project.json, rokit.toml, sourcemap
  line in .gitignore, Rojo lines in README/CLAUDE/tests/export notes). No game script mentions Rojo or
  `Lighting.Technology`; Lighting is Realistic + PrioritizeLightingQuality, StreamingEnabled on.
  **Your Studio still has the Rojo plugin installed (two versions, 7.4.4 and 7.7.1)**, and `~/.rokit` (outside the
  repo) still holds rojo.exe. Remove the plugin in Plugins > Manage Plugins; I can't uninstall plugins from MCP.
- Session 1 (bugs + game feel): done, playtested.
  - Bug a (can't re-use a machine): the client hid the machine's prompts while lifting and re-hid any change; the
    server re-enables the prompt just *before* sending Exit, so the client caught that and hid it again for good.
    Fixed in `MachineClient.close`. Tested enter/exit 5x on the bench, then the pull-up bar.
  - Bug b (floating arms on "Day one"): both mirror bodies are now real rigs built on the server from your avatar's
    HumanoidDescription (`MirrorService`), scaled by the description's height/width/depth and shaped by the new
    `Shared/BodyShape` module. Fixed.
  - Bug c (mirror didn't reflect): the glass now shows a live mirrored copy of you and the room in front of it
    (SurfaceGui + ViewportFrame, client only, only within 25 studs). See `MirrorClient` bottom section.
  - Bug d (broken statue): rebuilt from the leader's description (default body if there's no leader), all marble,
    double-biceps pose, every part placed from its joints before anchoring. Fixed.
  - Root cause behind b and d, worth knowing: **avatars in this place use Roblox's newer joints
    (AnimationConstraints), not Motor6Ds.** Emotes and the skateboard lean only looked for Motor6Ds, so they did
    nothing; fixed (both kinds now work everywhere). Machine poses already worked.
  - Lifting: reps run on their own (slow pace); tapping (Lift button bottom right, a click/tap anywhere, Space)
    makes them faster and fills a PUMP meter; full = PUMPED for 8 s (x2 gains, faster reps, gold glow on the
    trained muscles). ~1 in 12 reps is a gold BIG REP (x3). Every rep: clank + small camera punch + "+N" pop.
    Level up: "Mid Chest · Level 12" flash + sparkle burst + chime. New heaviest weight: "NEW PR" banner + sound.
  - Always-visible Growth Spurt bar (top center, `ProgressClient`) with a "next goal" line under it (reps to the
    next weight, coins for it, or which group to train). Tapping it when ready does the Growth Spurt.
  - Visible growth: size grows in 5 clear steps per Growth Spurt (whole body wider/deeper + trained parts
    thicker); each step plays a "you grew" pulse + sound + "You grew! Bigger Arms" note. Growth Spurt keeps the
    height and resets the size.
  - Weights: 12 tiers on every machine (`Config/Machines` Progression table); each needs the main muscle's level
    (again after every Growth Spurt) and coins once. The machine prompt shows your next weight and what it needs.
  - Plates: one color per weight (55 red, 45 blue, 35 yellow, 25 green, 10 white, 5 steel) on bars and the HUD.
- Next: Session 2 (gyms, equipment, NPCs).

## Decisions made overnight
- PR banner: your brief's design file lists "personal-record popups" as CUT, but tonight's prompt asks for a NEW PR
  banner. I followed tonight's prompt (small banner, not a popup window).
- Gold (#F2C14E) added to Theme for big moments only (BIG REP, NEW PR, PUMPED). Plate colors stay the bumper colors.
- PUMPED and BIG REP multiply gains *outside* the 5x cap (they're earned by playing; inside the cap they'd do nothing
  after a few Growth Spurts). Shakes/genetics/spurt bonuses stay inside the cap.
- "Gain numbers" setting: On = everything, Minimal = set + BIG REP popups, Off = no gain popups. The NEW PR banner,
  level flash and "you grew" note show in every mode (they're milestones, not gain numbers).
- Muscles can now go 30% past the Growth Spurt goal (`GrowthSpurts.CapOverGoal`), so a strong muscle helps its
  group's average; before, every muscle had to hit the cap exactly and side-only muscles (Traps, Forearms) were a grind.
- XP curve is now `20 + 2 × level` per level (was `6 + level`, which gave 3-4 levels per rep at the start).
- Tapping still fills the Pump meter while resting for stamina (nobody is punished; it just keeps tapping useful).
- The Auto Lift game pass (monetization off) now just keeps tapping for you; normal auto reps are free for everyone.
- Existing saves: weight tiers were renumbered (8 → 12), so a save's "bought up to tier N" now means the new tier N
  (a little lighter). Pre-launch, so I didn't migrate.
- Sound ids: 4 new placeholders in `Config/Sounds` (PumpFull, BigRep, PersonalRecord, Grew) reuse existing clips.

## Pacing (how the Growth Spurt goals are set)
- Targets live in one table: `GrowthSpurts.Targets = { 8, 15, 25, 35, 45 }` (1st, 2nd, 3rd, 4th, then every later).
- `tests/pacing.luau` plays 60 simulated players through 8 spurts with the real config modules: XP per rep =
  `BaseXp(34) × tier gains × muscle share × min(genetics × spurt bonus × balanced × Muscle of the Day, 5) ×
  quality × 1/(1 + level/50)`, where quality = x2 while PUMPED and x3 on a BIG REP (1 in 12); XP per level =
  `20 + 2 × level`; coins buy the next weight tiers (bought tiers need the level again after a spurt); beach gym
  after spurt 1, pro gym after spurt 2; 2.5 min of menu/tutorial before the first spurt, 45 s around later ones.
- "Normal play with some tapping": half the sets are tapped at 3 taps/s (reps every 1.05 s, 0.79 s while PUMPED; the
  meter fills in ~5 s of tapping, then 8 s PUMPED), the other half run on auto reps (1.05 s rep + 0.8 s gap). Each set
  lasts until stamina runs out (5 per rep, 100 max), then a rest to full. In this mix about half of tapped reps are
  PUMPED (x2), so a tapped set gives ~1.5x the gains of an auto set (and finishes sooner); BIG REPs add ~17%.
- The tuner (`lune run tests/pacing tune`) solves each stage's goal level in turn: **15, 47, 72, 103, 135, 157, then
  +18** each. Result (median minutes): 7.9, 14.6, 24.6, 34.7, 44.2, 44.2, 43.3, 43.7. The test fails if any spurt is
  more than 10% off its target. If gains, tiers, stamina or tapping change: run the tuner and paste the levels.
