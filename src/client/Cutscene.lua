--[[
	Cutscene (client) - "CITY LEGENDS" intro, directed like a car commercial.

	SHOT LIST (real seconds)
	  1  0.0 - 4.0   Aerial: slow orbit past the Legends Tower crown and its
	                 searchlights, tilting down onto the avenue. Location card.
	  2  4.0 - 6.9   Crane dive: from 170 studs high down to the median at road
	                 level. The hypercar screams past the lens, the camera whips round.
	  3  6.9 - 8.6   Low bumper rig: rear three-quarter at tyre height, light trails.
	  4  8.6 - 9.6   Side dolly: tracking alongside as it shoots under the monorail.
	  5  9.6 - 11.4  BULLET TIME: speed ramps to 15%, the camera orbits the car
	                 while it threads between two cars, then ramps back with a
	                 flash and an exhaust backfire.
	  6  11.4 - 13.6 Cockpit: over the driver's shoulder; the gloves really turn
	                 the wheel (same IK rig as gameplay).
	  7  13.6 - 15.8 Drone: chasing high towards the mountain tunnel.
	  8  15.8 - end  Tunnel: the car rockets past, under the glowing sign, the
	                 title builds with a chromatic split and a slow push-in.

	Rendering: depth of field focused on the car, a colour grade, vignette,
	letterbox, whip-pan blur, camera shake, tail-light / underglow trails and
	short light streaks on traffic. The world runs on a separate "story clock"
	(tau) so it can slow down while the camera keeps moving in real time.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local UI = require(script.Parent:WaitForChild("UI"))
local CarSkin = require(script.Parent:WaitForChild("CarSkin"))
local Audio = require(script.Parent:WaitForChild("Audio"))

local Cutscene = {}

local C = Config.City
local HWY_X0 = CityLayout.HighwayStartX
local TUNNEL_X0 = HWY_X0 + C.TunnelStart
local TUNNEL_MID = TUNNEL_X0 + C.TunnelLength / 2
local SIGN_POS = Vector3.new(TUNNEL_MID, 22 - 7.5, 0)
local LEGENDS_TOWER = Vector3.new(CityLayout.roadCoord(C.Blocks / 2 - 1) + C.BlockSize / 2, 0, CityLayout.roadCoord(C.Blocks / 2 - 1) + C.BlockSize / 2)

local HERO_START_X = -870
local HERO_SPEED = 205
local TRAFFIC_SPEED = 75
local ONCOMING_SPEED = 85
local THREAD_X = 1160 -- where the bullet-time thread-the-needle happens

-- slow motion window (real seconds)
local SLOW_START, SLOW_IN, SLOW_HOLD, SLOW_OUT, SLOW_SCALE = 9.6, 0.4, 1.0, 0.4, 0.15

local SHOTS = { 4.0, 6.9, 8.6, 9.6, 11.4, 13.6, 15.8 } -- shot start times (2..8)

type Actor = { model: Model, root: BasePart, x: number, z: number, speed: number, dir: number, height: number }

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeInOutCubic(x: number): number
	x = math.clamp(x, 0, 1)
	return if x < 0.5 then 4 * x * x * x else 1 - (-2 * x + 2) ^ 3 / 2
end

local function timeScale(t: number): number
	local a = t - SLOW_START
	if a < 0 then
		return 1
	elseif a < SLOW_IN then
		return 1 + (SLOW_SCALE - 1) * smooth(a / SLOW_IN)
	elseif a < SLOW_IN + SLOW_HOLD then
		return SLOW_SCALE
	elseif a < SLOW_IN + SLOW_HOLD + SLOW_OUT then
		return SLOW_SCALE + (1 - SLOW_SCALE) * smooth((a - SLOW_IN - SLOW_HOLD) / SLOW_OUT)
	end
	return 1
end

local function laneSet(x: number): { number }
	if x < HWY_X0 - 10 then
		return { 6, 18 }
	end
	return { 6, 18, 30 }
end

-- light-streak trail between two attachments on a part
local function addTrail(part: BasePart, a: Vector3, b: Vector3, color: Color3, lifetime: number, transparency: number)
	local a0 = Instance.new("Attachment")
	a0.Position = a
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = b
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = lifetime
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(transparency, 1)
	trail.WidthScale = NumberSequence.new(1, 0.25)
	trail.Parent = part
end

function Cutscene.play()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local rng = Random.new(77)

	local folder = Instance.new("Folder")
	folder.Name = "Cutscene"
	folder.Parent = workspace

	-----------------------------------------------------------------
	-- Post-processing just for the film
	-----------------------------------------------------------------
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0
	dof.NearIntensity = 0.5
	dof.FocusDistance = 30
	dof.InFocusRadius = 20
	dof.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Contrast = 0.12
	grade.Saturation = 0.12
	grade.TintColor = Color3.fromRGB(236, 240, 255)
	grade.Parent = Lighting
	local whip = Instance.new("BlurEffect")
	whip.Size = 0
	whip.Parent = Lighting

	-----------------------------------------------------------------
	-- Hero car (full interior so the cockpit shot shows the hands)
	-----------------------------------------------------------------
	local heroSpec = Cars.get(Cars.CutsceneId)
	local hero = CarBuilder.build(heroSpec, { anchored = true, lights = true, interior = true, underglow = Config.Theme.Accent2 })
	CarSkin.apply(hero, true)
	hero.Parent = folder
	local heroRoot = hero.PrimaryPart :: BasePart
	local heroH = hero:GetAttribute("Height") :: number
	local heroW = hero:GetAttribute("Width") :: number
	local heroL = hero:GetAttribute("Length") :: number
	local dims = CarBuilder.getDims(heroSpec.Class, heroSpec.Id)
	local heroWheels: { Motor6D } = {}
	for _, j in heroRoot:GetChildren() do
		if j:IsA("Motor6D") and j.Name:sub(1, 6) == "Wheel_" then
			table.insert(heroWheels, j)
		end
	end
	-- IK rig (same maths as gameplay)
	local steerMotor = heroRoot:FindFirstChild("SteerMotor") :: Motor6D?
	local steerMount = hero:GetAttribute("SteerMount") :: CFrame?
	local maxRot = (hero:GetAttribute("SteerMaxRot") :: number?) or math.rad(110)
	local eye = (hero:GetAttribute("Eye") :: Vector3?) or Vector3.new(-1.3, 0.8, 0)
	local arms = {}
	for _, side in { "L", "R" } do
		local upper = heroRoot:FindFirstChild("UpperArm" .. side) :: Motor6D?
		local fore = heroRoot:FindFirstChild("ForeArm" .. side) :: Motor6D?
		local shoulder = hero:GetAttribute("Shoulder" .. side) :: Vector3?
		local grip = hero:GetAttribute("Grip" .. side) :: Vector3?
		if upper and fore and shoulder and grip then
			table.insert(arms, { upper = upper, fore = fore, shoulder = shoulder, grip = grip, pole = Vector3.new(if side == "L" then -0.8 else 0.8, -1, 0.2) })
		end
	end
	local upperLen = (hero:GetAttribute("UpperLen") :: number?) or 1.1
	local foreLen = (hero:GetAttribute("ForeLen") :: number?) or 1.05
	local windshield = hero:FindFirstChild("SkinGlass", true) or hero:FindFirstChild("Windshield")

	-- light trails: two tail lights + a wide underglow ribbon + headlight streaks
	local halfH = heroH / 2
	local tailY = dims.belt - 0.25 - halfH
	local rearZ = heroL / 2 + 0.05
	for _, sx in { -1, 1 } do
		addTrail(heroRoot, Vector3.new(sx * (heroW / 2 - 0.6), tailY + 0.12, rearZ), Vector3.new(sx * (heroW / 2 - 0.6), tailY - 0.12, rearZ), Color3.fromRGB(255, 30, 40), 0.45, 0.1)
		addTrail(heroRoot, Vector3.new(sx * (heroW / 2 - 0.9), dims.belt * 0.55 - halfH + 0.1, -heroL / 2), Vector3.new(sx * (heroW / 2 - 0.9), dims.belt * 0.55 - halfH - 0.1, -heroL / 2), Color3.fromRGB(220, 235, 255), 0.18, 0.55)
	end
	addTrail(heroRoot, Vector3.new(-heroW / 2 + 1, dims.clr - halfH - 0.1, heroL / 2 - 2), Vector3.new(heroW / 2 - 1, dims.clr - halfH - 0.1, heroL / 2 - 2), Config.Theme.Accent2, 0.3, 0.45)

	-- exhaust backfire rig
	local exhaustAtt = Instance.new("Attachment")
	exhaustAtt.Position = Vector3.new(0, dims.clr + 0.18 - halfH, heroL / 2 + 0.3)
	exhaustAtt.Parent = heroRoot
	local flames = Instance.new("ParticleEmitter")
	flames.Rate = 0
	flames.EmissionDirection = Enum.NormalId.Back
	flames.Lifetime = NumberRange.new(0.08, 0.18)
	flames.Speed = NumberRange.new(18, 30)
	flames.SpreadAngle = Vector2.new(10, 10)
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	flames.Color = ColorSequence.new(Color3.fromRGB(120, 170, 255), Color3.fromRGB(255, 140, 30))
	flames.LightEmission = 1
	flames.Transparency = NumberSequence.new(0, 1)
	flames.Parent = exhaustAtt
	local flameLight = Instance.new("PointLight")
	flameLight.Color = Color3.fromRGB(255, 150, 60)
	flameLight.Range = 14
	flameLight.Brightness = 0
	flameLight.Shadows = false
	flameLight.Parent = exhaustAtt
	local heroEngine = Audio.engine(heroSpec.Class, heroRoot)
	local function backfire()
		Audio.backfire(heroRoot)
		flames:Emit(26)
		flameLight.Brightness = 6
		task.delay(0.12, function()
			flameLight.Brightness = 0
		end)
	end

	-----------------------------------------------------------------
	-- Scripted traffic
	-----------------------------------------------------------------
	local actors: { Actor } = {}
	local function addActor(x: number, z: number, speed: number, dir: number)
		local spec = CarBuilder.randomTrafficSpec(rng)
		local color = Cars.TrafficColors[rng:NextInteger(1, #Cars.TrafficColors)]
		local m = CarBuilder.build(spec, { anchored = true, driver = true, simpleWheels = true, lite = true, color = color })
		CarSkin.apply(m, true, true)
		local root = m.PrimaryPart :: BasePart
		local h = m:GetAttribute("Height") :: number
		local l = m:GetAttribute("Length") :: number
		-- short streaks so traffic reads as "long exposure" at speed
		local streakColor = if dir == 1 then Color3.fromRGB(255, 30, 30) else Color3.fromRGB(230, 240, 255)
		local zEnd = if dir == 1 then l / 2 else -l / 2
		addTrail(root, Vector3.new(0, 0.35 - h * 0.1, zEnd), Vector3.new(0, 0.05 - h * 0.1, zEnd), streakColor, 0.12, 0.45)
		m.Parent = folder
		table.insert(actors, { model = m, root = root, x = x, z = z, speed = speed, dir = dir, height = h })
	end

	-- the special thread-the-needle row: cars in lanes 6 and 30, gap in lane 18
	-- initial x of a row the hero reaches exactly at THREAD_X:
	-- solves rowX + v_t * (rowX - x0) / (v_h - v_t) = THREAD_X
	local threadRowX = (THREAD_X * (HERO_SPEED - TRAFFIC_SPEED) + TRAFFIC_SPEED * HERO_START_X) / HERO_SPEED

	local prevFree = 18
	local rowX = HERO_START_X + 230
	local threadPlaced = false
	while true do
		local tMeet = (rowX - HERO_START_X) / (HERO_SPEED - TRAFFIC_SPEED)
		local xMeet = rowX + TRAFFIC_SPEED * tMeet
		if xMeet > TUNNEL_X0 - 120 then
			break
		end
		if not threadPlaced and rowX > threadRowX - 160 then
			-- replaces the next regular row; the planner swings into lane 18 for it
			threadPlaced = true
			rowX = threadRowX
			addActor(rowX + 0.5, 6, TRAFFIC_SPEED, 1)
			addActor(rowX - 0.5, 30, TRAFFIC_SPEED, 1)
			prevFree = 18
		else
			local lanes = laneSet(xMeet)
			local options = {}
			for _, l in lanes do
				if l ~= prevFree then
					table.insert(options, l)
				end
			end
			local free = options[rng:NextInteger(1, #options)]
			for _, l in lanes do
				if l ~= free then
					addActor(rowX + rng:NextNumber(-6, 6), l, TRAFFIC_SPEED, 1)
				end
			end
			prevFree = free
		end
		rowX += rng:NextNumber(150, 175)
	end
	for x = HERO_START_X + 300, TUNNEL_X0 + 300, 140 do
		local lanes = if x < HWY_X0 then { -6, -18 } else { -6, -18, -30 }
		addActor(x + rng:NextNumber(-30, 30), lanes[rng:NextInteger(1, #lanes)], ONCOMING_SPEED, -1)
	end

	-----------------------------------------------------------------
	-- Cinematic chrome
	-----------------------------------------------------------------
	local skipped = false
	UI.letterbox(true)
	UI.vignette(true)
	UI.showSkip(function()
		skipped = true
	end)
	local skipConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			skipped = true
		end
	end)

	-----------------------------------------------------------------
	-- Simulation state
	-----------------------------------------------------------------
	local t = 0 -- real time
	local tau = 0 -- story time (slows down in bullet time)
	local heroX, heroZ, heroZVel = HERO_START_X, 18, 0
	local targetLane = 18
	local wheelSpin = 0
	local titleShownAt: number? = nil
	local finished = false
	local lastShot = 1
	local camCF = CFrame.new()
	local camFov = 60
	local smoothLook: Vector3? = nil
	local prevShotCF: CFrame? = nil
	local blendStart = 0
	local blendTime = 0
	local events: { [string]: boolean } = {}

	local function clearance(lane: number): number
		local best = math.huge
		for _, a in actors do
			if a.dir == 1 and math.abs(a.z - lane) < 5 and a.x > heroX - 9 then
				best = math.min(best, a.x - heroX)
			end
		end
		return best
	end
	local function reachable(lane: number): boolean
		local lo, hi = math.min(heroZ, lane) - 3, math.max(heroZ, lane) + 3
		for _, a in actors do
			if a.dir == 1 and math.abs(a.x - heroX) < 17 and a.z > lo and a.z < hi and math.abs(a.z - heroZ) > 3 then
				return false
			end
		end
		return true
	end
	local function shotIndex(time: number): number
		local idx = 1
		for k, start in SHOTS do
			if time >= start then
				idx = k + 1
			end
		end
		return idx
	end
	local function once(name: string): boolean
		if events[name] then
			return false
		end
		events[name] = true
		return true
	end

	local moveParts: { BasePart } = {}
	local moveCFrames: { CFrame } = {}

	local conn = RunService.RenderStepped:Connect(function(rawDt)
		local dt = math.min(rawDt, 1 / 20)
		t += dt
		local ts = timeScale(t)
		local sdt = dt * ts
		tau += sdt

		---------------------------------------------------- world
		table.clear(moveParts)
		table.clear(moveCFrames)
		for _, a in actors do
			a.x += a.speed * a.dir * sdt
			local pos = Vector3.new(a.x, a.height / 2, a.z)
			table.insert(moveParts, a.root)
			table.insert(moveCFrames, CFrame.lookAt(pos, pos + Vector3.new(a.dir, 0, 0)))
		end

		local lanes = laneSet(heroX)
		local current = clearance(targetLane)
		if current < 145 or not table.find(lanes, targetLane) then
			local bestLane, bestClear = targetLane, current
			for _, l in lanes do
				local c = clearance(l)
				if c > bestClear + 10 and reachable(l) then
					bestLane, bestClear = l, c
				end
			end
			targetLane = bestLane
		end
		local w = 6.5
		local accel = w * w * (targetLane - heroZ) - 2 * w * heroZVel
		heroZVel += accel * sdt
		heroZ += heroZVel * sdt
		heroX += HERO_SPEED * sdt

		local heroDir = Vector3.new(HERO_SPEED, 0, heroZVel).Unit
		local heroPos = Vector3.new(heroX, heroH / 2, heroZ)
		local roll = math.clamp(-heroZVel / 400, -0.04, 0.04)
		local heroCF = CFrame.lookAt(heroPos, heroPos + heroDir) * CFrame.Angles(0, 0, roll)
		table.insert(moveParts, heroRoot)
		table.insert(moveCFrames, heroCF)
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)

		-- wheels, steering wheel, hands
		wheelSpin = (wheelSpin - HERO_SPEED * sdt / 1.1) % (math.pi * 2)
		local steer = math.clamp(heroZVel / 45, -1, 1)
		for _, m in heroWheels do
			if m:GetAttribute("Front") then
				m.Transform = CFrame.Angles(0, -steer * 0.22, 0) * CFrame.Angles(wheelSpin, 0, 0)
				local knuckle = heroRoot:FindFirstChild("Knuckle" .. m.Name:sub(6))
				if knuckle and knuckle:IsA("Motor6D") then
					knuckle.Transform = CFrame.Angles(0, -steer * 0.22, 0)
				end
			else
				m.Transform = CFrame.Angles(wheelSpin, 0, 0)
			end
		end
		-- engine: pinned near the top of 6th, pitch follows the story clock so
		-- bullet time drops the whole soundscape down
		heroEngine:update(0.82 + 0.08 * math.sin(t * 1.3), 1, 0.92, math.abs(heroZVel) * 0.6, ts)
		local rot = -steer * maxRot
		if steerMotor then
			steerMotor.Transform = CFrame.Angles(0, 0, rot)
		end
		if steerMount then
			local wheelCF = steerMount * CFrame.Angles(0, 0, rot)
			for _, arm in arms do
				local hand = (wheelCF * CFrame.new(arm.grip)).Position
				local upperCF, foreCF = CarBuilder.solveArm(arm.shoulder, hand, upperLen, foreLen, arm.pole)
				arm.upper.Transform = arm.upper.C0:Inverse() * upperCF
				arm.fore.Transform = arm.fore.C0:Inverse() * foreCF
			end
		end

		---------------------------------------------------- camera
		local shot = shotIndex(t)
		local ground = Vector3.new(heroX, 0, heroZ)
		local heroCenter = heroPos
		local look: Vector3 = heroCenter
		local pos: Vector3
		local fov = 60
		local shake = 0
		local roll2 = 0

		if shot == 1 then
			-- 1: aerial orbit past the tower crown, tilting onto the avenue
			local k = t / SHOTS[1]
			local a = math.rad(200) + k * math.rad(38)
			pos = LEGENDS_TOWER + Vector3.new(math.cos(a) * 250, 790 - k * 50, math.sin(a) * 250)
			local crown = LEGENDS_TOWER + Vector3.new(0, 700, 0)
			local avenue = Vector3.new(heroX + 420, 0, 0)
			look = crown:Lerp(avenue, easeInOutCubic((k - 0.15) / 0.85))
			fov = 52
		elseif shot == 2 then
			-- 2: crane dive to the median, the car whips past
			local k = easeInOutCubic((t - SHOTS[1]) / 2.2)
			local p0 = Vector3.new(760, 170, 0)
			local p1 = Vector3.new(500, 2.3, 0)
			pos = p0:Lerp(p1, k) + Vector3.new(0, math.sin(k * math.pi) * 20, 0)
			look = heroCenter + Vector3.new(0, 1.2, 0)
			fov = 70 - 22 * k
			shake = if heroX > 470 and heroX < 540 then 0.5 else 0.05
		elseif shot == 3 then
			-- 3: low rear three-quarter bumper rig
			pos = (heroCF * CFrame.new(3.1, -halfH + 1.1, 8.8)).Position
			look = (heroCF * CFrame.new(-0.6, 0.4, -40)).Position
			fov = 80
			shake = 0.18
			roll2 = roll * 3
		elseif shot == 4 then
			-- 4: side dolly under the monorail
			local k = t - SHOTS[3]
			pos = ground + Vector3.new(7 - k * 9, 2.1, 0)
			pos = Vector3.new(pos.X, pos.Y, math.min(heroZ + 13, 36))
			look = heroCenter + Vector3.new(5, 0.4, 0)
			fov = 56
			shake = 0.12
		elseif shot == 5 then
			-- 5: bullet time orbit
			local k = smooth((t - SHOTS[4]) / (SHOTS[5] - SHOTS[4]))
			local a = math.rad(-115) + k * math.rad(175)
			local flatDir = Vector3.new(heroDir.X, 0, heroDir.Z).Unit
			local side = flatDir:Cross(Vector3.yAxis)
			local offset = (flatDir * math.cos(a) + side * math.sin(a)) * 13.5
			-- high enough to clear the roofs of the cars being threaded (SUVs are ~6 tall)
			pos = heroCenter + offset + Vector3.new(0, 4.8 + math.sin(k * math.pi) * 1.6, 0)
			look = heroCenter + Vector3.new(0, 0.3, 0)
			fov = 46
		elseif shot == 6 then
			-- 6: over the driver's shoulder
			pos = (heroCF * CFrame.new(eye + Vector3.new(0.75, 0.25, 1.2))).Position
			look = (heroCF * CFrame.new(eye + Vector3.new(0.3, -0.35, -25))).Position
			fov = 72
			shake = 0.06
		elseif shot == 7 then
			-- 7: drone towards the mountain
			local k = t - SHOTS[6]
			pos = ground + Vector3.new(-54 + k * 3, 27 - k * 2, -20)
			look = ground + Vector3.new(130, 2, 0)
			fov = 66
		else
			-- 8: tunnel, under the sign
			local k = t - SHOTS[7]
			local camX = TUNNEL_MID - 178 + k * 14
			pos = Vector3.new(camX, 4.2, -10)
			look = heroCenter
			if heroX > camX + 8 then
				local blend = math.clamp((heroX - camX - 8) / 90, 0, 1)
				look = heroCenter:Lerp(SIGN_POS, blend * 0.6)
			end
			fov = 60
			if titleShownAt then
				fov = 60 - 14 * smooth((t - titleShownAt) / 3.5)
			end
			if not titleShownAt and heroX > SIGN_POS.X - 40 then
				titleShownAt = t
				UI.whiteFlash(0.35, 0.6)
				Audio.boom(0.75)
				UI.cinematicTitle("CITY LEGENDS", "CUT UP  ·  GET PAID  ·  BECOME A LEGEND")
			end
		end

		-- smooth look target inside a shot, snap on cuts
		local isCut = shot ~= lastShot
		if isCut then
			-- cut events
			if shot == 2 or shot == 3 or shot == 7 or shot == 8 then
				whip.Size = 22
				Audio.whoosh(0.35, 2.1)
			end
			if shot == 5 then
				UI.whiteFlash(0.25, 0.35)
				Audio.boom(0.35)
			elseif shot == 6 then
				UI.whiteFlash(0.55, 0.5)
				backfire()
				task.delay(0.18, backfire)
			end
			if shot == 4 then
				-- shots 3 -> 4 blend instead of cutting
				prevShotCF = camCF
				blendStart = t
				blendTime = 0.45
			else
				prevShotCF = nil
			end
			smoothLook = look
			lastShot = shot
		end
		smoothLook = (smoothLook or look):Lerp(look, 1 - math.exp(-dt * 14))
		local target = CFrame.lookAt(pos, smoothLook :: Vector3) * CFrame.Angles(0, 0, roll2)
		if prevShotCF and t - blendStart < blendTime then
			target = (prevShotCF :: CFrame):Lerp(target, smooth((t - blendStart) / blendTime))
		end
		-- handheld shake
		if shake > 0 then
			local n = Vector3.new(math.noise(t * 9, 1.3), math.noise(t * 11, 7.1), math.noise(t * 7, 3.7))
			target *= CFrame.Angles(n.X * 0.012 * shake, n.Y * 0.012 * shake, n.Z * 0.008 * shake) + n * 0.15 * shake
		end
		camCF = target
		camFov += (fov - camFov) * math.min(1, dt * 10)
		if isCut then
			camFov = fov
		end
		camera.CFrame = camCF
		camera.FieldOfView = camFov

		---------------------------------------------------- lens
		local focus = (camCF.Position - heroCenter).Magnitude
		dof.FocusDistance = focus
		dof.InFocusRadius = math.max(6, focus * 0.35)
		dof.FarIntensity = if shot == 1 then 0 elseif shot == 8 and titleShownAt then 0.15 else 0.4
		whip.Size = math.max(0, whip.Size - dt * 90)
		-- desaturate during bullet time
		grade.Saturation = 0.12 - 0.35 * (1 - ts) / (1 - SLOW_SCALE)
		if windshield and windshield:IsA("BasePart") then
			windshield.LocalTransparencyModifier = if shot == 6 then 0.7 else 0
		end

		---------------------------------------------------- captions
		if t > 0.7 and once("cap1") then
			UI.caption("DOWNTOWN", "02:14 AM  ·  71°F  ·  LIGHT TRAFFIC")
		end
		if t > 3.6 and once("cap1off") then
			UI.hideCaption()
		end
		if t > 11.8 and once("cap2") then
			UI.caption("ROUTE 9", "OUTBOUND  ·  NO SPEED LIMIT TONIGHT")
		end
		if t > 13.4 and once("cap2off") then
			UI.hideCaption()
		end

		-- the car screaming past the crane camera and the tunnel camera
		if shot == 2 and heroX > 455 and once("passA") then
			Audio.passBy(0.9)
		end
		if shot == 8 and heroX > TUNNEL_MID - 205 and once("passB") then
			Audio.passBy(0.8)
		end
		if titleShownAt and t - titleShownAt > 4 then
			finished = true
		end
		if heroX > TUNNEL_X0 + C.TunnelLength + 500 then
			finished = true
		end
	end)

	-- opening fade in
	UI.fade(true, 0.01)
	UI.hideLoading()
	UI.fade(false, 1.4)

	while not finished and not skipped do
		task.wait()
	end
	UI.fade(true, if skipped then 0.35 else 1.0)

	conn:Disconnect()
	skipConn:Disconnect()
	UI.hideSkip()
	UI.hideTitle()
	UI.hideCaption()
	UI.letterbox(false)
	UI.vignette(false)
	heroEngine:destroy()
	dof:Destroy()
	grade:Destroy()
	whip:Destroy()
	folder:Destroy()
end

return Cutscene
