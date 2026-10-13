-- LegendClient: the legend challenge tracker in the right column (under the quest tracker), and notes when a
-- legend arrives, leaves, or a challenge is finished. The Title Book doubles as the "Legends met" list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Legends = require(Shared.Config.Legends)
local Onboarding = require(Shared.Config.Onboarding)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Colors = Theme.Colors
-- the legend challenge card (RightColumn.Tracker, mockup 01 look)
local tracker = RightColumn.Tracker({ name = "LegendTracker", title = "Legend challenge", color = Colors.Gold, icon = "trophy", order = 4, idleOnly = true })
local panel = tracker.frame
panel.Visible = false

local started = false
local function refresh()
	if not started then return end
	local data = ClientData.Get()
	local active = data.legends and data.legends.active
	local legend = active and Legends.ById[active.id]
	panel.Visible = legend ~= nil
	if not legend then return end
	tracker:SetTitle("Legend · " .. legend.name)
	tracker:SetText(legend.quest.text)
	tracker:SetProgress(active.goal > 0 and active.progress / active.goal or 0, active.progress .. "/" .. active.goal)
end

ClientData.Changed:Connect(function(path)
	if path[1] == "legends" then refresh() end
end)

local function metCount()
	local data = ClientData.Get()
	local n = 0
	for _ in pairs(data.legends and data.legends.met or {}) do n += 1 end
	return n
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "LegendArrived" then
		-- not on the menu or during the tutorial (the coach line is the only guide in the first minutes)
		local step = ClientData.Get().onboarding.tutorialStep or Onboarding.Done
		if UIBus.MenuOpen or step < Onboarding.Done then return end
		Notify.Show(tostring(info.name) .. " is in the gym for " .. tostring(info.minutes) .. " minutes. Go say hi.")
		Audio.PlayUI("SetComplete")
	elseif kind == "LegendLeft" then
		Notify.Show(tostring(info.name) .. " left the gym.", nil, "legend")
	elseif kind == "LegendDone" then
		Notify.Show("Challenge done: " .. tostring(info.name) .. ". +" .. tostring(info.coins) .. " coins, +" .. tostring(info.dnaTokens) .. " DNA token.")
		Notify.Show("Legends met: " .. metCount() .. " / " .. #Legends.List)
		Audio.PlayUI("TitleUnlocked")
	end
end)

task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	started = true
	refresh()
end)
