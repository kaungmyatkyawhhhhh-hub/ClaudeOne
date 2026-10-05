-- Coach quests. Talk to the Coach to get one; finish it, then talk to the Coach again for the reward and the next one.
-- The Chain is played once, in order; after that the Coach hands out the Repeatable quests in a loop.
-- Adding a quest = adding an entry. Types (checked on the server):
--   reps         `count` validated reps on any machine (counted from when the quest starts)
--   machineReps  `count` reps on one of `machines` (MachineIds)
--   groupLevel   muscle group `group` at level `level` (trainable muscles only, like the Growth Spurt goal)
--   allGroups    every group at level `level` (same rule)
--   anyTier      any machine with weight tier `tier` unlocked
--   titles       own `count` titles
--   spurts       Growth Spurt count at least `count` (new players start at 0)
-- reward: { coins = n, dnaTokens = n, shakes = n } (any of them)
local Quests = {}

Quests.Chain = {
	{ id = "Warmup", text = "Do 10 reps on any machine", type = "reps", count = 10, reward = { coins = 10 } },
	{ id = "LegDay", text = "Do 15 reps on the Squat Rack", type = "machineReps", machines = { "SquatRack" }, count = 15, reward = { coins = 15 } },
	{ id = "GoHeavier", text = "Unlock a heavier weight on any machine", type = "anyTier", tier = 2, reward = { coins = 20 } },
	{ id = "BackDay", text = "Do 20 reps on the Deadlift or Barbell Row", type = "machineReps", machines = { "Deadlift", "BarbellRow" }, count = 20, reward = { coins = 25, shakes = 1 } },
	{ id = "PullUps", text = "Do 15 reps on the Pull-Up Bar", type = "machineReps", machines = { "PullUpBar" }, count = 15, reward = { coins = 25 } },
	{ id = "ChestTen", text = "Get your Chest to level 10", type = "groupLevel", group = "Chest", level = 10, reward = { coins = 40 } },
	{ id = "Shoulders", text = "Do 25 Overhead Press reps", type = "machineReps", machines = { "OverheadPress" }, count = 25, reward = { coins = 35 } },
	{ id = "Crunches", text = "Do 25 reps on the Crunch Bench", type = "machineReps", machines = { "CrunchBench" }, count = 25, reward = { coins = 35, shakes = 1 } },
	{ id = "AllFive", text = "Get every muscle group to level 5", type = "allGroups", level = 5, reward = { coins = 60 } },
	{ id = "ThreeTitles", text = "Earn 3 titles", type = "titles", count = 3, reward = { coins = 60 } },
	{ id = "Grind", text = "Do 200 reps", type = "reps", count = 200, reward = { coins = 100, dnaTokens = 1 } },
	{ id = "FirstSpurt", text = "Do your first Growth Spurt", type = "spurts", count = 1, reward = { coins = 200, shakes = 2 } },
}

Quests.Repeatable = {
	{ id = "DailyGrind", text = "Do 100 reps", type = "reps", count = 100, reward = { coins = 60 } },
	{ id = "LegsAgain", text = "Do 40 reps on the Squat Rack or Deadlift", type = "machineReps", machines = { "SquatRack", "Deadlift" }, count = 40, reward = { coins = 50, shakes = 1 } },
	{ id = "PushDay", text = "Do 40 reps on any bench", type = "machineReps", machines = { "FlatBench", "InclineBench" }, count = 40, reward = { coins = 50 } },
	{ id = "PullDay", text = "Do 40 Pull-Up Bar or Barbell Row reps", type = "machineReps", machines = { "PullUpBar", "BarbellRow" }, count = 40, reward = { coins = 50 } },
}

-- The Coach's one-liners (original lines; one is picked at random).
Quests.Lines = {
	give = { "Here's one for you:", "Got a job for you:", "Try this:" },
	notDone = { "Not yet. Keep going:", "Almost. Still on:", "Back already? You're on:" },
	done = { "Look at you go. Here's your reward.", "That's what I like to see. Reward's yours.", "Solid work. Earned it." },
}

Quests.CoachName = "Coach Dex"
-- Where Coach Dex stands (behind the front desk, facing the room) and how he looks (built in Studio by
-- tools/builders/NPCs.luau; tag "Coach", prompt "TalkPrompt").
Quests.CoachSpot = CFrame.lookAt(Vector3.new(11, 0.15, -9), Vector3.new(0, 0.15, -9))
Quests.CoachLook = { name = Quests.CoachName, skin = "#8D5524", shirt = "#F4F1EA", pants = "#1E1E22", tag = "Coach",
	prompt = { action = "Talk", object = Quests.CoachName, distance = 10 } }

-- The quest at a slot: chain first, then the repeatables in a loop.
function Quests.ForIndex(index)
	if index <= #Quests.Chain then return Quests.Chain[index] end
	local loop = (index - #Quests.Chain - 1) % #Quests.Repeatable + 1
	return Quests.Repeatable[loop]
end

Quests.ById = {}
for _, list in ipairs({ Quests.Chain, Quests.Repeatable }) do
	for _, quest in ipairs(list) do Quests.ById[quest.id] = quest end
end

-- Short reward text, e.g. "+40 coins, +1 shake".
function Quests.RewardText(reward)
	local parts = {}
	if reward.coins then table.insert(parts, "+" .. reward.coins .. " coins") end
	if reward.dnaTokens then table.insert(parts, "+" .. reward.dnaTokens .. (reward.dnaTokens == 1 and " DNA token" or " DNA tokens")) end
	if reward.shakes then table.insert(parts, "+" .. reward.shakes .. (reward.shakes == 1 and " shake" or " shakes")) end
	return table.concat(parts, ", ")
end

return Quests
