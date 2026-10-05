-- Growth Spurt pacing: simulates new players playing through their first Growth Spurts with the real formulas
-- (Gains.PerRep, the XP curve, level caps, weight tiers + coins, stamina, auto reps, tapping, PUMPED, BIG REP, which
-- gyms are open) and checks each spurt takes as long as GrowthSpurts.TargetMinutes says.
--   lune run tests/pacing        prints the breakdown (median per spurt, spread, per overall grade for the first)
--   lune run tests/pacing tune   finds the requiredLevel for each stage that hits its target (paste into
--                                Config/GrowthSpurts.Stages)
local process = require("@lune/process")
local H = require("./harness")
local Gains = H.module("ReplicatedStorage/Shared/Config/Gains")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local Genetics = H.module("ReplicatedStorage/Shared/Config/Genetics")
local GrowthSpurts = H.module("ReplicatedStorage/Shared/Config/GrowthSpurts")
local Stamina = H.module("ReplicatedStorage/Shared/Config/Stamina")
local MuscleOfTheDay = H.module("ReplicatedStorage/Shared/Config/MuscleOfTheDay")

-- Muscle of the Day depends on the date; each simulated player gets their own 2x group for each spurt (a typical
-- day), so results don't change from day to day.
local motdGroup = nil
MuscleOfTheDay.MultiplierFor = function(muscleId)
	return Muscles.ById[muscleId].group == motdGroup and MuscleOfTheDay.Multiplier or 1
end

-- How a typical player plays ("normal play with some tapping"), in seconds
local PLAY = {
	Rep = 1.05,           -- one rep's animation (0.6 lower + 0.35 press + 0.1 hold)
	TapShare = 0.5,       -- share of sets the player taps through (the rest run on auto reps)
	TapsPerSecond = 3,    -- how fast a kid taps while tapping
	Walk = 8,             -- walking to another machine and tapping Use
	Overhead = 150,       -- first session: menu, genetics reveal, tutorial lines, Coach Dex (not lifting)
	SpurtOverhead = 45,   -- each later spurt: the Growth Spurt moment, walking to a newly opened gym, checking Stats
}
local SPURTS = 8 -- spurts simulated per player (1st-4th have their own targets, later ones share the last one)
local PLAYERS = 60

local function newPlayer(seed)
	local muscles = {}
	for _, m in Muscles.List do muscles[m.id] = { level = 0, xp = 0 } end
	math.randomseed(seed)
	return { seed = seed, muscles = muscles, growthSpurts = 0, genetics = Genetics.Roll(), coins = 0, bought = {} }
end

local function addXp(data, muscleId, xp, cap)
	local muscle = data.muscles[muscleId]
	if muscle.level >= cap then return end
	muscle.xp += xp
	while muscle.level < cap and muscle.xp >= Muscles.XpToNext(muscle.level) do
		muscle.xp -= Muscles.XpToNext(muscle.level)
		muscle.level += 1
	end
end

-- The PUMP meter over `dt` seconds (same rules as MachineService): tapping fills it, full = PUMPED for a while,
-- not tapping drains it.
local function stepPump(pump, dt, tapping)
	local P = Gains.Pump
	if pump.left > 0 then
		pump.left = math.max(0, pump.left - dt)
		return
	end
	if tapping then
		pump.meter += dt * math.min(PLAY.TapsPerSecond, P.TapsPerSecond) / P.TapsToFill
		if pump.meter >= 1 then
			pump.meter = 0
			pump.left = P.Duration
		end
	else
		pump.meter = math.max(0, pump.meter - P.DrainPerSecond * dt)
	end
end

-- Plays from the current state to the next Growth Spurt and does it. Returns the minutes it took.
local function playOneSpurt(data, overhead)
	motdGroup = Muscles.Groups[(data.seed + data.growthSpurts) % #Muscles.Groups + 1].id
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local required = GrowthSpurts.Get(data.growthSpurts + 1).requiredLevel
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	local open = {}
	for _, machine in Machines.List do
		if machine.gym ~= "Seasonal" and data.growthSpurts >= (Machines.GymUnlock[machine.gym] or 0) then
			table.insert(open, machine)
		end
	end
	local time, current = overhead, nil
	local pump = { meter = 0, left = 0 }

	local function progress()
		return GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	end
	-- buy the next weight tiers while the level and coins allow; lift the heaviest usable tier (bought + level)
	local function tierFor(machine)
		local level = data.muscles[machine.muscles[1].id].level
		local bought = data.bought[machine.id] or 1
		while machine.tiers[bought + 1] do
			local tier = machine.tiers[bought + 1]
			if level < tier.unlockLevel or data.coins < tier.cost then break end
			data.coins -= tier.cost
			bought += 1
		end
		data.bought[machine.id] = bought
		return Machines.UsableTier(machine, { unlocked = bought }, level)
	end
	-- the machine that does the most for the groups still under the goal (low muscles count more); stays on the
	-- current machine while it is at least 75% as good (real players do a few sets in a row)
	local function pick(p, stay)
		local best, bestScore, stayScore = nil, -1, -1
		for _, machine in open do
			local xp = Gains.PerRep(data, machine, tierFor(machine))
			local score = 0
			for id, amount in xp do
				local group = Muscles.ById[id].group
				if trainable[id] and p.groups[group] < required and data.muscles[id].level < cap then
					score += amount * (required - data.muscles[id].level)
				end
			end
			if machine == stay then stayScore = score end
			if score > bestScore then best, bestScore = machine, score end
		end
		if stay and stayScore >= bestScore * 0.75 then return stay end
		return best
	end

	while true do
		local p = progress()
		if p.ready then break end
		local machine = pick(p, current)
		if machine ~= current then time += PLAY.Walk; current = machine end
		local tier = tierFor(machine)
		-- one set: tapped or on auto reps, until stamina runs out; then rest until it's full again
		local tapping = math.random() < PLAY.TapShare
		local stamina = Stamina.Max
		while stamina >= machine.staminaCost do
			stamina -= machine.staminaCost
			local pumped = pump.left > 0
			local quality = (pumped and Gains.Pump.Multiplier or 1)
				* (math.random() < Gains.BigRep.Chance and Gains.BigRep.Multiplier or 1)
			for id, amount in Gains.PerRep(data, machine, tier, 1, quality) do addXp(data, id, amount, cap) end
			data.coins += machine.tiers[tier].coins
			local rep = PLAY.Rep * (pumped and Gains.Pump.Speed or 1) + (tapping and 0 or Gains.AutoRepGap)
			stepPump(pump, rep, tapping)
			time += rep
		end
		local rest = Stamina.RegenDelay + (Stamina.Max - stamina) / Stamina.RegenPerSecond
		stepPump(pump, rest, false)
		time += rest
		if time > 6 * 3600 then break end -- safety
	end
	-- the Growth Spurt itself (same as PlayerData.GrowthSpurt)
	for _, muscle in Muscles.List do data.muscles[muscle.id] = { level = 0, xp = 0 } end
	data.growthSpurts += 1
	return time / 60
end

local function median(list)
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.max(1, math.floor(#sorted * 0.5 + 0.5))], sorted
end
local function at(sorted, share) return sorted[math.max(1, math.floor(#sorted * share + 0.5))] end

-- Runs PLAYERS simulated players through `spurts` spurts. Returns perSpurt[n] = { minutes... }, firstByGrade.
local function simulate(spurts)
	local perSpurt, firstByGrade = {}, {}
	for n = 1, spurts do perSpurt[n] = {} end
	for seed = 1, PLAYERS do
		local data = newPlayer(seed)
		local grade = Genetics.GetOverallGrade(data.genetics.grades)
		for n = 1, spurts do
			local minutes = playOneSpurt(data, n == 1 and PLAY.Overhead or PLAY.SpurtOverhead)
			table.insert(perSpurt[n], minutes)
			if n == 1 then
				firstByGrade[grade] = firstByGrade[grade] or {}
				table.insert(firstByGrade[grade], minutes)
			end
		end
	end
	return perSpurt, firstByGrade
end

if process.args[1] == "tune" then
	-- one stage at a time: the earlier stages are already tuned, so only this stage's level moves its time
	local stages = GrowthSpurts.Stages
	for n = 1, #stages do
		local target = GrowthSpurts.TargetMinutes(n)
		local lo, hi = (n > 1 and stages[n - 1].requiredLevel or 1), 600
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			stages[n].requiredLevel = mid
			local per = simulate(n)
			if (median(per[n])) < target then lo = mid else hi = mid end
		end
		stages[n].requiredLevel = lo
		local per = simulate(n)
		print(string.format("stage %d: requiredLevel = %d -> median %.1f min (target %g)", n, lo, (median(per[n])), target))
	end
	return
end

local perSpurt, firstByGrade = simulate(SPURTS)
print(string.format("Growth Spurt pacing (%d new players, minutes of play per spurt)", PLAYERS))
for n = 1, SPURTS do
	local mid, sorted = median(perSpurt[n])
	local target = GrowthSpurts.TargetMinutes(n)
	local stage = GrowthSpurts.Get(n)
	print(string.format("  spurt %d (level %d, bonus x%.2f before it): median %.1f (target %g), fastest 10%% %.1f, slowest 10%% %.1f",
		n, stage.requiredLevel, GrowthSpurts.GetBonus(n - 1), mid, target, at(sorted, 0.1), at(sorted, 0.9)))
	-- within 10% of the target (later spurts compound small drifts, so they get the same relative band)
	H.check(math.abs(mid - target) <= target * 0.1, string.format("spurt %d takes about %g minutes (%.1f)", n, target, mid))
end
for _, grade in Genetics.Grades do
	local list = firstByGrade[grade.id]
	if list then print(string.format("  first spurt, overall %s: median %.1f (%d players)", grade.id, (median(list)), #list)) end
end
H.done()
