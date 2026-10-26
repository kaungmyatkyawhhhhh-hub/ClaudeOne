-- PlaytimeClient (26 Oct, retention): the playtime gift popups (PlaytimeService pays them by itself; Config.Playtime).
-- One reward toast in the toast lane: what you got, and what the next gift is and when ("Next: Creatine in 10 min").
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local remote = Remotes:WaitForChild("Playtime", 60) :: RemoteEvent
if not remote then return end -- the playtime service didn't start

remote.OnClientEvent:Connect(function(kind, info)
	if kind ~= "Gift" or type(info) ~= "table" then return end
	local sub = tostring(info.text or "")
	if info.nextText and info.nextMinutes then
		sub ..= ". Next: " .. tostring(info.nextText) .. " in " .. tostring(info.nextMinutes) .. " min"
	else
		sub ..= ". Come back tomorrow for more gifts!"
	end
	local title = "PLAYTIME GIFT " .. tostring(info.index or 1) .. "/" .. tostring(info.total or 6)
	Notify.Reward(title, sub, "gift", Theme.Colors.Gold, "QuestClaim", "playtime")
end)
