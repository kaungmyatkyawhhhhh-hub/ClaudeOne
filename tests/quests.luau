local H = require("./harness")
local Quests = H.module("ReplicatedStorage/Shared/Config/Quests")
local MOTD = H.module("ReplicatedStorage/Shared/Config/MuscleOfTheDay")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local Onboarding = H.module("ReplicatedStorage/Shared/Config/Onboarding")

print("Quests")
H.check(Quests.ForIndex(1).id == "Warmup", "chain starts with Warmup")
H.check(Quests.ForIndex(#Quests.Chain).id == "FirstSpurt", "chain ends with FirstSpurt")
H.check(Quests.ForIndex(#Quests.Chain + 1).id == Quests.Repeatable[1].id, "repeatables after chain")
H.check(Quests.ForIndex(#Quests.Chain + #Quests.Repeatable + 1).id == Quests.Repeatable[1].id, "repeatables loop")
local validTypes = { reps = true, machineReps = true, groupLevel = true, allGroups = true, anyTier = true, titles = true, spurts = true }
local ids = {}
for _, list in { Quests.Chain, Quests.Repeatable } do
	for _, q in list do
		H.check(validTypes[q.type] == true, q.id .. " has a known type")
		H.check(not ids[q.id], q.id .. " id is unique")
		ids[q.id] = true
		H.check(type(q.reward) == "table" and Quests.RewardText(q.reward) ~= "", q.id .. " has a reward")
		if q.type == "machineReps" then
			for _, m in q.machines do H.check(Machines.ById[m] ~= nil, q.id .. " machine " .. m .. " exists") end
		end
		if q.type == "groupLevel" then H.check(Muscles.GroupById[q.group] ~= nil, q.id .. " group exists") end
		H.check((q.count or q.level or q.tier) ~= nil, q.id .. " has a goal")
	end
end
H.check(Quests.RewardText({ coins = 5, shakes = 1 }) == "+5 coins, +1 shake", "reward text")

print("Muscle of the Day")
local seen = {}
for day = 0, 5 do seen[MOTD.GroupId(day * 86400 + 100)] = true end
local count = 0 for _ in seen do count += 1 end
H.check(count == 6, "all 6 groups appear over 6 days")
local g = MOTD.GroupId(1000)
H.check(MOTD.GroupId(1000) == MOTD.GroupId(80000), "same group all day")
local inGroup = Muscles.GroupById[g].muscles[1].id
H.check(MOTD.MultiplierFor(inGroup, 1000) == 2, "2x for the day's muscles")
H.check(MOTD.SecondsLeft(86400 - 10) == 10, "seconds left")

print("Onboarding")
H.check(#Onboarding.Steps < Onboarding.Done, "Done marker above step count")
for _, step in Onboarding.Steps do
	if step.target and step.target ~= "Coach" then H.check(Machines.ById[step.target] ~= nil, step.id .. " target exists") end
end
H.done()
