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
4. **Grow**: muscle groups thicken the avatar's body parts as they level
   (`BodyService`).
5. **Growth Spurt** (prestige): once every group hits the required level, muscles
   reset to 0, the player gets taller (4'0" → up to 7'0"), gains a permanent XP
   bonus, a higher level cap and a DNA Token.
6. **Titles**: collected for milestones (reps, ratios, height, genetics...), one
   shown above the head (`TitleService`, `TitlesClient`).

## Numbers that matter (all in `ReplicatedStorage/Shared/Config`)
| File | Controls |
|---|---|
| `Muscles` | 18 muscles in 6 groups (Chest, Shoulders, Back, Arms, Legs, Core), XP curve |
| `Machines` | the 8 machines, which muscles each trains, weight tiers (cost, unlock level, coins/rep, plates) |
| `Gains` | XP per rep formula: base 7 × tier × genetics × spurt bonus × balance bonus, capped ×5, diminishing at high level; 0.4s rep cooldown |
| `Stamina` | max 100, regen 20/s after 1.2s rest |
| `Genetics` | grade odds and multipliers (D 0.75× … S 1.5×), frames, body types |
| `GrowthSpurts` | height, required level and bonus per spurt |
| `Titles` | every title and its unlock condition |
| `Sounds` | every sound id, volume, group |
| `CoachNotes` | the coach one-liners on the machine HUD |
| `Poses` | where the body goes on each machine |

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
- `Server/BodyService`: avatar height and muscle size.
- `Server/TitleService`: stats, title unlocks, badges, overhead title tag.

**Remotes** (`ReplicatedStorage/Remotes`)
`GetData` (snapshot), `DataChanged` (path, value), `MachineAction`
(Lift/Leave/SelectTier/UnlockTier), `MachineState` (Enter/Exit), `RepResult`,
`PlayerAction` (ActionService), `PlayerEvent` (server → client moments).

**Client** (`StarterPlayerScripts`), all UI is built in code (StarterGui is empty)
- `MachineClient`: lift input, machine HUD, lifting effects and feel.
- `StatsClient`: STATS side button and 3D muscle-group labels around the body.
- `GeneticsClient`: genetics reveal and reroll screen.
- `TitlesClient`: Title Book and equip.
- `SettingsClient`: music/effects volume sliders, background music.
- `OverheadTitleClient`: local effects on overhead title tags.

**Shared helpers** (`ReplicatedStorage/Shared`)
- `ClientData`: client mirror of the player's data (`Get()`, `Changed`).
- `Audio`: plays sounds from `Config/Sounds` through SoundGroups.
- `UI/Theme`: the "clean minimal" design system (colors, fonts, spacing,
  `Theme.New`, panels, buttons). **All UI should use it.**
- `UI/SideMenu`, `UI/Notify`, `UI/Icons`, `UI/UIBus`.

## Open tasks (from the owner's task list, 4 Oct 2026)
- ~~Clean minimal UI: CLAUDE.md + Theme~~ (done)
- ~~Restyle all screens~~ (done in code; needs a visual check in Studio)
- Menu screen + first 5 minutes onboarding
- Sound overhaul + settings (Settings panel already exists)
- Test, screenshots, PROGRESS.md
