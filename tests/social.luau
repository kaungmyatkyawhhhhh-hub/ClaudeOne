local H = require("./harness")
local Social = H.module("ReplicatedStorage/Shared/Config/Social")
local Titles = H.module("ReplicatedStorage/Shared/Config/Titles")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
print("Arm wrestling strength")
local A = Social.ArmWrestle
local looks = {}
for _, m in Muscles.List do looks[m.id] = 0 end
H.check(Social.Strength(looks) == 1, "nothing grown = strength 1")
for _, id in A.Muscles do looks[id] = 1 end
H.check(math.abs(Social.Strength(looks) - (1 + A.StrengthBonus)) < 1e-9, "full look = 1 + bonus")
for _, id in A.Muscles do looks[id] = 5 end
H.check(math.abs(Social.Strength(looks) - (1 + A.StrengthBonus)) < 1e-9, "the bonus is capped (mass monster arms add nothing more)")
for _, id in A.Muscles do H.check(Muscles.ById[id] ~= nil, "arm muscle " .. id .. " exists") end
H.check(A.MaxTapsPerSecond == 15 and A.MaxTime == 8, "15 taps a second at most, 8 second matches")
print("NPC opponents")
H.check(#A.Npcs == 3, "three levels")
for i = 2, #A.Npcs do
	local a, b = A.Npcs[i - 1], A.Npcs[i]
	H.check(b.strength * b.taps[1] > a.strength * a.taps[1] and b.coins > a.coins, b.id .. " is harder and pays more than " .. a.id)
end
local champ = A.Npcs[#A.Npcs]
-- the champion can be beaten by fast tapping even with the smallest arms, but not by a lazy tapper with maxed arms
local champPush = champ.strength * champ.taps[2]
H.check(A.MaxTapsPerSecond * 1 > champPush, "a weak but fast tapper can still beat the champion")
H.check(7 * (1 + A.StrengthBonus) < champ.strength * champ.taps[1], "big arms alone don't beat the champion")
H.check(champ.king == true, "the champion gives the Arm Wrestling King title")
print("Titles")
for _, id in { "Spotter", "GymBuddy", "IronGrip", "ArmWrestlingKing" } do
	local t = Titles.ById[id]
	H.check(t ~= nil and t.condition.type == "stat", id .. " is a stat title")
	local ctx = { data = { stats = { [t.condition.stat] = t.condition.min } }, groups = {}, session = {} }
	H.check(Titles.Check(t, ctx), id .. " unlocks at its minimum")
	ctx.data.stats[t.condition.stat] = t.condition.min - 1
	H.check(not Titles.Check(t, ctx), id .. " locked below")
end
-- a kid tapping 7/s vs the easy NPC: the match should not be decided instantly
local rookie = A.Npcs[1]
local net = 7 * A.PushPerTap - rookie.taps[1] * A.PushPerTap * rookie.strength
H.check(net > 0 and 1 / net > 4, "a match against the easy NPC takes a while (" .. string.format("%.1f", 1 / net) .. "s to pin)")
H.done()
