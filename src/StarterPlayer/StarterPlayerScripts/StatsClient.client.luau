-- StatsClient: the Stats button, the Muscles button and the "Your muscles" panel.
--  * Stats (menu button): shows / hides your stats as labels around your character in the world (StatsLabelsClient does
--    the drawing; this script fires UIBus.StatsLabels). Hidden by default. The tutorial's "open Stats" step counts it.
--  * While the labels are shown a small "Muscles" button sits at the bottom center of the screen (above the machine
--    panel while you lift). It opens the full panel.
--  * "Your muscles" panel: the Growth Spurt goal (with the Growth Spurt button when ready), then the six groups as
--    cards: grade badge, level or Max (soft gold), genetics, each muscle with a bar and its level, "Needs work" (soft
--    red) on the weakest group when there is no tie. It sits on top of everything, the rest of the HUD is switched off
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

local CARD_HEIGHT = 140 -- fits a group's name row, genetics row and up to 4 muscle rows
local ROW_HEIGHT = 16

------------------------------------------------------------------------
-- The Stats button: labels around the character, on / off
------------------------------------------------------------------------
local statsButton = SideMenu.Add("Stats", "Stats", Icons.Flex, 1)
local labelsOn = false
local musclesOpen = false

------------------------------------------------------------------------
-- The "Your muscles" panel
------------------------------------------------------------------------
local screen = Theme.ScreenGui({ Name = "MusclesScreen", DisplayOrder = 60, Enabled = false, Parent = playerGui }) -- above notifications (50)
screen.ScreenInsets = Enum.ScreenInsets.None
local backdrop = New("TextButton", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.04, Text = "", AutoButtonColor = false, Parent = screen })
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

local cards = {} -- [groupId] = { level, disc, grade, mult, needs, muscles = { [id] = { level, fill } } }
for index, group in ipairs(Muscles.Groups) do
	local frame = New("Frame", { Name = group.id, LayoutOrder = index, BackgroundColor3 = Colors.Panel, BackgroundTransparency = 0.6, Parent = scroll },
		{ Theme.Round("Panel"), Theme.Stroke(), Theme.Pad("S"), Theme.List(Vertical, "XS", Left, Top) })
	local top = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = frame }, { Theme.List(Horizontal, "S", Left) })
	local disc = Theme.PlateDisc(Theme.Grades.B, { LayoutOrder = 1, Size = UDim2.fromOffset(22, 22) })
	disc.Parent = top
	local grade = Theme.Text({ Text = "B", Font = "SemiBold", TextSize = "Small", Size = UDim2.fromScale(1, 1), Parent = disc })
	local nameCol = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, -78, 1, 0), BackgroundTransparency = 1, Parent = top })
	Theme.Text({ Text = group.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = nameCol })
	local level = Theme.Text({ LayoutOrder = 3, Font = "Light", TextSize = "Large", Size = UDim2.new(0, 46, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = top })
	local sub = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Parent = frame })
	local mult = Theme.Text({ Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = sub })
	local needs = Theme.Text({ Text = "Needs work", Font = "Regular", TextSize = "Small", TextColor3 = Colors.NeedsWork, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = sub })
	local muscleRows = {}
	for m, muscle in ipairs(group.muscles) do
		local row = New("Frame", { Name = muscle.id, LayoutOrder = 2 + m, Size = UDim2.new(1, 0, 0, ROW_HEIGHT), BackgroundTransparency = 1, Parent = frame })
		Theme.Text({ Text = muscle.name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(0.52, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local back = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.55, 0, 0.5, 0), Size = UDim2.new(0.28, 0, 0, 5), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = row }, { Theme.Round("Segment") })
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
		local value = Theme.Text({ Font = "SemiBold", TextSize = "Small", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.15, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		muscleRows[muscle.id] = { level = value, fill = fill }
	end
	cards[group.id] = { level = level, disc = disc, grade = grade, mult = mult, needs = needs, muscles = muscleRows }
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
	goalLabel.Text = string.format("%d/%d groups at level %d  ·  gains x%.2f after", progress.met, progress.total, progress.required, GrowthSpurts.GetBonus(nextSpurt))
	goalLabel.Visible = not progress.ready
	spurtButton.Visible = progress.ready
	if progress.ready and wasReady == false then
		statsButton:SetDot(true) -- something new: clears when stats is opened
		Notify.Show("Growth Spurt ready! Open Stats, then Muscles.", nil, "spurtReady")
	end
	wasReady = progress.ready

	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
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
		local bumper = Theme.Grades[gradeId] or Theme.Grades.B
		card.disc.BackgroundColor3 = bumper.Fill
		local rim = card.disc:FindFirstChildOfClass("UIStroke")
		if rim then rim.Color = bumper.Rim end
		card.grade.Text = gradeId
		card.grade.TextColor3 = bumper.Text or Colors.Text
		card.mult.Text = string.format("Genetics x%.2f", Genetics.GetMultiplier(data.genetics, group.muscles[1].id))
		local groupMaxed = GrowthSpurts.GoalLevel(data.muscles, group, trainable) >= cap
		card.level.Text = groupMaxed and "Max" or tostring(levels[group.id])
		card.level.TextColor3 = groupMaxed and Colors.Gold or Colors.Text
		card.needs.Visible = group.id == weakest and ties == 1 and not groupMaxed
		for _, muscle in ipairs(group.muscles) do
			local row = card.muscles[muscle.id]
			local level = data.muscles[muscle.id].level
			row.level.Text = level >= cap and "Max" or tostring(level)
			row.level.TextColor3 = level >= cap and Colors.Gold or Colors.Text
			Theme.Tween(row.fill, { Size = UDim2.fromScale(math.clamp(level / progress.required, 0, 1), 1) })
		end
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
	hideHud(true)
	refreshScreen()
	screen.Enabled = true
	layoutGrid()
	scroll.CanvasPosition = Vector2.zero
	Audio.PlayUI("Whoosh")
	Theme.Fade(windowRoot, true)
	UIBus.MusclesVisible:Fire(true)
end

local function closeMuscles()
	if not musclesOpen then return end
	musclesOpen = false
	hideHud(false)
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
UIBus.OpenMuscles.Event:Connect(openMuscles)
UIBus.GeneticsVisible.Event:Connect(function(visible)
	if visible and musclesOpen then closeMuscles() end
end)

------------------------------------------------------------------------
-- The Muscles button: bottom center, only while the labels are shown
------------------------------------------------------------------------
local buttonGui = Theme.ScreenGui({ Name = "MusclesButton", DisplayOrder = 6, Enabled = false, Parent = playerGui })
local musclesButton = Theme.Button("Secondary", {
	Name = "Muscles",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -Spacing.M),
	Size = UDim2.fromOffset(132, Theme.MinTouch),
	Parent = buttonGui,
}, { Theme.Text({ Text = "Muscles", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }) })
musclesButton.Activated:Connect(openMuscles)

local buttonShown = false
local function setButtonShown(on)
	if on == buttonShown then return end
	buttonShown = on
	if on then
		buttonGui.Enabled = true
		Theme.Fade(musclesButton, true, 0.2)
	else
		local tween = Theme.Fade(musclesButton, false, 0.15)
		if tween then
			tween.Completed:Connect(function()
				if not buttonShown then buttonGui.Enabled = false end
			end)
		else
			buttonGui.Enabled = false
		end
	end
end

-- keep clear of the machine panel while lifting: sit just above it
local function placeButton()
	local hud = playerGui:FindFirstChild("MachineHud")
	local stack = hud and hud:IsA("ScreenGui") and hud.Enabled and hud:FindFirstChild("Stack", true)
	if stack and stack:IsA("GuiObject") and stack.Visible and stack.AbsoluteSize.Y > 0 then
		local y = stack.AbsolutePosition.Y - buttonGui.AbsolutePosition.Y - Spacing.S
		musclesButton.Position = UDim2.new(0.5, 0, 0, math.max(y, Theme.MinTouch + Spacing.S))
	else
		musclesButton.Position = UDim2.new(0.5, 0, 1, -Spacing.M)
	end
end

local menuDone = false
local function updateButton()
	local camera = workspace.CurrentCamera
	local tight = UIBus.Training and camera ~= nil and camera.ViewportSize.Y < UIBus.ShortScreen -- (the labels step aside too)
	local show = labelsOn and menuDone and not musclesOpen and not tight and not UIBus.CoverOpen(playerGui)
	setButtonShown(show)
	if show then placeButton() end
end

statsButton.Activated:Connect(function()
	labelsOn = not labelsOn
	statsButton:SetActive(labelsOn)
	statsButton:SetDot(false)
	Audio.PlayUI("Click")
	UIBus.StatsLabels:Fire(labelsOn)
	UIBus.StatsVisible:Fire(labelsOn) -- (the tutorial's "open Stats" step)
	updateButton()
end)

task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	menuDone = true
	refreshScreen()
	while true do
		task.wait(0.2)
		updateButton()
	end
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

