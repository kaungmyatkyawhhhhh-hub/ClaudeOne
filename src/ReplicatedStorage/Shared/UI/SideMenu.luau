-- Menu bar (client): a compact column of icon buttons at the top left, below the Roblox top bar (inside the safe
-- area, so it never collides with Roblox's own buttons). White line icons, no labels; on PC the label shows as a
-- small tooltip on hover. On phones (Theme.IsCompact) the column folds into one "Menu" button that opens it.
-- SideMenu.Add returns { button, SetActive(on), SetDot(on), Activated } (same as before, so screens didn't change).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local New, Colors, Spacing, Alpha = Theme.New, Theme.Colors, Theme.Spacing, Theme.Alpha

local SideMenu = {}

local BUTTON = 46          -- px, square (min touch 44)
local GAP = Spacing.XS + 2 -- px between buttons
local ACTIVE_FILL = 0.8    -- white fill transparency of the open menu's button

local changed = Instance.new("BindableEvent")
SideMenu.Changed = changed.Event -- fires when the bar's size or position changes (panels and the body map follow it)

local gui, bar, column, toggle, tooltip
local compact = false
local expanded = false
local training = false

local function position()
	-- just under the top bar (CoreUISafeInsets already keeps us out of it; add a small margin)
	bar.Position = UDim2.fromOffset(Spacing.M, Spacing.S)
end

local function setExpanded(on)
	expanded = on
	column.Visible = (not compact) or on
	if toggle then
		toggle:SetAttribute("Open", on)
		local icon = toggle:FindFirstChild("Icon")
		if icon then icon.Rotation = on and 90 or 0 end
	end
	changed:Fire()
end

-- phones fold the column into the Menu button; PCs show the column (switches live with the screen size)
local function applyMode(isCompact)
	compact = isCompact
	if toggle then toggle.Visible = compact and not training end
	setExpanded(false)
end

local function ensure()
	if column then return column end
	compact = Theme.IsCompact()
	gui = Theme.ScreenGui({ Name = "MainHud", DisplayOrder = 4, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	bar = New("Frame", {
		Name = "MenuBar",
		Size = UDim2.fromOffset(BUTTON, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.List(Enum.FillDirection.Vertical, nil, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	bar:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, GAP)
	position()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(position)

	do
		-- phones: one Menu button; the icons open below it (hidden on PC)
		toggle = New("TextButton", {
			Name = "MenuToggle",
			LayoutOrder = 0,
			Size = UDim2.fromOffset(BUTTON, BUTTON),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Colors.Panel,
			BackgroundTransparency = Alpha.Panel,
			Parent = bar,
		}, { Theme.Round("Panel"), Theme.Stroke(Colors.Border, 1, Alpha.Border) })
		Theme.BindPress(toggle)
		Theme.AddDepth(toggle, "Panel")
		-- a simple "menu" icon: three short lines
		local icon = New("Frame", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 16), BackgroundTransparency = 1, Parent = toggle })
		for i = 0, 2 do
			New("Frame", { Position = UDim2.fromOffset(0, i * 7), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Colors.Text, Parent = icon }, { Theme.Round("Segment") })
		end
		New("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -Spacing.S, 0, Spacing.S), Size = UDim2.fromOffset(Spacing.S, Spacing.S), BackgroundColor3 = Colors.Text, Visible = false, ZIndex = 3, Parent = toggle }, { Theme.Round("Round") })
		toggle.Activated:Connect(function() setExpanded(not expanded) end)
		toggle.Visible = compact
	end
	column = New("Frame", {
		Name = "SideMenu",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(BUTTON, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = not compact,
		Parent = bar,
	}, { Theme.List(Enum.FillDirection.Vertical, nil, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	column:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, GAP)

	-- PC tooltip: the button's name, beside it, while hovered
	tooltip = Theme.Panel({ Name = "Tooltip", Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Visible = false, ZIndex = 10, Parent = gui },
		{ New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.S), PaddingRight = UDim.new(0, Spacing.S) }) })
	Theme.Text({ Name = "Text", Font = "Regular", TextSize = "Small", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 11, Parent = tooltip })
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() changed:Fire() end)
	Theme.OnCompactChanged(applyMode)
	return column
end

function SideMenu.Column()
	return ensure()
end

-- Pixel x of the bar's right edge, for panels that open beside it.
function SideMenu.Right()
	ensure()
	return Spacing.M + BUTTON
end

-- Pixel y (inside the safe area) of the bar's bottom edge.
function SideMenu.Bottom()
	ensure()
	return bar.AbsolutePosition.Y - gui.AbsolutePosition.Y + bar.AbsoluteSize.Y
end

function SideMenu.Add(id, labelText, iconFactory, order)
	local parent = ensure()
	local border = Theme.Stroke(Colors.Border, 1, Alpha.Border)
	local button = New("TextButton", {
		Name = id,
		LayoutOrder = order or 1,
		Size = UDim2.fromOffset(BUTTON, BUTTON),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Alpha.Panel,
		Parent = parent,
	}, { Theme.Round("Panel"), border })
	Theme.BindPress(button)
	Theme.AddDepth(button, "Panel")
	local iconSlot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Parent = button })
	iconFactory(Colors.Text).Parent = iconSlot
	local dot = New("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -Spacing.XS - 2, 0, Spacing.XS + 2),
		Size = UDim2.fromOffset(Spacing.S, Spacing.S),
		BackgroundColor3 = Colors.Text,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { Theme.Round("Round") })

	-- hover tooltip (mouse only)
	button.MouseEnter:Connect(function()
		if compact then return end
		tooltip.Text.Text = labelText
		tooltip.Position = UDim2.fromOffset(button.AbsolutePosition.X - gui.AbsolutePosition.X + BUTTON + Spacing.S, button.AbsolutePosition.Y - gui.AbsolutePosition.Y + (BUTTON - 28) / 2)
		tooltip.Visible = true
	end)
	button.MouseLeave:Connect(function() tooltip.Visible = false end)
	-- phones: picking something folds the menu again
	button.Activated:Connect(function()
		tooltip.Visible = false
		if compact and expanded then setExpanded(false) end
	end)

	local entry = { button = button, Activated = button.Activated }
	function entry.SetActive(_, on)
		Theme.Tween(button, { BackgroundColor3 = on and Colors.Text or Colors.Panel, BackgroundTransparency = on and ACTIVE_FILL or Alpha.Panel }, Theme.Motion.Time)
		Theme.Tween(border, { Transparency = on and 0.5 or Alpha.Border }, Theme.Motion.Time)
	end
	function entry.SetDot(_, on)
		dot.Visible = on
		if toggle then
			local any = false
			for _, child in ipairs(column:GetChildren()) do
				local d = child:FindFirstChild("Dot")
				if d and d.Visible then any = true end
			end
			toggle.Dot.Visible = any
		end
	end
	changed:Fire()
	return entry
end

-- SetHidden(true) hides the whole bar (a screen that needs the full width, like Genetics on phones).
function SideMenu.SetHidden(on)
	ensure()
	bar.Visible = not on
end

-- SetTraining(true): a clean HUD while on a machine. The bar folds away (phones) or keeps only Stats (PC).
function SideMenu.SetTraining(on)
	ensure()
	training = on
	for _, button in ipairs(column:GetChildren()) do
		if button:IsA("GuiButton") and button.Name ~= "Stats" then button.Visible = not on end
	end
	if compact and on then setExpanded(false) end
	if toggle then toggle.Visible = not on end
	changed:Fire()
end

function SideMenu.IsTraining()
	return training
end

-- true while the bar is folded into the Menu button (phones)
function SideMenu.IsCompact()
	ensure()
	return compact
end

return SideMenu
