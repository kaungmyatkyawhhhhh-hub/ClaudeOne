-- Menu (client).
--  * PC: a 2-column grid of about 90px square tiles on the left edge, vertically centered below the Roblox top bar, even
--    8px gaps (smaller only if the screen is short, so every tile is always on screen). Big icon, bold outlined label,
--    colored border per tile, slight 3D look, bounce on hover and press (Config.HudIcons has the colors and icons).
--  * An arrow above the tiles folds them all away and brings them back (like the Growth Spurt bar's arrow: it stays put
--    and points up when open, down when folded; a dot on it while folded when a tile has something new).
--  * Phones (touch without a keyboard): the same tiles, smaller, hanging from the arrow at the top left and clear of the
--    thumbstick. They start folded, fold again after picking one, and never share the screen with a side panel.
-- SideMenu.Add returns { button, SetActive(on), SetDot(on), Activated } (Activated: use it, not button.Activated).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local HudIcons = require(script.Parent.Parent.Config.HudIcons)
local UIBus = require(script.Parent.UIBus)
local New, Colors, Spacing, Alpha = Theme.New, Theme.Colors, Theme.Spacing, Theme.Alpha

local SideMenu = {}

local SIZE = { Max = 90, Min = 64, PhoneMax = 64, PhoneMin = 48 } -- px: PC tile (about 90, smaller only if the screen is short), phone tile
local THUMB_ROOM = 120 -- px at the bottom of a phone screen the tiles leave free (the thumbstick)
local GAP = Spacing.S
local MARGIN = Spacing.M  -- from the left edge (and top/bottom of the free space)
local TOP_RESERVE = Spacing.S + Theme.MinTouch + Spacing.S -- the top bar's pills (coins) live above this line
local ARROW_HEIGHT = 26
local ARROW_GAP = 4      -- between the arrow and the first row of tiles

local changed = Instance.new("BindableEvent")
SideMenu.Changed = changed.Event -- fires when the bar's size or position changes (panels follow it)

local gui, bar
local entries = {}       -- every added button, in LayoutOrder
local phone = false
local training = false
local hiddenAll = false
local size = SIZE.Max
local columns = 1

local function isPhone()
	if RunService:IsStudio() and workspace:GetAttribute("TestPhoneLayout") == true then return true end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function visibleEntries()
	local list = {}
	for _, entry in ipairs(entries) do
		if not training or entry.id == "Stats" then table.insert(list, entry) end
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.id < b.id -- (same order: a fixed order, not a shuffle)
	end)
	return list
end

-- One square tile (owner's UI v7 look): a big icon on top, a bold outlined label at the bottom, a colored border per tile,
-- a slight 3D look (lighter top, darker bottom edge that the face sinks into when pressed) and a bounce on hover/press.
-- Returns the button and its parts.
local function darker(color, amount)
	return color:Lerp(Colors.Shadow, amount)
end

local function makeButton(id, labelText, iconFactory, side, order)
	local cfg = HudIcons.Tiles[id]
	local accent = cfg and cfg.accent or HudIcons.DefaultAccent
	local button = New("TextButton", {
		Name = id,
		LayoutOrder = order,
		Size = UDim2.fromOffset(side, side),
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
	})
	-- the dark bottom edge (full size) and the face on top of it (a little shorter, so the edge shows underneath)
	local lip = New("Frame", { Name = "Lip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = darker(accent, Theme.Tile.LipDarken), Parent = button }, { Theme.Round("Button") })
	local border = New("UIStroke", { Color = accent, Thickness = 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local face = New("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = darker(accent, Theme.Tile.FaceDarken),
		ZIndex = 2,
		Parent = button,
	}, {
		Theme.Round("Button"),
		border,
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Colors.Text, Theme.Tile.ShadeBottom) }),
	})
	Theme.BindPress(button)
	-- the bounce: press squashes the tile and the face sinks onto its edge; letting go springs back past 1 and settles
	local scale = button:FindFirstChildOfClass("UIScale")
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Theme.Tween(face, { Position = UDim2.fromOffset(0, 3) }, 0.06)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Theme.Tween(face, { Position = UDim2.fromOffset(0, 0) }, 0.2, Theme.Motion.Bounce)
			if scale then Theme.Tween(scale, { Scale = 1 }, 0.28, Theme.Motion.Bounce) end
		end
	end)
	Theme.AddDepth(button, "Button")
	-- the content grows a little on hover (its own UIScale; the press squash is on the button)
	local content = New("Frame", { Name = "Content", Size = UDim2.new(1, 0, 1, -5), BackgroundTransparency = 1, ZIndex = 3, Parent = button })
	local grow = New("UIScale", { Parent = content })
	local iconSlot = New("Frame", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 3, Parent = content })
	if cfg and cfg.image and cfg.image ~= "" then
		New("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = cfg.image, ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = iconSlot })
	else
		iconFactory(Colors.Text).Parent = iconSlot
	end
	-- bold label with a dark outline (the one place that isn't Montserrat, see Theme.TileFont)
	local label = New("TextLabel", {
		Name = "Label",
		Text = labelText,
		FontFace = Theme.TileFont,
		TextSize = Theme.Tile.LabelSmall,
		TextColor3 = Colors.Text,
		TextStrokeColor3 = Theme.TileStroke,
		TextStrokeTransparency = 0,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 3,
		Parent = content,
	})
	local dot = New("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -Spacing.XS - 2, 0, Spacing.XS + 2),
		Size = UDim2.fromOffset(Spacing.S + 2, Spacing.S + 2),
		BackgroundColor3 = Colors.Text,
		Visible = false,
		ZIndex = 5,
		Parent = button,
	}, { Theme.Round("Round"), New("UIStroke", { Color = Theme.TileStroke, Thickness = 1.5 }) })
	local parts = { button = button, border = border, label = label, icon = iconSlot, grow = grow, dot = dot, face = face, lip = lip, active = false, hover = false }
	function parts.resize(side2)
		button.Size = UDim2.fromOffset(side2, side2)
		local iconSize = math.floor(side2 * 0.5)
		iconSlot.Size = UDim2.fromOffset(iconSize, iconSize)
		iconSlot.Position = UDim2.new(0.5, 0, 0, math.floor(side2 * 0.1))
		label.TextSize = side2 >= Theme.Tile.BigFrom and Theme.Tile.LabelBig or Theme.Tile.LabelSmall
		label.Size = UDim2.new(1, -2, 0, label.TextSize + 4)
		label.Position = UDim2.new(0.5, 0, 1, -math.floor(side2 * 0.05))
	end
	function parts.paint()
		local color = parts.active and accent or (parts.hover and darker(accent, 0.28) or darker(accent, Theme.Tile.FaceDarken))
		Theme.Tween(face, { BackgroundColor3 = color }, 0.15)
		Theme.Tween(border, { Color = parts.active and Theme.Tile.ActiveBorder or accent, Transparency = (parts.active or parts.hover) and 0 or 0.1 }, 0.15)
		Theme.Tween(grow, { Scale = parts.hover and 1.1 or 1 }, 0.22, Theme.Motion.Bounce)
	end
	button.MouseEnter:Connect(function() parts.hover = true; parts.paint() end)
	button.MouseLeave:Connect(function() parts.hover = false; parts.paint() end)
	parts.resize(side)
	return parts
end

-- The tiles and the arrow above them. PC: a 2-column grid of tiles (about 90px), vertically centered, sized so every
-- tile fits between the top bar and the bottom of the screen. Phones: the same tiles, smaller (48-64px, up to 3
-- columns), hanging from the arrow at the top left and clear of the thumbstick.
local collapsed = false
local arrow, arrowIcon, arrowDot = nil, nil, nil

-- columns, rows and tile size that fit `count` tiles into `room` px of height
local function fit(count, room, minSize, maxSize, maxColumns)
	local first = count > 1 and 2 or 1
	for cols = first, math.max(first, maxColumns) do
		local rows = math.ceil(count / cols)
		local side = math.floor((room - (rows - 1) * GAP) / rows)
		if side >= minSize or cols >= maxColumns then return cols, rows, math.clamp(side, minSize, maxSize) end
	end
	return first, math.ceil(count / first), minSize
end

local function arrowSize()
	return if phone then Vector2.new(Theme.MinTouch, Theme.MinTouch) else Vector2.new(40, ARROW_HEIGHT)
end

-- while folded, the arrow carries the dot of any tile that has something new (the tutorial lights the Stats dot too)
local function refreshArrowDot()
	if not arrowDot then return end
	local any = false
	for _, entry in ipairs(entries) do
		if entry.pc.dot.Visible then any = true end
	end
	arrowDot.Visible = collapsed and any
end

local function layout()
	if not bar then return end
	local list = visibleEntries()
	local screenSize = gui.AbsoluteSize -- inside the safe area (below the top bar)
	local count = math.max(#list, 1)
	local arrowBox = arrowSize()
	local rows, tilesTop
	if phone then
		-- under the arrow at the top left; the bottom of the screen stays free for the thumbstick
		tilesTop = Spacing.S + arrowBox.Y + GAP
		columns, rows, size = fit(count, screenSize.Y - tilesTop - THUMB_ROOM, SIZE.PhoneMin, SIZE.PhoneMax, 3)
	else
		-- the tiles (and the arrow above them) stay below the coins pill and above the bottom margin
		local top = TOP_RESERVE + ARROW_HEIGHT + ARROW_GAP
		columns, rows, size = fit(count, screenSize.Y - top - MARGIN, SIZE.Min, SIZE.Max, 2)
		-- vertically centered, but never up under the top bar
		tilesTop = math.max(top, math.floor((screenSize.Y - (rows * size + (rows - 1) * GAP)) / 2))
	end
	for index, entry in ipairs(list) do
		local parts = entry.pc
		parts.resize(size)
		local row = (index - 1) // columns
		local column = (index - 1) % columns
		parts.button.Position = UDim2.fromOffset(column * (size + GAP), row * (size + GAP))
		parts.button.Visible = true
	end
	for _, entry in ipairs(entries) do
		if not table.find(list, entry) then entry.pc.button.Visible = false end
	end
	bar.Size = UDim2.fromOffset(columns * size + (columns - 1) * GAP, rows * size + (rows - 1) * GAP)
	bar.AnchorPoint = Vector2.new(0, 0)
	bar.Position = UDim2.fromOffset(MARGIN, tilesTop)
	bar.Visible = not hiddenAll and not collapsed and not (phone and training)
	-- the arrow stays put (like the Growth Spurt bar's): just above the tiles on PC, at the top left on phones
	arrow.Size = UDim2.fromOffset(arrowBox.X, arrowBox.Y)
	arrow.Position = if phone then UDim2.fromOffset(MARGIN, Spacing.S) else UDim2.fromOffset(MARGIN, tilesTop - ARROW_HEIGHT - ARROW_GAP)
	arrow.Visible = not hiddenAll and not training
	refreshArrowDot()
	changed:Fire()
end

-- Fold the tiles away (true) or bring them back, with a short fade. Phones: the open menu and a side panel never share
-- the screen (opening the menu closes the panel; a panel opening folds the menu, see ensure()).
local function setCollapsed(value)
	if collapsed == value then return end
	collapsed = value
	Theme.Tween(arrowIcon, { Rotation = collapsed and 90 or -90 }, 0.2)
	if not collapsed then
		if phone then UIBus.PanelOpened("Menu") end
		layout()
		Theme.Fade(bar, true, 0.2)
	else
		refreshArrowDot()
		-- a tile folded away under the pointer (or a finger) never gets MouseLeave: drop its hover look now
		for _, entry in ipairs(entries) do
			if entry.pc.hover then
				entry.pc.hover = false
				entry.pc.paint()
			end
		end
		local tween = Theme.Fade(bar, false, 0.2)
		if tween then
			tween.Completed:Connect(function()
				if collapsed then layout() end
			end)
		else
			layout()
		end
	end
end

local function ensure()
	if bar then return bar end
	phone = isPhone()
	collapsed = phone -- phones start folded (the screen is small); PC starts open
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Theme.ScreenGui({ Name = "MainHud", DisplayOrder = 4, Parent = playerGui })
	bar = New("Frame", { Name = "MenuBar", AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui })
	-- the arrow: folds all the tiles away and brings them back (up = open, down = folded, like the Growth Spurt bar)
	arrow = New("TextButton", { Name = "MenuArrow", Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Panel, BackgroundTransparency = Alpha.Panel, Parent = gui }, { Theme.Round("Button"), Theme.Stroke() })
	Theme.BindPress(arrow)
	Theme.AddDepth(arrow, "Button")
	arrowIcon = require(script.Parent.Icons).Chevron(1, Colors.Text)
	arrowIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowIcon.Position = UDim2.fromScale(0.5, 0.5)
	arrowIcon.Size = UDim2.fromOffset(22, 22)
	arrowIcon.Rotation = collapsed and 90 or -90
	arrowIcon.Parent = arrow
	arrowDot = New("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -Spacing.XS, 0, Spacing.XS), Size = UDim2.fromOffset(Spacing.S, Spacing.S), BackgroundColor3 = Colors.Text, Visible = false, ZIndex = 3, Parent = arrow }, { Theme.Round("Round") })
	arrow.Activated:Connect(function() setCollapsed(not collapsed) end)
	-- phones: a side panel opening (or getting on a machine) folds the menu away
	UIBus.RegisterPanel("Menu", function()
		if phone then setCollapsed(true) end
	end)


	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
	local function modeChanged()
		local now = isPhone()
		if now == phone then return end
		phone = now
		-- each mode starts the way it starts on join (phones folded, PC open)
		collapsed = phone
		arrowIcon.Rotation = collapsed and 90 or -90
		layout()
		if not collapsed then Theme.Fade(bar, true, 0.2) end
	end
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(modeChanged)
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(modeChanged)
	workspace:GetAttributeChangedSignal("TestPhoneLayout"):Connect(modeChanged)
	return bar
end

function SideMenu.Column()
	return ensure()
end

-- Pixel x of the menu's right edge, for panels that open beside it. Phones: the arrow's (the tiles fold away there when
-- a panel opens).
function SideMenu.Right()
	ensure()
	if phone then return MARGIN + Theme.MinTouch end
	return MARGIN + columns * size + (columns - 1) * GAP
end

-- Pixel x of the right edge of what the menu shows right now (the arrow alone while folded; 0 when hidden), for small
-- things that sit beside it (the phone notifications).
function SideMenu.VisibleRight()
	ensure()
	if bar.Visible then return MARGIN + columns * size + (columns - 1) * GAP end
	if arrow.Visible then return MARGIN + arrowSize().X end
	return 0
end

-- Pixel y (inside the safe area) of the menu's bottom edge (the arrow's while folded).
function SideMenu.Bottom()
	ensure()
	local target = if bar.Visible then bar else arrow
	return target.AbsolutePosition.Y - gui.AbsolutePosition.Y + target.AbsoluteSize.Y
end

function SideMenu.Add(id, labelText, iconFactory, order)
	ensure()
	order = order or 1
	local entry = { id = id, order = order }
	entry.pc = makeButton(id, labelText, iconFactory, size, order)
	entry.pc.button.Parent = bar
	table.insert(entries, entry)
	-- (the arrow carries the dot while folded; the tutorial sets a tile's dot directly, so watch the dot itself)
	entry.pc.dot:GetPropertyChangedSignal("Visible"):Connect(refreshArrowDot)

	local activated = Instance.new("BindableEvent")
	entry.pc.button.Activated:Connect(function()
		-- phones: picking a tile folds the menu away (the screen is small)
		if phone then setCollapsed(true) end
		activated:Fire()
	end)

	local api = { button = entry.pc.button, Activated = activated.Event }
	function api.SetActive(_, on)
		entry.pc.active = on
		entry.pc.paint()
	end
	function api.SetDot(_, on)
		entry.pc.dot.Visible = on
	end
	layout()
	return api
end

-- SetHidden(true) hides the whole menu (a screen that needs the full width, like Genetics on phones).
function SideMenu.SetHidden(on)
	ensure()
	hiddenAll = on
	layout()
end

-- SetTraining(true): a clean HUD while on a machine. PC keeps only Stats; phones hide the whole menu (arrow too).
function SideMenu.SetTraining(on)
	ensure()
	training = on
	if on then UIBus.CloseAllPanels() end -- (folds the phone menu too)
	layout()
end

function SideMenu.IsTraining()
	return training
end

-- true while a screen has hidden the whole menu (SetHidden), e.g. Genetics on phones
function SideMenu.IsHidden()
	return hiddenAll
end

-- true on phones (the tiles hang from the arrow at the top left and fold away after a pick)
function SideMenu.IsCompact()
	ensure()
	return phone
end

return SideMenu
