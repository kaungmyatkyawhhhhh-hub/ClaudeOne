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
local GrowthSpurts = require(Config.GrowthSpurts)
local Stamina = require(Config.Stamina)
local Titles = require(Config.Titles)
local Onboarding = require(Config.Onboarding)
local DataTemplate = require(script.Parent.DataTemplate)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local STORE_NAME = "PlayerData_xz"
local SESSION_ID = HttpService:GenerateGUID(false)
local LOCK_EXPIRY = 300 -- seconds; a lock older than this belongs to a crashed server
-- Studio playtests often stop before the lock is released; there, take over stale locks right away
-- (live servers keep the full expiry so two real servers never share a save).
if RunService:IsStudio() then
	LOCK_EXPIRY = 0
end
local AUTOSAVE_INTERVAL = 60
local BUDGET_RESERVE = 10 -- UpdateAsync requests kept free for loads and leave-saves before an autosave goes out
local LOAD_ATTEMPTS = 6 -- waits for another server to release the lock (e.g. quick rejoin)
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
				if lock and lock.id ~= SESSION_ID and os.time() - lock.time < LOCK_EXPIRY then
					lockedByOther = true
					return nil
				end
				lockedByOther = false
				stored.sessionLock = { id = SESSION_ID, time = os.time() }
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

-- Saves through UpdateAsync, refusing to overwrite a session another server now owns.
local function save(player, release)
	local profile = profiles[player]
	if not profile or not profile.canSave or profile.released then return false end
	if release then profile.released = true end

	local data = profile.data
	data.meta.lastSeen = os.time()
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
			out.sessionLock = (not release) and { id = SESSION_ID, time = os.time() } or nil
			return out
		end)
	end)

	if not ok then
		warn("[PlayerData] Save failed for", player.Name, err)
	elseif lostLock then
		warn("[PlayerData] Session for", player.Name, "is owned by another server; not saving")
		profile.canSave = false
		if player.Parent and not release then
			player:Kick("You joined from another server. Please rejoin!")
		end
	end
	return ok and not lostLock
end

local function onPlayerAdded(player)
	local data, reason = load(player)
	local canSave = data ~= nil

	if not player.Parent then
		-- Left while loading: release the lock we just took.
		if data then
			profiles[player] = { data = data, canSave = true }
			save(player, true)
			profiles[player] = nil
		end
		return
	end

	if not data then
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
	if RunService:IsStudio() and workspace:GetAttribute("FreshPlayer") then
		warn("[PlayerData] FreshPlayer: playing as a new player on temporary data. Progress will NOT save.")
		data = DataTemplate.new()
		canSave = false
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
	-- Studio testing: set a "ReplayTutorial" attribute (checked) on Workspace to see the genetics reveal and
	-- the tutorial again. Ignored on live servers.
	if RunService:IsStudio() and workspace:GetAttribute("ReplayTutorial") then
		data.onboarding.geneticsRevealed = false
		data.onboarding.tutorialStep = 1
	end
	if not data.genetics then
		data.genetics = Genetics.Roll()
	end
	if data.meta.firstJoin == 0 then
		data.meta.firstJoin = os.time()
	end
	data.meta.sessions += 1

	profiles[player] = { data = data, canSave = canSave }
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

-- Max stamina (Iron Lungs sets a bigger "MaxStamina" attribute on the player).
function PlayerData.GetMaxStamina(player)
	local bonus = player and player:GetAttribute("MaxStamina")
	return type(bonus) == "number" and bonus or Stamina.Max
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
	value = math.clamp(value, 0, PlayerData.GetMaxStamina(player))
	if value == data.stamina then return end
	data.stamina = value
	replicate(player, { "stamina" }, value)
end

-- Spends stamina if there is enough. Returns success.
function PlayerData.UseStamina(player, amount)
	local data = PlayerData.Get(player)
	if not data or data.stamina < amount then return false end
	PlayerData.SetStamina(player, data.stamina - amount)
	lastStaminaUse[player] = os.clock()
	return true
end

-- Natural refill; waits Stamina.RegenDelay after the last rep. `multiplier` = recovery stations and boosts.
function PlayerData.RegenStamina(player, dt, multiplier)
	local data = PlayerData.Get(player)
	if not data or data.stamina >= PlayerData.GetMaxStamina(player) then return end
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

function PlayerData.AddDnaTokens(player, amount)
	local data = PlayerData.Get(player)
	if not data then return false end
	data.dnaTokens += amount
	replicate(player, { "dnaTokens" }, data.dnaTokens)
	return true
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
	data.genetics = Genetics.Roll()
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
	return progress or { unlocked = 1, selected = 1 }
end

function PlayerData.SetMachine(player, machineId, unlocked, selected)
	local data = PlayerData.Get(player)
	if not data then return false end
	data.machines[machineId] = { unlocked = unlocked, selected = selected }
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
	data.dnaTokens += 1
	replicate(player, { "muscles" }, data.muscles)
	replicate(player, { "growthSpurts" }, data.growthSpurts)
	replicate(player, { "dnaTokens" }, data.dnaTokens)
	return true
end

function PlayerData.SetStat(player, stat, value)
	local data = PlayerData.Get(player)
	if not data then return end
	data.stats[stat] = value
	replicate(player, { "stats", stat }, value)
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

function PlayerData.AddShakes(player, amount)
	local data = PlayerData.Get(player)
	if not data or type(amount) ~= "number" then return false end
	if data.shakes + amount < 0 then return false end
	data.shakes += amount
	replicate(player, { "shakes" }, data.shakes)
	return true
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

-- Settings menu. Each field is optional and checked on its own: music/effects 0-1, gainNumbers On/Minimal/Off.
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
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
