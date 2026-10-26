-- NotifyService (26 Oct, retention): the "daily reward ready" experience notification (Config.Notifications).
-- Leaving queues you in a MemoryStore sorted map (key = UserId, sort key = when to send: the next UTC day reset + a spread);
-- joining removes you. Every server checks for due reminders, claims each one (UpdateAsync, so only one server sends it),
-- sends it through Open Cloud (POST /cloud/v2/users/{id}/notifications, API key from the experience secret) and removes it.
-- Not in Studio; without the secret nothing is sent (one warning per server).
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Notifications = require(Config.Notifications)
local Economy = require(Config.Economy)

local NotifyService = {}

local MAX_EXPIRY = 45 * 86400 -- (MemoryStore's longest expiry)
local queue = MemoryStoreService:GetSortedMap("DailyReadyNotify")
local secret = nil
local warned = false

local function getSecret()
	if secret then return secret end
	local ok, value = pcall(HttpService.GetSecret, HttpService, Notifications.SecretName)
	if ok then
		secret = value
	elseif not warned then
		warned = true
		warn("[NotifyService] no secret '" .. Notifications.SecretName .. "': daily reminders are off (" .. tostring(value) .. ")")
	end
	return secret
end

local function send(userId: number): boolean
	local key = getSecret()
	if not key then return false end
	local ok, result = pcall(HttpService.RequestAsync, HttpService, {
		Url = "https://apis.roblox.com/cloud/v2/users/" .. userId .. "/notifications",
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = key },
		Body = HttpService:JSONEncode({
			source = { universe = "universes/" .. game.GameId },
			payload = { message_id = Notifications.MessageId, type = "MOMENT" },
			join_experience = { launch_data = "daily" },
			analytics_data = { category = Notifications.Category },
		}),
	})
	if not ok then
		warn("[NotifyService] send failed: " .. tostring(result))
		return false
	end
	if not result.Success then
		warn("[NotifyService] send " .. result.StatusCode .. ": " .. string.sub(tostring(result.Body), 1, 200))
	end
	return result.Success
end

local function onRemoving(player)
	local now = os.time()
	local sendAt = (Economy.Day(now) + 1) * 86400 + math.random(0, Notifications.SpreadMinutes * 60)
	local expiry = math.min(sendAt - now + Notifications.MaxAwayDays * 86400, MAX_EXPIRY)
	pcall(queue.SetAsync, queue, tostring(player.UserId), { at = sendAt }, expiry, sendAt)
end

local function onAdded(player)
	pcall(queue.RemoveAsync, queue, tostring(player.UserId))
end

-- the due ones (sort key <= now): claim, send, remove
local function sendDue()
	if not getSecret() then return end
	local now = os.time()
	local ok, items = pcall(queue.GetRangeAsync, queue, Enum.SortDirection.Ascending, Notifications.BatchSize, nil, { sortKey = now + 1 })
	if not ok or type(items) ~= "table" then return end
	for _, item in ipairs(items) do
		local claimed = false
		pcall(queue.UpdateAsync, queue, item.key, function(value, sortKey)
			claimed = type(value) == "table" and not value.sent
			if not claimed then return nil end
			return { at = value.at, sent = true }, sortKey
		end, 300)
		local userId = tonumber(item.key)
		if claimed and userId then
			if not Players:GetPlayerByUserId(userId) then send(userId) end
			pcall(queue.RemoveAsync, queue, item.key)
		end
	end
end

function NotifyService.Start()
	if RunService:IsStudio() then return end
	Players.PlayerAdded:Connect(function(player) task.spawn(onAdded, player) end)
	Players.PlayerRemoving:Connect(onRemoving)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(onAdded, player) end
	task.spawn(function()
		while true do
			task.wait(Notifications.CheckSeconds + math.random() * 10)
			pcall(sendDue)
		end
	end)
end

return NotifyService
