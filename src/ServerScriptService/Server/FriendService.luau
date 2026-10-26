-- FriendService (26 Oct, retention): the Friend Boost (Config.Social.Friends). Every Roblox friend in the same server
-- gives GainsPer more gains (up to Max friends), through BoostService (source "Friends"). The player's "FriendsHere"
-- attribute is the count (the client's toast and the boost line). Friendships are checked once per pair (pcall; a failed
-- check counts as not friends) when someone joins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Social = require(ReplicatedStorage.Shared.Config.Social)
local BoostService = require(script.Parent.BoostService)

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
			friends[player][other] = true
			friends[other] = friends[other] or {}
			friends[other][player] = true
			publish(other, player)
		end
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

function FriendService.Start()
	Players.PlayerAdded:Connect(function(player) task.spawn(onAdded, player) end)
	Players.PlayerRemoving:Connect(onRemoving)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(onAdded, player) end
end

return FriendService
