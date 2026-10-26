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
local Alters = H.module("ReplicatedStorage/Shared/Config/Alters")
local Trainers = H.module("ReplicatedStorage/Shared/Config/Trainers")
local PumpShop = H.module("ReplicatedStorage/Shared/Config/PumpShop")

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
local SPURTS = GrowthSpurts.MaxSpurts() -- spurts simulated per player: every one up to the 7'0" cap (1st-4th have their own
-- targets, later ones share the last one)
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

-- (26 Oct) Trainers (lune run tests/pacing trainers): a player with data.tr rolls trainers with every coin from reps
-- once trainers open (Growth Spurt 1), gets the free first roll at Spurt 1 and one free roll per hour of play (the
-- daily playtime gift, playing about an hour a day), keeps every copy (3 of a trainer at a stage evolve into the next
-- stage, keeping the best level), equips the best ones in the slots they have (Trainers.SlotsFor, no pass) and levels
-- the equipped ones from reps (Trainers.RepXp / LevelXp). Their boosts: gains and coins x(1 + bonus), the stamina
-- refill faster, a bigger stamina bar, and the progress perk lowers every goal (GrowthSpurts.BoostedLevel).
local TRAINERS_OPEN = 1
local function trainerValue(copy)
	local perk = Trainers.ById[copy.id].perk
	return ((perk.gains or 0) + (perk.progress or 0) + 0.25 * (perk.coins or 0) + 0.2 * (perk.staminaRegen or 0) + 0.2 * (perk.maxStamina or 0))
		* Trainers.CopyMultiplier(copy)
end
local function equipTrainers(data)
	local tr = data.tr
	table.sort(tr.copies, function(a, b) return trainerValue(a) > trainerValue(b) end)
	local slots = Trainers.SlotsFor(false, data.growthSpurts, data.alter and data.alter.highest or 0)
	tr.equipped = {}
	for i = 1, math.min(slots, #tr.copies) do tr.equipped[i] = tr.copies[i] end
	tr.bonus = Trainers.Bonus(tr.equipped)
	data.trainers = { bonus = tr.bonus } -- (GrowthSpurts.ProgressBoost reads it)
end
local function addCopy(data, id)
	local tr = data.tr
	table.insert(tr.copies, { id = id, s = 1, l = 1, x = 0 })
	-- evolve: 3 of the same trainer at the same stage -> 1 at the next stage (the best level kept)
	local merged = true
	while merged do
		merged = false
		local groups = {}
		for _, copy in tr.copies do
			if copy.s < #Trainers.Stages then
				local key = copy.id .. "@" .. copy.s
				groups[key] = groups[key] or {}
				table.insert(groups[key], copy)
			end
		end
		for _, list in groups do
			if #list >= Trainers.EvolveCount then
				local best = 1
				for i = 1, Trainers.EvolveCount do best = math.max(best, list[i].l) end
				for i = 1, Trainers.EvolveCount do table.remove(tr.copies, table.find(tr.copies, list[i])) end
				table.insert(tr.copies, { id = list[1].id, s = list[1].s + 1, l = best, x = 0 })
				merged = true
				break
			end
		end
	end
end
local function rollTrainers(data)
	local tr = data.tr
	if not tr or data.growthSpurts < TRAINERS_OPEN then return end
	local price = Trainers.RollPrice(PumpShop.Rate(data.growthSpurts))
	local rolled = false
	while tr.freeRolls > 0 or data.coins >= price do
		if tr.freeRolls > 0 then tr.freeRolls -= 1 else data.coins -= price end
		local rarity
		rarity, tr.pity = Trainers.Roll(math.random(), tr.pity)
		addCopy(data, Trainers.PickTrainer(rarity, math.random()).id)
		tr.rolls += 1
		rolled = true
	end
	if rolled then equipTrainers(data) end
end
local function trainerReps(data, reps, tierGains)
	local tr = data.tr
	if not tr then return end
	for _, copy in tr.equipped do
		if copy.l < Trainers.MaxLevel then
			copy.x += reps * Trainers.RepXp(tierGains)
			while copy.l < Trainers.MaxLevel and copy.x >= Trainers.LevelXp(copy.l, copy.s) do
				copy.x -= Trainers.LevelXp(copy.l, copy.s)
				copy.l += 1
			end
		end
	end
	tr.bonus = Trainers.Bonus(tr.equipped)
	data.trainers = { bonus = tr.bonus }
end

-- Plays from the current state to the next Growth Spurt and does it. Returns the minutes it took.
-- alterGoal (prompt 21): at 7'0", play to that Body Alter goal instead and do the alter (keep Alters.KeepShare).
local function playOneSpurt(data, overhead, limitSeconds, alterGoal)
	motdGroup = Muscles.Groups[(data.seed + data.growthSpurts) % #Muscles.Groups + 1].id
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local required = alterGoal or GrowthSpurts.Get(data.growthSpurts + 1).requiredLevel
	if data.tr then required = GrowthSpurts.BoostedLevel(required, GrowthSpurts.ProgressBoost(data)) end -- (the trainers' progress perk)
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	local open = {}
	for _, machine in Machines.List do
		if machine.gym ~= "Seasonal" and data.growthSpurts >= (Machines.GymUnlock[machine.gym] or 0) then
			table.insert(open, machine)
		end
	end
	local time, current = overhead, nil
	local pump = { meter = 0, left = 0 }
	local stamina = Stamina.Max -- (carried from set to set: a player who switches machines keeps what's left)
	local function bonus(kind) return data.tr and data.tr.bonus and data.tr.bonus[kind] or 0 end

	local function progress()
		if alterGoal then
			local p = { groups = {}, met = 0 }
			for _, group in Muscles.Groups do
				p.groups[group.id] = GrowthSpurts.GoalLevel(data.muscles, group, trainable)
				if p.groups[group.id] >= required then p.met += 1 end
			end
			p.ready = p.met == #Muscles.Groups
			return p
		end
		return GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	end
	-- buy the next weight tiers while the level and coins allow; lift the heaviest usable tier (bought + level)
	local function tierFor(machine)
		local level = data.muscles[machine.muscles[1].id].level
		local bought = data.bought[machine.id] or 1
		while machine.tiers[bought + 1] do
			local tier = machine.tiers[bought + 1]
			if level < tier.unlockLevel then break end -- (weights are free, owner 14 Oct)
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
			-- (prompt 36) a Pro copy of a starter machine stays locked below its first weight's level (MachineService)
			if machine.base and data.muscles[machine.muscles[1].id].level < machine.tiers[1].unlockLevel then continue end
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
		if p.ready and not limitSeconds then break end
		if limitSeconds and time >= limitSeconds then break end
		local machine = pick(p, current)
		if machine ~= current then time += PLAY.Walk; current = machine end
		local tier = tierFor(machine)
		-- one set: tapped or on auto reps, until stamina runs out; then rest until it's full again
		local tapping = math.random() < PLAY.TapShare
		local cost = Stamina.RepCost(machine.staminaCost, data.growthSpurts)
		local reps, switch = 0, false
		while stamina >= cost do
			-- every 10 reps a look at the Growth Spurt card ("Needs LEGS", prompt 20): done here, or a better machine now?
			reps += 1
			if reps % 10 == 0 then
				local now = progress()
				if now.ready or pick(now, machine) ~= machine then switch = true break end
			end
			stamina -= cost
			local pumped = pump.left > 0
			local quality = (pumped and Gains.Pump.Multiplier or 1)
				* (math.random() < Gains.BigRep.Chance and Gains.BigRep.Multiplier or 1)
			for id, amount in Gains.PerRep(data, machine, tier, 1 + bonus("gains"), quality) do addXp(data, id, amount, cap) end
			data.coins += machine.tiers[tier].coins * (1 + bonus("coins"))
			local rep = PLAY.Rep * (pumped and Gains.Pump.Speed or 1) + (tapping and 0 or Gains.AutoRepGap)
			stepPump(pump, rep, tapping)
			time += rep
		end
		if not switch then
			-- recovering: empty to full in the pacing's refillSeconds, on the machine (Config/Stamina.Pacing)
			local maxStamina = Stamina.Max * (1 + bonus("maxStamina"))
			local rest = Stamina.PacingFor(data.growthSpurts).refillSeconds * math.max(maxStamina - stamina, 0) / maxStamina / (1 + bonus("staminaRegen"))
			stepPump(pump, rest, false)
			time += rest
			stamina = maxStamina
		end
		if data.tr then
			trainerReps(data, reps, machine.tiers[tier].gains)
			-- the playtime gift's free roll, about one per hour of play
			local hours = math.floor((data.tr.played + time) / 3600)
			if hours > data.tr.hourGifts then
				data.tr.freeRolls += hours - data.tr.hourGifts
				data.tr.hourGifts = hours
			end
			rollTrainers(data)
		end
		if time > 6 * 3600 then break end -- safety
	end
	if limitSeconds then return time / 60 end -- (timed play: no Growth Spurt)
	if alterGoal then -- the alter (same as PlayerData.Alter)
		for _, muscle in Muscles.List do data.muscles[muscle.id] = Alters.Kept(data.muscles[muscle.id]) end
		data.alter = { highest = (data.alter and data.alter.highest or 0) + 1 }
		if data.tr then
			data.tr.played += time
			equipTrainers(data) -- (the 3rd slot at the first alter)
		end
		return time / 60
	end
	-- the Growth Spurt itself (same as PlayerData.GrowthSpurt)
	for _, muscle in Muscles.List do data.muscles[muscle.id] = { level = 0, xp = 0 } end
	data.growthSpurts += 1
	if data.tr then
		data.tr.played += time
		if data.growthSpurts == TRAINERS_OPEN then data.tr.freeRolls += 1 end -- (the free first roll, TrainerService)
		equipTrainers(data)
	end
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

-- Coins per minute of active play (prompt 19: PUMP SHOP prices come from these): while playing toward each Growth
-- Spurt, and at 7'0" with grown muscles (10 minutes). Base rate: no 2x Coins pass, VIP, rush hour or event bonus.
--   lune run tests/pacing coins
if process.args[1] == "coins" then
	local rates = {}
	for seed = 1, PLAYERS do
		local data = newPlayer(seed)
		for n = 1, SPURTS do
			local before = data.coins
			local minutes = playOneSpurt(data, 0)
			rates[n - 1] = rates[n - 1] or {}
			table.insert(rates[n - 1], (data.coins - before) / minutes)
		end
		-- at 7'0": muscles grown past the last goal, 10 minutes of play
		for _, muscle in Muscles.List do data.muscles[muscle.id] = { level = 250, xp = 0 } end
		local before = data.coins
		local minutes = playOneSpurt(data, 0, 600)
		rates.max = rates.max or {}
		table.insert(rates.max, (data.coins - before) / minutes)
	end
	print("Coins per minute of active play (median of " .. PLAYERS .. " players; base, no boosts)")
	for n = 0, SPURTS - 1 do print(string.format("  Growth Spurt %d: %.0f", n, (median(rates[n])))) end
	print(string.format("  7'0\" max: %.0f", (median(rates.max))))
	return
end

-- Body Alters (prompt 21): players play up to 7'0", then through ALTERS alters; minutes per alter against
-- Alters.TargetMinutes.   lune run tests/pacing alters
if process.args[1] == "alters" then
	local ALTERS = tonumber(process.args[2]) or 10 -- (26 Oct: lune run tests/pacing alters 15)
	local per = {}
	for n = 1, ALTERS do per[n] = {} end
	for seed = 1, PLAYERS // 2 do
		local data = newPlayer(seed)
		for _ = 1, SPURTS do playOneSpurt(data, 0) end
		for n = 1, ALTERS do table.insert(per[n], playOneSpurt(data, 30, nil, Alters.Goal(n))) end
	end
	print("Body Alter pacing (minutes of play per alter, median of " .. (PLAYERS // 2) .. " players)")
	for n = 1, ALTERS do
		local mid, sorted = median(per[n])
		print(string.format("  alter %d (goal %d, bonus x%.2f before it): median %.1f, fastest 10%% %.1f, slowest 10%% %.1f",
			n, Alters.Goal(n), Alters.Bonus(n - 1), mid, at(sorted, 0.1), at(sorted, 0.9)))
	end
	return
end

-- (26 Oct) The whole game with trainers: Growth Spurts 1-6, then ALTERS alters, every player rolling trainers as above.
-- Prints the median minutes per step, the running total, and the typical equipped trainers when each step is done.
--   lune run tests/pacing trainers [alters = all with textures]
if process.args[1] == "trainers" then
	local ALTERS = tonumber(process.args[2]) or Alters.LastAvailable()
	local N = PLAYERS // 2
	local steps = {}
	for i = 1, SPURTS + ALTERS do steps[i] = { minutes = {}, gains = {}, progress = {}, rolls = {}, sets = {} } end
	for seed = 1, N do
		local data = newPlayer(seed)
		data.tr = { copies = {}, equipped = {}, pity = 0, freeRolls = 0, rolls = 0, played = 0, hourGifts = 0, bonus = Trainers.Bonus({}) }
		for i = 1, SPURTS + ALTERS do
			local minutes
			if i <= SPURTS then
				minutes = playOneSpurt(data, i == 1 and PLAY.Overhead or PLAY.SpurtOverhead)
			else
				minutes = playOneSpurt(data, 30, nil, Alters.Goal(i - SPURTS))
			end
			local step = steps[i]
			table.insert(step.minutes, minutes)
			table.insert(step.gains, data.tr.bonus.gains)
			table.insert(step.progress, data.tr.bonus.progress)
			table.insert(step.rolls, data.tr.rolls)
			local names = {}
			for _, copy in data.tr.equipped do
				table.insert(names, Trainers.ById[copy.id].name .. " " .. Trainers.Stages[copy.s].name .. " LV" .. copy.l)
			end
			table.insert(step.sets, table.concat(names, " + "))
		end
	end
	print(string.format("Whole game with trainers (median of %d players; all rep coins go to trainer rolls)", N))
	local total = 0
	for i, step in steps do
		local mid = median(step.minutes)
		total += mid
		local label = if i <= SPURTS then "Growth Spurt " .. i else "Alter " .. (i - SPURTS) .. " " .. Alters.Get(i - SPURTS).name
		-- the set of the player closest to the median EXP boost
		local g = median(step.gains)
		local pick = 1
		for j = 1, #step.gains do if math.abs(step.gains[j] - g) < math.abs(step.gains[pick] - g) then pick = j end end
		print(string.format("  %-22s %5.1f min  total %3dh%02d  rolls %4d  EXP +%3d%%  progress +%2d%%  e.g. %s", label, mid,
			math.floor(total / 60), math.floor(total % 60), (median(step.rolls)), math.floor(g * 100 + 0.5),
			math.floor((median(step.progress)) * 100 + 0.5), step.sets[pick]))
	end
	return
end

if process.args[1] == "tune" then
	-- one stage at a time: the earlier stages are already tuned, so only this stage's level moves its time
	-- (lune run tests/pacing tune 5: only from stage 5 on, searching near the current levels: much faster)
	local stages = GrowthSpurts.Stages
	local from = tonumber(process.args[2]) or 1
	for n = from, #stages do
		local target = GrowthSpurts.TargetMinutes(n)
		local lo, hi = (n > 1 and stages[n - 1].requiredLevel or 1), 600
		if from > 1 then lo, hi = math.max(lo, stages[n].requiredLevel - 10), stages[n].requiredLevel + 120 end
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

-- The 7'0" cap (owner, 13 Oct): no height past it, no spurt after reaching it, "7'0\" (MAX)" on screen
local maxSpurts = GrowthSpurts.MaxSpurts()
H.check(GrowthSpurts.GetHeight(maxSpurts) == GrowthSpurts.MaxHeightInches, "the last spurt lands exactly on 7'0\"")
H.check(not GrowthSpurts.IsMaxed(maxSpurts - 1) and GrowthSpurts.IsMaxed(maxSpurts), "maxed only from the last spurt")
for n = 0, 20 do
	H.check(GrowthSpurts.GetHeight(n) <= GrowthSpurts.MaxHeightInches, "no height past 7'0\" (spurt " .. n .. ")")
end
local full = { growthSpurts = maxSpurts + 3, muscles = {} } -- (an old save past the last spurt, every group far past its goal)
for _, muscle in Muscles.List do full.muscles[muscle.id] = { level = 5000, xp = 0 } end
local progress = GrowthSpurts.Progress(full, Muscles.Groups, Machines.TrainableMuscles(full.growthSpurts))
H.check(progress.maxed and not progress.ready and progress.met == progress.total, "at 7'0\" a spurt is never ready")
H.check(GrowthSpurts.FormatHeight(84) == "7'0\" (MAX)" and GrowthSpurts.FormatHeight(78) == "6'6\"", "height text")
H.done()
