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
-- Folding (owner, 15 Oct; the left menu's tab, mirrored): the cards sit in a drawer with a small graphite tab (gold
-- chevron) on its left edge, vertically centred on them. A tap slides the drawer right (X only, 0.25 s Quad Out) until
-- only the tab is left at the screen edge; the chevron points left while folded, right while open. Folded, a card that
-- becomes ready (a quest to hand in, TAP TO GROW, a posing round: priority >= Priority.CoachReady) shows a red dot on the
-- tab that pulses once. The choice is saved (settings.rightCollapsed). On a machine the drawer folds by itself (and its
-- tab hides when it would touch the weight panel); getting off brings the player's own choice back.
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
local drawer, tab, tabIcon, tabDot
local TAB = Vector2.new(24, 46)  -- mockup px (the left menu's tab); its touch area is bigger (see below)
local TAB_GAP = 6
local collapsedChoice = false     -- what the player chose (saved)
local training = false            -- on a machine: folded whatever the choice
local tabBlocked = false          -- the tab would touch the machine's weight panel
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
	-- the drawer: the cards and the tab on its left edge slide together
	drawer = New("Frame", {
		Name = "Drawer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -EDGE, 0, TOP),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	})
	column = New("Frame", {
		Name = "Column",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = drawer,
	}, { Theme.List(Enum.FillDirection.Vertical, "S", Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
	-- the tab: graphite, a gold chevron; the button is 44 px wide for the thumb, the visible tab inside it is TAB
	tab = New("TextButton", { Name = "Tab", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -TAB_GAP + (44 - TAB.X) / 2, 0.5, 0), Size = UDim2.fromOffset(44, math.max(TAB.Y, 48)), Visible = false, Parent = drawer })
	local face = New("Frame", { Name = "Face", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(TAB.X, TAB.Y),
		BackgroundColor3 = Colors.Pill, BackgroundTransparency = 0.15, Parent = tab }, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	Theme.BindPress(tab)
	tabIcon = require(script.Parent.Pieces).Icon("chevron-left", Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18), Parent = face })
	tabIcon:SetAttribute("KeepColor", true)
	tabDot = New("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 2, 0, 2), Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Colors.Red, Visible = false, ZIndex = 3, Parent = face }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Colors.Text, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		New("UIScale", { Name = "Pulse" }),
	})
	tab.Activated:Connect(function() RightColumn.SetCollapsed(not collapsedChoice, true) end)
	column:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		RightColumn.Layout(false)
		changed:Fire()
	end)
	Kit.OnTopbar(function()
		TOP = Kit.UnderTopbar(root)
		RightColumn.Layout(false)
		changed:Fire()
	end)
	task.spawn(function()
		local ClientData = require(ReplicatedStorage.Shared.ClientData)
		local data = ClientData.Get()
		if data and data.settings and data.settings.rightCollapsed == true then
			collapsedChoice = true
			RightColumn.Layout(false)
		end
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
		-- the tab would touch the weight panel (MachineHud's Panel) at its folded spot: hidden while training
		local function blocked(): boolean
			local hud = playerGui:FindFirstChild("MachineHud")
			local panel = hud and hud:FindFirstChild("Panel", true)
			if not panel or not tab then return false end
			local s = Kit.Scale()
			local tabTop = drawer.AbsolutePosition.Y + drawer.AbsoluteSize.Y / 2 - math.max(TAB.Y, 48) * s / 2
			local tabBottom = tabTop + math.max(TAB.Y, 48) * s
			local p, size = panel.AbsolutePosition, panel.AbsoluteSize
			return tabBottom > p.Y and tabTop < p.Y + size.Y
		end
		machineState.OnClientEvent:Connect(function(state)
			if state == "Enter" then
				training = true
				task.delay(0.35, function() -- (once the weight panel has slid in)
					if training then
						tabBlocked = blocked()
						RightColumn.Layout(true)
					end
				end)
				RightColumn.Layout(true)
			elseif state == "Exit" then
				training, tabBlocked = false, false
				RightColumn.Layout(true)
			end
		end)
		Players.LocalPlayer.CharacterAdded:Connect(function()
			training, tabBlocked = false, false
			RightColumn.Layout(false)
		end)
	end)
	return column
end

-- Places the drawer open or folded (and the tab and its dot). animate: slide (0.25 s Quad Out, X only).
local lastReady = false
function RightColumn.Layout(animate: boolean?)
	if not drawer then return end
	local folded = collapsedChoice or training
	local hasCards = column.AbsoluteSize.Y > 1
	-- folded: the cards go off the right edge; the tab's right side sits EDGE px from the edge
	local x = if folded then WIDTH + TAB_GAP - EDGE else -EDGE
	local goal = UDim2.new(1, x, 0, TOP)
	if animate then
		Theme.Tween(drawer, { Position = goal }, 0.25, Enum.EasingStyle.Quad)
		Theme.Tween(tabIcon, { Rotation = folded and 0 or 180 }, 0.25)
	else
		drawer.Position = goal
		tabIcon.Rotation = folded and 0 or 180
	end
	tab.Visible = hasCards and not (training and tabBlocked)
	if not folded then tabDot.Visible = false end
	changed:Fire()
end

-- the player's choice (save = remember it: settings.rightCollapsed)
function RightColumn.SetCollapsed(value: boolean, save: boolean?)
	ensure()
	if collapsedChoice == value then return end
	collapsedChoice = value
	if save then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local action = remotes and remotes:FindFirstChild("PlayerAction")
		if action then action:FireServer("SetSettings", { rightCollapsed = value }) end
	end
	RightColumn.Layout(true)
end
function RightColumn.IsCollapsed(): boolean
	return collapsedChoice or training
end

-- folded and a card became ready: the red dot, one pulse
local function noticeReady(ready: boolean)
	if ready and not lastReady and tabDot and (collapsedChoice or training) then
		tabDot.Visible = true
		local pulse = tabDot:FindFirstChild("Pulse")
		if pulse then
			pulse.Scale = 1
			Theme.Tween(pulse, { Scale = 1.6 }, 0.18)
			task.delay(0.18, function() Theme.Tween(pulse, { Scale = 1 }, 0.3, Theme.Motion.Bounce) end)
		end
	end
	lastReady = ready
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
	noticeReady(best ~= nil and bestPriority >= RightColumn.Priority.CoachReady)
	if drawer then task.defer(RightColumn.Layout, false) end
end

-- Parent `frame` into the column; lower `order` sits higher. `idleOnly` = true: idle items; "bottom": the bottom ones.
-- With a `priority` it is a card (one card at a time, see above).
-- (prompt 46, owner 22 Oct: "only TODAY'S QUEST, then TAP TO GROW under it. Nothing else stacked there.") Anything else
-- asked for is kept out of the column (its script can still change it; it just never shows).
RightColumn.Allowed = { DailyTracker = true, GrowthSpurt = true }
function RightColumn.Add(frame, order, idleOnly, priority: number?)
	ensure()
	if not RightColumn.Allowed[frame.Name] then
		frame.Parent = nil
		return frame
	end
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
	local barRow = New("Frame", { Name = "BarRow", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1, Parent = card })
	-- (owner's final kit: progress is teal; a gold tracker keeps its gold)
	local barColor = (props.color == Colors.Gold) and Colors.Gold or Colors.Teal
	local _, setBar, fill = Kit.Bar(barColor, { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 2), Parent = barRow }, { outline = 1 })
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
