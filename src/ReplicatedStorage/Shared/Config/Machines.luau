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
-- color = Theme.Bumper key ("Steel" = small metal change plate). Sizes in studs. Thin like calibrated plates, so the
-- heaviest tier fits the sleeves (tests/machines checks every tier fits Machines.SleeveRoom).
Machines.Plates = {
	[55] = { thickness = 0.2, diameter = 2.3, color = "Red" },
	[45] = { thickness = 0.17, diameter = 2.3, color = "Blue" },
	[35] = { thickness = 0.15, diameter = 2.05, color = "Yellow" },
	[25] = { thickness = 0.13, diameter = 1.75, color = "Green" },
	[10] = { thickness = 0.1, diameter = 1.3, color = "White" },
	[5] = { thickness = 0.07, diameter = 0.95, color = "Steel" },
}
Machines.PlateGap = 0.02   -- between plates on a sleeve
Machines.SleeveRoom = 1.55 -- studs of sleeve for plates (the BarSleeve is 1.75 long, the end collar takes the rest)
-- Width of one side's plates (plus gaps and the end collar) for a tier.
function Machines.StackWidth(tier): number
	local width = 0.12 -- the end collar
	for _, lb in ipairs(tier.plates) do width += Machines.Plates[lb].thickness + Machines.PlateGap end
	return width
end
Machines.Brand = "M WEIGHTS" -- printed on every plate face (the owner's gym brand)
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
	-- Leg press and hack squat: the same heavy loading as a squat, on a sled / carriage.
	Sled = tierSet({
		{ 45, {} }, { 95, { 25 } }, { 135, { 45 } }, { 165, { 55, 5 } }, { 185, { 45, 25 } }, { 225, { 45, 45 } },
		{ 255, { 55, 45, 5 } }, { 275, { 55, 55, 5 } }, { 315, { 55, 55, 25 } }, { 365, { 55, 55, 45, 5 } },
		{ 405, { 55, 55, 45, 25 } }, { 455, { 55, 55, 55, 35, 5 } },
	}, "Empty Sled"),
	-- Pull-ups, dips, crunches: bodyweight, then plates added (belt / held on the chest).
	Bodyweight = tierSet({
		{ 0, {}, "BW" }, { 5, { 5 }, "+5" }, { 10, { 10 }, "+10" }, { 15, { 10, 5 }, "+15" }, { 25, { 25 }, "+25" },
		{ 35, { 35 }, "+35" }, { 45, { 45 }, "+45" }, { 55, { 55 }, "+55" }, { 70, { 55, 10, 5 }, "+70" },
		{ 80, { 55, 25 }, "+80" }, { 90, { 55, 35 }, "+90" }, { 100, { 55, 45 }, "+100" },
	}, "Bodyweight"),
	-- Treadmill: speeds instead of weights (weight = mph, unit shown instead of "lb").
	Treadmill = (function()
		local rows = {}
		for i = 1, 12 do rows[i] = { i + 1, {} } end
		local set = tierSet(rows, "Walk")
		for _, tier in ipairs(set) do tier.unit = "mph" end
		return set
	end)(),
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

-- Text for a weight ("135 lb", "BW", "+25 lb", "6 mph").
function Machines.WeightText(tier)
	if tier.unit then return tier.weight .. " " .. tier.unit end
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
		muscles = { { id = "Abs", share = 1 }, { id = "Obliques", share = 0.6 } }, -- (the obliques work on every crunch: the starter gym trains them too)
		tiers = Machines.TierSets.Bodyweight, staminaCost = 4,
	},
	-- Plate-loaded leg machines (also placed in the pro gym). load = the part that slides on the machine's rail with the
	-- rep (the sled's foot platform / the hack squat carriage), see the model's Rail* attributes (GymKit).
	{
		id = "LegPress", name = "Leg Press", gym = "Starter", pose = "LegPress", load = "Sled",
		muscles = { { id = "Quads", share = 1 }, { id = "Glutes", share = 0.42 }, { id = "Hamstrings", share = 0.25 } },
		tiers = Machines.TierSets.Sled, staminaCost = 6,
	},
	{
		id = "HackSquat", name = "Hack Squat", gym = "Starter", pose = "HackSquat", load = "Carriage",
		muscles = { { id = "Quads", share = 1 }, { id = "Glutes", share = 0.2 }, { id = "Calves", share = 0.13 } },
		tiers = Machines.TierSets.Sled, staminaCost = 6,
	},
	-- Treadmill (2 in the starter gym's cardio corner, 4 in the pro gym): running uses no stamina (it keeps refilling, so it's something to do
	-- between sets), a little leg EXP (gainScale: well below a real leg machine, so it never beats lifting), normal coins,
	-- and the distance counts toward the Cardio King title (Machines.Cardio). load = the belt (no plates).
	{
		id = "Treadmill", name = "Treadmill", gym = "Starter", pose = "Run", load = "Belt", layout = "Center",
		muscles = { { id = "Quads", share = 1 }, { id = "Hamstrings", share = 0.3 }, { id = "Calves", share = 0.13 } },
		tiers = Machines.TierSets.Treadmill, staminaCost = 0, gainScale = 0.35,
	},
}

-- Cardio: the in-game distance per treadmill rep is the speed (mph) x MetersPerMph; Cardio King needs KingMeters in total.
Machines.Cardio = { MetersPerMph = 2, KingMeters = 10000, BeltScroll = 1.2 } -- BeltScroll: belt texture studs/s per mph

-- Client performance: other lifters (players and NPC regulars) are only animated (arms, moving bar and plates) within
-- AnimateDistance studs of the camera, and the pump swell only shows within PumpDistance. Your own lift always animates.
Machines.ClientCull = { AnimateDistance = 80, PumpDistance = 45 }

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

-- Set of muscle ids that some open machine trains (main or a real secondary: a light touch, below GoalShare, like the
-- hack squat's calves, still gains a little but doesn't put that muscle into the Growth Spurt goal).
Machines.GoalShare = 0.2
function Machines.TrainableMuscles(growthSpurts)
	local set = {}
	for _, machine in ipairs(Machines.List) do
		if growthSpurts >= (Machines.GymUnlock[machine.gym] or 0) then
			for _, entry in ipairs(machine.muscles) do
				if (entry.share or 1) >= Machines.GoalShare then set[entry.id] = true end
			end
		end
	end
	return set
end

-- The open machines whose MAIN muscle is in a group (the Muscles panel lists them as the group's exercises).
function Machines.ExercisesFor(groupId: string, growthSpurts: number, muscleGroup: (string) -> string): { string }
	local names, seen = {}, {}
	for _, machine in ipairs(Machines.List) do
		local open = growthSpurts >= (Machines.GymUnlock[machine.gym] or 0) and machine.gym ~= "Seasonal"
		if open and muscleGroup(machine.muscles[1].id) == groupId and not seen[machine.name] then
			seen[machine.name] = true
			table.insert(names, machine.name)
		end
	end
	return names
end

return Machines
