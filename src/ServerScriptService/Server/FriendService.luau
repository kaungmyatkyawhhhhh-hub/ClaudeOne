-- FriendService (26 Oct, retention): the Friend Boost (Config.Social.Friends). Every Roblox friend in the same server
-- gives GainsPer more gains (up to Max friends), through BoostService (source "Friends"). The player's "FriendsHere"
-- attribute is the count (the client's toast and the boost line). Friendships are checked once per pair (pcall; a failed
-- check counts as not friends) when someone joins.
-- (26 Oct) The invite boost (Social.Friends.Invite*): the invite carries "invite:<inviter UserId>" as launch data; when a
-- friend joins with it, the inviter's record in the "InviteRewards" DataStore gets +1 pending (once per friend per UTC day),
-- and the inviter claims every pending one on the spot or at their next join: InviteGains x EXP for InviteMinutes each
-- (BoostService source "InviteBoost", up to InviteMaxMinutes). A new player who joined through an invite gets the same.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local Social = require(ReplicatedStorage.Shared.Config.Social)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local BoostService = require(script.Parent.BoostService)
local PlayerData = require(script.Parent.PlayerData)

local okStore, inviteStore = pcall(DataStoreService.GetDataStore, DataStoreService, "InviteRewards")

local FriendService = {}

local friends = {} -- [player] = { [otherPlayer] = true }

local function event(player, kind, info)
	if player.Parent then ReplicatedStorage.Remotes.PlayerEvent:FireClient(player, kind, info or {}) end
end

local function publish(player, joined)
	local count = 0
	for other in pairs(friends[player] or {}) do
		if other.Parent then count += 1 end
	end
	local cfg = Social.Friends
	local counted = math.min(count, cfg.Max)
	BoostService.SetPlayer(player, "Friends", if counted > 0 then { gains = 1 + cfg.GainsPer * counted } else nil)
	local before = player:GetAttribute("FriendsHere") or 0
	player:SetAttribute("FriendsHere", if count > 0 then count else nil)
	if count > before then
		event(player, "FriendBoost", { name = joined and joined.DisplayName, count = count, percent = math.floor(cfg.GainsPer * counted * 100 + 0.5) })
	end
end

local function isFriends(a, b): boolean
	local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
	return ok and result == true
end

local function onAdded(player)
	friends[player] = friends[player] or {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and isFriends(player, other) then
			-- (memory: IsFriendsWith waits; either of them may have left meanwhile, and a left player's entry would stay)
			if not player.Parent then break end
			if other.Parent and friends[other] then
				friends[player][other] = true
				friends[other][player] = true
				publish(other, player)
			end
		end
	end
	if not player.Parent then
		friends[player] = nil
		return
	end
	publish(player, nil)
end

local function onRemoving(player)
	local mine = friends[player] or {}
	friends[player] = nil
	for other in pairs(mine) do
		if friends[other] then
			friends[other][player] = nil
			publish(other, nil)
		end
	end
end

-- the invite boost for `minutes` more (stacking up to InviteMaxMinutes from now)
local function giveInviteBoost(player, minutes: number, why: string, name: string?)
	local cfg = Social.Friends
	local now = Workspace:GetServerTimeNow()
	local current = BoostService.GetPlayer(player, "InviteBoost")
	local start = if current and current.untilTime then current.untilTime else now
	local untilTime = math.min(start + minutes * 60, now + cfg.InviteMaxMinutes * 60)
	BoostService.SetPlayer(player, "InviteBoost", { gains = cfg.InviteGains, untilTime = untilTime })
	player:SetAttribute("InviteBoostEnds", untilTime)
	event(player, "InviteBoost", { why = why, name = name, minutes = math.floor((untilTime - now) / 60 + 0.5),
		percent = math.floor((cfg.InviteGains - 1) * 100 + 0.5) })
end

-- every pending reward of `player` (friends who joined through their invites): claimed now
local function claimInvites(player)
	if not okStore or not player.Parent then return end
	local claimed, lastName = 0, nil
	local ok = pcall(inviteStore.UpdateAsync, inviteStore, tostring(player.UserId), function(record)
		if type(record) ~= "table" or (tonumber(record.pending) or 0) <= 0 then claimed = 0 return nil end
		claimed, lastName = math.floor(record.pending), record.lastName
		record.pending = 0
		return record
	end)
	if ok and claimed > 0 and player.Parent then
		giveInviteBoost(player, claimed * Social.Friends.InviteMinutes, "invited", lastName)
	end
end

-- `player` joined through someone's invite: +1 for the inviter (once per friend per day), the welcome boost if new
local function checkInvite(player)
	local okJoin, joinData = pcall(player.GetJoinData, player)
	local launch = okJoin and type(joinData) == "table" and joinData.LaunchData
	local inviterId = type(launch) == "string" and tonumber(string.match(launch, "^invite:(%d+)$"))
	if not inviterId or inviterId == player.UserId or not okStore then return end
	local today = Economy.Day(os.time())
	local counted = false
	pcall(inviteStore.UpdateAsync, inviteStore, tostring(inviterId), function(record)
		record = if type(record) == "table" then record else { pending = 0, seen = {} }
		record.seen = type(record.seen) == "table" and record.seen or {}
		local key = tostring(player.UserId)
		if record.seen[key] == today then counted = false return nil end
		record.seen[key] = today
		-- (keep the record small: forget friends seen before yesterday)
		for id, day in pairs(record.seen) do
			if type(day) ~= "number" or day < today - 1 then record.seen[id] = nil end
		end
		record.pending = (tonumber(record.pending) or 0) + 1
		record.lastName = player.DisplayName
		counted = true
		return record
	end)
	if not counted then return end
	local inviter = Players:GetPlayerByUserId(inviterId)
	if inviter then claimInvites(inviter) end
	-- a brand-new player: the welcome boost
	local data = PlayerData.WaitFor(player)
	if data and type(data.meta) == "table" and (tonumber(data.meta.sessions) or 0) <= 1 then
		giveInviteBoost(player, Social.Friends.InviteMinutes, "welcome", nil)
	end
end

function FriendService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(checkInvite, player)
		task.delay(5, claimInvites, player)
	end)
	Players.PlayerAdded:Connect(function(player) task.spawn(onAdded, player) end)
	Players.PlayerRemoving:Connect(onRemoving)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(onAdded, player) end
end

return FriendService
