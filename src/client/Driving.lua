--[[
	Driving (client)
	The local player owns the physics of their car. Every physics step we:
	  * read keyboard / gamepad / touch input
	  * integrate an arcade-realistic model: engine curve, brakes, drag, speed
	    sensitive steering with a lateral-g cap, tyre grip + handbrake drifts
	  * push the result into the LinearVelocity / AlignOrientation constraints
	  * detect crashes (physics stopped us) and "cut ups" (passing traffic close)
	Every render frame we:
	  * spin + steer the wheels, turn the steering wheel, and solve 2-bone IK so
	    the driver's arms follow their hands on the wheel
	  * drive the camera (interior cockpit or chase) with speed-based FOV,
	    shake and blur
	  * update the HUD + the live gauge cluster on the dashboard
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local Traffic = require(script.Parent:WaitForChild("Traffic"))
local UI = require(script.Parent:WaitForChild("UI"))
local Audio = require(script.Parent:WaitForChild("Audio"))

local camera = workspace.CurrentCamera

local Driving = {}
Driving.cameraMode = "Chase" -- "Chase" | "Interior"
Driving.inputEnabled = true

type ArmRig = { upper: Motor6D, fore: Motor6D, shoulder: Vector3, grip: Vector3, pole: Vector3 }

type State = {
	model: Model,
	root: BasePart,
	spec: Cars.CarSpec,
	lv: LinearVelocity,
	ao: AlignOrientation,
	topSpeed: number,
	accel: number,
	wheelbase: number,
	halfHeight: number,
	width: number,
	yaw: number,
	vel: Vector3,
	steer: number,
	wheelSpin: number,
	wheels: { Motor6D },
	steerMotor: Motor6D?,
	steerMount: CFrame?,
	steerMaxRot: number,
	arms: { ArmRig },
	upperLen: number,
	foreLen: number,
	eye: Vector3,
	lastCommand: Vector3,
	crashCooldown: number,
	lastCrash: number,
	passTrack: { [any]: number },
	lastCutTime: number,
	lastCutSide: number,
	grounded: boolean,
	connections: { RBXScriptConnection },
	hidden: { BasePart },
	glass: { BasePart },
	gaugeSpeed: TextLabel?,
	gaugeGear: TextLabel?,
	gaugeBar: Frame?,
	camPos: Vector3,
	camLook: Vector3,
	fov: number,
	shake: number,
	gear: string,
	rpm: number,
	cabinLight: PointLight?,
	engine: Audio.Engine,
	throttle: number,
	slip: number,
}

local state: State? = nil
local remotes: Folder? = nil
local blur: BlurEffect? = nil

local function remote(name: string): any
	local r = remotes or ReplicatedStorage:WaitForChild("Remotes")
	remotes = r
	return (r :: Folder):WaitForChild(name)
end

---------------------------------------------------------------------
-- Input
---------------------------------------------------------------------
local function readInput(): (number, number, number, boolean)
	if not Driving.inputEnabled or UI.isGarageOpen() then
		return 0, 0, 0, false
	end
	local throttle, brake, steer = 0, 0, 0
	local handbrake = false
	if UserInputService:GetFocusedTextBox() == nil then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			throttle = 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			brake = 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			steer -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			steer += 1
		end
		handbrake = UserInputService:IsKeyDown(Enum.KeyCode.Space)
	end
	-- gamepad
	if UserInputService.GamepadEnabled then
		for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				throttle = math.max(throttle, input.Position.Z)
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
				brake = math.max(brake, input.Position.Z)
			elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
				if math.abs(input.Position.X) > 0.12 then
					steer += input.Position.X
				end
			elseif input.KeyCode == Enum.KeyCode.ButtonX then
				handbrake = handbrake or input.UserInputState == Enum.UserInputState.Begin
			end
		end
	end
	-- touch
	throttle = math.max(throttle, UI.touch.throttle)
	brake = math.max(brake, UI.touch.brake)
	steer += UI.touch.steer
	handbrake = handbrake or UI.touch.handbrake
	return throttle, brake, math.clamp(steer, -1, 1), handbrake
end

---------------------------------------------------------------------
-- Attach / detach
---------------------------------------------------------------------
local function yawFromLook(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

local function forwardFromYaw(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function buildGauges(model: Model): (TextLabel?, TextLabel?, Frame?)
	local cluster = model:FindFirstChild("Cluster", true)
	local gui = cluster and cluster:FindFirstChild("Gauges")
	if not gui then
		return nil, nil, nil
	end
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local speed = Instance.new("TextLabel")
	speed.BackgroundTransparency = 1
	speed.Size = UDim2.new(0.5, 0, 0.75, 0)
	speed.Position = UDim2.fromScale(0.25, 0.02)
	speed.Font = Enum.Font.GothamBlack
	speed.TextScaled = true
	speed.TextColor3 = Color3.new(1, 1, 1)
	speed.Text = "0"
	speed.Parent = bg
	local gear = Instance.new("TextLabel")
	gear.BackgroundTransparency = 1
	gear.Size = UDim2.new(0.2, 0, 0.6, 0)
	gear.Position = UDim2.fromScale(0.78, 0.15)
	gear.Font = Enum.Font.GothamBlack
	gear.TextScaled = true
	gear.TextColor3 = Config.Theme.Accent
	gear.Text = "N"
	gear.Parent = bg
	local unit = Instance.new("TextLabel")
	unit.BackgroundTransparency = 1
	unit.Size = UDim2.new(0.2, 0, 0.3, 0)
	unit.Position = UDim2.fromScale(0.03, 0.35)
	unit.Font = Enum.Font.GothamBold
	unit.TextScaled = true
	unit.TextColor3 = Config.Theme.SubText
	unit.Text = "MPH"
	unit.Parent = bg
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromScale(0.05, 0.84)
	barBack.Size = UDim2.fromScale(0.9, 0.08)
	barBack.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
	barBack.BorderSizePixel = 0
	barBack.Parent = bg
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Config.Theme.Accent
	bar.BorderSizePixel = 0
	bar.Parent = barBack
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Config.Theme.Accent, Config.Theme.Accent2)
	grad.Parent = bar
	return speed, gear, bar
end

function Driving.detach()
	local s = state
	if not s then
		return
	end
	for _, c in s.connections do
		c:Disconnect()
	end
	s.engine:destroy()
	if s.cabinLight then
		s.cabinLight:Destroy()
	end
	state = nil
	if blur then
		blur.Size = 0
	end
end

function Driving.isDriving(): boolean
	return state ~= nil
end

function Driving.getRoot(): BasePart?
	return if state then state.root else nil
end

function Driving.toggleCamera()
	Driving.cameraMode = if Driving.cameraMode == "Chase" then "Interior" else "Chase"
	UI.setCameraLabel(Driving.cameraMode)
	local s = state
	if s then
		local interior = Driving.cameraMode == "Interior"
		for _, p in s.hidden do
			p.LocalTransparencyModifier = if interior then 1 else 0
		end
		for _, g in s.glass do
			g.LocalTransparencyModifier = if interior then 0.65 else 0
		end
		if s.cabinLight then
			s.cabinLight.Enabled = interior
		end
	end
end

function Driving.reset()
	local s = state
	if not s then
		return
	end
	local cf = CityLayout.nearestLaneCFrame(s.root.Position)
	s.root.AssemblyLinearVelocity = Vector3.zero
	s.root.AssemblyAngularVelocity = Vector3.zero
	s.root.CFrame = cf + Vector3.new(0, s.halfHeight + 0.4, 0)
	s.yaw = yawFromLook(cf.LookVector)
	s.vel = Vector3.zero
	s.lastCommand = Vector3.zero
end

function Driving.attach(model: Model)
	Driving.detach()
	local root = model.PrimaryPart :: BasePart
	local spec = Cars.get(model:GetAttribute("CarId") :: string)
	local dims = CarBuilder.getDims(spec.Class)
	local lv = root:WaitForChild("Drive") :: LinearVelocity
	local ao = root:WaitForChild("Steer") :: AlignOrientation

	local wheels = {}
	local arms: { ArmRig } = {}
	for _, j in root:GetChildren() do
		if j:IsA("Motor6D") and j.Name:sub(1, 6) == "Wheel_" then
			table.insert(wheels, j)
		end
	end
	local steerMotor = root:FindFirstChild("SteerMotor") :: Motor6D?
	for _, side in { "L", "R" } do
		local upper = root:FindFirstChild("UpperArm" .. side) :: Motor6D?
		local fore = root:FindFirstChild("ForeArm" .. side) :: Motor6D?
		local shoulder = model:GetAttribute("Shoulder" .. side) :: Vector3?
		local grip = model:GetAttribute("Grip" .. side) :: Vector3?
		if upper and fore and shoulder and grip then
			table.insert(arms, {
				upper = upper,
				fore = fore,
				shoulder = shoulder,
				grip = grip,
				pole = Vector3.new(if side == "L" then -0.8 else 0.8, -1, 0.2),
			})
		end
	end

	local hidden = {}
	local glass = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "DriverHead" or d.Name == "DriverHair" or d.Name == "DriverNeck" then
				table.insert(hidden, d)
			elseif d.Name == "SkinGlass" or (not model:GetAttribute("Skinned") and (d.Name == "Windshield" or d.Name == "SideGlassL" or d.Name == "SideGlassR")) then
				table.insert(glass, d)
			end
		end
	end

	local cabinLight = Instance.new("PointLight")
	cabinLight.Color = Color3.fromRGB(150, 110, 255)
	cabinLight.Brightness = 0.7
	cabinLight.Range = 7
	cabinLight.Shadows = false
	cabinLight.Enabled = false
	cabinLight.Parent = root

	local gSpeed, gGear, gBar = buildGauges(model)


	local s: State = {
		model = model,
		root = root,
		spec = spec,
		lv = lv,
		ao = ao,
		topSpeed = Config.mphToSps(spec.TopSpeed),
		accel = Config.mphToSps(60) / spec.ZeroToSixty,
		wheelbase = dims.wb,
		halfHeight = (model:GetAttribute("Height") :: number) / 2,
		width = model:GetAttribute("Width") :: number,
		yaw = yawFromLook(root.CFrame.LookVector),
		vel = Vector3.zero,
		steer = 0,
		wheelSpin = 0,
		wheels = wheels,
		steerMotor = steerMotor,
		steerMount = model:GetAttribute("SteerMount") :: CFrame?,
		steerMaxRot = (model:GetAttribute("SteerMaxRot") :: number?) or math.rad(110),
		arms = arms,
		upperLen = (model:GetAttribute("UpperLen") :: number?) or 1.1,
		foreLen = (model:GetAttribute("ForeLen") :: number?) or 1.05,
		eye = (model:GetAttribute("Eye") :: Vector3?) or Vector3.new(-1.3, 1, 0),
		lastCommand = Vector3.zero,
		crashCooldown = 0,
		lastCrash = 0,
		passTrack = {},
		lastCutTime = 0,
		lastCutSide = 0,
		grounded = true,
		connections = {},
		hidden = hidden,
		glass = glass,
		gaugeSpeed = gSpeed,
		gaugeGear = gGear,
		gaugeBar = gBar,
		camPos = root.Position + Vector3.new(0, 8, 20),
		camLook = root.Position,
		fov = Config.Camera.ChaseFov,
		shake = 0,
		gear = "N",
		rpm = 0,
		cabinLight = cabinLight,
		engine = Audio.engine(spec.Class, nil),
		throttle = 0,
		slip = 0,
	}
	state = s
	Audio.engineStart()
	camera.CameraType = Enum.CameraType.Scriptable

	-- apply current camera mode visibility
	Driving.cameraMode = if Driving.cameraMode == "Interior" then "Chase" else "Interior"
	Driving.toggleCamera()

	table.insert(s.connections, RunService.PreSimulation:Connect(function(dt)
		Driving.step(dt)
	end))
	table.insert(s.connections, RunService.RenderStepped:Connect(function(dt)
		Driving.render(dt)
	end))
	table.insert(s.connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and state and state.model == model then
			Driving.detach()
		end
	end))
end

---------------------------------------------------------------------
-- Physics step
---------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function reportCrash(s: State, severity: number)
	local now = os.clock()
	if now - s.lastCrash < 0.8 then
		return
	end
	s.lastCrash = now
	s.shake = math.max(s.shake, math.clamp(severity / 80, 0.3, 1.5))
	UI.flash(Config.Theme.Danger)
	UI.setCombo(0)
	remote("Crash"):FireServer()
	Audio.crash(severity)
end

local function detectCuts(s: State, fwd: Vector3, speedMph: number)
	local right = fwd:Cross(Vector3.yAxis)
	local myPos = Vector3.new(s.root.Position.X, 0, s.root.Position.Z)
	local E = Config.Economy
	local seen = {}
	for _, npc in Traffic.near(myPos, 45) do
		seen[npc] = true
		local rel = npc.pos - myPos
		local f = rel:Dot(fwd)
		local prev = s.passTrack[npc]
		s.passTrack[npc] = f
		if prev and prev > 0 and f <= 0 then
			local lat = rel:Dot(right)
			local gap = math.abs(lat) - (s.width + npc.width) / 2
			local recentlyCrashed = os.clock() - s.lastCrash < 1.2
			if gap < E.NearMissGap and gap > -1.5 and speedMph >= E.CutMinMph and not recentlyCrashed then
				local closeness = math.clamp(1 - gap / E.NearMissGap, 0, 1)
				local oncoming = npc.fwd:Dot(fwd) < -0.5
				local side = if lat >= 0 then 1 else -1
				local now = os.clock()
				local thread = now - s.lastCutTime < 0.4 and side ~= s.lastCutSide
				s.lastCutTime = now
				s.lastCutSide = side
				remote("CutUp"):FireServer({ closeness = closeness, oncoming = oncoming, thread = thread })
			end
		end
	end
	for npc in s.passTrack do
		if not seen[npc] then
			s.passTrack[npc] = nil
		end
	end
end

function Driving.step(dt: number)
	local s = state
	if not s or not s.root.Parent then
		return
	end
	dt = math.min(dt, 1 / 20)
	local root = s.root
	local throttle, brake, steerIn, handbrake = readInput()
	s.throttle += (throttle - s.throttle) * math.min(1, dt * 10)

	-- ground check
	rayParams.FilterDescendantsInstances = { s.model, workspace:FindFirstChild("Traffic") :: Instance }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(s.halfHeight + 1.2), 0), rayParams)
	s.grounded = hit ~= nil

	local actual = root.AssemblyLinearVelocity
	local actualFlat = Vector3.new(actual.X, 0, actual.Z)

	-- Crash detection: physics couldn't give us the velocity we asked for
	if s.grounded and s.lastCommand.Magnitude > 25 then
		local loss = (s.lastCommand - actualFlat).Magnitude
		if loss > math.max(22, s.lastCommand.Magnitude * 0.35) then
			s.vel = actualFlat
			reportCrash(s, loss)
		end
	end

	local fwd = forwardFromYaw(s.yaw)
	local right = Vector3.new(math.cos(s.yaw), 0, -math.sin(s.yaw))
	local fwdSpeed = s.vel:Dot(fwd)
	local latSpeed = s.vel:Dot(right)
	local handling = s.spec.Handling

	if s.grounded then
		-- longitudinal
		local a = 0
		local speedFrac = fwdSpeed / s.topSpeed
		if throttle > 0 then
			if fwdSpeed < -2 then
				a += 140 * throttle -- braking out of reverse
			else
				a += s.accel * 1.25 * throttle * math.max(0, 1 - math.max(speedFrac, 0) ^ 2.6)
			end
		end
		if brake > 0 then
			if fwdSpeed > 2 then
				a -= 150 * brake
			elseif fwdSpeed > -s.topSpeed * 0.22 then
				a -= s.accel * 0.6 * brake
			end
		end
		-- rolling resistance + aero drag
		local drag = 4 + 0.00045 * fwdSpeed * fwdSpeed
		if handbrake then
			drag += 40
		end
		if math.abs(fwdSpeed) > 0.5 then
			a -= math.sign(fwdSpeed) * drag
		elseif throttle == 0 and brake == 0 then
			fwdSpeed = 0
		end
		fwdSpeed += a * dt

		-- steering: speed-sensitive wheel angle, capped by lateral grip
		local steerRate = if math.abs(steerIn) > math.abs(s.steer) then 5 else 8
		s.steer += (steerIn - s.steer) * math.min(1, dt * steerRate)
		local speedAbs = math.abs(fwdSpeed)
		local maxAngle = math.rad(36) / (1 + (speedAbs / 70) ^ 1.3)
		local angle = s.steer * maxAngle
		local yawRate = fwdSpeed * math.tan(angle) / s.wheelbase
		local gripG = 2.6 + 2.4 * handling
		local cap = gripG * 28 / math.max(speedAbs, 1)
		if handbrake then
			cap *= 1.7
		end
		yawRate = math.clamp(yawRate, -cap, cap)
		s.yaw -= yawRate * dt

		-- lateral grip (low with handbrake -> drift)
		local grip = if handbrake then 1.4 else 7 + 7 * handling
		latSpeed *= math.exp(-grip * dt)
		s.slip = math.abs(latSpeed) + (if handbrake and math.abs(fwdSpeed) > 20 then 25 else 0)

		local newFwd = forwardFromYaw(s.yaw)
		local newRight = Vector3.new(math.cos(s.yaw), 0, -math.sin(s.yaw))
		s.vel = newFwd * fwdSpeed + newRight * latSpeed
		s.lv.MaxForce = root.AssemblyMass * 400
	else
		s.lv.MaxForce = root.AssemblyMass * 8
		s.steer += (steerIn - s.steer) * math.min(1, dt * 6)
	end

	-- out of the world
	if root.Position.Y < -40 then
		Driving.reset()
		return
	end

	s.lv.PlaneVelocity = Vector2.new(s.vel.X, s.vel.Z)
	s.ao.CFrame = CFrame.Angles(0, s.yaw, 0)
	s.lastCommand = s.vel

	-- gears / rpm (cosmetic)
	local fs = s.vel:Dot(forwardFromYaw(s.yaw))
	local frac = math.clamp(math.abs(fs) / s.topSpeed, 0, 1)
	local prevGear = s.gear
	if fs < -1 then
		s.gear = "R"
		s.rpm = math.clamp(-fs / (s.topSpeed * 0.22), 0, 1)
	elseif math.abs(fs) < 1 and throttle == 0 then
		s.gear = "N"
		s.rpm = 0.1
	else
		local gears = 7
		local g = math.clamp(math.floor(frac ^ 0.8 * gears) + 1, 1, gears)
		s.gear = tostring(g)
		local lo = ((g - 1) / gears) ^ (1 / 0.8)
		local hi = (g / gears) ^ (1 / 0.8)
		s.rpm = math.clamp((frac - lo) / (hi - lo), 0, 1) * 0.75 + 0.2
	end

	-- shift sounds (dip in revs, pops on hard upshifts)
	local pg, ng = tonumber(prevGear), tonumber(s.gear)
	if pg and ng and ng ~= pg then
		s.engine:shift(ng > pg)
	end

	local mph = Config.spsToMph(math.abs(fs))
	detectCuts(s, forwardFromYaw(s.yaw), mph)
end

---------------------------------------------------------------------
-- Render: rig animation + camera
---------------------------------------------------------------------
function Driving.render(dt: number)
	local s = state
	if not s or not s.root.Parent then
		return
	end
	local root = s.root
	local fwd = forwardFromYaw(s.yaw)
	local fwdSpeed = s.vel:Dot(fwd)
	local speedFrac = math.clamp(math.abs(fwdSpeed) / s.topSpeed, 0, 1)

	-- wheels
	s.wheelSpin = (s.wheelSpin - fwdSpeed * dt / 1.1) % (math.pi * 2)
	local wheelAngle = -s.steer * math.rad(28) / (1 + (math.abs(fwdSpeed) / 90))
	for _, m in s.wheels do
		if m:GetAttribute("Front") then
			m.Transform = CFrame.Angles(0, wheelAngle, 0) * CFrame.Angles(s.wheelSpin, 0, 0)
		else
			m.Transform = CFrame.Angles(s.wheelSpin, 0, 0)
		end
	end

	-- steering wheel + hands + IK arms
	local rot = -s.steer * s.steerMaxRot
	if s.steerMotor then
		s.steerMotor.Transform = CFrame.Angles(0, 0, rot)
	end
	if s.steerMount then
		local wheelCF = s.steerMount * CFrame.Angles(0, 0, rot)
		for _, arm in s.arms do
			local hand = (wheelCF * CFrame.new(arm.grip)).Position
			local upperCF, foreCF = CarBuilder.solveArm(arm.shoulder, hand, s.upperLen, s.foreLen, arm.pole)
			arm.upper.Transform = arm.upper.C0:Inverse() * upperCF
			arm.fore.Transform = arm.fore.C0:Inverse() * foreCF
		end
	end

	-- dashboard cluster + HUD
	local mph = Config.spsToMph(math.abs(fwdSpeed))
	if s.gaugeSpeed then
		s.gaugeSpeed.Text = tostring(math.floor(mph + 0.5))
	end
	if s.gaugeGear then
		s.gaugeGear.Text = s.gear
	end
	if s.gaugeBar then
		s.gaugeBar.Size = UDim2.fromScale(s.rpm, 1)
	end
	UI.setSpeed(mph, speedFrac, s.gear, s.rpm)

	-- engine / wind / tyre audio
	s.engine:update(s.rpm, s.throttle, speedFrac, s.slip)

	-- camera
	local C = Config.Camera
	s.shake = math.max(0, s.shake - dt * 2.5)
	local t = os.clock()
	local speedShake = math.max(0, speedFrac - 0.55) * 0.12
	local shakeAmt = speedShake + s.shake * 0.5
	local shakeOffset = Vector3.new(math.noise(t * 23, 0, 1), math.noise(0, t * 21, 2), 0) * shakeAmt

	local targetFov
	local rootCF = root.CFrame
	if Driving.cameraMode == "Interior" then
		targetFov = C.InteriorFov + C.MaxFovBoost * 0.8 * speedFrac ^ 1.5
		local mouseLook = 0
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			local vp = camera.ViewportSize
			local mp = UserInputService:GetMouseLocation()
			mouseLook = -((mp.X / vp.X) - 0.5) * math.rad(160)
		end
		local lookInto = -s.steer * math.rad(9)
		local eyeCF = rootCF * CFrame.new(s.eye) * CFrame.Angles(0, lookInto + mouseLook, 0) * CFrame.Angles(math.rad(-4), 0, 0)
		camera.CFrame = eyeCF * CFrame.new(shakeOffset * 0.3)
		s.camPos = camera.CFrame.Position
		if blur then
			blur.Size = 0
		end
	else
		targetFov = C.ChaseFov + C.MaxFovBoost * speedFrac ^ 1.4
		-- follow the direction of travel a little when drifting
		local velDir = if s.vel.Magnitude > 5 then s.vel.Unit else fwd
		if s.vel:Dot(fwd) < -5 then
			velDir = fwd
		end
		local camDir = (fwd * 0.75 + velDir * 0.25).Unit
		local dist = C.ChaseDistance + speedFrac * 4
		local desired = root.Position - camDir * dist + Vector3.new(0, C.ChaseHeight - speedFrac * 0.8, 0)
		local alpha = 1 - math.exp(-dt * 10)
		s.camPos = s.camPos:Lerp(desired, alpha)
		-- never let the camera lag too far behind at hyper speeds
		local offset = s.camPos - root.Position
		if offset.Magnitude > dist * 1.6 then
			s.camPos = root.Position + offset.Unit * dist * 1.6
		end
		local look = root.Position + fwd * 10 + Vector3.new(0, 1.8, 0)
		s.camLook = s.camLook:Lerp(look, 1 - math.exp(-dt * 14))
		local roll = math.clamp(-s.steer * speedFrac * 0.05, -0.05, 0.05)
		camera.CFrame = CFrame.lookAt(s.camPos + shakeOffset, s.camLook) * CFrame.Angles(0, 0, roll)
		if blur then
			blur.Size = 3.5 * math.max(0, speedFrac - 0.45) ^ 1.5
		end
	end
	s.fov += (targetFov - s.fov) * math.min(1, dt * 4)
	camera.FieldOfView = s.fov
end

---------------------------------------------------------------------
-- One-time setup
---------------------------------------------------------------------
function Driving.init()
	local b = Instance.new("BlurEffect")
	b.Size = 0
	b.Parent = Lighting
	blur = b

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not state then
			return
		end
		if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonY then
			Driving.toggleCamera()
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonSelect then
			Driving.reset()
		end
	end)

	remote("Earned").OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then
			return
		end
		if info.kind == "crash" then
			UI.setCombo(0)
			return
		end
		local amount = tonumber(info.amount) or 0
		local combo = tonumber(info.combo) or 1
		local text = tostring(info.label or "CUT UP")
		if combo > 1 then
			text ..= "  x" .. combo
		end
		local color = Config.Theme.Accent
		if text:find("THREAD") then
			color = Config.Theme.Accent2
		elseif text:find("ONCOMING") then
			color = Config.Theme.Warning
		end
		UI.popup(text, amount, color)
		UI.setCombo(combo)
		local s = state
		if s then
			s.shake = math.max(s.shake, 0.15)
		end
		Audio.cutUp(combo, text)
	end)
end

return Driving
