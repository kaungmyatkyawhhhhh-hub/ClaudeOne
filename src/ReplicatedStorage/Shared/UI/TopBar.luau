-- TopBar (client): the row of dark round pills at the top of the HUD (owner's UI v2, mockup 01_main_hud), in mockup px
-- inside a Kit.Root so it scales with the screen:
--   left (after the space Roblox's own buttons need): coins | height "6'4" / 7'0"" | level ("LVL 27" + a small gold bar
--   toward the next level)
--   right: DAILY | QUESTS | the settings gear (owner's final kit "BLACK + GOLD": bold italic caps, plain red dots)
-- Level = the average exact level of the 18 muscles. Shown on the HUD and while training (mockup 02); hidden on the main
-- menu and the genetics screen.
-- TopBar.AddPill(id, text, iconFactory, order): "Daily", "Quests" and "Settings" are the right-hand pills; any other id
-- is a hidden placeholder. Returns { button, SetActive(on), SetDot(on), SetBadge(n), SetText(text), Activated }.
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

TopBar.Top = 8       -- mockup px from the top of the screen
TopBar.Height = 32
TopBar.Left = 150    -- the left pills start here (Roblox's menu buttons sit before it)
TopBar.Right = 12
TopBar.TextSize = 14

-- the right-hand pills: id -> look
local PILLS = {
	Daily = { order = 1, text = "Daily", icon = "calendar-days" },
	Quests = { order = 2, text = "Quests", icon = "list-checks" },
	Settings = { order = 3, icon = "settings", round = true },
}

local geneticsOpen = false
local gui, root, leftRow, rightRow
local coinsText, levelNumber, setLevelBar, heightText, heightMax

local function refreshVisible()
	if not gui then return end
	gui.Enabled = not UIBus.MenuOpen and not geneticsOpen and not SideMenu.IsHidden()
end

-- a dark round pill (clickable = an ImageButton); returns the pill
local function pill(name, order, parent, clickable)
	local p = Theme.Panel({ Name = name, LayoutOrder = order, Piece = "pill", Clickable = clickable,
		Size = UDim2.fromOffset(0, TopBar.Height), AutomaticSize = Enum.AutomaticSize.X, Parent = parent }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
		Theme.List(Horizontal, 7, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	if clickable then Theme.BindPress(p) end
	return p
end

local function text(name, order, value, parent, color, size)
	return Kit.Text({ Name = name, LayoutOrder = order, Text = value, Font = "Title", TextSize = size or TopBar.TextSize, TextColor3 = color or Colors.Text,
		Upper = true, Size = UDim2.fromOffset(0, TopBar.Height), AutomaticSize = Enum.AutomaticSize.X, Parent = parent })
end

local function build()
	gui = Theme.ScreenGui({ Name = "TopBar", DisplayOrder = 5, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	root = Kit.Root(gui)
	leftRow = New("Frame", { Name = "Row", Position = UDim2.fromOffset(TopBar.Left, TopBar.Top), Size = UDim2.fromOffset(0, TopBar.Height),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = root }, { Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Left) })
	rightRow = New("Frame", { Name = "RightRow", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -TopBar.Right, 0, TopBar.Top),
		Size = UDim2.fromOffset(0, TopBar.Height), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = root },
		{ Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Right) })

	-- coins
	local coins = pill("Coins", 1, leftRow)
	Kit.Coin(19, { LayoutOrder = 1, Parent = coins })
	coinsText = text("Value", 2, "0", coins)
	-- (owner's final kit: hidden while a window is open; the window has its own coins pill)
	local player = Players.LocalPlayer
	local function coinsShown() coins.Visible = player:GetAttribute("WindowOpen") ~= true end
	player:GetAttributeChangedSignal("WindowOpen"):Connect(coinsShown)
	coinsShown()
	-- height: ruler, "6'4"", "/ 7'0"" in gray
	local height = pill("Height", 2, leftRow)
	Pieces.Icon("ruler", Colors.Text, { LayoutOrder = 1, Size = UDim2.fromOffset(17, 17), Parent = height })
	heightText = text("Value", 2, "", height)
	heightMax = text("Max", 3, "", height, Colors.Muted)
	-- level: "LVL" in gray, the number, a small gold bar toward the next level
	local level = pill("Level", 3, leftRow)
	text("Label", 1, "LVL", level, Colors.Muted, 12)
	levelNumber = text("Number", 2, "0", level, Colors.Text, 17)
	local _
	_, setLevelBar = Kit.Bar(Colors.Gold, { Name = "Bar", LayoutOrder = 3, Size = UDim2.fromOffset(52, 9), Parent = level }, { outline = 1.5 })
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
	local average = count > 0 and total / count or 0
	levelNumber.Text = tostring(math.floor(average))
	setLevelBar(average - math.floor(average))
	heightText.Text = GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts or 0), true)
	heightMax.Text = "/ " .. GrowthSpurts.FormatHeight(GrowthSpurts.MaxHeightInches, true)
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

-- A right-hand pill (Daily Reward, Quests, Settings). Other ids get a hidden placeholder with the same api.
function TopBar.AddPill(id, labelText, _iconFactory, _order)
	ensure()
	local cfg = PILLS[id]
	local activated = Instance.new("BindableEvent")
	local api = { Activated = activated.Event }
	if not cfg then
		api.button = New("TextButton", { Name = id, Visible = false, Text = "", Parent = rightRow })
		function api.SetActive() end
		function api.SetDot() end
		function api.SetBadge() end
		function api.SetText() end
		return api
	end
	local p = pill(id, cfg.order, rightRow, true)
	if cfg.round then
		p.AutomaticSize = Enum.AutomaticSize.None
		p.Size = UDim2.fromOffset(TopBar.Height, TopBar.Height)
		local pad = p:FindFirstChildOfClass("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 0), UDim.new(0, 0)
		p:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	Pieces.Icon(cfg.icon, Colors.Text, { LayoutOrder = 1, Size = UDim2.fromOffset(18, 18), Parent = p })
	local label = cfg.text and text("Label", 2, cfg.text or labelText, p) or nil
	local dot = New("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -5, 0, 5), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Colors.Red, Visible = false, ZIndex = 3, Parent = p }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local dotText = Kit.Text({ Name = "Count", Text = "", Font = "Number", TextSize = 10, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = dot })
	p.Activated:Connect(function() activated:Fire() end)
	api.button = p
	function api.SetActive() end
	function api.SetDot(_, on)
		dot.Visible = on and true or false
		dot.Size = UDim2.fromOffset(12, 12)
		dotText.Text = ""
	end
	function api.SetBadge(_, n)
		n = tonumber(n) or 0
		dot.Visible = n > 0
		dot.Size = UDim2.fromOffset(16, 16)
		dotText.Text = n > 0 and tostring(math.min(n, 9)) or ""
	end
	function api.SetText(_, value)
		-- (the pills keep their own words: "Daily", "Quests")
		if label and value and id ~= "Daily" and id ~= "Quests" then label.Text = value end
	end
	return api
end

-- Screen px (from the top of the safe area) just under the bar.
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
