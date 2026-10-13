-- Daily quests (owner's feature run, task 2): every player gets PerDay quests from the Pool each UTC day (reset at 00:00
-- UTC), tracked automatically on the server (DailyService) from what the game already counts. Claim each one for coins;
-- finishing all of them pays a bonus. A quest that needs another player (needsOther) can be swapped for another one,
-- SwapsPerDay times a day, so an empty server never blocks the bonus.
-- Types:
--   reps       validated reps on any machine (not the treadmill)
--   groupReps  reps on machines whose MAIN muscle is in `group`
--   groups     different muscle groups trained today (by the machines' main muscle)
--   cardio     metres run on the treadmill
--   spots      spot sessions where the lifter did at least one rep while you spotted
--   posing     posing competitions entered
--   armWins    arm wrestling wins (against a player or a practice opponent)
-- Adding a quest = adding an entry (unique id).
local DailyQuests = {}

DailyQuests.PerDay = 3
DailyQuests.BonusCoins = 150 -- for claiming all of the day's quests
DailyQuests.SwapsPerDay = 1

DailyQuests.Pool = {
	{ id = "ChestReps", text = "Do 50 reps on chest machines", type = "groupReps", group = "Chest", count = 50, coins = 60 },
	{ id = "LegReps", text = "Do 50 leg reps", type = "groupReps", group = "Legs", count = 50, coins = 60 },
	{ id = "BackReps", text = "Do 50 back reps", type = "groupReps", group = "Back", count = 50, coins = 60 },
	{ id = "ShoulderReps", text = "Do 40 shoulder reps", type = "groupReps", group = "Shoulders", count = 40, coins = 60 },
	{ id = "ArmReps", text = "Do 40 arm reps", type = "groupReps", group = "Arms", count = 40, coins = 60 },
	{ id = "CoreReps", text = "Do 40 core reps", type = "groupReps", group = "Core", count = 40, coins = 55 },
	{ id = "TotalReps", text = "Do 100 reps", type = "reps", count = 100, coins = 70 },
	{ id = "ThreeGroups", text = "Train 3 different muscle groups", type = "groups", count = 3, coins = 50 },
	{ id = "RunOneK", text = "Run 1 km on the treadmill", type = "cardio", count = 1000, coins = 60 },
	{ id = "SpotTwice", text = "Spot another player 2 times", type = "spots", count = 2, coins = 80, needsOther = true },
	{ id = "Posing", text = "Enter a posing competition", type = "posing", count = 1, coins = 80 },
	{ id = "ArmWin", text = "Win an arm wrestle", type = "armWins", count = 1, coins = 70 },
}

DailyQuests.ById = {}
for _, quest in ipairs(DailyQuests.Pool) do DailyQuests.ById[quest.id] = quest end

-- Today's quests for one player: the same list all day (seeded by the day and the player), different quests, at most one
-- that needs another player. `exclude` (optional): ids to leave out (a swap).
function DailyQuests.Pick(day: number, userId: number, exclude: { [string]: boolean }?): { string }
	local rng = Random.new(day * 1000003 + (userId % 1000003))
	local pool = {}
	for _, quest in ipairs(DailyQuests.Pool) do
		if not (exclude and exclude[quest.id]) then table.insert(pool, quest) end
	end
	local picked, social = {}, false
	while #picked < DailyQuests.PerDay and #pool > 0 do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		if not (quest.needsOther and social) then
			social = social or quest.needsOther == true
			table.insert(picked, quest.id)
		end
	end
	return picked
end

-- One replacement quest for a swap: not one of today's, never one that needs another player.
function DailyQuests.SwapFor(day: number, userId: number, current: { string }, swaps: number): string?
	local rng = Random.new(day * 7919 + userId % 7919 + swaps * 104729)
	local options = {}
	for _, quest in ipairs(DailyQuests.Pool) do
		if not table.find(current, quest.id) and not quest.needsOther then table.insert(options, quest.id) end
	end
	if #options == 0 then return nil end
	return options[rng:NextInteger(1, #options)]
end

return DailyQuests
