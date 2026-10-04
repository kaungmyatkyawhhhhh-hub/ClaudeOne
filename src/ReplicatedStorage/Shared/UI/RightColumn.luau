-- The column of small panels on the right middle of the screen (shake button, quest tracker). Each script adds
-- its own frame; the column stacks them with the standard gap so they never overlap.
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)

local RightColumn = {}

local WIDTH = 230
local column

local function ensure()
	if column then return column end
	local gui = Theme.ScreenGui({ Name = "RightColumn", DisplayOrder = 3, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	column = Theme.New("Frame", {
		Name = "Column",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Theme.Spacing.L, 0.5, 0),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	return column
end

RightColumn.Width = WIDTH

-- Parent `frame` into the column; lower `order` sits higher.
function RightColumn.Add(frame, order)
	frame.LayoutOrder = order or 1
	frame.Parent = ensure()
	return frame
end

-- Show or hide the whole column (e.g. while the menu screen is up).
function RightColumn.SetVisible(visible)
	ensure().Parent.Enabled = visible
end

return RightColumn
