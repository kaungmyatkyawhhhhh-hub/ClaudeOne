-- GeneticsClient: the genetics reveal (first join) and reroll screen.
-- A small dark 3D stage of its own, far above the town (this client only), seen by the real camera (Scriptable, restored
-- on close), so the plates are truly 3D and cast real shadows: a warm key light from the top left (Shadows on; the bar,
-- plates, collar and overall plate cast shadows), a soft fill from the right, a cool rim from behind on the plate edges.
-- The bar lies low over a dark matte floor (the biggest plates almost touch it). ONE shadow source: the key light's real
-- shadows, or (low graphics, where real shadows don't render) soft contact shadows under the plates instead. No stands.
-- The camera looks at the bar about 28 degrees from straight-on, slightly above, and drifts a little; the plates sit a
-- little apart on the sleeve so every flat face shows, spread left to right, and each label sits right under its plate.
--  * The bar carries a DNA helix: two thin strands of light (opposite phase) with short rungs every ~0.3 studs,
--    alternating soft blue / white, slowly turning. The background is plain dark.
--  * Plates are rubber bumper plates (stepped bevel edge, raised rim, inset ring, chrome hub, the grade letter printed on
--    the face). They slide onto the sleeve about 0.2s apart, best grade first (so it ends up innermost), each with a
--    clank; S plates get a quick shine sweep. A collar closes the sleeve and the overall grade drops in as a bigger
--    matching plate standing on the floor next to the bar. The whole reveal is under 3s; a tap (or Space) skips.
--  * Under each plate its label: group name (gray, 18px), grade letter in a 32px circle (the only color) and multiplier
--    ("x1.50", 22px white); two staggered rows when they'd touch. Tap / hover one for what it means. Frame (with a small
--    silhouette of the shoulder width) and body type are two cards. Reroll (shows its cost)
--    replays the reveal: plates that got better show a green arrow, worse ones a gray one; a good roll asks first.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
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

------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------
local STAGE_CF = CFrame.new(0, 1600, 0) -- far above the town, inside its own dark room
-- Plates: wide and thin (diameter about 3x thickness), all the same thickness; better grade = a little wider.
local PLATE = { Thickness = 0.62, Diameter = { S = 2.3, A = 2.15, B = 2.0, C = 1.85, D = 1.7 }, Hub = 0.62 }
local HERO = { Thickness = 0.9, Diameter = 3.2, Hub = 0.9 }
-- Along the bar's own X axis: grip on the left, the inner collar at 0, plates from SlotStart outward, sleeve end.
-- the plates sit Gap apart on the sleeve, so every face shows (the sleeve is long enough for six plates and the collar)
local BAR = { GripStart = -3.8, SlotStart = 0.15, Gap = 0.55, SleeveEnd = 7.3, Yaw = math.rad(-28) }
local BAR_CF = STAGE_CF * CFrame.new(-0.4, 0, 0) * CFrame.Angles(0, BAR.Yaw, 0) -- ~28 degrees from straight-on, the sleeve end toward the camera
-- where plate `slot` (1 = innermost) sits along the bar
local function slotX(slot)
	return BAR.SlotStart + PLATE.Thickness / 2 + (slot - 1) * (PLATE.Thickness + BAR.Gap)
end
local function slotCF(slot)
	return BAR_CF * CFrame.new(slotX(slot), 0, 0)
end
local FLOOR_Y = -PLATE.Diameter.S / 2 - 0.04 -- the floor's top: an S plate (the biggest) almost touches it
local HERO_CF = STAGE_CF * CFrame.new(-6.6, FLOOR_Y + HERO.Diameter / 2, 0.8) * CFrame.Angles(0, math.rad(-70), 0) -- on its rim on the floor, facing the camera
-- a 3/4 view: about 35 degrees off the bar's side (BAR.Yaw), slightly from above, drifting a little so the light moves
local CAMERA = { Fov = 30, Pitch = math.rad(16), Drift = math.rad(2.5), DriftSpeed = 0.35 }
local HELIX = {
	Color = Color3.fromHex("#BFE3FF"), Radius = 0.3, Turns = 5, Points = 110, Speed = 0.45, Width = 0.04, Transparency = 0.3,
	RungStep = 0.3, RungWidth = 0.022, RungTransparency = 0.4,
	RungColors = { Color3.fromHex("#8CC4FF"), Color3.fromHex("#F2F6FF") }, -- alternating soft blue / white
}
local CHROME = Color3.fromHex("#D6D8DE")
local KEY_LIGHT = { Brightness = 3.4, Range = 32, Angle = 55, Color = Color3.fromHex("#FFE2C2") }
local ROOM = Color3.fromHex("#050507")
local WORDS = { S = "Genetic Freak", A = "Blessed", B = "Gifted", C = "Average", D = "Hardgainer" }
local FLIP_PITCH = { S = 0.85, A = 0.92, B = 1, C = 1.06, D = 1.12 }
local PLURAL = { Shoulders = true, Arms = true, Legs = true }
local TIME = { Slide = 0.22, Gap = 0.2, Collar = 0.15, Drop = 0.28 } -- (the whole reveal stays under 3 seconds)

local camera = Workspace.CurrentCamera

------------------------------------------------------------------------
-- Text for frames / body types and the plate cards
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
local function frameLine(frame)
	local bonus = bonusText(frame.bonus)
	return "Frame: " .. frame.name, bonus ~= "" and bonus or "no bonus"
end
local function bodyLine(body)
	local bonus = bonusText(body.bonus)
	if bonus == "" then
		bonus = if body.detailLevelMult < 1 then "abs show earlier" elseif body.detailLevelMult > 1 then "abs show later" else "no bonus"
	end
	return "Body: " .. body.name, bonus
end
-- What one plate means: "Chest genetics A", "Your chest grows 20% faster", plus any frame / body bonus on that group.
local function plateMeaning(genetics, groupId)
	local grade = genetics.grades[groupId]
	local mult = Genetics.GradeById[grade].mult
	local name = Muscles.GroupById[groupId].name
	local pct = math.floor(math.abs(mult - 1) * 100 + 0.5)
	local speed = if mult > 1 then pct .. "% faster" elseif mult < 1 then pct .. "% slower" else "at normal speed"
	local lines = { "Your " .. string.lower(name) .. (PLURAL[name] and " grow " or " grows ") .. speed }
	local function extra(label, bonus)
		local amount = bonus.all or (bonus.groups and bonus.groups[groupId])
		if amount then
			table.insert(lines, label .. ": " .. percentText(amount) .. (bonus.all and " all muscles" or " " .. name))
		end
		for id, value in pairs(bonus.muscles or {}) do
			if Muscles.ById[id].group == groupId then table.insert(lines, label .. ": " .. percentText(value) .. " " .. Muscles.ById[id].name) end
		end
	end
	local frame, body = Genetics.FrameById[genetics.frame], Genetics.BodyTypeById[genetics.bodyType]
	extra(frame.name .. " frame", frame.bonus)
	extra(body.name .. " body", body.bonus)
	return name .. " genetics " .. grade, lines
end
local function percent(list, entry)
	local total = 0
	for _, e in ipairs(list) do total += e.weight end
	return math.floor(entry.weight / total * 100 + 0.5)
end
local function multOf(grade)
	return Genetics.GradeById[grade].mult
end

------------------------------------------------------------------------
-- Screen (2D): labels over the 3D stage, the header, the cards and buttons
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "GeneticsScreen", Enabled = false, DisplayOrder = 26, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None -- full screen: the projected labels use the camera's viewport pixels
local COMPACT = Theme.IsCompact() -- re-measured each time the screen opens

-- taps anywhere skip the reveal (everything tappable sits above this)
local skipCatcher = New("TextButton", { Name = "Skip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 1, Parent = gui })
local labelLayer = New("Frame", { Name = "Labels", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
local safe = Theme.SafeArea(gui)
safe.ZIndex = 3
-- a black cover for the cut into the stage and back
local fader = New("Frame", { Name = "Fader", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Shadow, BackgroundTransparency = 1, ZIndex = 10, Parent = gui })

-- Header: title left, DNA tokens right
local header = New("Frame", { Name = "Header", Position = UDim2.fromOffset(0, Spacing.M), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = safe },
	{ New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.XL), PaddingRight = UDim.new(0, Spacing.XL) }) })
local titleLabel = Theme.Text({ Text = "YOUR GENETICS", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
local tokensLabel = Theme.Text({ Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(220, 24), TextXAlignment = Enum.TextXAlignment.Right, Parent = header })
Theme.TextShadow(titleLabel)
Theme.TextShadow(tokensLabel)

-- Bottom: frame / body cards, then the buttons (or the reroll confirm)
local bottom = New("Frame", { Name = "Bottom", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -Spacing.M), Size = UDim2.new(1, -Spacing.XL * 2, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = safe },
	{ Theme.List(Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) })
local cardsList = Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center)
cardsList.Wraps = true -- phones: the body card goes under the frame card instead of off the side
local cardsRow = New("Frame", { Name = "Cards", LayoutOrder = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = bottom }, { cardsList })
local function infoCard(order)
	local card = Theme.Panel({ LayoutOrder = order, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = cardsRow },
		{ New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.M), PaddingRight = UDim.new(0, Spacing.M), PaddingTop = UDim.new(0, Spacing.S), PaddingBottom = UDim.new(0, Spacing.S) }),
			Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	-- one line, as wide as its text (white name, gray bonus): never clipped
	local label = Theme.Text({ LayoutOrder = 2, Font = "Regular", TextSize = "Body", RichText = true, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = card })
	return label, card
end
local frameCard, frameCardPanel = infoCard(1)
local bodyCard = infoCard(2)

-- A tiny silhouette beside "Frame: ...": head, shoulders as wide as the frame, a torso narrowing to the waist, arms.
local SILHOUETTE = { Width = 30, Height = 34, Shoulders = 16, Waist = 9 }
local silhouette = New("Frame", { Name = "FrameSilhouette", LayoutOrder = 1, Size = UDim2.fromOffset(SILHOUETTE.Width, SILHOUETTE.Height), BackgroundTransparency = 1, Parent = frameCardPanel })
local function drawSilhouette(f: number)
	silhouette:ClearAllChildren()
	local function piece(cx, y, w, h, round)
		New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.15, Parent = silhouette },
			{ New("UICorner", { CornerRadius = UDim.new(round, 0) }) })
	end
	local cx = SILHOUETTE.Width / 2
	local shoulders = math.floor(SILHOUETTE.Shoulders * f + 0.5)
	piece(cx, 0, 7, 7, 0.5) -- head
	-- the torso: rows from the shoulder width down to the waist (a V for wide frames)
	local rows = 6
	for r = 0, rows - 1 do
		local t = r / (rows - 1)
		piece(cx, 8 + r * 2.5, math.floor(shoulders + (SILHOUETTE.Waist - shoulders) * t + 0.5), 3, 0.3)
	end
	-- arms hang from the shoulder ends, hips and legs under the waist
	for _, side in ipairs({ -1, 1 }) do
		piece(cx + side * (shoulders / 2 + 2), 8, 3, 12, 0.5)
		piece(cx + side * 2.5, 24, 3.5, 10, 0.4)
	end
end
local function setCard(label, name, bonus)
	local gray = string.format("#%02X%02X%02X", Colors.Muted.R * 255, Colors.Muted.G * 255, Colors.Muted.B * 255)
	label.Text = string.format('<font weight="semibold">%s</font>  <font color="%s">·  %s</font>', name, gray, bonus)
end

local buttons = New("Frame", { Name = "Buttons", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = bottom },
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
local rerollButton = Theme.Button("Secondary", { Name = "Reroll", LayoutOrder = 1, Size = UDim2.new(0, 220, 1, 0), Parent = buttons })
local rerollStroke = rerollButton:FindFirstChildOfClass("UIStroke")
local rerollLabel = Theme.Text({ Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1), Parent = rerollButton })
local keepButton = Theme.Button("Primary", { Name = "Keep", LayoutOrder = 2, Size = UDim2.new(0, 150, 1, 0), Parent = buttons }, {
	Theme.Text({ Text = "Keep", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

-- Reroll confirm (a good roll is about to be replaced): replaces the buttons row
local confirm = New("Frame", { Name = "Confirm", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Visible = false, Parent = bottom },
	{ Theme.List(Horizontal, "M", Enum.HorizontalAlignment.Right) })
local confirmText = Theme.Text({ LayoutOrder = 0, Font = "Regular", TextSize = "Body", Size = UDim2.new(0, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = true, Parent = confirm })
New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = confirmText })
Theme.TextShadow(confirmText)
local confirmCancel = Theme.Button("Secondary", { Name = "Cancel", LayoutOrder = 1, Size = UDim2.new(0, 120, 1, 0), Parent = confirm }, {
	Theme.Text({ Text = "Cancel", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
local confirmYes = Theme.Button("Primary", { Name = "Yes", LayoutOrder = 2, Size = UDim2.new(0, 150, 1, 0), Parent = confirm }, {
	Theme.Text({ Text = "Reroll", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

local skipHint = Theme.Text({ Name = "SkipHint", Text = "Tap to skip", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -Spacing.L), Size = UDim2.fromOffset(200, 18), Visible = false, Parent = safe })
Theme.TextShadow(skipHint)

-- Odds panel (opened by "View odds")
local oddsPanel = Theme.Panel({
	Name = "Odds",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 270),
	Visible = false,
	ZIndex = 5,
	Parent = safe,
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
	Theme.RankTag(grade.id, { LayoutOrder = 1, Size = UDim2.fromOffset(26, 22), Parent = cell })
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

-- Under the overall plate: "Overall" and its word
local heroLabels = New("Frame", { Name = "Overall", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(260, 60), BackgroundTransparency = 1, Visible = false, Parent = labelLayer },
	{ Theme.List(Vertical, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
local overallLabel = Theme.Text({ LayoutOrder = 1, Text = "Overall", Font = "Regular", TextSize = "Medium", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 22), Parent = heroLabels })
local wordLabel = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Title", Upper = false, Size = UDim2.new(1, 0, 0, 36), Parent = heroLabels })
Theme.TextShadow(overallLabel)
Theme.TextShadow(wordLabel)

-- The small card when a plate is hovered / tapped
local card = Theme.Panel({ Name = "PlateCard", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, Visible = false, ZIndex = 7, Parent = labelLayer },
	{ Theme.Pad("M"), Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local cardTitle = Theme.Text({ LayoutOrder = 1, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 7, Parent = card })
local cardLines = {}
for i = 1, 4 do
	cardLines[i] = Theme.Text({ LayoutOrder = 1 + i, Font = "Regular", TextSize = "Small", TextColor3 = i == 1 and Colors.Text or Colors.Muted, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 7, Parent = card })
end

-- Side menu button
local menuButton = SideMenu.Add("Genetics", "Genetics", Icons.DNA, 3)

------------------------------------------------------------------------
-- The 3D stage
------------------------------------------------------------------------
local stage = nil   -- Model (client only) while the screen is open
local lights = {}   -- { light, base brightness }
local helix = nil   -- { strands = { { attachments, beams } }, phase, pulse }
local dof = nil

local function part(props)
	local p = New("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth })
	for key, value in pairs(props) do p[key] = value end
	return p
end
local function cylinder(name, length, diameter, color, material, cf, parent)
	return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), Color = color, Material = material or Enum.Material.SmoothPlastic, CFrame = cf or CFrame.new(), Parent = parent })
end

local function castShadows(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.Transparency < 1 then item.CastShadow = true end
	end
end

-- A circle drawn on a SurfaceGui (rings on the plate faces)
local function ring(parent, scale, color, thickness, transparency)
	return New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale), BackgroundTransparency = 1, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		New("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0 }),
	})
end

-- One plate (axis = X, front face = +X), built like a real rubber bumper plate: a slightly smaller core over a wider,
-- thinner edge band (a stepped bevel all round), a raised rim on the front face (a ring of short segments), a chrome
-- hub with a flange, and the grade letter printed on the face (embossed: a dark shadow under it, a light edge over it)
-- with the group name under the hub, plus an inset ring. Rubber finish, no glow. S plates get a shine layer that can
-- sweep across the face once.
local PPS = 100 -- SurfaceGui pixels per stud on the faces
local RIM_SEGMENTS = 36
local function makePlate(grade, diameter, thickness, hub, groupName, parent)
	local style = Theme.GradePlates[grade]
	local fill = style.Fill:Lerp(Color3.new(0, 0, 0), 0.08) -- (a touch deeper than the label colors)
	local model = New("Model", { Name = "Plate" })
	local body = cylinder("Body", thickness, diameter - 0.08, fill, nil, nil, model)
	model.PrimaryPart = body
	cylinder("Edge", thickness - 0.1, diameter, fill:Lerp(Color3.new(0, 0, 0), 0.12), nil, nil, model) -- the bevel step
	-- the raised rim on the front face
	local rimRadius = diameter / 2 - 0.13
	local chord = 2 * math.pi * rimRadius / RIM_SEGMENTS * 1.08
	for i = 1, RIM_SEGMENTS do
		local angle = (i / RIM_SEGMENTS) * math.pi * 2
		part({
			Name = "Rim",
			Size = Vector3.new(0.035, 0.09, chord),
			CFrame = CFrame.new(thickness / 2 + 0.0175, math.cos(angle) * rimRadius, math.sin(angle) * rimRadius) * CFrame.Angles(angle, 0, 0),
			Color = fill:Lerp(Color3.new(1, 1, 1), 0.06),
			Parent = model,
		})
	end
	-- the metal hub: flange + sleeve tube + the hole
	cylinder("Flange", thickness + 0.03, hub * 1.45, CHROME:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Metal, nil, model)
	cylinder("Hub", thickness + 0.08, hub, CHROME, Enum.Material.Metal, nil, model)
	cylinder("Hole", thickness + 0.1, hub * 0.6, Color3.fromRGB(20, 20, 24), nil, nil, model)
	local px = (diameter - 0.08) * PPS
	local surface = New("SurfaceGui", { Name = "Face", Face = Enum.NormalId.Right, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = PPS, LightInfluence = 1, Parent = body })
	local canvas = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = surface })
	ring(canvas, 0.72, style.Rim, math.max(px * 0.016, 3), 0.1)                              -- inset ring (dark groove)
	ring(canvas, 0.74, fill:Lerp(Color3.new(1, 1, 1), 0.25), math.max(px * 0.006, 1), 0.4) -- its lit edge
	local function letterLabel(name, offset, color, transparency, z)
		return New("TextLabel", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, offset, 0.22, offset),
			Size = UDim2.fromScale(0.5, 0.26),
			BackgroundTransparency = 1,
			Text = grade,
			FontFace = Theme.Fonts.Bold,
			TextSize = math.floor(px * 0.24),
			TextColor3 = color,
			TextTransparency = transparency,
			ZIndex = z,
			Parent = canvas,
		})
	end
	letterLabel("LetterShadow", math.max(px * 0.008, 2), Color3.new(0, 0, 0), 0.45, 1)
	letterLabel("LetterLight", -math.max(px * 0.004, 1), Color3.new(1, 1, 1), 0.55, 2)
	letterLabel("Letter", 0, style.Text, 0.04, 3)
	if groupName then
		New("TextLabel", {
			Name = "Group",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.79),
			Size = UDim2.fromScale(0.6, 0.1),
			BackgroundTransparency = 1,
			Text = string.upper(groupName),
			FontFace = Theme.Fonts.SemiBold,
			TextSize = math.floor(px * 0.075),
			TextColor3 = style.Text,
			TextTransparency = 0.3,
			Parent = canvas,
		})
	end
	-- S: a shine band that can sweep across the face once (clipped to the round face by a CanvasGroup)
	local shine = nil
	if grade == "S" then
		local clip = New("CanvasGroup", { Name = "ShineClip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = canvas },
			{ New("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		shine = New("Frame", {
			Name = "Shine",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-0.4, 0.5),
			Size = UDim2.fromScale(0.18, 1.6),
			Rotation = 22,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.35,
			Parent = clip,
		}, { New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })
	end
	castShadows(model)
	model.Parent = parent
	return { model = model, body = body, shine = shine, diameter = diameter }
end
local function addLight(class, cf, props, parent)
	local holder = part({ Name = class .. "Holder", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = cf, Parent = parent })
	local light = New(class, props)
	light.Parent = holder
	table.insert(lights, { light = light, base = light.Brightness })
	return light
end

-- the points of one helix strand along the bar (bar-local positions)
local function helixPoint(index, count, phase, radius, startX, endX, turns)
	local alpha = (index - 1) / (count - 1)
	local x = startX + (endX - startX) * alpha
	local theta = phase + alpha * turns * math.pi * 2
	return x, Vector3.new(x, math.cos(theta) * radius, math.sin(theta) * radius)
end

-- A helix of two strands of light (Beams between Attachments on an invisible part at `cf`).
local function makeHelix(cf, count, radius, startX, endX, turns, width, color, transparency, parent)
	local root = part({ Name = "Helix", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, CFrame = cf, Parent = parent })
	local h = { root = root, strands = {}, count = count, radius = radius, startX = startX, endX = endX, turns = turns, phase = 0, width = width, transparency = transparency }
	for s = 1, 2 do
		local strand = { attachments = {}, beams = {}, xs = {} }
		for i = 1, count do
			local x, position = helixPoint(i, count, (s - 1) * math.pi, radius, startX, endX, turns)
			strand.xs[i] = x
			strand.attachments[i] = New("Attachment", { Position = position, Parent = root })
			if i > 1 then
				strand.beams[i - 1] = New("Beam", {
					Attachment0 = strand.attachments[i - 1],
					Attachment1 = strand.attachments[i],
					Color = ColorSequence.new(color),
					Transparency = NumberSequence.new(transparency),
					Width0 = width,
					Width1 = width,
					FaceCamera = true,
					LightEmission = 1,
					LightInfluence = 0,
					Segments = 1,
					Texture = "",
					Parent = root,
				})
			end
		end
		h.strands[s] = strand
	end
	-- the rungs: a short bar between the two strands every RungStep studs (the strands are opposite each other)
	h.rungs = {}
	local x = startX + HELIX.RungStep / 2
	local index = 0
	while x < endX do
		index += 1
		local a0 = New("Attachment", { Parent = root })
		local a1 = New("Attachment", { Parent = root })
		New("Beam", {
			Attachment0 = a0, Attachment1 = a1,
			Color = ColorSequence.new(HELIX.RungColors[(index - 1) % 2 + 1]),
			Transparency = NumberSequence.new(HELIX.RungTransparency),
			Width0 = HELIX.RungWidth, Width1 = HELIX.RungWidth,
			FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1, Texture = "",
			Parent = root,
		})
		table.insert(h.rungs, { x = x, a0 = a0, a1 = a1 })
		x += HELIX.RungStep
	end
	return h
end

local function updateHelix(h, dt, speed, pulse)
	h.phase += dt * speed
	for _, rung in ipairs(h.rungs or {}) do
		local alpha = (rung.x - h.startX) / (h.endX - h.startX)
		local theta = h.phase + alpha * h.turns * math.pi * 2
		local c, s = math.cos(theta) * h.radius, math.sin(theta) * h.radius
		rung.a0.Position = Vector3.new(rung.x, c, s)
		rung.a1.Position = Vector3.new(rung.x, -c, -s)
	end
	for s, strand in ipairs(h.strands) do
		for i, attachment in ipairs(strand.attachments) do
			local _, position = helixPoint(i, h.count, h.phase + (s - 1) * math.pi, h.radius, h.startX, h.endX, h.turns)
			attachment.Position = position
		end
		-- the lock-on flash: a bright band running down the strands
		for i, beam in ipairs(strand.beams) do
			local intensity = 0
			if pulse then
				local mid = (strand.xs[i] + strand.xs[i + 1]) / 2
				intensity = math.exp(-((mid - pulse) / 0.4) ^ 2)
			end
			if beam:GetAttribute("I") ~= math.floor(intensity * 20) then
				beam:SetAttribute("I", math.floor(intensity * 20))
				beam.Width0 = h.width * (1 + 2.5 * intensity)
				beam.Width1 = beam.Width0
				beam.Transparency = NumberSequence.new(h.transparency * (1 - intensity))
			end
		end
	end
end

-- Real shadows don't render on low graphics (most phones): there the contact shadows stand in for them instead.
local function lowGraphics()
	local ok, level = pcall(function() return UserSettings().GameSettings.SavedQualityLevel end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		local okRender, render = pcall(function() return settings().Rendering.QualityLevel end)
		return okRender and render.Value > 0 and render.Value <= 4
	end
	return level.Value <= 4
end
local useContactShadows = false -- decided when the stage is built (one shadow source, never both)

-- A soft contact shadow on the floor: a dark blurred pill made of stacked see-through rounded frames on a SurfaceGui
-- (no image needed), centred under the given point, its length along the yaw's X axis.
local SHADOW_LAYERS = 7
local function contactShadow(name, center, yaw, length, width)
	if not useContactShadows then return nil end
	local holder = part({ Name = name, Size = Vector3.new(length, 0.02, width), Transparency = 1,
		CFrame = CFrame.new(center.X, STAGE_CF.Position.Y + FLOOR_Y + 0.012, center.Z) * yaw, Parent = stage })
	local surface = New("SurfaceGui", { Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0, Parent = holder })
	for i = 1, SHADOW_LAYERS do
		local k = 1 - (i - 1) / SHADOW_LAYERS * 0.75
		New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(k, k),
			BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.86, Parent = surface }, { New("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return holder
end

local function buildStage()
	stage = New("Model", { Name = "GeneticsStage" })
	table.clear(lights)
	useContactShadows = lowGraphics()
	-- the dark room (closed, so no sky or sun gets in; big enough that the lights fade out before the walls)
	local roomSize = Vector3.new(110, 80, 110)
	for _, face in ipairs({ { Vector3.new(0, -40, 0), Vector3.new(roomSize.X, 1, roomSize.Z) }, { Vector3.new(0, 40, 0), Vector3.new(roomSize.X, 1, roomSize.Z) },
		{ Vector3.new(0, 0, -50), Vector3.new(roomSize.X, roomSize.Y, 1) }, { Vector3.new(0, 0, 55), Vector3.new(roomSize.X, roomSize.Y, 1) },
		{ Vector3.new(-55, 0, 0), Vector3.new(1, roomSize.Y, roomSize.Z) }, { Vector3.new(55, 0, 0), Vector3.new(1, roomSize.Y, roomSize.Z) } }) do
		part({ Name = "Room", Size = face[2], CFrame = STAGE_CF * CFrame.new(face[1]), Color = ROOM, Parent = stage })
	end
	-- a dark rubber floor under the bar and the overall plate (the key light pools on it; big enough that its edges lie
	-- in the dark, never a visible horizon)
	part({ Name = "Floor", Size = Vector3.new(100, 1, 96), CFrame = STAGE_CF * CFrame.new(-0.5, FLOOR_Y - 0.5, 0.5), Color = Color3.fromHex("#141417"), Material = Enum.Material.Rubber, Parent = stage })
	-- lights: a warm key from the top left (with shadows), a soft fill from the right, a cool rim from behind that catches
	-- the plate edges
	addLight("SpotLight", CFrame.lookAt((STAGE_CF * CFrame.new(-7, 9, 6)).Position, (STAGE_CF * CFrame.new(0.5, 0, 0)).Position),
		{ Face = Enum.NormalId.Front, Brightness = KEY_LIGHT.Brightness, Range = KEY_LIGHT.Range, Angle = KEY_LIGHT.Angle, Color = KEY_LIGHT.Color, Shadows = not useContactShadows }, stage)
	addLight("PointLight", STAGE_CF * CFrame.new(9, 2, 6), { Brightness = 0.55, Range = 20, Color = Color3.fromHex("#DCE6FF"), Shadows = false }, stage)
	addLight("SpotLight", CFrame.lookAt((STAGE_CF * CFrame.new(2, 5, -8)).Position, (STAGE_CF * CFrame.new(1, 0, 0)).Position),
		{ Face = Enum.NormalId.Front, Brightness = 3, Range = 18, Angle = 60, Color = Color3.fromHex("#9CC2FF"), Shadows = false }, stage)

	-- the bar: a glassy grip with a soft glowing core, the inner collar, the chrome sleeve
	local barModel = New("Model", { Name = "Bar", Parent = stage })
	local gripLength = 0 - BAR.GripStart - 0.15
	local grip = cylinder("Grip", gripLength, 0.28, Color3.fromHex("#9FB4C8"), Enum.Material.Glass, BAR_CF * CFrame.new(BAR.GripStart + gripLength / 2, 0, 0), barModel)
	grip.Transparency = 0.35
	cylinder("Core", gripLength, 0.09, HELIX.Color, Enum.Material.Neon, grip.CFrame, barModel).Transparency = 0.45
	cylinder("GripEnd", 0.06, 0.32, CHROME, Enum.Material.Metal, BAR_CF * CFrame.new(BAR.GripStart, 0, 0), barModel)
	cylinder("InnerCollar", 0.3, 0.78, CHROME, Enum.Material.Metal, BAR_CF * CFrame.new(0, 0, 0), barModel)
	local sleeveLength = BAR.SleeveEnd - 0.15
	cylinder("Sleeve", sleeveLength, 0.5, CHROME, Enum.Material.Metal, BAR_CF * CFrame.new(0.15 + sleeveLength / 2, 0, 0), barModel)
	cylinder("EndCap", 0.08, 0.56, CHROME:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Metal, BAR_CF * CFrame.new(BAR.SleeveEnd, 0, 0), barModel)
	castShadows(barModel)
	-- the DNA helix along the whole bar (thin, soft, slow)
	helix = makeHelix(BAR_CF, HELIX.Points, HELIX.Radius, BAR.GripStart, BAR.SleeveEnd, HELIX.Turns, HELIX.Width, HELIX.Color, HELIX.Transparency, stage)

	stage.Parent = Workspace
end

local function destroyStage()
	if stage then stage:Destroy() end
	stage, helix = nil, nil
	table.clear(lights)
end

------------------------------------------------------------------------
-- Camera: framed so the bar and the overall plate fit between the header and the labels
------------------------------------------------------------------------
local savedCamera = nil
local cameraBase = nil
local fovPunch, shakeUntil, shakeStrength = 0, 0, 0
local ROW_H = 62      -- px of one row of plate labels (name + grade circle + multiplier)
local ARROW_H = 18    -- ...plus the upgrade arrow row after a reroll
local labelRows = 1   -- 1, or 2 when neighbouring labels would touch (they stagger)
local function labelBand() return labelRows * ROW_H + ARROW_H end
local function columnWidth() return COMPACT and 96 or 112 end

local function framePoints()
	local points = {}
	local r = PLATE.Diameter.S / 2 + 0.1
	for _, x in ipairs({ BAR.GripStart, BAR.SleeveEnd }) do
		table.insert(points, (BAR_CF * CFrame.new(x, r, 0)).Position)
		table.insert(points, (BAR_CF * CFrame.new(x, -r, 0)).Position)
	end
	local hr = HERO.Diameter / 2 + 0.1
	for _, offset in ipairs({ Vector3.new(0, hr, hr), Vector3.new(0, hr, -hr), Vector3.new(0, -hr, hr), Vector3.new(0, -hr, -hr) }) do
		table.insert(points, (HERO_CF * CFrame.new(offset)).Position)
	end
	return points
end

-- The free band for the 3D content, in viewport pixels (what WorldToViewportPoint gives). (AbsolutePosition counts from
-- under the Roblox top bar even on a full-screen gui: add the inset back.)
local function bandRect()
	local size = camera.ViewportSize
	local inset = game:GetService("GuiService"):GetGuiInset().Y
	local top = inset + header.AbsolutePosition.Y + header.AbsoluteSize.Y + Spacing.S
	local bottomTop = inset + bottom.AbsolutePosition.Y
	if bottom.AbsoluteSize.Y < 1 then bottomTop = size.Y - 140 end
	local side = COMPACT and Spacing.XL or Spacing.XL * 2
	return side, top, size.X - side, math.max(bottomTop - labelBand() - Spacing.M, top + 80)
end

local function fitCamera()
	local size = camera.ViewportSize
	camera.FieldOfView = CAMERA.Fov
	local left, top, right, bandBottom = bandRect()
	local points = framePoints()
	local center = (STAGE_CF * CFrame.new(-0.4, 0.2, 0.6)).Position
	local distance = 16
	local look = STAGE_CF.Rotation * CFrame.Angles(-CAMERA.Pitch, 0, 0)
	for _ = 1, 10 do
		local cf = CFrame.new(center) * look * CFrame.new(0, 0, distance)
		camera.CFrame = cf
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, p in ipairs(points) do
			local s = camera:WorldToViewportPoint(p)
			minX, minY, maxX, maxY = math.min(minX, s.X), math.min(minY, s.Y), math.max(maxX, s.X), math.max(maxY, s.Y)
		end
		local scale = math.max((maxX - minX) / (right - left), (maxY - minY) / (bandBottom - top))
		distance = math.clamp(distance * scale, 6, 60)
		local studsPerPx = 2 * distance * math.tan(math.rad(CAMERA.Fov) / 2) / size.Y
		local dx = (left + right) / 2 - (minX + maxX) / 2
		local dy = (top + bandBottom) / 2 - (minY + maxY) / 2
		center -= cf.RightVector * dx * studsPerPx
		center += cf.UpVector * dy * studsPerPx
	end
	cameraBase = CFrame.new(center) * look * CFrame.new(0, 0, distance)
	camera.CFrame = cameraBase
	if dof then dof.FocusDistance = (cameraBase.Position - BAR_CF.Position).Magnitude end
end

-- Frames the bar, then checks the label spacing: if neighbouring plates are closer on screen than a label is wide, the
-- labels go in two staggered rows (and the framing leaves room for them).
local function frameCamera()
	if not stage then return end
	if camera.ViewportSize.Y < 2 then return end
	labelRows = 1
	fitCamera()
	local width = columnWidth()
	for slot = 2, 6 do
		local a = camera:WorldToViewportPoint(slotCF(slot - 1).Position)
		local b = camera:WorldToViewportPoint(slotCF(slot).Position)
		if math.abs(b.X - a.X) < width + 4 then
			labelRows = 2
			fitCamera()
			return
		end
	end
end

local function punch(amount)
	fovPunch = math.max(fovPunch, amount)
end
local function shake(strength, time)
	shakeStrength, shakeUntil = strength, os.clock() + (time or 0.15)
end

------------------------------------------------------------------------
-- Reveal state and helpers
------------------------------------------------------------------------
local isOpen = false
local revealing = false
local skipping = false
local plates = {}   -- on the bar, inner to outer: { group, grade, prev, parts, cf, slot, column, line, hit, arrow }
local collar = nil
local hero = nil    -- { parts, cf }
local barShadow, heroShadow = nil, nil -- the contact shadows on the floor
local landed = 0     -- plates on the bar so far (the bar shadow grows with them)
local hoverPlate = nil
local pinnedPlate = nil
local current = nil -- the genetics on screen

-- Runs `step(alpha)` every frame for `duration` (or once at 1 when skipping).
local function animate(duration, step)
	if skipping or duration <= 0 then step(1) return end
	local start = os.clock()
	while true do
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		step(t)
		if t >= 1 then break end
		if skipping then step(1) break end
		RunService.RenderStepped:Wait()
	end
end
local function pause(seconds)
	local stop = os.clock() + seconds
	while not skipping and os.clock() < stop do RunService.RenderStepped:Wait() end
end
local function easeOut(t) return 1 - (1 - t) ^ 3 end
local function easeIn(t) return t * t end
local function play(name, opts)
	if skipping then return nil end
	return Audio.Play2D(name, opts)
end

-- Studio test hook: Workspace attribute "TestGeneticsHold" = n holds the reveal for screenshots: 6 = all plates on the
-- bar, 7 = the overall plate landed. Tweens started meanwhile pause while held.
local held = false
local activeTweens = {}
local function track(tween)
	table.insert(activeTweens, tween)
	if #activeTweens > 40 then table.remove(activeTweens, 1) end
	return tween
end
local function testHold(index)
	if not RunService:IsStudio() then return end
	if not (isOpen and not skipping and Workspace:GetAttribute("TestGeneticsHold") == index) then return end
	held = true
	for _, tween in ipairs(activeTweens) do tween:Pause() end
	while isOpen and not skipping and Workspace:GetAttribute("TestGeneticsHold") == index do task.wait(0.1) end
	for _, tween in ipairs(activeTweens) do
		if tween.PlaybackState == Enum.PlaybackState.Paused then tween:Play() end
	end
	table.clear(activeTweens)
	held = false
end

local function place(entry, cf)
	entry.cf = cf
	entry.parts.model:PivotTo(cf)
end
-- S plates: one quick shine sweep across the face
local function shineSweep(entry)
	local shine = entry.parts.shine
	if skipping or not shine then return end
	shine.Position = UDim2.fromScale(-0.4, 0.5)
	track(Theme.Tween(shine, { Position = UDim2.fromScale(1.4, 0.5) }, 0.5, Enum.EasingStyle.Sine))
end

------------------------------------------------------------------------
-- Labels under the plates (projected every frame) and the card
------------------------------------------------------------------------
local function makeColumn(entry)
	local col = New("Frame", { Name = entry.group, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(columnWidth(), ROW_H + ARROW_H), BackgroundTransparency = 1, Parent = labelLayer },
		{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
	local name = Theme.Text({ LayoutOrder = 1, Text = Muscles.GroupById[entry.group].name, Font = "Regular", TextSize = "Medium", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 22), Parent = col })
	Theme.TextShadow(name)
	-- the grade letter in a circle (the only color in the row) and the multiplier in white
	local row = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = col },
		{ Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local tag = Theme.RankTag(entry.grade, { LayoutOrder = 1, Size = UDim2.fromOffset(32, 32), Parent = row })
	tag:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	tag.Letter.TextSize = Theme.TextSize.Medium
	local mult = Theme.Text({ LayoutOrder = 2, Text = string.format("x%.2f", multOf(entry.grade)), Font = "SemiBold", TextSize = "Large", Upper = false, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Parent = row })
	Theme.TextShadow(mult)
	-- after a reroll: a green arrow for a better grade, a small gray one for a worse grade
	if entry.prev and entry.prev ~= entry.grade then
		local better = multOf(entry.grade) > multOf(entry.prev)
		local row = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = col },
			{ Theme.List(Horizontal, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
		local holder = New("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(better and 14 or 12, better and 14 or 12), BackgroundTransparency = 1, Parent = row })
		local chevron = Icons.Chevron(1, better and Colors.Upgrade or Colors.Muted)
		chevron.Rotation = better and -90 or 90
		chevron.Parent = holder
		if better then
			local up = Theme.Text({ LayoutOrder = 2, Text = "upgrade", Font = "SemiBold", TextSize = "Small", TextColor3 = Colors.Upgrade, Size = UDim2.fromOffset(60, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			Theme.TextShadow(up)
		end
		entry.arrow = row
	end
	local hit = New("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 3, Parent = labelLayer })
	hit.MouseEnter:Connect(function() hoverPlate = entry end)
	hit.MouseLeave:Connect(function() if hoverPlate == entry then hoverPlate = nil end end)
	hit.Activated:Connect(function()
		if revealing then return end
		pinnedPlate = pinnedPlate ~= entry and entry or nil
	end)
	entry.column, entry.hit = col, hit
	if not skipping then Theme.Fade(col, true, 0.25) end
end

local function updateLabels()
	if not cameraBase then return end
	local size = camera.ViewportSize
	local n = #plates
	if n > 0 then
		local bottoms, tops = {}, {}
		local rowY = 0
		for i, entry in ipairs(plates) do
			local r = entry.parts.diameter / 2
			local b = camera:WorldToViewportPoint(entry.cf.Position - Vector3.new(0, r, 0))
			local t = camera:WorldToViewportPoint(entry.cf.Position + Vector3.new(0, r, 0))
			bottoms[i], tops[i] = b, t
			rowY = math.max(rowY, b.Y)
		end
		rowY += Spacing.M
		-- each label right under its own plate (same order, same x); every other one a row lower when they'd touch
		local width = columnWidth()
		local order = {}
		for i in ipairs(plates) do table.insert(order, i) end
		table.sort(order, function(a, b) return bottoms[a].X < bottoms[b].X end)
		local rank = {}
		for r, i in ipairs(order) do rank[i] = r end
		for i, entry in ipairs(plates) do
			-- (a plate joins the bar a moment before its label exists)
			if not entry.column then continue end
			local x = math.clamp(bottoms[i].X, Spacing.S + width / 2, size.X - Spacing.S - width / 2)
			local y = rowY + ((labelRows == 2 and rank[i] % 2 == 0) and ROW_H or 0)
			entry.column.Size = UDim2.fromOffset(width, ROW_H + ARROW_H)
			entry.column.Position = UDim2.fromOffset(x, y)
			-- tap / hover area: the label and the plate above it
			local half = math.max(width / 2, 22)
			local left = math.min(x - width / 2, bottoms[i].X - half / 2)
			local rightEdge = math.max(x + width / 2, bottoms[i].X + half / 2)
			entry.hit.Position = UDim2.fromOffset(left, tops[i].Y)
			entry.hit.Size = UDim2.fromOffset(rightEdge - left, y + ROW_H - tops[i].Y)
			entry.top = tops[i]
		end
	end
	if hero and heroLabels.Visible then
		local b = camera:WorldToViewportPoint(hero.cf.Position - Vector3.new(0, HERO.Diameter / 2 + 0.35, 0))
		heroLabels.Position = UDim2.fromOffset(b.X, b.Y + Spacing.S)
	end
	-- the card: above the plate being hovered (PC) or tapped (phones)
	local target = pinnedPlate or hoverPlate
	if target and target.top and current and not revealing then
		local title, lines = plateMeaning(current, target.group)
		cardTitle.Text = title
		cardTitle.TextColor3 = Theme.RankColors[target.grade]
		for i, label in ipairs(cardLines) do
			label.Text = lines[i] or ""
			label.Visible = lines[i] ~= nil
		end
		card.Visible = true
		local x = math.clamp(target.top.X, card.AbsoluteSize.X / 2 + Spacing.S, size.X - card.AbsoluteSize.X / 2 - Spacing.S)
		card.Position = UDim2.fromOffset(x, math.max(target.top.Y - Spacing.S, card.AbsoluteSize.Y + Spacing.S))
	else
		card.Visible = false
	end
end

------------------------------------------------------------------------
-- The moments
------------------------------------------------------------------------
-- The bar's contact shadow covers the plates on it so far.
local function setBarShadow(count)
	if barShadow then barShadow:Destroy() end
	barShadow = nil
	if count < 1 or not stage then return end
	local first, last = slotX(1) - PLATE.Thickness / 2, slotX(count) + PLATE.Thickness / 2
	local center = BAR_CF * CFrame.new((first + last) / 2, 0, 0)
	barShadow = contactShadow("BarShadow", center.Position, BAR_CF.Rotation, last - first + 0.6, PLATE.Diameter.S * 0.75)
end

-- A plate slides onto the sleeve from its end into its slot (best grade first, so it ends up innermost) and lands with
-- a clank (pitch by grade); S plates get a quick shine sweep.
local function slideOn(entry, slot)
	local target = slotCF(slot)
	local from = BAR_CF * CFrame.new(BAR.SleeveEnd + 1.6, 0, 0)
	place(entry, from)
	animate(TIME.Slide, function(t) place(entry, from:Lerp(target, easeIn(t))) end)
	place(entry, target)
	landed += 1
	setBarShadow(landed)
	play("GeneticsClank", { pitch = FLIP_PITCH[entry.grade] })
	punch(0.4)
	shake(0.04)
	if entry.grade == "S" then
		play("GeneticsShimmer")
		shineSweep(entry)
	end
	makeColumn(entry)
end

local function closeCollar(count)
	collar = { parts = { model = New("Model", { Name = "Collar" }) } }
	local model = collar.parts.model
	local ringPart = cylinder("Ring", 0.28, 0.74, CHROME, Enum.Material.Metal, nil, model)
	cylinder("Lever", 0.14, 0.18, CHROME:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Metal, CFrame.new(0, 0.42, 0), model)
	model.PrimaryPart = ringPart
	castShadows(model)
	model.Parent = stage
	local rest = BAR_CF * CFrame.new(slotX(count) + PLATE.Thickness / 2 + 0.16, 0, 0)
	local start = BAR_CF * CFrame.new(BAR.SleeveEnd + 1.2, 0, 0)
	animate(TIME.Collar, function(t) model:PivotTo(start:Lerp(rest, easeOut(t))) end)
	model:PivotTo(rest)
	play("Click", { pitch = 0.8 })
end

-- The overall plate drops onto the floor next to the bar (standing on its rim) with a thud, then its word fades in.
local function dropHero(grade)
	hero = { parts = makePlate(grade, HERO.Diameter, HERO.Thickness, HERO.Hub, nil, stage) }
	local rest = HERO_CF
	local from = rest + Vector3.new(0, 6, 0)
	animate(TIME.Drop, function(t) place(hero, from:Lerp(rest, easeIn(t))) end)
	place(hero, rest)
	if heroShadow then heroShadow:Destroy() end
	heroShadow = contactShadow("HeroShadow", rest.Position, rest.Rotation, HERO.Thickness * 2.2, HERO.Diameter * 0.6)
	play("GeneticsThud")
	play("GeneticsThudLow")
	play("GeneticsClank", { pitch = 0.7, volume = 0.7 })
	shake(0.18, 0.18)
	punch(1)
	if grade == "S" then shineSweep(hero) end
	wordLabel.Text = WORDS[grade]
	wordLabel.TextColor3 = Theme.RankColors[grade]
	heroLabels.Visible = true
	if not skipping then Theme.Fade(heroLabels, true, 0.3) end
	pause(0.2)
	testHold(7)
end

local function clearBoard()
	for _, entry in ipairs(plates) do
		entry.parts.model:Destroy()
		for _, item in ipairs({ entry.column, entry.hit }) do
			if item then item:Destroy() end
		end
	end
	table.clear(plates)
	landed = 0
	setBarShadow(0)
	if heroShadow then heroShadow:Destroy() heroShadow = nil end
	if collar then collar.parts.model:Destroy() collar = nil end
	if hero then hero.parts.model:Destroy() hero = nil end
	heroLabels.Visible = false
	hoverPlate, pinnedPlate = nil, nil
	card.Visible = false
end

------------------------------------------------------------------------
-- Buttons, confirm
------------------------------------------------------------------------
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

local function setBottom(visible)
	if visible then
		bottom.Visible = true
		Theme.Fade(bottom, true, 0.3)
	else
		bottom.Visible = false
	end
end

local function showCards(genetics)
	local frame, body = Genetics.FrameById[genetics.frame], Genetics.BodyTypeById[genetics.bodyType]
	setCard(frameCard, frameLine(frame))
	drawSilhouette(frame.shoulders or 1)
	setCard(bodyCard, bodyLine(body))
end

------------------------------------------------------------------------
-- The reveal
------------------------------------------------------------------------
local function runReveal(genetics, previous)
	revealing, skipping = true, false
	current = genetics
	titleLabel.Text = previous and "NEW GENETICS" or "YOUR GENETICS"
	clearBoard()
	setBottom(false)
	showCards(genetics)
	skipHint.Visible = true
	-- best grade first: it slides furthest and ends up innermost; the rest stack outward (ties keep the group order)
	local order = {}
	for index, group in ipairs(Muscles.Groups) do
		table.insert(order, { group = group, index = index, grade = genetics.grades[group.id] })
	end
	table.sort(order, function(a, b)
		local ma, mb = multOf(a.grade), multOf(b.grade)
		if ma ~= mb then return ma > mb end
		return a.index < b.index
	end)
	for slot, item in ipairs(order) do
		if not isOpen then return end
		local entry = { group = item.group.id, grade = item.grade, index = item.index, slot = slot, prev = previous and previous.grades[item.group.id] }
		entry.parts = makePlate(item.grade, PLATE.Diameter[item.grade], PLATE.Thickness, PLATE.Hub, item.group.name, stage)
		place(entry, BAR_CF * CFrame.new(BAR.SleeveEnd + 1.6, 0, 0))
		plates[slot] = entry
		task.spawn(slideOn, entry, slot)
		pause(TIME.Gap)
	end
	pause(TIME.Slide)
	if not isOpen then return end
	testHold(6)
	closeCollar(#plates)
	dropHero(genetics.overall)
	revealing = false
	skipHint.Visible = false
	setBottom(true)
	refreshButtons()
end

-- Everything comes off the bar (outermost first) and the overall plate lifts away (before a reroll's reveal).
local function slideOff()
	if collar then
		local model = collar.parts.model
		local from = model:GetPivot()
		animate(0.15, function(t) model:PivotTo(from:Lerp(BAR_CF * CFrame.new(BAR.SleeveEnd + 1.5, 0, 0), easeIn(t))) end)
		model:Destroy()
		collar = nil
	end
	Audio.Play2D("PlateSlide")
	landed = 0
	setBarShadow(0)
	for i = #plates, 1, -1 do
		local entry = plates[i]
		for _, item in ipairs({ entry.column, entry.hit }) do if item then item:Destroy() end end
		local from = entry.cf
		local to = BAR_CF * CFrame.new(BAR.SleeveEnd + 2.5, 0, 0)
		task.spawn(function()
			animate(0.2, function(t) place(entry, from:Lerp(to, easeIn(t))) end)
			entry.parts.model:Destroy()
		end)
		task.wait(0.06)
	end
	table.clear(plates)
	card.Visible = false
	if heroShadow then heroShadow:Destroy() heroShadow = nil end
	if hero then
		local h = hero
		local from = h.cf
		animate(0.22, function(t) place(h, from + Vector3.new(0, 7 * easeIn(t), 0)) end)
		h.parts.model:Destroy()
		hero = nil
	end
	heroLabels.Visible = false
	task.wait(0.2)
end

------------------------------------------------------------------------
-- Frame loop: helix, camera punch / shake, labels
------------------------------------------------------------------------
local function renderStep(dt)
	if not stage then return end
	if helix then updateHelix(helix, dt, HELIX.Speed, nil) end
	if cameraBase then
		fovPunch *= math.exp(-dt * 9)
		camera.FieldOfView = CAMERA.Fov - fovPunch
		local offset = CFrame.new()
		local now = os.clock()
		if now < shakeUntil then
			local m = shakeStrength * ((shakeUntil - now) / 0.15)
			offset = CFrame.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
		end
		-- a slow small swing around the bar, so the light moves across the plates
		local pivot = BAR_CF.Position
		local drift = math.sin(os.clock() * CAMERA.DriftSpeed) * CAMERA.Drift
		camera.CFrame = CFrame.new(pivot) * CFrame.Angles(0, drift, 0) * CFrame.new(-pivot) * cameraBase * offset
	end
	updateLabels()
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local function freeze()
	return Enum.ContextActionResult.Sink
end

local function applyLayout()
	COMPACT = Theme.IsCompact()
	header.Size = UDim2.new(1, 0, 0, COMPACT and 28 or 34)
	header.UIPadding.PaddingLeft = UDim.new(0, COMPACT and Spacing.L or Spacing.XL)
	header.UIPadding.PaddingRight = header.UIPadding.PaddingLeft
	bottom.Size = UDim2.new(1, -(COMPACT and Spacing.L or Spacing.XL) * 2, 0, 0)
	rerollButton.Size = UDim2.new(0, COMPACT and 190 or 220, 1, 0)
	keepButton.Size = UDim2.new(0, COMPACT and 110 or 150, 1, 0)
	frameCard.TextSize = COMPACT and Theme.TextSize.Small or Theme.TextSize.Body
	bodyCard.TextSize = frameCard.TextSize
end

local function open()
	if isOpen then return end
	isOpen = true
	applyLayout()
	SideMenu.SetHidden(true) -- the stage gets the whole screen
	menuButton:SetActive(true)
	oddsPanel.Visible = false
	confirm.Visible, buttons.Visible = false, true
	UIBus.GeneticsVisible:Fire(true)
	ContextActionService:BindActionAtPriority("GeneticsFreeze", freeze, false, Enum.ContextActionPriority.High.Value + 100,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
	Audio.PlayUI("Whoosh")
	-- cut into the stage behind a quick fade to black
	gui.Enabled = true
	labelLayer.Visible = false
	fader.BackgroundTransparency = 1
	Theme.Tween(fader, { BackgroundTransparency = 0 }, 0.18).Completed:Wait()
	if not isOpen then return end
	savedCamera = { type = camera.CameraType, fov = camera.FieldOfView }
	buildStage()
	camera.CameraType = Enum.CameraType.Scriptable
	showCards(ClientData.Get().genetics) -- (the cards' height is part of the framing)
	tokensLabel.Text = "DNA tokens: " .. ClientData.Get().dnaTokens
	setBottom(false)
	task.wait() -- (one frame, so the header and bottom have their sizes)
	frameCamera()
	dof = New("DepthOfFieldEffect", { Name = "GeneticsDOF", FarIntensity = 0.6, NearIntensity = 0, InFocusRadius = 5, FocusDistance = (cameraBase.Position - BAR_CF.Position).Magnitude, Parent = Lighting })
	RunService:BindToRenderStep("GeneticsStage", Enum.RenderPriority.Camera.Value + 2, renderStep)
	labelLayer.Visible = true
	Theme.Tween(fader, { BackgroundTransparency = 1 }, 0.3)
	task.spawn(runReveal, ClientData.Get().genetics, nil)
end

local function close()
	if not isOpen then return end
	isOpen = false
	skipping = true -- (a running reveal finishes at once)
	menuButton:SetActive(false)
	ContextActionService:UnbindAction("GeneticsFreeze")
	Theme.Tween(fader, { BackgroundTransparency = 0 }, 0.18).Completed:Wait()
	RunService:UnbindFromRenderStep("GeneticsStage")
	clearBoard()
	destroyStage()
	if dof then dof:Destroy() dof = nil end
	cameraBase = nil
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = savedCamera and savedCamera.fov or 70
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	SideMenu.SetHidden(false)
	UIBus.GeneticsVisible:Fire(false)
	labelLayer.Visible = false
	setBottom(false)
	Theme.Tween(fader, { BackgroundTransparency = 1 }, 0.25).Completed:Wait()
	if not isOpen then gui.Enabled = false end
end

local function keep()
	if revealing then return end
	if not ClientData.Get().onboarding.geneticsRevealed then
		Remotes.PlayerAction:FireServer("GeneticsSeen")
	end
	close()
end
keepButton.Activated:Connect(keep)

-- skip: tap anywhere (or the Space / Enter key) while the reveal runs
skipCatcher.Activated:Connect(function()
	if revealing then skipping = true end
	pinnedPlate = nil
end)
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed or not isOpen or not revealing then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then skipping = true end
end)

-- Reroll: asks first when a good roll (overall A or S, or any S plate) is about to be replaced
local pendingReroll = false
local function doReroll()
	if revealing or not isOpen then return end
	revealing = true
	pendingReroll = true
	refreshButtons()
	local previous = table.clone(current or ClientData.Get().genetics)
	previous.grades = table.clone(previous.grades)
	Remotes.PlayerAction:FireServer("Reroll")
	task.spawn(function()
		setBottom(false)
		slideOff()
		-- wait for the server's new genetics, then the new reveal
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
	if needsConfirm() then
		local genetics = current or ClientData.Get().genetics
		confirmText.Text = "Replace your " .. genetics.overall .. " genetics? You can't get them back."
		buttons.Visible, confirm.Visible = false, true
		Theme.Fade(confirm, true, 0.2)
	else
		doReroll()
	end
end)
confirmCancel.Activated:Connect(function()
	confirm.Visible, buttons.Visible = false, true
end)
confirmYes.Activated:Connect(function()
	confirm.Visible, buttons.Visible = false, true
	doReroll()
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

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if isOpen and stage then
		applyLayout()
		task.defer(frameCamera)
	end
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
