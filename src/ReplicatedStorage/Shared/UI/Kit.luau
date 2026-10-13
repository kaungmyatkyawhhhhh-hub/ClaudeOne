-- Kit: the UI components (owner's UI v2, 13 Oct: Gym League style, GYM_ARC_UI_v2_gymleague_style.md + the v2 mockups),
-- built once and reused by every screen. They are drawn in the mockups' pixels (844x390 landscape phone); Kit.Root
-- scales a whole gui with the screen (UIScale from the shorter side, base 390, never wider than the 844px layout), so
-- the same numbers fit a phone, a tablet and a PC. Looks come from Theme (colors, gradients, fonts, surfaces).
--   Kit.Root(screenGui)                       -> Frame that fills the screen in mockup px (its UIScale follows the screen)
--   Kit.Text(props)                           Theme.Text with Font = "Title" | "Number" | "Label" | "Body" | "Strong"
--   Kit.Button(style, text, props?, opts?)    glossy gradient button with a label (+ opts.icon, textSize, height, width)
--   Kit.CloseButton(props?)                   the red square X with a white border
--   Kit.Chip(icon, text, props?)              dark round pill with an icon and a value (top bar)
--   Kit.Bar(color, props?, opts?)             -> track, set(f, text?), fill (chunky bar, opts.text = centered text)
--   Kit.Tag(text, color, props?)              small colored word on a tint
--   Kit.Card(props?, children?)               #28282F card (props.Piece = "card_selected" (green) / "card_gold")
--   Kit.IconTile(icon, color, size, props?)   glossy colored rounded square with a white icon
--   Kit.GradeBadge(grade, size, props?)       S / A / B / C / D badge
--   Kit.Toggle(on, onChanged, props?)         ON (green) / OFF (gray) button -> button, set(on)
--   Kit.Slider(value, onChanged, props?)      -> frame, set(value) (0..100)
--   Kit.Tabs(tabs, onSelect, props?)          tab buttons in a row (active red) -> row, select(id)
--   Kit.Modal(spec)                           a menu window: tabs above, title + red icon, red X, blur behind
--   Kit.Coin(size, props?), Kit.Format(n) "1,500", Kit.Short(n) "1.5K"
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(script.Parent:WaitForChild("Theme"))
local Pieces = require(script.Parent:WaitForChild("Pieces"))

local New, Colors = Theme.New, Theme.Colors
local Horizontal = Enum.FillDirection.Horizontal

local Kit = {}

Kit.Base = Vector2.new(844, 390) -- the mockups' screen
Kit.MinScale, Kit.MaxScale = 0.8, 2.4
Kit.HeaderHeight = 46
Kit.OpenTime = 0.18
Kit.OpenScale = 0.96
Kit.BlurSize = 10

-- The scale for a viewport: the shorter side against 390, but never so big that 844 mockup px don't fit across.
function Kit.ScaleFor(viewport: Vector2): number
	if viewport.X < 2 or viewport.Y < 2 then return 1 end
	local s = math.min(math.min(viewport.X, viewport.Y) / Kit.Base.Y, viewport.X / Kit.Base.X)
	return math.clamp(s, Kit.MinScale, Kit.MaxScale)
end

-- Studio: the Workspace attribute TestPhoneSize (a Vector2, e.g. 844, 390) lays every redesigned screen out in a phone
-- of that size in the top left of the window (scaled to fit), to check the phone layout on a PC.
local function testPhone(): Vector2?
	if not game:GetService("RunService"):IsStudio() then return nil end
	local v = Workspace:GetAttribute("TestPhoneSize")
	return typeof(v) == "Vector2" and v.X > 100 and v.Y > 100 and v or nil
end

local scaleListeners = {}
local currentScale = 1
local currentPhone = nil
local function refreshScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Kit.Base
	local phone = testPhone()
	local s
	if phone then
		-- (the phone's own scale, then blown up to fill the window)
		s = Kit.ScaleFor(phone) * math.min(viewport.X / phone.X, viewport.Y / phone.Y)
	else
		s = Kit.ScaleFor(viewport)
	end
	if math.abs(s - currentScale) < 0.001 and phone == currentPhone then return end
	currentScale, currentPhone = s, phone
	for _, fn in ipairs(scaleListeners) do task.spawn(fn, s) end
end
local function watchCamera(camera)
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale) end
end
watchCamera(Workspace.CurrentCamera)
Workspace:GetAttributeChangedSignal("TestPhoneSize"):Connect(refreshScale)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera(Workspace.CurrentCamera)
	refreshScale()
end)
refreshScale()

function Kit.Scale(): number return currentScale end
function Kit.OnScale(fn) table.insert(scaleListeners, fn); task.spawn(fn, currentScale) end

-- A frame that fills the screen gui, measured in mockup px (so 844 wide on the mockup phone).
function Kit.Root(screenGui: Instance, name: string?): Frame
	local root = New("Frame", { Name = name or "Root", BackgroundTransparency = 1, Parent = screenGui })
	local scale = New("UIScale", { Parent = root })
	Kit.OnScale(function(s)
		scale.Scale = s
		if currentPhone then
			local units = Kit.ScaleFor(currentPhone)
			root.Size = UDim2.fromOffset(currentPhone.X / units, currentPhone.Y / units)
		else
			root.Size = UDim2.fromScale(1 / s, 1 / s)
		end
	end)
	return root
end

------------------------------------------------------------------------
-- Text
------------------------------------------------------------------------
local FONTS = {
	Title = "SemiBold", Number = "SemiBold", Body = "Regular", Strong = "Strong", Label = "SemiBold",
}
-- props.Font: Title / Number / Label (FredokaOne, white with a black outline; Label is small and gray), Body (Montserrat
-- SemiBold), Strong (Montserrat Bold). props.TextSize: mockup px. props.Upper = true makes it UPPERCASE.
function Kit.Text(props)
	local kind = props.Font or "Body"
	props.Font = FONTS[kind] or kind
	if kind == "Label" then
		props.TextColor3 = props.TextColor3 or Colors.Muted
		props.TextSize = props.TextSize or Theme.TextSize.Label
	end
	props.TextSize = props.TextSize or 12
	return Theme.Text(props)
end

function Kit.Coin(size: number, props: { [string]: any }?)
	local icon = Pieces.Icon("coin", Color3.new(1, 1, 1), { Size = UDim2.fromOffset(size, size) })
	icon:SetAttribute("KeepColor", true)
	for k, v in pairs(props or {}) do (icon :: any)[k] = v end
	return icon
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
-- opts: icon = icon name (or "coin"), textSize, iconColor, height (default 36), width (default auto), upper (default true)
function Kit.Button(style: string, text: string, props: { [string]: any }?, opts: { [string]: any }?)
	props = props or {}
	opts = opts or {}
	local height = opts.height or 36
	props.Size = props.Size or UDim2.fromOffset(opts.width or 0, height)
	if not opts.width and not (props :: any).AutomaticSize then (props :: any).AutomaticSize = Enum.AutomaticSize.X end
	local lip = math.floor(height * Theme.LipHeight)
	local button = Theme.Button(style, props, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, lip) }),
		Theme.List(Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local textSize = opts.textSize or math.floor(height * 0.46)
	if opts.icon then
		local iconSize = math.floor(textSize * 1.05)
		local icon
		if opts.icon == "coin" then
			icon = Kit.Coin(iconSize)
		else
			icon = Pieces.Icon(opts.icon, opts.iconColor or Colors.Text, { Size = UDim2.fromOffset(iconSize, iconSize) })
			if opts.iconColor then icon:SetAttribute("KeepColor", true) end
		end
		icon.LayoutOrder = 1
		icon.Parent = button
	end
	local label = Kit.Text({ Name = "Label", LayoutOrder = 2, Text = text, Font = "Title", TextSize = textSize,
		Upper = opts.upper ~= false and true or false,
		Size = UDim2.fromOffset(0, height - lip), AutomaticSize = Enum.AutomaticSize.X, Parent = button })
	Theme.SetButtonStyle(button, style)
	return button, label
end

-- Sets a Kit.Button's text and style together (e.g. BUY -> OWNED).
function Kit.SetButton(button, style: string?, text: string?)
	if style then Theme.SetButtonStyle(button, style) end
	local label = button:FindFirstChild("Label")
	if text and label then label.Text = text end
end

-- The red square X with a white border (top-right of a panel).
function Kit.CloseButton(props: { [string]: any }?)
	props = props or {}
	props.Name = props.Name or "Close"
	props.Size = props.Size or UDim2.fromOffset(38, 38)
	local button = Theme.Button("Red", props, {})
	local stroke = button:FindFirstChild("Border")
	stroke.Color, stroke.Thickness = Color3.new(1, 1, 1), 3
	local x = Pieces.Icon("x", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(0.62, 0.62), Parent = button })
	x:SetAttribute("KeepColor", true)
	return button
end

------------------------------------------------------------------------
-- Small pieces
------------------------------------------------------------------------
-- A dark round pill with an icon and a value (top bar: coins, height, level). icon: an icon name, "coin", or nil.
function Kit.Chip(icon: string?, text: string, props: { [string]: any }?)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(0, Theme.PillHeight)
	if not props.AutomaticSize then props.AutomaticSize = Enum.AutomaticSize.X end
	props.Piece = "pill"
	local chip = Theme.Panel(props, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }),
		Theme.List(Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local h = props.Size.Y.Offset
	if icon == "coin" then
		Kit.Coin(math.floor(h * 0.6), { LayoutOrder = 1, Parent = chip })
	elseif icon then
		Pieces.Icon(icon, Colors.Text, { LayoutOrder = 1, Size = UDim2.fromOffset(math.floor(h * 0.52), math.floor(h * 0.52)), Parent = chip })
	end
	Kit.Text({ Name = "Value", LayoutOrder = 2, Text = text, Font = "Body", TextSize = math.floor(h * 0.44),
		Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, Parent = chip })
	return chip
end

-- A chunky bar: dark track with an outline, a glossy fill of `color`, optional text in the middle (opts.text = true).
-- Returns track, set(fraction, text?), fill.
function Kit.Bar(color: Color3, props: { [string]: any }?, opts: { [string]: any }?)
	props = props or {}
	opts = opts or {}
	props.Size = props.Size or UDim2.new(1, 0, 0, 14)
	props.BackgroundColor3 = Colors.Well
	props.BackgroundTransparency = 0.05
	local track = New("Frame", props, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = opts.outline or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local fill = New("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), Parent = track }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIGradient", { Name = "Gloss", Rotation = 90, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.2)) }),
	})
	local label
	if opts.text then
		label = Kit.Text({ Name = "Text", Text = "", Font = "Number", TextSize = opts.textSize or math.max(10, math.floor(props.Size.Y.Offset * 0.72)),
			Size = UDim2.fromScale(1, 1), ZIndex = (track.ZIndex or 1) + 2, Parent = track })
	end
	local function set(f: number, text: string?)
		f = math.clamp(f, 0, 1)
		fill.Visible = f > 0
		fill.Size = UDim2.new(f, 0, 1, 0)
		if label and text then label.Text = text end
	end
	set(0)
	return track, set, fill
end

local function tint(color: Color3, amount: number?)
	return color:Lerp(Colors.Panel, amount or 0.75)
end
Kit.Tint = tint

-- A small colored word on a darker tint of its color (e.g. "CHEST", "RARE").
function Kit.Tag(text: string, color: Color3, props: { [string]: any }?)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(0, 18)
	if not props.AutomaticSize then props.AutomaticSize = Enum.AutomaticSize.X end
	props.BackgroundColor3 = props.BackgroundColor3 or tint(color, 0.7)
	props.ImageColor3 = nil
	local tag = New("Frame", props, {
		New("UICorner", { CornerRadius = Theme.Corner.Tag }),
		New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
	Kit.Text({ Name = "Text", Text = text, Font = "Title", TextSize = math.floor(props.Size.Y.Offset * 0.66), TextColor3 = color,
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = tag })
	return tag
end

function Kit.Card(props: { [string]: any }?, children: { Instance }?)
	props = props or {}
	props.Piece = props.Piece or "card"
	return Theme.Panel(props, children)
end

-- A rounded square in a glossy color with a white icon (quest rows, smoothie items, toasts).
function Kit.IconTile(icon: string, color: Color3, size: number, props: { [string]: any }?)
	props = props or {}
	props.Size = UDim2.fromOffset(size, size)
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	props.ImageColor3 = nil
	local tile = New("Frame", props, {
		New("UICorner", { CornerRadius = UDim.new(0, math.max(6, math.floor(size * 0.22))) }),
		New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Name = "Gloss", Rotation = 90, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.25)) }),
	})
	Pieces.Icon(icon, Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.58, 0.58), Parent = tile }):SetAttribute("KeepColor", true)
	return tile
end
function Kit.SetTileColor(tile, color: Color3)
	local gloss = tile:FindFirstChild("Gloss")
	if gloss then gloss.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.25)) end
end

-- Grade badges (mockup 07): S red, A blue, B gold, C green, D gray; a rounded square with a white-outlined letter.
Kit.GradeColors = {
	S = Colors.Red, A = Color3.fromHex("#2F7BEA"), B = Color3.fromHex("#F2B51F"), C = Color3.fromHex("#3DBA4A"), D = Color3.fromHex("#5A5A66"),
}
function Kit.GradeBadge(grade: string, size: number, props: { [string]: any }?)
	props = props or {}
	local badge = Kit.IconTile("star", Kit.GradeColors[grade] or Kit.GradeColors.D, size, props)
	local icon = badge:FindFirstChild("Icon")
	if icon then icon:Destroy() end
	local stroke = badge:FindFirstChild("Border")
	if stroke then stroke.Color, stroke.Thickness = Color3.new(1, 1, 1), 2 end
	Kit.Text({ Name = "Letter", Text = grade, Font = "Title", TextSize = math.floor(size * 0.66), Size = UDim2.fromScale(1, 1), Parent = badge })
	return badge
end
function Kit.SetGrade(badge, grade: string)
	Kit.SetTileColor(badge, Kit.GradeColors[grade] or Kit.GradeColors.D)
	local letter = badge:FindFirstChild("Letter")
	if letter then letter.Text = grade end
end

-- ON / OFF button (mockup 10): green ON, gray OFF. Returns button, set(on).
function Kit.Toggle(on: boolean, onChanged: (boolean) -> (), props: { [string]: any }?)
	props = props or {}
	local button = Kit.Button(on and "Green" or "Gray", on and "On" or "Off", props, { width = props.Size and props.Size.X.Offset or 60, height = props.Size and props.Size.Y.Offset or 30 })
	local state = on
	local function set(value: boolean)
		state = value
		Kit.SetButton(button, value and "Green" or "Gray", value and "On" or "Off")
	end
	button.Activated:Connect(function()
		set(not state)
		onChanged(state)
	end)
	return button, set
end

-- value 0..100; onChanged(value) while dragging
function Kit.Slider(value: number, onChanged: (number) -> (), props: { [string]: any }?)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(120, 22)
	props.BackgroundTransparency = 1
	local frame = New("Frame", props)
	local track, setFill = Kit.Bar(Colors.Green, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 10), Parent = frame })
	local knob = New("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Colors.Text, ZIndex = 3, Parent = frame }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 2 }),
	})
	local current = value
	local function set(v: number)
		current = math.clamp(math.floor(v + 0.5), 0, 100)
		setFill(current / 100)
		knob.Position = UDim2.new(current / 100, 0, 0.5, 0)
	end
	set(value)
	local dragging = false
	local function fromInput(input)
		local x = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		set(x * 100)
		onChanged(current)
	end
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromInput(input) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	frame.Active = true
	return frame, set
end

-- Tabs ABOVE a panel (mockups 04-10): separate buttons in a row, the active one red, the others dark gray.
-- tabs = { { id = "Passes", text = "Passes", icon = "star" }, ... }; onSelect(id). Returns row, select(id).
function Kit.Tabs(tabs, onSelect: (string) -> (), props: { [string]: any }?)
	props = props or {}
	local h = props.Size and props.Size.Y.Offset or 30
	props.Size = UDim2.fromOffset(0, h)
	props.AutomaticSize = Enum.AutomaticSize.X
	props.BackgroundTransparency = 1
	local row = New("Frame", props, { Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom) })
	local items = {}
	local function select(id: string)
		for _, item in ipairs(items) do
			Theme.SetButtonStyle(item.button, item.id == id and "Red" or "Dark")
		end
	end
	for order, tab in ipairs(tabs) do
		local button = Kit.Button("Dark", tab.text, { Name = tab.id, LayoutOrder = order, Parent = row },
			{ height = h, icon = tab.icon, textSize = math.floor(h * 0.56), upper = false })
		table.insert(items, { id = tab.id, button = button })
		button.Activated:Connect(function()
			select(tab.id)
			onSelect(tab.id)
		end)
	end
	if tabs[1] then select(tabs[1].id) end
	return row, select
end

------------------------------------------------------------------------
-- Modal panel (mockups 04-10): tabs above the panel, a title with a red icon inside it, the red X on the top-right
-- corner, the game blurred and darkened behind.
------------------------------------------------------------------------
-- spec: { name, title, icon? (Config/UI.Icons name for the red title icon), width, height (mockup px), tabs?, onTab?,
--         onClose?, displayOrder?, noTitle? }
-- Returns modal = { gui, root, panel, body, title, open(), close(), isOpen(), selectTab(id), setTitle(text, icon?) }.
local openModals = 0
local blur = nil
local function setBlur(on: boolean)
	openModals = math.max(0, openModals + (on and 1 or -1))
	if not blur or not blur.Parent then
		blur = Lighting:FindFirstChild("ModalBlur") or New("BlurEffect", { Name = "ModalBlur", Size = 0, Parent = Lighting })
	end
	Theme.Tween(blur, { Size = openModals > 0 and Kit.BlurSize or 0 }, Kit.OpenTime)
end
Kit.SetBlur = setBlur

local function formatInt(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then sign, s = "-", string.sub(s, 2) end
	return sign .. string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,"))):gsub("^,", "")
end
Kit.Format = formatInt

-- 1500 -> "1.5K", 2000 -> "2K", 1200000 -> "1.2M"
function Kit.Short(n: number): string
	local function trim(x) return (string.format("%.1f", x):gsub("%.0$", "")) end
	if n >= 1e6 then return trim(n / 1e6) .. "M" end
	if n >= 1e3 then return trim(n / 1e3) .. "K" end
	return tostring(math.floor(n))
end

Kit.TabHeight = 30
Kit.TitleHeight = 46

local activeModal = nil -- one menu at a time: opening one closes the other
function Kit.Modal(spec)
	local player = Players.LocalPlayer
	local gui = Theme.ScreenGui({ Name = spec.name, Enabled = false, DisplayOrder = spec.displayOrder or 30,
		Parent = player:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.None
	local backdrop = New("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Shadow,
		BackgroundTransparency = Theme.Alpha.Backdrop, Size = UDim2.fromScale(1, 1), Parent = gui })
	local root = Kit.Root(gui)
	local width, height = spec.width or 600, spec.height or 290
	-- the group: tabs row on top, the panel under it; centred a little below the middle (under the top bar)
	local group = New("Frame", { Name = "Group", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14), Size = UDim2.fromOffset(width, height + Kit.TabHeight + 10), Parent = root })
	local pop = New("UIScale", { Parent = group })
	local panel = Theme.Panel({ Name = "Panel", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(width, height), Active = true, Parent = group })
	local selectTab = nil
	if spec.tabs then
		local row
		row, selectTab = Kit.Tabs(spec.tabs, spec.onTab or function() end, { Name = "Tabs", Size = UDim2.fromOffset(0, Kit.TabHeight), Parent = group })
		row.Position = UDim2.fromOffset(0, 0)
	end
	local titleRow = New("Frame", { Name = "TitleRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -32, 0, Kit.TitleHeight - 6), Visible = not spec.noTitle, Parent = panel }, {
		Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local titleIcon = Pieces.Icon(spec.icon or "star", Colors.Red, { Name = "TitleIcon", LayoutOrder = 1, Size = UDim2.fromOffset(22, 22),
		Visible = spec.icon ~= nil, Parent = titleRow })
	titleIcon:SetAttribute("KeepColor", true)
	local title = Kit.Text({ Name = "Title", LayoutOrder = 2, Text = spec.title or "", Font = "Title", TextSize = 22,
		Size = UDim2.fromOffset(0, Kit.TitleHeight - 6), AutomaticSize = Enum.AutomaticSize.X, Parent = titleRow })
	local top = spec.noTitle and 12 or Kit.TitleHeight
	local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, top),
		Size = UDim2.new(1, -24, 1, -top - 12), Parent = panel })
	-- the red X on the panel's top-right corner
	local close = Kit.CloseButton({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -18, 1, -height - 22), ZIndex = 5, Parent = group })

	local modal = { gui = gui, root = root, group = group, panel = panel, body = body, title = title, closeButton = close }
	local open = false
	function modal.isOpen() return open end
	function modal.open()
		if open then return end
		if activeModal and activeModal ~= modal then activeModal.close() end
		activeModal = modal
		open = true
		gui.Enabled = true
		pop.Scale = Kit.OpenScale
		Theme.Tween(pop, { Scale = 1 }, Kit.OpenTime, Enum.EasingStyle.Back)
		Theme.Fade(group, true, Kit.OpenTime)
		backdrop.BackgroundTransparency = 1
		Theme.Tween(backdrop, { BackgroundTransparency = Theme.Alpha.Backdrop }, Kit.OpenTime)
		setBlur(true)
		if spec.onOpen then task.spawn(spec.onOpen) end
	end
	function modal.close()
		if not open then return end
		open = false
		if activeModal == modal then activeModal = nil end
		Theme.Tween(pop, { Scale = Kit.OpenScale }, Kit.OpenTime)
		Theme.Tween(backdrop, { BackgroundTransparency = 1 }, Kit.OpenTime)
		setBlur(false)
		local tween = Theme.Fade(group, false, Kit.OpenTime)
		local function hide() if not open then gui.Enabled = false end end
		if tween then tween.Completed:Connect(hide) else hide() end
		if spec.onClose then task.spawn(spec.onClose) end
	end
	function modal.toggle()
		if open then modal.close() else modal.open() end
	end
	function modal.selectTab(id: string)
		if selectTab then selectTab(id) end
	end
	function modal.setTitle(text: string, icon: string?)
		title.Text = text
		if icon then
			titleIcon.Image = require(Shared.Config.UI).Icons[icon] or titleIcon.Image
			titleIcon.Visible = true
		end
	end
	close.Activated:Connect(modal.close)
	backdrop.Activated:Connect(modal.close)
	UserInputService.InputBegan:Connect(function(input, processed)
		if open and not processed and input.KeyCode == Enum.KeyCode.Escape then modal.close() end
	end)
	return modal
end

return Kit
