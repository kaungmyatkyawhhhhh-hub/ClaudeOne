-- gains per rep = tier weight x genetics x frame/body x Growth Spurt x boosts x Muscle of the Day x diminishing
local Muscles = require(script.Parent.Muscles)
local Genetics = require(script.Parent.Genetics)
local GrowthSpurts = require(script.Parent.GrowthSpurts)
local MuscleOfTheDay = require(script.Parent.MuscleOfTheDay)

local Gains = {}

Gains.BaseXp = 34         -- tuned with tests/pacing to GrowthSpurts.Targets (first Growth Spurt ~8 min)
Gains.MaxMultiplier = 5     -- cap on all stacked multipliers together
Gains.DiminishLevel = 50    -- a muscle at this level grows at half speed
Gains.BalancedBonus = 1.1   -- when all 6 groups are close together
Gains.BalancedSpread = 10   -- "close" = within this many levels
Gains.BalancedMinLevel = 5
Gains.RepCooldown = 0.4     -- seconds; enforced on the server
-- Sustained rep rate the server accepts (token bucket): a tapped rep takes 1.05 s on the client (0.6 lower +
-- 0.35 press + 0.1 hold), a PUMPED one 0.79 s, so anything faster than this for long is a modified client.
-- RepBurst absorbs lag bunching.
Gains.MaxRepsPerSecond = 1.35
Gains.RepBurst = 3

-- Reps happen on their own at a slow pace; tapping makes them faster and fills the PUMP meter. Nobody is ever
-- punished for not tapping: auto reps give normal gains, tapping only adds on top.
Gains.AutoRepGap = 0.8 -- seconds of rest between automatic reps (a tapped rep starts right away)

-- PUMP meter (server-authoritative; the client predicts it for an instant feel).
Gains.Pump = {
	TapsToFill = 16,        -- taps from empty to full
	TapsPerSecond = 8,      -- most taps per second that count (rate limit)
	DrainDelay = 0.8,       -- seconds after the last tap before the meter starts draining
	DrainPerSecond = 0.12,  -- share of the meter lost per second while not tapping
	Duration = 8,           -- seconds of PUMPED once the meter is full (the meter drains over this time)
	Multiplier = 2,         -- gains while PUMPED
	Speed = 0.75,           -- rep animation time while PUMPED (x)
}

-- BIG REP: about 1 in 12 reps counts triple (gold number, stronger camera punch).
Gains.BigRep = { Chance = 1 / 12, Multiplier = 3 }

function Gains.IsBalanced(data)
	local low, high = math.huge, -math.huge
	for _, group in ipairs(Muscles.Groups) do
		local level = Muscles.GetGroupLevel(data.muscles, group.id)
		low = math.min(low, level)
		high = math.max(high, level)
	end
	return low >= Gains.BalancedMinLevel and high - low <= Gains.BalancedSpread
end

-- Returns { [muscleId] = xp } for one rep at the given tier. `boost` = shakes/server boosts (inside the
-- Gains.MaxMultiplier cap with genetics and Growth Spurt bonuses). `quality` = how the rep was done (PUMPED x2,
-- BIG REP x3): earned by playing, so it sits outside the cap and still matters after many Growth Spurts.
function Gains.PerRep(data, machine, tierIndex, boost, quality)
	if machine.trains == "Stamina" then return {} end -- (cardio trains stamina, not muscles: Config.Stamina.Cardio)
	local tier = machine.tiers[tierIndex]
	local shared = GrowthSpurts.GetBonus(data.growthSpurts)
		* (boost or 1)
		* (Gains.IsBalanced(data) and Gains.BalancedBonus or 1)

	local result = {}
	for _, entry in ipairs(machine.muscles) do
		local multiplier = math.min(Genetics.GetMultiplier(data.genetics, entry.id) * shared * MuscleOfTheDay.MultiplierFor(entry.id), Gains.MaxMultiplier)
		local diminish = 1 / (1 + data.muscles[entry.id].level / Gains.DiminishLevel)
		result[entry.id] = Gains.BaseXp * tier.gains * entry.share * multiplier * diminish * (quality or 1) * (machine.gainScale or 1)
	end
	return result
end

return Gains
