-- MenuClient: the main menu shown on join (owner's UI v2, mockup 00_main_menu; replaces the live gym tour, the white PLAY
-- button and the pointing hand).
--  * The picture: the menu art (Config/UI.MenuArt) on the right fading into the dark on its left, over a dim soft copy of
--    it (the same picture as the loading screen, so one fades into the other).
--  * On the left: the GYM ARC logo (GYM white, ARC red) and "Everyone starts tiny.", a big green PLAY, under it a gold SHOP
--    (players who finished the tutorial, only while something is for sale: Play, then the Gym Store opens) and a blue
--    UPDATES (a window with the latest update notes, Config/UI.Updates), and a small pill at the bottom: coins | LVL | height.
-- Start: ReplicatedFirst's LoadingScreen covers everything until this script has the save data and has streamed in the
-- area around your character (Player:RequestStreamAroundAsync), then sets the LocalPlayer attribute "MenuReady";
-- "MenuLoad" (0..1) feeds its bar. Movement is frozen and the HUD hidden while the menu is up.
-- Play: the menu fades, the camera is behind your character, the HUD fades in (UIBus.MenuClosed).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIBus = require(Shared:WaitForChild("UI"):WaitForChild("UIBus"))
UIBus.MenuOpen = true -- set first, before anything else loads, so other scripts wait for Play

local Onboarding = require(Shared.Config.Onboarding)
local Monetization = require(Shared.Config.Monetization)
local Muscles = require(Shared.Config.Muscles)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local UI = require(Shared.Config.UI)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors

local TIMING = { StreamTimeout = 8, Fade = 0.4, HudFade = 0.35, Slide = 0.35 }
-- full-screen and menu UIs that are not part of the HUD fade-in after Play
local NOT_HUD = { MenuScreen = true, LoadingScreen = true, GeneticsScreen = true, Updates = true }

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "MenuScreen", DisplayOrder = 20, IgnoreGuiInset = true, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None
local back = New("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#0C0A0C"), BorderSizePixel = 0, Active = true, Parent = gui })
New("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = UI.MenuArt, ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.9, ImageColor3 = Color3.fromRGB(110, 90, 90),
	Size = UDim2.fromScale(1, 1), Parent = back })
New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = UI.MenuArt, ScaleType = Enum.ScaleType.Crop, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.62, 1), Parent = back }, {
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 0.2),
		NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 0) }) }),
})

local root = Kit.Root(gui)
local column = New("Frame", { Name = "Column", BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(0, 330, 1, 0), Parent = root })

-- the logo
local logo = New("Frame", { Name = "Logo", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.fromOffset(380, 82), Parent = column }, {
	Theme.List(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
local function logoWord(order: number, text: string, color: Color3)
	local word = Kit.Text({ Name = text, LayoutOrder = order, Text = text, Font = "Title", TextSize = 76, TextColor3 = color, Size = UDim2.fromOffset(0, 82),
		AutomaticSize = Enum.AutomaticSize.X, Parent = logo })
	local stroke = word:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Thickness = 4 end
	return word
end
logoWord(1, "GYM", Colors.Text)
logoWord(2, "ARC", Colors.Red)
Kit.Text({ Name = "Tagline", Text = "Everyone starts tiny.", Font = "Title", TextSize = 18, Position = UDim2.fromOffset(2, 130), Size = UDim2.fromOffset(330, 24),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = column })

-- the buttons
local playButton = Kit.Button("Green", "Play", { Name = "Play", Position = UDim2.fromOffset(0, 172), Parent = column }, { width = 250, height = 58, textSize = 32 })
playButton.Active = false
local shopButton = Kit.Button("Gold", "Shop", { Name = "Shop", Position = UDim2.fromOffset(0, 242), Visible = false, Parent = column }, { width = 120, height = 36, textSize = 17 })
local updatesButton = Kit.Button("Blue", "Updates", { Name = "Updates", Position = UDim2.fromOffset(130, 242), Parent = column }, { width = 120, height = 36, textSize = 17 })

-- the pill: coins | LVL | height
local pill = Theme.Panel({ Name = "Info", Piece = "pill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -22), Size = UDim2.fromOffset(0, 34),
	AutomaticSize = Enum.AutomaticSize.X, Visible = false, Parent = column }, {
	New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
	Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
Kit.Coin(18, { LayoutOrder = 1, Parent = pill })
local pillText = Kit.Text({ Name = "Text", LayoutOrder = 2, Text = "", Font = "Body", TextSize = 14, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X,
	Parent = pill })

-- The column slides in: each piece from a little to the left, fading in (no CanvasGroup: text stays crisp)
local function reveal()
	local pieces = { logo, column:FindFirstChild("Tagline"), playButton, shopButton, updatesButton, pill }
	for index, piece in ipairs(pieces) do
		if piece and piece.Visible then
			local goal = piece.Position
			piece.Position = goal - UDim2.fromOffset(24, 0)
			task.delay((index - 1) * 0.06, function()
				Theme.Tween(piece, { Position = goal }, TIMING.Slide)
				Theme.Fade(piece, true, TIMING.Slide)
			end)
		end
	end
end

-- The PLAY button breathes: a soft scale pulse (one button's UIScale only)
local function playAlive()
	local scale = playButton:FindFirstChild("Breath") or New("UIScale", { Name = "Breath", Parent = playButton })
	task.spawn(function()
		while playButton.Parent and UIBus.MenuOpen do
			Theme.Tween(scale, { Scale = 1.035 }, 1.1, Enum.EasingStyle.Sine)
			task.wait(1.1)
			Theme.Tween(scale, { Scale = 1 }, 1.1, Enum.EasingStyle.Sine)
			task.wait(1.1)
		end
	end)
end

------------------------------------------------------------------------
-- UPDATES: the latest update notes
------------------------------------------------------------------------
local updates = Kit.Modal({ name = "Updates", title = "Updates", icon = "bell", width = 500, height = 280, displayOrder = 40,
	tabs = { { id = "Updates", text = "What's new", icon = "sparkles" } } })
local updateList = New("ScrollingFrame", { Name = "List", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Colors.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, Parent = updates.body }, {
	Theme.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
})
for order, entry in ipairs(UI.Updates or {}) do
	local card = Kit.Card({ Name = "Update" .. order, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = updateList }, {
		New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		Theme.List(Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	Kit.Text({ LayoutOrder = 1, Text = entry.title .. "  ·  " .. entry.date, Font = "Title", TextSize = 16, TextColor3 = Colors.Gold, Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	for index, line in ipairs(entry.lines or {}) do
		Kit.Text({ LayoutOrder = 1 + index, Text = "• " .. line, Font = "Body", TextSize = 13, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	end
end
updatesButton.Activated:Connect(function()
	Audio.PlayUI("Click")
	updates.open()
end)

------------------------------------------------------------------------
-- Freeze movement and hide the HUD while the menu is up
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
-- Load: the save data and the world around you, then let the loading screen go
------------------------------------------------------------------------
local function levelOf(data): number
	local total, count = 0, 0
	for _, muscle in ipairs(Muscles.List) do
		total += Muscles.ExactLevel(data.muscles and data.muscles[muscle.id])
		count += 1
	end
	return math.floor(count > 0 and total / count or 0)
end
local function refreshPill(data)
	local height = GrowthSpurts.FormatHeight(GrowthSpurts.GetHeight(data.growthSpurts or 0))
	pillText.Text = string.format("%s  |  LVL %d  |  %s", Kit.Format(data.coins or 0), levelOf(data), height)
end

task.spawn(function()
	player:SetAttribute("MenuLoad", 0.1)
	local data = ClientData.Get()
	player:SetAttribute("MenuLoad", 0.4)
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	player:SetAttribute("MenuLoad", 0.6)
	if rootPart and rootPart:IsA("BasePart") then
		local ok, err = pcall(function()
			player:RequestStreamAroundAsync(rootPart.Position, TIMING.StreamTimeout)
		end)
		if not ok then warn("[MenuClient] streaming around the character: " .. tostring(err)) end
	end
	player:SetAttribute("MenuLoad", 1)

	local returning = (data.onboarding.tutorialStep or Onboarding.Done) >= Onboarding.Done
	shopButton.Visible = returning and Monetization.AnyConfigured()
	if not shopButton.Visible then updatesButton.Position = UDim2.fromOffset(0, 242) end
	pill.Visible = returning
	refreshPill(data)
	ClientData.Changed:Connect(function(path)
		if UIBus.MenuOpen and (path[1] == "coins" or path[1] == "muscles" or path[1] == "growthSpurts") then refreshPill(ClientData.Get()) end
	end)
	player:SetAttribute("MenuReady", true)

	-- the column slides in as the loading screen fades
	while playerGui:FindFirstChild("LoadingScreen") and not player:GetAttribute("LoadingDone") do task.wait(0.05) end
	reveal()
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
				if piece:IsA("GuiObject") and piece.Visible then Theme.Fade(piece, true, TIMING.HudFade) end
			end
		end
	end
end

local function play(thenShop: boolean?)
	if not UIBus.MenuOpen or not playButton.Active then return end
	playButton.Active = false
	updates.close()
	Audio.PlayUI("Whoosh")
	-- the camera behind the character, far enough to see all of them (a 7'0" character needs more room than a 4'0" one)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		local height = character:GetExtentsSize().Y
		local behind = rootPart.CFrame * CFrame.new(0, height * 0.45, math.max(11, height * 1.9))
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(behind.Position, rootPart.Position + Vector3.new(0, height * 0.25, 0))
	end
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then camera.CameraSubject = humanoid end
	ContextActionService:UnbindAction("MenuFreeze")
	if mainHud then mainHud.Enabled = true end
	UIBus.MenuOpen = false
	UIBus.MenuClosed:Fire()
	task.spawn(fadeInHud)
	-- the menu fades away over the gym
	local info = TweenInfo.new(TIMING.Fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, item in ipairs(gui:GetDescendants()) do
		if item:IsA("ImageLabel") then
			game:GetService("TweenService"):Create(item, info, { ImageTransparency = 1 }):Play()
		end
	end
	game:GetService("TweenService"):Create(back, info, { BackgroundTransparency = 1 }):Play()
	Theme.Fade(column, false, TIMING.Fade)
	task.delay(TIMING.Fade, function() gui.Enabled = false end)
	if thenShop then
		task.delay(TIMING.Fade + 0.2, function() UIBus.OpenShop:Fire("Passes") end)
	end
end

playButton.Activated:Connect(function() play(false) end)
shopButton.Activated:Connect(function() play(true) end)
