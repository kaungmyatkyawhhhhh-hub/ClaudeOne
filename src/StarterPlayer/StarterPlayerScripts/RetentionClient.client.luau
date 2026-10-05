-- RetentionClient: the rush hour pill at the top of the right column (with a countdown), and corner notes for the
-- daily streak, offline coins, re-racked plates and DNA tokens bought at the front desk.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Seasons = require(Shared.Config.Seasons)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Colors = Theme.Colors
local Horizontal = Enum.FillDirection.Horizontal

------------------------------------------------------------------------
-- Rush hour pill
------------------------------------------------------------------------
local pill = Theme.Panel({
	Name = "RushHour",
	Size = UDim2.fromOffset(RightColumn.Width, 36),
	Visible = false,
}, {
	Theme.Pad("S"),
	Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left),
})
RightColumn.Add(pill, 0)
local iconSlot = Theme.New("Frame", { LayoutOrder = 1, Size = UDim2.fromScale(0, 1), BackgroundTransparency = 1, Parent = pill }, { Theme.Aspect(1, Enum.DominantAxis.Height) })
Icons.Timer(Colors.Text).Parent = iconSlot
local pillText = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Small", Size = UDim2.new(1, -30, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = pill })

local started = false
local function rushLeft()
	local ends = ReplicatedStorage:GetAttribute("RushHourEnds")
	if type(ends) ~= "number" then return 0 end
	return math.max(0, ends - Workspace:GetServerTimeNow())
end

local function refreshPill()
	local left = rushLeft()
	pill.Visible = started and left > 0
	if left > 0 then
		pillText.Text = string.format("Rush hour %d:%02d  ·  %dx coins", left // 60, math.floor(left % 60), Economy.RushHour.Coins)
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
	if kind == "Reracked" then
		Notify.Show("Plate re-racked. +" .. tostring(info.coins) .. " coins.", nil, "rerack")
		Audio.PlayUI("Click")
	elseif kind == "DnaTokenBought" then
		if info.failed then
			Notify.Show("A DNA token costs " .. Economy.DnaTokenCost .. " coins.", nil, "dna")
		else
			Notify.Show("Bought a DNA token. Reroll on the Genetics screen.")
			Audio.PlayUI("LevelUp")
		end
	elseif kind == "GymLocked" then
		local names = { Beach = "The beach gym", Pro = "The pro gym" }
		Notify.Show((names[info.gym] or "This gym") .. " opens at Growth Spurt " .. tostring(info.spurts) .. ".", nil, "gymlocked")
	elseif kind == "ProGymLocked" then
		Notify.Show("The pro gym opens at Growth Spurt " .. tostring(info.spurts) .. ".", nil, "progym")
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
	if (welcome.streakCoins or 0) > 0 then
		local streak = data.daily and data.daily.streak or 1
		Notify.Show("Day " .. streak .. " streak: +" .. welcome.streakCoins .. " coins" .. (welcome.streakToken and ", +1 DNA token" or "") .. ".")
	end
	if (welcome.offlineCoins or 0) > 0 then
		Notify.Show("While you were away: +" .. welcome.offlineCoins .. " coins.")
	end
end)
