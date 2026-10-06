-- StatsLabelsClient: your stats around your character, and the Strength line over other players.
--  * Your labels: a small dark see-through box per stat (name on top, number under it in light blue-white), spread wide
--    on both sides of your character so they never overlap each other or the body: Chest, Core, Calves on the left;
--    Shoulders, Back, Triceps, Biceps, Legs on the right; Strength (big) and Stamina above your head (over your title;
--    when the Growth Spurt bar or the screen top leaves no room there, they head the left and right columns).
--    A thin white line runs from each label to a small white dot on its body part.
--  * Drawn on a 2D layer from the character's projected position, so they are always visible (never hidden by walls or
--    machines) and stay the same size on screen. Columns are placed from the root part (not the animated limbs) and
--    every position is smoothed, so they don't jitter while walking. A column steps up or down off a shown
--    ProximityPrompt or the Growth Spurt bar instead of covering it.
--  * Settings > Stats labels: Always / Training (only while on a machine) / Off; until picked, phones use Training and
--    everything else Always. Only updates while shown.
--  * Other players: a small "Strength 1,234" line over their head (player attribute Strength, set by BodyService),
--    next to their title.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Muscles = require(Config.Muscles)
local Stamina = require(Config.Stamina)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local UIBus = require(Shared.UI.UIBus)
local SideMenu = require(Shared.UI.SideMenu)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing

local SIZES = {
	Normal = { Width = 104, Height = 46, Number = "Large", TopWidth = 150, TopHeight = 64, Top = "Huge" },
	Compact = { Width = 88, Height = 40, Number = "Body", TopWidth = 112, TopHeight = 46, Top = "Large" },
}
local LAYOUT = {
	Gap = Spacing.S,          -- min px between labels in a column
	Spread = 0.55,            -- extra distance from the body, as a share of the character's screen height
	MinSpread = 64,           -- px, at least this far from the body
	Margin = Spacing.M,       -- px from the screen edges
	Dot = 6,                  -- px
	Smooth = 14,              -- label follow speed (higher = snappier)
	DotSmooth = 24,
	TitleClear = 3.4,         -- studs above the head center where the Strength row starts (clears the title)
}

-- What each label shows and where its dot sits. side: which column; anchor: body point (see anchorPoint).
local LABELS = {
	{ id = "Chest", name = "Chest", group = "Chest", side = "Left", anchor = "Chest" },
	{ id = "Core", name = "Core", group = "Core", side = "Left", anchor = "Core" },
	{ id = "Calves", name = "Calves", muscle = "Calves", side = "Left", anchor = "Calf" },
	{ id = "Shoulders", name = "Shoulders", group = "Shoulders", side = "Right", anchor = "Shoulder" },
	{ id = "Back", name = "Back", group = "Back", side = "Right", anchor = "Back" },
	{ id = "Triceps", name = "Triceps", muscle = "Triceps", side = "Right", anchor = "Triceps" },
	{ id = "Biceps", name = "Biceps", muscle = "Biceps", side = "Right", anchor = "Biceps" },
	{ id = "Legs", name = "Legs", group = "Legs", side = "Right", anchor = "Thigh" },
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

-- small labels on phones and on any screen under SMALL_SCREEN px tall (so both columns fit beside the machine panel)
local SMALL_SCREEN = 700
local function wantSmall()
	local camera = Workspace.CurrentCamera
	return Theme.IsCompact() or (camera ~= nil and camera.ViewportSize.Y > 1 and camera.ViewportSize.Y < SMALL_SCREEN)
end
local compact = wantSmall()
local size = compact and SIZES.Compact or SIZES.Normal

local function box(name, width, height, numberSize)
	local frame = New("Frame", {
		Name = name,
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Theme.Alpha.LabelBacking,
		ZIndex = 3,
		Parent = layer,
	}, { Theme.Round("Button"), Theme.Stroke(), Theme.List(Enum.FillDirection.Vertical, nil, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local title = Theme.Text({ Name = "Name", LayoutOrder = 1, Text = name, Font = "Regular", TextSize = "Small", Size = UDim2.new(1, 0, 0, 16), ZIndex = 4, Parent = frame })
	local number = Theme.Text({ Name = "Number", LayoutOrder = 2, Text = "0", Font = "SemiBold", TextSize = numberSize, TextColor3 = Colors.StatNumber, Size = UDim2.new(1, 0, 0, Theme.TextSize[numberSize] + 2), ZIndex = 4, Parent = frame })
	Theme.TextShadow(title)
	Theme.TextShadow(number)
	return { frame = frame, title = title, number = number }
end

local labels = {}
for _, spec in ipairs(LABELS) do
	local entry = box(spec.name, size.Width, size.Height, size.Number)
	entry.spec = spec
	entry.dot = New("Frame", { Name = spec.id .. "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(LAYOUT.Dot, LAYOUT.Dot), BackgroundColor3 = Colors.Text, ZIndex = 2, Parent = layer }, { Theme.Round("Round") })
	entry.line = New("Frame", { Name = spec.id .. "Line", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.25, ZIndex = 1, Parent = lineLayer })
	table.insert(labels, entry)
end
local strength = box("Strength", size.TopWidth, size.TopHeight, size.Top)
local stamina = box("Stamina", size.Width, size.TopHeight, size.Number)

local function applySize(isCompact)
	compact = isCompact
	size = isCompact and SIZES.Compact or SIZES.Normal
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
end
Theme.OnCompactChanged(function() applySize(wantSmall()) end)

------------------------------------------------------------------------
-- Numbers
------------------------------------------------------------------------
local function refreshNumbers()
	local data = ClientData.Get()
	if not data or not data.muscles then return end
	for _, entry in ipairs(labels) do
		local spec = entry.spec
		local value = spec.group and Muscles.GetGroupLevel(data.muscles, spec.group) or data.muscles[spec.muscle].level
		entry.number.Text = commas(value)
	end
	strength.number.Text = commas(Muscles.TotalStrength(data.muscles))
	local max = player:GetAttribute("MaxStamina")
	local current = math.clamp(data.stamina or 0, 0, type(max) == "number" and max or Stamina.Max)
	stamina.number.Text = commas(current)
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
		-- chest a little to the left of center (its label is left), back a little to the right
		local x = (name == "Chest" and -0.22 or 0.3) * s.X * toRight
		return torso.CFrame * Vector3.new(x, s.Y * (name == "Chest" and 0.18 or 0.02), (name == "Chest" and -0.5 or 0.5) * s.Z)
	elseif name == "Core" then
		if not waist then return nil end
		return waist.CFrame * Vector3.new(-0.2 * waist.Size.X * rightSign(waist), 0, -0.5 * waist.Size.Z)
	elseif name == "Shoulder" or name == "Triceps" or name == "Biceps" then
		local arm = pick(character, "LeftUpperArm", "RightUpperArm", true)
		if not arm then return nil end
		local s = arm.Size
		if name == "Shoulder" then return arm.CFrame * Vector3.new(0, s.Y * 0.42, 0) end
		if name == "Triceps" then return arm.CFrame * Vector3.new(0, -s.Y * 0.05, s.Z * 0.5) end
		return arm.CFrame * Vector3.new(0, -s.Y * 0.35, -s.Z * 0.5)
	elseif name == "Thigh" then
		local leg = pick(character, "LeftUpperLeg", "RightUpperLeg", true)
		return leg and leg.Position or nil
	elseif name == "Calf" then
		local leg = pick(character, "LeftLowerLeg", "RightLowerLeg", false)
		return leg and leg.CFrame * Vector3.new(0, leg.Size.Y * 0.1, leg.Size.Z * 0.5) or nil
	end
	return nil
end

-- Screen rects the labels step off: shown ProximityPrompts and the Growth Spurt bar.
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
	-- the Growth Spurt bar (top center) and, while lifting, the machine panel with its pump bar (bottom)
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
	local prompts = #rects
	addGui("SpurtBar")
	addGui("Tutorial", "CoachLine")
	local topBar = { table.unpack(rects, prompts + 1) } -- only the bar decides where a column may start
	local before = #rects
	addGui("MachineHud", "Stack")
	local panel = #rects > before and rects[#rects] or nil -- columns beside it may use the full height, others fit above it
	return rects, panel, topBar
end

-- How far to move a block (x1..x2, y1..y2) up or down to clear every rect it overlaps, staying between minY and maxY
-- if it can (the smaller move wins).
local function clearOf(x1, y1, x2, y2, rects, minY, maxY)
	local shift = 0
	for _ = 1, 4 do
		local moved = false
		for _, r in ipairs(rects) do
			if x1 < r[3] and x2 > r[1] and y1 + shift < r[4] and y2 + shift > r[2] then
				local up = r[2] - (y2 + shift)    -- negative
				local down = r[4] - (y1 + shift)  -- positive
				local upFits = y1 + shift + up >= minY
				local downFits = y2 + shift + down <= maxY
				if upFits and (not downFits or -up <= down) then
					shift += up
				elseif downFits then
					shift += down
				else
					-- no room either way: stay on screen (a small overlap beats a label off the edge)
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

local body = { top = 2.6, bottom = 3, half = 1.6 } -- studs from the root part, refreshed every second
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
	local view = camera.ViewportSize
	if wantSmall() ~= compact then applySize(not compact) end
	local up = Vector3.yAxis
	local top = project(root.Position + up * body.top)
	local bottom = project(root.Position - up * body.bottom)
	local height = math.max(bottom.Y - top.Y, 1)
	local halfWidth = math.abs(project(root.Position + camera.CFrame.RightVector * body.half).X - center.X)
	local spread = halfWidth + math.max(LAYOUT.MinSpread, height * LAYOUT.Spread)
	local rects, panel, topBar = obstacles()
	local screenBottom = view.Y - LAYOUT.Margin
	local leftLimit = (SideMenu.IsCompact() and 0 or SideMenu.Right()) + LAYOUT.Gap -- PC: the menu column on the left
	local topLimit = GuiService:GetGuiInset().Y + LAYOUT.Margin

	-- Strength (big) and Stamina above the head, over the title. When there's no room up there (the Growth Spurt bar
	-- or the top of the screen is in the way), they head the two columns instead: Strength left, Stamina right.
	local gap = Spacing.S
	local rowWidth = size.TopWidth + gap + size.Width
	local rowX = math.clamp(center.X - rowWidth / 2, LAYOUT.Margin, view.X - LAYOUT.Margin - rowWidth)
	local rowY = project(root.Position + up * (body.headUp or body.top) + up * LAYOUT.TitleClear).Y - size.TopHeight
	local rowShift = clearOf(rowX, rowY, rowX + rowWidth, rowY + size.TopHeight, rects, topLimit, view.Y - LAYOUT.Margin)
	local overHead = rowShift <= 0 and rowY + rowShift >= topLimit
	if overHead then
		local at = smooth(strength.frame, Vector2.new(rowX, rowY + rowShift), LAYOUT.Smooth, dt)
		strength.frame.Position = UDim2.fromOffset(math.floor(at.X + 0.5), math.floor(at.Y + 0.5))
		local staminaAt = smooth(stamina.frame, Vector2.new(rowX + size.TopWidth + gap, rowY + rowShift), LAYOUT.Smooth, dt)
		stamina.frame.Position = UDim2.fromOffset(math.floor(staminaAt.X + 0.5), math.floor(staminaAt.Y + 0.5))
	end

	-- the two columns
	for _, side in ipairs({ "Left", "Right" }) do
		local column = {}
		for _, entry in ipairs(labels) do
			if entry.spec.side == side then table.insert(column, entry) end
		end
		local cap = not overHead and (side == "Left" and strength or stamina) or nil -- Strength / Stamina on top
		local headWidth = side == "Left" and size.TopWidth or size.Width
		local headSpace = cap and size.TopHeight + LAYOUT.Gap or 0
		local count = #column
		local x = side == "Left" and center.X - spread - size.Width or center.X + spread
		x = math.clamp(x, side == "Left" and leftLimit + (cap and headWidth or size.Width) - size.Width or LAYOUT.Margin, view.X - LAYOUT.Margin - size.Width)
		-- lifting: step out beside the machine panel when there is room (right of it; left of it, clear of the menu)
		if panel then
			if side == "Right" and x < panel[3] and panel[3] + LAYOUT.Gap + size.Width <= view.X - LAYOUT.Margin then
				x = panel[3] + LAYOUT.Gap
			elseif side == "Left" and x + size.Width > panel[1] and panel[1] - LAYOUT.Gap - (cap and headWidth or size.Width) >= leftLimit then
				x = panel[1] - LAYOUT.Gap - size.Width
			end
		end
		local besidePanel = not panel or x >= panel[3] or x + size.Width <= panel[1]
		local bottomLimit = besidePanel and screenBottom or math.min(screenBottom, panel[2])
		-- under the Growth Spurt bar (or anything else up top) the column starts below it
		local columnTop = topLimit
		for _, r in ipairs(topBar) do
			if x < r[3] and x + size.Width > r[1] then columnTop = math.max(columnTop, r[4]) end
		end
		local step = math.max(size.Height + LAYOUT.Gap, (height * 0.82 - size.Height) / math.max(count - 1, 1))
		-- short screens / the machine panel: squeeze the column to fit (labels still never overlap)
		local room = bottomLimit - columnTop - headSpace - size.Height
		step = math.max(size.Height + 2, math.min(step, room / math.max(count - 1, 1)))
		local total = step * (count - 1) + size.Height
		local y = top.Y + height * 0.1
		y = math.clamp(y, columnTop + headSpace, math.max(columnTop + headSpace, bottomLimit - total))
			y += clearOf(x, y - headSpace, x + size.Width, y + total, rects, columnTop, bottomLimit)
		if cap then
			local headX = side == "Left" and x + size.Width - headWidth or x
			local at = smooth(cap.frame, Vector2.new(math.max(headX, leftLimit), y - headSpace), LAYOUT.Smooth, dt)
			cap.frame.Position = UDim2.fromOffset(math.floor(at.X + 0.5), math.floor(at.Y + 0.5))
		end
		for index, entry in ipairs(column) do
			local target = Vector2.new(x, y + (index - 1) * step)
			local at = smooth(entry.frame, target, LAYOUT.Smooth, dt)
			entry.frame.Position = UDim2.fromOffset(math.floor(at.X + 0.5), math.floor(at.Y + 0.5))
			local world = anchorPoint(character, entry.spec.anchor)
			if world then
				local dot = smooth(entry.dot, (project(world)), LAYOUT.DotSmooth, dt)
				entry.dot.Visible = true
				entry.line.Visible = true
				entry.dot.Position = UDim2.fromOffset(dot.X, dot.Y)
				local edge = Vector2.new(side == "Left" and at.X + size.Width or at.X, at.Y + size.Height / 2)
				setLine(entry.line, dot, edge)
			else
				entry.dot.Visible = false
				entry.line.Visible = false
			end
		end
	end
end

------------------------------------------------------------------------
-- Show / hide
------------------------------------------------------------------------
local hidden = { menu = true, genetics = false, stats = false, panel = false, grid = false }
local onMachine = false
local shown = false
local renderConnection = nil

local function mode()
	local settings = ClientData.Get().settings or {}
	return settings.statsLabels or (Theme.IsCompact() and "Training" or "Always")
end

local function update()
	local m = mode()
	local want = not hidden.menu and not hidden.genetics and not hidden.stats and not hidden.panel and not hidden.grid
		and (m == "Always" or (m == "Training" and onMachine))
	if want == shown then return end
	shown = want
	if want then
		refreshNumbers()
		if player.Character then measure(player.Character) end
		table.clear(current)
		gui.Enabled = true
		if not renderConnection then
			renderConnection = RunService.RenderStepped:Connect(place)
		end
		place(0)
		Theme.Fade(layer, true, 0.2)
	else
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

UIBus.GeneticsVisible.Event:Connect(function(visible) hidden.genetics = visible; update() end)
UIBus.StatsVisible.Event:Connect(function(visible) hidden.stats = visible; update() end)
UIBus.MenuPanelVisible.Event:Connect(function(visible) hidden.panel = visible; update() end) -- Titles / Settings
task.spawn(function() -- the phone menu grid (SideMenu)
	local grid = playerGui:WaitForChild("MenuGrid", 30)
	if not grid then return end
	grid:GetPropertyChangedSignal("Enabled"):Connect(function() hidden.grid = grid.Enabled; update() end)
end)
Remotes.MachineState.OnClientEvent:Connect(function(state)
	if state == "Enter" then onMachine = true elseif state == "Exit" then onMachine = false end
	update()
end)
player.CharacterAdded:Connect(function(character)
	onMachine = false
	update()
	character:WaitForChild("Head", 10)
	task.wait(0.5)
	if player.Character == character then measure(character) end
end)
Theme.OnCompactChanged(function() task.defer(update) end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "settings" then
		update()
	elseif (key == "muscles" or key == "stamina") and shown then
		refreshNumbers()
	end
end)
player:GetAttributeChangedSignal("MaxStamina"):Connect(function() if shown then refreshNumbers() end end)

task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	hidden.menu = false
	update()
	-- the body's size changes with Growth Spurts and muscle tiers: re-measure now and then while shown
	while true do
		task.wait(1)
		if shown and player.Character then measure(player.Character) end
	end
end)

------------------------------------------------------------------------
-- Other players: "Strength 1,234" over their head, above their title
------------------------------------------------------------------------
local TAG = { Width = 5, Height = 0.55, Offset = 3.55, MaxDistance = 60 }
local function strengthTag(other, character)
	local head = character:WaitForChild("Head", 10)
	if not head then return end
	local tag = New("BillboardGui", {
		Name = "StrengthTag",
		Size = UDim2.fromScale(TAG.Width, TAG.Height),
		StudsOffset = Vector3.new(0, TAG.Offset, 0),
		MaxDistance = TAG.MaxDistance,
		LightInfluence = 0,
		Parent = head,
	}, { Theme.List(Enum.FillDirection.Horizontal, nil, Enum.HorizontalAlignment.Center) })
	tag:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0.03, 0)
	local function text(name, order, color, font)
		return New("TextLabel", {
			Name = name,
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts[font],
			TextScaled = true, -- stud-sized billboard: the only place text may scale
			TextColor3 = color,
			Parent = tag,
		}, {
			New("UITextSizeConstraint", { MinTextSize = Theme.TextSize.Small, MaxTextSize = 36 }),
			New("UIStroke", { Color = Colors.Shadow, Thickness = 1, Transparency = Theme.Alpha.TextShadow }),
		})
	end
	text("Name", 1, Colors.Text, "Regular").Text = "Strength"
	local number = text("Number", 2, Colors.StatNumber, "SemiBold")
	local function show()
		local value = other:GetAttribute("Strength")
		number.Text = commas(type(value) == "number" and value or 0)
	end
	show()
	other:GetAttributeChangedSignal("Strength"):Connect(show)
end
local function watchOther(other)
	if other == player then return end
	other.CharacterAdded:Connect(function(character) strengthTag(other, character) end)
	if other.Character then task.spawn(strengthTag, other, other.Character) end
end
Players.PlayerAdded:Connect(watchOther)
for _, other in ipairs(Players:GetPlayers()) do watchOther(other) end
