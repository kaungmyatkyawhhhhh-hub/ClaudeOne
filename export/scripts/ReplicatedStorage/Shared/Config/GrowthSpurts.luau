-- Growth Spurt n: reach `requiredLevel` in all 6 groups to do it; you become `height`
-- inches tall with a permanent `bonus`. Your muscle level cap is the next spurt's requiredLevel.
local GrowthSpurts = {}

GrowthSpurts.StartHeight = 48 -- 4'0"
GrowthSpurts.MaxHeight = 84   -- 7'0"

GrowthSpurts.Stages = {
	{ height = 54, requiredLevel = 50, bonus = 1.25 },
	{ height = 60, requiredLevel = 100, bonus = 1.5 },
	{ height = 66, requiredLevel = 175, bonus = 1.75 },
	{ height = 72, requiredLevel = 275, bonus = 2 },
	{ height = 78, requiredLevel = 400, bonus = 2.5 },
}

-- Beyond the table: keep growing until MaxHeight, and keep adding level + bonus.
GrowthSpurts.ExtraPerStage = { height = 6, requiredLevel = 150, bonus = 0.5 }

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

function GrowthSpurts.GetLevelCap(spurts)
	return GrowthSpurts.Get(spurts + 1).requiredLevel
end

-- A group's level for the spurt goal: the average of its muscles you can train right now
-- (so a group never waits on a muscle no open machine trains).
function GrowthSpurts.GoalLevel(muscleData, group, trainable)
	local total, count = 0, 0
	for _, muscle in ipairs(group.muscles) do
		if trainable[muscle.id] then
			total += muscleData[muscle.id].level
			count += 1
		end
	end
	return count > 0 and total / count or 0
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
