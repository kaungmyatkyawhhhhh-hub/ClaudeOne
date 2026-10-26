-- FriendClient (26 Oct, retention): the Friend Boost toast (FriendService: "FriendBoost" { name?, count, percent }) and
-- Roblox's invite prompt, once, after Growth Spurt Social.Friends.PromptAfterSpurt (a toast first says what friends give;
-- off the machine, no window open). The Crew window has its own INVITE FRIENDS row (CrewClient).
-- (owner, 26 Oct) An INVITE button as a row under the left menu's tiles (SideMenu.AddFooter; after the tutorial). Every
-- invite carries "invite:<your UserId>" as launch data: a friend who joins through it gives you the invite boost
-- (FriendService: "InviteBoost" { why = "invited" | "welcome", name?, minutes, percent }).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Social = require(Shared.Config.Social)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local SideMenu = require(Shared.UI.SideMenu)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = Theme.Colors
local cfg = Social.Friends
local percent = math.floor(cfg.GainsPer * 100 + 0.5)

local function invite()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if not (ok and can) then return end
	local options = Instance.new("ExperienceInviteOptions")
	options.LaunchData = "invite:" .. player.UserId
	options.PromptMessage = "Train with me in GYM ARC!"
	pcall(SocialService.PromptGameInvite, SocialService, player, options)
end
UIBus.InviteFriends.Event:Connect(invite)

-- the INVITE row under the left menu's tiles
local invitePercent = math.floor((cfg.InviteGains - 1) * 100 + 0.5)
local inviteButton = Kit.Button("Green", "Invite  +" .. invitePercent .. "%", { Name = "InviteFriends", Visible = false }, { height = 34, textSize = 13, icon = "users" })
inviteButton.Size = UDim2.new(1, 0, 0, 34)
SideMenu.AddFooter(inviteButton, 34, 5)
inviteButton.Activated:Connect(function()
	Audio.PlayUI("Click")
	invite()
end)
UIBus.AfterTutorial(function() inviteButton.Visible = true end)

local asked = false
Remotes:WaitForChild("PlayerEvent").OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "InviteBoost" then
		local title = if info.why == "welcome" then "Welcome! Invite boost" elseif type(info.name) == "string" then info.name .. " joined from your invite!" else "Your invite worked!"
		Notify.Reward(title, "+" .. tostring(info.percent or invitePercent) .. "% EXP for " .. tostring(info.minutes or cfg.InviteMinutes) .. " min", "users", Colors.Green, "QuestClaim", "inviteboost")
	elseif kind == "FriendBoost" then
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
