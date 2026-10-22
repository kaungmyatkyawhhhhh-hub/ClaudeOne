-- ProGymCity (prompt 58, 23 Oct): the city the Pro Gym's windows look down on, in the valley east of the gym
-- (tools/builders/ProGymValley: the valley floor is at y -72, x 157..1400, z -600..-8 and, from x 244, z -8..150).
-- A cheap backdrop: ReplicatedStorage.Backdrops.ProGymCity (a Model), never in the Workspace on the server.
-- Client/CityBackdropClient puts a copy in the Workspace only while the camera is near the Pro Gym (the east half of the
-- town), and lights it at night. Every part: Anchored, no collisions, no queries, no touches, no shadows.
--   * Roads: a boulevard right under the gym's windows (x 181, with street lights both sides), the main avenue east
--     along z -20 and a few more avenues; dark asphalt with a pale centre line.
--   * Blocks of buildings, low near the gym and taller towards the horizon (the tallest at the far end so they stand
--     out on the skyline). Each building: a body, a roof cap, rows of windows (one band per floor wrapping all four
--     sides; by day dark glass, at night ~60% of them glow warm or cool white: attribute NightColor, the rest stay dark).
--     The tallest have a red light on top.
--   * A river across the valley (x 640..700) with stone banks and a lit suspension bridge on the main avenue, and a park.
--   * Lamp heads and bridge lights carry NightColor too (glow at night, plain by day).
-- Run: require(this).Run() (rebuilds it: the old one is replaced). Deterministic (Random seed 58).
local ProGymCity = {}

local FLOOR = -72
local rng = Random.new(58)

local ASPHALT = Color3.fromHex("#2B2D31")
local LINE = Color3.fromHex("#C9C2A8")
local BODY = { Color3.fromHex("#C9CCD1"), Color3.fromHex("#D8CFC0"), Color3.fromHex("#9BA3AD"), Color3.fromHex("#5C6670"),
	Color3.fromHex("#B7B0A2"), Color3.fromHex("#7F8C99"), Color3.fromHex("#E2E0DA") }
local GLASS_DAY = Color3.fromHex("#34475B")
local WARM = { Color3.fromHex("#FFE4B0"), Color3.fromHex("#F5D79A"), Color3.fromHex("#FFF1D6") }
local COOL = { Color3.fromHex("#DCE8FF"), Color3.fromHex("#C9DBF5") }

local root
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = p.Parent or root
	return p
end

local function inValley(x: number, z: number, margin: number): boolean
	if x < 161 + margin or x > 1396 - margin or z < -596 + margin or z > 146 - margin then return false end
	if z > -12 - margin and x < 248 + margin then return false end
	return true
end

-- roads (x0, z0, x1, z1 = a strip on the floor) and the areas kept free of buildings
local ROAD_W = 12
local roads, free = {}, {}
local function road(x0, z0, x1, z1)
	local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, math.abs(x1 - x0), math.abs(z1 - z0)
	part({ Name = "Road", Size = Vector3.new(w, 0.2, d), CFrame = CFrame.new(cx, FLOOR + 0.1, cz), Color = ASPHALT, Material = Enum.Material.Asphalt, Parent = roads })
	if w > d then
		part({ Name = "RoadLine", Size = Vector3.new(w, 0.04, 0.3), CFrame = CFrame.new(cx, FLOOR + 0.22, cz), Color = LINE, Parent = roads })
	else
		part({ Name = "RoadLine", Size = Vector3.new(0.3, 0.04, d), CFrame = CFrame.new(cx, FLOOR + 0.22, cz), Color = LINE, Parent = roads })
	end
	table.insert(free, { math.min(x0, x1) - 3, math.min(z0, z1) - 3, math.max(x0, x1) + 3, math.max(z0, z1) + 3 })
end
local function blocked(x0, z0, x1, z1): boolean
	for _, f in ipairs(free) do
		if x1 > f[1] and x0 < f[3] and z1 > f[2] and z0 < f[4] then return true end
	end
	return false
end

-- a street light: pole, arm and a lamp head that glows at night
local function streetLight(x: number, z: number, armDir: number)
	part({ Name = "LampPole", Size = Vector3.new(0.4, 9, 0.4), CFrame = CFrame.new(x, FLOOR + 4.5, z), Color = Color3.fromHex("#3A3D42"), Parent = roads })
	part({ Name = "LampArm", Size = Vector3.new(2.2, 0.25, 0.25), CFrame = CFrame.new(x + armDir * 1, FLOOR + 9, z), Color = Color3.fromHex("#3A3D42"), Parent = roads })
	local head = part({ Name = "Lamp", Size = Vector3.new(1.2, 0.35, 0.7), CFrame = CFrame.new(x + armDir * 2, FLOOR + 8.85, z), Color = Color3.fromHex("#C8CCD2"), Parent = roads })
	head:SetAttribute("NightColor", Color3.fromHex("#FFE9C4"))
end

local function building(x: number, z: number, w: number, d: number, h: number)
	local color = BODY[rng:NextInteger(1, #BODY)]
	local b = Instance.new("Model")
	b.Name = "Building"
	part({ Name = "Body", Size = Vector3.new(w, h, d), CFrame = CFrame.new(x, FLOOR + h / 2, z), Color = color, Parent = b })
	part({ Name = "Roof", Size = Vector3.new(w + 0.6, 0.8, d + 0.6), CFrame = CFrame.new(x, FLOOR + h + 0.4, z), Color = Color3.fromHex("#3E4349"), Parent = b })
	-- one window band per floor (wrapping all four sides), fewer on the tall ones so a tower stays cheap
	local floorH = math.max(5, h / 9)
	local bandH = math.min(2.6, floorH * 0.5)
	local lit = rng:NextNumber() < 0.5 and WARM or COOL
	local y = FLOOR + 4
	while y + bandH < FLOOR + h - 1.5 do
		local band = part({ Name = "Windows", Size = Vector3.new(w + 0.12, bandH, d + 0.12), CFrame = CFrame.new(x, y + bandH / 2, z), Color = GLASS_DAY,
			Material = Enum.Material.Glass, Reflectance = 0.15, Parent = b })
		if rng:NextNumber() < 0.6 then band:SetAttribute("NightColor", lit[rng:NextInteger(1, #lit)]) end
		y += floorH
	end
	if h > 90 then
		local beacon = part({ Name = "Beacon", Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(x, FLOOR + h + 1.1, z), Color = Color3.fromHex("#E53935"),
			Material = Enum.Material.Neon, Parent = b })
		local _ = beacon
	end
	b.Parent = root
end

function ProGymCity.Run()
	local RS = game:GetService("ReplicatedStorage")
	local folder = RS:FindFirstChild("Backdrops") or Instance.new("Folder")
	folder.Name = "Backdrops"
	folder.Parent = RS
	local old = folder:FindFirstChild("ProGymCity")
	if old then old:Destroy() end
	root = Instance.new("Model")
	root.Name = "ProGymCity"
	roads = Instance.new("Model")
	roads.Name = "Streets"
	roads.Parent = root
	free = {}

	-- the city ground (darker than the valley's bare concrete)
	for _, g in ipairs({ { 157, -600, 1400, -8 }, { 244, -8, 1400, 150 } }) do
		part({ Name = "Ground", Size = Vector3.new(g[3] - g[1], 0.1, g[4] - g[2]), CFrame = CFrame.new((g[1] + g[3]) / 2, FLOOR + 0.03, (g[2] + g[4]) / 2),
			Color = Color3.fromHex("#55585D"), Material = Enum.Material.Concrete })
	end
	-- roads: the boulevard under the windows, the main avenue east, more avenues
	road(175, -596, 187, -14)
	road(175, -26, 1396, -14)
	for _, x in ipairs({ 300, 440, 560, 800, 940, 1080, 1220 }) do road(x - ROAD_W / 2, -596, x + ROAD_W / 2, 146) end
	for _, z in ipairs({ -140, -270, -400, -520 }) do road(175, z - ROAD_W / 2, 1396, z + ROAD_W / 2) end
	for _, z in ipairs({ 70 }) do road(248, z - ROAD_W / 2, 1396, z + ROAD_W / 2) end
	-- street lights along the boulevard (both sides) and the main avenue
	for z = -584, -30, 24 do
		streetLight(173, z, 1)
		streetLight(189, z, -1)
	end
	for x = 200, 1390, 30 do
		streetLight(x, -28, 1)
		streetLight(x, -12, 1)
	end

	-- the river with stone banks, a park beside it, and the bridge on the main avenue
	local river = { 640, 700 }
	part({ Name = "River", Size = Vector3.new(river[2] - river[1], 0.3, 760), CFrame = CFrame.new((river[1] + river[2]) / 2, FLOOR + 0.2, -225),
		Color = Color3.fromHex("#2F5D78"), Reflectance = 0.3, Material = Enum.Material.SmoothPlastic })
	for _, bx in ipairs(river) do
		part({ Name = "Bank", Size = Vector3.new(2, 1.4, 760), CFrame = CFrame.new(bx, FLOOR + 0.7, -225), Color = Color3.fromHex("#8D8A82"), Material = Enum.Material.Concrete })
	end
	table.insert(free, { river[1] - 30, -600, river[2] + 30, 150 })
	part({ Name = "Park", Size = Vector3.new(24, 0.3, 200), CFrame = CFrame.new(river[1] - 16, FLOOR + 0.2, -250), Color = Color3.fromHex("#4E8A3E"), Material = Enum.Material.Grass })
	for i = 1, 14 do
		local tx, tz = river[1] - 16 + rng:NextNumber(-9, 9), -340 + i * 13
		part({ Name = "TreeTop", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(tx, FLOOR + 5, tz), Color = Color3.fromHex("#3F7A35"), Material = Enum.Material.Grass })
		part({ Name = "TreeTrunk", Size = Vector3.new(0.6, 3, 0.6), CFrame = CFrame.new(tx, FLOOR + 1.5, tz), Color = Color3.fromHex("#5A4030") })
	end
	local deckY = FLOOR + 10
	local bridge = Instance.new("Model")
	bridge.Name = "Bridge"
	bridge.Parent = root
	part({ Name = "Deck", Size = Vector3.new(110, 1.2, 14), CFrame = CFrame.new(670, deckY, -20), Color = Color3.fromHex("#5E6268"), Parent = bridge })
	for _, rx in ipairs({ 620, 720 }) do
		part({ Name = "Ramp", Size = Vector3.new(22, 1.2, 14), CFrame = CFrame.new(rx + (rx < 670 and -10 or 10), FLOOR + 5, -20) * CFrame.Angles(0, 0, (rx < 670 and 1 or -1) * math.rad(26)),
			Color = Color3.fromHex("#5E6268"), Parent = bridge })
	end
	for _, tx in ipairs({ 650, 690 }) do
		for _, tz in ipairs({ -27, -13 }) do
			part({ Name = "Tower", Size = Vector3.new(1.6, 44, 1.6), CFrame = CFrame.new(tx, FLOOR + 22, tz), Color = Color3.fromHex("#B8473B"), Parent = bridge })
		end
		part({ Name = "TowerBeam", Size = Vector3.new(1.6, 1.6, 15.6), CFrame = CFrame.new(tx, FLOOR + 40, -20), Color = Color3.fromHex("#B8473B"), Parent = bridge })
	end
	-- the main cables (straight segments: tower top to deck, over each side)
	local function cable(a: Vector3, b: Vector3)
		local mid, len = (a + b) / 2, (b - a).Magnitude
		part({ Name = "Cable", Size = Vector3.new(0.25, 0.25, len), CFrame = CFrame.lookAt(mid, b), Color = Color3.fromHex("#D5D8DC"), Parent = bridge })
	end
	for _, tz in ipairs({ -27, -13 }) do
		local top1, top2 = Vector3.new(650, FLOOR + 43, tz), Vector3.new(690, FLOOR + 43, tz)
		cable(top1, Vector3.new(670, deckY + 4, tz))
		cable(Vector3.new(670, deckY + 4, tz), top2)
		cable(top1, Vector3.new(620, deckY + 1, tz))
		cable(top2, Vector3.new(720, deckY + 1, tz))
	end
	for x = 622, 718, 12 do
		for _, tz in ipairs({ -26.6, -13.4 }) do
			local l = part({ Name = "BridgeLight", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(x, deckY + 1.1, tz), Color = Color3.fromHex("#C8CCD2"), Parent = bridge })
			l:SetAttribute("NightColor", Color3.fromHex("#FFF3D6"))
		end
	end

	-- buildings: fill the blocks; taller towards the horizon
	local count = 0
	for x = 196, 1390, 32 do
		for z = -590, 140, 32 do
			local w, d = rng:NextNumber(14, 24), rng:NextNumber(14, 24)
			local bx, bz = x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3)
			local x0, z0, x1, z1 = bx - w / 2, bz - d / 2, bx + w / 2, bz + d / 2
			if inValley(bx, bz, math.max(w, d) / 2 + 2) and not blocked(x0, z0, x1, z1) and rng:NextNumber() < 0.66 then
				local far = math.clamp((bx - 170) / 1100, 0, 1)
				local h = rng:NextNumber(14, 30) + far * far * rng:NextNumber(30, 150)
				-- a few landmark towers on the skyline
				if far > 0.55 and rng:NextNumber() < 0.08 then h += rng:NextNumber(60, 110) end
				-- right under the windows stay low so the street shows
				if bx < 260 then h = math.min(h, 24) end
				building(bx, bz, w, d, h)
				table.insert(free, { x0, z0, x1, z1 })
				count += 1
			end
		end
	end
	root.Parent = folder
	local parts = 0
	for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return count .. " buildings, " .. parts .. " parts"
end

return ProGymCity
