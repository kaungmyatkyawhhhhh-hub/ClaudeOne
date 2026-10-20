-- Growth Spurt n: reach `requiredLevel` in all 6 groups to do it; you become `height`
-- inches tall with a permanent `bonus`. Your muscle level cap is the next spurt's requiredLevel.
local Muscles = require(script.Parent.Muscles)

local GrowthSpurts = {}

GrowthSpurts.StartHeight = 48 -- 4'0"
-- Height cap (owner, 13 Oct): no spurt ever goes past 7'0" (clamped to exactly 7'0"), and once you're there there are no
-- more Growth Spurts (height and body scale stop; muscles keep growing). Same inches as the height shown on screen.
GrowthSpurts.MaxHeightInches = 84 -- 7'0"
GrowthSpurts.MaxHeight = GrowthSpurts.MaxHeightInches -- (older name, kept for callers)

-- requiredLevel is tuned with tests/pacing to GrowthSpurts.Targets below (the permanent bonus makes later stages much
-- faster per level, so the goals climb slowly). Re-tuned 14 Oct when weights became free (heavier weights sooner):
-- 47 / 72 / 103 / 135 / 157 -> 58 / 92 / 132 / 164 / 178.
GrowthSpurts.Stages = {
	{ height = 54, requiredLevel = 9, bonus = 1.25 }, -- (prompt 20, 21 Oct: 15 -> 9, first Growth Spurt in ~5 min)
	{ height = 60, requiredLevel = 52, bonus = 1.5 }, -- (prompt 20: 58 -> 56; prompt 16: 52, every machine opens from the start so the goal has more muscles)
	{ height = 66, requiredLevel = 92, bonus = 1.75 },
	{ height = 72, requiredLevel = 132, bonus = 2 },
	{ height = 78, requiredLevel = 164, bonus = 2.5 },
	{ height = 84, requiredLevel = 178, bonus = 3 },
}

-- Beyond the table: keep growing until MaxHeight, and keep adding level + bonus. (From here the bonus mostly runs
-- into Gains.MaxMultiplier, so each extra spurt is a few minutes longer than the last; see tests/pacing.)
GrowthSpurts.ExtraPerStage = { height = 6, requiredLevel = 18, bonus = 0.5 }

-- How long each Growth Spurt should take a typical player, in minutes of play: 1st, 2nd, 3rd, 4th, then every later
-- one ("normal play with some tapping": half the sets tapped, see tests/pacing).
-- The requiredLevel values above are tuned to these with tests/pacing, which plays simulated players through the
-- spurts with the real gains formula. If gains, tiers, stamina or bonuses change, rerun it and retune the levels.
GrowthSpurts.Targets = { 5, 15, 25, 35, 45 }

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
	local height = spurts == 0 and GrowthSpurts.StartHeight or GrowthSpurts.Get(spurts).height
	return math.min(height, GrowthSpurts.MaxHeightInches)
end

-- The spurt that reaches 7'0" (the last one anybody can do).
function GrowthSpurts.MaxSpurts()
	local n = 0
	while GrowthSpurts.GetHeight(n) < GrowthSpurts.MaxHeightInches do n += 1 end
	return n
end

-- At 7'0": no more Growth Spurts.
function GrowthSpurts.IsMaxed(spurts)
	return GrowthSpurts.GetHeight(spurts or 0) >= GrowthSpurts.MaxHeightInches
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
-- reaches the goal EXP shown on screen (about 24,700 for the first spurt).
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
	result.maxed = GrowthSpurts.IsMaxed(data.growthSpurts)
	result.ready = result.met == result.total and not result.maxed
	return result
end

-- "5'6\""; a player at the cap reads "7'0\" (MAX)". `plain` skips the MAX tag (NPCs like Dante, who are no player).
function GrowthSpurts.FormatHeight(inches, plain)
	local text = string.format("%d'%d\"", inches // 12, inches % 12)
	if not plain and inches >= GrowthSpurts.MaxHeightInches then text ..= " (MAX)" end
	return text
end

return GrowthSpurts
