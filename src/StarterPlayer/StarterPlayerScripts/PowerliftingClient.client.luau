-- PowerliftingClient (prompt 58, 23 Oct): the Powerlifting Gym on this device (Server/PowerliftingService, Config/Powerlifting).
--   * The loading door: locked for you (before Growth Spurt 5) the shutter is down and its Blocker solid; walking up to it
--     shows the locked toast with how far you are ("Growth Spurt 5 · 54% there"). Open: the shutter is rolled up for you.
--     (The door streams in and out, so it's looked up again whenever it's gone, like ProGymClient.)
--   * PLBell: the PR bell swings and rings, it glows, a quick gold flash on screen and the toast "NAME hit a ... PR!".
--   * PLRecord: the record board flashes, the judge lights turn white with GOOD LIFT, the crowd cheers, a toast.
--   * PLJudge: the judge lights answer a rep on the platform during a meet. PLMeet: toasts, and the countdown
--     ("MEET 0:42 · PLATFORM +20%") on the panel under the judge lights.
--   * A heavy pull set down on a deadlift-type machine here thuds (PlateDrop) for anyone close.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Machines = require(Config.Machines)
local Powerlifting = require(Config.Powerlifting)
local GrowthSpurts = require(Config.GrowthSpurts)
local Muscles = require(Config.Muscles)
local Guides = require(Config.Guides)
local ClientData = require(Shared.ClientData)
local Notify = require(Shared.UI.Notify)
local Theme = require(Shared.UI.Theme)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Colors = Theme.Colors
local player = Players.LocalPlayer
local UNLOCK = Machines.GymUnlock.Powerlifting
local LOCK = { when = "Growth Spurt " .. UNLOCK, progress = UNLOCK, tease = "The heaviest bars in town." }
local NOTE_RANGE = 10
local LIGHT_ON, LIGHT_OFF = Color3.fromHex("#FFFFFF"), Color3.fromHex("#3A3A3C")

local function gym(): Model?
	return Workspace:FindFirstChild("PowerliftingGym") :: Model?
end

------------------------------------------------------------------------
-- the door
------------------------------------------------------------------------
local door, blocker, shutter = nil, nil, nil
local wasOpen = nil
local lastNote = 0
local function share(data): number
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts or 0))
	return GrowthSpurts.Share(progress, Muscles.Groups)
end
-- the locked toast with your progress (walking up to the door, or tapping its shutter: prompt 62)
local function lockedNote(data)
	lastNote = os.clock()
	local ok, s = pcall(share, data)
	local title, sub = Guides.LockedLines(LOCK, data, if ok then s else nil)
	Notify.Toast(title, sub, "lock", Colors.Gold, "pllocked")
end
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then return end
	acc = 0
	if not door or not door:IsDescendantOf(Workspace) then
		door = nil
		local g = gym()
		local found = g and g:FindFirstChild("LoadingDoor")
		if not (found and found:FindFirstChild("Blocker")) then return end
		door, blocker, shutter, wasOpen = found, found.Blocker, found:FindFirstChild("Shutter"), nil
		local tap = blocker:FindFirstChildOfClass("ClickDetector") -- (prompt 62: a tap on the door)
		if tap then
			tap.MouseClick:Connect(function()
				local data = ClientData.Get()
				if data and not wasOpen and os.clock() - lastNote > 1.5 then lockedNote(data) end
			end)
		end
	end
	local data = ClientData.Get()
	if not data then return end
	local open = Machines.GymLevel(data) >= UNLOCK
	if open ~= wasOpen then
		wasOpen = open
		blocker.CanCollide = not open
		local tap = blocker:FindFirstChildOfClass("ClickDetector")
		if tap then tap.MaxActivationDistance = if open then 0 else 40 end
		if shutter then
			shutter.LocalTransparencyModifier = if open then 1 else 0
			for _, d in ipairs(shutter:GetDescendants()) do
				if d:IsA("BasePart") then d.LocalTransparencyModifier = if open then 1 else 0
				elseif d:IsA("SurfaceGui") then d.Enabled = not open end
			end
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not open and root and (root.Position - blocker.Position).Magnitude < NOTE_RANGE and os.clock() - lastNote > 8 then
		lockedNote(data)
	end
end)

------------------------------------------------------------------------
-- the bell, the board, the judges
------------------------------------------------------------------------
local function find(...)
	local node: Instance? = gym()
	for _, name in ipairs({ ... }) do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function screenFlash(color: Color3)
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "PLFlash", true, false, 5
	local frame = Instance.new("Frame")
	frame.BackgroundColor3, frame.BackgroundTransparency, frame.Size, frame.BorderSizePixel = color, 0.65, UDim2.fromScale(1, 1), 0
	frame.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local tween = TweenService:Create(frame, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	tween.Completed:Connect(function() gui:Destroy() end)
	tween:Play()
end

local function ringBell()
	local bell = find("PRBell")
	if not bell then return end
	local swing = bell:FindFirstChild("Swing") :: Model?
	local glow = bell:FindFirstChild("BellGlow") :: BasePart?
	Audio.PlayAt("PRBell", (glow or bell:FindFirstChildWhichIsA("BasePart")) :: BasePart)
	if glow then
		glow.LocalTransparencyModifier = 0
		glow.Transparency = 0.45
		TweenService:Create(glow, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	end
	if swing then
		local yoke = bell:FindFirstChild("Yoke") :: BasePart?
		local start = swing:GetPivot()
		local hinge = if yoke then yoke.Position else start.Position
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 1.6 and swing.Parent do
				local t = os.clock() - t0
				local angle = math.rad(28) * math.exp(-t * 2.2) * math.sin(t * 14)
				local turn = CFrame.new(hinge) * CFrame.Angles(angle, 0, 0) * CFrame.new(-hinge)
				swing:PivotTo(turn * start)
				RunService.RenderStepped:Wait()
			end
			if swing.Parent then swing:PivotTo(start) end
		end)
	end
end

local judgeToken = 0
local judgeShowing = false -- (the verdict line says GOOD LIFT: the meet countdown waits)
local function judgeLights(on: boolean, text: string?)
	judgeToken += 1
	judgeShowing = on
	local token = judgeToken
	local judges = find("Judges")
	if not judges then return end
	for _, d in ipairs(judges:GetChildren()) do
		if d:IsA("BasePart") and (string.match(d.Name, "^JudgeLight%d") or string.match(d.Name, "^JudgeLamp%d")) then
			d.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			d.Color = if on then LIGHT_ON else LIGHT_OFF
		end
	end
	local verdict = judges:FindFirstChild("JudgeVerdict")
	local label = verdict and verdict:FindFirstChildWhichIsA("SurfaceGui") and verdict:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChild("Text")
	if label and text then
		label.Text = text
		label.TextColor3 = Color3.new(1, 1, 1)
	end
	if on then
		task.delay(Powerlifting.JudgeHold, function()
			if token == judgeToken then judgeLights(false, "") end
		end)
	end
end

local function boardFlash()
	local flash = find("Props", "RecordFlash") :: BasePart?
	if not flash then return end
	task.spawn(function()
		for _ = 1, 3 do
			flash.Transparency = 0.35
			TweenService:Create(flash, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			task.wait(0.45)
		end
	end)
end

-- the meet's countdown on the panel under the judge lights
local meetEndsAt = 0
local function meetCountdown()
	task.spawn(function()
		while Workspace:GetServerTimeNow() < meetEndsAt do
			local left = math.max(0, math.ceil(meetEndsAt - Workspace:GetServerTimeNow()))
			local judges = find("Judges")
			local verdict = judges and judges:FindFirstChild("JudgeVerdict")
			local gui = verdict and verdict:FindFirstChildWhichIsA("SurfaceGui")
			local label = gui and gui:FindFirstChild("Text") :: TextLabel?
			if label and not judgeShowing then
				label.Text = string.format("MEET %d:%02d  ·  PLATFORM +%d%%", left // 60, left % 60, math.floor((Powerlifting.MeetBonus - 1) * 100 + 0.5))
				label.TextColor3 = Color3.fromHex("#FF6B5E")
			end
			task.wait(0.5)
		end
		local judges = find("Judges")
		local verdict = judges and judges:FindFirstChild("JudgeVerdict")
		local gui = verdict and verdict:FindFirstChildWhichIsA("SurfaceGui")
		local label = gui and gui:FindFirstChild("Text") :: TextLabel?
		if label then label.Text, label.TextColor3 = "", Color3.new(1, 1, 1) end
	end)
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then info = {} end
	if kind == "PLBell" then
		local text = Powerlifting.PRText(tostring(info.name or ""), tonumber(info.weight) or 0, tostring(info.lift or ""))
		if not info.quiet then
			ringBell()
			screenFlash(Colors.Gold)
		end
		Notify.Toast(text, "PR BELL", "star", Colors.Gold, "plbell")
	elseif kind == "PLRecord" then
		boardFlash()
		judgeLights(true, "GOOD LIFT")
		Audio.Play2D("RecordCheer")
		Notify.Toast("NEW SERVER RECORD", string.format("%s · %s LB %s", tostring(info.name or ""), Powerlifting.FormatWeight(tonumber(info.weight) or 0),
			tostring(info.liftName or "")), "star", Colors.Gold, "plrecord")
	elseif kind == "PLJudge" then
		judgeLights(true, "GOOD LIFT")
		Audio.Play2D("GoodLift")
	elseif kind == "PLMeet" then
		local bonus = math.floor((Powerlifting.MeetBonus - 1) * 100 + 0.5)
		if info.phase == "soon" then
			Notify.Show("A MEET starts in " .. tostring(info.seconds or 15) .. " s: lift on the competition platform for +" .. bonus .. "% EXP!", nil, "plmeet")
		elseif info.phase == "start" then
			meetEndsAt = tonumber(info.endsAt) or 0
			Notify.Toast("THE MEET IS ON", "Competition platform: +" .. bonus .. "% EXP", "zap", Colors.Gold, "plmeet")
			meetCountdown()
		elseif info.phase == "end" then
			meetEndsAt = 0
			Notify.Show("The meet is over. Next one in about 10 minutes.", nil, "plmeet")
		end
	elseif kind == "PowerliftingLocked" then
		Notify.Show("Reach Growth Spurt " .. tostring(info.spurts or UNLOCK) .. " to enter the Powerlifting Gym", nil, "pllocked")
	elseif kind == "PowerliftingEntered" then
		Notify.Show("Welcome to the Powerlifting Gym: the heaviest bars in town. Hit a PR to ring the bell!", nil, "plwelcome")
		Audio.PlayUI("Whoosh")
		-- a meet already running when you walk in
		local ends = tonumber(info.meetEndsAt) or 0
		if ends > Workspace:GetServerTimeNow() then
			meetEndsAt = ends
			meetCountdown()
		end
	end
end)

------------------------------------------------------------------------
-- heavy pulls thud (a rep on a deadlift-type machine here: its Reps attribute goes up)
------------------------------------------------------------------------
local watched = {}
local function watch(model: Instance)
	if watched[model] or not model:IsA("Model") then return end
	local machine = Machines.ById[model:GetAttribute("MachineId") or ""]
	if not machine or (machine.base ~= "Deadlift" and machine.base ~= "BarbellRow") then return end
	watched[model] = model:GetAttributeChangedSignal("Reps"):Connect(function()
		local camera = Workspace.CurrentCamera
		local at = model:GetPivot().Position
		if camera and (camera.CFrame.Position - at).Magnitude < 70 then
			task.delay(0.45, function() Audio.PlayAt("PlateDrop", at) end)
		end
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) and watched[model] then
			watched[model]:Disconnect()
			watched[model] = nil
		end
	end)
end
local CollectionService = game:GetService("CollectionService")
local function consider(model: Instance)
	local g = gym()
	if g and model:IsDescendantOf(g) then watch(model) end
end
for _, model in ipairs(CollectionService:GetTagged("Machine")) do consider(model) end
CollectionService:GetInstanceAddedSignal("Machine"):Connect(function(model)
	task.defer(consider, model)
end)
