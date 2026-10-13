local H = require("./harness")
local R = H.module("ReplicatedStorage/Shared/Config/Rivals")
local Titles = H.module("ReplicatedStorage/Shared/Config/Titles")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
print("Rivals")
local gyms = {}
for _, rival in R.List do
	gyms[rival.gym] = rival
	H.check(rival.lines.intro and rival.lines.win and rival.lines.lose and rival.lines.beaten, rival.id .. " has all his lines")
	local found = false
	for _, t in Titles.List do if t.id == rival.reward.title then found = t.condition.stat == "beat" .. rival.id end end
	H.check(found, rival.id .. "'s title is earned by the stat beat" .. rival.id)
	if rival.challenge.kind == "lift" then
		local machine = Machines.ById[rival.challenge.machineId]
		H.check(machine ~= nil, rival.id .. "'s machine exists")
		local heavier = false
		for _, tier in machine.tiers do if tier.weight > rival.challenge.record then heavier = true end end
		H.check(heavier, rival.id .. "'s record can be beaten (a heavier tier exists)")
	end
end
H.check(gyms.Starter and gyms.Beach and gyms.Pro, "one rival per gym")
H.check(gyms.Starter.reward.coins < gyms.Beach.reward.coins and gyms.Beach.reward.coins < gyms.Pro.reward.coins, "rewards rise in the order the gyms open")
H.check(gyms.Starter.challenge.record < gyms.Pro.challenge.record, "lift records rise")
print("Rules")
local benny = R.ById.Benny
H.check(R.BeatsLift(benny, "FlatBench", 115, 10), "a full set heavier than his record wins")
H.check(not R.BeatsLift(benny, "FlatBench", 95, 10), "matching his record is not enough")
H.check(not R.BeatsLift(benny, "FlatBench", 115, 9), "a short set doesn't count")
H.check(not R.BeatsLift(benny, "SquatRack", 135, 10), "only on his machine")
H.check(R.FromArmId(R.ArmId(R.ById.Coral)) == R.ById.Coral and R.FromArmId("Rookie") == nil, "arm wrestling ids")
local spec = R.BuildSpec(R.ById.Coral)
H.check(spec and spec.scale.width == R.ById.Coral.look.width and spec.name == "Coral", "one size source: BuildSpec from the look")
H.done()
