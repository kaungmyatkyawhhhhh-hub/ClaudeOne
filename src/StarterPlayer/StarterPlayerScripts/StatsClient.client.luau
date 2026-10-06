-- StatsClient: the Stats menu button and the Stats window (two panels in one window).
--  * LEFT "Your muscles": the Growth Spurt goal (with the Growth Spurt button when ready), then the six groups as cards
--    with their genetics grade, level and muscle bars. "Needs work" marks the weakest group (no tie).
--  * RIGHT "Front" / "Back": a body viewer. A copy of YOUR character (own clothes, hair, accessories) stands in a
--    ViewportFrame + WorldModel, facing you, lit from the front. Labels with thin lines to dots on the muscles sit on
--    both sides (never crossing). A Front / Back toggle turns the character around; dragging turns it a little and it
--    springs back. Hover (PC) or tap a label to light up its row on the left, and the other way around.
--  * Phones and narrow screens: the two panels become two tabs ("Muscles" | "Body").
--  * The window sits on top of everything (DisplayOrder above notifications), the rest of the HUD is covered by a
--    near-opaque backdrop and the menu is hidden. Close: the X, Esc, or a tap outside the window.
--  * The Growth Spurt moment (a line of text, a bell, a chalk burst) is played here too.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
local Left, Center, Top = Enum.HorizontalAlignment.Left, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top

local NARROW_WIDTH = 720 -- screens narrower than this (or short phone screens) use the two-tab layout
local CARD_HEIGHT = 140
local ROW_HEIGHT = 16

------------------------------------------------------------------------
-- Menu button
------------------------------------------------------------------------
local statsButton = SideMenu.Add("Stats", "Stats", Icons.Flex, 1)

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local screen = Theme.ScreenGui({ Name = "StatsScreen", DisplayOrder = 60, Enabled = false, Parent = playerGui }) -- above notifications (50)
screen.ScreenInsets = Enum.ScreenInsets.None
local backdrop = New("TextButton", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.04, Text = "", AutoButtonColor = false, Parent = screen })
-- windowRoot holds the window panel and the close button (the panel has a list layout, so the button can't be inside it)
local windowRoot = New("Frame", {
	Name = "WindowRoot",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.95, 0.92),
	BackgroundTransparency = 1,
	Parent = Theme.SafeArea(backdrop),
}, { Theme.Limit(Vector2.new(300, 220), Vector2.new(1080, 720)) })
local window = Theme.Panel({
	Name = "Window",
	Size = UDim2.fromScale(1, 1),
	Active = true, -- taps inside the window never reach the backdrop (which closes it)
	Parent = windowRoot,
}, { Theme.Pad("M"), Theme.List(Vertical, "S", Left, Top) })

-- tabs (narrow screens only), kept clear of the close button on the right
local tabBar = New("Frame", { Name = "Tabs", LayoutOrder = 1, Size = UDim2.new(1, -(Theme.MinTouch + Spacing.S), 0, Theme.MinTouch), BackgroundTransparency = 1, Visible = false, Parent = window },
	{ Theme.List(Horizontal, "S", Left, Enum.VerticalAlignment.Center) })
local tabButtons = {}
for index, name in ipairs({ "Muscles", "Body" }) do
	local label = Theme.Text({ Text = name, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) })
	local button = Theme.Button("Secondary", { Name = name, LayoutOrder = index, Size = UDim2.fromScale(0, 1) }, { label, New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	button.Parent = tabBar
	tabButtons[name] = { button = button, label = label, stroke = button:FindFirstChildOfClass("UIStroke") }
end

local body = New("Frame", { Name = "Body", LayoutOrder = 2, Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, Parent = window },
	{ New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.List(Horizontal, "M", Left, Enum.VerticalAlignment.Top) })

local function innerPanel(name, order)
	return New("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.45,
		Parent = body,
	}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.Round("Panel"), Theme.Stroke(), Theme.Pad("M"), Theme.List(Vertical, "S", Left, Top) })
end
local leftPanel = innerPanel("MusclesPanel", 1)
local rightPanel = innerPanel("BodyPanel", 2)

local closeButton = Theme.Button("Secondary", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -Spacing.M, 0, Spacing.M),
	Size = UDim2.fromOffset(Theme.MinTouch, Theme.MinTouch),
	ZIndex = 20,
	Parent = windowRoot,
}, { New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ZIndex = 21 }, { Icons.Close(Colors.Text) }) })

------------------------------------------------------------------------
-- LEFT: Your muscles
------------------------------------------------------------------------
local leftHeader = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = leftPanel })
Theme.Text({ Text = "Your muscles", Font = "SemiBold", TextSize = "Large", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = leftHeader })

-- the Growth Spurt goal
local goal = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = leftPanel },
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

-- the six groups: cards that always fit their muscles (a fixed height for 4 rows), the area scrolls on short screens
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
	Parent = leftPanel,
}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
local grid = New("UIGridLayout", {
	CellPadding = UDim2.fromOffset(Spacing.S, Spacing.S),
	CellSize = UDim2.new(0.5, -Spacing.S, 0, CARD_HEIGHT),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = scroll,
})

local HIGHLIGHT_FILL = 0.86
local cards = {} -- [groupId] = { frame, stroke, level, disc, grade, mult, needs, muscles = { [id] = { row, bg, name, level, fill } } }
for index, group in ipairs(Muscles.Groups) do
	local frame = New("TextButton", { Name = group.id, LayoutOrder = index, Text = "", AutoButtonColor = false, BackgroundColor3 = Colors.Panel, BackgroundTransparency = 0.6, Parent = scroll },
		{ Theme.Round("Panel"), Theme.Pad("S"), Theme.List(Vertical, "XS", Left, Top) })
	local stroke = Theme.Stroke()
	stroke.Parent = frame
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
		local row = New("TextButton", { Name = muscle.id, LayoutOrder = 2 + m, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, ROW_HEIGHT), BackgroundColor3 = Colors.Text, BackgroundTransparency = 1, Parent = frame }, { Theme.Round("Segment") })
		local nameLabel = Theme.Text({ Text = muscle.name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(0.52, 0, 1, 0), Position = UDim2.fromOffset(4, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local back = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.55, 0, 0.5, 0), Size = UDim2.new(0.28, 0, 0, 5), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = row }, { Theme.Round("Segment") })
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
		local value = Theme.Text({ Font = "SemiBold", TextSize = "Small", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0), Size = UDim2.new(0.15, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		muscleRows[muscle.id] = { row = row, name = nameLabel, level = value, fill = fill }
	end
	cards[group.id] = { frame = frame, stroke = stroke, level = level, disc = disc, grade = grade, mult = mult, needs = needs, muscles = muscleRows }
end

-- columns: as many cards across as fit (min ~190px each)
local function layoutGrid()
	local width = scroll.AbsoluteSize.X
	local columns = math.clamp(math.floor(width / 190), 1, 3)
	grid.CellSize = UDim2.new(1 / columns, -Spacing.S, 0, CARD_HEIGHT)
end
scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)

------------------------------------------------------------------------
-- RIGHT: body viewer
------------------------------------------------------------------------
local rightHeader = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = rightPanel },
	{ New("UIPadding", { PaddingRight = UDim.new(0, 0) }) })
local rightHeaderPad = rightHeader:FindFirstChildOfClass("UIPadding")
local viewTitle = Theme.Text({ Text = "Front", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = rightHeader })
local toggle = New("Frame", { Name = "Toggle", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = rightHeader },
	{ Theme.List(Horizontal, "S", Left, Enum.VerticalAlignment.Center) })
local viewButtons = {}
for index, name in ipairs({ "Front", "Back" }) do
	local label = Theme.Text({ Text = name, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) })
	local button = Theme.Button("Secondary", { Name = name, LayoutOrder = index, Size = UDim2.fromOffset(76, 40), Parent = toggle }, { label })
	viewButtons[name] = { button = button, label = label, stroke = button:FindFirstChildOfClass("UIStroke") }
end

local viewer = New("Frame", {
	Name = "Viewer",
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = 0.35,
	ClipsDescendants = true,
	Parent = rightPanel,
}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.Round("Panel"), Theme.Stroke() })
local viewport = New("ViewportFrame", {
	Name = "Viewport",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(140, 134, 128),
	LightColor = Color3.fromRGB(255, 244, 228),
	LightDirection = Vector3.new(-0.25, -0.55, -1), -- from the camera's side, a little above
	Parent = viewer,
})
local dragArea = New("TextButton", { Name = "Drag", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 2, Parent = viewer })
local lineLayer = New("Frame", { Name = "Lines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = viewer })
local labelLayer = New("Frame", { Name = "Labels", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = viewer })
local emptyNote = Theme.Text({ Text = "Your body shows up here once you've spawned.", Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, TextWrapped = true, Size = UDim2.fromScale(0.8, 0.2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false, ZIndex = 5, Parent = viewer })

-- Where each label's dot sits: parts (both sides of a pair, or one), a position as a fraction of the part's size (x right,
-- y up, z -0.5 = front surface / +0.5 = back surface of a body facing -Z), and mirror = also try the opposite x on the
-- same part (torso muscles come in left and right halves). Level comes from `key`: a group id (group level) or a muscle id.
local ARMS_UP, ARMS_LOW = { "RightUpperArm", "LeftUpperArm" }, { "RightLowerArm", "LeftLowerArm" }
local LEGS_UP, LEGS_LOW = { "RightUpperLeg", "LeftUpperLeg" }, { "RightLowerLeg", "LeftLowerLeg" }
local VIEWS = {
	Front = { turn = 0, items = {
		{ key = "Shoulders", name = "Shoulders", parts = ARMS_UP, frac = Vector3.new(0, 0.36, -0.5) },
		{ key = "Chest", name = "Chest", parts = { "UpperTorso" }, mirror = true, frac = Vector3.new(0.22, 0.2, -0.5) },
		{ key = "Biceps", name = "Biceps", parts = ARMS_UP, frac = Vector3.new(0, -0.08, -0.5) },
		{ key = "Abs", name = "Abs", parts = { "UpperTorso" }, mirror = true, frac = Vector3.new(0.1, -0.3, -0.5) },
		{ key = "Forearms", name = "Forearms", parts = ARMS_LOW, frac = Vector3.new(0, 0, -0.5) },
		{ key = "Obliques", name = "Obliques", parts = { "LowerTorso" }, mirror = true, frac = Vector3.new(0.4, 0, -0.5) },
		{ key = "Quads", name = "Quads", parts = LEGS_UP, frac = Vector3.new(0, 0, -0.5) },
		{ key = "Calves", name = "Calves", parts = LEGS_LOW, frac = Vector3.new(0, 0, -0.5) },
	} },
	Back = { turn = math.pi, items = {
		{ key = "Traps", name = "Traps", parts = { "UpperTorso" }, frac = Vector3.new(0, 0.42, 0.5) },
		{ key = "RearDelts", name = "Rear Delts", parts = ARMS_UP, frac = Vector3.new(0, 0.36, 0.5) },
		{ key = "Rhomboids", name = "Rhomboids", parts = { "UpperTorso" }, mirror = true, frac = Vector3.new(0.1, 0.18, 0.5) },
		{ key = "Lats", name = "Lats", parts = { "UpperTorso" }, mirror = true, frac = Vector3.new(0.34, -0.05, 0.5) },
		{ key = "Triceps", name = "Triceps", parts = ARMS_UP, frac = Vector3.new(0, -0.08, 0.5) },
		{ key = "LowerBack", name = "Lower Back", parts = { "UpperTorso" }, frac = Vector3.new(0, -0.4, 0.5) },
		{ key = "Glutes", name = "Glutes", parts = { "LowerTorso" }, mirror = true, frac = Vector3.new(0.22, -0.3, 0.5) },
		{ key = "Hamstrings", name = "Hamstrings", parts = LEGS_UP, frac = Vector3.new(0, 0, 0.5) },
		{ key = "Calves", name = "Calves", parts = LEGS_LOW, frac = Vector3.new(0, 0, 0.5) },
	} },
}

local FOV = 30
local TAN_HALF = math.tan(math.rad(FOV / 2))
local view = "Front"
local rig, rigBase, camera, rigHeight = nil, nil, nil, 5
local camCFrame = CFrame.new()
local turn, turnFrom, turnTo, turnClock, turning = 0, 0, 0, 0, false
local dragYaw, dragging = 0, false
local entries = {}      -- the labels currently shown
local labelsReady = false
local hovered, selected = nil, nil

local labelSize = Vector2.new(96, 42)
local function sizeForScreen(compact)
	labelSize = compact and Vector2.new(88, 38) or Vector2.new(98, 42)
end

-- a copy of your character for the viewport: your clothes, hair and accessories, an easy standing pose, facing +Z
local JUNK = { "Skateboard", "Animate" }
local function buildRig()
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = wasArchivable
	if not copy then return nil end
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("BaseScript") or item:IsA("Sound") or item:IsA("BillboardGui") or item:IsA("ParticleEmitter") or item:IsA("Highlight")
			or item:IsA("ForceField") or item:IsA("Tool") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("PointLight") or item:IsA("SpotLight") then
			item:Destroy()
		end
	end
	for _, name in ipairs(JUNK) do
		local junk = copy:FindFirstChild(name)
		if junk then junk:Destroy() end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
		elseif item:IsA("Motor6D") or item:IsA("AnimationConstraint") then
			item.Transform = CFrame.new() -- no leftover animation pose
		end
	end
	-- arms a little away from the body so the biceps and forearms have room for their labels
	for joint, angle in pairs({ RightShoulder = 11, LeftShoulder = -11 }) do
		local motor = copy:FindFirstChild(joint, true)
		if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then motor.Transform = CFrame.Angles(0, 0, math.rad(angle)) end
	end
	copy.PrimaryPart = copy:FindFirstChild("HumanoidRootPart")
	return copy
end

local function rigPart(name)
	return rig and rig:FindFirstChild(name)
end

-- projection into the viewer's pixels (the viewport camera is known, so no engine call is needed)
local function project(world)
	local size = viewer.AbsoluteSize
	local rel = camCFrame:PointToObjectSpace(world)
	local depth = math.max(-rel.Z, 0.01)
	local aspect = size.X / math.max(size.Y, 1)
	local x = rel.X / (depth * TAN_HALF * aspect)
	local y = rel.Y / (depth * TAN_HALF)
	return Vector2.new((x + 1) / 2 * size.X, (1 - y) / 2 * size.Y)
end

-- put the rig into the viewport (feet on y = 0, on the root's vertical axis, facing +Z = toward the camera)
local function mountRig()
	viewport:ClearAllChildren()
	local world = New("WorldModel", { Parent = viewport })
	rig.Parent = world
	local boxCFrame, boxSize = rig:GetBoundingBox()
	rigHeight = boxSize.Y
	local feetOffset = rig.PrimaryPart.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	rigBase = CFrame.new(0, feetOffset, 0) * CFrame.Angles(0, math.pi, 0)
	rig:PivotTo(rigBase)
	camera = New("Camera", { FieldOfView = FOV, Parent = viewport })
	viewport.CurrentCamera = camera
end

-- frame the body: ~78% of the viewer's height (less when the viewer is narrow, so the labels keep their room)
local function fitCamera()
	if not rig or not camera then return end
	local size = viewer.AbsoluteSize
	local fraction = 0.78
	if size.X > 0 and size.Y > 0 then
		fraction = math.clamp((size.X - 2 * (labelSize.X + 18)) / (0.5 * size.Y), 0.38, 0.8)
	end
	local depth = (rigHeight / fraction) / (2 * TAN_HALF)
	camCFrame = CFrame.lookAt(Vector3.new(0, rigHeight * 0.5, depth), Vector3.new(0, rigHeight * 0.5, 0))
	camera.CFrame = camCFrame
end

-- world position(s) of an item's dot: one per candidate part/side
local function candidates(item)
	local list = {}
	for _, partName in ipairs(item.parts) do
		local part = rigPart(partName)
		if part then
			local signs = item.mirror and { -1, 1 } or { 1 }
			for _, sign in ipairs(signs) do
				local offset = Vector3.new(item.frac.X * sign, item.frac.Y, item.frac.Z) * part.Size
				table.insert(list, { world = part.CFrame * offset, part = part, offset = offset })
			end
		end
	end
	return list
end

------------------------------------------------------------------------
-- Level text
------------------------------------------------------------------------
local function levelFor(key, data)
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	local group = Muscles.GroupById[key]
	if group then
		local trainable = Machines.TrainableMuscles(data.growthSpurts)
		if GrowthSpurts.GoalLevel(data.muscles, group, trainable) >= cap then return "Max", true end
		return tostring(math.floor(Muscles.GetGroupLevel(data.muscles, key))), false
	end
	local level = data.muscles[key] and data.muscles[key].level or 0
	if level >= cap then return "Max", true end
	return tostring(level), false
end

local function refreshLabelText()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	for _, entry in ipairs(entries) do
		local text, isMax = levelFor(entry.item.key, data)
		entry.level.Text = text
		entry.level.TextColor3 = isMax and Colors.Gold or Colors.Text
	end
end

------------------------------------------------------------------------
-- Highlight links between the labels and the rows on the left
------------------------------------------------------------------------
local function groupOf(key)
	if Muscles.GroupById[key] then return key end
	local muscle = Muscles.ById[key]
	return muscle and muscle.group or nil
end

local function litKey()
	return hovered or selected
end

local function related(a, b) -- same thing, or a muscle and its group
	if not a or not b then return false end
	return a == b or (Muscles.GroupById[a] and groupOf(b) == a) or (Muscles.GroupById[b] and groupOf(a) == b)
end

local function applyHighlight()
	local lit = litKey()
	for _, entry in ipairs(entries) do
		local on = related(lit, entry.item.key)
		entry.button.BackgroundColor3 = on and Colors.Text or Colors.Panel
		entry.button.BackgroundTransparency = on and 0.82 or 0.35
		entry.stroke.Transparency = on and 0.15 or 0.6
		entry.dot.Size = UDim2.fromOffset(on and 11 or 7, on and 11 or 7)
		entry.line.BackgroundTransparency = on and 0 or 0.3
	end
	for groupId, card in pairs(cards) do
		local cardOn = lit ~= nil and groupOf(lit) == groupId
		card.stroke.Transparency = cardOn and 0.4 or Theme.Alpha.Border
		for muscleId, row in pairs(card.muscles) do
			local on = lit ~= nil and (lit == muscleId or lit == groupId)
			row.row.BackgroundTransparency = on and HIGHLIGHT_FILL or 1
			row.name.TextColor3 = on and Colors.Text or Colors.Muted
		end
	end
end

local function setHovered(key)
	hovered = key
	applyHighlight()
end
local function clearHovered(key)
	if hovered == key then
		hovered = nil
		applyHighlight()
	end
end
local function toggleSelected(key)
	selected = selected ~= key and key or nil
	applyHighlight()
end

for groupId, card in pairs(cards) do
	card.frame.MouseEnter:Connect(function()
		if not hovered or groupOf(hovered) ~= groupId then setHovered(groupId) end -- a row inside this card keeps its own highlight
	end)
	card.frame.MouseLeave:Connect(function() clearHovered(groupId) end)
	card.frame.Activated:Connect(function() toggleSelected(groupId) end)
	for muscleId, row in pairs(card.muscles) do
		row.row.MouseEnter:Connect(function() setHovered(muscleId) end)
		row.row.MouseLeave:Connect(function() clearHovered(muscleId) end)
		row.row.Activated:Connect(function() toggleSelected(muscleId) end)
	end
end

------------------------------------------------------------------------
-- Labels: placed once per view (sides alternate down the body, so lines never cross), dots follow the body
------------------------------------------------------------------------
local function clearLabels()
	for _, entry in ipairs(entries) do
		entry.button:Destroy()
		entry.dot:Destroy()
		entry.line:Destroy()
	end
	table.clear(entries)
	labelsReady = false
end

local function setLine(line, a, b)
	local delta = b - a
	line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	line.Size = UDim2.fromOffset(delta.Magnitude, 1)
	line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local function buildLabels()
	clearLabels()
	local size = viewer.AbsoluteSize
	if not rig or size.X < 50 or size.Y < 50 then return end
	local spec = VIEWS[view]
	if not spec then return end
	-- rest pose of this view (turned all the way, not dragged)
	rig:PivotTo(rigBase * CFrame.Angles(0, spec.turn, 0))
	-- order the items top to bottom, then alternate left / right
	local ordered = {}
	for _, item in ipairs(spec.items) do
		local list = candidates(item)
		if #list > 0 then
			local y = project(list[1].world).Y
			table.insert(ordered, { item = item, list = list, y = y })
		end
	end
	table.sort(ordered, function(a, b) return a.y < b.y end)
	local columns = { Left = {}, Right = {} }
	for index, info in ipairs(ordered) do
		local side = index % 2 == 1 and "Left" or "Right"
		-- the candidate on that side of the screen
		local best, bestX = nil, nil
		for _, candidate in ipairs(info.list) do
			local x = project(candidate.world).X
			if best == nil or (side == "Left" and x < bestX) or (side == "Right" and x > bestX) then best, bestX = candidate, x end
		end
		info.anchor, info.side = best, side
		info.dotY = project(best.world).Y
		table.insert(columns[side], info)
	end
	-- vertical positions per column: next to the dot, kept apart, kept on screen
	local gap = size.Y < 330 and 3 or 6
	local margin = Spacing.S
	-- label height: as tall as the room allows for the fullest column (never below 30)
	local fullest = math.max(#columns.Left, #columns.Right)
	local labelH = labelSize.Y
	if fullest > 0 then labelH = math.clamp(math.floor((size.Y - 2 * margin - (fullest - 1) * gap) / fullest), 30, labelSize.Y) end
	for _, column in pairs(columns) do
		local previousBottom = margin - gap
		for _, info in ipairs(column) do
			info.labelY = math.max(info.dotY - labelH / 2, previousBottom + gap)
			previousBottom = info.labelY + labelH
		end
		-- too low for the viewer: move up only as far as needed, from the bottom label upward
		if previousBottom > size.Y - margin then
			local limit = size.Y - margin
			for i = #column, 1, -1 do
				local info = column[i]
				info.labelY = math.min(info.labelY, limit - labelH)
				limit = info.labelY - gap
			end
		end
	end
	for _, column in pairs(columns) do
		for _, info in ipairs(column) do
			local x = info.side == "Left" and margin or (size.X - margin - labelSize.X)
			local button = New("TextButton", {
				Name = info.item.key,
				Position = UDim2.fromOffset(x, info.labelY),
				Size = UDim2.fromOffset(labelSize.X, labelH),
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Colors.Panel,
				BackgroundTransparency = 0.35,
				Parent = labelLayer,
			}, { Theme.Round("Button"), Theme.List(Vertical, nil, Center, Enum.VerticalAlignment.Center) })
			local stroke = Theme.Stroke(Colors.Border, 1, 0.6)
			stroke.Parent = button
			Theme.Text({ LayoutOrder = 1, Text = info.item.name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), Parent = button })
			local level = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 18), Parent = button })
			local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Colors.Text, Parent = lineLayer }, { Theme.Round("Round"), Theme.Stroke(Colors.Shadow, 1, 0.5) })
			local line = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = lineLayer })
			local entry = { item = info.item, part = info.anchor.part, offset = info.anchor.offset, button = button, stroke = stroke, level = level, dot = dot, line = line, side = info.side, x = x, y = info.labelY, h = labelH }
			button.MouseEnter:Connect(function() setHovered(info.item.key) end)
			button.MouseLeave:Connect(function() clearHovered(info.item.key) end)
			button.Activated:Connect(function() toggleSelected(info.item.key) end)
			table.insert(entries, entry)
		end
	end
	labelsReady = true
	refreshLabelText()
	applyHighlight()
	Theme.Fade(labelLayer, true, 0.2)
	Theme.Fade(lineLayer, true, 0.2)
end

-- every frame while the window is open: turn / drag the body, move the dots and lines
local function updateFrame(dt)
	if not rig or not rigBase then return end
	if turning then
		turnClock += dt
		local t = math.clamp(turnClock / 0.6, 0, 1)
		local eased = t * t * (3 - 2 * t)
		turn = turnFrom + (turnTo - turnFrom) * eased
		if t >= 1 then
			turning = false
			turn = turnTo
			buildLabels()
		end
	end
	if not dragging and dragYaw ~= 0 then
		dragYaw = math.abs(dragYaw) < 0.002 and 0 or dragYaw * (1 - math.min(1, dt * 8))
	end
	rig:PivotTo(rigBase * CFrame.Angles(0, turn + dragYaw, 0))
	for _, entry in ipairs(entries) do
		if entry.part then
			local dotAt = project(entry.part.CFrame * entry.offset)
			entry.dot.Position = UDim2.fromOffset(dotAt.X, dotAt.Y)
			local edge = Vector2.new(entry.side == "Left" and entry.x + labelSize.X or entry.x, entry.y + entry.h / 2)
			setLine(entry.line, dotAt, edge)
		end
	end
end

local function setView(name)
	if name == view and (labelsReady or turning) then return end
	view = name
	viewTitle.Text = name
	for key, entry in pairs(viewButtons) do
		local on = key == name
		entry.button.BackgroundColor3 = on and Colors.Text or Colors.Panel
		entry.button.BackgroundTransparency = on and Theme.Alpha.Primary or Theme.Alpha.Panel
		entry.stroke.Transparency = on and 0.5 or Theme.Alpha.ButtonBorder
	end
	selected, hovered = nil, nil
	applyHighlight()
	clearLabels()
	turnFrom, turnTo, turnClock, turning = turn, VIEWS[name].turn, 0, rig ~= nil and math.abs(VIEWS[name].turn - turn) > 0.01
	if rig and not turning then buildLabels() end
end
for name, entry in pairs(viewButtons) do
	entry.button.Activated:Connect(function() setView(name) end)
end

-- dragging turns the body a little (±40°) and it springs back. The turn follows how far the pointer has moved since the
-- press (not per-event deltas), and keeps following when the pointer leaves the viewer.
local dragStartX, dragStartYaw, dragInput = 0, 0, nil
dragArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging, dragInput = true, input
		dragStartX, dragStartYaw = input.Position.X, dragYaw
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput then
		dragYaw = math.clamp(dragStartYaw + (input.Position.X - dragStartX) * 0.012, -0.7, 0.7)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragInput then dragging, dragInput = false, nil end
end)

------------------------------------------------------------------------
-- Data (left panel)
------------------------------------------------------------------------
local wasReady = nil
local narrowMode = false -- two-tab layout: the goal sentence and the panel title give their room to the cards
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
	goalLabel.Visible = not progress.ready and not narrowMode
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
	refreshLabelText()
end

------------------------------------------------------------------------
-- Layout mode: two panels side by side, or two tabs on phones and narrow screens
------------------------------------------------------------------------
local isOpen = false
local tab = "Muscles"

local function viewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function isNarrow()
	return Theme.IsCompact() or viewportSize().X < NARROW_WIDTH
end

local function styleTabs()
	for name, entry in pairs(tabButtons) do
		local on = name == tab
		entry.button.BackgroundColor3 = on and Colors.Text or Colors.Panel
		entry.button.BackgroundTransparency = on and Theme.Alpha.Primary or Theme.Alpha.Panel
		entry.stroke.Transparency = on and 0.5 or Theme.Alpha.ButtonBorder
		entry.label.TextColor3 = on and Colors.Text or Colors.Muted
	end
end

local function refitViewer()
	if not rig or not isOpen or view == "" then return end -- (setView places the labels the first time)
	local size = viewer.AbsoluteSize
	if size.X < 50 or size.Y < 50 then return end
	sizeForScreen(Theme.IsCompact() or viewportSize().Y < 560)
	fitCamera()
	if not turning then buildLabels() end
end

local windowPad, leftPad, rightPad = window:FindFirstChildOfClass("UIPadding"), leftPanel:FindFirstChildOfClass("UIPadding"), rightPanel:FindFirstChildOfClass("UIPadding")
local function applyMode()
	local narrow = isNarrow()
	narrowMode = narrow
	leftHeader.Visible = not narrow
	windowRoot.Size = narrow and UDim2.fromScale(0.98, 0.96) or UDim2.fromScale(0.95, 0.92)
	local pad = UDim.new(0, narrow and Spacing.S or Spacing.M)
	for _, p in ipairs({ windowPad, leftPad, rightPad }) do p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = pad, pad, pad, pad end
	tabBar.Visible = narrow
	leftPanel.Visible = not narrow or tab == "Muscles"
	rightPanel.Visible = not narrow or tab == "Body"
	-- wide: the close button sits over the right panel's top corner, so the toggle keeps clear of it
	rightHeaderPad.PaddingRight = UDim.new(0, narrow and 0 or (Theme.MinTouch + Spacing.XS))
	styleTabs()
	layoutGrid()
	refreshScreen() -- (the goal sentence shows or hides with the layout)
end

for name, entry in pairs(tabButtons) do
	entry.button.Activated:Connect(function()
		tab = name
		applyMode()
		if name == "Body" then task.defer(refitViewer) end
	end)
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local frameConnection = nil

-- The rest of the HUD is switched off while the window is open (and put back as it was on close)
local HUD_GUIS = { "RightColumn", "SpurtBar", "Tutorial", "Notifications", "MachineHud", "MainHud" }
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

local function stopViewer()
	if frameConnection then
		frameConnection:Disconnect()
		frameConnection = nil
	end
	clearLabels()
	viewport:ClearAllChildren()
	if rig then rig:Destroy() end
	rig, rigBase, camera = nil, nil, nil
	hovered, selected, dragging, dragYaw = nil, nil, false, 0
end

local function startViewer()
	stopViewer()
	rig = buildRig()
	emptyNote.Visible = rig == nil
	if not rig then return end
	mountRig()
	turn, turning = 0, false
	view = ""
	frameConnection = RunService.RenderStepped:Connect(updateFrame)
	-- the window's layout settles on the next frame: size the camera and place the labels then
	task.defer(function()
		if not isOpen or not rig then return end
		RunService.RenderStepped:Wait()
		if not isOpen or not rig then return end
		sizeForScreen(Theme.IsCompact() or viewportSize().Y < 560)
		fitCamera()
		setView("Front")
	end)
end

local function open()
	if isOpen or UIBus.MenuOpen then return end
	isOpen = true
	statsButton:SetActive(true)
	statsButton:SetDot(false)
	hideHud(true) -- quest panel, goal bar, notes and the menu are switched off behind the window
	tab = "Muscles"
	refreshScreen()
	screen.Enabled = true
	applyMode()
	Audio.PlayUI("Whoosh")
	Theme.Fade(windowRoot, true)
	startViewer()
	UIBus.StatsVisible:Fire(true)
end

local function close()
	if not isOpen then return end
	isOpen = false
	statsButton:SetActive(false)
	hideHud(false)
	UIBus.StatsVisible:Fire(false)
	local tween = Theme.Fade(windowRoot, false)
	local function finish()
		if isOpen then return end
		screen.Enabled = false
		stopViewer()
	end
	if tween then tween.Completed:Connect(finish) else finish() end
end

viewer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(refitViewer)
end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if isOpen then applyMode() end
		end)
	end
end)
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if isOpen then applyMode() end
	end)
end

statsButton.Activated:Connect(function()
	if isOpen then close() else open() end
end)
closeButton.Activated:Connect(close)
UIBus.OpenStats.Event:Connect(function()
	if not isOpen then open() end
end)
-- Studio testing (e.g. screens too narrow to reach the menu button): Workspace attribute TestOpenStats true / false
if RunService:IsStudio() then
	Workspace:GetAttributeChangedSignal("TestOpenStats"):Connect(function()
		if Workspace:GetAttribute("TestOpenStats") == true then
			if not isOpen then open() end
		elseif isOpen then
			close()
		end
	end)
end
backdrop.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(input, processed)
	if isOpen and input.KeyCode == Enum.KeyCode.Escape then close() end
end)
spurtButton.Activated:Connect(function()
	Remotes.PlayerAction:FireServer("GrowthSpurt")
end)
UIBus.GeneticsVisible.Event:Connect(function(visible)
	if visible and isOpen then close() end
end)
player.CharacterAdded:Connect(function()
	if isOpen then startViewer() end
end)

task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	refreshScreen()
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "muscles" or key == "growthSpurts" or key == "genetics" then
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

