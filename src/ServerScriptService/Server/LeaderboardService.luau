-- LeaderboardService (owner's feature run, task 4; numbers in Config.Leaderboards). Every Refresh seconds:
--   1. writes each player's values to the boards' OrderedDataStores (only when changed; never for Studio test players)
--   2. reads each board's top FetchCount, looks up the names of the top 10
--   3. publishes it all as JSON in ReplicatedStorage.LeaderboardData (one StringValue): LeaderboardClient draws the boards
--      near each player and works out "Your rank" from the list.
-- Boards: Biggest (average muscle look), Strongest (heaviest weight ever lifted), Tallest (height), Most reps today (a
-- new store each UTC day), Posing wins, Arm wrestling wins.
-- Studio: Workspace attribute TestLeaderboards = true fills every board with example rows (nothing is written).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Leaderboards = require(Config.Leaderboards)
local Machines = require(Config.Machines)
local Muscles = require(Config.Muscles)
local Economy = require(Config.Economy)
local GrowthSpurts = require(Config.GrowthSpurts)
local PlayerData = require(script.Parent.PlayerData)
local BodyService = require(script.Parent.BodyService)
local GameEvents = require(script.Parent.GameEvents)

local LeaderboardService = {}

local published: StringValue
local stores = {}   -- [store name] = OrderedDataStore
local written = {}  -- [player] = { [store name] = value written }
local names = {}    -- [userId] = display name

local function today(): number
	return Economy.Day(os.time())
end

local function store(name: string)
	if not stores[name] then stores[name] = DataStoreService:GetOrderedDataStore(name) end
	return stores[name]
end

local function nameOf(userId: number): string
	if names[userId] then return names[userId] end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or ("Lifter " .. userId)
	return names[userId]
end

------------------------------------------------------------------------
-- Values
------------------------------------------------------------------------
local function heaviestLift(data): number
	local best = 0
	for machineId, progress in pairs(data.machines or {}) do
		local machine = Machines.ById[machineId]
		local tier = machine and machine.tiers[progress.best or 0]
		if tier and not tier.unit and type(tier.weight) == "number" then best = math.max(best, tier.weight) end
	end
	return best
end

local function valueOf(player: Player, data, boardId: string): number
	if boardId == "Biggest" then
		local levels, goal = BodyService.LevelsOf(data)
		local looks = Muscles.LooksFromLevels(levels, goal)
		local sum, n = 0, 0
		for _, muscle in ipairs(Muscles.List) do
			sum += looks[muscle.id] or 0
			n += 1
		end
		return math.floor((n > 0 and sum / n or 0) * Leaderboards.SizeScale + 0.5)
	elseif boardId == "Strongest" then
		return heaviestLift(data)
	elseif boardId == "Tallest" then
		return math.floor(GrowthSpurts.GetHeight(data.growthSpurts or 0))
	elseif boardId == "RepsToday" then
		local today_ = data.repsToday
		return (type(today_) == "table" and today_.day == today()) and (today_.count or 0) or 0
	elseif boardId == "PosingWins" then
		return data.stats.posingWins or 0
	elseif boardId == "ArmWins" then
		return data.stats.armWins or 0
	end
	return 0
end

local function writeScores(player: Player)
	local data = PlayerData.Get(player)
	-- a Studio test (FreshPlayer) or failed-load session must never touch the real boards
	if not data or not PlayerData.IsPersistent(player) then return end
	local mine = written[player] or {}
	written[player] = mine
	local day = today()
	for _, board in ipairs(Leaderboards.Boards) do
		local name = Leaderboards.StoreName(board.id, day)
		local value = valueOf(player, data, board.id)
		if value > 0 and mine[name] ~= value then
			local ok = pcall(function() store(name):SetAsync(tostring(player.UserId), value) end)
			if ok then mine[name] = value end
		end
	end
end

------------------------------------------------------------------------
-- Reading and publishing
------------------------------------------------------------------------
local function readBoard(board, day)
	local ok, pages = pcall(function() return store(Leaderboards.StoreName(board.id, day)):GetSortedAsync(false, Leaderboards.FetchCount) end)
	if not ok or not pages then return nil end
	local ok2, list = pcall(function() return pages:GetCurrentPage() end)
	if not ok2 then return nil end
	local entries = {}
	for rank, entry in ipairs(list) do
		local userId = tonumber(entry.key)
		if userId then
			entries[rank] = { u = userId, v = entry.value, n = rank <= Leaderboards.Top and nameOf(userId) or nil }
		end
	end
	return entries
end

-- Example rows for screenshots and layout checks (Studio only): every board full, with the testers' own names.
local function testBoard(board)
	local players = Players:GetPlayers()
	local entries = {}
	local base = { Biggest = 260, Strongest = 455, Tallest = 84, RepsToday = 1840, PosingWins = 37, ArmWins = 112 }
	for rank = 1, 40 do
		local who = players[(rank - 1) % math.max(#players, 1) + 1]
		local value = base[board.id] or 100
		value = board.id == "Tallest" and math.max(48, value - (rank - 1) // 3 * 2) or math.max(1, math.floor(value * (1 - (rank - 1) * 0.022)))
		entries[rank] = { u = who and who.UserId or 1, v = value, n = rank <= Leaderboards.Top and ((who and who.DisplayName or "Lifter") .. " " .. rank) or nil }
	end
	return entries
end

local last = nil -- the last published boards (kept when a read fails)
local function refresh()
	local testing = RunService:IsStudio() and Workspace:GetAttribute("TestLeaderboards") == true
	if not testing then
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(writeScores, player)
			if not ok then warn("[LeaderboardService] write:", err) end
		end
	end
	local day = today()
	local boards = {}
	for _, board in ipairs(Leaderboards.Boards) do
		local entries = testing and testBoard(board) or readBoard(board, day)
		boards[board.id] = entries or (last and last[board.id]) or {}
	end
	last = boards
	published.Value = HttpService:JSONEncode({ day = day, at = os.time(), boards = boards })
end

------------------------------------------------------------------------
-- Reps today (counted here from GameEvents; saved so a rejoin keeps today's count)
------------------------------------------------------------------------
local function addRep(player: Player)
	local data = PlayerData.Get(player)
	if not data then return end
	local day = today()
	local entry = data.repsToday
	if type(entry) ~= "table" or entry.day ~= day then entry = { day = day, count = 0 } end
	entry.count += 1
	data.repsToday = entry -- (a plain field: no need to send every rep to the client)
end

function LeaderboardService.Start()
	published = ReplicatedStorage:FindFirstChild("LeaderboardData") :: StringValue
	if not published then
		local value = Instance.new("StringValue")
		value.Name = "LeaderboardData"
		value.Parent = ReplicatedStorage
		published = value
	end
	GameEvents.On("Rep", function(player) addRep(player) end)
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(pcall, writeScores, player)
		written[player] = nil
	end)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("TestLeaderboards"):Connect(function() task.spawn(refresh) end)
	end
	task.spawn(function()
		task.wait(Leaderboards.FirstRefresh)
		while true do
			local ok, err = pcall(refresh)
			if not ok then warn("[LeaderboardService] refresh:", err) end
			task.wait(Leaderboards.Refresh)
		end
	end)
end

return LeaderboardService
