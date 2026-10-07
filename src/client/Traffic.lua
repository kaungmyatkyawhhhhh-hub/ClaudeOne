--[[
	Traffic (client)
	Smart NPC traffic simulated locally on every client for buttery-smooth motion.
	Each car:
	  * follows the lane graph (lanes + bezier turns through intersections)
	  * stops on red, decides whether it can stop on yellow, resumes on green
	    (lights are computed from synced server time so all clients agree)
	  * keeps a safe following distance to NPCs *and* player cars, brakes hard
	    when you cut in front of it, shows brake lights
	  * slows for turns, and un-sticks itself if it ever gets gridlocked
	Far-away cars are recycled to just out of sight around the player so the
	streets near you always feel busy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cars = require(Shared:WaitForChild("Cars"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local T = Config.Traffic
local TURN_SPEED = Config.mphToSps(T.TurnSpeedMph)
local BRAKE_ON = Color3.fromRGB(255, 25, 25)
local BRAKE_OFF = Color3.fromRGB(150, 0, 6)

export type Npc = {
	model: Model,
	root: BasePart,
	seg: CityLayout.Segment,
	nextSeg: CityLayout.Segment?,
	s: number,
	speed: number,
	maxSpeed: number,
	halfLen: number,
	width: number,
	height: number,
	pos: Vector3,
	fwd: Vector3,
	stuck: number,
	ghost: number,
	braking: boolean,
	tails: { BasePart },
}

type Obstacle = { pos: Vector3, fwd: Vector3, speed: number, halfLen: number, width: number, self: Npc? }

local Traffic = {}
Traffic.cars = {} :: { Npc }

local rng = Random.new()
local graph = CityLayout.buildGraph()
local folder: Folder? = nil
local running = false
local recycleTimer = 0
local focusGetter: (() -> Vector3?)? = nil

local function chooseNext(seg: CityLayout.Segment): CityLayout.Segment?
	local options = seg.next
	if #options == 0 then
		return nil
	end
	if seg.kind == "turn" then
		return options[1]
	end
	-- prefer going straight (weight 3) over turning (weight 1)
	local total = 0
	for _, o in options do
		total += if o.dir == seg.dir then 3 else 1
	end
	local r = rng:NextNumber() * total
	for _, o in options do
		r -= if o.dir == seg.dir then 3 else 1
		if r <= 0 then
			return o
		end
	end
	return options[#options]
end

local function placeNpc(npc: Npc, seg: CityLayout.Segment, s: number)
	npc.seg = seg
	npc.s = s
	npc.nextSeg = chooseNext(seg)
	npc.stuck = 0
	npc.ghost = 0
	local pos, fwd = CityLayout.sample(seg, s)
	npc.pos = pos
	npc.fwd = fwd
end

local function isFree(pos: Vector3, radius: number, ignore: Npc?): boolean
	for _, other in Traffic.cars do
		if other ~= ignore and (other.pos - pos).Magnitude < radius then
			return false
		end
	end
	for _, car in Traffic.playerCars() do
		if (car.pos - pos).Magnitude < radius + 10 then
			return false
		end
	end
	return true
end

-- Lane position near "center" (or anywhere if center == nil)
local function findSpot(center: Vector3?, minDist: number, maxDist: number, ignore: Npc?, avoidView: boolean?): (CityLayout.Segment?, number)
	local camera = workspace.CurrentCamera
	for _ = 1, 40 do
		local seg = graph.lanes[rng:NextInteger(1, #graph.lanes)]
		local s = rng:NextNumber(8, math.max(9, seg.length - 25))
		local pos = CityLayout.sample(seg, s)
		local ok = true
		if center then
			local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
			ok = d >= minDist and d <= maxDist
			if ok and avoidView and camera then
				local toPos = (pos - camera.CFrame.Position).Unit
				if toPos:Dot(camera.CFrame.LookVector) > 0.55 and d < 380 then
					ok = false
				end
			end
		end
		if ok and isFree(pos, 22, ignore) then
			return seg, s
		end
	end
	return nil, 0
end

local function setBrake(npc: Npc, on: boolean)
	if npc.braking == on then
		return
	end
	npc.braking = on
	for _, t in npc.tails do
		t.Color = if on then BRAKE_ON else BRAKE_OFF
	end
end

local function spawnNpc(center: Vector3?): Npc?
	local seg, s = findSpot(center, 0, if center then 700 else math.huge, nil, false)
	if not seg then
		return nil
	end
	local spec = CarBuilder.randomTrafficSpec(rng)
	local color = Cars.TrafficColors[rng:NextInteger(1, #Cars.TrafficColors)]
	local model = CarBuilder.build(spec, { anchored = true, driver = true, simpleWheels = true, lite = true, color = color })
	local tails = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("TailLight") then
			table.insert(tails, d)
		end
	end
	local npc: Npc = {
		model = model,
		root = model.PrimaryPart :: BasePart,
		seg = seg,
		nextSeg = nil,
		s = s,
		speed = 0,
		maxSpeed = Config.mphToSps(rng:NextNumber(T.MinSpeedMph, T.MaxSpeedMph)),
		halfLen = (model:GetAttribute("Length") :: number) / 2,
		width = model:GetAttribute("Width") :: number,
		height = model:GetAttribute("Height") :: number,
		pos = Vector3.zero,
		fwd = Vector3.zAxis,
		stuck = 0,
		ghost = 0,
		braking = false,
		tails = tails,
	}
	placeNpc(npc, seg, s)
	npc.speed = npc.maxSpeed * 0.7
	model:PivotTo(CFrame.lookAt(npc.pos, npc.pos + npc.fwd) + Vector3.new(0, npc.height / 2, 0))
	model.Parent = folder
	table.insert(Traffic.cars, npc)
	return npc
end

-- Player cars as obstacles (replicated models in workspace.PlayerCars)
local playerCarCache: { Obstacle } = {}
function Traffic.playerCars(): { Obstacle }
	return playerCarCache
end

local function refreshPlayerCars()
	table.clear(playerCarCache)
	local pc = workspace:FindFirstChild("PlayerCars")
	if not pc then
		return
	end
	for _, model in pc:GetChildren() do
		if model:IsA("Model") and model.PrimaryPart then
			local root = model.PrimaryPart
			local v = root.AssemblyLinearVelocity
			local flatV = Vector3.new(v.X, 0, v.Z)
			local look = root.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			table.insert(playerCarCache, {
				pos = Vector3.new(root.Position.X, 0, root.Position.Z),
				fwd = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.zAxis,
				speed = flatV.Magnitude,
				halfLen = ((model:GetAttribute("Length") :: number?) or 14) / 2,
				width = (model:GetAttribute("Width") :: number?) or 6,
			})
		end
	end
end

function Traffic.start(count: number?, focus: (() -> Vector3?)?)
	if running then
		return
	end
	running = true
	focusGetter = focus
	local f = Instance.new("Folder")
	f.Name = "Traffic"
	f.Parent = workspace
	folder = f
	refreshPlayerCars()
	local center = if focus then focus() else nil
	local total = count or T.CarCount
	for k = 1, total do
		-- most cars around the player, some spread through the city
		spawnNpc(if k % 4 ~= 0 then center else nil)
		if k % 10 == 0 then
			task.wait()
		end
	end
end

function Traffic.stop()
	running = false
	for _, npc in Traffic.cars do
		npc.model:Destroy()
	end
	table.clear(Traffic.cars)
	if folder then
		folder:Destroy()
		folder = nil
	end
end

local function lookAheadGap(npc: Npc, obstacles: { Obstacle }): (number, number, number)
	-- returns the bumper-to-bumper gap to the nearest thing in our path and its speed along our heading
	local fwd = npc.fwd
	local right = fwd:Cross(Vector3.yAxis)
	local best, bestSpeed, bestAlign = math.huge, 0, 1
	for _, o in obstacles do
		if o.self ~= npc then
			local rel = o.pos - npc.pos
			local f = rel:Dot(fwd)
			if f > 0 and f < T.LookAhead then
				local lat = math.abs(rel:Dot(right))
				if lat < (npc.width + o.width) / 2 + 0.9 then
					local gap = f - npc.halfLen - o.halfLen
					if gap < best then
						best = gap
						bestSpeed = math.max(0, o.speed * o.fwd:Dot(fwd))
						bestAlign = o.fwd:Dot(fwd)
					end
				end
			end
		end
	end
	return best, bestSpeed, bestAlign
end

-- Left turns cross oncoming traffic: wait at the line until the oncoming lanes are clear
local function leftOf(dir: number): number
	return ((dir + 2) % 4) + 1
end

local function mustYieldLeft(npc: Npc, seg: CityLayout.Segment): boolean
	local oncoming = ((seg.dir + 1) % 4) + 1
	for _, o in Traffic.cars do
		if o ~= npc and o.seg.i == seg.i and o.seg.j == seg.j then
			local os = o.seg
			if os.kind == "lane" and os.dir == oncoming and os.length - o.s < 75 and o.speed > 2 then
				local oNext = o.nextSeg
				-- an oncoming car that is also turning left does not conflict
				if not (oNext and oNext.turning and oNext.dir == leftOf(oncoming)) then
					return true
				end
			elseif os.kind == "turn" and not os.turning and os.dir == oncoming then
				return true -- oncoming car already crossing the junction
			end
		end
	end
	local center = CityLayout.intersectionPos(seg.i, seg.j)
	for _, pc in playerCarCache do
		if (pc.pos - center).Magnitude < 45 and pc.speed > 3 then
			return true
		end
	end
	return false
end

local obstacleList: { Obstacle } = {}
local npcObstacle: { [Npc]: Obstacle } = setmetatable({}, { __mode = "k" }) :: any
local frameCount = 0
local movedParts: { BasePart } = {}
local movedCFrames: { CFrame } = {}

function Traffic.update(dt: number)
	if not running or #Traffic.cars == 0 then
		return
	end
	dt = math.min(dt, 0.1)
	refreshPlayerCars()
	local now = workspace:GetServerTimeNow()

	-- reuse one obstacle record per NPC instead of allocating every frame
	table.clear(obstacleList)
	for _, npc in Traffic.cars do
		local o = npcObstacle[npc]
		if not o then
			o = { pos = npc.pos, fwd = npc.fwd, speed = 0, halfLen = npc.halfLen, width = npc.width, self = npc }
			npcObstacle[npc] = o
		end
		o.pos = npc.pos
		o.fwd = npc.fwd
		o.speed = npc.speed
		table.insert(obstacleList, o)
	end
	for _, pc in playerCarCache do
		table.insert(obstacleList, pc)
	end

	table.clear(movedParts)
	table.clear(movedCFrames)
	frameCount += 1
	local camPos = if workspace.CurrentCamera then workspace.CurrentCamera.CFrame.Position else Vector3.zero

	for _idx, npc in Traffic.cars do
		local seg = npc.seg
		local target = npc.maxSpeed
		local remaining = seg.length - npc.s

		if seg.kind == "turn" then
			if seg.turning then
				target = math.min(target, TURN_SPEED)
			end
		else
			-- slow down before a turn
			local nxt = npc.nextSeg
			if nxt and nxt.dir ~= seg.dir then
				target = math.min(target, math.sqrt(TURN_SPEED * TURN_SPEED + 2 * T.Brake * 0.5 * math.max(remaining, 0)))
			end
			-- traffic light at the end of this lane
			local state = CityLayout.lightState(seg.i, seg.j, seg.axis, now)
			if state ~= "G" then
				local stopDist = remaining - 0.5
				local mustStop = state == "R"
				if state == "Y" then
					-- stop only if we can do it comfortably, otherwise clear the junction
					local needed = (npc.speed * npc.speed) / (2 * T.Brake * 0.6)
					mustStop = stopDist > needed
				end
				if mustStop and stopDist > -2 then
					if stopDist < 0.3 then
						target = 0
					else
						target = math.min(target, math.sqrt(2 * T.Brake * 0.6 * stopDist))
					end
				end
			end
		end

		-- yield before turning left across oncoming traffic
		if seg.kind == "lane" then
			local nxt = npc.nextSeg
			if nxt and nxt.turning and nxt.dir == leftOf(seg.dir) and remaining < 30 and mustYieldLeft(npc, seg) then
				local stopDist = remaining - 0.5
				target = if stopDist < 0.3 then 0 else math.min(target, math.sqrt(2 * T.Brake * 0.6 * stopDist))
			end
		end

		-- cars / players ahead
		local crossBlocked = false
		if npc.ghost <= 0 then
			local gap, otherSpeed, align = lookAheadGap(npc, obstacleList)
			crossBlocked = gap < math.huge and align < 0.7
			if gap < math.huge then
				local safe = gap - T.StopGap
				if safe <= 0 then
					target = 0
				else
					target = math.min(target, math.sqrt(2 * T.Brake * 0.7 * safe + otherSpeed * otherSpeed))
				end
			end
		else
			npc.ghost -= dt
		end

		-- integrate speed
		if npc.speed < target then
			npc.speed = math.min(target, npc.speed + T.Accel * dt)
		else
			local decel = if npc.speed - target > 18 then T.EmergencyBrake else T.Brake
			npc.speed = math.max(target, npc.speed - decel * dt)
		end
		setBrake(npc, target < npc.speed - 0.5 or npc.speed < 0.5)

		-- gridlock breaker: only for a true deadlock with crossing traffic,
		-- never for a normal queue or a car waiting at a light
		if npc.speed < 0.5 and crossBlocked then
			npc.stuck += dt
			if npc.stuck > T.StuckTime then
				npc.ghost = 2.5
				npc.stuck = 0
			end
		else
			npc.stuck = 0
		end

		-- advance along the path
		npc.s += npc.speed * dt
		while npc.s >= npc.seg.length do
			npc.s -= npc.seg.length
			local nxt = npc.nextSeg
			if not nxt then
				npc.s = 0
				break
			end
			npc.seg = nxt
			npc.nextSeg = chooseNext(nxt)
		end

		local pos, fwd = CityLayout.sample(npc.seg, npc.s)
		npc.pos = pos
		npc.fwd = fwd
		-- far-away cars only need their transform pushed every 3rd frame
		local far = (pos - camPos).Magnitude > 380
		if not far or (frameCount + _idx) % 3 == 0 then
			local up = Vector3.new(0, npc.height / 2, 0)
			table.insert(movedParts, npc.root)
			table.insert(movedCFrames, CFrame.lookAt(pos + up, pos + up + fwd))
		end
	end

	workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)

	-- recycle far cars to just out of sight around the focus point
	recycleTimer += dt
	if recycleTimer > 0.5 and focusGetter then
		recycleTimer = 0
		local focus = focusGetter()
		if focus then
			local flatFocus = Vector3.new(focus.X, 0, focus.Z)
			local moved = 0
			for _, npc in Traffic.cars do
				if moved >= 3 then
					break
				end
				if (npc.pos - flatFocus).Magnitude > T.RecycleDistance then
					local seg, s = findSpot(flatFocus, T.RespawnMin, T.RespawnMax, npc, true)
					if seg then
						placeNpc(npc, seg, s)
						npc.speed = npc.maxSpeed * 0.8
						moved += 1
					end
				end
			end
		end
	end
end

-- Move NPCs out of the way (used when a player car spawns)
function Traffic.clearAround(pos: Vector3, radius: number)
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, npc in Traffic.cars do
		if (npc.pos - flat).Magnitude < radius then
			local seg, s = findSpot(flat, T.RespawnMin, T.RespawnMax, npc, true)
			if seg then
				placeNpc(npc, seg, s)
			end
		end
	end
end

-- Cars currently near a point (used for cut-up detection)
function Traffic.near(pos: Vector3, radius: number): { Npc }
	local out = {}
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, npc in Traffic.cars do
		if (npc.pos - flat).Magnitude < radius then
			table.insert(out, npc)
		end
	end
	return out
end

return Traffic
