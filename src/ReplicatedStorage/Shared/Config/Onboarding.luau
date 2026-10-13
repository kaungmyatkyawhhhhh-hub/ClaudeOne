-- First 5 minutes: the tutorial steps, in order (after the menu and the genetics reveal).
-- Each step shows one coach line (`text`; `onMachineText` instead while the player is on another machine).
-- `target` = MachineId (or "Coach") to walk to: a glowing path on the floor leads there and it gets an outline.
-- `done` says what finishes the step (checked by TutorialClient):
--   onMachine  the player gets on the target machine
--   reps       `count` validated reps since the step started (optional `machine` = only on that machine)
--   staminaLow stamina drops below `below` (0-1), or `count` reps since the step started, whichever is first
--   statsOpen  the Stats overlay is opened
--   statsOpenFor  the Stats overlay has been open for `count` seconds in total (or is closed after opening)
--   quest      the player has a quest from the Coach
--   shake      the player drinks an Energy Shake
-- `gift` = given by the server once, when the player reaches the step ({ shakes = n }).
--   seconds    `count` seconds pass
-- `coach` = the Coach's pages for the step (owner's UI v2, mockup 11: a dialog with his portrait at the bottom, "Tap to
-- continue (1/3)"); the short `text` stays in the top band. While you're on a machine there is no dialog (band only).
-- Saves store the step number and the server only moves it forward. Players who finished never see new steps.
-- SKIP TUTORIAL (tap it twice) jumps to the end without the reward; finishing it the normal way pays FinishCoins.
local Onboarding = {}

Onboarding.Steps = {
	{ id = "GoBench", text = "Walk to the Flat Bench and tap Occupy.", onMachineText = "Tap Exit, then walk to the Flat Bench.",
		target = "FlatBench", done = { type = "onMachine" },
		coach = { "Welcome to the gym! Follow the glowing dots to the Flat Bench and tap Occupy.",
			"Every machine trains real muscles. The bench builds your chest, shoulders and triceps." } },
	{ id = "FirstLift", text = "Tap REP to lift faster. A full PUMP bar: tap it for x2.", done = { type = "reps", count = 1 },
		coach = { "Reps go on their own. Tap REP to lift faster!", "Every tap fills the PUMP bar. When it's full, tap it for double gains." } },
	{ id = "Stamina", text = "Every rep uses stamina. Keep lifting until it runs low.", done = { type = "staminaLow", below = 0.4, count = 20 },
		coach = { "Every rep uses stamina, the blue bar. Keep lifting until it runs low." } },
	{ id = "Shake", text = "Stamina refills when you rest. Here's a free Energy Shake: tap Drink shake on the right.",
		gift = { shakes = 1 }, done = { type = "shake" },
		coach = { "Stamina refills when you rest. Here's a free Energy Shake on me!", "Tap Drink shake on the right to fill up right away." } },
	{ id = "GoSquat", text = "Head to the Squat Rack.", onMachineText = "Tap Exit, then head to the Squat Rack.",
		target = "SquatRack", done = { type = "onMachine" },
		coach = { "Nice work! Now head to the Squat Rack. Legs need love too." } },
	{ id = "SquatLift", text = "Tap fast to fill the PUMP bar, then tap it. Legs need love too.", done = { type = "reps", count = 3, machine = "SquatRack" } },
	{ id = "OpenStats", text = "Open Stats in the menu to see your muscles.", done = { type = "statsOpen" },
		coach = { "Want to see your gains? Tap Stats in the menu on the left." } },
	{ id = "Coach", text = "Find Coach Dex at the front desk and tap Talk.", onMachineText = "Tap Exit, then find Coach Dex at the front desk.",
		target = "Coach", done = { type = "quest" },
		coach = { "Come find me at the front desk and tap Talk. I'll give you your first quest." } },
	{ id = "Goal", text = "Open Muscles in the menu: the Growth Spurt row shows your goal.",
		done = { type = "statsOpenFor", count = 6 },
		coach = { "Open Muscles in the menu to see your Growth Spurt goal.",
			"Get every muscle group to its goal and you grow taller, with bigger gains forever!" } },
}

-- The saved step number once every step is finished. Fixed (not #Steps + 1), so adding steps later never sends
-- players who already finished back into the tutorial.
Onboarding.Done = 100
-- Bumped when steps are renumbered; PlayerData converts older saves (see PlayerData onPlayerAdded).
Onboarding.Version = 2

Onboarding.FinishedText = "You're all set. Go get big."
Onboarding.FinishCoins = 50 -- paid once when the last step is done the normal way (not when skipped)

return Onboarding
