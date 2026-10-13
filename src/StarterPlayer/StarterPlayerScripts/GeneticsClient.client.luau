-- GeneticsClient: the genetics reveal (first join) and reroll screen (owner, 14 Oct: rebuilt as ONE centered panel in the
-- final kit "BLACK + GOLD", like the Store, so it fits every phone; replaces the full-screen 3D plate stage).
-- In mockup px inside a Kit.Root (UIScale follows the screen), at most 600 wide, so it always fits 844x390 and smaller.
-- The gym stays visible around it, darkened only behind the panel; the HUD steps aside (UIBus.GeneticsVisible).
--  * Header: GENETICS (NEW GENETICS after a reroll) on the left, the DNA token chip on the right.
--  * Left: OVERALL, the overall grade plate and its word ("BLESSED") in the gold heavy italic, "View odds" (gray link).
--  * Right: the six groups in a 2-column grid with fixed rows (name, gold grade plate, "x1.50"; after a reroll a green
--    "UP" or gray "DOWN" beside it), then Frame and Body as two chips (they wrap to two lines, never overflow).
--  * Bottom row: REROLL · 1 DNA TOKEN (quiet; "Reroll · free", or dimmed "No DNA tokens") and KEEP (the red CTA). A good
--    roll (overall A or S, or any S) asks first, in the same row: "Replace your A genetics? You can't get them back."
--  * Reveal (under 3 s, best grade first): each row pops in with a clank (pitch by grade), S rows shine once, then the
--    overall plate drops in with a thud and its word fades in. A tap / click (or Space) skips to the end.
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Genetics = require(Config.Genetics)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Icons = require(Shared.UI.Icons)
local UIBus = require(Shared.UI.UIBus)
local SideMenu = require(Shared.UI.SideMenu)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

------------------------------------------------------------------------
-- Tuning (mockup px)
------------------------------------------------------------------------
local W = 600                      -- the panel's width (owner: at most 600)
local LEFT_W = 168                 -- the overall column
local ROW_H, ROW_GAP = 46, 8       -- the group rows (fixed height: nothing can overlap)
local BUTTON_H = 46                -- the bottom row's buttons (touch targets over 44)
local WORDS = { S = "Genetic Freak", A = "Blessed", B = "Gifted", C = "Average", D = "Hardgainer" }
local CLANK_PITCH = { S = 0.85, A = 0.92, B = 1, C = 1.06, D = 1.12 }
local TIME = { Gap = 0.2, Pop = 0.22, Drop = 0.3 } -- (the whole reveal stays under 3 seconds)

------------------------------------------------------------------------
-- Text for frames / body types
------------------------------------------------------------------------
local function percentText(amount)
	return string.format("+%d%%", math.floor(amount * 100 + 0.5))
end
-- "+10% Arms" / "+5% all" / "+15% Back, Legs, Traps"
local function bonusText(bonus)
	local parts = {}
	if bonus.all then table.insert(parts, percentText(bonus.all) .. " all") end
	local named, amount = {}, nil
	for id, value in pairs(bonus.groups or {}) do table.insert(named, Muscles.GroupById[id].name) amount = value end
	for id, value in pairs(bonus.muscles or {}) do table.insert(named, Muscles.ById[id].name) amount = value end
	table.sort(named)
	if #named > 0 then table.insert(parts, percentText(amount) .. " " .. table.concat(named, ", ")) end
	return table.concat(parts, ", ")
end
local function frameBonus(frame)
	local bonus = bonusText(frame.bonus)
	return bonus ~= "" and bonus or "no bonus"
end
local function bodyBonus(body)
	local bonus = bonusText(body.bonus)
	if bonus == "" then
		bonus = if body.detailLevelMult < 1 then "abs show earlier" elseif body.detailLevelMult > 1 then "abs show later" else "no bonus"
	end
	return bonus
end
local function percent(list, entry)
	local total = 0
	for _, e in ipairs(list) do total += e.weight end
	return math.floor(entry.weight / total * 100 + 0.5)
end
local function multOf(grade)
	return Genetics.GradeById[grade].mult
end
local function multText(grade)
	return string.format("x%.2f", multOf(grade))
end

------------------------------------------------------------------------
-- The screen
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "GeneticsScreen", Enabled = false, DisplayOrder = 26, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
-- a light dim over the whole screen (the gym stays visible); taps on it skip the reveal
local skipCatcher = New("TextButton", { Name = "Skip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.82,
	Text = "", AutoButtonColor = false, Parent = gui })
local root = Kit.Root(gui)

-- the soft dark backing behind the panel only (stacked rounded frames: a soft edge, no hard box)
local backing = New("Frame", { Name = "Backing", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = root })
for i, grow in ipairs({ 36, 24, 12 }) do
	New("Frame", { Name = "Soft" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, grow, 1, grow),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.82, Parent = backing }, {
		New("UICorner", { CornerRadius = UDim.new(0, 18 + grow / 2) }),
	})
end

local panel = Theme.Panel({ Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Clickable = true, Parent = root }, {
	New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14) }),
	Theme.List(Vertical, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
local pop = New("UIScale", { Parent = panel })
local function fitBacking()
	backing.Size = UDim2.fromOffset(panel.AbsoluteSize.X / Kit.Scale(), panel.AbsoluteSize.Y / Kit.Scale())
end
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBacking)

-- Header: GENETICS left, the DNA token chip right
local header = New("Frame", { Name = "Header", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = panel })
local titleLabel = Kit.Text({ Name = "Title", Text = "GENETICS", Font = "Title", TextSize = 22, Size = UDim2.new(1, -170, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })
local _tokenChip, tokenText = Kit.PricePill("0 DNA TOKENS", { Name = "Tokens", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromOffset(0, 26), Parent = header })
tokenText.TextSize = 13
New("Frame", { Name = "Divider", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9,
	BorderSizePixel = 0, Parent = panel })

-- Body: the overall column (left), the groups and the frame / body chips (right)
local body = New("Frame", { Name = "Body", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = panel }, {
	Theme.List(Horizontal, 14, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local left = New("Frame", { Name = "Overall", LayoutOrder = 1, Size = UDim2.fromOffset(LEFT_W, 3 * ROW_H + 2 * ROW_GAP), BackgroundTransparency = 1, Parent = body })
Kit.Text({ Name = "Label", Text = "OVERALL", Font = "Label", TextSize = 12, Size = UDim2.new(1, 0, 0, 16), Parent = left })
local overallBadge = Kit.GradeBadge("B", 58, { Name = "Grade", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Parent = left })
local overallScale = New("UIScale", { Parent = overallBadge })
local wordLabel = Kit.GoldText(Kit.Text({ Name = "Word", Text = "", Font = "Title", TextSize = 24, Upper = true, TextWrapped = true,
	Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 56), TextYAlignment = Enum.TextYAlignment.Top, Parent = left }))
local oddsLink = New("TextButton", { Name = "ViewOdds", Text = "<u>View odds</u>", RichText = true, FontFace = Theme.Fonts.Regular, TextSize = 12,
	TextColor3 = Colors.Muted, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(110, 24), Parent = left })

local right = New("Frame", { Name = "Groups", LayoutOrder = 2, Size = UDim2.new(1, -(LEFT_W + 14), 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Parent = body }, {
	Theme.List(Vertical, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local grid = New("Frame", { Name = "Grid", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 3 * ROW_H + 2 * ROW_GAP), BackgroundTransparency = 1, Parent = right }, {
	New("UIGridLayout", { CellSize = UDim2.new(0.5, -ROW_GAP / 2, 0, ROW_H), CellPadding = UDim2.fromOffset(ROW_GAP, ROW_GAP), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal }),
})
local rows = {} -- group id -> { frame, scale, badge, mult, change }
for index, group in ipairs(Muscles.Groups) do
	local row = Kit.Card({ Name = group.id, LayoutOrder = index, Parent = grid })
	local scale = New("UIScale", { Parent = row })
	-- name (left, cut with "..." if it ever gets too long), then the grade plate and the multiplier on the right
	Kit.Text({ Name = "Name", Text = group.name, Font = "Title", TextSize = 13, Upper = true, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -92, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local badge = Kit.GradeBadge("B", 24, { Name = "Grade", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Parent = row })
	local mult = Kit.Text({ Name = "Mult", Text = "", Font = "Number", TextSize = 13, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(40, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	local change = Kit.Text({ Name = "Change", Text = "", Font = "Title", TextSize = 9, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 3),
		Size = UDim2.fromOffset(40, 11), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = row })
	rows[group.id] = { frame = row, scale = scale, badge = badge, mult = mult, change = change }
end

-- Frame and Body chips (wrap to two lines on narrow screens, never overflow)
local chipsList = Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
chipsList.Wraps = true
local chips = New("Frame", { Name = "Chips", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = right }, { chipsList })
local function chip(order)
	local c = Theme.Panel({ Name = "Chip" .. order, LayoutOrder = order, Piece = "well", Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Parent = chips }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(W - LEFT_W - 46, 26), Parent = c })
	local label = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 11, RichText = true, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = c })
	return label
end
local frameChip, bodyChip = chip(1), chip(2)
local function setChip(label, kind, name, bonus)
	local gray = "#" .. Colors.Muted:ToHex()
	label.Text = string.format('<font color="%s">%s</font>  <b>%s</b>  <font color="%s">· %s</font>', gray, kind, name, gray, bonus)
end

-- Bottom row: (the confirm line) REROLL and KEEP, both inside the panel
local bottom = New("Frame", { Name = "Bottom", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, BUTTON_H), BackgroundTransparency = 1, Parent = panel }, {
	Theme.List(Horizontal, 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
})
local confirmText = Kit.Text({ Name = "Confirm", LayoutOrder = 0, Text = "", Font = "Body", TextSize = 12, TextWrapped = true, Size = UDim2.new(1, -346, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = bottom })
local skipHint = Kit.Text({ Name = "SkipHint", LayoutOrder = 0, Text = "Tap to skip", Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Size = UDim2.new(1, -346, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = bottom })
local rerollButton = Kit.Button("Quiet", "Reroll · 1 DNA token", { Name = "Reroll", LayoutOrder = 1, Parent = bottom }, { width = 200, height = BUTTON_H, textSize = 14 })
local keepButton = Kit.Button("Red", "Keep", { Name = "Keep", LayoutOrder = 2, Parent = bottom }, { width = 116, height = BUTTON_H, textSize = 18 })

-- Odds panel (opened by "View odds"), over the genetics panel
local oddsPanel = Theme.Panel({ Name = "Odds", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 5, Parent = root }, {
	New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 16) }),
	Theme.List(Vertical, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})
local oddsHeader = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = oddsPanel })
Kit.Text({ Text = "ODDS", Font = "Title", TextSize = 20, Size = UDim2.new(1, -50, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsHeader })
local oddsClose = Kit.CloseButton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Parent = oddsHeader })
Kit.Text({ LayoutOrder = 2, Text = "Grade (each group)", Font = "Label", TextSize = 11, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
local gradeRow = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = oddsPanel }, { Theme.List(Horizontal, 14, Enum.HorizontalAlignment.Left) })
for index, grade in ipairs(Genetics.Grades) do
	local cell = New("Frame", { LayoutOrder = index, Size = UDim2.fromOffset(52, 48), BackgroundTransparency = 1, Parent = gradeRow }, { Theme.List(Vertical, 4) })
	Kit.GradeBadge(grade.id, 26, { LayoutOrder = 1, Parent = cell })
	Kit.Text({ LayoutOrder = 2, Text = percent(Genetics.Grades, grade) .. "%", Font = "Number", TextSize = 12, Size = UDim2.new(1, 0, 0, 16), Parent = cell })
end
local function oddsList(order, title, list)
	local items = {}
	for _, entry in ipairs(list) do table.insert(items, entry.name .. " " .. percent(list, entry) .. "%") end
	Kit.Text({ LayoutOrder = order, Text = title, Font = "Label", TextSize = 11, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
	Kit.Text({ LayoutOrder = order + 1, Text = table.concat(items, "  ·  "), Font = "Body", TextSize = 12, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
end
oddsList(4, "Frame", Genetics.Frames)
oddsList(6, "Body type", Genetics.BodyTypes)

-- Side menu button
local menuButton = SideMenu.Add("Genetics", "Genetics", Icons.DNA, 3)

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local isOpen, revealing, skipping = false, false, false
local current = nil -- the genetics on screen
local confirming = false

local function play(name, opts)
	if skipping then return nil end
	return Audio.Play2D(name, opts)
end
local function pause(seconds)
	local untilTime = os.clock() + seconds
	while not skipping and isOpen and os.clock() < untilTime do task.wait() end
end

local function refreshButtons()
	local data = ClientData.Get()
	local canReroll = data.freeReroll or (data.dnaTokens or 0) > 0
	tokenText.Text = (data.dnaTokens or 0) .. ((data.dnaTokens or 0) == 1 and " DNA TOKEN" or " DNA TOKENS")
	if confirming then
		Kit.SetButton(rerollButton, "Quiet", "Cancel")
		Kit.SetButton(keepButton, "Red", "Reroll")
	else
		Kit.SetButton(rerollButton, canReroll and "Quiet" or "Disabled", canReroll and (data.freeReroll and "Reroll · free" or "Reroll · 1 DNA token") or "No DNA tokens")
		Kit.SetButton(keepButton, "Red", "Keep")
	end
	rerollButton.Active = (canReroll or confirming) and not revealing
	keepButton.Active = not revealing
	confirmText.Visible = confirming
	skipHint.Visible = revealing and not confirming
end

-- Fill the rows / overall / chips (shown = false: hidden, the reveal pops them in)
local function fill(genetics, previous, shown: boolean)
	for _, group in ipairs(Muscles.Groups) do
		local row = rows[group.id]
		local grade = genetics.grades[group.id]
		Kit.SetGrade(row.badge, grade)
		row.mult.Text = multText(grade)
		local before = previous and previous.grades[group.id]
		row.change.Visible = before ~= nil and before ~= grade
		if before and before ~= grade then
			local better = multOf(grade) > multOf(before)
			row.change.Text = better and "UP" or "DOWN"
			row.change.TextColor3 = better and Colors.Green or Colors.Muted
		end
		row.scale.Scale = shown and 1 or 0.6
		row.frame.Visible = shown
	end
	Kit.SetGrade(overallBadge, genetics.overall)
	overallBadge.Visible = shown
	wordLabel.Text = WORDS[genetics.overall] or ""
	wordLabel.Visible = shown
	local frame, bodyType = Genetics.FrameById[genetics.frame], Genetics.BodyTypeById[genetics.bodyType]
	setChip(frameChip, "FRAME", frame.name, frameBonus(frame))
	setChip(bodyChip, "BODY", bodyType.name, bodyBonus(bodyType))
end

-- The reveal: best grade first, each row pops in with a clank; then the overall plate with a thud and its word
local function runReveal(genetics, previous)
	revealing, skipping = true, false
	current = genetics
	titleLabel.Text = previous and "NEW GENETICS" or "GENETICS"
	confirming = false
	fill(genetics, previous, false)
	refreshButtons()
	local order = {}
	for index, group in ipairs(Muscles.Groups) do table.insert(order, { id = group.id, index = index, grade = genetics.grades[group.id] }) end
	table.sort(order, function(a, b)
		local ma, mb = multOf(a.grade), multOf(b.grade)
		if ma ~= mb then return ma > mb end
		return a.index < b.index
	end)
	for _, item in ipairs(order) do
		if not isOpen then return end
		local row = rows[item.id]
		row.frame.Visible = true
		if skipping then
			row.scale.Scale = 1
		else
			Theme.Tween(row.scale, { Scale = 1 }, TIME.Pop, Enum.EasingStyle.Back)
			play("GeneticsClank", { pitch = CLANK_PITCH[item.grade] })
			if item.grade == "S" then
				task.delay(TIME.Pop, function() play("GeneticsShimmer") Theme.Shine(row.frame) end)
			end
		end
		pause(TIME.Gap)
	end
	if not isOpen then return end
	-- the overall plate drops in, then its word
	overallBadge.Visible = true
	if skipping then
		overallScale.Scale = 1
	else
		overallScale.Scale = 1.6
		Theme.Tween(overallScale, { Scale = 1 }, TIME.Drop, Enum.EasingStyle.Back)
		play("GeneticsThud")
		play("GeneticsThudLow")
		pause(TIME.Drop)
	end
	wordLabel.Visible = true
	Theme.Fade(wordLabel, true, skipping and 0 or 0.3)
	revealing, skipping = false, false
	refreshButtons()
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function freeze()
	return Enum.ContextActionResult.Sink
end

local function open()
	if isOpen then return end
	isOpen = true
	SideMenu.SetHidden(true) -- the HUD steps aside (the top bar, right column, stamina and toasts follow GeneticsVisible)
	menuButton:SetActive(true)
	oddsPanel.Visible = false
	UIBus.GeneticsVisible:Fire(true)
	ContextActionService:BindActionAtPriority("GeneticsFreeze", freeze, false, Enum.ContextActionPriority.High.Value + 100,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	Audio.PlayUI("Whoosh")
	gui.Enabled = true
	pop.Scale = Kit.OpenScale
	Theme.Tween(pop, { Scale = 1 }, Kit.OpenTime)
	Theme.Fade(panel, true, Kit.OpenTime)
	task.defer(fitBacking)
	task.spawn(runReveal, ClientData.Get().genetics, nil)
end

local function close()
	if not isOpen then return end
	isOpen = false
	skipping = true -- (a running reveal finishes at once)
	menuButton:SetActive(false)
	ContextActionService:UnbindAction("GeneticsFreeze")
	SideMenu.SetHidden(false)
	UIBus.GeneticsVisible:Fire(false)
	gui.Enabled = false
end

local function keep()
	if revealing then return end
	if not ClientData.Get().onboarding.geneticsRevealed then
		Remotes.PlayerAction:FireServer("GeneticsSeen")
	end
	close()
end

-- skip: tap anywhere (or Space / Enter) while the reveal runs
skipCatcher.Activated:Connect(function()
	if revealing then skipping = true end
end)
panel.Activated:Connect(function()
	if revealing then skipping = true end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not isOpen or not revealing then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then skipping = true end
end)

-- Reroll: asks first when a good roll (overall A or S, or any S plate) is about to be replaced
local pendingReroll = false
local function doReroll()
	if revealing or not isOpen then return end
	revealing = true
	pendingReroll = true
	confirming = false
	refreshButtons()
	local previous = table.clone(current or ClientData.Get().genetics)
	previous.grades = table.clone(previous.grades)
	Remotes.PlayerAction:FireServer("Reroll")
	task.spawn(function()
		local deadline = os.clock() + 5
		while pendingReroll and os.clock() < deadline do task.wait() end
		if isOpen then runReveal(ClientData.Get().genetics, previous) end
	end)
end
local function needsConfirm()
	local genetics = current or ClientData.Get().genetics
	if genetics.overall == "S" or genetics.overall == "A" then return true end
	for _, grade in pairs(genetics.grades) do if grade == "S" then return true end end
	return false
end
rerollButton.Activated:Connect(function()
	if revealing or not rerollButton.Active then return end
	if confirming then -- (Cancel)
		confirming = false
		refreshButtons()
		return
	end
	if needsConfirm() then
		local genetics = current or ClientData.Get().genetics
		confirmText.Text = "Replace your " .. genetics.overall .. " genetics? You can't get them back."
		confirming = true
		refreshButtons()
		Theme.Fade(confirmText, true, 0.2)
	else
		doReroll()
	end
end)
keepButton.Activated:Connect(function()
	if confirming then doReroll() else keep() end
end)
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind)
	if kind == "Rerolled" then pendingReroll = false end
end)

oddsLink.Activated:Connect(function()
	oddsPanel.Visible = true
	Theme.Fade(oddsPanel, true)
end)
oddsClose.Activated:Connect(function()
	local tween = Theme.Fade(oddsPanel, false)
	if tween then tween.Completed:Connect(function() oddsPanel.Visible = false end) else oddsPanel.Visible = false end
end)

ClientData.Changed:Connect(function(path)
	if isOpen and (path[1] == "dnaTokens" or path[1] == "freeReroll") and not revealing then refreshButtons() end
end)

menuButton.Activated:Connect(function()
	if isOpen then keep() else open() end
end)
UIBus.OpenGenetics.Event:Connect(open)

-- First join: reveal right after the player presses Play on the menu screen.
task.spawn(function()
	local data = ClientData.Get()
	UIBus.WaitForMenu()
	if not data.onboarding.geneticsRevealed then
		task.wait(0.6)
		open()
	end
end)
