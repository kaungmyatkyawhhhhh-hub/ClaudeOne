-- Every machine is one entry in Machines.List. muscles[1] is the main muscle;
-- the rest are secondaries. Players only ever see muscle names, never shares.
local Machines = {}

-- Weight tiers. gains = gains multiplier, unlockLevel = main muscle level needed,
-- cost = coins to unlock, coins = coins per rep, plates = plates per side (lb),
-- color = bumper plate color (Theme.Bumper key) shown on the HUD barbell,
-- label = optional text instead of the weight number (e.g. "BW").
Machines.TierSets = {
	Barbell = {
		{ weight = 45, name = "Empty Bar", gains = 1, unlockLevel = 0, cost = 0, coins = 1, plates = {} },
		{ weight = 65, gains = 1.4, unlockLevel = 3, cost = 15, coins = 1, plates = { 10 }, color = "White" },
		{ weight = 95, gains = 2, unlockLevel = 7, cost = 40, coins = 2, plates = { 25 }, color = "Green" },
		{ weight = 135, gains = 2.7, unlockLevel = 12, cost = 90, coins = 2, plates = { 45 }, color = "Yellow" },
		{ weight = 185, gains = 3.5, unlockLevel = 18, cost = 175, coins = 3, plates = { 45, 25 }, color = "Blue" },
		{ weight = 225, gains = 4.4, unlockLevel = 25, cost = 300, coins = 3, plates = { 45, 45 }, color = "Red" },
		{ weight = 275, gains = 5.4, unlockLevel = 33, cost = 500, coins = 4, plates = { 45, 45, 25 }, color = "Red" },
		{ weight = 315, gains = 6.5, unlockLevel = 42, cost = 800, coins = 5, plates = { 45, 45, 45 }, color = "Red" },
	},
	-- Squat and deadlift go heavier.
	HeavyBarbell = {
		{ weight = 45, name = "Empty Bar", gains = 1, unlockLevel = 0, cost = 0, coins = 1, plates = {} },
		{ weight = 95, gains = 1.4, unlockLevel = 3, cost = 15, coins = 1, plates = { 25 }, color = "White" },
		{ weight = 135, gains = 2, unlockLevel = 7, cost = 40, coins = 2, plates = { 45 }, color = "Green" },
		{ weight = 185, gains = 2.7, unlockLevel = 12, cost = 90, coins = 2, plates = { 45, 25 }, color = "Yellow" },
		{ weight = 225, gains = 3.5, unlockLevel = 18, cost = 175, coins = 3, plates = { 45, 45 }, color = "Blue" },
		{ weight = 275, gains = 4.4, unlockLevel = 25, cost = 300, coins = 3, plates = { 45, 45, 25 }, color = "Red" },
		{ weight = 315, gains = 5.4, unlockLevel = 33, cost = 500, coins = 4, plates = { 45, 45, 45 }, color = "Red" },
		{ weight = 405, gains = 6.5, unlockLevel = 42, cost = 800, coins = 5, plates = { 45, 45, 45, 45 }, color = "Red" },
	},
	-- Pull-ups and crunches: bodyweight, then plates added (belt / held on the chest).
	Bodyweight = {
		{ weight = 0, label = "BW", name = "Bodyweight", gains = 1, unlockLevel = 0, cost = 0, coins = 1, plates = {} },
		{ weight = 10, label = "+10", gains = 1.4, unlockLevel = 3, cost = 15, coins = 1, plates = { 10 }, color = "White" },
		{ weight = 25, label = "+25", gains = 2, unlockLevel = 7, cost = 40, coins = 2, plates = { 25 }, color = "Green" },
		{ weight = 35, label = "+35", gains = 2.7, unlockLevel = 12, cost = 90, coins = 2, plates = { 25, 10 }, color = "Yellow" },
		{ weight = 45, label = "+45", gains = 3.5, unlockLevel = 18, cost = 175, coins = 3, plates = { 45 }, color = "Blue" },
		{ weight = 55, label = "+55", gains = 4.4, unlockLevel = 25, cost = 300, coins = 3, plates = { 45, 10 }, color = "Red" },
		{ weight = 70, label = "+70", gains = 5.4, unlockLevel = 33, cost = 500, coins = 4, plates = { 45, 25 }, color = "Red" },
		{ weight = 90, label = "+90", gains = 6.5, unlockLevel = 42, cost = 800, coins = 5, plates = { 45, 45 }, color = "Red" },
	},
	-- Cable stacks and dumbbell-style moves (pro gym): lighter numbers, same progression.
	Cable = {
		{ weight = 10, gains = 1, unlockLevel = 0, cost = 0, coins = 1, plates = {} },
		{ weight = 20, gains = 1.4, unlockLevel = 3, cost = 15, coins = 1, plates = { 10 }, color = "White" },
		{ weight = 30, gains = 2, unlockLevel = 7, cost = 40, coins = 2, plates = { 25 }, color = "Green" },
		{ weight = 40, gains = 2.7, unlockLevel = 12, cost = 90, coins = 2, plates = { 25, 10 }, color = "Yellow" },
		{ weight = 50, gains = 3.5, unlockLevel = 18, cost = 175, coins = 3, plates = { 45 }, color = "Blue" },
		{ weight = 60, gains = 4.4, unlockLevel = 25, cost = 300, coins = 3, plates = { 45, 10 }, color = "Red" },
		{ weight = 70, gains = 5.4, unlockLevel = 33, cost = 500, coins = 4, plates = { 45, 25 }, color = "Red" },
		{ weight = 80, gains = 6.5, unlockLevel = 42, cost = 800, coins = 5, plates = { 45, 45 }, color = "Red" },
	},
}

-- Plate look per weight (thickness/diameter in studs).
Machines.Plates = {
	[45] = { thickness = 0.32, diameter = 2.3, color = Color3.fromRGB(38, 38, 42) },
	[25] = { thickness = 0.28, diameter = 1.75, color = Color3.fromRGB(52, 52, 58) },
	[10] = { thickness = 0.22, diameter = 1.25, color = Color3.fromRGB(70, 70, 76) },
}

-- pose = Config.Poses key. load = the part in the model that carries the plates
-- ("Bar" by default); layout = "Sleeves" (both ends of a bar) or "Center" (one stack).
Machines.List = {
	{
		id = "FlatBench", name = "Flat Bench", gym = "Starter", pose = "BenchPress",
		muscles = { { id = "MidChest", share = 1 }, { id = "FrontDelts", share = 0.4 }, { id = "Triceps", share = 0.5 } },
		tiers = Machines.TierSets.Barbell, staminaCost = 5,
	},
	{
		id = "InclineBench", name = "Incline Bench", gym = "Starter", pose = "InclinePress",
		muscles = { { id = "UpperChest", share = 1 }, { id = "FrontDelts", share = 0.5 }, { id = "Triceps", share = 0.4 } },
		tiers = Machines.TierSets.Barbell, staminaCost = 5,
	},
	{
		id = "SquatRack", name = "Squat Rack", gym = "Starter", pose = "Squat",
		muscles = { { id = "Quads", share = 1 }, { id = "Glutes", share = 0.5 }, { id = "LowerBack", share = 0.3 } },
		tiers = Machines.TierSets.HeavyBarbell, staminaCost = 6,
	},
	{
		id = "Deadlift", name = "Deadlift", gym = "Starter", pose = "Deadlift",
		muscles = {
			{ id = "LowerBack", share = 1 }, { id = "Hamstrings", share = 0.5 }, { id = "Glutes", share = 0.5 },
			{ id = "Traps", share = 0.3 }, { id = "Forearms", share = 0.3 },
		},
		tiers = Machines.TierSets.HeavyBarbell, staminaCost = 6,
	},
	{
		id = "OverheadPress", name = "Overhead Press", gym = "Starter", pose = "OverheadPress",
		muscles = { { id = "FrontDelts", share = 1 }, { id = "SideDelts", share = 0.5 }, { id = "Triceps", share = 0.4 } },
		tiers = Machines.TierSets.Barbell, staminaCost = 5,
	},
	{
		id = "PullUpBar", name = "Pull-Up Bar", gym = "Starter", pose = "PullUp", load = "Load", layout = "Center",
		muscles = { { id = "Lats", share = 1 }, { id = "Biceps", share = 0.5 }, { id = "RearDelts", share = 0.4 } },
		tiers = Machines.TierSets.Bodyweight, staminaCost = 5,
	},
	{
		id = "BarbellRow", name = "Barbell Row", gym = "Starter", pose = "BarbellRow",
		muscles = {
			{ id = "Rhomboids", share = 1 }, { id = "Lats", share = 0.5 }, { id = "RearDelts", share = 0.4 }, { id = "Biceps", share = 0.3 },
		},
		tiers = Machines.TierSets.Barbell, staminaCost = 5,
	},
	{
		id = "CrunchBench", name = "Crunch Bench", gym = "Starter", pose = "Crunch", load = "Load", layout = "Center",
		muscles = { { id = "Abs", share = 1 } },
		tiers = Machines.TierSets.Bodyweight, staminaCost = 4,
	},
}

-- Pro gym (opens at Growth Spurt 2). Built from code by ProGymService; every one carries its plates on a
-- weight stack ("Bar" part, centered layout) and the lifter's hands stay free (pose follow = "None").
local PRO = {
	{ id = "Dips", name = "Dips", pose = "Dip", tiers = "Bodyweight", staminaCost = 5,
		muscles = { { id = "MidChest", share = 1 }, { id = "Triceps", share = 0.5 }, { id = "FrontDelts", share = 0.4 } } },
	{ id = "LateralRaise", name = "Lateral Raise", pose = "LateralRaise", tiers = "Cable", staminaCost = 4,
		muscles = { { id = "SideDelts", share = 1 } } },
	{ id = "ReverseFly", name = "Reverse Fly", pose = "ReverseFly", tiers = "Cable", staminaCost = 4,
		muscles = { { id = "RearDelts", share = 1 }, { id = "Rhomboids", share = 0.5 } } },
	{ id = "Shrugs", name = "Shrugs", pose = "Shrug", tiers = "Barbell", staminaCost = 4,
		muscles = { { id = "Traps", share = 1 }, { id = "Forearms", share = 0.4 } } },
	{ id = "LegCurl", name = "Leg Curl", pose = "LegCurl", tiers = "Cable", staminaCost = 5,
		muscles = { { id = "Hamstrings", share = 1 } } },
	{ id = "HipThrust", name = "Hip Thrust", pose = "HipThrust", tiers = "HeavyBarbell", staminaCost = 6,
		muscles = { { id = "Glutes", share = 1 }, { id = "Hamstrings", share = 0.5 } } },
	{ id = "CalfRaise", name = "Calf Raise", pose = "CalfRaise", tiers = "Barbell", staminaCost = 4,
		muscles = { { id = "Calves", share = 1 } } },
	{ id = "BicepCurl", name = "Bicep Curl", pose = "BicepCurl", tiers = "Cable", staminaCost = 4,
		muscles = { { id = "Biceps", share = 1 }, { id = "Forearms", share = 0.4 } } },
	{ id = "TricepPushdown", name = "Tricep Pushdown", pose = "TricepPushdown", tiers = "Cable", staminaCost = 4,
		muscles = { { id = "Triceps", share = 1 } } },
	{ id = "HangingLegRaise", name = "Hanging Leg Raise", pose = "LegRaise", tiers = "Bodyweight", staminaCost = 5,
		muscles = { { id = "Abs", share = 1 }, { id = "Forearms", share = 0.4 } } },
	{ id = "CableWoodchop", name = "Cable Woodchop", pose = "Woodchop", tiers = "Cable", staminaCost = 4,
		muscles = { { id = "Obliques", share = 1 }, { id = "Abs", share = 0.5 } } },
}
for _, machine in ipairs(PRO) do
	machine.gym = "Pro"
	machine.layout = "Center"
	machine.tiers = Machines.TierSets[machine.tiers]
	table.insert(Machines.List, machine)
end

Machines.ById = {}
for _, machine in ipairs(Machines.List) do
	Machines.ById[machine.id] = machine
end

-- Gyms open by Growth Spurt count (the pro gym opens at Growth Spurt 2).
Machines.GymUnlock = { Starter = 0, Pro = 2 }

-- Set of muscle ids that some open machine trains (main or secondary).
function Machines.TrainableMuscles(growthSpurts)
	local set = {}
	for _, machine in ipairs(Machines.List) do
		if growthSpurts >= (Machines.GymUnlock[machine.gym] or 0) then
			for _, entry in ipairs(machine.muscles) do set[entry.id] = true end
		end
	end
	return set
end

return Machines
