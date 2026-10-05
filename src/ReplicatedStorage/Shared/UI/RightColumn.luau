-- The column of small panels on the right of the screen (shake button, boost pills, quest + legend trackers).
-- Each script adds its own frame; the column stacks them with the standard gap so they never overlap.
-- Frames added with `idleOnly = true` hide while the player is on a machine (clean HUD while training, and room
-- for the machine panel on phones).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local UIBus = require(script.Parent.UIBus)

local RightColumn = {}

-- narrower than before, and at the top right (under the Roblox top bar), so it never covers the body map (bottom
-- left), the Growth Spurt bar (top center) or the Lift button (bottom right)
local WIDTH = 200 -- 176 on phones (set live in ensure)
local column, always, idle
local changed = Instance.new("BindableEvent")
RightColumn.Changed = changed.Event -- fires when the column's size changes (notifications stack below it)

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
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Spacing.M, 0, Theme.Spacing.S), -- top right, just under the top bar
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
	column:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() changed:Fire() end)
	-- narrower on phones; every panel in it fills the column's width
	Theme.OnCompactChanged(function(isCompact)
		WIDTH = isCompact and 176 or 200
		RightColumn.Width = WIDTH
		column.Size = UDim2.fromOffset(WIDTH, 0)
		for _, holder in ipairs({ always, idle }) do
			if holder then
				holder.Size = UDim2.fromOffset(WIDTH, 0)
				for _, child in ipairs(holder:GetChildren()) do
					if child:IsA("GuiObject") then child.Size = UDim2.new(0, WIDTH, child.Size.Y.Scale, child.Size.Y.Offset) end
				end
			end
		end
	end)
	always = container("Always", 1)
	idle = container("Idle", 2)

	-- the genetics screen is full-screen; the column would peek out behind its barbell
	UIBus.GeneticsVisible.Event:Connect(function(visible) gui.Enabled = not visible end)

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

-- Pixel y (inside the safe area) of the column's bottom edge.
function RightColumn.Bottom()
	ensure()
	return column.AbsolutePosition.Y - column.Parent.AbsolutePosition.Y + column.AbsoluteSize.Y
end

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
