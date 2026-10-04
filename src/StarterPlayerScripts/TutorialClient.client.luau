-- TutorialClient: the first 5 minutes, after the menu and the genetics reveal. Steps come from Config.Onboarding.
-- Each step shows one coach line (small panel, top center; bottom center while Stats is open). Steps that lead to a
-- machine draw a glowing path of dots on the floor (Roblox pathfinding, so it walks around equipment) and outline
-- the machine. Progress is saved through the server, so a player who leaves mid-tutorial picks up where they were.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Onboarding = require(Shared.Config.Onboarding)
local Stamina = require(Shared.Config.Stamina)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
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
	Refresh = 0.75,      -- seconds between path updates (only if the player moved)
	MoveThreshold = 2,   -- studs the player must move before the path is recomputed
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
local gui = Theme.ScreenGui({ Name = "Tutorial", DisplayOrder = 40, Parent = playerGui })
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
local function placeLine()
	if statsOpen then
		-- the Growth Spurt goal panel owns the top center while Stats is open
		line.AnchorPoint = Vector2.new(0.5, 1)
		line.Position = UDim2.new(0.5, 0, 1, -Spacing.XL)
	else
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0.5, 0, 0, GuiService.TopbarInset.Height + Spacing.S)
	end
end

local shownText = nil
local function setLine(text)
	if text == shownText then return end
	local first = shownText == nil
	shownText = text
	lineText.Text = text
	if first then
		placeLine()
		Theme.Fade(line, true)
	else
		-- a new step: a small nudge so the change is noticed
		Theme.Fade(lineText, false, 0.1)
		task.delay(0.1, function()
			if shownText == text then Theme.Fade(lineText, true, 0.15) end
		end)
	end
end

------------------------------------------------------------------------
-- Machines: find them, and the spot just outside each one facing the room
------------------------------------------------------------------------
-- A target is a MachineId, or "Coach" (the Coach NPC, tagged "Coach").
local function machineModel(machineId)
	if machineId == "Coach" then
		return CollectionService:GetTagged("Coach")[1]
	end
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("MachineId") == machineId then return model end
	end
	return nil
end

local function gymCenter()
	local sum, count = Vector3.zero, 0
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:IsA("Model") then
			sum += model:GetPivot().Position
			count += 1
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
	local center = gymCenter() or boxCFrame.Position
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

local function placeDots(points)
	-- walk the polyline, dropping a dot every PATH.Spacing studs
	local count, carry = 0, PATH.Spacing
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = b - a
		local length = segment.Magnitude
		local t = carry
		while t <= length and count < PATH.MaxDots do
			count += 1
			dots[count].CFrame = CFrame.new(a + segment * (t / length) + Vector3.new(0, 0.07, 0)) * FLAT
			t += PATH.Spacing
		end
		carry = t - length
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
	task.spawn(function()
		local feet = from - Vector3.new(0, 2.5, 0)
		local ok = pcall(function() agent:ComputeAsync(feet, targetPoint) end)
		local points
		if ok and agent.Status == Enum.PathStatus.Success then
			points = {}
			for _, waypoint in ipairs(agent:GetWaypoints()) do table.insert(points, waypoint.Position) end
		else
			points = { Vector3.new(from.X, targetPoint.Y, from.Z), targetPoint } -- straight line fallback
		end
		-- start the dots a little ahead of the player
		while #points >= 2 and (points[2] - feet).Magnitude < PATH.SkipNear do table.remove(points, 1) end
		if #points >= 1 and (points[1] - feet).Magnitude < PATH.SkipNear and #points >= 2 then
			local dir = (points[2] - points[1]).Unit
			points[1] = points[1] + dir * (PATH.SkipNear - (points[1] - feet).Magnitude)
		end
		computing = false
		if targetPoint then placeDots(points) end
	end)
end

local function showPath(machineId)
	targetModel = machineModel(machineId)
	if not targetModel then return end
	targetPoint = approachPoint(targetModel)
	highlight.Adornee = targetModel
	highlight.Parent = targetModel
	highlight.Enabled = true
	dotFolder.Parent = Workspace.CurrentCamera
	lastFrom = nil
	refreshPath(true)
end

local function hidePath()
	targetModel, targetPoint = nil, nil
	highlight.Enabled = false
	highlight.Parent = nil
	dotFolder.Parent = nil
	activeDots = 0
end

local refreshClock = 0
RunService.Heartbeat:Connect(function(dt)
	if not targetPoint then return end
	refreshClock += dt
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
local onMachine = nil -- MachineId of the machine the player is on
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

local function refreshStep()
	local step = stepDef()
	if not step then return end
	local text = (onMachine and step.onMachineText) or step.text
	setLine(text)
	if step.target and onMachine ~= step.target then
		if not targetPoint then showPath(step.target) end
	else
		hidePath()
	end
	-- point at the Stats button
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
		if ClientData.Get().stamina / Stamina.Max < done.below or stepReps >= done.count then advance() end
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

local function finish()
	hidePath()
	shownText = nil
	local tween = Theme.Fade(line, false)
	if tween then tween.Completed:Connect(function() gui:Destroy() end) end
	Notify.Show(Onboarding.FinishedText)
	Audio.PlayUI("Whoosh")
end

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

UIBus.StatsVisible.Event:Connect(function(visible)
	statsOpen = visible
	if stepIndex >= Onboarding.Done then return end
	placeLine()
	local step = stepDef()
	if visible then statsSeenThisStep = true end
	-- closing Stats after a look also finishes a "statsOpenFor" step
	if not visible and step and step.done.type == "statsOpenFor" and statsSeenThisStep and statsOpenTime > 1 then
		advance()
	else
		check()
	end
end)

-- The coach line steps aside while the genetics screen is open.
UIBus.GeneticsVisible.Event:Connect(function(visible)
	if stepIndex < Onboarding.Done and shownText then
		Theme.Fade(line, not visible)
	end
end)

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
