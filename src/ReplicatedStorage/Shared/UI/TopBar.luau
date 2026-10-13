-- TopBar (client): the row at the top center of the HUD (owner's UI redesign, mockup 01_main_hud), in mockup px inside a
-- Kit.Root so it scales with the screen:
--   coins chip (+ a gold "+" that opens Shop > Coins, only while the shop exists) | LEVEL badge + EXP bar | height chip
-- Level = the average exact level of the 18 muscles; the bar and % are the way to the next one.
-- Visible on the HUD and while training (mockup 02); hidden on the main menu and the genetics screen.
-- TopBar.AddPill (the old top-right pills: Settings, the coach quest, the daily reward) now makes a menu tile
-- (SideMenu) with the same api: { button, SetActive(on), SetDot(on), SetText(text), Activated }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local SideMenu = require(script.Parent.SideMenu)
local UIBus = require(script.Parent.UIBus)
local New, Colors = Theme.New, Theme.Colors
local Horizontal = Enum.FillDirection.Horizontal

local TopBar = {}

TopBar.Top = 8      -- mockup px from the top of the screen
TopBar.Height = 34

local geneticsOpen = false
local gui, row
local coinsText, plusButton, levelBadge, levelLabel, levelPct, setLevelBar, heightText, heightMax

-- (old pill ids -> menu tile ids)
local TILE_IDS = { Quests = "Coach", Daily = "Daily", Settings = "Settings" }

local function refreshVisible()
	if not gui then return end
	gui.Enabled = not UIBus.MenuOpen and not geneticsOpen and not SideMenu.IsHidden()
end

local function build()
	gui = Theme.ScreenGui({ Name = "TopBar", DisplayOrder = 5, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = Kit.Root(gui)
	row = New("Frame", { Name = "Row", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TopBar.Top),
		Size = UDim2.fromOffset(0, TopBar.Height), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = root },
		{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })

	-- coins: the coin, the number, a gold "+" (Shop > Coins)
	local coins = Theme.Panel({ Name = "Coins", LayoutOrder = 1, Piece = "hud_box", Shadow = false, Size = UDim2.fromOffset(0, TopBar.Height),
		AutomaticSize = Enum.AutomaticSize.X, Parent = row }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 6) }),
		Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	Kit.Coin(18, { LayoutOrder = 1, Parent = coins })
	coinsText = Kit.Text({ Name = "Value", LayoutOrder = 2, Text = "0", Font = "Number", TextSize = 18, Size = UDim2.fromOffset(0, TopBar.Height),
		AutomaticSize = Enum.AutomaticSize.X, Parent = coins })
	plusButton = Theme.Button("Gold", { Name = "Plus", LayoutOrder = 3, Size = UDim2.fromOffset(22, 22), Visible = false, Parent = coins }, {})
	Pieces.Icon("plus", Colors.Ink, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -1), Size = UDim2.fromOffset(14, 14), Parent = plusButton })
	plusButton.Activated:Connect(function() UIBus.OpenShop:Fire("Coins") end)

	-- level: red badge, "LEVEL 27", the %, a red EXP bar
	local level = Theme.Panel({ Name = "Level", LayoutOrder = 2, Piece = "hud_box", Shadow = false, Size = UDim2.fromOffset(171, TopBar.Height), Parent = row })
	levelBadge = Pieces.Image("rounded_white_r8", { Name = "Badge", ImageColor3 = Colors.Red, Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(24, 24), Parent = level })
	Kit.Text({ Name = "Number", Text = "0", Font = "Title", TextSize = 14, Size = UDim2.fromScale(1, 1), Parent = levelBadge })
	levelLabel = Kit.Text({ Name = "Label", Text = "LEVEL 0", Font = "Body", TextSize = 9, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(38, 5),
		Size = UDim2.fromOffset(90, 12), TextXAlignment = Enum.TextXAlignment.Left, Parent = level })
	levelPct = Kit.Text({ Name = "Pct", Text = "0%", Font = "Number", TextSize = 9, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 5),
		Size = UDim2.fromOffset(40, 12), TextXAlignment = Enum.TextXAlignment.Right, Parent = level })
	local _, setBar = Kit.Bar(Colors.Red, { Name = "Bar", Position = UDim2.fromOffset(38, 21), Size = UDim2.new(1, -48, 0, 5), Parent = level })
	setLevelBar = setBar

	-- height: ruler, "6'4"", "/ 7'0""
	local height = Theme.Panel({ Name = "Height", LayoutOrder = 3, Piece = "hud_box", Shadow = false, Size = UDim2.fromOffset(0, TopBar.Height),
		AutomaticSize = Enum.AutomaticSize.X, Parent = row }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 10) }),
		Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	Pieces.Icon("ruler", Colors.Text, { LayoutOrder = 1, Size = UDim2.fromOffset(15, 15), Parent = height })
	heightText = Kit.Text({ Name = "Value", LayoutOrder = 2, Text = "", Font = "Number", TextSize = 18, Size = UDim2.fromOffset(0, TopBar.Height),
		AutomaticSize = Enum.AutomaticSize.X, Parent = height })
	heightMax = Kit.Text({ Name = "Max", LayoutOrder = 3, Text = "", Font = "Number", TextSize = 10, TextColor3 = Colors.Muted, Size = UDim2.fromOffset(0, TopBar.Height),
		AutomaticSize = Enum.AutomaticSize.X, Parent = height })
end

local function refreshData()
	local ok, ClientData = pcall(function() return require(ReplicatedStorage.Shared.ClientData) end)
	if not ok then return end
	local data = ClientData.Get()
	if not data then return end
	coinsText.Text = Kit.Format(data.coins or 0)
	local Config = ReplicatedStorage.Shared.Config
	local Muscles = require(Config.Muscles)
	local GrowthSpurts = require(Config.GrowthSpurts)
	local total, count = 0, 0
	for _, muscle in ipairs(Muscles.List) do
		local entry = data.muscles and data.muscles[muscle.id]
		if entry then
			total += Muscles.ExactLevel(entry)
			count += 1
		end
	end
	local exact = count > 0 and total / count or 0
	local level = math.floor(exact)
	local frac = exact - level
	levelBadge.Number.Text = tostring(level)
	levelLabel.Text = "LEVEL " .. level
	levelPct.Text = math.floor(frac * 100) .. "%"
	setLevelBar(frac)
	heightText.Text = GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts or 0), true)
	heightMax.Text = "/ " .. GrowthSpurts.FormatHeight(GrowthSpurts.MaxHeightInches, true)
	local okM, Monetization = pcall(function() return require(Config.Monetization) end)
	plusButton.Visible = okM and Monetization.AnyConfigured() or false
end

local function ensure()
	if gui then return gui end
	build()
	UIBus.MenuClosed.Event:Connect(refreshVisible)
	UIBus.GeneticsVisible.Event:Connect(function(open)
		geneticsOpen = open
		refreshVisible()
	end)
	SideMenu.Changed:Connect(refreshVisible)
	task.spawn(function() -- (MenuClient raises UIBus.MenuOpen when it starts, which can be after this runs)
		while true do
			task.wait(0.4)
			refreshVisible()
		end
	end)
	task.spawn(function()
		local ClientData = require(ReplicatedStorage.Shared.ClientData)
		ClientData.Get()
		refreshData()
		ClientData.Changed:Connect(function(path)
			local key = path[1]
			if key == "coins" or key == "muscles" or key == "growthSpurts" then refreshData() end
		end)
	end)
	refreshVisible()
	return gui
end

-- (old api) A top-right pill: now a menu tile. `order` is ignored (Config/HudIcons.Tiles sorts the tiles).
function TopBar.AddPill(id, text, iconFactory, order)
	ensure()
	local tile = SideMenu.Add(TILE_IDS[id] or id, text, iconFactory, order)
	return tile
end

-- Screen px (from the top of the safe area) just under the row.
function TopBar.Bottom()
	ensure()
	return math.floor((TopBar.Top + TopBar.Height) * Kit.Scale())
end

-- Screen px from the right edge where right-hand panels line up.
function TopBar.Edge()
	return math.floor(12 * Kit.Scale())
end

ensure()
return TopBar
