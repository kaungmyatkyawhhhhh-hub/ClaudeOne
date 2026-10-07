-- BodyMapClient: the small body-map widget that slides in while you're on a machine (and out when you leave).
--  * Front and back silhouettes made of muscle shapes. Each muscle glows by its level toward the next Growth Spurt goal
--    (dim -> bright), with a gold outline when maxed. The muscles the machine trains pulse on every rep.
--  * Under the figures: your level, the Growth Spurt (next / ready) and a small segmented bar. Tapping the widget opens
--    the "Your muscles" panel. The "-" button folds it into a small "Stats" chip (and the chip unfolds it again).
--  * It lives in the right column (under the quest panel's place, so it never sits on a phone's thumbstick at the bottom
--    left or on the jump / tap area at the bottom right).
--  * The training highlight is cleared when you leave the machine, switch machines, respawn or die.
-- Proportions (a 40 x 100 grid, head = 12.8): torso 3 heads, legs 3.5 heads, arms end at mid-thigh, shapes inside the
-- body never overlap each other.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local GrowthSpurts = require(Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local SIZES = {
	Normal = { Width = 140, Figure = 124 }, -- panel width, height of each silhouette (the caption comes under it)
	Compact = { Width = 116, Figure = 88 },
}
local MAP = {
	Dim = 0.82,      -- fill transparency of an untrained muscle
	Bright = 0.05,   -- ...of a muscle at the goal
	Body = 0.9,      -- the faint body behind the muscles
	Training = 0.45, -- trained muscles are at least this bright while you are on the machine
	SlideTime = 0.28,
}
local BAR_SEGMENTS = 10

------------------------------------------------------------------------
-- The 40 x 100 grid. Shapes are { x, y, w, h, roundness }; paired muscles are drawn mirrored left / right.
------------------------------------------------------------------------
local function mirror(shape) return { 40 - shape[1] - shape[3], shape[2], shape[3], shape[4], shape[5] } end
local function pair(shape) return { shape, mirror(shape) } end
local function both(list)
	local out = {}
	for _, shape in ipairs(list) do table.insert(out, shape); table.insert(out, mirror(shape)) end
	return out
end

local BODY = both({ -- one side of every paired piece (mirrored) + the middle pieces below
	{ 3.6, 16.5, 5.2, 23.5, 0.5 },  -- upper arm (to y 40)
	{ 3.4, 40, 4.9, 18, 0.5 },      -- forearm (to 58)
	{ 3.6, 58, 4.4, 7, 1 },         -- hand (ends at mid-thigh, y 65)
	{ 11.2, 54, 8.2, 22.6, 0.4 },   -- thigh (to 76.6)
	{ 12, 76.6, 6.6, 19.6, 0.4 },   -- shin (to 96.2)
	{ 11.6, 96.2, 7.6, 3.2, 0.5 },  -- foot
})
table.insert(BODY, { 14.6, 0, 10.8, 12.8, 1 })     -- head (1 head = 12.8)
table.insert(BODY, { 17.6, 12.2, 4.8, 3.6, 0.3 })  -- neck
table.insert(BODY, { 9.5, 15.3, 21, 38.7, 0.2 })   -- torso (3 heads)

local FRONT = {
	FrontDelts = pair({ 8.9, 16.4, 3.4, 6, 0.6 }),
	SideDelts = pair({ 3.8, 16.8, 4.8, 6, 0.6 }),
	UpperChest = pair({ 12.6, 18.4, 7, 4.6, 0.4 }),
	MidChest = pair({ 12.6, 23.4, 7, 5.2, 0.4 }),
	Biceps = pair({ 4, 23.6, 4.6, 11, 0.6 }),
	Forearms = pair({ 3.8, 40.6, 4.4, 15.4, 0.5 }),
	Abs = { { 16.8, 30, 6.4, 18.4, 0.25 } },
	Obliques = pair({ 12.4, 30.4, 3.8, 15.6, 0.5 }),
	Quads = pair({ 12, 56.2, 6.8, 18.4, 0.5 }),
}
local BACK = {
	Traps = { { 14.2, 14.6, 11.6, 6.4, 0.5 } },
	RearDelts = pair({ 3.8, 16.6, 5.2, 5.8, 0.6 }),
	Rhomboids = { { 16.2, 21.8, 7.6, 7.6, 0.3 } },
	Lats = pair({ 11.6, 22.2, 4.4, 15.8, 0.5 }),
	LowerBack = { { 15.4, 38.6, 9.2, 10.4, 0.3 } },
	Triceps = pair({ 4, 23.6, 4.6, 12, 0.6 }),
	Glutes = pair({ 12, 49.8, 7.2, 8.2, 0.6 }),
	Hamstrings = pair({ 12.2, 58.8, 6.6, 15.4, 0.5 }),
	Calves = pair({ 12.6, 78, 5.6, 14.8, 0.6 }),
}

------------------------------------------------------------------------
-- The widget
------------------------------------------------------------------------
local compact = Theme.IsCompact()
local dims = compact and SIZES.Compact or SIZES.Normal

-- holder: the slot in the column. Its children are placed by hand so the panel can slide.
local holder = New("Frame", { Name = "BodyMap", Size = UDim2.fromOffset(dims.Width, 0), BackgroundTransparency = 1, Visible = false })
holder:SetAttribute("KeepWidth", true)
RightColumn.Add(holder, 2, "bottom")

local panel = Theme.Button("Secondary", {
	Name = "Panel",
	Size = UDim2.fromOffset(dims.Width, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = holder,
}, { Theme.Pad("S"), Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
panel:FindFirstChildOfClass("UIStroke").Transparency = Theme.Alpha.Border

local chip = Theme.Button("Secondary", {
	Name = "Chip",
	Size = UDim2.fromOffset(96, Theme.MinTouch),
	Visible = false,
	Parent = holder,
}, { Theme.Pad("S"), Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
local chipIcon = New("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Parent = chip })
Icons.Flex(Colors.Text).Parent = chipIcon
Theme.Text({ LayoutOrder = 2, Text = "Stats", Font = "SemiBold", TextSize = "Body", Size = UDim2.new(0, 46, 1, 0), Parent = chip })

-- header: "Stats" + the fold button
local header = New("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = panel })
Theme.Text({ Text = "Stats", Font = "SemiBold", TextSize = "Small", Size = UDim2.fromScale(0.6, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local foldButton = New("TextButton", {
	Name = "Fold",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, Spacing.XS, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Parent = header,
})
New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 2), BackgroundColor3 = Colors.Text, Parent = foldButton }, { Theme.Round("Segment") })

local figures = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, dims.Figure + 18), BackgroundTransparency = 1, Parent = panel },
	{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })

local shapes = {}   -- [muscleId] = { frames }
local rest = {}     -- [frame] = the resting transparency (its level)
local training = {} -- [frame] = true while the machine trains it
local holders = {}
local function figure(order, title, muscles)
	-- the canvas keeps the grid's 40:100 shape, so the body is never stretched
	local column = New("Frame", { LayoutOrder = order, Size = UDim2.new(0, math.floor(dims.Figure * 0.4), 1, 0), BackgroundTransparency = 1, Parent = figures })
	table.insert(holders, column)
	local canvas = New("Frame", { Size = UDim2.new(1, 0, 1, -18), BackgroundTransparency = 1, Parent = column })
	local function draw(spec, transparency, z)
		return New("Frame", {
			Position = UDim2.fromScale(spec[1] / 40, spec[2] / 100),
			Size = UDim2.fromScale(spec[3] / 40, spec[4] / 100),
			BackgroundColor3 = Colors.Text,
			BackgroundTransparency = transparency,
			ZIndex = z,
			Parent = canvas,
		}, { New("UICorner", { CornerRadius = UDim.new(spec[5], 0) }) })
	end
	for _, spec in ipairs(BODY) do draw(spec, MAP.Body, 1) end
	for muscleId, list in pairs(muscles) do
		shapes[muscleId] = shapes[muscleId] or {}
		for _, spec in ipairs(list) do
			local frame = draw(spec, MAP.Dim, 2)
			frame.Name = muscleId
			New("UIStroke", { Name = "Maxed", Color = Colors.Gold, Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame })
			rest[frame] = MAP.Dim
			table.insert(shapes[muscleId], frame)
		end
	end
	Theme.Text({ Text = title, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0, 16), Parent = column })
end
figure(1, "Front", FRONT)
figure(2, "Back", BACK)

local levelRow = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = panel })
local levelText = Theme.Text({ Font = "SemiBold", TextSize = "Small", Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = levelRow })
local spurtText = Theme.Text({ Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = levelRow })
local barRow = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 7), BackgroundTransparency = 1, Parent = panel }, { Theme.List(Horizontal, "XS") })
local barFills = {}
for i = 1, BAR_SEGMENTS do
	local back = New("Frame", { LayoutOrder = i, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = barRow },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	barFills[i] = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
end

------------------------------------------------------------------------
-- Layout: sizes, folding, sliding
------------------------------------------------------------------------
local onMachine = false
local folded = false
local slideToken = 0

local function applySize()
	compact = Theme.IsCompact()
	dims = compact and SIZES.Compact or SIZES.Normal
	holder.Size = UDim2.fromOffset(dims.Width, holder.Size.Y.Offset)
	panel.Size = UDim2.fromOffset(dims.Width, 0)
	figures.Size = UDim2.new(1, 0, 0, dims.Figure + 18)
	for _, column in ipairs(holders) do column.Size = UDim2.new(0, math.floor(dims.Figure * 0.4), 1, 0) end
	-- phones (and very short screens): only the silhouettes while you lift, so the panel stays small beside the machine panel
	local short = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y < 400
	levelRow.Visible = not (short or compact)
	barRow.Visible = not (short or compact)
end
Theme.OnCompactChanged(function() task.defer(applySize) end)
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applySize) end

-- the holder is as tall as whatever is showing (the panel, or the chip)
local function fitHolder()
	local height = folded and chip.AbsoluteSize.Y or panel.AbsoluteSize.Y
	holder.Size = UDim2.fromOffset(dims.Width, height)
end
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHolder)

local function showFolded()
	panel.Visible = not folded
	chip.Visible = folded
	fitHolder()
end

foldButton.Activated:Connect(function()
	Audio.PlayUI("Click")
	folded = true
	showFolded()
end)
chip.Activated:Connect(function()
	Audio.PlayUI("Click")
	folded = false
	showFolded()
end)
panel.Activated:Connect(function()
	Audio.PlayUI("Click")
	UIBus.OpenMuscles:Fire()
end)

local function slide(visible)
	slideToken += 1
	local token = slideToken
	local target = folded and chip or panel
	local offScreen = dims.Width + 24
	holder.ClipsDescendants = true
	if visible then
		holder.Visible = true
		showFolded()
		target.Position = UDim2.fromOffset(offScreen, 0)
		Theme.Tween(target, { Position = UDim2.fromOffset(0, 0) }, MAP.SlideTime)
		task.delay(MAP.SlideTime + 0.05, function()
			if token == slideToken then holder.ClipsDescendants = false end
		end)
	else
		Theme.Tween(target, { Position = UDim2.fromOffset(offScreen, 0) }, MAP.SlideTime)
		task.delay(MAP.SlideTime + 0.05, function()
			if token == slideToken then
				holder.Visible = false
				holder.ClipsDescendants = false
				panel.Position, chip.Position = UDim2.new(), UDim2.new()
			end
		end)
	end
end

------------------------------------------------------------------------
-- Data: each muscle's glow by level
------------------------------------------------------------------------
local function averageLevel(data)
	local total = 0
	for _, group in ipairs(Muscles.Groups) do total += Muscles.GetGroupLevel(data.muscles, group.id) end
	return math.floor(total / #Muscles.Groups)
end

local function restFor(frame)
	return rest[frame] or MAP.Dim
end
local function shownTransparency(frame)
	return training[frame] and math.min(restFor(frame), MAP.Training) or restFor(frame)
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
			rest[frame] = transparency
			Theme.Tween(frame, { BackgroundTransparency = shownTransparency(frame) }, 0.4)
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
	levelText.Text = Muscles.FormatExp(Muscles.TotalExp(data.muscles) / #Muscles.List) .. " exp"
	spurtText.Text = progress.ready and "Ready!" or ("Spurt " .. (data.growthSpurts + 1))
	spurtText.TextColor3 = progress.ready and Colors.Text or Colors.Muted
end

------------------------------------------------------------------------
-- Training: the muscles the machine trains glow and pulse on every rep. Cleared on every way out of the machine.
------------------------------------------------------------------------
local currentMachine = nil

local function clearTraining()
	currentMachine = nil
	for _, frames in pairs(shapes) do
		for _, frame in ipairs(frames) do
			if training[frame] then
				training[frame] = nil
				Theme.Tween(frame, { BackgroundTransparency = restFor(frame) }, 0.2)
			end
		end
	end
end

local function startTraining(machine)
	clearTraining() -- (switching machines: the old highlight goes first)
	currentMachine = machine
	for _, entry in ipairs(machine.muscles) do
		for _, frame in ipairs(shapes[entry.id] or {}) do
			training[frame] = true
			Theme.Tween(frame, { BackgroundTransparency = shownTransparency(frame) }, 0.2)
		end
	end
end

local function pulse()
	if not currentMachine then return end
	for index, entry in ipairs(currentMachine.muscles) do
		for _, frame in ipairs(shapes[entry.id] or {}) do
			-- the main muscle flashes fully, the helpers a little
			frame.BackgroundTransparency = index == 1 and 0 or math.min(restFor(frame), 0.3)
			Theme.Tween(frame, { BackgroundTransparency = shownTransparency(frame) }, 0.6)
		end
	end
end

local function leaveMachine()
	clearTraining()
	UIBus.Training = false
	if onMachine then
		onMachine = false
		slide(false)
	end
end

Remotes.MachineState.OnClientEvent:Connect(function(state, model)
	if state == "Enter" and typeof(model) == "Instance" then
		local machine = Machines.ById[model:GetAttribute("MachineId")]
		if not machine then
			leaveMachine()
			return
		end
		startTraining(machine)
		UIBus.Training = true
		if not onMachine then
			onMachine = true
			slide(true)
		end
	elseif state == "Exit" then
		leaveMachine()
	end
end)

Remotes.RepResult.OnClientEvent:Connect(function(result)
	if type(result) == "table" and not result.noStamina then pulse() end
end)

local function watchCharacter(character)
	leaveMachine() -- respawned: whatever was training is over
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then humanoid.Died:Connect(leaveMachine) end
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then task.spawn(watchCharacter, player.Character) end

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "muscles" or key == "growthSpurts" or key == "genetics" then refreshMap() end
end)
task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	applySize()
	refreshMap()
end)
