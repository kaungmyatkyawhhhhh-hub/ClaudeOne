# CITY LEGENDS

A Roblox night-city driving game. You cut up through traffic for cash, and you earn more the closer, faster and longer your combo is.

Everything is generated in code: the city, the cars, the lighting and the UI. The project needs no models from the Toolbox and no uploaded assets.

## Quick start

**Option A: open the prebuilt place**
1. Open `CityLegends.rbxlx` in Roblox Studio.
2. Press **Play**. The server builds the city in a few seconds, and then the intro cutscene starts.

**Option B: sync with [Rojo](https://rojo.space) (for editing the code)**
```bash
rojo build default.project.json -o CityLegends.rbxlx   # or: rojo serve
```

To save progress, publish the place and turn on **Game Settings → Security → Enable Studio Access to API Services**. Without that, cash isn't saved between sessions.

## Features

| Feature | Where |
|---|---|
| Cinematic intro (~21 s, 8 shots): an aerial shot past the Legends Tower, a crane dive to road level, a low bumper rig, a side dolly under the monorail, a **bullet-time** slow-motion orbit as the car threads between two cars, a cockpit shot over the driver's shoulder with the hands turning the wheel, a drone shot to the mountain, then the tunnel and the **CITY LEGENDS** title. It uses depth of field, a colour grade, vignette, whip-pan blur, light trails, exhaust backfire and typewriter location captions | `src/client/Cutscene.lua` |
| Working interior: dashboard, live gauge cluster, infotainment screen, seats, console, pedals, ambient LED lighting | `src/shared/CarBuilder.lua` |
| Hands on the steering wheel: the gloves are welded to the wheel rim, and two-bone IK makes the arms follow as you steer | `CarBuilder.solveArm`, `Driving.render` |
| FOV widens with speed, plus speed shake and motion blur in both chase and cockpit cameras | `Driving.render` |
| Traffic AI: follows lanes and turns, stops on red, decides whether to stop on yellow, goes on green, yields on left turns, keeps a gap, brakes when you cut in (brake lights) | `src/client/Traffic.lua` |
| Money: passive income above 40 mph, plus cut-up rewards scaled by closeness, speed and combo. Bonuses for oncoming cuts and for threading between two cars. All checked on the server | `src/server/Main.server.lua` |
| 12 cars across 5 classes (sedans, coupes, SUVs, supercars, hypercars), with a garage that shows a live 3D preview | `src/shared/Cars.lua`, `UI.lua` |
| Night city: Future lighting, bloom, atmosphere, lit window bands, neon shop signs, billboards, street lights, blinking aviation lights, parks, a skyline ring, a highway, a tunnel and a plaza | `src/server/CityBuilder.lua` |
| Dark-themed UI: speedometer arc, gear and RPM, combo meter, cut-up popups, main menu, garage, touch controls | `src/client/UI.lua` |

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Throttle / brake & reverse | W / S | RT / LT |
| Steer | A / D | Left stick |
| Handbrake (drift) | Space | X |
| Camera (chase ↔ interior) | C (hold right mouse button to look around inside) | Y |
| Reset car to road | R | Select |
| Garage | G | — |

Mobile players get on-screen buttons.

## Smooth car bodies

Car bodies are generated at runtime as real meshes (`src/shared/BodyMesh.lua` builds the geometry and `src/client/CarSkin.lua` turns it into MeshParts with `EditableMesh`). Each body has curved panels, wheel arches, a sloped hood, a rounded nose and tail, fender humps on super/hypercars, and a tinted glass cabin. Lights, wheels, mirrors, spoilers and the interior stay as detail parts.

If the Output shows *"Smooth car bodies unavailable"*, turn on **Game Settings → Security → Allow Mesh / Image APIs**. The cars fall back to their part bodies until you do.

## Performance

- **Detail LOD:** shop fronts, lobbies, rooftop clutter, street furniture, road markings and traffic signals are grouped. The client removes these groups from the scene when the camera is far away, which is roughly 30% of the city's parts at any moment. The work is spread over frames, so it never stutters.
- **Light LOD:** lights beyond about 420 studs switch off.
- **Signs:** they stop drawing beyond 650 studs, using `SurfaceGui.MaxDistance`.
- **Automatic quality:** LOD distances and traffic density shrink with the player's Roblox graphics level, and a bit further on phones.
- **Traffic:** reuses its data each frame instead of creating new tables, and updates distant cars every 3rd frame.

## Graphics quality

The full city is about 30k parts and 600 lights. That is fine on PC, but heavy for phones. Turn features off in `Config.Graphics`:

```lua
PremiumBuildings, Landmarks, StreetDetail, WetRoads, Water, Monorail, Searchlights
```

## Tuning

Every number is in `src/shared/Config.lua`: city size, traffic density and speeds, light timings, payouts, combo rules, camera FOV and UI colours. Cars and prices are in `src/shared/Cars.lua`.

**Sounds:** Roblox audio has to be uploaded or chosen from the Creator Store. To add engine, wind, cut-up, crash or music sounds, paste the asset ids into `Config.Sounds`. Any slot left blank is skipped.

## Architecture

```
src/shared   Config, Cars, CarBuilder (procedural cars + IK), CityLayout (grid, lane graph, light phases)
src/server   Main.server (spawning, economy, remotes), CityBuilder, CityPremium, PlayerData (DataStore)
src/client   Main.client (flow), Driving, Traffic, Cutscene, UI, WorldFx (lights, searchlights, billboards, monorail)
```

- **Player car:** the client owns the physics. It drives a `LinearVelocity` set to plane mode, so gravity still applies, and an `AlignOrientation`. A crash is detected when the physics engine refuses the velocity the car asked for.
- **Traffic:** each client simulates the traffic itself so the cars move smoothly. The lights come from synced server time, so every player sees the same light colours. NPC cars treat every player's car as an obstacle.
- **Cut-ups:** the client detects a car passing from in front to behind within a few studs. The server rate-limits the reports, checks the car's real speed, and computes the payout itself.

All car names are fictional, so the game is safe to publish.
