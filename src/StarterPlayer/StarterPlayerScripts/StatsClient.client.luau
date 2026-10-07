-- StatsClient: the Stats button, the Muscles button and the "Your muscles" panel.
--  * Stats (menu button): shows / hides your stats as labels around your character in the world (StatsLabelsClient does
--    the drawing; this script fires UIBus.StatsLabels). Hidden by default. The tutorial's "open Stats" step counts it.
--  * While the labels are shown a small "Muscles" button sits at the bottom center of the screen (above the machine
--    panel while you lift). It opens the full panel.
--  * "Your muscles" panel: the Growth Spurt goal (with the Growth Spurt button when ready), then the six groups as
--    cards: grade badge, level or Max (soft gold), genetics, each muscle with a bar and its level, "Needs work" (soft
--    red) on the weakest group when there is no tie. A muscle held back by the look balance cap (Config.LookBalance) shows
--    a small lock next to its bar and a faint segment for the held-back part; hovering / tapping it shows which partner
--    to train in the card's bottom line. It sits on top of everything, the rest of the HUD is switched off
--    behind it, every card fits (the area scrolls on short screens), and it closes with the X, Esc or a tap outside.
--  * The Growth Spurt moment (a line of text, a bell, a chalk burst) is played here too.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local Genetics = require(Config.Genetics)
local GrowthSpurts = require(Config.GrowthSpurts)
local LookBalance = require(Config.LookBalance)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal
local Left, Top = Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top

local CARD_HEIGHT = 160 -- fits a group's name row, genetics row, up to 4 muscle rows and its exercises line
local ROW_HEIGHT = 16

------------------------------------------------------------------------
-- The Stats button: labels around the character, on / off
------------------------------------------------------------------------
local statsButton = SideMenu.Add("Stats", "Stats", Icons.Flex, 1)
local labelsOn = false
local musclesOpen = false
local musclesTile = nil -- (set below, with the left menu tile)

------------------------------------------------------------------------
-- The "Your muscles" panel
------------------------------------------------------------------------
local screen = Theme.ScreenGui({ Name = "MusclesScreen", DisplayOrder = 60, Enabled = false, Parent = playerGui }) -- above notifications (50)
screen.ScreenInsets = Enum.ScreenInsets.None
local backdrop = New("TextButton", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = screen }) -- (no dark backdrop: the world is blurred instead)
local windowRoot = New("Frame", {
	Name = "WindowRoot",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.94, 0.92),
	BackgroundTransparency = 1,
	Parent = Theme.SafeArea(backdrop),
}, { Theme.Limit(Vector2.new(300, 220), Vector2.new(900, 680)) })
local window = Theme.Panel({
	Name = "Window",
	Size = UDim2.fromScale(1, 1),
	Active = true, -- taps inside the window never reach the backdrop (which closes it)
	Parent = windowRoot,
}, { Theme.Pad("M"), Theme.List(Vertical, "S", Left, Top) })
-- frosted glass: light and see-through with a thin white border
window.BackgroundColor3 = Color3.new(1, 1, 1)
window.BackgroundTransparency = 0.85
local windowStroke = window:FindFirstChildOfClass("UIStroke")
if windowStroke then
	windowStroke.Color = Color3.new(1, 1, 1)
	windowStroke.Transparency = 0.6
end

-- the world blurs behind the panel (tweened; always cleared when it closes)
local Lighting = game:GetService("Lighting")
local oldBlur = Lighting:FindFirstChild("MusclesBlur")
if oldBlur then oldBlur:Destroy() end
local blur = Instance.new("BlurEffect")
blur.Name = "MusclesBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting
local blurToken = 0
local function setBlur(on)
	blurToken += 1
	local token = blurToken
	if on then blur.Enabled = true end
	Theme.Tween(blur, { Size = on and 16 or 0 }, 0.25)
	if not on then
		task.delay(0.35, function()
			if token == blurToken then
				blur.Size = 0
				blur.Enabled = false
			end
		end)
	end
end

-- title row with the close button (the window has a list layout, so the button lives in this row)
local header = New("Frame", { Name = "Header", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = window })
Theme.Text({ Text = "Your muscles", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, -(Theme.MinTouch + Spacing.S), 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local closeButton = Theme.Button("Secondary", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch),
	Parent = header,
}, { New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 }, { Icons.Close(Colors.Text) }) })

-- the Growth Spurt goal
local goal = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = window },
	{ Theme.List(Vertical, "XS", Left, Top) })
local goalTitleRow = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = goal })
local goalTitle = Theme.Text({ Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(0.7, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = goalTitleRow })
local goalHeight = Theme.Text({ Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.3, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = goalTitleRow })
local goalBlocks = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, Parent = goal }, { Theme.List(Horizontal, "XS") })
local goalFills = {}
for index, group in ipairs(Muscles.Groups) do
	local back = New("Frame", { LayoutOrder = index, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = goalBlocks },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	goalFills[group.id] = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
end
local goalLabel = Theme.Text({ LayoutOrder = 3, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = goal })
local spurtButton = Theme.Button("Primary", { Name = "GrowthSpurt", LayoutOrder = 4, Size = UDim2.new(0, 220, 0, Theme.MinTouch), Visible = false, Parent = goal }, {
	Theme.Text({ Text = "Growth Spurt", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

-- the six groups: cards that always fit their muscles; the area scrolls on short screens
local scroll = New("ScrollingFrame", {
	Name = "Groups",
	LayoutOrder = 3,
	Size = UDim2.fromScale(1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Colors.Text,
	ScrollBarImageTransparency = 0.6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Parent = window,
}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
local grid = New("UIGridLayout", {
	CellPadding = UDim2.fromOffset(Spacing.S, Spacing.S),
	CellSize = UDim2.new(0.5, -Spacing.S, 0, CARD_HEIGHT),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = scroll,
})

local hintRow -- (defined right below; the rows connect to it)
local cards = {} -- [groupId] = { level, disc, grade, mult, needs, muscles = { [id] = { level, fill, held, lock, hint } }, exercises, hinting }
-- The card's bottom line: the exercises, or (hovering / tapping a capped muscle) "Look capped - train Back to unlock".
-- on = true / false (hover), nil = toggle (tap).
local function showBottomLine(card)
	local row = card.hinting and card.muscles[card.hinting]
	if row and row.hint then
		card.exercises.Text = row.hint
		card.exercises.TextColor3 = Colors.Text
	else
		card.exercises.Text = card.exercisesText or ""
		card.exercises.TextColor3 = Colors.Muted
	end
end
hintRow = function(groupId: string, muscleId: string, on: boolean?)
	local card = cards[groupId]
	if not card then return end
	if on == nil then on = card.hinting ~= muscleId end
	if on then card.hinting = muscleId elseif card.hinting == muscleId then card.hinting = nil end
	showBottomLine(card)
end
for index, group in ipairs(Muscles.Groups) do
	local frame = New("Frame", { Name = group.id, LayoutOrder = index, BackgroundColor3 = Colors.Panel, BackgroundTransparency = 0.6, Parent = scroll },
		{ Theme.Round("Panel"), Theme.Stroke(), Theme.Pad("S"), Theme.List(Vertical, "XS", Left, Top) })
	local top = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = frame }, { Theme.List(Horizontal, "S", Left) })
	local disc = Theme.RankTag("B", { LayoutOrder = 1, Size = UDim2.fromOffset(20, 18), Parent = top })
	local grade = disc
	local nameCol = New("Frame", { LayoutOrder = 2, Size = UDim2.new(0.36, 0, 1, 0), BackgroundTransparency = 1, Parent = top })
	Theme.Text({ Text = group.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = nameCol })
	-- the group's EXP: takes the rest of the row so six or seven digits fit
local level = Theme.Text({ LayoutOrder = 3, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(0.64, -34, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = top })
	local sub = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Parent = frame })
	local mult = Theme.Text({ Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = sub })
	local needs = Theme.Text({ Text = "Needs work", Font = "Regular", TextSize = "Small", TextColor3 = Colors.NeedsWork, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = sub })
	local muscleRows = {}
	for m, muscle in ipairs(group.muscles) do
		local row = New("Frame", { Name = muscle.id, LayoutOrder = 2 + m, Size = UDim2.new(1, 0, 0, ROW_HEIGHT), BackgroundTransparency = 1, Parent = frame })
		Theme.Text({ Text = muscle.name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(0.34, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		local back = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.36, 0, 0.5, 0), Size = UDim2.new(0.12, 0, 0, 5), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = row }, { Theme.Round("Segment") })
		-- (the held-back look: a faint segment after the solid part, shown while the look balance cap holds the muscle)
		local held = New("Frame", { Name = "Held", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.7, Visible = false, Parent = back }, { Theme.Round("Segment") })
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, ZIndex = 2, Parent = back }, { Theme.Round("Segment") })
		-- a small lock drawn from shapes: a round shackle (a stroked ring, its lower half behind the body) over a body
		local lock = New("Frame", { Name = "Lock", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.48, 4, 0.5, 0), Size = UDim2.fromOffset(9, 11), BackgroundTransparency = 1, Visible = false, Parent = row })
		New("Frame", { Name = "Shackle", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(6, 8), BackgroundTransparency = 1, Parent = lock },
			{ New("UICorner", { CornerRadius = UDim.new(0.5, 0) }), New("UIStroke", { Color = Colors.Text, Thickness = 1.5 }) })
		New("Frame", { Name = "Body", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(9, 6), BackgroundColor3 = Colors.Text, ZIndex = 2, Parent = lock },
			{ New("UICorner", { CornerRadius = UDim.new(0, 2) }) })
		local value = Theme.Text({ Font = "SemiBold", TextSize = "Small", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		local entryRow = { level = value, fill = fill, held = held, lock = lock, hint = nil }
		muscleRows[muscle.id] = entryRow
		-- hover (PC) or tap (phones): the card's bottom line says which partner to train
		local hit = New("TextButton", { Name = "Hit", Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 3, Parent = row })
		hit.MouseEnter:Connect(function() hintRow(group.id, muscle.id, true) end)
		hit.MouseLeave:Connect(function() hintRow(group.id, muscle.id, false) end)
		hit.Activated:Connect(function() hintRow(group.id, muscle.id, nil) end)
	end
	-- the machines that train this group (main muscle), e.g. "Squat Rack · Leg Press · Hack Squat"
	local exercises = Theme.Text({ Name = "Exercises", LayoutOrder = 20, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, ROW_HEIGHT), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	cards[group.id] = { level = level, disc = disc, grade = grade, mult = mult, needs = needs, muscles = muscleRows, exercises = exercises }
end

-- columns: as many cards across as fit (~200px each): up to 3 on big screens, 2 on phones
local function layoutGrid()
	local width = scroll.AbsoluteSize.X
	local maxColumns = Theme.IsCompact() and 2 or 3
	local columns = math.clamp(math.floor(width / 200), 1, maxColumns)
	grid.CellSize = UDim2.new(1 / columns, -Spacing.S, 0, CARD_HEIGHT)
end
scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------
local wasReady = nil
local function refreshScreen()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	local nextSpurt = data.growthSpurts + 1
	goalTitle.Text = "Growth Spurt " .. nextSpurt
	goalHeight.Text = GrowthSpurts.FormatHeight(GrowthSpurts.Get(nextSpurt).height)
	for _, group in ipairs(Muscles.Groups) do
		Theme.Tween(goalFills[group.id], { Size = UDim2.fromScale(math.clamp(progress.groups[group.id] / progress.required, 0, 1), 1) })
	end
	goalLabel.Text = string.format("%d/%d groups at their goal  ·  gains x%.2f after", progress.met, progress.total, GrowthSpurts.GetBonus(nextSpurt))
	goalLabel.Visible = not progress.ready
	spurtButton.Visible = progress.ready
	if progress.ready and wasReady == false then
		statsButton:SetDot(true) -- something new: clears when stats is opened
		Notify.Show("Growth Spurt ready! Open Stats, then Muscles.", nil, "spurtReady")
	end
	wasReady = progress.ready

	-- the six cards (about 40 tweens) only need updating while the window is open; opening it refreshes everything
	if not musclesOpen then return end

	-- the look balance cap of every muscle (what the body shows vs what was trained)
	local muscleLevels = {}
	for _, muscle in ipairs(Muscles.List) do
		local entry = data.muscles[muscle.id]
		muscleLevels[muscle.id] = entry and entry.level or 0
	end
	local _, lookInfo = LookBalance.FromLevels(muscleLevels, math.max(GrowthSpurts.GetGoal(data.growthSpurts or 0), 1))

	local levels, weakest, ties = {}, nil, 0
	for _, group in ipairs(Muscles.Groups) do
		levels[group.id] = math.floor(Muscles.GetGroupLevel(data.muscles, group.id))
		if not weakest or levels[group.id] < levels[weakest] then
			weakest, ties = group.id, 1
		elseif levels[group.id] == levels[weakest] then
			ties += 1
		end
	end
	for _, group in ipairs(Muscles.Groups) do
		local card = cards[group.id]
		local gradeId = data.genetics and data.genetics.grades and data.genetics.grades[group.id] or "B"
		Theme.SetRankTag(card.disc, gradeId)
		card.mult.Text = string.format("Genetics x%.2f", Genetics.GetMultiplier(data.genetics, group.muscles[1].id))
		-- the group's muscles added up, and its Growth Spurt goal as the same sum (no "Max": it keeps counting past it)
		local groupExp = Muscles.FormatExp(Muscles.GroupExp(data.muscles, group.id))
		card.level.Text = groupExp .. " / " .. Muscles.FormatExp(Muscles.GroupShown(group.id, progress.required))
		card.level.TextColor3 = Colors.Text
		card.needs.Visible = group.id == weakest and ties == 1
		card.exercisesText = table.concat(Machines.ExercisesFor(group.id, data.growthSpurts or 0, function(id) return Muscles.ById[id].group end), " · ")
		for _, muscle in ipairs(group.muscles) do
			local row = card.muscles[muscle.id]
			local entry = data.muscles[muscle.id]
			local rowExp = Muscles.FormatExp(Muscles.MuscleExp(entry))
			row.level.Text = rowExp
			row.level.TextColor3 = Colors.Text
			-- the bar: the muscle's progress; while the look balance cap holds it, the solid part is the share that shows and a
			-- faint segment the held-back rest
			local full = math.clamp(Muscles.ExactLevel(entry) / progress.required, 0, 1)
			local look = lookInfo[muscle.id]
			local solid = if look.capped and look.raw > 0 then full * look.shown / look.raw else full
			Theme.Tween(row.fill, { Size = UDim2.fromScale(solid, 1) })
			row.held.Visible = look.capped
			row.held.Size = UDim2.fromScale(full, 1)
			row.lock.Visible = look.capped
			row.hint = if look.capped and look.rule then "Look capped - train " .. look.rule.name .. " to unlock" else nil
		end
		showBottomLine(card)
	end
end

------------------------------------------------------------------------
-- The rest of the HUD is switched off behind the panel (and put back as it was on close)
------------------------------------------------------------------------
local HUD_GUIS = { "RightColumn", "SpurtBar", "Tutorial", "Notifications", "MachineHud", "MainHud", "MusclesButton" }
local hudBefore = {}
local function hideHud(hide)
	for _, name in ipairs(HUD_GUIS) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			if hide then
				hudBefore[name] = gui.Enabled
				gui.Enabled = false
			elseif hudBefore[name] ~= nil then
				gui.Enabled = hudBefore[name]
				hudBefore[name] = nil
			end
		end
	end
end

local function openMuscles()
	if musclesOpen or UIBus.MenuOpen then return end
	musclesOpen = true
	UIBus.PanelOpened("Muscles") -- (side panels close behind the big window)
	if musclesTile then musclesTile:SetActive(true) end
	hideHud(true)
	refreshScreen()
	screen.Enabled = true
	layoutGrid()
	scroll.CanvasPosition = Vector2.zero
	Audio.PlayUI("Whoosh")
	setBlur(true)
	Theme.Fade(windowRoot, true)
	UIBus.MusclesVisible:Fire(true)
end

local function closeMuscles()
	if not musclesOpen then return end
	musclesOpen = false
	hideHud(false)
	if musclesTile then musclesTile:SetActive(false) end
	setBlur(false)
	UIBus.MusclesVisible:Fire(false)
	local tween = Theme.Fade(windowRoot, false)
	if tween then
		tween.Completed:Connect(function()
			if not musclesOpen then screen.Enabled = false end
		end)
	else
		screen.Enabled = false
	end
end

closeButton.Activated:Connect(closeMuscles)
backdrop.Activated:Connect(closeMuscles)
UserInputService.InputBegan:Connect(function(input)
	if musclesOpen and input.KeyCode == Enum.KeyCode.Escape then closeMuscles() end
end)
spurtButton.Activated:Connect(function()
	Remotes.PlayerAction:FireServer("GrowthSpurt")
end)
UIBus.RegisterPanel("Muscles", closeMuscles)
UIBus.OpenMuscles.Event:Connect(openMuscles)
UIBus.GeneticsVisible.Event:Connect(function(visible)
	if visible and musclesOpen then closeMuscles() end
end)

------------------------------------------------------------------------
-- The Muscles tile (left menu) opens the panel; there is no floating button any more
------------------------------------------------------------------------
musclesTile = SideMenu.Add("Muscles", "Muscles", Icons.Stats, 2)
musclesTile.Activated:Connect(function()
	Audio.PlayUI("Click")
	if musclesOpen then closeMuscles() else openMuscles() end
end)
local menuDone = false

statsButton.Activated:Connect(function()
	labelsOn = not labelsOn
	statsButton:SetActive(labelsOn)
	statsButton:SetDot(false)
	Audio.PlayUI("Click")
	UIBus.StatsLabels:Fire(labelsOn)
	UIBus.StatsVisible:Fire(labelsOn) -- (the tutorial's "open Stats" step)
end)

task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	menuDone = true
	refreshScreen()
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "growthSpurts" or key == "muscles" or key == "genetics" then
		refreshScreen() -- live while the panel is open, and keeps the "ready" dot current
	end
end)

------------------------------------------------------------------------
-- Growth Spurt moment: a short line of text, a bell, a chalk burst (no pop-up window)
------------------------------------------------------------------------
local celebration = Theme.ScreenGui({ Name = "Celebration", DisplayOrder = 30, Parent = playerGui })
local function chalkBurst()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local attachment = New("Attachment", { Parent = rootPart })
	local emitter = New("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Colors.Chalk),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Rate = 0,
		Parent = attachment,
	})
	emitter:Emit(40)
	Debris:AddItem(attachment, 2)
end
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind ~= "GrowthSpurt" then return end
	if musclesOpen then closeMuscles() end
	local banner = Theme.Text({
		Text = "Growth Spurt!",
		Font = "SemiBold",
		TextSize = "Huge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, Spacing.XL),
		Size = UDim2.fromOffset(420, 56),
		Parent = celebration,
	})
	Theme.TextShadow(banner, 0.5)
	Theme.Fade(banner, true)
	Theme.Tween(banner, { Position = UDim2.fromScale(0.5, 0.3) })
	task.delay(2.2, function()
		local tween = Theme.Fade(banner, false, 0.4)
		if tween then tween.Completed:Connect(function() banner:Destroy() end) end
	end)
	Audio.Play2D("GrowthSpurt")
	chalkBurst()
	Notify.Show(string.format("You're now %s. Gains x%.2f forever!", GrowthSpurts.FormatHeight(info.height), info.bonus))
end)

