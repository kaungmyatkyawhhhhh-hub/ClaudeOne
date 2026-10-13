-- MenuClient: the main menu shown on join (owner's UI v2, mockup 00_main_menu; replaces the live gym tour, the white PLAY
-- button and the pointing hand).
--  * The picture: the menu art (Config/UI.MenuArt) on the right fading into the dark on its left, over a dim soft copy of
--    it (the same picture as the loading screen, so one fades into the other).
--  * On the left, vertically centered (owner, 14 Oct: the NEW mockup 00_main_menu, clean and dark): SEASON 1 · NOW LIVE,
--    the GYM ARC logo (GYM white, ARC red, a small drop shadow), a red rule + "Everyone starts tiny.", a red PLAY, under
--    it two dark buttons: SHOP (gold cart; players who finished the tutorial, only while something is for sale: Play,
--    then the Gym Store opens) and UPDATES (bell, a red dot while there's news; a window with Config/UI.Updates), and the
--    player card (returning players): the real avatar headshot, name, LEVEL · height, coins. "v1.0 · Update 1" bottom right.
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
local Pieces = require(Shared.UI.Pieces)
local Audio = require(Shared.Audio)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors

local TIMING = { StreamTimeout = 8, Fade = 0.4, HudFade = 0.35, Slide = 0.35 }
-- full-screen and menu UIs that are not part of the HUD fade-in after Play
local NOT_HUD = { MenuScreen = true, LoadingScreen = true, GeneticsScreen = true, Updates = true }

------------------------------------------------------------------------
-- UI (owner, 14 Oct: the NEW mockup 00_main_menu, clean and dark, not a simulator: no black text outlines, no glossy
-- buttons; Oswald bold UPPERCASE on buttons, Montserrat for small text). Drawn in mockup px inside Kit.Root.
------------------------------------------------------------------------
local MENU = {
	Back = Color3.fromHex("#0C0A0C"),
	Surface = Color3.fromHex("#141113"), -- the dark buttons and the player card
	Edge = Color3.new(1, 1, 1), EdgeTransparency = 0.87,
	Red = Color3.fromHex("#E4262F"), RedDark = Color3.fromHex("#A5161D"),
	Gold = Color3.fromHex("#F5B62F"),
	Text = Color3.fromHex("#F6F3F3"), Soft = Color3.fromHex("#C9C2C4"), Muted = Color3.fromHex("#9D9396"), Faint = Color3.fromHex("#6F6669"),
	Oswald = "rbxasset://fonts/families/Oswald.json",
	Montserrat = "rbxasset://fonts/families/Montserrat.json",
	Logo = "rbxasset://fonts/families/LuckiestGuy.json",
	Width = 268, -- the column's buttons and card
}
local function font(family: string, weight: Enum.FontWeight?): Font
	return Font.new(family, weight or Enum.FontWeight.Regular)
end
-- letter-spaced caps ("S E A S O N"), since a TextLabel has no letter spacing
local function spaced(text: string, gap: string?): string
	local out = {}
	for _, word in ipairs(string.split(string.upper(text), " ")) do
		table.insert(out, (string.gsub(word, "(.)", "%1" .. (gap or "\u{200A}"))))
	end
	return table.concat(out, "  ")
end
-- plain text: no outline (this screen only)
local function label(props)
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return New("TextLabel", props)
end

local gui = Theme.ScreenGui({ Name = "MenuScreen", DisplayOrder = 20, IgnoreGuiInset = true, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None
local back = New("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = MENU.Back, BorderSizePixel = 0, Active = true, Parent = gui })
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
-- the dark fade behind the column (black, never colored), so the text always reads
New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(0.62, 1), ZIndex = 3, Parent = back }, {
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 1) }) }),
})
task.spawn(function() -- (load the art first, so the menu never shows a plain dark screen)
	pcall(function() game:GetService("ContentProvider"):PreloadAsync({ back }) end)
end)

local root = Kit.Root(gui)
-- the left column, vertically centered
local column = New("Frame", { Name = "Column", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 52, 0.5, 0),
	Size = UDim2.fromOffset(MENU.Width, 296), Parent = root })

local season = label({ Name = "Season", Text = spaced("Season 1", "\u{2009}") .. "   \u{00B7}   " .. spaced("Now live", "\u{2009}"), FontFace = font(MENU.Oswald, Enum.FontWeight.SemiBold),
	TextSize = 12, TextColor3 = MENU.Gold, Size = UDim2.fromOffset(MENU.Width, 14), Parent = column })

-- the logo: GYM white, ARC red, a small soft drop shadow (no thick outline)
local logo = New("Frame", { Name = "Logo", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(MENU.Width + 40, 58), Parent = column })
local function logoWord(text: string, color: Color3, x: number)
	local props = { Text = text, FontFace = font(MENU.Logo), TextSize = 56, Size = UDim2.fromOffset(0, 58), AutomaticSize = Enum.AutomaticSize.X }
	local shadow = label(table.clone(props))
	shadow.Name, shadow.TextColor3, shadow.TextTransparency = text .. "Shadow", Color3.new(0, 0, 0), 0.55
	shadow.Position = UDim2.fromOffset(x + 2, 3)
	shadow.Parent = logo
	local word = label(props)
	word.Name, word.TextColor3, word.Position, word.ZIndex = text, color, UDim2.fromOffset(x, 0), 2
	word.Parent = logo
	return word
end
local gym = logoWord("GYM", MENU.Text, 0)
New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("#D9D3D4")), Parent = gym })
logoWord("ARC", MENU.Red, 0)
-- ARC sits right after GYM, whatever the font measures
local function placeArc()
	local x = gym.AbsoluteSize.X / math.max(Kit.Scale(), 0.01) + 14
	logo.ARC.Position = UDim2.fromOffset(x, 0)
	logo.ARCShadow.Position = UDim2.fromOffset(x + 2, 3)
end
gym:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeArc)
task.defer(placeArc)

-- a short red line and the tagline
local tagline = New("Frame", { Name = "Tagline", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 86), Size = UDim2.fromOffset(MENU.Width, 20), Parent = column }, {
	New("Frame", { Name = "Rule", BackgroundColor3 = MENU.Red, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(26, 3) }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
})
label({ Name = "Text", Text = "Everyone starts tiny.", FontFace = font(MENU.Montserrat, Enum.FontWeight.Medium), TextSize = 15, TextColor3 = MENU.Soft,
	Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 1, 0), Parent = tagline })

-- a flat button: a color face over a 3px darker bottom edge (pressed = the face goes down and the edge goes)
local function flatButton(name: string, props: { [string]: any }, face: Color3, edge: Color3, faceProps: { [string]: any }?)
	props.Name = name
	props.Text, props.AutoButtonColor, props.BackgroundColor3, props.BorderSizePixel = "", false, edge, 0
	local button = New("TextButton", props, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	local f = New("Frame", { Name = "Face", BackgroundColor3 = face, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -3), Parent = button }, {
		New("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
	for key, value in pairs(faceProps or {}) do (f :: any)[key] = value end
	button.MouseButton1Down:Connect(function()
		f.Position, f.Size = UDim2.fromOffset(0, 2), UDim2.new(1, 0, 1, -2)
	end)
	local function release() f.Position, f.Size = UDim2.new(), UDim2.new(1, 0, 1, -3) end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return button, f
end

-- PLAY: red, 52 tall, a play triangle (drawn from thin strips: no glyph, no emoji) and spaced PLAY, a soft shadow
local playButton, playFace = flatButton("Play", { Position = UDim2.fromOffset(0, 124), Size = UDim2.fromOffset(MENU.Width, 52), Parent = column },
	Color3.new(1, 1, 1), MENU.RedDark)
New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromHex("#F0373F"), Color3.fromHex("#C91D25")), Parent = playFace })
New("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 5),
	Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = playButton }, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
local playRow = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = playFace }, {
	Theme.List(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local triangle = New("Frame", { Name = "Triangle", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 15), Parent = playRow })
for row = 0, 14 do
	local width = 12 * (1 - math.abs(row - 7) / 7.5)
	New("Frame", { BackgroundColor3 = MENU.Text, BorderSizePixel = 0, Position = UDim2.fromOffset(0, row), Size = UDim2.fromOffset(width, 1), Parent = triangle })
end
label({ Name = "Label", LayoutOrder = 2, Text = spaced("Play", "\u{2009}"), FontFace = font(MENU.Oswald, Enum.FontWeight.Bold), TextSize = 25, TextColor3 = MENU.Text,
	Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Parent = playRow })
playButton.Active = false

-- SHOP and UPDATES: dark, a thin light border, an icon and spaced Oswald
local function darkButton(name: string, icon: string, iconColor: Color3, text: string, x: number)
	local button, face = flatButton(name, { Position = UDim2.fromOffset(x, 188), Size = UDim2.fromOffset(129, 40), Parent = column },
		MENU.Surface, Color3.fromHex("#080607"))
	New("UIStroke", { Color = MENU.Edge, Transparency = MENU.EdgeTransparency, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = face })
	local row = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = face }, {
		Theme.List(Enum.FillDirection.Horizontal, 9, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	Pieces.Icon(icon, iconColor, { LayoutOrder = 1, Size = UDim2.fromOffset(16, 16), Parent = row }):SetAttribute("KeepColor", true)
	label({ Name = "Label", LayoutOrder = 2, Text = spaced(text), FontFace = font(MENU.Oswald, Enum.FontWeight.Bold), TextSize = 15, TextColor3 = MENU.Text,
		Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Parent = row })
	return button, face
end
local shopButton = darkButton("Shop", "shopping-cart", MENU.Gold, "Shop", 0)
shopButton.Visible = false
local updatesButton, updatesFace = darkButton("Updates", "bell", MENU.Text, "Updates", 139)
-- the red dot: there's news the player hasn't opened yet (Config/UI.Updates[1].date, remembered in the save's settings)
local newsDot = New("Frame", { Name = "NewsDot", BackgroundColor3 = MENU.Red, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -9, 0, 9), Size = UDim2.fromOffset(7, 7), Visible = false, Parent = updatesFace }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
})

-- the player card: headshot, name, LEVEL · height, coins on the right
local card = New("Frame", { Name = "Card", BackgroundColor3 = MENU.Surface, BackgroundTransparency = 0.06, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 240),
	Size = UDim2.fromOffset(MENU.Width, 56), Visible = false, Parent = column }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIStroke", { Color = MENU.Edge, Transparency = MENU.EdgeTransparency, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
Kit.Headshot(player.UserId, player.DisplayName, 34, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Parent = card })
label({ Name = "PlayerName", Text = player.DisplayName, FontFace = font(MENU.Montserrat, Enum.FontWeight.Bold), TextSize = 14, TextColor3 = MENU.Text,
	TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(56, 10), Size = UDim2.fromOffset(110, 18), Parent = card })
local cardSub = label({ Name = "Sub", Text = "", FontFace = font(MENU.Montserrat, Enum.FontWeight.SemiBold), TextSize = 11, TextColor3 = MENU.Muted,
	Position = UDim2.fromOffset(56, 29), Size = UDim2.fromOffset(110, 16), Parent = card })
local coinRow = New("Frame", { Name = "Coins", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8),
	Size = UDim2.fromOffset(110, 22), Parent = card }, {
	Theme.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
})
Kit.Coin(16, { LayoutOrder = 1, Parent = coinRow })
local coinText = label({ Name = "Amount", LayoutOrder = 2, Text = "0", FontFace = font(MENU.Oswald, Enum.FontWeight.SemiBold), TextSize = 19, TextColor3 = MENU.Text,
	Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Parent = coinRow })
label({ Name = "CoinsWord", Text = spaced("Coins"), FontFace = font(MENU.Montserrat, Enum.FontWeight.SemiBold), TextSize = 10, TextColor3 = MENU.Muted,
	TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 32), Size = UDim2.fromOffset(110, 14), Parent = card })

-- the version, small at the bottom right
local version = label({ Name = "Version", Text = UI.MenuVersion or "v1.0 \u{00B7} Update 1", FontFace = font(MENU.Montserrat, Enum.FontWeight.Medium), TextSize = 11,
	TextColor3 = MENU.Muted, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -14),
	Size = UDim2.fromOffset(240, 14), Parent = root })

-- The column slides in: each piece from a little to the left, fading in (no CanvasGroup: text stays crisp)
local function reveal()
	local pieces = { season, logo, tagline, playButton, shopButton, updatesButton, card, version }
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
			Theme.Tween(scale, { Scale = 1.025 }, 1.1, Enum.EasingStyle.Sine)
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
	cardSub.Text = string.format("LEVEL %d  ·  %s", levelOf(data), height)
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
	if not shopButton.Visible then updatesButton.Position = UDim2.fromOffset(0, 188) end
	card.Visible = returning
	newsDot.Visible = UI.UpdatesStamp ~= nil and (data.settings and data.settings.updatesSeen) ~= UI.UpdatesStamp
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
