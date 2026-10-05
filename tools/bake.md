# World builders (tools/builders)

The world is built in Studio and saved in the place. These builder scripts are **not part of the game**: they are
the recipes that made the code-made areas into real parts, kept so an area can be rebuilt from scratch. Nothing in
`src/` builds world geometry any more; the services only find the Studio-built pieces by name and wire them
(prompts, doors, machines).

| Builder | Makes | Wired by |
|---|---|---|
| `ProGym` | `Workspace.ProGymBuild`: pro gym room, 11 machines, spotlights, both doors (`ProGymDoorPrompt`, `StarterDoorPrompt`) | ProGymService, MachineService |
| `Town` | `Workspace.Town`: street, smoothie bar (moves the shake machine in), clothing store (`ShopPrompt`), skate park, beach, beach gym (3 machines), posing stage (`PosePrompt`), hedge + skyline; the sea (terrain water); tags the entrance's glass doors `SlidingDoor` | TownService, MachineService, TownClient |
| `Mirror` | `Workspace.ProgressMirror` (`MirrorPrompt`) | MirrorService |
| `GymCat` | `Workspace.NPCs.GymCat` (`PetPrompt`) | StaminaService |
| `ArmWrestleTable` | `Workspace.ArmWrestleTable` (Seats `Stool1`/`Stool2`, `ArmWrestlePrompt`) | ArmWrestleService |
| `ShowOff` | `Workspace.LeaderboardWall` (rows by group id / `Rank1..5` / `Name`, `Level`), `Workspace.StatuePedestal` (`Plaque`) | ShowOffService |
| `Seasons` | `ServerStorage.SeasonDecor.<Halloween/Winter/Summer>` templates (Winter has the Sled Pull machine) | SeasonService clones the running season's folder |
| `NPCs` | `Workspace.NPCs`: Coach Dex (`TalkPrompt`, tag `Coach`), three gym-goers (tag `GymGoer`) | QuestService; EmoteClient animates the gym-goers |

Visiting legends are still created by LegendService while they visit (they come and go).

## Editing an area
Move, recolor or add parts directly in Studio, then **save/publish the place**. Keep the names in the "Makes" column
(the services look them up). If a service can't find its piece it warns in Output with the builder to run.

## Rebuilding an area from scratch
Re-running a builder replaces what it made before (your Studio edits to that area are lost). In Studio's command
bar, with the builders loaded as ModuleScripts in a temporary folder (`ServerStorage._Builders`, `Kit` included):
`require(game.ServerStorage._Builders.Town).Build(workspace, game.ServerStorage)`, then delete `_Builders` and save.
