-- GuidePath: a glowing path of dots on the floor to a machine (or the Coach), and an outline on it. Roblox pathfinding, so
-- it walks around equipment. Used by the tutorial (TutorialClient) and the Growth Spurt's "Go" buttons (ProgressClient).
-- Moved out of TutorialClient (prompt 20, 21 Oct). Client only.
--   GuidePath.Show(target, owner?)  target = a MachineId (the nearest free one), "Coach", or a Vector3 (a spot on the
--                                   floor, e.g. the posing stage: no outline); owner = who asked (a string)
--   GuidePath.Hide(owner?)          hides it (with an owner: only if that owner's path is showing)
--   GuidePath.Target()              the MachineId / "Coach" being shown, and its owner (nil when hidden)
--   GuidePath.Walk()                (prompt 11) walks the player along the path (Humanoid:MoveTo); stops when the path is
--                                   hidden, the player steers themselves or gets stuck. Returns true if they arrived.
--   GuidePath.Teleport(target)      (22 Oct, owner: the GO TO buttons teleport) a 0.3 s fade to black with a whoosh, the
--                                   server moves the player in front of the target (GoToService: checks it, 3 s cooldown,
--                                   off a machine first), the fade back in. Yields; returns true if the player was moved.
--   GuidePath.Mark(target, seconds?) a glowing gold marker on the target (a soft gold glow over it) and a gold arrow
--                                   bouncing above it, for `seconds` (nil = until Unmark / the next Mark): the tutorial
--   GuidePath.Unmark()
-- (prompt 11, 21 Oct) Under the dots a glowing gold ribbon (Beams lying flat on the floor) runs from the player to the target.
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
	RibbonWidth = 0.9,   -- (prompt 11) the gold ribbon under the dots
	RibbonStep = 3,      -- studs per ribbon segment
	MaxSegments = 40,
}

------------------------------------------------------------------------
-- Machines: find them, and the spot just outside each one facing the room
------------------------------------------------------------------------
-- A target is a MachineId, or "Coach" (the Coach NPC, tagged "Coach"). (22 Oct: finding it and the spot in front of it
-- moved to Shared/GoTo, so the server's teleport picks the same machine and spot.)
local GoTo = require(script.Parent.Parent.GoTo)
local function machineModel(machineId)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local ClientData = require(script.Parent.Parent.ClientData)
	return GoTo.Find(machineId, if root then root.Position else Vector3.zero, ClientData.Get().growthSpurts or 0)
end
local approachPoint = GoTo.Spot

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
		Color = Color3.fromHex("#FFF3C4"), -- (prompt 11: a pale gold over the gold ribbon; was white)
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 1,
		Parent = dotFolder,
	})
end
local activeDots = 0

-- (prompt 11) the gold ribbon: a pool of flat Beams between attachment pairs on one invisible anchored part. A Beam's width
-- runs along its attachments' Y axis, so each attachment's Y points sideways (flat on the floor).
local ribbonHolder = New("Part", { Name = "Ribbon", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
	Size = Vector3.one, CFrame = CFrame.new(), Parent = dotFolder })
local ribbon = {}
for i = 1, PATH.MaxSegments do
	local a0 = New("Attachment", { Parent = ribbonHolder })
	local a1 = New("Attachment", { Parent = ribbonHolder })
	local beam = New("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = PATH.RibbonWidth, Width1 = PATH.RibbonWidth, FaceCamera = false,
		Segments = 1, LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Colors.Gold), Transparency = NumberSequence.new(0.35),
		Enabled = false, Parent = ribbonHolder })
	ribbon[i] = { a0 = a0, a1 = a1, beam = beam }
end
local activeSegments = 0
local function flatAt(point: Vector3, dir: Vector3): CFrame
	local side = Vector3.new(-dir.Z, 0, dir.X)
	if side.Magnitude < 1e-3 then side = Vector3.xAxis end
	return CFrame.fromMatrix(point, dir, side.Unit)
end

local highlight = New("Highlight", {
	Name = "GuideOutline",
	FillTransparency = 1,
	OutlineColor = Colors.Gold, -- (22 Oct: gold, like the path; was white)
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
		for i = 1, activeSegments do ribbon[i].beam.Enabled = false end
		activeSegments = 0
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
	-- the gold ribbon from just ahead of the player to the target
	local segments = 0
	local s = playerS + PATH.SkipNear * 0.5
	while s < pathLength - 0.2 and segments < PATH.MaxSegments do
		local e = math.min(s + PATH.RibbonStep, pathLength)
		local p0, p1 = pointAt(s) + Vector3.new(0, 0.06, 0), pointAt(e) + Vector3.new(0, 0.06, 0)
		local dir = (p1 - p0) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.05 then
			segments += 1
			local seg = ribbon[segments]
			dir = dir.Unit
			seg.a0.WorldCFrame = flatAt(p0, dir)
			seg.a1.WorldCFrame = flatAt(p1, dir)
			seg.beam.Enabled = true
		end
		s = e
	end
	for i = segments + 1, activeSegments do ribbon[i].beam.Enabled = false end
	activeSegments = segments
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
	if typeof(machineId) == "Vector3" then -- (a spot, not a model: no outline, nothing to look up again)
		targetModel, targetPoint = nil, machineId
		dotFolder.Parent = Workspace.CurrentCamera
		lastFrom = nil
		refreshPath(true)
		return
	end
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
	if wantedTarget and typeof(wantedTarget) ~= "Vector3" and (not targetModel or not targetModel:IsDescendantOf(Workspace)) then
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
	local glow = 0.3 + 0.15 * math.sin(os.clock() * 3)
	for i = 1, activeSegments do ribbon[i].beam.Transparency = NumberSequence.new(glow) end
	highlight.OutlineTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 3))
end)

function GuidePath.Show(target: any, owner: string?)
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

function GuidePath.Target(): (any, string?)
	return wantedTarget, wantedOwner
end

-- (prompt 11) Walk the player to the target along a fresh path (the "Go to bench" button). Stops when the path is hidden,
-- another walk starts, the player steers (keys / thumbstick: MoveDirection away from the next waypoint) or is stuck.
local walkToken = 0
function GuidePath.Walk(): boolean
	walkToken += 1
	local token = walkToken
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootPart()
	local target = targetPoint
	if not humanoid or not root or not target then return false end
	local walker = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 4 })
	local ok = pcall(function() walker:ComputeAsync(root.Position - Vector3.new(0, 2.5, 0), target) end)
	if not ok or walker.Status ~= Enum.PathStatus.Success then return false end
	for _, waypoint in ipairs(walker:GetWaypoints()) do
		if token ~= walkToken or targetPoint ~= target or not humanoid.Parent or humanoid.Health <= 0 then return false end
		humanoid:MoveTo(waypoint.Position)
		local arrived = false
		local started = os.clock()
		local conn = humanoid.MoveToFinished:Connect(function(reached) arrived = reached end)
		while not arrived and os.clock() - started < 3 do
			task.wait(0.05)
			if token ~= walkToken or targetPoint ~= target then break end
		end
		conn:Disconnect()
		if not arrived then return false end
	end
	return token == walkToken
end
function GuidePath.StopWalk()
	walkToken += 1
end

------------------------------------------------------------------------
-- (22 Oct) Teleport: fade to black, the server moves the player (GoToService), fade back in
------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local FADE = 0.3
local COOLDOWN = 3 -- (the server checks it too)
local fadeGui = New("ScreenGui", { Name = "GoToFade", DisplayOrder = 90, IgnoreGuiInset = true, ResetOnSpawn = false, Enabled = false })
fadeGui.ScreenInsets = Enum.ScreenInsets.None
local fade = New("Frame", { Name = "Fade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = fadeGui })
local lastTeleport = -math.huge
local teleporting = false
function GuidePath.Teleport(target: any): boolean
	if teleporting or os.clock() - lastTeleport < COOLDOWN then return false end
	teleporting = true
	lastTeleport = os.clock()
	GuidePath.StopWalk()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	pcall(function() require(script.Parent.Parent.Audio).PlayUI("Whoosh") end)
	fadeGui.Parent = player:WaitForChild("PlayerGui")
	fadeGui.Enabled = true
	TweenService:Create(fade, TweenInfo.new(FADE), { BackgroundTransparency = 0 }):Play()
	-- the server's answer (or give up after 2 s: the screen never stays black)
	local done, moved, at = false, false, nil
	local connection = Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
		if kind == "GoTo" then
			done, moved = true, type(info) == "table" and info.ok == true
			at = if type(info) == "table" and typeof(info.at) == "Vector3" then info.at else nil
		end
	end)
	task.wait(FADE)
	Remotes.PlayerAction:FireServer("GoTo", target)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 2 do task.wait() end
	connection:Disconnect()
	-- the camera behind the player, looking at the target (it kept its old direction and could end up behind a rack)
	local root = rootPart()
	local camera = Workspace.CurrentCamera
	if moved and at and root and camera then
		local flat = (at - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.1 then
			local from = root.Position - flat.Unit * 9 + Vector3.new(0, 4, 0)
			camera.CFrame = CFrame.lookAt(from, at + Vector3.new(0, 1, 0))
		end
	end
	task.wait(0.05)
	local out = TweenService:Create(fade, TweenInfo.new(FADE), { BackgroundTransparency = 1 })
	out:Play()
	out.Completed:Wait()
	fadeGui.Enabled = false
	teleporting = false
	return moved
end

-- A gold arrow over the target, bouncing, pointing down at it, for `seconds`.
local markToken = 0
function GuidePath.Mark(target: any, seconds: number?)
	markToken += 1
	local token = markToken
	local model = if typeof(target) == "Instance" then target else (targetModel or machineModel(target))
	if not model or not model:IsA("Model") then return end
	-- (anchored on an attachment over the model's box, above the machine sign's diamond and name)
	local boxCFrame, size = model:GetBoundingBox()
	local anchor = New("Attachment", { Name = "GoToMarkAnchor", WorldPosition = boxCFrame.Position + Vector3.new(0, size.Y / 2 + 5.2, 0), Parent = Workspace.Terrain })
	local gui = New("BillboardGui", { Name = "GoToMark", AlwaysOnTop = true, LightInfluence = 0, Size = UDim2.fromOffset(64, 64), Adornee = anchor,
		Parent = player:WaitForChild("PlayerGui") })
	local glow = New("Highlight", { Name = "GoToGlow", Adornee = model, FillColor = Colors.Gold, FillTransparency = 0.75, OutlineTransparency = 1,
		DepthMode = Enum.HighlightDepthMode.Occluded, Parent = Workspace.CurrentCamera })
	gui.Destroying:Connect(function()
		anchor:Destroy()
		glow:Destroy()
	end)
	local Pieces = require(script.Parent.Pieces)
	local arrow = Pieces.Icon("arrow-big-up", Colors.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8), Rotation = 180, Parent = gui })
	arrow:SetAttribute("KeepColor", true)
	task.spawn(function()
		local t0 = os.clock()
		while gui.Parent and token == markToken and model.Parent and os.clock() - t0 < (seconds or math.huge) do
			local t = os.clock() - t0
			arrow.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 6) * 8)
			glow.FillTransparency = 0.68 + 0.14 * math.sin(t * 3)
			task.wait()
		end
		gui:Destroy()
	end)
end
function GuidePath.Unmark()
	markToken += 1
end

return GuidePath
