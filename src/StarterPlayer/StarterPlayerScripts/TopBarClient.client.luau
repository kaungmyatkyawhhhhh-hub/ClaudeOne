-- TopBarClient: the left-hand icons on Roblox's top bar (owner, 14 Oct: TopbarPlus, see Shared/UI/TopBar):
--   Coins   the gold coin + the live amount ("28,859")
--   Height  the ruler + "6'4"" (at the cap "7'0" MAX", MAX in gold)
--   Level   "LVL 60" (the average exact level of the 18 muscles); its caption shows the way to the next level; a new LVL
--           shows the LVL UP reward popup (Notify.Reward)
-- The right-hand icons (Daily, Quests, Settings) come from their own scripts through TopBar.AddPill.
-- Small screens: when the icons don't fit beside Roblox's buttons, Height goes first (TopbarPlus' overflow menu takes
-- anything else). The coins icon steps aside while a window is open (the window shows its own coins).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TopBar = require(Shared.UI.TopBar)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local UI = require(Shared.Config.UI)
local Muscles = require(Shared.Config.Muscles)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)
local Notify = require(Shared.UI.Notify)

local player = Players.LocalPlayer
local GOLD = "#" .. Theme.Colors.Gold:ToHex()
local ROOM = 16 -- px kept free between the left and the right icons

local coins = TopBar.NewIcon("Coins", 1):setImage(UI.Icons.coin):setLabel("0")
coins:modifyTheme({ "IconImage", "ImageColor3", Theme.Colors.Gold }) -- (the one gold accent)
local height = TopBar.NewIcon("Height", 2):setImage(UI.Icons.ruler):setLabel("")
local level = TopBar.NewIcon("Level", 3):setLabel("LVL 0")

local heightRoom = true -- false = Height is folded away for room
local shownLevel, shownSpurts = nil, 0 -- the LVL shown last (for the LVL UP popup)
local function refresh()
	local data = ClientData.Get()
	if not data then return end
	coins:setLabel(Kit.Format(data.coins or 0))
	local inches = GrowthSpurts.GetHeight(data.growthSpurts or 0)
	local text = GrowthSpurts.FormatHeight(inches, true)
	if inches >= GrowthSpurts.MaxHeightInches then text ..= ' <font color="' .. GOLD .. '">MAX</font>' end
	height:setLabel(text)
	local total, count = 0, 0
	for _, muscle in ipairs(Muscles.List) do
		local entry = data.muscles and data.muscles[muscle.id]
		if entry then
			total += Muscles.ExactLevel(entry)
			count += 1
		end
	end
	local average = count > 0 and total / count or 0
	local whole = math.floor(average)
	level:setLabel("LVL " .. whole)
	level:setCaption(string.format("%d%% to LVL %d", math.floor((average - whole) * 100), whole + 1))
	-- LVL up (prompt 20, 21 Oct): a reward popup. Not on the first read, and not after a Growth Spurt (the level starts over)
	if shownLevel and whole > shownLevel and (data.growthSpurts or 0) == shownSpurts then
		Notify.Reward("LVL UP", "You are LVL " .. whole .. " now", "arrow-big-up", Theme.Colors.Gold, "LevelUp", "lvl")
	end
	shownLevel, shownSpurts = whole, data.growthSpurts or 0
end

-- Height goes first when the left and right icons would meet (checked after every change of size)
local function widthOf(name: string): number
	local icon = TopBar.Icon.getIcon(name)
	local widget = icon and icon.widget
	return widget and widget.Visible and widget.AbsoluteSize.X or 0
end
local heightWidth = 0
local function fit()
	local inset = GuiService.TopbarInset
	local used = 0
	for _, name in ipairs({ "Coins", "Level", "Daily", "Quests", "Settings" }) do used += widthOf(name) + 12 end
	if heightRoom then heightWidth = math.max(heightWidth, widthOf("Height")) end
	local wanted = inset.Width - ROOM >= used + heightWidth + 12
	if wanted ~= heightRoom then
		heightRoom = wanted
		height:setEnabled(wanted)
	end
end

task.spawn(function()
	ClientData.Get()
	refresh()
	ClientData.Changed:Connect(function(path)
		local key = path[1]
		if key == "coins" or key == "muscles" or key == "growthSpurts" then
			refresh()
			task.defer(fit)
		end
	end)
	task.wait(0.5)
	fit()
end)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() task.defer(fit) end)
for _, icon in ipairs({ coins, height, level }) do
	icon.widget:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(fit) end)
end

local function windowCoins()
	coins:setEnabled(player:GetAttribute("WindowOpen") ~= true)
end
player:GetAttributeChangedSignal("WindowOpen"):Connect(windowCoins)
windowCoins()
