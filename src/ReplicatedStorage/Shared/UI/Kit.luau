-- Kit: the UI components of the redesign (owner's GYM_ARC_UI_redesign.md), built once and reused by every screen. They
-- are drawn in the mockups' pixels (the mockups are a 844x390 landscape phone); Kit.Root scales a whole gui with the
-- screen (UIScale from the shorter side, base 390, and never wider than the 844px layout), so the same numbers fit a
-- phone, a tablet and a PC. Looks come from Theme (colors, fonts) and Shared.UI.Pieces (the 9-slice images).
--   Kit.Root(screenGui)                       -> Frame that fills the screen in mockup px (its UIScale follows the screen)
--   Kit.Text(props)                           Theme.Text with Font = "Title" | "Number" | "Body" | "Strong" | "Label"
--   Kit.Button(style, text, props?, opts?)    Theme.Button with a label (+ opts.icon, opts.textSize, opts.iconColor)
--   Kit.Chip(icon, text, props?)              dark pill with an icon and a number (coins, height, timers)
--   Kit.Bar(color, props?)                    -> frame, setFraction(f) (dark well, colored fill)
--   Kit.Tag(text, color, props?)              tiny uppercase label on a tinted background
--   Kit.Card(props?, children?)               #1D191B card with a soft border (props.Piece = "card_selected" / "card_gold")
--   Kit.IconTile(icon, color, size, props?)   rounded square, tinted background, colored icon
--   Kit.GradeBadge(grade, size, props?)       S / A / B / C / D on its grade color
--   Kit.Toggle(on, onChanged, props?)         -> frame, set(on)
--   Kit.Slider(value, onChanged, props?)      -> frame, set(value) (0..100)
--   Kit.Tabs(tabs, onSelect, props?)          segmented strip; tabs = { { id, text, icon? } }; -> frame, select(id)
--   Kit.Modal(spec)                           a panel window (backdrop, header with title / tabs / coins / X); see below
--   Kit.Coin(size, props?)                    the coin icon
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

local scaleListeners = {}
local currentScale = 1
local function refreshScale()
	local camera = Workspace.CurrentCamera
	local s = Kit.ScaleFor(camera and camera.ViewportSize or Kit.Base)
	if math.abs(s - currentScale) < 0.001 then return end
	currentScale = s
	for _, fn in ipairs(scaleListeners) do task.spawn(fn, s) end
end
local function watchCamera(camera)
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale) end
end
watchCamera(Workspace.CurrentCamera)
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
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end)
	return root
end

------------------------------------------------------------------------
-- Text
------------------------------------------------------------------------
local FONTS = {
	Title = "SemiBold", Number = "Medium", Body = "Regular", Strong = "Strong", Label = "Medium",
}
-- props.Font: Title (Oswald Bold, UPPERCASE), Number (Oswald SemiBold), Body (Montserrat SemiBold), Strong (Montserrat
-- Bold), Label (small muted Oswald section label, UPPERCASE). props.TextSize: mockup px.
function Kit.Text(props)
	local kind = props.Font or "Body"
	props.Font = FONTS[kind] or kind
	if kind == "Label" then
		props.TextColor3 = props.TextColor3 or Colors.Muted
		props.TextSize = props.TextSize or Theme.TextSize.Label
	end
	props.TextSize = props.TextSize or 12
	local upper = kind == "Title" or kind == "Label"
	if props.Upper ~= nil then upper = props.Upper end
	props.Upper = false
	local label = Theme.Text(props)
	if upper then
		label:SetAttribute("Upper", nil)
		Theme.Uppercase(label)
	end
	return label
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
-- opts: icon = icon name (or "coin" / "robux"), textSize, iconColor, height (default 36), width (default auto)
function Kit.Button(style: string, text: string, props: { [string]: any }?, opts: { [string]: any }?)
	props = props or {}
	opts = opts or {}
	local height = opts.height or 36
	props.Size = props.Size or UDim2.fromOffset(opts.width or 0, height)
	if not opts.width and not (props :: any).AutomaticSize then (props :: any).AutomaticSize = Enum.AutomaticSize.X end
	local button = Theme.Button(style, props, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 3) }),
		Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local textSize = opts.textSize or (height >= 34 and 15 or 12)
	if opts.icon then
		local iconSize = math.floor(textSize * 1.1)
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
		Size = UDim2.fromOffset(0, height - 6), AutomaticSize = Enum.AutomaticSize.X, Parent = button })
	Theme.SetButtonStyle(button, style)
	-- (the hit area stays at least 44 screen px tall on phones: a bigger invisible pad around small buttons)
	if height < 30 then
		New("TextButton", { Name = "HitArea", Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 8, 1, 16), ZIndex = button.ZIndex + 1, Parent = button.Parent })
	end
	return button, label
end

-- Sets a Kit.Button's text and style together (e.g. BUY -> OWNED).
function Kit.SetButton(button, style: string?, text: string?)
	if style then Theme.SetButtonStyle(button, style) end
	local label = button:FindFirstChild("Label")
	if text and label then label.Text = text end
end

function Kit.CloseButton(props: { [string]: any }?)
	props = props or {}
	props.Name = props.Name or "Close"
	props.Size = props.Size or UDim2.fromOffset(32, 32)
	props.Text, props.AutoButtonColor, props.BackgroundTransparency = "", false, 1
	local button = New("TextButton", props)
	Pieces.Image("close_button", { Name = "Bg", ZIndex = 0, Size = UDim2.fromScale(1, 1), Parent = button })
	Pieces.Icon("x", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), Parent = button })
	Theme.BindPress(button)
	return button
end

------------------------------------------------------------------------
-- Small pieces
------------------------------------------------------------------------
-- icon: an icon name, "coin", or nil; text is Oswald SemiBold (numbers)
function Kit.Chip(icon: string?, text: string, props: { [string]: any }?)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(0, 30)
	if not props.AutomaticSize then props.AutomaticSize = Enum.AutomaticSize.X end
	props.Piece = "chip"
	local chip = Theme.Panel(props, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local h = props.Size.Y.Offset
	if icon == "coin" then
		Kit.Coin(math.floor(h * 0.55), { LayoutOrder = 1, Parent = chip })
	elseif icon then
		Pieces.Icon(icon, Colors.Text, { LayoutOrder = 1, Size = UDim2.fromOffset(math.floor(h * 0.5), math.floor(h * 0.5)), Parent = chip })
	end
	Kit.Text({ Name = "Value", LayoutOrder = 2, Text = text, Font = "Number", TextSize = math.floor(h * 0.5),
		Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, Parent = chip })
	return chip
end

function Kit.Bar(color: Color3, props: { [string]: any }?)
	props = props or {}
	props.Size = props.Size or UDim2.new(1, 0, 0, 6)
	local track = Pieces.Image("bar_track", props)
	local fill = Pieces.Image("bar_fill_white", { Name = "Fill", ImageColor3 = color, Size = UDim2.fromScale(0, 1), Parent = track })
	local function set(f: number)
		f = math.clamp(f, 0, 1)
		fill.Visible = f > 0
		fill.Size = UDim2.new(f, 0, 1, 0)
	end
	set(0)
	return track, set, fill
end

local function tint(color: Color3, amount: number?)
	return color:Lerp(Colors.Panel, amount or 0.78)
end
Kit.Tint = tint

function Kit.Tag(text: string, color: Color3, props: { [string]: any }?)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(0, 18)
	if not props.AutomaticSize then props.AutomaticSize = Enum.AutomaticSize.X end
	props.ImageColor3 = props.ImageColor3 or tint(color, 0.72)
	local tag = Pieces.Image("rounded_white_r5", props)
	New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = tag })
	Kit.Text({ Name = "Text", Text = text, Font = "Title", TextSize = math.floor(props.Size.Y.Offset * 0.62), TextColor3 = color,
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = tag })
	return tag
end

function Kit.Card(props: { [string]: any }?, children: { Instance }?)
	props = props or {}
	props.Piece = props.Piece or "card"
	return Theme.Panel(props, children)
end

function Kit.IconTile(icon: string, color: Color3, size: number, props: { [string]: any }?)
	props = props or {}
	props.Size = UDim2.fromOffset(size, size)
	props.ImageColor3 = props.ImageColor3 or tint(color)
	local tile = Pieces.Image("rounded_white_r8", props)
	Pieces.Icon(icon, color, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56), Parent = tile }):SetAttribute("KeepColor", true)
	return tile
end

Kit.GradeColors = {
	S = Theme.Bumper.Red.Fill, A = Theme.Bumper.Blue.Fill, B = Theme.Bumper.Yellow.Fill, C = Theme.Bumper.Green.Fill,
	D = Color3.fromHex("#3A3437"),
}
Kit.GradeText = { B = Colors.Ink }
function Kit.GradeBadge(grade: string, size: number, props: { [string]: any }?)
	props = props or {}
	props.Size = UDim2.fromOffset(size, size)
	props.ImageColor3 = Kit.GradeColors[grade] or Kit.GradeColors.D
	local badge = Pieces.Image("rounded_white_r8", props)
	Kit.Text({ Name = "Letter", Text = grade, Font = "Title", TextSize = math.floor(size * 0.62), TextColor3 = Kit.GradeText[grade] or Colors.Text,
		Size = UDim2.fromScale(1, 1), Parent = badge })
	return badge
end
function Kit.SetGrade(badge, grade: string)
	badge.ImageColor3 = Kit.GradeColors[grade] or Kit.GradeColors.D
	local letter = badge:FindFirstChild("Letter")
	if letter then
		letter.Text = grade
		letter.TextColor3 = Kit.GradeText[grade] or Colors.Text
	end
end

function Kit.Toggle(on: boolean, onChanged: (boolean) -> (), props: { [string]: any }?)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(40, 22)
	props.Text, props.AutoButtonColor, props.BackgroundTransparency = "", false, 1
	local button = New("TextButton", props)
	local track = Pieces.Image("toggle_off", { Name = "Track", Size = UDim2.fromScale(1, 1), Parent = button })
	local knob = Pieces.Image("circle_white", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 16, 0, 16), ZIndex = 2, Parent = button })
	local state = on
	local function set(value: boolean)
		state = value
		Pieces.Apply(track, value and "toggle_on" or "toggle_off")
		Theme.Tween(knob, { Position = UDim2.new(value and 1 or 0, value and -11 or 11, 0.5, 0) }, 0.15)
	end
	knob.Position = UDim2.new(on and 1 or 0, on and -11 or 11, 0.5, 0)
	set(on)
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
	local track, setFill = Kit.Bar(Colors.Red, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 5), Parent = frame })
	local knob = Pieces.Image("circle_white", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), ZIndex = 3, Parent = frame })
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

-- tabs = { { id = "Passes", text = "Passes", icon = "star" }, ... }; onSelect(id)
function Kit.Tabs(tabs, onSelect: (string) -> (), props: { [string]: any }?)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(0, 34)
	props.AutomaticSize = Enum.AutomaticSize.X
	props.Piece, props.Shadow = "well", false
	local strip = Theme.Panel(props, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
		Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local h = props.Size.Y.Offset - 6
	local items = {}
	local function select(id: string)
		for _, item in ipairs(items) do
			local active = item.id == id
			item.bg.Visible = active
			item.label.TextColor3 = active and Colors.Text or Colors.Muted
			if item.icon then item.icon.ImageColor3 = active and Colors.Red or Colors.Muted end
		end
	end
	for order, tab in ipairs(tabs) do
		local button = New("TextButton", { Name = tab.id, LayoutOrder = order, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, Parent = strip }, {
			New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
			Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
		})
		local bgFolder = New("Folder", { Name = "Depth", Parent = button })
		local bg = Pieces.Image("tab_active", { Name = "Bg", ZIndex = 0, Position = UDim2.fromOffset(-12, 0), Size = UDim2.new(1, 24, 1, 0), Visible = false, Parent = bgFolder })
		local icon
		if tab.icon then
			icon = tab.icon == "coin" and Kit.Coin(math.floor(h * 0.5), { LayoutOrder = 1, Parent = button })
				or Pieces.Icon(tab.icon, Colors.Muted, { LayoutOrder = 1, Size = UDim2.fromOffset(math.floor(h * 0.5), math.floor(h * 0.5)), Parent = button })
			if tab.icon == "coin" then icon = nil end
		end
		local label = Kit.Text({ LayoutOrder = 2, Text = tab.text, Font = "Title", TextSize = math.floor(h * 0.5), TextColor3 = Colors.Muted,
			Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, Parent = button })
		table.insert(items, { id = tab.id, bg = bg, label = label, icon = icon })
		button.Activated:Connect(function()
			select(tab.id)
			onSelect(tab.id)
		end)
	end
	if tabs[1] then select(tabs[1].id) end
	return strip, select
end

------------------------------------------------------------------------
-- Modal panel
------------------------------------------------------------------------
-- spec: { name, title, width, height (mockup px; height may be nil = fit the content), tabs = Kit.Tabs list?, onTab?,
--         coins = true (coins chip), subtitle?, onClose?, displayOrder?, extraHeader? (instance put left of the X) }
-- Returns modal = { gui, panel, body, header, open(), close(), isOpen(), setCoins(n), selectTab(id) }.
local openModals = 0
local blur = nil
local function setBlur(on: boolean)
	openModals = math.max(0, openModals + (on and 1 or -1))
	if not blur or not blur.Parent then
		blur = Lighting:FindFirstChild("ModalBlur") or New("BlurEffect", { Name = "ModalBlur", Size = 0, Parent = Lighting })
	end
	Theme.Tween(blur, { Size = openModals > 0 and Kit.BlurSize or 0 }, Kit.OpenTime)
end

local function formatInt(n: number): string
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then sign, s = "-", string.sub(s, 2) end
	return sign .. string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,"))):gsub("^,", "")
end
Kit.Format = formatInt

function Kit.Modal(spec)
	local player = Players.LocalPlayer
	local gui = Theme.ScreenGui({ Name = spec.name, Enabled = false, DisplayOrder = spec.displayOrder or 30,
		ScreenInsets = Enum.ScreenInsets.None, Parent = player:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.None
	local backdrop = New("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Shadow,
		BackgroundTransparency = Theme.Alpha.Backdrop, Size = UDim2.fromScale(1, 1), Parent = gui })
	local root = Kit.Root(gui)
	local width, height = spec.width or 640, spec.height
	local panel = Theme.Panel({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height or 0), AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		Active = true, Parent = root })
	local pop = New("UIScale", { Parent = panel })
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })
	-- header: red accent bar, title, tabs, coins chip, X
	local header = Pieces.Image("panel_header", { Name = "Header", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, Kit.HeaderHeight), Parent = panel })
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Colors.HeaderBottom:Lerp(Color3.new(1, 1, 1), 0.85)), Parent = header })
	New("Frame", { Name = "Line", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.Border, BackgroundTransparency = Theme.Alpha.BorderSoft, Parent = header })
	local left = New("Frame", { Name = "Left", BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(16, 0), Parent = header }, {
		Theme.List(Horizontal, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	New("Frame", { Name = "Accent", LayoutOrder = 1, BackgroundColor3 = Colors.Red, Size = UDim2.fromOffset(4, 18), Parent = left }, { Theme.Round("Round") })
	local title = Kit.Text({ Name = "Title", LayoutOrder = 2, Text = spec.title, Font = "Title", TextSize = 20,
		Size = UDim2.fromOffset(0, Kit.HeaderHeight), AutomaticSize = Enum.AutomaticSize.X, Parent = left })
	if spec.subtitle then
		Kit.Text({ Name = "Subtitle", LayoutOrder = 3, Text = spec.subtitle, Font = "Body", TextSize = 11, TextColor3 = Colors.Muted,
			Size = UDim2.fromOffset(0, Kit.HeaderHeight), AutomaticSize = Enum.AutomaticSize.X, Parent = left })
	end
	local selectTab = nil
	if spec.tabs then
		local strip
		strip, selectTab = Kit.Tabs(spec.tabs, spec.onTab or function() end, { LayoutOrder = 4, Size = UDim2.fromOffset(0, 34), Parent = left })
		strip.Name = "Tabs"
	end
	local right = New("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, Parent = header }, {
		Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
	})
	local coinsChip = nil
	if spec.coins then
		coinsChip = Kit.Chip("coin", "0", { Name = "Coins", LayoutOrder = 1, Size = UDim2.fromOffset(0, 30), Parent = right })
	end
	if spec.extraHeader then spec.extraHeader.LayoutOrder = 2; spec.extraHeader.Parent = right end
	local close = Kit.CloseButton({ LayoutOrder = 3, Parent = right })
	local body = New("Frame", { Name = "Body", LayoutOrder = 1, BackgroundTransparency = 1,
		Size = height and UDim2.new(1, 0, 1, -Kit.HeaderHeight) or UDim2.fromScale(1, 0), AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		Parent = panel }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
	})

	local modal = { gui = gui, panel = panel, body = body, header = header, title = title, right = right, closeButton = close }
	local open = false
	function modal.isOpen() return open end
	function modal.open()
		if open then return end
		open = true
		gui.Enabled = true
		pop.Scale = Kit.OpenScale
		Theme.Tween(pop, { Scale = 1 }, Kit.OpenTime)
		Theme.Fade(panel, true, Kit.OpenTime)
		backdrop.BackgroundTransparency = 1
		Theme.Tween(backdrop, { BackgroundTransparency = Theme.Alpha.Backdrop }, Kit.OpenTime)
		setBlur(true)
	end
	function modal.close()
		if not open then return end
		open = false
		Theme.Tween(pop, { Scale = Kit.OpenScale }, Kit.OpenTime)
		Theme.Tween(backdrop, { BackgroundTransparency = 1 }, Kit.OpenTime)
		setBlur(false)
		local tween = Theme.Fade(panel, false, Kit.OpenTime)
		local function hide() if not open then gui.Enabled = false end end
		if tween then tween.Completed:Connect(hide) else hide() end
		if spec.onClose then task.spawn(spec.onClose) end
	end
	function modal.setCoins(n: number)
		if coinsChip then coinsChip.Value.Text = formatInt(n) end
	end
	function modal.selectTab(id: string)
		if selectTab then selectTab(id) end
	end
	close.Activated:Connect(modal.close)
	backdrop.Activated:Connect(modal.close)
	UserInputService.InputBegan:Connect(function(input, processed)
		if open and not processed and input.KeyCode == Enum.KeyCode.Escape then modal.close() end
	end)
	if spec.coins then
		local ClientData = require(Shared:WaitForChild("ClientData"))
		local function refresh() modal.setCoins(ClientData.Get().coins or 0) end
		refresh()
		ClientData.Changed:Connect(function(path) if path[1] == "coins" then refresh() end end)
	end
	return modal
end

return Kit
