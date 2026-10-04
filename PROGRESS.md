# GYM ARC — Progress log

> ## Morning summary (overnight run, 2026-10-05): everything else in the brief
> Built from the cloud session while you slept. **Nothing here has been playtested** (the cloud can't run
> Studio). Every step passed: compile, Roblox type analysis (luau-lsp), Rojo build, and the Lune logic tests in
> `tests/`. One real bug was found by review and fixed (tutorial save conversion). Expect some things to need
> tuning once you see them, especially the new code-driven poses (pro gym lifts, emotes).
>
> **Do first:** `git pull` in your second PowerShell window (Rojo keeps running and syncs everything; no
> restart needed). Optional: `rokit install` adds Lune for the tests. Lighting → Technology → **Future** if
> you haven't yet.
>
> **New since yesterday, in build order** (details + test steps in each entry below):
> 1. **Breath** exhale louder.
> 2. **Step 8: Coach Dex quests + Muscle of the Day**: NPC at the front desk, 12-quest chain + repeatables,
>    quest tracker on the right, today's 2x group on the chalkboard; tutorial gets its "first quest" step.
> 3. **Energy Shakes** (shake machine, Drink button, +50% gains 30 s), **stretching mat** 2.5x refill,
>    **Plates the gym cat** (pet = +10 stamina); tutorial gets its "free shake" step.
> 4. **Economy:** daily streak (DNA token every 7th day), offline coins (8 h cap), loose plates to re-rack,
>    DNA tokens for coins at the desk, **rush hour** 2x coins at :00/:30 UTC; streak/offline/MOTD on the menu.
> 5. **Step 9: Spotting** (bench/squat, +25% for the lifter, coins + Spotter title for the spotter), lifting
>    together +10%, **arm wrestling** table (vs players or practice opponents, Iron Grip title).
> 6. **Legend NPCs:** the brief's 8 legends visit every 20-30 min (first one 30 s after Play in Studio),
>    one-time challenges, matching titles.
> 7. **Showing off:** leaderboard wall above the front desk (crown for #1), marble **statue** of the #1 player in
>    the entrance hall, **Emotes** button (double biceps, lat spread, high five, auto shake chug), membership
>    **player card** (Bronze → Diamond) on the menu.
> 8. **Monetization framework:** all passes/products wired, **all off** until you paste ids (see entry).
> 9. **Pro gym** (Growth Spurt 2): door on the starter gym's right wall → dark neon room, **11 machines**,
>    Calves and Obliques trainable.
> 10. **Crews:** Crew button, create/invite/join/leave, tag above heads, top crews.
> 11. **Seasonal events:** Halloween (from Oct 15), Winter, Summer: decor, +25% coins, seasonal titles.
>
> **Quick test tour (15 min):** Play → menu card + streak line → Coach Dex at the desk (Talk) → buy a shake
> left of the door, drink it → re-rack a loose plate → pet the cat → arm wrestle on the right side (wait 8 s
> for a practice opponent) → wait for the legend note (~30 s) → Emotes button → right-wall door ("opens at
> Growth Spurt 2") → Crew button → create a crew. Add `ForceSeason = Halloween` (string attribute on
> Workspace) to see the decorations. Two-player tests (spotting, high five, crews, arm wrestling) need
> Test → Clients and Servers → 2 players.
>
> **Needs you:**
> - **Monetization ids** (Creator Hub → Monetization) → `Config/Monetization.luau`. Until then no Store.
> - **Badge ids** for the big titles (unchanged from before).
> - **Popup fixes:** that request still never reached me (step 0).
> - Tell me what looks off (poses, positions, prices); most numbers are in the `Config` files.
>
> **Not built (need art, assets or new areas):** town hub, beach gym + posing stage, skate park/skateboard,
> smoothie bar building, clothing store/wardrobe/trendy fits, veins/abs detail, gym-goers walking around,
> progress mirror and before/after snapshot, winter sled pulls.

All game code lives in this repo under `src/` and Rojo syncs it into the Studio place (GYM ARC,
placeId 80031260599632). Parts, models, lighting and `ReplicatedStorage.Remotes` are built in Studio.
Shared config: `src/ReplicatedStorage/Shared/Config`. Server: `src/ServerScriptService` (`Main` + `Server/`).
Client: `src/StarterPlayerScripts`. UI look: `src/ReplicatedStorage/Shared/UI/Theme.luau`.

---

## Area music (2026-10-05) ✅

- The two music tracks are now split by area (`Config/Sounds` → `AreaMusic`): the starter gym plays the warm
  underscore track, the pro gym the vinyl chillhop one, with a short crossfade when you go through the door
  (`Audio.SetArea`). Music volume setting still applies. More areas = more entries.

---

## "Maxed" glow on the Stats labels (2026-10-05) ✅

- From the brief ("MAXED glow when reached"): a group whose trainable muscles are all at the level cap shows
  **"Maxed"** instead of its number, with a soft white glow that pulses on the label; maxed sub-muscles show
  "Max" with the same glow. "Needs work" never points at a maxed group.
- After closing and reopening Stats the glow stays but stops pulsing (the open/close fade takes over the stroke);
  fine for now, easy to polish.

---

## NPC gym-goers (2026-10-05) ✅ (needs a look)

- Three original regulars (no names shown) stand behind the utility benches in the free-weight zone with a
  dumbbell in each hand (`GymGoerService`). Each client animates them (alternating curls, a double-biceps flex,
  a short rest, out of sync with each other), so it costs no network.
- `NpcService` gained `animated` (only the root anchored, joints can move) and `noLabel` options.
- Not built: gym-goers walking around (needs pathfinding NPC movement; can come later).

---

## Right column: clean HUD while training (2026-10-05) ✅

- The quest and legend trackers now hide while you're on a machine (the brief's "clean HUD while training";
  it also keeps them clear of the machine panel on a 667x375 phone). Shake button, Auto Lift and the rush hour /
  server boost pills stay, since they matter mid-set. Quest-done notes still pop in the corner.
- The column sits a little above the middle of the screen.

---

## Seasonal events (2026-10-05) ✅ (Halloween starts Oct 15)

**Built** (`SeasonService`, dates in `Config/Seasons`)
- **Halloween Gym** (Oct 15 - Nov 2), **Winter Lifts** (Dec 10 - Jan 6), **Summer Shred** (Jun 15 - Aug 31),
  UTC dates, every year.
- While one runs: simple decorations built from parts in the starter gym (Halloween: glowing pumpkins on the front
  desk, shake machine, by the door and the mirror; Winter: little trees with a glowing star on snow; Summer: beach
  balls and towels), **+25% coins** for everyone, and a corner note after Play.
- **Seasonal titles** (Epic): Pumpkin Spice Swole, Snow Plow, Beach Ready, for 200 reps during that event.

**How to test**
- Studio: Workspace → Attributes → **+** → `ForceSeason`, type **string**, value `Halloween` (or `Winter` /
  `Summer`) → Play → decorations + note; 200 reps → title. Delete the attribute afterwards (Studio only anyway).

**Assumptions**
- The brief's beach gym, posing stage and winter sled pulls need new areas/activities; for now each season is
  decor + bonus + title. A sled pull can become a seasonal machine later.

**Not verified**
- No playtest. Lune tests cover the date windows (incl. Winter wrapping over New Year) and the titles.

---

## Crews (2026-10-05) ✅ (needs a 2-player playtest)

**Built** (`CrewService`, `CrewClient`, limits in `Config/Social` → `Crew`)
- New **Crew** side button (two-people icon, as in the brief). Without a crew: type a name (3-20) and a tag
  (2-4 letters/numbers) → Create. With a crew: members "n / 8" (leader marked, "here" if in this server, score),
  **Invite** buttons for players in this server who have no crew, **Leave crew**.
- **Invites:** the invited player gets a note + a dot on their Crew button; Join from the panel. Up to 8 members.
- **Saved across servers** (DataStore "Crews"); your crew id is in your save. If you were removed while away,
  it's cleared on join. When the leader leaves, another member becomes leader.
- **Crew tag** above members' heads: small gray "[GAIN]" above the title.
- **Top crews** (crew leaderboard): crew score = members' muscle levels (+100 per Growth Spurt), updated every
  2 minutes, top 5 listed at the bottom of the Crew panel.
- **Text filter:** names and tags go through Roblox's text filter (required for player-typed text); blocked
  words are refused ("That name isn't allowed").

**How to test**
1. `git pull`, Play → Crew button → create a crew → your tag appears above your head.
2. Two players: one creates, invites the other → the other opens Crew → Join → both tags show.
3. Leave crew → tag disappears.

**Assumptions**
- Creating a crew is free (`CreateCost = 0`); invites only reach players in the same server (no cross-server
  friend invites yet).
- Studio's text filter can behave differently from live servers (it often passes everything in Studio).

**Not verified**
- No playtest. Compile, type analysis and Rojo build pass.

---

## Pro gym (Growth Spurt 2) with 11 machines (2026-10-05) ✅ (needs your playtest)

**Built** (`ProGymService`, machines in `Config/Machines`, poses in `Config/Poses` + `MachineClient`)
- **The room** (built from code at server start, 150 studs south of the starter gym, sealed): 60 x 46 studs,
  ceiling 14, dark concrete walls and dark rubber floor, **neon LED strips** along the bottom and top of every wall,
  a **spotlight pool** over each machine (shadows on), two soft fill lights so nothing is pitch black, and a neon
  "PRO GYM" sign on the back wall.
- **Getting there:** a new door on the starter gym's right wall (between the poster and the dumbbell rack, at
  z = -16) with a "Pro gym" sign. "Enter": below Growth Spurt 2 you get "The pro gym opens at Growth Spurt 2";
  at 2+ you're teleported in. An exit door on the pro gym's left wall takes you back.
- **The 11 machines from the brief:** Dips, Lateral Raise, Reverse Fly, Shrugs, Leg Curl, Hip Thrust, Calf Raise,
  Bicep Curl, Tricep Pushdown, Hanging Leg Raise, Cable Woodchop, with the brief's muscles. Each is a normal
  machine (same HUD, tiers, unlocks, coins, gains, sounds, quests, spotting rules), built from simple parts: a
  rubber base, a steel cable-stack frame (plates stack on its pin in the tier colors) or dip bars / leg-curl pad /
  hip-thrust bench / hanging bar. A new lighter **Cable** tier set (10 → 80 lb) for cable moves.
- **Lifting animations** for all 11 (dips sink, lateral raises go to shoulder height, leg curls curl the heels,
  hip thrusts drive the hips, calf raises go up on the toes, curls/pushdowns/woodchops/hanging leg raises...),
  written with the same joint helpers and angle conventions as the starter lifts.
- **Calves and Obliques are finally trainable** (Calf Raise, Cable Woodchop). From Growth Spurt 2 the Growth
  Spurt goal counts them, as the earlier "needs your decision" note expected.
- Server check: pro machines can't be used below Growth Spurt 2 even if someone gets in.
- The menu camera and the tutorial path only look at machines near them, so the far-away pro gym doesn't shift them.

**How to test**
1. `git pull`, Play. Find the door on the right wall of the starter gym → Enter → "opens at Growth Spurt 2".
2. To try it now: in Studio's command bar during Play (server side), give yourself spurts:
   `require(game.ServerScriptService.Server.PlayerData).Get(game.Players:GetPlayers()[1]).growthSpurts = 2`
   then use the door. (Studio only; it saves if you leave it, so set it back to your real value, usually 1.)
3. In the pro gym, try every machine: pose, plates on the stack, HUD, reps.

**Assumptions**
- The pro gym is a separate room reached by a door/teleport (cutting a real doorway into the Studio-built walls
  isn't possible from code without rebuilding them). Move it by changing `CENTER` in `ProGymService`.
- Lighting (bloom/haze/color grading) is shared with the starter gym; the pro gym's cooler look comes from its
  dark materials, white neon and spotlights.
- **Animations are a first pass I couldn't watch.** They use the measured starter-lift conventions, but expect
  a few to need tweaks (angles are at the bottom of the POSE_ANIMS list in `MachineClient`).

**Not verified**
- No playtest. Compile, type analysis, Rojo build and Lune tests (every machine has a pose, an animation, 8 tiers,
  known muscles; pro machines stack plates and keep hands free; Calves/Obliques unlock at Growth Spurt 2) pass.

---

## Monetization framework (2026-10-05) ✅ (off until you add ids)

**Built** (`MonetizationService`, `StoreClient`, everything in `Config/Monetization`)
- **Gamepasses** from the brief, each with its effect wired in: 2x Gains, Auto Lift (an on/off toggle appears in
  the right column; it taps for you on a machine), Iron Lungs (+50% max stamina, the HUD bar follows), Fast
  Recovery (+50% refill), Shake Fridge (a free shake every 10 minutes played), Gene Lock (rerolls keep your best
  group's grade), VIP Gym (+10% coins, VIP on the player card).
- **Developer products:** DNA Token, Shake Pack (5 shakes), Server Boost (2x gains for the whole server for 30
  minutes; everyone gets a note and a "2x gains 29:10 · by Name" pill shows the buyer's name).
- Purchases are granted once per purchase id (remembered in the save, so Roblox retries can't double-grant).
- **Fair, never forced:** no prompt ever opens by itself. The **Store** side button only appears after the tutorial
  and 5 minutes of play in that session, and lists only items that have an id. Every paid thing is also earnable
  (DNA tokens from streaks/quests/legends/coins, shakes from quests/coins, boosts from rush hour/spotting).
- **Right now it's all off:** every id is `nil`, so no Store button and no purchase code runs.

**How to turn it on**
1. Roblox Creator Hub → your experience → Monetization → create the passes and products (names/prices up to you).
2. Paste each id into `src/ReplicatedStorage/Shared/Config/Monetization.luau` (`id = 123456789`), commit, push,
   `git pull`. Studio test purchases are free.
3. Play for 5 minutes after the tutorial → Store button → Buy.

**Assumptions**
- "VIP Gym" gives +10% coins and a VIP tag for now; a VIP room can come with the town hub.
- Gene Lock keeps the single best group (if the new roll is worse there).
- Auto Lift uses the normal tap path, so animations, sounds and server checks are identical.

**Not verified**
- No purchases tested (no ids). Compile, type analysis and Rojo build pass.

---

## Showing off: leaderboards, statue, emotes, membership card (2026-10-05) ✅ (needs your playtest)

**Built** (`ShowOffService`, `EmoteClient`, numbers in `Config/ShowOff`)
- **Leaderboard wall:** a dark board on the front wall above the front desk, "Strongest lifters", one column per
  muscle group with the top 5 across all servers (OrderedDataStores), a small gold crown on each #1. Ranked by
  Growth Spurt first, then group level ("Lv 23 · GS2"). Updates every 2 minutes (and when you leave).
- **Statue of the strongest player:** a marble copy of the #1 overall player's real avatar (textures stripped,
  scaled 1.35x) on a dark pedestal in the entrance hall (-7, 8.5), with a plaque "Strongest lifter: Name".
  Rebuilt only when the #1 changes.
- **Emotes:** new **Emotes** side button (flexing-figure icon) → Double biceps, Lat spread, High five. Everyone
  sees them (each client poses that character, same joint conventions as the machine lifts). Two players
  high-fiving within 2.5 s and 7 studs → "High five with X!". Drinking a shake plays a **shake chug** pose.
  Not while on a machine or seated.
- **Membership card:** returning players see a player card bottom-left on the menu: name, **Bronze → Silver
  (500 reps) → Gold (2,500) → Platinum (10,000) → Diamond (30,000)** with the tier color as a thin top line,
  overall genetics grade disc (the brief's "player card"), height, reps, titles, legends met, and the next tier.

**How to test**
1. `git pull`, Play. Menu: player card bottom-left.
2. After ~10 s in game: the board above the front desk fills with your levels (DataStores must be enabled:
   Game Settings → Security → Enable Studio Access to API Services, already on for saving).
3. Entrance hall, left of spawn: your statue appears after the first board update if you're #1.
4. Emotes button → try each; drink a shake off-machine to see the chug. High five needs 2 players.

**Assumptions**
- Leaderboard ranks group levels including Calves/Obliques (the real average), same as the Stats labels.
- Emote poses are code-driven (no uploaded animations); angles are first guesses from the measured lift poses,
  so they may need small tweaks after you see them.
- Membership tiers are by lifetime reps (simple, always going up).
- Not built: progress mirror and the shareable before/after snapshot (need a camera capture feature Roblox
  doesn't offer to scripts in a way that fits; left for later), crews (need cross-server groups + moderation).

**Not verified**
- No playtest. Compile, type analysis, Rojo build and Lune tests (score ordering, tiers, emotes) pass.

---

## Legend NPCs (2026-10-05) ✅ (needs your playtest)

**Built** (`LegendService`, `LegendClient`, list in `Config/Legends`)
- The 8 legends from the brief (Lance Lats, Brody Pumpkins, Tank McFlex, Kyle Swole, Ricky Reps, Big Beefington,
  Tiny Tim Gains, Chad Gainsworth), each an original big NPC (wider/deeper body, own colors) built from code.
- **Visits:** one legend appears in front of the bench row (0, -34.5) every 20-30 minutes for 3 minutes, picked
  from legends someone in the server hasn't met yet. Corner note when they arrive/leave. First visit 2 minutes
  after a server starts (**30 s in Studio**, so you can test without waiting).
- **One-time challenge:** tap Talk → their line + challenge (e.g. Lance Lats: 15 Pull-Up Bar reps). A "Legend
  challenge" tracker appears in the right column. Finish it any time, even after they leave → +60 coins, +1 DNA
  token, and their **matching title** (Wingspan, Pumpkin Delts, Tank Mode, Certified Swole, Rep Machine,
  Beefcake, Small but Mighty, Gainsworth Approved; all Epic, category Legend). One challenge at a time.
- **Legends met list:** the 8 legend titles in the Title Book (locked ones show ???), plus a "Legends met: 3 / 8"
  note when you finish one.
- Legends speak through the same speech bubble as Coach Dex.

**How to test**
1. `git pull`, Play in Studio, wait ~30 s → "X is in the gym" note → walk to the bench row → Talk.
2. Do the challenge reps → "Challenge done" + new title in the Title Book.
3. Talk to the same legend again later → "Good to see you again".

**Assumptions**
- Names are the brief's own examples (original characters). Lines are original.
- Challenges can be finished after the legend leaves (3 minutes is short for kids).
- Legends stand still where they appear; they don't walk around or lift.

**Not verified**
- No playtest. Compile, type analysis, Rojo build and Lune tests (titles generated per legend, unlock rules,
  quest machines exist, unique title ids) pass.

---

## Step 9: Spotting + arm wrestling (2026-10-05) ✅ (needs a 2-player playtest)

**Built** (numbers in `Config/Social`)
- **Spotting** (`SocialService`): while someone lifts on the Flat Bench, Incline Bench or Squat Rack, other
  players see a **Spot** prompt on that machine. Spotting gives the lifter **+25% gains**; the spotter earns
  **1 coin per spotted rep** and works toward the **Spotter** title (10 spotted reps; it was locked before).
  The spot ends if either one leaves or the spotter walks more than ~14 studs away. One spotter per lifter.
- **Workout together:** lifting while another player lifts within 30 studs gives **+10% gains** and counts toward
  the new **Gym Buddy** title (100 reps).
- **Arm wrestling** (`ArmWrestleService`, `SocialClient`): a new table with two stools on the right side of the
  gym (15.5, -29.5, the open floor between the stretching mats and the dip station). Sit down (prompt, or just
  walk into a stool). With a second player, a 3-2-1 countdown starts; alone, a practice opponent (Rocco, Tess or
  Big Lou, original characters) stands in after 8 s. Then both tap anywhere / Space as fast as possible: each tap
  pushes the meter toward you, harder with stronger Biceps, Forearms and Front Delts. Pin it (meter all the way)
  or be ahead after 12 s. Win 15 coins (8 vs practice), lose 5. Taps over 14/s are ignored. New **Iron Grip**
  title (10 wins). Bottom panel: meter (you on the left), countdown, result.
- MachineService now ignores the Spot prompt when it looks for a machine's own Use prompt.
- New RemoteEvent `ArmWrestle` is created by the server at start (Remotes stays Studio-built otherwise).

**How to test**
1. `git pull`. Solo: walk to the table on the right side, sit, wait 8 s → a practice opponent → tap fast.
2. Two players (Test → Clients and Servers → 2 players): one lifts on the bench, the other walks up → Spot →
   notes on both screens; the lifter's popups are bigger; the spotter's coins go up per rep.
3. Two players lifting near each other → "Lifting together" note.
4. Two players on the arm wrestling stools → countdown → match.

**Assumptions**
- Players sit with the normal Roblox sitting pose; there's no custom arm-wrestling arm animation yet (the meter
  carries the match). Practice opponents stand behind their stool.
- The table position is my pick of open floor; move `TableSpot` in `Config/Social` if it blocks anything.
- Practice wins count toward Iron Grip (kids often play alone).

**Not verified**
- No playtest (and spotting needs two players). Compile, type analysis, Rojo build and Lune tests (strength,
  titles, match pacing) pass.

---

## Economy + retention: streak, offline coins, re-racking, DNA tokens, rush hour (2026-10-05) ✅ (needs your playtest)

**Built** (`RetentionService`, numbers in `Config/Economy`, notes in `RetentionClient`)
- **Daily streak:** paid automatically on the first join of each UTC day: 20 coins + 5 per streak day (counted
  up to 30 days), and a **DNA token every 7th day**. Missing days only drops the streak 3 days per missed day
  (never straight to zero, as the brief says).
- **Offline coins:** 0.5 coins per minute away, capped at 8 hours (240 coins), nothing for breaks under 10 min.
- **Menu info lines** for returning players (from the brief's menu list): "Day 5 streak", "While you were away:
  +120 coins", "Muscle of the Day: Legs (2x gains)". Corner notes repeat them after Play.
- **Re-racking:** up to 3 loose bumper plates lie on the floor near the benches/racks (a new one every 90 s).
  Tap **Re-rack** for +5 coins; first player to grab it gets it.
- **DNA tokens for coins:** the front desk gets a short-hold "Buy DNA token · 400 coins" prompt.
- **Rush hour:** every 30 minutes on the clock (:00 and :30 UTC, same on every server) for 3 minutes: **2x
  coins** per rep, a corner note, and a "Rush hour 2:41 · 2x coins" pill at the top of the right column.

**How to test**
1. `git pull`, Play. As a returning player the menu shows your streak line and Muscle of the Day.
2. Look on the floor near the benches/racks for a loose colored plate → Re-rack → +5 coins.
3. Front desk → hold "Buy DNA token" (needs 400 coins) → token count goes up on the Genetics screen.
4. Rush hour: wait for :00 or :30 UTC (6:30 / 7:00 pm etc. in Yangon) or temporarily set
   `Economy.RushHour.EveryMinutes = 2` in `Config/Economy` to see it quickly (then set it back to 30).
5. Offline coins: leave, come back after 10+ minutes → menu line + corner note.

**Assumptions**
- "Offline gains" pays coins (not muscle XP): coins are the brief's one currency and XP offline would skip the
  lifting loop.
- Loose plates on the floor are a gameplay chore; the decor rule "plates never scattered" still holds for the
  built gym. Spots are fixed in `Config/Economy` so they never land inside equipment.
- Rush hour = 2x coins only (gains stay normal so the Growth Spurt pace doesn't change).
- Prices are first guesses (DNA token 400 coins).

**Not verified**
- No playtest. Streak / offline / rush hour math is covered by Lune tests; compile, type analysis and Rojo build pass.

---

## Energy Shakes, stretching mat, gym cat (2026-10-05) ✅ (needs your playtest)

**Built**
- **Energy Shakes** (`StaminaService`, numbers in `Config/Stamina`): the shake machine by the door gets a
  "Buy shake · 25 coins" prompt. Shakes go in your bag (max 20). A **Drink shake** button appears in the right
  column above the quest tracker while you have any: drinking fills stamina and gives **+50% gains for 30 s**
  (drinking again adds time, up to 90 s); the button then counts down "Shake boost 23s". Random flavor in the note
  (chocolate, strawberry...), flavors are cosmetic only. Quest rewards also give shakes.
- **Boosts in one place** (`BoostService`): shakes now, and later rush hour / server boost / gamepasses all
  multiply gains, coins and stamina refill the same way. Gains still go through the 5x cap; the client's gain
  popups use the same boost so the numbers match.
- **Stretching mat:** standing on the stretching area (its `Recovery = StretchMat` attribute, already in the
  place) refills stamina **2.5x faster**.
- **Plates the gym cat:** a small part-built cat sits in front of the cat bed by the front desk, tail wagging
  (animated on each client, no network cost). Tap **Pet**: +10 stamina, once every 30 s per player.
- **Tutorial:** the "stamina + free shake" step from the brief replaces the plain "rest" step: you get a free
  shake (given by the server once) and the step ends when you drink it.
- **Right column** (`Shared/UI/RightColumn`): shake button and quest tracker stack there without overlapping.

**How to test**
1. `git pull`, Play. Walk to the shake machine left of the door → Buy shake (needs 25 coins) → button appears on
   the right → Drink: stamina full, countdown starts, gain popups are bigger.
2. Lift until stamina is low, step onto the stretching mats (right side, middle): it refills much faster.
3. Pet the cat at the right end of the front desk: "+10 stamina"; pet again right away: "napping".
4. Replay the tutorial: step 4 gives a free shake and waits for you to drink it.

**Assumptions**
- Prices/durations are first guesses (25 coins, 30 s, +50%); tune in `Config/Stamina`.
- The cat's name is "Plates" (original). It doesn't walk around.
- Foam rollers and a sauna don't exist as separate stations; the whole stretching area counts as one recovery
  station. Any model can become one by giving it a `Recovery` attribute (`StretchMat`).
- No gulp/purr sounds: I can't audition new sounds from the cloud, so drinking reuses the soft ding.

**Not verified**
- No playtest. Compile, type analysis, Rojo build and the logic tests pass.

---

## Step 8: Coach quests + Muscle of the Day (2026-10-05) ✅ (needs your playtest)

**Built**
- **Coach Dex** (`QuestService` + new `NpcService`): an original R15 NPC built from code (chalk-white shirt,
  dark pants, name label), standing at the gym end of the front desk (11, 0, -9) facing the door aisle. Tap
  **Talk**: he gives a quest; finish it and talk again for the reward and the next quest. His one-liners show
  above his head for 5 s (only you see them). All progress is server-side.
- **Quests** (`Config/Quests`, adding one = adding a table entry): a 12-quest chain (10 reps, 15 squats, unlock a
  heavier weight, back day, pull-ups, chest level 10, overhead press, crunches, every group level 5, 3 titles,
  200 reps, first Growth Spurt), then 4 repeatable quests in a loop. Rewards: coins, DNA tokens, shakes.
- **Quest tracker** (`QuestClient`): small panel at the right middle with the quest, a chunky 10-segment progress
  bar and "x / y", or "Done. Talk to Coach Dex". Corner note + soft ding when a quest is ready.
- **Muscle of the Day** (`Config/MuscleOfTheDay`, `MuscleOfTheDayService`): one group per UTC day at 2x gains
  (same on every server, cycles through all 6). Written on the chalkboard by the front desk ("Legs · 2x gains"),
  applied inside the gains formula (still under the 5x cap, so popups match), and a corner note after Play.
- **Tutorial:** the missing "first quest" step is in (Stats → talk to Coach Dex → Growth Spurt goal), with the
  glowing path leading to him.
- **Tutorial saves:** "finished" is now a fixed 100, so adding steps never sends finished players back; saves
  from the earlier tutorial version are converted automatically.
- **Safety:** new server services start in protected calls; if one fails it warns in Output and the rest of the
  game keeps running.
- Shakes are already stored (quest rewards give them); drinking them comes in the next step.

**How to test**
1. `git pull`, Play. Walk to the front desk: Coach Dex stands at its left end. Tap Talk → line above his head,
   tracker shows "Do 10 reps on any machine 0 / 10".
2. Do 10 reps → tracker fills, "Quest done" note → Talk → "Quest reward: +10 coins", next quest given.
3. Look at the chalkboard next to the desk: today's group + "2x gains". Lift a machine for that group: bigger popups.
4. Replay the tutorial (`ReplayTutorial` attribute): after Stats, the path leads to Coach Dex.

**Assumptions**
- Coach name "Coach Dex" and his look are original. He stands still (no animation), like a desk clerk.
- Reward sizes are first guesses against the tier costs (15-800 coins); tune them in `Config/Quests`.
- Group-level quests use the trainable muscles only (same rule as the Growth Spurt goal), so Calves/Obliques
  don't block them.
- Muscle of the Day uses the UTC date, so it changes at 6:30 am Yangon time.

**Not verified**
- No playtest from the cloud. Checked: compile, Roblox type analysis (luau-lsp), Rojo build, and Lune tests of the
  quest/MOTD/gains/onboarding config logic. NPC built with `Players:CreateHumanoidModelFromDescription`; if that
  ever fails, a simple part figure stands in so Talk still works.

---

## Sound overhaul + settings (2026-10-04) ✅ (needs a listen)

**Already in place (checked, not rebuilt)**
- `Config/Sounds`: every sound in one table (Roblox's licensed Pro Sound Effects / APM Music), random variants and
  pitch spread, `Shared.Audio` with Gameplay / UI / Music SoundGroups, 3D falloff for machine sounds, clank deeper
  for heavier tiers, plate knock on heavy reps, breath exhale only on heavy tiers / low stamina (never grunts),
  rack rattle + floor thud, set-complete chime, Growth Spurt bell, looping background music.
- Settings panel: Music and Effects sliders, applied live and saved with the player's data. The menu's Settings
  button now opens it too.

**Built (the moments that were silent)**
- Muscle level up: a soft high ding (at most once every 1.5 s, since early levels come fast).
- Muscle maxed: a short high bell.
- New title: a bell with the corner note.
- Heavier plates bought: a plate clank at the machine.
- Out of stamina: one breath exhale per empty tank (not one per tap).
- `basePitch` in `Config/Sounds` lets one clip make two different sounds; all new sounds reuse clips the game
  already uses, so none of them can fail to load.

**How to test**
- `git pull`, Play, get on a machine: lift until a muscle levels (ding), lift until stamina is empty and keep
  tapping (one exhale), buy the next weight tier (clank). Earn a title (bell). Move both Settings sliders to check
  the new sounds follow the Effects volume.

**Assumptions**
- "Sound overhaul" was mostly done before; this step only filled the gaps. Area music (different music per area)
  waits until there is more than one area.
- No new sound ids were picked: I can't audition sounds from the cloud, so new moments reuse existing clips at a
  different pitch. Swap ids in `Config/Sounds` if you find better ones.

---

## Menu screen + first 5 minutes onboarding (2026-10-04) ✅ (needs your playtest)

**Built**
- **Menu screen** (`MenuClient`, new): shows the moment you join and covers data loading ("Loading..." until your
  save is in). The camera stands in the entrance hall and slowly drifts left/right in front of your character, who
  faces the camera with the gym visible through the doorway behind. Panel on the right: "GYM ARC", "Everyone
  starts tiny.", **Play**, and for returning players **Titles** and **Settings** (they open the existing Title Book
  and Settings panel). New players get the simplified menu: Play only. Movement is frozen and the side menu is
  hidden until Play; then the camera glides behind your character (now facing the gym) and you're in.
- **Genetics reveal** now waits for Play (it used to open by itself on join).
- **Tutorial** (`TutorialClient`, new; steps in `Config/Onboarding`, so changing a line or a step = editing a table):
  1. Walk to the Flat Bench (glowing dot path on the floor + outline on the bench)
  2. Tap to lift → first rep (Beginner Gains title pops in the corner as before)
  3. Every rep uses stamina, keep lifting until it runs low
  4. Stamina refills when you rest
  5. Head to the Squat Rack (path + outline; "Tap Exit, then..." if you're still on the bench)
  6. Three squat reps
  7. Open Stats (the Stats button gets its "new" dot)
  8. The Growth Spurt goal (7 seconds, or until you close Stats) → "You're all set. Go get big."
  One small coach line at the top center (moves to the bottom while Stats is open so it never covers the goal
  panel). The dot path uses Roblox pathfinding, so it walks around the free-weight zone benches.
- **Save data:** `onboarding.tutorialStep` (server-validated, forward only). Leaving mid-tutorial resumes at the
  same step. Saves from before the tutorial that already have reps skip it (so your own save won't see it).

**How to test**
1. `git pull` (Rojo adds MenuClient, TutorialClient, Config/Onboarding and updates 7 scripts).
2. **Returning player (your save):** Play → menu with Play / Titles / Settings over your character. Try Titles and
   Settings, then Play: camera glides behind you, side menu appears, no tutorial.
3. **New player:** select **Workspace** → Properties → Attributes → **+** → name `ReplayTutorial`, type
   **boolean**, tick it. Play → simplified menu (Play only) → genetics reveal → follow the coach line through all 8
   steps. Untick the attribute afterwards (it's Studio-only; live servers ignore it).
4. Device Emulator (phone landscape): menu panel and coach line fit and don't cover the side menu.

**Assumptions**
- Menu buttons only for features that exist (brief: "only show a button once its feature exists"): no Wardrobe,
  Crew, offline gains, streak or Muscle of the Day info yet.
- "GYM ARC" on the menu stays in capitals: it's the game's name/wordmark, not a heading.
- Character on the menu: your real character at the spawn, framed in the doorway (instead of a separate pan through
  the gym), so the camera never clips walls; the gym shows behind you through the door.
- **Skipped steps:** "stamina + free shake" has no shake (Energy Shakes don't exist yet), and "first quest" is left
  out (quests are build step 8). Both slot in as table entries in `Config/Onboarding` later.
- The tutorial coach line is a small panel, not a pop-up, and is the only new on-screen element.
- If steps are added to `Config/Onboarding` later, players who finished the old list will see the new steps.

**Not verified**
- No playtest from the cloud. Code compiles and Rojo builds; layout positions were checked against the real place
  (spawn at 0,0,0, gym door 3.5 studs north, free-weight zone between the door and the bench row). Camera framing
  numbers are at the top of `MenuClient` (`CAMERA`) if the shot needs a tweak.

---

## Clean minimal UI: brief + restyle check (2026-10-04) ✅ (needs a visual check)

**Built**
- Checked every screen's code against the clean minimal Theme: machine HUD, stats overlay + goal panel,
  genetics reveal, Title Book, settings, side menu, corner notifications, overhead titles. All of them already
  use Theme panels, buttons, Montserrat and normal-case text; no tape labels, marker font, Oswald or ALL CAPS
  remain. (The restyle had been finished before the session limit hit; only the brief was still old.)
- `docs/DESIGN.md` (the brief) rewritten to describe clean minimal: UI design system, crisp text, side menu,
  overhead title, machine HUD, genetics layout and stats label style now match what the code does.
- Tidied leftovers in code (comments and two variable names that still said Oswald/tape/marker). No behavior change.
- All 30 scripts pass a Luau compile check.

**How to test**
- `git pull` (Rojo syncs the 3 changed scripts). Play and look at: machine HUD, STATS overlay, GENETICS screen
  (+ View odds), Title Book, Settings, a corner notification, your overhead title. Everything should look the same
  as before: dark see-through panels, thin light borders, white/gray Montserrat.
- Device Emulator (phone landscape) on the same screens.

**Assumptions**
- The Theme module is the source of truth for the new look; the brief was updated to match it, not the other way.
- Side menu "new" dots are white (as coded), not red as the old brief said.
- Stamina turns soft red under 15% only (the old yellow-under-40% step is gone in the code).
- 3D-only colors (chrome bar and warm light in the genetics ViewportFrame, the legendary shine) stay as constants in
  their scripts: they are lighting/material values, not UI style.

**Not verified**
- I can't see Studio from the cloud, so this was a code review only. Tell me if any screen still looks old.

---

## Scripts moved into Rojo (2026-10-04) ✅ (needs the switch-over below)

**Built**
- All 30 scripts copied from the place export into `src/`, unchanged. Verified: a Rojo build of the repo gives the
  same 30 scripts, same types, same places and byte-identical code as the place.
- `default.project.json` now maps `src/ServerScriptService` → ServerScriptService,
  `src/ReplicatedStorage/Shared` → ReplicatedStorage.Shared, `src/StarterPlayerScripts` → StarterPlayerScripts.
- README, CLAUDE.md and the docs updated: edit code in `src/`, never in Studio.

**How to test**
- Back up the place first (File → Save to File As… → `GymArc-backup.rbxl` somewhere outside the repo).
- `git pull`, `rojo serve`, Connect in Studio. Accept Rojo's changes if it asks.
- Delete the leftover `ReplicatedStorage.RojoShared` folder in Studio if it is still there.
- Play: everything should behave exactly as before (genetics, lifting, stats, titles, settings), no new errors in Output.

**Assumptions**
- Nothing was added to the scripts in Studio after the 4 Oct export (anything newer would be replaced by the repo version).
- `ReplicatedStorage.Remotes` stays Studio-built (not synced), so the remotes are untouched.

**Leftovers to delete (couldn't remove them from the cloud session)**
- `src/server`, `src/client`, `src/shared` (old Rojo test placeholders, no longer synced) and `export/scripts`
  (duplicate of `src/`).

---

## Two redesigns (2026-10-04): stats world labels, 3D genetics reveal, depth on all 2D UI ✅

Playtested with no errors in Output. CLAUDE.md updated (UI depth rule, side menu Genetics icon, section 6
Genetics, section 8 Stats). Screenshots: `screenshots/` in this folder (stats-walking.jpg,
stats-walking-back-expanded.jpg, stats-behind-squat-rack.jpg, genetics-mid-animation.jpg, genetics-final.jpg,
title-book-depth.jpg, machine-hud-and-toasts-depth.jpg).

**1. Stats: world-space labels (`StatsClient`, rewritten)**
- Each group label is a BillboardGui next to its body part, sized in studs plus a pixel floor for phones. No box:
  Oswald name + grade disc, bigger level number under it, thin dark text stroke.
- Placed every frame in camera space: Shoulders/Arms/Core always to the camera's left, Chest/Back/Legs always to
  the right, slightly lifted. Each side is stacked with a minimum gap (never overlaps or crosses), stays below the
  goal panel, and slides up if it would run off the bottom of the screen.
- Short chalk elbow lines to dots on the body; label and dot positions are lerped (no jitter).
- "needs work" in small red marker under the weakest group only (hidden on a tie).
- Tap a label → its sub-muscle labels appear around that body part with their own lines; tap again to collapse.
- Labels are not AlwaysOnTop, so prompts always draw over them, and a label that would sit on a shown prompt fades
  out. Labels are drawn at 35% of the body's distance (scaled so they look identical) and a raycast pulls a label in
  front of any equipment/wall between it and the camera, so racks and bars never hide them.
- The GENETICS button moved out of stats into the side menu (DNA icon).

**2. Genetics reveal in 3D (`GeneticsClient`, rewritten)**
- No panel: the world is blurred (DepthOfField "GeneticsBlur") and dimmed 50%; movement stays frozen while open.
- 3D barbell in a ViewportFrame (chrome bar, collar, sleeve), warm light from above, 3/4 camera angle.
- Six 3D bumper plates (plate colors, darker rim, chrome hub); better grade = bigger diameter.
  They slide onto the sleeve and slam against each other: clank pitched by grade, camera shake, chalk puff on S.
- The overall grade is a big 3D plate that drops in with a deep thud and a bigger shake, then the marker reaction.
- Oswald name + multiplier under each plate; frame and body stay as tape labels.
- Reroll: plates slide off (outermost first), the hero lifts out, the new set slams on.
- No reroll left → REROLL becomes a solid gray "NO DNA TOKENS" block that can't be tapped.
- The screen sits to the right of the side menu so the hero plate never covers the buttons.

**3. Depth on all 2D UI (`Theme.AddDepth`, `Theme.Panel`)**
- Soft drop shadow (three faint strokes, fading out toward the top), a 1px chalk highlight on the inner top edge
  (a faint dark shade along the bottom of chalk buttons), the steel border slightly lighter on top, and faint
  rubber flecks on mat panels. Frames and strokes only, no images.
- Applied to: all Theme buttons and tapes, side menu buttons, stats goal panel, genetics odds panel, machine HUD
  panel, Title Book panel + title cards, corner toasts.

**Bugs found and fixed while testing**
- `Theme.Fade` lost its saved values for labels that no script kept a reference to (Luau collected the
  weak-table key), so those labels faded back in as invisible (stats names vanished after a prompt fade).
  Saved values now live in attributes on the instances. This affects every faded UI in the game, for the better.
- Depth pieces were shrunk by a panel's UIPadding (stray lines inside tapes); they now offset the padding.

**How to test**
1. Play, press STATS, walk around and spin the camera: six labels stay beside your body, left/right of it, no
   overlaps. Walk next to the squat rack with the camera behind it: labels stay in front of the rack.
2. Walk up to a machine: the prompt appears and any label under it fades; walk away and it comes back.
3. Tap BACK: Lats/Traps/Rhomboids/Lower Back appear with lines; tap again to collapse.
4. Press the GENETICS side button: blur + 3D bar, plates slam on one by one, the big plate thuds in. REROLL →
   plates slide off and a new set slams on. With 0 tokens and no free reroll the button says NO DNA TOKENS.
5. Check depth: Title Book cards, machine HUD panel, toasts have soft shadows under them.

**Assumptions**
- ViewportFrames only support one directional light + ambient, so the "soft rim light" is approximated with a
  warm key light from above plus ambient fill; there's no true rim light.
- Grade letters sit on each plate's front edge (2D text over the 3D plate): SurfaceGuis don't render in
  ViewportFrames, and plates pressed together hide each other's faces.
- Labels draw at 35% of the body's distance (min 2.5 studs from the camera) so props don't hide them.
- On very short screens with a group expanded, the goal panel wins and the lowest label may touch the bottom edge.
- `DataTemplate` currently gives new saves test values (coins 9999, DNA tokens 999, Growth Spurt 10). I didn't set
  or change these; reset them before launch.

**Placeholders:** the clank/thud reuse the existing plate clank sound at lower pitch (no custom thud sound).

---

## Fix batch (2026-10-04): genetics, crisp text, stats overlay, side buttons, overhead title, gym lighting ✅

All six parts done in order and playtested with no errors in Output. New rules were added to CLAUDE.md
(Crisp text, Side menu buttons, Overhead title, the Genetics layout/reveal, Stats: live overlay, and the Starter gym lighting/palette).

**1. Genetics screen (`GeneticsClient`, rewritten)**
- Layout:
  - Tape "YOUR GENETICS" top left, DNA tokens top right.
  - Big overall bumper plate on the left with "OVERALL" and the marker reaction (S "genetic freak?!" … D "hard gainer... respect").
  - Six tall rounded plates on a barbell, with height by grade (S tallest, D shortest), and the group name and multiplier under each.
  - Frame and body as two tilted chalk tapes with their bonus beside them.
  - The gray cards and the odds text are gone. The underlined VIEW ODDS link opens a clean odds panel (grade discs with %, frame %, body %).
  - REROLL is an outline button and KEEP is solid chalk.
- Reveal:
  - The bar slides in.
  - Plates slam on left to right, 0.15s apart, each with a clank (pitched by grade) and a tiny camera shake. S plates puff chalk dust.
  - After a pause, the overall plate stamps down with a deep thud, then the reaction fades in.
- Reroll: the plates fly off, the screen waits for the server's new genetics, then the new set slams on.
- Slots size to the screen width, so the screen fits a 667×375 phone with no text overflow (checked).

**2. Crisp text (whole game)**
- `Theme.Text` now always uses a whole-number TextSize ≥ 14 and never TextScaled.
- New `Theme.Fade` fades each element's own transparency. It replaces every CanvasGroup fade, since CanvasGroups render text as an image and blur it. Converted: machine HUD (now just slides up), toasts, Title Book, genetics, stats.
- No screen-wide UIScale. The rotated "needs work" note on the machine HUD is now flat. The only remaining tilted text is 18px marker on tapes.
- Toast text uses Theme sizes. The machine HUD's UNLOCK button now sizes its text to fit (a 4-digit cost would have overflowed).

**3. Stats = live overlay (`StatsClient`, rewritten)**
- No camera takeover, freeze, blur or dim, so you can walk and turn the camera while it's open. The old unused DepthOfField effect was removed from Lighting.
- Labels:
  - Six compact, semi-transparent labels in fixed spots: Shoulders/Arms/Core on the left, Chest/Back/Legs on the right. They fade in together (0.2s) and never move or hide.
  - Only the leader lines move. They're smoothed (lerped) and only update while the overlay is open.
- Anchors:
  - Shoulders and Arms → whichever arm is on the left of the screen.
  - Legs → whichever leg is on the right.
  - Chest, Back and Core → the torso.
- Numbers update live, including while lifting.
- "needs work" shows only on the single weakest group (no tie), beside its label.
- Tap a label to open its sub-muscles in a small list under it. The list floats over the labels below, so nothing shifts; one list is open at a time.
- The goal panel sits at the top center. The columns are placed so they never overlap it, even when the GROWTH SPURT button shows.

**4. Side menu buttons (new `Shared.UI.SideMenu`)**
- Style:
  - 64×72 buttons, 12px corners, #1A1A1A at 15% transparency, 1.5px #2E2E2E border.
  - Chalk line icon over a small Oswald label: new Flex (flexing figure) and Trophy icons in `Icons`.
- Behavior:
  - Active: chalk background with a dark icon and label.
  - Red dot top right: STATS when a Growth Spurt becomes ready, TITLES when you unlock a title. It clears when you open them.
  - Press shrinks to 0.95. Stacked on the left middle with 8px gaps.
- Only STATS and TITLES exist; Bag and Crew will be added when those features exist.

**5. Overhead title (`TitleService.updateTag` + new `OverheadTitleClient`)**
- The billboard is sized in studs and sits above the head and name. MaxDistance is 60.
- Style: Oswald ALL CAPS in the rarity color with a thin dark stroke and a tiny plate disc in front. No tape or box. Secret titles use chalk text on a black disc so they stay readable.
- Legendary titles get a slow shine sweep every 4s.
- Your own title is drawn at 75% size and 40% transparent.

**6. Starter gym: moody, not dark**
- Lighting:
  - Warmer, brighter Ambient/OutdoorAmbient and ExposureCompensation 0.3; lighter atmosphere.
  - Pendants are warm #FFC98A with range 32 and angle 120 (wide, soft pools), plus a faint glow so the ceiling isn't pitch black.
  - 8 soft fill lights along the walkways.
- Room:
  - Floor is charcoal rubber #2B2B2B.
  - The harsh white window panels are now frosted, high basement windows with mullions.
- Sign and mirror: the bench-row lamps hang 1.3 studs higher so they no longer block the GYM ARC sign. Mirror reflectance went from 0.65 to 0.35 and is darker, and the sign glow was reduced, so there's much less red in the mirror.
- New center free-weight zone: a mat with a chalk border, 3 utility benches with dumbbell pairs, kettlebells and 2 lamps.
- Plates: the five plates leaning on walls are gone. Two plate trees were added (back-left corner and next to the crunch bench).
- Palette is brick, charcoal/black, chalk and warm light, with the red sign as the only neon:
  - Posters are black or chalk.
  - Dumbbell heads, mats, foam roller, gym bags and rope handles are black.
  - Shake cups are chalk and the SHAKES text is chalk.
  - Machine pads went from oxblood to near-black leather.
  - Bumper plates keep their colors.
- New entrance hall around the spawn (brick, lamp, frosted closed street doors), so the doorway no longer shows the empty baseplate.
- Checked with a simulated low-brightness filter: walls, floor and machines still read. The center mat was lightened so the black benches don't disappear.

**How to test**
- Join (or reset `onboarding.geneticsRevealed`) → watch the slam reveal. Open STATS → GENETICS → REROLL to see the fly-off.
- Open STATS and walk around: labels stay put, lines follow you. Tap SHOULDERS: the sub-list opens without moving the other labels.
- Lift on a machine with STATS open: the numbers tick up.
- Look at another player (2-player local test server) to see their full-size title. Equip a Legendary title to see the shine.
- Device Emulator → a phone in landscape: genetics, stats, machine HUD.

**Assumptions**
- The machine pads and the decor were recolored to fit the palette. Bumper plates (on machines, trees and wall racks) keep their colors because they're the plate color system.
- The entrance hall is a stand-in until the town hub exists. It can be deleted then (`Workspace.Gym.StarterGym.Entrance`).
- "Needs work" sits beside the label instead of under it, so the labels never shift.

**Not verified / limits**
- I can't drive Studio's Device Emulator. Instead, I rendered the genetics screen and machine HUD inside a 667×375 phone frame and ran an automatic text-overflow check (none). The stats overlay was checked by layout math.
- The legendary shine was confirmed by data (the gradient sweep runs), but my screenshots didn't catch it mid-sweep.
- Still needs your one-time step: Lighting → Technology → **Future**.
- Your save was backed up before the reroll test and restored after (C overall, Wide, Lean, 0 tokens). Verified in a fresh playtest.

---

## Step 0 — Popup fixes + breath instead of grunt

**Built**
- Grunt sound removed everywhere. New `Breath` sound (Pro Sound Effects "Candles Blow Out, Airy Breath, Exhale", 0.6s):
  plays at lockout only on heavy tiers (185 lb+) or under 40% stamina, 50% chance, never on back-to-back reps.
- CLAUDE.md Game feel section updated: no grunts on any machine, soft exhale rule written in.
- Gain popups: smaller (28px main, secondaries at 72%), secondary muscles nudged left/right so the three popups
  don't stack on top of each other, shorter float/fade.

**How to test**
- Get on the Flat Bench, lift. Popups should appear at chest/arms, main one centered, the other two to the sides.
- Switch to 185 lb+ or drain stamina below 40%: you'll occasionally hear a soft exhale at the top of a rep.

**Assumptions**
- I couldn't find your "popup fixes" message anywhere in our conversation or in CLAUDE.md, so I made best-guess fixes
  (smaller, no overlap, quicker). **Needs your decision:** tell me what you actually wanted changed.

**Broken / not verified**
- My screenshot tool doesn't capture BillboardGuis, so I verified popups by data only (created, sized 200x34, correct
  text and offsets), not visually.

---

## Step 2b — All 8 starter machines + starter gym room ✅

**Built**
- Starter gym room (`Workspace.Gym.StarterGym`): wood floor, brick walls, ceiling with 6 warm lamps, doorway
  facing the spawn.
- 7 new machine models from parts (no toolbox): Incline Bench, Overhead Press (rack + platform), Crunch Bench
  (plate on a stand), Squat Rack (power rack with J-hooks + safeties), Deadlift and Barbell Row (bar on jacks on
  a platform), Pull-Up Bar (plate belt hangs on a peg). The Flat Bench moved into its slot.
  Front row: Flat Bench, Incline Bench, Overhead Press, Crunch Bench. Back row: Squat Rack, Deadlift,
  Barbell Row, Pull-Up Bar.
- `Config.Machines`: all 8 machines with muscles from CLAUDE.md and tiers: Barbell, HeavyBarbell
  (squat/deadlift up to 405) and Bodyweight (BW, +10 ... +90 for pull-ups and crunches; panel shows "BW", "+10").
- `Config.Poses` + server: lie / stand / hang placement. The pull-up height comes from the character's arm length.
- Client pose system: one animation per pose using the R15 root, waist, shoulders, elbows, hips, knees and
  ankles: bench/incline arm flare, squat (bar rides on the upper back), deadlift hinge, overhead press,
  bent-over row, pull-up (body rises, plate belt at the hips), crunch (curl with knees up).
- The overhead-grip arm twist and angles were tuned by measuring hand positions in a playtest.

**How to test**
- Play, walk into the gym, use each machine (E / tap the prompt), tap to lift. Check that each pose looks right
  and the bar or plates stay in the hands, on the back (squat) or at the hips (pull-up belt).

**Assumptions**
- Pull-ups and crunches use bodyweight + added plates as their "weight tiers" (belt plates / plate on chest).
- Squat and deadlift go up to 405 lb; the other barbell lifts stop at 315 lb.
- Every rep starts and ends at the top (lockout). For pull-ups and crunches the rest position is the top
  (chin over bar / curled up), so the timing rules match the other lifts.
- Stamina cost: 6 for squat/deadlift, 4 for crunches, 5 for the rest.

**Broken / needs your decision**
- Poses are blocky approximations (Roblox R15, no custom animations). The hands sit ~0.6 studs under the
  pull-up bar at the top. They read fine, but a real animator would do better.
- Gains are not yet tuned for the 15–20 minute first Growth Spurt; that happens in step 5.
- Still open: Calves and Obliques can't be trained in the starter gym (see step 5).

## Step 3 — Theme + stats inspect mode ✅

**Built**
- Theme ("gym materials") was done earlier. Stats is now an in-world inspect mode (`StatsClient`), replacing the
  ViewportFrame screen, per your rework request. CLAUDE.md section 8 was rewritten to match.
- STATS button (chalk outline, left side) is always on screen. Opening tweens the camera (0.5s) to orbit in front of
  your real character, freezes movement, hides the machine panel, and adds a soft DepthOfField blur + slight dim.
- Drag/swipe orbits the camera (pitch clamped −20°..35°, smooth easing). EXIT (or STATS again) flies back.
- Labels: the 6 groups by default as dark 40%-transparent chips with chalk Oswald text, a big level number and a
  plate grade disc. Tap a group to expand its sub-muscles; tap again to collapse. Tap a sub-muscle for a card
  (level, grade, machines that train it) and a brief chalk highlight on that body part.
- Layout: side-and-sort with balancing (even columns), no overlaps, sorted by anchor height so lines never
  cross, thin chalk elbow lines. Muscles facing away from the camera are hidden.
- Weakest group chip outlined red; "needs work" tape under the weakest group (or the weakest muscle when its
  group is open).
- Also fixed: Studio playtests now take over a stale session lock immediately. Quick stop/start used to leave
  you on temporary, unsaved data for 5 minutes. Live servers keep the strict lock.

**How to test**
- Walk into the gym, press STATS. Drag left/right/up/down. Tap CHEST → Upper/Mid Chest appear. Tap MID CHEST →
  card + highlight. Turn around: Back shows up, Chest/Core hide. EXIT → camera returns, you can walk again.
- Check it on a phone in the Device Emulator. I could only test PC size; columns clamp to the screen edges.

**Assumptions**
- Only one group expands at a time (tapping another group switches).
- The bottom strip of 6 boxes from the old spec was dropped: the group chips around the body replace it, and
  the weakest group is outlined on its chip.
- Group dots sit at the average of that group's visible muscles. Arm/leg muscles anchor on the right limb.

## Starter gym fit-out ✅

**Built** (`Workspace.Gym.StarterGym`: Shell, Windows, Pendants, WallDecor, Props; layout written into CLAUDE.md)
- Room shrunk to 56x44, ceiling 13 with beams, pipes and ducts. Black rubber tile floor. Brick walls, 6 high windows.
- Zones: entrance (front desk, shake machine, fountain, chalkboard, cat bed), rack area on the left wall (squat,
  OHP, deadlift, row, all turned to face into the room), bench row facing the full mirror wall, pull-up/dip
  corner, dumbbell rack, stretching area. Clear center aisle.
- Wall decor: mirror wall, neon "GYM ARC" sign, 5 original text-only posters, Muscle of the Day chalkboard
  ("coming soon" until step 8), wall plate racks, hooks with belts and jump ropes, leaning plates.
- Lighting: 12 warm pendant spotlights with shadows, window light, neon glow, Atmosphere haze, softer bloom,
  warm `GymGrade` ColorCorrection, sun rays off.
- Plates are now bumper colors with chrome hubs; idle bars show a mix of loads/colors.
- ~340 parts total for the whole gym.

**Needs you**
- **Set Lighting → Technology to Future** in the Properties panel. Roblox blocks scripts from setting it. Until
  then the floor looks very dark, because the pendant spotlights barely light floors in the current lighting mode.

**Assumptions**
- The stretching area is tagged `Recovery = "StretchMat"` for the faster stamina refill later; it does nothing yet.
- Posters are text-only (no images) so nothing is copyrighted.



## Step 4 — Pump + body scaling ✅

**Built**
- `Server.BodyService` (server, so every player sees it):
  - Height from Growth Spurts via Roblox's BodyHeightScale (4'0" = 0.8 ... 7'0" = 1.4; 60 inches = 1.0).
  - Each group thickens its body parts as it levels: Chest/Back widen and deepen the UpperTorso, Shoulders add
    torso width + upper-arm thickness, Arms thicken upper/lower arms, Legs thicken legs, Core widens the
    LowerTorso. Up to +35% at the level cap. Joints (e.g. shoulders on a wider torso) and attachments
    (accessories) move with the parts so nothing detaches. Refreshes every 1.5s.
- Pump (client, from the Game feel step) now grows from the server's scaled size (`BaseSize` attribute), so
  the two don't fight.

**How to test**
- Lift until a group levels: that body part slowly thickens. Compare chest (level 25) vs core (level 0).

**Assumptions**
- Size is relative to the current Growth Spurt's level cap, so after a spurt you're taller but start thin again
  (muscles reset, as the brief says).
- Veins/abs/delt detail at high levels (section 14) isn't done: it needs texture/decal art. Placeholder: none.

**Note**
- Testing added XP to your dev save's Biceps/Triceps/Forearms (now about 24/40/24).

## Step 5 — Growth Spurts ✅

**Built**
- Goal: every group must reach the next spurt's level (50, 100, 175, 275, 400, then +150 each). Your level cap
  is that same number, so you reach the goal when all your trainable muscles are MAXED.
- `PlayerData.GrowthSpurt` (server-validated, via the new `PlayerAction` remote + `Server.ActionService`):
  muscles reset to 0, spurt count +1, +1 DNA Token. You get taller (BodyService rescales live, no respawn), and
  the permanent gains bonus (x1.25, x1.5, ...) applies through Gains.
- Inspect mode has a goal panel at the top: next spurt + height, 6 chunky blocks filling per group (yellow when
  met), "x/6 GROUPS AT LV n · GAINS xN AFTER", and a chalk GROWTH SPURT button when ready.
- Ready signal: a yellow dot on the STATS button + one corner notification.
- The moment: "GROWTH SPURT!" tape strip, chime, chalk burst, "You're now 4'6". Gains x1.25 forever!"
- Gains tuned toward the 15–20 minute first spurt: XP per level = 6 + level (1525 XP to reach 50), BaseXp 7.
  Math: 16 trainable muscles × 1525 = 24,400 XP. At ~1.1 s/rep with stamina breaks that's ~740 reps in 17 min,
  i.e. ~33 XP per rep across all trained muscles. This is an estimate: **please playtest the timing.**

**How to test**
- Lift on all 8 machines; open STATS to watch the goal fill. When ready, press GROWTH SPURT: you get taller,
  muscles reset, the panel moves to the next goal.
- I tested a full spurt by maxing muscles with a temporary script, then restored your save from a backup.

**Needs your decision**
- **Calves & Obliques:** no starter machine trains them, so the goal only counts muscles you can train right
  now (starter gym: Legs = Quads/Hamstrings/Glutes, Core = Abs). The stats chips still show the full average,
  so Legs/Core look lower than "met". Alternative: move Calf Raise + Cable Woodchop into the starter gym.
- Weight unlocks stay unlocked after a spurt (the brief doesn't say to reset them).

## Step 6 — Titles ✅

**Built**
- `Config.Titles`: 16 titles with data conditions (adding a title = adding an entry):
  Beginner Gains (first rep), Gym Rat (1,000 reps), Lock In (50-rep set), Glow Up (all groups 25+),
  Skipped Leg Day / Chicken Legs (chest/arms 2x legs), Boulder Shoulders (1.5x other groups), Greek Statue
  (all within 10%, 30+), Aesthetics God (all 45+), Late Bloomer (first spurt), Skyscraper (7'0"), Genetic Freak
  (S overall), Hard Gainer (D overall), Defied Genetics (max a D-grade group), Spotter (locked until spotting,
  step 9), No Days Off (secret: 500 reps in one visit).
- `Server.TitleService`: counts reps and sets (new `stats.totalReps` / `stats.bestSet` in the save), checks
  conditions after every validated rep, on join and after a Growth Spurt, grants titles, auto-equips your
  first one, and can award a linked badge.
- Equipped title shows above your head as a chalk tape strip (Permanent Marker) with a rarity disc.
- TITLES button under STATS opens the Title Book: rarity-ordered tape cards, locked ones show "???" with their
  rarity color, tap an owned title to equip (tap again to unequip). Corner note on unlock.

**How to test**
- Do one rep → "New title: Beginner Gains". Open TITLES, tap a title to equip; look at your head.

**Needs you**
- Badges: the biggest titles (Aesthetics God, Skyscraper, Defied Genetics) have a `badgeId = nil` slot. Create
  the badges on the Roblox website (I'm not allowed to) and paste the ids into `Config.Titles`.

**Assumptions**
- Cardio King and the legend physique titles aren't included: there's no cardio and no Legend NPCs yet.
- Physique titles use the full group levels (including untrainable Calves/Obliques), so Greek Statue and
  Aesthetics God can't be earned until those muscles are trainable (pro gym).
- Your dev save got Skipped Leg Day + Beginner Gains during testing.

## Step 7 — Genetics reveal / reroll ✅

**Built** (`GeneticsClient`, plus `Reroll` / `GeneticsSeen` actions in `Server.ActionService`)
- First join: the reveal opens automatically. The 6 group grades flip over one by one as bumper plate discs
  (with a tick sound and x-multiplier), then frame and body type (with what they do, generated from the config),
  then a big overall grade with a chime.
- Odds are always visible on the screen (grades per group, frame, body type, computed from the config weights).
- REROLL uses the free reroll first, then 1 DNA Token (server-validated), rerolls everything at once and replays
  the reveal. KEEP closes it and marks the reveal as seen (new `onboarding.geneticsRevealed` in the save).
- Inspect mode has a GENETICS button (bottom-left, with your overall grade disc) to reopen it any time.
- Movement is frozen and taps are blocked while it's open.

**How to test**
- Join: the reveal plays (your save is reset so you see it). Try REROLL (free), then KEEP.
- Open STATS → GENETICS to see it again; REROLL is greyed out with 0 DNA Tokens.

**Assumptions**
- DNA Tokens come from Growth Spurts for now (daily streak / store come later).
- Existing saves see the reveal once too (the flag is new).
- Your dev save was restored after testing (overall A, free reroll still available).
