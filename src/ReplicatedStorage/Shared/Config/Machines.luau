-- Every machine is one entry in Machines.List. muscles[1] is the main muscle;
-- the rest are secondaries. Players only ever see muscle names, never shares.
local Machines = {}

-- Gyms open by Growth Spurt count. (prompt 58, owner 23 Oct: not a new gym every spurt) Starter, Beach at 1, NO gym at 2,
-- the Pro Gym at 3 (was 2: players who had already been inside keep it, data.gymAccess, Machines.GymLevel), NO gym at 4,
-- the Powerlifting Gym at 5; the Golden Era Gym at 7'0" later.
Machines.GymUnlock = { Starter = 0, Beach = 1, Pro = 3, Powerlifting = 5, Seasonal = 0, Dumbbell = 0 }
-- The gym names players read (signs, toasts, the growth spurt card's "Next:").
Machines.GymNames = { Starter = "Starter Gym", Beach = "Beach Gym", Pro = "Pro Gym", Powerlifting = "Powerlifting Gym" }

-- Weight tiers: 12 per machine, built from the shared progression below. A tier is usable when the machine's main
-- muscle is at its unlockLevel (needed again after every Growth Spurt); nothing is bought (owner, 14 Oct).
--   gains = gains multiplier, unlockLevel = main muscle level needed (the only gate: machines and weights are FREE,
--   owner, 14 Oct; cost stays 0 so old code paths still read a number),
--   coins = coins per rep, plates = plates per side (lb), label = optional text instead of the weight (e.g. "BW").
-- Heavier always pays more per rep, so moving up is always worth it. Tuned with tests/pacing.
Machines.Progression = {
	gains = { 1, 1.3, 1.65, 2.05, 2.5, 3, 3.6, 4.3, 5.1, 6, 7, 8.2 },
	unlockLevel = { 0, 3, 7, 12, 18, 25, 33, 42, 52, 64, 78, 95 },
	cost = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, -- (free, owner 14 Oct: was 0 / 5 / 12 ... 600 coins)
	coins = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 9 },
}

-- Plates per weight: one color per weight, used the same way everywhere (bars, racks, the HUD barbell).
-- color = Theme.Bumper key ("Steel" = small metal change plate). Sizes in studs. Thin like calibrated plates, so the
-- heaviest tier fits the sleeves (tests/machines checks every tier fits Machines.SleeveRoom).
Machines.Plates = {
	[100] = { thickness = 0.28, diameter = 2.3, color = "Black" }, -- (prompt 58) the Powerlifting Gym's big bumper
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
Machines.PlateOrder = { 100, 55, 45, 35, 25, 10, 5 } -- heaviest first (inside on the sleeve, bottom of a stack)

-- (prompt 36) the Pro Gym's copies of the starter machines go on from the starter top weight: 8 more tiers, the same
-- step from one tier to the next (+15% EXP), the same rule (the main muscle's level; the first one is the starter top's)
Machines.ProProgression = {
	gains = { 8.2, 9.4, 10.8, 12.4, 14.3, 16.4, 18.9, 21.7 },
	unlockLevel = { 95, 106, 118, 130, 142, 154, 166, 178 },
	cost = { 0, 0, 0, 0, 0, 0, 0, 0 },
	coins = { 9, 10, 11, 12, 13, 14, 15, 16 },
}
-- (prompt 58) the Powerlifting Gym's lifts go on from the Pro top weight the same way: 8 more tiers, +15% EXP a tier,
-- the main muscle's level (the first one is the Pro top's)
Machines.PowerliftingProgression = {
	gains = { 21.7, 25, 28.7, 33, 38, 43.7, 50.2, 57.8 },
	unlockLevel = { 178, 190, 202, 214, 226, 238, 250, 262 },
	cost = { 0, 0, 0, 0, 0, 0, 0, 0 },
	coins = { 16, 17, 18, 19, 20, 21, 22, 23 },
}

-- rows: { weight, plates per side, label? }; the first row is the empty bar / bodyweight / lightest stack
local function tierSet(rows, firstName, progression)
	local p = progression or Machines.Progression
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
	-- Dumbbells (prompt 16): one dumbbell's weight; drawn in the hands (no plates), bigger with the weight.
	Dumbbell = tierSet({
		{ 10, {} }, { 15, {} }, { 20, {} }, { 25, {} }, { 30, {} }, { 35, {} }, { 40, {} }, { 50, {} }, { 60, {} },
		{ 70, {} }, { 85, {} }, { 100, {} },
	}),
	-- Treadmill: speeds instead of weights (weight = mph, unit shown instead of "lb").
	Treadmill = (function()
		local rows = {}
		for i = 1, 12 do rows[i] = { i + 1, {} } end
		local set = tierSet(rows, "Walk")
		for _, tier in ipairs(set) do tier.unit = "mph" end
		return set
	end)(),
	-- (prompt 36) the Pro copies of the starter machines: from the starter top weight on, about the same steps
	ProBarbell = tierSet({
		{ 315, { 55, 55, 25 } }, { 335, { 55, 55, 35 } }, { 355, { 55, 55, 45 } }, { 375, { 55, 55, 55 } }, { 395, { 55, 55, 55, 10 } },
		{ 415, { 55, 55, 55, 10, 10 } }, { 435, { 55, 55, 55, 25, 5 } }, { 455, { 55, 55, 55, 35, 5 } },
	}, nil, Machines.ProProgression),
	ProHeavyBarbell = tierSet({
		{ 455, { 55, 55, 55, 35, 5 } }, { 485, { 55, 55, 55, 55 } }, { 515, { 55, 55, 55, 55, 10, 5 } }, { 545, { 55, 55, 55, 55, 25, 5 } },
		{ 575, { 55, 55, 55, 55, 45 } }, { 605, { 55, 55, 55, 55, 55, 5 } }, { 635, { 55, 55, 55, 55, 55, 10, 10 } }, { 665, { 55, 55, 55, 55, 55, 35 } },
	}, nil, Machines.ProProgression),
	ProSled = tierSet({
		{ 455, { 55, 55, 55, 35, 5 } }, { 485, { 55, 55, 55, 55 } }, { 515, { 55, 55, 55, 55, 10, 5 } }, { 545, { 55, 55, 55, 55, 25, 5 } },
		{ 575, { 55, 55, 55, 55, 45 } }, { 605, { 55, 55, 55, 55, 55, 5 } }, { 635, { 55, 55, 55, 55, 55, 10, 10 } }, { 665, { 55, 55, 55, 55, 55, 35 } },
	}, nil, Machines.ProProgression),
	ProBodyweight = tierSet({
		{ 100, { 55, 45 }, "+100" }, { 115, { 55, 55, 5 }, "+115" }, { 130, { 55, 55, 10, 10 }, "+130" }, { 145, { 55, 55, 35 }, "+145" },
		{ 160, { 55, 55, 45, 5 }, "+160" }, { 175, { 55, 55, 55, 10 }, "+175" }, { 190, { 55, 55, 55, 25 }, "+190" }, { 205, { 55, 55, 55, 35, 5 }, "+205" },
	}, nil, Machines.ProProgression),
	ProDumbbell = tierSet({
		{ 100, {} }, { 105, {} }, { 110, {} }, { 115, {} }, { 120, {} }, { 130, {} }, { 140, {} }, { 150, {} },
	}, nil, Machines.ProProgression),
	ProTreadmill = (function()
		local rows = {}
		for i = 1, 8 do rows[i] = { 12 + i, {} } end
		local set = tierSet(rows, nil, Machines.ProProgression)
		for _, tier in ipairs(set) do tier.unit = "mph" end
		return set
	end)(),
	-- (prompt 58) the Powerlifting Gym: from the Pro top weight on, the same steps (bars 20, squat / deadlift 30, bodyweight
	-- 15, dumbbells 10), loaded with the big 100 lb bumpers
	PLBarbell = tierSet({
		{ 455, { 100, 100, 5 } }, { 475, { 100, 100, 10, 5 } }, { 495, { 100, 100, 25 } }, { 515, { 100, 100, 35 } }, { 535, { 100, 100, 45 } },
		{ 555, { 100, 100, 55 } }, { 575, { 100, 100, 55, 10 } }, { 595, { 100, 100, 55, 10, 10 } },
	}, nil, Machines.PowerliftingProgression),
	PLHeavyBarbell = tierSet({
		{ 665, { 100, 100, 100, 10 } }, { 695, { 100, 100, 100, 25 } }, { 725, { 100, 100, 100, 35, 5 } }, { 755, { 100, 100, 100, 55 } },
		{ 785, { 100, 100, 100, 55, 10, 5 } }, { 815, { 100, 100, 100, 55, 25, 5 } }, { 845, { 100, 100, 100, 100 } }, { 875, { 100, 100, 100, 100, 10, 5 } },
	}, nil, Machines.PowerliftingProgression),
	PLBodyweight = tierSet({
		{ 205, { 100, 100, 5 }, "+205" }, { 220, { 100, 100, 10, 10 }, "+220" }, { 235, { 100, 100, 35 }, "+235" }, { 250, { 100, 100, 45, 5 }, "+250" },
		{ 265, { 100, 100, 55, 10 }, "+265" }, { 280, { 100, 100, 55, 25 }, "+280" }, { 295, { 100, 100, 55, 35, 5 }, "+295" }, { 310, { 100, 100, 100, 10 }, "+310" },
	}, nil, Machines.PowerliftingProgression),
	PLDumbbell = tierSet({
		{ 150, {} }, { 160, {} }, { 170, {} }, { 180, {} }, { 190, {} }, { 200, {} }, { 210, {} }, { 220, {} },
	}, nil, Machines.PowerliftingProgression),
	-- Cable stacks and dumbbell-style moves: lighter numbers, same progression.
	Cable = tierSet({
		{ 10, {} }, { 20, { 10 } }, { 30, { 25, 5 } }, { 40, { 35, 5 } }, { 50, { 45, 5 } }, { 60, { 55, 5 } },
		{ 70, { 55, 10, 5 } }, { 80, { 55, 25 } }, { 90, { 55, 35 } }, { 100, { 55, 45 } }, { 110, { 55, 55 } },
		{ 120, { 55, 55, 10 } },
	}),
}

-- Highest tier this player can lift right now: the main muscle level is high enough (weights are free, owner 14 Oct:
-- nothing to buy; progress.unlocked only remembers the heaviest weight ever picked, for quests and stats).
function Machines.UsableTier(machine, progress, mainLevel)
	local usable = 1
	for index = 1, #machine.tiers do
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
	-- Treadmill (3 in the starter gym's cardio corner, 4 in the pro gym; all the premium model since 8 Oct night): trains STAMINA, not muscles (trains = "Stamina":
	-- no muscle EXP; the distance run raises max stamina, Config.Stamina.Cardio, and counts toward Cardio King). Running
	-- uses no stamina (it keeps refilling, so it's something to do between sets), normal coins. `muscles` only picks which
	-- level unlocks the faster speeds. load = the belt (no plates).
	{
		id = "Treadmill", name = "Treadmill", gym = "Starter", pose = "Run", load = "Belt", layout = "Center", trains = "Stamina",
		muscles = { { id = "Quads", share = 1 } },
		tiers = Machines.TierSets.Treadmill, staminaCost = 0,
	},
}

-- Cardio: the in-game distance per treadmill rep is the speed (mph) x MetersPerMph; Cardio King needs KingMeters in total.
Machines.Cardio = { MetersPerMph = 2, KingMeters = 10000, BeltScroll = 1.2 } -- BeltScroll: belt texture studs/s per mph

-- Client performance: other lifters (players and NPC regulars) are only animated (arms, moving bar and plates) within
-- AnimateDistance studs of the camera, and the pump swell only shows within PumpDistance. Your own lift always animates.
Machines.ClientCull = { AnimateDistance = 80, PumpDistance = 30 }

-- Pro gym (opens at Growth Spurt 3 since prompt 58, 23 Oct). Built from code by ProGymService; every one carries its plates on a
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
	-- (prompt 32, 21 Oct: the starter gym's copies of these from prompt 16 are gone again, so they open with the pro gym)
	table.insert(Machines.List, machine)
end

-- Dumbbells (prompt 16, 21 Oct): every gym's dumbbell rack has "Train" spots (small machine models with Dumbbell = true,
-- tools/builders/DumbbellSpots); a tap opens the exercise picker and the spot becomes that exercise (its MachineId), so
-- reps, stamina, EXP, weight tiers and the machine HUD work exactly like a machine. dumbbell = true; about 85% of the
-- matching machine's EXP (gainScale). Poses DB_* (Config/Poses, MachineClient's moves); MachineService welds the
-- dumbbells to the hands (hands = 1: one dumbbell in the right hand; grip = the hand's axis the handle lies along, "X" or
-- "Z", measured on the poses so the handle runs the right way: across for curls and presses, front-back for neutral grips,
-- upright for the overhead extension).
Machines.DumbbellGain = 0.85
local DUMBBELLS = {
	{ id = "DBCurl", name = "Bicep Curl", pose = "DB_Curl", grip = "X", muscles = { { id = "Biceps", share = 1 }, { id = "Forearms", share = 0.4 } } },
	{ id = "DBHammerCurl", name = "Hammer Curl", pose = "DB_HammerCurl", grip = "Z", muscles = { { id = "Forearms", share = 1 }, { id = "Biceps", share = 0.6 } } },
	{ id = "DBShoulderPress", name = "Shoulder Press", pose = "DB_ShoulderPress", grip = "Z",
		muscles = { { id = "FrontDelts", share = 1 }, { id = "SideDelts", share = 0.5 }, { id = "Triceps", share = 0.4 } } },
	{ id = "DBLateralRaise", name = "Lateral Raise", pose = "DB_LateralRaise", grip = "X", muscles = { { id = "SideDelts", share = 1 } } },
	{ id = "DBRearDeltFly", name = "Rear Delt Fly", pose = "DB_RearDeltFly", grip = "X", muscles = { { id = "RearDelts", share = 1 }, { id = "Rhomboids", share = 0.5 } } },
	{ id = "DBTricepExtension", name = "Overhead Tricep Extension", pose = "DB_TricepExtension", grip = "Z", hands = 1, muscles = { { id = "Triceps", share = 1 } } },
	{ id = "DBShrugs", name = "Dumbbell Shrugs", pose = "DB_Shrug", grip = "Z", muscles = { { id = "Traps", share = 1 }, { id = "Forearms", share = 0.4 } } },
	{ id = "DBRow", name = "One-Arm Row", pose = "DB_Row", grip = "Z", hands = 1, muscles = { { id = "Lats", share = 1 }, { id = "Rhomboids", share = 0.5 }, { id = "Biceps", share = 0.3 } } },
	{ id = "DBGobletSquat", name = "Goblet Squat", pose = "DB_GobletSquat", grip = "X", hands = 1, muscles = { { id = "Quads", share = 1 }, { id = "Glutes", share = 0.5 } } },
	{ id = "DBLunges", name = "Lunges", pose = "DB_Lunge", grip = "Z", muscles = { { id = "Glutes", share = 1 }, { id = "Quads", share = 0.6 }, { id = "Hamstrings", share = 0.4 } } },
	{ id = "DBCalfRaise", name = "Standing Calf Raise", pose = "DB_CalfRaise", grip = "Z", muscles = { { id = "Calves", share = 1 } } },
}
Machines.Dumbbells = {}
for _, exercise in ipairs(DUMBBELLS) do
	exercise.gym = "Dumbbell"
	exercise.dumbbell = true
	exercise.layout = "Center"
	exercise.tiers = Machines.TierSets.Dumbbell
	exercise.staminaCost = 4
	exercise.gainScale = Machines.DumbbellGain
	exercise.openAt = 0
	table.insert(Machines.List, exercise)
	table.insert(Machines.Dumbbells, exercise)
end

-- (prompt 36, owner 21 Oct) The Pro Gym's own copy of every starter machine and a Pro dumbbell rack: the same exercise,
-- pose and muscles, a Pro look (chrome, black, gold: built in Studio from the starter models), heavier tiers that start
-- at the starter top weight (Machines.ProProgression). id = "Pro" .. the starter id, base = the starter id (quests, gear
-- perks, rivals and spotting treat it as that machine). Below the first tier's level the machine stays locked (it says
-- which level it needs; MachineService). The starter machines are unchanged.
local PRO_TIERS = { Barbell = "ProBarbell", HeavyBarbell = "ProHeavyBarbell", Sled = "ProSled", Bodyweight = "ProBodyweight",
	Treadmill = "ProTreadmill", Dumbbell = "ProDumbbell" }
local function proCopy(machine)
	local setName = nil
	for name, set in pairs(Machines.TierSets) do
		if set == machine.tiers then setName = name end
	end
	local copy = table.clone(machine)
	copy.id = "Pro" .. machine.id
	copy.name = "Pro " .. machine.name
	copy.base = machine.id
	copy.tiers = Machines.TierSets[PRO_TIERS[setName or ""] or ""] or machine.tiers
	return copy
end
local STARTER_IDS = { "FlatBench", "InclineBench", "SquatRack", "Deadlift", "OverheadPress", "PullUpBar", "BarbellRow", "CrunchBench", "LegPress",
	"HackSquat", "Treadmill" }
Machines.ProCopies = {}
for _, id in ipairs(STARTER_IDS) do
	for _, machine in ipairs(Machines.List) do
		if machine.id == id then
			local copy = proCopy(machine)
			copy.gym = "Pro"
			table.insert(Machines.ProCopies, copy)
		end
	end
end
for _, copy in ipairs(Machines.ProCopies) do table.insert(Machines.List, copy) end
-- the Pro dumbbell rack's exercises (its spots carry the attribute DumbbellSet = "Pro"; MachineService / MachineClient)
Machines.ProDumbbells = {}
for _, exercise in ipairs(Machines.Dumbbells) do
	local copy = proCopy(exercise)
	copy.name = exercise.name -- (the picker's title says PRO DUMBBELLS)
	copy.gym, copy.openAt = "Pro", Machines.GymUnlock.Pro -- (the rack stands in the Pro Gym: its +10%, open with it)
	copy.dumbbellSet = "Pro"
	table.insert(Machines.ProDumbbells, copy)
	table.insert(Machines.List, copy)
end

-- (prompt 58, owner 23 Oct) The Powerlifting Gym (opens at Growth Spurt 5): competition versions of the big three and a
-- few accessories so every group trains there, heavier again (Machines.PowerliftingProgression, from the Pro top weight).
-- base = the starter id (quests, gear perks, rivals and spotting count it as that lift); lift = the record board's lift
-- (Config/Powerlifting). Locked below the first weight's level like the Pro copies (MachineService).
local PL_COPIES = {
	{ id = "PLSquat", from = "SquatRack", name = "Comp Squat", tiers = "PLHeavyBarbell", lift = "Squat" },
	{ id = "PLMonolift", from = "SquatRack", name = "Monolift Squat", tiers = "PLHeavyBarbell", lift = "Squat" },
	{ id = "PLBench", from = "FlatBench", name = "Comp Bench", tiers = "PLBarbell", lift = "Bench" },
	{ id = "PLDeadlift", from = "Deadlift", name = "Comp Deadlift", tiers = "PLHeavyBarbell", lift = "Deadlift" },
	{ id = "PLBlockPull", from = "Deadlift", name = "Block Pull", tiers = "PLHeavyBarbell" },
	{ id = "PLPress", from = "OverheadPress", name = "Strict Press", tiers = "PLBarbell" },
	{ id = "PLRow", from = "BarbellRow", name = "Pendlay Row", tiers = "PLBarbell" },
	{ id = "PLPullUp", from = "PullUpBar", name = "Weighted Pull-Up", tiers = "PLBodyweight" },
	{ id = "PLCrunch", from = "CrunchBench", name = "Weighted Crunch", tiers = "PLBodyweight" },
}
Machines.PowerliftingCopies = {}
for _, def in ipairs(PL_COPIES) do
	for _, machine in ipairs(Machines.List) do
		if machine.id == def.from then
			local copy = table.clone(machine)
			copy.id, copy.name, copy.base, copy.lift = def.id, def.name, machine.id, def.lift
			copy.tiers = Machines.TierSets[def.tiers]
			copy.gym = "Powerlifting"
			table.insert(Machines.PowerliftingCopies, copy)
		end
	end
end
for _, copy in ipairs(Machines.PowerliftingCopies) do table.insert(Machines.List, copy) end
-- its dumbbell rack (spots with DumbbellSet = "Powerlifting"): 150 to 220 lb
Machines.PowerliftingDumbbells = {}
for _, exercise in ipairs(Machines.Dumbbells) do
	local copy = table.clone(exercise)
	copy.id, copy.base = "PL" .. exercise.id, exercise.id
	copy.tiers = Machines.TierSets.PLDumbbell
	copy.gym, copy.openAt, copy.dumbbellSet = "Powerlifting", Machines.GymUnlock.Powerlifting, "Powerlifting"
	table.insert(Machines.PowerliftingDumbbells, copy)
	table.insert(Machines.List, copy)
end
-- the exercises a dumbbell rack offers, by its spots' DumbbellSet attribute (none = the normal ones)
Machines.DumbbellSets = { Pro = Machines.ProDumbbells, Powerlifting = Machines.PowerliftingDumbbells }
function Machines.DumbbellSetList(set: any)
	return if type(set) == "string" and Machines.DumbbellSets[set] then Machines.DumbbellSets[set] else Machines.Dumbbells
end

-- (prompt 36) a small gains bonus for training in a newer gym (gameplay plan: +10% per gym), on that gym's machines
-- (prompt 58: the Powerlifting Gym is the next step. The beach gym has no machines of its own: copies of the starter
-- ones, so no bonus there)
Machines.GymGains = { Pro = 1.1, Powerlifting = 1.2 }

-- Beach gym (town hub, opens at Growth Spurt 1): no machines of its own (owner, 8 Oct night): it has copies of the REAL
-- machines (same models, configs, tiers, EXP; the same MachineId, so unlocked weights, "NEW" tags and quests are shared
-- with every gym). A copy carries the model attribute Gym = "Beach": it opens with the beach gym but never later than its
-- own gym would (Machines.GymOpenAt). The old beach-only machines' saved progress moves to the real ones (PlayerData).
Machines.Renamed = { BeachCurl = "BicepCurl", BeachRaise = "LateralRaise", BeachShrug = "Shrugs" }

-- Seasonal: only built while Winter Lifts runs (SeasonService). Trains muscles the starter gym already trains,
-- so it never changes what counts toward a Growth Spurt.
table.insert(Machines.List, {
	id = "SledPull", name = "Sled Pull", gym = "Seasonal", pose = "SledPush", layout = "Center", staminaCost = 6,
	tiers = Machines.TierSets.HeavyBarbell,
	muscles = { { id = "Quads", share = 1 }, { id = "Glutes", share = 0.5 }, { id = "Hamstrings", share = 0.4 } },
})

-- Spotting (Config.Spotting): spotType "hands" = spotters at the bar with their hands under it (the barbell lifts),
-- "hype" = a cheering half-circle (everything else); cardio can't be spotted.
local HANDS_SPOT = { FlatBench = true, InclineBench = true, SquatRack = true, OverheadPress = true }
for _, machine in ipairs(Machines.List) do
	if machine.spotType == nil and machine.trains ~= "Stamina" then
		machine.spotType = if HANDS_SPOT[machine.base or machine.id] then "hands" else "hype"
	end
end

Machines.ById = {}
for _, machine in ipairs(Machines.List) do
	Machines.ById[machine.id] = machine
end

-- (Machines.GymUnlock: at the top) The Growth Spurt count a player's GYMS open with: their Growth Spurts, or more when a gym
-- stays open for them from before a ladder change (prompt 58: data.gymAccess.Pro for players who had been in the Pro
-- Gym when it opened at Growth Spurt 2). Use it for every gym / machine gate (not for the spurt goal).
function Machines.GymLevel(data): number
	local level = type(data) == "table" and tonumber(data.growthSpurts) or 0
	local access = type(data) == "table" and data.gymAccess
	if type(access) == "table" then
		for gym, on in pairs(access) do
			if on == true and Machines.GymUnlock[gym] then level = math.max(level, Machines.GymUnlock[gym]) end
		end
	end
	return level
end

-- The next gym that opens after this many Growth Spurts: its key, its name and the spurt (nil when none is left).
function Machines.NextGym(spurts: number): (string?, string?, number?)
	local best, bestAt = nil, math.huge
	for gym, at in pairs(Machines.GymUnlock) do
		if Machines.GymNames[gym] and at > spurts and at < bestAt then best, bestAt = gym, at end
	end
	if not best then return nil, nil, nil end
	return best, Machines.GymNames[best], bestAt
end

-- The Growth Spurts an exercise is open at anywhere (a copy in an earlier gym counts: openAt).
function Machines.OpenAt(machine): number
	return machine.openAt or Machines.GymUnlock[machine.gym] or 0
end

-- The Growth Spurt count a machine MODEL opens at: its config's gym, or the gym it stands in (the model attribute "Gym",
-- e.g. a real Bicep Curl in the beach gym opens with the beach gym) when that opens earlier.
function Machines.GymOpenAt(machine, model: Instance?): (number, string)
	local gym = machine.gym
	local need = Machines.GymUnlock[gym] or 0
	local placed = model and model:GetAttribute("Gym")
	if machine.dumbbell then return 0, "Dumbbell" end -- (every gym's rack: open from the start)
	if type(placed) == "string" and Machines.GymUnlock[placed] and Machines.GymUnlock[placed] < need then
		return Machines.GymUnlock[placed], placed
	end
	return need, gym
end

-- Set of muscle ids that some open machine trains (main or a real secondary: a light touch, below GoalShare, like the
-- hack squat's calves, still gains a little but doesn't put that muscle into the Growth Spurt goal).
-- A machine's muscle split as whole percents that add up to 100 (the main muscle takes the rounding): the machine HUD
-- shows it after you sit down (owner, 8 Oct).
function Machines.SharePercents(machine): { { id: string, pct: number } }
	local total = 0
	for _, entry in ipairs(machine.muscles) do total += entry.share or 1 end
	local out, sum = {}, 0
	for _, entry in ipairs(machine.muscles) do
		local pct = math.floor((entry.share or 1) / total * 100 + 0.5)
		table.insert(out, { id = entry.id, pct = pct })
		sum += pct
	end
	if out[1] then out[1].pct += 100 - sum end
	return out
end

Machines.GoalShare = 0.2
function Machines.TrainableMuscles(growthSpurts)
	local set = {}
	for _, machine in ipairs(Machines.List) do
		if growthSpurts >= Machines.OpenAt(machine) and machine.trains ~= "Stamina" then
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
		local open = growthSpurts >= Machines.OpenAt(machine) and machine.gym ~= "Seasonal"
		if open and machine.trains ~= "Stamina" and not machine.base and muscleGroup(machine.muscles[1].id) == groupId and not seen[machine.name] then
			seen[machine.name] = true
			table.insert(names, machine.name)
		end
	end
	return names
end

return Machines
