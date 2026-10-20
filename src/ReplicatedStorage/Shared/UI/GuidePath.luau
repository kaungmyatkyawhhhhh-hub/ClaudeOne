-- GuidePath: a glowing path of dots on the floor to a machine (or the Coach), and an outline on it. Roblox pathfinding, so
-- it walks around equipment. Used by the tutorial (TutorialClient) and the Growth Spurt's "Go" buttons (ProgressClient).
-- Moved out of TutorialClient (prompt 20, 21 Oct). Client only.
--   GuidePath.Show(target, owner?)  target = a MachineId (the nearest free one) or "Coach"; owner = who asked (a string)
--   GuidePath.Hide(owner?)          hides it (with an owner: only if that owner's path is showing)
--   GuidePath.Target()              the MachineId / "Coach" being shown, and its owner (nil when hidden)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local GuidePath = {}

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
	-- (only machines in a gym the player has opened: the nearest deadlift can be in the locked pro gym)
	local Machines = require(script.Parent.Parent.Config.Machines)
	local ClientData = require(script.Parent.Parent.ClientData)
	local machine = Machines.ById[machineId]
	local spurts = ClientData.Get().growthSpurts or 0
	local best, bestScore = nil, math.huge
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:IsA("Model") and model:GetAttribute("MachineId") == machineId and (not machine or Machines.GymOpenAt(machine, model) <= spurts) then
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
local dotFolder = New("Folder", { Name = "GuidePath" })
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
	Name = "GuideOutline",
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
local wantedTarget, wantedOwner = nil, nil
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
	wantedTarget, wantedOwner = nil, nil
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

function GuidePath.Show(target: string, owner: string?)
	if wantedTarget == target and targetPoint then
		wantedOwner = owner
		return
	end
	hidePath()
	showPath(target)
	wantedTarget, wantedOwner = target, owner
end

function GuidePath.Hide(owner: string?)
	if owner and wantedOwner ~= owner then return end
	hidePath()
end

function GuidePath.Target(): (string?, string?)
	return wantedTarget, wantedOwner
end

return GuidePath
