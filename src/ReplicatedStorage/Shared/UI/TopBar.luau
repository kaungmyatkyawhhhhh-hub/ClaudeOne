-- TopBar (client): rounded pill buttons along the top of the screen, just under the Roblox top bar (owner's UI v7 brief).
--   left:  the coins pill (always your coin count)
--   right: Quests, Daily Reward and Settings pills (each an icon + a short text; phones show the icon only)
-- Each right-hand pill is made with TopBar.AddPill, which returns { button, SetActive(on), SetDot(on), SetText(text),
-- Activated } like SideMenu.Add. The icons and any images you want to use instead are in Config.HudIcons.
-- Hidden while training (clean HUD) and while a screen hides the whole menu (SideMenu.SetHidden).
-- TopBar.Bottom() = the y (inside the safe area) just below the pills, for the right-hand column and panels that drop down.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local HudIcons = require(script.Parent.Parent.Config.HudIcons)
local Icons = require(script.Parent.Icons)
local SideMenu = require(script.Parent.SideMenu)
local UIBus = require(script.Parent.UIBus)
local New, Colors, Spacing, Alpha = Theme.New, Theme.Colors, Theme.Spacing, Theme.Alpha

local TopBar = {}

local TOP = Spacing.S
local EDGE = Spacing.M
local NARROW_WIDTH = 1400 -- px: under this the right pills drop their text
local ACTIVE_FILL = 0.8
local HOVER_FILL = 0.4

local geneticsOpen = false -- the Genetics screen needs the whole top of the screen
local gui, left, right, coinsText
local pills = {}
local compact = false -- a phone (short screen): the coins pill goes right of the Menu button
local narrow = false  -- not much width (phones, small windows): the right pills show only their icons, so they stay clear of
                      -- the Growth Spurt bar in the middle

local function pillIcon(id, factory)
	local cfg = HudIcons.Pills[id]
	if cfg and cfg.image and cfg.image ~= "" then
		return New("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = cfg.image, ScaleType = Enum.ScaleType.Fit })
	end
	return factory(Colors.Text)
end

-- One pill: a dark see-through rounded capsule with a thin border, the icon and the text.
local function makePill(id, text, factory, textWidth)
	local pill = New("TextButton", {
		Name = id,
		Size = UDim2.new(0, 0, 0, Theme.PillHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Alpha.Panel,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Theme.Stroke(Colors.Border, 1, Alpha.Border),
		New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.M), PaddingRight = UDim.new(0, Spacing.M) }),
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Spacing.S),
		}),
	})
	local slot = New("Frame", { Name = "Icon", LayoutOrder = 1, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Parent = pill })
	pillIcon(id, factory).Parent = slot
	local label = Theme.Text({
		Name = "Text",
		LayoutOrder = 2,
		Text = text,
		Font = "SemiBold",
		TextSize = "Body",
		Size = UDim2.new(0, textWidth or 0, 1, 0),
		AutomaticSize = textWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Parent = pill,
	})
	local dot = New("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 1, 0, 1),
		Size = UDim2.fromOffset(Spacing.S, Spacing.S),
		BackgroundColor3 = Colors.Text,
		Visible = false,
		ZIndex = 3,
		Parent = slot, -- (on the icon's corner: the pill's list layout would move it if it were a child of the pill)
	}, { Theme.Round("Round") })
	Theme.BindPress(pill)
	Theme.AddDepth(pill, "Button", "Round")
	local api = { button = pill, label = label, dot = dot, active = false, hover = false }
	local border = pill:FindFirstChildOfClass("UIStroke")
	function api.paint()
		local fill = api.active and ACTIVE_FILL or (api.hover and HOVER_FILL or Alpha.Panel)
		Theme.Tween(pill, { BackgroundColor3 = api.active and Colors.Text or Colors.Panel, BackgroundTransparency = fill }, 0.15)
		if border then Theme.Tween(border, { Transparency = (api.active or api.hover) and 0.5 or Alpha.Border }, 0.15) end
	end
	pill.MouseEnter:Connect(function() api.hover = true; api.paint() end)
	pill.MouseLeave:Connect(function() api.hover = false; api.paint() end)
	return api
end

local function applyMode()
	if not gui then return end
	-- phones: the right pills show only icons (the coins pill keeps the top left corner)
	local phone = SideMenu.IsCompact() or compact -- the same "phone" as the menu (a short screen, or touch without a keyboard)
	local iconsOnly = narrow or phone
	left.Position = UDim2.fromOffset(EDGE, TOP) -- (the menu arrow sits beside the tiles now, never in this corner)
	for _, entry in pairs(pills) do
		entry.api.label.Visible = not iconsOnly or entry.keepText == true
	end
end

-- full-width screens the pills step aside for (Settings is not one: it opens from a pill)
local COVERS = { "MusclesScreen", "TitleBook", "ProgressMirror", "GeneticsScreen", "ClothingStore", "ArmWrestle", "Store", "Wardrobe", "Crew" }
local function coverOpen()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end
	for _, name in ipairs(COVERS) do
		local screen = playerGui:FindFirstChild(name)
		if screen and screen:IsA("ScreenGui") and screen.Enabled then return true end
	end
	return false
end

local function refreshVisible()
	if not gui then return end
	local show = not SideMenu.IsTraining() and not SideMenu.IsHidden() and not UIBus.MenuOpen and not geneticsOpen and not coverOpen()
	left.Visible = show
	right.Visible = show
end

local function coinsNow()
	local ok, ClientData = pcall(function() return require(ReplicatedStorage.Shared.ClientData) end)
	if not ok then return 0 end
	local data = ClientData.Get()
	return data and data.coins or 0
end

local function ensure()
	if gui then return gui end
	gui = Theme.ScreenGui({ Name = "TopBar", DisplayOrder = 5, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	left = New("Frame", { Name = "Left", Size = UDim2.new(0, 0, 0, Theme.PillHeight), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = gui },
		{ Theme.List(Enum.FillDirection.Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	right = New("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -EDGE, 0, TOP),
		Size = UDim2.new(0, 0, 0, Theme.PillHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.List(Enum.FillDirection.Horizontal, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })

	-- the coins pill (not a button: it just shows the count)
	local coins = makePill("Coins", "0", Icons.Plate)
	coins.button.Active = false
	coins.button.Parent = left
	coinsText = coins.label
	coins.button.Interactable = false

	local function viewportWatch(camera)
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local now = camera.ViewportSize.X < NARROW_WIDTH
			if now ~= narrow then
				narrow = now or compact
				applyMode()
			end
		end)
	end
	Theme.OnCompactChanged(function(isCompact)
		compact = isCompact
		local camera = workspace.CurrentCamera
		narrow = isCompact or (camera ~= nil and camera.ViewportSize.X < NARROW_WIDTH)
		applyMode()
	end)
	if workspace.CurrentCamera then viewportWatch(workspace.CurrentCamera) end
	SideMenu.Changed:Connect(function()
		refreshVisible()
		applyMode()
	end)
	UIBus.MenuClosed.Event:Connect(refreshVisible)
	UIBus.GeneticsVisible.Event:Connect(function(open)
		geneticsOpen = open
		refreshVisible()
	end)
	task.spawn(function() -- (MenuClient raises UIBus.MenuOpen when it starts, which can be after this runs)
		while true do
			task.wait(0.4)
			refreshVisible()
		end
	end)
	task.spawn(function()
		local ClientData = require(ReplicatedStorage.Shared.ClientData)
		ClientData.Get()
		local function update() coinsText.Text = require(ReplicatedStorage.Shared.Config.Muscles).FormatExp(coinsNow()) end
		update()
		ClientData.Changed:Connect(function(path)
			if path[1] == "coins" then update() end
		end)
	end)
	refreshVisible()
	return gui
end

-- A pill on the right. `order` sorts them left to right. keepText = keep the text on phones too.
function TopBar.AddPill(id, text, iconFactory, order, keepText)
	ensure()
	local api = makePill(id, text, iconFactory)
	api.button.LayoutOrder = order or 1
	api.button.Parent = right
	pills[id] = { api = api, keepText = keepText }
	applyMode()

	local activated = Instance.new("BindableEvent")
	api.button.Activated:Connect(function() activated:Fire() end)
	local out = { button = api.button, Activated = activated.Event }
	function out.SetActive(_, on)
		api.active = on
		api.paint()
	end
	function out.SetDot(_, on)
		api.dot.Visible = on
	end
	function out.SetText(_, newText)
		api.label.Text = newText
	end
	return out
end

-- Pixel y (inside the safe area) just under the pills.
function TopBar.Bottom()
	return TOP + Theme.PillHeight
end

-- Pixel distance from the right edge to where the pills start (right-hand panels line up with it).
function TopBar.Edge()
	return EDGE
end

return TopBar
