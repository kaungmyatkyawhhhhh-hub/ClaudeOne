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
--   seconds    `count` seconds pass
-- Saves store the step number and the server only moves it forward. Players who finished never see new steps.
local Onboarding = {}

Onboarding.Steps = {
	{ id = "GoBench", text = "Walk to the Flat Bench and tap Use.", onMachineText = "Tap Exit, then walk to the Flat Bench.",
		target = "FlatBench", done = { type = "onMachine" } },
	{ id = "FirstLift", text = "Tap anywhere to lift.", done = { type = "reps", count = 1 } },
	{ id = "Stamina", text = "Every rep uses stamina. Keep lifting until it runs low.", done = { type = "staminaLow", below = 0.4, count = 20 } },
	{ id = "Rest", text = "Stamina refills on its own when you rest. Legs are next.", done = { type = "seconds", count = 4 } },
	{ id = "GoSquat", text = "Head to the Squat Rack.", onMachineText = "Tap Exit, then head to the Squat Rack.",
		target = "SquatRack", done = { type = "onMachine" } },
	{ id = "SquatLift", text = "Tap to lift. Legs need love too.", done = { type = "reps", count = 3, machine = "SquatRack" } },
	{ id = "OpenStats", text = "Open Stats on the left to see your muscles.", done = { type = "statsOpen" } },
	{ id = "Coach", text = "Find Coach Dex at the front desk and tap Talk.", onMachineText = "Tap Exit, then find Coach Dex at the front desk.",
		target = "Coach", done = { type = "quest" } },
	{ id = "Goal", text = "Open Stats again. At the top: your Growth Spurt goal. Get every group there to grow taller.",
		done = { type = "statsOpenFor", count = 6 } },
}

-- The saved step number once every step is finished. Fixed (not #Steps + 1), so adding steps later never sends
-- players who already finished back into the tutorial.
Onboarding.Done = 100
-- Bumped when steps are renumbered; PlayerData converts older saves (see PlayerData onPlayerAdded).
Onboarding.Version = 2

Onboarding.FinishedText = "You're all set. Go get big."

return Onboarding
