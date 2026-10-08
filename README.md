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

## HUD and progression

- **HUD:** your level and XP bar sit at the top centre. An analog rev counter (0–7k rpm, redline, gear and mph) sits bottom right, or bottom centre on touch. Your cash shows in a tab on the bottom edge, with a **Controls** tab next to it. Down the left side are **Settings** (camera and music), **Shop** (the garage) and **Gifts** buttons. On the right, a **Daily Gift** card counts down to your next gift.
- **XP and levels:** you earn XP from the same things that pay cash: driving above 40 mph and cut-ups (bigger cuts and combos give more). Level N needs `40 × N^1.35` XP. Each level-up shows a banner and pays cash.
- **Daily gift:** free cash every 24 hours, and the amount grows with your level. The server keeps the timer and checks it before it pays.
- Level, XP and the gift timer are saved with your cash. Old saves load at level 1. All the numbers are in `Config.Progression` and `Config.Daily`. The remotes are `Progress` (server → client) and `ClaimDaily`.

## Imported car models (recommended)

The cars can also come in as normal imported meshes instead of being generated while the game runs. They are 3x denser (about 35k triangles each), load instantly, and work without the "Allow Mesh / Image APIs" setting.

1. Generate the files (or use the `CityLegendsCars.glb` you were sent): `lune run tools/export_models.luau && python3 tools/make_glb.py`. This writes `build/models/CityLegendsCars.glb` (all cars) and `build/models/cars/<id>.glb` (one per car).
2. In Studio: **File > Import 3D**, pick `CityLegendsCars.glb`. Keep the default settings, but make sure merging meshes is off so every part stays separate.
3. Drag the imported model into **ReplicatedStorage**. Its name doesn't matter: the game looks for the `CarModels` group inside it. If you import cars one by one, put each one in a Folder named `CarModels` in ReplicatedStorage.

Each car model holds its body layers (`Paint`, `Glass`, `Trim`, ...), one wheel (`WheelTire`, `WheelRim`, `WheelCaliper`) and small `Mark_*` parts. Leave the `Mark_*` parts in: the game reads the car's position, scale, wheel hub, plate and exhaust tips from them. Player cars, the garage and the cutscene use the imported model when one exists. Traffic keeps the lighter runtime meshes and switches to the imported ones if runtime meshes aren't allowed.

You can swap in a model you made or bought the same way. Name it after the car id, name its parts like the ones above, and keep the `Mark_Origin`, `Mark_RefX` (4 studs along +X) and `Mark_RefZ` (4 studs along +Z, towards the rear) markers.

## Weather

`Weather.lua` alternates rain and clear spells (4-8 minutes each; it is raining when you join). Rain streaks and road splashes follow the camera and stop under the tunnel, roads and sidewalks turn darker and glossier, the haze thickens, and a rain bed fades in. Lifting off at high revs or upshifting fires blue exhaust flames from the real pipe positions.

## Sound

Everything is in `src/client/Audio.lua`. It uses only files that ship inside every Roblox client (`rbxasset://sounds/...`), so no asset can fail to load or be blocked:

| Sound | How it's made |
|---|---|
| Engine | Roblox's wind recording pitched down through distortion, EQ and tremolo. Pitch follows RPM, idle is lumpy and smooths out at high revs, and a throttle "growl" layer, rev dips on gear changes and backfire pops on hard upshifts sit on top. Each car class has its own pitch. |
| Wind / tyres | Wind rush that grows with speed, and tyre hiss while sliding or using the handbrake |
| Cut-ups | A swoosh plus a chime that climbs with your combo (an extra note for thread-the-needle) |
| Crashes | A heavy impact plus a body thud, scaled by how hard you hit |
| Cutscene | 3D engine pass-bys, whip-pan whooshes, everything slowing down in bullet time, backfire, and bass hits under the title |
| World | Low city night hum, monorail rumble overhead, and the reverb switches to tunnel echo inside the tunnel |
| UI | Button clicks |

**Real recordings (on by default):** `Config.Sounds` uses Creator Store audio. I checked each one through Roblox's API: it is an audio asset and it is marked public domain, which means any experience can use it:

| Slot | Sound | Uploader |
|---|---|---|
| Engine / EngineStart | Car-Engine-Loop, Engine-Start | Roblox Resources (verified Roblox group) |
| Crash | Metal Crash 4, Metal Crash 2 | ProSoundEffects (Roblox's SFX partner) |
| TyreSqueal | Vehicle Skids Long Heavy Tire Squeal 3 | ProSoundEffects |
| CutUp | Whoosh By Fast Airy Swooshing | ProSoundEffects |
| PassBy (cutscene) | Race Car Pass By | ProSoundEffects |
| Impact (title) | Sonic Boom Low End Impact | ProSoundEffects |
| Music (shuffled, **M** mutes) | Eclipse Drift, Urban Mirage – Night Drive Edit, Insert Coin, Escape the Night, Infinite Void | DistroKid / APM (Roblox's licensed music partners) |

Every ID is test-loaded on the loading screen. If one doesn't load in your game, Output shows a warning and that slot uses the built-in sound instead. You can swap in any IDs you like.

## Facade textures

`src/shared/FacadeTex.lua` paints building facades procedurally: glass curtain wall, office panels, limestone or brick, with window frames, floor slabs, glass reflections and lit rooms (ceiling falloff, blinds, furniture, warm or cool interiors, a few whole floors still working). `src/client/BuildingSkin.lua` turns these into runtime images and tiles them over every tower as PBR textures: colour, emissive (lit rooms glow), normal, roughness and metalness. It then removes the part-built window strips locally, which cuts about 22,000 parts from what the client draws.

This needs the same **Allow Mesh / Image APIs** setting as the car bodies. Without it, buildings keep their part facades.

## Car bodies

Every car has its own design, built at runtime as real meshes. `src/shared/CarMesh.lua` builds the geometry and `src/client/CarSkin.lua` turns it into MeshParts with `EditableMesh`.

- **Body:** hard-edged cross sections lofted along the car. That gives crisp character lines, a shoulder crease, a sharp hood edge and flat panels. On top of that: wedge or upright noses, fender haunches, widebody flares, cut wheel arches, a cabin with raked glass and tumblehome, and a dark interior you can see through the glass.
- **Details:** laid exactly onto the bodywork: grilles, headlight housings with LED signatures (Y-shaped, eye, quad, angel rings, round JDM lamps), tail lamps (light bars, Y-shapes, round quads), intakes, side scoops, hood vents, engine louvres, shut lines, door handles, plates, badges and liveries. Splitters, diffusers, wings, mirrors and exhausts are real geometry.
- **Wheels:** tyres with a sidewall and tread grooves, spoked rims (5-spoke, twin-spoke, Y-spoke, 6-spoke, multi-spoke, turbine) and brake discs, all spinning. Calipers sit on a steering knuckle, so they steer but don't spin.
- **Inspired-by designs:** the Spectre 720 is a V12 wedge with Y lamps, side scoops and a wing. The Kaizen RZ is a widebody GT with a carbon hood and round quad tail lamps. The Strada C2 is a late-90s JDM coupe with blue twin stripes. The Brute SRX and Outlaw '69 are widebody muscle cars (hood scoops, quad round lamps in a full-width grille), the Meridian SRT is a muscle saloon with a racetrack tail lamp, the Kensho M-Sport has tall kidneys and yellow DRLs, the Eclipse JX has a swan-neck wing and roof scoop, and the Velluto P7 is a purple hypercar with gold pinlines and portholes. A car can override its class proportions in `CarBuilder` (`DIM_OVERRIDES`). Rear plates show the owner's name. All names and badges are fictional.
- **Two levels of detail:** about 24k triangles for your car and the cutscene car, and about 8.5k for traffic. Each design is generated once and cloned.

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

**Sounds:** the game already has a full soundscape built from audio that ships inside the Roblox client, so it always loads (see below). You can still paste your own Creator Store IDs into `Config.Sounds`.

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
