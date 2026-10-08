-- MenuClient: the menu screen shown on join (owner, 9 Oct: "as good as the genetics screen").
--  * Camera: slow cinematic moves through the town's best places, one after another (the gym entrance, inside the
--    starter gym, the pro gym, the beach gym, the skate park), each a slow dolly with soft depth of field, dissolving
--    through black into the next; a small caption names the place. The first shot is the entrance ("MenuCamera" part in
--    Workspace.Gym.Entrance, a Persistent model: move it in Studio to reframe; its FocusDistance attribute is how far
--    ahead it looks). The next place streams in while the current one plays.
--  * The card: a dark shade over the left of the screen (black, fading out to the right, never colored), the big GYM
--    ARC title with a thin white rule and "Everyone starts tiny."; for returning players a profile (genetics grade,
--    name, membership, Growth Spurt + height, equipped title in its rarity color, streak); a solid white PLAY button that
--    breathes (a soft glow) and catches a light sweep every few seconds; TITLES and SETTINGS; small chips (offline coins,
--    Muscle of the Day). Everything slides in one after another. New players get the title and Play only.
-- Start: ReplicatedFirst's LoadingScreen covers everything until this script has streamed in the area around the first
-- shot (Player:RequestStreamAroundAsync) and set the LocalPlayer attribute "MenuReady"; "MenuLoad" (0..1) feeds its bar.
-- Play: the card fades; from another place the screen dips to black and comes back at the entrance; the camera glides
-- in through the door to behind the character, then the HUD fades in. Movement is frozen and the side menu hidden until
-- then.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIBus = require(Shared:WaitForChild("UI"):WaitForChild("UIBus"))
UIBus.MenuOpen = true -- set first, before anything else loads, so other scripts wait for Play

local Onboarding = require(Shared.Config.Onboarding)
local Muscles = require(Shared.Config.Muscles)
local MuscleOfTheDay = require(Shared.Config.MuscleOfTheDay)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local ShowOff = require(Shared.Config.ShowOff)
local Titles = require(Shared.Config.Titles)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local UIFonts = require(Shared.UI.UIFonts)
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local SHOT = {
	-- used when the MenuCamera part is missing: left of the entrance looking along the gym front
	Eye = Vector3.new(-8, 5.4, 38),
	Focus = Vector3.new(10.5, 7.2, 8),
	Fov = 55,
	StreamTimeout = 8,  -- seconds to wait for the area around the first shot
	ExitTime = 1.6,     -- camera glide from the entrance shot to behind the character
	HudFade = 0.35,
	Hold = 8.5,         -- seconds per place
	Dip = 0.45,         -- seconds to black and back between places
}
-- The places after the entrance: a slow dolly from `from` to `to`, looking at `focus` (world studs; the gyms' layout
-- from the Gyms / Town builders). Edit here to reframe.
local PLACES = {
	{ name = "The starter gym", from = Vector3.new(38, 10.5, -35), to = Vector3.new(33, 9.6, -44), focus = Vector3.new(-30, 3, -55) },
	{ name = "The pro gym", from = Vector3.new(106, 7.5, -12), to = Vector3.new(100, 6.6, -18), focus = Vector3.new(78, 3.5, -62) },
	{ name = "The beach gym", from = Vector3.new(-54, 8.5, 171), to = Vector3.new(-46, 7.4, 179), focus = Vector3.new(-10, 3, 210) },
	{ name = "The skate park", from = Vector3.new(-86, 6.5, 183), to = Vector3.new(-95, 5.8, 190), focus = Vector3.new(-128, 1.5, 214) },
}
-- Phones in landscape (667x375 and similar) get a compact card.
local COMPACT = Theme.IsCompact()
local COLUMN_WIDTH = COMPACT and 270 or 380
local MARGIN = COMPACT and Spacing.L or Spacing.XL * 2
local PLAY_HEIGHT = COMPACT and 50 or 64
local BUTTON_HEIGHT = COMPACT and Theme.MinTouch or 48
local HOVER_SCALE = 1.04
-- full-screen and menu UIs that are not part of the HUD fade-in after Play
local NOT_HUD = { MenuScreen = true, LoadingScreen = true, GeneticsScreen = true }

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "MenuScreen", DisplayOrder = 20, IgnoreGuiInset = true, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None -- (the shade and the dip cover the whole screen, the Roblox top bar too)
-- the shade behind the card: black on the left, gone by the middle (so the place stays the picture)
local shade = New("Frame", { Name = "Shade", Size = UDim2.fromScale(COMPACT and 0.75 or 0.6, 1), BackgroundColor3 = Colors.Shadow, BorderSizePixel = 0, Parent = gui }, {
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.5, 0.42), NumberSequenceKeypoint.new(1, 1) }) }),
})
-- the dip between places: plain black, its transparency tweened
local dip = New("Frame", { Name = "Dip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Shadow, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Parent = gui })

local column = New("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, MARGIN, 0.5, 0), Size = UDim2.fromOffset(COLUMN_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 2, Parent = gui }, {
	Theme.List(Vertical, COMPACT and "S" or "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
-- every row sits in a holder (the list places the holder; the row slides inside it on the way in)
local rows = {}
local function row(order: number, height: number?, name: string?): Frame
	local holder = New("Frame", { Name = name or ("Row" .. order), LayoutOrder = order, Size = UDim2.new(1, 0, 0, height or 0),
		AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = column })
	local inner = New("Frame", { Name = "Inner", Size = UDim2.new(1, 0, if height then 1 else 0, 0), AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Parent = holder })
	table.insert(rows, inner)
	return inner
end

local titleRow = row(1, COMPACT and 46 or 66)
local title = Theme.Text({ Text = "GYM ARC", TextSize = COMPACT and "HeroCompact" or "Hero", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = titleRow })
title.FontFace = UIFonts.Heading
Theme.TextShadow(title, 0.5)
local ruleRow = row(2, 3)
New("Frame", { Size = UDim2.fromOffset(56, 3), BackgroundColor3 = Colors.Text, BorderSizePixel = 0, Parent = ruleRow }, { Theme.Round("Segment") })
local taglineRow = row(3, 22)
local tagline = Theme.Text({ Text = "Everyone starts tiny.", TextSize = "Medium", TextColor3 = Colors.Muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = taglineRow })
tagline.FontFace = UIFonts.Body
Theme.TextShadow(tagline, 0.6)
row(4, COMPACT and 2 or Spacing.M)
local profileRow = row(5, nil, "Profile") -- filled for returning players
profileRow.Parent.Visible = false

-- Hover grows the button a little with a springy Back ease, press shrinks it, release springs back (one button's
-- UIScale only, never a whole screen).
local function bounce(button: GuiButton)
	local scale = New("UIScale", { Parent = button })
	local hovering, pressing = false, false
	local function settle()
		local goal = if pressing then Theme.Motion.PressScale elseif hovering then HOVER_SCALE else 1
		local info = if pressing
			then TweenInfo.new(Theme.Motion.PressTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			else TweenInfo.new(0.3, Theme.Motion.Bounce, Enum.EasingDirection.Out)
		TweenService:Create(scale, info, { Scale = goal }):Play()
	end
	local function isPress(input: InputObject)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	button.MouseEnter:Connect(function()
		hovering = true
		settle()
	end)
	button.MouseLeave:Connect(function()
		hovering, pressing = false, false
		settle()
	end)
	button.InputBegan:Connect(function(input)
		if isPress(input) and button.Active then
			pressing = true
			settle()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			pressing = false
			if input.UserInputType == Enum.UserInputType.Touch then hovering = false end
			settle()
		end
	end)
	button.Activated:Connect(function()
		if button.Active then Audio.PlayUI("Click") end
	end)
end

-- Play: a solid white button with dark text (the one bold call to action); a soft glow breathes around it and a light
-- sweep crosses it every few seconds
local playRow = row(6, PLAY_HEIGHT)
local playButton = New("TextButton", { Name = "Play", Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.7,
	Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Active = false, Parent = playRow }, { Theme.Round("Button") })
local playGlow = New("UIStroke", { Name = "Glow", Color = Colors.Text, Thickness = 0, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = playButton })
local sweep = New("Frame", { Name = "Sweep", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.3, 0, 0.5, 0), Size = UDim2.new(0, 46, 2, 0),
	Rotation = 18, BackgroundColor3 = Colors.Text, BorderSizePixel = 0, Parent = playButton }, {
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }) }),
})
sweep.Visible = false
local playLabel = Theme.Text({ Text = "LOADING", TextSize = "Large", TextColor3 = Colors.Ink, TextTransparency = 0.5, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = playButton })
playLabel.FontFace = UIFonts.Heading
bounce(playButton)

local buttonsRow = row(7, BUTTON_HEIGHT, "Buttons")
buttonsRow.Parent.Visible = false -- shown for returning players once data loads
New("UIListLayout", { FillDirection = Horizontal, Padding = UDim.new(0, Spacing.S), SortOrder = Enum.SortOrder.LayoutOrder, Parent = buttonsRow })
local function menuButton(order, text)
	local button = Theme.Button("Secondary", { Name = text, LayoutOrder = order, Size = UDim2.new(0.5, -Spacing.S / 2, 1, 0), Parent = buttonsRow })
	local label = Theme.Text({ Text = string.upper(text), TextSize = "Body", Size = UDim2.fromScale(1, 1), Parent = button })
	label.FontFace = UIFonts.Heading
	return button
end
local titlesButton = menuButton(1, "Titles")
local settingsButton = menuButton(2, "Settings")

-- chips (returning players): streak, offline coins, Muscle of the Day
local chipsRow = row(8, nil, "Chips")
chipsRow.Parent.Visible = false
New("UIListLayout", { FillDirection = Vertical, Padding = UDim.new(0, Spacing.XS), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chipsRow })
New("UIPadding", { PaddingTop = UDim.new(0, Spacing.S), Parent = chipsRow })
local function chip(order: number, text: string, key: string?)
	local holder = Theme.Panel({ Name = key or ("Chip" .. order), LayoutOrder = order, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = chipsRow }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.M), PaddingRight = UDim.new(0, Spacing.M) }),
		Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	New("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Colors.Text, BorderSizePixel = 0, Parent = holder }, { Theme.Round("Round") })
	local label = Theme.Text({ LayoutOrder = 2, Text = text, TextSize = "Small", TextColor3 = Colors.Text, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = holder })
	label.FontFace = UIFonts.Body
	return holder
end

-- the caption naming the place (bottom right)
local caption = New("Frame", { Name = "Caption", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -MARGIN, 1, -MARGIN), Size = UDim2.fromOffset(240, 30),
	BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
local captionLine = New("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(28, 2), BackgroundColor3 = Colors.Text,
	BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = caption })
local captionText = Theme.Text({ Text = "", TextSize = "Body", TextColor3 = Colors.Text, TextTransparency = 1, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 1, -8), Size = UDim2.fromOffset(240, 22), TextXAlignment = Enum.TextXAlignment.Right, Parent = caption })
captionText.FontFace = UIFonts.Heading
Theme.TextShadow(captionText, 0.5)
local function showCaption(text: string)
	Theme.Tween(captionText, { TextTransparency = 1 }, 0.25)
	task.delay(0.3, function()
		captionText.Text = string.upper(text)
		Theme.Tween(captionText, { TextTransparency = 0.1 }, 0.5)
		captionLine.Size = UDim2.fromOffset(0, 2)
		Theme.Tween(captionLine, { Size = UDim2.fromOffset(28, 2) }, 0.5)
	end)
end

-- Rows slide in from the left, one after another (each its own transparency tweened: no CanvasGroup, text stays crisp)
local function revealRows()
	for index, inner in ipairs(rows) do
		if inner.Parent.Visible then
			inner.Position = UDim2.fromOffset(-28, 0)
			Theme.Fade(inner, false, 0)
			task.delay(0.08 * index, function()
				Theme.Tween(inner, { Position = UDim2.fromOffset(0, 0) }, 0.45, Enum.EasingStyle.Quint)
				Theme.Fade(inner, true, 0.4)
			end)
		end
	end
end

------------------------------------------------------------------------
-- Profile (returning players)
------------------------------------------------------------------------
local function buildProfile(data)
	local tier = ShowOff.Tier(data.stats and data.stats.totalReps or 0)
	local card = New("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = profileRow }, {
		Theme.List(Horizontal, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local overall = data.genetics and data.genetics.overall
	if overall and Theme.Grades and Theme.Grades[overall] then
		local tag = Theme.RankTag(overall, { LayoutOrder = 1, Size = UDim2.fromOffset(40, 34) })
		local letter = tag:FindFirstChild("Letter")
		if letter and letter:IsA("TextLabel") then letter.TextSize = Theme.TextSize.Large end -- (the badge is bigger here)
		tag.Parent = card
	end
	local text = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, -60, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card },
		{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local name = Theme.Text({ LayoutOrder = 1, Text = player.DisplayName, TextSize = "Medium", Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = text })
	name.FontFace = UIFonts.BodyBold
	Theme.TextShadow(name, 0.6)
	local lines = {
		{ tier.id .. " member" .. (player:GetAttribute("Pass_VIP") and "  ·  VIP" or ""), tier.color },
		{ "Growth Spurt " .. data.growthSpurts .. "  ·  " .. GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts)), Colors.Muted },
	}
	local equipped = data.titles and data.titles.equipped
	local titleDef = equipped and Titles.ById[equipped]
	if titleDef then
		local rarity = Theme.Rarity[titleDef.rarity]
		table.insert(lines, { titleDef.name, if titleDef.rarity == "Secret" then Colors.Text elseif rarity then rarity.Fill else Colors.Text })
	end
	for i, entry in ipairs(lines) do
		local line = Theme.Text({ LayoutOrder = 1 + i, Text = entry[1], TextSize = "Small", TextColor3 = entry[2], Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = text })
		line.FontFace = UIFonts.Body
		Theme.TextShadow(line, 0.6)
	end
	profileRow.Parent.Visible = true
end

------------------------------------------------------------------------
-- Freeze movement and hide the side menu while the menu is up
------------------------------------------------------------------------
local function sink()
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindActionAtPriority("MenuFreeze", sink, false, Enum.ContextActionPriority.High.Value + 200,
	Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
	Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)

local mainHud = nil
task.spawn(function()
	mainHud = playerGui:WaitForChild("MainHud", 10)
	if mainHud and UIBus.MenuOpen then mainHud.Enabled = false end
end)

------------------------------------------------------------------------
-- Camera: the places, one after another
------------------------------------------------------------------------
local camera = Workspace.CurrentCamera
local baseFov = camera.FieldOfView
-- the entrance shot: a slow slide sideways in front of the door
local entrance = { name = "Main Street", from = SHOT.Eye, to = SHOT.Eye, focus = SHOT.Focus }
local current = entrance
local shotStart = os.clock()
local cycling = true

-- soft depth of field and a touch more contrast while the menu is up (on the camera: this client only)
local dof = New("DepthOfFieldEffect", { Name = "MenuDof", FarIntensity = 0.28, NearIntensity = 0, FocusDistance = 30, InFocusRadius = 26, Parent = camera })
local grade = New("ColorCorrectionEffect", { Name = "MenuGrade", Contrast = 0.08, Saturation = 0.06, Parent = camera })

local function shotCFrame(): CFrame
	local t = math.clamp((os.clock() - shotStart) / (SHOT.Hold + SHOT.Dip * 2), 0, 1)
	local eased = t * t * (3 - 2 * t) * 0.6 + t * 0.4 -- (moving from the first frame, slowing a little at the end)
	local eye = current.from:Lerp(current.to, eased)
	return CFrame.lookAt(eye, current.focus)
end

camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = SHOT.Fov
camera.CFrame = shotCFrame()
RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function()
	-- the default camera scripts may switch back when the character spawns
	if camera.CameraType ~= Enum.CameraType.Scriptable then camera.CameraType = Enum.CameraType.Scriptable end
	camera.CFrame = shotCFrame()
	dof.FocusDistance = math.clamp((current.focus - camera.CFrame.Position).Magnitude * 0.55, 12, 60)
end)

local function dipTo(alpha: number)
	local tween = TweenService:Create(dip, TweenInfo.new(SHOT.Dip, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { BackgroundTransparency = alpha })
	tween:Play()
	tween.Completed:Wait()
end

-- the cycle: the entrance, then each place, then the entrance again ... (the next place streams in while one plays)
local function cycle()
	local order = { entrance }
	for _, place in ipairs(PLACES) do table.insert(order, place) end
	local index = 1
	while cycling do
		local nextPlace = order[index % #order + 1]
		task.spawn(function()
			pcall(function() player:RequestStreamAroundAsync(nextPlace.focus, 4) end)
		end)
		task.wait(SHOT.Hold)
		if not cycling then break end
		dipTo(0)
		if not cycling then break end
		index = index % #order + 1
		current = order[index]
		shotStart = os.clock()
		showCaption(current.name)
		dipTo(1)
	end
end

-- Find the shot marker, stream in the area around it, then let the loading screen go.
task.spawn(function()
	player:SetAttribute("MenuLoad", 0.1)
	local gym = Workspace:WaitForChild("Gym", 10)
	local entranceModel = gym and gym:WaitForChild("Entrance", 10)
	local marker = entranceModel and entranceModel:WaitForChild("MenuCamera", 5)
	if marker and marker:IsA("BasePart") then
		local distance = marker:GetAttribute("FocusDistance")
		distance = if type(distance) == "number" and distance > 0 then distance else (SHOT.Focus - SHOT.Eye).Magnitude
		local right = marker.CFrame.RightVector
		entrance.focus = marker.Position + marker.CFrame.LookVector * distance
		-- (a slow slide of a few studs sideways in front of the door, ending on the marker's own framing)
		entrance.from = marker.Position - right * 2.4 + Vector3.new(0, 0.3, 0)
		entrance.to = marker.Position + right * 0.6
	else
		warn("[MenuClient] Workspace.Gym.Entrance.MenuCamera is missing: using the built-in menu shot")
	end
	shotStart = os.clock()
	player:SetAttribute("MenuLoad", 0.3)
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(entrance.focus, SHOT.StreamTimeout)
	end)
	if not ok then warn("[MenuClient] streaming the menu scene: " .. tostring(err)) end
	player:SetAttribute("MenuLoad", 1)
	player:SetAttribute("MenuReady", true)
	-- the tour starts once the loading screen has gone (the entrance shot plays its whole time in view)
	while playerGui:FindFirstChild("LoadingScreen") do task.wait(0.1) end
	shotStart = os.clock()
	showCaption(entrance.name)
	task.spawn(cycle)
end)

-- Horizontal direction from a point toward the gym (the middle of the machines near it), if there are any.
local function gymDirection(fromPosition: Vector3): Vector3?
	local sum, count = Vector3.zero, 0
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:IsA("Model") and (model:GetPivot().Position - fromPosition).Magnitude < 80 then
			sum += model:GetPivot().Position
			count += 1
		end
	end
	if count == 0 then return nil end
	local flat = (sum / count - fromPosition) * Vector3.new(1, 0, 1)
	return if flat.Magnitude > 1 then flat.Unit else nil
end

------------------------------------------------------------------------
-- The Play button's life: a soft breathing glow, a light sweep every few seconds
------------------------------------------------------------------------
local function playAlive()
	sweep.Visible = true
	task.spawn(function()
		while playButton.Parent and UIBus.MenuOpen do
			local up = TweenService:Create(playGlow, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = 5, Transparency = 0.55 })
			up:Play()
			up.Completed:Wait()
			local down = TweenService:Create(playGlow, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = 1, Transparency = 0.9 })
			down:Play()
			down.Completed:Wait()
		end
	end)
	task.spawn(function()
		while playButton.Parent and UIBus.MenuOpen do
			sweep.Position = UDim2.new(-0.2, 0, 0.5, 0)
			TweenService:Create(sweep, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.new(1.2, 0, 0.5, 0) }):Play()
			task.wait(3.6)
		end
	end)
end

------------------------------------------------------------------------
-- Ready: data loaded
------------------------------------------------------------------------
task.spawn(function()
	local data = ClientData.Get()
	local returning = (data.onboarding.tutorialStep or Onboarding.Done) >= Onboarding.Done
	buttonsRow.Parent.Visible = returning
	if returning then
		local okCard, err = pcall(buildProfile, data)
		if not okCard then warn("[MenuClient] profile: " .. tostring(err)) end
		chipsRow.Parent.Visible = true
		local streak = data.daily and data.daily.streak or 0
		if streak > 0 then chip(1, "Day " .. streak .. " streak", "Streak") end
		chip(3, "Muscle of the Day: " .. Muscles.GroupById[MuscleOfTheDay.GroupId()].name .. " (" .. MuscleOfTheDay.Multiplier .. "x gains)")
		-- the server pays streak/offline coins right after load; show them when they arrive
		local shownOffline = false
		local function offlineChip()
			local coins = data.welcome and data.welcome.offlineCoins or 0
			if coins > 0 and not shownOffline then
				shownOffline = true
				chip(2, "While you were away: +" .. Muscles.FormatExp(coins) .. " coins")
			end
		end
		offlineChip()
		ClientData.Changed:Connect(function(path)
			if path[1] == "welcome" and UIBus.MenuOpen then offlineChip() end
			if path[1] == "daily" and UIBus.MenuOpen then
				local old = chipsRow:FindFirstChild("Streak")
				if old then old:Destroy() end
				chip(1, "Day " .. data.daily.streak .. " streak", "Streak")
			end
		end)
	end
	-- the rows slide in once the loading screen has gone
	if not player:GetAttribute("MenuReady") then player:GetAttributeChangedSignal("MenuReady"):Wait() end
	while playerGui:FindFirstChild("LoadingScreen") do task.wait(0.1) end
	-- (the Play button's final look first: the slide-in fades every row back to what it shows now)
	playLabel.Text = "PLAY"
	playButton.BackgroundTransparency = 0
	playLabel.TextTransparency = 0
	revealRows()
	Audio.PlayUI("Whoosh")
	playButton.Active = true
	playAlive()
end)

------------------------------------------------------------------------
-- Play
------------------------------------------------------------------------
-- The HUD fades in: every HUD screen's top-level pieces that are showing (a frame after MenuClosed, once the scripts
-- waiting for the menu have shown theirs).
local function fadeInHud()
	RunService.Heartbeat:Wait()
	for _, screen in ipairs(playerGui:GetChildren()) do
		if screen:IsA("ScreenGui") and screen.Enabled and not NOT_HUD[screen.Name] then
			for _, piece in ipairs(screen:GetChildren()) do
				if piece:IsA("GuiObject") and piece.Visible then Theme.Fade(piece, true, SHOT.HudFade) end
			end
		end
	end
end

local function play()
	if not UIBus.MenuOpen or not playButton.Active then return end
	playButton.Active = false
	cycling = false
	Audio.PlayUI("Whoosh")

	local function finish()
		RunService:UnbindFromRenderStep("MenuCamera")
		dof:Destroy()
		grade:Destroy()
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
		ContextActionService:UnbindAction("MenuFreeze")
		if mainHud then mainHud.Enabled = true end
		UIBus.MenuOpen = false
		UIBus.MenuClosed:Fire()
		task.spawn(fadeInHud)
		gui.Enabled = false
	end

	Theme.Fade(column, false)
	Theme.Fade(caption, false)
	Theme.Tween(shade, { BackgroundTransparency = 1 }, 0.4)
	-- away from the entrance: dip to black and come back there (the glide starts at the door)
	if current ~= entrance then
		dipTo(0)
		current, shotStart = entrance, os.clock() - SHOT.Hold
		camera.CFrame = shotCFrame()
		task.wait(0.1)
		dipTo(1)
	end
	RunService:UnbindFromRenderStep("MenuCamera")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- face into the gym, then glide from the shot (in through the door) to a normal view behind the character
		local toGym = gymDirection(root.Position)
		if toGym then root.CFrame = CFrame.lookAt(root.Position, root.Position + toGym) end
		local behind = root.CFrame * CFrame.new(0, 3, 11)
		local goal = CFrame.lookAt(behind.Position, root.Position + Vector3.new(0, 1.5, 0))
		local info = TweenInfo.new(SHOT.ExitTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		TweenService:Create(camera, info, { CFrame = goal, FieldOfView = baseFov }):Play()
		TweenService:Create(dof, TweenInfo.new(SHOT.ExitTime), { FarIntensity = 0 }):Play()
		task.delay(SHOT.ExitTime, finish)
	else
		camera.FieldOfView = baseFov
		finish()
	end
end

playButton.Activated:Connect(play)
titlesButton.Activated:Connect(function() UIBus.OpenTitles:Fire() end)
settingsButton.Activated:Connect(function() UIBus.OpenSettings:Fire() end)

-- Titles/Settings opened from the menu: the column steps aside so see-through panels never stack
local subPanelOpen = false
UIBus.MenuPanelVisible.Event:Connect(function(visible)
	if not UIBus.MenuOpen or not playButton.Active or subPanelOpen == visible then return end
	subPanelOpen = visible
	if visible then
		local fadeOut = Theme.Fade(column, false)
		if fadeOut then
			-- hidden (not just see-through) so its buttons can't be tapped
			fadeOut.Completed:Connect(function()
				if subPanelOpen then column.Visible = false end
			end)
		end
	else
		column.Visible = true
		Theme.Fade(column, true)
	end
end)
