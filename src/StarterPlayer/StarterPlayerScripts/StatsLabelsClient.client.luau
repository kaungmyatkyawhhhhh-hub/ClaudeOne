-- StatsLabelsClient: your stats around your character in the 3D world, switched on and off by the Stats button (hidden
-- by default; StatsClient fires UIBus.StatsLabels).
--  * Compact: a small box per stat (name on top, the number under it in light blue-white, with commas), a thin white line
--    to a small white dot on the body. Strength (total of all muscle levels) and Stamina sit above the head; the six
--    groups sit on both sides, three each: Chest, Core, Legs to the camera's left, Shoulders, Back, Arms to its right.
--    A maxed group shows "Max" in soft gold. The set stays close to the body (about 40% of the screen height) and keeps
--    the same size on screen at any camera distance.
--  * A 2D layer placed from the character's projected position, so it is always visible (never hidden behind walls or
--    machines) and doesn't jitter: positions come from the root part (not the animated limbs) and are smoothed. Columns
--    step off a shown ProximityPrompt ("E / Use"), the Growth Spurt bar and the machine panel.
--  * Steps aside (keeps its on/off state) while the menu, genetics, the Muscles panel or any other full panel is open,
--    and in first person.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local GrowthSpurts = require(Config.GrowthSpurts)
local Stamina = require(Config.Stamina)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local UIBus = require(Shared.UI.UIBus)
local MuscleRig = require(Shared.MuscleRig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing

local SIZES = {
	Normal = { Width = 92, Height = 40, Number = "Body", TopWidth = 118, TopHeight = 48, Top = "Large" },
	Compact = { Width = 82, Height = 36, Number = "Small", TopWidth = 100, TopHeight = 42, Top = "Body" },
}
local LAYOUT = {
	SideGap = 26,       -- px between the body's edge and a label column
	Gap = 6,            -- min px between labels in a column
	Margin = Spacing.M, -- px from the screen edges
	Dot = 6,
	Smooth = 14,
	DotSmooth = 24,
	TitleClear = 3.4,   -- studs above the head center where the top row starts (clears the overhead title)
	MaxSpan = 0.42,     -- the columns never span more than this share of the screen height
}

-- the six groups: which column, and where the dot sits (see anchorPoint)
local GROUPS = {
	{ id = "Chest", side = "Left", anchor = "Chest" },
	{ id = "Core", side = "Left", anchor = "Core" },
	{ id = "Legs", side = "Left", anchor = "Thigh" },
	{ id = "Shoulders", side = "Right", anchor = "Shoulder" },
	{ id = "Back", side = "Right", anchor = "Back" },
	{ id = "Arms", side = "Right", anchor = "Biceps" },
}

-- 1966552 -> "1,966,552"
local function commas(value)
	local text = tostring(math.floor(value))
	local formatted, count = text, 1
	while count > 0 do
		formatted, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	end
	return formatted
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "StatsLabels", DisplayOrder = 1, Enabled = false, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.None -- positions are viewport pixels (Camera:WorldToViewportPoint)
local layer = New("Frame", { Name = "Layer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local lineLayer = New("Frame", { Name = "Lines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = layer })

-- smaller on phones and on short screens
local SMALL_SCREEN = 700
local function wantSmall()
	local camera = Workspace.CurrentCamera
	return Theme.IsCompact() or (camera ~= nil and camera.ViewportSize.Y > 1 and camera.ViewportSize.Y < SMALL_SCREEN)
end
local size = wantSmall() and SIZES.Compact or SIZES.Normal

local function box(name, width, height, numberSize)
	-- no box: just the text (name in white, the number under it in pale blue-white) on an almost invisible black rectangle
	-- that is only as big as the text (square corners, no border)
	local frame = New("Frame", {
		Name = name,
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = layer,
	})
	local content = New("Frame", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = frame }, { Theme.List(Enum.FillDirection.Vertical, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	-- (a holder without a list layout, so the backing and the click area never push the text around)
	local holder = New("Frame", { Name = "Holder", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = frame })
	holder.LayoutOrder = -1
	local back = New("Frame", { Name = "Back", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 3, Parent = holder }, { New("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	local title = Theme.Text({ Name = "Name", LayoutOrder = 1, Text = name, Font = "Regular", TextSize = "Small", Size = UDim2.new(1, 0, 0, 15), ZIndex = 4, Parent = content })
	local number = Theme.Text({ Name = "Number", LayoutOrder = 2, Text = "0", Font = "Regular", TextSize = numberSize, TextColor3 = Colors.StatNumber, Size = UDim2.new(1, 0, 0, Theme.TextSize[numberSize] + 2), ZIndex = 4, Parent = content })
	Theme.TextShadow(title)
	Theme.TextShadow(number)
	return { frame = frame, title = title, number = number, back = back, holder = holder }
end

local labels = {} -- the six group labels, in GROUPS order
for _, spec in ipairs(GROUPS) do
	local entry = box(spec.id, size.Width, size.Height, size.Number)
	entry.spec = spec
	entry.dot = New("Frame", { Name = spec.id .. "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(LAYOUT.Dot, LAYOUT.Dot), BackgroundColor3 = Colors.Text, ZIndex = 2, Parent = layer }, { Theme.Round("Round") })
	entry.line = New("Frame", { Name = spec.id .. "Line", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1, Parent = lineLayer })
	entry.tail = New("Frame", { Name = spec.id .. "Tail", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1, Parent = lineLayer })
	table.insert(labels, entry)
end
local strength = box("Strength", size.TopWidth, size.TopHeight, size.Top)
local stamina = box("Stamina", size.Width, size.TopHeight, size.Number)
for _, top in ipairs({ strength, stamina }) do
	top.tail = New("Frame", { Name = top.frame.Name .. "Tail", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1, Parent = lineLayer })
end

-- the backing hugs the text
local function fitBacking(entry)
	local w = (math.max(entry.title.TextBounds.X, entry.number.TextBounds.X) + 12) * 1.5
	local h = entry.title.AbsoluteSize.Y + entry.number.AbsoluteSize.Y + 2
	entry.back.Size = UDim2.fromOffset(w, h)
	entry.backWidth = w
end
local function fitAll()
	for _, entry in ipairs(labels) do fitBacking(entry) end
	-- every group label is the same length (the longest one)
	local widest = 0
	for _, entry in ipairs(labels) do widest = math.max(widest, entry.backWidth or 0) end
	for _, entry in ipairs(labels) do
		entry.backWidth = widest
		entry.back.Size = UDim2.fromOffset(widest, entry.back.Size.Y.Offset)
		for _, sub in ipairs(entry.subs or {}) do sub.back.Size = UDim2.fromOffset(widest, sub.back.Size.Y.Offset) end
	end
	fitBacking(strength)
	fitBacking(stamina)
end

local function applySize(small)
	size = small and SIZES.Compact or SIZES.Normal
	for _, entry in ipairs(labels) do
		entry.frame.Size = UDim2.fromOffset(size.Width, size.Height)
		entry.number.TextSize = Theme.TextSize[size.Number]
		entry.number.Size = UDim2.new(1, 0, 0, Theme.TextSize[size.Number] + 2)
	end
	strength.frame.Size = UDim2.fromOffset(size.TopWidth, size.TopHeight)
	stamina.frame.Size = UDim2.fromOffset(size.Width, size.TopHeight)
	stamina.number.TextSize = Theme.TextSize[size.Number]
	strength.number.TextSize = Theme.TextSize[size.Top]
	strength.number.Size = UDim2.new(1, 0, 0, Theme.TextSize[size.Top] + 2)
	task.defer(fitAll)
end
applySize(wantSmall())

------------------------------------------------------------------------
-- Numbers
------------------------------------------------------------------------
local function refreshNumbers()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	for _, entry in ipairs(labels) do
		local group = Muscles.GroupById[entry.spec.id]
		local maxed = GrowthSpurts.GoalLevel(data.muscles, group, trainable) >= cap
		entry.number.Text = maxed and "Max" or commas(Muscles.GroupExp(data.muscles, group.id))
		entry.number.TextColor3 = maxed and Colors.Gold or Colors.StatNumber
	end
	strength.number.Text = commas(Muscles.TotalExp(data.muscles))
	local max = player:GetAttribute("MaxStamina")
	stamina.number.Text = commas(math.clamp(data.stamina or 0, 0, type(max) == "number" and max or Stamina.Max))
	task.defer(fitAll)
end


------------------------------------------------------------------------
-- Click to expand (one group open at a time) and hover highlights on the real character
------------------------------------------------------------------------
local SUB_HEIGHT = 18
local openGroup = nil -- the expanded group id
local hoverKey = nil

-- the hovered group / muscle is painted neon red on your character (the muscle meshes' own face colors, so a single muscle
-- lights up on its own); target = a set { [muscleId] = true } or nil to clear
local function setHighlight(target, on)
	local character = player.Character
	if character then MuscleRig.SetHighlight(character, on and target or nil) end
end

local function hover(key, ids)
	if ids then
		hoverKey = key
		local set = {}
		for _, id in ipairs(ids) do set[id] = true end
		setHighlight(set, true)
	elseif hoverKey == key then
		hoverKey = nil
		setHighlight(nil, false)
	end
end

for _, entry in ipairs(labels) do
	local group = Muscles.GroupById[entry.spec.id]
	local groupIds = {}
	for _, muscle in ipairs(group.muscles) do table.insert(groupIds, muscle.id) end
	entry.extra = 0
	entry.subs = {}
	local hit = New("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 6, Parent = entry.holder })
	hit.MouseEnter:Connect(function() hover(group.id, groupIds) end)
	hit.MouseLeave:Connect(function() hover(group.id, nil) end)
	hit.Activated:Connect(function()
		if openGroup == group.id then
			openGroup = nil
			hover(group.id, nil)
		else
			openGroup = group.id
			hover(group.id, groupIds) -- (phones: a tap highlights and expands)
		end
	end)
	for _, muscle in ipairs(group.muscles) do
		local sub = New("TextButton", { Name = muscle.id, Size = UDim2.fromOffset(size.Width, SUB_HEIGHT), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 5, Parent = layer })
		local back = New("Frame", { Name = "Back", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.Width, SUB_HEIGHT - 2), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 5, Parent = sub }, { New("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		local text = Theme.Text({ Name = "Text", Text = muscle.name, Font = "Regular", TextSize = "Small", Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = sub })
		Theme.TextShadow(text)
		sub.MouseEnter:Connect(function() hover(muscle.id, { muscle.id }) end)
		sub.MouseLeave:Connect(function() hover(muscle.id, nil) end)
		sub.Activated:Connect(function() hover(muscle.id, { muscle.id }) end)
		table.insert(entry.subs, { frame = sub, back = back, text = text, muscle = muscle })
	end
end

local function refreshSubs()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	local cap = GrowthSpurts.GetLevelCap(data.growthSpurts)
	for _, entry in ipairs(labels) do
		for _, sub in ipairs(entry.subs) do
			local entry = data.muscles[sub.muscle.id]
			local maxed = entry.level >= cap
			sub.text.Text = sub.muscle.name .. "  " .. (maxed and "Max" or commas(Muscles.MuscleExp(entry)))
			sub.text.TextColor3 = maxed and Colors.Gold or Colors.Text
			sub.back.Size = UDim2.fromOffset((sub.text.TextBounds.X + 12) * 1.5, SUB_HEIGHT - 2)
		end
	end
end

------------------------------------------------------------------------
-- Placement
------------------------------------------------------------------------
local camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() camera = Workspace.CurrentCamera end)

local function project(point)
	local screen, onScreen = camera:WorldToViewportPoint(point)
	return Vector2.new(screen.X, screen.Y), screen.Z, onScreen
end

-- +1 if the part's +X side shows on the right of the screen, else -1
local function rightSign(part)
	local a = project(part.CFrame * Vector3.new(1, 0, 0))
	local b = project(part.CFrame * Vector3.new(-1, 0, 0))
	return a.X >= b.X and 1 or -1
end

-- the arm/leg part that shows further right (or left) on screen
local function pick(character, leftName, rightName, wantRight)
	local a, b = character:FindFirstChild(leftName), character:FindFirstChild(rightName)
	if not a then return b end
	if not b then return a end
	local ax, bx = project(a.Position).X, project(b.Position).X
	if wantRight then return ax > bx and a or b end
	return ax < bx and a or b
end

local function anchorPoint(character, name)
	local torso = character:FindFirstChild("UpperTorso")
	local waist = character:FindFirstChild("LowerTorso")
	if name == "Chest" or name == "Back" then
		if not torso then return nil end
		local s, toRight = torso.Size, rightSign(torso)
		-- the chest dot a little to the screen-left of center (its label is left), the back dot to the right
		local x = (name == "Chest" and -0.22 or 0.3) * s.X * toRight
		return torso.CFrame * Vector3.new(x, s.Y * (name == "Chest" and 0.18 or 0.12), (name == "Chest" and -0.5 or 0.5) * s.Z)
	elseif name == "Core" then
		if not waist then return nil end
		return waist.CFrame * Vector3.new(-0.2 * waist.Size.X * rightSign(waist), 0, -0.5 * waist.Size.Z)
	elseif name == "Shoulder" or name == "Biceps" then
		local arm = pick(character, "LeftUpperArm", "RightUpperArm", true)
		if not arm then return nil end
		local s = arm.Size
		if name == "Shoulder" then return arm.CFrame * Vector3.new(0, s.Y * 0.42, 0) end
		return arm.CFrame * Vector3.new(0, -s.Y * 0.3, -s.Z * 0.5)
	elseif name == "Thigh" then
		local leg = pick(character, "LeftUpperLeg", "RightUpperLeg", false)
		return leg and leg.Position or nil
	end
	return nil
end

-- Screen rects the labels step off: shown ProximityPrompts ("E / Use"), the Growth Spurt bar, the coach line and the
-- machine panel.
local shownPrompts = {}
ProximityPromptService.PromptShown:Connect(function(prompt)
	shownPrompts[prompt] = true
	prompt.PromptHidden:Once(function() shownPrompts[prompt] = nil end)
end)
local function promptWorldPosition(prompt)
	local parent = prompt.Parent
	if not parent then return nil end
	if parent:IsA("Attachment") then return parent.WorldPosition end
	if parent:IsA("BasePart") then return parent.Position end
	if parent:IsA("Model") then return parent:GetPivot().Position end
	return nil
end
local function obstacles()
	local rects = {}
	for prompt in pairs(shownPrompts) do
		local world = promptWorldPosition(prompt)
		if world then
			local at, depth = project(world)
			if depth > 0 then table.insert(rects, { at.X - 90, at.Y - 44, at.X + 90, at.Y + 44 }) end
		end
	end
	local function addGui(name, path)
		local screen = playerGui:FindFirstChild(name)
		if not screen or not screen:IsA("ScreenGui") or not screen.Enabled then return end
		local inset = screen.ScreenInsets == Enum.ScreenInsets.None and Vector2.zero or GuiService:GetGuiInset()
		local items = path and { screen:FindFirstChild(path, true) } or screen:GetChildren()
		for _, item in ipairs(items) do
			if item:IsA("GuiObject") and item.Visible then
				local p = item.AbsolutePosition + inset
				table.insert(rects, { p.X, p.Y - Spacing.S, p.X + item.AbsoluteSize.X, p.Y + item.AbsoluteSize.Y + Spacing.S })
			end
		end
	end
	addGui("SpurtBar")
	addGui("Tutorial", "CoachLine")
	addGui("MachineHud", "Stack")
	return rects
end

-- How far to move a block (x1..x2, y1..y2) up or down to clear every rect it overlaps, staying between minY and maxY
-- if it can (the smaller move wins).
local function clearOf(x1, y1, x2, y2, rects, minY, maxY)
	local shift = 0
	for _ = 1, 4 do
		local moved = false
		for _, r in ipairs(rects) do
			if x1 < r[3] and x2 > r[1] and y1 + shift < r[4] and y2 + shift > r[2] then
				local up = r[2] - (y2 + shift)
				local down = r[4] - (y1 + shift)
				local upFits = y1 + shift + up >= minY
				local downFits = y2 + shift + down <= maxY
				if upFits and (not downFits or -up <= down) then
					shift += up
				elseif downFits then
					shift += down
				else
					local low = minY - y1
					shift = math.clamp(shift + ((-up <= down) and up or down), low, math.max(low, maxY - y2))
					break
				end
				moved = true
			end
		end
		if not moved then break end
	end
	return shift
end

local current = {} -- [frame or dot] = Vector2 smoothed position

-- Labels follow their rest spot on a soft spring (they drift when you walk, turn or jump, up to ~50px, then settle back)
-- plus a tiny idle float of their own.
-- which way each dot's body side faces (+1 = the chest side, -1 = the back side); side dots (shoulder, arm, leg) always show
local FACING = { Chest = 1, Core = 1, Back = -1 }

local SPRING = { Stiffness = 55, Damping = 9.5, MaxDrift = 50, Float = 3 }
local springs = {}
local function spring(key, target, dt, seed)
	local s = springs[key]
	if not s or (s.p - target).Magnitude > 700 then
		s = { p = target, v = Vector2.zero }
		springs[key] = s
	end
	dt = math.min(dt, 1 / 30)
	local accel = (target - s.p) * SPRING.Stiffness - s.v * SPRING.Damping
	s.v += accel * dt
	s.p += s.v * dt
	local off = s.p - target
	if off.Magnitude > SPRING.MaxDrift then s.p = target + off.Unit * SPRING.MaxDrift end
	local t = os.clock()
	return s.p + Vector2.new(0, math.sin(t * (0.9 + (seed % 5) * 0.17) + seed * 1.7) * SPRING.Float)
end
local function smooth(key, target, rate, dt)
	local last = current[key]
	if not last or (last - target).Magnitude > 600 then
		current[key] = target
	else
		current[key] = last:Lerp(target, 1 - math.exp(-rate * dt))
	end
	return current[key]
end

local function setLine(line, a, b)
	local delta = b - a
	line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	line.Size = UDim2.fromOffset(delta.Magnitude, 1)
	line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local body = { top = 2.6, bottom = 3, half = 1.6, headUp = 2.2 } -- studs from the root part, refreshed every second
local function measure(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso")
	local arm = character:FindFirstChild("RightUpperArm")
	if not root or not head or not humanoid then return end
	body.top = head.Position.Y + head.Size.Y / 2 - root.Position.Y
	body.bottom = humanoid.HipHeight + root.Size.Y / 2
	body.half = (torso and torso.Size.X / 2 or 1) + (arm and arm.Size.X or 0.6)
	body.headUp = head.Position.Y - root.Position.Y
end

local function place(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not head then
		layer.Visible = false
		return
	end
	local center, depth = project(root.Position)
	-- behind the camera, or first person: nothing to label
	if depth <= 0 or (camera.CFrame.Position - head.Position).Magnitude < 2 then
		layer.Visible = false
		return
	end
	layer.Visible = true
	local small = wantSmall()
	if (size == SIZES.Compact) ~= small then applySize(small) end
	local view = camera.ViewportSize
	local up = Vector3.yAxis
	local top = project(root.Position + up * body.top)
	local bottom = project(root.Position - up * body.bottom)
	local height = math.max(bottom.Y - top.Y, 1)
	local halfWidth = math.abs(project(root.Position + camera.CFrame.RightVector * body.half).X - center.X)
	local gap = LAYOUT.SideGap
	local rects = obstacles()
	local topLimit = GuiService:GetGuiInset().Y + LAYOUT.Margin
	local bottomLimit = view.Y - LAYOUT.Margin

	-- the two columns: three labels each, spread over the body (never more than MaxSpan of the screen)
	local span = math.min(height * 0.9, view.Y * LAYOUT.MaxSpan)
	local step = math.max(size.Height + LAYOUT.Gap, (span - size.Height) / 2)
	local total = step * 2 + size.Height
	local columnTop = math.clamp(center.Y - total / 2, topLimit + size.TopHeight + LAYOUT.Gap, math.max(topLimit, bottomLimit - total))
	for _, side in ipairs({ "Left", "Right" }) do
		local column = {}
		for _, entry in ipairs(labels) do
			if entry.spec.side == side then table.insert(column, entry) end
		end
		local x = side == "Left" and center.X - halfWidth - gap - size.Width or center.X + halfWidth + gap
		x = math.clamp(x, LAYOUT.Margin, view.X - LAYOUT.Margin - size.Width)
		local y = columnTop + clearOf(x, columnTop, x + size.Width, columnTop + total, rects, topLimit, bottomLimit)
		local cursor = y
		for index, entry in ipairs(column) do
			-- an open group pushes the labels under it down (they glide out of the way)
			local wantExtra = (openGroup == entry.spec.id) and #entry.subs * SUB_HEIGHT or 0
			entry.extra += (wantExtra - entry.extra) * (1 - math.exp(-14 * dt))
			if math.abs(wantExtra - entry.extra) < 0.3 then entry.extra = wantExtra end
			local target = Vector2.new(x, cursor)
			cursor += step + entry.extra
			local at = spring(entry.frame, target, dt, index + (side == "Left" and 0 or 3))
			entry.frame.Position = UDim2.fromOffset(math.floor(at.X + 0.5), math.floor(at.Y + 0.5))
			for subIndex, sub in ipairs(entry.subs) do
				local show = entry.extra > subIndex * SUB_HEIGHT * 0.5
				sub.frame.Visible = show
				if show then
					sub.frame.Position = UDim2.fromOffset(math.floor(at.X + 0.5), math.floor(at.Y + size.Height + 4 + (subIndex - 1) * SUB_HEIGHT + 0.5))
					sub.frame.Size = UDim2.fromOffset(size.Width, SUB_HEIGHT)
				end
			end
			local world = anchorPoint(character, entry.spec.anchor)
			-- dots on the front (Chest, Core) or the back (Back) only show when that side faces the camera (your body blocks them otherwise)
			if world then
				local facing = FACING[entry.spec.anchor]
				local torsoPart = character:FindFirstChild("UpperTorso")
				if facing and torsoPart then
					local normal = torsoPart.CFrame.LookVector * facing
					if (camera.CFrame.Position - world):Dot(normal) <= 0 then world = nil end
				end
			end
			if world then
				local dot = smooth(entry.dot, (project(world)), LAYOUT.DotSmooth, dt)
				entry.dot.Visible = true
				entry.line.Visible = true
				entry.dot.Position = UDim2.fromOffset(dot.X, dot.Y)
				-- the line meets a short horizontal segment under the label (like the reference)
				local textW = entry.backWidth or size.Width
				local x0 = at.X + (size.Width - textW) / 2
				local x1 = x0 + textW
				local baseY = at.Y + size.Height + 1
				local near = side == "Left" and x1 or x0
				entry.tail.Visible = true
				entry.tail.Position = UDim2.fromOffset((x0 + x1) / 2, baseY)
				entry.tail.Size = UDim2.fromOffset(textW, 1)
				setLine(entry.line, dot, Vector2.new(near, baseY))
			else
				entry.dot.Visible = false
				entry.line.Visible = false
				entry.tail.Visible = false
			end
		end
	end

	-- Strength (the total) and Stamina side by side above the head, over the title
	local rowWidth = size.TopWidth + LAYOUT.Gap + size.Width
	local rowX = math.clamp(center.X - rowWidth / 2, LAYOUT.Margin, view.X - LAYOUT.Margin - rowWidth)
	local rowY = project(root.Position + up * (body.headUp + LAYOUT.TitleClear)).Y - size.TopHeight
	rowY = math.max(rowY, topLimit)
	rowY += clearOf(rowX, rowY, rowX + rowWidth, rowY + size.TopHeight, rects, topLimit, bottomLimit)
	local at = spring(strength.frame, Vector2.new(rowX, rowY), dt, 7)
	strength.frame.Position = UDim2.fromOffset(math.floor(at.X + 0.5), math.floor(at.Y + 0.5))
	stamina.frame.Position = UDim2.fromOffset(math.floor(at.X + size.TopWidth + LAYOUT.Gap + 0.5), math.floor(at.Y + 0.5))
	for _, top in ipairs({ strength, stamina }) do
		local w = top.backWidth or size.Width
		local cx = top.frame.AbsolutePosition.X - layer.AbsolutePosition.X + size.Width / 2
		if top == strength then cx = at.X + size.TopWidth / 2 else cx = at.X + size.TopWidth + LAYOUT.Gap + size.Width / 2 end
		top.tail.Position = UDim2.fromOffset(math.floor(cx + 0.5), math.floor(at.Y + size.TopHeight + 1))
		top.tail.Size = UDim2.fromOffset(w, 1)
	end
end

------------------------------------------------------------------------
-- Show / hide
------------------------------------------------------------------------
local wanted = false -- the Stats button is on
local hidden = { menu = true, genetics = false, muscles = false, cover = false, tight = false }
local shown = false
local renderConnection = nil

local function update()
	local want = wanted and not hidden.menu and not hidden.genetics and not hidden.muscles and not hidden.cover and not hidden.tight
	if want == shown then return end
	shown = want
	if want then
		refreshNumbers()
		refreshSubs()
		if player.Character then measure(player.Character) end
		table.clear(current)
		gui.Enabled = true
		if not renderConnection then renderConnection = RunService.RenderStepped:Connect(place) end
		place(0)
		Theme.Fade(layer, true, 0.2)
	else
		openGroup = nil -- stats closing: collapse and clear any highlight
		hoverKey = nil
		setHighlight(nil, false)
		local tween = Theme.Fade(layer, false, 0.2)
		local function stop()
			if shown then return end
			gui.Enabled = false
			if renderConnection then
				renderConnection:Disconnect()
				renderConnection = nil
			end
		end
		if tween then tween.Completed:Connect(stop) else stop() end
	end
end

UIBus.StatsLabels.Event:Connect(function(visible) wanted = visible; update() end)
UIBus.GeneticsVisible.Event:Connect(function(visible) hidden.genetics = visible; update() end)
UIBus.MusclesVisible.Event:Connect(function(visible) hidden.muscles = visible; update() end)

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Head", 10)
	task.wait(0.5)
	if player.Character == character then measure(character) end
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if (key == "muscles" or key == "stamina" or key == "growthSpurts") and shown then refreshNumbers() refreshSubs() end
end)
player:GetAttributeChangedSignal("MaxStamina"):Connect(function() if shown then refreshNumbers() end end)

task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	hidden.menu = false
	update()
	-- the body's size changes with Growth Spurts and muscle growth, and other full panels open and close: check now and then
	local clock = 0
	while true do
		task.wait(0.25)
		clock += 0.25
		local cover = UIBus.CoverOpen(playerGui)
		-- on a short screen the machine panel leaves no room for the labels: the body map widget shows the stats then
		local tight = UIBus.Training and camera ~= nil and camera.ViewportSize.Y < UIBus.ShortScreen
		if cover ~= hidden.cover or tight ~= hidden.tight then
			hidden.cover, hidden.tight = cover, tight
			update()
		end
		if clock >= 1 then
			clock = 0
			if shown and player.Character then measure(player.Character) end
		end
	end
end)
