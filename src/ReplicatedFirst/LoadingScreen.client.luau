-- LoadingScreen: replaces Roblox's default loading screen from the very first frame (owner's final kit "BLACK + GOLD",
-- mockup gym_arc_ui_final/00_loading; owner, 15 Oct: new art). The menu's art (UI.MenuArt) fills the screen, pinned to
-- the right edge so the character on the right always shows whole (a narrow screen crops the empty left side), with a dark
-- gradient over the left 40%; the 3D logo (UI.Logo3D) top left with a soft red glow, "Everyone starts tiny." under it;
-- along the bottom left (never over the character): a rotating tip in a dark graphite tile with a small gold TIP tag
-- (Config/UI.LoadingTips), the step ("LOADING PLAYERS", heavy italic) with the percent in gold, a thick metallic red bar
-- and small page dots under it (gold = the current tip). SKIP (a quiet dark button) shows top right after 5 seconds
-- (straight to the menu). It fades into the menu.
-- Steps (the bar): the game itself (to 30%), "Loading muscles" = ContentProvider:PreloadAsync of the UI images (icons,
-- art, trainer portraits; to 55%), "Loading the gym" = your save data and the world around you (MenuClient's MenuLoad
-- attribute 0..1, to 90%), "Loading players" = the other players' body stage meshes (Shared.BodyStages, to 100%, at most
-- TIMING.Stages seconds). Between steps the bar creeps a little so it never looks stuck.
-- This starts before ReplicatedStorage has replicated, so the kit's colors, fonts, the art / logo ids and a few tips are
-- repeated here (Theme.Colors, UIFonts, UI.MenuArt / UI.Logo3D / UI.SoftGlow); the full tip list is read once it's in.
-- (owner, 26 Oct: "make it look like a gym game's loading screen", more dramatic) The art slowly pushes in, a red light
-- behind the character beats like a heart, embers drift up, and the bar is a barbell: at 25 / 50 / 75 / 100% a bumper
-- plate slams onto its end (white flash, a short shake, a plate clank, the gold percent punches) and the big hype line
-- over the tip changes (WARMING UP, CHALKING UP, LOADING PLATES, GETTING PUMPED, LET'S LIFT!). Sounds: the game's own
-- licensed library picks (Config/AlterThemes MetalClang / ImpactSub).
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
local LOOK = {
	Background = Color3.fromHex("#0C0A0C"),
	Text = Color3.fromHex("#FFFFFF"),
	Muted = Color3.fromHex("#A39A9D"),
	Gold = Color3.fromHex("#F6C75A"),
	Ink = Color3.fromHex("#2A1C05"),
	Outline = Color3.fromHex("#050405"),
	Well = Color3.fromHex("#0A090B"),
	PanelTop = Color3.fromHex("#252226"),
	PanelBottom = Color3.fromHex("#18161A"),
	QuietTop = Color3.fromHex("#2E2A2F"),
	QuietBottom = Color3.fromHex("#1A181B"),
	Dot = Color3.fromHex("#3A363B"),
	Display = Font.new(MONTSERRAT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic), -- UIFonts.Display
	Body = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold),
	Chunky = Font.fromEnum(Enum.Font.LuckiestGuy), -- UIFonts.Chunky (prompt 40: the loading words, mockup real/loading)
	Art = "rbxassetid://124549460345839", -- Config/UI.MenuArt (owner, 15 Oct)
	Logo = "rbxassetid://86034269506160", -- Config/UI.Logo3D
	Glow = "rbxassetid://108461610476976", -- Config/UI.SoftGlow
	Music = "rbxassetid://118959016267248", MusicVolume = 0.7, -- Config/Sounds.MenuMusic (owner, 14 Oct)
}
local GOLD = ColorSequence.new({ -- Theme.GoldSequence
	ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF3C4")),
	ColorSequenceKeypoint.new(0.3, Color3.fromHex("#F6C75A")),
	ColorSequenceKeypoint.new(0.72, Color3.fromHex("#C98A12")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("#F2C45A")),
})
local TIMING = { Skip = 5, Tip = 4.5, Fade = 0.5, Stages = 8, GiveUp = 25, Creep = 0.08, CreepTime = 6, Follow = 4 }
local TIPS = {
	"Spot other players on their lifts to earn coins!",
	"Tap fast while lifting to fill PUMP: pumped reps grow twice as much.",
	"Weak muscles grow fastest. Train the group that needs work.",
}
local BASE = Vector2.new(844, 390) -- the mockups' phone screen (Kit.Base)
local BAR_W = 320 -- (no longer used for the bar: prompt 40 made it full width)

local function new(class, props, children)
	local instance = Instance.new(class)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then (instance :: any)[key] = value end
	end
	for _, child in ipairs(children or {}) do child.Parent = instance end
	if props and props.Parent then instance.Parent = props.Parent end
	return instance
end
local function text(props)
	props.BackgroundTransparency = 1
	props.FontFace = props.FontFace or LOOK.Display
	props.TextColor3 = props.TextColor3 or LOOK.Text
	local label = new("TextLabel", props)
	-- the kit's soft dark outline on text (chunky words: a solid one)
	local chunky = props.FontFace == LOOK.Chunky
	new("UIStroke", { Color = LOOK.Outline, Thickness = if chunky then 1.6 else 1, Transparency = if chunky then 0 else 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	return label
end
-- a graphite surface (top -> bottom gradient, a dark edge, the light hairline along the top)
local function graphite(frame, top, bottom, radius)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = frame })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = frame })
	new("UIStroke", { Color = LOOK.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame })
	new("Frame", { Name = "Hairline", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.78, BorderSizePixel = 0,
		Position = UDim2.new(0, radius, 0, 1), Size = UDim2.new(1, -2 * radius, 0, 1), Parent = frame })
	return frame
end

-- The loading screen and menu track (Config/Sounds.MenuMusic), looping from the first frame; it keeps playing through the
-- main menu (the same Sound, never restarted) and fades out on Play (MenuClient, Audio.StopMenuMusic)
local music = Instance.new("Sound")
music.Name = "MenuMusic"
music.SoundId = LOOK.Music
music.Volume = LOOK.MusicVolume
music.Looped = true
music.Parent = game:GetService("SoundService")
music:Play()

local gui = new("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None -- (the whole screen, under Roblox's top bar too)
local back = new("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = LOOK.Background, BorderSizePixel = 0, Parent = gui })
back.ClipsDescendants = true
-- the art covering the whole screen by scale + Crop (owner, 15 Oct: never a pixel size worked out once, which left a gap
-- on the right when a phone changed size); the dark gradient over the left 40%
local art = new("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = LOOK.Art, ScaleType = Enum.ScaleType.Crop,
	ResampleMode = Enum.ResamplerMode.Default, AnchorPoint = Vector2.new(0.7, 0.5), Position = UDim2.fromScale(0.7, 0.5), Size = UDim2.fromScale(1, 1),
	Parent = back })
-- (26 Oct) the red light behind the character, beating like a heart (DRAMA below)
local heartGlow = new("ImageLabel", { Name = "HeartGlow", BackgroundTransparency = 1, Image = LOOK.Glow, ImageColor3 = Color3.fromRGB(255, 30, 30),
	ImageTransparency = 0.7, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.48), Size = UDim2.fromScale(0.75, 1.25), Parent = back })
new("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(0.4, 1), Parent = back }, {
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.55, 0.55),
		NumberSequenceKeypoint.new(1, 1) }) }),
})

-- everything else in mockup px (scaled like Kit.Root: the shorter side / 390, never wider than the 844px layout)
local placeTop -- (set below, once the logo exists)
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Parent = gui })
local scale = new("UIScale", { Parent = root })
local function rescale()
	local size = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	-- (Studio: the TestPhoneSize phone in the top left, like Kit)
	local phone = RunService:IsStudio() and Workspace:GetAttribute("TestPhoneSize")
	local blow = 1
	if typeof(phone) == "Vector2" and phone.X > 0 then
		blow = math.min(size.X / phone.X, size.Y / phone.Y)
		size = phone
	end
	local s = math.max(0.5, math.min(size.Y / BASE.Y, size.X / BASE.X))
	scale.Scale = s * blow
	root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	-- the background: the whole screen (Studio's TestPhoneSize phone: that rectangle)
	back.Size = if blow ~= 1 or typeof(phone) == "Vector2" then UDim2.fromOffset(size.X * blow, size.Y * blow) else UDim2.fromScale(1, 1)
	if placeTop then placeTop(size.Y / s, s * blow) end
end
-- (the camera can be replaced while joining: follow the current one's ViewportSize)
local viewportConnection
local function watchCamera()
	if viewportConnection then viewportConnection:Disconnect() end
	local camera = Workspace.CurrentCamera
	if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
	rescale()
end

-- the logo and the tagline
local logo = new("ImageLabel", { Name = "Logo", BackgroundTransparency = 1, Image = LOOK.Logo, ScaleType = Enum.ScaleType.Fit, ZIndex = 2,
	Position = UDim2.new(0, 18, 0.02, 0), Size = UDim2.fromScale(0.6, 0.32), Parent = root }, {
	new("UIAspectRatioConstraint", { AspectRatio = 432 / 354, DominantAxis = Enum.DominantAxis.Height }),
})
new("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = LOOK.Glow, ImageColor3 = Color3.fromRGB(255, 45, 40), ImageTransparency = 0.35,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(1.55, 1.45), ZIndex = 1, Parent = logo })
local tagline = text({ Name = "Tagline", Text = "Everyone starts tiny.", FontFace = LOOK.Body, TextSize = 14, TextColor3 = Color3.fromHex("#E7DEDF"),
	Position = UDim2.new(0, 24, 0.34, 4), Size = UDim2.fromOffset(300, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = root })
-- the logo starts under Roblox's top bar (owner, 15 Oct: it sat under the top-left buttons), the tagline under it; the
-- logo shrinks so both stay above the tip tile
local GuiService = game:GetService("GuiService")
local lastRootH, lastScale = BASE.Y, 1
placeTop = function(rootH: number, screenScale: number)
	lastRootH, lastScale = rootH, screenScale
	local top = (GuiService.TopbarInset.Max.Y + 8) / math.max(screenScale, 0.01)
	local logoMax = math.max(60, rootH * 0.32) -- (the first frame can report a tiny screen: never an empty range)
	local logoH = math.clamp(math.min(rootH * 0.32, rootH - 196 - 28 - top), 60, logoMax) -- (26 Oct: 196 = the tip, bar and the hype line)
	logo.Size = UDim2.fromOffset(logoH * 432 / 354, logoH)
	logo.Position = UDim2.new(0, 18, 0, top)
	tagline.Position = UDim2.new(0, 24, 0, top + logoH + 4)
end
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() placeTop(lastRootH, lastScale) end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
Workspace:GetAttributeChangedSignal("TestPhoneSize"):Connect(rescale)
watchCamera()

-- the tip: a graphite tile with a small gold TIP tag
local tipTile = graphite(new("Frame", { Name = "TipTile", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -78), Size = UDim2.new(0.46, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Parent = root }), LOOK.PanelTop, LOOK.PanelBottom, 10)
-- (prompt 40) a thin gold edge (owner, 22 Oct: no mesh on cards)
new("UIStroke", { Name = "GoldEdge", Color = LOOK.Gold, Thickness = 1.5, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tipTile })
-- (the padding sits on an inner frame, so the tile's hairline stays on its top edge)
local tipBody = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = tipTile }, {
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
})
local tag = new("Frame", { Name = "Tag", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromOffset(36, 18), Parent = tipBody }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	new("UIStroke", { Color = LOOK.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	new("UIGradient", { Rotation = 90, Color = GOLD }),
})
new("TextLabel", { Name = "Text", BackgroundTransparency = 1, Text = "TIP", FontFace = LOOK.Chunky, TextSize = 12, TextColor3 = LOOK.Ink,
	Size = UDim2.fromScale(1, 1), Parent = tag })
local tip = text({ Name = "Tip", Text = "", FontFace = LOOK.Chunky, TextSize = 13, TextWrapped = true, Position = UDim2.fromOffset(46, 1),
	Size = UDim2.new(1, -46, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.1, Parent = tipBody })

-- the step and the percent, the bar, the page dots
-- (prompt 40, mockup real/loading) the words chunky, the bar the full width under them
local status = text({ Name = "Status", Text = "LOADING THE GAME", FontFace = LOOK.Chunky, TextSize = 16, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -52),
	Size = UDim2.new(1, -140, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = root })
local PLATE_AREA = 70 -- (26 Oct) room at the bar's right end for the sleeve and its plates
local percent = text({ Name = "Percent", Text = "0%", FontFace = LOOK.Chunky, TextSize = 28, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24 - PLATE_AREA, 1, -48),
	Size = UDim2.fromOffset(90, 30), TextXAlignment = Enum.TextXAlignment.Right, Parent = root })
local percentScale = new("UIScale", { Parent = percent })
new("UIGradient", { Rotation = 90, Color = GOLD, Parent = percent })
local bar = new("Frame", { Name = "Bar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -30), Size = UDim2.new(1, -48 - PLATE_AREA, 0, 16),
	BackgroundColor3 = LOOK.Well, BorderSizePixel = 0, Parent = root }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	new("UIStroke", { Color = LOOK.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) }),
})
-- metallic red: a bright band near the top, a dark bottom
local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bar }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#FF8A90")),
		ColorSequenceKeypoint.new(0.28, Color3.fromHex("#F2434B")),
		ColorSequenceKeypoint.new(0.62, Color3.fromHex("#D0222B")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#8E1219")),
	}) }),
})
local dots = new("Frame", { Name = "Dots", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -18),
	Size = UDim2.fromOffset(300, 6), Parent = root }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function drawDots(count: number, current: number)
	for _, child in ipairs(dots:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for index = 1, count do
		new("Frame", { Name = "Dot" .. index, LayoutOrder = index, BorderSizePixel = 0, Size = UDim2.fromOffset(index == current and 18 or 6, 5),
			BackgroundColor3 = index == current and LOOK.Gold or LOOK.Dot, Parent = dots }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end
end

-- SKIP: a quiet dark button (the word is its own label: the button's gradient would tint its text too)
local skip = new("TextButton", { Name = "Skip", Text = "", AutoButtonColor = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14),
	Size = UDim2.fromOffset(64, 34), Visible = false, Parent = root })
graphite(skip, LOOK.QuietTop, LOOK.QuietBottom, 9)
text({ Name = "Label", Text = "SKIP", FontFace = LOOK.Chunky, TextSize = 16, Size = UDim2.fromScale(1, 1), Parent = skip })

------------------------------------------------------------------------
-- Drama (owner, 26 Oct): push-in, heartbeat light, embers, the barbell's plates, the hype line, flash + shake
------------------------------------------------------------------------
local DRAMA = {
	Zoom = 0.1, ZoomTime = 24,            -- the art grows this much over ZoomTime seconds
	Beat = 1.25,                          -- seconds per heartbeat (two pulses)
	Embers = 22,
	Shake = 6, ShakeTime = 0.28,          -- px (mockup) and seconds per plate slam
	Milestones = { 0.25, 0.5, 0.75, 1 },
	Hype = { "WARMING UP", "CHALKING UP", "LOADING PLATES", "GETTING PUMPED", "LET'S LIFT!" },
	-- bumper plates, heaviest (tallest) inside; (owner, 26 Oct) all red, a shade apart so each plate still reads
	Plates = { { "#D0222B", 40 }, { "#B81E26", 36 }, { "#E0333B", 32 }, { "#A8171F", 28 } },
	Clank = { id = "rbxassetid://9116750726", volume = 0.5 },   -- PSE Metal Plate Impact (AlterThemes MetalClang)
	Boom = { id = "rbxassetid://9125484526", volume = 0.5 },    -- PSE Deep Hits Big Reverberant Booms 1 (AlterThemes ImpactSub)
}
local function sfx(spec)
	local sound = new("Sound", { SoundId = spec.id, Volume = spec.volume, Parent = game:GetService("SoundService") })
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
	task.delay(4, function() if sound.Parent then sound:Destroy() end end)
end

-- the big hype line over the tip (heavy italic, white into red)
local hype = text({ Name = "Hype", Text = DRAMA.Hype[1], FontFace = LOOK.Display, TextScaled = true, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 22, 1, -150), Size = UDim2.new(0.6, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = root }, {})
new("UITextSizeConstraint", { MaxTextSize = 40, Parent = hype })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#FFFFFF"), Color3.fromHex("#FF4A4A")), Parent = hype })
local hypeScale = new("UIScale", { Parent = hype })

-- the barbell's end: a steel sleeve, the plates slide onto it, a collar at the end
local sleeve = new("Frame", { Name = "Sleeve", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 2, 0.5, 0), Size = UDim2.fromOffset(PLATE_AREA - 6, 8),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = bar }, {
	new("UICorner", { CornerRadius = UDim.new(0, 3) }),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#E6E8EC")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#9AA0A8")), ColorSequenceKeypoint.new(1, Color3.fromHex("#4A4E55")) }) }),
	new("UIStroke", { Color = LOOK.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
local plates = {}
for index, spec in ipairs(DRAMA.Plates) do
	local color = Color3.fromHex(spec[1])
	local plate = new("Frame", { Name = "Plate" .. index, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4 + (index - 1) * 12, 0.5, -40),
		Size = UDim2.fromOffset(10, spec[2]), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 + index,
		Parent = sleeve }, {
		new("UICorner", { CornerRadius = UDim.new(0, 3) }),
		new("UIGradient", { Rotation = 0, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.35)),
			ColorSequenceKeypoint.new(0.45, color), ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.45)) }) }),
		new("UIStroke", { Color = LOOK.Outline, Thickness = 1.5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	plates[index] = plate
end
local collar = new("Frame", { Name = "Collar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4 + #DRAMA.Plates * 12, 0.5, 0),
	Size = UDim2.fromOffset(6, 16), BackgroundColor3 = Color3.fromHex("#C9CDD3"), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 8, Parent = sleeve }, {
	new("UICorner", { CornerRadius = UDim.new(0, 2) }),
})

-- the flash (whole screen) and embers drifting up over the art
local flash = new("Frame", { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = gui })
local rng = Random.new()
local embers = {}
local EMBER_COLORS = { Color3.fromHex("#FF5A3A"), Color3.fromHex("#FFB347"), Color3.fromHex("#FF2D2D") }
local function resetEmber(ember, anywhere: boolean)
	ember.x, ember.y = rng:NextNumber(0.3, 1), if anywhere then rng:NextNumber(0, 1.05) else 1.05
	ember.speed, ember.drift, ember.phase = rng:NextNumber(0.05, 0.13), rng:NextNumber(-0.02, 0.02), rng:NextNumber(0, 6.28)
	local size = rng:NextInteger(2, 5)
	ember.frame.Size = UDim2.fromOffset(size, size)
	ember.frame.BackgroundColor3 = EMBER_COLORS[rng:NextInteger(1, #EMBER_COLORS)]
end
for _ = 1, DRAMA.Embers do
	local frame = new("Frame", { Name = "Ember", BorderSizePixel = 0, BackgroundTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 0.5), Parent = back }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local ember = { frame = frame }
	resetEmber(ember, true)
	table.insert(embers, ember)
end

local startedAt = os.clock()
local shakeUntil = 0
local reached = 0 -- milestones slammed so far
local function slam(index: number)
	local plate = plates[index]
	if plate then
		plate.BackgroundTransparency = 0
		plate.UIStroke.Transparency = 0
		TweenService:Create(plate, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 4 + (index - 1) * 12, 0.5, 0) }):Play()
	end
	task.delay(0.12, function()
		if not gui.Parent then return end
		sfx(DRAMA.Clank)
		if index == #DRAMA.Milestones then
			sfx(DRAMA.Boom)
			collar.BackgroundTransparency = 0
		end
		flash.BackgroundTransparency = if index == #DRAMA.Milestones then 0.35 else 0.7
		TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		shakeUntil = os.clock() + DRAMA.ShakeTime
		percentScale.Scale = 1.35
		TweenService:Create(percentScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		hype.Text = DRAMA.Hype[index + 1] or hype.Text
		hypeScale.Scale = 1.3
		hype.TextTransparency = 0.6
		TweenService:Create(hypeScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(hype, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	end)
end

-- every frame (called from the progress loop below with the bar's shown value)
local function drama(dt: number, value: number)
	local t = os.clock() - startedAt
	local zoom = 1 + DRAMA.Zoom * math.sin(math.min(t / DRAMA.ZoomTime, 1) * math.pi / 2)
	art.Size = UDim2.fromScale(zoom, zoom)
	-- the heartbeat: two quick pulses, then a rest
	local beat = (t % DRAMA.Beat) / DRAMA.Beat
	local pulse = math.max(math.exp(-((beat - 0.08) / 0.05) ^ 2), 0.7 * math.exp(-((beat - 0.28) / 0.05) ^ 2))
	heartGlow.ImageTransparency = 0.78 - 0.33 * pulse
	-- shake on a slam
	local offset = Vector2.zero
	if os.clock() < shakeUntil then
		local k = (shakeUntil - os.clock()) / DRAMA.ShakeTime
		offset = Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * DRAMA.Shake * k
	end
	root.Position = UDim2.fromOffset(offset.X, offset.Y)
	art.Position = UDim2.new(0.7, offset.X * 1.5, 0.5, offset.Y * 1.5)
	-- embers
	for _, ember in ipairs(embers) do
		ember.y -= ember.speed * dt
		ember.x += ember.drift * dt + math.sin(t * 1.7 + ember.phase) * 0.0006
		if ember.y < -0.05 then resetEmber(ember, false) end
		ember.frame.Position = UDim2.fromScale(ember.x, ember.y)
		ember.frame.BackgroundTransparency = math.clamp(1 - ember.y * 1.4, 0.15, 1)
	end
	-- the plates: one per milestone passed
	while reached < #DRAMA.Milestones and value >= DRAMA.Milestones[reached + 1] - 0.001 do
		reached += 1
		slam(reached)
	end
end

------------------------------------------------------------------------
-- Progress
------------------------------------------------------------------------
local step, stepAt, shown = 0, os.clock(), 0
local label = "Loading the game"
local updating = false
local loadedAt = nil
local function setStep(value: number, text: string?)
	if value > step then
		step, stepAt = value, os.clock()
	end
	if text and not updating then label = text end
end

-- Soft shutdown (ShutdownService): the game was updated and this is the short stop on the way to a new server. The game
-- never loads here, so the screen stays and says why until the teleport takes over.
local function checkUpdating()
	if updating or Workspace:GetAttribute("SoftShutdown") ~= true then return end
	updating = true
	label = "Updating the gym"
	dots.Visible = false
	tip.Text = "Taking you to the new version. Your progress is saved."
	setStep(0.9)
end
Workspace:GetAttributeChangedSignal("SoftShutdown"):Connect(checkUpdating)
checkUpdating()

local function menuProgress()
	local value = player:GetAttribute("MenuLoad")
	if type(value) == "number" and step >= 0.55 then setStep(0.55 + 0.35 * math.clamp(value, 0, 1), "Loading the gym") end
end
player:GetAttributeChangedSignal("MenuLoad"):Connect(menuProgress)

-- the game, then the UI images, then (MenuClient) the gym; the other players' body stage meshes download behind it all
local BodyStages = nil
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	checkUpdating()
	loadedAt = os.clock()
	setStep(0.3, "Loading muscles")
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 10)
	local config = shared and shared:WaitForChild("Config", 10)
	local uiModule = config and config:WaitForChild("UI", 10)
	local ok, UI = pcall(require, uiModule)
	if ok and type(UI) == "table" then
		if type(UI.LoadingTips) == "table" and #UI.LoadingTips > 0 then TIPS = UI.LoadingTips end
		-- preload the UI images (every icon, the art, the trainer portraits): the bar follows them
		local list = {}
		for _, group in ipairs({ UI.Icons or {}, UI.Trainers or {}, UI.ShopIcons or {} }) do
			for _, id in pairs(group) do
				table.insert(list, new("ImageLabel", { Image = id }))
			end
		end
		table.insert(list, new("ImageLabel", { Image = UI.MenuArt or LOOK.Art }))
		table.insert(list, new("ImageLabel", { Image = UI.Logo3D or LOOK.Logo }))
		local done = 0
		pcall(function()
			ContentProvider:PreloadAsync(list, function()
				done += 1
				setStep(0.3 + 0.25 * done / math.max(#list, 1))
			end)
		end)
	end
	setStep(0.55, "Loading the gym")
	menuProgress()
	local module = shared and shared:WaitForChild("BodyStages", 10)
	if module then
		local okStages, result = pcall(require, module)
		if okStages then BodyStages = result end
	end
end)

-- tips: one at a time, faded in and out
task.spawn(function()
	local rng = Random.new()
	local index = rng:NextInteger(1, #TIPS)
	while gui.Parent do
		index = index % #TIPS + 1
		tip.Text = if updating then "Taking you to the new version. Your progress is saved." else TIPS[index]
		drawDots(#TIPS, index)
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		local tipStroke = tip:FindFirstChildOfClass("UIStroke") -- (the chunky outline fades with the words)
		if tipStroke then TweenService:Create(tipStroke, TweenInfo.new(0.3), { Transparency = 0 }):Play() end
		task.wait(TIMING.Tip)
		if not gui.Parent then break end
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		local fadeStroke = tip:FindFirstChildOfClass("UIStroke")
		if fadeStroke then TweenService:Create(fadeStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play() end
		task.wait(0.3)
	end
end)

local done, finishing = false, false
local function fadeOut()
	if done then return end
	done = true
	player:SetAttribute("LoadingDone", true)
	local info = TweenInfo.new(TIMING.Fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, item in ipairs(gui:GetDescendants()) do
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			TweenService:Create(item, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif item:IsA("ImageLabel") then
			TweenService:Create(item, info, { ImageTransparency = 1 }):Play()
		elseif item:IsA("Frame") and item.BackgroundTransparency < 1 then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(TIMING.Fade, function() gui:Destroy() end)
end
local function finish()
	if done or finishing then return end
	finishing = true
	-- the menu is ready: give the body stage meshes a few more seconds
	if BodyStages then
		label = "Loading players"
		local deadline = os.clock() + TIMING.Stages
		while not done and not BodyStages.WaitReady(0.1) and os.clock() < deadline and gui.Parent do
			setStep(0.9 + 0.09 * BodyStages.Progress())
		end
	end
	setStep(1)
	while not done and shown < 0.995 and gui.Parent do RunService.Heartbeat:Wait() end
	-- (Studio only: the Workspace attribute TestHoldLoading = true keeps the loading screen up, for screenshots)
	while RunService:IsStudio() and Workspace:GetAttribute("TestHoldLoading") == true and not done do task.wait(0.2) end
	if done then return end
	label = "Let's lift"
	task.wait(0.9) -- (26 Oct: time for the last plate's slam and LET'S LIFT!)
	fadeOut()
end

if player:GetAttribute("MenuReady") then task.spawn(finish) end
player:GetAttributeChangedSignal("MenuReady"):Connect(function()
	if player:GetAttribute("MenuReady") then task.spawn(finish) end
end)

-- SKIP after a few seconds: straight to the menu (it keeps loading behind it)
task.delay(TIMING.Skip, function()
	if gui.Parent and not done and not updating then skip.Visible = true end
end)
skip.Activated:Connect(fadeOut)

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not gui.Parent then
		connection:Disconnect()
		return
	end
	if loadedAt and not finishing and os.clock() - loadedAt > TIMING.GiveUp then task.spawn(finish) end
	-- creep a little past the last step while waiting, then follow the target smoothly
	local creep = if step < 1 then TIMING.Creep * (1 - math.exp(-(os.clock() - stepAt) / TIMING.CreepTime)) else 0
	local target = math.min(step + creep, 1)
	shown += (target - shown) * math.min(1, dt * TIMING.Follow)
	if step >= 1 and target - shown < 0.01 then shown = 1 end
	fill.Size = UDim2.fromScale(math.max(shown, 0.02), 1)
	status.Text = string.upper(label)
	percent.Text = math.floor(shown * 100) .. "%"
	drama(dt, shown)
end)
