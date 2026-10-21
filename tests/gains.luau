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
-- (owner, prompt 25) the cap: x5 until the first Body Alter, then +1 per alter tier; MAX BOOST when the boosts pass it
H.check(Gains.Cap({ alter = { highest = 0 } }) == Gains.MaxMultiplier and Gains.Cap({}) == Gains.MaxMultiplier, "the cap is x" .. Gains.MaxMultiplier .. " before 7'0\"")
H.check(Gains.Cap({ alter = { highest = 1 } }) == Gains.MaxMultiplier + 1 and Gains.Cap({ alter = { highest = 6 } }) == Gains.MaxMultiplier + 2, "+1 per alter tier (alter 1: tier 1, alter 6: tier 2)")
H.check(Gains.IsCapped(data, 50) and not Gains.IsCapped(data, 1), "a huge boost is capped (MAX BOOST), none isn't")
H.done()

