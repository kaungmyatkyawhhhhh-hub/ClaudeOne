-- MenuClient: the menu screen shown on join. A fixed shot of the GYM ARC entrance (eye height, very slow drift) is behind
-- a dark see-through card with the title, "Everyone starts tiny." and a bold Play button (+ Titles, Settings and a few
-- info lines for returning players: streak, offline coins, Muscle of the Day; new players get Play only).
-- Start: ReplicatedFirst's LoadingScreen covers everything until this script has streamed in the area around the shot
-- (Player:RequestStreamAroundAsync) and set the LocalPlayer attribute "MenuReady"; "MenuLoad" (0..1) feeds its bar.
-- The shot is the "MenuCamera" part in Workspace.Gym.Entrance (a Persistent model, so it and the entrance are always
-- there): move that part in Studio to reframe; its FocusDistance attribute is how far ahead it looks.
-- Play: the card fades, the camera glides in through the door to behind the character, then the HUD fades in.
-- Movement is frozen and the side menu is hidden until then.
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
local Legends = require(Shared.Config.Legends)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local UIFonts = require(Shared.UI.UIFonts)
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical = Enum.FillDirection.Vertical

local SHOT = {
	-- used when the MenuCamera part is missing: left of the entrance looking along the gym front, the door left of center
	-- (the card is on the right, over the long brick front and the Pro gym; the entrance block hides the wall poster)
	Eye = Vector3.new(-8, 5.4, 38),
	Focus = Vector3.new(10.5, 7.2, 8),
	Fov = 55,
	Drift = 0.7,        -- studs side to side
	DriftUp = 0.15,     -- studs up and down
	DriftSpeed = 0.14,  -- radians per second (one sway takes ~45 s)
	StreamTimeout = 8,  -- seconds to wait for the area around the shot
	ExitTime = 1.6,     -- camera glide from the shot to behind the character
	HudFade = 0.35,
}
-- Phones in landscape (667x375 and similar) get a compact card.
local COMPACT = Theme.IsCompact()
local PANEL_WIDTH = COMPACT and 250 or 320
local MARGIN = COMPACT and Spacing.L or Spacing.XL * 2
local PLAY_HEIGHT = COMPACT and 48 or 58
local BUTTON_HEIGHT = COMPACT and Theme.MinTouch or 48
local HOVER_SCALE = 1.04
-- full-screen and menu UIs that are not part of the HUD fade-in after Play
local NOT_HUD = { MenuScreen = true, LoadingScreen = true, GeneticsScreen = true }

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "MenuScreen", DisplayOrder = 20, Parent = playerGui })
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -MARGIN, 0.5, 0),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = gui,
}, {
	Theme.Pad(COMPACT and "L" or "XL"),
	Theme.List(Vertical, COMPACT and "S" or "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})

local title = Theme.Text({ LayoutOrder = 1, Text = "GYM ARC", TextSize = COMPACT and "HeroCompact" or "Hero", Size = UDim2.new(1, 0, 0, COMPACT and 44 or 64), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
title.FontFace = UIFonts.Heading
local tagline = Theme.Text({ LayoutOrder = 2, Text = "Everyone starts tiny.", TextSize = "Body", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
tagline.FontFace = UIFonts.Body
New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, COMPACT and Spacing.XS or Spacing.M), BackgroundTransparency = 1, Parent = panel })

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
			-- a tap on a touch screen has no hover to return to
			if input.UserInputType == Enum.UserInputType.Touch then hovering = false end
			settle()
		end
	end)
	button.Activated:Connect(function()
		if button.Active then Audio.PlayUI("Click") end
	end)
end

-- Play: a solid white button with dark text (the one bold call to action), no shadow rings under it.
local playButton = New("TextButton", {
	Name = "Play",
	LayoutOrder = 4,
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Colors.Text,
	BackgroundTransparency = 0.7,
	Size = UDim2.new(1, 0, 0, PLAY_HEIGHT),
	Active = false,
	Parent = panel,
}, { Theme.Round("Button") })
local playLabel = Theme.Text({ Text = "LOADING", TextSize = "Large", TextColor3 = Colors.Ink, TextTransparency = 0.5, Size = UDim2.fromScale(1, 1), Parent = playButton })
playLabel.FontFace = UIFonts.Heading
bounce(playButton)

local function menuButton(order, text)
	local button = Theme.Button("Secondary", { Name = text, LayoutOrder = order, Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT), Parent = panel })
	local label = Theme.Text({ Text = string.upper(text), TextSize = "Body", Size = UDim2.fromScale(1, 1), Parent = button })
	label.FontFace = UIFonts.Heading
	return button
end
local titlesButton = menuButton(5, "Titles")
local settingsButton = menuButton(6, "Settings")
titlesButton.Visible, settingsButton.Visible = false, false -- shown for returning players once data loads

-- info lines (returning players): streak, offline coins, Muscle of the Day
local info = New("Frame", { LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = panel },
	{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top), New("UIPadding", { PaddingTop = UDim.new(0, Spacing.S) }) })
local function infoLine(order, text)
	local line = Theme.Text({ LayoutOrder = order, Text = text, TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = info })
	line.FontFace = UIFonts.Body
	return line
end

------------------------------------------------------------------------
-- Player card (returning players): membership tier, overall genetics grade, height and a few numbers
------------------------------------------------------------------------
local function buildCard(data)
	local tier, nextTier = ShowOff.Tier(data.stats and data.stats.totalReps or 0)
	local card = Theme.Panel({
		Name = "PlayerCard",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, MARGIN, 1, -MARGIN),
		Size = UDim2.fromOffset(COMPACT and 230 or 280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, {
		Theme.Pad("L"),
		Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	-- the tier color is a thin line along the top of the card
	New("Frame", { Name = "TierLine", Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = tier.color, LayoutOrder = 0, Parent = card }, { Theme.Round("Segment") })
	local top = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = card })
	local name = Theme.Text({ Text = player.DisplayName, TextSize = "Body", Size = UDim2.new(1, -48, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	name.FontFace = UIFonts.BodyBold
	local member = Theme.Text({ Text = tier.id .. " member" .. (player:GetAttribute("Pass_VIP") and "  ·  VIP" or ""), TextSize = "Small", TextColor3 = tier.color, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -48, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	member.FontFace = UIFonts.Body
	local overall = data.genetics and data.genetics.overall
	if overall and Theme.Grades[overall] then
		Theme.RankTag(overall, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(28, 24), Parent = top })
	end
	local metCount, titleCount = 0, 0
	for _ in pairs(data.legends and data.legends.met or {}) do metCount += 1 end
	for _ in pairs(data.titles and data.titles.owned or {}) do titleCount += 1 end
	local lines = {
		"Height " .. GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts)) .. "  ·  Growth Spurt " .. data.growthSpurts,
		Muscles.FormatExp(data.stats and data.stats.totalReps or 0) .. " reps  ·  " .. titleCount .. " titles  ·  " .. metCount .. "/" .. #Legends.List .. " legends",
		nextTier and (nextTier.id .. " at " .. nextTier.reps .. " reps") or "Top tier",
	}
	for i, text in ipairs(lines) do
		local line = Theme.Text({ LayoutOrder = 1 + i, Text = text, TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		line.FontFace = UIFonts.Body
	end
	Theme.Fade(card, true)
	return card
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
-- Camera: the fixed entrance shot with a very slow drift
------------------------------------------------------------------------
local camera = Workspace.CurrentCamera
local baseFov = camera.FieldOfView
local shot = CFrame.lookAt(SHOT.Eye, SHOT.Focus)
local focus = SHOT.Focus
local started = os.clock()

local function shotCFrame(): CFrame
	local t = os.clock() - started
	local eye = shot.Position + shot.RightVector * math.sin(t * SHOT.DriftSpeed) * SHOT.Drift
		+ Vector3.yAxis * math.sin(t * SHOT.DriftSpeed * 0.7) * SHOT.DriftUp
	return CFrame.lookAt(eye, focus)
end

camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = SHOT.Fov
camera.CFrame = shotCFrame()
RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function()
	-- the default camera scripts may switch back when the character spawns
	if camera.CameraType ~= Enum.CameraType.Scriptable then camera.CameraType = Enum.CameraType.Scriptable end
	camera.CFrame = shotCFrame()
end)

-- Find the shot marker, stream in the area around it, then let the loading screen go.
task.spawn(function()
	player:SetAttribute("MenuLoad", 0.1)
	local gym = Workspace:WaitForChild("Gym", 10)
	local entrance = gym and gym:WaitForChild("Entrance", 10)
	local marker = entrance and entrance:WaitForChild("MenuCamera", 5)
	if marker and marker:IsA("BasePart") then
		local distance = marker:GetAttribute("FocusDistance")
		distance = if type(distance) == "number" and distance > 0 then distance else (SHOT.Focus - SHOT.Eye).Magnitude
		shot = marker.CFrame
		focus = marker.Position + marker.CFrame.LookVector * distance
	else
		warn("[MenuClient] Workspace.Gym.Entrance.MenuCamera is missing: using the built-in menu shot")
	end
	player:SetAttribute("MenuLoad", 0.3)
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(focus, SHOT.StreamTimeout)
	end)
	if not ok then warn("[MenuClient] streaming the menu scene: " .. tostring(err)) end
	player:SetAttribute("MenuLoad", 1)
	player:SetAttribute("MenuReady", true)
end)

-- Horizontal direction from a point toward the gym (the middle of the machines near it), if there are any.
local function gymDirection(fromPosition: Vector3): Vector3?
	local sum, count = Vector3.zero, 0
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		-- only the gym next to the spawn (the pro gym is built far away)
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
-- Ready: data loaded
------------------------------------------------------------------------
task.spawn(function()
	local data = ClientData.Get()
	local returning = (data.onboarding.tutorialStep or Onboarding.Done) >= Onboarding.Done
	titlesButton.Visible, settingsButton.Visible = returning, returning
	if returning then
		local okCard, err = pcall(buildCard, data)
		if not okCard then warn("[MenuClient] player card: " .. tostring(err)) end
		info.Visible = true
		local streak = data.daily and data.daily.streak or 0
		if streak > 0 then infoLine(1, "Day " .. streak .. " streak") end
		infoLine(3, "Muscle of the Day: " .. Muscles.GroupById[MuscleOfTheDay.GroupId()].name .. " (" .. MuscleOfTheDay.Multiplier .. "x gains)")
		-- the server pays streak/offline coins right after load; show them when they arrive
		local shownOffline = false
		local function offlineLine()
			local coins = data.welcome and data.welcome.offlineCoins or 0
			if coins > 0 and not shownOffline then
				shownOffline = true
				infoLine(2, "While you were away: +" .. Muscles.FormatExp(coins) .. " coins")
			end
		end
		offlineLine()
		ClientData.Changed:Connect(function(path)
			if path[1] == "welcome" and UIBus.MenuOpen then offlineLine() end
			if path[1] == "daily" and UIBus.MenuOpen then
				for _, child in ipairs(info:GetChildren()) do
					if child:IsA("TextLabel") and child.LayoutOrder == 1 then child:Destroy() end
				end
				infoLine(1, "Day " .. data.daily.streak .. " streak")
			end
		end)
	end
	playLabel.Text = "PLAY"
	Theme.Tween(playButton, { BackgroundTransparency = 0.04 })
	Theme.Tween(playLabel, { TextTransparency = 0 })
	playButton.Active = true
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
	Audio.PlayUI("Whoosh")
	RunService:UnbindFromRenderStep("MenuCamera")

	local function finish()
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
		ContextActionService:UnbindAction("MenuFreeze")
		if mainHud then mainHud.Enabled = true end
		UIBus.MenuOpen = false
		UIBus.MenuClosed:Fire()
		task.spawn(fadeInHud)
	end

	local tween = Theme.Fade(panel, false)
	local card = gui:FindFirstChild("PlayerCard")
	if card then Theme.Fade(card, false) end
	if tween then
		tween.Completed:Connect(function() gui.Enabled = false end)
	end
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
		task.delay(SHOT.ExitTime, finish)
	else
		camera.FieldOfView = baseFov
		finish()
	end
end

playButton.Activated:Connect(play)
titlesButton.Activated:Connect(function() UIBus.OpenTitles:Fire() end)
settingsButton.Activated:Connect(function() UIBus.OpenSettings:Fire() end)

-- Titles/Settings opened from the menu: the menu panel and card step aside so see-through panels never stack
local subPanelOpen = false
UIBus.MenuPanelVisible.Event:Connect(function(visible)
	if not UIBus.MenuOpen or not playButton.Active or subPanelOpen == visible then return end
	subPanelOpen = visible
	for _, frame in ipairs({ panel, gui:FindFirstChild("PlayerCard") }) do
		if visible then
			local fadeOut = Theme.Fade(frame, false)
			if fadeOut then
				-- hidden (not just see-through) so its buttons can't be tapped
				fadeOut.Completed:Connect(function()
					if subPanelOpen then frame.Visible = false end
				end)
			end
		else
			frame.Visible = true
			Theme.Fade(frame, true)
		end
	end
end)
