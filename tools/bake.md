# World builders (tools/builders)

The world is built in Studio and saved in the place. These builder scripts are **not part of the game**: they are
the recipes that made the code-made areas into real parts, kept so an area can be rebuilt from scratch. Nothing in
`src/` builds world geometry any more; the services only find the Studio-built pieces by name and wire them
(prompts, doors, machines).

| Builder | Makes | Wired by |
|---|---|---|
| `GymAssets` | `ReplicatedStorage.GymAssets`: plate templates `Plates.Plate55..Plate5` (CSG faces, rim, hub, number on `FaceRight`/`FaceLeft`), `BarSleeve` | MachineService (plates on bars), RetentionService (loose plates), GymKit |
| `GymKit` | (helper module) all gym equipment and props: plate-loaded starter machines, pro machines with weight stacks (`Stack` attribute, `StackBlock1..12`), racks, cardio, desk, lockers, posters, mirrors, pendants | used by `Gyms` |
| `Gyms` | `Workspace.Gym.StarterGym` (72 x 70 room, zones, props, lights), `Workspace.Gym.Machines` (18 machines), `Workspace.ProGym` (room, 15 machines, `GlassWall.GlassDoor` with `Blocker`, lockers, podium), `Workspace.Gym.NpcSpots`. Keeps `Workspace.Gym.Entrance`. Needs `GymAssets` first | MachineService, ProGymService, ProGymClient, GymGoerService |
| `ProGym` | old pro gym builder; only `ProGym.BuildMachine` is still used (by `Town` for the beach gym) | |
| `TownKit` | (helper module) trees, palms, bushes, flowers, rocks, street lamp, bench, bin, bike rack, hydrant, bus stop, signpost, string lights, the building facade generator, umbrellas, beach chairs, surfboards | used by `Town` |
| `Town` | Terrain (grass, hills, beach, sea; removes the Baseplate) and `Workspace.Town`: street, gym forecourt + exteriors + roofs, plaza, smoothie bar (with `ShakeMachine`), Gear & Fits (`ShopPrompt`), skate park, beach, beach gym (3 machines), posing stage (`PosePrompt`), background buildings, greenery, boundary; tags the entrance doors `SlidingDoor`. Layout in `Config/Town` | TownService, StaminaService, MachineService, TownClient, SkateService |
| `Mirror` | `Workspace.ProgressMirror` (`MirrorPrompt`) | MirrorService |
| `GymCat` | `Workspace.NPCs.GymCat` (`PetPrompt`) | StaminaService |
| `ArmWrestleTable` | `Workspace.ArmWrestleTable` (Seats `Stool1`/`Stool2`, `ArmWrestlePrompt`) | ArmWrestleService |
| `ShowOff` | `Workspace.LeaderboardWall` (rows by group id / `Rank1..5` / `Name`, `Level`), `Workspace.StatuePedestal` (`Plaque`) | ShowOffService |
| `Seasons` | `ServerStorage.SeasonDecor.<Halloween/Winter/Summer>` templates (Winter has the Sled Pull machine) | SeasonService clones the running season's folder |
| `NPCs` | `Workspace.NPCs`: Coach Dex (`TalkPrompt`, tag `Coach`), eight gym regulars (tag `GymNpc`, attribute `Gym`), moves the gym cat | QuestService, GymGoerService |

Visiting legends are still created by LegendService while they visit (they come and go).

## Editing an area
Move, recolor or add parts directly in Studio, then **save/publish the place**. Keep the names in the "Makes" column
(the services look them up). If a service can't find its piece it warns in Output with the builder to run.

## Rebuilding an area from scratch
Re-running a builder replaces what it made before (your Studio edits to that area are lost). In Studio's command
bar, with the builders loaded as ModuleScripts in a temporary folder (`ServerStorage._Builders`, `Kit` included):
`require(game.ServerStorage._Builders.Town).Build(workspace, game.ServerStorage)`, then delete `_Builders` and save.
