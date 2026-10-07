-- The column of small panels on the right of the screen (shake button, boost pills, quest + legend trackers).
-- Each script adds its own frame; the column stacks them with the standard gap so they never overlap.
-- Frames added with `idleOnly = true` hide while the player is on a machine (clean HUD while training, and room
-- for the machine panel on phones).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local UIBus = require(script.Parent.UIBus)

local RightColumn = {}

-- At the top right (under the Roblox top bar), top to bottom: small buttons (Skate, shake), the quest tracker, the body
-- map. It never covers the Growth Spurt bar (top center), the thumbstick, the jump button or the machine panel.
local WIDTH = 200 -- 176 on phones (set live in ensure)
local column, always, idle, bottom
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
		Position = UDim2.new(1, -Theme.Spacing.M, 0, Theme.Spacing.S + Theme.PillHeight + Theme.Spacing.S), -- top right, under the top-bar pills
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
	column:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() changed:Fire() end)
	always = container("Always", 1)
	-- the idle panels and the "bottom" ones (the body map) share a middle block: stacked on big screens; side by side on
	-- phones (bottom to the left), because a phone's right side has only ~200 px above the jump button
	local middle = Theme.New("Frame", { Name = "Middle", LayoutOrder = 2, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, Parent = column })
	local middleList = Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
	middleList.Parent = middle
	idle = container("Idle", 2)
	idle.Parent = middle
	bottom = container("Bottom", 3) -- always shown (the body map)
	bottom.Parent = middle
	bottom.Size = UDim2.new()
	bottom.AutomaticSize = Enum.AutomaticSize.XY
	local bottomPad = Theme.New("UIPadding", { Parent = bottom }) -- phones: starts below the Growth Spurt bar
	-- narrower on phones; every panel in it fills the column's width
	Theme.OnCompactChanged(function(isCompact)
		WIDTH = isCompact and 176 or 200
		RightColumn.Width = WIDTH
		column.Size = UDim2.fromOffset(WIDTH, 0)
		middleList.FillDirection = isCompact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		bottom.LayoutOrder = isCompact and 1 or 3
		bottomPad.PaddingTop = UDim.new(0, isCompact and 88 or 0) -- under the Growth Spurt bar (even with a two-line goal)
		for _, holder in ipairs({ always, idle, bottom }) do
			if holder ~= bottom then holder.Size = UDim2.fromOffset(WIDTH, 0) end
			for _, child in ipairs(holder:GetChildren()) do
				-- full-width panels follow the column; small ones (KeepWidth: Skate, the body map, the Stats chip) keep theirs
				if child:IsA("GuiObject") and not child:GetAttribute("KeepWidth") then child.Size = UDim2.new(0, WIDTH, child.Size.Y.Scale, child.Size.Y.Offset) end
			end
		end
	end)

	-- the genetics screen is full-screen (the column would peek out behind its barbell), and the other big screens (Title
	-- Book, Wardrobe, Crew, ...) are see-through: the quest tracker showed through them, over their Close buttons. The
	-- column steps aside while any of them is open (UIBus.CoverGuis).
	local playerGui = gui.Parent
	local geneticsUp = false
	local function refreshCovered()
		gui.Enabled = not geneticsUp and not UIBus.CoverOpen(playerGui)
	end
	UIBus.GeneticsVisible.Event:Connect(function(visible)
		geneticsUp = visible
		refreshCovered()
	end)
	local function watchCover(child)
		if child:IsA("ScreenGui") and table.find(UIBus.CoverGuis, child.Name) then
			child:GetPropertyChangedSignal("Enabled"):Connect(refreshCovered)
			refreshCovered()
		end
	end
	for _, child in ipairs(playerGui:GetChildren()) do watchCover(child) end
	playerGui.ChildAdded:Connect(watchCover)

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

-- Parent `frame` into the column; lower `order` sits higher. `idleOnly` = true: hidden while on a machine;
-- "bottom": always shown, under the idle panels.
function RightColumn.Add(frame, order, idleOnly)
	ensure()
	frame.LayoutOrder = order or 1
	frame.Parent = idleOnly == "bottom" and bottom or (idleOnly and idle or always)
	return frame
end

-- Show or hide the whole column.
function RightColumn.SetVisible(visible)
	ensure().Parent.Enabled = visible
end

return RightColumn
