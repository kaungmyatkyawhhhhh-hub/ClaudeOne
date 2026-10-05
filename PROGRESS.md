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

## Pacing (how the Growth Spurt goals are set)
- Targets live in one table: `GrowthSpurts.Targets = { 18.5, 25, 35, 45 }` (1st, 2nd, 3rd, then every later spurt).
- `tests/pacing.luau` plays 60 simulated players through 8 spurts with the real config modules: XP per rep =
  `BaseXp × tier gains × muscle share × min(genetics × spurt bonus × balanced × Muscle of the Day, 5) ×
  1/(1 + level/50)`; XP per level = `6 + level`; reps every 1.05 s until stamina runs out, then rest; coins buy the
  next weight tiers (they stay bought after a spurt, but need the level again); the beach gym opens after spurt 1 and
  the pro gym after spurt 2; 3 minutes of menu/tutorial before the first spurt and 45 s around each later one.
- Because the permanent bonus multiplies every rep (x1.25, 1.5, 1.75, 2, 2.5, 3...), a later spurt covers far more
  levels in the same time, so the goals climb slowly: **50, 89, 114, 146, 160, 179, then +10** each.
  `Gains.BaseXp` went 22 → 27 (the slower stamina refill had pushed the first spurt to 21 minutes).
- Result (median): 18.7, 24.9, 35.1, 44.5, 44.6, 44.7, 42.6, 43.1 minutes. The test fails if any spurt is more than
  10% off its target. If gains, tiers, stamina or bonuses change: run `lune run tests/pacing` and retune the levels.
