local H = require("./harness")
local D = H.module("ReplicatedStorage/Shared/Config/DailyQuests")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")

print("Pool")
local types = { reps = true, groupReps = true, groups = true, cardio = true, spots = true, posing = true, armWins = true }
local seen = {}
for _, q in D.Pool do
	H.check(types[q.type] == true and q.count > 0 and q.coins > 0 and not seen[q.id], q.id .. " is valid")
	seen[q.id] = true
	if q.type == "groupReps" then H.check(Muscles.GroupById[q.group] ~= nil, q.id .. " names a real group") end
end

print("Picking")
local ok = true
for day = 19000, 19060 do
	for _, user in { 1, 1834504124, 99999 } do
		local picked = D.Pick(day, user)
		local social, unique = 0, {}
		for _, id in picked do
			if D.ById[id].needsOther then social += 1 end
			if unique[id] then ok = false end
			unique[id] = true
		end
		if #picked ~= D.PerDay or social > 1 then ok = false end
	end
end
H.check(ok, "always " .. D.PerDay .. " different quests, at most one that needs another player")
local a, b = D.Pick(19100, 42), D.Pick(19100, 42)
H.check(table.concat(a, ",") == table.concat(b, ","), "the same list all day")

print("Swap")
local current = D.Pick(19100, 42)
local new = D.SwapFor(19100, 42, current, 0)
H.check(new ~= nil and not table.find(current, new) and not D.ById[new].needsOther, "a swap gives a new quest that never needs another player")
H.check(D.FreeRerollsPerDay == 1 and D.BonusCoins > 0, "one free reroll a day and a bonus")
H.done()
