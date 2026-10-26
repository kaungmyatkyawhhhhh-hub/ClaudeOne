-- FriendClient (26 Oct, retention): the Friend Boost toast (FriendService: "FriendBoost" { name?, count, percent }) and
-- Roblox's invite prompt, once, after Growth Spurt Social.Friends.PromptAfterSpurt (a toast first says what friends give;
-- off the machine, no window open). The Crew window has its own INVITE FRIENDS row (CrewClient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Social = require(Shared.Config.Social)
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = Theme.Colors
local cfg = Social.Friends
local percent = math.floor(cfg.GainsPer * 100 + 0.5)

local function invite()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then pcall(SocialService.PromptGameInvite, SocialService, player) end
end

local asked = false
Remotes:WaitForChild("PlayerEvent").OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "FriendBoost" then
		local title = if type(info.name) == "string" then info.name .. " is here!" else "Friends are here!"
		Notify.Toast(title, "Friend Boost: +" .. tostring(info.percent or percent) .. "% gains", "users", Colors.Green, "friendboost")
	elseif kind == "GrowthSpurt" and info.spurts == cfg.PromptAfterSpurt and not asked then
		asked = true
		task.wait(20) -- (after the Growth Spurt moment, and the favourite prompt's turn at Spurt 1 is long over)
		local deadline = os.clock() + 180
		while (UIBus.Training or UIBus.CoverOpen(playerGui)) and os.clock() < deadline do task.wait(2) end
		Notify.Toast("Train with friends", "Every friend here: +" .. percent .. "% gains (up to +" .. percent * cfg.Max .. "%)", "users", Colors.Green, "friendinvite")
		task.wait(2)
		invite()
	end
end)
