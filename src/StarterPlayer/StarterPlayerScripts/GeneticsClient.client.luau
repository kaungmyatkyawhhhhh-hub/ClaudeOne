-- GeneticsClient: the genetics reveal (first join) and reroll screen (owner's genetics redesign).
-- A small dark 3D stage of its own, far above the town (this client only), seen by the real camera, so the plates can
-- carry SurfaceGui letters, real lights, Neon glow and particles (none of which render in a ViewportFrame).
--  * The bar is a glowing DNA bar: two thin strands of light spiral along it and slowly turn. Faint DNA dust and soft
--    helix shapes drift in the dark behind it, blurred (DepthOfField).
--  * Each group's genetics is a plate, revealed one at a time (Chest, Shoulders, Back, Arms, Legs, Core): it spins in
--    face-down, pauses, flips to show its grade. The higher the grade, the bigger the moment: C/D a small pop, B a gold
--    shimmer, A a blue burst, S dims the stage, drum roll, glows and shakes, then explodes with an "S!" slam. It then
--    locks onto the bar in grade order (best on the inside) with a flash running down the helix; a collar closes the
--    sleeve. Two or more S: a "BLESSED" banner. The overall grade is a big plate standing on the left, last.
--  * Under each plate its multiplier ("x1.50 gains") in the grade color; tap / hover one for what it means. Frame and
--    body type are two cards. Reroll (shows its cost) replays the reveal: plates that got better show a green arrow,
--    worse ones a gray one; a good roll asks before it is replaced. Tap anywhere to skip to the end.
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

------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------
local STAGE_CF = CFrame.new(0, 1600, 0) -- far above the town, inside its own dark room
-- Plates: wide and thin (diameter about 3x thickness), all the same thickness; better grade = a little wider.
local PLATE = { Thickness = 0.62, Diameter = { S = 2.3, A = 2.15, B = 2.0, C = 1.85, D = 1.7 }, Hub = 0.62 }
local HERO = { Thickness = 0.9, Diameter = 3.2, Hub = 0.9 }
-- Along the bar's own X axis: grip on the left, the inner collar at 0, plates from SlotStart outward, sleeve end.
local BAR = { GripStart = -3.8, SlotStart = 0.15, SleeveEnd = 4.5, Yaw = math.rad(-28) }
local BAR_CF = STAGE_CF * CFrame.new(0.6, 0, 0) * CFrame.Angles(0, BAR.Yaw, 0) -- sleeve end turned toward the camera
local HERO_CF = STAGE_CF * CFrame.new(-5.4, 0.15, 0.6) * CFrame.Angles(0, math.rad(-70), 0) -- face toward the camera
-- where a plate is shown before it goes on the bar: the left, in front (the overall plate only stands there at the end)
local SPOT = (STAGE_CF * CFrame.new(-3.7, 0.25, 2.2)).Position
local CAMERA = { Fov = 30, Pitch = math.rad(6) }
local HELIX = { Color = Color3.fromHex("#BFE3FF"), Radius = 0.3, Turns = 2.4, Points = 60, Speed = 0.55, Width = 0.045, Transparency = 0.35 }
local CHROME = Color3.fromHex("#D6D8DE")
local ROOM = Color3.fromHex("#050507")
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local WORDS = { S = "Genetic Freak", A = "Blessed", B = "Gifted", C = "Average", D = "Hardgainer" }
local FLIP_PITCH = { S = 0.85, A = 0.92, B = 1, C = 1.06, D = 1.12 }
local PLURAL = { Shoulders = true, Arms = true, Legs = true }
local TIME = { SpinIn = 0.55, FaceDown = 0.3, Flip = 0.3, Hold = 0.45, MakeRoom = 0.18, Fly = 0.32, Drop = 0.15, Helix = 0.22 }

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
		{ New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.M), PaddingRight = UDim.new(0, Spacing.M), PaddingTop = UDim.new(0, Spacing.S), PaddingBottom = UDim.new(0, Spacing.S) }) })
	-- one line, as wide as its text (white name, gray bonus): never clipped
	local label = Theme.Text({ Font = "Regular", TextSize = "Body", RichText = true, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY, Parent = card })
	return label
end
local frameCard = infoCard(1)
local bodyCard = infoCard(2)
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
local heroLabels = New("Frame", { Name = "Overall", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(200, 44), BackgroundTransparency = 1, Visible = false, Parent = labelLayer },
	{ Theme.List(Vertical, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
local overallLabel = Theme.Text({ LayoutOrder = 1, Text = "Overall", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), Parent = heroLabels })
local wordLabel = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, 0, 0, 26), Parent = heroLabels })
Theme.TextShadow(overallLabel)
Theme.TextShadow(wordLabel)

-- Big moments: the "S!" slam and the BLESSED banner (text over the stage, never a window)
local function slamText(text, size, color)
	local label = Theme.Text({ Text = text, Font = "SemiBold", TextSize = size, TextColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(600, Theme.TextSize[size] + 20), ZIndex = 6, Parent = labelLayer })
	Theme.TextShadow(label, 0.3)
	local scale = New("UIScale", { Scale = 2, Parent = label })
	return label, scale
end

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
local backHelices = {}
local fx = nil      -- Attachment the bursts come from
local dof = nil

local function part(props)
	local p = New("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.SmoothPlastic, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth })
	for key, value in pairs(props) do p[key] = value end
	return p
end
local function cylinder(name, length, diameter, color, material, cf, parent)
	return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), Color = color, Material = material or Enum.Material.SmoothPlastic, CFrame = cf or CFrame.new(), Parent = parent })
end

-- A circle drawn on a SurfaceGui (rings on the plate faces)
local function ring(parent, scale, color, thickness, transparency)
	return New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale), BackgroundTransparency = 1, Parent = parent }, {
		New("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		New("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0 }),
	})
end

-- One plate (axis = X, front face = +X): body with a slight metallic sheen, raised lips on both rims, a chrome hub, a
-- Neon glow ring (hidden) and a light for the big moments. The front face carries the grade letter (SurfaceGui) between
-- the hub and the rim, with a raised-rim highlight and an inset ring; the back face only the rings (face-down side).
local PPS = 100 -- SurfaceGui pixels per stud on the faces
local function makePlate(grade, diameter, thickness, hub, groupName, parent)
	local style = Theme.GradePlates[grade]
	local model = New("Model", { Name = "Plate" })
	local body = cylinder("Body", thickness, diameter, style.Fill, nil, nil, model)
	body.Reflectance = 0.08
	model.PrimaryPart = body
	-- the raised rim around the edge: a slightly wider band set inside the plate (it only shows at the edge; a disc on
	-- the face would fight with it)
	cylinder("Lip", thickness * 0.55, diameter + 0.05, style.Rim, nil, nil, model)
	cylinder("Hub", thickness + 0.08, hub, CHROME, Enum.Material.Metal, nil, model)
	cylinder("Hole", thickness + 0.1, hub * 0.6, Color3.fromRGB(20, 20, 24), nil, nil, model)
	local glow = cylinder("Glow", thickness + 0.04, diameter + 0.16, style.Glow, Enum.Material.Neon, nil, model)
	glow.Transparency = 1
	local light = New("PointLight", { Brightness = 0, Range = 12, Color = style.Glow, Shadows = false, Parent = body })
	local px = diameter * PPS
	for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
		local surface = New("SurfaceGui", { Name = face.Name, Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = PPS, LightInfluence = 1, Parent = body })
		local canvas = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = surface })
		ring(canvas, 0.985, style.Fill:Lerp(Color3.new(1, 1, 1), 0.3), math.max(px * 0.022, 3), 0.35) -- raised rim highlight
		ring(canvas, 0.93, style.Rim, math.max(px * 0.012, 2), 0.2)                                    -- rim shadow line
		ring(canvas, 0.76, style.Rim, math.max(px * 0.02, 3), 0)                                       -- inset ring
		ring(canvas, (hub + 0.16) / diameter, style.Rim, math.max(px * 0.01, 2), 0.2)                -- around the hub
		if face == Enum.NormalId.Right then
			local letter = New("TextLabel", {
				Name = "Letter",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.215),
				Size = UDim2.fromScale(0.5, 0.26),
				BackgroundTransparency = 1,
				Text = grade,
				FontFace = Theme.Fonts.Bold,
				TextSize = math.floor(px * 0.24),
				TextColor3 = style.Text,
				Parent = canvas,
			}, { New("UIStroke", { Color = Colors.Shadow, Thickness = math.max(px * 0.008, 2), Transparency = 0.45 }) })
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
					TextTransparency = 0.25,
					Parent = canvas,
				})
			end
		end
	end
	model.Parent = parent
	return { model = model, body = body, glow = glow, light = light, diameter = diameter }
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
	return h
end

local function updateHelix(h, dt, speed, pulse)
	h.phase += dt * speed
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

local function emitter(props)
	local e = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		LightEmission = 1,
		LightInfluence = 0,
		Texture = SPARKLE,
		SpreadAngle = Vector2.new(180, 180),
		Parent = fx,
	})
	for key, value in pairs(props) do e[key] = value end
	return e
end
local emitters = {}

local function buildStage()
	stage = New("Model", { Name = "GeneticsStage" })
	table.clear(lights)
	-- the dark room (closed, so no sky or sun gets in)
	-- (big enough that the lights never reach a wall or the floor: just dark all round)
	local roomSize = Vector3.new(110, 80, 110)
	for _, face in ipairs({ { Vector3.new(0, -40, 0), Vector3.new(roomSize.X, 1, roomSize.Z) }, { Vector3.new(0, 40, 0), Vector3.new(roomSize.X, 1, roomSize.Z) },
		{ Vector3.new(0, 0, -50), Vector3.new(roomSize.X, roomSize.Y, 1) }, { Vector3.new(0, 0, 55), Vector3.new(roomSize.X, roomSize.Y, 1) },
		{ Vector3.new(-55, 0, 0), Vector3.new(1, roomSize.Y, roomSize.Z) }, { Vector3.new(55, 0, 0), Vector3.new(1, roomSize.Y, roomSize.Z) } }) do
		part({ Name = "Room", Size = face[2], CFrame = STAGE_CF * CFrame.new(face[1]), Color = ROOM, Parent = stage })
	end
	-- lights: a warm key from above the front, a cool fill, a blue rim behind
	addLight("SpotLight", CFrame.lookAt((STAGE_CF * CFrame.new(-0.5, 9, 9)).Position, (STAGE_CF * CFrame.new(-0.5, 0, 0)).Position),
		{ Face = Enum.NormalId.Front, Brightness = 1.9, Range = 30, Angle = 75, Color = Color3.fromHex("#FFE6C8"), Shadows = false }, stage)
	addLight("PointLight", STAGE_CF * CFrame.new(-7, 3, 9), { Brightness = 0.6, Range = 22, Color = Color3.fromHex("#A8C8FF") }, stage)
	addLight("PointLight", STAGE_CF * CFrame.new(1, 3, -5), { Brightness = 1.2, Range = 14, Color = Color3.fromHex("#6FA8FF") }, stage)

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
	-- the DNA helix along the whole bar
	helix = makeHelix(BAR_CF, HELIX.Points, HELIX.Radius, BAR.GripStart, BAR.SleeveEnd, HELIX.Turns, HELIX.Width, HELIX.Color, HELIX.Transparency, stage)

	-- behind: two soft helix shapes and floating DNA dust, faint (and blurred by the depth of field where the device
	-- renders it)
	table.clear(backHelices)
	for i, spec in ipairs({ { Vector3.new(-9, 2, -22), 18, 1.6, math.rad(10) }, { Vector3.new(10, 0, -26), 22, 2, math.rad(-7) } }) do
		local cf = STAGE_CF * CFrame.new(spec[1]) * CFrame.Angles(0, 0, spec[4])
		local h = makeHelix(cf, 26, spec[3], -spec[2] / 2, spec[2] / 2, spec[2] / 8, 0.08, HELIX.Color, 0.93, stage)
		h.speed = (i % 2 == 0 and -1 or 1) * 0.18
		table.insert(backHelices, h)
	end
	local dust = part({ Name = "Dust", Size = Vector3.new(40, 18, 10), CFrame = STAGE_CF * CFrame.new(0, 3, -12), Transparency = 1, Parent = stage })
	New("ParticleEmitter", {
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = 10,
		Lifetime = NumberRange.new(7, 11),
		Speed = NumberRange.new(0.1, 0.35),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.14), NumberSequenceKeypoint.new(1, 0.08) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(HELIX.Color),
		LightEmission = 1,
		LightInfluence = 0,
		Texture = SPARKLE,
		Parent = dust,
	}):Emit(40)

	-- bursts come from here (moved to wherever the moment happens)
	local fxPart = part({ Name = "FX", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, CFrame = CFrame.new(SPOT), Parent = stage })
	fx = New("Attachment", { Parent = fxPart })
	emitters.sparks = emitter({ Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(5, 11), Drag = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.42), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
	emitters.shimmer = emitter({ Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1.6, 3.4), Drag = 1.5, Acceleration = Vector3.new(0, -0.6, 0),
		RotSpeed = NumberRange.new(-90, 90), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.36), NumberSequenceKeypoint.new(1, 0.06) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
	emitters.puff = emitter({ Texture = SMOKE, LightEmission = 0.2, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(1, 2.2), Drag = 2,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }), Color = ColorSequence.new(Color3.fromHex("#DDE2EA")) })

	stage.Parent = Workspace
end

local function destroyStage()
	if stage then stage:Destroy() end
	stage, helix, fx = nil, nil, nil
	table.clear(lights)
	table.clear(backHelices)
	table.clear(emitters)
end

local function burst(kind, at, color, count)
	if not fx or not emitters[kind] then return end
	-- (from just in front of the plate's face: from its middle the solid plate hides most of them)
	local toward = camera.CFrame.Position - at
	fx.WorldPosition = at + (toward.Magnitude > 0.01 and toward.Unit * 0.6 or Vector3.zero)
	emitters[kind].Color = ColorSequence.new(color)
	emitters[kind]:Emit(count)
end

------------------------------------------------------------------------
-- Camera: framed so the bar, the overall plate and the shown plate fit between the header and the labels
------------------------------------------------------------------------
local savedCamera = nil
local cameraBase = nil
local fovPunch, shakeUntil, shakeStrength = 0, 0, 0
local LABEL_ROW = 64 -- px under the bar for the plate labels

local function framePoints()
	local points = {}
	local r = PLATE.Diameter.S / 2 + 0.1
	for _, x in ipairs({ BAR.GripStart, BAR.SleeveEnd }) do
		table.insert(points, (BAR_CF * CFrame.new(x, r, 0)).Position)
		table.insert(points, (BAR_CF * CFrame.new(x, -r, 0)).Position)
	end
	local hr = HERO.Diameter / 2 + 0.1
	for _, offset in ipairs({ Vector3.new(0, hr, hr), Vector3.new(0, hr, -hr), Vector3.new(0, -hr - 0.35, hr), Vector3.new(0, -hr - 0.35, -hr) }) do
		table.insert(points, (HERO_CF * CFrame.new(offset)).Position)
	end
	local right = STAGE_CF.RightVector
	for _, offset in ipairs({ Vector3.new(0, r, 0), Vector3.new(0, -r, 0), right * r, -right * r }) do
		table.insert(points, SPOT + offset)
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
	return side, top, size.X - side, math.max(bottomTop - LABEL_ROW - Spacing.M, top + 80)
end

local function frameCamera()
	if not stage then return end
	local size = camera.ViewportSize
	if size.Y < 2 then return end
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
local shown = nil   -- the plate being presented
local collar = nil
local hero = nil    -- { parts, cf }
local hoverPlate = nil
local pinnedPlate = nil
local drum = nil
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
local function easeInOut(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end
local function backOut(t) local c = 1.6 return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2 end
local function play(name, opts)
	if skipping then return nil end
	return Audio.Play2D(name, opts)
end

-- Studio test hook: Workspace attribute "TestGeneticsHold" = n holds the reveal at plate n's big moment (7 = the overall
-- plate) until the attribute changes, for screenshots.
-- While held, the moment freezes (particles stop, the light / glow fades pause) so a screenshot catches its peak.
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
	for _, e in pairs(emitters) do e.TimeScale = 0 end
	for _, tween in ipairs(activeTweens) do tween:Pause() end
	while isOpen and not skipping and Workspace:GetAttribute("TestGeneticsHold") == index do task.wait(0.1) end
	for _, e in pairs(emitters) do e.TimeScale = 1 end
	for _, tween in ipairs(activeTweens) do
		if tween.PlaybackState == Enum.PlaybackState.Paused then tween:Play() end
	end
	table.clear(activeTweens)
	held = false
end

local function slotCF(slot)
	return BAR_CF * CFrame.new(BAR.SlotStart + PLATE.Thickness * (slot - 0.5) + 0.004 * (slot - 1), 0, 0)
end
-- facing the camera (front face = +X toward it); `back` = face-down (the blank side toward it)
local function presentCF(position, back)
	local toward = cameraBase and cameraBase.Position or (STAGE_CF * CFrame.new(0, 2, 16)).Position
	return CFrame.lookAt(position, toward) * CFrame.Angles(0, math.rad(back and -90 or 90), 0)
end
local function place(entry, cf)
	entry.cf = cf
	entry.parts.model:PivotTo(cf)
end
local function flash(entry, brightness, glowFrom, time)
	if skipping then return end
	entry.parts.light.Brightness = brightness
	track(Theme.Tween(entry.parts.light, { Brightness = 0 }, time or 0.45))
	if glowFrom then
		entry.parts.glow.Transparency = glowFrom
		track(Theme.Tween(entry.parts.glow, { Transparency = 1 }, time or 0.45))
	end
end
local function dimStage(amount, time)
	for _, item in ipairs(lights) do
		Theme.Tween(item.light, { Brightness = item.base * amount }, time or 0.25)
	end
end

------------------------------------------------------------------------
-- Labels under the plates (projected every frame) and the card
------------------------------------------------------------------------
local COLUMN_W = 100
local function makeColumn(entry)
	local col = New("Frame", { Name = entry.group, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(COLUMN_W, LABEL_ROW), BackgroundTransparency = 1, Parent = labelLayer },
		{ Theme.List(Vertical, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
	local name = Theme.Text({ LayoutOrder = 1, Text = Muscles.GroupById[entry.group].name, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), Parent = col })
	local mult = Theme.Text({ LayoutOrder = 2, Text = string.format("x%.2f gains", multOf(entry.grade)), Font = "SemiBold", TextSize = "Body", TextColor3 = Theme.RankColors[entry.grade], Size = UDim2.new(1, 0, 0, 22), Parent = col })
	Theme.TextShadow(name)
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
	local line = New("Frame", { Name = "Line", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.75, Size = UDim2.fromOffset(0, 1), Parent = labelLayer })
	local hit = New("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 3, Parent = labelLayer })
	hit.MouseEnter:Connect(function() hoverPlate = entry end)
	hit.MouseLeave:Connect(function() if hoverPlate == entry then hoverPlate = nil end end)
	hit.Activated:Connect(function()
		if revealing then return end
		pinnedPlate = pinnedPlate ~= entry and entry or nil
	end)
	entry.column, entry.line, entry.hit = col, line, hit
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
		rowY += Spacing.L
		-- evenly spaced columns, in the plates' left-to-right order, centred under them and kept on screen
		local width = COMPACT and 88 or COLUMN_W
		local center = (bottoms[1].X + bottoms[n].X) / 2
		local first = center - width * (n - 1) / 2
		first = math.clamp(first, Spacing.S + width / 2, size.X - Spacing.S - width / 2 - width * (n - 1))
		for i, entry in ipairs(plates) do
			-- (a plate joins the bar a moment before its label exists)
			if not entry.column then continue end
			local x = first + width * (i - 1)
			entry.column.Size = UDim2.fromOffset(width, LABEL_ROW)
			entry.column.Position = UDim2.fromOffset(x, rowY)
			-- a thin line from the plate's bottom to its label
			local from, to = Vector2.new(bottoms[i].X, bottoms[i].Y + 2), Vector2.new(x, rowY - 2)
			local delta = to - from
			entry.line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
			entry.line.Size = UDim2.fromOffset(delta.Magnitude, 1)
			entry.line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
			-- tap / hover area: the label and the plate above it
			local half = math.max(width / 2, 22)
			local left = math.min(x - width / 2, bottoms[i].X - half / 2)
			local rightEdge = math.max(x + width / 2, bottoms[i].X + half / 2)
			entry.hit.Position = UDim2.fromOffset(left, tops[i].Y)
			entry.hit.Size = UDim2.fromOffset(rightEdge - left, rowY + LABEL_ROW - tops[i].Y)
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
-- The grade's moment, right after the flip (the plate faces the camera at SPOT).
local function celebrate(entry)
	local grade = entry.grade
	local at = entry.cf.Position
	local glowColor = Theme.GradePlates[grade].Glow
	if grade == "C" or grade == "D" then
		-- small pop: a little bump toward the camera and a soft puff
		play("GeneticsPop")
		flash(entry, 1.5, 0.7, 0.3)
		burst("puff", at, Colors.Text, 10)
		local base = entry.cf
		local toward = (cameraBase.Position - at).Unit
		animate(0.22, function(t)
			local k = math.sin(t * math.pi) * 0.18
			place(entry, base + toward * k)
		end)
		punch(0.6)
		testHold(entry.index)
	elseif grade == "B" then
		-- gold shimmer
		play("GeneticsShimmer")
		flash(entry, 2.5, 0.45, 0.9)
		burst("shimmer", at, glowColor, 40)
		punch(1)
		pause(0.2)
		testHold(entry.index)
	elseif grade == "A" then
		-- blue burst
		play("GeneticsBurst")
		flash(entry, 4, 0.3, 0.8)
		burst("sparks", at, glowColor, 55)
		burst("shimmer", at, Colors.Text, 14)
		punch(1.6)
		shake(0.08)
		pause(0.12)
		testHold(entry.index)
	else
		-- S: the stage dims, a drum roll, the plate glows and shakes... then explodes
		if not skipping then
			dimStage(0.2, 0.3)
			drum = play("GeneticsDrumRoll")
		end
		local base = entry.cf
		animate(1.25, function(t)
			if skipping then return end
			entry.parts.glow.Transparency = 0.95 - 0.7 * t
			entry.parts.light.Brightness = 3 * t
			local amp = 0.07 * t
			place(entry, base + Vector3.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, (math.random() - 0.5) * amp))
		end)
		place(entry, base)
		if drum then drum:Stop() drum = nil end
		if not skipping then
			dimStage(1, 0.4)
			play("GeneticsExplode")
			play("GeneticsThudLow")
			flash(entry, 9, 0, 0.8)
			entry.parts.light.Range = 26
			burst("sparks", at, glowColor, 80)
			burst("sparks", at, Colors.Text, 25)
			burst("shimmer", at, glowColor, 30)
			punch(3)
			shake(0.3, 0.35)
			local label, scale = slamText("S!", "Slam", Theme.RankColors.S)
			-- (above the plate, clear of its own letter)
			local above = camera:WorldToViewportPoint(at + Vector3.new(0, entry.parts.diameter / 2, 0))
			label.Position = UDim2.fromOffset(above.X, above.Y - Theme.TextSize.Slam * 0.6)
			Theme.Tween(scale, { Scale = 1 }, 0.3, Theme.Motion.Bounce)
			task.delay(0.9, function()
				while held do task.wait(0.1) end
				Theme.Tween(label, { TextTransparency = 1 }, 0.3)
				local stroke = label:FindFirstChildOfClass("UIStroke")
				if stroke then Theme.Tween(stroke, { Transparency = 1 }, 0.3) end
				Debris:AddItem(label, 0.35)
			end)
			pause(0.3)
			testHold(entry.index)
			pause(0.2)
			task.delay(0.6, function() if entry.parts.light then entry.parts.light.Range = 12 end end)
		end
	end
end

-- Spins in face-down, pauses, flips to show the grade.
local function present(entry)
	local finalBack = presentCF(SPOT, true)
	local start = SPOT + Vector3.new(0, -6, 0)
	play("GeneticsSpin")
	animate(TIME.SpinIn, function(t)
		local e = easeOut(t)
		local spin = (1 - e) * math.pi * 6 -- a few turns, settling face-down
		place(entry, CFrame.new(start:Lerp(SPOT, e)) * finalBack.Rotation * CFrame.Angles(spin, 0, 0))
	end)
	pause(TIME.FaceDown)
	play("GeneticsFlip", { pitch = FLIP_PITCH[entry.grade] })
	local front = presentCF(SPOT, false)
	animate(TIME.Flip, function(t)
		local e = backOut(t)
		place(entry, CFrame.new(SPOT) * finalBack.Rotation * CFrame.Angles(0, math.pi * e, 0))
	end)
	place(entry, front)
	punch(0.8)
	celebrate(entry)
end

-- Goes onto the bar at its sorted slot (best grade on the inside): the plates outside it make room, it flies over and
-- drops on, and a flash of light runs down the helix into it.
local function lockOn(entry, slot)
	-- make room
	local moving = {}
	for i = #plates, slot, -1 do
		table.insert(moving, { entry = plates[i], from = plates[i].cf, to = slotCF(i + 1) })
	end
	if #moving > 0 then
		play("PlateSlide")
		animate(TIME.MakeRoom, function(t)
			for _, m in ipairs(moving) do place(m.entry, m.from:Lerp(m.to, easeInOut(t))) end
		end)
	end
	table.insert(plates, slot, entry)
	for i, p in ipairs(plates) do p.slot = i end
	-- fly over the slot, then drop onto the sleeve
	local target = slotCF(slot)
	local above = target + Vector3.new(0, 2.4, 0)
	local from = entry.cf
	animate(TIME.Fly, function(t)
		local e = easeInOut(t)
		local arc = math.sin(e * math.pi) * 0.6
		place(entry, from:Lerp(above, e) + Vector3.new(0, arc, 0))
	end)
	animate(TIME.Drop, function(t) place(entry, above:Lerp(target, easeIn(t))) end)
	place(entry, target)
	-- the helix flash runs from the grip into the plate
	if helix and not skipping then
		local slotX = BAR.SlotStart + PLATE.Thickness * (slot - 0.5)
		local t0 = os.clock()
		helix.pulse = { from = BAR.GripStart, to = slotX, start = t0, time = TIME.Helix }
	end
	pause(TIME.Helix * 0.8)
	play("GeneticsClank", { pitch = FLIP_PITCH[entry.grade] })
	flash(entry, 3, 0.55, 0.4)
	if not skipping then burst("shimmer", entry.cf.Position + Vector3.new(0, 0, 0), HELIX.Color, 10) end
	punch(0.5)
	shake(0.05)
end

local function closeCollar(count)
	collar = { parts = { model = New("Model", { Name = "Collar" }) } }
	local model = collar.parts.model
	local ringPart = cylinder("Ring", 0.28, 0.74, CHROME, Enum.Material.Metal, nil, model)
	cylinder("Lever", 0.14, 0.18, CHROME:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Metal, CFrame.new(0, 0.42, 0), model)
	model.PrimaryPart = ringPart
	model.Parent = stage
	local rest = BAR_CF * CFrame.new(BAR.SlotStart + PLATE.Thickness * count + 0.004 * (count - 1) + 0.15, 0, 0)
	local start = BAR_CF * CFrame.new(BAR.SleeveEnd + 1.2, 0, 0)
	play("PlateSlide")
	animate(0.25, function(t) model:PivotTo(start:Lerp(rest, easeOut(t))) end)
	model:PivotTo(rest)
	play("Click", { pitch = 0.8 })
end

local function blessedBanner()
	if skipping then return end
	play("GeneticsBlessed")
	local _, top = bandRect()
	local label, scale = slamText("BLESSED", "Huge", Colors.Gold)
	label.Position = UDim2.fromOffset(camera.ViewportSize.X / 2, top + 30)
	Theme.Tween(scale, { Scale = 1 }, 0.3, Theme.Motion.Bounce)
	punch(1.5)
	pause(0.35)
	testHold(8)
	pause(0.75)
	Theme.Tween(label, { TextTransparency = 1 }, 0.35)
	Debris:AddItem(label, 0.4)
end

-- The overall plate drops onto its stand with a thud, then its word fades in.
local function dropHero(grade)
	hero = { parts = makePlate(grade, HERO.Diameter, HERO.Thickness, HERO.Hub, nil, stage) }
	-- its stand: a low dark block with a chrome trim (comes with the plate)
	-- (built where the plate is now, at the origin; it moves with the plate)
	local stand = part({ Name = "Stand", Size = Vector3.new(1.5, 0.32, 1.7), CFrame = hero.parts.body.CFrame * CFrame.new(0, -HERO.Diameter / 2 - 0.16, 0), Color = Color3.fromHex("#1C1C20"), Material = Enum.Material.Rubber, Parent = hero.parts.model })
	part({ Name = "Trim", Size = Vector3.new(1.54, 0.05, 1.74), CFrame = stand.CFrame * CFrame.new(0, 0.16, 0), Color = CHROME, Material = Enum.Material.Metal, Parent = hero.parts.model })
	local rest = HERO_CF
	local from = rest + Vector3.new(0, 7, 0)
	animate(0.32, function(t) place(hero, from:Lerp(rest, easeIn(t))) end)
	play("GeneticsThud")
	play("GeneticsThudLow")
	play("GeneticsClank", { pitch = 0.7, volume = 0.7 })
	shake(0.22, 0.2)
	punch(1.2)
	for _, y in ipairs({ 0.14, 0 }) do
		local a = hero.cf
		animate(0.08, function(t) place(hero, a:Lerp(rest + Vector3.new(0, y, 0), t)) end)
	end
	place(hero, rest)
	flash(hero, grade == "S" and 7 or 4, grade == "S" and 0.1 or 0.4, 0.8)
	if grade == "S" or grade == "A" then burst("sparks", rest.Position, Theme.GradePlates[grade].Glow, 50) end
	wordLabel.Text = WORDS[grade]
	wordLabel.TextColor3 = Theme.RankColors[grade]
	heroLabels.Visible = true
	if not skipping then Theme.Fade(heroLabels, true, 0.35) end
	pause(0.4)
	testHold(7)
end

local function clearBoard()
	for _, entry in ipairs(plates) do
		entry.parts.model:Destroy()
		for _, item in ipairs({ entry.column, entry.line, entry.hit }) do
			if item then item:Destroy() end
		end
	end
	table.clear(plates)
	if shown then shown.parts.model:Destroy() shown = nil end
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
	for index, group in ipairs(Muscles.Groups) do
		if not isOpen then return end
		local grade = genetics.grades[group.id]
		local entry = { group = group.id, grade = grade, index = index, prev = previous and previous.grades[group.id] }
		entry.parts = makePlate(grade, PLATE.Diameter[grade], PLATE.Thickness, PLATE.Hub, group.name, stage)
		shown = entry
		place(entry, CFrame.new(SPOT + Vector3.new(0, -6, 0)))
		present(entry)
		pause(grade == "S" and 0.25 or TIME.Hold)
		-- sorted slot: after every plate with the same or a better grade (best on the inside)
		local slot = 1
		for _, other in ipairs(plates) do
			if multOf(other.grade) >= multOf(grade) then slot += 1 end
		end
		shown = nil
		lockOn(entry, slot)
		makeColumn(entry)
	end
	if not isOpen then return end
	closeCollar(#plates)
	local sCount = 0
	for _, grade in pairs(genetics.grades) do if grade == "S" then sCount += 1 end end
	if sCount >= 2 then blessedBanner() end
	pause(0.25)
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
	for i = #plates, 1, -1 do
		local entry = plates[i]
		for _, item in ipairs({ entry.column, entry.line, entry.hit }) do item:Destroy() end
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
	if helix then
		local pulse = helix.pulse
		local at = nil
		if pulse then
			local t = (os.clock() - pulse.start) / pulse.time
			if t >= 1.15 then helix.pulse = nil else at = pulse.from + (pulse.to - pulse.from) * math.clamp(t, 0, 1) end
		end
		updateHelix(helix, dt, HELIX.Speed, at)
	end
	for _, h in ipairs(backHelices) do updateHelix(h, dt, h.speed, nil) end
	if cameraBase then
		fovPunch *= math.exp(-dt * 9)
		camera.FieldOfView = CAMERA.Fov - fovPunch
		local offset = CFrame.new()
		local now = os.clock()
		if now < shakeUntil then
			local m = shakeStrength * ((shakeUntil - now) / 0.15)
			offset = CFrame.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
		end
		camera.CFrame = cameraBase * offset
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
	if drum then drum:Stop() drum = nil end
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
