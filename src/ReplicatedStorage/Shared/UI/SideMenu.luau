-- Menu (client).
--  * PC: a 2-column grid of about 90px square tiles on the left edge, vertically centered below the Roblox top bar, even
--    8px gaps (smaller only if the screen is short, so every tile is always on screen). Big icon, bold outlined label,
--    colored border per tile, slight 3D look, bounce on hover and press (Config.HudIcons has the colors and icons).
--  * Phones (touch without a keyboard): one Menu button at the top left (clear of the thumbstick); it opens the full
--    menu as a clean grid of the same buttons in the middle of the screen. Picking one (or tapping outside) closes it.
-- SideMenu.Add returns { button, SetActive(on), SetDot(on), Activated } (same as before, so screens didn't change).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local HudIcons = require(script.Parent.Parent.Config.HudIcons)
local New, Colors, Spacing, Alpha = Theme.New, Theme.Colors, Theme.Spacing, Theme.Alpha

local SideMenu = {}

local SIZE = { Max = 90, Min = 64, Grid = 76 } -- px: PC tile (about 90, smaller only if the screen is short), phone grid tile
local GAP = Spacing.S
local MARGIN = Spacing.M  -- from the left edge (and top/bottom of the free space)
local ACTIVE_FILL = 0.8   -- white fill transparency of the open menu's button
local HOVER_FILL = 0.4    -- the dark fill gets a little lighter while hovered
local HOVER_SCALE = 1.06

local changed = Instance.new("BindableEvent")
SideMenu.Changed = changed.Event -- fires when the bar's size or position changes (panels follow it)

local gui, bar, toggle, gridScreen, grid
local entries = {}       -- every added button, in LayoutOrder
local phone = false
local gridOpen = false
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
	table.sort(list, function(a, b) return a.order < b.order end)
	return list
end

-- One square tile (owner's UI v7 look): a big icon on top, a bold outlined label at the bottom, a colored border per tile,
-- a slight 3D look (lighter top, darker bottom edge that the face sinks into when pressed) and a bounce on hover/press.
-- Returns the button and its parts.
local function darker(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount)
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
	local lip = New("Frame", { Name = "Lip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = darker(accent, 0.66), Parent = button }, { Theme.Round("Button") })
	local border = New("UIStroke", { Color = accent, Thickness = 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local face = New("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = darker(accent, 0.5),
		ZIndex = 2,
		Parent = button,
	}, {
		Theme.Round("Button"),
		border,
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 150)) }),
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
		TextSize = 14,
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
		label.TextSize = side2 >= 80 and 17 or 14
		label.Size = UDim2.new(1, -2, 0, label.TextSize + 4)
		label.Position = UDim2.new(0.5, 0, 1, -math.floor(side2 * 0.05))
	end
	function parts.paint()
		local color = parts.active and accent or (parts.hover and darker(accent, 0.28) or darker(accent, 0.5))
		Theme.Tween(face, { BackgroundColor3 = color }, 0.15)
		Theme.Tween(border, { Color = parts.active and Color3.new(1, 1, 1) or accent, Transparency = (parts.active or parts.hover) and 0 or 0.1 }, 0.15)
		Theme.Tween(grow, { Scale = parts.hover and 1.1 or 1 }, 0.22, Theme.Motion.Bounce)
	end
	button.MouseEnter:Connect(function() parts.hover = true; parts.paint() end)
	button.MouseLeave:Connect(function() parts.hover = false; parts.paint() end)
	parts.resize(side)
	return parts
end

-- PC: a 2-column grid of tiles (about 90px), sized so every tile fits between the top bar and the bottom of the screen.
local collapsed = false
local arrow, arrowIcon = nil, nil

local function layout()
	if not bar then return end
	local list = visibleEntries()
	local screenSize = gui.AbsoluteSize -- inside the safe area (below the top bar)
	local room = screenSize.Y - MARGIN * 2
	local count = math.max(#list, 1)
	columns = count > 1 and 2 or 1
	local rows = math.ceil(count / columns)
	size = math.clamp(math.floor((room - (rows - 1) * GAP) / rows), SIZE.Min, SIZE.Max)
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
	local height = rows * size + (rows - 1) * GAP
	bar.Size = UDim2.fromOffset(columns * size + (columns - 1) * GAP, height)
	bar.Position = UDim2.new(0, MARGIN, 0.5, 0)
	bar.Visible = not phone and not hiddenAll and not collapsed
	if arrow then
		arrow.Visible = not phone and not hiddenAll and not training
		-- the arrow sits just above the buttons (or alone in the middle when they are folded away)
		arrow.Position = collapsed and UDim2.new(0, MARGIN, 0.5, 0) or UDim2.new(0, MARGIN, 0.5, -(height / 2) - 30)
		arrow.AnchorPoint = Vector2.new(0, collapsed and 0.5 or 0)
	end
	if toggle then toggle.Visible = phone and not training and not hiddenAll end
	changed:Fire()
end

local function setGrid(open)
	gridOpen = open
	if not gridScreen then return end
	if open then
		gridScreen.Enabled = true
		Theme.Fade(grid, true, 0.2)
	else
		local tween = Theme.Fade(grid, false, 0.2)
		if tween then
			tween.Completed:Connect(function()
				if not gridOpen then gridScreen.Enabled = false end
			end)
		else
			gridScreen.Enabled = false
		end
	end
end

local function ensure()
	if bar then return bar end
	phone = isPhone()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Theme.ScreenGui({ Name = "MainHud", DisplayOrder = 4, Parent = playerGui })
	bar = New("Frame", { Name = "MenuBar", AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui })
	-- arrow: folds all the left buttons away and brings them back
	arrow = New("TextButton", { Name = "MenuArrow", Size = UDim2.fromOffset(40, 26), Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Panel, BackgroundTransparency = Alpha.Panel, Visible = not phone, Parent = gui }, { Theme.Round("Button"), Theme.Stroke() })
	arrowIcon = require(script.Parent.Icons).Chevron(1, Colors.Text)
	arrowIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowIcon.Position = UDim2.fromScale(0.5, 0.5)
	arrowIcon.Size = UDim2.fromOffset(22, 22)
	arrowIcon.Rotation = 180
	arrowIcon.Parent = arrow
	arrow.Activated:Connect(function()
		collapsed = not collapsed
		Theme.Tween(arrowIcon, { Rotation = collapsed and 0 or 180 }, 0.2)
		layout()
	end)

	-- phones: one Menu button at the top left (the thumbstick is bottom left)
	toggle = New("TextButton", {
		Name = "MenuToggle",
		Position = UDim2.fromOffset(MARGIN, Spacing.S),
		Size = UDim2.fromOffset(SIZE.Max, SIZE.Max),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Alpha.Panel,
		Visible = phone,
		Parent = gui,
	}, { Theme.Round("Button"), Theme.Stroke(Colors.Border, 1, Alpha.Border) })
	Theme.BindPress(toggle)
	Theme.AddDepth(toggle, "Button")
	local lines = New("Frame", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(20, 14), BackgroundTransparency = 1, Parent = toggle })
	for i = 0, 2 do
		New("Frame", { Position = UDim2.fromOffset(0, i * 6), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Colors.Text, Parent = lines }, { Theme.Round("Segment") })
	end
	Theme.Text({ Name = "Label", Text = "Menu", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 16), Parent = toggle })
	New("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -Spacing.S, 0, Spacing.S), Size = UDim2.fromOffset(Spacing.S, Spacing.S), BackgroundColor3 = Colors.Text, Visible = false, ZIndex = 3, Parent = toggle }, { Theme.Round("Round") })
	toggle.Activated:Connect(function() setGrid(not gridOpen) end)

	-- the phone grid: a dim backdrop (tap to close) and a panel of tiles in the middle
	gridScreen = Theme.ScreenGui({ Name = "MenuGrid", DisplayOrder = 26, Enabled = false, Parent = playerGui })
	gridScreen.ScreenInsets = Enum.ScreenInsets.None
	local backdrop = New("TextButton", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, Parent = gridScreen })
	backdrop.Activated:Connect(function() setGrid(false) end)
	grid = Theme.Panel({
		Name = "Grid",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Active = true,
		Parent = gridScreen,
	}, {
		Theme.Pad("L"),
		New("UIGridLayout", {
			CellSize = UDim2.fromOffset(SIZE.Grid, SIZE.Grid),
			CellPadding = UDim2.fromOffset(Spacing.M, Spacing.M),
			FillDirectionMaxCells = 4,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
	local function modeChanged()
		local now = isPhone()
		if now == phone then return end
		phone = now
		if not phone then setGrid(false) end
		layout()
	end
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(modeChanged)
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(modeChanged)
	workspace:GetAttributeChangedSignal("TestPhoneLayout"):Connect(modeChanged)
	return bar
end

function SideMenu.Column()
	return ensure()
end

-- Pixel x of the menu's right edge, for panels that open beside it (phones: the Menu button's).
function SideMenu.Right()
	ensure()
	if phone then return MARGIN + SIZE.Max end
	return MARGIN + columns * size + (columns - 1) * GAP
end

-- Pixel y (inside the safe area) of the menu's bottom edge.
function SideMenu.Bottom()
	ensure()
	local target = phone and toggle or bar
	return target.AbsolutePosition.Y - gui.AbsolutePosition.Y + target.AbsoluteSize.Y
end

function SideMenu.Add(id, labelText, iconFactory, order)
	ensure()
	order = order or 1
	local entry = { id = id, order = order }
	entry.pc = makeButton(id, labelText, iconFactory, size, order)
	entry.pc.button.Parent = bar
	entry.tile = makeButton(id, labelText, iconFactory, SIZE.Grid, order)
	entry.tile.button.Parent = grid
	table.insert(entries, entry)

	-- one Activated signal for both copies; picking from the phone grid closes it
	local activated = Instance.new("BindableEvent")
	entry.pc.button.Activated:Connect(function() activated:Fire() end)
	entry.tile.button.Activated:Connect(function()
		setGrid(false)
		activated:Fire()
	end)

	local api = { button = entry.pc.button, Activated = activated.Event }
	function api.SetActive(_, on)
		for _, parts in ipairs({ entry.pc, entry.tile }) do
			parts.active = on
			parts.paint()
		end
	end
	function api.SetDot(_, on)
		entry.pc.dot.Visible = on
		entry.tile.dot.Visible = on
		local any = false
		for _, other in ipairs(entries) do
			if other.pc.dot.Visible then any = true end
		end
		toggle.Dot.Visible = any
	end
	layout()
	return api
end

-- SetHidden(true) hides the whole menu (a screen that needs the full width, like Genetics on phones).
function SideMenu.SetHidden(on)
	ensure()
	hiddenAll = on
	if on then setGrid(false) end
	layout()
end

-- SetTraining(true): a clean HUD while on a machine. PC keeps only Stats; phones hide the Menu button.
function SideMenu.SetTraining(on)
	ensure()
	training = on
	if on then setGrid(false) end
	layout()
end

function SideMenu.IsTraining()
	return training
end

-- true while a screen has hidden the whole menu (SetHidden), e.g. Genetics on phones
function SideMenu.IsHidden()
	return hiddenAll
end

-- true on phones (the menu is the Menu button + grid)
function SideMenu.IsCompact()
	ensure()
	return phone
end

return SideMenu
