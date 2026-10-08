local H = require("./harness")
local Social = H.module("ReplicatedStorage/Shared/Config/Social")
local Titles = H.module("ReplicatedStorage/Shared/Config/Titles")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
print("Social")
local muscles = {}
for _, m in Muscles.List do muscles[m.id] = { level = 0, xp = 0 } end
H.check(Social.Strength(muscles) == 1, "level 0 strength = 1")
for _, id in Social.ArmWrestle.Muscles do muscles[id].level = 40 end
H.check(math.abs(Social.Strength(muscles) - 2) < 1e-9, "level 40 strength = 2")
for _, id in Social.ArmWrestle.Muscles do H.check(Muscles.ById[id] ~= nil, "arm muscle " .. id .. " exists") end
print("Titles")
for _, id in { "Spotter", "GymBuddy", "IronGrip" } do
	local t = Titles.ById[id]
	H.check(t ~= nil and t.condition.type == "stat", id .. " is a stat title")
	local ctx = { data = { stats = { [t.condition.stat] = t.condition.min } }, groups = {}, session = {} }
	H.check(Titles.Check(t, ctx), id .. " unlocks at its minimum")
	ctx.data.stats[t.condition.stat] = t.condition.min - 1
	H.check(not Titles.Check(t, ctx), id .. " locked below")
end
-- a kid tapping 7/s vs an average rookie: the match should not be decided instantly
local A = Social.ArmWrestle
local net = 7 * A.PushPerTap - 6.5 * A.PushPerTap * 0.95
H.check(net > 0 and 1 / net > 4, "even match takes a while (" .. string.format("%.1f", 1 / net) .. "s to pin)")
H.done()
