--[[
	CityLayout
	Pure maths shared by server (building the city) and client (traffic AI):
	  * grid / road coordinates
	  * deterministic traffic-light phases (driven by synced server time, so every
	    client sees the same lights at the same moment)
	  * the lane graph that NPC cars drive on (lanes + turn connectors as
	    quadratic bezier curves)
]]

local Config = require(script.Parent.Config)

local CityLayout = {}

local C = Config.City
local N = C.Blocks
local HALF_ROAD = C.RoadWidth / 2

CityLayout.N = N
CityLayout.HalfRoad = HALF_ROAD
CityLayout.StopLineGap = 3

-- 1 = East(+X), 2 = South(+Z), 3 = West(-X), 4 = North(-Z)
CityLayout.Dirs = {
	Vector3.new(1, 0, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 0, -1),
}
local DI = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }

function CityLayout.roadCoord(i: number): number
	return (i - N / 2) * C.BlockSize
end

function CityLayout.intersectionPos(i: number, j: number): Vector3
	return Vector3.new(CityLayout.roadCoord(i), 0, CityLayout.roadCoord(j))
end

function CityLayout.inGrid(i: number, j: number): boolean
	return i >= 0 and i <= N and j >= 0 and j <= N
end

function CityLayout.laneOffset(lane: number): number
	return C.LaneWidth * (lane - 0.5)
end

-- the east-side intersection where the highway leaves the city
CityLayout.HighwayJ = math.floor(N / 2)
CityLayout.HighwayStartX = CityLayout.roadCoord(N) + HALF_ROAD

---------------------------------------------------------------------
-- Monorail loop (rounded square around the city, shared by server + client)
---------------------------------------------------------------------
local function monorailDims(): (number, number, number)
	local R = C.HalfExtent + HALF_ROAD + Config.Monorail.Offset
	local rc = Config.Monorail.CornerRadius
	local side = 2 * (R - rc)
	return R, rc, side
end

function CityLayout.monorailLength(): number
	local _, rc, side = monorailDims()
	return 4 * side + 2 * math.pi * rc
end

-- Position (at track height) and travel direction at distance s along the loop
function CityLayout.monorailSample(s: number): (Vector3, Vector3)
	local R, rc, side = monorailDims()
	local arc = math.pi / 2 * rc
	local h = Config.Monorail.Height
	local c = R - rc
	s = s % CityLayout.monorailLength()
	-- side starts / directions, then the corner after each side
	local sides = {
		{ Vector3.new(R, h, -c), Vector3.new(0, 0, 1), Vector3.new(c, h, c), 0 },
		{ Vector3.new(c, h, R), Vector3.new(-1, 0, 0), Vector3.new(-c, h, c), math.pi / 2 },
		{ Vector3.new(-R, h, c), Vector3.new(0, 0, -1), Vector3.new(-c, h, -c), math.pi },
		{ Vector3.new(-c, h, -R), Vector3.new(1, 0, 0), Vector3.new(c, h, -c), math.pi * 1.5 },
	}
	for _, sd in sides do
		if s <= side then
			return sd[1] + sd[2] * s, sd[2]
		end
		s -= side
		if s <= arc then
			local a = sd[4] + s / rc
			return sd[3] + Vector3.new(math.cos(a), 0, math.sin(a)) * rc, Vector3.new(-math.sin(a), 0, math.cos(a))
		end
		s -= arc
	end
	return sides[1][1], sides[1][2]
end

---------------------------------------------------------------------
-- Traffic lights
---------------------------------------------------------------------
-- axis: "X" for traffic moving along X (east/west), "Z" otherwise
function CityLayout.lightState(i: number, j: number, axis: string, t: number): string
	local L = Config.Lights
	local half = L.Green + L.Yellow + L.AllRed
	local offset = ((i + j) % 4) * (L.Cycle / 4)
	local ph = (t + offset) % L.Cycle
	local localT = if axis == "X" then ph else (ph - half) % L.Cycle
	if localT < L.Green then
		return "G"
	elseif localT < L.Green + L.Yellow then
		return "Y"
	end
	return "R"
end

-- time left in the current state (used so cars can decide to run a yellow)
function CityLayout.lightTimeLeft(i: number, j: number, axis: string, t: number): number
	local L = Config.Lights
	local half = L.Green + L.Yellow + L.AllRed
	local offset = ((i + j) % 4) * (L.Cycle / 4)
	local ph = (t + offset) % L.Cycle
	local localT = if axis == "X" then ph else (ph - half) % L.Cycle
	if localT < L.Green then
		return L.Green - localT
	elseif localT < L.Green + L.Yellow then
		return L.Green + L.Yellow - localT
	end
	return L.Cycle - localT
end

---------------------------------------------------------------------
-- Lane graph
---------------------------------------------------------------------
export type Segment = {
	id: number,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	length: number,
	kind: string, -- "lane" | "turn"
	i: number, -- intersection this lane leads to (lanes) / is inside (turns)
	j: number,
	axis: string,
	dir: number,
	lane: number,
	turning: boolean, -- connector that changes direction
	next: { Segment },
	samples: { number }, -- cumulative arc length per sample (for turns)
}

local SAMPLES = 12

local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

local function bezierTangent(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	return (p1 - p0) * (2 * (1 - t)) + (p2 - p1) * (2 * t)
end

local function newSegment(list: { Segment }, p0: Vector3, p1: Vector3, p2: Vector3, kind: string): Segment
	local samples = { 0 }
	local total = 0
	local prev = p0
	for k = 1, SAMPLES do
		local pt = bezier(p0, p1, p2, k / SAMPLES)
		total += (pt - prev).Magnitude
		samples[k + 1] = total
		prev = pt
	end
	local seg: Segment = {
		id = #list + 1,
		p0 = p0,
		p1 = p1,
		p2 = p2,
		length = total,
		kind = kind,
		i = 0,
		j = 0,
		axis = "X",
		dir = 1,
		lane = 1,
		turning = false,
		next = {},
		samples = samples,
	}
	table.insert(list, seg)
	return seg
end

-- distance along -> bezier parameter t
local function distToT(seg: Segment, s: number): number
	if seg.kind == "lane" then
		return math.clamp(s / seg.length, 0, 1)
	end
	local samples = seg.samples
	if s <= 0 then
		return 0
	end
	for k = 2, #samples do
		if samples[k] >= s then
			local a, b = samples[k - 1], samples[k]
			local f = if b > a then (s - a) / (b - a) else 0
			return ((k - 2) + f) / SAMPLES
		end
	end
	return 1
end

-- Returns world position (on the ground) and unit forward direction
function CityLayout.sample(seg: Segment, s: number): (Vector3, Vector3)
	local t = distToT(seg, s)
	local pos = bezier(seg.p0, seg.p1, seg.p2, t)
	local tan = bezierTangent(seg.p0, seg.p1, seg.p2, t)
	if tan.Magnitude < 1e-4 then
		tan = seg.p2 - seg.p0
	end
	return pos, tan.Unit
end

local cachedGraph: { lanes: { Segment }, all: { Segment } }? = nil

function CityLayout.buildGraph(): { lanes: { Segment }, all: { Segment } }
	if cachedGraph then
		return cachedGraph
	end
	local all: { Segment } = {}
	local lanes: { Segment } = {}
	local byKey: { [string]: Segment } = {}
	local lanesPerSide = C.LanesPerSide

	-- straight lane segments between intersections
	for i = 0, N do
		for j = 0, N do
			local a = CityLayout.intersectionPos(i, j)
			for k = 1, 4 do
				local ni, nj = i + DI[k][1], j + DI[k][2]
				if CityLayout.inGrid(ni, nj) then
					local dir = CityLayout.Dirs[k]
					local right = dir:Cross(Vector3.yAxis)
					local b = CityLayout.intersectionPos(ni, nj)
					for l = 1, lanesPerSide do
						local off = right * CityLayout.laneOffset(l)
						local p0 = a + dir * HALF_ROAD + off
						local p2 = b - dir * (HALF_ROAD + CityLayout.StopLineGap) + off
						local seg = newSegment(all, p0, (p0 + p2) / 2, p2, "lane")
						seg.i, seg.j = ni, nj
						seg.dir = k
						seg.lane = l
						seg.axis = if k % 2 == 1 then "X" else "Z"
						byKey[`{i},{j},{k},{l}`] = seg
						table.insert(lanes, seg)
					end
				end
			end
		end
	end

	-- connectors through each intersection
	for _, seg in lanes do
		local bi, bj = seg.i, seg.j
		local k = seg.dir
		local dir = CityLayout.Dirs[k]
		local options = {}
		local fallback = {}
		for _, turn in { "straight", "right", "left" } do
			local k2 = if turn == "straight" then k elseif turn == "right" then (k % 4) + 1 else ((k + 2) % 4) + 1
			local ni, nj = bi + DI[k2][1], bj + DI[k2][2]
			if CityLayout.inGrid(ni, nj) then
				local allowed = turn == "straight" or (turn == "right" and seg.lane == lanesPerSide) or (turn == "left" and seg.lane == 1)
				local targetLane = seg.lane
				local target = byKey[`{bi},{bj},{k2},{targetLane}`]
				if target then
					table.insert(if allowed then options else fallback, { target = target, straight = turn == "straight" })
				end
			end
		end
		if #options == 0 then
			options = fallback
		end
		for _, opt in options do
			local p0 = seg.p2
			local p2 = opt.target.p0
			local p1 = if opt.straight then (p0 + p2) / 2 else p0 + dir * (p2 - p0):Dot(dir)
			local con = newSegment(all, p0, p1, p2, "turn")
			con.i, con.j = bi, bj
			con.dir = opt.target.dir
			con.lane = opt.target.lane
			con.axis = seg.axis
			con.turning = not opt.straight
			con.next = { opt.target }
			table.insert(seg.next, con)
		end
	end

	cachedGraph = { lanes = lanes, all = all }
	return cachedGraph :: any
end

-- Closest lane position + heading to a world point (used for car resets)
function CityLayout.nearestLaneCFrame(pos: Vector3): CFrame
	local graph = CityLayout.buildGraph()
	local best, bestDist = nil, math.huge
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, seg in graph.lanes do
		local ab = seg.p2 - seg.p0
		local t = math.clamp((flat - seg.p0):Dot(ab) / ab:Dot(ab), 0.05, 0.95)
		local p = seg.p0 + ab * t
		local dist = (p - flat).Magnitude
		if dist < bestDist then
			bestDist = dist
			best = CFrame.lookAt(p, p + ab.Unit)
		end
	end
	-- highway counts as road too
	if math.abs(pos.Z) < C.HighwayWidth / 2 and pos.X > CityLayout.HighwayStartX - 10 then
		local x = math.clamp(pos.X, CityLayout.HighwayStartX + 20, CityLayout.HighwayStartX + C.HighwayLength - 40)
		local p = Vector3.new(x, 0, C.LaneWidth * 1.5)
		if (p - flat).Magnitude < bestDist then
			best = CFrame.lookAt(p, p + Vector3.xAxis)
		end
	end
	return best or CFrame.new()
end

return CityLayout
