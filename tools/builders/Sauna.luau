-- Sauna: a wooden beach sauna east of the beach gym (Workspace.Town.Sauna). Stamina refills much faster inside
-- (invisible part "SaunaZone" with the Recovery attribute "Sauna", read by BoostService; speed in Config/Stamina).
-- Raised plank deck with a porch and steps, a duckboard path to the boardwalk (between two bollards), board walls with
-- corner posts, a gable roof with shingle rows, an open door, two windows, a sign plaque and a lantern. Inside: two
-- bench tiers with seats, a stove with hot stones, a warm glow and a little steam; a chimney that steams outside.
-- Run once in Studio with Kit + TownKit loaded next to it, then save:
--   require(game.ServerStorage._Builders.Sauna).Build()
-- Running it again replaces the old one.
local Kit = require(script.Parent.Kit)
local TownKit = require(script.Parent.TownKit)

local Sauna = {}

local hex, rad = Kit.hex, math.rad
local M = Enum.Material
local p, cyl, ball = TownKit.p, TownKit.cyl, TownKit.ball
local up = CFrame.Angles(0, 0, rad(90))

Sauna.Spot = Vector3.new(-48.5, 0, 226) -- the door faces the boardwalk (-Z)
Sauna.BoardwalkEdgeZ = 209.15            -- where the path meets the boardwalk (world z)

local COLOR = {
	Wall = hex("#A87B52"), WallAlt = hex("#9E7249"), Post = hex("#6B4A31"), Trim = hex("#5A3D28"),
	Roof = hex("#5B4636"), RoofLine = hex("#4A382B"), Deck = hex("#B08A63"), DeckDark = hex("#8E6B4B"),
	Bench = hex("#C79A6B"), Iron = hex("#2B2C2F"), Stone = hex("#77736C"), StoneDark = hex("#5E5A54"),
	Glow = hex("#FF8A3D"), Warm = hex("#FFC98A"), Glass = hex("#B9CCD6"),
	TowelA = hex("#F2EEE6"), TowelB = hex("#7CC6A5"), TowelC = hex("#E86A6A"),
}

-- cabin box in local space (door wall at -Z)
local W, FRONT, BACK = 11, -3, 5     -- x from -W/2..W/2, z from FRONT..BACK
local FLOOR, ROW, ROWS = 0.8, 0.75, 10
local TOP = FLOOR + ROW * ROWS      -- 8.3: top of the walls
local RIDGE = TOP + 2.6
local THICK = 0.4

local function steam(parent, rate, size, speed)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Steam"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.4), NumberSequenceKeypoint.new(1, size) })
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Acceleration = Vector3.new(0.4, 0.6, 0)
	emitter.LightInfluence = 0.6
	emitter.Parent = parent
	return emitter
end

-- One wall of horizontal boards from a to b (local x/z at wall center), with openings { from, to, rowFrom, rowTo }
-- measured along the wall from a. Boards stop inside the corner posts.
local function wall(m, cf, a, b, openings)
	local along = (b - a).Unit
	local length = (b - a).Magnitude
	local inset = 0.35
	for row = 1, ROWS do
		local y = FLOOR + (row - 0.5) * ROW
		local cuts = {}
		for _, o in ipairs(openings or {}) do
			if row >= o[3] and row <= o[4] then table.insert(cuts, o) end
		end
		table.sort(cuts, function(x, z) return x[1] < z[1] end)
		local start = inset
		local pieces = {}
		for _, cut in ipairs(cuts) do
			table.insert(pieces, { start, cut[1] })
			start = cut[2]
		end
		table.insert(pieces, { start, length - inset })
		for _, piece in ipairs(pieces) do
			local len = piece[2] - piece[1]
			if len > 0.05 then
				local mid = a + along * ((piece[1] + piece[2]) / 2)
				local look = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X, y, mid.Z) + along)
				p(m, "WallBoard", Vector3.new(THICK, ROW - 0.02, len), cf * look, row % 2 == 0 and COLOR.WallAlt or COLOR.Wall, M.Wood, true)
			end
		end
	end
end

-- a framed window: glass pane, frame, sill, a cross bar
local function window(m, cf, center, along, width, height)
	local look = CFrame.lookAt(center, center + along) -- local Z runs along the wall, X across it
	p(m, "WindowGlass", Vector3.new(0.12, height, width), cf * look, COLOR.Glass, M.Glass, false, { Transparency = 0.45, Reflectance = 0.08 })
	for _, s in ipairs({ -1, 1 }) do
		p(m, "WindowFrame", Vector3.new(THICK + 0.16, height + 0.3, 0.18), cf * look * CFrame.new(0, 0, s * (width / 2 + 0.07)), COLOR.Trim, M.Wood, true)
		p(m, "WindowFrame", Vector3.new(THICK + 0.16, 0.18, width + 0.5), cf * look * CFrame.new(0, s * (height / 2 + 0.07), 0), COLOR.Trim, M.Wood, true)
	end
	p(m, "WindowBar", Vector3.new(0.2, 0.1, width), cf * look, COLOR.Trim, M.Wood)
	p(m, "WindowBar", Vector3.new(0.2, height, 0.1), cf * look, COLOR.Trim, M.Wood)
	p(m, "WindowSill", Vector3.new(THICK + 0.5, 0.14, width + 0.7), cf * look * CFrame.new(0, -height / 2 - 0.22, 0), COLOR.Trim, M.Wood, true)
end

-- The boardwalk's edge rope runs past the sauna path: cut it into two pieces between the bollards at x gapFrom..gapTo.
local function openRope(gapFrom, gapTo, z)
	local beach = workspace:FindFirstChild("Town") and workspace.Town:FindFirstChild("Beach")
	for _, rope in ipairs(beach and beach:GetChildren() or {}) do
		if rope:IsA("BasePart") and rope.Name == "Rope" and math.abs(rope.Position.Z - z) < 0.5 then
			local axis = rope.CFrame.LookVector * rope.Size.Z / 2
			local a, b = rope.Position - axis, rope.Position + axis
			if a.X > b.X then a, b = b, a end
			if a.X < gapFrom and b.X > gapTo then
				for _, span in ipairs({ { a, Vector3.new(gapFrom, a.Y, a.Z) }, { Vector3.new(gapTo, b.Y, b.Z), b } }) do
					local piece = rope:Clone()
					piece.Size = Vector3.new(rope.Size.X, rope.Size.Y, (span[2] - span[1]).Magnitude)
					piece.CFrame = CFrame.lookAt((span[1] + span[2]) / 2, span[2])
					piece.Parent = rope.Parent
				end
				rope:Destroy()
			end
		end
	end
end

function Sauna.Build(parent)
	parent = parent or workspace:FindFirstChild("Town") or workspace
	local old = parent:FindFirstChild("Sauna")
	if old then old:Destroy() end
	local cf = CFrame.lookAt(Sauna.Spot, Sauna.Spot + Vector3.new(0, 0, -1)) -- local -Z = world -Z (door side)
	local m = TownKit.model(parent, "Sauna", cf)
	openRope(Sauna.Spot.X - 2.5, Sauna.Spot.X + 2.5, Sauna.BoardwalkEdgeZ)

	-- deck: planks across x with small gaps, posts under it, two steps and a duckboard path to the boardwalk
	local deckW, deckFront, deckBack = W + 3, FRONT - 3, BACK + 1
	local plank = 0.9
	local z = deckFront
	while z + plank <= deckBack + 0.01 do
		p(m, "DeckPlank", Vector3.new(deckW, 0.3, plank - 0.08), cf * CFrame.new(0, FLOOR - 0.15, z + plank / 2), (math.floor(z) % 2 == 0) and COLOR.Deck or COLOR.DeckDark, M.WoodPlanks, true)
		z += plank
	end
	for _, x in ipairs({ -deckW / 2 + 0.4, 0, deckW / 2 - 0.4 }) do
		for _, zz in ipairs({ deckFront + 0.4, (deckFront + deckBack) / 2, deckBack - 0.4 }) do
			p(m, "DeckPost", Vector3.new(0.5, FLOOR - 0.2, 0.5), cf * CFrame.new(x, (FLOOR - 0.3) / 2 - 0.05, zz), COLOR.Post, M.Wood, true)
		end
	end
	p(m, "DeckFascia", Vector3.new(deckW + 0.1, 0.35, 0.12), cf * CFrame.new(0, FLOOR - 0.3, deckFront - 0.08), COLOR.Trim, M.Wood, true)
	p(m, "Step", Vector3.new(3.2, 0.27, 0.9), cf * CFrame.new(0, 0.135 + 0.27, deckFront - 0.45 - 0.02), COLOR.Deck, M.WoodPlanks, true)
	p(m, "Step", Vector3.new(3.2, 0.27, 0.9), cf * CFrame.new(0, 0.135, deckFront - 1.35 - 0.02), COLOR.DeckDark, M.WoodPlanks, true)
	local pathStart = deckFront - 1.85
	local pathEnd = Sauna.BoardwalkEdgeZ - Sauna.Spot.Z
	local zp = pathStart
	while zp - 0.85 >= pathEnd do
		p(m, "PathBoard", Vector3.new(3, 0.18, 0.8), cf * CFrame.new(0, 0.1, zp - 0.4), COLOR.DeckDark, M.WoodPlanks, true)
		zp -= 1
	end
	for _, s in ipairs({ -1, 1 }) do
		p(m, "PathRail", Vector3.new(0.2, 0.16, pathStart - pathEnd - 0.1), cf * CFrame.new(s * 1.6, 0.08, (pathStart + pathEnd) / 2), COLOR.Trim, M.Wood)
	end

	-- corner posts, wall boards, top plate
	local corners = { Vector3.new(-W / 2, 0, FRONT), Vector3.new(W / 2, 0, FRONT), Vector3.new(W / 2, 0, BACK), Vector3.new(-W / 2, 0, BACK) }
	for _, c in ipairs(corners) do
		p(m, "CornerPost", Vector3.new(0.7, TOP - FLOOR + 0.1, 0.7), cf * CFrame.new(c.X, (FLOOR + TOP) / 2, c.Z), COLOR.Post, M.Wood, true)
	end
	-- door (2.4 wide, rows 1-8) in the middle of the front wall, a window to its right; one window on each side wall
	wall(m, cf, corners[1], corners[2], { { W / 2 - 1.2, W / 2 + 1.2, 1, 8 }, { W / 2 + 2.3, W / 2 + 4.1, 4, 6 } })
	wall(m, cf, corners[2], corners[3], { { 2.6, 5.4, 4, 6 } })
	wall(m, cf, corners[3], corners[4], {})
	wall(m, cf, corners[4], corners[1], { { 2.6, 5.4, 4, 6 } })
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local mid = (a + b) / 2
		local look = CFrame.lookAt(Vector3.new(mid.X, TOP + 0.15, mid.Z), Vector3.new(b.X, TOP + 0.15, b.Z))
		p(m, "TopPlate", Vector3.new(THICK + 0.3, 0.3, (b - a).Magnitude + 0.9), cf * look, COLOR.Trim, M.Wood, true)
	end
	window(m, cf, Vector3.new(3.2, FLOOR + 4.5 * ROW, FRONT), Vector3.new(1, 0, 0), 1.8, 2.2)
	window(m, cf, Vector3.new(W / 2, FLOOR + 4.5 * ROW, FRONT + 4), Vector3.new(0, 0, 1), 2.8, 2.2)
	window(m, cf, Vector3.new(-W / 2, FLOOR + 4.5 * ROW, FRONT + 4), Vector3.new(0, 0, 1), 2.8, 2.2)

	-- door frame and the door, standing open against the porch
	for _, s in ipairs({ -1, 1 }) do
		p(m, "DoorJamb", Vector3.new(0.3, 6.1, THICK + 0.2), cf * CFrame.new(s * 1.35, FLOOR + 3.05, FRONT), COLOR.Trim, M.Wood, true)
	end
	p(m, "DoorHeader", Vector3.new(3.1, 0.3, THICK + 0.2), cf * CFrame.new(0, FLOOR + 6.1, FRONT), COLOR.Trim, M.Wood, true)
	local hinge = cf * CFrame.new(1.2, FLOOR, FRONT - 0.3) * CFrame.Angles(0, rad(-100), 0)
	local leaf = hinge * CFrame.new(-1.15, 2.95, 0)
	p(m, "Door", Vector3.new(2.3, 5.9, 0.16), leaf, COLOR.WallAlt, M.Wood, true)
	p(m, "DoorWindow", Vector3.new(0.8, 1.2, 0.24), leaf * CFrame.new(0, 1.4, 0), COLOR.Glass, M.Glass, false, { Transparency = 0.4 })
	for _, yy in ipairs({ -2, 0, 2 }) do
		p(m, "DoorBrace", Vector3.new(2.1, 0.22, 0.22), leaf * CFrame.new(0, yy - 0.4, 0.12), COLOR.Trim, M.Wood)
	end
	p(m, "DoorHandle", Vector3.new(0.12, 0.7, 0.14), leaf * CFrame.new(0.85, 0, -0.18), COLOR.Iron, M.Metal)

	-- roof: two panels meeting at the ridge, shingle lines, ridge cap, fascia, gable ends
	local overhangZ, overhangX = 0.8, 0.6
	local centerZ = (FRONT + BACK) / 2
	local half = (BACK - FRONT) / 2
	local rise = RIDGE - TOP
	for _, s in ipairs({ -1, 1 }) do
		local ridgePoint = Vector3.new(0, RIDGE, centerZ)
		local eaveZ = centerZ + s * (half + overhangZ)
		local eave = Vector3.new(0, TOP - overhangZ * rise / half, eaveZ)
		local len = (eave - ridgePoint).Magnitude
		local panelCf = CFrame.lookAt((ridgePoint + eave) / 2, eave) * CFrame.new(0, 0.2, 0)
		p(m, "RoofPanel", Vector3.new(W + overhangX * 2, 0.35, len + 0.2), cf * panelCf, COLOR.Roof, M.WoodPlanks, true)
		for i = 1, 4 do
			p(m, "Shingles", Vector3.new(W + overhangX * 2, 0.08, 0.16), cf * panelCf * CFrame.new(0, 0.21, -len / 2 + i * len / 5), COLOR.RoofLine, M.Wood)
		end
		p(m, "Fascia", Vector3.new(W + overhangX * 2 + 0.1, 0.45, 0.14), cf * CFrame.new(0, eave.Y + 0.05, eaveZ + s * 0.05), COLOR.Trim, M.Wood)
	end
	p(m, "RidgeCap", Vector3.new(W + overhangX * 2 + 0.2, 0.3, 0.9), cf * CFrame.new(0, RIDGE + 0.42, centerZ), COLOR.Trim, M.Wood, true)
	-- the ridge runs along x, so the gable triangles close the two side walls
	for _, xx in ipairs({ -W / 2, W / 2 }) do
		local a = (cf * CFrame.new(xx, TOP + 0.3, FRONT + 0.2)).Position
		local b = (cf * CFrame.new(xx, TOP + 0.3, BACK - 0.2)).Position
		local c = (cf * CFrame.new(xx, RIDGE - 0.05, centerZ)).Position
		TownKit.triangle(m, "Gable", a, b, c, THICK, COLOR.Wall, M.Wood)
	end

	-- sign plaque above the door, lantern beside it
	local signCf = cf * CFrame.new(0, FLOOR + 6.55, FRONT - THICK / 2 - 0.08)
	local board = Kit.sign(m, "SaunaSign", Vector3.new(3.2, 0.95, 0.12), signCf, "Sauna", COLOR.Warm, hex("#3A2A1E"), 60)
	board.Material = M.Wood
	for _, s in ipairs({ -1, 1 }) do
		p(m, "SignTrim", Vector3.new(3.5, 0.12, 0.18), signCf * CFrame.new(0, s * 0.53, 0), COLOR.Trim, M.Wood)
		p(m, "SignTrim", Vector3.new(0.12, 1.18, 0.18), signCf * CFrame.new(s * 1.69, 0, 0), COLOR.Trim, M.Wood)
	end
	local lanternCf = cf * CFrame.new(-2.1, FLOOR + 5, FRONT - THICK / 2 - 0.35)
	p(m, "LanternArm", Vector3.new(0.12, 0.12, 0.5), lanternCf * CFrame.new(0, 0.55, 0.2), COLOR.Iron, M.Metal)
	p(m, "LanternTop", Vector3.new(0.6, 0.15, 0.6), lanternCf * CFrame.new(0, 0.45, 0), COLOR.Iron, M.Metal)
	local glass = p(m, "LanternGlass", Vector3.new(0.4, 0.6, 0.4), lanternCf * CFrame.new(0, 0.05, 0), COLOR.Warm, M.Glass, false, { Transparency = 0.3 })
	p(m, "LanternBase", Vector3.new(0.5, 0.12, 0.5), lanternCf * CFrame.new(0, -0.3, 0), COLOR.Iron, M.Metal)
	local lamp = Instance.new("PointLight")
	lamp.Color, lamp.Range, lamp.Brightness, lamp.Shadows = COLOR.Warm, 12, 0.8, false
	lamp.Parent = glass

	-- porch: a bench, a wooden bucket with a ladle, a towel rack with towels
	local benchCf = cf * CFrame.new(-4.2, FLOOR, FRONT - 1.2)
	for i = -1, 1 do p(m, "PorchSlat", Vector3.new(2.8, 0.14, 0.32), benchCf * CFrame.new(0, 1.45, i * 0.38), COLOR.Bench, M.Wood, true) end
	for _, x in ipairs({ -1.15, 1.15 }) do p(m, "PorchLeg", Vector3.new(0.25, 1.38, 1.0), benchCf * CFrame.new(x, 0.69, 0), COLOR.Post, M.Wood) end
	local bucketCf = cf * CFrame.new(2, FLOOR, FRONT - 0.9)
	cyl(m, "Bucket", 0.9, 0.9, bucketCf * CFrame.new(0, 0.45, 0) * up, COLOR.Bench, M.Wood)
	for _, yy in ipairs({ 0.2, 0.7 }) do cyl(m, "BucketBand", 0.08, 0.94, bucketCf * CFrame.new(0, yy, 0) * up, COLOR.Iron, M.Metal) end
	p(m, "Ladle", Vector3.new(0.08, 0.08, 1.3), bucketCf * CFrame.new(0.15, 1.0, 0.1) * CFrame.Angles(rad(-35), 0, 0), COLOR.Post, M.Wood)
	local rackCf = cf * CFrame.new(5.4, FLOOR, FRONT - 1.4)
	for _, zz in ipairs({ -0.9, 0.9 }) do p(m, "RackPost", Vector3.new(0.2, 2.6, 0.2), rackCf * CFrame.new(0, 1.3, zz), COLOR.Post, M.Wood) end
	p(m, "RackBar", Vector3.new(0.16, 0.16, 2.0), rackCf * CFrame.new(0, 2.4, 0), COLOR.Post, M.Wood)
	for i, color in ipairs({ COLOR.TowelA, COLOR.TowelB, COLOR.TowelC }) do
		p(m, "Towel", Vector3.new(0.42, 1.1, 0.45), rackCf * CFrame.new(0, 1.9, -0.75 + i * 0.5 - 0.25), color, M.Fabric)
	end

	-- inside: two bench tiers along the back wall (with seats), the stove in the front left corner
	local inner = W / 2 - THICK / 2 - 0.05
	for tier, spec in ipairs({ { y = FLOOR + 1.5, z = BACK - 2.4 }, { y = FLOOR + 3.1, z = BACK - 1.1 } }) do
		for i = -1, 1 do
			p(m, "BenchSlat", Vector3.new(inner * 2 - 0.2, 0.14, 0.34), cf * CFrame.new(0, spec.y, spec.z + i * 0.4), COLOR.Bench, M.Wood, true)
		end
		for _, x in ipairs({ -inner + 0.6, 0, inner - 0.6 }) do
			p(m, "BenchLeg", Vector3.new(0.25, spec.y - FLOOR - 0.07, 1.1), cf * CFrame.new(x, (spec.y + FLOOR - 0.07) / 2, spec.z), COLOR.Post, M.Wood)
		end
		for _, x in ipairs({ -2.8, 0, 2.8 }) do
			local seat = Instance.new("Seat")
			seat.Name = "SaunaSeat"
			seat.Size = Vector3.new(1.6, 0.2, 1.1)
			seat.CFrame = cf * CFrame.new(x, spec.y + 0.15, spec.z)
			seat.Transparency = 1
			seat.CanCollide = false
			seat.Anchored = true
			seat.CastShadow = false
			seat.Parent = m
		end
		if tier == 2 then
			p(m, "BackRest", Vector3.new(inner * 2 - 0.2, 0.9, 0.12), cf * CFrame.new(0, spec.y + 0.9, BACK - THICK / 2 - 0.2), COLOR.Bench, M.Wood)
		end
	end
	local stoveCf = cf * CFrame.new(-3.6, FLOOR, FRONT + 1.6)
	p(m, "Stove", Vector3.new(1.4, 1.8, 1.4), stoveCf * CFrame.new(0, 0.9, 0), COLOR.Iron, M.Metal, true)
	p(m, "StoveRim", Vector3.new(1.6, 0.25, 1.6), stoveCf * CFrame.new(0, 1.9, 0), COLOR.Iron, M.Metal, true)
	p(m, "StoveGlow", Vector3.new(0.7, 0.4, 0.05), stoveCf * CFrame.new(0, 0.6, 0.72), COLOR.Glow, M.Neon)
	local stones = {
		{ -0.35, -0.35 }, { 0.3, -0.4 }, { -0.4, 0.3 }, { 0.35, 0.3 }, { 0, 0 }, { -0.05, -0.45 }, { 0.45, -0.02 }, { -0.1, 0.42 },
	}
	for i, o in ipairs(stones) do
		ball(m, "Stone", Vector3.new(0.48, 0.38, 0.48), stoveCf * CFrame.new(o[1], 2.15 + (i == 5 and 0.15 or 0), o[2]), i % 2 == 0 and COLOR.Stone or COLOR.StoneDark, M.Slate)
	end
	local heat = p(m, "StoveHeat", Vector3.new(0.6, 0.2, 0.6), stoveCf * CFrame.new(0, 2.4, 0), COLOR.Iron, M.SmoothPlastic, false, { Transparency = 1 })
	steam(heat, 2, 2.2, 1.2)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = COLOR.Glow, 10, 1.3, false
	light.Parent = heat
	-- the flue leaves the back of the stove and goes up through the roof (clear of the stones)
	local flueZ = -0.95
	p(m, "FlueJoint", Vector3.new(0.4, 0.4, 0.5), stoveCf * CFrame.new(0, 1.4, -0.7), COLOR.Iron, M.Metal)
	cyl(m, "Chimney", RIDGE - FLOOR, 0.45, stoveCf * CFrame.new(0, (1.2 + RIDGE + 1.2 - FLOOR) / 2, flueZ) * up, COLOR.Iron, M.Metal, true)
	cyl(m, "ChimneyCap", 0.18, 0.75, stoveCf * CFrame.new(0, RIDGE + 1.25 - FLOOR, flueZ) * up, COLOR.Iron, M.Metal)
	local chimneyTop = p(m, "ChimneySmoke", Vector3.new(0.4, 0.2, 0.4), stoveCf * CFrame.new(0, RIDGE + 1.45 - FLOOR, flueZ), COLOR.Iron, M.SmoothPlastic, false, { Transparency = 1 })
	steam(chimneyTop, 3, 3.5, 2.5)
	-- bucket of water by the stove (for the stones)
	cyl(m, "StoveBucket", 0.7, 0.7, cf * CFrame.new(-2.3, FLOOR + 0.35, FRONT + 1.0) * up, COLOR.Bench, M.Wood)
	cyl(m, "StoveBucketBand", 0.08, 0.74, cf * CFrame.new(-2.3, FLOOR + 0.5, FRONT + 1.0) * up, COLOR.Iron, M.Metal)

	-- the recovery zone: the whole inside of the cabin
	local zone = p(m, "SaunaZone", Vector3.new(W - 1, TOP - FLOOR, BACK - FRONT - 1), cf * CFrame.new(0, (FLOOR + TOP) / 2, (FRONT + BACK) / 2), COLOR.Warm, M.SmoothPlastic, false, { Transparency = 1 })
	zone:SetAttribute("Recovery", "Sauna")

	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return m
end

return Sauna
