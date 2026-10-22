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
	for _, folder in ipairs(folders) do
		local seconds = folder:GetAttribute("Seconds")
		table.insert(list, { start = folder.Start.CFrame, finish = folder.End.CFrame, seconds = if type(seconds) == "number" and seconds > 1 then seconds else DEFAULT_SECONDS })
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
		pose = if reduced then shot.start else shot.start:Lerp(shot.finish, ease(t))
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
			local wait = shot.seconds - DIP
			local t0 = os.clock()
			while os.clock() - t0 < wait do
				if not running or mine ~= token then return end
				task.wait(0.05)
			end
			if darkLayer then
				TweenService:Create(darkLayer, TweenInfo.new(DIP, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = DIP_DARK }):Play()
				task.wait(DIP)
			end
			if not running or mine ~= token then return end
			index, shotStart = nextIndex, os.clock()
			if darkLayer then
				TweenService:Create(darkLayer, TweenInfo.new(DIP, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
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
	local t0 = os.clock()
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if mine ~= token then return end
		local k = (os.clock() - t0) / time
		local cam = Workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = from:Lerp(target, ease(k))
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
end

return MenuFlyover
