-- gains per rep = tier weight x genetics x frame/body x Growth Spurt x boosts x Muscle of the Day x diminishing
local Muscles = require(script.Parent.Muscles)
local Genetics = require(script.Parent.Genetics)
local GrowthSpurts = require(script.Parent.GrowthSpurts)
local MuscleOfTheDay = require(script.Parent.MuscleOfTheDay)

local Gains = {}

Gains.BaseXp = 27         -- tuned with tests/pacing to GrowthSpurts.Targets (first Growth Spurt ~18.5 min)
Gains.MaxMultiplier = 5     -- cap on all stacked multipliers together
Gains.DiminishLevel = 50    -- a muscle at this level grows at half speed
Gains.BalancedBonus = 1.1   -- when all 6 groups are close together
Gains.BalancedSpread = 10   -- "close" = within this many levels
Gains.BalancedMinLevel = 5
Gains.RepCooldown = 0.4     -- seconds; enforced on the server
-- Sustained rep rate the server accepts (token bucket): a real rep takes at least 1.05 s on the client (0.6 lower +
-- 0.35 press + 0.1 hold), so anything faster than this for long is a modified client. RepBurst absorbs lag bunching.
Gains.MaxRepsPerSecond = 1.05
Gains.RepBurst = 3

function Gains.IsBalanced(data)
	local low, high = math.huge, -math.huge
	for _, group in ipairs(Muscles.Groups) do
		local level = Muscles.GetGroupLevel(data.muscles, group.id)
		low = math.min(low, level)
		high = math.max(high, level)
	end
	return low >= Gains.BalancedMinLevel and high - low <= Gains.BalancedSpread
end

-- Returns { [muscleId] = xp } for one rep at the given tier. `boost` = shakes/server boosts.
function Gains.PerRep(data, machine, tierIndex, boost)
	local tier = machine.tiers[tierIndex]
	local shared = GrowthSpurts.GetBonus(data.growthSpurts)
		* (boost or 1)
		* (Gains.IsBalanced(data) and Gains.BalancedBonus or 1)

	local result = {}
	for _, entry in ipairs(machine.muscles) do
		local multiplier = math.min(Genetics.GetMultiplier(data.genetics, entry.id) * shared * MuscleOfTheDay.MultiplierFor(entry.id), Gains.MaxMultiplier)
		local diminish = 1 / (1 + data.muscles[entry.id].level / Gains.DiminishLevel)
		result[entry.id] = Gains.BaseXp * tier.gains * entry.share * multiplier * diminish
	end
	return result
end

return Gains
