-- MenuClient: the main menu shown on join (owner's UI v2, mockup 00_main_menu; replaces the live gym tour, the white PLAY
-- button and the pointing hand).
--  * (owner, 15 Oct) The art (Config/UI.MenuArt) fills the screen, pinned right so the character always shows whole, a
--    dark gradient on the left 40%; the 3D logo (UI.Logo3D) top left with a red glow; under it the tagline, the red PLAY
--    CTA (it pulses; its shine sweeps once) and SHOP (players who finished the tutorial, while something is for sale:
--    Play, then the Store opens) / SETTINGS / NEWS (the update notes, a red dot while unread) stacked; the player card
--    bottom left. The loading screen uses the same art and logo, so one fades into the other.
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
local NOT_HUD = { MenuScreen = true, MenuBackground = true, LoadingScreen = true, GeneticsScreen = true, Updates = true }

------------------------------------------------------------------------
-- UI (owner, 15 Oct: new art). Two ScreenGuis:
--   MenuBackground (full screen, no safe-area insets): the art (UI.MenuArt, gym_arc_thumbnail2_nologo) covering the screen,
--     pinned to the RIGHT edge so a narrow / tall screen (iPad) crops the empty left side and the character on the right
--     always shows whole; a dark gradient over the left 40% so the text reads.
--   MenuScreen (inside the safe area, Kit.Root mockup px): top left the 3D logo (UI.Logo3D, ~32% of the screen height)
--     with a soft red glow behind it (the aura's red), "Everyone starts tiny." under it, then the Column: the red PLAY
--     CTA and SHOP (players who finished the tutorial, while something is for sale) / SETTINGS / NEWS (the update notes,
--     red dot while unread) stacked under it, all left of the barbell plate. The player card (headshot, name, level and
--     height, coins) bottom left. Nothing on the right half: the character.
------------------------------------------------------------------------
local COL_W = 172          -- the column's width (mockup px): PLAY and the buttons under it, left of the plate on phones
local LEFT = 24            -- left margin (inside the safe area)

-- the area the background fills: the whole screen, or in Studio the TestPhoneSize phone in the top left (like Kit)
local function stageSize(): Vector2
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local phone = RunService:IsStudio() and Workspace:GetAttribute("TestPhoneSize")
	if typeof(phone) == "Vector2" and phone.X > 0 then
		return phone * math.min(viewport.X / phone.X, viewport.Y / phone.Y)
	end
	return viewport
end

local bgGui = Theme.ScreenGui({ Name = "MenuBackground", DisplayOrder = 19, IgnoreGuiInset = true, Parent = playerGui })
bgGui.ScreenInsets = Enum.ScreenInsets.None
-- (owner, 15 Oct: a gap on the right showed the game: the background was sized in pixels from the camera once, and missed
-- later size changes. Now it is the whole screen by scale, and the art covers it by Crop: nothing to recalculate.)
local back = New("Frame", { Name = "Back", BackgroundColor3 = Color3.fromHex("#0C0A0C"), BorderSizePixel = 0, ClipsDescendants = true, Active = true,
	Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1), Parent = bgGui })
local art = New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = UI.MenuArt, ScaleType = Enum.ScaleType.Crop,
	ResampleMode = Enum.ResamplerMode.Default, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1), Parent = back })
-- the dark gradient over the left 40% (black, fading out to the right)
New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(0.4, 1), ZIndex = 2, Parent = back }, {
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.55, 0.55),
		NumberSequenceKeypoint.new(1, 1) }) }),
})
-- (Studio only: the TestPhoneSize phone in the top left, like Kit; a live game always uses the full-screen scale size)
local function placeArt()
	local phone = RunService:IsStudio() and Workspace:GetAttribute("TestPhoneSize")
	if typeof(phone) == "Vector2" and phone.X > 0 then
		local size = stageSize()
		back.Size = UDim2.fromOffset(size.X, size.Y)
	else
		back.Size = UDim2.fromScale(1, 1)
	end
end
placeArt()
Workspace:GetAttributeChangedSignal("TestPhoneSize"):Connect(placeArt)
task.spawn(function() -- (load the art first, so the menu never shows a plain dark screen)
	pcall(function() game:GetService("ContentProvider"):PreloadAsync({ art }) end)
end)

local gui = Theme.ScreenGui({ Name = "MenuScreen", DisplayOrder = 20, IgnoreGuiInset = true, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local root = Kit.Root(gui)

-- the 3D logo, ~32% of the screen height, with a soft red glow behind it
-- (placed by layoutMenu below: always under Roblox's top bar, so never under its top-left buttons)
local logo = New("ImageLabel", { Name = "Logo", BackgroundTransparency = 1, Image = UI.Logo3D, ScaleType = Enum.ScaleType.Fit, ZIndex = 2,
	Position = UDim2.new(0, LEFT - 6, 0.02, 0), Size = UDim2.fromScale(0.6, 0.32), Parent = root }, {
	New("UIAspectRatioConstraint", { AspectRatio = 432 / 354, DominantAxis = Enum.DominantAxis.Height }),
})
New("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = UI.SoftGlow, ImageColor3 = Color3.fromRGB(255, 45, 40), ImageTransparency = 0.35,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(1.55, 1.45), ZIndex = 1, Parent = logo })

-- the column: tagline, PLAY, then SHOP / SETTINGS / NEWS stacked
local column = New("Frame", { Name = "Column", BackgroundTransparency = 1, Position = UDim2.new(0, LEFT, 0.34, 4), Size = UDim2.fromOffset(COL_W, 180),
	Parent = root }, {
	Theme.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
Kit.Text({ Name = "Tagline", LayoutOrder = 1, Text = "Everyone starts tiny.", Font = "Strong", TextSize = 13, TextColor3 = Color3.fromHex("#E7DEDF"),
	Size = UDim2.fromOffset(COL_W, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = column })

-- PLAY: the red CTA with a play triangle (drawn from thin strips: no glyph, no emoji)
local playButton = Theme.Button("Red", { Name = "Play", LayoutOrder = 2, Size = UDim2.fromOffset(COL_W, 50), Parent = column }, {})
local playRow = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1 - Theme.LipHeight, 0), Parent = playButton }, {
	Theme.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local triangle = New("Frame", { Name = "Triangle", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 15), Parent = playRow })
for row = 0, 14 do
	local width = 12 * (1 - math.abs(row - 7) / 7.5)
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(0, row), Size = UDim2.fromOffset(width, 1), Parent = triangle })
end
Kit.Text({ Name = "Label", LayoutOrder = 2, Text = "Play", Font = "Title", TextSize = 30, Upper = true, Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X, Parent = playRow })
playButton.Active = false

local shopButton = Kit.Button("Gold", "Shop", { Name = "Shop", LayoutOrder = 3, Visible = false, Parent = column },
	{ width = COL_W, height = 30, textSize = 14, icon = "shopping-cart" })
local settingsButton = Kit.Button("Quiet", "Settings", { Name = "Settings", LayoutOrder = 4, Parent = column },
	{ width = COL_W, height = 30, textSize = 14, icon = "settings" })
local updatesButton = Kit.Button("Quiet", "News", { Name = "Updates", LayoutOrder = 5, Parent = column },
	{ width = COL_W, height = 30, textSize = 14, icon = "bell" })
local newsDot = New("Frame", { Name = "NewsDot", BackgroundColor3 = Colors.Red, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -7, 0, 6), Size = UDim2.fromOffset(9, 9), Visible = false, ZIndex = 4, Parent = New("Folder", { Name = "Dot", Parent = updatesButton }) }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
})

-- the player card, bottom left: headshot, name, level and height, coins
local card = Theme.Panel({ Name = "Card", Piece = "hud_box", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, LEFT, 1, -12),
	Size = UDim2.fromOffset(236, 48), Visible = false, Parent = root })
Kit.Headshot(player.UserId, player.DisplayName, 34, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = card })
Kit.Text({ Name = "PlayerName", Text = player.DisplayName, Font = "Strong", TextSize = 14, Position = UDim2.fromOffset(50, 7), Size = UDim2.fromOffset(110, 18),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
local cardSub = Kit.Text({ Name = "Sub", Text = "", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(50, 25), Size = UDim2.fromOffset(120, 15),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
local coinRow = New("Frame", { Name = "Coins", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(80, 24), Parent = card }, {
	Theme.List(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
})
Kit.Coin(16, { LayoutOrder = 1, Parent = coinRow })
local coinText = Kit.Text({ Name = "Amount", LayoutOrder = 2, Text = "0", Font = "Number", TextSize = 15, Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X, Parent = coinRow })

-- Logo, column and card from the top bar down (owner, 15 Oct: the logo sat under Roblox's top-left buttons): the logo
-- starts at TopbarInset.Max.Y + 8, the column right under it; the logo shrinks (down to 60 mockup px) so everything
-- fits, and when the card has no room under the column it moves beside it (bottom). Again on every scale / top bar change.
local LOGO_ASPECT = 432 / 354
local function layoutMenu()
	local s = math.max(Kit.Scale(), 0.01)
	local rootH = root.AbsoluteSize.Y / s
	if rootH < 10 then return end
	local top = Kit.UnderTopbar(root)
	local list = column:FindFirstChildOfClass("UIListLayout")
	local colH = list and list.AbsoluteContentSize.Y / s or 180
	if colH < 10 then colH = 180 end
	local cardH, logoMax = 48, math.max(60, rootH * 0.32)
	local stacked = rootH - top - 4 - colH - 10 - cardH - 12
	local beside = stacked < math.min(logoMax, 100)
	local logoH = math.clamp(if beside then rootH - top - 4 - colH - 12 else stacked, 60, logoMax)
	logo.Size = UDim2.fromOffset(logoH * LOGO_ASPECT, logoH)
	logo.Position = UDim2.new(0, LEFT - 6, 0, top)
	column.Position = UDim2.new(0, LEFT, 0, top + logoH + 4)
	card.Position = if beside then UDim2.new(0, LEFT + COL_W + 12, 1, -12) else UDim2.new(0, LEFT, 1, -12)
end
Kit.OnTopbar(layoutMenu)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutMenu)
do
	local list = column:FindFirstChildOfClass("UIListLayout")
	if list then list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(layoutMenu) end
end

-- The logo, the column and the card slide in from a little to the left, fading in (no CanvasGroup: text stays crisp)
local function reveal()
	layoutMenu()
	for index, piece in ipairs({ logo, column, card }) do
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

settingsButton.Activated:Connect(function()
	Audio.PlayUI("Click")
	UIBus.OpenSettings:Fire()
end)

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
	shopButton.Visible = Monetization.AnyConfigured() -- (owner, 20 Oct: the Shop always shows, new players too)
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
	game:GetService("TweenService"):Create(art, info, { ImageTransparency = 1 }):Play()
	game:GetService("TweenService"):Create(back, info, { BackgroundTransparency = 1 }):Play()
	Theme.Fade(logo, false, TIMING.Fade)
	Theme.Fade(column, false, TIMING.Fade)
	Theme.Fade(card, false, TIMING.Fade)
	for _, item in ipairs(back:GetDescendants()) do
		if item:IsA("Frame") then game:GetService("TweenService"):Create(item, info, { BackgroundTransparency = 1 }):Play() end
	end
	task.delay(TIMING.Fade, function()
		gui.Enabled = false
		bgGui.Enabled = false
	end)
	if thenShop then
		task.delay(TIMING.Fade + 0.2, function() UIBus.OpenShop:Fire("Passes") end)
	end
end

playButton.Activated:Connect(function() play(false) end)
shopButton.Activated:Connect(function() play(true) end)
