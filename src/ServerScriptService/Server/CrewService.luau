-- Crews (Config.Social.Crew): up to 8 players with a name and a short tag above their heads, saved across
-- servers. Create one, invite players in your server, accept invites, leave. Every name and tag goes through
-- Roblox's text filter before anyone else sees it. A crew's score (its members' muscle levels) feeds the top
-- crews list shown in the Crew panel. Scores are EXP (Muscles.TotalExp), like every number the player sees.
-- Records: DataStore "Crews", key = crew id -> { name, tag, owner, members = { [userId] = { score, level, spurts, seen,
-- name } }, officers? = { [userId] = true }, joinMode? = "request" | "open", requests? = { [userId] = { name, at } } }.
-- Top crews (owner, 15 Oct): tapping a crew opens its members (action "View": read from the DataStore, kept 60 s per
-- crew on this server). Joining from there: "open" crews are joined at once (JOIN), the others get a join request
-- (REQUEST TO JOIN) that the leader (or an officer) accepts in MY CREW. An accepted player who isn't in this server is
-- told through the "CrewInboxV1" DataStore (key = userId -> crewId), read when they join and on every score refresh.
-- "Online" = the member's server wrote their score in the last two refreshes (any server: no extra calls).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local Social = require(Config.Social)
local Muscles = require(Config.Muscles)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes
local CREW = Social.Crew

local CrewService = {}

local remote -- RemoteEvent "Crew": client -> server (action, ...); server -> client ("Info", info) / ("View", view) / ("Result", text)
local crewStore = DataStoreService:GetDataStore("CrewsV1") -- (V1: fresh for the release, 9 Oct)
local scoreStore = DataStoreService:GetOrderedDataStore("CrewLeaderboardV1")
local inboxStore = DataStoreService:GetDataStore("CrewInboxV1") -- [userId] = crewId of an accepted join request
-- Unique crew names and tags (owner, 19 Oct; case-insensitive): "tag:<TAG>" / "name:<name>" = the crew id that holds it,
-- claimed with UpdateAsync when a crew is made, let go when it's deleted (its last member leaves). (Crews can't be renamed.)
local namesStore = DataStoreService:GetDataStore("CrewNamesV1")
local cache = {}   -- [crewId] = record (as last read or written by this server)
local invites = {} -- [player] = { [crewId] = inviterName }
local names = {}   -- [userId] = name
local busy = {}    -- [player] = true while an action runs
local viewed = {}  -- [crewId] = os.clock() of the last DataStore read for "View" (VIEW_CACHE seconds)
local VIEW_CACHE = 60
local MAX_REQUESTS = 20

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

-- Studio test crews (Workspace attribute TestCrews = true): never read from or written to the DataStore
local function isTest(crewId): boolean
	return type(crewId) == "string" and crewId:sub(1, 5) == "test-"
end

local function readCrew(crewId)
	if not crewId then return nil end
	if isTest(crewId) then return cache[crewId] end
	local ok, record = pcall(crewStore.GetAsync, crewStore, crewId)
	if ok then cache[crewId] = record end
	return ok and record or cache[crewId]
end

-- Change a crew record safely (UpdateAsync). `change(record)` returns the new record or nil to cancel.
local function updateCrew(crewId, change)
	if isTest(crewId) then return false, nil end
	local ok, newRecord = pcall(crewStore.UpdateAsync, crewStore, crewId, function(record)
		return change(record)
	end)
	if ok and newRecord then cache[crewId] = newRecord end
	return ok, newRecord
end

local function nameKey(kind: string, text: string): string
	return kind .. ":" .. (if kind == "tag" then text:upper() else text:lower())
end

-- Claims a crew name / tag for crewId. Returns "ok", "taken" (another crew with members holds it) or "error" (try
-- later). A claim left by a crew that no longer exists (or has no members) is taken over.
local function claim(kind: string, text: string, crewId: string): string
	local key = nameKey(kind, text)
	local holder = nil
	local ok = pcall(namesStore.UpdateAsync, namesStore, key, function(current)
		if current == nil or current == crewId then return crewId end
		holder = current
		return nil
	end)
	if not ok then return "error" end
	if holder == nil then return "ok" end
	local okRead, record = pcall(crewStore.GetAsync, crewStore, holder)
	if not okRead then return "error" end
	if record and count(record.members) > 0 then return "taken" end
	local took = false
	local okTake = pcall(namesStore.UpdateAsync, namesStore, key, function(current)
		took = current == holder or current == nil
		return if took then crewId else nil
	end)
	if not okTake then return "error" end
	return if took then "ok" else "taken"
end

-- Lets go of a name / tag (only when crewId is the one holding it).
local function unclaim(kind: string, text: string, crewId: string)
	local key = nameKey(kind, text)
	local ok, current = pcall(namesStore.GetAsync, namesStore, key)
	if ok and current == crewId then pcall(namesStore.RemoveAsync, namesStore, key) end
end

-- A crew with no members is deleted: its record, its leaderboard score (so it leaves TOP CREWS) and its name / tag.
local function deleteCrew(crewId: string, record)
	if isTest(crewId) then return end
	pcall(crewStore.RemoveAsync, crewStore, crewId)
	pcall(scoreStore.RemoveAsync, scoreStore, crewId)
	cache[crewId] = nil
	if type(record.tag) == "string" then unclaim("tag", record.tag, crewId) end
	if type(record.name) == "string" then unclaim("name", record.name, crewId) end
	local ok, top = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("CrewTop") or "[]")
	if ok and type(top) == "table" then
		local kept = {}
		for _, entry in ipairs(top) do
			if entry.crewId ~= crewId then table.insert(kept, entry) end
		end
		ReplicatedStorage:SetAttribute("CrewTop", HttpService:JSONEncode(kept))
	end
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

local function roleOf(record, userId): string
	userId = tostring(userId)
	if tostring(record.owner) == userId then return "Leader" end
	if type(record.officers) == "table" and record.officers[userId] then return "Officer" end
	return "Member"
end

local function canManage(record, userId): boolean
	local role = roleOf(record, userId)
	return role == "Leader" or role == "Officer"
end

-- average muscle level (the top bar's "LVL n")
local function levelOf(data): number
	local total, n = 0, 0
	for _, muscle in ipairs(Muscles.List) do
		local entry = data.muscles and data.muscles[muscle.id]
		if entry then
			total += Muscles.ExactLevel(entry)
			n += 1
		end
	end
	return n > 0 and math.floor(total / n) or 0
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
	tag.MaxDistance = 40
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
-- What the panels show
------------------------------------------------------------------------
local function topList()
	local topJson = ReplicatedStorage:GetAttribute("CrewTop")
	local top = {}
	if type(topJson) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, topJson)
		if ok and type(decoded) == "table" then top = decoded end
	end
	if RunService:IsStudio() and workspace:GetAttribute("TestCrews") == true then
		local test = {}
		for _, id in ipairs({ "test-full", "test-solo", "test-gone" }) do
			local record = cache[id]
			local total = 0
			if record then for _, member in pairs(record.members) do total += member.score or 0 end end
			table.insert(test, { crewId = id, name = record and record.name or "Gone Crew", tag = record and record.tag or "GONE",
				score = total, members = record and count(record.members) or 3 })
		end
		for _, entry in ipairs(top) do table.insert(test, entry) end
		top = test
	end
	return top
end

-- The crew as both panels show it (the same shape for MY CREW and a top crew): name, tag, rank, score, members
-- (leader first, then by contribution) with role, level, Growth Spurts (the height), score, online / here.
local function crewView(crewId, record)
	local members, total = {}, 0
	local now = os.time()
	for userId, member in pairs(record.members) do
		local here = Players:GetPlayerByUserId(tonumber(userId)) ~= nil
		total += member.score or 0
		table.insert(members, {
			userId = tonumber(userId), name = member.name or nameOf(userId), role = roleOf(record, userId),
			score = member.score or 0, level = member.level, spurts = member.spurts or 0, here = here,
			online = here or (member.seen ~= nil and now - member.seen < CREW.Refresh * 2 + 30),
		})
	end
	table.sort(members, function(a, b)
		if (a.role == "Leader") ~= (b.role == "Leader") then return a.role == "Leader" end
		if a.score ~= b.score then return a.score > b.score end
		return a.name < b.name
	end)
	local rank = nil
	for index, entry in ipairs(topList()) do
		if entry.crewId == crewId then rank = index break end
	end
	return { crewId = crewId, name = record.name, tag = record.tag, rank = rank, score = total, members = members,
		max = CREW.MaxMembers, joinMode = record.joinMode or "request" }
end

local function sendInfo(player)
	if not player.Parent then return end
	local info = { invites = {}, eligible = {}, top = topList() }
	local crewId = crewIdOf(player)
	local record = crewId and cache[crewId]
	if record then
		info.crew = crewView(crewId, record)
		info.crew.manage = canManage(record, player.UserId)
		info.crew.leader = roleOf(record, player.UserId) == "Leader"
		-- join requests (leader / officers)
		if info.crew.manage then
			info.crew.requests = {}
			for userId, request in pairs(record.requests or {}) do
				table.insert(info.crew.requests, { userId = tonumber(userId), name = request.name or nameOf(userId), at = request.at or 0 })
			end
			table.sort(info.crew.requests, function(a, b) return a.at < b.at end)
		end
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
	remote:FireClient(player, "Info", info)
end

-- A top crew's members for the viewer (read-only). gone = the crew no longer exists.
local function sendView(player, crewId)
	if type(crewId) ~= "string" or #crewId > 64 then return end
	local record = cache[crewId]
	if not isTest(crewId) and (not record or not viewed[crewId] or os.clock() - viewed[crewId] > VIEW_CACHE) then
		local ok, stored = pcall(crewStore.GetAsync, crewStore, crewId)
		if ok then
			cache[crewId] = stored
			viewed[crewId] = os.clock()
			record = stored
		end
	end
	if not record or count(record.members) == 0 then
		remote:FireClient(player, "View", { crewId = crewId, gone = true })
		return
	end
	local view = crewView(crewId, record)
	local mine = crewIdOf(player)
	view.mine = mine == crewId
	view.inCrew = mine ~= nil
	view.requested = type(record.requests) == "table" and record.requests[tostring(player.UserId)] ~= nil
	remote:FireClient(player, "View", view)
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
local actions = {}

actions.Create = function(player, name, tag)
	if crewIdOf(player) then result(player, "You're already in a crew.") return end
	if not PlayerData.IsPersistent(player) then result(player, "Crews can't be made in a test session (progress isn't saved).") return end
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
	local crewId = HttpService:GenerateGUID(false)
	-- the tag and the name are claimed first (unique across all crews, any capitals)
	local tagClaim = claim("tag", cleanTag, crewId)
	if tagClaim ~= "ok" then
		result(player, if tagClaim == "taken" then "That tag is already taken." else "Couldn't save the crew right now. Try again in a minute.")
		return
	end
	local nameClaim = claim("name", cleanName, crewId)
	if nameClaim ~= "ok" then
		unclaim("tag", cleanTag, crewId)
		result(player, if nameClaim == "taken" then "That crew name is already taken." else "Couldn't save the crew right now. Try again in a minute.")
		return
	end
	if CREW.CreateCost > 0 and not PlayerData.SpendCoins(player, CREW.CreateCost) then
		unclaim("tag", cleanTag, crewId)
		unclaim("name", cleanName, crewId)
		result(player, "Creating a crew costs " .. CREW.CreateCost .. " coins.") return
	end
	local record = { name = cleanName, tag = cleanTag, owner = player.UserId, members = { [tostring(player.UserId)] = { score = 0, name = player.DisplayName } },
		created = os.time(), joinMode = "request" }
	local ok = pcall(crewStore.SetAsync, crewStore, crewId, record)
	if not ok then
		if CREW.CreateCost > 0 then PlayerData.AddCoins(player, CREW.CreateCost) end -- (the coins were taken above)
		unclaim("tag", cleanTag, crewId)
		unclaim("name", cleanName, crewId)
		result(player, "Couldn't save the crew right now. Try again in a minute.")
		return
	end
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

-- Puts `player` (in this server) into the crew: checks it's not full, writes the record, sets their crew, tells the crew.
local function joinCrew(player, crewId): boolean
	local full = false
	local ok, record = updateCrew(crewId, function(stored)
		if not stored or count(stored.members) == 0 then return nil end
		if count(stored.members) >= CREW.MaxMembers then full = true return nil end
		stored.members[tostring(player.UserId)] = { score = 0, name = player.DisplayName }
		if stored.requests then stored.requests[tostring(player.UserId)] = nil end
		return stored
	end)
	if full then result(player, "That crew is full now.") return false end
	if not ok or not record then result(player, "Couldn't join right now. Try again in a minute.") return false end
	setCrew(player, crewId)
	updateTag(player)
	result(player, "You joined " .. record.name .. " [" .. record.tag .. "].")
	for _, other in ipairs(Players:GetPlayers()) do
		if crewIdOf(other) == crewId and other ~= player then
			Remotes.PlayerEvent:FireClient(other, "CrewJoined", { name = player.DisplayName })
		end
	end
	return true
end

actions.Accept = function(player, crewId)
	if type(crewId) ~= "string" or not (invites[player] and invites[player][crewId]) then return end
	if not PlayerData.IsPersistent(player) then result(player, "Crews can't be joined in a test session (progress isn't saved).") return end
	if crewIdOf(player) then result(player, "Leave your crew first.") return end
	invites[player][crewId] = nil
	joinCrew(player, crewId)
end

actions.Decline = function(player, crewId)
	if invites[player] and type(crewId) == "string" then invites[player][crewId] = nil end
end

-- From a top crew's member view: JOIN (open crews) or REQUEST TO JOIN (the others).
actions.Request = function(player, crewId)
	if type(crewId) ~= "string" or #crewId > 64 then return end
	if isTest(crewId) then result(player, "That's a Studio test crew.") return end
	if not PlayerData.IsPersistent(player) then result(player, "Crews can't be joined in a test session (progress isn't saved).") return end
	if crewIdOf(player) then result(player, "Leave your crew first.") return end
	local record = readCrew(crewId)
	if not record or count(record.members) == 0 then result(player, "This crew no longer exists.") return end
	if count(record.members) >= CREW.MaxMembers then result(player, "That crew is full.") return end
	if (record.joinMode or "request") == "open" then
		joinCrew(player, crewId)
	else
		local ok, stored = updateCrew(crewId, function(current)
			if not current or count(current.members) == 0 then return nil end
			current.requests = current.requests or {}
			current.requests[tostring(player.UserId)] = { name = player.DisplayName, at = os.time() }
			-- (the oldest go past MAX_REQUESTS)
			local list = {}
			for userId, request in pairs(current.requests) do table.insert(list, { userId = userId, at = request.at or 0 }) end
			table.sort(list, function(a, b) return a.at > b.at end)
			for index = MAX_REQUESTS + 1, #list do current.requests[list[index].userId] = nil end
			return current
		end)
		if not ok or not stored then result(player, "Couldn't send the request right now. Try again in a minute.") return end
		result(player, "Join request sent to " .. stored.name .. ".")
		for _, other in ipairs(Players:GetPlayers()) do
			if crewIdOf(other) == crewId and canManage(stored, other.UserId) then
				Remotes.PlayerEvent:FireClient(other, "CrewRequest", { name = player.DisplayName })
			end
		end
	end
	viewed[crewId] = nil
	sendView(player, crewId)
end

-- MY CREW, leader / officers: accept or decline a join request.
actions.AnswerRequest = function(player, userId, accept)
	local crewId = crewIdOf(player)
	local record = crewId and cache[crewId]
	if type(userId) ~= "number" or not record or not canManage(record, player.UserId) then return end
	local key = tostring(userId)
	local full = false
	local ok, stored = updateCrew(crewId, function(current)
		if not current or not (current.requests and current.requests[key]) then return nil end
		local request = current.requests[key]
		current.requests[key] = nil
		if accept == true then
			if count(current.members) >= CREW.MaxMembers then full = true return current end
			current.members[key] = { score = 0, name = request.name }
		end
		return current
	end)
	if full then result(player, "Your crew is full.") return end
	if not ok or not stored then return end
	if accept ~= true then return end
	local target = Players:GetPlayerByUserId(userId)
	if target then
		if crewIdOf(target) then -- (joined another crew meanwhile: take them back out)
			updateCrew(crewId, function(current) if current then current.members[key] = nil end return current end)
			result(player, (stored.members[key] and stored.members[key].name or "They") .. " is already in a crew.")
			return
		end
		setCrew(target, crewId)
		updateTag(target)
		result(target, "You joined " .. stored.name .. " [" .. stored.tag .. "].")
		sendInfo(target)
	else
		pcall(inboxStore.SetAsync, inboxStore, key, crewId) -- (told when they next join, or within a refresh in their server)
	end
	result(player, "Request accepted.")
end

-- MY CREW, leader: join requests (default) or open to all.
actions.SetJoinMode = function(player, mode)
	local crewId = crewIdOf(player)
	local record = crewId and cache[crewId]
	if (mode ~= "request" and mode ~= "open") or not record or roleOf(record, player.UserId) ~= "Leader" then return end
	updateCrew(crewId, function(current)
		if not current then return nil end
		current.joinMode = mode
		return current
	end)
end

-- (owner, 24 Oct) MY CREW, leader only: kick a member out. In this server they're told at once; in another server their
-- next score refresh notices (refreshScores); offline, onJoin clears it.
actions.Kick = function(player, userId)
	local crewId = crewIdOf(player)
	local record = crewId and cache[crewId]
	if type(userId) ~= "number" or userId == player.UserId or not record or roleOf(record, player.UserId) ~= "Leader" then return end
	local key = tostring(userId)
	local name = record.members[key] and record.members[key].name or nameOf(userId)
	local ok, stored = updateCrew(crewId, function(current)
		if not current or not current.members[key] or tostring(current.owner) ~= tostring(player.UserId) then return nil end
		current.members[key] = nil
		if current.officers then current.officers[key] = nil end
		return current
	end)
	if not ok or not stored then result(player, "Couldn't kick right now. Try again in a minute.") return end
	local target = Players:GetPlayerByUserId(userId)
	if target and crewIdOf(target) == crewId then
		setCrew(target, nil)
		updateTag(target)
		result(target, "You were removed from " .. stored.name .. " [" .. stored.tag .. "].")
		sendInfo(target)
	end
	result(player, name .. " was kicked from the crew.")
end

actions.Leave = function(player)
	local crewId = crewIdOf(player)
	if not crewId then return end
	local left = updateCrew(crewId, function(stored)
		if not stored then return nil end
		stored.members[tostring(player.UserId)] = nil
		if stored.officers then stored.officers[tostring(player.UserId)] = nil end
		if tostring(stored.owner) == tostring(player.UserId) then
			stored.owner = nil
			for userId in pairs(stored.members) do stored.owner = tonumber(userId) break end
		end
		return stored
	end)
	-- (a failed write must not leave the player gone on their side but still listed in the crew)
	if not left then result(player, "Couldn't leave right now. Try again in a minute.") return end
	local record = cache[crewId]
	if record and count(record.members) == 0 then deleteCrew(crewId, record) end
	setCrew(player, nil)
	updateTag(player)
	result(player, "You left the crew.")
end

------------------------------------------------------------------------
-- Accepted join requests from another server
------------------------------------------------------------------------
local function checkInbox(player)
	if not PlayerData.IsPersistent(player) then return end
	local key = tostring(player.UserId)
	local ok, crewId = pcall(inboxStore.GetAsync, inboxStore, key)
	if not ok or type(crewId) ~= "string" then return end
	pcall(inboxStore.RemoveAsync, inboxStore, key)
	local record = readCrew(crewId)
	if not record or not record.members[key] then return end
	if crewIdOf(player) and crewIdOf(player) ~= crewId then
		-- already in another crew: leave the accepted one's list
		updateCrew(crewId, function(current) if current then current.members[key] = nil end return current end)
		return
	end
	setCrew(player, crewId)
	updateTag(player)
	result(player, "Your join request was accepted: you're in " .. record.name .. " [" .. record.tag .. "].")
end

------------------------------------------------------------------------
-- Scores + top crews
------------------------------------------------------------------------
local function levelSum(data)
	-- EXP: all muscles together, plus a big step per Growth Spurt (a spurt resets the muscles, so it must still count)
	return Muscles.TotalExp(data.muscles) + data.growthSpurts * 1000000
end

local function refreshScores()
	local byCrew = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.Get(player)
		local crewId = data and data.crew and data.crew.id
		if crewId and PlayerData.IsPersistent(player) then
			byCrew[crewId] = byCrew[crewId] or {}
			byCrew[crewId][tostring(player.UserId)] = { score = levelSum(data), level = levelOf(data), spurts = data.growthSpurts or 0,
				name = player.DisplayName }
		elseif data and not crewId then
			task.spawn(checkInbox, player)
		end
	end
	local now = os.time()
	for crewId, scores in pairs(byCrew) do
		local ok, record = updateCrew(crewId, function(stored)
			if not stored then return nil end
			for userId, fresh in pairs(scores) do
				local member = stored.members[userId]
				if member then
					member.score, member.level, member.spurts, member.name, member.seen = fresh.score, fresh.level, fresh.spurts, fresh.name, now
				end
			end
			return stored
		end)
		if ok and record then
			-- kicked by the leader in another server: out of the crew here too
			for userId in pairs(scores) do
				local target = not record.members[userId] and Players:GetPlayerByUserId(tonumber(userId))
				if target and crewIdOf(target) == crewId then
					setCrew(target, nil)
					updateTag(target)
					result(target, "You were removed from " .. record.name .. " [" .. record.tag .. "].")
					sendInfo(target)
				end
			end
			local total = 0
			for _, member in pairs(record.members) do total += member.score or 0 end
			pcall(scoreStore.SetAsync, scoreStore, crewId, total)
		end
	end
	-- the top crews for the Crew panel (Social.Crew.TopCount; a crew's record is read once per server, then cached)
	local ok, pages = pcall(function() return scoreStore:GetSortedAsync(false, Social.Crew.TopCount) end)
	if ok and pages then
		local top = {}
		for _, entry in ipairs(pages:GetCurrentPage()) do
			local record = cache[entry.key] or readCrew(entry.key)
			if record and count(record.members) > 0 then
				table.insert(top, { crewId = entry.key, name = record.name, tag = record.tag, score = entry.value, members = count(record.members) })
			end
		end
		ReplicatedStorage:SetAttribute("CrewTop", HttpService:JSONEncode(top))
	end
end

------------------------------------------------------------------------
-- Studio test crews (Workspace attribute TestCrews = true): a full crew with long names, a crew of one, and a deleted
-- crew in the top list. Read-only: never saved.
------------------------------------------------------------------------
local function makeTestCrews()
	local now = os.time()
	local full = { name = "The Extremely Long Crew Name", tag = "LONG", owner = 1, joinMode = "request", officers = { ["2"] = true }, members = {} }
	local longNames = { "Captain_Gainsworth_The_Unstoppable", "Officer_Broccoli_Muncher_9000", "SquatQueenWithAVeryLongName", "Pump",
		"DeadliftDestroyerXXL_2014", "Reps", "Lat_Spread_Larry_The_Third", "Tiny" }
	for index, name in ipairs(longNames) do
		full.members[tostring(index)] = { name = name, score = 2500000 - index * 180000, level = 60 - index * 4, spurts = 6 - (index % 4),
			seen = if index % 3 == 0 then now else now - 3600 }
	end
	cache["test-full"] = full
	cache["test-solo"] = { name = "Solo", tag = "ONE", owner = 9, joinMode = "open", members = { ["9"] = { name = "LoneLifter", score = 12000, level = 4, spurts = 0, seen = now } } }
	cache["test-gone"] = nil
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
				-- a one-time message for the leader (e.g. their tag was changed because another crew had it first)
				if type(record.notice) == "string" and tostring(record.owner) == tostring(player.UserId) then
					local notice = record.notice
					task.delay(20, function() result(player, notice) end) -- (after the loading screen and menu)
					updateCrew(crewId, function(stored)
						if stored then stored.notice = nil end
						return stored
					end)
				end
			end
		end
		if not crewIdOf(player) then checkInbox(player) end
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
	if RunService:IsStudio() then
		if workspace:GetAttribute("TestCrews") == true then makeTestCrews() end
		workspace:GetAttributeChangedSignal("TestCrews"):Connect(function()
			if workspace:GetAttribute("TestCrews") == true then makeTestCrews() end
		end)
	end
	remote.OnServerEvent:Connect(function(player, action, a, b)
		if action == "Info" then
			if Guard.Allow(player, "crew:info", 2, 4) then sendInfo(player) end
			return
		end
		if action == "View" then
			if Guard.Allow(player, "crew:view", 2, 4) then sendView(player, a) end
			return
		end
		local handler = type(action) == "string" and actions[action]
		-- create/invite/accept/leave hit the DataStore and the text filter: one every 2 s at most
		if not handler or busy[player] or not Guard.Allow(player, "crew:action", 0.5, 3) then return end
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
