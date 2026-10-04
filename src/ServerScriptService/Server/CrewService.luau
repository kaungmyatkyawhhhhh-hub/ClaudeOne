-- Crews (Config.Social.Crew): up to 8 players with a name and a short tag above their heads, saved across
-- servers. Create one, invite players in your server, accept invites, leave. Every name and tag goes through
-- Roblox's text filter before anyone else sees it. A crew's score (its members' muscle levels) feeds the top
-- crews list shown in the Crew panel.
-- Records: DataStore "Crews", key = crew id -> { name, tag, owner, members = { [userId] = { score } } }.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Social = require(Config.Social)
local Muscles = require(Config.Muscles)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes
local CREW = Social.Crew

local CrewService = {}

local remote -- RemoteEvent "Crew": client -> server (action, ...); server -> client ("Info", info) / ("Result", text)
local crewStore = DataStoreService:GetDataStore("Crews")
local scoreStore = DataStoreService:GetOrderedDataStore("CrewLeaderboard")
local cache = {}   -- [crewId] = record (as last read or written by this server)
local invites = {} -- [player] = { [crewId] = inviterName }
local names = {}   -- [userId] = name
local busy = {}    -- [player] = true while an action runs

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function result(player, text)
	if player.Parent then remote:FireClient(player, "Result", text) end
end

local function nameOf(userId)
	userId = tonumber(userId)
	if names[userId] then return names[userId] end
	local player = Players:GetPlayerByUserId(userId)
	if player then names[userId] = player.DisplayName return names[userId] end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or "Lifter"
	return names[userId]
end

local function count(members)
	local n = 0
	for _ in pairs(members) do n += 1 end
	return n
end

local function readCrew(crewId)
	if not crewId then return nil end
	local ok, record = pcall(crewStore.GetAsync, crewStore, crewId)
	if ok then cache[crewId] = record end
	return ok and record or cache[crewId]
end

-- Change a crew record safely (UpdateAsync). `change(record)` returns the new record or nil to cancel.
local function updateCrew(crewId, change)
	local ok, newRecord = pcall(crewStore.UpdateAsync, crewStore, crewId, function(record)
		return change(record)
	end)
	if ok and newRecord then cache[crewId] = newRecord end
	return ok, newRecord
end

-- Filtered for everyone to see; nil if it was blocked or the filter failed.
local function filter(text, player)
	local ok, filtered = pcall(function()
		local obj = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return obj:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or not filtered or filtered:find("#") then return nil end
	return filtered
end

local function crewIdOf(player)
	local data = PlayerData.Get(player)
	return data and data.crew and data.crew.id or nil
end

local function setCrew(player, crewId)
	PlayerData.SetTable(player, "crew", { id = crewId })
end

------------------------------------------------------------------------
-- Tag above the head (small, gray, above the title)
------------------------------------------------------------------------
local function updateTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild("CrewTag")
	if old then old:Destroy() end
	local record = cache[crewIdOf(player)]
	if not record then return end
	local tag = Instance.new("BillboardGui")
	tag.Name = "CrewTag"
	tag.Size = UDim2.fromScale(3, 0.5)
	tag.StudsOffset = Vector3.new(0, 3.45, 0)
	tag.MaxDistance = 60
	tag.LightInfluence = 0
	tag.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "[" .. record.tag .. "]"
	label.TextColor3 = Theme.Colors.Muted
	label.FontFace = Theme.Fonts.SemiBold
	label.TextScaled = true -- stud-sized billboard: the only place text may scale
	label.Parent = tag
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Shadow
	stroke.Transparency = 0.45
	stroke.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize = Theme.TextSize.Small, 32
	limit.Parent = label
end

------------------------------------------------------------------------
-- Info for the Crew panel
------------------------------------------------------------------------
local function sendInfo(player)
	if not player.Parent then return end
	local info = { invites = {}, eligible = {}, top = {} }
	local crewId = crewIdOf(player)
	local record = crewId and cache[crewId]
	if record then
		local members = {}
		for userId, member in pairs(record.members) do
			table.insert(members, {
				name = nameOf(userId), score = member.score or 0,
				here = Players:GetPlayerByUserId(tonumber(userId)) ~= nil, owner = tostring(record.owner) == userId,
			})
		end
		table.sort(members, function(a, b) return a.score > b.score end)
		info.crew = { name = record.name, tag = record.tag, members = members, max = CREW.MaxMembers }
		-- players here without a crew can be invited
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and not crewIdOf(other) and PlayerData.Get(other) then
				table.insert(info.eligible, { userId = other.UserId, name = other.DisplayName })
			end
		end
	end
	for id, from in pairs(invites[player] or {}) do
		local invite = cache[id]
		if invite then table.insert(info.invites, { crewId = id, name = invite.name, tag = invite.tag, from = from }) end
	end
	local topJson = ReplicatedStorage:GetAttribute("CrewTop")
	if type(topJson) == "string" then
		local ok, top = pcall(HttpService.JSONDecode, HttpService, topJson)
		if ok then info.top = top end
	end
	remote:FireClient(player, "Info", info)
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
local actions = {}

actions.Create = function(player, name, tag)
	if crewIdOf(player) then result(player, "You're already in a crew.") return end
	if type(name) ~= "string" or type(tag) ~= "string" then return end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	tag = tag:upper()
	if #name < CREW.NameLength[1] or #name > CREW.NameLength[2] then
		result(player, "Crew names are " .. CREW.NameLength[1] .. "-" .. CREW.NameLength[2] .. " letters.") return
	end
	if #tag < CREW.TagLength[1] or #tag > CREW.TagLength[2] or tag:find("[^%w]") then
		result(player, "Tags are " .. CREW.TagLength[1] .. "-" .. CREW.TagLength[2] .. " letters or numbers.") return
	end
	local cleanName, cleanTag = filter(name, player), filter(tag, player)
	if not cleanName or not cleanTag then result(player, "That name isn't allowed. Try another one.") return end
	if CREW.CreateCost > 0 and not PlayerData.SpendCoins(player, CREW.CreateCost) then
		result(player, "Creating a crew costs " .. CREW.CreateCost .. " coins.") return
	end
	local crewId = HttpService:GenerateGUID(false)
	local record = { name = cleanName, tag = cleanTag, owner = player.UserId, members = { [tostring(player.UserId)] = { score = 0 } }, created = os.time() }
	local ok = pcall(crewStore.SetAsync, crewStore, crewId, record)
	if not ok then result(player, "Couldn't save the crew right now. Try again in a minute.") return end
	cache[crewId] = record
	setCrew(player, crewId)
	updateTag(player)
	result(player, "Crew created: " .. cleanName .. " [" .. cleanTag .. "]")
end

actions.Invite = function(player, userId)
	local crewId = crewIdOf(player)
	local record = crewId and cache[crewId]
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not record or not target or target == player or crewIdOf(target) then return end
	if count(record.members) >= CREW.MaxMembers then result(player, "Your crew is full.") return end
	invites[target] = invites[target] or {}
	invites[target][crewId] = player.DisplayName
	Remotes.PlayerEvent:FireClient(target, "CrewInvite", { name = record.name, tag = record.tag, from = player.DisplayName })
	result(player, "Invite sent to " .. target.DisplayName .. ".")
	sendInfo(target)
end

actions.Accept = function(player, crewId)
	if type(crewId) ~= "string" or not (invites[player] and invites[player][crewId]) then return end
	if crewIdOf(player) then result(player, "Leave your crew first.") return end
	local full = false
	local ok, record = updateCrew(crewId, function(stored)
		if not stored then return nil end
		if count(stored.members) >= CREW.MaxMembers then full = true return nil end
		stored.members[tostring(player.UserId)] = { score = 0 }
		return stored
	end)
	invites[player][crewId] = nil
	if full then result(player, "That crew is full now.") return end
	if not ok or not record then result(player, "Couldn't join right now. Try again in a minute.") return end
	setCrew(player, crewId)
	updateTag(player)
	result(player, "You joined " .. record.name .. " [" .. record.tag .. "].")
	for _, other in ipairs(Players:GetPlayers()) do
		if crewIdOf(other) == crewId and other ~= player then
			Remotes.PlayerEvent:FireClient(other, "CrewJoined", { name = player.DisplayName })
		end
	end
end

actions.Decline = function(player, crewId)
	if invites[player] and type(crewId) == "string" then invites[player][crewId] = nil end
end

actions.Leave = function(player)
	local crewId = crewIdOf(player)
	if not crewId then return end
	updateCrew(crewId, function(stored)
		if not stored then return nil end
		stored.members[tostring(player.UserId)] = nil
		if tostring(stored.owner) == tostring(player.UserId) then
			stored.owner = nil
			for userId in pairs(stored.members) do stored.owner = tonumber(userId) break end
		end
		return stored
	end)
	setCrew(player, nil)
	updateTag(player)
	result(player, "You left the crew.")
end

------------------------------------------------------------------------
-- Scores + top crews
------------------------------------------------------------------------
local function levelSum(data)
	local sum = 0
	for _, group in ipairs(Muscles.Groups) do sum += Muscles.GetGroupLevel(data.muscles, group.id) end
	return math.floor(sum + (data.growthSpurts - 1) * 100)
end

local function refreshScores()
	local byCrew = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.Get(player)
		local crewId = data and data.crew and data.crew.id
		if crewId then
			byCrew[crewId] = byCrew[crewId] or {}
			byCrew[crewId][tostring(player.UserId)] = levelSum(data)
		end
	end
	for crewId, scores in pairs(byCrew) do
		local ok, record = updateCrew(crewId, function(stored)
			if not stored then return nil end
			for userId, score in pairs(scores) do
				if stored.members[userId] then stored.members[userId].score = score end
			end
			return stored
		end)
		if ok and record then
			local total = 0
			for _, member in pairs(record.members) do total += member.score or 0 end
			pcall(scoreStore.SetAsync, scoreStore, crewId, total)
		end
	end
	-- top 5 crews for the Crew panel
	local ok, pages = pcall(function() return scoreStore:GetSortedAsync(false, 5) end)
	if ok and pages then
		local top = {}
		for _, entry in ipairs(pages:GetCurrentPage()) do
			local record = cache[entry.key] or readCrew(entry.key)
			if record and count(record.members) > 0 then
				table.insert(top, { name = record.name, tag = record.tag, score = entry.value, members = count(record.members) })
			end
		end
		ReplicatedStorage:SetAttribute("CrewTop", HttpService:JSONEncode(top))
	end
end

------------------------------------------------------------------------
local function onJoin(player)
	task.spawn(function()
		local data = PlayerData.WaitFor(player)
		if not data then return end
		local crewId = data.crew and data.crew.id
		if crewId then
			local record = readCrew(crewId)
			-- removed (or crew gone) while away: clear it
			if record and not record.members[tostring(player.UserId)] then
				setCrew(player, nil)
			elseif record then
				updateTag(player)
			end
		end
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		updateTag(player)
	end)
end

function CrewService.Start()
	remote = Remotes:FindFirstChild("Crew")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Crew"
		remote.Parent = Remotes
	end
	remote.OnServerEvent:Connect(function(player, action, a, b)
		if action == "Info" then sendInfo(player) return end
		local handler = type(action) == "string" and actions[action]
		if not handler or busy[player] then return end
		busy[player] = true
		local ok, err = pcall(handler, player, a, b)
		busy[player] = nil
		if not ok then warn("[CrewService] " .. tostring(err)) end
		sendInfo(player)
	end)
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do onJoin(player) end
	Players.PlayerRemoving:Connect(function(player)
		invites[player], busy[player] = nil, nil
	end)
	task.spawn(function()
		task.wait(15)
		while true do
			pcall(refreshScores)
			task.wait(CREW.Refresh)
		end
	end)
end

return CrewService
