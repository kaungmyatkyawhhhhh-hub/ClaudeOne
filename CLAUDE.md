# City Legends: notes for Claude

A Roblox night-city driving game. Players earn money driving and "cutting up" traffic (close passes), buy cars in a garage, and level up. It is built with Rojo from Luau source in this repo. `README.md` has the full feature list and player-facing setup; this file is the working context for continuing development.

## About the owner

The owner's personal context is in their Obsidian vault, GitHub repo `kaungmyatkyawhhhhh-hub/ProjectOne`. When it is in the session (it should be selected when starting one), follow its `CLAUDE.md`. That means reading its start notes before replying, never announcing it, and saving new decisions to the vault.


- **Not a programmer.** They work in Roblox Studio and often use a phone, so give short, plain steps ("open X, click Y").
- **Deliverable is a place file.** Rebuild `CityLegends.rbxlx` after changes and send it to them.
- **Target look is "Highway Legends"** (another Roblox game): realistic cars, a Highway Legends-style HUD, a rainy night city.
- **Never ask for or accept their Roblox / alt account logins or cookies.** They offered once; it was declined.
- **Fictional names only.** Cars use fictional names and no real badges. Car looks can be inspired by real cars.

## Layout

- `src/shared`: modules used by both sides.
  - `Config`: all tuning: economy, progression, daily gift, traffic, sounds, theme.
  - `Cars`: the roster of 15 cars, ids like `brute_srx`.
  - `CarBuilder`: part-built car, physics hitbox, interior, driver arms. `getDims(class, id)` gives per-car proportions through `DIM_OVERRIDES`.
  - `CarMesh`: procedural lofted car meshes, with a `DESIGNS` table per car.
  - `CityLayout`, `FacadeTex`.
- `src/server`:
  - `Main.server.lua`: remotes, car spawn, cash / XP / cut-up validation, daily gift, console cash hook.
  - `PlayerData`: DataStore profile with Cash, Owned, Selected, Level, XP, LastDaily.
  - `CityBuilder`, `CityPremium`.
- `src/client`:
  - `Main.client.lua`: startup order.
  - `UI`: HUD, garage, menus.
  - `Driving`: car controller, exhaust flames.
  - `CarSkin`: swaps part bodies for meshes or imported models.
  - `Traffic`: NPC cars that obey red lights.
  - `Weather`: rain cycle, wet roads.
  - `Audio`, `Cutscene`, `WorldFx`, `BuildingSkin`.
- `tools/`:
  - `export_models.luau` (run with Lune) plus `make_glb.py`: export every car as a `.glb` for Studio's 3D Importer into `build/models` (gitignored).

## Build and check

These tools are not in the repo; install them first (e.g. with aftman or foreman, or from their GitHub releases): rojo, luau-lsp (plus the Roblox `globalTypes.d.luau`), and lune.

```
rojo build default.project.json -o CityLegends.rbxlx
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --no-strict-dm-types src
```

Keep `luau-lsp analyze` free of errors. Nothing can be run in real Roblox from a cloud session, so say what has and hasn't been tested.

## How the cars work

`CarSkin.apply(model, destroyReplaced, lite)` chooses the body for each car, in this order:

1. **Imported model:** `ReplicatedStorage.CarModels/<car id>` (searched recursively).
   - With `Mark_Origin` / `Mark_RefX` / `Mark_RefZ` marker parts, it is one of our exported `.glb` files. Layers are named Paint, Glass and so on, with one wheel.
   - Otherwise it is any model (Toolbox, Creator Store, bought). The generic adapter finds which way it faces from its VehicleSeat or PrimaryPart, finds the wheels from a `Wheels` folder with FL/FR/RL/RR or from wheel-like names, scales it to our wheelbase, and copies only the looks of visible parts. A `Reverse` attribute flips a model that comes in backwards.
2. **Runtime meshes:** `CarMesh.build` turned into EditableMesh parts. This needs Game Settings → Security → "Allow Mesh / Image APIs".
3. **Fallback:** the old part-built body.

Traffic uses the "lite" runtime meshes first. The owner thinks the procedural cars look bad. Their plan is to insert real Creator Store car models in Studio themselves, delete the scripts inside, and put them in `ReplicatedStorage/CarModels` named after car ids.

## Rules and decisions

- **No auto-loading of Creator Store models.** Do not make the game download Creator Store assets at runtime (InsertService with hard-coded asset ids). It was blocked as integrating unvetted third-party content. Models go in by hand, after the owner has checked them.
- **Assets can't be downloaded from here.** `assetdelivery.roblox.com` needs a login, and the thumbnail CDN (`tr.rbxcdn.com`) is blocked from the cloud sandbox. The Creator Store search and details API (`apis.roblox.com/toolbox-service`) works.
- **Money from the console:** `game.Players.NAME:SetAttribute("SetCash", n)` or `"AddCash"` on the server side (Studio command bar in Server mode, or the F9 server console).
- **Saving:** needs "Enable Studio Access to API Services" or a published place.
- **Git:** work on branch `claude/festive-gates-8s1tur`. No pull requests unless asked.

## Open or paused

- **Sounds:** making all sounds "high quality and accurate" was paused; ask the owner before resuming. There is no real rain sound yet; it uses a filtered built-in wind. `Config.Sounds.Rain` takes an id.
- **Untested in Roblox:**
  - the new HUD (level/XP bar, analog rev counter, side buttons, daily gift card);
  - rain and splashes;
  - exhaust flames;
  - the model import and the generic adapter.
- **XP and reward numbers** in `Config.Progression` and `Config.Daily` are first guesses.
