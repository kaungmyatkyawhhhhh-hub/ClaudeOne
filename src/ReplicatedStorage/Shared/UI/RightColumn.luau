-- The column of small panels on the right of the screen (shake button, boost pills, quest + legend trackers).
-- Each script adds its own frame; the column stacks them with the standard gap so they never overlap.
-- Frames added with `idleOnly = true` hide while the player is on a machine (clean HUD while training, and room
-- for the machine panel on phones).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)

local RightColumn = {}

local WIDTH = 230
local column, always, idle

local function container(name, order)
	return Theme.New("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = column,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
end

local function ensure()
	if column then return column end
	local gui = Theme.ScreenGui({ Name = "RightColumn", DisplayOrder = 3, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	column = Theme.New("Frame", {
		Name = "Column",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Theme.Spacing.L, 0.42, 0), -- a little above the middle, clear of the machine panel
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	always = container("Always", 1)
	idle = container("Idle", 2)

	-- hide the idle-only panels while on a machine
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		local machineState = remotes and remotes:WaitForChild("MachineState", 30)
		if not machineState then return end
		machineState.OnClientEvent:Connect(function(state)
			if state == "Enter" then
				idle.Visible = false
			elseif state == "Exit" then
				idle.Visible = true
			end
		end)
		Players.LocalPlayer.CharacterAdded:Connect(function() idle.Visible = true end)
	end)
	return column
end

RightColumn.Width = WIDTH

-- Parent `frame` into the column; lower `order` sits higher. `idleOnly` = hidden while on a machine.
function RightColumn.Add(frame, order, idleOnly)
	ensure()
	frame.LayoutOrder = order or 1
	frame.Parent = idleOnly and idle or always
	return frame
end

-- Show or hide the whole column.
function RightColumn.SetVisible(visible)
	ensure().Parent.Enabled = visible
end

return RightColumn
