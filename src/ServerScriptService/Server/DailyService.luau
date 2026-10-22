-- DailyService (owner's feature run, task 2): the daily quests (Config.DailyQuests) and the 7-day login calendar
-- (Config.Economy.Login). Everything is decided and paid here; the client only asks.
--   * Daily quests: PerDay quests a UTC day, picked per player. Progress comes from GameEvents (reps, treadmill metres,
--     spots, posing entries, arm wrestling wins). Claim each finished quest for coins; claiming them all unlocks a bonus.
--     Rerolls (owner, 14 Oct): DailyQuests.FreeRerollsPerDay free a day (dq.swaps, saved with the day), then each one is the
--     "Quest Reroll" product: the quest picked is remembered (dq.pendingReroll) BEFORE the client prompts the purchase, and
--     the reroll happens only in ProcessReceipt (DailyService.PaidReroll); a paid reroll that has no quest left to swap is
--     kept as a credit (stats.questRerollCredits) and used by the next reroll. DailyQuests.SwapFor never gives the same
--     quest, one of the other two, or one that needs another player.
--   * Login calendar: one claim per UTC day; the next calendar day if you claimed yesterday, else day 1. Days 4 and 7 add a
--     DNA token (Config/Economy.Login.DnaTokens); day 7 counts a week (stat loginWeeks: the "Dedicated" title). The claim
--     day is saved before anything is paid, so a claim can't be paid twice (rejoining, another server).
-- Studio: Workspace attribute TestLoginDay = n (see Start); TestDayOffset = n days added to today (fake the date).
-- Remote "Daily": client -> server "ClaimLogin" | "Claim", index | "ClaimBonus" | "Swap", index.
--                 server -> client (kind, info): "LoginClaimed", "QuestDone", "Claimed", "Swapped", "BuyReroll" (prompt the
--                 Quest Reroll purchase), "RerollFailed".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local DailyQuests = require(Config.DailyQuests)
local Economy = require(Config.Economy)
local Boosts = require(Config.Boosts)
local PlayerData = require(script.Parent.PlayerData)
local TitleService = require(script.Parent.TitleService)
local GameEvents = require(script.Parent.GameEvents)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local DailyService = {}

local remote: RemoteEvent

local IS_STUDIO = game:GetService("RunService"):IsStudio()
local function today(): number
	local offset = if IS_STUDIO then tonumber(game:GetService("Workspace"):GetAttribute("TestDayOffset")) or 0 else 0
	return Economy.Day(os.time() + offset * 86400)
end

local function send(player: Player, kind: string, info)
	if player.Parent then remote:FireClient(player, kind, info or {}) end
end

------------------------------------------------------------------------
-- Today's quests
------------------------------------------------------------------------
local function freshList(ids: { string })
	local list = {}
	for i, id in ipairs(ids) do list[i] = { id = id, progress = 0, done = false, claimed = false } end
	return list
end

-- Makes sure the player has today's quests (a new UTC day = a new set). Returns the table, and whether it changed.
local function ensure(player: Player)
	local data = PlayerData.Get(player)
	if not data then return nil, false end
	local dq = data.dailyQuests
	local day = today()
	if type(dq) ~= "table" or dq.day ~= day or type(dq.list) ~= "table" or #dq.list == 0 then
		dq = { day = day, list = freshList(DailyQuests.Pick(day, player.UserId, nil, data.growthSpurts or 0)), bonus = false, swaps = 0, groups = {} }
		PlayerData.SetTable(player, "dailyQuests", dq)
		return dq, true
	end
	return dq, false
end

local function save(player: Player, dq)
	PlayerData.SetTable(player, "dailyQuests", dq)
end

-- Something countable happened: move every matching quest along. events = { { kind, amount, info } } (one save for all).
local function step(player: Player, dq, kind: string, amount: number, info): boolean
	local changed = false
	if kind == "groups" then
		local group = info and info.group
		if type(group) ~= "string" or dq.groups[group] then return false end
		dq.groups[group] = true
		changed = true
	end
	for _, entry in ipairs(dq.list) do
		local quest = DailyQuests.ById[entry.id]
		if quest and not entry.done then
			local value = nil
			if quest.type == "groups" and kind == "groups" then
				local n = 0
				for _ in pairs(dq.groups) do n += 1 end
				value = n
			elseif quest.type == kind and (quest.type ~= "groupReps" or (info and info.group == quest.group)) then
				value = entry.progress + amount
			end
			if value then
				entry.progress = math.min(math.floor(value), quest.count)
				changed = true
				if entry.progress >= quest.count then
					entry.done = true
					send(player, "QuestDone", { text = quest.text })
				end
			end
		end
	end
	return changed
end

local function advance(player: Player, events)
	local dq = ensure(player)
	if not dq then return end
	local changed = false
	for _, e in ipairs(events) do
		if step(player, dq, e[1], e[2], e[3]) then changed = true end
	end
	if changed then save(player, dq) end
end

local function claim(player: Player, index: any)
	local dq = ensure(player)
	if not dq or type(index) ~= "number" then return end
	local entry = dq.list[index]
	local quest = entry and DailyQuests.ById[entry.id]
	if not quest or not entry.done or entry.claimed then return end
	entry.claimed = true
	local data = PlayerData.Get(player)
	local coins = DailyQuests.CoinsFor(quest, data and data.growthSpurts) -- (prompt 61)
	PlayerData.AddCoins(player, coins)
	save(player, dq)
	send(player, "Claimed", { coins = coins })
end

local function claimBonus(player: Player)
	local dq = ensure(player)
	if not dq or dq.bonus then return end
	for _, entry in ipairs(dq.list) do
		if not entry.claimed then return end
	end
	dq.bonus = true
	local data = PlayerData.Get(player)
	local coins = DailyQuests.BonusFor(data and data.growthSpurts) -- (prompt 61)
	PlayerData.AddCoins(player, coins)
	save(player, dq)
	send(player, "Claimed", { coins = coins, bonus = true })
end

-- Can this quest be rerolled? (there, not finished, not claimed)
local function rerollable(dq, index: any): boolean
	local entry = type(index) == "number" and dq.list[index]
	return type(entry) == "table" and not entry.done and not entry.claimed
end

-- Swaps quest `index` for a new one. Returns whether it happened.
local function reroll(player: Player, dq, index: number): boolean
	local current = {}
	for i, e in ipairs(dq.list) do current[i] = e.id end
	local data = PlayerData.Get(player)
	local id = DailyQuests.SwapFor(dq.day, player.UserId, current, (dq.swaps or 0) + (dq.paidRerolls or 0), data and data.growthSpurts or 0)
	if not id then return false end
	dq.list[index] = { id = id, progress = 0, done = false, claimed = false }
	-- a swapped-in "groups" quest counts the groups already trained today
	local quest = DailyQuests.ById[id]
	if quest and quest.type == "groups" then
		local n = 0
		for _ in pairs(dq.groups) do n += 1 end
		dq.list[index].progress = math.min(n, quest.count)
		dq.list[index].done = n >= quest.count
	end
	dq.pendingReroll = nil
	save(player, dq)
	send(player, "Swapped", { text = quest and quest.text or "" })
	return true
end

-- The player asks to reroll quest `index`: free while today's free one is left, then a saved credit, else remember the
-- quest and ask the client to prompt the purchase (the reroll itself happens in PaidReroll, after the receipt).
local function swap(player: Player, index: any)
	local dq = ensure(player)
	if not dq or not rerollable(dq, index) then
		send(player, "RerollFailed", {})
		return
	end
	local data = PlayerData.Get(player)
	if (dq.swaps or 0) < DailyQuests.FreeRerollsPerDay then
		dq.swaps = (dq.swaps or 0) + 1
		if not reroll(player, dq, index) then dq.swaps -= 1 end
		return
	end
	local credits = data and data.stats.questRerollCredits or 0
	if credits > 0 then
		if reroll(player, dq, index) then PlayerData.SetStat(player, "questRerollCredits", credits - 1) end
		return
	end
	dq.pendingReroll = { index = index, id = dq.list[index].id }
	save(player, dq)
	send(player, "BuyReroll", { index = index })
end

-- ProcessReceipt for the "Quest Reroll" product (MonetizationService): rerolls the remembered quest (or, if that one was
-- finished meanwhile, the first unfinished one); with nothing left to reroll it becomes a credit, so a purchase is never
-- lost. Returns true once granted.
function DailyService.PaidReroll(player: Player): boolean
	local dq = ensure(player)
	if not dq then return false end
	local pending = dq.pendingReroll
	local index = nil
	if type(pending) == "table" and rerollable(dq, pending.index) and dq.list[pending.index].id == pending.id then
		index = pending.index
	else
		for i in ipairs(dq.list) do
			if rerollable(dq, i) then index = i break end
		end
	end
	dq.paidRerolls = (dq.paidRerolls or 0) + 1
	if index and reroll(player, dq, index) then return true end
	dq.pendingReroll = nil
	save(player, dq)
	local data = PlayerData.Get(player)
	PlayerData.SetStat(player, "questRerollCredits", (data and data.stats.questRerollCredits or 0) + 1)
	send(player, "RerollCredit", {})
	return true
end

------------------------------------------------------------------------
-- Login calendar
------------------------------------------------------------------------
local function claimLogin(player: Player)
	local data = PlayerData.Get(player)
	if not data then return end
	local daily = data.daily
	local day = today()
	local calendarDay = Economy.LoginDay(daily.lastDay or 0, daily.calendarDay or 0, day)
	if not calendarDay then return end -- already claimed today
	local coins, tokens = Economy.LoginReward(calendarDay, data.growthSpurts) -- (prompt 61: at the player's stage)
	local streak = (daily.lastDay == day - 1) and (daily.streak or 0) + 1 or 1
	PlayerData.SetTable(player, "daily", { lastDay = day, streak = streak, best = math.max(daily.best or 0, streak), calendarDay = calendarDay })
	PlayerData.AddCoins(player, coins)
	if tokens > 0 then PlayerData.AddDnaTokens(player, tokens) end
	-- (prompt 14) boosts on some days, into the inventory (Config.Boosts.LoginItems)
	local items = Boosts.LoginItems[calendarDay]
	for id, amount in pairs(items or {}) do PlayerData.AddItem(player, id, amount) end
	if calendarDay == #Economy.Login.Coins then
		PlayerData.SetStat(player, "loginWeeks", (data.stats.loginWeeks or 0) + 1)
		TitleService.Check(player) -- "Dedicated"
	end
	send(player, "LoginClaimed", { day = calendarDay, coins = coins, tokens = tokens, items = items })
end

------------------------------------------------------------------------
function DailyService.Start()
	local existing = Remotes:FindFirstChild("Daily")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "Daily"
		created.Parent = Remotes
		remote = created
	end
	Guard.Remote(remote, "Daily", 4, 6, function(player, action, arg)
		if action == "ClaimLogin" then
			claimLogin(player)
		elseif action == "Claim" then
			claim(player, arg)
		elseif action == "ClaimBonus" then
			claimBonus(player)
		elseif action == "Swap" then
			swap(player, arg)
		end
	end)

	GameEvents.On("Rep", function(player, amount, info)
		local events = { { "reps", amount } }
		if info and info.group then
			table.insert(events, { "groupReps", amount, info })
			table.insert(events, { "groups", 1, info })
		end
		advance(player, events)
	end)
	GameEvents.On("CardioMeters", function(player, amount) advance(player, { { "cardio", amount } }) end)
	GameEvents.On("Spot", function(player, amount) advance(player, { { "spots", amount } }) end)
	GameEvents.On("PosingEntered", function(player, amount) advance(player, { { "posing", amount } }) end)
	GameEvents.On("ArmWrestleWon", function(player, amount) advance(player, { { "armWins", amount } }) end)

	PlayerData.Loaded:Connect(function(player) ensure(player) end)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Get(player) then ensure(player) end
	end
	-- Studio: Workspace attribute TestLoginDay = n makes today's claim calendar day n (as if days 1..n-1 were claimed)
	if game:GetService("RunService"):IsStudio() then
		game:GetService("Workspace"):GetAttributeChangedSignal("TestLoginDay"):Connect(function()
			local n = tonumber(game:GetService("Workspace"):GetAttribute("TestLoginDay"))
			if not n then return end
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data then
					PlayerData.SetTable(player, "daily", { lastDay = today() - 1, streak = n - 1, best = math.max(data.daily.best or 0, n - 1), calendarDay = n - 1 })
				end
			end
		end)
	end
	-- a new UTC day while playing: new quests (the calendar's claim opens by itself: the client sees the new day)
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(Players:GetPlayers()) do
				if PlayerData.Get(player) then ensure(player) end
			end
		end
	end)
end

return DailyService
