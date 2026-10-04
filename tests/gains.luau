local H = require("./harness")
local Gains = H.module("ReplicatedStorage/Shared/Config/Gains")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local Genetics = H.module("ReplicatedStorage/Shared/Config/Genetics")

local function fakeData(grade)
	local muscles = {}
	for _, m in Muscles.List do muscles[m.id] = { level = 0, xp = 0 } end
	return { muscles = muscles, growthSpurts = 1, genetics = Genetics.Roll() }
end
print("Gains")
local data = fakeData()
local ok, err = pcall(function() return Genetics.GetMultiplier(data.genetics, "MidChest") end)
H.check(ok, "genetics multiplier works with fake data " .. tostring(err))
for _, machine in Machines.List do
	local xp = Gains.PerRep(data, machine, 1)
	for id, amount in xp do
		H.check(amount > 0 and amount <= Gains.BaseXp * machine.tiers[1].gains * Gains.MaxMultiplier, machine.id .. " " .. id .. " xp in range (" .. string.format("%.2f", amount) .. ")")
	end
end
H.done()

