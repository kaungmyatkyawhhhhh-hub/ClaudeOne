-- Showing off (Config.ShowOff): the leaderboard wall above the front desk (top 5 per muscle group, crown for #1),
-- the marble statue of the strongest player in the entrance hall, and emotes everyone can see (incl. high fives).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local ShowOff = require(Config.ShowOff)
local Muscles = require(Config.Muscles)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local ShowOffService = {}

local emoteRemote -- RemoteEvent "Emote": client -> server emoteId; server -> all clients (player, emoteId, seconds)
local stores = {}  -- [groupId | "Total"] = OrderedDataStore
local written = {} -- [player] = { [key] = score } last value written
local names = {}   -- [userId] = name
local statueUserId = nil

------------------------------------------------------------------------
-- Leaderboard board (built from code: a dark panel on the front wall)
------------------------------------------------------------------------
local board, columns = nil, {}

local function label(parent, props)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextColor3 = Theme.Colors.Text
	text.FontFace = Theme.Fonts.Regular
	text.TextScaled = true -- sign on a wall (SurfaceGui): the only kind of screen text that may scale
	text.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in pairs(props) do text[key] = value end
	text.Parent = parent
	return text
end

-- A small crown from frames: a base and three points.
local function crown(parent)
	local holder = Instance.new("Frame")
	holder.Name = "Crown"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.09, 0.8)
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.fromScale(0, 0.5)
	holder.Parent = parent
	local gold = Theme.Bumper.Yellow.Fill
	local base = Instance.new("Frame")
	base.BackgroundColor3 = gold
	base.BorderSizePixel = 0
	base.Size = UDim2.fromScale(1, 0.32)
	base.Position = UDim2.fromScale(0, 0.68)
	base.Parent = holder
	for i, x in ipairs({ 0.15, 0.5, 0.85 }) do
		local point = Instance.new("Frame")
		point.BackgroundColor3 = gold
		point.BorderSizePixel = 0
		point.AnchorPoint = Vector2.new(0.5, 0.5)
		point.Size = UDim2.fromScale(0.3, 0.36)
		point.SizeConstraint = Enum.SizeConstraint.RelativeYY
		point.Position = UDim2.fromScale(x, i == 2 and 0.42 or 0.52)
		point.Rotation = 45
		point.Parent = holder
	end
	return holder
end

local function buildBoard()
	local cfg = ShowOff.Leaderboard
	board = Instance.new("Part")
	board.Name = "LeaderboardWall"
	board.Size = Vector3.new(cfg.BoardSize.X, cfg.BoardSize.Y, 0.2)
	board.CFrame = CFrame.lookAt(cfg.BoardCenter, cfg.BoardCenter + Vector3.new(0, 0, -1)) -- faces into the gym
	board.Color = Theme.Colors.Panel
	board.Material = Enum.Material.SmoothPlastic
	board.Anchored = true
	board.CanCollide = false
	board.Parent = Workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.2
	gui.Parent = board
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.03, 0), UDim.new(0.03, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.Parent = root
	label(root, { Text = "Strongest lifters", FontFace = Theme.Fonts.SemiBold, Size = UDim2.fromScale(1, 0.13) })
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromScale(0, 0.18)
	grid.Size = UDim2.fromScale(1, 0.82)
	grid.Parent = root
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 3, -12, 0.5, -10)
	layout.CellPadding = UDim2.fromOffset(12, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for index, group in ipairs(Muscles.Groups) do
		local column = Instance.new("Frame")
		column.BackgroundTransparency = 1
		column.LayoutOrder = index
		column.Parent = grid
		label(column, { Text = group.name, FontFace = Theme.Fonts.SemiBold, TextColor3 = Theme.Colors.Muted, Size = UDim2.fromScale(1, 1 / 6) })
		local rows = {}
		for rank = 1, ShowOff.Leaderboard.Top do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromScale(0, rank / 6)
			row.Size = UDim2.fromScale(1, 1 / 6)
			row.Parent = column
			local nameLabel = label(row, { Text = rank .. "  -", Position = UDim2.fromScale(rank == 1 and 0.12 or 0, 0), Size = UDim2.fromScale(rank == 1 and 0.6 or 0.72, 1) })
			local levelLabel = label(row, { Text = "", Position = UDim2.fromScale(0.72, 0), Size = UDim2.fromScale(0.28, 1), TextXAlignment = Enum.TextXAlignment.Right })
			if rank == 1 then crown(row) end
			rows[rank] = { name = nameLabel, level = levelLabel }
		end
		columns[group.id] = rows
	end
end

local function nameOf(userId)
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
-- Scores
------------------------------------------------------------------------
local function store(key)
	if not stores[key] then
		stores[key] = DataStoreService:GetOrderedDataStore("Leaderboard_" .. key)
	end
	return stores[key]
end

local function writeScores(player)
	local data = PlayerData.Get(player)
	if not data then return end
	written[player] = written[player] or {}
	local sum = 0
	for _, group in ipairs(Muscles.Groups) do
		local level = Muscles.GetGroupLevel(data.muscles, group.id)
		sum += level
		local score = ShowOff.GroupScore(data.growthSpurts, level)
		if written[player][group.id] ~= score then
			local ok = pcall(function() store(group.id):SetAsync(tostring(player.UserId), score) end)
			if ok then written[player][group.id] = score end
		end
	end
	local total = ShowOff.TotalScore(data.growthSpurts, sum)
	if written[player].Total ~= total then
		local ok = pcall(function() store("Total"):SetAsync(tostring(player.UserId), total) end)
		if ok then written[player].Total = total end
	end
end

local function top(key, count)
	local ok, pages = pcall(function() return store(key):GetSortedAsync(false, count) end)
	if not ok or not pages then return {} end
	local ok2, list = pcall(function() return pages:GetCurrentPage() end)
	return ok2 and list or {}
end

local function refreshBoard()
	for _, group in ipairs(Muscles.Groups) do
		local entries = top(group.id, ShowOff.Leaderboard.Top)
		for rank, row in ipairs(columns[group.id]) do
			local entry = entries[rank]
			if entry then
				local spurts, level = ShowOff.SplitGroupScore(entry.value)
				row.name.Text = rank .. "  " .. nameOf(tonumber(entry.key))
				row.level.Text = "Lv " .. level .. (spurts > 0 and (" · GS" .. spurts) or "")
			else
				row.name.Text = rank .. "  -"
				row.level.Text = ""
			end
		end
	end
end

------------------------------------------------------------------------
-- Statue of the strongest player
------------------------------------------------------------------------
local statue = nil
local function buildPedestal()
	local cfg = ShowOff.Statue
	local pedestal = Instance.new("Part")
	pedestal.Name = "StatuePedestal"
	pedestal.Size = Vector3.new(3.4, 1.2, 3.4)
	pedestal.CFrame = CFrame.new(cfg.Spot + Vector3.new(0, 0.6, 0))
	pedestal.Color = Color3.fromHex("#2B2B2B")
	pedestal.Material = Enum.Material.Slate
	pedestal.Anchored = true
	pedestal.Parent = Workspace
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- faces +X, toward the middle of the hall
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = pedestal
	local text = label(gui, { Name = "Plaque", Text = "Strongest lifter", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.Colors.Text })
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.25, 0), UDim.new(0.25, 0)
	pad.Parent = text
	return pedestal, text
end

local plaque = nil
local function refreshStatue()
	local entries = top("Total", 1)
	local entry = entries[1]
	if not entry then return end
	local userId = tonumber(entry.key)
	if userId == statueUserId and statue and statue.Parent then return end
	local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
	if not ok or not desc then return end
	local okModel, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not okModel or not model then return end
	statueUserId = userId
	if statue then statue:Destroy() end
	statue = model
	model.Name = "Statue"
	local cfg = ShowOff.Statue
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.Material = cfg.Material
			item.Color = cfg.Color
			item.CanCollide = false
			if item:IsA("MeshPart") then item.TextureID = "" end
		elseif item:IsA("SpecialMesh") then
			item.TextureId = ""
		elseif item:IsA("Decal") or item:IsA("Clothing") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	pcall(function() model:ScaleTo(cfg.Scale) end)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then model.PrimaryPart = root end
	local hip = humanoid and humanoid.HipHeight or 2
	local rootHalf = root and root.Size.Y / 2 or 1
	-- on the pedestal, facing the middle of the hall (+X)
	local base = cfg.Spot + Vector3.new(0, 1.2, 0)
	model:PivotTo(CFrame.lookAt(base, base + Vector3.new(1, 0, 0)) + Vector3.new(0, hip + rootHalf, 0))
	model.Parent = Workspace
	if plaque then plaque.Text = "Strongest lifter: " .. nameOf(userId) end
end

------------------------------------------------------------------------
-- Emotes
------------------------------------------------------------------------
local lastEmote = {}
local highFives = {} -- [player] = os.clock() of their last high five

local function busy(player)
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == player.UserId then return true end
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Sit or humanoid.Health <= 0
end

function ShowOffService.PlayEmote(player, emoteId)
	local emote = ShowOff.EmoteById[emoteId]
	if not emote or not emoteRemote or busy(player) then return false end
	emoteRemote:FireAllClients(player, emote.id, emote.seconds)
	return true
end

local function onEmote(player, emoteId)
	if type(emoteId) ~= "string" or emoteId == "Chug" then return end
	local now = os.clock()
	if now - (lastEmote[player] or 0) < 1 then return end
	lastEmote[player] = now
	if not ShowOffService.PlayEmote(player, emoteId) then return end
	if emoteId ~= "HighFive" then return end
	-- two high fives close together = a real high five
	highFives[player] = now
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for other, at in pairs(highFives) do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot and now - at <= ShowOff.HighFive.Window and (otherRoot.Position - root.Position).Magnitude <= ShowOff.HighFive.Range then
			highFives[player], highFives[other] = nil, nil
			Remotes.PlayerEvent:FireClient(player, "HighFived", { name = other.DisplayName })
			Remotes.PlayerEvent:FireClient(other, "HighFived", { name = player.DisplayName })
			break
		end
	end
end

function ShowOffService.Start()
	emoteRemote = Remotes:FindFirstChild("Emote")
	if not emoteRemote then
		emoteRemote = Instance.new("RemoteEvent")
		emoteRemote.Name = "Emote"
		emoteRemote.Parent = Remotes
	end
	emoteRemote.OnServerEvent:Connect(onEmote)
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(writeScores, player)
		written[player], lastEmote[player], highFives[player] = nil, nil, nil
	end)

	buildBoard()
	_, plaque = buildPedestal()
	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in ipairs(Players:GetPlayers()) do writeScores(player) end
			refreshBoard()
			refreshStatue()
			task.wait(ShowOff.Leaderboard.Refresh)
		end
	end)
end

return ShowOffService
