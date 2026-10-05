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
	-- As tall as the screen allows: on short screens (a 667x375 phone fits 4 buttons) the buttons wrap into a second
	-- column instead of running off the bottom. Panels that open beside the menu use SideMenu.Right().
	local list = Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	list.Wraps = true
	column = New("Frame", {
		Name = "SideMenu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Spacing.L, 0.5, 0),
		Size = UDim2.new(0, BUTTON.X, 1, -Spacing.L * 2),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { list })
	return column
end

function SideMenu.Column()
	return ensure()
end

-- Pixel x of the menu's right edge (one or two columns), for panels that open beside it.
function SideMenu.Right()
	local menu = ensure()
	local width = menu.AbsoluteSize.X > 0 and menu.AbsoluteSize.X or BUTTON.X
	return Spacing.L + width
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

-- SetHidden(true) hides the whole menu (a phone screen that needs the full width, like Genetics).
function SideMenu.SetHidden(on)
	ensure().Visible = not on
end

-- SetTraining(true) leaves only Stats while on a machine, moved up to the top-left corner: a clean HUD while
-- training, and on phones the machine panel (low on the left) needs the room.
function SideMenu.SetTraining(on)
	local menu = ensure()
	for _, button in ipairs(menu:GetChildren()) do
		if button:IsA("GuiButton") and button.Name ~= "Stats" then button.Visible = not on end
	end
	local list = menu:FindFirstChildOfClass("UIListLayout")
	if list then list.VerticalAlignment = on and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center end
end

return SideMenu
