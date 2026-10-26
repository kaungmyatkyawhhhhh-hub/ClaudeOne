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
	-- (26 Oct, retention: Targets 5/15/25/35/45 -> 5/10/18/28/38, retuned with tests/pacing tune: 52/92/132/191/238 ->
	-- 35/68/113/163/197; the old 1 -> 2 jump was 3x longer and the middle spurts took 3-4 sessions each)
	{ height = 60, requiredLevel = 35, bonus = 1.5 }, -- (prompt 20: 58 -> 56; prompt 16: 52; 26 Oct: 35, 9.8 min)
	{ height = 66, requiredLevel = 68, bonus = 1.75 }, -- (26 Oct: 92 -> 68, 17.8 min)
	{ height = 72, requiredLevel = 113, bonus = 2 }, -- (26 Oct: 132 -> 113, 27.8 min)
	{ height = 78, requiredLevel = 163, bonus = 2.5 }, -- (prompt 36, 22 Oct: 164 -> 191; 26 Oct: 163, 37.9 min)
	{ height = 84, requiredLevel = 197, bonus = 3 }, -- (prompt 58: 216 -> 238; 26 Oct: 197, 37.7 min)
}

-- Beyond the table: keep growing until MaxHeight, and keep adding level + bonus. (From here the bonus mostly runs
-- into Gains.MaxMultiplier, so each extra spurt is a few minutes longer than the last; see tests/pacing.)
GrowthSpurts.ExtraPerStage = { height = 6, requiredLevel = 18, bonus = 0.5 }

-- How long each Growth Spurt should take a typical player, in minutes of play: 1st, 2nd, 3rd, 4th, then every later
-- one ("normal play with some tapping": half the sets tapped, see tests/pacing).
-- The requiredLevel values above are tuned to these with tests/pacing, which plays simulated players through the
-- spurts with the real gains formula. If gains, tiers, stamina or bonuses change, rerun it and retune the levels.
GrowthSpurts.Targets = { 5, 10, 18, 28, 38 } -- (26 Oct: was 5, 15, 25, 35, 45)

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

-- (owner, 24 Oct) past 7'0": every finished Body Alter tier (5 alters) adds AlterTierInches (Tier 1 done = 7'4").
GrowthSpurts.AlterTierInches = 4
GrowthSpurts.AltersPerTier = 5
-- (owner, 26 Oct: "7'0 is not max") the tallest anyone can get: 7'0" + every alter tier (Config/Alters: 6 tiers of 5 =
-- 30 alters) = 9'0". Only this height says MAX (top bar, menu card, stats); 7'0" is only the last Growth Spurt.
GrowthSpurts.AlterTiers = 6
GrowthSpurts.TopHeightInches = GrowthSpurts.MaxHeightInches + GrowthSpurts.AlterTierInches * GrowthSpurts.AlterTiers

-- A player's real height: the Growth Spurt height, plus the alter tiers once at 7'0" (data.alter.highest, Config/Alters).
function GrowthSpurts.PlayerHeight(data)
	local spurts = type(data) == "table" and data.growthSpurts or 0
	local height = GrowthSpurts.GetHeight(spurts or 0)
	if height < GrowthSpurts.MaxHeightInches then return height end
	local alter = type(data) == "table" and data.alter
	local highest = type(alter) == "table" and tonumber(alter.highest) or 0
	return height + GrowthSpurts.AlterTierInches * (highest // GrowthSpurts.AltersPerTier)
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

-- (prompt 24) The equipped trainers' progress boost (data.trainers.bonus.progress, TrainerService): the goal's EXP counts that much
-- more, so the level a goal asks for drops a little (+10% progress: 10% less EXP to reach it).
function GrowthSpurts.ProgressBoost(data): number
	local t = type(data) == "table" and data.trainers
	local trainers = math.max(0, type(t) == "table" and type(t.bonus) == "table" and tonumber(t.bonus.progress) or 0)
	-- (prompt 45) + the equipped aura's progress perk (Blood Moon, Galaxy, Void)
	local auras = type(data) == "table" and data.auras
	local worn = type(auras) == "table" and auras.equipped or nil
	return trainers + require(script.Parent.Auras).Perk(worn, "progress")
end
function GrowthSpurts.BoostedLevel(level: number, boost: number): number
	if boost <= 0 then return level end
	return Muscles.LevelFromXp(Muscles.CumXp(level) / (1 + boost))
end

-- Progress toward the next Growth Spurt: { required, met, total, ready, groups = { [groupId] = goalLevel } }
function GrowthSpurts.Progress(data, groups, trainable)
	local required = GrowthSpurts.BoostedLevel(GrowthSpurts.Get(data.growthSpurts + 1).requiredLevel, GrowthSpurts.ProgressBoost(data))
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

-- (prompt 11, 21 Oct) Small rewards on the way to each Growth Spurt: at these shares of the goal bar a popup, a sound and
-- a few coins (MilestoneCoinMinutes minutes of coins at your stage, Config.PumpShop.Rate), so players see progress.
-- Server/SpurtMilestoneService; the first spurt's milestones are the funnel steps 13a / 13b / 13c (Server/Analytics).
-- (prompt 58, owner 23 Oct: not a new gym every spurt) What each Growth Spurt opens, shown under the "Growth Spurt!"
-- moment (StatsClient) so a spurt without a new gym still feels big. Short, in caps, joined with " · ".
GrowthSpurts.Unlocks = {
	[1] = { "TRAINERS", "BEACH GYM", "POSES", "CREWS", "LOCAL SHOW" }, -- (26 Oct: trainers from Spurt 1)
	[2] = { "2ND TRAINER SLOT", "GEAR", "ARM WRESTLING", "REGIONAL SHOW" },
	[3] = { "PRO GYM", "AURAS", "PUMP SHOP" },
	[4] = { "NATIONAL SHOW" },
	[5] = { "POWERLIFTING GYM", "PRO CARD QUALIFIER" },
	[6] = { "UNIVERSE CHAMPIONSHIP", "BODY ALTERS" },
}
function GrowthSpurts.UnlockText(spurts: number): string?
	local list = GrowthSpurts.Unlocks[spurts]
	return if list then table.concat(list, "  ·  ") else nil
end

GrowthSpurts.Milestones = { 25, 50, 75 }
GrowthSpurts.MilestoneCoinMinutes = 2 -- (26 Oct: 0.5 -> 2, half a minute of coins felt like nothing; the marks stay 25/50/75, the funnel steps use them)

-- The goal bar's share (0..1), exactly as the HUD shows it (ProgressClient): the shown levels of every group, each
-- capped at the goal, against the goal in every group.
function GrowthSpurts.Share(progress, groups): number
	local have, need = 0, 0
	for _, group in ipairs(groups) do
		local level = progress.groups[group.id] or 0
		have += Muscles.Shown(math.min(level, progress.required))
		need += Muscles.Shown(progress.required)
	end
	return if need > 0 then math.clamp(have / need, 0, 1) else 0
end

-- "5'6\""; a player at the cap reads "7'0\" (MAX)". `plain` skips the MAX tag (NPCs like Dante, who are no player).
function GrowthSpurts.FormatHeight(inches, plain)
	local text = string.format("%d'%d\"", inches // 12, inches % 12)
	if not plain and inches >= GrowthSpurts.TopHeightInches then text ..= " (MAX)" end
	return text
end

return GrowthSpurts
