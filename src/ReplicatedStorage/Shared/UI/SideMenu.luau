-- The left menu (owner, 13 Oct: keep the old colored tiles, only tidied). Built in mockup px inside a Kit.Root, so every
-- tile has the same size and gap on every screen and scales with it:
--  * 2 columns of rounded-square tiles (a 3rd column only if a short screen can't fit them), VERTICALLY CENTERED on the
--    left (owner, 14 Oct: AnchorPoint 0, 0.5 at 0.5 of the screen, no top offset; at most 8 tiles; the fold tween only
--    moves X). The "<" tab is centered on the tiles' right edge.
--    Each tile (owner's final kit "BLACK + GOLD", mockup 01_hud): dark glass (a graphite gradient, a faint light border,
--    a darker bottom edge the face sinks into when pressed), a white line icon (the Shop's in gold), the label in small
--    italic caps under it, a bounce on hover and press. Icons, order and labels: Config/HudIcons.Tiles. The open panel's
--    tile lights up (lighter glass, a gold border).
--  * A red dot in the top-right corner (quests ready to claim, new titles), with a number when there is one.
--  * The "<" tab on the tiles' right edge folds them away to the left (it then points ">" at the screen edge, with a red
--    dot when a folded tile has a badge) and back. The choice is saved per player (settings.menuCollapsed).
--  * On a machine, and while any window is open (the WindowOpen attribute, Kit.Modal), the menu folds away by itself and
--    comes back after (unless you had folded it).
--  * The Wardrobe tile is hidden while Config/Features.Wardrobe is false (no gap). Ids that aren't tiles any more (the
--    top bar's pills) get a hidden placeholder with the same api.
-- SideMenu.Add returns { button, SetActive(on), SetDot(on), SetBadge(n), SetText, SetShown(on), Activated }.
-- (prompt 39, 22 Oct) Tiles that open later (Config/Guides.Locks, GuideClient):
--   SideMenu.SetLocked(id, locked, onLockedTap)  locked: the tile stays (owner: never hidden), darker, a grey outline, a
--                                                GREY padlock in place of its icon, the label grey (prompt 39b); a tap
--                                                shakes it and calls onLockedTap() instead of Activated. Unlocked: it pops.
--   SideMenu.SetNew(id, on, onTapped)            the small gold "NEW" tag in its top-right corner until it's tapped once
--   (one badge per tile: LOCKED > NEW > the red "!" of SetDot / SetBadge)
--   SideMenu.Button(id)                          the tile's button (the unlock guides point at it)
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

-- (owner, 23 Oct, chrome reset: back to the earlier tiles, larger with more spacing) every tile measure is a share of the
-- tile: icon 46% (10% from the top), label 20% tall with 7% under it; 10 px corners, 10 px between tiles
SideMenu.TileSize = 58
SideMenu.Shape = { Gap = 10 / 58, Corner = 10 / 58, Icon = 0.46, IconTop = 0.10, Label = 0.20, LabelBottom = 0.07 }
SideMenu.Gap = 10
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

local windowOpen = false -- a window (Kit.Modal) is open
local function folded()
	return collapsed or training or windowOpen
end

local function refreshArrowDot()
	if not arrowDot then return end
	local any = false
	for _, entry in ipairs(entries) do
		if not entry.placeholder and not entry.hidden and (entry.count > 0 or entry.dot) then any = true end
	end
	arrowDot.Visible = folded() and any
end

-- (prompt 43) rows under the grid (SideMenu.AddFooter): { frame, height, order }
local footers = {}
local function layout(animate: boolean?)
	if not bar then return end
	local list = shownEntries()
	local size, gap = SideMenu.TileSize, SideMenu.Gap
	local footH = 0
	for _, f in ipairs(footers) do if f.frame.Visible then footH += gap + f.height end end
	-- (room for the centered grid: clear of the top bar at the top and the same at the bottom; the footer rows too)
	local room = math.max(size, root.AbsoluteSize.Y / Kit.Scale() - 2 * math.max(SideMenu.Top, SideMenu.BottomRoom) - footH)
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
	-- the footer rows, as wide as the grid
	for _, f in ipairs(footers) do
		if f.frame.Visible then
			gridH += gap
			f.frame.Position = UDim2.fromOffset(0, gridH)
			f.frame.Size = UDim2.fromOffset(gridW, f.height)
			gridH += f.height
		end
	end
	bar.Size = UDim2.fromOffset(gridW, gridH)
	local isFolded = folded()
	-- vertically centered on the screen (the rows above make sure it fits); folding only moves it sideways
	local screenH = root.AbsoluteSize.Y / Kit.Scale()
	gridTop = (screenH - gridH) / 2
	bar.AnchorPoint, arrow.AnchorPoint = Vector2.new(0, 0.5), Vector2.new(0, 0.5)
	local barPos = UDim2.new(0, isFolded and (-gridW - SideMenu.Left) or SideMenu.Left, 0.5, 0)
	local arrowPos = UDim2.new(0, isFolded and SideMenu.Left or (SideMenu.Left + gridW + gap), 0.5, 0)
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
	-- a window open: the tiles step aside (owner, 14 Oct: they covered the panels on phones)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("WindowOpen"):Connect(function()
		local open = player:GetAttribute("WindowOpen") == true
		if open ~= windowOpen then
			windowOpen = open
			layout(true)
		end
	end)
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

-- One tile. (owner, 23 Oct, chrome reset: the earlier tile, chrome) A dark graphite rounded square, a thin dark outline,
-- a 1 px top highlight, a darker bottom edge, a WHITE line icon and a clean heavy italic white label (no stroke, no mesh).
-- Gold only on the active tile (its panel is open) or a notified one (a "!" or NEW): a gold outline. Locked: dimmed, a
-- grey padlock in place of the icon, the label dimmed but readable. One badge inside the top-right corner, LOCKED > NEW (a
-- small gold "NEW" tag) > "!" (a small red chip, gentle pulse).
local GOLD = Color3.fromHex("#F2C14E")
local LOCK_GREY = Color3.fromHex("#6C6A70")
local WHITE = Color3.fromHex("#F2EEF0")
local CHUNKY = Font.fromEnum(Enum.Font.LuckiestGuy)
local Icons = require(script.Parent.Icons)
local function makeTile(id, labelText, iconFactory)
	local cfg = HudIcons.Tiles[id] or {}
	local size = SideMenu.TileSize
	local shape = SideMenu.Shape
	local radius = math.floor(size * shape.Corner + 0.5)
	local button = New("TextButton", { Name = id, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size), Parent = bar }, { New("UIAspectRatioConstraint", { AspectRatio = 1 }) }) -- (always square)
	New("Frame", { Name = "Lip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#060507"), BackgroundTransparency = 0.05, Parent = button },
		{ New("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	-- the outline: thin and dark, gold on the active / notified tile
	local border = New("UIStroke", { Name = "Outline", Color = Color3.fromHex("#060507"), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local face = New("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, -SideMenu.Lip), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0,
		ZIndex = 2, Parent = button }, {
		New("UICorner", { CornerRadius = UDim.new(0, radius) }),
		border,
		New("UIGradient", { Name = "Glass", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#2C292E"), Color3.fromHex("#18161A")) }),
	})
	-- the 1 px top highlight
	New("Frame", { Name = "Highlight", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.86, BorderSizePixel = 0, Position = UDim2.fromOffset(radius - 2, 1),
		Size = UDim2.new(1, -2 * (radius - 2), 0, 1), ZIndex = 3, Parent = face })
	local shade = New("Frame", { Name = "LockShade", BackgroundColor3 = Color3.fromHex("#050406"), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 3, Parent = face }, { New("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	local content = New("Frame", { Name = "Content", Size = UDim2.new(1, 0, 1, -SideMenu.Lip), BackgroundTransparency = 1, ZIndex = 4, Parent = face })
	local grow = New("UIScale", { Parent = content })
	local iconSize = math.floor(size * shape.Icon)
	local iconTop = math.floor(size * shape.IconTop + 0.5)
	local iconSlot = New("Frame", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, iconTop),
		Size = UDim2.fromOffset(iconSize, iconSize), BackgroundTransparency = 1, ZIndex = 4, Parent = content })
	-- the icon, white: an image, a ui icon, one of Shared/UI/Icons by name (Config/HudIcons), or the caller's
	if cfg.image and cfg.image ~= "" then
		New("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = cfg.image, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = iconSlot })
	elseif cfg.uiIcon then
		Pieces.Icon(cfg.uiIcon, WHITE, { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = iconSlot }):SetAttribute("KeepColor", true)
	elseif cfg.icon and (Icons :: any)[cfg.icon] then
		local icon = (Icons :: any)[cfg.icon](WHITE)
		icon.Parent = iconSlot
	elseif iconFactory then
		local icon = iconFactory(WHITE)
		icon.Parent = iconSlot
	end
	local padlock = Pieces.Icon("lock", LOCK_GREY, { Name = "Padlock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, iconTop),
		Size = UDim2.fromOffset(iconSize, iconSize), Visible = false, ZIndex = 4, Parent = content })
	padlock:SetAttribute("KeepColor", true)
	local label = New("TextLabel", { Name = "Label", BackgroundTransparency = 1, Text = string.upper(cfg.label or labelText), FontFace = Theme.Fonts.Display, TextSize = 10,
		TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, SideMenu.Lip - math.floor(size * shape.LabelBottom + 0.5)),
		Size = UDim2.new(1, -6, 0, math.floor(size * shape.Label + 0.5)), ZIndex = 4, Parent = content })
	Kit.Fit(label, 10, 8)
	-- the one badge, inside the top-right corner
	local newTag = New("Frame", { Name = "NewTag", BackgroundColor3 = GOLD, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(26, 12), Visible = false, ZIndex = 6, Parent = face }, { New("UICorner", { CornerRadius = UDim.new(0, 4) }) })
	New("TextLabel", { BackgroundTransparency = 1, Text = "NEW", FontFace = Theme.Fonts.Display, TextSize = 8, TextColor3 = Color3.fromHex("#1A1408"), Size = UDim2.fromScale(1, 1),
		ZIndex = 7, Parent = newTag })
	local badge = New("Frame", { Name = "Badge", BackgroundColor3 = Colors.Red, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(15, 15), Visible = false, ZIndex = 6, Parent = face }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Color3.fromHex("#2A0505"), Thickness = 1 }),
	})
	New("TextLabel", { Name = "Bang", BackgroundTransparency = 1, Text = "!", FontFace = CHUNKY, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1),
		ZIndex = 7, Parent = badge })
	local badgeScale = New("UIScale", { Parent = badge })

	local entry = { id = id, order = cfg.order or 50, button = button, label = label, count = 0, dot = false, active = false, hover = false,
		face = face, border = border, isNew = false, locked = false }
	function entry.paint()
		-- lighter glass on hover / while its panel is open; gold outline only on the active or a notified tile
		local notified = not entry.locked and (entry.isNew or entry.count > 0 or entry.dot)
		local gold = not entry.locked and (entry.active or notified)
		Theme.Tween(face, { BackgroundColor3 = (entry.active or entry.hover) and Color3.fromRGB(255, 245, 235) or Color3.new(1, 1, 1) }, 0.15)
		Theme.Tween(border, { Color = if gold then GOLD else Color3.fromHex("#060507"), Transparency = if gold and not entry.active then 0.15 else 0,
			Thickness = if gold then 2 else 1.5 }, 0.15)
		Theme.Tween(grow, { Scale = entry.hover and 1.08 or 1 }, 0.22, Theme.Motion.Bounce)
	end
	function entry.paintLock()
		shade.BackgroundTransparency = if entry.locked then 0.45 else 1
		iconSlot.Visible = not entry.locked
		padlock.Visible = entry.locked
		label.TextColor3 = if entry.locked then Color3.fromHex("#8E8B92") else WHITE
		entry.paint()
	end
	function entry.paintBadge()
		-- one badge: LOCKED (the padlock is the badge) > NEW > "!"
		newTag.Visible = entry.isNew and not entry.locked
		badge.Visible = not entry.locked and not entry.isNew and (entry.count > 0 or entry.dot)
		entry.paint()
		refreshArrowDot()
	end
	-- the "!" breathes gently
	task.spawn(function()
		while button.Parent do
			if badge.Visible then badgeScale.Scale = 1 + 0.08 * math.sin(os.clock() * 4) end
			task.wait(0.05)
		end
	end)
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

-- (prompt 43) a row under the tiles, as wide as them (the LVL pill, the gear), lower order first
function SideMenu.AddFooter(frame: GuiObject, height: number, order: number?)
	ensure()
	frame.Parent = bar
	table.insert(footers, { frame = frame, height = height, order = order or 1 })
	table.sort(footers, function(a, b) return a.order < b.order end)
	frame:GetPropertyChangedSignal("Visible"):Connect(function() layout() end)
	layout()
	return frame
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
		entry.button.Activated:Connect(function()
			-- (prompt 39) a locked tile: a shake and the "locked" toast instead
			if entry.locked then
				local face = entry.face
				task.spawn(function()
					for _, dx in ipairs({ -5, 5, -4, 4, -2, 2, 0 }) do
						face.Position = UDim2.fromOffset(dx, 0)
						task.wait(0.035)
					end
				end)
				if entry.onLockedTap then entry.onLockedTap() end
				return
			end
			if entry.isNew then
				SideMenu.SetNew(id, false)
				if entry.onNewTapped then entry.onNewTapped() end
			end
			activated:Fire()
		end)
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

local function entryOf(id)
	for _, entry in ipairs(entries) do
		if entry.id == id and not entry.placeholder then return entry end
	end
	return nil
end

function SideMenu.Button(id): GuiObject?
	local entry = entryOf(id)
	return entry and entry.button
end

function SideMenu.SetLocked(id, locked: boolean, onLockedTap)
	local entry = entryOf(id)
	if not entry then return end
	entry.onLockedTap = onLockedTap
	local wasLocked = entry.locked == true
	if wasLocked == locked then return end
	entry.locked = locked
	entry.paintLock()
	entry.paintBadge()
	if wasLocked and not locked then
		-- the padlock breaks open: the tile pops
		local scale = entry.face:FindFirstChildOfClass("UIScale") or New("UIScale", { Parent = entry.face })
		scale.Scale = 1.15
		Theme.Tween(scale, { Scale = 1 }, 0.35, Theme.Motion.Bounce)
	end
end

-- the gold NEW tag inside the top-right corner until the tile is tapped once (not while it's locked)
function SideMenu.SetNew(id, on: boolean, onTapped)
	local entry = entryOf(id)
	if not entry then return end
	if onTapped then entry.onNewTapped = onTapped end
	if entry.isNew == on then return end
	entry.isNew = on
	entry.paintBadge()
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
