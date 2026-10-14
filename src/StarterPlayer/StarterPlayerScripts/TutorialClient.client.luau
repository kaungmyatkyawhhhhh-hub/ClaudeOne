-- TutorialClient: the first 5 minutes, after the menu and the genetics reveal. Steps come from Config.Onboarding.
-- Owner's UI v2 (mockup 11): each step's short line goes to the top band (Notify.SetBand), a green SKIP TUTORIAL sits
-- under it (tap twice: the first tap asks "Tap again to skip"), and the step's coach pages show in a dialog at the bottom
-- (a live portrait of the Coach NPC, "Coach Dex · Reward (coin) 50", the words, "Tap to continue (1/3)"). On a machine
-- there is no dialog, so it never covers the machine HUD (the band has the step's line). Steps that lead to a machine
-- draw a glowing path of dots on the floor (Roblox pathfinding, so it walks around equipment) and outline the machine.
-- Progress is saved through the server, so a player who leaves mid-tutorial picks up where they were.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Onboarding = require(Shared.Config.Onboarding)
local Quests = require(Shared.Config.Quests)
local Stamina = require(Shared.Config.Stamina)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing

local PATH = {
	Spacing = 2.5,       -- studs between dots
	SkipNear = 3,        -- no dots this close to the player
	MaxDots = 40,
	Refresh = 0.25,      -- seconds between path recomputes (only if the player moved); the dots themselves move every frame
	MoveThreshold = 1,   -- studs the player must move before the path is recomputed
	Approach = 2.5,      -- the path ends this far outside the machine, on the side facing the room
	DotSize = 0.7,
	WaveSpeed = 4,       -- the pulse runs along the path toward the machine
}

------------------------------------------------------------------------
-- Wait for the menu, the data, and the genetics reveal
------------------------------------------------------------------------
local data = ClientData.Get()
local savedStep = data.onboarding.tutorialStep or Onboarding.Done
if savedStep >= Onboarding.Done or savedStep > #Onboarding.Steps then return end
UIBus.WaitForMenu()

local geneticsVisible = false
UIBus.GeneticsVisible.Event:Connect(function(visible) geneticsVisible = visible end)
while not data.onboarding.geneticsRevealed or geneticsVisible do
	task.wait(0.25)
end
task.wait(0.8)

------------------------------------------------------------------------
-- Coach line
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "Tutorial", DisplayOrder = 23, Parent = playerGui }) -- above the stats screen (22), under open panels (24+)
local line = Theme.Panel({
	Name = "CoachLine",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	Parent = gui,
}, {
	New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.L), PaddingRight = UDim.new(0, Spacing.L) }),
	Theme.List(Enum.FillDirection.Horizontal, "S"),
})
New("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(Spacing.S, Spacing.S), BackgroundColor3 = Colors.Text, Parent = line }, { Theme.Round("Round") })
local lineText = Theme.Text({ LayoutOrder = 2, Font = "Regular", TextSize = "Body", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Parent = line })

local statsOpen = false
local onMachine = nil -- MachineId of the machine the player is on
local function placeLine()
	-- the top row (TopBar: coins / level / height) owns the top center: sit just under it. While the stats screen is
	-- open the row hides, so the line moves up to the top (it draws above the stats screen).
	local spurtGui = playerGui:FindFirstChild("TopBar")
	local bar = spurtGui and spurtGui:FindFirstChild("Row", true)
	line.AnchorPoint = Vector2.new(0.5, 0)
	if not statsOpen and spurtGui and spurtGui.Enabled and bar and bar:IsA("GuiObject") and bar.AbsoluteSize.Y > 0 then
		-- both are Theme.ScreenGuis (same inset), so the bar's AbsolutePosition is in this gui's space
		line.Position = UDim2.new(0.5, 0, 0, bar.AbsolutePosition.Y - gui.AbsolutePosition.Y + bar.AbsoluteSize.Y + Spacing.S)
	else
		line.Position = UDim2.new(0.5, 0, 0, Spacing.S)
	end
end

-- (owner, 13 Oct: one hint at a time, in the top band, gone after 4 s: the step's line goes to Notify's band; the old
-- coach line pill stays hidden)
line.Visible = false
local shownText = nil
local function setLine(text)
	if text == shownText then return end
	shownText = text
	lineText.Text = text
	Notify.SetBand(text)
end

------------------------------------------------------------------------
-- SKIP TUTORIAL and the coach dialog (mockup 11)
------------------------------------------------------------------------
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets -- the same top as Notify's band and toasts, so they line up
local root = Kit.Root(gui)
local SKIP_Y = Notify.Top + Notify.BandHeight + 4
local skip = Kit.Button("Green", "Skip tutorial", { Name = "Skip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, SKIP_Y), Parent = root },
	{ width = 170, height = 30, textSize = 15 })
Notify.Reserve(38) -- toasts stack under the skip button
local skipArmed = 0

local dialog = Theme.Panel({ Name = "CoachDialog", Clickable = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(540, 92), Visible = false, Parent = root }, {})
local portrait = New("ViewportFrame", { Name = "Portrait", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = Colors.Blue, Ambient = Color3.fromRGB(190, 190, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -0.6, -1),
	Parent = dialog }, {
	New("UICorner", { CornerRadius = UDim.new(0, 10) }),
	New("UIStroke", { Color = Colors.Outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) }),
})
local nameRow = New("Frame", { Name = "NameRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(94, 7), Size = UDim2.new(1, -104, 0, 22), Parent = dialog }, {
	Theme.List(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
})
Kit.Text({ LayoutOrder = 1, Text = Quests.CoachName .. " · Reward", Font = "Title", TextSize = 17, TextColor3 = Colors.Gold, Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X, Parent = nameRow })
Kit.Coin(17, { LayoutOrder = 2, Parent = nameRow })
Kit.Text({ LayoutOrder = 3, Text = tostring(Onboarding.FinishCoins or 0), Font = "Title", TextSize = 17, TextColor3 = Colors.Gold, Size = UDim2.fromOffset(0, 22),
	AutomaticSize = Enum.AutomaticSize.X, Parent = nameRow })
local dialogText = Kit.Text({ Name = "Text", Text = "", Font = "Body", TextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(94, 30), Size = UDim2.new(1, -106, 0, 38),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = dialog })
local dialogFoot = Kit.Text({ Name = "Continue", Text = "", Font = "Body", TextSize = 12, TextColor3 = Colors.Muted, Position = UDim2.fromOffset(94, 70), Size = UDim2.new(1, -106, 0, 16),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = dialog })

-- the Coach's face: a copy of the Coach NPC in the portrait (no scripts, prompts or labels)
task.spawn(function()
	local coach = CollectionService:GetTagged("Coach")[1]
	local waited = 0
	while not coach and waited < 15 do
		task.wait(0.5)
		waited += 0.5
		coach = CollectionService:GetTagged("Coach")[1]
	end
	local head = coach and coach:FindFirstChild("Head")
	if not head then
		Pieces.Image("trainer_exp", { Size = UDim2.fromScale(1, 1), Parent = portrait })
		return
	end
	local ok = pcall(function()
		coach.Archivable = true
		local copy = coach:Clone()
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Sound") then d:Destroy() end
		end
		local world = New("WorldModel", { Parent = portrait })
		copy.Parent = world
		local copyHead = copy:FindFirstChild("Head") :: BasePart
		local camera = New("Camera", { FieldOfView = 30, Parent = portrait })
		local face = copyHead.CFrame
		camera.CFrame = CFrame.lookAt(face.Position + face.LookVector * 5.6 + Vector3.new(0, 0.2, 0), face.Position - Vector3.new(0, 0.55, 0)) -- head and shoulders
		portrait.CurrentCamera = camera
	end)
	if not ok then Pieces.Image("trainer_exp", { Size = UDim2.fromScale(1, 1), Parent = portrait }) end
end)

local pages, pageIndex = nil, 0
local showPage -- (below)
local function placeDialog()
	-- on a machine the machine HUD owns the screen: no dialog (the band shows the step's line)
	if onMachine and pages then
		pages = nil
		showPage()
	end
end
function showPage()
	if not pages or pageIndex > #pages then
		if dialog.Visible then
			local tween = Theme.Fade(dialog, false, 0.2)
			if tween then tween.Completed:Connect(function() if not pages then dialog.Visible = false end end) else dialog.Visible = false end
		end
		pages = nil
		return
	end
	dialogText.Text = pages[pageIndex]
	dialogFoot.Text = string.format("Tap to continue (%d/%d)", pageIndex, #pages)
	if not dialog.Visible then
		dialog.Visible = true
		Theme.Fade(dialog, true, 0.2)
	end
end
local function showCoach(step)
	pages = (step and not onMachine) and step.coach or nil
	pageIndex = 1
	showPage()
end
dialog.Activated:Connect(function()
	if not pages then return end
	Audio.PlayUI("Click")
	pageIndex += 1
	showPage()
end)

------------------------------------------------------------------------
-- Machines: find them, and the spot just outside each one facing the room
------------------------------------------------------------------------
-- A target is a MachineId, or "Coach" (the Coach NPC, tagged "Coach").
local function machineModel(machineId)
	if machineId == "Coach" then
		return CollectionService:GetTagged("Coach")[1]
	end
	-- the gym has several of each machine: the nearest one nobody is using (any one if all are busy)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position or Vector3.zero
	local best, bestScore = nil, math.huge
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:IsA("Model") and model:GetAttribute("MachineId") == machineId then
			local busy = model:GetAttribute("UserId") ~= nil or model:FindFirstChild("Occupant") ~= nil
			local score = (model:GetPivot().Position - from).Magnitude + (busy and 1000 or 0)
			if score < bestScore then best, bestScore = model, score end
		end
	end
	return best
end

-- The middle of the gym the target is in (machines in the same room, within 60 studs of it).
local function gymCenter(near, room)
	local sum, count = Vector3.zero, 0
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:IsA("Model") and (not room or model.Parent == room) then
			local position = model:GetPivot().Position
			if not near or (position - near).Magnitude < 60 then
				sum += position
				count += 1
			end
		end
	end
	return count > 0 and sum / count or nil
end

-- From the machine's prompt, head toward the middle of the gym until leaving the machine's box, then a bit more.
local function approachPoint(model)
	local boxCFrame, size = model:GetBoundingBox()
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true) -- Use or Spot: both sit on the same part
	local holder = prompt and prompt.Parent
	local start = (holder and holder:IsA("BasePart") and holder.Position)
		or (holder and holder:IsA("Attachment") and holder.WorldPosition)
		or boxCFrame.Position
	local center = gymCenter(boxCFrame.Position, model.Parent) or boxCFrame.Position
	local localStart = boxCFrame:PointToObjectSpace(start)
	local localDir = boxCFrame:VectorToObjectSpace((center - start) * Vector3.new(1, 0, 1))
	if localDir.Magnitude < 0.01 then localDir = Vector3.new(0, 0, -1) end
	localDir = localDir.Unit
	local half = size / 2
	local exit = math.huge
	for _, axis in ipairs({ "X", "Z" }) do
		local d = localDir[axis]
		if math.abs(d) > 1e-4 then
			local bound = d > 0 and half[axis] or -half[axis]
			exit = math.min(exit, (bound - localStart[axis]) / d)
		end
	end
	if exit == math.huge then exit = 0 end
	local localPoint = localStart + localDir * (math.max(exit, 0) + PATH.Approach)
	local world = boxCFrame:PointToWorldSpace(localPoint)
	local floorY = boxCFrame.Position.Y - half.Y
	return Vector3.new(world.X, floorY, world.Z)
end

------------------------------------------------------------------------
-- Glowing path + outline
------------------------------------------------------------------------
local dotFolder = New("Folder", { Name = "TutorialPath" })
local dots = {}
for i = 1, PATH.MaxDots do
	dots[i] = New("Part", {
		Name = "Dot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, PATH.DotSize, PATH.DotSize),
		Material = Enum.Material.Neon,
		Color = Colors.Text,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 1,
		Parent = dotFolder,
	})
end
local activeDots = 0

local highlight = New("Highlight", {
	Name = "TutorialOutline",
	FillTransparency = 1,
	OutlineColor = Colors.Text,
	OutlineTransparency = 0.2,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Enabled = false,
})

local agent = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 2 })
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis up: a flat disc on the floor

-- The dots live on the last computed path (a polyline) and are re-placed EVERY frame from the player's current spot: they
-- sit at fixed distances measured back from the target (so they do not swim when the path is recomputed) and only the ones
-- ahead of the player show, so they never lag behind a running player.
local polyline, cumulative, pathLength = nil, nil, 0
local function placeDots(points)
	polyline = points
	cumulative = { 0 }
	for i = 2, #points do cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude end
	pathLength = cumulative[#points] or 0
end

local function pointAt(s)
	for i = 1, #polyline - 1 do
		if s <= cumulative[i + 1] then
			local seg = cumulative[i + 1] - cumulative[i]
			local t = seg > 0 and (s - cumulative[i]) / seg or 0
			return polyline[i]:Lerp(polyline[i + 1], t)
		end
	end
	return polyline[#polyline]
end

local function renderDots(feet)
	if not polyline or #polyline < 2 then
		activeDots = 0
		for i = 1, PATH.MaxDots do dots[i].Transparency = 1 end
		return
	end
	-- where along the path the player is (closest point on any segment)
	local playerS, best = 0, math.huge
	for i = 1, #polyline - 1 do
		local a, b = polyline[i], polyline[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		local t = len2 > 0 and math.clamp((feet - a):Dot(ab) / len2, 0, 1) or 0
		local d = (feet - (a + ab * t)).Magnitude
		if d < best then
			best = d
			playerS = cumulative[i] + t * math.sqrt(len2)
		end
	end
	local count, k = 0, 0
	while count < PATH.MaxDots do
		local s = pathLength - k * PATH.Spacing
		if s <= playerS + PATH.SkipNear then break end
		count += 1
		dots[count].CFrame = CFrame.new(pointAt(s) + Vector3.new(0, 0.07, 0)) * FLAT
		k += 1
	end
	for i = count + 1, PATH.MaxDots do dots[i].Transparency = 1 end
	activeDots = count
end

local targetModel, targetPoint = nil, nil
local lastFrom = nil
local computing = false

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function refreshPath(force)
	local root = rootPart()
	if not root or not targetPoint or computing then return end
	local from = root.Position
	if not force and lastFrom and (from - lastFrom).Magnitude < PATH.MoveThreshold then return end
	lastFrom = from
	computing = true
	local target = targetPoint -- (the step can end while the path is computing: targetPoint turns nil)
	task.spawn(function()
		local feet = from - Vector3.new(0, 2.5, 0)
		local ok = pcall(function() agent:ComputeAsync(feet, target) end)
		local points
		if ok and agent.Status == Enum.PathStatus.Success then
			points = {}
			for _, waypoint in ipairs(agent:GetWaypoints()) do table.insert(points, waypoint.Position) end
		else
			points = { Vector3.new(from.X, target.Y, from.Z), target } -- straight line fallback
		end
		computing = false
		if targetPoint == target then placeDots(points) end
	end)
end

-- (owner, 14 Oct: instance streaming) the target machine may not be on this device yet, or stream out and back in as a
-- new instance: the step's machine is remembered (wantedTarget) and looked up again until it's here; the highlight lives
-- under the camera and only points at it, so it never leaves with a streamed-out model
local wantedTarget = nil
local function showPath(machineId)
	wantedTarget = machineId
	targetModel = machineModel(machineId)
	if not targetModel then return end
	targetPoint = approachPoint(targetModel)
	highlight.Adornee = targetModel
	highlight.Parent = Workspace.CurrentCamera
	highlight.Enabled = true
	dotFolder.Parent = Workspace.CurrentCamera
	lastFrom = nil
	refreshPath(true)
end

local function hidePath()
	wantedTarget = nil
	targetModel, targetPoint = nil, nil
	polyline = nil
	highlight.Enabled = false
	highlight.Parent = nil
	dotFolder.Parent = nil
	activeDots = 0
end

local refreshClock, retryClock = 0, 0
RunService.Heartbeat:Connect(function(dt)
	-- the step's machine not here yet, or streamed out: look again once a second
	if wantedTarget and (not targetModel or not targetModel:IsDescendantOf(Workspace)) then
		retryClock += dt
		if retryClock >= 1 then
			retryClock = 0
			targetModel, targetPoint = nil, nil
			showPath(wantedTarget)
		end
	end
	if not targetPoint then return end
	refreshClock += dt
	local rootNow = rootPart()
	if rootNow then renderDots(rootNow.Position - Vector3.new(0, 2.5, 0)) end
	if refreshClock >= PATH.Refresh then
		refreshClock = 0
		refreshPath(false)
	end
	local t = os.clock() * PATH.WaveSpeed
	for i = 1, activeDots do
		dots[i].Transparency = 0.15 + 0.55 * (0.5 + 0.5 * math.sin(i * 0.7 - t))
	end
	highlight.OutlineTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 3))
end)

------------------------------------------------------------------------
-- What the player is doing
------------------------------------------------------------------------
local statsOpenTime = 0 -- seconds Stats has been open during the current step
local statsSeenThisStep = false
local drankShake = false -- during the current step
local stepIndex = data.onboarding.tutorialStep
local stepReps = 0
local stepStarted = os.clock()

local advance -- forward declaration

local function stepDef()
	return Onboarding.Steps[stepIndex]
end

local coachShownFor = nil
local function refreshStep()
	local step = stepDef()
	if not step then return end
	local text = (onMachine and step.onMachineText) or step.text
	setLine(text)
	if coachShownFor ~= stepIndex then
		coachShownFor = stepIndex
		showCoach(step)
	elseif pages then
		placeDialog()
	end
	if step.target and onMachine ~= step.target then
		if not targetPoint then showPath(step.target) end
	else
		hidePath()
	end
	-- point at the Stats button (a dot on it until stats is opened)
	if step.done.type == "statsOpen" then
		local hud = playerGui:FindFirstChild("MainHud")
		local button = hud and hud:FindFirstChild("Stats", true)
		local dot = button and button:FindFirstChild("Dot")
		if dot then dot.Visible = true end
	end
end

local function check()
	local step = stepDef()
	if not step then return end
	local done = step.done
	if done.type == "onMachine" then
		if onMachine == step.target then advance() end
	elseif done.type == "reps" then
		if stepReps >= done.count then advance() end
	elseif done.type == "staminaLow" then
		local max = player:GetAttribute("MaxStamina")
		if ClientData.Get().stamina / (type(max) == "number" and max or Stamina.Max) < done.below or stepReps >= done.count then advance() end
	elseif done.type == "statsOpen" then
		if statsOpen then advance() end
	elseif done.type == "statsOpenFor" then
		if statsOpenTime >= done.count then advance() end
	elseif done.type == "shake" then
		if drankShake then advance() end
	elseif done.type == "quest" then
		local quests = ClientData.Get().quests
		if quests and quests.active then advance() end
	elseif done.type == "seconds" then
		if os.clock() - stepStarted >= done.count then advance() end
	end
end

local function finish(skipped: boolean?)
	hidePath()
	shownText = nil
	pages = nil
	Notify.SetBand(nil)
	Notify.Reserve(0)
	gui:Destroy()
	if skipped then
		Notify.Toast("Tutorial skipped", "Quests and hints are in the menu", "list-checks", Colors.Blue)
	else
		Notify.Toast(Onboarding.FinishedText, Onboarding.FinishCoins and ("+" .. Onboarding.FinishCoins .. " coins") or nil, "coin", Colors.Gold)
	end
	Audio.PlayUI("Whoosh")
end

skip.Activated:Connect(function()
	if os.clock() - skipArmed > 3 then
		-- the first tap only asks (a stray tap never wipes the tutorial)
		skipArmed = os.clock()
		Kit.SetButton(skip, "Gold", "Tap again to skip")
		task.delay(3, function()
			if skip.Parent and os.clock() - skipArmed >= 3 then Kit.SetButton(skip, "Green", "Skip tutorial") end
		end)
		return
	end
	stepIndex = Onboarding.Done
	Remotes.PlayerAction:FireServer("SkipTutorial")
	finish(true)
end)

function advance()
	stepIndex += 1
	if stepIndex > #Onboarding.Steps then stepIndex = Onboarding.Done end
	stepReps = 0
	stepStarted = os.clock()
	statsOpenTime = 0
	statsSeenThisStep = statsOpen
	drankShake = false
	Remotes.PlayerAction:FireServer("TutorialStep", stepIndex)
	hidePath()
	if stepIndex >= Onboarding.Done then
		finish()
		return
	end
	Audio.PlayUI("Click")
	refreshStep()
	task.defer(check) -- e.g. already on the next target machine
end

Remotes.MachineState.OnClientEvent:Connect(function(state, model)
	if state == "Enter" and typeof(model) == "Instance" then
		onMachine = model:GetAttribute("MachineId")
	elseif state == "Exit" then
		onMachine = nil
	end
	if stepIndex < Onboarding.Done then
		refreshStep()
		check()
	end
end)

Remotes.RepResult.OnClientEvent:Connect(function(result)
	if stepIndex >= Onboarding.Done or type(result) ~= "table" or result.noStamina then return end
	local step = stepDef()
	if step and (not step.done.machine or step.done.machine == onMachine) then
		stepReps += 1
		check()
	end
end)

ClientData.Changed:Connect(function(path)
	if (path[1] == "stamina" or path[1] == "quests") and stepIndex < Onboarding.Done then check() end
end)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind)
	if kind == "ShakeDrunk" and stepIndex < Onboarding.Done then
		drankShake = true
		check()
	end
end)

-- "stats open" = the stat labels around you (the Stats tile) or the Muscles window
local labelsShown, musclesShown = false, false
local function onStatsVisible()
	local visible = labelsShown or musclesShown
	statsOpen = visible
	if stepIndex >= Onboarding.Done then return end
	placeLine()
	task.delay(0.1, placeLine) -- again once the goal panel has its measured size
	local step = stepDef()
	if visible then statsSeenThisStep = true end
	-- closing Stats after a look also finishes a "statsOpenFor" step
	if not visible and step and step.done.type == "statsOpenFor" and statsSeenThisStep and statsOpenTime > 1 then
		advance()
	else
		check()
	end
end
UIBus.StatsVisible.Event:Connect(function(visible) labelsShown = visible onStatsVisible() end)
UIBus.MusclesVisible.Event:Connect(function(visible) musclesShown = visible onStatsVisible() end)

-- The skip button and the coach dialog step aside while the genetics screen or a menu window is open.
local geneticsShown = false
local function applyHidden()
	if stepIndex < Onboarding.Done and gui.Parent then
		gui.Enabled = not geneticsShown and not player:GetAttribute("WindowOpen")
	end
end
UIBus.GeneticsVisible.Event:Connect(function(visible)
	geneticsShown = visible == true
	applyHidden()
end)
player:GetAttributeChangedSignal("WindowOpen"):Connect(applyHidden)
applyHidden() -- (a window can already be open when the tutorial starts: the Daily Reward after Play)

-- Timed steps
task.spawn(function()
	while stepIndex < Onboarding.Done do
		local dt = task.wait(0.5)
		local step = stepDef()
		if statsOpen then statsOpenTime += dt end
		if step and (step.done.type == "seconds" or step.done.type == "statsOpenFor") then check() end
	end
end)

player.CharacterAdded:Connect(function()
	onMachine = nil
	if stepIndex < Onboarding.Done then
		hidePath()
		task.wait(1)
		refreshStep()
	end
end)

refreshStep()
check()
