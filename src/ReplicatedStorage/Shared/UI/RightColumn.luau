-- The column of small HUD cards on the right of the screen (owner's UI v2, mockup 01_main_hud): tracker cards (daily
-- quests, coach quest, legend) and the GROW tile (Growth Spurt), plus small buttons (Skate, Photo, Drink shake). Built
-- in mockup px inside a Kit.Root (it scales with the screen). Each script adds its own frame; the column stacks them
-- with an 8px gap so they never overlap.
--   RightColumn.Add(frame, order, idleOnly)  idleOnly = true: idle cards; "bottom": under the idle cards
--   RightColumn.Tracker(props)               -> card api { frame, SetTitle, SetCount, SetText, SetProgress, SetFooter }
--   RightColumn.Chip(icon, color, order)     -> a boost icon in the row above the stamina bar (HudBottom.Chip)
--   RightColumn.Width                        the column's width (mockup px)
-- On a machine the whole column steps aside (the right side belongs to the weight panel, mockup 02).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local UIBus = require(script.Parent.UIBus)

local New, Colors = Theme.New, Theme.Colors

local RightColumn = {}

local WIDTH = 196  -- mockup px
local TOP = 52     -- under the top bar
local EDGE = 12
RightColumn.Width = WIDTH

local column, always, idle, bottom
local changed = Instance.new("BindableEvent")
RightColumn.Changed = changed.Event -- fires when the column's size changes (notifications follow it)

local function container(name, order, parent)
	return New("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent or column,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
end

local function ensure()
	if column then return column end
	local gui = Theme.ScreenGui({ Name = "RightColumn", DisplayOrder = 3, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = Kit.Root(gui)
	column = New("Frame", {
		Name = "Column",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -EDGE, 0, TOP),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
	column:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() changed:Fire() end)
	always = container("Always", 1)
	local middle = New("Frame", { Name = "Middle", LayoutOrder = 3, Size = UDim2.fromOffset(WIDTH, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = column },
		{ Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
	idle = container("Idle", 1, middle)
	bottom = container("Bottom", 2, middle) -- always shown (the Growth Spurt card)

	-- big screens step aside: the genetics screen and the full-width screens (UIBus.CoverGuis)
	local playerGui = gui.Parent
	local geneticsUp = false
	local function refreshCovered()
		gui.Enabled = not geneticsUp and not UIBus.MenuOpen and not UIBus.CoverOpen(playerGui)
	end
	-- (hidden behind the main menu: MenuClient raises UIBus.MenuOpen when it starts, which can be after this runs)
	UIBus.MenuClosed.Event:Connect(refreshCovered)
	task.spawn(function()
		while true do
			task.wait(0.4)
			refreshCovered()
		end
	end)
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

	-- on a machine the right side belongs to the weight panel (mockup 02): the column steps aside
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		local machineState = remotes and remotes:WaitForChild("MachineState", 30)
		if not machineState then return end
		machineState.OnClientEvent:Connect(function(state)
			if state == "Enter" then
				column.Visible = false
			elseif state == "Exit" then
				column.Visible = true
			end
		end)
		Players.LocalPlayer.CharacterAdded:Connect(function() column.Visible = true end)
	end)
	return column
end

-- Root-relative y (mockup px) of the column's bottom edge.
function RightColumn.Bottom()
	ensure()
	return TOP + column.AbsoluteSize.Y / Kit.Scale()
end

-- Parent `frame` into the column; lower `order` sits higher. `idleOnly` = true: idle cards; "bottom": the bottom cards.
function RightColumn.Add(frame, order, idleOnly)
	ensure()
	frame.LayoutOrder = order or 1
	frame.Parent = idleOnly == "bottom" and bottom or (idleOnly and idle or always)
	return frame
end

-- A tracker card (mockup 01: "DAILY QUESTS  1/3", a line of text, a green bar with "34/50" in it).
-- props: { title, color (bar), order, idleOnly, icon? (an icon name before the title), iconColor?, name?,
--          clickable? (the card is a button: api.Activated) }
function RightColumn.Tracker(props)
	ensure()
	local card = Theme.Panel({ Name = props.name or "Tracker", Piece = "hud_box", Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Clickable = props.clickable }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }),
		Theme.List(Enum.FillDirection.Vertical, 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	local head = New("Frame", { Name = "Head", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = card })
	local titleX = 0
	if props.icon then
		require(script.Parent.Pieces).Icon(props.icon, props.iconColor or Colors.Gold, { Size = UDim2.fromOffset(15, 15), Position = UDim2.fromOffset(0, 2), Parent = head })
		titleX = 20
	end
	local title = Kit.Text({ Name = "Title", Text = props.title or "", Font = "Title", TextSize = 15, Upper = true, Position = UDim2.fromOffset(titleX, 0),
		Size = UDim2.new(1, -titleX - 44, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head })
	local count = Kit.Text({ Name = "Count", Text = "", Font = "Number", TextSize = 15, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 44, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = head })
	local text = Kit.Text({ Name = "Text", LayoutOrder = 2, Text = "", Font = "Strong", TextSize = 13, TextColor3 = Color3.fromHex("#E9E3E5"), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local barRow = New("Frame", { Name = "BarRow", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = card })
	-- (owner's final kit: progress is teal; a gold tracker keeps its gold)
	local barColor = (props.color == Colors.Gold) and Colors.Gold or Colors.Teal
	local _, setBar, fill = Kit.Bar(barColor, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 3), Parent = barRow })
	local footer = Kit.Text({ Name = "Footer", LayoutOrder = 4, Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Visible = false,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	RightColumn.Add(card, props.order or 2, props.idleOnly)
	local api = { frame = card, title = title, text = text, count = count, Activated = props.clickable and card.Activated or nil }
	function api.SetTitle(_, value) title.Text = value end
	function api.SetCount(_, value) count.Text = value or "" end
	function api.SetText(_, value)
		text.Text = value or ""
		text.Visible = (value or "") ~= ""
	end
	-- fraction 0..1 (nil hides the bar) and the numbers in it ("34/50")
	function api.SetProgress(_, fraction, label)
		barRow.Visible = fraction ~= nil
		if fraction then setBar(fraction) end -- (the bar shows no numbers in this kit; the count is in the header)
	end
	function api.SetFooter(_, value)
		footer.Text = value or ""
		footer.Visible = (value or "") ~= ""
	end
	function api.SetColor(_, color)
		local gloss = fill:FindFirstChild("Gloss")
		if gloss then gloss.Color = Kit.Metal(color == Colors.Gold and Colors.Gold or Colors.Teal) end
	end
	return api
end

-- A boost icon (smoothies, the shake, rush hour, server boost): it lives in the row above the stamina bar now.
function RightColumn.Chip(icon: string, color: Color3, order: number?)
	return require(script.Parent.HudBottom).Chip(icon, color, order)
end

-- Show or hide the whole column.
function RightColumn.SetVisible(visible)
	local c = ensure()
	c:FindFirstAncestorOfClass("ScreenGui").Enabled = visible
end

return RightColumn
