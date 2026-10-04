# GYM ARC place map

Auto-generated from `export/GymArc.rbxlx` (place saved 4 Oct 2026).
Scripts themselves are in `src/` (synced by Rojo).

## ServerScriptService
- Main (Script)
- Server/
  - ActionService (ModuleScript)
  - BodyService (ModuleScript)
  - DataTemplate (ModuleScript)
  - MachineService (ModuleScript)
  - PlayerData (ModuleScript)
  - TitleService (ModuleScript)

## ReplicatedStorage
- Remotes/
  - DataChanged (instance)
  - GetData (instance)
  - MachineAction (instance)
  - MachineState (instance)
  - PlayerAction (instance)
  - PlayerEvent (instance)
  - RepResult (instance)
- Shared/
  - Audio (ModuleScript)
  - ClientData (ModuleScript)
  - Config/
    - CoachNotes (ModuleScript)
    - Gains (ModuleScript)
    - Genetics (ModuleScript)
    - GrowthSpurts (ModuleScript)
    - Machines (ModuleScript)
    - Muscles (ModuleScript)
    - Poses (ModuleScript)
    - Sounds (ModuleScript)
    - Stamina (ModuleScript)
    - Titles (ModuleScript)
  - UI/
    - Icons (ModuleScript)
    - Notify (ModuleScript)
    - SideMenu (ModuleScript)
    - Theme (ModuleScript)
    - UIBus (ModuleScript)

## Lighting
- Atmosphere (instance)
- Bloom (instance)
- GymGrade (instance)
- Sky (instance)
- SunRays (instance)

## Workspace
- Baseplate (model)
- Camera (model)
- SpawnLocation (model)
- Gym/
  - Machines/
    - BarbellRow (model)
    - CrunchBench (model)
    - Deadlift (model)
    - FlatBench (model)
    - InclineBench (model)
    - OverheadPress (model)
    - PullUpBar (model)
    - SquatRack (model)
  - StarterGym/
    - Entrance (model)
    - FillLights (model)
    - Pendants (model)
    - Props (model)
    - Shell (model)
    - WallDecor (model)
    - Windows (model)

## StarterPlayer
- StarterPlayerScripts (StarterPlayerScripts)
  - MachineClient (LocalScript)
  - StatsClient (LocalScript)
  - TitlesClient (LocalScript)
  - GeneticsClient (LocalScript)
  - OverheadTitleClient (LocalScript)
  - SettingsClient (LocalScript)
- StarterCharacterScripts (StarterCharacterScripts)

## How machines are set up
Each model in `Workspace/Gym/Machines` is tagged `Machine` (CollectionService) with a
`MachineId` attribute matching `Config/Machines.luau`. It contains a ProximityPrompt
(found recursively), a `Bar` part (or `Load` for PullUpBar/CrunchBench) that the
server hangs plates on, and a SurfaceGui. Studio-built: 8 machines, 8 prompts, 8 SurfaceGuis.

No UI lives in StarterGui: every screen is built in code by the client scripts
using `Shared/UI/Theme`.
