-- Genetics rolled on first join. Odds here are what the reroll screen shows.
local Muscles = require(script.Parent.Muscles)

local Genetics = {}

Genetics.Grades = {
	{ id = "D", mult = 0.75, weight = 15 },
	{ id = "C", mult = 0.9, weight = 25 },
	{ id = "B", mult = 1.0, weight = 30 },
	{ id = "A", mult = 1.2, weight = 20 },
	{ id = "S", mult = 1.5, weight = 10 },
}

-- bonus.all applies to every muscle; groups/muscles are per-target. A muscle
-- matched by both its group and its own id only gets the larger bonus once.
-- shoulders = the starting shoulder width (permanent; BodyService widens the UpperTorso and moves the arms out, the
-- muscle meshes taper it back to the normal waist so the frame reads as a V).
Genetics.Frames = {
	{ id = "Narrow", name = "Narrow", weight = 25, shoulders = 0.9, bonus = { groups = { Arms = 0.10 } } },
	{ id = "Average", name = "Average", weight = 35, shoulders = 1.0, bonus = { all = 0.05 } },
	{ id = "Wide", name = "Wide", weight = 25, shoulders = 1.1, bonus = { groups = { Back = 0.10, Legs = 0.10 } } },
	{ id = "VTaper", name = "V-Taper", weight = 15, shoulders = 1.2, bonus = { groups = { Shoulders = 0.10 }, muscles = { Lats = 0.10 } } },
}

-- detailLevelMult scales the level at which abs/detail start showing (lower = earlier).
Genetics.BodyTypes = {
	{ id = "Lean", name = "Lean", weight = 33, bonus = {}, detailLevelMult = 0.8 },
	{ id = "Balanced", name = "Balanced", weight = 34, bonus = { all = 0.05 }, detailLevelMult = 1 },
	{ id = "Stocky", name = "Stocky", weight = 33, bonus = { groups = { Legs = 0.15, Back = 0.15 }, muscles = { Traps = 0.15 } }, detailLevelMult = 1.25 },
}

local function index(list)
	local byId = {}
	for _, entry in ipairs(list) do byId[entry.id] = entry end
	return byId
end
Genetics.GradeById = index(Genetics.Grades)
Genetics.FrameById = index(Genetics.Frames)

-- The shoulder width factor of a frame id (1 for anything unknown).
function Genetics.ShoulderWidth(frameId: string?): number
	local frame = frameId and Genetics.FrameById[frameId]
	return frame and frame.shoulders or 1
end
Genetics.BodyTypeById = index(Genetics.BodyTypes)

local function pick(list, rng)
	local total = 0
	for _, entry in ipairs(list) do total += entry.weight end
	local roll = rng:NextNumber() * total
	for _, entry in ipairs(list) do
		roll -= entry.weight
		if roll < 0 then return entry end
	end
	return list[#list]
end

-- Overall grade = the grade whose multiplier is closest to the average group multiplier.
function Genetics.GetOverallGrade(grades)
	local sum, count = 0, 0
	for _, gradeId in pairs(grades) do
		sum += Genetics.GradeById[gradeId].mult
		count += 1
	end
	local avg = sum / count
	local best, bestDiff = Genetics.Grades[1], math.huge
	for _, grade in ipairs(Genetics.Grades) do
		local diff = math.abs(grade.mult - avg)
		if diff < bestDiff then best, bestDiff = grade, diff end
	end
	return best.id
end

-- Rolls everything at once (first join and rerolls).
function Genetics.Roll(rng)
	rng = rng or Random.new()
	local grades = {}
	for _, group in ipairs(Muscles.Groups) do
		grades[group.id] = pick(Genetics.Grades, rng).id
	end
	return {
		grades = grades,
		frame = pick(Genetics.Frames, rng).id,
		bodyType = pick(Genetics.BodyTypes, rng).id,
		overall = Genetics.GetOverallGrade(grades),
	}
end

local function bonusFor(bonus, muscle)
	local specific = math.max(bonus.groups and bonus.groups[muscle.group] or 0, bonus.muscles and bonus.muscles[muscle.id] or 0)
	return (bonus.all or 0) + specific
end

-- Gains multiplier from genetics for one muscle: grade x frame x body type.
function Genetics.GetMultiplier(genetics, muscleId)
	local muscle = Muscles.ById[muscleId]
	local grade = Genetics.GradeById[genetics.grades[muscle.group]]
	local frame = Genetics.FrameById[genetics.frame]
	local body = Genetics.BodyTypeById[genetics.bodyType]
	return grade.mult * (1 + bonusFor(frame.bonus, muscle)) * (1 + bonusFor(body.bonus, muscle))
end

return Genetics
