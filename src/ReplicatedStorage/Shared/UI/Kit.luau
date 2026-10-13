-- Kit: the UI components (owner's final kit "BLACK + GOLD", 14 Oct: GYM_ARC_UI_final.md + gym_arc_ui_final; the looks
-- come from Theme), built once and reused by every screen. They are drawn in the mockups' pixels (844x390 landscape phone); Kit.Root
-- scales a whole gui with the screen (UIScale from the shorter side, base 390, never wider than the 844px layout), so
-- the same numbers fit a phone, a tablet and a PC. Looks come from Theme (colors, gradients, fonts, surfaces).
--   Kit.Root(screenGui)                       -> Frame that fills the screen in mockup px (its UIScale follows the screen)
--   Kit.Text(props)                           Theme.Text with Font = "Title" | "Number" | "Label" | "Body" | "Strong"
--   Kit.Button(style, text, props?, opts?)    a button with a label (CTA "Red" / "Gold", quiet, "Flat"; opts.icon, textSize, height, width)
--   Kit.CloseButton(props?)                   the quiet dark X
--   Kit.Chip(icon, text, props?)              dark round pill with an icon and a value (top bar)
--   Kit.Bar(color, props?, opts?)             -> track, set(f, text?), fill (fat outlined bar, metallic fill, opts.text)
--   Kit.PricePill(text, props?)               -> pill, label: a small dark price pill ("R$ 249", coins)
--   Kit.GoldText(label)                       paints a label with the gold gradient
--   Kit.Tag(text, color, props?)              small colored word on a tint
--   Kit.Card(props?, children?)               #28282F card (props.Piece = "card_selected" (green) / "card_gold")
--   Kit.IconTile(icon, color, size, props?)   glossy colored rounded square with a white icon
--   Kit.GradeBadge(grade, size, props?)       S / A / B / C / D badge
--   Kit.Toggle(on, onChanged, props?)         ON (green) / OFF (gray) button -> button, set(on)
--   Kit.Slider(value, onChanged, props?)      -> frame, set(value) (0..100)
--   Kit.Tabs(tabs, onSelect, props?)          tab buttons in a row (active gold, the rest flat) -> row, select(id)
--   Kit.Modal(spec)                           a window: TITLE + tabs in its header, coins + X on the right, a vignette behind
--   Kit.Coin(size, props?), Kit.Format(n) "1,500", Kit.Short(n) "1.5K"
--   Kit.Headshot(userId, name, size, props?) the player's real avatar headshot in a plain dark circle (owner, 14 Oct)
--   Kit.CoinBurst(fromGui)                   claim feedback: coins fly to the coin counter + a small gold sparkle burst
--   Kit.ApplyHeadshot(image, userId, name)   the same look on an existing ImageLabel (e.g. a leaderboard row)
--   Kit.UnderTopbar(guiObject, gap?)          mockup px from the top of guiObject (inside a Kit.Root) to just under Roblox's top
--                                             bar (GuiService.TopbarInset.Max.Y + 8): where anything under the top bar starts
--   Kit.OnTopbar(fn)                          calls fn now and whenever the top bar's size or the screen's scale changes
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
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
Kit.PanelScale = 0.9 -- (owner's final kit: panels ~10% smaller than before, so the gym shows around them)
Kit.BlurSize = 4     -- a light blur (Roblox can only blur the whole screen; the vignette keeps the edges clear)

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

-- Under Roblox's top bar (owner, 14 Oct: TopbarPlus icons sit on it; everything under it starts at TopbarInset.Max.Y + 8).
-- AbsolutePosition is measured from under the GUI inset, so the object's screen y is AbsolutePosition.Y + the inset.
Kit.TopbarGap = 8
function Kit.UnderTopbar(guiObject: GuiObject, gap: number?): number
	local inset = GuiService:GetGuiInset()
	local screenY = guiObject.AbsolutePosition.Y + inset.Y
	return math.max(0, (GuiService.TopbarInset.Max.Y + (gap or Kit.TopbarGap) - screenY) / currentScale)
end
function Kit.OnTopbar(fn)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() task.defer(fn) end)
	table.insert(scaleListeners, function() task.defer(fn) end)
	task.defer(fn)
end

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
-- props.Font: Title / Number / Label (the heavy italic display font with a soft dark outline; Label is small and gray),
-- Body (Montserrat Medium), Strong (Montserrat Bold). props.TextSize: mockup px. props.Upper = true makes it UPPERCASE.
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

-- The X (top-right of a panel): a quiet dark square with a white X.
function Kit.CloseButton(props: { [string]: any }?)
	props = props or {}
	props.Name = props.Name or "Close"
	props.Size = props.Size or UDim2.fromOffset(38, 38)
	local button = Theme.Button("Quiet", props, {})
	local x = Pieces.Icon("x", Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.5, 0.5), Parent = button })
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
	Kit.Text({ Name = "Value", LayoutOrder = 2, Text = text, Font = "Number", TextSize = math.floor(h * 0.46),
		Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, Parent = chip })
	return chip
end

-- A fat outlined bar: a near-black track with a dark outline, a metallic fill of `color` (a highlight along its top),
-- optional text in the middle (opts.text = true). Returns track, set(fraction, text?), fill.
function Kit.Metal(color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.55)),
		ColorSequenceKeypoint.new(0.28, color:Lerp(Color3.new(1, 1, 1), 0.12)),
		ColorSequenceKeypoint.new(0.7, color),
		ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.35)),
	})
end
function Kit.Bar(color: Color3, props: { [string]: any }?, opts: { [string]: any }?)
	props = props or {}
	opts = opts or {}
	props.Size = props.Size or UDim2.new(1, 0, 0, 14)
	props.BackgroundColor3 = Colors.Well
	props.BackgroundTransparency = 0
	local track = New("Frame", props, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Name = "Border", Color = Colors.Outline, Thickness = opts.outline or 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIPadding", { Name = "Inset", PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
	})
	local fill = New("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), Parent = track }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIGradient", { Name = "Gloss", Rotation = 90, Color = Kit.Metal(color) }),
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

-- Paints a label with the gold gradient (hero names, rewards, big numbers). Its outline goes so the gold stays clean.
function Kit.GoldText(label: TextLabel)
	local gradient = label:FindFirstChild("Gold") or New("UIGradient", { Name = "Gold", Rotation = 90, Parent = label })
	gradient.Color = Theme.GoldSequence
	label.TextColor3 = Color3.new(1, 1, 1)
	local outline = label:FindFirstChild("TextStroke")
	if outline then outline.Transparency = 0.7 end
	return label
end

-- A small dark price pill (near black, a thin inner highlight): "R$ 249" or a coin + "600". icon: "coin" or nil.
function Kit.PricePill(text: string, props: { [string]: any }?, icon: string?)
	props = props or {}
	local h = props.Size and props.Size.Y.Offset or 26
	props.Size = props.Size or UDim2.fromOffset(0, h)
	if not props.AutomaticSize then props.AutomaticSize = Enum.AutomaticSize.X end
	props.Piece = "well"
	local pill = Theme.Panel(props, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		Theme.List(Horizontal, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local corner = pill:FindFirstChildOfClass("UICorner")
	if corner then corner.CornerRadius = UDim.new(0, 8) end
	local line = New("Frame", { Name = "Highlight", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88,
		Position = UDim2.fromOffset(6, 1), Size = UDim2.new(1, -12, 0, 1), Parent = New("Folder", { Name = "Depth", Parent = pill }) })
	line.ZIndex = pill.ZIndex
	if icon == "coin" then Kit.Coin(math.floor(h * 0.7), { LayoutOrder = 1, Parent = pill }) end
	local label = Kit.Text({ Name = "Price", LayoutOrder = 2, Text = text, Font = "Number", TextSize = math.floor(h * 0.66),
		Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, Parent = pill })
	return pill, label
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

-- Player pictures (owner, 14 Oct): the player's real Roblox avatar headshot (Players:GetUserThumbnailAsync, HeadShot
-- 150x150) as a simple circle: plain dark #1D191B behind it, a thin 1px white border at 88% transparency. No ring, no
-- gradient, no glow, no generic person icon. While it loads only the dark circle shows; if it fails, the first letter of
-- the player's name in light gray. Used everywhere a player picture appears (menu card, leaderboards, posing vote,
-- spot requests, crew).
Kit.HeadshotLook = { Back = Color3.fromHex("#1D191B"), Border = Color3.new(1, 1, 1), BorderTransparency = 0.88, Letter = Color3.fromHex("#C9C2C4") }
local headshotCache: { [number]: string } = {}
function Kit.ApplyHeadshot(image: ImageLabel, userId: number?, name: string?)
	local look = Kit.HeadshotLook
	image.BackgroundColor3 = look.Back
	image.BackgroundTransparency = 0
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Crop
	image.Image = ""
	local corner = image:FindFirstChild("HeadshotCorner") or New("UICorner", { Name = "HeadshotCorner", CornerRadius = UDim.new(1, 0), Parent = image })
	corner.CornerRadius = UDim.new(1, 0)
	if not image:FindFirstChild("HeadshotBorder") then
		New("UIStroke", { Name = "HeadshotBorder", Color = look.Border, Transparency = look.BorderTransparency, Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = image })
	end
	local letter = image:FindFirstChild("Letter") :: TextLabel?
	if not letter then
		letter = New("TextLabel", { Name = "Letter", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", TextScaled = true,
			FontFace = Theme.UIFonts.BodyBold, TextColor3 = look.Letter, Visible = false, Parent = image }, {
			New("UIPadding", { PaddingTop = UDim.new(0.24, 0), PaddingBottom = UDim.new(0.24, 0) }),
		}) :: TextLabel
	end
	(letter :: TextLabel).Visible = false
	(letter :: TextLabel).Text = string.upper(string.sub(tostring(name or ""), 1, 1))
	image:SetAttribute("HeadshotUser", userId or 0)
	if type(userId) ~= "number" or userId <= 0 then
		(letter :: TextLabel).Visible = true -- (an NPC or unknown player: the letter)
		return
	end
	if headshotCache[userId] then
		image.Image = headshotCache[userId]
		return
	end
	task.spawn(function()
		local ok, content, ready = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if image:GetAttribute("HeadshotUser") ~= userId then return end -- (reused for someone else meanwhile)
		if ok and ready ~= false and type(content) == "string" and content ~= "" then
			headshotCache[userId] = content
			image.Image = content
		else
			(letter :: TextLabel).Visible = true
		end
	end)
end

function Kit.Headshot(userId: number?, name: string?, size: number, props: { [string]: any }?)
	props = props or {}
	props.Name = props.Name or "Headshot"
	props.Size = props.Size or UDim2.fromOffset(size, size)
	local image = New("ImageLabel", props) :: ImageLabel
	Kit.ApplyHeadshot(image, userId, name)
	return image
end

-- Grade badges (owner's final kit: the rank letter on a small gold plate, mockup 07_physique). Kit.GradeColors stays for
-- screens that tint other things by grade.
Kit.GradeColors = {
	S = Colors.Red, A = Color3.fromHex("#2F7BEA"), B = Color3.fromHex("#F2B51F"), C = Color3.fromHex("#3DBA4A"), D = Color3.fromHex("#5A5A66"),
}
function Kit.GradeBadge(grade: string, size: number, props: { [string]: any }?)
	props = props or {}
	props.Size = UDim2.fromOffset(size, size)
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	local badge = New("Frame", props, {
		New("UICorner", { CornerRadius = UDim.new(0, math.max(5, math.floor(size * 0.2))) }),
		New("UIStroke", { Name = "Border", Color = Color3.fromHex("#6B4A06"), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIGradient", { Name = "Gloss", Rotation = 90, Color = Theme.GoldSequence }),
	})
	Kit.Text({ Name = "Letter", Text = grade, Font = "Title", TextSize = math.floor(size * 0.66), TextColor3 = Colors.Ink, Stroke = false,
		Size = UDim2.fromScale(1, 1), Parent = badge })
	return badge
end
function Kit.SetGrade(badge, grade: string)
	local letter = badge:FindFirstChild("Letter")
	if letter then letter.Text = grade end
end

-- ON / OFF button (mockup 10): green ON, gray OFF. Returns button, set(on).
function Kit.Toggle(on: boolean, onChanged: (boolean) -> (), props: { [string]: any }?)
	props = props or {}
	local button = Kit.Button(on and "Gold" or "Quiet", on and "On" or "Off", props, { width = props.Size and props.Size.X.Offset or 60, height = props.Size and props.Size.Y.Offset or 30 })
	local state = on
	local function set(value: boolean)
		state = value
		Kit.SetButton(button, value and "Gold" or "Quiet", value and "On" or "Off")
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
	local track, setFill = Kit.Bar(Colors.Teal, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 10), Parent = frame })
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

-- Tabs (owner's final kit): the active tab is a gold CTA, the others FLAT (no bevel, darker, gray text) so the gold pops.
-- tabs = { { id = "Passes", text = "Passes" }, ... }; onSelect(id). Returns row, select(id).
function Kit.Tabs(tabs, onSelect: (string) -> (), props: { [string]: any }?)
	props = props or {}
	local h = props.Size and props.Size.Y.Offset or 30
	props.Size = UDim2.fromOffset(0, h)
	props.AutomaticSize = Enum.AutomaticSize.X
	props.BackgroundTransparency = 1
	local row = New("Frame", props, { Theme.List(Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local items = {}
	local function select(id: string)
		for _, item in ipairs(items) do
			Theme.SetButtonStyle(item.button, item.id == id and "Gold" or "Flat")
		end
	end
	for order, tab in ipairs(tabs) do
		local button = Kit.Button("Flat", tab.text, { Name = tab.id, LayoutOrder = order, Parent = row },
			{ height = h, textSize = math.floor(h * 0.5) })
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
-- Modal window (owner's final kit, mockups 04-07): the header inside the panel: the TITLE (big heavy italic, uppercase),
-- the tabs right after it, then on the right the coins pill (spec.coins = true; the HUD's own coin counter hides while
-- a window is open) and the quiet X. Behind it a soft dark vignette around the panel and a light blur, so the gym stays
-- visible at the edges. The whole window is Kit.PanelScale of its mockup size and pops 0.96 -> 1 with a fade (0.18 s);
-- its CTAs shine once as it opens.
------------------------------------------------------------------------
-- spec: { name, title, icon? (unused in this kit), width, height (mockup px), tabs?, onTab?, onClose?, onOpen?,
--         displayOrder?, noTitle?, coins? }
-- Returns modal = { gui, root, group, panel, body, title, closeButton, coins?, open(), close(), isOpen(), selectTab(id),
-- setTitle(text) }.
local openModals = 0
local blur = nil
local function setBlur(on: boolean)
	openModals = math.max(0, openModals + (on and 1 or -1))
	if not blur or not blur.Parent then
		blur = Lighting:FindFirstChild("ModalBlur") or New("BlurEffect", { Name = "ModalBlur", Size = 0, Parent = Lighting })
	end
	Theme.Tween(blur, { Size = openModals > 0 and Kit.BlurSize or 0 }, Kit.OpenTime)
	if Players.LocalPlayer then Players.LocalPlayer:SetAttribute("WindowOpen", openModals > 0) end -- (Notify hides the band, TopBar the coins)
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
Kit.TitleHeight = 56 -- the header inside the panel (title, tabs, coins, X)
Kit.HeaderExtra = 10 -- the panel grows by this much: its header is taller than the old title row

-- the soft dark vignette behind a window: darkest at the panel, clear toward the screen edges
local function vignette(parent, width: number, height: number)
	local frame = New("Frame", { Name = "Vignette", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.fromOffset(width + 300, height + 220), BackgroundColor3 = Colors.Shadow, BackgroundTransparency = 0, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0, 160) }),
		New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 0.6),
			NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.78, 0.6), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	return frame
end

local activeModal = nil -- one menu at a time: opening one closes the other
function Kit.Modal(spec)
	local player = Players.LocalPlayer
	local gui = Theme.ScreenGui({ Name = spec.name, Enabled = false, DisplayOrder = spec.displayOrder or 30,
		Parent = player:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.None
	local backdrop = New("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Shadow,
		BackgroundTransparency = Theme.Alpha.Backdrop, Size = UDim2.fromScale(1, 1), Parent = gui })
	local root = Kit.Root(gui)
	local width = spec.width or 600
	local height = (spec.height or 290) + (spec.noTitle and 0 or Kit.HeaderExtra)
	local shade = vignette(root, width * Kit.PanelScale, height * Kit.PanelScale)
	-- the group: the panel, centred a little below the middle (under the top bar)
	local group = New("Frame", { Name = "Group", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(width, height), Parent = root })
	local pop = New("UIScale", { Parent = group })
	local panel = Theme.Panel({ Name = "Panel", Size = UDim2.fromScale(1, 1), Active = true, Parent = group })
	-- header: TITLE, then the tabs
	local titleRow = New("Frame", { Name = "TitleRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -36, 0, Kit.TitleHeight - 14), Visible = not spec.noTitle, Parent = panel }, {
		Theme.List(Horizontal, 14, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local titleIcon = Pieces.Icon(spec.icon or "star", Colors.Gold, { Name = "TitleIcon", LayoutOrder = 1, Size = UDim2.fromOffset(22, 22),
		Visible = false, Parent = titleRow })
	titleIcon:SetAttribute("KeepColor", true)
	local title = Kit.Text({ Name = "Title", LayoutOrder = 2, Text = spec.title or "", Font = "Title", TextSize = 30, Upper = true,
		Size = UDim2.fromOffset(0, Kit.TitleHeight - 14), AutomaticSize = Enum.AutomaticSize.X, Parent = titleRow })
	local selectTab = nil
	if spec.tabs then
		local _row
		_row, selectTab = Kit.Tabs(spec.tabs, spec.onTab or function() end, { Name = "Tabs", LayoutOrder = 3, Size = UDim2.fromOffset(0, Kit.TabHeight), Parent = titleRow })
	end
	local top = spec.noTitle and 12 or Kit.TitleHeight
	local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, top),
		Size = UDim2.new(1, -28, 1, -top - 14), Parent = panel })
	-- right: the coins pill and the X
	local close = Kit.CloseButton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), ZIndex = 5, Parent = panel })
	local coins = nil
	if spec.coins then
		coins = Kit.Chip("coin", "0", { Name = "Coins", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 12),
			Size = UDim2.fromOffset(0, 34), Parent = panel })
		task.spawn(function()
			local clientData = require(Shared:WaitForChild("ClientData"))
			local function refresh()
				local value = coins:FindFirstChild("Value")
				if value then value.Text = formatInt(clientData.Get().coins or 0) end
			end
			refresh()
			clientData.Changed:Connect(function(path)
				if path[1] == "coins" then refresh() end
			end)
		end)
	end

	local modal = { gui = gui, root = root, group = group, panel = panel, body = body, title = title, closeButton = close, coins = coins }
	local open = false
	function modal.isOpen() return open end
	function modal.open()
		if open then return end
		if activeModal and activeModal ~= modal then activeModal.close() end
		activeModal = modal
		open = true
		gui.Enabled = true
		pop.Scale = Kit.OpenScale * Kit.PanelScale
		Theme.Tween(pop, { Scale = Kit.PanelScale }, Kit.OpenTime)
		Theme.Fade(group, true, Kit.OpenTime)
		backdrop.BackgroundTransparency = 1
		Theme.Tween(backdrop, { BackgroundTransparency = Theme.Alpha.Backdrop }, Kit.OpenTime)
		shade.BackgroundTransparency = 1
		Theme.Tween(shade, { BackgroundTransparency = 0 }, Kit.OpenTime)
		setBlur(true)
		task.delay(Kit.OpenTime, function() if open then Theme.ShineAll(panel) end end)
		if spec.onOpen then task.spawn(spec.onOpen) end
	end
	function modal.close()
		if not open then return end
		open = false
		if activeModal == modal then activeModal = nil end
		Theme.Tween(pop, { Scale = Kit.OpenScale * Kit.PanelScale }, Kit.OpenTime)
		Theme.Tween(backdrop, { BackgroundTransparency = 1 }, Kit.OpenTime)
		Theme.Tween(shade, { BackgroundTransparency = 1 }, Kit.OpenTime)
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
	function modal.setTitle(text: string, _icon: string?)
		title.Text = text
	end
	close.Activated:Connect(modal.close)
	backdrop.Activated:Connect(modal.close)
	UserInputService.InputBegan:Connect(function(input, processed)
		if open and not processed and input.KeyCode == Enum.KeyCode.Escape then modal.close() end
	end)
	return modal
end

-- Claim feedback (owner's final kit): a small gold sparkle burst at `fromGui` and a few coins flying to the coin counter
-- (the top bar's, or the open window's own pill). Reduced motion: only the sparkle.
function Kit.CoinBurst(fromGui: GuiObject)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if not playerGui or not fromGui.Parent then return end
	local layer = playerGui:FindFirstChild("CoinBurst")
	if not layer then
		layer = Theme.ScreenGui({ Name = "CoinBurst", DisplayOrder = 80, IgnoreGuiInset = true, Parent = playerGui })
		layer.ScreenInsets = Enum.ScreenInsets.None
	end
	local inset = game:GetService("GuiService"):GetGuiInset()
	local from = fromGui.AbsolutePosition + fromGui.AbsoluteSize / 2 + inset
	-- where the coins go: a coins pill that is showing (a window's own), else the top bar's
	local target = nil
	for _, gui in ipairs(playerGui:GetChildren()) do
		local pill = gui:IsA("ScreenGui") and gui.Enabled and gui:FindFirstChild("Coins", true)
		if pill and pill:IsA("GuiObject") and pill.Visible and pill.AbsoluteSize.X > 0 then
			target = pill.AbsolutePosition + Vector2.new(18, pill.AbsoluteSize.Y / 2) + inset
			break
		end
	end
	target = target or Vector2.new(180, 30)
	local s = currentScale
	-- sparkle: little gold stars popping out and fading
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2 + math.random() * 0.4
		local star = Pieces.Icon("sparkles", Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X, from.Y),
			Size = UDim2.fromOffset(4, 4), Parent = layer })
		star:SetAttribute("KeepColor", true)
		local reach = (26 + math.random() * 18) * s
		local goal = from + Vector2.new(math.cos(angle), math.sin(angle)) * reach
		Theme.Tween(star, { Position = UDim2.fromOffset(goal.X, goal.Y), Size = UDim2.fromOffset(16 * s, 16 * s) }, 0.28)
		task.delay(0.22, function()
			Theme.Tween(star, { ImageTransparency = 1, Size = UDim2.fromOffset(6 * s, 6 * s) }, 0.3)
			task.delay(0.32, function() star:Destroy() end)
		end)
	end
	if Theme.ReducedMotion() then return end
	for i = 1, 8 do
		local coin = Kit.Coin(math.floor(20 * s), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X, from.Y), Parent = layer })
		local spread = from + Vector2.new(math.random(-40, 40), math.random(-34, 10)) * s
		Theme.Tween(coin, { Position = UDim2.fromOffset(spread.X, spread.Y) }, 0.18)
		task.delay(0.18 + i * 0.04, function()
			local fly = game:GetService("TweenService"):Create(coin, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(12 * s, 12 * s) })
			fly:Play()
			fly.Completed:Connect(function() coin:Destroy() end)
		end)
	end
end

return Kit
