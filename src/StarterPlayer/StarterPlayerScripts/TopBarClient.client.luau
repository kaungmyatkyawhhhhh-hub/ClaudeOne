-- TopBarClient (prompt 43, owner 22 Oct: "the Roblox top bar holds ONLY the coins"):
--   Coins   the one icon on Roblox's top bar (TopbarPlus, next to Roblox's buttons): the coin + the amount ("184,250"),
--           counting up / down to a new amount. It steps aside while a window is open (the window shows its own coins).
--   Under the left menu (SideMenu.AddFooter), one row: a small gear tile (the nav tile look, smaller) that opens Settings,
--   and a dark chunky pill "LVL 27 · 6'4"" (thin gold outline) that opens Stats. LVL = the average exact level of the
--   18 muscles; a new LVL shows the LVL UP reward popup (Notify.Reward).
-- (Daily and Quests have no top bar icons any more: the right-side cards open them, DailyClient.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TopBar = require(Shared.UI.TopBar)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local UI = require(Shared.Config.UI)
local Muscles = require(Shared.Config.Muscles)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)
local Notify = require(Shared.UI.Notify)

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors
local GOLD = "#" .. Colors.Gold:ToHex()
local ROW_H = 32 -- mockup px (about 44 screen px on a phone)

------------------------------------------------------------------------
-- Coins: the only top bar icon, counting to the new amount
------------------------------------------------------------------------
local coins = TopBar.NewIcon("Coins", 1):setImage(UI.Icons.coin):setLabel("0")
coins:modifyTheme({ "IconImage", "ImageColor3", Colors.Gold }) -- (the one gold accent)
local shownCoins = New("NumberValue", { Name = "ShownCoins", Value = 0 })
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
-- Under the left menu: the gear (Settings) and the LVL · height pill (Stats)
------------------------------------------------------------------------
local row = New("Frame", { Name = "LevelRow", BackgroundTransparency = 1 })
-- the gear: a small nav tile (graphite, gold inner line, gold line icon)
local gear = New("TextButton", { Name = "Settings", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1),
	Size = UDim2.fromOffset(ROW_H, ROW_H), Parent = row }, {
	New("UICorner", { CornerRadius = UDim.new(0, 8) }),
	New("UIStroke", { Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#2A272D"), Color3.fromHex("#18161A")) }),
})
New("Frame", { Name = "Inner", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -4, 1, -4),
	Parent = gear }, {
	New("UICorner", { CornerRadius = UDim.new(0, 6) }),
	New("UIStroke", { Color = Colors.Gold, Thickness = 1, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
Pieces.Icon("settings", Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), Parent = gear })
	:SetAttribute("KeepColor", true)
Theme.BindPress(gear)
gear.Activated:Connect(function() UIBus.OpenSettings:Fire() end)
-- the pill
local pill = New("TextButton", { Name = "Level", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("#141215"), AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0), Size = UDim2.new(1, -(ROW_H + 6), 1, 0), Parent = row }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	New("UIStroke", { Color = Colors.Gold, Thickness = 1.2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})
local pillText = Kit.Text({ Name = "Text", Text = "LVL 0", Font = "Chunky", TextSize = 13, RichText = true, Size = UDim2.fromScale(1, 1), Parent = pill })
Kit.Fit(pillText, 13, 9)
Theme.BindPress(pill)
pill.Activated:Connect(function() UIBus.OpenStats:Fire("Muscles") end)
SideMenu.AddFooter(row, ROW_H, 1)

------------------------------------------------------------------------
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
	pillText.Text = "LVL " .. whole .. " · " .. heightText
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
