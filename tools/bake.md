# World builders (tools/builders)

The world is built in Studio and saved in the place. These builder scripts are **not part of the game**: they are
the recipes that made the code-made areas into real parts, kept so an area can be rebuilt from scratch. Nothing in
`src/` builds world geometry any more; the services only find the Studio-built pieces by name and wire them
(prompts, doors, machines).

| Builder | Makes | Wired by |
|---|---|---|
| `GymAssets` | `ReplicatedStorage.GymAssets`: plate templates `Plates.Plate55..Plate5` built like the genetics plates (bevel edge, rim band, chrome hub, printing on `FaceRight`/`FaceLeft`: curved "M WEIGHTS", the weight at 9 and 3 o'clock; `GymAssets.Replace(root)` swaps every placed plate for the new templates), `BarSleeve` | MachineService (plates on bars), RetentionService (loose plates), GymKit |
| `GymKit` | (helper module) all gym equipment and props: plate-loaded starter machines, pro machines with weight stacks (`Stack` attribute, `StackBlock1..12`), racks, cardio, desk, lockers, posters, mirrors, pendants | used by `Gyms` |
| `GymKit.LegPress` / `GymKit.HackSquat` | the plate-loaded leg machines (Sled / Carriage load part, `Rides` folder, Rail* attributes). Placed by hand (7 Oct): starter gym x 15 z -41.5 / -48.5 (leg presses, facing -X), x 9.5 / 16.5 z -56.5 (hack squats); pro gym (86, -35.5) and (78, -28.5) | MachineService, MachineClient |
| `Gyms` | `Workspace.Gym.StarterGym` (72 x 70 room, zones, props, lights), `Workspace.Gym.Machines` (18 machines), `Workspace.ProGym` (room, 15 machines, `GlassWall.GlassDoor` with `Blocker`, lockers, podium), `Workspace.Gym.NpcSpots`. Keeps `Workspace.Gym.Entrance`. Needs `GymAssets` first | MachineService, ProGymService, ProGymClient, GymGoerService |
| `ProGym` | old pro gym builder; only `ProGym.BuildMachine` is still used (by `Town` for the beach gym) | |
| `TownKit` | (helper module) trees, palms, bushes, flowers, rocks, street lamp, bench, bin, bike rack, hydrant, bus stop, signpost, string lights, the building facade generator, umbrellas, beach chairs, surfboards | used by `Town` |
| `Town` | Terrain (grass, hills, beach, sea; removes the Baseplate) and `Workspace.Town`: street, gym forecourt + exteriors + roofs, plaza, smoothie bar (with `ShakeMachine`), Gear & Fits (`ShopPrompt`), skate park (84 x 64: quarter pipes with smooth curved sides, half pipe, fun box, ledges, kicker, manual pad, painted discs; rails tagged `GrindRail`), beach, beach gym (3 machines), posing stage (`PosePrompt`), background buildings, greenery, boundary; tags the entrance doors `SlidingDoor`. Layout in `Config/Town`. `Town.RebuildSkatePark()` rebuilds only the skate park (and its two boardwalks, moves palms off it) | TownService, StaminaService, MachineService, TownClient, SkateService, SkateClient (grinding) |
| `Mirror` | `Workspace.ProgressMirror` (`MirrorPrompt`) | MirrorService |
| `GymCat` | `Workspace.NPCs.GymCat` (`PetPrompt`) | StaminaService |
| `ArmWrestleTable` | `Workspace.ArmWrestleTable` (Seats `Stool1`/`Stool2`, `ArmWrestlePrompt`) | ArmWrestleService |
| `ShowOff` | `Workspace.LeaderboardWall` (rows by group id / `Rank1..5` / `Name`, `Level`), `Workspace.StatuePedestal` (`Plaque`) | ShowOffService |
| `Seasons` | `ServerStorage.SeasonDecor.<Halloween/Winter/Summer>` templates (Winter has the Sled Pull machine) | SeasonService clones the running season's folder |
| `NPCs` | `Workspace.NPCs`: Coach Dex (`TalkPrompt`, tag `Coach`), eight gym regulars (tag `GymNpc`, attribute `Gym`), moves the gym cat | QuestService, GymGoerService |
| `Fix3Overlaps` | one-off fixes for the saved place (fix list 3): park ring path merged into one `PathRing` part, solid umbrella canopies, path edges raised, coplanar faces nudged apart (`Run()`; `Scan()` / `Detail(prefix)` only report). Needs `Kit` + `TownKit` loaded next to it. Running it again only touches what still overlaps. | |
| `Sauna` | `Workspace.Town.Sauna`: wooden beach sauna east of the beach gym (deck, path to the boardwalk with a gap cut in the edge rope, benches with seats, stove with steam) and the invisible `SaunaZone` (attribute `Recovery = "Sauna"`) | BoostService (recovery stations) |
| `BeachGymSails` | the two shade sails in `Workspace.Town.BeachGym` as smooth triangles tied to the 4 `SailPole` parts (replaces parts named `Sail`) | (decoration) |
| `GeneticsSet` | `ReplicatedStorage.GeneticsSet`: the genetics screen's gym (`Room`: tiles, back wall, squat rack, dumbbell rack, wall plates; `Platform`; `HookGrip` / `HookSleeve` J-hooks; `PlateTree`). Its bar height must match GeneticsClient's FLOOR_Y | GeneticsClient clones it onto the client-only stage |
| `Decor` | `Decor` folders in `StarterGym` (lockers, rolling whiteboard, sign-in clipboard), `ProGym` (wall TVs, smoothie counter, wood platform) and `Town.Plaza` (fountain); each area's Decor folder can be deleted on its own | (decoration) |
| `GymFrontPoster` | `Workspace.Town.GymFront.PosterBox`: framed, lit tagline poster with a planter on the starter gym's front wall | (decoration) |
| `SkinStages` | `ReplicatedStorage.SkinStages`: one SurfaceAppearance per skin texture stage (Stage1..Stage5, maps from `Config/SkinStages`). A game script can't set SurfaceAppearance maps, so run this in the command bar once after changing the ids | MuscleRig (clones them onto the skin) |

Visiting legends are still created by LegendService while they visit (they come and go).

## Editing an area
Move, recolor or add parts directly in Studio, then **save/publish the place**. Keep the names in the "Makes" column
(the services look them up). If a service can't find its piece it warns in Output with the builder to run.

## Rebuilding an area from scratch
Re-running a builder replaces what it made before (your Studio edits to that area are lost). In Studio's command
bar, with the builders loaded as ModuleScripts in a temporary folder (`ServerStorage._Builders`, `Kit` included):
`require(game.ServerStorage._Builders.Town).Build(workspace, game.ServerStorage)`, then delete `_Builders` and save.
