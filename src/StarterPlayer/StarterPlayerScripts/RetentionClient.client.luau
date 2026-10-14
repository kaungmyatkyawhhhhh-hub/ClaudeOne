-- RetentionClient: the rush hour pill at the top of the right column (with a countdown), and corner notes for
-- offline coins, re-racked plates and DNA tokens bought at the front desk.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Seasons = require(Shared.Config.Seasons)
local Muscles = require(Shared.Config.Muscles)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Colors = Theme.Colors

------------------------------------------------------------------------
-- Rush hour pill
------------------------------------------------------------------------
-- (owner's UI redesign) a boost chip: a gold timer tile, "2x" and the time left
local chip = RightColumn.Chip("timer", Colors.Gold, 0)

local started = false
local function rushLeft()
	local ends = ReplicatedStorage:GetAttribute("RushHourEnds")
	if type(ends) ~= "number" then return 0 end
	return math.max(0, ends - Workspace:GetServerTimeNow())
end

local function refreshPill()
	local left = rushLeft()
	chip:SetVisible(started and left > 0)
	if left > 0 then
		chip:SetText(Economy.RushHour.Coins .. "x coins", string.format("%d:%02d", left // 60, math.floor(left % 60)))
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		refreshPill()
	end
end)

------------------------------------------------------------------------
-- Notes
------------------------------------------------------------------------
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "SoftShutdown" then
		-- (ShutdownService: this server is closing for an update; the teleport follows in a second)
		Notify.Show("The gym is updating. Moving you to the new version, your progress is saved.", nil, "shutdown")
	elseif kind == "Reracked" then
		Notify.Show("Plate re-racked. +" .. tostring(info.coins) .. " coins.", nil, "rerack")
		Audio.PlayUI("Click")
	elseif kind == "DnaTokenBought" then
		-- (a coin buy from the Shop or the Genetics screen, ActionService.BuyDnaToken)
		if info.failed then
			Notify.Toast("Not enough coins", "A DNA token costs " .. Kit.Format(tonumber(info.price) or 0) .. " coins", "coin", Colors.Red, "dnacoins")
		else
			Notify.Toast("+1 DNA Token", "Reroll your genetics on the Genetics screen", "sparkles", Colors.Gold, "dnatoken")
			Audio.PlayUI("LevelUp")
		end
	elseif kind == "GymLocked" then
		local names = { Beach = "The beach gym", Pro = "The pro gym" }
		Notify.Show((names[info.gym] or "This gym") .. " opens at Growth Spurt " .. tostring(info.spurts) .. ".", nil, "gymlocked")
	elseif kind == "ProGymLocked" then
		Notify.Show("Reach Growth Spurt " .. tostring(info.spurts) .. " to enter the Pro Gym", nil, "progym")
	elseif kind == "ProGymEntered" then
		Notify.Show("Welcome to the pro gym. 11 new machines, including Calves and Obliques.", nil, "progym")
		Audio.PlayUI("Whoosh")
	elseif kind == "RushHour" then
		if info.active then
			Notify.Show("Rush hour! " .. Economy.RushHour.Coins .. "x coins for " .. Economy.RushHour.LengthMinutes .. " minutes.")
			Audio.PlayUI("SetComplete")
		end
		refreshPill()
	end
end)

-- What this join paid out, after Play (the menu shows it too).
task.spawn(function()
	local data = ClientData.Get()
	UIBus.WaitForMenu()
	started = true
	refreshPill()
	task.wait(3.5)
	local season = Seasons.ById[ReplicatedStorage:GetAttribute("Season") or ""]
	if season then
		Notify.Show(season.name .. " is on: +" .. math.floor((season.coins - 1) * 100 + 0.5) .. "% coins, and " .. season.title.reps .. " reps earn the " .. season.title.name .. " title.")
	end
	local welcome = data.welcome or {}
	if (welcome.offlineCoins or 0) > 0 then
		Notify.Show("While you were away: +" .. Muscles.FormatExp(welcome.offlineCoins) .. " coins.")
	end
end)
-- (the Daily pill and the login streak calendar live in DailyClient)
