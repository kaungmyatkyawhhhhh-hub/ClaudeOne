-- Leaderboards (owner's feature run, task 4): six boards, top 10 each, on a wall in the starter gym, the pro gym and a
-- freestanding one in the town plaza (tools/builders/Leaderboards: parts tagged "LeaderboardPanel" with a Board
-- attribute). LeaderboardService writes OrderedDataStores (all-time, and a key per UTC day for "today") and publishes
-- each board's top FetchCount to every client; LeaderboardClient fills only the panels that are streamed in near you,
-- with "Your rank: #N" under each board when you're not in the top 10.
-- (The older per-muscle-group wall above the front desk and the statue are ShowOffService's, unchanged.)
local Leaderboards = {}

Leaderboards.Refresh = 90     -- seconds between writes / reads (60-120 keeps every server inside the DataStore limits)
Leaderboards.FirstRefresh = 12 -- seconds after the server starts
Leaderboards.Top = 10         -- rows on a board
Leaderboards.FetchCount = 100 -- entries read per board: "Your rank" is exact inside these, "100+" below
Leaderboards.StorePrefix = "LB1_" -- OrderedDataStore names: LB1_<board id> (daily boards: LB1_<id>_<UTC day number>)

-- The boards, in the order they hang on the walls.
--   daily = true: a fresh store every UTC day
Leaderboards.Boards = {
	{ id = "Biggest", title = "Biggest", sub = "Most muscle" },
	{ id = "Strongest", title = "Strongest", sub = "Heaviest lift ever" },
	{ id = "Tallest", title = "Tallest", sub = "Height" },
	{ id = "RepsToday", title = "Most reps", sub = "Today", daily = true },
	{ id = "PosingWins", title = "Posing wins", sub = "All time" },
	{ id = "ArmWins", title = "Arm wrestling", sub = "Wins" },
}
Leaderboards.ById = {}
for index, board in ipairs(Leaderboards.Boards) do
	board.order = index
	Leaderboards.ById[board.id] = board
end

-- "Biggest" stores the average muscle look (Muscles.LookG, 1 = the full aesthetic look) x this, as a whole number.
Leaderboards.SizeScale = 100

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- How a stored value reads on a board.
function Leaderboards.Format(boardId: string, value: number): string
	value = math.floor(value or 0)
	if boardId == "Biggest" then
		return "Size " .. commas(value)
	elseif boardId == "Strongest" then
		return commas(value) .. " lb"
	elseif boardId == "Tallest" then
		return string.format("%d'%d\"", value // 12, value % 12)
	elseif boardId == "RepsToday" then
		return commas(value) .. " reps"
	elseif boardId == "PosingWins" or boardId == "ArmWins" then
		return commas(value) .. (value == 1 and " win" or " wins")
	end
	return commas(value)
end

-- The store name of a board (daily boards get today's UTC day number).
function Leaderboards.StoreName(boardId: string, day: number): string
	local board = Leaderboards.ById[boardId]
	if board and board.daily then return Leaderboards.StorePrefix .. boardId .. "_" .. day end
	return Leaderboards.StorePrefix .. boardId
end

-- "Your rank" line: rank = your place in the fetched list (nil = not in it), inTop = shown on the board already.
function Leaderboards.YourRankText(rank: number?): string
	if not rank then return "Your rank: " .. Leaderboards.FetchCount .. "+" end
	if rank <= Leaderboards.Top then return "You're #" .. rank .. "!" end
	return "Your rank: #" .. rank
end

return Leaderboards
