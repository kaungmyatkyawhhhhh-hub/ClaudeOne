--[[
	Cutscene (client)
	Intro cinematic: a hypercar cuts up through traffic down the main avenue,
	blasts onto the highway and into the mountain tunnel, passing under the
	glowing CITY LEGENDS sign while the title card lands.

	Everything here is local-only: the hero car and the scripted traffic are
	built on the client and destroyed afterwards. The hero picks its lanes with
	a small planner (always aim for the lane with the most free space ahead)
	and moves sideways with a critically damped spring, so the weaving looks
	like a real driver cutting up.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local UI = require(script.Parent:WaitForChild("UI"))

local Cutscene = {}

local C = Config.City
local HWY_X0 = CityLayout.HighwayStartX
local TUNNEL_X0 = HWY_X0 + C.TunnelStart
local TUNNEL_MID = TUNNEL_X0 + C.TunnelLength / 2
local SIGN_POS = Vector3.new(TUNNEL_MID, 22 - 7.5, 0)

local HERO_START_X = -850
local HERO_SPEED = 230
local TRAFFIC_SPEED = 75
local ONCOMING_SPEED = 85

type Actor = { model: Model, root: BasePart, x: number, z: number, speed: number, dir: number, height: number }

local function laneSet(x: number): { number }
	if x < HWY_X0 - 10 then
		return { 6, 18 }
	end
	return { 6, 18, 30 }
end

function Cutscene.play()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local rng = Random.new(77)

	local folder = Instance.new("Folder")
	folder.Name = "Cutscene"
	folder.Parent = workspace

	-----------------------------------------------------------------
	-- Hero
	-----------------------------------------------------------------
	local heroSpec = Cars.get(Cars.CutsceneId)
	local hero = CarBuilder.build(heroSpec, { anchored = true, lights = true, driver = true, underglow = Config.Theme.Accent2 })
	hero.Parent = folder
	local heroRoot = hero.PrimaryPart :: BasePart
	local heroH = hero:GetAttribute("Height") :: number
	local heroWheels: { Motor6D } = {}
	for _, j in heroRoot:GetChildren() do
		if j:IsA("Motor6D") and j.Name:sub(1, 6) == "Wheel_" then
			table.insert(heroWheels, j)
		end
	end

	-----------------------------------------------------------------
	-- Scripted traffic
	-----------------------------------------------------------------
	local actors: { Actor } = {}
	local function addActor(x: number, z: number, speed: number, dir: number)
		local spec = CarBuilder.randomTrafficSpec(rng)
		local color = Cars.TrafficColors[rng:NextInteger(1, #Cars.TrafficColors)]
		local m = CarBuilder.build(spec, { anchored = true, driver = true, simpleWheels = true, lite = true, color = color })
		m.Parent = folder
		table.insert(actors, {
			model = m,
			root = m.PrimaryPart :: BasePart,
			x = x,
			z = z,
			speed = speed,
			dir = dir,
			height = m:GetAttribute("Height") :: number,
		})
	end

	-- Rows of eastbound traffic, always leaving exactly one lane open
	local prevFree = 18
	local rowX = HERO_START_X + 230
	while true do
		local tMeet = (rowX - HERO_START_X) / (HERO_SPEED - TRAFFIC_SPEED)
		local xMeet = rowX + TRAFFIC_SPEED * tMeet
		if xMeet > TUNNEL_X0 - 120 then
			break
		end
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
		rowX += rng:NextNumber(150, 175)
	end
	-- Oncoming westbound traffic
	for x = HERO_START_X + 300, TUNNEL_X0 + 300, 150 do
		local lanes = if x < HWY_X0 then { -6, -18 } else { -6, -18, -30 }
		addActor(x + rng:NextNumber(-30, 30), lanes[rng:NextInteger(1, #lanes)], ONCOMING_SPEED, -1)
	end

	-----------------------------------------------------------------
	-- Cinematic setup
	-----------------------------------------------------------------
	local skipped = false
	UI.letterbox(true)
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

	local heroX, heroZ, heroZVel = HERO_START_X, 18, 0
	local targetLane = 18
	local wheelSpin = 0
	local t = 0
	local titleShownAt: number? = nil
	local finished = false
	local shotF_t: number? = nil

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

	local moveParts: { BasePart } = {}
	local moveCFrames: { CFrame } = {}

	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		t += dt

		-- traffic
		table.clear(moveParts)
		table.clear(moveCFrames)
		for _, a in actors do
			a.x += a.speed * a.dir * dt
			local pos = Vector3.new(a.x, a.height / 2, a.z)
			table.insert(moveParts, a.root)
			table.insert(moveCFrames, CFrame.lookAt(pos, pos + Vector3.new(a.dir, 0, 0)))
		end

		-- hero lane planner
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
		-- critically damped lateral spring
		local w = 6.5
		local accel = w * w * (targetLane - heroZ) - 2 * w * heroZVel
		heroZVel += accel * dt
		heroZ += heroZVel * dt
		heroX += HERO_SPEED * dt

		local heroDir = Vector3.new(HERO_SPEED, 0, heroZVel).Unit
		local heroPos = Vector3.new(heroX, heroH / 2, heroZ)
		local roll = math.clamp(-heroZVel / 400, -0.04, 0.04)
		local heroCF = CFrame.lookAt(heroPos, heroPos + heroDir) * CFrame.Angles(0, 0, roll)
		table.insert(moveParts, heroRoot)
		table.insert(moveCFrames, heroCF)
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)

		wheelSpin = (wheelSpin - HERO_SPEED * dt / 1.1) % (math.pi * 2)
		local steerVisual = math.clamp(heroZVel / 60, -1, 1)
		for _, m in heroWheels do
			if m:GetAttribute("Front") then
				m.Transform = CFrame.Angles(0, -steerVisual * 0.25, 0) * CFrame.Angles(wheelSpin, 0, 0)
			else
				m.Transform = CFrame.Angles(wheelSpin, 0, 0)
			end
		end

		-------------------------------------------------------------
		-- Camera shots
		-------------------------------------------------------------
		local camCF: CFrame
		local fov: number
		local ground = Vector3.new(heroX, 0, heroZ)
		if t < 2.6 then
			-- A: low roadside shot, car whips past
			local camPos = Vector3.new(HERO_START_X + 430, 2.4, 32)
			camCF = CFrame.lookAt(camPos, ground + Vector3.new(0, 1.5, 0))
			fov = 42
		elseif t < 5.8 then
			-- B: low chase, wide lens
			local back = heroCF * CFrame.new(0, 1.6, 15)
			camCF = CFrame.lookAt(back.Position, (heroCF * CFrame.new(0, 0.5, -30)).Position) * CFrame.Angles(0, 0, roll * 2)
			fov = 82
		elseif t < 8.4 then
			-- C: side tracking shot at wheel height, oncoming traffic flashing behind
			local k = t - 5.8
			local camPos = ground + Vector3.new(3 - k * 2.2, 2.2, -12.5)
			camCF = CFrame.lookAt(camPos, ground + Vector3.new(2, 1.2, 0))
			fov = 58
		elseif t < 10.6 then
			-- D: front reverse shot looking back at the car cutting through
			local camPos = ground + Vector3.new(26, 3.4, 4 - heroZ * 0.25)
			camCF = CFrame.lookAt(camPos, ground + Vector3.new(0, 1.4, 0))
			fov = 52
		elseif heroX < TUNNEL_X0 - 140 then
			-- E: drone shot towards the mountain tunnel
			local camPos = ground + Vector3.new(-48, 22, -16)
			camCF = CFrame.lookAt(camPos, ground + Vector3.new(90, 0, 0))
			fov = 68
		else
			-- F: inside the tunnel, the car flies past and under the sign
			shotF_t = shotF_t or t
			local k = t - (shotF_t :: number)
			local camX = TUNNEL_MID - 165 + k * 18
			local camPos = Vector3.new(camX, 4.2, -10)
			local look = ground + Vector3.new(0, 2, 0)
			if heroX > camX + 8 then
				local blend = math.clamp((heroX - camX - 8) / 90, 0, 1)
				look = look:Lerp(SIGN_POS, blend * 0.55)
			end
			camCF = CFrame.lookAt(camPos, look)
			fov = 60
			if not titleShownAt and heroX > SIGN_POS.X - 40 then
				titleShownAt = t
				UI.showTitle("CITY LEGENDS", "CUT UP  ·  GET PAID  ·  BECOME A LEGEND")
			end
		end
		camera.CFrame = camCF
		camera.FieldOfView = fov

		if titleShownAt and t - titleShownAt > 3.6 then
			finished = true
		end
		if heroX > TUNNEL_X0 + C.TunnelLength + 400 then
			finished = true
		end
	end)

	-- opening fade in
	UI.fade(true, 0.01)
	UI.hideLoading()
	UI.fade(false, 1.2)

	while not finished and not skipped do
		task.wait()
	end
	UI.fade(true, if skipped then 0.35 else 0.9)

	conn:Disconnect()
	skipConn:Disconnect()
	UI.hideSkip()
	UI.hideTitle()
	UI.letterbox(false)
	folder:Destroy()
end

return Cutscene
