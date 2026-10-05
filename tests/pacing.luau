-- Growth Spurt pacing: simulates a new player's road to their first Growth Spurt with the real formulas (Gains.PerRep,
-- the XP curve, level cap, weight tiers + coins, stamina) and checks it takes 15-20 minutes for a typical player.
-- `lune run tests/pacing` prints the breakdown (median, spread, per overall grade).
local H = require("./harness")
local Gains = H.module("ReplicatedStorage/Shared/Config/Gains")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local Genetics = H.module("ReplicatedStorage/Shared/Config/Genetics")
local GrowthSpurts = H.module("ReplicatedStorage/Shared/Config/GrowthSpurts")
local Stamina = H.module("ReplicatedStorage/Shared/Config/Stamina")

-- How a typical new player plays (seconds)
local PLAY = {
	Rep = 1.05,        -- fastest real rep (0.6 lower + 0.35 press + 0.1 hold), taps buffered
	Walk = 8,          -- walking to another machine and tapping Use
	Overhead = 180,    -- menu, genetics reveal, tutorial lines, Stats, Coach Dex: time not spent lifting
}

local function newPlayer(seed)
	local muscles = {}
	for _, m in Muscles.List do muscles[m.id] = { level = 0, xp = 0 } end
	return { muscles = muscles, growthSpurts = 0, genetics = (function() math.randomseed(seed) return Genetics.Roll() end)(), coins = 0, machines = {} }
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

local function simulate(seed)
	local data = newPlayer(seed)
	local trainable = Machines.TrainableMuscles(0)
	local required = GrowthSpurts.Get(1).requiredLevel
	local cap = GrowthSpurts.GetLevelCap(0)
	local starter = {}
	for _, machine in Machines.List do
		if machine.gym == "Starter" then table.insert(starter, machine) end
	end
	local time, reps, current = PLAY.Overhead, 0, nil

	local function progress()
		return GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	end
	-- buy the next weight tiers on this machine while the level and coins allow, and lift the heaviest
	local function tierFor(machine)
		local unlocked = data.machines[machine.id] or 1
		while machine.tiers[unlocked + 1] do
			local tier = machine.tiers[unlocked + 1]
			if data.muscles[machine.muscles[1].id].level < tier.unlockLevel or data.coins < tier.cost then break end
			data.coins -= tier.cost
			unlocked += 1
		end
		data.machines[machine.id] = unlocked
		return unlocked
	end
	-- the machine that does the most for the groups still under the goal (low muscles count more)
	-- (stays on the current machine while it is still at least 75% as good as the best one: real players do a few
	-- sets in a row instead of walking after every set)
	local function pick(p, stay)
		local best, bestScore, stayScore = nil, -1, -1
		for _, machine in starter do
			local xp = Gains.PerRep(data, machine, data.machines[machine.id] or 1)
			local score = 0
			for id, amount in xp do
				local group = Muscles.ById[id].group
				if p.groups[group] < required and data.muscles[id].level < cap then
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
			reps += 1
			time += PLAY.Rep
		end
		time += Stamina.RegenDelay + (Stamina.Max - stamina) / Stamina.RegenPerSecond
		if time > 3 * 3600 then break end -- safety
	end
	return time / 60, reps, Genetics.GetOverallGrade(data.genetics.grades)
end

print("Growth Spurt pacing (first spurt, new player)")
local results, byGrade = {}, {}
for seed = 1, 200 do
	local minutes, reps, grade = simulate(seed)
	table.insert(results, minutes)
	byGrade[grade] = byGrade[grade] or {}
	table.insert(byGrade[grade], minutes)
end
table.sort(results)
local function at(list, share) return list[math.max(1, math.floor(#list * share + 0.5))] end
local median = at(results, 0.5)
print(string.format("  median %.1f min, fastest 10%% %.1f, slowest 10%% %.1f (200 genetics rolls)", median, at(results, 0.1), at(results, 0.9)))
for _, grade in Genetics.Grades do
	local list = byGrade[grade.id]
	if list then
		table.sort(list)
		print(string.format("  overall %s: median %.1f min (%d players)", grade.id, at(list, 0.5), #list))
	end
end
H.check(median >= 15 and median <= 20, string.format("typical first Growth Spurt takes 15-20 minutes (%.1f)", median))
H.done()
