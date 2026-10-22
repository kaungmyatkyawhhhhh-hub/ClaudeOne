-- TopBarClient: the left-hand icons on Roblox's top bar (TopbarPlus, see Shared/UI/TopBar; prompt 46, owner 22 Oct: the HUD
-- mockup 05, one row of dark pills with a thin gold outline):
--   Coins   the coin + the amount ("184,250"), counting up / down to a new amount. It steps aside while a window is open
--           (the window shows its own coins).
--   Level   "LVL 52 · 4'6"" (the average exact level of the 18 muscles, the height; "7'0" MAX" in gold at the cap) with a
--           small gold bar along its bottom: the way to the next LVL. A tap opens Stats. A new LVL shows the LVL UP popup.
-- The right-hand icons (POSING SHOW, DAILY, the gear) come from their own scripts (PosingCompClient, TopBar.AddPill).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TopBar = require(Shared.UI.TopBar)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local UIBus = require(Shared.UI.UIBus)
local UI = require(Shared.Config.UI)
local Muscles = require(Shared.Config.Muscles)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)
local Notify = require(Shared.UI.Notify)

local player = Players.LocalPlayer
local Colors = Theme.Colors
local GOLD = "#" .. Colors.Gold:ToHex()

------------------------------------------------------------------------
-- Coins, counting to the new amount
------------------------------------------------------------------------
local coins = TopBar.NewIcon("Coins", 1):setImage(UI.Icons.coin):setLabel("0")
coins:modifyTheme({ "IconImage", "ImageColor3", Colors.Gold }) -- (the one gold accent)
coins:modifyTheme({ "IconLabel", "TextColor3", Colors.Gold }) -- (owner, 23 Oct, chrome reset: the coin count in gold)
local shownCoins = Instance.new("NumberValue")
shownCoins.Changed:Connect(function(value) coins:setLabel(Kit.Format(math.floor(value + 0.5))) end)
local firstCoins = true
local function setCoins(amount: number)
	if firstCoins then
		firstCoins = false
		shownCoins.Value = amount
		coins:setLabel(Kit.Format(amount))
		return
	end
	local steps = math.abs(amount - shownCoins.Value)
	TweenService:Create(shownCoins, TweenInfo.new(if steps < 1 then 0 else math.clamp(0.25 + steps / 4000, 0.25, 0.8), Enum.EasingStyle.Quad), { Value = amount }):Play()
end
local function windowCoins()
	coins:setEnabled(player:GetAttribute("WindowOpen") ~= true)
end
player:GetAttributeChangedSignal("WindowOpen"):Connect(windowCoins)
windowCoins()

------------------------------------------------------------------------
-- LVL · height, with the small gold EXP bar; a tap opens Stats
------------------------------------------------------------------------
local level = TopBar.NewIcon("Level", 2):setLabel("LVL 0")
level:unlock():oneClick(true)
level:bindEvent("selected", function() UIBus.OpenStats:Fire("Muscles") end)
local barTrack, barFill = nil, nil
do
	local button = level.widget:FindFirstChild("IconButton")
	if button then
		barTrack = Instance.new("Frame")
		barTrack.Name = "ExpBar"
		barTrack.AnchorPoint = Vector2.new(0.5, 1)
		barTrack.Position = UDim2.new(0.5, 0, 1, -3)
		barTrack.Size = UDim2.new(1, -18, 0, 3)
		barTrack.BackgroundColor3 = Color3.fromHex("#0C0B0D")
		barTrack.BorderSizePixel = 0
		barTrack.ZIndex = 10
		Instance.new("UICorner", barTrack).CornerRadius = UDim.new(1, 0)
		barTrack.Parent = button
		barFill = Instance.new("Frame")
		barFill.Name = "Fill"
		barFill.Size = UDim2.fromScale(0, 1)
		barFill.BackgroundColor3 = Colors.Gold
		barFill.BorderSizePixel = 0
		barFill.ZIndex = 11
		Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
		barFill.Parent = barTrack
	end
end

local shownLevel, shownSpurts = nil, 0 -- the LVL shown last (for the LVL UP popup)
local function refresh()
	local data = ClientData.Get()
	if not data then return end
	setCoins(data.coins or 0)
	local inches = GrowthSpurts.GetHeight(data.growthSpurts or 0)
	local heightText = GrowthSpurts.FormatHeight(inches, true)
	if inches >= GrowthSpurts.MaxHeightInches then heightText ..= ' <font color="' .. GOLD .. '">MAX</font>' end
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
	-- (owner, 23 Oct, chrome reset: the LVL number in gold)
	level:setLabel('LVL <font color="' .. GOLD .. '">' .. whole .. "</font> · " .. heightText)
	if barFill then barFill.Size = UDim2.fromScale(math.clamp(average - whole, 0, 1), 1) end
	-- LVL up (prompt 20, 21 Oct): a reward popup. Not on the first read, and not after a Growth Spurt (the level starts over)
	local stage = (data.growthSpurts or 0) * 100 + (type(data.alter) == "table" and data.alter.highest or 0) -- (a Body Alter starts the level over too)
	if shownLevel and whole > shownLevel and stage == shownSpurts then
		Notify.Reward("LVL UP", "You are LVL " .. whole .. " now", "arrow-big-up", Colors.Gold, "LevelUp", "lvl")
	end
	shownLevel, shownSpurts = whole, stage
end

task.spawn(function()
	ClientData.Get()
	refresh()
	ClientData.Changed:Connect(function(path)
		local key = path[1]
		if key == "coins" or key == "muscles" or key == "growthSpurts" or key == "alter" then refresh() end
	end)
end)
