-- GYM ARC design system: the FINAL UI kit "BLACK + GOLD" (owner, 14 Oct: Downloads/GYM_ARC_UI_final.md + the mockups in
-- gym_arc_ui_final; replaces every earlier look: grit, Gym League, premium). Layouts stay; only the materials changed.
--   * Panels: dark graphite, a vertical gradient #252226 -> #18161A -> #0D0C0E, a 1px light hairline along the top edge,
--     14px corners and a soft dark edge. Cards inside: #232023 -> #141215, a top highlight, a darker bottom lip, 11px.
--   * Text: one heavy italic athletic font (Montserrat Black Italic) for titles, names, buttons and numbers; small body
--     text Montserrat Medium in gray.
--   * Gold (a gradient with a glint) for the active tab, hero names, rewards, big numbers and rank plates. Red only for
--     the one hype / CTA button on a screen; teal only for progress and stamina.
--   * CTA buttons (Red, Gold): a bevelled gradient with a glossy top lip, a darker bottom lip, a soft colored glow and a
--     diagonal shine streak (it sweeps across once when a window opens; featured CTAs pulse every 1.6 s).
--     Everything else is quiet: dark buttons with a top highlight; inactive tabs are FLAT (no bevel, gray text).
--   * Hover 1.04, press 0.96. Reduced motion (Roblox's setting or the game's Settings toggle) stops the loops.
-- Color still means something: plates, grades and rarity keep the bumper plate colors. Every UI reads its look from here
-- and from Shared.UI.Kit (the components).
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Background = Color3.fromHex("#0A090B"), -- modal backdrops, deep wells
	Panel = Color3.fromHex("#18161A"),      -- panels (the middle of their gradient)
	Card = Color3.fromHex("#1B181C"),       -- cards / rows inside panels
	Well = Color3.fromHex("#0A090B"),       -- bar tracks, price pills
	Pill = Color3.fromHex("#141215"),       -- top bar pills, HUD cards over the world
	Secondary = Color3.fromHex("#2A272B"),  -- quiet buttons
	Disabled = Color3.fromHex("#1C1A1D"),
	TabActive = Color3.fromHex("#F6C75A"),
	HeaderTop = Color3.fromHex("#252226"),
	HeaderBottom = Color3.fromHex("#18161A"),
	Outline = Color3.fromHex("#050405"),    -- the dark edge around panels, buttons and cards
	Border = Color3.fromHex("#050405"),     -- (old name for the outline)
	Text = Color3.fromHex("#FFFFFF"),       -- main text
	Muted = Color3.fromHex("#A39A9D"),      -- secondary text
	Faint = Color3.fromHex("#6F6669"),      -- locked items
	Chalk = Color3.fromHex("#FFFFFF"),
	Ink = Color3.fromHex("#2A1C05"),        -- dark text on gold
	Shadow = Color3.fromHex("#000000"),
	Red = Color3.fromHex("#E8343C"),        -- the CTA
	RedTint = Color3.fromHex("#3A1013"),
	Gold = Color3.fromHex("#F6C75A"),       -- coins, prices, tiers, big moments
	GoldDeep = Color3.fromHex("#C98A12"),
	Green = Color3.fromHex("#36C26B"),      -- claim, done, auto on, following
	Blue = Color3.fromHex("#3F8CFF"),       -- rare
	Purple = Color3.fromHex("#9A5CFF"),     -- epic
	Orange = Color3.fromHex("#FF9A2E"),
	Teal = Color3.fromHex("#3CC8B4"),       -- progress and stamina only
	Robux = Color3.fromHex("#FFFFFF"),      -- "R$ 249" prices (white in a dark pill)
	NeedsWork = Color3.fromHex("#FF8A8A"),  -- soft light red: "needs work", very low stamina
	StatNumber = Color3.fromHex("#DCEEFF"), -- light blue-white: the numbers on the world stats labels
}

-- Transparency levels (0 = solid, 1 = invisible)
Theme.Alpha = {
	Panel = 0,            -- panels are solid graphite
	Pill = 0.08,          -- top bar pills
	HudCard = 0.06,       -- HUD cards over the world (daily quests)
	LabelBacking = 0.6,   -- the faint box behind world labels
	Border = 0,
	BorderSoft = 0.4,
	ButtonBorder = 0,
	Primary = 0,
	TextShadow = 0.55,    -- the soft dark outline on text (strong enough over the world, quiet on panels)
	Backdrop = 0.82,      -- black behind a modal: light, the gym stays visible (the vignette darkens near the panel)
	Hairline = 0.78,      -- the light line along a panel's top edge
}

-- The gold gradient (with a glint) and the red CTA, top -> bottom.
Theme.GoldSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF3C4")),
	ColorSequenceKeypoint.new(0.3, Color3.fromHex("#F6C75A")),
	ColorSequenceKeypoint.new(0.72, Color3.fromHex("#C98A12")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("#F2C45A")),
})
-- Button gradients (top, bottom); the bottom lip is the bottom made darker. Gold / Red are the CTAs.
Theme.Gradients = {
	Gold = { Color3.fromHex("#FFE9A6"), Color3.fromHex("#D69B22") },
	Red = { Color3.fromHex("#FF5A61"), Color3.fromHex("#C41E27") },
	Quiet = { Color3.fromHex("#2E2A2F"), Color3.fromHex("#1A181B") },
	Flat = { Color3.fromHex("#1C1A1D"), Color3.fromHex("#1C1A1D") },
	Disabled = { Color3.fromHex("#1A181B"), Color3.fromHex("#1A181B") },
	-- (prompt 37 / 40: the ChunkyButton's green: EQUIP, CLAIM, WEAR, USE, KEEP, OWNED)
	Green = { Color3.fromHex("#7BE38F"), Color3.fromHex("#23A047") },
	-- (older names some screens still pass; they all draw as a quiet or CTA button)
	Blue = { Color3.fromHex("#2E2A2F"), Color3.fromHex("#1A181B") },
	Gray = { Color3.fromHex("#2E2A2F"), Color3.fromHex("#1A181B") },
	Purple = { Color3.fromHex("#2E2A2F"), Color3.fromHex("#1A181B") },
	Orange = { Color3.fromHex("#2E2A2F"), Color3.fromHex("#1A181B") },
	Teal = { Color3.fromHex("#2E2A2F"), Color3.fromHex("#1A181B") },
	Dark = { Color3.fromHex("#2E2A2F"), Color3.fromHex("#1A181B") },
}
-- button style names -> look. Red / Primary / Main = the red CTA; Gold = the gold CTA; Green = the same gold without the
-- glow ring (buttons that come in rows: EQUIP, buy tiles, choices); Tab = the active tab; Flat = an inactive tab;
-- Disabled; everything else (Gray, Secondary, Dark, Blue, Purple, Orange, Teal, White) = a quiet dark button.
Theme.ButtonGradients = {
	Primary = "Red", Main = "Red", Red = "Red", Gold = "Gold", Green = "Green", Flat = "Flat", Disabled = "Disabled",
	Tab = "Gold", -- the active tab: the gold fill only (no glow ring, no gloss / shine; owner, 14 Oct)
	Secondary = "Quiet", Gray = "Quiet", Dark = "Quiet", Blue = "Quiet", Purple = "Quiet", Orange = "Quiet", Teal = "Quiet",
	White = "Quiet", Quiet = "Quiet",
}
Theme.CTA = { Red = Color3.fromHex("#FF4A52"), Gold = Color3.fromHex("#FFD36B"), Green = Color3.fromHex("#5BE07A") } -- each CTA's glow color

-- (prompt 37 / 40, 22 Oct) the ONE rarity colour table: text, outlines and tile tints everywhere (Theme.Rarity below is
-- the older bumper-plate table some screens still use for plates)
Theme.RarityColor = {
	Common = Color3.fromHex("#AAAAB2"), Uncommon = Color3.fromHex("#50D264"), Rare = Color3.fromHex("#468CFF"),
	Epic = Color3.fromHex("#AA50FF"), Legendary = Color3.fromHex("#F5BE28"), Mythic = Color3.fromHex("#FF5AC8"),
	Eternal = Color3.fromHex("#F0F0FF"), Secret = Color3.fromHex("#8E8E9A"),
}
-- (prompt 44, owner: the old mesh was too fine to see) Downloads\gym_arc_textures\hex_tile.png (seamless, white lines on
-- transparent, 156x90), always ScaleType Tile at a fixed size (never scaled with the tile), tinted, ~0.8 transparent
Theme.HexImage = "rbxassetid://117814833566275"
Theme.HexTile = UDim2.fromOffset(52, 30)    -- normal tiles (cards, nav tiles, reward tiles)
Theme.HexTileBig = UDim2.fromOffset(78, 45) -- big panels
Theme.HexTileBar = UDim2.fromOffset(26, 15) -- bars (they're only ~10 px tall)
Theme.HexAlpha = 0.65 -- collectible tiles (tested 22 Oct: at 52x30 the lines are ~1 px, 0.8 vanished on phones)
Theme.HexQuiet = 0.91 -- (owner, 22 Oct) panels, cards, HUD boxes: 8-10%

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

-- Fonts (UIFonts): Display = Montserrat Black Italic (titles, names, buttons, numbers), Body = Montserrat Medium,
-- BodyBold = Montserrat Bold. The weight names stay so every screen keeps working: Regular / Small / Label = body text,
-- Strong = bold body text, everything else = the display font.
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
Theme.Fonts.Chunky = UIFonts.Chunky -- (prompt 40: buttons, numbers, names, labels)
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
Theme.Colors.Edge = Color3.fromHex("#2E2A2E")      -- a soft lighter edge (rows, inputs)
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
	PressScale = 0.96,
	HoverScale = 1.04,
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

-- An outline (the dark one by default).
function Theme.Stroke(color, thickness, transparency)
	return Theme.New("UIStroke", {
		Color = color or Theme.Border.Color,
		Thickness = thickness or Theme.Border.Thickness,
		Transparency = transparency or Theme.Border.Transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- The soft dark outline on text (every display-font label gets one; this adds or returns it).
function Theme.TextShadow(label, transparency)
	local existing = label:FindFirstChild("TextStroke")
	if existing then
		if transparency then existing.Transparency = transparency end
		return existing
	end
	return Theme.New("UIStroke", { Name = "TextStroke", Color = Theme.Colors.Shadow, Thickness = 1,
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

-- Text: whole-number sizes (named or mockup px), no TextScaled. Display-font text (every weight but Regular / Small /
-- Label / Strong) gets a soft dark outline; props.Stroke = false leaves it off.
local BODY_FONTS = { Regular = true, Small = true, Label = true, Strong = true }
function Theme.StrokeFor(size)
	return size >= 24 and 1.5 or 1
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
		-- (prompt 40) chunky words wear a solid dark stroke (mockups 05 / 06)
		if props.FontFace == Theme.Fonts.Chunky then
			outline.Color = Theme.Colors.Outline
			outline.Transparency = 0
			outline.Thickness = math.max(1.5, props.TextSize / 11)
		end
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

-- A button's ONE UIScale ("Scale", from its centre): press x pulse, two NumberValues tweened separately (owner, 14 Oct:
-- press and pulse never tween Size or Position, and a gui uses only one UIScale).
function Theme.ButtonScale(button)
	local scale = button:FindFirstChild("Scale")
	local press = scale and scale:FindFirstChild("Press")
	local pulse = scale and scale:FindFirstChild("Pulse")
	if not (scale and press and pulse) then
		scale = Theme.New("UIScale", { Name = "Scale", Parent = button })
		press = Theme.New("NumberValue", { Name = "Press", Value = 1, Parent = scale })
		pulse = Theme.New("NumberValue", { Name = "Pulse", Value = 1, Parent = scale })
		local function update() scale.Scale = press.Value * pulse.Value end
		press.Changed:Connect(update)
		pulse.Changed:Connect(update)
	end
	return { scale = scale, press = press, pulse = pulse }
end

-- Hover grows a button to 1.04, pressing shrinks it to 0.96 and it bounces back on release. A very soft click.
local audio -- Shared.Audio, loaded on first press (client only)
function Theme.BindPress(button)
	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	local down, hover = false, false
	local function apply()
		local press = Theme.ButtonScale(button).press
		if down then
			Theme.Tween(press, { Value = Theme.Motion.PressScale }, Theme.Motion.PressTime)
		else
			Theme.Tween(press, { Value = hover and Theme.Motion.HoverScale or 1 }, 0.2, Theme.Motion.Bounce)
		end
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) then
			down = true
			apply()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			down = false
			apply()
		end
	end)
	button.MouseEnter:Connect(function()
		hover = true
		apply()
	end)
	button.MouseLeave:Connect(function()
		hover, down = false, false
		apply()
	end)
	button.Activated:Connect(function()
		audio = audio or require(script.Parent.Parent:WaitForChild("Audio"))
		audio.PlayUI("Click")
	end)
end

-- Reduced motion: Roblox's own setting or the game's Settings toggle (settings.reduceMotion = "On") stops the loops
-- (pulses); one-off moves (a window opening) still play.
function Theme.ReducedMotion(): boolean
	if game:GetService("GuiService").ReducedMotionEnabled then return true end
	local ok, data = pcall(function()
		local clientData = require(script.Parent.Parent:WaitForChild("ClientData"))
		return clientData.IsLoaded() and clientData.Get() or nil
	end)
	return ok and type(data) == "table" and data.settings and data.settings.reduceMotion == "On" or false
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
--   panel       graphite gradient, 14px, top hairline, soft dark edge   hud_box  the same over the world
--   card        #232023 -> #141215, 11px, top highlight, darker lip     well     near-black inset (bar tracks, prices)
--   card_selected / card_gold  a card with a 2.5px gold border + a soft gold glow outside it
--   chip / pill    dark round pill (top bar)                           banner_gold  dark gold banner
-- The hairline and the glow live in a "Depth" Folder inside the gui (list / grid layouts ignore a Folder's children).
------------------------------------------------------------------------
local function sequence(points)
	local keys = {}
	for _, p in ipairs(points) do table.insert(keys, ColorSequenceKeypoint.new(p[1], Color3.fromHex(p[2]))) end
	return ColorSequence.new(keys)
end
local PANEL_SHEEN = sequence({ { 0, "#252226" }, { 0.5, "#18161A" }, { 1, "#0D0C0E" } })
local CARD_SHEEN = sequence({ { 0, "#232023" }, { 0.9, "#141215" }, { 0.905, "#0E0C0F" }, { 1, "#0E0C0F" } })
local PILL_SHEEN = sequence({ { 0, "#211E22" }, { 1, "#121013" } })
Theme.Surfaces = {
	panel = { sheen = PANEL_SHEEN, alpha = Theme.Alpha.Panel, corner = 14, outline = 2, outlineColor = Theme.Colors.Outline, outlineAlpha = 0.35, hairline = Theme.Alpha.Hairline,
		hex = 0.95 },
	hud_box = { sheen = PANEL_SHEEN, alpha = Theme.Alpha.HudCard, corner = 12, outline = 2, outlineColor = Theme.Colors.Outline, outlineAlpha = 0.35, hairline = Theme.Alpha.Hairline,
		hex = 0.95, goldLine = 0.3 }, -- (prompt 40: the HUD cards, mockup 05: hex mesh + a gold inner line; owner 22 Oct: quiet mesh)
	card = { sheen = CARD_SHEEN, alpha = 0, corner = 11, outline = 1.5, outlineColor = Theme.Colors.Outline, outlineAlpha = 0.3, hairline = 0.88, hex = 0.95 },
	card_selected = { sheen = CARD_SHEEN, alpha = 0, corner = 11, outline = 2.5, outlineColor = Theme.Colors.Gold, outlineAlpha = 0, hairline = 0.88, glow = 0.72 },
	card_gold = { sheen = CARD_SHEEN, alpha = 0, corner = 11, outline = 2.5, outlineColor = Theme.Colors.Gold, outlineAlpha = 0, hairline = 0.88, glow = 0.6 },
	well = { color = Theme.Colors.Well, alpha = 0, corner = 8, outline = 1.5, outlineColor = Theme.Colors.Outline, outlineAlpha = 0.2 },
	chip = { sheen = PILL_SHEEN, alpha = Theme.Alpha.Pill, corner = 999, outline = 1.5, outlineColor = Theme.Colors.Outline, outlineAlpha = 0.3, hairline = 0.86 },
	pill = { sheen = PILL_SHEEN, alpha = Theme.Alpha.Pill, corner = 999, outline = 1.5, outlineColor = Theme.Colors.Outline, outlineAlpha = 0.3, hairline = 0.86 },
	panel_header = { color = Theme.Colors.Panel, alpha = 1, corner = 14, outline = 0 },
	banner_gold = { color = Color3.fromHex("#2A1F0A"), alpha = 0.05, corner = 12, outline = 2.5, outlineColor = Theme.Colors.Gold, outlineAlpha = 0, hairline = 0.85, glow = 0.7 },
}

local function outlineOf(gui)
	local stroke = gui:FindFirstChild("Border")
	if not stroke then
		stroke = Theme.New("UIStroke", { Name = "Border", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = gui })
	end
	return stroke
end

-- The Depth folder's layers (hairline, glow ring, top gloss, shine) are laid out by the gui's UIPadding like any child (a
-- Folder doesn't stop padding), which pushed them off-centre on padded buttons (owner's bug, 14 Oct: a ghost ring above
-- the button). fitLayer undoes the padding: every layer is placed on the gui itself (centred, AnchorPoint 0.5), sized
-- from the gui's full size. Layer attributes: FitExtra = px added to both sizes (ring +6, inner -4), FitTop = share of
-- the height from the top (gloss, shine), FitInset = the hairline's side inset.
local function padOf(gui)
	local pad = gui:FindFirstChildOfClass("UIPadding")
	if not pad then return 0, 0, 0, 0 end
	return pad.PaddingLeft.Offset, pad.PaddingRight.Offset, pad.PaddingTop.Offset, pad.PaddingBottom.Offset
end
local function fitLayer(gui, layer)
	local l, r, t, b = padOf(gui)
	local cx, cy = (r - l) / 2, (b - t) / 2 -- the gui's own centre, from the padded box's centre
	local inset = layer:GetAttribute("FitInset")
	if inset then -- the 1px top line
		layer.AnchorPoint = Vector2.new(0.5, 0)
		layer.Position = UDim2.new(0.5, cx, 0, 1 - t)
		layer.Size = UDim2.new(1, l + r - inset * 2, 0, 1)
		return
	end
	local extra = layer:GetAttribute("FitExtra") or 0
	local top = layer:GetAttribute("FitTop")
	if top then -- a band from the top edge (a share of the gui's height), `extra` / 2 in from the edges
		layer.AnchorPoint = Vector2.new(0.5, 0)
		layer.Position = UDim2.new(0.5, cx, 0, -t - extra / 2)
		layer.Size = UDim2.new(1, l + r + extra, top, (t + b) * top)
		return
	end
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.Position = UDim2.new(0.5, cx, 0.5, cy)
	layer.Size = UDim2.new(1, l + r + extra, 1, t + b + extra)
end
local function fitLayers(gui)
	local depth = gui:FindFirstChild("Depth")
	if not depth then return end
	for _, layer in ipairs(depth:GetChildren()) do
		if layer:IsA("GuiObject") and (layer:GetAttribute("FitExtra") or layer:GetAttribute("FitTop") or layer:GetAttribute("FitInset")) then
			fitLayer(gui, layer)
		end
	end
end
Theme.FitLayers = fitLayers

local function depthOf(gui)
	local depth = gui:FindFirstChild("Depth")
	if depth then return depth end
	depth = Theme.New("Folder", { Name = "Depth", Parent = gui })
	-- (padding added or changed later moves the layers back onto the gui)
	local function watch(pad)
		if pad:IsA("UIPadding") then
			task.defer(fitLayers, gui)
			pad.Changed:Connect(function() fitLayers(gui) end)
		end
	end
	for _, child in ipairs(gui:GetChildren()) do watch(child) end
	gui.ChildAdded:Connect(watch)
	return depth
end

-- the 1px light line along the top edge (inset past the corners)
local function setHairline(gui, alpha: number?, corner: number)
	local depth = depthOf(gui)
	local line = depth:FindFirstChild("Hairline")
	if not alpha then
		if line then line.Visible = false end
		return
	end
	if not line then
		line = Theme.New("Frame", { Name = "Hairline", BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = gui.ZIndex, Parent = depth })
	end
	line:SetAttribute("FitInset", math.max(4, math.floor(corner * 0.8)))
	fitLayer(gui, line)
	line.BackgroundTransparency = alpha
	line.Visible = true
end

-- a soft colored glow just outside the border (a see-through frame with its own stroke, so it never covers the content)
local function setGlow(gui, color: Color3?, alpha: number?, corner: number)
	local depth = depthOf(gui)
	local glow = depth:FindFirstChild("Glow")
	if not color then
		if glow then glow.Visible = false end
		return
	end
	if not glow then
		glow = Theme.New("Frame", { Name = "Glow", BackgroundTransparency = 1, ZIndex = gui.ZIndex, Parent = depth }, {
			Theme.New("UICorner", { Name = "Corner" }),
			Theme.New("UIStroke", { Name = "Stroke", Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
	end
	-- the ring just outside the border: 3 px each side, the corner 3 px rounder so the curves stay parallel
	glow:SetAttribute("FitExtra", 6)
	fitLayer(gui, glow)
	glow.Corner.CornerRadius = UDim.new(0, corner + 3)
	glow.Stroke.Color = color
	glow.Stroke.Transparency = alpha or 0.7
	glow.Visible = true
end
Theme.SetGlow = setGlow

-- (prompt 40 / 44) the hex mesh inside a gui: nil alpha = none, else shown at Theme.HexAlpha (a number above 0.9 = a
-- quieter one); color tints it (white by default); big = the panel size
function Theme.SetHex(gui, alpha: number?, radius: number, color: Color3?, big: boolean?)
	local depth = depthOf(gui)
	local hex = depth:FindFirstChild("Hex")
	if alpha and not hex then
		hex = Theme.New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = Theme.HexImage, ScaleType = Enum.ScaleType.Tile,
			TileSize = Theme.HexTile, ZIndex = gui.ZIndex, Parent = depth }, { Theme.New("UICorner", { Name = "Corner" }) })
		hex:SetAttribute("FitExtra", -2)
		fitLayer(gui, hex)
	end
	if hex then
		hex.Visible = alpha ~= nil
		-- (owner, 22 Oct) full strength only on collectible tiles (alpha 0.9 or less); panels, cards and HUD boxes ~9%
		hex.ImageTransparency = if alpha == nil then 1 elseif big or alpha > 0.9 then Theme.HexQuiet else Theme.HexAlpha
		hex.ImageColor3 = color or Color3.new(1, 1, 1)
		hex.TileSize = if big then Theme.HexTileBig else Theme.HexTile
		hex.Corner.CornerRadius = UDim.new(0, math.max(radius - 1, 0))
	end
end

function Theme.SetPiece(gui, name)
	local surface = Theme.Surfaces[name] or Theme.Surfaces.card
	local sheen = gui:FindFirstChild("Sheen")
	if surface.sheen then
		gui.BackgroundColor3 = Color3.new(1, 1, 1)
		sheen = sheen or Theme.New("UIGradient", { Name = "Sheen", Rotation = 90, Parent = gui })
		sheen.Color = surface.sheen
		sheen.Enabled = true
	else
		gui.BackgroundColor3 = surface.color
		if sheen then sheen.Enabled = false end
	end
	gui.BackgroundTransparency = surface.alpha
	if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then gui.Image = "" end
	local corner = gui:FindFirstChildOfClass("UICorner") or Theme.New("UICorner", { Parent = gui })
	corner.CornerRadius = surface.corner >= 999 and UDim.new(1, 0) or UDim.new(0, surface.corner)
	local stroke = outlineOf(gui)
	stroke.Color = surface.outlineColor or Theme.Colors.Outline
	stroke.Thickness = surface.outline
	stroke.Transparency = surface.outlineAlpha or 0
	stroke.Enabled = surface.outline > 0
	local radius = surface.corner >= 999 and 12 or surface.corner
	setHairline(gui, surface.hairline, radius)
	setGlow(gui, surface.glow and Theme.Colors.Gold or nil, surface.glow, radius)
	-- (prompt 40) the hex mesh and the gold inner line (mockups 05 / 06)
	local depth = depthOf(gui)
	Theme.SetHex(gui, surface.hex, radius, nil, name == "panel")
	local inner = depth:FindFirstChild("GoldLine")
	if surface.goldLine and not inner then
		inner = Theme.New("Frame", { Name = "GoldLine", BackgroundTransparency = 1, ZIndex = gui.ZIndex, Parent = depth }, {
			Theme.New("UICorner", { Name = "Corner" }),
			Theme.New("UIStroke", { Name = "Stroke", Color = Theme.Colors.Gold, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		inner:SetAttribute("FitExtra", -6)
		fitLayer(gui, inner)
	end
	if inner then
		inner.Visible = surface.goldLine ~= nil
		inner.Stroke.Transparency = surface.goldLine or 1
		inner.Corner.CornerRadius = UDim.new(0, math.max(radius - 3, 0))
	end
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
-- Buttons. CTA ("Red" / "Primary" / "Main", "Gold" / "Green"): a bevelled gradient, a glossy top lip (white on the top
-- 44%), a darker bottom lip, a soft colored glow and a diagonal shine streak. Quiet (every other style): dark with a
-- top highlight. "Flat": an inactive tab (no bevel, no glow, gray text). "Disabled": flat with faint text.
-- Labels: the display font, UPPERCASE; dark ink on gold, white on red / quiet. Theme.SetButtonStyle switches it.
------------------------------------------------------------------------
Theme.ButtonText = { Gold = Theme.Colors.Ink, Green = Theme.Colors.Ink, Flat = Theme.Colors.Muted, Disabled = Theme.Colors.Faint }
Theme.LipHeight = 0.18 -- share of the button's height that is the darker bottom lip (prompt 40: the ChunkyButton's thick edge)

local function lookOf(style)
	return Theme.ButtonGradients[style] or "Quiet"
end

local function gradientFor(style)
	local look = lookOf(style)
	if look == "Gold" then
		local edge = 1 - Theme.LipHeight
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF3C4")),
			ColorSequenceKeypoint.new(0.3, Color3.fromHex("#F6C75A")),
			ColorSequenceKeypoint.new(edge - 0.001, Color3.fromHex("#D69B22")),
			ColorSequenceKeypoint.new(edge, Color3.fromHex("#8A5A06")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#8A5A06")),
		})
	end
	local g = Theme.Gradients[look]
	local top, bottom = g[1], g[2]
	if look == "Flat" or look == "Disabled" then return ColorSequence.new(top) end
	local lip = bottom:Lerp(Color3.new(0, 0, 0), 0.5)
	local edge = 1 - Theme.LipHeight
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(edge - 0.001, bottom),
		ColorSequenceKeypoint.new(edge, lip),
		ColorSequenceKeypoint.new(1, lip),
	})
end

-- the glossy top lip and the shine streak (CTAs only), in the button's Depth folder
local function ctaLayers(button, on: boolean)
	local depth = depthOf(button)
	local gloss = depth:FindFirstChild("TopGloss")
	local streak = depth:FindFirstChild("Streak")
	if on and not gloss then
		gloss = Theme.New("Frame", { Name = "TopGloss", BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = button.ZIndex, Parent = depth }, {
			Theme.New("UICorner", { CornerRadius = Theme.Corner.Button }),
			Theme.New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.93) }) }),
		})
		streak = Theme.New("Frame", { Name = "Streak", BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = button.ZIndex, Parent = depth }, {
			Theme.New("UICorner", { CornerRadius = Theme.Corner.Button }),
			Theme.New("UIGradient", { Name = "Band", Rotation = 25, Offset = Vector2.new(-0.28, 0), Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.45, 0.78),
				NumberSequenceKeypoint.new(0.52, 0.78), NumberSequenceKeypoint.new(0.57, 1), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		-- inside the button: the gloss on the top 44% and the shine above the lip, 2 px in from the border
		gloss:SetAttribute("FitTop", 0.44)
		gloss:SetAttribute("FitExtra", -4)
		streak:SetAttribute("FitTop", 1 - Theme.LipHeight)
		streak:SetAttribute("FitExtra", -4)
		fitLayer(button, gloss)
		fitLayer(button, streak)
	end
	if gloss then gloss.Visible = on end
	if streak then streak.Visible = on end
end

function Theme.SetButtonStyle(button, style)
	button:SetAttribute("Style", style)
	local look = lookOf(style)
	local cta = (look == "Red" or look == "Gold" or look == "Green") and style ~= "Tab"
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0
	if button:IsA("ImageButton") or button:IsA("ImageLabel") then button.Image = "" end
	local gradient = button:FindFirstChild("Gloss") or Theme.New("UIGradient", { Name = "Gloss", Rotation = 90, Parent = button })
	gradient.Color = gradientFor(style)
	local corner = button:FindFirstChildOfClass("UICorner") or Theme.New("UICorner", { Parent = button })
	corner.CornerRadius = Theme.Corner.Button
	local stroke = outlineOf(button)
	if cta then
		-- (prompt 40, the ChunkyButton) a 3 px near-black outline; the soft glow in its colour only on a screen's main
		-- button (attribute "Glow" = true; the pulsing CTAs set it)
		stroke.Color, stroke.Thickness, stroke.Transparency, stroke.Enabled = Theme.Colors.Outline, 3, 0, true
		setGlow(button, if button:GetAttribute("Glow") == true then Theme.CTA[look] else nil, 0.55, 10)
	elseif look == "Flat" or look == "Disabled" then
		stroke.Enabled = false
		setGlow(button, nil, nil, 10)
	elseif style == "Tab" then
		stroke.Color, stroke.Thickness, stroke.Transparency, stroke.Enabled = Theme.Colors.Outline, 1.5, 0.2, true
		setGlow(button, nil, nil, 10)
	else
		-- (prompt 40) Dark: graphite with a grey outline
		stroke.Color, stroke.Thickness, stroke.Transparency, stroke.Enabled = Color3.fromHex("#4E4A52"), 2, 0.1, true
		setGlow(button, nil, nil, 10)
	end
	setHairline(button, (look == "Quiet") and 0.8 or nil, 10)
	-- (owner, 22 Oct) no mesh on any button; a dark button is solid graphite with its outline, bottom edge and a thin gold inner line
	Theme.SetHex(button, nil, 10)
	local gold = depthOf(button):FindFirstChild("GoldLine")
	local wantGold = look == "Quiet" and style ~= "Tab" and not button:GetAttribute("TabButton")
	if wantGold and not gold then
		gold = Theme.New("Frame", { Name = "GoldLine", BackgroundTransparency = 1, ZIndex = button.ZIndex, Parent = depthOf(button) }, {
			Theme.New("UICorner", { Name = "Corner", CornerRadius = UDim.new(0, 8) }),
			Theme.New("UIStroke", { Name = "Stroke", Color = Theme.Colors.Gold, Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		gold:SetAttribute("FitExtra", -5)
		fitLayer(button, gold)
	end
	if gold then gold.Visible = wantGold end
	ctaLayers(button, cta)
	local color = Theme.ButtonText[style] or Theme.ButtonText[look] or Theme.Colors.Text
	if style == "Tab" then color = Theme.Colors.Ink end
	-- (prompt 40) a ChunkyButton's words: LuckiestGuy, white, a dark stroke (tabs keep the italic font: TabButton)
	local chunky = not button:GetAttribute("TabButton") and look ~= "Flat"
	if chunky then color = if look == "Disabled" then Theme.Colors.Faint else Theme.Colors.Text end
	for _, item in ipairs(button:GetDescendants()) do
		if item:IsA("TextLabel") and not item:GetAttribute("KeepColor") then
			item.TextColor3 = color
			item.TextYAlignment = Enum.TextYAlignment.Center -- (centred in the button's padded box, above the lip)
			local display = item.FontFace.Family == Theme.Fonts.Display.Family and item.FontFace.Weight == Theme.Fonts.Display.Weight
			if chunky and (display or item.FontFace.Family == UIFonts.Chunky.Family) and not item:GetAttribute("KeepFont") then
				item.FontFace = UIFonts.Chunky
				local outline = Theme.TextShadow(item)
				outline.Color = Theme.Colors.Outline
				outline.Transparency = 0
				outline.Thickness = math.max(1.5, item.TextSize / 11)
			else
				local outline = item:FindFirstChild("TextStroke")
				if outline then outline.Transparency = (look == "Gold") and 1 or Theme.Alpha.TextShadow end
			end
		end
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
	-- content passed in as children goes back on top of the gloss / shine layers
	for _, child in ipairs(children or {}) do
		if child:IsA("GuiObject") then
			child.Parent = nil
			child.Parent = button
		end
	end
	Theme.BindPress(button)
	return button
end

-- The shine streak sweeps across a CTA once (windows call it for their CTAs on open).
function Theme.Shine(button, delay: number?)
	local depth = button:FindFirstChild("Depth")
	local streak = depth and depth:FindFirstChild("Streak")
	local band = streak and streak:FindFirstChild("Band")
	if not band or not streak.Visible then return end
	task.delay(delay or 0, function()
		band.Offset = Vector2.new(-1, 0)
		local tween = TweenService:Create(band, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Offset = Vector2.new(1, 0) })
		tween:Play()
		tween.Completed:Connect(function()
			band.Offset = Vector2.new(-1, 0)
			TweenService:Create(band, TweenInfo.new(0.4), { Offset = Vector2.new(-0.28, 0) }):Play()
		end)
	end)
end

-- Every CTA inside `root` shines once, one after another.
function Theme.ShineAll(root)
	local n = 0
	for _, item in ipairs(root:GetDescendants()) do
		if item.Name == "Streak" and item:IsA("Frame") and item.Parent and item.Parent.Name == "Depth" then
			Theme.Shine(item.Parent.Parent, 0.12 + n * 0.08)
			n += 1
		end
	end
end

-- A featured CTA pulses: scale 1 -> 1.03 and its glow a little brighter, every 1.6 s, while `alive()` says so (default:
-- while it's in the game). Reduced motion stops it. Only the ONE main CTA of a screen pulses (KEEP, BUY, PLAY, a bonus
-- CLAIM), never tabs, EQUIP buttons, opponent cards or anything with many copies (owner, 14 Oct).
function Theme.Pulse(button, alive: (() -> boolean)?)
	if button:GetAttribute("Pulsing") then return end
	button:SetAttribute("Pulsing", true)
	-- (prompt 40) the pulsing button is the screen's main one: it gets the soft glow in its colour
	if button:GetAttribute("Glow") ~= true and button:GetAttribute("Style") then
		button:SetAttribute("Glow", true)
		Theme.SetButtonStyle(button, button:GetAttribute("Style"))
	end
	local pulse = Theme.ButtonScale(button).pulse
	task.spawn(function()
		while button.Parent and (not alive or alive()) do
			if not Theme.ReducedMotion() and button.Visible then
				-- (the ring is centred on the button, so it grows from the centre with the button's one UIScale)
				local glow = button:FindFirstChild("Depth") and button.Depth:FindFirstChild("Glow")
				Theme.Tween(pulse, { Value = 1.03 }, 0.5, Enum.EasingStyle.Sine)
				if glow and glow.Visible then Theme.Tween(glow.Stroke, { Transparency = 0.3 }, 0.5, Enum.EasingStyle.Sine) end
				task.wait(0.5)
				Theme.Tween(pulse, { Value = 1 }, 0.6, Enum.EasingStyle.Sine)
				if glow and glow.Visible then Theme.Tween(glow.Stroke, { Transparency = 0.55 }, 0.6, Enum.EasingStyle.Sine) end
				task.wait(1.1)
			else
				pulse.Value = 1
				task.wait(1)
			end
		end
		pulse.Value = 1
		button:SetAttribute("Pulsing", nil)
	end)
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
