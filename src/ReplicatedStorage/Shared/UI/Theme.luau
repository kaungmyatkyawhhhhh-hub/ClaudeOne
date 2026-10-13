-- GYM ARC design system, UI v2 (owner, 13 Oct: GYM_ARC_UI_v2_gymleague_style.md + gym_arc_ui_mockups_v2; replaces the
-- dark image-piece style): bright "simulator" UI built from Frames + UIGradient + UIStroke + UICorner.
--   * Text: FredokaOne, white with a thick black outline (labels, titles, buttons, numbers); body text (descriptions,
--     dialog) Montserrat Bold, white, no outline.
--   * Buttons: glossy vertical gradients (green / red / gold / blue / gray / purple / orange / teal), 10px corners and a
--     lighter border in their own color like the left menu tiles (owner, 13 Oct), a thin lighter inner line and a darker
--     bottom lip. Press = shrink to 0.94 and bounce back.
--   * Panels: dark translucent #18181E, 14px corners, a soft light edge. Cards inside: #28282F, 10px corners.
--   * Tabs sit above a panel as separate buttons (active = red); close = a red square X with a white border.
-- Color still means something: plates, grades and rarity keep the bumper plate colors. Every UI reads its look from here
-- and from Shared.UI.Kit (the components).
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Background = Color3.fromHex("#0D0D12"), -- modal backdrops, deep wells
	Panel = Color3.fromHex("#18181E"),      -- panels
	Card = Color3.fromHex("#28282F"),       -- cards / rows inside panels
	Well = Color3.fromHex("#101016"),       -- bar tracks
	Pill = Color3.fromHex("#16161A"),       -- top bar pills, HUD cards over the world
	Secondary = Color3.fromHex("#3A3A44"),  -- gray buttons
	Disabled = Color3.fromHex("#2C2C34"),
	TabActive = Color3.fromHex("#EE3A42"),
	HeaderTop = Color3.fromHex("#18181E"),
	HeaderBottom = Color3.fromHex("#18181E"),
	Outline = Color3.fromHex("#0D0D12"),    -- the dark outline around panels, buttons and cards
	Border = Color3.fromHex("#0D0D12"),     -- (old name for the outline)
	Text = Color3.fromHex("#FFFFFF"),       -- main text
	Muted = Color3.fromHex("#B8B8C4"),      -- secondary text
	Faint = Color3.fromHex("#6E6E7A"),      -- locked items
	Chalk = Color3.fromHex("#FFFFFF"),
	Ink = Color3.fromHex("#16161A"),        -- dark text on light fills
	Shadow = Color3.fromHex("#000000"),
	Red = Color3.fromHex("#EE3A42"),        -- primary
	RedTint = Color3.fromHex("#4A1A1E"),
	Gold = Color3.fromHex("#FFC93C"),       -- coins, prices, tiers, big moments
	Green = Color3.fromHex("#5FD35A"),      -- claim, done, auto on, following
	Blue = Color3.fromHex("#4AA3FF"),       -- stamina, rare
	Purple = Color3.fromHex("#B26BFF"),     -- epic
	Orange = Color3.fromHex("#FF9A2E"),
	Teal = Color3.fromHex("#2EC4B6"),
	Robux = Color3.fromHex("#5FD35A"),      -- "R$ 249" prices
	NeedsWork = Color3.fromHex("#FF8A8A"),  -- soft light red: "needs work", very low stamina
	StatNumber = Color3.fromHex("#DCEEFF"), -- light blue-white: the numbers on the world stats labels
}

-- Transparency levels (0 = solid, 1 = invisible)
Theme.Alpha = {
	Panel = 0.06,         -- panels (#18181E at 6%)
	Pill = 0.22,          -- top bar pills
	HudCard = 0.12,       -- HUD cards over the world (daily quests)
	LabelBacking = 0.6,   -- the faint box behind world labels
	Border = 0,           -- the dark outline is solid
	BorderSoft = 0.4,
	ButtonBorder = 0,
	Primary = 0,
	TextShadow = 0,       -- the black outline on text over the world
	Backdrop = 0.6,       -- black behind a modal (the game also blurs)
}

-- The glossy button gradients (top -> bottom). The bottom lip is the bottom color made darker.
Theme.Gradients = {
	Green = { Color3.fromHex("#5FD35A"), Color3.fromHex("#2F9E35") },
	Red = { Color3.fromHex("#EE3A42"), Color3.fromHex("#B31D25") },
	Gold = { Color3.fromHex("#FFD34D"), Color3.fromHex("#E79A12") },
	Blue = { Color3.fromHex("#4AA3FF"), Color3.fromHex("#1F62D6") },
	Gray = { Color3.fromHex("#4A4A55"), Color3.fromHex("#2C2C34") },
	Purple = { Color3.fromHex("#B26BFF"), Color3.fromHex("#6D2FD1") },
	Orange = { Color3.fromHex("#FFB04A"), Color3.fromHex("#E2701A") },
	Teal = { Color3.fromHex("#4FE0CF"), Color3.fromHex("#1A9A8D") },
	Dark = { Color3.fromHex("#2E2E36"), Color3.fromHex("#1E1E25") },
}
-- button style names -> gradient (old names kept: Primary / Main = red, Secondary = gray, White = gray)
Theme.ButtonGradients = {
	Primary = "Red", Main = "Red", Red = "Red", Green = "Green", Gold = "Gold", Blue = "Blue", Secondary = "Gray", Gray = "Gray",
	Disabled = "Dark", Purple = "Purple", Orange = "Orange", Teal = "Teal", White = "Gray", Dark = "Dark",
}

-- Real bumper plate colors (plate fill + darker rim). Used for grades, rarity and plates.
local function plate(hex, textOnPlate)
	local fill = Color3.fromHex(hex)
	return { Fill = fill, Rim = fill:Lerp(Color3.new(0, 0, 0), 0.35), Text = textOnPlate }
end
Theme.Bumper = {
	White = plate("#F4F1EA", Theme.Colors.Ink),
	Green = plate("#2E9E4F", Theme.Colors.Text),
	Yellow = plate("#E8C21C", Theme.Colors.Ink),
	Blue = plate("#1F5FBF", Theme.Colors.Text),
	Red = plate("#D7262E", Theme.Colors.Text),
	Black = plate("#141414", Theme.Colors.Text),
	Steel = plate("#A9ADB3", Theme.Colors.Ink), -- small metal change plate (5 lb)
}
Theme.Grades = { D = Theme.Bumper.White, C = Theme.Bumper.Green, B = Theme.Bumper.Yellow, A = Theme.Bumper.Blue, S = Theme.Bumper.Red }
Theme.Rarity = {
	Common = Theme.Bumper.White,
	Uncommon = Theme.Bumper.Green,
	Rare = Theme.Bumper.Yellow,
	Epic = Theme.Bumper.Blue,
	Legendary = Theme.Bumper.Red,
	Secret = Theme.Bumper.Black,
}

-- Fonts (UIFonts): Display = FredokaOne (labels, titles, buttons, numbers; white with a black outline), Body = Montserrat
-- SemiBold, BodyBold = Montserrat Bold. The weight names stay so every screen keeps working: Regular / Small / Label =
-- body text, Strong = bold body text, everything else = FredokaOne.
local UIFonts = require(script.Parent:WaitForChild("UIFonts"))
Theme.UIFonts = UIFonts
Theme.Fonts = {
	Light = UIFonts.Display,
	Regular = UIFonts.Body,
	SemiBold = UIFonts.Display,
	Bold = UIFonts.Display,
	Strong = UIFonts.BodyBold,
}
Theme.Fonts.Medium = UIFonts.Display
Theme.Fonts.Heading = UIFonts.Display
Theme.Fonts.Display = UIFonts.Display
Theme.Fonts.Label = Theme.Fonts.Regular
Theme.Fonts.Small = Theme.Fonts.Regular

Theme.TileFont = UIFonts.Display
Theme.TileStroke = Theme.Colors.Outline
Theme.PillHeight = 32 -- the top-bar pills (mockup px; their tap area is padded to 44)
Theme.Tile = {
	ShadeBottom = Color3.fromRGB(140, 140, 150),
	ActiveBorder = Color3.new(1, 1, 1),
	LabelSmall = 14,
	LabelBig = 17,
	BigFrom = 80,
	LipDarken = 0.66,
	FaceDarken = 0.5,
}

-- Named sizes, or a plain number (mockup px inside a Kit.Root).
Theme.TextSize = {
	Slam = 72,
	Hero = 56,
	HeroCompact = 38,
	Huge = 40,
	Display = 42,
	Big = 34,
	Title = 30,
	Large = 22,
	Medium = 18,
	Popup = 26,
	Body = 16,
	Small = 14,
	Label = 11,
}
Theme.MinTextSize = 10

Theme.Spacing = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }

Theme.Corner = {
	Panel = UDim.new(0, 14),
	Card = UDim.new(0, 10),
	Button = UDim.new(0, 10), -- (the left menu tiles' corners)
	Tag = UDim.new(0, 6),
	Segment = UDim.new(0, 3),
	Round = UDim.new(1, 0),
}

Theme.Border = { Color = Theme.Colors.Outline, Thickness = 2, Transparency = 0 }
Theme.Outline = { Panel = 2, Button = 2, Card = 1.5 }
Theme.Colors.Edge = Color3.fromHex("#3A3A46")      -- the soft light edge around panels and cards (like the menu's "<" tab)
Theme.IconStroke = 2
Theme.MinTouch = 44 -- px, smallest tappable button on mobile

-- Short screens (phones in landscape) get compact layouts. In Studio a "TestPhoneLayout" attribute on Workspace forces it.
Theme.CompactHeight = 520
function Theme.IsCompact()
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.Y > 1 and camera.ViewportSize.Y < Theme.CompactHeight then return true end
	return game:GetService("RunService"):IsStudio() and workspace:GetAttribute("TestPhoneLayout") == true
end

function Theme.OnCompactChanged(callback)
	local last = Theme.IsCompact()
	task.spawn(callback, last)
	local function watch(camera)
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local now = Theme.IsCompact()
			if now ~= last then
				last = now
				callback(now)
			end
		end)
	end
	if workspace.CurrentCamera then watch(workspace.CurrentCamera) end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if workspace.CurrentCamera then watch(workspace.CurrentCamera) end
	end)
end

Theme.Motion = {
	Time = 0.25,
	Style = Enum.EasingStyle.Quad,
	Direction = Enum.EasingDirection.Out,
	PressScale = 0.94,
	PressTime = 0.07,
	Bounce = Enum.EasingStyle.Back, -- pops, rep counter, button release
}

------------------------------------------------------------------------
-- Builders
------------------------------------------------------------------------
function Theme.Tween(instance, props, time, style)
	local info = TweenInfo.new(time or Theme.Motion.Time, style or Theme.Motion.Style, Theme.Motion.Direction)
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

-- Instance.new with properties and children. GuiObjects never get default borders.
function Theme.New(class, props, children)
	local instance = Instance.new(class)
	if instance:IsA("GuiObject") then
		instance.BorderSizePixel = 0
	end
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	return instance
end

function Theme.ScreenGui(props)
	props.ResetOnSpawn = false
	props.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	props.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return Theme.New("ScreenGui", props)
end

-- The part of a full-screen gui (ScreenInsets.None) below the Roblox top bar.
function Theme.SafeArea(parent)
	local GuiService = game:GetService("GuiService")
	local frame = Theme.New("Frame", { Name = "Safe", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	local function fit()
		local inset = GuiService.TopbarInset.Height
		frame.Position = UDim2.fromOffset(0, inset)
		frame.Size = UDim2.new(1, 0, 1, -inset)
	end
	fit()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit)
	return frame
end

function Theme.Round(kind)
	return Theme.New("UICorner", { CornerRadius = Theme.Corner[kind] })
end

-- An outline (the dark #0D0D12 one by default).
function Theme.Stroke(color, thickness, transparency)
	return Theme.New("UIStroke", {
		Color = color or Theme.Border.Color,
		Thickness = thickness or Theme.Border.Thickness,
		Transparency = transparency or Theme.Border.Transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- The black outline on text (every FredokaOne label gets one; this adds or returns it).
function Theme.TextShadow(label, transparency)
	local existing = label:FindFirstChild("TextStroke")
	if existing then
		if transparency then existing.Transparency = transparency end
		return existing
	end
	return Theme.New("UIStroke", { Name = "TextStroke", Color = Theme.Colors.Shadow, Thickness = 2,
		Transparency = transparency or Theme.Alpha.TextShadow, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
end

function Theme.Pad(space)
	local px = UDim.new(0, Theme.Spacing[space])
	return Theme.New("UIPadding", { PaddingTop = px, PaddingBottom = px, PaddingLeft = px, PaddingRight = px })
end

function Theme.List(direction, space, horizontal, vertical)
	return Theme.New("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, type(space) == "number" and space or Theme.Spacing[space] or 0),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Theme.Aspect(ratio, dominantAxis)
	return Theme.New("UIAspectRatioConstraint", {
		AspectRatio = ratio,
		DominantAxis = dominantAxis or Enum.DominantAxis.Width,
	})
end

function Theme.Limit(minSize, maxSize)
	return Theme.New("UISizeConstraint", { MinSize = minSize, MaxSize = maxSize })
end

-- Button labels are UPPERCASE (titles keep their case in this style: "Gym Store", "Bench Press").
-- props.Upper = false keeps a label's own case even inside a button.
function Theme.Uppercase(label)
	if label:GetAttribute("Upper") then return end
	label:SetAttribute("Upper", true)
	local function apply()
		local upper = string.upper(label.Text)
		if upper ~= label.Text then label.Text = upper end
	end
	apply()
	label:GetPropertyChangedSignal("Text"):Connect(apply)
end

-- Text: whole-number sizes (named or mockup px), no TextScaled. FredokaOne text (every weight but Regular / Small /
-- Label / Strong) gets the black outline, thicker on big text; props.Stroke = false leaves it off.
local BODY_FONTS = { Regular = true, Small = true, Label = true, Strong = true }
function Theme.StrokeFor(size)
	return size >= 24 and 3 or (size >= 14 and 2 or 1.5)
end
function Theme.Text(props)
	local sizeKey = props.TextSize or "Body"
	local fontKey = props.Font or "Regular"
	local upper = props.Upper
	local stroke = props.Stroke
	props.Font = nil
	props.Upper = nil
	props.Stroke = nil
	props.BackgroundTransparency = 1
	props.TextScaled = false
	local size = type(sizeKey) == "number" and sizeKey or Theme.TextSize[sizeKey] or Theme.TextSize.Body
	props.TextSize = math.max(Theme.MinTextSize, math.floor(size))
	props.FontFace = Theme.Fonts[fontKey] or Theme.Fonts.Regular
	props.TextColor3 = props.TextColor3 or Theme.Colors.Text
	local label = Theme.New("TextLabel", props)
	if stroke ~= false and not BODY_FONTS[fontKey] then
		local outline = Theme.TextShadow(label)
		outline.Thickness = Theme.StrokeFor(props.TextSize)
	end
	if upper == true then Theme.Uppercase(label) end
	if upper == false then label:SetAttribute("Upper", true) end -- (so a button can't make it upper either)
	return label
end

-- Fade a whole UI tree by tweening each element's own transparency (no CanvasGroup, which
-- rasterizes text and makes it blurry). Fading out remembers each value; fading in restores it.
-- The remembered values and the fade state live in attributes on the instances themselves: a weak table keyed
-- by instances loses entries when Luau collects the wrapper of an unreferenced label, and that label then
-- fades back in to "invisible".
local FADE_RECORD = "FadeShown_" -- + property name: the value to restore when fading in
local FADE_STATE = "FadeState"   -- on the root: "shown" | "hidden" | "in" | "out"

local function fadeProps(instance)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		return { "BackgroundTransparency", "TextTransparency" }
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		return { "BackgroundTransparency", "ImageTransparency" }
	elseif instance:IsA("ScrollingFrame") then
		return { "BackgroundTransparency", "ScrollBarImageTransparency" }
	elseif instance:IsA("GuiObject") then
		return { "BackgroundTransparency" }
	elseif instance:IsA("UIStroke") then
		return { "Transparency" }
	end
	return nil
end

function Theme.Fade(root, visible, time)
	time = time or Theme.Motion.Time
	local state = root:GetAttribute(FADE_STATE) or "shown"
	local items = root:GetDescendants()
	table.insert(items, root)
	local lastTween
	for _, instance in ipairs(items) do
		local props = fadeProps(instance)
		if props then
			local recorded = instance:GetAttribute(FADE_RECORD .. props[1]) ~= nil
			local goal = {}
			for _, prop in ipairs(props) do
				local key = FADE_RECORD .. prop
				if visible then
					if not recorded then
						-- never faded before: its current look is the target; start from invisible
						instance:SetAttribute(key, instance[prop])
						instance[prop] = 1
					end
					goal[prop] = instance:GetAttribute(key)
				else
					if not recorded or state == "shown" then
						instance:SetAttribute(key, instance[prop])
					end
					goal[prop] = 1
				end
			end
			lastTween = Theme.Tween(instance, goal, time)
		end
	end
	root:SetAttribute(FADE_STATE, visible and "in" or "out")
	if lastTween then
		lastTween.Completed:Connect(function(playback)
			if playback == Enum.PlaybackState.Completed and root:GetAttribute(FADE_STATE) == (visible and "in" or "out") then
				root:SetAttribute(FADE_STATE, visible and "shown" or "hidden")
				if visible then
					for _, instance in ipairs(items) do
						local props = fadeProps(instance)
						if props then
							for _, prop in ipairs(props) do instance:SetAttribute(FADE_RECORD .. prop, nil) end
						end
					end
				end
			end
		end)
	end
	return lastTween
end

-- Pressing a button: shrink to 0.94, then bounce back on release. A very soft click.
local audio -- Shared.Audio, loaded on first press (client only)
function Theme.BindPress(button)
	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	local down = false
	local function setDown(on)
		if on == down then return end
		down = on
		local scale = button:FindFirstChild("PressScale") or Theme.New("UIScale", { Name = "PressScale", Parent = button })
		if on then
			Theme.Tween(scale, { Scale = Theme.Motion.PressScale }, Theme.Motion.PressTime)
		else
			Theme.Tween(scale, { Scale = 1 }, 0.22, Theme.Motion.Bounce)
		end
	end
	button.InputBegan:Connect(function(input) if isPress(input) then setDown(true) end end)
	button.InputEnded:Connect(function(input) if isPress(input) then setDown(false) end end)
	button.MouseLeave:Connect(function() setDown(false) end)
	button.Activated:Connect(function()
		audio = audio or require(script.Parent.Parent:WaitForChild("Audio"))
		audio.PlayUI("Click")
	end)
end

-- (the soft drop shadows of the old styles: this style has none; kept so older screens still work)
Theme.Depth = { Shadow = { Offset = 0, Rings = {} } }
function Theme.AddDepth(gui)
	return gui
end
Theme.PanelShadowGrow = 0

------------------------------------------------------------------------
-- Surfaces: panels, cards, wells, pills. Theme.SetPiece(gui, name) gives a gui one of these looks (the names are the
-- old image piece names, so every screen keeps working):
--   panel       dark #18181E, 14px corners, 3px outline           hud_box  HUD card over the world (#16161A)
--   card        #28282F row / cell, 10px corners, 2px outline     well     dark inset (bar tracks)
--   card_selected  card with a green outline (equipped, following)  card_gold  card with a gold outline
--   chip / pill    dark round pill (top bar)                       banner_gold  dark gold banner
------------------------------------------------------------------------
Theme.Surfaces = {
	panel = { color = Theme.Colors.Panel, alpha = Theme.Alpha.Panel, corner = 14, outline = 2, outlineColor = Theme.Colors.Edge },
	hud_box = { color = Theme.Colors.Pill, alpha = Theme.Alpha.HudCard, corner = 12, outline = 1.5, outlineColor = Theme.Colors.Edge },
	card = { color = Theme.Colors.Card, alpha = 0, corner = 10, outline = 1.5, outlineColor = Theme.Colors.Edge },
	card_selected = { color = Theme.Colors.Card, alpha = 0, corner = 10, outline = 3, outlineColor = Theme.Colors.Green },
	card_gold = { color = Theme.Colors.Card, alpha = 0, corner = 10, outline = 3, outlineColor = Theme.Colors.Gold },
	well = { color = Theme.Colors.Well, alpha = 0, corner = 8, outline = 1.5, outlineColor = Theme.Colors.Edge },
	chip = { color = Theme.Colors.Pill, alpha = Theme.Alpha.Pill, corner = 999, outline = 0 },
	pill = { color = Theme.Colors.Pill, alpha = Theme.Alpha.Pill, corner = 999, outline = 0 },
	panel_header = { color = Theme.Colors.Panel, alpha = 1, corner = 14, outline = 0 },
	banner_gold = { color = Color3.fromHex("#3A2A0C"), alpha = 0.1, corner = 12, outline = 3, outlineColor = Theme.Colors.Gold },
}

local function outlineOf(gui)
	local stroke = gui:FindFirstChild("Border")
	if not stroke then
		stroke = Theme.New("UIStroke", { Name = "Border", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = gui })
	end
	return stroke
end

function Theme.SetPiece(gui, name)
	local surface = Theme.Surfaces[name] or Theme.Surfaces.card
	gui.BackgroundColor3 = surface.color
	gui.BackgroundTransparency = surface.alpha
	if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then gui.Image = "" end
	local corner = gui:FindFirstChildOfClass("UICorner") or Theme.New("UICorner", { Parent = gui })
	corner.CornerRadius = surface.corner >= 999 and UDim.new(1, 0) or UDim.new(0, surface.corner)
	local stroke = outlineOf(gui)
	stroke.Color = surface.outlineColor or Theme.Colors.Outline
	stroke.Thickness = surface.outline
	stroke.Transparency = 0
	stroke.Enabled = surface.outline > 0
	gui:SetAttribute("Piece", name)
	return gui
end

-- Panel: a surface (props.Piece: "panel" by default, or any Theme.Surfaces name). props.Clickable = true makes it a button
-- (an ImageButton without an image: use its Activated).
function Theme.Panel(props, children)
	local piece = props.Piece or "panel"
	local clickable = props.Clickable
	props.Piece, props.Shadow, props.Clickable = nil, nil, nil
	if clickable then props.AutoButtonColor = false end
	local panel = Theme.New(clickable and "ImageButton" or "ImageLabel", props, children)
	Theme.SetPiece(panel, piece)
	return panel
end

------------------------------------------------------------------------
-- Buttons: a glossy gradient (Theme.Gradients) with a darker bottom lip, a thin lighter inner line and the dark
-- outline. Styles: "Primary" / "Main" / "Red", "Green", "Gold", "Blue", "Secondary" / "Gray", "Disabled", "Purple",
-- "Orange", "Teal". Labels are FredokaOne, white with a black outline, UPPERCASE. Theme.SetButtonStyle switches it.
------------------------------------------------------------------------
Theme.ButtonText = { Disabled = Theme.Colors.Muted }
Theme.LipHeight = 0.14 -- share of the button's height that is the darker bottom lip

local function gradientFor(style)
	local g = Theme.Gradients[Theme.ButtonGradients[style] or "Gray"]
	local top, bottom = g[1], g[2]
	local lip = bottom:Lerp(Color3.new(0, 0, 0), 0.3)
	local edge = 1 - Theme.LipHeight
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(edge - 0.001, bottom),
		ColorSequenceKeypoint.new(edge, lip),
		ColorSequenceKeypoint.new(1, lip),
	})
end

function Theme.SetButtonStyle(button, style)
	button:SetAttribute("Style", style)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0
	if button:IsA("ImageButton") or button:IsA("ImageLabel") then button.Image = "" end
	local gradient = button:FindFirstChild("Gloss") or Theme.New("UIGradient", { Name = "Gloss", Rotation = 90, Parent = button })
	gradient.Color = gradientFor(style)
	local corner = button:FindFirstChildOfClass("UICorner") or Theme.New("UICorner", { Parent = button })
	corner.CornerRadius = Theme.Corner.Button
	-- (owner, 13 Oct: buttons match the left menu tiles: a lighter border in the button's own color, the tiles' corners)
	local g = Theme.Gradients[Theme.ButtonGradients[style] or "Gray"]
	local stroke = outlineOf(button)
	stroke.Color, stroke.Thickness, stroke.Transparency, stroke.Enabled = g[1]:Lerp(Color3.new(1, 1, 1), 0.3), Theme.Outline.Button, 0.1, true
	-- the thin lighter line just inside the outline (above the lip). It lives in a "Depth" Folder (list layouts ignore
	-- it) and is pushed back out by the button's UIPadding.
	local depth = button:FindFirstChild("Depth") or Theme.New("Folder", { Name = "Depth", Parent = button })
	local inner = depth:FindFirstChild("Inner")
	if not inner then
		inner = Theme.New("Frame", { Name = "Inner", BackgroundTransparency = 1, ZIndex = button.ZIndex, Parent = depth }, {
			Theme.New("UICorner", { CornerRadius = UDim.new(0, 7) }),
			Theme.New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		local lip = Theme.LipHeight
		local function fit()
			local pad = button:FindFirstChildOfClass("UIPadding")
			local l = pad and pad.PaddingLeft.Offset or 0
			local r = pad and pad.PaddingRight.Offset or 0
			local t = pad and pad.PaddingTop.Offset or 0
			local b = pad and pad.PaddingBottom.Offset or 0
			inner.Position = UDim2.fromOffset(2 - l, 2 - t)
			inner.Size = UDim2.new(1, l + r - 4, 1 - lip, (t + b) * (1 - lip) - 2)
		end
		fit()
		button.ChildAdded:Connect(function(child)
			if child:IsA("UIPadding") then task.defer(fit) end
		end)
	end
	inner:FindFirstChildOfClass("UIStroke").Transparency = style == "Disabled" and 0.92 or 0.7
	local color = Theme.ButtonText[style] or Theme.Colors.Text
	for _, item in ipairs(button:GetDescendants()) do
		if item:IsA("TextLabel") and not item:GetAttribute("KeepColor") then item.TextColor3 = color end
		if item:IsA("ImageLabel") and item.Name == "Icon" and not item:GetAttribute("KeepColor") then item.ImageColor3 = color end
	end
end

function Theme.Button(style, props, children)
	props.Text = nil
	props.AutoButtonColor = false
	local button = Theme.New("ImageButton", props, children)
	-- button labels are UPPERCASE (labels passed in as children, or added later)
	local function upperLabel(item)
		if item:IsA("TextLabel") and item.FontFace == Theme.Fonts.Display then Theme.Uppercase(item) end
	end
	for _, item in ipairs(button:GetDescendants()) do upperLabel(item) end
	button.DescendantAdded:Connect(function(item) task.defer(upperLabel, item) end)
	Theme.SetButtonStyle(button, style)
	Theme.BindPress(button)
	return button
end

function Theme.PlateDisc(bumper, props)
	props.BackgroundColor3 = bumper.Fill
	return Theme.New("Frame", props, { Theme.Round("Round"), Theme.Stroke(bumper.Rim, 2, 0) })
end

-- RankTag: the one reusable rank badge (genetics grades S/A/B/C/D): a small fully-rounded pill (20x18), thin border and the
-- letter in the rank color, dark see-through fill, Oswald Bold. S gets a very faint glow. Use it everywhere a grade shows.
Theme.RankColors = {
	S = Color3.fromHex("#FF7B6E"), -- soft red/coral
	A = Color3.fromHex("#6FA8FF"), -- soft blue
	B = Color3.fromHex("#F2CF66"), -- soft gold
	C = Color3.fromHex("#6FD08C"), -- soft green
	D = Color3.fromHex("#B8B8BE"), -- gray
}
-- The genetics plates (owner's genetics redesign): the rank colors, deeper and less saturated, with a slight metallic
-- sheen (Reflectance). Fill = plate body, Rim = raised rim / inset ring, Glow = light and particles (the bright rank
-- color), Text = the grade letter on the plate face.
local function gradePlate(grade, deepen)
	local glow = Theme.RankColors[grade]
	local fill = glow:Lerp(Color3.fromHex("#16161A"), deepen)
	return { Fill = fill, Rim = fill:Lerp(Color3.new(0, 0, 0), 0.35), Glow = glow, Text = Theme.Colors.Text }
end
Theme.GradePlates = {
	S = gradePlate("S", 0.3),
	A = gradePlate("A", 0.32),
	B = gradePlate("B", 0.3),
	C = gradePlate("C", 0.34),
	D = gradePlate("D", 0.4),
}
Theme.Colors.Upgrade = Theme.RankColors.C -- the green "upgrade" arrow after a reroll
function Theme.SetRankTag(tag, grade)
	local color = Theme.RankColors[grade] or Theme.RankColors.D
	local stroke = tag:FindFirstChild("Border")
	if stroke then stroke.Color = color end
	local glow = tag:FindFirstChild("Glow")
	if glow then
		glow.Color = color
		glow.Enabled = grade == "S"
	end
	local label = tag:FindFirstChild("Letter")
	if label then
		label.Text = grade
		label.TextColor3 = color
	end
end
function Theme.RankTag(grade, props)
	props = props or {}
	props.Name = props.Name or "RankTag"
	props.Size = props.Size or UDim2.fromOffset(20, 18)
	props.BackgroundColor3 = Theme.Colors.Panel
	props.BackgroundTransparency = Theme.Alpha.Panel
	local tag = Theme.New("Frame", props, {
		Theme.New("UICorner", { CornerRadius = UDim.new(0, 9) }), -- (fully rounded pill)
		Theme.New("UIStroke", { Name = "Glow", Thickness = 4, Transparency = 0.9, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Enabled = false }),
		Theme.New("UIStroke", { Name = "Border", Thickness = 1.2, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	Theme.Text({ Name = "Letter", Font = "Bold", TextSize = "Small", Size = UDim2.fromScale(1, 1), Parent = tag })
	Theme.SetRankTag(tag, grade)
	return tag
end

-- Panels slide up and fade in / slide down and fade out. `frame` fills its layout slot.
function Theme.Show(frame)
	frame.Visible = true
	frame.Position = UDim2.fromOffset(0, Theme.Spacing.XL)
	Theme.Tween(frame, { Position = UDim2.fromOffset(0, 0) })
	return Theme.Fade(frame, true)
end

function Theme.Hide(frame)
	Theme.Tween(frame, { Position = UDim2.fromOffset(0, Theme.Spacing.XL) })
	local tween = Theme.Fade(frame, false)
	if tween then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then frame.Visible = false end
		end)
	end
	return tween
end

return Theme
