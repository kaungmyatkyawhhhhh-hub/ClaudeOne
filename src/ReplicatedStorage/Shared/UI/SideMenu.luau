-- Menu tiles (owner's UI redesign, mockup 01_main_hud): a grid of 56px menu buttons on the left (mockup px, inside a
-- Kit.Root so it scales with the screen), two columns, at most four rows (more tiles start a third column, so the bottom
-- left stays free for the thumbstick). Each tile: the menu_button piece (menu_button_gold for the Shop), a white icon
-- (Config/UI.Icons) and an Oswald label; a red badge with a count (Quests) or a small dot when something is new.
-- Order, labels and icons: Config/HudIcons.Tiles. While training every tile steps aside (mockup 02 shows only LEAVE).
-- SideMenu.Add returns { button, SetActive(on), SetDot(on), SetBadge(n), Activated } (use Activated, not button.Activated).
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local HudIcons = require(script.Parent.Parent.Config.HudIcons)
local UIBus = require(script.Parent.UIBus)
local New, Colors = Theme.New, Theme.Colors

local SideMenu = {}

SideMenu.TileSize = 56
SideMenu.Gap = 8
SideMenu.Left = 12
SideMenu.Top = 57
SideMenu.MaxRows = 4

local changed = Instance.new("BindableEvent")
SideMenu.Changed = changed.Event -- fires when the grid's size changes (panels follow it)

local gui, root, bar
local entries = {}
local training = false
local hiddenAll = false
local columns = 2

local function tileCfg(id) return HudIcons.Tiles[id] or {} end

local function visibleEntries()
	local list = {}
	for _, entry in ipairs(entries) do
		if not entry.hidden then table.insert(list, entry) end
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.id < b.id
	end)
	return list
end

local function layout()
	if not bar then return end
	local list = visibleEntries()
	local size, gap = SideMenu.TileSize, SideMenu.Gap
	columns = math.max(2, math.ceil(#list / SideMenu.MaxRows))
	local rows = math.max(1, math.ceil(#list / columns))
	for index, entry in ipairs(list) do
		local col = (index - 1) % columns
		local row = (index - 1) // columns
		entry.button.Position = UDim2.fromOffset(col * (size + gap), row * (size + gap))
		entry.button.Visible = true
	end
	for _, entry in ipairs(entries) do
		if entry.hidden then entry.button.Visible = false end
	end
	bar.Size = UDim2.fromOffset(columns * size + (columns - 1) * gap, rows * size + (rows - 1) * gap)
	bar.Visible = not hiddenAll and not training
	changed:Fire()
end

local function ensure()
	if bar then return bar end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Theme.ScreenGui({ Name = "MainHud", DisplayOrder = 4, Parent = playerGui })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	root = Kit.Root(gui)
	bar = New("Frame", { Name = "MenuBar", Position = UDim2.fromOffset(SideMenu.Left, SideMenu.Top), BackgroundTransparency = 1, Parent = root })
	Kit.OnScale(function() changed:Fire() end)
	return bar
end

local function makeTile(id, labelText, order)
	local cfg = tileCfg(id)
	local size = SideMenu.TileSize
	local button = New("TextButton", { Name = id, LayoutOrder = order, Size = UDim2.fromOffset(size, size), Text = "",
		AutoButtonColor = false, BackgroundTransparency = 1, Parent = bar })
	local bg = Pieces.Image(cfg.gold and "menu_button_gold" or "menu_button", { Name = "Bg", ZIndex = 0, Size = UDim2.fromScale(1, 1), Parent = button })
	local content = New("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = button })
	local iconColor = cfg.gold and Colors.Gold or Colors.Text
	if cfg.image and cfg.image ~= "" then
		New("ImageLabel", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 9), Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1, Image = cfg.image, ScaleType = Enum.ScaleType.Fit, Parent = content })
	else
		Pieces.Icon(cfg.uiIcon or "info", iconColor, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 9), Size = UDim2.fromOffset(22, 22), Parent = content })
	end
	local label = Kit.Text({ Name = "Label", Text = cfg.label or labelText, Font = "Title", TextSize = 10, TextColor3 = iconColor,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -4, 0, 12), Parent = content })
	local badge = Pieces.Image("circle_white", { Name = "Badge", ImageColor3 = Colors.Red, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(17, 17), Visible = false, ZIndex = 3, Parent = button })
	local badgeText = Kit.Text({ Name = "Count", Text = "", Font = "Title", TextSize = 10, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = badge })
	Theme.BindPress(button) -- (no piece attribute on the button: it shrinks a little when pressed)
	local entry = { id = id, order = cfg.order or order or 50, button = button, bg = bg, label = label, badge = badge, badgeText = badgeText,
		active = false, hover = false, dot = false, count = 0 }
	-- open panel: a red outline; hover: the tile brightens
	local outline = New("UIStroke", { Color = Colors.Red, Thickness = 1.5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	New("UICorner", { CornerRadius = Theme.Corner.Card, Parent = button })
	function entry.paint()
		bg.ImageColor3 = entry.hover and Color3.new(1, 1, 1) or Color3.new(0.88, 0.88, 0.88)
		outline.Transparency = entry.active and 0 or 1
	end
	function entry.paintBadge()
		local show = entry.count > 0 or entry.dot
		badge.Visible = show
		badgeText.Text = entry.count > 0 and tostring(math.min(entry.count, 9)) or ""
		badge.Size = entry.count > 0 and UDim2.fromOffset(17, 17) or UDim2.fromOffset(10, 10)
	end
	button.MouseEnter:Connect(function() entry.hover = true; entry.paint() end)
	button.MouseLeave:Connect(function() entry.hover = false; entry.paint() end)
	entry.paint()
	return entry
end

function SideMenu.Column()
	return ensure()
end

-- Screen px of the grid's right edge (+ a gap), for panels that open beside it.
function SideMenu.Right()
	ensure()
	return math.floor((SideMenu.Left + bar.Size.X.Offset + SideMenu.Gap) * Kit.Scale())
end

-- Screen px of the right edge of what the menu shows right now (0 when hidden).
function SideMenu.VisibleRight()
	ensure()
	if not bar.Visible then return 0 end
	return SideMenu.Right()
end

-- Screen px (from the top of the screen) of the grid's bottom edge.
function SideMenu.Bottom()
	ensure()
	return math.floor((SideMenu.Top + bar.Size.Y.Offset) * Kit.Scale())
end

function SideMenu.Add(id, labelText, _iconFactory, order)
	ensure()
	local entry = makeTile(id, labelText, order)
	table.insert(entries, entry)
	local activated = Instance.new("BindableEvent")
	entry.button.Activated:Connect(function() activated:Fire() end)
	local api = { button = entry.button, Activated = activated.Event }
	function api.SetActive(_, on)
		entry.active = on
		entry.paint()
	end
	function api.SetDot(_, on)
		entry.dot = on and true or false
		entry.paintBadge()
	end
	function api.SetBadge(_, count)
		entry.count = tonumber(count) or 0
		entry.paintBadge()
	end
	function api.SetText(_, text) entry.label.Text = text end
	-- a tile that only shows sometimes (the Shop while monetization is off)
	function api.SetShown(_, on)
		entry.hidden = not on
		layout()
	end
	layout()
	return api
end

-- SetHidden(true) hides the whole menu (a screen that needs the full width, like Genetics).
function SideMenu.SetHidden(on)
	ensure()
	hiddenAll = on
	layout()
end

-- SetTraining(true): on a machine every tile steps aside (mockup 02: only LEAVE on the left).
function SideMenu.SetTraining(on)
	ensure()
	training = on
	if on then UIBus.CloseAllPanels() end
	layout()
end

function SideMenu.IsTraining()
	return training
end

function SideMenu.IsHidden()
	return hiddenAll
end

-- (phones used to get their own folded menu; the grid now scales with the screen instead)
function SideMenu.IsCompact()
	return false
end

return SideMenu
