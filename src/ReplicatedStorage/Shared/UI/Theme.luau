-- GYM ARC design system: "clean minimal". Dark see-through panels, thin light borders, Oswald (headings, numbers,
-- buttons; UPPERCASE titles and buttons) + Nunito (body) in white and gray. Color is only used for bumper plates, grades and rarity. Every UI reads its look from here.
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Background = Color3.fromHex("#0E0E10"), -- dim backdrops
	Panel = Color3.fromHex("#0E0E10"),      -- see-through panels and label backings (use Theme.Alpha.Panel)
	Border = Color3.fromHex("#FFFFFF"),     -- thin borders (use Theme.Alpha.Border)
	Text = Color3.fromHex("#FFFFFF"),       -- main text
	Muted = Color3.fromHex("#B8B8BE"),      -- secondary text
	Chalk = Color3.fromHex("#FFFFFF"),      -- light fills (bar segments, icons); same as Text
	Ink = Color3.fromHex("#0E0E10"),        -- dark text, only on light plate discs
	Shadow = Color3.fromHex("#000000"),
	NeedsWork = Color3.fromHex("#FF8A8A"),  -- soft light red: "needs work", very low stamina
	Gold = Color3.fromHex("#F2C14E"),       -- big moments only: BIG REP, NEW PR, PUMPED, maxed outline
	StatNumber = Color3.fromHex("#DCEEFF"), -- light blue-white: the numbers on the world stats labels
}

-- Transparency levels (0 = solid, 1 = invisible)
Theme.Alpha = {
	Panel = 0.55,         -- panels and label backings
	LabelBacking = 0.6,   -- the faint box behind world labels
	Border = 0.85,        -- 1px white panel border
	ButtonBorder = 0.7,   -- thin light border on buttons
	Primary = 0.85,       -- primary button fill (white)
	TextShadow = 0.6,     -- subtle dark stroke behind text over the world
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

-- The UI fonts live in UIFonts (Oswald for headings / numbers / buttons, Nunito for body text); never Montserrat or Gotham.
-- The weight names stay so every screen keeps working: Regular = body text, the rest = Oswald.
local UIFonts = require(script.Parent:WaitForChild("UIFonts"))
Theme.UIFonts = UIFonts
Theme.Fonts = {
	Light = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular), -- big calm numbers
	Regular = UIFonts.Body,                                                             -- normal text
	SemiBold = UIFonts.Heading,                                                         -- titles, button labels, important numbers
	Bold = UIFonts.Heading,                                                             -- rank tag letters
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
}

Theme.Spacing = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }

Theme.Corner = {
	Panel = UDim.new(0, 10),
	Button = UDim.new(0, 10),
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
	props.TextSize = math.max(Theme.TextSize.Small, math.floor(Theme.TextSize[sizeKey]))
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

-- Buttons shrink to PressScale while held and spring back, with a very soft click.
local audio -- Shared.Audio, loaded on first press (client only)
function Theme.BindPress(button)
	local scale = button:FindFirstChildOfClass("UIScale") or Theme.New("UIScale", { Parent = button })
	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) then Theme.Tween(scale, { Scale = Theme.Motion.PressScale }, Theme.Motion.PressTime) end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then Theme.Tween(scale, { Scale = 1 }) end
	end)
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

-- UIPadding also shrinks the Depth pieces, so they are pushed back out by the padding.
local function paddingOf(gui)
	local p = gui:FindFirstChildOfClass("UIPadding")
	if not p then return 0, 0, 0, 0 end
	return p.PaddingLeft.Offset, p.PaddingRight.Offset, p.PaddingTop.Offset, p.PaddingBottom.Offset
end

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

-- See-through dark panel: #0E0E10 at 55%, 10px corners, 1px faint white border, soft shadow.
function Theme.Panel(props, children)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or Theme.Alpha.Panel
	local panel = Theme.New("Frame", props, children)
	if not panel:FindFirstChildOfClass("UICorner") then Theme.Round("Panel").Parent = panel end
	if not panel:FindFirstChildOfClass("UIStroke") then Theme.Stroke().Parent = panel end
	return Theme.AddDepth(panel, "Panel")
end

-- Buttons: dark see-through rounded rectangles with a thin light border and white text.
-- "Primary" (also "Main") is a little brighter: white fill at 85% transparency.
function Theme.Button(style, props, children)
	props.Text = ""
	props.AutoButtonColor = false
	local primary = style == "Primary" or style == "Main"
	props.BackgroundColor3 = primary and Theme.Colors.Text or Theme.Colors.Panel
	props.BackgroundTransparency = primary and Theme.Alpha.Primary or Theme.Alpha.Panel
	local button = Theme.New("TextButton", props, children)
	-- button labels are UPPERCASE Oswald (labels passed in as children, or added later)
	local function upperLabel(item)
		if item:IsA("TextLabel") and item.FontFace == Theme.Fonts.SemiBold then Theme.Uppercase(item) end
	end
	for _, item in ipairs(button:GetDescendants()) do upperLabel(item) end
	button.DescendantAdded:Connect(function(item) task.defer(upperLabel, item) end)
	Theme.Round("Button").Parent = button
	Theme.Stroke(Theme.Colors.Border, 1, primary and 0.6 or Theme.Alpha.ButtonBorder).Parent = button
	Theme.BindPress(button)
	Theme.AddDepth(button, "Button")
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
