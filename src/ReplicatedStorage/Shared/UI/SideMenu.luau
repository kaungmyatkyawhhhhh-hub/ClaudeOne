-- The left menu (owner, 13 Oct: keep the old colored tiles, only tidied). Built in mockup px inside a Kit.Root, so every
-- tile has the same size and gap on every screen and scales with it:
--  * 2 columns of rounded-square tiles (a 3rd column only if a short screen can't fit them), VERTICALLY CENTERED on the
--    left (owner, 14 Oct: AnchorPoint 0, 0.5 at 0.5 of the screen; only nudged down if it would reach the top bar).
--    The "<" tab is centered on the tiles' right edge.
--    Each tile (owner's final kit "BLACK + GOLD", mockup 01_hud): dark glass (a graphite gradient, a faint light border,
--    a darker bottom edge the face sinks into when pressed), a white line icon (the Shop's in gold), the label in small
--    italic caps under it, a bounce on hover and press. Icons, order and labels: Config/HudIcons.Tiles. The open panel's
--    tile lights up (lighter glass, a gold border).
--  * A red dot in the top-right corner (quests ready to claim, new titles), with a number when there is one.
--  * The "<" tab on the tiles' right edge folds them away to the left (it then points ">" at the screen edge, with a red
--    dot when a folded tile has a badge) and back. The choice is saved per player (settings.menuCollapsed).
--  * On a machine the menu folds away by itself and comes back when you leave (unless you had folded it).
--  * The Wardrobe tile is hidden while Config/Features.Wardrobe is false (no gap). Ids that aren't tiles any more (the
--    top bar's pills) get a hidden placeholder with the same api.
-- SideMenu.Add returns { button, SetActive(on), SetDot(on), SetBadge(n), SetText, SetShown(on), Activated }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local UIBus = require(script.Parent.UIBus)
local HudIcons = require(script.Parent.Parent.Config.HudIcons)
local Features = require(script.Parent.Parent.Config.Features)
local New, Colors = Theme.New, Theme.Colors

local SideMenu = {}

SideMenu.TileSize = 54
SideMenu.Gap = 8
SideMenu.Left = 12
SideMenu.Top = 52      -- never higher than this: under Roblox's top bar (set from Kit.UnderTopbar)
SideMenu.BottomRoom = 12 -- room left at the bottom of the screen
SideMenu.Arrow = Vector2.new(24, 46)
SideMenu.FaceDarken = 0.5
SideMenu.LipDarken = 0.66
SideMenu.Lip = 4

local changed = Instance.new("BindableEvent")
SideMenu.Changed = changed.Event -- fires when the menu's size or position changes

local gui, root, bar, arrow, arrowIcon, arrowDot
local entries = {}
local training = false
local hiddenAll = false
local collapsed = false      -- what the player chose (saved)
local columns = 2
local gridTop = SideMenu.Top -- where the grid's top edge is now (mockup px from the top of the safe area)

local function shownEntries()
	local list = {}
	for _, entry in ipairs(entries) do
		if not entry.hidden and not entry.placeholder then table.insert(list, entry) end
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.id < b.id
	end)
	return list
end

local function folded()
	return collapsed or training
end

local function refreshArrowDot()
	if not arrowDot then return end
	local any = false
	for _, entry in ipairs(entries) do
		if not entry.placeholder and not entry.hidden and (entry.count > 0 or entry.dot) then any = true end
	end
	arrowDot.Visible = folded() and any
end

local function layout(animate: boolean?)
	if not bar then return end
	local list = shownEntries()
	local size, gap = SideMenu.TileSize, SideMenu.Gap
	local room = math.max(size, root.AbsoluteSize.Y / Kit.Scale() - SideMenu.Top - SideMenu.BottomRoom)
	local maxRows = math.max(1, math.floor((room + gap) / (size + gap)))
	columns = math.max(2, math.ceil(#list / maxRows))
	local rows = math.max(1, math.ceil(#list / columns))
	for index, entry in ipairs(list) do
		local col = (index - 1) % columns
		local row = (index - 1) // columns
		entry.button.Position = UDim2.fromOffset(col * (size + gap), row * (size + gap))
		entry.button.Visible = true
	end
	for _, entry in ipairs(entries) do
		if entry.hidden or entry.placeholder then entry.button.Visible = false end
	end
	local gridW, gridH = columns * size + (columns - 1) * gap, rows * size + (rows - 1) * gap
	bar.Size = UDim2.fromOffset(gridW, gridH)
	local isFolded = folded()
	-- vertically centered; nudged down only when the centered grid would reach the top bar (a very short screen)
	local screenH = root.AbsoluteSize.Y / Kit.Scale()
	local centered = (screenH - gridH) / 2
	gridTop = math.max(SideMenu.Top, math.min(centered, screenH - SideMenu.BottomRoom - gridH))
	local shift = math.floor(gridTop - centered)
	bar.AnchorPoint, arrow.AnchorPoint = Vector2.new(0, 0.5), Vector2.new(0, 0.5)
	local barPos = UDim2.new(0, isFolded and (-gridW - SideMenu.Left) or SideMenu.Left, 0.5, shift)
	local arrowPos = UDim2.new(0, isFolded and SideMenu.Left or (SideMenu.Left + gridW + gap), 0.5, shift)
	bar.Visible = not hiddenAll
	arrow.Visible = not hiddenAll and not training
	if animate then
		Theme.Tween(bar, { Position = barPos }, 0.25)
		Theme.Tween(arrow, { Position = arrowPos }, 0.25)
		Theme.Tween(arrowIcon, { Rotation = isFolded and 180 or 0 }, 0.25)
	else
		bar.Position, arrow.Position = barPos, arrowPos
		arrowIcon.Rotation = isFolded and 180 or 0
	end
	refreshArrowDot()
	changed:Fire()
end

local function setCollapsed(value: boolean, save: boolean?)
	if collapsed == value then return end
	collapsed = value
	if save then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local action = remotes and remotes:FindFirstChild("PlayerAction")
		if action then action:FireServer("SetSettings", { menuCollapsed = value }) end
	end
	layout(true)
end

local function ensure()
	if bar then return bar end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Theme.ScreenGui({ Name = "MainHud", DisplayOrder = 4, Parent = playerGui })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	root = Kit.Root(gui)
	bar = New("Frame", { Name = "MenuBar", BackgroundTransparency = 1, Parent = root })
	-- the "<" tab: folds the tiles away and brings them back
	arrow = New("TextButton", { Name = "MenuArrow", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(SideMenu.Arrow.X, SideMenu.Arrow.Y),
		BackgroundColor3 = Colors.Pill, BackgroundTransparency = 0.15, Parent = root }, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	Theme.BindPress(arrow)
	arrowIcon = Pieces.Icon("chevron-left", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18), Parent = arrow })
	arrowDot = New("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Colors.Red, Visible = false, ZIndex = 3, Parent = arrow }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Text, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	arrow.Activated:Connect(function() setCollapsed(not collapsed, true) end)
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() layout() end)
	Kit.OnTopbar(function()
		SideMenu.Top = Kit.UnderTopbar(root)
		layout()
	end)
	Kit.OnScale(function() task.defer(layout) end)
	-- the saved choice
	task.spawn(function()
		local ClientData = require(ReplicatedStorage.Shared.ClientData)
		local data = ClientData.Get()
		if data and data.settings and data.settings.menuCollapsed == true then
			collapsed = true
			layout()
		end
	end)
	return bar
end

-- One tile (the old look): lip, face, border, icon, outlined label, badge.
local function makeTile(id, labelText, iconFactory)
	local cfg = HudIcons.Tiles[id] or {}
	local size = SideMenu.TileSize
	local iconColor = id == "Store" and Colors.Gold or Colors.Text -- (the Shop's icon is gold)
	local button = New("TextButton", { Name = id, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size), Parent = bar })
	New("Frame", { Name = "Lip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#08070A"), BackgroundTransparency = 0.1, Parent = button },
		{ New("UICorner", { CornerRadius = UDim.new(0, 11) }) })
	local border = New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.2, Transparency = 0.86, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local face = New("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, -SideMenu.Lip), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.08,
		ZIndex = 2, Parent = button }, {
		New("UICorner", { CornerRadius = UDim.new(0, 11) }),
		border,
		New("UIGradient", { Name = "Glass", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#2A262B"), Color3.fromHex("#141215")) }),
	})
	local content = New("Frame", { Name = "Content", Size = UDim2.new(1, 0, 1, -SideMenu.Lip), BackgroundTransparency = 1, ZIndex = 3, Parent = face })
	local grow = New("UIScale", { Parent = content })
	local iconSize = math.floor(size * 0.46)
	local iconSlot = New("Frame", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(iconSize, iconSize), BackgroundTransparency = 1, ZIndex = 3, Parent = content })
	if cfg.image and cfg.image ~= "" then
		New("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = cfg.image, ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = iconSlot })
	elseif cfg.uiIcon then
		Pieces.Icon(cfg.uiIcon, iconColor, { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = iconSlot }):SetAttribute("KeepColor", true)
	elseif iconFactory then
		local icon = iconFactory(iconColor)
		icon.Parent = iconSlot
	end
	local label = Kit.Text({ Name = "Label", Text = string.upper(cfg.label or labelText), Font = "Title", TextSize = 10, TextColor3 = Color3.fromHex("#D9D2D5"),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 4, 0, 14), ZIndex = 4, Parent = content })
	local badge = New("Frame", { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -7, 0, 7), Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Colors.Red, Visible = false, ZIndex = 6, Parent = button }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local badgeText = Kit.Text({ Name = "Count", Text = "", Font = "Number", TextSize = 11, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = badge })

	local entry = { id = id, order = cfg.order or 50, button = button, label = label, count = 0, dot = false, active = false, hover = false }
	function entry.paint()
		-- lighter glass on hover / while its panel is open; the open one gets a gold border
		Theme.Tween(face, { BackgroundTransparency = (entry.active or entry.hover) and 0 or 0.08,
			BackgroundColor3 = (entry.active or entry.hover) and Color3.fromRGB(255, 245, 235) or Color3.new(1, 1, 1) }, 0.15)
		Theme.Tween(border, { Color = entry.active and Colors.Gold or Color3.new(1, 1, 1), Transparency = entry.active and 0.1 or (entry.hover and 0.7 or 0.86) }, 0.15)
		Theme.Tween(grow, { Scale = entry.hover and 1.08 or 1 }, 0.22, Theme.Motion.Bounce)
	end
	function entry.paintBadge()
		badge.Visible = entry.count > 0 or entry.dot
		badgeText.Text = entry.count > 0 and tostring(math.min(entry.count, 9)) or ""
		badge.Size = entry.count > 0 and UDim2.fromOffset(18, 18) or UDim2.fromOffset(11, 11)
		refreshArrowDot()
	end
	-- press: the face sinks onto its edge; letting go springs back
	Theme.BindPress(button)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Theme.Tween(face, { Position = UDim2.fromOffset(0, 3) }, 0.06)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Theme.Tween(face, { Position = UDim2.fromOffset(0, 0) }, 0.2, Theme.Motion.Bounce)
		end
	end)
	button.MouseEnter:Connect(function() entry.hover = true; entry.paint() end)
	button.MouseLeave:Connect(function() entry.hover = false; entry.paint() end)
	entry.paint()
	return entry
end

function SideMenu.Column()
	return ensure()
end

-- Screen px of the menu's right edge (the tab included), for panels that open beside it.
function SideMenu.Right()
	ensure()
	local s = Kit.Scale()
	if folded() then return math.floor((SideMenu.Left + SideMenu.Arrow.X) * s) end
	return math.floor((SideMenu.Left + bar.Size.X.Offset + SideMenu.Gap + SideMenu.Arrow.X) * s)
end

function SideMenu.VisibleRight()
	ensure()
	if hiddenAll then return 0 end
	return SideMenu.Right()
end

-- Screen px (from the top of the safe area) of the grid's bottom edge.
function SideMenu.Bottom()
	ensure()
	return math.floor((gridTop + bar.Size.Y.Offset) * Kit.Scale())
end

function SideMenu.Add(id, labelText, iconFactory, _order)
	ensure()
	local isTile = HudIcons.Tiles[id] ~= nil
	local activated = Instance.new("BindableEvent")
	local entry
	if isTile then
		entry = makeTile(id, labelText, iconFactory)
		if id == "Wardrobe" and not Features.Wardrobe then entry.hidden = true end
		entry.button.Activated:Connect(function() activated:Fire() end)
	else
		local button = New("TextButton", { Name = id, Text = "", Visible = false, Parent = bar })
		entry = { id = id, order = 99, button = button, placeholder = true, count = 0, dot = false,
			paint = function() end, paintBadge = function() end }
	end
	table.insert(entries, entry)
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
	function api.SetText() end -- (tiles keep their labels from Config/HudIcons)
	-- a tile that only shows sometimes (the Shop while nothing is for sale); never shows a switched-off feature
	function api.SetShown(_, on)
		entry.hidden = not on or (id == "Wardrobe" and not Features.Wardrobe)
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

-- SetTraining(true): on a machine the open menus close and the tiles fold away; they come back when you leave.
function SideMenu.SetTraining(on)
	ensure()
	if training == on then return end
	training = on
	if on then UIBus.CloseAllPanels() end
	layout(true)
end

function SideMenu.IsTraining()
	return training
end

function SideMenu.IsHidden()
	return hiddenAll
end

function SideMenu.IsCollapsed()
	return folded()
end

function SideMenu.IsCompact()
	return false
end

return SideMenu
