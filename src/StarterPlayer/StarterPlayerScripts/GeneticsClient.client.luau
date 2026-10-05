-- GeneticsClient: genetics reveal (first join) and reroll screen, in 3D.
-- The gym behind is blurred and dimmed. A real 3D barbell sits in a ViewportFrame; six bumper plates (bigger
-- diameter = better grade) slide onto the sleeve one by one and slam against each other. The overall grade is a
-- big 3D plate that drops in with a thud. Grade letters and names are crisp 2D text placed over the 3D plates;
-- the rest is plain white/gray text floating over the blur.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Genetics = require(Config.Genetics)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local UIBus = require(Shared.UI.UIBus)
local SideMenu = require(Shared.UI.SideMenu)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local REVEAL = {
	BlurIntensity = 0.75,
	SlideTime = 0.16,     -- plate slides down the sleeve (accelerating), then slams
	SlamGap = 0.15,       -- between plates
	StartX = 9,           -- plates start off the end of the sleeve
	StampPause = 0.35,
	DropTime = 0.22,
	SlideOffTime = 0.18,
	SlideOffGap = 0.05,
}
-- 3D plate sizes (studs). Better grade = bigger diameter.
local PLATE = { Thickness = 0.8, Diameter = { S = 2.4, A = 2.22, B = 2.06, C = 1.9, D = 1.75 } }
local HERO = { Thickness = 0.9, Diameter = 3 }
local BAR = { Collar = 0.15 } -- x where the sleeve starts (plates slam against the collar here)
local REACTIONS = { S = "genetic freak?!", A = "blessed!", B = "solid start", C = "grind time", D = "hard gainer... respect" }
local CLANK_PITCH = { S = 0.85, A = 0.92, B = 1, C = 1.06, D = 1.12 }
local CHROME = Color3.fromHex("D6D8DE")

------------------------------------------------------------------------
-- Text for frames/body types, generated from the config
------------------------------------------------------------------------
local function bonusText(bonus)
	local parts = {}
	if bonus.all then table.insert(parts, string.format("+%d%% all", bonus.all * 100)) end
	local named, amount = {}, nil
	for id, value in pairs(bonus.groups or {}) do table.insert(named, Muscles.GroupById[id].name) amount = value end
	for id, value in pairs(bonus.muscles or {}) do table.insert(named, Muscles.ById[id].name) amount = value end
	table.sort(named)
	if #named > 0 then
		table.insert(parts, string.format("+%d%% %s", amount * 100, table.concat(named, ", ")))
	end
	return parts
end
local function frameBonus(frame)
	return table.concat(bonusText(frame.bonus), ", ")
end
local function bodyBonus(body)
	local parts = bonusText(body.bonus)
	if body.detailLevelMult < 1 then table.insert(parts, "abs show earlier")
	elseif body.detailLevelMult > 1 then table.insert(parts, "abs show later") end
	return #parts > 0 and table.concat(parts, " · ") or "no bonus"
end
local function percent(list, entry)
	local total = 0
	for _, e in ipairs(list) do total += e.weight end
	return math.floor(entry.weight / total * 100 + 0.5)
end

------------------------------------------------------------------------
-- Screen: a full-screen dim (behind) and the content in the safe area
------------------------------------------------------------------------
local dimGui = Theme.ScreenGui({ Name = "GeneticsDim", Enabled = false, DisplayOrder = 25, Parent = playerGui })
dimGui.ScreenInsets = Enum.ScreenInsets.None
local dim = New("TextButton", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.5, Text = "", AutoButtonColor = false, Parent = dimGui })

local gui = Theme.ScreenGui({ Name = "GeneticsScreen", Enabled = false, DisplayOrder = 26, Parent = playerGui })
-- Phones (Theme.IsCompact): the content starts right of the side menu (one or two columns, measured on open) and
-- fills the height; the Frame/Body lines wrap to two rows and the buttons are narrower.
local COMPACT = Theme.IsCompact()
local root = New("Frame", {
	Name = "Root",
	-- shifted right so it clears the side menu (16px margin + 64px buttons + 16px gap)
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 48, 0.5, 0),
	Size = UDim2.new(1, -120, 0.94, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	Theme.Limit(COMPACT and Vector2.new(400, 240) or Vector2.new(520, 300), Vector2.new(940, 480)),
	Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
})

-- Header: title left, DNA tokens right
local header = New("Frame", { Name = "Header", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = root })
local titleLabel = Theme.Text({ Text = "Your genetics", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local tokensLabel = Theme.Text({ Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(220, 24), TextXAlignment = Enum.TextXAlignment.Right, Parent = header })
Theme.TextShadow(titleLabel)
Theme.TextShadow(tokensLabel)

local main = New("Frame", { Name = "Main", LayoutOrder = 2, Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, Parent = root },
	{ New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.List(Horizontal, "M", Enum.HorizontalAlignment.Left) })

-- Hero column: big 3D overall plate, "Overall", reaction line
local hero = New("Frame", { Name = "Hero", LayoutOrder = 1, Size = UDim2.fromScale(0.26, 1), BackgroundTransparency = 1, Parent = main },
	{ Theme.List(Vertical, "XS") })
local heroHolder = New("Frame", { Name = "HeroHolder", LayoutOrder = 1, Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, Parent = hero },
	{ New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
local heroViewport = New("ViewportFrame", {
	Name = "HeroViewport",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(78, 66, 56),
	LightColor = Color3.fromRGB(255, 218, 176),
	LightDirection = Vector3.new(-0.3, -1, -0.55),
	Parent = heroHolder,
}, { Theme.Aspect(1, Enum.DominantAxis.Height) })
local heroLetter = Theme.Text({ Font = "SemiBold", TextSize = "Huge", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 50), Visible = false, Parent = heroViewport.Parent })
local overallLabel = Theme.Text({ LayoutOrder = 2, Text = "Overall", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), Parent = hero })
local reaction = Theme.Text({ LayoutOrder = 3, Font = "Regular", TextSize = "Body", Size = UDim2.new(1, 0, 0, 24), TextTransparency = 1, Parent = hero })
for _, label in ipairs({ overallLabel, reaction }) do Theme.TextShadow(label) end

-- Barbell column: 3D bar (fill), plate names row, frame/body lines
local barColumn = New("Frame", { Name = "BarColumn", LayoutOrder = 2, Size = UDim2.fromScale(0, 1), BackgroundTransparency = 1, Parent = main },
	{ New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local barHolder = New("Frame", { Name = "BarHolder", LayoutOrder = 1, Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, Parent = barColumn },
	{ New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
local barViewport = New("ViewportFrame", {
	Name = "BarViewport",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(78, 66, 56),
	LightColor = Color3.fromRGB(255, 218, 176),
	LightDirection = Vector3.new(-0.3, -1, -0.55),
	Parent = barHolder,
})
local letterLayer = New("Frame", { Name = "Letters", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = barHolder })
local namesRow = New("Frame", { Name = "Names", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = barColumn })

local infoList = Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left)
infoList.Wraps = true -- narrow screens: "Body: ..." moves to a second row instead of running off the side
local infoRow = New("Frame", { Name = "Info", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = barColumn },
	{ infoList })
-- "Frame: Average" in white with its bonus in gray beside it
local function infoWithBonus(order)
	local text = Theme.Text({ LayoutOrder = order, Font = "Regular", TextSize = "Body", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), Parent = infoRow })
	local bonus = Theme.Text({
		LayoutOrder = order + 1,
		Font = "Regular",
		TextSize = "Small",
		TextColor3 = Colors.Muted,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X, -- one line, as wide as its text (a wrapped second line got clipped)
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = infoRow,
	})
	Theme.TextShadow(text)
	Theme.TextShadow(bonus)
	return text, bonus
end
local frameLabel, frameBonusLabel = infoWithBonus(1)
New("Frame", { Name = "Gap", LayoutOrder = 3, Size = UDim2.fromOffset(Spacing.XL, 24), BackgroundTransparency = 1, Parent = infoRow })
local bodyLabel, bodyBonusLabel = infoWithBonus(4)

-- Buttons row: "View odds" link (left), Reroll and Keep (right)
local buttons = New("Frame", { Name = "Buttons", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = root },
	{ Theme.List(Horizontal, "M", Enum.HorizontalAlignment.Right) })
local oddsLink = New("TextButton", {
	Name = "ViewOdds",
	LayoutOrder = 0,
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundTransparency = 1,
	RichText = true,
	Text = "<u>View odds</u>",
	FontFace = Theme.Fonts.Regular,
	TextSize = Theme.TextSize.Body,
	TextColor3 = Colors.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = buttons,
}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
Theme.TextShadow(oddsLink)
local rerollButton = Theme.Button("Secondary", { Name = "Reroll", LayoutOrder = 1, Size = UDim2.new(0, COMPACT and 170 or 210, 1, 0), Parent = buttons })
local rerollStroke = rerollButton:FindFirstChildOfClass("UIStroke")
local rerollLabel = Theme.Text({ Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), Parent = rerollButton })
local keepButton = Theme.Button("Primary", { Name = "Keep", LayoutOrder = 2, Size = UDim2.new(0, COMPACT and 110 or 150, 1, 0), Parent = buttons }, {
	Theme.Text({ Text = "Keep", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

-- Odds panel (opened by "View odds")
local oddsPanel = Theme.Panel({
	Name = "Odds",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 270),
	Visible = false,
	ZIndex = 5,
	Parent = gui,
}, { Theme.Pad("L"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local oddsHeader = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = oddsPanel })
Theme.Text({ Text = "Odds", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsHeader })
local oddsClose = Theme.Button("Secondary", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(96, Theme.MinTouch), Parent = oddsHeader }, {
	Theme.Text({ Text = "Close", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
Theme.Text({ LayoutOrder = 2, Text = "Grade (each group)", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
local gradeRow = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = oddsPanel }, { Theme.List(Horizontal, "M", Enum.HorizontalAlignment.Left) })
for index, grade in ipairs(Genetics.Grades) do
	local cell = New("Frame", { LayoutOrder = index, Size = UDim2.fromOffset(56, 52), BackgroundTransparency = 1, Parent = gradeRow }, { Theme.List(Vertical, "XS") })
	local disc = Theme.PlateDisc(Theme.Grades[grade.id], { LayoutOrder = 1, Size = UDim2.fromOffset(30, 30), Parent = cell })
	Theme.Text({ Text = grade.id, Font = "Heading", TextSize = "Small", TextColor3 = Theme.Grades[grade.id].Text, Size = UDim2.fromScale(1, 1), Parent = disc })
	Theme.Text({ LayoutOrder = 2, Text = percent(Genetics.Grades, grade) .. "%", Font = "Regular", TextSize = "Small", Size = UDim2.new(1, 0, 0, 18), Parent = cell })
end
local function oddsList(order, title, list)
	local items = {}
	for _, entry in ipairs(list) do table.insert(items, entry.name .. " " .. percent(list, entry) .. "%") end
	Theme.Text({ LayoutOrder = order, Text = title, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
	Theme.Text({ LayoutOrder = order + 1, Text = table.concat(items, "   ·   "), Font = "Regular", TextSize = "Small", Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = oddsPanel })
end
oddsList(4, "Frame", Genetics.Frames)
oddsList(6, "Body type", Genetics.BodyTypes)

-- Side menu button
local menuButton = SideMenu.Add("Genetics", "Genetics", Icons.DNA, 3)

------------------------------------------------------------------------
-- 3D: barbell, plates, hero plate
------------------------------------------------------------------------
local function part(props)
	local p = New("Part", { Anchored = true, CanCollide = false, CastShadow = false, Material = Enum.Material.SmoothPlastic })
	for key, value in pairs(props) do p[key] = value end
	return p
end
local function cylinder(name, length, diameter, color, material, parent)
	return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = parent })
end

-- Bar along X: grip shaft on the left, collar at BAR.Collar, sleeve to the right.
local barModel = New("Model", { Name = "Barbell", Parent = barViewport })
cylinder("Shaft", 8, 0.28, CHROME, Enum.Material.Metal, barModel).CFrame = CFrame.new(-4 + BAR.Collar - 0.15, 0, 0)
cylinder("Collar", 0.3, 0.8, CHROME, Enum.Material.Metal, barModel).CFrame = CFrame.new(BAR.Collar - 0.15, 0, 0)
cylinder("Sleeve", 6.5, 0.5, CHROME, Enum.Material.Metal, barModel).CFrame = CFrame.new(BAR.Collar + 3.25, 0, 0)
cylinder("EndCap", 0.08, 0.56, CHROME:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Metal, barModel).CFrame = CFrame.new(BAR.Collar + 6.54, 0, 0)

-- A bumper plate: fill-colored body, darker rim ring on each face, steel hub. Axis = X. Pivot = center.
local function makePlate(bumper, diameter, thickness, hubDiameter, parent)
	local model = New("Model", { Name = "Plate" })
	local body = cylinder("Body", thickness, diameter, bumper.Fill, nil, model)
	model.PrimaryPart = body
	for _, side in ipairs({ -1, 1 }) do
		local offset = CFrame.new(side * (thickness / 2), 0, 0)
		cylinder("Rim", 0.02, diameter * 0.985, bumper.Rim, nil, model).CFrame = offset
		cylinder("Face", 0.04, diameter * 0.82, bumper.Fill, nil, model).CFrame = offset
		cylinder("EdgeBand", 0.07, diameter + 0.02, bumper.Rim, nil, model).CFrame = CFrame.new(side * (thickness / 2 - 0.035), 0, 0)
	end
	cylinder("Hub", thickness + 0.08, hubDiameter, CHROME, Enum.Material.Metal, model)
	cylinder("Hole", thickness + 0.1, hubDiameter * 0.72, hubDiameter > 1 and bumper.Fill or Color3.fromRGB(24, 24, 26), nil, model)
	model.Parent = parent
	return model
end

-- Cameras (vertical FOV; a slight 3/4 angle so the plate faces and edges both read)
local barCamera = New("Camera", { FieldOfView = 30, Parent = barViewport })
barViewport.CurrentCamera = barCamera
local BAR_TARGET = Vector3.new(2.8, 0, 0)
local BAR_SPAN = 7.4 -- studs of bar that should always fit across (some grip, collar, all six plates, sleeve end)
local BAR_YAW, BAR_PITCH = math.rad(18), math.rad(8)
local barBaseCFrame
local function placeBarCamera()
	local size = barViewport.AbsoluteSize
	if size.Y < 1 then return end
	-- fit the biggest plate to the height and the loaded sleeve to the width, whichever needs more room
	local visibleHeight = math.max(PLATE.Diameter.S + 0.35, BAR_SPAN / (size.X / size.Y))
	local distance = visibleHeight / (2 * math.tan(math.rad(barCamera.FieldOfView) / 2))
	local offset = Vector3.new(math.sin(BAR_YAW), math.sin(BAR_PITCH), math.cos(BAR_YAW)) * distance
	barBaseCFrame = CFrame.lookAt(BAR_TARGET + offset, BAR_TARGET)
	barCamera.CFrame = barBaseCFrame
end

local heroCamera = New("Camera", { FieldOfView = 30, Parent = heroViewport })
heroViewport.CurrentCamera = heroCamera
local heroBaseCFrame = CFrame.lookAt(Vector3.new(0, 0.3, (HERO.Diameter + 0.6) / (2 * math.tan(math.rad(15)))), Vector3.new(0, 0, 0))
heroCamera.CFrame = heroBaseCFrame
local HERO_ROTATION = CFrame.Angles(0, math.rad(90 - 14), 0) -- plate axis toward the camera, turned a little

-- Projects a point in a viewport's world to pixels inside that viewport.
local function project(viewport, camera, world)
	local size = viewport.AbsoluteSize
	local p = camera.CFrame:PointToObjectSpace(world)
	local depth = math.max(-p.Z, 0.01)
	local tanHalf = math.tan(math.rad(camera.FieldOfView) / 2)
	local x = (p.X / depth) / (tanHalf * size.X / size.Y)
	local y = (p.Y / depth) / tanHalf
	return Vector2.new((x + 1) / 2 * size.X, (1 - y) / 2 * size.Y)
end

local function restX(index)
	return BAR.Collar + (PLATE.Thickness + 0.02) * (index - 0.5)
end

------------------------------------------------------------------------
-- Plate state, names, letters
------------------------------------------------------------------------
local plates = {} -- [index] = { group, grade, model, x, letter }
local heroPlate, heroY = nil, 0
local nameCells = {}
for index, group in ipairs(Muscles.Groups) do
	local cell = New("Frame", { Name = group.id, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 84, 1, 0), BackgroundTransparency = 1, Parent = namesRow },
		{ Theme.List(Vertical, nil) })
	local name = Theme.Text({ LayoutOrder = 1, Text = group.name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), Parent = cell })
	local mult = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Small", Size = UDim2.new(1, 0, 0, 18), Parent = cell })
	for _, label in ipairs({ name, mult }) do Theme.TextShadow(label) end
	nameCells[index] = { cell = cell, mult = mult }
end

local function layoutNames()
	if barViewport.AbsoluteSize.Y < 1 then return end
	placeBarCamera()
	-- under the plate edge that faces the camera (same spot as its letter)
	local points = {}
	for index in ipairs(nameCells) do
		points[index] = project(barViewport, barCamera, Vector3.new(restX(index), 0, PLATE.Diameter.B / 2)).X
	end
	-- plates close together (narrow screens): the names spread evenly across the row instead, still left to right,
	-- so they never run into each other
	local width = namesRow.AbsoluteSize.X
	local tight = false
	for index = 2, #points do
		if points[index] - points[index - 1] < 76 then tight = true end
	end
	for index, entry in ipairs(nameCells) do
		entry.cell.Position = UDim2.fromOffset(tight and width * (index - 0.5) / #nameCells or points[index], 0)
		entry.cell.Size = UDim2.new(0, tight and math.floor(width / #nameCells) or 84, 1, 0)
	end
end
barViewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutNames)

-- Letters ride on the plate edge that faces the camera (the faces are pressed against each other).
local function updateOverlay()
	for _, plate in pairs(plates) do
		if plate.model.Parent then
			local radius = PLATE.Diameter[plate.grade] / 2
			local point = project(barViewport, barCamera, Vector3.new(plate.x, -radius * 0.08, radius))
			plate.letter.Position = UDim2.fromOffset(point.X, point.Y)
		end
	end
	if heroPlate then
		local point = project(heroViewport, heroCamera, Vector3.new(0, heroY, HERO.Thickness / 2))
		heroLetter.Position = UDim2.fromOffset(heroViewport.AbsolutePosition.X - heroViewport.Parent.AbsolutePosition.X + point.X,
			heroViewport.AbsolutePosition.Y - heroViewport.Parent.AbsolutePosition.Y + point.Y)
	end
end

------------------------------------------------------------------------
-- Effects
------------------------------------------------------------------------


-- Tiny shake on the viewport cameras and the (blurred) game camera.
local shakeUntil, shakeStrength = 0, 0
local function shake(strength)
	shakeUntil, shakeStrength = os.clock() + 0.15, strength
end
local function shakeOffset(scale)
	local now = os.clock()
	if now >= shakeUntil then return CFrame.new() end
	local m = shakeStrength * scale * ((shakeUntil - now) / 0.15)
	return CFrame.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
end

-- Chalk dust puff at a point inside barHolder (S grades).
local function chalkPuff(center)
	for i = 1, 9 do
		local angle = (i / 9) * math.pi * 2 + math.random() * 0.4
		local size = math.random(8, 14)
		local puff = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Colors.Chalk,
			BackgroundTransparency = 0.2,
			ZIndex = 6,
			Parent = barHolder,
		}, { Theme.Round("Round") })
		local distance = math.random(30, 56)
		Theme.Tween(puff, {
			Position = UDim2.fromOffset(center.X + math.cos(angle) * distance, center.Y + math.sin(angle) * distance),
			Size = UDim2.fromOffset(size * 2, size * 2),
			BackgroundTransparency = 1,
		}, 0.5)
		Debris:AddItem(puff, 0.55)
	end
end

-- Moves a plate along the sleeve over `time` with an easing function; yields until done.
local function slide(plate, toX, time, ease)
	local fromX = plate.x
	local start = os.clock()
	while true do
		local t = math.clamp((os.clock() - start) / time, 0, 1)
		plate.x = fromX + (toX - fromX) * ease(t)
		plate.model:PivotTo(CFrame.new(plate.x, 0, 0))
		updateOverlay() -- letters move in the same frame as their plate (no lag)
		if t >= 1 then break end
		RunService.RenderStepped:Wait()
	end
end
local function easeIn(t) return t * t end
local function easeOut(t) return 1 - (1 - t) * (1 - t) end

------------------------------------------------------------------------
-- Reveal / slide-off
------------------------------------------------------------------------
local isOpen = false
local revealing = false
local blur = nil

local function refreshButtons()
	local data = ClientData.Get()
	local canReroll = data.freeReroll or data.dnaTokens > 0
	if canReroll then
		rerollLabel.Text = data.freeReroll and "Reroll · free" or "Reroll · 1 DNA token"
		rerollLabel.TextColor3 = Colors.Text
		rerollButton.BackgroundTransparency = Theme.Alpha.Panel
		rerollStroke.Transparency = Theme.Alpha.ButtonBorder
	else
		-- clearly disabled: faded button with a plain reason
		rerollLabel.Text = "No DNA tokens"
		rerollLabel.TextColor3 = Colors.Muted
		rerollButton.BackgroundTransparency = 0.8
		rerollStroke.Transparency = 0.92
	end
	rerollButton.Active = canReroll and not revealing
	rerollButton.AutoButtonColor = false
	tokensLabel.Text = "DNA tokens: " .. data.dnaTokens
end

local function clearBoard()
	for _, plate in pairs(plates) do
		plate.model:Destroy()
		plate.letter:Destroy()
	end
	table.clear(plates)
	if heroPlate then heroPlate:Destroy() heroPlate = nil end
	heroLetter.Visible = false
	reaction.TextTransparency = 1
	for _, entry in ipairs(nameCells) do entry.mult.Text = "" end
	frameLabel.Text, frameBonusLabel.Text = "Frame: ?", ""
	bodyLabel.Text, bodyBonusLabel.Text = "Body: ?", ""
end

local function slamAll(genetics)
	layoutNames()
	for index, group in ipairs(Muscles.Groups) do
		if not isOpen then return end
		local gradeId = genetics.grades[group.id]
		local bumper = Theme.Grades[gradeId]
		local model = makePlate(bumper, PLATE.Diameter[gradeId], PLATE.Thickness, 0.62, barViewport)
		local letter = Theme.Text({ Text = gradeId, Font = "Heading", TextSize = "Popup", TextColor3 = bumper.Text, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 34), ZIndex = 2, Parent = letterLayer })
		local plate = { group = group.id, grade = gradeId, model = model, x = REVEAL.StartX, letter = letter }
		plates[index] = plate
		model:PivotTo(CFrame.new(plate.x, 0, 0))
		task.spawn(function()
			-- accelerate down the sleeve, slam, tiny rebound
			local target = restX(index)
			slide(plate, target, REVEAL.SlideTime, easeIn)
			Audio.Play2D("GeneticsClank", { pitch = CLANK_PITCH[gradeId] })
			shake(0.08)
			nameCells[index].mult.Text = string.format("x%.2f", Genetics.GradeById[gradeId].mult)
			if gradeId == "S" then
				local radius = PLATE.Diameter.S / 2
				Audio.Play2D("ChalkPuff")
				chalkPuff(project(barViewport, barCamera, Vector3.new(plate.x, radius * 0.6, radius * 0.6)))
			end
			slide(plate, target + 0.06, 0.05, easeOut)
			slide(plate, target, 0.08, easeIn)
		end)
		task.wait(REVEAL.SlamGap)
	end
	task.wait(REVEAL.SlideTime + 0.1)
	local frame, body = Genetics.FrameById[genetics.frame], Genetics.BodyTypeById[genetics.bodyType]
	frameLabel.Text, frameBonusLabel.Text = "Frame: " .. frame.name, frameBonus(frame)
	bodyLabel.Text, bodyBonusLabel.Text = "Body: " .. body.name, bodyBonus(body)

	task.wait(REVEAL.StampPause)
	if not isOpen then return end
	-- the overall plate drops into view and lands with a deep thud
	local bumper = Theme.Grades[genetics.overall]
	heroPlate = makePlate(bumper, HERO.Diameter, HERO.Thickness, 1.35, heroViewport)
	heroLetter.Text = genetics.overall
	heroLetter.TextColor3 = bumper.Text
	heroLetter.Visible = true
	local start = os.clock()
	while true do
		local t = math.clamp((os.clock() - start) / REVEAL.DropTime, 0, 1)
		heroY = 4.5 * (1 - easeIn(t))
		heroPlate:PivotTo(CFrame.new(0, heroY, 0) * HERO_ROTATION)
		if t >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	Audio.Play2D("GeneticsThud")
	Audio.Play2D("GeneticsThudLow")
	Audio.Play2D("GeneticsClank", { pitch = 0.7, volume = 0.7 })
	shake(0.22)
	-- small settle bounce
	for _, y in ipairs({ 0.12, 0 }) do
		local from = heroY
		local t0 = os.clock()
		while os.clock() - t0 < 0.07 do
			heroY = from + (y - from) * ((os.clock() - t0) / 0.07)
			heroPlate:PivotTo(CFrame.new(0, heroY, 0) * HERO_ROTATION)
			RunService.RenderStepped:Wait()
		end
	end
	heroY = 0
	heroPlate:PivotTo(HERO_ROTATION)
	reaction.Text = REACTIONS[genetics.overall]
	Theme.Tween(reaction, { TextTransparency = 0 })
end

local function slideOff()
	Audio.Play2D("PlateSlide")
	for index = #Muscles.Groups, 1, -1 do -- outermost plate comes off first
		local plate = plates[index]
		if plate then
			task.spawn(function()
				slide(plate, REVEAL.StartX + 1, REVEAL.SlideOffTime, easeIn)
				plate.letter.Visible = false
			end)
			nameCells[index].mult.Text = ""
			task.wait(REVEAL.SlideOffGap)
		end
	end
	if heroPlate then
		local start = os.clock()
		while os.clock() - start < REVEAL.SlideOffTime do
			heroY = 4.5 * easeIn((os.clock() - start) / REVEAL.SlideOffTime)
			heroPlate:PivotTo(CFrame.new(0, heroY, 0) * HERO_ROTATION)
			RunService.RenderStepped:Wait()
		end
	end
	Theme.Tween(reaction, { TextTransparency = 1 })
	task.wait(REVEAL.SlideOffTime)
end

local function reveal()
	revealing = true
	refreshButtons()
	clearBoard()
	slamAll(ClientData.Get().genetics)
	revealing = false
	if isOpen then refreshButtons() end
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function freeze()
	return Enum.ContextActionResult.Sink
end

local function renderStep()
	local offset = shakeOffset(1)
	if barBaseCFrame then barCamera.CFrame = barBaseCFrame * offset end
	heroCamera.CFrame = heroBaseCFrame * offset
	updateOverlay()
end
local function worldShake()
	Workspace.CurrentCamera.CFrame *= shakeOffset(0.5)
end

local function open()
	if isOpen then return end
	isOpen = true
	if COMPACT then
		-- phones: the side menu steps aside while this screen is up, so the barbell gets the whole width
		SideMenu.SetHidden(true)
		local left = Spacing.L
		root.AnchorPoint = Vector2.new(0, 0.5)
		root.Position = UDim2.new(0, left, 0.5, 0)
		root.Size = UDim2.new(1, -(left + Spacing.L), 1, -Spacing.M * 2)
	end
	menuButton:SetActive(true)
	oddsPanel.Visible = false
	UIBus.GeneticsVisible:Fire(true)
	Audio.PlayUI("Whoosh")
	dimGui.Enabled, gui.Enabled = true, true
	Theme.Fade(dim, true)
	Theme.Fade(root, true)
	blur = New("DepthOfFieldEffect", { Name = "GeneticsBlur", FocusDistance = 0, InFocusRadius = 0, FarIntensity = 0, NearIntensity = 0, Parent = Lighting })
	Theme.Tween(blur, { FarIntensity = REVEAL.BlurIntensity, NearIntensity = REVEAL.BlurIntensity })
	ContextActionService:BindActionAtPriority("GeneticsFreeze", freeze, false, Enum.ContextActionPriority.High.Value + 100,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	RunService:BindToRenderStep("GeneticsViewports", Enum.RenderPriority.Last.Value, renderStep)
	RunService:BindToRenderStep("GeneticsShake", Enum.RenderPriority.Camera.Value + 2, worldShake)
	task.spawn(reveal)
end

local function close()
	if not isOpen then return end
	isOpen = false
	menuButton:SetActive(false)
	if COMPACT then SideMenu.SetHidden(false) end
	ContextActionService:UnbindAction("GeneticsFreeze")
	UIBus.GeneticsVisible:Fire(false)
	local fadingBlur = blur
	blur = nil
	if fadingBlur then
		Theme.Tween(fadingBlur, { FarIntensity = 0, NearIntensity = 0 }).Completed:Connect(function() fadingBlur:Destroy() end)
	end
	Theme.Fade(dim, false)
	local tween = Theme.Fade(root, false)
	local function finish()
		if isOpen then return end
		RunService:UnbindFromRenderStep("GeneticsViewports")
		RunService:UnbindFromRenderStep("GeneticsShake")
		dimGui.Enabled, gui.Enabled = false, false
	end
	if tween then tween.Completed:Connect(finish) else finish() end
end

local function keep()
	if revealing then return end
	if not ClientData.Get().onboarding.geneticsRevealed then
		Remotes.PlayerAction:FireServer("GeneticsSeen")
	end
	close()
end
keepButton.Activated:Connect(keep)

local pendingReroll = false
rerollButton.Activated:Connect(function()
	if revealing or not rerollButton.Active then return end
	revealing = true
	pendingReroll = true
	refreshButtons()
	Remotes.PlayerAction:FireServer("Reroll")
	task.spawn(function()
		slideOff()
		-- wait for the server's new genetics, then slam the new set on
		local deadline = os.clock() + 5
		while pendingReroll and os.clock() < deadline do task.wait() end
		if isOpen then reveal() end
	end)
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
	if tween then tween.Completed:Connect(function() oddsPanel.Visible = false end) end
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
