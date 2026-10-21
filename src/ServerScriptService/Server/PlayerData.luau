-- Loads, saves and mutates player data. All writes go through this module so the
-- server stays authoritative and every change is replicated to the owning client.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Muscles = require(Config.Muscles)
local Genetics = require(Config.Genetics)
local Body = require(Config.Body)
local GrowthSpurts = require(Config.GrowthSpurts)
local Stamina = require(Config.Stamina)
local Monetization = require(Config.Monetization)
local Titles = require(Config.Titles)
local Onboarding = require(Config.Onboarding)
local DataTemplate = require(script.Parent.DataTemplate)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local STORE_NAME = "GymArcDataStoreV1" -- (owner, 9 Oct: fresh store for the release; the old test saves stay in "PlayerData_1")
local SESSION_ID = HttpService:GenerateGUID(false)
local LOCK_EXPIRY = 180 -- seconds; a lock older than this belongs to a crashed server (live locks are refreshed by every 60 s autosave)
-- Studio playtests often stop before the lock is released; there, take over stale locks right away
-- (live servers keep the full expiry so two real servers never share a save).
local IS_STUDIO = RunService:IsStudio()
if IS_STUDIO then
	LOCK_EXPIRY = 0
end
local function newLock()
	return { id = SESSION_ID, time = os.time(), studio = IS_STUDIO or nil }
end
local AUTOSAVE_INTERVAL = 60
local BUDGET_RESERVE = 10 -- UpdateAsync requests kept free for loads and leave-saves before an autosave goes out
local LOAD_ATTEMPTS = 12 -- waits (up to ~60 s, behind the loading screen) for another server to release the lock (e.g. quick rejoin)
local LOAD_LOCK_WAIT = 5
local CALL_ATTEMPTS = 5

local store = DataStoreService:GetDataStore(STORE_NAME)

local PlayerData = {}

local loadedEvent = Instance.new("BindableEvent")
PlayerData.Loaded = loadedEvent.Event -- (player, data)

local profiles = {} -- [player] = { data, canSave, released }
local lastStaminaUse = {} -- [player] = os.clock() of the last rep

local function storeKey(player)
	return "Player_" .. player.UserId
end

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in pairs(value) do copy[k] = deepCopy(v) end
	return copy
end

-- Fill in fields missing from older saves without touching existing values.
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(data[k]) == "table" and type(v) == "table" then
			reconcile(data[k], v)
		end
	end
end

-- Runs a DataStore call with exponential backoff.
local function withRetries(fn)
	local lastError
	for attempt = 1, CALL_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastError = result
		-- 403 = API access disabled (Studio setting); retrying won't help
		if string.find(tostring(result), "403", 1, true) then break end
		if attempt < CALL_ATTEMPTS then
			task.wait(math.min(2 ^ attempt, 16))
		end
	end
	return false, lastError
end

local function replicate(player, path, value)
	Remotes.DataChanged:FireClient(player, path, deepCopy(value))
end

local function snapshot(data)
	local copy = deepCopy(data)
	copy.sessionLock = nil
	return copy
end

-- Loads and claims the session lock. Returns data or nil + reason ("error" | "locked" | "left").
local function load(player)
	for _ = 1, LOAD_ATTEMPTS do
		local lockedByOther = false
		local ok, result = withRetries(function()
			return store:UpdateAsync(storeKey(player), function(stored)
				stored = stored or DataTemplate.new()
				local lock = stored.sessionLock
				-- a lock left by a Studio playtest never blocks a live server (Studio often stops before releasing it;
				-- if that playtest is still running, its next save sees the new owner and stops saving)
				local studioLock = type(lock) == "table" and lock.studio == true and not IS_STUDIO
				if lock and lock.id ~= SESSION_ID and not studioLock and os.time() - lock.time < LOCK_EXPIRY then
					lockedByOther = true
					return nil
				end
				lockedByOther = false
				stored.sessionLock = newLock()
				return stored
			end)
		end)
		if not ok then
			warn("[PlayerData] Load failed for", player.Name, result)
			return nil, "error"
		end
		if not lockedByOther then return result end
		task.wait(LOAD_LOCK_WAIT)
		if not player.Parent then return nil, "left" end
	end
	return nil, "locked"
end

local savesInFlight = 0 -- saves currently talking to the DataStore (the shutdown handler waits for them)

-- Saves through UpdateAsync, refusing to overwrite a session another server now owns.
-- Clears this server's session lock without writing any data (sessions that don't save, e.g. Studio TestMuscleExp,
-- must still let go of the save, or the next server waits out the lock and kicks the player).
local function releaseLock(player)
	savesInFlight += 1
	local ok, err = withRetries(function()
		return store:UpdateAsync(storeKey(player), function(stored)
			if type(stored) ~= "table" or not stored.sessionLock or stored.sessionLock.id ~= SESSION_ID then return nil end
			stored.sessionLock = nil
			return stored
		end)
	end)
	if not ok then warn("[PlayerData] Couldn't release the session lock for", player.Name, err) end
	savesInFlight -= 1
end

-- (prompt 21) Best physique: the biggest body this player ever had (more Growth Spurts, or the same and more EXP), so a
-- Body Alter (muscles back to 25%) never makes the statue or the Total board smaller. Kept up to date on every save and
-- right before an alter.
local function updateBest(data)
	if type(data.alter) ~= "table" or type(data.muscles) ~= "table" then return end
	local exp = Muscles.TotalExp(data.muscles)
	local best = data.alter.best
	local spurts = data.growthSpurts or 0
	if type(best) == "table" and ((best.spurts or 0) > spurts or ((best.spurts or 0) == spurts and (best.exp or 0) >= exp)) then
		return
	end
	local levels = {}
	for id, entry in pairs(data.muscles) do levels[id] = entry.level or 0 end
	data.alter.best = { muscles = levels, spurts = spurts, alter = data.alter.highest or 0, exp = exp }
end
PlayerData.UpdateBest = updateBest

local function save(player, release)
	local profile = profiles[player]
	if not profile or profile.released then return false end
	if not profile.canSave then
		if release and profile.ownsLock then
			profile.released = true
			releaseLock(player)
		end
		return false
	end
	if release then profile.released = true end
	savesInFlight += 1

	local data = profile.data
	data.meta.lastSeen = os.time()
	pcall(updateBest, data)
	local lostLock = false
	local ok, err = withRetries(function()
		return store:UpdateAsync(storeKey(player), function(stored)
			if stored and stored.sessionLock and stored.sessionLock.id ~= SESSION_ID then
				lostLock = true
				return nil
			end
			lostLock = false
			-- An autosave still in flight after the release must not re-lock the session.
			if not release and profile.released then
				return nil
			end
			local out = deepCopy(data)
			out.sessionLock = (not release) and newLock() or nil
			return out
		end)
	end)

	if not ok then
		warn("[PlayerData] Save failed for", player.Name, err)
	elseif lostLock then
		warn("[PlayerData] Session for", player.Name, "is owned by another server; not saving")
		profile.canSave = false
		profile.ownsLock = false
		if player.Parent and not release then
			player:Kick("You joined from another server. Please rejoin!")
		end
	end
	savesInFlight -= 1
	return ok and not lostLock
end

local clampedToMax = 0 -- saves past the 7'0" cap seen by this server
local OVER_CAP_EXP = 10000000 -- (owner, 14 Oct) shown EXP added to every muscle of a save past the cap, once
local function onPlayerAdded(player)
	-- Studio FreshPlayer sessions never touch the real save (not even its lock)
	local fresh = IS_STUDIO and workspace:GetAttribute("FreshPlayer") == true
	local data, reason
	if not fresh then data, reason = load(player) end
	local canSave = data ~= nil
	local ownsLock = data ~= nil

	if not player.Parent then
		-- Left while loading: release the lock we just took.
		if data then
			profiles[player] = { data = data, canSave = true }
			save(player, true)
			profiles[player] = nil
		end
		return
	end

	if not data and not fresh then
		if RunService:IsStudio() then
			warn("[PlayerData] Using temporary data in Studio (" .. reason .. "). Progress will NOT save.")
			data = DataTemplate.new()
		else
			player:Kick(reason == "locked"
				and "Your data is still saving from another server. Please rejoin in a minute!"
				or "We couldn't load your data. Please rejoin!")
			return
		end
	end

	-- Studio testing: a "FreshPlayer" attribute (checked) on Workspace plays as a brand-new player (4'0", level 0,
	-- tutorial) on temporary data that is never saved, so the real save stays untouched. Ignored on live servers.
	if fresh then
		warn("[PlayerData] FreshPlayer: playing as a new player on temporary data. Progress will NOT save.")
		data = DataTemplate.new()
		canSave = false
		-- optional "TestCoins" (number) attribute: start with that many coins (to test the stores)
		local testCoins = workspace:GetAttribute("TestCoins")
		if type(testCoins) == "number" then data.coins = math.max(0, math.floor(testCoins)) end
		-- optional "TestSpurts" (number) attribute: start after that many Growth Spurts (to test the pro gym)
		local testSpurts = workspace:GetAttribute("TestSpurts")
		if type(testSpurts) == "number" then data.growthSpurts = math.clamp(math.floor(testSpurts), 0, 20) end
		-- optional "TestMuscleShare" (0 to 6 times the goal's EXP; there is no level cap; 2 = full look, 5 = mass monster) and "TestMuscleIds" ("Biceps,Triceps", default all): start with those muscles at that
		-- share of the Growth Spurt goal (to test the muscle blobs). Changing TestMuscleShare while playing updates the muscles.
		-- An entry can carry its own share ("Abs=0.7,MidChest=0.7"): those muscles get that, the rest of the list TestMuscleShare.
		local function applyTestMuscles()
			local share = workspace:GetAttribute("TestMuscleShare")
			if type(share) ~= "number" then return end
			local goal = GrowthSpurts.GetGoal(data.growthSpurts)
			local only = workspace:GetAttribute("TestMuscleIds")
			local listed = nil -- [id] = its share (nil list = every muscle at TestMuscleShare)
			if type(only) == "string" and only ~= "" then
				listed = {}
				for item in string.gmatch(only, "[^,]+") do
					local id, own = string.match(item, "^%s*([%w_]+)%s*=%s*([%d%.]+)%s*$")
					if id then listed[id] = tonumber(own) else listed[(string.gsub(item, "%s", ""))] = share end
				end
			end
			for id, entry in pairs(data.muscles) do
				local wanted = if listed then listed[id] else share
				entry.level = if wanted then math.ceil(Muscles.LevelFromXp(math.clamp(wanted, 0, 6) * Muscles.CumXp(goal)) - 1e-6) else 0
			end
			if player.Parent then replicate(player, { "muscles" }, data.muscles) end
		end
		applyTestMuscles()
		workspace:GetAttributeChangedSignal("TestMuscleShare"):Connect(applyTestMuscles)
		workspace:GetAttributeChangedSignal("TestMuscleIds"):Connect(applyTestMuscles)
	end

	-- Studio testing: a "TestMuscleExp" number attribute on Workspace (e.g. 2000000) puts every muscle at that much EXP
	-- on your OWN save (to see the big look), with saving off for the session so the real save stays untouched.
	local testExp = if RunService:IsStudio() then workspace:GetAttribute("TestMuscleExp") else nil
	if type(testExp) == "number" and testExp > 0 then
		warn("[PlayerData] TestMuscleExp: every muscle at " .. testExp .. " EXP for this session. Progress will NOT save.")
		canSave = false
		local xp = testExp / Muscles.ExpPerXp
		local level = math.floor(Muscles.LevelFromXp(xp))
		for _, muscle in ipairs(Muscles.List) do
			local entry = data.muscles and data.muscles[muscle.id]
			if entry then
				entry.level = level
				entry.xp = math.max(0, math.floor(xp - Muscles.CumXp(level)))
			end
		end
	end

	-- Saves from before the tutorial existed: players who already lifted skip it.
	local onboarding = data.onboarding
	if onboarding and onboarding.tutorialStep == nil and data.stats and (data.stats.totalReps or 0) > 0 then
		onboarding.tutorialStep = Onboarding.Done
	end
	-- read the saved tutorial version before reconcile fills in the template's (current) one
	local savedTutorialVersion = onboarding and onboarding.tutorialVersion or 1
	reconcile(data, DataTemplate.new())
	-- Tutorial v1 had 8 steps and saved 9 for "finished"; v2 added the Coach step before the last one.
	if savedTutorialVersion < Onboarding.Version then
		local step = data.onboarding.tutorialStep
		if step >= 9 then
			data.onboarding.tutorialStep = Onboarding.Done
		elseif step == 8 then
			data.onboarding.tutorialStep = 9 -- the Goal step moved from 8 to 9
		end
		data.onboarding.tutorialVersion = Onboarding.Version
	end
	data.sessionLock = nil
	-- (prompt 14, 21 Oct) the Energy Shakes in the bag are the inventory's Protein Shakes now: moved over, nothing lost
	if type(data.shakes) == "number" and data.shakes > 0 then
		data.items.Shake = (tonumber(data.items.Shake) or 0) + data.shakes
		data.shakes = 0
	end
	-- 7'0" cap (owner, 13 Oct): height comes from the spurt count (GrowthSpurts.GetHeight clamps it). A save from before
	-- the cap with MORE spurts than the last one (owner, 14 Oct): once, +OVER_CAP_EXP shown EXP on every muscle, and the
	-- spurt count goes back to the last one (6). The count then isn't past the cap any more, so this never runs twice.
	local maxSpurts = GrowthSpurts.MaxSpurts()
	if (data.growthSpurts or 0) > maxSpurts then
		clampedToMax += 1
		local before = data.growthSpurts
		local extraXp = OVER_CAP_EXP / Muscles.ExpPerXp -- (shown EXP -> the save's xp)
		for _, muscle in ipairs(Muscles.List) do
			local entry = data.muscles[muscle.id]
			if type(entry) == "table" then
				local total = Muscles.EntryXp(entry) + extraXp
				local level = math.floor(Muscles.LevelFromXp(total))
				-- (float safety: never a level whose xp is above the total)
				while level > 0 and Muscles.CumXp(level) > total do level -= 1 end
				entry.level = level
				entry.xp = total - Muscles.CumXp(level)
			end
		end
		data.growthSpurts = maxSpurts
		print(string.format("[PlayerData] %s was past the height cap (Growth Spurt %d): +%s EXP on every muscle, Growth Spurt set to %d. This server: %d",
			player.Name, before, Muscles.FormatExp(OVER_CAP_EXP), maxSpurts, clampedToMax))
	end
	-- The beach gym's own machines are gone (owner, 8 Oct night: it uses the real machines): their weight progress moves to
	-- the real machine (same tier sets, so the same tier numbers; the higher of the two is kept)
	for oldId, newId in pairs(require(Config.Machines).Renamed) do
		local old = data.machines[oldId]
		if type(old) == "table" then
			local new = data.machines[newId]
			if type(new) ~= "table" then
				data.machines[newId] = old
			else
				new.unlocked = math.max(new.unlocked or 1, old.unlocked or 1)
				new.best = math.max(new.best or 0, old.best or 0)
				new.selected = math.min(new.selected or old.selected or 1, new.unlocked)
			end
			data.machines[oldId] = nil
		end
		if data.machinesUsed[oldId] then
			data.machinesUsed[newId] = true
			data.machinesUsed[oldId] = nil
		end
	end
	-- Studio testing: set a "ReplayTutorial" attribute (checked) on Workspace to see the genetics reveal and
	-- the tutorial again. Ignored on live servers.
	if RunService:IsStudio() and workspace:GetAttribute("ReplayTutorial") then
		data.onboarding.geneticsRevealed = false
		data.onboarding.tutorialStep = 1
	end
	if not data.genetics then
		data.genetics = PlayerData.TestGenetics("TestGenetics") or Genetics.Roll()
	end
	if data.meta.firstJoin == 0 then
		data.meta.firstJoin = os.time()
	end
	data.meta.sessions += 1

	profiles[player] = { data = data, canSave = canSave, ownsLock = ownsLock }
	PlayerData.RefreshMaxStamina(player)
	player:SetAttribute("DataLoaded", true)
	loadedEvent:Fire(player, data)
end

local function onPlayerRemoving(player)
	save(player, true)
	profiles[player] = nil
	lastStaminaUse[player] = nil
end

-- Saves right away (e.g. after a Robux purchase, before telling Roblox it was granted). True when it's stored.
function PlayerData.SaveNow(player)
	return save(player, false)
end

-- Reading -----------------------------------------------------------------

-- Returns the live data table, or nil if not loaded. Treat as read-only outside this module.
-- True when this player's progress is really saved (false for Studio FreshPlayer sessions, failed loads and lost locks).
-- Anything that writes shared DataStores on the player's behalf (leaderboards, crews) must check it first.
function PlayerData.IsPersistent(player)
	local profile = profiles[player]
	return profile ~= nil and profile.canSave == true
end

function PlayerData.Get(player)
	local profile = profiles[player]
	return profile and profile.data
end

function PlayerData.WaitFor(player, timeout)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent and not profiles[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	return PlayerData.Get(player)
end

-- A read-only look at any player's save, for copies of their body (the statue): their live data when they're in this
-- server, else the stored copy (no session lock, never written; nil when there's none or the read failed).
function PlayerData.Peek(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local live = player and PlayerData.Get(player)
	if live then return live end
	local ok, stored = withRetries(function() return store:GetAsync("Player_" .. userId) end)
	if ok and type(stored) == "table" then return stored end
	return nil
end

-- Max stamina: trained by cardio (Stamina.MaxFor the distance run) x Iron Lungs; kept on the player's "MaxStamina"
-- attribute so clients read the same number.
function PlayerData.GetMaxStamina(player)
	local max = player and player:GetAttribute("MaxStamina")
	return type(max) == "number" and max or Stamina.Max
end

function PlayerData.RefreshMaxStamina(player)
	local data = PlayerData.Get(player)
	if not data then return end
	local lungs = if player:GetAttribute("Pass_IronLungs") then Monetization.Effects.IronLungsMax else 1
	-- (prompt 24) the equipped trainers' max stamina boost (TrainerService writes data.trainers.bonus)
	local bonus = type(data.trainers) == "table" and type(data.trainers.bonus) == "table" and tonumber(data.trainers.bonus.maxStamina) or 0
	player:SetAttribute("MaxStamina", Stamina.MaxFor(data.stats.cardioMeters) * lungs * (1 + bonus))
end

function PlayerData.GetLevelCap(player)
	return GrowthSpurts.GetLevelCap(PlayerData.Get(player).growthSpurts)
end

-- Writing -----------------------------------------------------------------

function PlayerData.AddCoins(player, amount)
	local data = PlayerData.Get(player)
	if not data then return false end
	data.coins += amount
	replicate(player, { "coins" }, data.coins)
	return true
end

-- Returns false if the player can't afford it.
function PlayerData.SpendCoins(player, amount)
	local data = PlayerData.Get(player)
	if not data or amount < 0 or data.coins < amount then return false end
	data.coins -= amount
	replicate(player, { "coins" }, data.coins)
	return true
end

-- Adds XP to one muscle, levelling up until the Growth Spurt cap. Returns levels gained.
function PlayerData.AddMuscleXp(player, muscleId, xp)
	local data = PlayerData.Get(player)
	assert(Muscles.ById[muscleId], "Unknown muscle: " .. tostring(muscleId))
	if not data or xp <= 0 then return 0 end

	local muscle = data.muscles[muscleId]
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	if muscle.level >= cap then return 0 end

	local before = muscle.level
	muscle.xp += xp
	while muscle.level < cap and muscle.xp >= Muscles.XpToNext(muscle.level) do
		muscle.xp -= Muscles.XpToNext(muscle.level)
		muscle.level += 1
	end
	if muscle.level >= cap then
		muscle.xp = 0
	end
	replicate(player, { "muscles", muscleId }, muscle)
	return muscle.level - before
end

function PlayerData.SetStamina(player, value)
	local data = PlayerData.Get(player)
	if not data then return end
	local max = PlayerData.GetMaxStamina(player)
	value = math.clamp(value, 0, max)
	-- (a full bar ends recovering: a shake, Endless Stamina, a refill)
	if value >= max and player:GetAttribute("StaminaRecovering") then player:SetAttribute("StaminaRecovering", nil) end
	if value == data.stamina then return end
	data.stamina = value
	replicate(player, { "stamina" }, value)
end

-- Spends stamina if there is enough. Returns success. (Endless Stamina: costs nothing and stays full.)
function PlayerData.UseStamina(player, amount)
	local data = PlayerData.Get(player)
	if not data then return false end
	if (data.endlessStamina or 0) > 0 then
		PlayerData.SetStamina(player, PlayerData.GetMaxStamina(player))
		return true
	end
	-- recovering (Stamina.Pacing): no reps until the bar is full again; running out starts it
	if player:GetAttribute("StaminaRecovering") then return false end
	if data.stamina < amount then
		player:SetAttribute("StaminaRecovering", true)
		return false
	end
	PlayerData.SetStamina(player, data.stamina - amount)
	lastStaminaUse[player] = os.clock()
	return true
end

-- Endless Stamina (owner, 14 Oct; product 3718306417): data.endlessStamina = seconds left. It counts down only while
-- the player is in a server (StaminaService calls TickEndlessStamina every second) and is saved with the rest, so leaving
-- keeps the rest. While it's above 0 reps cost nothing and stamina stays full (UseStamina). The client reads the
-- player's "EndlessStaminaUntil" attribute (the server time it ends) for its timer and the gold stamina bar.
local function showEndless(player, data)
	local left = data.endlessStamina or 0
	player:SetAttribute("EndlessStaminaUntil", if left > 0 then workspace:GetServerTimeNow() + left else nil)
end

function PlayerData.EndlessStaminaLeft(player): number
	local data = PlayerData.Get(player)
	return data and data.endlessStamina or 0
end

-- adds time (a purchase), at most maxSeconds in all
function PlayerData.AddEndlessStamina(player, seconds, maxSeconds)
	local data = PlayerData.Get(player)
	if not data or type(seconds) ~= "number" or seconds <= 0 then return false end
	data.endlessStamina = math.min((data.endlessStamina or 0) + seconds, maxSeconds)
	showEndless(player, data)
	PlayerData.SetStamina(player, PlayerData.GetMaxStamina(player))
	return true
end

function PlayerData.TickEndlessStamina(player, dt)
	local data = PlayerData.Get(player)
	local left = data and data.endlessStamina or 0
	if left <= 0 then return end
	left = math.max(0, left - dt)
	data.endlessStamina = left
	if left <= 0 or not player:GetAttribute("EndlessStaminaUntil") then showEndless(player, data) end -- (ended / just joined)
	if left > 0 then PlayerData.SetStamina(player, PlayerData.GetMaxStamina(player)) end
end

-- Natural refill; waits Stamina.RegenDelay after the last rep. `multiplier` = recovery stations and boosts.
-- Recovering (the player's "StaminaRecovering" attribute): refills from empty to full in the pacing's refillSeconds with no
-- delay, then reps work again.
function PlayerData.RegenStamina(player, dt, multiplier)
	local data = PlayerData.Get(player)
	if not data then return end
	local max = PlayerData.GetMaxStamina(player)
	if data.stamina >= max then
		if player:GetAttribute("StaminaRecovering") then player:SetAttribute("StaminaRecovering", nil) end
		return
	end
	if player:GetAttribute("StaminaRecovering") then
		local rate = max / Stamina.PacingFor(data.growthSpurts).refillSeconds
		PlayerData.SetStamina(player, data.stamina + rate * dt * (multiplier or 1))
		if data.stamina >= max then player:SetAttribute("StaminaRecovering", nil) end
		return
	end
	if os.clock() - (lastStaminaUse[player] or 0) < Stamina.RegenDelay then return end
	PlayerData.SetStamina(player, data.stamina + Stamina.RegenPerSecond * dt * (multiplier or 1))
end

-- Returns true if the title was newly granted.
function PlayerData.GrantTitle(player, titleId)
	local data = PlayerData.Get(player)
	assert(Titles.ById[titleId], "Unknown title: " .. tostring(titleId))
	if not data or data.titles.owned[titleId] then return false end
	data.titles.owned[titleId] = os.time()
	replicate(player, { "titles", "owned", titleId }, data.titles.owned[titleId])
	return true
end

-- Pass nil to unequip. Only owned titles can be equipped.
function PlayerData.EquipTitle(player, titleId)
	local data = PlayerData.Get(player)
	if not data or (titleId ~= nil and not data.titles.owned[titleId]) then return false end
	data.titles.equipped = titleId
	replicate(player, { "titles", "equipped" }, titleId)
	return true
end

-- (only three callers, Config/DNA: a Growth Spurt, a coin buy, a Robux purchase)
function PlayerData.AddDnaTokens(player, amount)
	local data = PlayerData.Get(player)
	if not data or type(amount) ~= "number" or amount < 1 or amount % 1 ~= 0 then return false end
	data.dnaTokens = math.max(0, data.dnaTokens or 0) + amount
	replicate(player, { "dnaTokens" }, data.dnaTokens)
	return true
end

-- Studio testing: the Workspace attribute `attribute` ("TestGenetics" for the first roll, "TestRerollGenetics" for rerolls)
-- = six grades in group order, e.g. "C,B,A,S,S,D", forces those grades (frame and body type stay random). nil otherwise.
function PlayerData.TestGenetics(attribute)
	if not RunService:IsStudio() then return nil end
	local text = workspace:GetAttribute(attribute)
	if type(text) ~= "string" or text == "" then return nil end
	local list = string.split(text, ",")
	local rolled = Genetics.Roll()
	for index, group in ipairs(Muscles.Groups) do
		local grade = list[index] and string.upper((string.gsub(list[index], "%s", "")))
		if grade and Genetics.GradeById[grade] then rolled.grades[group.id] = grade end
	end
	-- an optional 7th entry picks the frame (e.g. "C,B,A,S,S,D,VTaper")
	local frame = list[#Muscles.Groups + 1] and (string.gsub(list[#Muscles.Groups + 1], "%s", ""))
	if frame and Genetics.FrameById[frame] then rolled.frame = frame end
	rolled.overall = Genetics.GetOverallGrade(rolled.grades)
	return rolled
end

-- Rerolls all genetics, spending the free reroll first, then a DNA Token.
function PlayerData.RerollGenetics(player)
	local data = PlayerData.Get(player)
	if not data then return false end
	if data.freeReroll then
		data.freeReroll = false
		replicate(player, { "freeReroll" }, false)
	elseif data.dnaTokens > 0 then
		data.dnaTokens -= 1
		replicate(player, { "dnaTokens" }, data.dnaTokens)
	else
		return false
	end
	local previous = data.genetics
	data.genetics = PlayerData.TestGenetics("TestRerollGenetics") or Genetics.Roll()
	-- Gene Lock pass: the best group keeps its grade (if the new roll is worse)
	if player:GetAttribute("Pass_GeneLock") and previous and previous.grades then
		local multOf = {}
		for _, grade in ipairs(Genetics.Grades) do multOf[grade.id] = grade.mult end
		local bestGroup, bestMult = nil, -math.huge
		for groupId, grade in pairs(previous.grades) do
			if (multOf[grade] or 0) > bestMult then bestGroup, bestMult = groupId, multOf[grade] or 0 end
		end
		if bestGroup and (multOf[data.genetics.grades[bestGroup]] or 0) < bestMult then
			data.genetics.grades[bestGroup] = previous.grades[bestGroup]
			data.genetics.overall = Genetics.GetOverallGrade(data.genetics.grades)
		end
	end
	replicate(player, { "genetics" }, data.genetics)
	return true
end

-- Weight tier progress for one machine (defaults to the first tier).
function PlayerData.GetMachine(player, machineId)
	local data = PlayerData.Get(player)
	local progress = data and data.machines[machineId]
	return progress or { unlocked = 1, selected = 1, best = nil }
end

-- best = heaviest tier ever lifted on it (personal record); nil keeps the current one.
-- The first rep on a machine (the machine signs stop showing it as "NEW").
function PlayerData.MarkMachineUsed(player, machineId)
	local data = PlayerData.Get(player)
	if not data or type(machineId) ~= "string" or data.machinesUsed[machineId] then return end
	data.machinesUsed[machineId] = true
	replicate(player, { "machinesUsed", machineId }, true)
end

function PlayerData.SetMachine(player, machineId, unlocked, selected, best)
	local data = PlayerData.Get(player)
	if not data then return false end
	local old = data.machines[machineId]
	data.machines[machineId] = { unlocked = unlocked, selected = selected, best = best or (old and old.best) }
	replicate(player, { "machines", machineId }, data.machines[machineId])
	return true
end

-- Growth Spurt: if every group meets the goal, muscles reset to 0, the spurt count goes up
-- (taller + permanent gains bonus via Config) and you get a DNA Token. Returns success.
function PlayerData.GrowthSpurt(player)
	local data = PlayerData.Get(player)
	if not data then return false end
	local Machines = require(Config.Machines)
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts))
	if not progress.ready then return false end
	for _, muscle in ipairs(Muscles.List) do
		data.muscles[muscle.id] = { level = 0, xp = 0 }
	end
	data.growthSpurts += 1
	data.dnaTokens = math.max(0, data.dnaTokens or 0) + require(Config.DNA).PerGrowthSpurt -- (the free token, once per spurt)
	replicate(player, { "muscles" }, data.muscles)
	replicate(player, { "growthSpurts" }, data.growthSpurts)
	replicate(player, { "dnaTokens" }, data.dnaTokens)
	return true
end

-- (prompt 21) A Body Alter, when its goal is met (Config.Alters.Progress: at 7'0", the next alter has textures): every
-- muscle keeps Alters.KeepShare of its EXP, the alter count goes up and the new skin is worn. Never loses progress: the
-- save is written first (if that fails, nothing changes) and again right after. Returns the new alter number or nil.
function PlayerData.Alter(player): number?
	local data = PlayerData.Get(player)
	if not data then return nil end
	local Machines = require(Config.Machines)
	local Alters = require(Config.Alters)
	local progress = Alters.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts))
	if not progress.ready then return nil end
	updateBest(data)
	if PlayerData.IsPersistent(player) and not save(player, false) then return nil end
	if not PlayerData.Get(player) then return nil end -- (left while saving)
	local kept = {}
	for _, muscle in ipairs(Muscles.List) do kept[muscle.id] = Alters.Kept(data.muscles[muscle.id]) end
	data.muscles = kept
	local state = Alters.State(data)
	data.alter = { highest = progress.next, equipped = progress.next, best = state.best }
	replicate(player, { "muscles" }, data.muscles)
	replicate(player, { "alter" }, data.alter)
	task.spawn(function()
		if PlayerData.IsPersistent(player) then save(player, false) end
	end)
	return progress.next
end

-- (prompt 21) Wear any alter skin up to the highest one (0 = Natural); the gains bonus stays the highest's.
function PlayerData.EquipAlter(player, n): boolean
	local data = PlayerData.Get(player)
	if not data or type(n) ~= "number" or n % 1 ~= 0 then return false end
	local Alters = require(Config.Alters)
	local state = Alters.State(data)
	if n < 0 or n > (state.highest or 0) then return false end
	data.alter = { highest = state.highest or 0, equipped = n, best = state.best }
	replicate(player, { "alter" }, data.alter)
	return true
end

function PlayerData.SetStat(player, stat, value)
	local data = PlayerData.Get(player)
	if not data then return end
	data.stats[stat] = value
	replicate(player, { "stats", stat }, value)
	if stat == "cardioMeters" then PlayerData.RefreshMaxStamina(player) end
end

function PlayerData.SetFlag(player, flag, value)
	local data = PlayerData.Get(player)
	if not data then return end
	data.onboarding[flag] = value
	replicate(player, { "onboarding", flag }, value)
end

-- Replace one top-level table (e.g. "daily", "welcome") owned and validated by a service.
function PlayerData.SetTable(player, key, value)
	local data = PlayerData.Get(player)
	if not data or type(value) ~= "table" then return end
	data[key] = value
	replicate(player, { key }, value)
end

-- Quest state is owned by QuestService (it validates everything); this only stores and replicates it.
function PlayerData.SetQuests(player, quests)
	local data = PlayerData.Get(player)
	if not data then return end
	data.quests = quests
	replicate(player, { "quests" }, quests)
end

-- Inventory items (Config.Boosts; ItemService uses them): add `amount` (negative = use). Returns false when there aren't
-- enough, or for an unknown item.
function PlayerData.AddItem(player, id, amount)
	local data = PlayerData.Get(player)
	local Boosts = require(Config.Boosts)
	if not data or not Boosts.ById[id] or type(amount) ~= "number" or amount % 1 ~= 0 then return false end
	local now = tonumber(data.items[id]) or 0
	if now + amount < 0 then return false end
	data.items[id] = math.min(now + amount, Boosts.MaxCount)
	replicate(player, { "items", id }, data.items[id])
	return true
end

-- Protein Shakes (the old Energy Shakes): the inventory's "Shake" item (prompt 14)
function PlayerData.AddShakes(player, amount)
	return PlayerData.AddItem(player, "Shake", amount)
end
function PlayerData.ShakeCount(player): number
	local data = PlayerData.Get(player)
	return data and tonumber(data.items.Shake) or 0
end

-- Tutorial progress only moves forward (any step up to Onboarding.Done); no rewards hang on it.
function PlayerData.SetTutorialStep(player, step)
	local data = PlayerData.Get(player)
	if not data or type(step) ~= "number" or step ~= math.floor(step) then return false end
	if step <= data.onboarding.tutorialStep or step > Onboarding.Done then return false end
	data.onboarding.tutorialStep = step
	replicate(player, { "onboarding", "tutorialStep" }, step)
	return true
end

-- Sound volume settings (0-1 each), clamped here so the client can't store anything odd.
local GAIN_NUMBERS = { On = true, Minimal = true, Off = true }
local REP_FLASH = { On = true, Off = true }
local EXP_POPUPS = { On = true, Off = true }
local SPOT_REQUESTS = { On = true, Off = true }
local ON_OFF = { On = true, Off = true }
local INVENTORY_TABS = { Boosts = true, Gear = true, Alters = true, Titles = true, Auras = true, Items = true }

-- Settings menu. Each field is optional and checked on its own: music/effects 0-1, gainNumbers On/Minimal/Off,
-- repFlash On/Off, expPopups On/Off.
function PlayerData.SetSettings(player, settings)
	local data = PlayerData.Get(player)
	if not data or type(settings) ~= "table" then return end
	local function volume(value)
		if type(value) ~= "number" or value ~= value then return nil end -- not a number / NaN
		return math.clamp(math.floor(value * 100 + 0.5) / 100, 0, 1)
	end
	local new = table.clone(data.settings)
	new.music = volume(settings.music) or new.music
	new.effects = volume(settings.effects) or new.effects
	if GAIN_NUMBERS[settings.gainNumbers] then new.gainNumbers = settings.gainNumbers end
	if REP_FLASH[settings.repFlash] then new.repFlash = settings.repFlash end
	if EXP_POPUPS[settings.expPopups] then new.expPopups = settings.expPopups end
	if SPOT_REQUESTS[settings.spotRequests] then new.spotRequests = settings.spotRequests end
	new.statsLabels = nil -- the world stats labels are gone; drop the old saved choice
	-- (prompt 19) PUMP SHOP colors (shop = true) only once bought: cosmetics.owned["Top_<id>"] / ["Shorts_<id>"]
	local owned = type(data.cosmetics) == "table" and type(data.cosmetics.owned) == "table" and data.cosmetics.owned or {}
	for _, entry in ipairs(Body.Tops) do -- wardrobe: Shirtless / Tank top / Sports top
		if entry.id == settings.top and (not entry.shop or owned["Top_" .. entry.id]) then new.top = entry.id end
	end
	for _, entry in ipairs(Body.ShortsColors) do
		if entry.id == settings.shorts and (not entry.shop or owned["Shorts_" .. entry.id]) then new.shorts = entry.id end
	end
	if settings.pumpHintSeen == true then new.pumpHintSeen = true end -- one-way: the "Tap to pump" hint never comes back
	if settings.skateHintSeen == true then new.skateHintSeen = true end -- one-way: the "Tap to skate" hint, once per player
	-- (UI v2, 13 Oct) the left menu folded away; Settings toggles: tutorial / coach hints, other players' scream sounds and
	-- auras, low graphics; (final kit, 14 Oct) reduce motion: the UI's looping pulses / shines stop
	if type(settings.menuCollapsed) == "boolean" then new.menuCollapsed = settings.menuCollapsed end
	if type(settings.rightCollapsed) == "boolean" then new.rightCollapsed = settings.rightCollapsed end -- (the right cards folded)
	-- the Inventory window's last tab (owner, 14 Oct: remembered)
	if INVENTORY_TABS[settings.inventoryTab] then new.inventoryTab = settings.inventoryTab end
	-- the newest update notes the player opened (main menu UPDATES red dot; a short stamp like "14 Oct")
	if type(settings.updatesSeen) == "string" and #settings.updatesSeen <= 24 then new.updatesSeen = settings.updatesSeen end
	-- (prompt 16) the dumbbell picker's last exercise (shown first)
	if type(settings.dumbbellLast) == "string" and #settings.dumbbellLast <= 24 and string.match(settings.dumbbellLast, "^DB%w+$") then
		new.dumbbellLast = settings.dumbbellLast
	end
	for _, key in ipairs({ "hints", "otherScreams", "otherAuras", "otherTrainers", "lowGraphics", "reduceMotion" }) do
		if ON_OFF[settings[key]] then new[key] = settings[key] end
	end
	data.settings = new
	replicate(player, { "settings" }, new)
end

-- Lifecycle ---------------------------------------------------------------

function PlayerData.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Remotes.GetData.OnServerInvoke = function(player)
		-- the client asks once per join (and retries while loading); a full copy of the save is not free
		if not Guard.Allow(player, "getdata", 0.5, 5) then return nil end
		local data = PlayerData.WaitFor(player)
		return data and snapshot(data)
	end

	-- Autosave: each player once per AUTOSAVE_INTERVAL, spread evenly over it (no burst every minute), and only while
	-- the server has UpdateAsync budget to spare, so joins and leaves (load/release) always get through.
	task.spawn(function()
		while true do
			local list = {}
			for player in pairs(profiles) do table.insert(list, player) end
			if #list == 0 then
				task.wait(AUTOSAVE_INTERVAL)
			else
				local gap = AUTOSAVE_INTERVAL / #list
				for _, player in ipairs(list) do
					task.wait(gap)
					while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync) < BUDGET_RESERVE do
						task.wait(1)
					end
					if profiles[player] then task.spawn(save, player, false) end
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		-- (also waits for saves that started earlier, e.g. a player who left a moment ago)
		while (pending > 0 or savesInFlight > 0) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
