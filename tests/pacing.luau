-- Growth Spurt pacing: simulates a new player playing through their first Growth Spurts with the real formulas
-- (Gains.PerRep, the XP curve, level caps, weight tiers + coins, stamina, which gyms are open) and checks each spurt
-- takes as long as GrowthSpurts.TargetMinutes says (first one: also within the brief's 15-20 minutes).
-- `lune run tests/pacing` prints the breakdown (median per spurt, spread, per overall grade for the first one).
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

-- How a typical player plays (seconds)
local PLAY = {
	Rep = 1.05,           -- fastest real rep (0.6 lower + 0.35 press + 0.1 hold), taps buffered
	Walk = 8,             -- walking to another machine and tapping Use
	Overhead = 180,       -- first session: menu, genetics reveal, tutorial lines, Stats, Coach Dex (not lifting)
	SpurtOverhead = 45,   -- each later spurt: the Growth Spurt moment, walking to a newly opened gym, checking Stats
}
local SPURTS = 8 -- spurts simulated per player (1st-3rd have their own targets, 4th+ share the last one)
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

	local function progress()
		return GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	end
	-- buy the next weight tiers while the level and coins allow; lift the heaviest bought tier the level allows
	-- (bought tiers stay bought after a Growth Spurt, but each needs its main muscle level again)
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
		local usable = 1
		for index = 1, bought do
			if level >= machine.tiers[index].unlockLevel then usable = index end
		end
		return usable
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
		-- one set: lift until stamina runs out, then rest until it's full again
		local stamina = Stamina.Max
		while stamina >= machine.staminaCost do
			stamina -= machine.staminaCost
			for id, amount in Gains.PerRep(data, machine, tier) do addXp(data, id, amount, cap) end
			data.coins += machine.tiers[tier].coins
			time += PLAY.Rep
		end
		time += Stamina.RegenDelay + (Stamina.Max - stamina) / Stamina.RegenPerSecond
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

local perSpurt, firstByGrade = {}, {}
for n = 1, SPURTS do perSpurt[n] = {} end
for seed = 1, PLAYERS do
	local data = newPlayer(seed)
	local grade = Genetics.GetOverallGrade(data.genetics.grades)
	for n = 1, SPURTS do
		local minutes = playOneSpurt(data, n == 1 and PLAY.Overhead or PLAY.SpurtOverhead)
		table.insert(perSpurt[n], minutes)
		if n == 1 then
			firstByGrade[grade] = firstByGrade[grade] or {}
			table.insert(firstByGrade[grade], minutes)
		end
	end
end

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
local first = median(perSpurt[1])
H.check(first >= 15 and first <= 20, string.format("typical first Growth Spurt takes 15-20 minutes (%.1f)", first))
H.done()
