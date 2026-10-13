-- LeaderboardClient (owner's feature run, task 4): fills the leaderboard panels (parts tagged "LeaderboardPanel", built by
-- tools/builders/Leaderboards) from ReplicatedStorage.LeaderboardData, which LeaderboardService publishes every
-- Config.Leaderboards.Refresh seconds. Only the panels that are streamed in (near you) exist on this client, so only
-- those are drawn: on new data, and when a panel streams in. Each row: rank, the player's headshot, name, value; under
-- the board "Your rank: #N" (or "You're #3!" in the top 10, "100+" when you're not in the fetched list).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Leaderboards"))

local player = Players.LocalPlayer
local data = nil -- the decoded LeaderboardData: { day, at, boards = { [id] = { { u, v, n }, ... } } }

local function headshot(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", userId)
end

local function draw(panel: Instance)
	local boardId = panel:GetAttribute("Board")
	local gui = panel:FindFirstChild("Board")
	if not boardId or not gui then return end
	local entries = data and data.boards and data.boards[boardId] or {}
	local myRank = nil
	for rank, entry in ipairs(entries) do
		if entry.u == player.UserId then
			myRank = rank
			break
		end
	end
	for i = 1, Leaderboards.Top do
		local row = gui:FindFirstChild("Row" .. i)
		if row then
			local entry = entries[i]
			local name, value, head = row:FindFirstChild("Name"), row:FindFirstChild("Value"), row:FindFirstChild("Head")
			if name then
				name.Text = entry and (entry.n or "Lifter") or "-"
				name.TextColor3 = (entry and entry.u == player.UserId) and Color3.fromHex("#DCEEFF") or Color3.new(1, 1, 1)
			end
			if value then value.Text = entry and Leaderboards.Format(boardId, entry.v) or "" end
			if head and head:IsA("ImageLabel") then head.Image = entry and headshot(entry.u) or "" end
		end
	end
	local you = gui:FindFirstChild("You")
	if you then you.Text = data and Leaderboards.YourRankText(myRank) or "Loading..." end
end

local function drawAll()
	for _, panel in ipairs(CollectionService:GetTagged("LeaderboardPanel")) do
		local ok, err = pcall(draw, panel)
		if not ok then warn("[LeaderboardClient]", err) end
	end
end

local function load(value: StringValue)
	local function read()
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
		if ok and type(decoded) == "table" then
			data = decoded
			drawAll()
		end
	end
	value.Changed:Connect(read)
	if value.Value ~= "" then read() end
end

task.spawn(function()
	local value = ReplicatedStorage:WaitForChild("LeaderboardData", 120)
	if value and value:IsA("StringValue") then load(value) end
end)

-- a panel streaming in (walking up to a board) is drawn at once from the last data
CollectionService:GetInstanceAddedSignal("LeaderboardPanel"):Connect(function(panel)
	task.defer(function()
		if panel.Parent then draw(panel) end
	end)
end)
drawAll()
