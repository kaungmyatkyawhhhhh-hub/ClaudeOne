-- Every machine is one entry in Machines.List. muscles[1] is the main muscle;
-- the rest are secondaries. Players only ever see muscle names, never shares.
local Machines = {}

-- Weight tiers: 12 per machine, built from the shared progression below. A tier is usable when it is bought
-- (coins, once) AND the machine's main muscle is at its unlockLevel (needed again after every Growth Spurt).
--   gains = gains multiplier, unlockLevel = main muscle level needed, cost = coins to buy it,
--   coins = coins per rep, plates = plates per side (lb), label = optional text instead of the weight (e.g. "BW").
-- Heavier always pays more per rep, so moving up is always worth it. Tuned with tests/pacing.
Machines.Progression = {
	gains = { 1, 1.3, 1.65, 2.05, 2.5, 3, 3.6, 4.3, 5.1, 6, 7, 8.2 },
	unlockLevel = { 0, 3, 7, 12, 18, 25, 33, 42, 52, 64, 78, 95 },
	cost = { 0, 5, 12, 25, 45, 70, 110, 160, 230, 320, 440, 600 },
	coins = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 9 },
}

-- Plates per weight: one color per weight, used the same way everywhere (bars, racks, the HUD barbell).
-- color = Theme.Bumper key ("Steel" = small metal change plate). Sizes in studs.
Machines.Plates = {
	[55] = { thickness = 0.36, diameter = 2.3, color = "Red" },
	[45] = { thickness = 0.3, diameter = 2.3, color = "Blue" },
	[35] = { thickness = 0.26, diameter = 2.05, color = "Yellow" },
	[25] = { thickness = 0.22, diameter = 1.75, color = "Green" },
	[10] = { thickness = 0.18, diameter = 1.3, color = "White" },
	[5] = { thickness = 0.12, diameter = 0.95, color = "Steel" },
}
Machines.PlateOrder = { 55, 45, 35, 25, 10, 5 } -- heaviest first (inside on the sleeve, bottom of a stack)

-- rows: { weight, plates per side, label? }; the first row is the empty bar / bodyweight / lightest stack
local function tierSet(rows, firstName)
	local p = Machines.Progression
	local set = {}
	for i, row in ipairs(rows) do
		local plates = row[2]
		set[i] = {
			weight = row[1], label = row[3], name = if i == 1 then firstName else nil, plates = plates,
			gains = p.gains[i], unlockLevel = p.unlockLevel[i], cost = p.cost[i], coins = p.coins[i],
			-- the heaviest plate's color stands for the tier (HUD weight, tier dots)
			color = if plates[1] then Machines.Plates[plates[1]].color else nil,
		}
	end
	return set
end

Machines.TierSets = {
	Barbell = tierSet({
		{ 45, {} }, { 65, { 10 } }, { 95, { 25 } }, { 115, { 35 } }, { 135, { 45 } }, { 155, { 45, 10 } },
		{ 185, { 45, 25 } }, { 205, { 45, 35 } }, { 225, { 45, 45 } }, { 255, { 55, 45, 5 } }, { 275, { 55, 55, 5 } },
		{ 315, { 55, 55, 25 } },
	}, "Empty Bar"),
	-- Squat, deadlift and hip thrust go heavier.
	HeavyBarbell = tierSet({
		{ 45, {} }, { 95, { 25 } }, { 135, { 45 } }, { 165, { 55, 5 } }, { 185, { 45, 25 } }, { 225, { 45, 45 } },
		{ 255, { 55, 45, 5 } }, { 275, { 55, 55, 5 } }, { 315, { 55, 55, 25 } }, { 365, { 55, 55, 45, 5 } },
		{ 405, { 55, 55, 45, 25 } }, { 455, { 55, 55, 55, 35, 5 } },
	}, "Empty Bar"),
	-- Pull-ups, dips, crunches: bodyweight, then plates added (belt / held on the chest).
	Bodyweight = tierSet({
		{ 0, {}, "BW" }, { 5, { 5 }, "+5" }, { 10, { 10 }, "+10" }, { 15, { 10, 5 }, "+15" }, { 25, { 25 }, "+25" },
		{ 35, { 35 }, "+35" }, { 45, { 45 }, "+45" }, { 55, { 55 }, "+55" }, { 70, { 55, 10, 5 }, "+70" },
		{ 80, { 55, 25 }, "+80" }, { 90, { 55, 35 }, "+90" }, { 100, { 55, 45 }, "+100" },
	}, "Bodyweight"),
	-- Cable stacks and dumbbell-style moves: lighter numbers, same progression.
	Cable = tierSet({
		{ 10, {} }, { 20, { 10 } }, { 30, { 25, 5 } }, { 40, { 35, 5 } }, { 50, { 45, 5 } }, { 60, { 55, 5 } },
		{ 70, { 55, 10, 5 } }, { 80, { 55, 25 } }, { 90, { 55, 35 } }, { 100, { 55, 45 } }, { 110, { 55, 55 } },
		{ 120, { 55, 55, 10 } },
	}),
}

-- Highest tier this player can lift right now: bought (progress.unlocked) and the main muscle level is high enough.
function Machines.UsableTier(machine, progress, mainLevel)
	local usable = 1
	for index = 1, math.min(progress and progress.unlocked or 1, #machine.tiers) do
		if mainLevel >= machine.tiers[index].unlockLevel then usable = index end
	end
	return usable
end

-- The tier to lift: the selected one, but never above what the level allows right now.
function Machines.LiftTier(machine, progress, mainLevel)
	return math.min(progress and progress.selected or 1, Machines.UsableTier(machine, progress, mainLevel))
end

-- Text for a weight ("135 lb", "BW", "+25 lb").
function Machines.WeightText(tier)
	if tier.label then return tier.label == "BW" and "Bodyweight" or (tier.label .. " lb") end
	return tier.weight .. " lb"
end

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

-- Beach gym (town hub, opens at Growth Spurt 1): outdoor cable stacks under a canopy (TownService builds them with the
-- pro gym's machine builder). They only train muscles the starter gym already trains, so the Growth Spurt goal
-- never changes; they're a faster way to bring up arms, shoulders and traps after the first spurt.
local BEACH = {
	{ id = "BeachCurl", name = "Beach Curl", pose = "BicepCurl", tiers = "Cable", staminaCost = 4,
		muscles = { { id = "Biceps", share = 1 }, { id = "Forearms", share = 0.4 } } },
	{ id = "BeachRaise", name = "Beach Lateral Raise", pose = "LateralRaise", tiers = "Cable", staminaCost = 4,
		muscles = { { id = "SideDelts", share = 1 } } },
	{ id = "BeachShrug", name = "Beach Shrug", pose = "Shrug", tiers = "Barbell", staminaCost = 4,
		muscles = { { id = "Traps", share = 1 }, { id = "Forearms", share = 0.4 } } },
}
for _, machine in ipairs(BEACH) do
	machine.gym = "Beach"
	machine.layout = "Center"
	machine.tiers = Machines.TierSets[machine.tiers]
	table.insert(Machines.List, machine)
end

-- Seasonal: only built while Winter Lifts runs (SeasonService). Trains muscles the starter gym already trains,
-- so it never changes what counts toward a Growth Spurt.
table.insert(Machines.List, {
	id = "SledPull", name = "Sled Pull", gym = "Seasonal", pose = "SledPush", layout = "Center", staminaCost = 6,
	tiers = Machines.TierSets.HeavyBarbell,
	muscles = { { id = "Quads", share = 1 }, { id = "Glutes", share = 0.5 }, { id = "Hamstrings", share = 0.4 } },
})

Machines.ById = {}
for _, machine in ipairs(Machines.List) do
	Machines.ById[machine.id] = machine
end

-- Gyms open by Growth Spurt count (the pro gym opens at Growth Spurt 2).
Machines.GymUnlock = { Starter = 0, Beach = 1, Pro = 2, Seasonal = 0 }

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
