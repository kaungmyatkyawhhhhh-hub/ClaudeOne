I'm asleep. Work through ALL sessions below in order without waiting for me. Don't stop to ask questions:
make the most reasonable choice, write it down in PROGRESS.md under "Decisions made overnight", and keep going.
If something is blocked, note it in PROGRESS.md and move on to the next item.

START: git status → commit/push any changes → git pull. Tell me in the report if anything conflicted.

AFTER EACH SESSION (overnight safety):
- Save the place (File > Save to Roblox) if you can through the Studio connection. If you can't, note it.
- Export ONLY changed scripts to src/ (same folder tree as Explorer), commit + push ("Session N: ...").
- Update PROGRESS.md with what's done + what's next, so a new chat can continue if this one runs out.

SCREENSHOTS (I want to see everything in the morning):
- Save screenshots to the folder screenshots/ in this project (create it). Add "screenshots/" to
  .gitignore so they don't get pushed to GitHub.
- Take them by moving the Studio camera to a good angle, then capturing the screen with PowerShell
  (System.Windows.Forms + System.Drawing CopyFromScreen) and saving as PNG. If the Studio MCP has
  a screenshot tool, you can use that instead. Make sure the image isn't black or blank. If it is,
  note it in PROGRESS.md and keep working.
- Name them clearly: screenshots/<session>_<area>_<before|after>.png
  (e.g. s2_pro-gym_after.png, s3_smoothie-bar-interior_after.png).
- Take a BEFORE shot of each area before changing it and an AFTER shot when done. For big areas,
  take one from player eye level and one from above.
- At the end, write screenshots/INDEX.md listing every screenshot with one line on what it shows.

Always: no emojis in UI, no grunt sounds, no real people/brands/copyrighted art, monetization OFF.
Sound IDs: I pick them myself. Put every sound in one Sounds config table with placeholder ids.

========== SESSION 0: REMOVE ROJO COMPLETELY ==========
- Delete default.project.json (and any *.project.json), sourcemap.json, aftman.toml / rokit.toml /
  foreman.toml, selene.toml + wally.toml if only there for Rojo, .vscode Rojo settings, and Rojo
  sections in README.md, PROGRESS.md, CLAUDE.md or other notes.
- Remove anything in Studio that checks for or mentions Rojo.
- Search the whole repo for "rojo" (case-insensitive) and remove/rewrite every mention.
- Add to CLAUDE.md: "No Rojo. Studio is the source of truth (edit through the MCP connection).
  GitHub is backup only (export changed scripts to src/). Never suggest or set up Rojo."
- Lighting: the old "Technology" property no longer exists, so never set it. Use LightingStyle = Realistic,
  PrioritizeLightingQuality = true. Remove/replace any script that references Technology.
- Commit + push: "Remove Rojo completely". List what you deleted in the report.

========== ART DIRECTION (copy this into CLAUDE.md so every session follows it) ==========
Theme: sunny beach-side fitness town. Stylized-realistic, warm, clean, premium. Kids audience,
so it should feel bright and inviting, not dark and empty.
Banned "slop" signs (check every build against this list):
- Plain single-part boxes used as buildings, furniture or objects
- Flat untextured surfaces, default gray, everything the same material
- Floating parts, gaps, z-fighting, parts clipping through each other
- Big empty floors/walls with nothing on them
- Gray void or a flat baseplate edge visible anywhere
- Every object the same size and lined up in a perfect grid
- Signs that are just a text box stuck on a wall
Every object is made of several parts with real detail: trims, frames, bevels/edges, bases,
small props. Reuse well-made templates (one great lamp used 30 times) instead of many bad ones.
Creator Store: allowed ONLY for meshes/models made by Roblox or trusted creators that match the style.
Delete ALL scripts inside any inserted model (free models can contain backdoors) and list what you
inserted in the report.
Performance: StreamingEnabled on, reasonable part counts, MeshParts for repeated detail,
CastShadow off on small props. Must still run smoothly on a phone.

========== SESSION 1: BUGS + GAME FEEL ==========

## 1. Bugs (fix first, playtest each one)
a) Can't use a machine again after entering and exiting it. Find the cause (prompt left disabled,
   "in machine" state not cleared, seat/weld left behind, cooldown never ending) and fix it.
   Test: enter → exit → re-enter the same machine 5 times, then different machines.
b) Progress mirror screen: the "Day one" character has detached/floating arms. Build both preview
   rigs with Players:CreateHumanoidModelFromDescription inside a WorldModel in the ViewportFrame,
   and scale with HumanoidDescription scales, not by resizing parts.
c) Progress mirror doesn't reflect the player. Make a fake mirror: SurfaceGui + ViewportFrame on the
   glass, a client-side clone of the player's character mirrored across the glass plane, updated
   every frame. Only run it when the player is within ~25 studs. Client only.
d) "Strongest lifter" statue is broken (gaps, no head, misaligned parts). Rebuild it from the top
   player's HumanoidDescription (CreateHumanoidModelFromDescription), set every part to Marble,
   anchor it, and freeze it in a flex pose. Use a default rig if there's no leader yet.
e) The Pro gym door leads nowhere. Fix it as part of Session 2 section 3 (gyms connected).

## 2. Lifting feel: tap for pump + way more juice
Goal: lifting feels exciting, not chill. Kids audience, so you can never be punished for not tapping.
- Reps still happen automatically (slow pace).
- Tapping (mobile: big tap button near the thumb; PC: click or Space) makes reps faster
  and fills a PUMP meter.
- Full meter → "PUMPED" for ~8s: x2 gains, faster rep animation, muscle glow, meter drains.
  The meter slowly drains when you stop tapping.
- Every rep: plate clank sound, small camera FOV punch, the "+N" pop scales in then fades.
- Big reps: ~1 in 12 reps is a "BIG REP" with x3 gains, a gold, larger number and a slightly
  stronger camera punch.
- Level up: short burst (particles + chime + "Level 12" flash). Not a full-screen blocker.
- Personal record: lifting a new heaviest weight shows a "NEW PR" banner + sound.
- The progress bar to the next Growth Spurt is always visible and fills smoothly.
- Small goals every 30–60s (e.g. "12 reps to unlock 45 kg") so there's always a next thing.
- Keep the gain popup setting (On / Minimal / Off). Minimal still shows BIG REP and PR.

## 3. Visible body growth
The "Now" and "Day one" characters barely look different apart from height, and that has to change.
- Muscle growth must be clearly visible: step up body width/depth (and arm/chest bulk where
  possible) as levels go up, in noticeable steps, not tiny invisible increments.
- When a visible step happens, play a short "you grew" moment (quick pulse + sound).
- Growth Spurt keeps the height increase and resets the muscle size.

## 4. Weight progression (currently too easy to max)
- Give every machine many more weight tiers (around 10+). Each tier needs a level in the muscles
  that machine trains.
- Heavier weight = more gains per rep, so moving up always feels worth it.
- A new tier unlocking is a big moment (the PR banner from section 2).
- Show the next tier and what it needs on the machine prompt.

## 5. Growth Spurt pacing (replaces all old targets)
- 1st spurt ≈ 8 min of normal play (with some tapping), 2nd ≈ 15, 3rd ≈ 25, 4th ≈ 35, then 45.
- One config table. In the report, explain how you calculated it with the pump/big rep multipliers.

Playtest everything in this session and fix errors in Output.

========== SESSION 2: GYMS, EQUIPMENT, NPCs ==========

## 1. Starter gym: bigger + more machines
- Keep the current interior style (brick, dark floor, warm lights). The interior looks fine.
- Make it about 2x bigger with clear zones: free weights, machines, cardio, stretching mat area.
- 2–4 of every machine so players don't wait in line. Spread them naturally, not in one grid.
- Add life: mirrors on walls, rubber floor mats, water fountain, benches, towel racks, original
  posters, wall clock, fans, a reception desk at the entrance.

## 2. Pro gym: rebuild it (it's currently empty frames in a dark room)
- Machines must look like real machines: seats, pads, cables, pulleys, weight stacks,
  handles, metal + rubber materials. No bare wooden frames.
- Premium feel: darker palette with accent lighting (LED strips, spotlights on machines),
  polished concrete floor, glass, chrome, GYM ARC PRO signage, a locker area, a podium spot.
- Same zones as the starter gym, more machines, heavier weight tiers.

## 3. Connect the two gyms
- Put the pro gym right next to the starter gym. They share a wall with a big glass window,
  so starter players can SEE the pro gym (lights, NPCs lifting heavy) but can't go in.
- Glass door between them: locked shows a lock + "Unlocks at Growth Spurt 2", unlocked lets you
  walk in (no teleport). Make the pro gym look exciting through the glass so players want it.
- Remove the old "No Days Off" door that leads nowhere (or make it this glass door).

## 4. Weight plates (replace all current plate designs)
- Real-looking plates: flat faces, raised outer rim, inset ring, metal center hub with a hole,
  weight number on the face (SurfaceGui, Montserrat). Remove the broken wedge decals.
- One color per weight, used the same way everywhere (original colors, no brand look).
- Plate racks: each plate sits on its own peg/horn with spacing, so nothing overlaps or clips.
- Remove stray plates on the floor unless they're placed on purpose.
- Build it once as a template and reuse it for every rack and barbell.

## 5. NPCs (replace all current NPCs): they must MOVE and WORK OUT
- Real R15 avatars from HumanoidDescription with original outfits (catalog clothing/hair is fine,
  no real people/brands). Each one has a distinct look that fits their role.
- Gym NPCs actually use machines: they walk to a free machine, do sets with the same rep
  animation players use, rest, drink water, chat in pairs, then move to another machine.
  Simple waypoint/state loop, server-side, cheap on performance.
- They must never take a machine a player is using or walking toward.
- Coach Dex + quest NPCs stay at their spots but get idle animations and turn toward players.
- Pro gym NPCs lift heavier (bigger plates) so the glass view looks impressive.
- Name labels: small and clean, MaxDistance ~30 studs, never bigger than the quest panel.

Playtest, screenshot each zone, check against the slop list, fix.

========== SESSION 3: TOWN MAP, SHOPS, BEACH, SKATEPARK ==========

## 6. Map layout (the whole map currently looks like slop)
- No flat baseplate edge or gray void. Ocean on one side, hills/trees/distant skyline on the
  others, so there's no visible world edge.
- Redesign the town as a small, dense, walkable area: main street with sidewalks + curbs,
  crosswalks, a plaza in the middle, paths to every place. No wide empty lawns.
- Grass: Terrain (Grass + LeafyGrass + Ground mixed) with gentle height variation, plus
  flowers, bushes, rocks, tree clusters. No flat green part.
- Trees: proper multi-part or mesh trees in several varieties and sizes, not ball-on-stick.
- Street props: benches, bins, bike racks, planters, fire hydrant, bus stop, signposts,
  crates, string lights over the plaza.
- Street lamps: replace with a detailed lamp template (base, pole, arm, lamp head, light),
  spaced evenly along streets.
- Background buildings: real facades instead of plain boxes, with windows (frames + glass), doors,
  balconies, rooftop details (AC units, railings, water tanks), ground-floor shopfronts with
  awnings and original shop names. Vary heights and colors in one warm palette.
  Far-away ones can be simpler, but no plain blocks.

## 7. Starter gym exterior (currently a brick box with a floating sign)
- Real entrance: glass double doors, canopy over the door, steps or ramp, door mat.
- Big framed windows so you can see the gym inside.
- Proper lit GYM ARC sign (mounted or rooftop) with a backing frame.
- Roof edge trim, drainpipes, wall lights, planters by the entrance, a bike rack.
- The exterior must match the interior (the door leads into the reception).
- The attached pro gym building is visibly fancier (dark glass, LED trim, "PRO" sign).

## 8. Gear & Fits (clothing store): rebuild interior + exterior
- Exterior: shopfront with big display windows, mannequins in the windows, awning, lit sign.
- Interior: clothing racks with hanging clothes, shelves with folded shirts, mannequins in outfits,
  changing room with a curtain, mirror, checkout counter with register, rugs, wall displays,
  good lighting. No hats on poles, no plain cylinders on a shelf.

## 9. Smoothie bar: rebuild interior + exterior
- Exterior: real windows with glass and frames (not gray rectangles), a striped awning,
  outdoor tables with umbrellas, a menu board, a lit sign with a smoothie cup icon.
- Interior: counter with blenders, fruit baskets, cups, a readable shake menu board (prices in game
  currency), a fridge with bottles, proper bar stools, plants, warm lighting.

## 10. Beach gym + posing stage + beach
- Beach gym: real wooden/bamboo shade structure, proper machines (not frames), rubber mats on sand,
  pull-up bars, a rope, kettlebells, a flag.
- Posing stage: real stage with steps, backdrop with GYM ARC art, spotlights on trusses,
  a small crowd area with benches.
- Beach: real umbrellas (pole + canopy) with towels and chairs, varied palm trees, lifeguard tower,
  volleyball net, surfboards, rocks, shoreline detail.

## 11. Skatepark
- Real ramps: quarter pipes, a half pipe or bowl, grind rails, ledges, a fun box, all with metal
  coping and concrete material. Fence, original graffiti-style art (no brands), benches, lights.
  Ramps must actually work with the skateboard.

Playtest by walking the whole map + skateboarding. Screenshot every area from street level and
from above, compare against the slop list, fix.

========== SESSION 4: UI + STATS ==========

## 12. New stats design: body map (replaces the lines-around-character labels)
- Remove the world-space stat labels with connector lines.
- Add a small front/back body silhouette in a corner. Each of the 18 muscles is its own shape,
  and its brightness/fill shows its level (dim = untrained, bright = high, gold outline = maxed).
- The muscles the current machine trains pulse while you lift.
- Under the map: level + progress bar to the next Growth Spurt.
- Tapping the map opens the full stats screen (groups → muscles, numbers, grades).
- Clean minimal style: dark see-through panel, Montserrat, color only for grades/rarity.

## 13. UI layout (current positions are bad)
- The left button column is too big and collides with the Roblox top-left buttons. Replace it with
  a compact icon bar (small labels or none) that respects the safe area.
  Phone: bottom row or a collapsible menu button. PC: slim bar.
- Quest panel: smaller, top-right under the Roblox top bar, and it must never cover the body map
  or the tap button.
- Layout zones: top = quest + spurt bar, bottom-right = tap/pump button (phone thumb),
  corner = body map, menu = compact bar. Nothing overlaps.
- Phone layout for the genetics screen (3D barbell reveal must fit) and all newer screens
  (wardrobe, titles, quests, leaderboards, crews, settings, Growth Spurt, progress mirror).
- Test in the device emulator: small phone portrait + landscape, tablet, 1080p PC.
  Screenshot each and fix anything overlapping or too small.

========== FINAL ==========
- Rewrite PROGRESS.md short and current: Done / In progress / Waiting on me (sound IDs, badge IDs,
  monetization IDs) / Known issues / Decisions made overnight / Workflow note (no Rojo).
- Final save, export changed scripts, commit + push.
- Write a short morning report: what got done per session, what didn't, anything I need to check
  or decide, and screenshots of the main areas if you can.
