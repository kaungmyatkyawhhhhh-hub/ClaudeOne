-- StatsClient: the body map and the full stats screen.
--  * Body map (bottom left, always on): a small front + back body silhouette. Each of the 18 muscles is its own shape;
--    how bright it is shows its level toward the next Growth Spurt goal (dim = untrained, bright = strong), and a gold
--    outline means maxed. The muscles the current machine trains pulse on every rep. Under it: your level and a chunky
--    bar to the next Growth Spurt. Tapping the map (or Stats in the menu) opens the full stats screen.
--  * Full stats screen: the Growth Spurt goal (with the Growth Spurt button when ready), then the six groups, each with
--    its genetics grade disc, level and its muscles. "Needs work" marks the weakest group (no tie). Clean minimal style.
--  * The Growth Spurt moment (a line of text, a bell, a chalk burst) is played here too.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
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

local compact = Theme.IsCompact()
local SIZES = { -- the panel width and the height of each silhouette (with its "Front"/"Back" caption)
	Normal = { Width = 150, Figure = 156 },
	Compact = { Width = 100, Figure = 84 },
}
local MAP = {
	Width = SIZES.Normal.Width,
	Figure = SIZES.Normal.Figure,
	Dim = 0.82,                         -- fill transparency of an untrained muscle
	Bright = 0.05,                      -- ...of a muscle at the goal
	Body = 0.9,                         -- the faint body behind the muscles
}

------------------------------------------------------------------------
-- Menu button
------------------------------------------------------------------------
local statsButton = SideMenu.Add("Stats", "Stats", Icons.Flex, 1)

------------------------------------------------------------------------
-- Body map
------------------------------------------------------------------------
local hud = Theme.ScreenGui({ Name = "BodyMap", DisplayOrder = 4, Enabled = false, Parent = playerGui })

local mapPanel = Theme.Button("Secondary", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0, 1),
	Size = UDim2.fromOffset(MAP.Width, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = hud,
}, { Theme.Pad("S"), Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
mapPanel:FindFirstChildOfClass("UIStroke").Transparency = Theme.Alpha.Border

local figures = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, MAP.Figure), BackgroundTransparency = 1, Parent = mapPanel },
	{ Theme.List(Horizontal, "S") })

-- A silhouette is drawn on a 40 x 100 grid (x 0..40, y 0..100), mirrored left/right. Each muscle is a list of
-- rounded shapes { x, y, w, h, roundness } (one per side for paired muscles).
local function mirror(shape) return { 40 - shape[1] - shape[3], shape[2], shape[3], shape[4], shape[5] } end
local function pair(shape) return { shape, mirror(shape) } end

local BODY = { -- the faint body: head, neck, torso, arms, legs
	{ 15, 0, 10, 11, 1 }, { 18, 10, 4, 3, 0.3 }, { 10, 13, 20, 33, 0.25 },
	{ 3, 14, 7, 18, 0.5 }, { 30, 14, 7, 18, 0.5 }, { 2, 31, 6, 17, 0.5 }, { 32, 31, 6, 17, 0.5 },
	{ 11, 45, 8, 27, 0.4 }, { 21, 45, 8, 27, 0.4 }, { 12, 71, 7, 26, 0.4 }, { 21, 71, 7, 26, 0.4 },
}
local FRONT = {
	UpperChest = pair({ 11.5, 14, 8, 5, 0.4 }),
	MidChest = pair({ 11.5, 19.5, 8, 6, 0.4 }),
	FrontDelts = pair({ 7, 13.5, 5, 6, 0.6 }),
	SideDelts = pair({ 3, 14, 4, 6, 0.6 }),
	Biceps = pair({ 3.5, 20.5, 5.5, 10, 0.6 }),
	Forearms = pair({ 2.5, 32, 5, 14, 0.5 }),
	Abs = { { 16.5, 27, 7, 17, 0.25 } },
	Obliques = pair({ 11.5, 28, 4.5, 15, 0.5 }),
	Quads = pair({ 11.5, 47, 7, 22, 0.5 }),
}
local BACK = {
	Traps = { { 14, 11, 12, 7, 0.5 } },
	RearDelts = pair({ 4, 14, 6, 6, 0.6 }),
	Rhomboids = { { 15.5, 18.5, 9, 7, 0.3 } },
	Lats = pair({ 10.5, 19, 5.5, 15, 0.5 }),
	LowerBack = { { 15, 34, 10, 10, 0.3 } },
	Triceps = pair({ 3, 20.5, 6, 10, 0.6 }),
	Glutes = pair({ 11.5, 45, 8, 10, 0.6 }),
	Hamstrings = pair({ 11.5, 56, 7, 15, 0.5 }),
	Calves = pair({ 12.5, 73, 6, 16, 0.6 }),
}

local shapes = {} -- [muscleId] = { frames }
local holders = {}
local function figure(order, title, muscles)
	-- the canvas keeps the grid's 40:100 shape, so the body is never stretched
	local holder = New("Frame", { LayoutOrder = order, Size = UDim2.new(0, math.floor((MAP.Figure - 14) * 0.4), 1, 0), BackgroundTransparency = 1, Parent = figures })
	table.insert(holders, holder)
	local canvas = New("Frame", { Size = UDim2.new(1, 0, 1, -14), BackgroundTransparency = 1, Parent = holder })
	local function draw(spec, color, transparency, z)
		local frame = New("Frame", {
			Position = UDim2.fromScale(spec[1] / 40, spec[2] / 100),
			Size = UDim2.fromScale(spec[3] / 40, spec[4] / 100),
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			ZIndex = z,
			Parent = canvas,
		}, { New("UICorner", { CornerRadius = UDim.new(spec[5], 0) }) })
		return frame
	end
	for _, spec in ipairs(BODY) do draw(spec, Colors.Text, MAP.Body, 1) end
	for muscleId, list in pairs(muscles) do
		shapes[muscleId] = shapes[muscleId] or {}
		for _, spec in ipairs(list) do
			local frame = draw(spec, Colors.Text, MAP.Dim, 2)
			New("UIStroke", { Name = "Maxed", Color = Colors.Gold, Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame })
			table.insert(shapes[muscleId], frame)
		end
	end
	Theme.Text({ Text = title, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0, 14), Parent = holder })
end
figure(1, "Front", FRONT)
figure(2, "Back", BACK)

local levelRow = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = mapPanel })
local levelText = Theme.Text({ Font = "SemiBold", TextSize = "Small", Size = UDim2.fromScale(0.6, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = levelRow })
local spurtText = Theme.Text({ Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.4, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = levelRow })
local BAR_SEGMENTS = 10
local barRow = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 7), BackgroundTransparency = 1, Parent = mapPanel }, { Theme.List(Horizontal, "XS") })
local barFills = {}
for i = 1, BAR_SEGMENTS do
	local back = New("Frame", { LayoutOrder = i, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = barRow },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	barFills[i] = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
end

-- Placement: on PC bottom left, beside the menu bar. On phones the bottom left is the movement thumbstick, so the map
-- sits at the top left, under the Menu button (the menu folds into that one button there).
local UserInputService = game:GetService("UserInputService")
local function placeMap()
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	if compact then
		mapPanel.AnchorPoint = Vector2.new(0, 0)
		mapPanel.Position = UDim2.fromOffset(Spacing.M, Spacing.S + 46 + Spacing.S)
	elseif touch then
		-- tablets: the thumbstick is bottom left, so the map sits at the top, beside the menu column
		mapPanel.AnchorPoint = Vector2.new(0, 0)
		mapPanel.Position = UDim2.fromOffset(SideMenu.Right() + Spacing.M, Spacing.S)
	else
		mapPanel.AnchorPoint = Vector2.new(0, 1)
		mapPanel.Position = UDim2.new(0, SideMenu.Right() + Spacing.M, 1, -Spacing.M)
	end
end
local function applySize(isCompact)
	compact = isCompact
	local size = isCompact and SIZES.Compact or SIZES.Normal
	MAP.Width, MAP.Figure = size.Width, size.Figure
	mapPanel.Size = UDim2.fromOffset(MAP.Width, 0)
	figures.Size = UDim2.new(1, 0, 0, MAP.Figure)
	for _, holder in ipairs(holders) do holder.Size = UDim2.new(0, math.floor((MAP.Figure - 14) * 0.4), 1, 0) end
	placeMap()
end
Theme.OnCompactChanged(applySize)
SideMenu.Changed:Connect(placeMap)

------------------------------------------------------------------------
-- Full stats screen
------------------------------------------------------------------------
local screen = Theme.ScreenGui({ Name = "StatsScreen", DisplayOrder = 22, Enabled = false, Parent = playerGui }) -- under the tutorial line (23)
screen.ScreenInsets = Enum.ScreenInsets.None
local backdrop = New("TextButton", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, Parent = screen })
local sheet = Theme.Panel({
	Name = "Sheet",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.86),
	Parent = Theme.SafeArea(backdrop),
}, { Theme.Limit(Vector2.new(300, 240), Vector2.new(760, 620)), Theme.Pad("L"), Theme.List(Vertical, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

local headerRow = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = sheet })
Theme.Text({ Text = "Your muscles", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, -120, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = headerRow })
local closeButton = Theme.Button("Secondary", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(104, Theme.MinTouch), Parent = headerRow }, {
	Theme.Text({ Text = "Close", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

-- the Growth Spurt goal
local goal = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sheet },
	{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
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

-- the six groups (a grid of cards that scrolls on short screens)
local scroll = New("ScrollingFrame", {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 0),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Colors.Text,
	ScrollBarImageTransparency = 0.6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Parent = sheet,
}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
local grid = New("UIGridLayout", {
	CellPadding = UDim2.fromOffset(Spacing.M, Spacing.M),
	CellSize = UDim2.new(1 / 3, -Spacing.M, 0, 150),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = scroll,
})

local cards = {} -- [groupId] = { level, disc, grade, mult, needs, muscles = { [id] = { level, fill } } }
for index, group in ipairs(Muscles.Groups) do
	local card = New("Frame", { LayoutOrder = index, BackgroundColor3 = Colors.Panel, BackgroundTransparency = 0.7, Parent = scroll },
		{ Theme.Round("Panel"), Theme.Stroke(), Theme.Pad("S"), Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local top = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = card }, { Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left) })
	local disc = Theme.PlateDisc(Theme.Grades.B, { LayoutOrder = 1, Size = UDim2.fromOffset(24, 24) })
	disc.Parent = top
	local grade = Theme.Text({ Text = "B", Font = "SemiBold", TextSize = "Small", Size = UDim2.fromScale(1, 1), Parent = disc })
	local nameCol = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, -86, 1, 0), BackgroundTransparency = 1, Parent = top })
	Theme.Text({ Text = group.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = nameCol })
	local level = Theme.Text({ LayoutOrder = 3, Font = "Light", TextSize = "Large", Size = UDim2.new(0, 46, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = top })
	local sub = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Parent = card })
	local mult = Theme.Text({ Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = sub })
	local needs = Theme.Text({ Text = "Needs work", Font = "Regular", TextSize = "Small", TextColor3 = Colors.NeedsWork, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = sub })
	local muscleRows = {}
	for m, muscle in ipairs(group.muscles) do
		local row = New("Frame", { LayoutOrder = 2 + m, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = card })
		Theme.Text({ Text = muscle.name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(0.55, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local back = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.55, 0, 0.5, 0), Size = UDim2.new(0.3, 0, 0, 5), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = row }, { Theme.Round("Segment") })
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
		local value = Theme.Text({ Font = "SemiBold", TextSize = "Small", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.15, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		muscleRows[muscle.id] = { level = value, fill = fill }
	end
	cards[group.id] = { level = level, disc = disc, grade = grade, mult = mult, needs = needs, muscles = muscleRows }
end

-- 3 columns on wide screens, 2 on narrow ones
local function layoutGrid()
	local width = scroll.AbsoluteSize.X
	local columns = width >= 560 and 3 or 2
	grid.CellSize = UDim2.new(1 / columns, -Spacing.M, 0, 150)
end
scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------
local function averageLevel(data)
	local total = 0
	for _, group in ipairs(Muscles.Groups) do total += Muscles.GetGroupLevel(data.muscles, group.id) end
	return math.floor(total / #Muscles.Groups)
end

local function refreshMap()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local goalLevel = GrowthSpurts.GetGoal(data.growthSpurts)
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	for muscleId, frames in pairs(shapes) do
		local level = data.muscles[muscleId].level
		local share = math.clamp(level / goalLevel, 0, 1)
		local transparency = MAP.Dim + (MAP.Bright - MAP.Dim) * share
		for _, frame in ipairs(frames) do
			frame:SetAttribute("Rest", transparency)
			Theme.Tween(frame, { BackgroundTransparency = transparency }, 0.4)
			frame.Maxed.Transparency = level >= cap and 0 or 1
		end
	end
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	local fill = 0
	for _, level in pairs(progress.groups) do fill += math.min(level / progress.required, 1) end
	fill /= #Muscles.Groups
	for i, segment in ipairs(barFills) do
		Theme.Tween(segment, { Size = UDim2.fromScale(math.clamp(fill * BAR_SEGMENTS - (i - 1), 0, 1), 1) }, 0.4)
	end
	levelText.Text = "Level " .. averageLevel(data)
	spurtText.Text = progress.ready and "Ready!" or ("Spurt " .. (data.growthSpurts + 1))
	spurtText.TextColor3 = progress.ready and Colors.Text or Colors.Muted
end

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
		Notify.Show("Growth Spurt ready! Open Stats.", nil, "spurtReady")
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
-- Pulse: the muscles the current machine trains glow on every rep
------------------------------------------------------------------------
local currentMachine = nil
-- phones while lifting: only the silhouettes (the machine panel needs the room under them)
local function updateCompactTraining()
	local slim = compact and currentMachine ~= nil
	levelRow.Visible = not slim
	barRow.Visible = not slim
end
local function pulse()
	if not currentMachine then return end
	for index, entry in ipairs(currentMachine.muscles) do
		for _, frame in ipairs(shapes[entry.id] or {}) do
			local rest = frame:GetAttribute("Rest") or MAP.Dim
			frame.BackgroundTransparency = index == 1 and 0 or math.min(rest, 0.3)
			Theme.Tween(frame, { BackgroundTransparency = rest }, 0.6)
		end
	end
end
Remotes.MachineState.OnClientEvent:Connect(function(state, model)
	if state == "Enter" and typeof(model) == "Instance" then
		currentMachine = Machines.ById[model:GetAttribute("MachineId")]
	elseif state == "Exit" then
		currentMachine = nil
	end
	updateCompactTraining()
end)
Theme.OnCompactChanged(function() task.defer(updateCompactTraining) end)
Remotes.RepResult.OnClientEvent:Connect(function(result)
	if type(result) == "table" and not result.noStamina then pulse() end
end)

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local isOpen = false
local function open()
	if isOpen or UIBus.MenuOpen then return end
	isOpen = true
	statsButton:SetActive(true)
	statsButton:SetDot(false)
	refreshScreen()
	screen.Enabled = true
	layoutGrid()
	Audio.PlayUI("Whoosh")
	Theme.Fade(sheet, true)
	UIBus.StatsVisible:Fire(true)
end

local function close()
	if not isOpen then return end
	isOpen = false
	statsButton:SetActive(false)
	UIBus.StatsVisible:Fire(false)
	local tween = Theme.Fade(sheet, false)
	if tween then
		tween.Completed:Connect(function()
			if not isOpen then screen.Enabled = false end
		end)
	else
		screen.Enabled = false
	end
end

statsButton.Activated:Connect(function()
	if isOpen then close() else open() end
end)
mapPanel.Activated:Connect(function()
	Audio.PlayUI("Click")
	if isOpen then close() else open() end
end)
closeButton.Activated:Connect(close)
backdrop.Activated:Connect(close)
spurtButton.Activated:Connect(function()
	Remotes.PlayerAction:FireServer("GrowthSpurt")
end)

-- The map shows after Play, hides behind the genetics screen and while the stats screen is open
local hidden = { menu = true, genetics = false }
local function updateMap()
	hud.Enabled = not hidden.menu and not hidden.genetics
end
UIBus.GeneticsVisible.Event:Connect(function(visible)
	hidden.genetics = visible
	if visible and isOpen then close() end
	updateMap()
end)
task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	hidden.menu = false
	refreshMap()
	refreshScreen()
	updateMap()
	Theme.Fade(mapPanel, true)
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "muscles" or key == "growthSpurts" or key == "genetics" then
		refreshMap()
		refreshScreen() -- live while open (and keeps the "ready" dot current)
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
	if isOpen then close() end
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

