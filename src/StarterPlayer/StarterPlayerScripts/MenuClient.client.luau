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
-- (prompt 41, 22 Oct) The live gym behind the menu (no art: the camera frames the doorway and your character in the right
-- two-thirds), a black-to-clear gradient over the left 45%, one column holding everything: logo, tagline, PLAY, SHOP,
-- SETTINGS, NEWS, the player card. Desktop / tablet: the column centred top to bottom, 12 px gaps. Phone (touch and a
-- screen under 500 px tall; Studio: TestPhoneSize): 38% of the width, logo 120, no tagline, PLAY 56, SHOP 44, SETTINGS and
-- NEWS as two 44 px icon squares on one row, a 40 px card (avatar, name, coins). Every other screen is hidden until PLAY.
-- (prompt 60, 23 Oct) Behind the menu the camera flies slowly round the map (Shared/UI/MenuFlyover: shots from
-- Workspace.MenuCameraPath, a light depth of field, a dip through dark between shots), your character hidden; a soft dark
-- vignette keeps the buttons readable. PLAY: the camera swoops down to your character (~1 s) and hands control back.
-- Without a MenuCameraPath the prompt 41 framing (the doorway and your character) is used.
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
local UserInputService = game:GetService("UserInputService")
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Audio = require(Shared.Audio)
local MenuFlyover = require(Shared.UI.MenuFlyover)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors

local TIMING = { StreamTimeout = 8, Fade = 0.4, HudFade = 0.35, Slide = 0.35, FlyDown = 1 }
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


local bgGui = Theme.ScreenGui({ Name = "MenuBackground", DisplayOrder = 19, IgnoreGuiInset = true, Parent = playerGui })
bgGui.ScreenInsets = Enum.ScreenInsets.None
-- (owner, 15 Oct: a gap on the right showed the game: the background was sized in pixels from the camera once, and missed
-- later size changes. Now it is the whole screen by scale, and the art covers it by Crop: nothing to recalculate.)
-- (prompt 41) the live gym shows through (the art is off: Visible false, kept for the fade code)
local back = New("Frame", { Name = "Back", BackgroundColor3 = Color3.fromHex("#0C0A0C"), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
	Active = true, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1), Parent = bgGui })
local art = New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = "", Visible = false, ScaleType = Enum.ScaleType.Crop,
	Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1), Parent = back })
-- the dark gradient: black ~80% at the left edge to clear at 45% of the width
New("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(0.45, 1), ZIndex = 2, Parent = back }, {
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1) }) }),
})
-- (prompt 60) a soft dark vignette round the other three edges (the flyover behind stays readable under the buttons)
for _, side in ipairs({ "Top", "Bottom", "Right" }) do
	local vertical = side ~= "Right"
	New("Frame", { Name = "Vignette" .. side, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
		AnchorPoint = Vector2.new(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0),
		Position = UDim2.fromScale(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0),
		Size = if vertical then UDim2.fromScale(1, 0.28) else UDim2.fromScale(0.22, 1), ZIndex = 2, Parent = back }, {
		New("UIGradient", { Rotation = ({ Top = 90, Bottom = 270, Right = 180 })[side], Transparency = NumberSequence.new(0.45, 1) }),
	})
end
-- (prompt 60) the flyover's dip through dark between shots (MenuFlyover fades it)
local dip = New("Frame", { Name = "Dip", BackgroundColor3 = Color3.fromHex("#050406"), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
	ZIndex = 3, Parent = back })
-- (prompt 41: always the whole screen; the Studio phone sizing read the camera too early and left it 1 x 0)

local gui = Theme.ScreenGui({ Name = "MenuScreen", DisplayOrder = 20, IgnoreGuiInset = true, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local root = Kit.Root(gui)

-- the 3D logo, ~32% of the screen height, with a soft red glow behind it
-- (placed by layoutMenu below: always under Roblox's top bar, so never under its top-left buttons)
local logo = New("ImageLabel", { Name = "Logo", LayoutOrder = 0, BackgroundTransparency = 1, Image = UI.Logo3D, ScaleType = Enum.ScaleType.Fit, ZIndex = 2,
	Size = UDim2.fromOffset(150, 123) })
New("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = UI.SoftGlow, ImageColor3 = Color3.fromRGB(255, 45, 40), ImageTransparency = 0.35,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(1.55, 1.45), ZIndex = 1, Parent = logo })

-- the column: tagline, PLAY, then SHOP / SETTINGS / NEWS stacked
local column = New("Frame", { Name = "Column", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, LEFT, 0.5, 0),
	Size = UDim2.fromOffset(COL_W, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root }, {
	Theme.List(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
logo.Parent = column
Kit.Text({ Name = "Tagline", LayoutOrder = 1, Text = "Everyone starts tiny.", Font = "Strong", TextSize = 13, TextColor3 = Color3.fromHex("#E7DEDF"),
	Size = UDim2.fromOffset(COL_W, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = column })

-- PLAY: the red CTA with a play triangle (drawn from thin strips: no glyph, no emoji)
-- (owner, 23 Oct, chrome reset) every menu button is chrome (Theme.SetChrome): no diagonal shine, a 1 px top highlight,
-- 10 px corners; PLAY keeps the chunky stroked word on a deep red with a 5 px darker bottom edge, SHOP clean heavy italic
-- dark words on metallic gold, SETTINGS / NEWS clean heavy italic white on dark graphite with a thin dark outline
local playButton = Theme.Button("Red", { Name = "Play", LayoutOrder = 2, Size = UDim2.fromOffset(COL_W, 50), Parent = column }, {})
local playRow = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -Theme.HeroLip), Parent = playButton }, {
	Theme.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
})
local triangle = New("Frame", { Name = "Triangle", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 15), Parent = playRow },
	{ New("UIScale", { Scale = 1.5 }) }) -- (owner, 23 Oct: sized to the ~44 px PLAY)
for row = 0, 14 do
	local width = 12 * (1 - math.abs(row - 7) / 7.5)
	New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(0, row), Size = UDim2.fromOffset(width, 1), Parent = triangle })
end
Kit.Text({ Name = "Label", LayoutOrder = 2, Text = "Play", Font = "Title", TextSize = 30, Upper = true, Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X, Parent = playRow })
playButton.Active = false
-- (owner, 23 Oct) PLAY and SHOP are the menu's hero buttons (Theme "Hero"): the heavy italic words (PLAY white ~44 px with
-- a 2 px dark stroke, SHOP dark ~28 px), 14 px corners, a 3 px dark outline, a 6 px darker bottom edge, a 2 px pale top
-- line, no glow or halo
playButton:SetAttribute("Hero", true)
playButton:SetAttribute("HeroText", 44)
Theme.SetChrome(playButton)

local shopButton = Kit.Button("Gold", "Shop", { Name = "Shop", LayoutOrder = 3, Visible = false, Parent = column },
	{ width = COL_W, height = 30, textSize = 14, icon = "shopping-cart" })
local settingsButton = Kit.Button("Quiet", "Settings", { Name = "Settings", LayoutOrder = 4, Parent = column },
	{ width = COL_W, height = 30, textSize = 14, icon = "settings" })
local updatesButton = Kit.Button("Quiet", "News", { Name = "Updates", LayoutOrder = 5, Parent = column },
	{ width = COL_W, height = 30, textSize = 14, icon = "bell" })
shopButton:SetAttribute("Hero", true)
shopButton:SetAttribute("HeroText", 28)
for _, b in ipairs({ shopButton, settingsButton, updatesButton }) do Theme.SetChrome(b) end
-- (owner, 22 Oct) the news badge: the small red "!" chip (as on the side menu tiles), inside the top-right corner
local newsDot = New("Frame", { Name = "NewsDot", BackgroundColor3 = Colors.Red, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, -1), Size = UDim2.fromOffset(17, 17), Visible = false, ZIndex = 4, Parent = New("Folder", { Name = "Dot", Parent = updatesButton }) }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	New("UIStroke", { Color = Color3.fromHex("#2A0505"), Thickness = 1.5 }),
})
local bang = Kit.Text({ Name = "Bang", Text = "!", Font = "Chunky", TextSize = 13, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = newsDot })
bang:SetAttribute("KeepColor", true)

-- (prompt 41) phones: SETTINGS and NEWS as two 44 px icon squares on one row (NEWS keeps its "!" chip)
local iconRow = New("Frame", { Name = "IconRow", LayoutOrder = 6, BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 44), Visible = false, Parent = column }, {
	Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
local function squareButton(name: string, icon: string, order: number)
	local b = Theme.SetChrome(Theme.Button("Quiet", { Name = name, LayoutOrder = order, Size = UDim2.fromOffset(44, 44), Parent = iconRow }, {}))
	require(Shared.UI.Pieces).Icon(icon, Colors.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(20, 20),
		ZIndex = b.ZIndex + 2, Parent = b })
	return b
end
local settingsSquare = squareButton("SettingsIcon", "settings", 1)
local newsSquare = squareButton("NewsIcon", "bell", 2)
local newsSquareDot = newsDot:Clone()
newsSquareDot.AnchorPoint = Vector2.new(1, 0)
newsSquareDot.Position = UDim2.new(1, 4, 0, -4)
newsSquareDot.Parent = New("Folder", { Name = "Dot", Parent = newsSquare })

-- the player card, bottom left: headshot, name, level and height, coins
local card = Theme.Panel({ Name = "Card", Piece = "hud_box", LayoutOrder = 7, Size = UDim2.fromOffset(236, 48), Visible = false, Parent = column })
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

-- (prompt 41) the layout: desktop / tablet or phone, again on every size / top bar change
local function isPhone(): boolean
	local phone = RunService:IsStudio() and Workspace:GetAttribute("TestPhoneSize")
	if typeof(phone) == "Vector2" and phone.X > 0 then return phone.Y < 500 end
	local camera = Workspace.CurrentCamera
	return UserInputService.TouchEnabled and camera ~= nil and camera.ViewportSize.Y < 500
end
-- a Kit button resized: its bottom lip padding and its label follow
local function sizeButton(button: GuiObject, width: number, height: number, textSize: number?)
	button.Size = UDim2.fromOffset(width, height)
	local lip = if button:GetAttribute("Hero") then Theme.HeroLip elseif button:GetAttribute("Chrome") then 0 else math.floor(height * Theme.LipHeight) -- (chrome: no bottom edge on these)
	local pad = button:FindFirstChildOfClass("UIPadding")
	if pad then pad.PaddingBottom = UDim.new(0, lip) end
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Size = UDim2.fromOffset(0, height - lip)
		if textSize then label.TextSize = textSize end
	end
	-- (a hero button's icon follows its bigger words: SHOP's cart)
	local icon = button:FindFirstChild("Icon")
	if icon and icon:IsA("GuiObject") and textSize and button:GetAttribute("Hero") then
		local px = math.floor(textSize * 0.8)
		icon.Size = UDim2.fromOffset(px, px)
	end
end
local LOGO_ASPECT = 432 / 354
local function layoutMenu()
	local s = math.max(Kit.Scale(), 0.01)
	local rootW, rootH = root.AbsoluteSize.X / s, root.AbsoluteSize.Y / s
	if rootH < 10 then return end
	local top = Kit.UnderTopbar(root)
	local phone = isPhone()
	local list = column:FindFirstChildOfClass("UIListLayout")
	local gap = if phone then 8 else 12
	if list then list.Padding = UDim.new(0, gap) end
	local colW = if phone then math.max(170, math.floor(rootW * 0.38)) else 236
	column.Size = UDim2.fromOffset(colW, 0)
	column.Position = UDim2.new(0, if phone then 16 else LEFT, 0.5, top / 2)
	local tagline = column:FindFirstChild("Tagline")
	if tagline then tagline.Visible = not phone; tagline.Size = UDim2.fromOffset(colW, 18) end
	-- the buttons
	playButton.Size = UDim2.fromOffset(colW, if phone then 56 else 60)
	local playLabel = playButton:FindFirstChild("Label", true)
	if playLabel then playLabel.TextSize = 44 end
	sizeButton(shopButton, colW, if phone then 44 else 36, 28)
	sizeButton(settingsButton, colW, 36, 15)
	sizeButton(updatesButton, colW, 36, 15)
	settingsButton.Visible = not phone
	updatesButton.Visible = not phone
	iconRow.Visible = phone
	-- the card: 40 px avatar + name + coins on a phone, 48 with level and height otherwise
	card.Size = UDim2.fromOffset(colW, if phone then 40 else 48)
	cardSub.Visible = not phone
	local name = card:FindFirstChild("PlayerName")
	if name then name.Position = UDim2.fromOffset(50, if phone then 11 else 7) end
	local headshot = card:FindFirstChild("Headshot")
	if headshot then headshot.Size = UDim2.fromOffset(if phone then 30 else 34, if phone then 30 else 34) end
	-- the logo: 30% bigger than before on desktop, 120 on a phone; smaller when the column wouldn't fit under the top bar
	local logoH = if phone then 120 else math.min(rootH * 0.4, 190)
	logo.Size = UDim2.fromOffset(logoH * LOGO_ASPECT, logoH)
	task.defer(function()
		local content = list and list.AbsoluteContentSize.Y / s or 0
		local room = rootH - top - 16
		if content > room then
			local shrink = math.max(60, logoH - (content - room))
			logo.Size = UDim2.fromOffset(shrink * LOGO_ASPECT, shrink)
		end
	end)
end
Kit.OnTopbar(layoutMenu)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutMenu)
Workspace:GetAttributeChangedSignal("TestPhoneSize"):Connect(function() task.defer(layoutMenu) end)

-- The logo, the column and the card slide in from a little to the left, fading in (no CanvasGroup: text stays crisp)
local function reveal()
	layoutMenu()
	for index, piece in ipairs({ column }) do
		if piece.Visible then
			local goal = piece.Position
			piece.Position = goal - UDim2.fromOffset(24, 0)
			task.delay((index - 1) * 0.08, function()
				Theme.Tween(piece, { Position = goal }, TIMING.Slide)
				Theme.Fade(piece, true, TIMING.Slide)
			end)
		end
	end
	-- (owner, 23 Oct, chrome reset: no diagonal shine on the menu buttons)
end

-- PLAY pulses (the featured CTA) while the menu is up
local playGlow = New("ImageLabel", { Name = "SoftGlow", BackgroundTransparency = 1, Image = UI.SoftGlow, ImageColor3 = Color3.fromRGB(255, 50, 45),
	ImageTransparency = 0.55, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.35, 0, 2.2, 0), ZIndex = 0 })
playGlow.Parent = playButton
local function playAlive()
	Theme.Pulse(playButton, function() return UIBus.MenuOpen end)
	-- (prompt 41) a clean dark outline and a soft red glow only: the coloured ring goes
	task.defer(function()
		local ring = playButton:FindFirstChild("Depth") and playButton.Depth:FindFirstChild("Glow")
		if ring then ring.Visible = false; ring:SetAttribute("Off", true) end
	end)
end

local function openSettings()
	Audio.PlayUI("Click")
	UIBus.OpenSettings:Fire()
end
settingsButton.Activated:Connect(openSettings)
settingsSquare.Activated:Connect(openSettings)

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
local function openNews()
	Audio.PlayUI("Click")
	updates.open()
	if newsDot.Visible then
		newsDot.Visible = false
		newsSquareDot.Visible = false
		ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayerAction"):FireServer("SetSettings", { updatesSeen = UI.UpdatesStamp })
	end
end
updatesButton.Activated:Connect(openNews)
newsSquare.Activated:Connect(openNews)

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

-- (prompt 41) every other screen (HUD, tooltips, popups) stays hidden until PLAY; the ones it hid come back after
local MENU_SCREENS = { MenuScreen = true, MenuBackground = true, LoadingScreen = true, Updates = true, Settings = true, Freecam = true }
local hiddenByMenu = {}
RunService.Heartbeat:Connect(function()
	if not UIBus.MenuOpen then return end
	for _, screen in ipairs(playerGui:GetChildren()) do
		if screen:IsA("LayerCollector") and screen.Enabled and not MENU_SCREENS[screen.Name] and string.sub(screen.Name, 1, 6) ~= "Topbar"
			and screen.Name ~= "MainHud" then
			screen.Enabled = false
			hiddenByMenu[screen] = true
		end
	end
end)
local function restoreScreens()
	for screen in pairs(hiddenByMenu) do
		if screen.Parent then screen.Enabled = true end
	end
	hiddenByMenu = {}
end
-- (prompt 41) your own trainers (Workspace.LocalTrainers, TrainerFollowClient) stand behind you, in the camera's way: hidden
-- for you while the menu is up
local function hideFollowers(hide: boolean)
	local trainers = Workspace:FindFirstChild("LocalTrainers")
	if not trainers then return end
	for _, item in ipairs(trainers:GetDescendants()) do
		if item:IsA("BasePart") or item:IsA("Decal") then item.LocalTransparencyModifier = if hide then 1 else 0 end
	end
end
-- (prompt 60) while the camera flies round the map your own character is hidden (its parts, and its name tags)
local hiddenTags = {}
local function hideCharacter(hide: boolean)
	local character = player.Character
	if not character then return end
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = if hide then 1 else 0
		elseif item:IsA("BillboardGui") then
			if hide and item.Enabled then item.Enabled = false hiddenTags[item] = true end
		end
	end
	if not hide then
		for tag in pairs(hiddenTags) do if tag.Parent then tag.Enabled = true end end
		hiddenTags = {}
	end
end
task.spawn(function()
	while UIBus.MenuOpen do
		hideFollowers(true)
		if MenuFlyover.Running() then hideCharacter(true) end
		task.wait(0.25)
	end
end)

-- (prompt 41) the camera frames the gym doorway and your character in the right part of the screen (no ceiling lamp)
local function frameCamera()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not (rootPart and rootPart:IsA("BasePart") and camera) then return end
	local height = character:GetExtentsSize().Y
	local phone = isPhone()
	local cf = rootPart.CFrame
	local back = math.max(10, height * 1.9) * (if phone then 1.25 else 1)
	-- behind and a little left of the character, looking ahead, left and a little down: the character and the doorway sit
	-- right of centre, the ceiling lamp above the frame
	local eye = cf * Vector3.new(-height * 0.15, height * 0.08, back)
	local aim = cf * Vector3.new(-height * 0.75, -height * 0.4, -height * 3)
	-- never through a wall: the corridor behind the spawn is narrow, so the camera stops 1 stud inside the first wall
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, Workspace:FindFirstChild("LocalTrainers") }
	local origin = cf * Vector3.new(0, height * 0.22, 0)
	local hit = Workspace:Raycast(origin, eye - origin, params)
	if hit then eye = hit.Position - (eye - origin).Unit * 1 end
	local framed = CFrame.lookAt(eye, aim)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = framed
	-- (other scripts set the camera back to Custom while loading: the framing is held every frame until PLAY)
	RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if not UIBus.MenuOpen then return end
		local cam = Workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = framed
		end
	end)
end

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
	local height = GrowthSpurts.FormatHeight(GrowthSpurts.PlayerHeight(data))
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
	newsSquareDot.Visible = newsDot.Visible
	refreshPill(data)
	Audio.AdoptMenuMusic() -- (the loading screen's track keeps playing here, now at the player's music volume)
	ClientData.Changed:Connect(function(path)
		if UIBus.MenuOpen and (path[1] == "coins" or path[1] == "muscles" or path[1] == "growthSpurts") then refreshPill(ClientData.Get()) end
	end)
	-- (prompt 60) the flyover round the map (its first shot streamed in while loading); without its path, the framing
	if MenuFlyover.Prepare() then
		MenuFlyover.Start(dip)
		hideCharacter(true)
	else
		frameCamera()
	end
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
	pcall(function() RunService:UnbindFromRenderStep("MenuCamera") end)
	updates.close()
	Audio.PlayUI("Whoosh")
	Audio.StopMenuMusic(1.2) -- (the area music starts under the fade)
	-- the camera behind the character, far enough to see all of them (a 7'0" character needs more room than a 4'0" one)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local behindView = nil
	if rootPart and rootPart:IsA("BasePart") then
		local height = character:GetExtentsSize().Y
		local behind = rootPart.CFrame * CFrame.new(0, height * 0.45, math.max(11, height * 1.9))
		behindView = CFrame.lookAt(behind.Position, rootPart.Position + Vector3.new(0, height * 0.25, 0))
	end
	local function handBack()
		if behindView then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = behindView
		end
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then camera.CameraSubject = humanoid end
	end
	hideCharacter(false)
	if MenuFlyover.Running() and behindView then
		-- (prompt 60) the camera swoops down from the flyover to behind your character, then it's yours
		MenuFlyover.FlyTo(behindView, TIMING.FlyDown, handBack)
	else
		MenuFlyover.Stop()
		handBack()
	end
	ContextActionService:UnbindAction("MenuFreeze")
	if mainHud then mainHud.Enabled = true end
	UIBus.MenuOpen = false
	restoreScreens()
	hideFollowers(false)
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
	Theme.Fade(column, false, TIMING.Fade)
	for _, item in ipairs(back:GetDescendants()) do
		if item:IsA("Frame") then game:GetService("TweenService"):Create(item, info, { BackgroundTransparency = 1 }):Play() end
	end
	task.delay(TIMING.Fade, function()
		gui.Enabled = false
		bgGui.Enabled = false
	end)
	if thenShop then
		-- (prompt 20: the Store's own first tab, Auras, not the Robux passes)
		task.delay(TIMING.Fade + 0.2, function() UIBus.OpenShop:Fire() end)
	end
end

playButton.Activated:Connect(function() play(false) end)
shopButton.Activated:Connect(function() play(true) end)
