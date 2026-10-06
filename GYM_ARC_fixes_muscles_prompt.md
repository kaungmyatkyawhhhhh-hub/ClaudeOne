Work through ALL parts below in order. Don't stop to ask questions: make the most reasonable choice,
write it in PROGRESS.md under "Decisions made", and keep going. If something is blocked, note it and move on.

START: git status → commit/push any changes → git pull.
Studio is the source of truth, no Rojo. Follow the art direction + slop rules in CLAUDE.md.
Always: no emojis in UI, no grunts, no real people/brands/copyrighted art, monetization OFF.

SCREENSHOTS: save to screenshots/ (already in .gitignore). Take a before + after shot for every fix,
named <part>_<thing>_<before|after>.png. Use PowerShell screen capture (or a Studio screenshot tool
if there is one) and check that the images aren't black. Add every shot to screenshots/INDEX.md with one line.

AFTER EACH PART: save the place if you can, export ONLY changed scripts to src/, commit + push
("Part N: ..."), and update PROGRESS.md so a new chat can continue if this one runs out.

==================== PART 1: PLAYTEST FIXES ====================

## 1. Outdoor lighting is way too bright
- Tone down daytime: lower Lighting.ExposureCompensation and Brightness, reduce Bloom intensity/size,
  add or tune Atmosphere (soft haze), and use a ColorCorrection that isn't washed out.
- Street lamps: lights off or very dim during the day, on at night. Lamp heads must not glow white like
  neon in daylight (lower Neon or use a normal material + a light).
- Check that indoor areas (gyms, shops) still look right after the change.
- Target look: warm sunny afternoon. Bright, but buildings still show texture and color, no
  blown-out white walls.

## 2. Make the outside map bigger and more open
- The main street currently feels like a narrow alley. Widen the streets and sidewalks and add space
  between building rows.
- Grow the town: more blocks, a park with paths and a fountain, an open plaza, a parking area,
  side streets, and the beach + skatepark connected with clear paths.
- Bigger has to mean more to explore, not more empty space. No empty lawns.
- Keep it smooth on phone (StreamingEnabled, reuse templates).

## 2b. Beach gym is too small and cramped
- Make it about 3x bigger: an open-air outdoor gym spread across the sand, not everything squeezed
  under one pergola.
- Zones with space between them: a shaded machine area (2–3 pergolas or shade sails, not one),
  a free-weight area (racks, benches, kettlebells, dumbbells on rubber mats), a calisthenics area
  (pull-up bars, dip bars, monkey bars, rings), and a tire/rope/sled area on the sand.
- 2–3 of each beach machine so players don't queue, with enough room around each to walk and
  see your character lifting.
- Pergola beams must be high enough that they don't block the camera or the player's view.
  Test the third-person camera around every machine.
- The sign currently says "opens at Growth Spurt 1" even when the player is already past it.
  Show the lock text only while locked. When unlocked, show just "Beach gym". Same for every
  other locked-area sign.
- Keep the style: wood, rope, sand, palm trees, flags. Connect it to the posing stage with a boardwalk.

## 3. Remove the Lift button + move the pump UI
- Delete the round "Lift" button completely.
- New input while on a machine: tapping ANYWHERE on the screen (that isn't another button) counts as a
  tap on phone. On PC it's mouse click or Space. Show a one-time hint: "Tap to pump".
- Pump meter: a slim horizontal bar at the bottom-center of the screen, only visible while on a machine.
  It must not sit in the joystick (bottom-left) or jump (bottom-right) area. When PUMPED it glows and
  shows "PUMPED" with a short timer drain.
- The "+N" gain popups stay near the character/barbell, not in the meter.

## 4. Body map stats: proportions, highlight bug, position
- Proportions: the legs are way too long. Use real body proportions: a head, torso about 3 head-heights,
  legs about 3.5 head-heights, arms that end at mid-thigh. Clean muscle shapes that don't overlap each
  other messily.
- Bug: the "training" highlight/pulse stays on after the workout. Clear it when the player leaves the
  machine, switches machine, respawns, or dies. Test all four.
- Move it out of the bottom-left (phone joystick). Put it on the right side under the quest panel,
  make it smaller, and make it collapsible (tap to shrink to a small "Stats" chip).
- The body map shapes should match the new muscle system in Part 2.

## 5. Top bars
- Quest panel is cut off by the right edge of the screen. Keep it fully on screen with safe-area padding.
- The "Skate" panel overlaps the quest panel. Stack them properly or turn Skate into a small button.
- Growth Spurt bar: the "Next: ..." line is too faint and clipped. Make it readable and fit inside the panel.
- Test in the device emulator: small phone portrait + landscape, tablet, 1080p PC. Nothing overlaps,
  nothing cut off, and nothing in the joystick or jump area.

==================== PART 2: VISIBLE MUSCLES ====================
Right now growth only scales body width, so the avatar looks like a wide block.

## 6. Stop the block look
- Remove (or heavily reduce) the BodyWidthScale/BodyDepthScale growth. Width can still go up a little
  overall, but muscles do the real work now.

## 7. Muscle shapes per muscle (18 muscles → visible parts)
- Build smooth muscle shapes and weld them onto the R15 body parts: pecs (2), front/side/rear delts,
  biceps, triceps, forearms, traps, lats, upper back, abs (6-pack segments), obliques, glutes, quads,
  hamstrings, calves. Use rounded shapes (Ball/cylinder parts, or MeshParts if you can make or find a
  clean Roblox-made one), not boxes.
- Each shape's size is driven by ITS muscle's level: small/flat at level 0 → clearly big at max.
  Grow in visible steps, tween smoothly, and play the "you grew" pulse.
- Shape rules: symmetrical left/right, anatomically placed (pecs on the chest, delts capping the
  shoulders, abs in a 2x3 grid, etc.), nothing floating, no gaps, no clipping into each other.
- Every muscle part: Massless, CanCollide/CanQuery/CanTouch off, CastShadow off, welded, no effect on
  movement or animations. Must look right while walking, lifting and doing emotes.
- Growth Spurt reset: muscles shrink back to small (height still increases).
- Performance with 20+ players: reuse templates, only update when levels change.

## 8. Clothing: make the muscles look right with shirts
Roblox shirts only paint the body, so muscle shapes would sit on top of the shirt. Handle it like this:
- Default: in game, players wear a GYM LOOK (original tank top + shorts made for the game, a few colors).
  Arm/shoulder/leg muscles are skin colored (match BodyColors), and chest/back/ab shapes take the
  tank top color where the top covers them, so it looks like muscle under fabric.
- Setting "Keep my avatar clothes": muscle parts under the shirt get tinted to the shirt's main color.
  Wardrobe/clothing store outfits work with both modes.
- Keep the player's own head, face, hair and accessories. Hats/hair must not clip into traps/delts.

## 9. Base body
- Blocky avatars make the muscles look bad. Use one consistent smooth R15 base body for everyone during
  play (a clean Roblox-made body, no brands), with the player's skin color, head, face and hair.
- Kids audience: stylized and cartoony, not hyper-realistic, nothing inappropriate.

## 10. Vascularity (veins when very strong)
- Veins appear only on strong muscles, in stages tied to that muscle's level:
  · 70%+ of max: a few faint veins
  · 90%+: more veins, a bit more visible
  · Maxed: full vascularity on that muscle
- Where: forearms, biceps, triceps, front delts, calves, lower abs/obliques. Not on the face or neck.
- How: thin, slightly raised curved strands made of small chained cylinder parts that follow the muscle
  surface, with gentle branches (not straight lines). Color: skin tone slightly darker and cooler
  (match each player's BodyColors). Massless, no collision, CastShadow off, welded.
  Don't use decals on rounded parts (they stretch).
- Pattern generated from the player's UserId, so it's the same every session and differs between
  players. Left/right similar but not perfect mirrors.
- PUMPED state: veins become more visible for the pump duration (slightly thicker/more contrast), then
  fade back. Only on muscles that already qualify.
- Kid-friendly: subtle, stylized and clean. It should read as "strong", never gross. No extreme bulging,
  no red/purple colors.
- With "Keep my avatar clothes" on: veins only on skin-colored (uncovered) muscles.
- Growth Spurt reset: veins disappear and come back as you get strong again.
- Cap vein parts per player, and build them only when the stage changes.

## 11. Everywhere the body shows
- Progress mirror screen: "Day one" shows small muscles, "Now" shows the real current muscles + veins.
  The difference must be obvious.
- Live mirror reflection, posing stage: same muscle + vein system.
- Strongest lifter statue: muscles in marble, veins as carved lines.
- NPC lifters: pro gym NPCs big with veins, starter gym NPCs medium, so players see what to aim for.

## 12. Muscle tests (screenshot each from front, side and back)
- Level 0 character
- Mid-level character
- Fully maxed character, normal vs PUMPED
- Only chest maxed (chest clearly big, legs still small)
- 70% arm vs maxed arm up close (vein stages)
- With gym look vs "Keep my avatar clothes"

==================== FINAL ====================
- Update PROGRESS.md: Done / In progress / Waiting on me / Known issues / Decisions made.
- Final save, export changed scripts, commit + push.
- Short report: what got done, what didn't, anything I should check or decide, and which screenshots
  to look at first.
