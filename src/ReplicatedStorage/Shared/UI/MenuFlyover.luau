-- MenuFlyover (prompt 60, 23 Oct): the title screen's live camera flyover (MenuClient). The camera is scriptable and glides
-- slowly round the map on a loop of shots read from Workspace.MenuCameraPath (built in Studio, tools/builders/MenuCameraPath:
-- one Folder per shot in name order, each with a "Start" and an "End" part; the camera looks out of each part's front face;
-- the shot's "Seconds" attribute is its length). Each shot glides Start -> End with a sine ease in / out, no shake; between
-- shots a soft dip through dark (DIP s out, DIP s in). The next shot's points are streamed in (RequestStreamAroundAsync)
-- while the current one plays, so nothing pops in.
--   * A light depth of field (only the far distance softens) and a soft dark vignette (in the menu's background gui) so the
--     buttons stay readable. The depth of field is dropped on low graphics quality, or when the frame rate stays under
--     MIN_FPS (phones): the vignette stays.
--   * Reduced Motion: the camera holds still on each shot (the dips still change shots).
--   MenuFlyover.Prepare() -> bool    the path is there and the first shot is streamed in (call while loading)
--   MenuFlyover.Start(darkLayer)      runs the loop; darkLayer = a full-screen Frame used for the dips (its own colour)
--   MenuFlyover.FlyTo(cframe, time, done)  stops the loop and flies the camera to `cframe` (the PLAY swoop), then done()
--   MenuFlyover.Stop()                stops everything and removes the depth of field
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local MenuFlyover = {}

local DEFAULT_SECONDS = 9
local DIP = 0.55            -- the dip through dark between shots: this long out, and this long back in
local DIP_DARK = 0.1        -- how dark the dip gets (the layer's transparency at its darkest)
local STREAM_TIMEOUT = 6
local MIN_FPS = 40          -- under this (averaged over FPS_WINDOW s) the depth of field goes
local FPS_WINDOW = 3
local DOF = { FarIntensity = 0.22, FocusDistance = 55, InFocusRadius = 45, NearIntensity = 0 } -- (light: only the far distance softens)
local BIND = "MenuFlyover"

local player = Players.LocalPlayer
local shots = nil
local running = false
local token = 0
local dof = nil

local function ease(t: number): number return 0.5 - 0.5 * math.cos(math.pi * math.clamp(t, 0, 1)) end

-- (owner, 26 Oct: "make the main menu more dramatic by changing the camera angles") Every shot is short and punchy: it
-- pushes in fast and settles (quart out), the field of view zooms in over it, the camera leans a little (alternating
-- left / right), shots change with a quick cut through black, and a low-angle orbit round the champion statue
-- (Workspace.StatuePedestal, looking up) comes in between the Studio shots.
local DRAMA = {
	MaxSeconds = 5.5,          -- a Studio shot is cut to at most this long
	Fov = { 80, 62 },          -- the field of view from the start of a shot to its end
	Roll = 4,                  -- degrees of lean, alternating each shot
	Cut = 0.16, CutDark = 0,   -- the cut through black: this long out and back in, fully dark
	Statue = { every = 3, seconds = 5, radius = 8, camHeight = 1.6, lookHeight = 7, sweep = math.rad(60) },
}
-- (the statue orbit) its arc, picked when the shot starts: the longest run of angles (every 10 degrees) with no wall
-- between the camera and the statue and nobody standing in the way (your own character spawns there, gym regulars walk by;
-- a character blocks the camera angles within BlockDegrees of its own angle round the statue)
local BLOCK_DEGREES = 40
local function pickOrbit(center: Vector3, look: Vector3, pedestal: BasePart?): number
	local s = DRAMA.Statue
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { pedestal }
	local people = {}
	for _, h in ipairs(Workspace:GetDescendants()) do
		if h:IsA("Humanoid") and h.Parent then
			local root = h.Parent:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local d = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
				-- (never the statue itself: it stands on the pedestal)
				if d.Magnitude > 2.5 and d.Magnitude < s.radius + 4 then table.insert(people, math.atan2(d.Z, d.X)) end
			end
		end
	end
	local function clear(a)
		for _, c in ipairs(people) do
			local diff = math.abs((a - c + math.pi) % (2 * math.pi) - math.pi)
			if diff < math.rad(BLOCK_DEGREES) then return false end
		end
		local pos = center + Vector3.new(math.cos(a) * s.radius, s.camHeight, math.sin(a) * s.radius)
		local hit = Workspace:Raycast(look, pos - look, params)
		return hit == nil or (hit.Position - look).Magnitude > s.radius - 0.5 or hit.Instance.Transparency > 0.9
	end
	local a0, best = 0, -1
	for step = 0, 35 do
		local a = math.rad(step * 10)
		local run = 0
		for k = 0, math.ceil(math.deg(s.sweep) / 10) do
			if clear(a + math.rad(k * 10)) then run += 1 else break end
		end
		if run > best then a0, best = a, run end
	end
	return a0
end
local function punch(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 4
end

-- the shots in name order: { start = CFrame, finish = CFrame, seconds }
local function readShots()
	local path = Workspace:FindFirstChild("MenuCameraPath") or Workspace:WaitForChild("MenuCameraPath", 5)
	if not path then return {} end
	local folders = {}
	for _, folder in ipairs(path:GetChildren()) do
		local a, b = folder:FindFirstChild("Start"), folder:FindFirstChild("End")
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then table.insert(folders, folder) end
	end
	table.sort(folders, function(x, y) return x.Name < y.Name end)
	local list = {}
	local pedestal = Workspace:FindFirstChild("StatuePedestal")
	for i, folder in ipairs(folders) do
		local seconds = folder:GetAttribute("Seconds")
		seconds = if type(seconds) == "number" and seconds > 1 then seconds else DEFAULT_SECONDS
		table.insert(list, { start = folder.Start.CFrame, finish = folder.End.CFrame, seconds = math.min(seconds, DRAMA.MaxSeconds) })
		-- (26 Oct) the statue orbit every few shots
		if pedestal and pedestal:IsA("BasePart") and i % DRAMA.Statue.every == 0 then
			local s = DRAMA.Statue
			local center = pedestal.Position
			local look = center + Vector3.new(0, s.lookHeight, 0)
			local a0 = pickOrbit(center, look, pedestal)
			local function at(a)
				local pos = center + Vector3.new(math.cos(a) * s.radius, s.camHeight, math.sin(a) * s.radius)
				return CFrame.lookAt(pos, look)
			end
			table.insert(list, { start = at(a0), finish = at(a0 + s.sweep), seconds = s.seconds, orbit = { center = center, look = look, a0 = a0, pedestal = pedestal } })
		end
	end
	return list
end

local function streamShot(shot)
	if not shot then return end
	for _, cf in ipairs({ shot.start, shot.finish }) do
		pcall(function() player:RequestStreamAroundAsync(cf.Position, STREAM_TIMEOUT) end)
	end
end

local function lowGraphics(): boolean
	local ok, level = pcall(function() return UserSettings().GameSettings.SavedQualityLevel end)
	if ok and level ~= Enum.SavedQualitySetting.Automatic and level.Value <= 3 then return true end
	return false
end

local function removeDof()
	if dof then dof:Destroy() dof = nil end
end

function MenuFlyover.Prepare(): boolean
	shots = readShots()
	if #shots == 0 then return false end
	streamShot(shots[1])
	return true
end

function MenuFlyover.Start(darkLayer: GuiObject?)
	if running then return end
	shots = shots or readShots()
	if #shots == 0 then return end
	running = true
	token += 1
	local mine = token
	local camera = Workspace.CurrentCamera
	local reduced = Theme.ReducedMotion()
	-- the light depth of field (not on low graphics)
	for _, old in ipairs(Lighting:GetChildren()) do
		if old.Name == "MenuDOF" then old:Destroy() end
	end
	if not lowGraphics() then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "MenuDOF"
		for k, v in pairs(DOF) do (dof :: any)[k] = v end
		dof.Parent = Lighting
	end
	-- the camera follows the current pose every frame (other scripts set it back to Custom while loading)
	local index, shotStart = 1, os.clock()
	local pose = shots[1].start
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = pose
	-- (the first window is skipped: loading drops frames; two slow windows in a row are needed)
	local frames, fpsStart, windows, slow = 0, os.clock(), 0, 0
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if mine ~= token then return end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local shot = shots[index]
		local t = (os.clock() - shotStart) / shot.seconds
		if reduced then
			pose = shot.start
		elseif shot.orbit then
			-- round the statue on an arc (a straight lerp would cut through it), looking up at it
			local s, o = DRAMA.Statue, shot.orbit
			local a = o.a0 + s.sweep * ease(t)
			local pos = o.center + Vector3.new(math.cos(a) * s.radius, s.camHeight, math.sin(a) * s.radius)
			pose = CFrame.lookAt(pos, o.look)
		else
			pose = shot.start:Lerp(shot.finish, punch(t))
		end
		if not reduced then
			local lean = DRAMA.Roll * (if index % 2 == 0 then 1 else -1) * (1 - 0.4 * punch(t))
			pose = pose * CFrame.Angles(0, 0, math.rad(lean))
			cam.FieldOfView = DRAMA.Fov[1] + (DRAMA.Fov[2] - DRAMA.Fov[1]) * punch(t)
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = pose
		-- the frame rate: too low = the depth of field goes (for this menu)
		frames += 1
		local span = os.clock() - fpsStart
		if span >= FPS_WINDOW then
			windows += 1
			if windows > 1 then
				slow = if frames / span < MIN_FPS then slow + 1 else 0
				if dof and slow >= 2 then removeDof() end
			end
			frames, fpsStart = 0, os.clock()
		end
	end)
	-- the loop: each shot, the next one streamed in meanwhile, a dip through dark between them
	task.spawn(function()
		while running and mine == token do
			local shot = shots[index]
			local nextIndex = index % #shots + 1
			task.spawn(streamShot, shots[nextIndex])
			local wait = shot.seconds - DRAMA.Cut
			local t0 = os.clock()
			while os.clock() - t0 < wait do
				if not running or mine ~= token then return end
				task.wait(0.05)
			end
			-- (26 Oct) a quick cut through black
			if darkLayer then
				TweenService:Create(darkLayer, TweenInfo.new(DRAMA.Cut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = DRAMA.CutDark }):Play()
				task.wait(DRAMA.Cut)
			end
			if not running or mine ~= token then return end
			index, shotStart = nextIndex, os.clock()
			local o = shots[index].orbit
			if o then o.a0 = pickOrbit(o.center, o.look, o.pedestal) end -- (people move: picked again each time)
			if darkLayer then
				TweenService:Create(darkLayer, TweenInfo.new(DRAMA.Cut, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
			end
		end
	end)
end

function MenuFlyover.Running(): boolean return running end

-- stops the loop and flies from where the camera is to `target` in `time` s (eased), then calls done
function MenuFlyover.FlyTo(target: CFrame, time: number, done: (() -> ())?)
	running = false
	token += 1
	local mine = token
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	removeDof()
	local camera = Workspace.CurrentCamera
	local from = camera.CFrame
	local fromFov = camera.FieldOfView
	local t0 = os.clock()
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if mine ~= token then return end
		local k = (os.clock() - t0) / time
		local cam = Workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = from:Lerp(target, ease(k))
		cam.FieldOfView = fromFov + (70 - fromFov) * ease(k) -- (back to the normal field of view)
		if k >= 1 then
			pcall(function() RunService:UnbindFromRenderStep(BIND) end)
			if done then task.spawn(done) end
		end
	end)
end

function MenuFlyover.Stop()
	running = false
	token += 1
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	removeDof()
	if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = 70 end
end

return MenuFlyover
