-- Growth Spurt n: reach `requiredLevel` in all 6 groups to do it; you become `height`
-- inches tall with a permanent `bonus`. Your muscle level cap is the next spurt's requiredLevel.
local Muscles = require(script.Parent.Muscles)

local GrowthSpurts = {}

GrowthSpurts.StartHeight = 48 -- 4'0"
GrowthSpurts.MaxHeight = 84   -- 7'0"

-- requiredLevel is tuned with tests/pacing to GrowthSpurts.Targets below (the permanent bonus makes later stages much
-- faster per level, so the goals climb slowly).
GrowthSpurts.Stages = {
	{ height = 54, requiredLevel = 15, bonus = 1.25 },
	{ height = 60, requiredLevel = 47, bonus = 1.5 },
	{ height = 66, requiredLevel = 72, bonus = 1.75 },
	{ height = 72, requiredLevel = 103, bonus = 2 },
	{ height = 78, requiredLevel = 135, bonus = 2.5 },
	{ height = 84, requiredLevel = 157, bonus = 3 },
}

-- Beyond the table: keep growing until MaxHeight, and keep adding level + bonus. (From here the bonus mostly runs
-- into Gains.MaxMultiplier, so each extra spurt is a few minutes longer than the last; see tests/pacing.)
GrowthSpurts.ExtraPerStage = { height = 6, requiredLevel = 18, bonus = 0.5 }

-- How long each Growth Spurt should take a typical player, in minutes of play: 1st, 2nd, 3rd, 4th, then every later
-- one ("normal play with some tapping": half the sets tapped, see tests/pacing).
-- The requiredLevel values above are tuned to these with tests/pacing, which plays simulated players through the
-- spurts with the real gains formula. If gains, tiers, stamina or bonuses change, rerun it and retune the levels.
GrowthSpurts.Targets = { 8, 15, 25, 35, 45 }

function GrowthSpurts.TargetMinutes(n)
	local targets = GrowthSpurts.Targets
	return targets[math.min(n, #targets)]
end

function GrowthSpurts.Get(n)
	local stages = GrowthSpurts.Stages
	if n <= #stages then return stages[n] end
	local last, extra, steps = stages[#stages], GrowthSpurts.ExtraPerStage, n - #stages
	return {
		height = math.min(GrowthSpurts.MaxHeight, last.height + extra.height * steps),
		requiredLevel = last.requiredLevel + extra.requiredLevel * steps,
		bonus = last.bonus + extra.bonus * steps,
	}
end

function GrowthSpurts.GetHeight(spurts)
	return spurts == 0 and GrowthSpurts.StartHeight or GrowthSpurts.Get(spurts).height
end

function GrowthSpurts.GetBonus(spurts)
	return spurts == 0 and 1 or GrowthSpurts.Get(spurts).bonus
end

-- NO CAP: a muscle keeps growing as long as you train it (the diminishing factor in Gains.PerRep slows it down), so a strong
-- muscle helps its group's average. GetLevelCap stays so every caller keeps working; it is simply infinite.
function GrowthSpurts.GetLevelCap(_spurts)
	return math.huge
end

-- A mark for the "Defied Genetics" title only (not a limit): 130% of the next goal.
GrowthSpurts.MasteryOverGoal = 1.3
function GrowthSpurts.GetMasteryLevel(spurts)
	return math.ceil(GrowthSpurts.Get(spurts + 1).requiredLevel * GrowthSpurts.MasteryOverGoal)
end

-- The level every group needs for the next Growth Spurt.
function GrowthSpurts.GetGoal(spurts)
	return GrowthSpurts.Get(spurts + 1).requiredLevel
end

-- A group's level for the spurt goal: the average EXP of its muscles you can train right now (so a group never waits on a
-- muscle no open machine trains), expressed as a (fractional) level. A group meets the goal exactly when its average EXP
-- reaches the goal EXP shown on screen (50,000 for the first spurt).
function GrowthSpurts.GoalLevel(muscleData, group, trainable)
	local total, count = 0, 0
	for _, muscle in ipairs(group.muscles) do
		if trainable[muscle.id] then
			total += Muscles.EntryXp(muscleData[muscle.id])
			count += 1
		end
	end
	return count > 0 and Muscles.LevelFromXp(total / count) or 0
end

-- Progress toward the next Growth Spurt: { required, met, total, ready, groups = { [groupId] = goalLevel } }
function GrowthSpurts.Progress(data, groups, trainable)
	local required = GrowthSpurts.Get(data.growthSpurts + 1).requiredLevel
	local result = { required = required, met = 0, total = #groups, groups = {} }
	for _, group in ipairs(groups) do
		local level = GrowthSpurts.GoalLevel(data.muscles, group, trainable)
		result.groups[group.id] = level
		if level >= required then result.met += 1 end
	end
	result.ready = result.met == result.total
	return result
end

function GrowthSpurts.FormatHeight(inches)
	return string.format("%d'%d\"", inches // 12, inches % 12)
end

return GrowthSpurts
