-- The column on the right of the screen, just under Roblox's top bar (owner's UI v2, mockup 01_main_hud; owner's
-- declutter, 14 Oct). It shows ONE CARD at a time: of the cards that want to show, the one with the highest priority
-- (RightColumn.Priority: TAP TO GROW when ready, the posing competition, a coach quest ready to hand in, today's quest,
-- the legend challenge, the coach quest still going, the Growth Spurt progress). The rest wait; every quest is in the
-- Quests window. Small context buttons (Skate outdoors, Photo, Drink shake while you have one) stay above the card.
-- Built in mockup px inside a Kit.Root (it scales with the screen).
--   RightColumn.Add(frame, order, idleOnly, priority?)  idleOnly = true: idle items; "bottom": under them. With a
--                                            priority the frame is a CARD: its own Visible says it wants to show, the
--                                            column decides if it does; frame attribute CardPriority changes the priority
--   RightColumn.Tracker(props)               -> card api { frame, SetTitle, SetCount, SetText, SetProgress, SetFooter }
--                                            (props.priority: a card, default Priority.Daily)
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

local WIDTH = 176  -- mockup px (compact cards)
local TOP = 52     -- under Roblox's top bar (set from Kit.UnderTopbar)
local EDGE = 12
RightColumn.Width = WIDTH
RightColumn.Priority = { GrowReady = 100, Posing = 95, CoachReady = 80, Daily = 50, Legend = 40, Coach = 20, Grow = 10 }

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
	Kit.OnTopbar(function()
		TOP = Kit.UnderTopbar(root)
		column.Position = UDim2.new(1, -EDGE, 0, TOP)
		changed:Fire()
	end)
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

-- One card at a time: each card sits in its own slot; only the slot of the card that wants to show (its Visible) with
-- the highest CardPriority is shown.
local cards = {} -- card frame -> its slot
local function pickCard()
	local best, bestPriority = nil, -math.huge
	for card in pairs(cards) do
		local priority = card:GetAttribute("CardPriority") or 0
		if card.Visible and priority > bestPriority then best, bestPriority = card, priority end
	end
	for card, slot in pairs(cards) do slot.Visible = card == best end
end

-- Parent `frame` into the column; lower `order` sits higher. `idleOnly` = true: idle items; "bottom": the bottom ones.
-- With a `priority` it is a card (one card at a time, see above).
function RightColumn.Add(frame, order, idleOnly, priority: number?)
	ensure()
	local parent = idleOnly == "bottom" and bottom or (idleOnly and idle or always)
	if priority then
		local slot = New("Frame", { Name = frame.Name .. "Slot", LayoutOrder = order or 1, Size = UDim2.fromOffset(WIDTH, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, Visible = false, Parent = parent })
		if frame:GetAttribute("CardPriority") == nil then frame:SetAttribute("CardPriority", priority) end
		frame.Parent = slot
		cards[frame] = slot
		frame:GetPropertyChangedSignal("Visible"):Connect(pickCard)
		frame:GetAttributeChangedSignal("CardPriority"):Connect(pickCard)
		pickCard()
		return frame
	end
	frame.LayoutOrder = order or 1
	frame.Parent = parent
	return frame
end

-- A tracker card (mockup 01: "DAILY QUESTS  1/3", a line of text, a green bar with "34/50" in it).
-- props: { title, color (bar), order, idleOnly, icon? (an icon name before the title), iconColor?, name?,
--          clickable? (the card is a button: api.Activated), priority? (default Priority.Daily) }
-- Compact (owner, 14 Oct): a small title row, one or two lines of text, a thin bar.
function RightColumn.Tracker(props)
	ensure()
	local card = Theme.Panel({ Name = props.name or "Tracker", Piece = "hud_box", Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Clickable = props.clickable }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 7) }),
		Theme.List(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	local head = New("Frame", { Name = "Head", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Parent = card })
	local titleX = 0
	if props.icon then
		require(script.Parent.Pieces).Icon(props.icon, props.iconColor or Colors.Gold, { Size = UDim2.fromOffset(13, 13), Position = UDim2.fromOffset(0, 1), Parent = head })
		titleX = 17
	end
	local title = Kit.Text({ Name = "Title", Text = props.title or "", Font = "Title", TextSize = 12, Upper = true, Position = UDim2.fromOffset(titleX, 0),
		Size = UDim2.new(1, -titleX - 44, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head })
	local count = Kit.Text({ Name = "Count", Text = "", Font = "Number", TextSize = 12, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 44, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = head })
	local text = Kit.Text({ Name = "Text", LayoutOrder = 2, Text = "", Font = "Strong", TextSize = 11, TextColor3 = Color3.fromHex("#E9E3E5"), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	New("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 28), Parent = text }) -- (two lines at most)
	local barRow = New("Frame", { Name = "BarRow", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, Parent = card })
	-- (owner's final kit: progress is teal; a gold tracker keeps its gold)
	local barColor = (props.color == Colors.Gold) and Colors.Gold or Colors.Teal
	local _, setBar, fill = Kit.Bar(barColor, { Size = UDim2.new(1, 0, 0, 7), Position = UDim2.fromOffset(0, 2), Parent = barRow }, { outline = 1 })
	local footer = Kit.Text({ Name = "Footer", LayoutOrder = 4, Text = "", Font = "Body", TextSize = 10, TextColor3 = Colors.Muted, Visible = false,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	RightColumn.Add(card, props.order or 2, props.idleOnly, props.priority or RightColumn.Priority.Daily)
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
