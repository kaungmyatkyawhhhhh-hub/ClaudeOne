-- gains per rep = tier weight x genetics x frame/body x Growth Spurt x boosts x Muscle of the Day x diminishing
local Muscles = require(script.Parent.Muscles)
local Genetics = require(script.Parent.Genetics)
local GrowthSpurts = require(script.Parent.GrowthSpurts)
local MuscleOfTheDay = require(script.Parent.MuscleOfTheDay)
local Alters = require(script.Parent.Alters)

local Gains = {}

Gains.BaseXp = 34         -- tuned with tests/pacing to GrowthSpurts.Targets (first Growth Spurt ~8 min)
Gains.MaxMultiplier = 5     -- cap on all stacked multipliers together (until the first Body Alter, see Gains.Cap)
-- (owner, prompt 25: keep the cap before 7'0", then about +1x per alter tier: x6 from alter 1, x7 from alter 6, ...)
Gains.CapPerAlterTier = 1
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
	Duration = 8,           -- seconds of PUMPED after tapping the full PUMP bar (a full bar waits, it doesn't drain)
	Multiplier = 2,         -- gains while PUMPED
	Speed = 0.75,           -- rep animation time while PUMPED (x)
}

-- BIG REP: about 1 in 12 reps counts triple (gold number, stronger camera punch).
Gains.BigRep = { Chance = 1 / 12, Multiplier = 3 }

-- The cap on the stacked multipliers for this player: MaxMultiplier, + CapPerAlterTier for each Body Alter tier reached.
function Gains.Cap(data): number
	return Gains.MaxMultiplier + Gains.CapPerAlterTier * Alters.TierOf(Alters.State(data).highest or 0)
end

-- the shared multiplier of PerRep (Growth Spurt x boosts x balanced), before the genetics / Muscle of the Day per muscle
local function sharedMultiplier(data, boost)
	return GrowthSpurts.GetBonus(data.growthSpurts) * (boost or 1) * (Gains.IsBalanced(data) and Gains.BalancedBonus or 1)
end

-- (prompt 25) true when the boosts are past the cap for any muscle: the HUD shows a small MAX BOOST tag (player attribute
-- "MaxBoost", MachineService) so players know more boosts won't help until their next alter tier
function Gains.IsCapped(data, boost): boolean
	local shared = sharedMultiplier(data, boost)
	local cap = Gains.Cap(data)
	for _, muscle in ipairs(Muscles.List) do
		if Genetics.GetMultiplier(data.genetics, muscle.id) * shared * MuscleOfTheDay.MultiplierFor(muscle.id) >= cap - 1e-6 then return true end
	end
	return false
end

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
-- Gains.Cap limit with genetics and Growth Spurt bonuses). `quality` = how the rep was done (PUMPED x2,
-- BIG REP x3): earned by playing, so it sits outside the cap and still matters after many Growth Spurts.
function Gains.PerRep(data, machine, tierIndex, boost, quality)
	if machine.trains == "Stamina" then return {} end -- (cardio trains stamina, not muscles: Config.Stamina.Cardio)
	local tier = machine.tiers[tierIndex]
	local shared = sharedMultiplier(data, boost)
	local cap = Gains.Cap(data)

	-- (prompt 21) the Body Alter bonus (the highest alter's): outside the cap, like quality, so it still counts at 7'0"
	local alterBonus = Alters.Bonus(Alters.State(data).highest or 0)

	local result = {}
	for _, entry in ipairs(machine.muscles) do
		local multiplier = math.min(Genetics.GetMultiplier(data.genetics, entry.id) * shared * MuscleOfTheDay.MultiplierFor(entry.id), cap)
		local diminish = 1 / (1 + data.muscles[entry.id].level / Gains.DiminishLevel)
		result[entry.id] = Gains.BaseXp * tier.gains * entry.share * multiplier * diminish * (quality or 1) * (machine.gainScale or 1) * alterBonus
	end
	return result
end

return Gains
