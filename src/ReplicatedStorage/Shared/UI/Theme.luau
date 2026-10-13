-- GYM ARC design system (owner's UI redesign, 13 Oct; GYM_ARC_UI_redesign.md + the mockups): dark warm panels built
-- from 9-slice image pieces (Shared.UI.Pieces, Config/UI), red primary buttons, Oswald (titles, buttons, tabs, numbers;
-- UPPERCASE) + Montserrat (body). Color means something: red = primary / main muscle, gold = coins / big moments,
-- green = done / claim, blue / purple = tags; plates, grades and rarity keep the bumper colors. Every UI reads its look
-- from here and from Shared.UI.Kit (the components).
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Background = Color3.fromHex("#0F0C0E"), -- modal backdrops, deep wells
	Panel = Color3.fromHex("#141113"),      -- panels (the panel piece; use Theme.Alpha.Panel for plain frames)
	Card = Color3.fromHex("#1D191B"),       -- cards inside panels
	Well = Color3.fromHex("#0F0C0E"),       -- deep wells: bar tracks, the tab strip
	Secondary = Color3.fromHex("#2B2427"),  -- secondary buttons
	Disabled = Color3.fromHex("#1F1B1D"),
	TabActive = Color3.fromHex("#2C2528"),
	HeaderTop = Color3.fromHex("#1F1A1C"),  -- the panel header's subtle gradient
	HeaderBottom = Color3.fromHex("#181416"),
	Border = Color3.fromHex("#FFFFFF"),     -- 1px borders (use Theme.Alpha.Border / BorderSoft)
	Text = Color3.fromHex("#F6F3F3"),       -- main text
	Muted = Color3.fromHex("#9D9396"),      -- secondary text
	Faint = Color3.fromHex("#6F6669"),      -- faint text, locked items
	Chalk = Color3.fromHex("#F6F3F3"),      -- light fills (icons, bar segments)
	Ink = Color3.fromHex("#141113"),        -- dark text on light fills
	Shadow = Color3.fromHex("#000000"),
	Red = Color3.fromHex("#E4262F"),        -- primary
	RedTint = Color3.fromHex("#3A1013"),    -- tag / icon tile backgrounds
	Gold = Color3.fromHex("#F5B62F"),       -- coins, PUMP, big moments (NEW PR, BIG REP)
	Green = Color3.fromHex("#36C26B"),      -- claim, done, auto on, quest bars
	Blue = Color3.fromHex("#3F8CFF"),
	Purple = Color3.fromHex("#9A5CFF"),
	NeedsWork = Color3.fromHex("#FF8A8A"),  -- soft light red: "needs work", very low stamina
	StatNumber = Color3.fromHex("#DCEEFF"), -- light blue-white: the numbers on the world stats labels
}

-- Transparency levels (0 = solid, 1 = invisible)
Theme.Alpha = {
	Panel = 0.06,         -- panels (#141113 at 6%)
	LabelBacking = 0.6,   -- the faint box behind world labels
	Border = 0.87,        -- strong 1px white border
	BorderSoft = 0.93,    -- soft 1px white border
	ButtonBorder = 0.87,
	Primary = 1,          -- (buttons are image pieces now: their own frame stays invisible)
	TextShadow = 0.6,     -- subtle dark stroke behind text over the world
	Backdrop = 0.38,      -- black behind a modal
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

-- The UI fonts live in UIFonts (Oswald for titles / numbers / buttons, Montserrat for body text).
-- The weight names stay so every screen keeps working: Regular = body text, Light / Medium = Oswald numbers, the rest =
-- Oswald Bold, Strong = Montserrat Bold.
local UIFonts = require(script.Parent:WaitForChild("UIFonts"))
Theme.UIFonts = UIFonts
Theme.Fonts = {
	Light = UIFonts.Number,                                                             -- calm numbers
	Regular = UIFonts.Body,                                                             -- normal text
	SemiBold = UIFonts.Heading,                                                         -- titles, button labels, important numbers
	Bold = UIFonts.Heading,                                                             -- rank tag letters
	Strong = UIFonts.BodyBold,                                                          -- names and item names in body text
}
-- older names, kept so every screen reads the same three weights
Theme.Fonts.Medium = UIFonts.Number -- Oswald SemiBold in sentence case (genetics plate labels)
Theme.Fonts.Heading = Theme.Fonts.SemiBold
Theme.Fonts.Label = Theme.Fonts.Regular
Theme.Fonts.Small = Theme.Fonts.Regular

-- The left menu tiles (owner's UI v7 brief) use a bold rounded display face for their labels, with a dark outline;
-- everything else is Oswald / Nunito.
Theme.TileFont = Font.fromEnum(Enum.Font.FredokaOne)
Theme.TileStroke = Color3.fromHex("#1A1320") -- the dark outline around tile labels
Theme.PillHeight = 44 -- the top-bar pills (44 = the smallest tap target) (coins, quests, daily reward, settings)
-- Tile look (SideMenu): the 3D face fades from white to this gray from top to bottom, the active tile's border is white, and
-- the label is 14px (17px on the bigger PC tiles).
Theme.Tile = {
	ShadeBottom = Color3.fromRGB(140, 140, 150),
	ActiveBorder = Color3.new(1, 1, 1),
	LabelSmall = 14,
	LabelBig = 17,
	BigFrom = 80, -- tiles at least this many px wide use the big label
	LipDarken = 0.66, -- how dark the bottom edge is (0 = the accent, 1 = black)
	FaceDarken = 0.5,
}

-- Named sizes, or a plain number (the redesigned screens use the mockup's px; Theme.ScreenScale scales the whole gui).
Theme.TextSize = {
	Slam = 72,  -- one-off slams of a big moment (the genetics "S!")
	Hero = 56,  -- the GYM ARC title on the menu card (HeroCompact on phones)
	HeroCompact = 38,
	Huge = 40,  -- big numbers
	Display = 42,
	Big = 34,     -- the genetics "Overall" label (the word under it is Hero size)
	Title = 30,
	Large = 22, -- screen titles
	Medium = 18, -- the genetics stat row names
	Popup = 26, -- 3D gain popups
	Body = 16,
	Small = 14,
	Label = 10, -- small section labels ("DAILY QUESTS", "STAMINA") at mockup size
}
Theme.MinTextSize = 10

Theme.Spacing = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }

Theme.Corner = {
	Panel = UDim.new(0, 12),
	Card = UDim.new(0, 10),
	Button = UDim.new(0, 8),
	Tag = UDim.new(0, 5),
	Segment = UDim.new(0, 3),
	Round = UDim.new(1, 0), -- plate discs and icons
}

Theme.Border = { Color = Theme.Colors.Border, Thickness = 1, Transparency = Theme.Alpha.Border }
Theme.IconStroke = 2
Theme.MinTouch = 44 -- px, smallest tappable button on mobile

-- Short screens (phones in landscape, e.g. 667x375) get compact layouts: tighter spacing, 44px buttons, panels that
-- fit the height. In Studio a "TestPhoneLayout" attribute on Workspace forces it, to check phone layouts on a PC.
Theme.CompactHeight = 520
function Theme.IsCompact()
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.Y > 1 and camera.ViewportSize.Y < Theme.CompactHeight then return true end
	return game:GetService("RunService"):IsStudio() and workspace:GetAttribute("TestPhoneLayout") == true
end

-- Calls callback(isCompact) now and again whenever the screen switches between compact and normal (the viewport is
-- often not its final size yet when scripts start, e.g. on phones, and it changes when a window is resized).
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
	PressScale = 0.95,
	PressTime = 0.08,
	Bounce = Enum.EasingStyle.Back, -- pops, rep counter
}

------------------------------------------------------------------------
-- Builders
------------------------------------------------------------------------
-- UIPadding also shrinks the Depth pieces, so they are pushed back out by the padding.
local Pieces -- Shared.UI.Pieces (loaded on first use)
local function pieces()
	Pieces = Pieces or require(script.Parent:WaitForChild("Pieces"))
	return Pieces
end

local function paddingOf(gui)
	local p = gui:FindFirstChildOfClass("UIPadding")
	if not p then return 0, 0, 0, 0 end
	return p.PaddingLeft.Offset, p.PaddingRight.Offset, p.PaddingTop.Offset, p.PaddingBottom.Offset
end

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

-- The part of a full-screen gui (ScreenInsets.None, so its dim backdrop covers the top bar too) below the Roblox top
-- bar. Panels go in here: centred on the whole screen, a short phone screen puts their header under the top bar.
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

-- Thin light border (1px white at 85% transparency by default).
function Theme.Stroke(color, thickness, transparency)
	return Theme.New("UIStroke", {
		Color = color or Theme.Border.Color,
		Thickness = thickness or Theme.Border.Thickness,
		Transparency = transparency or Theme.Border.Transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Subtle dark outline behind text, only where text sits over the 3D world.
function Theme.TextShadow(label, transparency)
	return Theme.New("UIStroke", { Color = Theme.Colors.Shadow, Thickness = 1, Transparency = transparency or Theme.Alpha.TextShadow, Parent = label })
end

function Theme.Pad(space)
	local px = UDim.new(0, Theme.Spacing[space])
	return Theme.New("UIPadding", { PaddingTop = px, PaddingBottom = px, PaddingLeft = px, PaddingRight = px })
end

function Theme.List(direction, space, horizontal, vertical)
	return Theme.New("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, Theme.Spacing[space] or 0),
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

-- Crisp text: a whole-number Theme.TextSize (never below 14), no TextScaled. Normal case.
-- props.TextSize = "Huge" | "Large" | "Popup" | "Body" | "Small"; props.Font = "Light" | "Regular" | "SemiBold".
-- Titles and button labels are UPPERCASE (Oswald text that is a title size, or sits in a button). The text stays upper
-- when a script changes it later. props.Upper = false keeps a label's own case (e.g. a word that should read "Blessed").
local TITLE_SIZES = { Large = true, Huge = true, Hero = true, HeroCompact = true, Slam = true }
local HEADING_FONTS = { SemiBold = true, Bold = true, Heading = true }
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

function Theme.Text(props)
	local sizeKey = props.TextSize or "Body"
	local fontKey = props.Font or "Regular"
	local upper = props.Upper
	props.Font = nil
	props.Upper = nil
	props.BackgroundTransparency = 1
	props.TextScaled = false
	local size = type(sizeKey) == "number" and sizeKey or Theme.TextSize[sizeKey] or Theme.TextSize.Body
	props.TextSize = math.max(Theme.MinTextSize, math.floor(size))
	props.FontFace = Theme.Fonts[fontKey]
	props.TextColor3 = props.TextColor3 or Theme.Colors.Text
	local label = Theme.New("TextLabel", props)
	if upper ~= false and HEADING_FONTS[fontKey] and (TITLE_SIZES[sizeKey] or (label.Parent and label.Parent:IsA("GuiButton"))) then
		Theme.Uppercase(label)
	end
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

-- Pressing a button: image buttons move their content down 2px and lose the edge (the red one swaps to its pressed
-- piece); plain buttons shrink a little instead. A very soft click.
local audio -- Shared.Audio, loaded on first press (client only)
function Theme.BindPress(button)
	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	local down = false
	local function setDown(on)
		if on == down then return end
		down = on
		local piece = button:GetAttribute("Piece")
		if piece then
			local pad = button:FindFirstChildOfClass("UIPadding") or Theme.New("UIPadding", { Parent = button })
			local shift = on and 2 or -2
			pad.PaddingTop = UDim.new(pad.PaddingTop.Scale, pad.PaddingTop.Offset + shift)
			pad.PaddingBottom = UDim.new(pad.PaddingBottom.Scale, pad.PaddingBottom.Offset - shift)
			local depth = button:FindFirstChild("Depth")
			local bg = (button:IsA("ImageButton") or button:IsA("ImageLabel")) and button or (depth and depth:FindFirstChild("Bg"))
			local pressed = Theme.ButtonPressed[piece]
			if bg and pressed then pieces().Apply(bg, on and pressed or piece) end
			if bg and not pressed then bg.ImageColor3 = on and Color3.new(0.85, 0.85, 0.85) or Color3.new(1, 1, 1) end
		else
			local scale = button:FindFirstChildOfClass("UIScale") or Theme.New("UIScale", { Parent = button })
			Theme.Tween(scale, { Scale = on and Theme.Motion.PressScale or 1 }, on and Theme.Motion.PressTime or nil)
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

------------------------------------------------------------------------
-- Depth: a soft drop shadow under panels and buttons. It lives in a "Depth" Folder, which list/grid
-- layouts ignore, so it never disturbs layouts. Built only from frames and strokes (no images).
------------------------------------------------------------------------
Theme.Depth = {
	Shadow = { Offset = 2, Rings = { { 2, 0.86 }, { 5, 0.92 }, { 10, 0.96 } } }, -- ring thickness px, transparency
}


-- kind and cornerKind: "Panel" (default) or "Button" pick the corner radius; extra args are ignored.
function Theme.AddDepth(gui, kind, cornerKind)
	local folder = gui:FindFirstChild("Depth") or Theme.New("Folder", { Name = "Depth", Parent = gui })
	local border = gui:FindFirstChildOfClass("UIStroke")
	local pad = border and math.ceil(border.Thickness) or 0
	local left, right, top, bottom = paddingOf(gui)
	local corner = Theme.Corner[cornerKind or kind or "Panel"] or Theme.Corner.Panel
	for _, ring in ipairs(Theme.Depth.Shadow.Rings) do
		Theme.New("Frame", {
			Name = "Shadow",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, -pad - left, 0, -pad + Theme.Depth.Shadow.Offset - top),
			Size = UDim2.new(1, pad * 2 + left + right, 1, pad * 2 + top + bottom),
			ZIndex = 0,
			Parent = folder,
		}, {
			Theme.New("UICorner", { CornerRadius = corner.Scale > 0 and corner or UDim.new(0, corner.Offset + pad) }),
			Theme.New("UIStroke", { Color = Theme.Colors.Shadow, Thickness = ring[1], Transparency = ring[2], ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, {
				-- lighter along the top edge (light comes from above)
				Theme.New("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.4, 0.2), NumberSequenceKeypoint.new(1, 0) }),
				}),
			}),
		})
	end
	return gui
end

------------------------------------------------------------------------
-- Image pieces behind panels and buttons. They live in the "Depth" Folder (list / grid layouts ignore it), pushed back
-- out by the gui's UIPadding (UIPadding moves them too), kept in step when the padding changes (button presses).
------------------------------------------------------------------------

local function fitBehind(gui, image, grow)
	local function fit()
		local left, right, top, bottom = paddingOf(gui)
		image.Position = UDim2.fromOffset(-left - grow, -top - grow)
		image.Size = UDim2.new(1, left + right + grow * 2, 1, top + bottom + grow * 2)
	end
	local watched = nil
	local function watch()
		local pad = gui:FindFirstChildOfClass("UIPadding")
		if pad and pad ~= watched then
			watched = pad
			for _, prop in ipairs({ "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" }) do
				pad:GetPropertyChangedSignal(prop):Connect(fit)
			end
		end
		fit()
	end
	watch()
	gui.ChildAdded:Connect(function(child) if child:IsA("UIPadding") then task.defer(watch) end end)
end

Theme.PanelShadowGrow = 20 -- the soft shadow behind a panel is this much bigger on every side

-- Shows piece `name` on `gui`: an ImageLabel / ImageButton draws it itself (panels and buttons are those), anything else
-- gets it as a "Bg" image behind its content. `shadow` adds the soft panel shadow (only on a gui that doesn't size
-- itself to its content: a child bigger than an AutomaticSize frame would keep growing it). Returns the image.
function Theme.SetPiece(gui, name, shadow)
	local folder = gui:FindFirstChild("Depth") or Theme.New("Folder", { Name = "Depth", Parent = gui })
	local bg
	if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
		pieces().Apply(gui, name)
		bg = gui
	else
		bg = folder:FindFirstChild("Bg")
		if not bg then
			bg = pieces().Image(name, { Name = "Bg", ZIndex = 0, Parent = folder }) -- (under the content)
			fitBehind(gui, bg, 0)
		else
			pieces().Apply(bg, name)
		end
	end
	if shadow and gui.AutomaticSize == Enum.AutomaticSize.None and not folder:FindFirstChild("PanelShadow") then
		local s = pieces().Image("panel_shadow", { Name = "PanelShadow", ZIndex = -1, Parent = folder })
		fitBehind(gui, s, Theme.PanelShadowGrow)
	end
	gui:SetAttribute("Piece", name)
	return bg
end

-- A hidden 1px border every panel and button keeps, so a script can still light it up (a selected card, a warning).
-- (No UICorner on the image panels: the pieces have their own rounded corners, and a UICorner on a sliced image draws
-- dark blobs past its corners.)
local function hookStroke(gui, corner)
	if not gui:FindFirstChildOfClass("UIStroke") then
		Theme.New("UIStroke", { Name = "Border", Color = Theme.Colors.Border, Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = gui })
	end
	if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
		local c = gui:FindFirstChildOfClass("UICorner")
		if c then c:Destroy() end
		return
	end
	local c = gui:FindFirstChildOfClass("UICorner") or Theme.New("UICorner", { Parent = gui })
	c.CornerRadius = corner
end

-- Panel: the panel piece (dark, 12px corners, thin border) with its soft shadow. props.Piece picks another piece ("card",
-- "hud_box", "well", "chip" ...); props.Shadow = false leaves the shadow out (default: only the "panel" piece has one).
function Theme.Panel(props, children)
	local piece = props.Piece or "panel"
	local shadow = props.Shadow
	if shadow == nil then shadow = piece == "panel" end
	local clickable = props.Clickable -- a panel you can tap (an ImageButton; use its Activated)
	props.Piece, props.Shadow, props.Clickable = nil, nil, nil
	props.BackgroundTransparency = 1
	if clickable then props.AutoButtonColor = false end
	local panel = Theme.New(clickable and "ImageButton" or "ImageLabel", props, children) -- (draws its own piece: see SetPiece)
	hookStroke(panel, piece == "panel" and Theme.Corner.Panel or Theme.Corner.Card)
	Theme.SetPiece(panel, piece, shadow)
	return panel
end

-- Buttons: image pieces with a darker bottom edge so they feel pressable. Styles: "Primary" (red; also "Main"),
-- "Secondary" (dark), "Gold", "Green", "Disabled", "White" (tint the piece). Press = the content moves down 2px and the
-- edge goes (the red one swaps to its pressed piece). Theme.SetButtonStyle(button, style) switches it later.
Theme.ButtonPieces = {
	Primary = "btn_red", Main = "btn_red", Secondary = "btn_dark", Gold = "btn_gold", Green = "btn_green",
	Disabled = "btn_disabled", White = "btn_white_tint",
}
Theme.ButtonPressed = { btn_red = "btn_red_pressed" }
Theme.ButtonText = { Gold = Theme.Colors.Ink, Disabled = Theme.Colors.Muted }

function Theme.SetButtonStyle(button, style)
	button:SetAttribute("Style", style)
	Theme.SetPiece(button, Theme.ButtonPieces[style] or Theme.ButtonPieces.Secondary, false)
	local color = Theme.ButtonText[style] or Theme.Colors.Text
	for _, item in ipairs(button:GetDescendants()) do
		if item:IsA("TextLabel") and not item:GetAttribute("KeepColor") then item.TextColor3 = color end
		if item:IsA("ImageLabel") and item.Name == "Icon" and not item:GetAttribute("KeepColor") then item.ImageColor3 = color end
	end
end

function Theme.Button(style, props, children)
	props.Text = nil
	props.AutoButtonColor = false
	props.BackgroundTransparency = 1
	local button = Theme.New("ImageButton", props, children) -- (draws its own piece: see SetPiece)
	-- button labels are UPPERCASE Oswald (labels passed in as children, or added later)
	local function upperLabel(item)
		if item:IsA("TextLabel") and item.FontFace == Theme.Fonts.SemiBold then Theme.Uppercase(item) end
	end
	for _, item in ipairs(button:GetDescendants()) do upperLabel(item) end
	button.DescendantAdded:Connect(function(item) task.defer(upperLabel, item) end)
	hookStroke(button, Theme.Corner.Button)
	Theme.SetButtonStyle(button, style)
	Theme.BindPress(button)
	return button
end

-- Bumper plate disc (circle with darker rim), e.g. for grades and rarity.
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
