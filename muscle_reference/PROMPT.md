Blob muscles from reference images. Studio is the source of truth, no Rojo.

REFERENCE IMAGES (look at all of them before starting):
  C:\Users\kaung\ClaudeOne\muscle_reference\front_1.png, front_2.png  (front view)
  C:\Users\kaung\ClaudeOne\muscle_reference\back_1.png,  back_2.png   (back view)
  C:\Users\kaung\ClaudeOne\muscle_reference\side_1.png,  side_2.png   (side view)

Build our blob muscle system on the Robloxian 2.0 body (bundle 311) to match the STYLE of these
references. Don't copy their assets or textures. Build our own in the same style.

## What to match from the references
- Many smooth ELLIPSOID blobs per muscle (SpecialMesh Sphere with non-uniform Scale, or a sphere MeshPart),
  overlapping heavily and sunk into the body, so only the bulge shows.
- Same skin color + same subtle mottled skin texture on blobs AND body, with a soft shiny sheen, so seams blend.
- Front: big pecs with a clear split in the middle, round 3-part delts capping the shoulders, traps rising
  to the neck, 6-pack in 2 columns + obliques, thick arms made of stacked blobs.
- Back: wide lats flaring out, upper back/rhomboid blobs, two lower back columns along the spine, rear
  delts, triceps horseshoe, glutes under the shorts.
- Side: chest pushes forward, delts round the shoulder, arm is biceps in front + triceps behind.
- Shirtless upper body, dark gym shorts, calves skin-colored.

## What to do BETTER than the references
- More aesthetic: narrower waist (V-taper), less rocky/lumpy, smoother, cleaner shapes, symmetrical.
- Legs grow too (quads 3 blobs with a teardrop above the knee, hamstrings, diamond calves). No tiny legs.
- No blob floating or poking out at odd angles. No gaps between body and blobs.
- Kid-friendly and stylized.

## Growth (must keep)
- Each blob grows from ITS muscle's level, continuously, so every level is a small visible change.
  Level 0 = blobs fully sunk inside (normal Robloxian 2.0 look), max = reference-like size.
  Tween each change (~0.4s). Only that muscle grows when trained.
- Growth Spurt resets to level 0. PUMPED = briefly ~5% bigger.
- Every blob has a MuscleName attribute (for stats hover highlights).
- Blobs: Massless, no collision/query/touch, welded, follow animations. Built once, scaled only on level change.

## Work loop (do at least 3 rounds)
1. Build/adjust the blobs on my character at MAX level.
2. Take screenshots of my character from front, back and side at roughly the same camera angles as the
   references. Save to screenshots/muscles_round<N>_<front|back|side>.png.
3. Look at each screenshot next to its reference. Write down what's different (shape, size, position,
   gaps, seams, proportions).
4. Fix those differences. Repeat.
Then also screenshot level 0, 25%, 50%, 75% and max (front + back) and "only arms maxed" to check the growth.

At the end: export changed scripts to src/, commit + push, update PROGRESS.md, and tell me which round
screenshots to look at.
