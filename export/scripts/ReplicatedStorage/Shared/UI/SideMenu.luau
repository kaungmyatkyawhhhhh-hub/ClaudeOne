-- Side menu buttons (client): dark see-through buttons stacked on the left middle, each with a white line icon
-- above a small Montserrat label. SideMenu.Add returns { button, SetActive(on), SetDot(on), Activated }.
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local New, Colors, Spacing, Alpha = Theme.New, Theme.Colors, Theme.Spacing, Theme.Alpha

local SideMenu = {}

local BUTTON = Vector2.new(64, 68)
local ACTIVE_FILL = 0.8 -- white fill transparency of the open menu's button

local column
local function ensure()
	if column then return column end
	local gui = Theme.ScreenGui({ Name = "MainHud", DisplayOrder = 4, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	column = New("Frame", {
		Name = "SideMenu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Spacing.L, 0.5, 0),
		Size = UDim2.fromOffset(BUTTON.X, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	return column
end

function SideMenu.Column()
	return ensure()
end

function SideMenu.Add(id, labelText, iconFactory, order)
	local parent = ensure()
	local border = Theme.Stroke(Colors.Border, 1, Alpha.Border)
	local button = New("TextButton", {
		Name = id,
		LayoutOrder = order or 1,
		Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Alpha.Panel,
		Parent = parent,
	}, { Theme.Round("Panel"), border })
	Theme.BindPress(button)
	Theme.AddDepth(button, "Panel")
	local content = New("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = button }, {
		New("UIPadding", { PaddingTop = UDim.new(0, Spacing.M), PaddingBottom = UDim.new(0, Spacing.S) }),
		Theme.List(Enum.FillDirection.Vertical, "XS"),
	})
	local iconSlot = New("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Parent = content })
	local icon = iconFactory(Colors.Text)
	icon.Parent = iconSlot
	local label = Theme.Text({ LayoutOrder = 2, Text = labelText, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), Parent = content })
	local dot = New("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -Spacing.S, 0, Spacing.S),
		Size = UDim2.fromOffset(Spacing.S, Spacing.S),
		BackgroundColor3 = Colors.Text,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { Theme.Round("Round") })

	local entry = { button = button, Activated = button.Activated }
	function entry.SetActive(_, on)
		Theme.Tween(button, { BackgroundColor3 = on and Colors.Text or Colors.Panel, BackgroundTransparency = on and ACTIVE_FILL or Alpha.Panel }, Theme.Motion.Time)
		Theme.Tween(border, { Transparency = on and 0.5 or Alpha.Border }, Theme.Motion.Time)
		label.TextColor3 = on and Colors.Text or Colors.Muted
	end
	function entry.SetDot(_, on)
		dot.Visible = on
	end
	return entry
end

return SideMenu
