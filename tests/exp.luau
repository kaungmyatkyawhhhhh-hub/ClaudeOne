local H = require("./harness")
local M = H.module("ReplicatedStorage/Shared/Config/Muscles")
local G = H.module("ReplicatedStorage/Shared/Config/GrowthSpurts")

print("EXP shown on screen")
H.check(M.FirstSpurtLevel == G.Get(1).requiredLevel, "the EXP scale is tied to the first Growth Spurt's level goal")
H.check(M.Shown(G.Get(1).requiredLevel) == 50000, "the first Growth Spurt needs exactly 50,000 EXP")
H.check(M.Shown(0) == 0, "level 0 = 0 EXP")
H.check(M.Shown(G.Get(2).requiredLevel) > 50000, "later goals need more EXP")

-- a muscle's EXP is its total xp times one constant, so a rep's gain adds up exactly
local entry = { level = 3, xp = 11 }
local before = M.MuscleExp(entry)
local after = M.MuscleExp({ level = 3, xp = 11 + 34 })
H.check(math.abs((after - before) - M.ShownXp(34)) <= 1, "a rep's popup number is the EXP the muscle gains")
H.check(math.abs(M.Shown(M.ExactLevel(entry)) - before) <= 1, "exact level and EXP agree")
local walked = { level = 0, xp = 0 }
local total = 0
for _ = 1, 400 do
	total += M.XpToNext(walked.level)
	walked.level += 1
end
H.check(math.abs(M.Shown(walked.level) - total * M.ExpPerXp) < 1, "levels walked one by one give the same EXP")

-- a group meets its goal exactly when its average EXP reaches the goal EXP
local group = M.GroupById.Chest
local trainable = {}
for _, muscle in group.muscles do trainable[muscle.id] = true end
local function dataAt(level, xp)
	local muscles = {}
	for _, muscle in M.List do muscles[muscle.id] = { level = level, xp = xp } end
	return muscles
end
local goal = G.Get(1).requiredLevel
H.check(G.GoalLevel(dataAt(goal, 0), group, trainable) >= goal - 1e-9, "all muscles at the goal level meet the goal")
H.check(G.GoalLevel(dataAt(goal - 1, 5), group, trainable) < goal, "just under the goal does not")
H.check(M.GroupExp(dataAt(goal, 0), "Chest") == 50000 * #M.GroupById.Chest.muscles, "a group at the goal shows 50,000 EXP per muscle, added up")
H.check(M.GroupShown("Chest", goal) == M.GroupExp(dataAt(goal, 0), "Chest"), "the group goal is the same sum")
H.check(math.abs(M.LookG("Biceps", goal, goal) - 0.67) < 0.02, "the goal is not the full look")
local function levelAtExp(times) return M.LevelFromXp(times * M.CumXp(goal)) end
H.check(math.abs(M.LookG("Biceps", levelAtExp(2), goal) - 1) < 1e-6, "2x the goal's EXP = the full aesthetic look")
H.check(math.abs(M.LookG("Traps", levelAtExp(5), goal) - M.MonsterG("Traps")) < 1e-6 and M.LookG("Traps", levelAtExp(9), goal) == M.LookG("Traps", levelAtExp(5), goal), "5x the EXP = the mass monster look, then it stays")
H.check(M.FormatExp(50000) == "50,000" and M.FormatExp(999) == "999" and M.FormatExp(1234567) == "1,234,567", "EXP gets thousands separators")
H.done()
