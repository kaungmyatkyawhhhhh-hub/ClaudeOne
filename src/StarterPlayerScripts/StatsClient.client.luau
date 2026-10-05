-- StatsClient: the STATS side button and the live stats overlay.
-- Six group labels float in the 3D world next to their body part (BillboardGuis sized in studs). Each frame they
-- are placed in camera space: left groups always to the camera's left of the body, right groups always to the
-- right, stacked with a minimum gap so they never overlap or cross. Short thin white elbow lines run to dots on the body.
-- Labels are depth-tested (not AlwaysOnTop) so ProximityPrompts always draw above them. They are drawn part of the
-- way toward the camera (DepthShare) with their stud size scaled by the same share, so on screen they look exactly
-- like labels at the body (and scale with distance the same way). If a raycast finds equipment or a wall between
-- the camera and a label, that label is pulled in front of it (never closer than MinDepth).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")
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
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

-- Sizes are studs (scale with distance) + pixels (a floor so text stays readable on phones).
local OVERLAY = {
	FadeTime = 0.2,
	Label = { Studs = Vector2.new(1.3, 0.95), Pixels = Vector2.new(72, 46) },
	SubLabel = { Studs = Vector2.new(1.45, 0.38), Pixels = Vector2.new(78, 20) },
	BoxShare = 0.78,                          -- the label's box takes this much height; "Needs work" sits under it
	BodyGap = { Studs = 0.3, Pixels = 10 },   -- space between the body and the label column
	StackGap = { Studs = 0.12, Pixels = 6 },  -- minimum space between labels on one side
	Lift = 0.15,                              -- labels sit slightly above their anchor (studs)
	DepthShare = 0.35,                        -- labels are drawn at this share of the body's distance
	MinDepth = 2.5,                           -- studs from the camera, so labels never touch the near clip plane
	Smoothing = 16,                           -- exponential lerp speed (no jitter from animations)
	Elbow = 14,                               -- px of the horizontal part of each leader line
	LineTransparency = 0.25,
	ScreenMargin = 24,                        -- px kept free at the bottom of the screen
	PromptRect = Vector2.new(260, 110),       -- screen area kept clear around a shown ProximityPrompt
}
local SIDE = { Shoulders = -1, Arms = -1, Core = -1, Chest = 1, Back = 1, Legs = 1 } -- -1 = camera left

-- Where each group and sub-muscle sits on the body. Arm parts use whichever arm is on the left of the screen,
-- leg parts whichever leg is on the right; y is a fraction of the part's height from its center.
local GROUP_ANCHOR = {
	Shoulders = { "ArmUpper", 0.35 }, Arms = { "ArmUpper", -0.15 }, Core = { "LowerTorso", 0.25 },
	Chest = { "UpperTorso", 0.2 }, Back = { "UpperTorso", -0.05 }, Legs = { "LegUpper", 0 },
}
local MUSCLE_ANCHOR = {
	UpperChest = { "UpperTorso", 0.32 }, MidChest = { "UpperTorso", 0.05 },
	FrontDelts = { "ArmUpper", 0.42 }, SideDelts = { "ArmUpper", 0.3 }, RearDelts = { "ArmUpper", 0.18 },
	Lats = { "UpperTorso", -0.15 }, Traps = { "UpperTorso", 0.45 }, Rhomboids = { "UpperTorso", 0.15 }, LowerBack = { "LowerTorso", 0.3 },
	Biceps = { "ArmUpper", 0 }, Triceps = { "ArmUpper", -0.25 }, Forearms = { "ArmLower", 0 },
	Quads = { "LegUpper", 0.15 }, Hamstrings = { "LegUpper", -0.15 }, Glutes = { "LowerTorso", -0.3 }, Calves = { "LegLower", 0 },
	Abs = { "LowerTorso", 0.4 }, Obliques = { "LowerTorso", 0.05 },
}

------------------------------------------------------------------------
-- Side button
------------------------------------------------------------------------
local statsButton = SideMenu.Add("Stats", "Stats", Icons.Flex, 1)

------------------------------------------------------------------------
-- Screen layer: leader lines, dots, tap targets, and the Growth Spurt goal
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "StatsOverlay", Enabled = false, DisplayOrder = 6, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None
local root = New("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local lineLayer = New("Frame", { Name = "Lines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
local tapLayer = New("Frame", { Name = "Taps", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })

local goal = Theme.Panel({
	Name = "Goal",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(320, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = root,
}, { Theme.Pad("M"), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local goalTitleRow = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = goal })
local goalTitle = Theme.Text({ Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(0.75, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = goalTitleRow })
local goalHeight = Theme.Text({ Font = "Regular", TextSize = "Body", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.25, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = goalTitleRow })
local goalBlocks = New("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, Parent = goal }, { Theme.List(Horizontal, "XS") })
local goalFills = {}
for index, group in ipairs(Muscles.Groups) do
	local back = New("Frame", { LayoutOrder = index, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = goalBlocks },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	goalFills[group.id] = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
end
local goalLabel = Theme.Text({ LayoutOrder = 3, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = goal })
local spurtButton = Theme.Button("Primary", { Name = "GrowthSpurt", LayoutOrder = 4, Size = UDim2.new(1, 0, 0, Theme.MinTouch), Visible = false, Parent = goal }, {
	Theme.Text({ Text = "Growth Spurt", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

------------------------------------------------------------------------
-- World labels
------------------------------------------------------------------------
-- One invisible local part at the origin carries an attachment and billboard per label (it only exists while open).
local anchorPart = New("Part", {
	Name = "StatsLabels",
	Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(),
})

local entries = {}      -- group labels, each { kind, id, side, anchor, billboard, root, subs, ... }
local groupEntries = {} -- [groupId] = entry
local expandedGroup = nil

local function scaledText(props, maxSize)
	props.BackgroundTransparency = 1
	props.TextScaled = true -- world-space label sized in studs: the only place text may scale
	props.TextColor3 = props.TextColor3 or Colors.Text
	return New("TextLabel", props, {
		New("UITextSizeConstraint", { MinTextSize = Theme.TextSize.Small, MaxTextSize = maxSize }),
	})
end

local function newBillboard(name, size)
	local attachment = New("Attachment", { Name = name, Parent = anchorPart })
	local billboard = New("BillboardGui", {
		Name = name,
		Adornee = attachment,
		Size = UDim2.new(size.Studs.X, size.Pixels.X, size.Studs.Y, size.Pixels.Y),
		LightInfluence = 0,
		Enabled = false,
		Parent = anchorPart,
	})
	return attachment, billboard
end

-- the faint dark see-through box behind each label
local function labelBox(props)
	props.BackgroundColor3 = Colors.Panel
	props.BackgroundTransparency = Theme.Alpha.LabelBacking
	return New("Frame", props, { New("UICorner", { CornerRadius = UDim.new(0.18, 0) }) })
end

local function newLine(transparency, dotSize)
	local function segment()
		return New("Frame", { BackgroundColor3 = Colors.Text, BackgroundTransparency = transparency, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = lineLayer })
	end
	local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(dotSize, dotSize), BackgroundColor3 = Colors.Text, Visible = false, Parent = lineLayer }, { Theme.Round("Round") })
	return { segment(), segment() }, dot
end

local function collapse()
	if not expandedGroup then return end
	for _, sub in ipairs(groupEntries[expandedGroup].subs) do
		sub.line[1].Visible, sub.line[2].Visible, sub.dot.Visible = false, false, false
		local tween = Theme.Fade(sub.root, false, 0.15)
		if tween then
			tween.Completed:Connect(function()
				if expandedGroup ~= sub.group then sub.billboard.Enabled = false end
			end)
		end
	end
	expandedGroup = nil
end

local function makeGroupLabel(group)
	local side = SIDE[group.id]
	local hAlign = side < 0 and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left -- hugs the body side
	local align = side < 0 and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	local attachment, billboard = newBillboard("Stats_" .. group.id, OVERLAY.Label)
	local labelRoot = New("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = billboard },
		{ Theme.List(Vertical, nil, hAlign, Enum.VerticalAlignment.Top) })
	local box = labelBox({ Name = "Box", LayoutOrder = 1, Size = UDim2.fromScale(1, OVERLAY.BoxShare), Parent = labelRoot })
	New("UIPadding", { PaddingLeft = UDim.new(0.1, 0), PaddingRight = UDim.new(0.1, 0), PaddingTop = UDim.new(0.08, 0), PaddingBottom = UDim.new(0.08, 0), Parent = box })
	Theme.List(Vertical, nil, hAlign, Enum.VerticalAlignment.Center).Parent = box
	scaledText({ Name = "Name", LayoutOrder = 1, Text = group.name, FontFace = Theme.Fonts.Regular, TextColor3 = Colors.Muted, Size = UDim2.fromScale(1, 0.4), TextXAlignment = align, Parent = box }, 18)
	local level = scaledText({ Name = "Level", LayoutOrder = 2, FontFace = Theme.Fonts.Light, Size = UDim2.fromScale(1, 0.6), TextXAlignment = align, Parent = box }, 32)
	local needs = scaledText({ Name = "Needs", LayoutOrder = 2, Text = "Needs work", FontFace = Theme.Fonts.Regular, TextColor3 = Colors.NeedsWork, Size = UDim2.fromScale(1, 1 - OVERLAY.BoxShare), TextXAlignment = align, Visible = false, Parent = labelRoot }, 16)
	needs.TextScaled = false -- stays a small, readable fixed size
	needs.TextSize = Theme.TextSize.Small
	Theme.TextShadow(needs, 0.5)

	-- tap target in screen space (billboards in the world can't be tapped); sinks the tap so it never lifts
	local tap = New("TextButton", { Name = group.id, Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Visible = false, Parent = tapLayer })

	local entry = { kind = "group", id = group.id, side = side, anchor = GROUP_ANCHOR[group.id], size = OVERLAY.Label,
		attachment = attachment, billboard = billboard, root = labelRoot, level = level, needs = needs,
		tap = tap, visible = true, subs = {} }
	entry.line, entry.dot = newLine(OVERLAY.LineTransparency, 6)

	for _, muscle in ipairs(group.muscles) do
		local subAttachment, subBillboard = newBillboard("Stats_" .. muscle.id, OVERLAY.SubLabel)
		local subRoot = labelBox({ Name = "Root", Size = UDim2.fromScale(1, 1), Parent = subBillboard })
		New("UIPadding", { PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0), PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), Parent = subRoot })
		Theme.List(Horizontal, "XS", hAlign).Parent = subRoot
		scaledText({ Name = "Name", LayoutOrder = side < 0 and 1 or 2, Text = muscle.name, FontFace = Theme.Fonts.Regular, TextColor3 = Colors.Muted, Size = UDim2.fromScale(0.72, 1), TextXAlignment = align, Parent = subRoot }, 16)
		local subLevel = scaledText({ Name = "Level", LayoutOrder = side < 0 and 2 or 1, FontFace = Theme.Fonts.Light, Size = UDim2.fromScale(0.22, 1), TextXAlignment = side < 0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, Parent = subRoot }, 18)
		local sub = { kind = "muscle", id = muscle.id, group = group.id, side = side, anchor = MUSCLE_ANCHOR[muscle.id], size = OVERLAY.SubLabel,
			attachment = subAttachment, billboard = subBillboard, root = subRoot, level = subLevel, visible = true }
		sub.line, sub.dot = newLine(0.45, 4)
		table.insert(entry.subs, sub)
	end

	tap.Activated:Connect(function()
		local open = expandedGroup ~= group.id
		collapse()
		Audio.PlayUI("Click")
		if open then
			expandedGroup = group.id
			for _, sub in ipairs(entry.subs) do
				sub.smoothed, sub.dotSmoothed, sub.visible = nil, nil, true
				sub.billboard.Enabled = true
				Theme.Fade(sub.root, true, OVERLAY.FadeTime)
			end
		end
	end)
	groupEntries[group.id] = entry
	table.insert(entries, entry)
end
for _, group in ipairs(Muscles.Groups) do makeGroupLabel(group) end

------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------
-- "Maxed" glow (brief: level cap reached): a soft white stroke that slowly pulses on the label's box.
local TweenService = game:GetService("TweenService")
local MAXED_PULSE = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local function setMaxedGlow(box, on)
	local glow = box:FindFirstChild("MaxedGlow")
	if on and not glow then
		glow = New("UIStroke", { Name = "MaxedGlow", Color = Colors.Text, Thickness = 1.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box })
		TweenService:Create(glow, MAXED_PULSE, { Transparency = 0.7 }):Play()
	elseif not on and glow then
		glow:Destroy()
	end
end

local function refreshLabels()
	local data = ClientData.Get()
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local levels, weakest, weakestCount = {}, nil, 0
	for _, group in ipairs(Muscles.Groups) do
		levels[group.id] = math.floor(Muscles.GetGroupLevel(data.muscles, group.id))
	end
	for id, level in pairs(levels) do
		if not weakest or level < levels[weakest] then
			weakest, weakestCount = id, 1
		elseif level == levels[weakest] then
			weakestCount += 1
		end
	end
	for groupId, entry in pairs(groupEntries) do
		local groupMaxed = GrowthSpurts.GoalLevel(data.muscles, Muscles.GroupById[groupId], trainable) >= cap
		entry.level.Text = groupMaxed and "Maxed" or tostring(levels[groupId])
		local box = entry.root:FindFirstChild("Box")
		if box then setMaxedGlow(box, groupMaxed) end
		entry.needs.Visible = groupId == weakest and weakestCount == 1 and not groupMaxed
		for _, sub in ipairs(entry.subs) do
			local level = data.muscles[sub.id].level
			local maxed = level >= cap
			sub.level.Text = maxed and "Max" or tostring(level)
			setMaxedGlow(sub.root, maxed)
		end
	end
end

local wasReady = nil
local function refreshGoal()
	local data = ClientData.Get()
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts))
	local nextSpurt = data.growthSpurts + 1
	goalTitle.Text = "Growth Spurt " .. nextSpurt
	goalHeight.Text = GrowthSpurts.FormatHeight(GrowthSpurts.Get(nextSpurt).height)
	for _, group in ipairs(Muscles.Groups) do
		local ratio = math.clamp(progress.groups[group.id] / progress.required, 0, 1)
		Theme.Tween(goalFills[group.id], { Size = UDim2.fromScale(ratio, 1) })
	end
	goalLabel.Text = string.format("%d/%d groups at level %d  ·  gains x%.2f after", progress.met, progress.total, progress.required, GrowthSpurts.GetBonus(nextSpurt))
	goalLabel.Visible = not progress.ready
	spurtButton.Visible = progress.ready
	if progress.ready and wasReady == false then
		statsButton:SetDot(true) -- something new: clears when stats is opened
		Notify.Show("Growth Spurt ready! Open Stats.", nil, "spurtReady")
	end
	wasReady = progress.ready
end

------------------------------------------------------------------------
-- Placement (only while open)
------------------------------------------------------------------------
local shownPrompts = {}
ProximityPromptService.PromptShown:Connect(function(prompt) shownPrompts[prompt] = true end)
ProximityPromptService.PromptHidden:Connect(function(prompt) shownPrompts[prompt] = nil end)

local function bodyPart(character, camera, key)
	local function pick(rightName, leftName, wantLeft)
		local a, b = character:FindFirstChild(rightName), character:FindFirstChild(leftName)
		if not a or not b then return a or b end
		local ax, bx = camera:WorldToViewportPoint(a.Position).X, camera:WorldToViewportPoint(b.Position).X
		if wantLeft then return ax < bx and a or b end
		return ax > bx and a or b
	end
	if key == "ArmUpper" then return pick("RightUpperArm", "LeftUpperArm", true) end
	if key == "ArmLower" then return pick("RightLowerArm", "LeftLowerArm", true) end
	if key == "LegUpper" then return pick("RightUpperLeg", "LeftUpperLeg", false) end
	if key == "LegLower" then return pick("RightLowerLeg", "LeftLowerLeg", false) end
	return character:FindFirstChild(key)
end

local function anchorPoint(character, camera, anchor)
	local part = bodyPart(character, camera, anchor[1])
	if not part then return nil end
	return (part.CFrame * CFrame.new(0, part.Size.Y * anchor[2], 0)).Position
end

local function promptRects(camera)
	local rects = {}
	for prompt in pairs(shownPrompts) do
		local parent = prompt.Parent
		local position = parent and (parent:IsA("Attachment") and parent.WorldPosition or parent:IsA("BasePart") and parent.Position)
		if position then
			local point, onScreen = camera:WorldToScreenPoint(position)
			if onScreen then table.insert(rects, { Vector2.new(point.X, point.Y), OVERLAY.PromptRect / 2 }) end
		end
	end
	return rects
end

local function overlaps(center, half, rects)
	for _, rect in ipairs(rects) do
		local d = center - rect[1]
		if math.abs(d.X) < half.X + rect[2].X and math.abs(d.Y) < half.Y + rect[2].Y then return true end
	end
	return false
end

local function setVisible(entry, visible)
	if entry.visible == visible then return end
	entry.visible = visible
	Theme.Fade(entry.root, visible, 0.15)
end

local function drawLine(line, a, b, side)
	-- elbow: a short horizontal run from the label toward the body, then straight to the dot
	local elbow = Vector2.new(a.X - side * OVERLAY.Elbow, a.Y)
	local function segment(frame, p, q)
		local delta = q - p
		frame.Position = UDim2.fromOffset((p.X + q.X) / 2, (p.Y + q.Y) / 2)
		frame.Size = UDim2.fromOffset(delta.Magnitude + 1, 1.5)
		frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	end
	segment(line[1], a, elbow)
	segment(line[2], elbow, b)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function step(dt)
	local character = player.Character
	local camera = Workspace.CurrentCamera
	local torso = character and character:FindFirstChild("UpperTorso")
	if not torso then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local scaleValue = humanoid and humanoid:FindFirstChild("BodyHeightScale")
	local bodyScale = scaleValue and scaleValue.Value or 1
	local cf = camera.CFrame
	local viewport = camera.ViewportSize
	local tanHalf = math.tan(math.rad(camera.FieldOfView) / 2)
	local alpha = 1 - math.exp(-OVERLAY.Smoothing * dt)
	local origin = lineLayer.AbsolutePosition
	local rects = promptRects(camera)
	rayParams.FilterDescendantsInstances = { character, camera }

	local center = cf:PointToObjectSpace(torso.Position)
	local arm = character:FindFirstChild("LeftUpperArm")
	local halfWidth = torso.Size.X / 2 + (arm and arm.Size.X or 0.5)

	local active = {}
	for _, entry in ipairs(entries) do
		table.insert(active, entry)
		if expandedGroup == entry.id then
			for _, sub in ipairs(entry.subs) do table.insert(active, sub) end
		end
	end

	-- target positions in camera space (x = right, y = up, z = toward the camera)
	local perSide = { [-1] = {}, [1] = {} }
	for _, entry in ipairs(active) do
		local world = anchorPoint(character, camera, entry.anchor)
		if world then
			local a = cf:PointToObjectSpace(world)
			local bodyZ = math.min(a.Z, -0.6)
			local z = math.min(bodyZ * OVERLAY.DepthShare, -OVERLAY.MinDepth)
			-- pull the label in front of anything between it and the camera
			local probe = cf:PointToWorldSpace(entry.smoothed or a * (z / bodyZ))
			local ray = probe - cf.Position
			local hit = Workspace:Raycast(cf.Position, ray, rayParams)
			if hit and hit.Instance.Transparency < 0.9 then
				z = math.min(z * math.max(hit.Distance - 0.3, 0) / ray.Magnitude, -OVERLAY.MinDepth)
			end
			z = math.max(z, bodyZ) -- never behind the body
			local share = z / bodyZ
			entry.share = share
			local pxPerStud = viewport.Y / (2 * -z * tanHalf)
			-- label size in studs at its depth (studs part scales with the body; pixel part is a floor)
			local size = entry.size.Studs * bodyScale * share + entry.size.Pixels / pxPerStud
			entry.studSize, entry.pxPerStud, entry.anchorWorld = size, pxPerStud, world
			local gap = OVERLAY.BodyGap.Studs * bodyScale * share + OVERLAY.BodyGap.Pixels / pxPerStud
			-- the body's edge, scaled to the label's depth so the column clears the body on screen
			local edge = (center.X + entry.side * halfWidth) * (z / math.min(center.Z, -1))
			entry.target = Vector3.new(edge + entry.side * (gap + size.X / 2), a.Y * (z / math.min(a.Z, -1)) + OVERLAY.Lift * bodyScale * share, z)
			table.insert(perSide[entry.side], entry)
		else
			entry.target = nil
		end
	end
	-- stack each side with a minimum gap, kept between the goal panel and the bottom of the screen
	-- (AbsolutePosition is measured below the top bar; viewport rows include it, so go through the full-screen layer)
	-- the tutorial's coach line sits under the goal panel and the machine panel at the bottom: keep clear of both
	-- (all of these are Theme.ScreenGuis, so their AbsolutePositions share the goal panel's origin)
	local topEdge = goal.AbsolutePosition.Y + goal.AbsoluteSize.Y
	local coachGui = playerGui:FindFirstChild("Tutorial")
	local coachLine = coachGui and coachGui:FindFirstChild("CoachLine")
	if coachGui and coachGui:IsA("ScreenGui") and coachGui.Enabled and coachLine and coachLine:IsA("GuiObject") and coachLine.Visible
		and coachLine.AbsolutePosition.Y < viewport.Y / 2 then
		topEdge = math.max(topEdge, coachLine.AbsolutePosition.Y + coachLine.AbsoluteSize.Y)
	end
	local topPx = topEdge - origin.Y + Spacing.S
	local bottomPx = viewport.Y - OVERLAY.ScreenMargin
	local machineHud = playerGui:FindFirstChild("MachineHud")
	local machineStack = machineHud and machineHud:FindFirstChild("Stack", true)
	if machineHud and machineHud:IsA("ScreenGui") and machineHud.Enabled and machineStack and machineStack:IsA("GuiObject") then
		bottomPx = math.min(bottomPx, machineStack.AbsolutePosition.Y - origin.Y - Spacing.S)
	end
	local function screenY(entry, px) -- camera-space y of a screen row at the entry's depth
		return (viewport.Y / 2 - px) / entry.pxPerStud
	end
	local function gapOf(entry)
		return OVERLAY.StackGap.Studs * bodyScale * entry.share + OVERLAY.StackGap.Pixels / entry.pxPerStud
	end
	local function setY(entry, y)
		entry.target = Vector3.new(entry.target.X, y, entry.target.Z)
	end
	local function stackDown(list)
		for i = 2, #list do
			local above, entry = list[i - 1], list[i]
			local maxY = above.target.Y - (above.studSize.Y + entry.studSize.Y) / 2 - gapOf(entry)
			if entry.target.Y > maxY then setY(entry, maxY) end
		end
	end
	for _, list in pairs(perSide) do
		table.sort(list, function(a, b) return a.target.Y > b.target.Y end)
		stackDown(list)
		-- if the stack runs off the bottom (e.g. an expanded group), push labels up from the bottom only as needed
		local last = list[#list]
		if last then
			local minY = screenY(last, bottomPx) + last.studSize.Y / 2
			if last.target.Y < minY then setY(last, minY) end
			for i = #list - 1, 1, -1 do
				local entry, below = list[i], list[i + 1]
				local lowest = below.target.Y + (below.studSize.Y + entry.studSize.Y) / 2 + gapOf(below)
				if entry.target.Y < lowest then setY(entry, lowest) end
			end
		end
		-- never under the goal panel (wins over the bottom edge on very short screens)
		local first = list[1]
		if first then
			local maxY = screenY(first, topPx) - first.studSize.Y / 2
			if first.target.Y > maxY then
				setY(first, maxY)
				stackDown(list)
			end
		end
	end

	for _, entry in ipairs(active) do
		if entry.target then
			entry.smoothed = entry.smoothed and entry.smoothed:Lerp(entry.target, alpha) or entry.target
			local world = cf:PointToWorldSpace(entry.smoothed)
			entry.attachment.Position = world
			local studScale = bodyScale * entry.share
			entry.billboard.Size = UDim2.new(entry.size.Studs.X * studScale, entry.size.Pixels.X, entry.size.Studs.Y * studScale, entry.size.Pixels.Y)

			local labelScreen, onScreen = camera:WorldToScreenPoint(world)
			local dotScreen = camera:WorldToScreenPoint(entry.anchorWorld)
			local pixelSize = entry.studSize * entry.pxPerStud
			local labelCenter = Vector2.new(labelScreen.X, labelScreen.Y)
			setVisible(entry, onScreen and not overlaps(labelCenter, pixelSize / 2, rects))

			local dot = Vector2.new(dotScreen.X, dotScreen.Y) - origin
			entry.dotSmoothed = entry.dotSmoothed and entry.dotSmoothed:Lerp(dot, alpha) or dot
			-- the line leaves the box's body-side edge at its middle
			local rowY = entry.kind == "group" and (-0.5 + OVERLAY.BoxShare / 2) or 0
			local local2d = labelCenter - origin
			local edge = local2d + Vector2.new(-entry.side * pixelSize.X / 2, rowY * pixelSize.Y)
			local show = entry.visible and onScreen
			entry.line[1].Visible, entry.line[2].Visible, entry.dot.Visible = show, show, show
			if show then
				drawLine(entry.line, edge, entry.dotSmoothed, entry.side)
				entry.dot.Position = UDim2.fromOffset(entry.dotSmoothed.X, entry.dotSmoothed.Y)
			end
			if entry.tap then
				entry.tap.Visible = show
				entry.tap.Position = UDim2.fromOffset(local2d.X - pixelSize.X / 2, local2d.Y - pixelSize.Y / 2)
				entry.tap.Size = UDim2.fromOffset(pixelSize.X, pixelSize.Y)
			end
		end
	end
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------
local isOpen = false

local function open()
	if isOpen then return end
	isOpen = true
	refreshLabels()
	Audio.PlayUI("Whoosh")
	refreshGoal()
	statsButton:SetActive(true)
	statsButton:SetDot(false)
	anchorPart.Parent = Workspace.CurrentCamera
	gui.Enabled = true
	goal.Position = UDim2.new(0.5, 0, 0, GuiService.TopbarInset.Height + Spacing.S)
	for _, entry in ipairs(entries) do
		entry.smoothed, entry.dotSmoothed, entry.visible = nil, nil, true
		entry.billboard.Enabled = true
		Theme.Fade(entry.root, true, OVERLAY.FadeTime)
	end
	step(1)
	Theme.Fade(root, true, OVERLAY.FadeTime)
	RunService:BindToRenderStep("StatsLabels", Enum.RenderPriority.Camera.Value + 1, step)
	UIBus.StatsVisible:Fire(true)
end

local function close()
	if not isOpen then return end
	isOpen = false
	statsButton:SetActive(false)
	collapse()
	UIBus.StatsVisible:Fire(false)
	local tween = Theme.Fade(root, false, OVERLAY.FadeTime)
	for _, entry in ipairs(entries) do Theme.Fade(entry.root, false, OVERLAY.FadeTime) end
	local function finish()
		if isOpen then return end
		RunService:UnbindFromRenderStep("StatsLabels")
		gui.Enabled = false
		for _, entry in ipairs(entries) do
			entry.billboard.Enabled = false
			for _, sub in ipairs(entry.subs) do sub.billboard.Enabled = false end
		end
		anchorPart.Parent = nil
	end
	if tween then tween.Completed:Connect(finish) else finish() end
end

statsButton.Activated:Connect(function()
	if isOpen then close() else open() end
end)
-- the overlay and its goal panel hide while the genetics screen is up, and come back after
local reopenAfterGenetics = false
UIBus.GeneticsVisible.Event:Connect(function(visible)
	if visible then
		reopenAfterGenetics = isOpen
		if isOpen then close() end
	elseif reopenAfterGenetics then
		reopenAfterGenetics = false
		open()
	end
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "muscles" or key == "growthSpurts" then
		refreshGoal()
	end
	if isOpen and (key == "muscles" or key == "genetics" or key == "growthSpurts") then
		refreshLabels() -- live while lifting
	end
end)
task.spawn(refreshGoal)

spurtButton.Activated:Connect(function()
	Remotes.PlayerAction:FireServer("GrowthSpurt")
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
