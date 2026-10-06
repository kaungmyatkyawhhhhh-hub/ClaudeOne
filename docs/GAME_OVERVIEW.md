# GYM ARC: how the game works

Written from the scripts in `src/` (as of 4 Oct 2026). See `export/TREE.md`
for where everything sits in Studio.

## The loop
1. **First join**: the player's **genetics** are rolled (a grade D–S per muscle group,
   plus a body frame and body type), revealed on a 3D barbell screen
   (`GeneticsClient`). One free reroll; after that, rerolls cost **DNA Tokens**.
2. **Train**: walk up to one of 8 machines in the Starter Gym and use the
   ProximityPrompt. The player is posed on the machine; **tap to lift**. Each rep
   costs stamina, gives muscle XP and coins (`MachineService`, `MachineClient`).
3. **Go heavier**: each machine has 8 weight tiers. A tier unlocks when the
   machine's main muscle reaches a level and the player pays coins.
4. **Grow**: total muscle progress moves the body up 4 muscle tiers (Marketplace body parts set in
   `Config/MuscleBodies`; empty ids = no change) (`BodyService`).
5. **Growth Spurt** (prestige): once every group hits the required level, muscles
   reset to 0, the player gets taller (4'0" → up to 7'0"), gains a permanent XP
   bonus, a higher level cap and a DNA Token.
6. **Titles**: collected for milestones (reps, ratios, height, genetics...), one
   shown above the head (`TitleService`, `TitlesClient`).

## Numbers that matter (all in `ReplicatedStorage/Shared/Config`)
| File | Controls |
|---|---|
| `Muscles` | 18 muscles in 6 groups (Chest, Shoulders, Back, Arms, Legs, Core), XP curve |
| `Machines` | the 8 starter + 11 pro machines, muscles trained, weight tiers (cost, unlock level, coins/rep, plates) |
| `Gains` | XP per rep formula: base 22 × tier × genetics × spurt bonus × balance bonus, capped ×5, diminishing at high level; 0.4s rep cooldown |
| `Stamina` | max 100, regen 20/s after 1.2s rest; recovery stations, Energy Shakes, the gym cat |
| `Genetics` | grade odds and multipliers (D 0.75× … S 1.5×), frames, body types |
| `GrowthSpurts` | height, required level and bonus per spurt |
| `Titles` | every title and its unlock condition |
| `Sounds` | every sound id, volume, group |
| `CoachNotes` | the coach one-liners on the machine HUD |
| `Poses` | where the body goes on each machine |
| `Onboarding` | the tutorial steps and their coach lines |
| `Quests` | Coach quests (chain + repeatables), rewards, Coach lines |
| `MuscleOfTheDay` | which group gets 2x gains each day |
| `Economy` | daily streak, offline coins, re-racking, DNA token price, rush hour |
| `Social` | spotting, lifting together, arm wrestling, crews |
| `Legends` | legend NPCs, their challenges and titles, visit timing |
| `ShowOff` | leaderboard wall, statue, emotes, membership tiers |
| `Monetization` | gamepass / product ids (nil = off) and their effects |
| `Seasons` | seasonal event dates, coin bonus, titles |

## Code structure
**Server** (`ServerScriptService`)
- `Main` starts the services and runs stamina regen.
- `Server/PlayerData`: DataStore load/save with session locking, autosave every
  60s, reconcile of new fields. **Every data change goes through here** and is
  replicated to the owning client via `Remotes.DataChanged`.
- `Server/DataTemplate`: default save for a new player. Add new fields here.
- `Server/MachineService`: entering/leaving machines, reps, tier select/unlock,
  plate visuals. Validates everything.
- `Server/ActionService`: non-machine requests (Growth Spurt, equip title, reroll,
  settings). Other services can `Register` more actions.
- `Server/BodyService`: Growth Spurt height, the muscle body tier (`Config/MuscleBodies`, applied through the HumanoidDescription; keeps head, face, hair, accessories, skin and clothes), the "Grew" event on a tier up, and the player attribute `Strength` (all muscle levels added up). NPC regulars use `ApplyTier`; the statue and the mirror rigs put the tier on their description first (`BodyTier`, `TierOf`).
- `Server/NightLightService`: outdoor lamps (tag `NightLight`) off by day, glowing at night.
- `Server/TitleService`: stats, title unlocks, badges, overhead title tag.
- `Server/NpcService`: builds NPCs (R15 from a HumanoidDescription, name label, prompt).
- `Server/QuestService`: Coach Dex, quest progress and rewards.
- `Server/MuscleOfTheDayService`: writes today's group on the chalkboard.
- `Server/BoostService`: every gains/coins/refill multiplier (shakes, events, passes) and recovery stations.
- `Server/StaminaService`: shake machine, drinking shakes, Plates the gym cat.
- `Server/RetentionService`: daily streak, offline coins, loose plates, DNA tokens at the desk, rush hour.
- `Server/SocialService`: spotting and the workout-together bonus.
- `Server/LegendService`: legend visits, challenges and rewards.
- `Server/ProGymService`: the pro gym next to the starter gym (glass wall + door; keeps locked players out).
- `Server/GymGoerService`: 8 NPC regulars walk to free machines, lift, rest, drink water, chat (never take a player's machine).
- `Server/SeasonService`: seasonal decorations, bonus and rep counting.
- `Server/CrewService`: crews (create, invite, join, leave, tags, top crews; creates the `Crew` remote).
- `Server/MonetizationService`: pass ownership + effects, product receipts, server boost.
- `Server/ShowOffService`: leaderboard wall, statue of the strongest player, emotes and high fives (creates the `Emote` remote).
- `Server/ArmWrestleService`: the arm wrestling table, matches and practice opponents (creates the `ArmWrestle` remote).
- `Main` starts newer services in protected calls (a failing one can't stop saving or machines).

**Remotes** (`ReplicatedStorage/Remotes`)
`GetData` (snapshot), `DataChanged` (path, value), `MachineAction`
(Lift/Leave/SelectTier/UnlockTier), `MachineState` (Enter/Exit), `RepResult`,
`PlayerAction` (ActionService), `PlayerEvent` (server → client moments).

**Client** (`StarterPlayerScripts`), all UI is built in code (StarterGui is empty)
- `MachineClient`: auto reps + tapping (tap anywhere / click / Space, pump bar above the panel, BIG REP), machine HUD, lifting effects and feel, NEW PR banner, level flash, next-weight text on machine prompts.
- `ProgressClient`: the always-visible Growth Spurt bar (top center) with a "next goal" line, and the "you grew" moment.
- `ProGymClient`: the glass door between the gyms (slides open from Growth Spurt 2, locked before).
- `AreaSignsClient`: area signs show "Opens at Growth Spurt N" only while that area is locked for you.
- `StatsClient`: the Stats menu button and the full stats screen (groups, muscles, grades, Growth Spurt goal and button).
- `StatsLabelsClient`: your stats around your character (2D labels with lines to dots on the body; Settings > Stats labels Always / Training / Off) and the "Strength" line over other players.
- `GeneticsClient`: genetics reveal and reroll screen.
- `TitlesClient`: Title Book and equip.
- `SettingsClient`: music/effects volume sliders, background music.
- `OverheadTitleClient`: local effects on overhead title tags.
- `MenuClient`: menu screen on join (covers data loading; Play, plus Titles/Settings for returning players).
- `QuestClient`: quest tracker, Coach speech, Muscle of the Day note.
- `ShakeClient`: Drink shake button + boost countdown, shake/cat notes, cat tail wag.
- `RetentionClient`: rush hour pill, streak/offline/re-rack/DNA token notes.
- `SocialClient`: arm wrestling panel and input, spotting/together notes.
- `LegendClient`: legend challenge tracker and notes.
- `EmoteClient`: Emotes side button and panel, poses for everyone's emotes.
- `CrewClient`: Crew side button and panel.
- `StoreClient`: Store (only with ids, after tutorial + 5 min), Auto Lift toggle, server boost pill.
- `TutorialClient`: first 5 minutes coach line, glowing floor path and machine outline (steps in `Config/Onboarding`).

**Shared helpers** (`ReplicatedStorage/Shared`)
- `ClientData`: client mirror of the player's data (`Get()`, `Changed`).
- `Audio`: plays sounds from `Config/Sounds` through SoundGroups.
- `UI/Theme`: the "clean minimal" design system (colors, fonts, spacing,
  `Theme.New`, panels, buttons). **All UI should use it.**
- `UI/RightColumn` (top-right stack: quest tracker, shake button; notifications stack under it), `UI/SideMenu` (PC: 64px labeled square buttons centered on the left, wrapping to 2 columns on short screens; phones: one Menu button that opens a grid), `UI/Notify`, `UI/Icons`, `UI/UIBus` (signals between screens: menu open/closed,
  stats/genetics visible, open titles/settings).

## Open tasks (from the owner's task list, 4 Oct 2026)
- ~~Clean minimal UI: CLAUDE.md + Theme~~ (done)
- ~~Restyle all screens~~ (done in code; needs a visual check in Studio)
- ~~Menu screen + first 5 minutes onboarding~~ (built; needs a playtest)
- ~~Sound overhaul + settings~~ (done; needs a listen)
- Test, screenshots, PROGRESS.md
