-- MenuClient: the main menu shown on join (owner's UI v2, mockup 00_main_menu; replaces the live gym tour, the white PLAY
-- button and the pointing hand).
--  * The picture: the menu art (Config/UI.MenuArt) on the right fading into the dark on its left, over a dim soft copy of
--    it (the same picture as the loading screen, so one fades into the other).
--  * On the left, vertically centered (owner's final kit "BLACK + GOLD", mockup 00_title): ONE graphite panel with the
--    GYM ARC logo (GYM white, ARC red), "Everyone starts tiny.", the red PLAY CTA (it pulses; its shine sweeps once), a
--    gold SHOP (players who finished the tutorial, only while something is for sale: Play, then the Store opens) and a
--    quiet UPDATES (a red dot while there's news; a window with Config/UI.Updates), a thin divider and the player row
--    (returning players): the real avatar headshot, name, "Level 27 · 6'4"", coins. Bottom right: a small NEW tag with
--    the newest update's name (tap = the update notes).
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
-- UI (owner's final kit "BLACK + GOLD", mockup gym_arc_ui_final/00_title): one graphite panel on the left with the logo,
-- the tagline, the red PLAY CTA, a gold SHOP and a quiet UPDATES (red dot), a thin divider and the player row (the real
-- avatar headshot, name, "Level 27 · 6'4"", coins); a small "NEW · <latest update>" tag bottom-right. Drawn in mockup px
-- inside Kit.Root with the Theme / Kit pieces.
------------------------------------------------------------------------
local PANEL = Vector2.new(290, 292)

local gui = Theme.ScreenGui({ Name = "MenuScreen", DisplayOrder = 20, IgnoreGuiInset = true, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None
local back = New("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#0C0A0C"), BorderSizePixel = 0, Active = true, Parent = gui })
-- the soft dark copy filling the whole screen (a blur made of four offset, faint copies)
for index, offset in ipairs({ Vector2.new(-10, -6), Vector2.new(10, -6), Vector2.new(-10, 6), Vector2.new(10, 6) }) do
	New("ImageLabel", { Name = "Soft" .. index, BackgroundTransparency = 1, Image = UI.MenuArt, ScaleType = Enum.ScaleType.Crop,
		ImageTransparency = 0.8, ImageColor3 = Color3.fromRGB(120, 90, 90), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, offset.X, 0.5, offset.Y), Size = UDim2.new(1, 40, 1, 40), Parent = back })
end
-- the art on the right, fading into the dark on its left
New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = UI.MenuArt, ScaleType = Enum.ScaleType.Crop, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.68, 1), ZIndex = 2, Parent = back }, {
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(1, 0) }) }),
})
-- the dark fade behind the panel (black, never colored)
New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(0.55, 1), ZIndex = 3, Parent = back }, {
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1) }) }),
})
task.spawn(function() -- (load the art first, so the menu never shows a plain dark screen)
	pcall(function() game:GetService("ContentProvider"):PreloadAsync({ back }) end)
end)

local root = Kit.Root(gui)
-- the graphite panel, vertically centered on the left
local column = Theme.Panel({ Name = "Column", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 46, 0.5, 0), Size = UDim2.fromOffset(PANEL.X, PANEL.Y),
	Parent = root })

-- the logo image (Config/UI.Logo: GYM white, ARC red)
New("ImageLabel", { Name = "Logo", BackgroundTransparency = 1, Image = UI.Logo, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(PANEL.X - 40, 64), Parent = column })
Kit.Text({ Name = "Tagline", Text = "Everyone starts tiny.", Font = "Strong", TextSize = 13, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(0, 84),
	Size = UDim2.new(1, 0, 0, 18), Parent = column })

-- PLAY: the red CTA with a play triangle (drawn from thin strips: no glyph, no emoji)
local playButton = Theme.Button("Red", { Name = "Play", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(PANEL.X - 36, 54),
	Parent = column }, {})
local playRow = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1 - Theme.LipHeight, 0), Parent = playButton }, {
	Theme.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local triangle = New("Frame", { Name = "Triangle", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 15), Parent = playRow })
for row = 0, 14 do
	local width = 12 * (1 - math.abs(row - 7) / 7.5)
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(0, row), Size = UDim2.fromOffset(width, 1), Parent = triangle })
end
Kit.Text({ Name = "Label", LayoutOrder = 2, Text = "Play", Font = "Title", TextSize = 32, Upper = true, Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X, Parent = playRow })
playButton.Active = false

-- SHOP (gold) and UPDATES (quiet, a red dot while there's news)
local halfW = (PANEL.X - 36 - 10) / 2
local shopButton = Kit.Button("Gold", "Shop", { Name = "Shop", Position = UDim2.fromOffset(18, 176), Visible = false, Parent = column },
	{ width = halfW, height = 40, textSize = 17 })
local updatesButton = Kit.Button("Quiet", "Updates", { Name = "Updates", Position = UDim2.fromOffset(18 + halfW + 10, 176), Parent = column },
	{ width = halfW, height = 40, textSize = 17, icon = "bell" })
local newsDot = New("Frame", { Name = "NewsDot", BackgroundColor3 = Colors.Red, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -7, 0, 6), Size = UDim2.fromOffset(9, 9), Visible = false, ZIndex = 4, Parent = New("Folder", { Name = "Dot", Parent = updatesButton }) }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
})

-- the divider and the player row: headshot, name, "Level 27 · 6'4"", coins
local card = New("Frame", { Name = "Card", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 228), Size = UDim2.new(1, -36, 0, 52), Visible = false, Parent = column })
New("Frame", { Name = "Divider", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = card })
Kit.Headshot(player.UserId, player.DisplayName, 34, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 4), Parent = card })
Kit.Text({ Name = "PlayerName", Text = player.DisplayName, Font = "Strong", TextSize = 14, Position = UDim2.fromOffset(44, 14), Size = UDim2.fromOffset(120, 18),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
local cardSub = Kit.Text({ Name = "Sub", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(44, 32), Size = UDim2.fromOffset(130, 15),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
local coinRow = New("Frame", { Name = "Coins", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 4),
	Size = UDim2.fromOffset(110, 24), Parent = card }, {
	Theme.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
})
Kit.Coin(18, { LayoutOrder = 1, Parent = coinRow })
local coinText = Kit.Text({ Name = "Amount", LayoutOrder = 2, Text = "0", Font = "Number", TextSize = 17, Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X, Parent = coinRow })

-- bottom right: a small dark pill with a gold NEW tag and the newest update's name (tap = the update notes)
local newest = UI.Updates and UI.Updates[1]
local version = Theme.Panel({ Name = "News", Piece = "hud_box", Clickable = true, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -16),
	Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Visible = newest ~= nil, Parent = root }, {
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14) }),
	Theme.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
local newTag = New("Frame", { Name = "New", LayoutOrder = 1, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = version }, {
	New("UICorner", { CornerRadius = UDim.new(0, 5) }),
	New("UIGradient", { Rotation = 90, Color = Theme.GoldSequence }),
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
})
Kit.Text({ Name = "Text", Text = "NEW", Font = "Title", TextSize = 12, TextColor3 = Colors.Ink, Stroke = false, Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X, Parent = newTag })
Kit.Text({ Name = "Title", LayoutOrder = 2, Text = newest and newest.title or "", Font = "Title", TextSize = 15, Upper = true, Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X, Parent = version })

-- The panel slides in from a little to the left, fading in (no CanvasGroup: text stays crisp)
local function reveal()
	for index, piece in ipairs({ column, version }) do
		if piece.Visible then
			local goal = piece.Position
			piece.Position = goal - UDim2.fromOffset(24, 0)
			task.delay((index - 1) * 0.08, function()
				Theme.Tween(piece, { Position = goal }, TIMING.Slide)
				Theme.Fade(piece, true, TIMING.Slide)
			end)
		end
	end
	task.delay(TIMING.Slide, function() Theme.ShineAll(column) end) -- (the PLAY shine sweeps across once)
end

-- PLAY pulses (the featured CTA) while the menu is up
local function playAlive()
	Theme.Pulse(playButton, function() return UIBus.MenuOpen end)
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
version.Activated:Connect(function()
	Audio.PlayUI("Click")
	updates.open()
end)
updatesButton.Activated:Connect(function()
	Audio.PlayUI("Click")
	updates.open()
	if newsDot.Visible then
		newsDot.Visible = false
		ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayerAction"):FireServer("SetSettings", { updatesSeen = UI.UpdatesStamp })
	end
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
	cardSub.Text = string.format("Level %d · %s", levelOf(data), height)
	coinText.Text = Kit.Format(data.coins or 0)
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
	if not shopButton.Visible then
		-- (no shop: UPDATES takes the whole row)
		updatesButton.Position = UDim2.fromOffset(18, 176)
		updatesButton.Size = UDim2.fromOffset(PANEL.X - 36, 40)
	end
	card.Visible = returning
	newsDot.Visible = UI.UpdatesStamp ~= nil and (data.settings and data.settings.updatesSeen) ~= UI.UpdatesStamp
	refreshPill(data)
	Audio.AdoptMenuMusic() -- (the loading screen's track keeps playing here, now at the player's music volume)
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
	Audio.StopMenuMusic(1.2) -- (the area music starts under the fade)
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
	Theme.Fade(version, false, TIMING.Fade)
	for _, item in ipairs(back:GetDescendants()) do
		if item:IsA("Frame") then game:GetService("TweenService"):Create(item, info, { BackgroundTransparency = 1 }):Play() end
	end
	task.delay(TIMING.Fade, function() gui.Enabled = false end)
	if thenShop then
		task.delay(TIMING.Fade + 0.2, function() UIBus.OpenShop:Fire("Passes") end)
	end
end

playButton.Activated:Connect(function() play(false) end)
shopButton.Activated:Connect(function() play(true) end)
