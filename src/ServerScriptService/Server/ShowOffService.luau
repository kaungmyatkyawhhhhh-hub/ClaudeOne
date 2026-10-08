-- Showing off (Config.ShowOff): the leaderboard wall above the front desk (top 5 per muscle group, crown for #1),
-- the marble statue of the strongest player in the entrance hall, and emotes everyone can see: held bodybuilding poses
-- (PoseData + the "Pose" attribute, judged on the posing stage) and high fives.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local ShowOff = require(Config.ShowOff)
local Muscles = require(Config.Muscles)
local GrowthSpurts = require(Config.GrowthSpurts)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local BodyShape = require(ReplicatedStorage.Shared.BodyShape)
local PoseApply = require(ReplicatedStorage.Shared.PoseApply)
local PoseData = require(ReplicatedStorage:WaitForChild("PoseData"))
local Town = require(Config.Town)
local BodyService = require(script.Parent.BodyService)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local ShowOffService = {}

local emoteRemote -- RemoteEvent "Emote": client -> server emoteId; server -> all clients (player, emoteId, seconds)
local stores = {}  -- [groupId | "Total"] = OrderedDataStore
local written = {} -- [player] = { [key] = score } last value written
local names = {}   -- [userId] = name
local statueUserId = nil
local statueSpurts = nil

------------------------------------------------------------------------
-- Leaderboard board (built in Studio: Workspace.LeaderboardWall, made with tools/builders/ShowOff.luau)
------------------------------------------------------------------------
local columns = {} -- [groupId][rank] = { name = TextLabel, level = TextLabel }

local function findBoard()
	local board = Workspace:WaitForChild("LeaderboardWall", 10)
	if not board then return false end
	for _, group in ipairs(Muscles.Groups) do
		local column = board:FindFirstChild(group.id, true)
		if not column then return false end
		local rows = {}
		for rank = 1, ShowOff.Leaderboard.Top do
			local row = column:FindFirstChild("Rank" .. rank)
			if row then rows[rank] = { name = row:FindFirstChild("Name"), level = row:FindFirstChild("Level") } end
		end
		columns[group.id] = rows
	end
	return true
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
		stores[key] = DataStoreService:GetOrderedDataStore("LeaderboardV1_" .. key) -- (V1: fresh for the release, 9 Oct)
	end
	return stores[key]
end

local function writeScores(player)
	local data = PlayerData.Get(player)
	if not data then return end
	-- a Studio test (FreshPlayer) or failed-load session must never overwrite the real leaderboards
	if not PlayerData.IsPersistent(player) then return end
	-- a local reference: the player can leave (and their entry be cleared) while a SetAsync below is in flight
	local mine = written[player] or {}
	written[player] = mine
	local sum = 0
	for _, group in ipairs(Muscles.Groups) do
		local level = Muscles.GetGroupLevel(data.muscles, group.id)
		sum += level
		local score = ShowOff.GroupScore(data.growthSpurts, level)
		if mine[group.id] ~= score then
			local ok = pcall(function() store(group.id):SetAsync(tostring(player.UserId), score) end)
			if ok then mine[group.id] = score end
		end
	end
	local total = ShowOff.TotalScore(data.growthSpurts, sum)
	if mine.Total ~= total then
		local ok = pcall(function() store("Total"):SetAsync(tostring(player.UserId), total) end)
		if ok then mine.Total = total end
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
		for rank, row in ipairs(columns[group.id] or {}) do
			local entry = entries[rank]
			if entry then
				local spurts, level = ShowOff.SplitGroupScore(entry.value)
				row.name.Text = rank .. "  " .. nameOf(tonumber(entry.key))
				row.level.Text = Muscles.FormatExp(Muscles.Shown(level)) .. " exp" .. (spurts > 0 and (" · GS" .. spurts) or "")
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
-- The pedestal is built in Studio (Workspace.StatuePedestal with a "Plaque" label).
local function findPlaque()
	local pedestal = Workspace:WaitForChild("StatuePedestal", 10)
	return pedestal and pedestal:FindFirstChild("Plaque", true)
end

local plaque = nil

-- The statue strikes the front double biceps (PoseData), set once on the joints; every part is then placed from them.
local function flexPose(model)
	PoseApply.Apply(model, PoseData.FrontDoubleBiceps, 1)
end

-- Rebuilds the statue from the strongest player's avatar (or a plain default body while there's no leader yet):
-- a real R15 rig from the HumanoidDescription, all marble, posed, then every part placed from its joints and anchored
-- (anchoring before the joints are solved is what left gaps and a missing head before).
local function refreshStatue()
	local entry = top("Total", 1)[1]
	local userId = entry and tonumber(entry.key) or 0
	-- the statue is as tall as that player is (their Growth Spurts; the Total score carries the count)
	local spurts = entry and entry.value // 1000000 or 0
	if userId == statueUserId and spurts == statueSpurts and statue and statue.Parent then return end
	local desc = nil
	if userId > 0 then
		local ok, result = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
		if ok then desc = result end
	end
	desc = desc or Instance.new("HumanoidDescription") -- default rig
	-- the strongest lifter: the Robloxian 2.0 body, fully grown muscle blobs (all made marble below)
	BodyService.PrepareDescription(desc, nil, GrowthSpurts.GetHeight(spurts) / BodyShape.BaseHeight)
	local okModel, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not okModel or not model then
		warn("[ShowOffService] Could not build the statue:", model)
		return
	end
	statueUserId = userId
	statueSpurts = spurts
	if statue then statue:Destroy() end
	statue = model
	model.Name = "Statue"
	BodyShape.EnsureJoints(model)
	BodyShape.ApplyProportions(model, true)
	local cfg = ShowOff.Statue
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BaseScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Material = cfg.Material
			item.Color = cfg.Color
			item.CanCollide = false
			item.CastShadow = true
			if item:IsA("MeshPart") then item.TextureID = "" end
		elseif item:IsA("SpecialMesh") then
			item.TextureId = ""
		elseif item:IsA("Decal") or item:IsA("Clothing") or item:IsA("ShirtGraphic") or item:IsA("SurfaceAppearance") then
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
	if root then root.CFrame = CFrame.lookAt(base, base + Vector3.new(1, 0, 0)) + Vector3.new(0, hip + rootHalf, 0) end
	flexPose(model)
	BodyShape.SolveJoints(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = true end
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = Workspace
	-- the clients draw the full-grown marble muscles (muscle v7) from these attributes
	model:SetAttribute("MuscleG", BodyService.EncodeShare(1))
	model:SetAttribute("MuscleMarble", true)
	if plaque then
		plaque.Text = userId > 0 and ("Strongest lifter: " .. nameOf(userId)) or "Strongest lifter: could be you"
	end
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

------------------------------------------------------------------------
-- Held poses (PoseData): the character attribute "Pose" makes every client pose that character (PoseController). While
-- posing the player can't walk or jump; the client asks to let go when they try to move (PoseClient), and machines,
-- skating, death and the time limit let go too.
------------------------------------------------------------------------
local posed = {} -- [player] = { walkSpeed, jumpPower, jumpHeight, token }
local poseCounter = 0

function ShowOffService.ReleasePose(player)
	local state = posed[player]
	posed[player] = nil
	local character = player.Character
	if character and character:GetAttribute("Pose") ~= nil and character:GetAttribute("Pose") ~= "" then
		character:SetAttribute("Pose", "")
	end
	if state and character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = state.walkSpeed, state.jumpPower, state.jumpHeight
		end
	end
end

-- The judges on the posing stage score a pose that is held there: how developed the muscles it shows off are (0 to 10).
local function onStage(root)
	local stage = Town.Stage
	local half = stage.Size / 2 + Vector3.new(ShowOff.PoseJudge.Margin, 0, ShowOff.PoseJudge.Margin)
	local offset = root.Position - stage.Center
	return math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z and offset.Y < 14
end

local function judge(player, emote, token)
	local state = posed[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local data = PlayerData.Get(player)
	if not state or state.token ~= token or not root or not data or not onStage(root) then return end
	local goal = math.max(GrowthSpurts.GetGoal(data.growthSpurts or 0), 1)
	local total = 0
	for _, id in ipairs(emote.muscles) do
		local entry = data.muscles and data.muscles[id]
		total += math.clamp((entry and entry.level or 0) / goal, 0, 1)
	end
	local share = total / #emote.muscles
	local score = math.floor((1 + 9 * share) * 2 + 0.5) / 2 -- 1 to 10 in halves
	Remotes.PlayerEvent:FireClient(player, "PoseScore", { name = emote.name, score = score })
end

function ShowOffService.SetPose(player, emote)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not emote or not emote.poseData or not PoseData[emote.poseData] or not humanoid or busy(player) then return false end
	if player:GetAttribute("Skating") == true then return false end
	local state = posed[player]
	if not state then
		state = { walkSpeed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight }
		posed[player] = state
	end
	poseCounter += 1 -- (one counter for the whole server: timers from an earlier pose or character can never match a new one)
	state.token = poseCounter
	local token = state.token
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
	character:SetAttribute("Pose", emote.poseData)
	task.delay(ShowOff.PoseJudge.Delay, judge, player, emote, token)
	task.delay(ShowOff.PoseMaxSeconds, function()
		if posed[player] and posed[player].token == token then ShowOffService.ReleasePose(player) end
	end)
	return true
end

function ShowOffService.PlayEmote(player, emoteId)
	local emote = ShowOff.EmoteById[emoteId]
	if not emote or not emoteRemote or busy(player) then return false end
	if player:GetAttribute("Skating") == true then return false end -- (a skater's joints belong to the skate pose)
	if emote.poseData then return ShowOffService.SetPose(player, emote) end
	ShowOffService.ReleasePose(player)
	emoteRemote:FireAllClients(player, emote.id, emote.seconds)
	return true
end

local function onEmote(player, emoteId)
	if emoteId == "" then -- the player moved or jumped: let go of the pose
		ShowOffService.ReleasePose(player)
		return
	end
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
	Guard.Remote(emoteRemote, "Emote", 4, 6, onEmote)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function() posed[player] = nil end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterRemoving:Connect(function() posed[player] = nil end)
	end
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(writeScores, player)
		written[player], lastEmote[player], highFives[player], posed[player] = nil, nil, nil, nil
	end)

	if not findBoard() then
		warn("[ShowOffService] Workspace.LeaderboardWall is missing: build it in Studio with tools/builders/ShowOff.luau")
	end
	plaque = findPlaque()
	task.spawn(function()
		task.wait(10)
		while true do
			-- (each step protected: one error must not stop the leaderboard and statue for the rest of the server's life)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(writeScores, player)
				if not ok then warn("[ShowOffService] writeScores:", err) end
			end
			local okBoard, errBoard = pcall(refreshBoard)
			if not okBoard then warn("[ShowOffService] refreshBoard:", errBoard) end
			local okStatue, errStatue = pcall(refreshStatue)
			if not okStatue then warn("[ShowOffService] refreshStatue:", errStatue) end
			task.wait(ShowOff.Leaderboard.Refresh)
		end
	end)
end

return ShowOffService
