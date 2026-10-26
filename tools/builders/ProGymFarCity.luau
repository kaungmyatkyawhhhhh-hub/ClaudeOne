-- ProGymFarCity (prompt 62b, 23 Oct): the cheap FAR version of the Pro Gym's valley city (tools/builders/ProGymCity),
-- seen from everywhere the detailed city isn't drawn (the west of town, high above the town, the menu flyover).
-- ReplicatedStorage.Backdrops.ProGymFarCity (a Model); Client/BackdropClient shows it whenever the detailed city is
-- out of the Workspace, so the two never draw at the same time. Owner: "under ~150 parts", no details.
--   * Ground: dark asphalt over the whole valley floor with lighter roads on the detailed city's road grid (so the streets
--     line up when the detailed city swaps in); never bare grey ground.
--   * One dark block per city block (between the roads), as tall as most of its buildings, built from the detailed
--     city's own buildings so the skyline keeps its shape; a tower where a landmark rises well above its block.
--   * Lit window strips (NightColor: glow at night, dark glass by day) on the taller blocks and towers.
--   * The river, the park and the horizon hills (copied from the detailed city).
-- Every part: Anchored, no collisions, no queries, no touches, no shadows.
-- Run: require(this).Run() after ProGymCity.Run() (rebuilds it from that model; the old one is replaced).
local ProGymFarCity = {}

-- 6 studs over the valley floor (y -72), like ProGymCity: from far away Roblox draws the terrain at low detail, and that
-- rough surface sits a few studs above the real floor (it covered a ground at the floor). Nobody walks there.
local FLOOR = -66
local MAX_PARTS = 150
local GROUND = Color3.fromHex("#2F3236")
local ROAD = Color3.fromHex("#5E6166")
local HAZE = Color3.fromHex("#2E3238") -- blocks are their buildings' colour pulled towards this (dark, a little hazy)
local STRIP_DAY = Color3.fromHex("#2A3442")
local WARM, COOL = Color3.fromHex("#FFE4B0"), Color3.fromHex("#DCE8FF")
local STRIP_MIN = 44 -- blocks lower than this get no window strip

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

-- the detailed city's blocks: x and z spans between its roads (ProGymCity: avenues at x 300 .. 1220, streets at z -520 ..
-- 70, the main avenue at z -26..-14, the river kept free at x 610..730)
local XS = { { 187, 294 }, { 306, 434 }, { 446, 554 }, { 566, 612 }, { 728, 794 }, { 806, 934 }, { 946, 1074 }, { 1086, 1214 }, { 1226, 1396 } }
local ZS = { { -596, -526 }, { -514, -406 }, { -394, -276 }, { -264, -146 }, { -134, -26 }, { -14, 64 }, { 76, 146 } }
-- (same roads as ProGymCity)
local ROAD_W = 12
local function roads()
	local list = { { 175, -596, 187, -14 }, { 175, -26, 1396, -14 } }
	for _, x in ipairs({ 300, 440, 560, 800, 940, 1080, 1220 }) do table.insert(list, { x - ROAD_W / 2, -596, x + ROAD_W / 2, 146 }) end
	for _, z in ipairs({ -140, -270, -400, -520 }) do table.insert(list, { 175, z - ROAD_W / 2, 1396, z + ROAD_W / 2 }) end
	table.insert(list, { 248, 70 - ROAD_W / 2, 1396, 70 + ROAD_W / 2 })
	return list
end

local function percentile(sorted, q)
	return sorted[math.clamp(math.ceil(#sorted * q), 1, #sorted)]
end

function ProGymFarCity.Run()
	local RS = game:GetService("ReplicatedStorage")
	local folder = RS:FindFirstChild("Backdrops")
	-- (26 Oct) the detailed city is in Workspace.Backdrops in Studio; the far city stays in ReplicatedStorage.Backdrops
	local shown = workspace:FindFirstChild("Backdrops")
	local city = (shown and shown:FindFirstChild("ProGymCity")) or (folder and folder:FindFirstChild("ProGymCity"))
	assert(city and folder, "run ProGymCity first")
	local old = folder:FindFirstChild("ProGymFarCity")
	if old then old:Destroy() end
	root = Instance.new("Model")
	root.Name = "ProGymFarCity"

	-- ground and roads (the roads stand a little proud of the ground so they never flicker from far away)
	for _, g in ipairs({ { 157, -600, 1400, -8 }, { 244, -8, 1400, 150 } }) do
		part({ Name = "Ground", Size = Vector3.new(g[3] - g[1], 0.2, g[4] - g[2]), CFrame = CFrame.new((g[1] + g[3]) / 2, FLOOR, (g[2] + g[4]) / 2),
			Color = GROUND, Material = Enum.Material.Asphalt })
	end
	for _, r in ipairs(roads()) do
		part({ Name = "Road", Size = Vector3.new(r[3] - r[1], 0.4, r[4] - r[2]), CFrame = CFrame.new((r[1] + r[3]) / 2, FLOOR + 0.15, (r[2] + r[4]) / 2),
			Color = ROAD, Material = Enum.Material.Concrete })
	end
	-- the river and the park (copies of the detailed city's, a little higher than the roads)
	for _, name in ipairs({ "River", "Park" }) do
		local src = city:FindFirstChild(name)
		if src then
			local p = src:Clone()
			p.Size = Vector3.new(p.Size.X, 0.4, p.Size.Z)
			p.CFrame = CFrame.new(p.Position.X, FLOOR + 0.35, p.Position.Z)
			p.Parent = root
		end
	end

	-- the detailed city's buildings, by block
	local buildings = {}
	for _, b in ipairs(city:GetChildren()) do
		local body = b:IsA("Model") and b.Name == "Building" and b:FindFirstChild("Body")
		if body then table.insert(buildings, { pos = body.Position, size = body.Size, color = body.Color }) end
	end
	local blocks = {}
	for _, xs in ipairs(XS) do
		for _, zs in ipairs(ZS) do
			local inside = {}
			for _, b in ipairs(buildings) do
				if b.pos.X >= xs[1] and b.pos.X <= xs[2] and b.pos.Z >= zs[1] and b.pos.Z <= zs[2] then table.insert(inside, b) end
			end
			if #inside > 0 then
				local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
				local heights, colors, tallest = {}, {}, inside[1]
				for _, b in ipairs(inside) do
					x0, x1 = math.min(x0, b.pos.X - b.size.X / 2), math.max(x1, b.pos.X + b.size.X / 2)
					z0, z1 = math.min(z0, b.pos.Z - b.size.Z / 2), math.max(z1, b.pos.Z + b.size.Z / 2)
					table.insert(heights, b.size.Y)
					local key = b.color:ToHex()
					colors[key] = (colors[key] or 0) + 1
					if b.size.Y > tallest.size.Y then tallest = b end
				end
				table.sort(heights)
				local best, bestN = nil, 0
				for key, n in pairs(colors) do if n > bestN or (n == bestN and key < best) then best, bestN = key, n end end
				table.insert(blocks, { x0 = x0 + 2, z0 = z0 + 2, x1 = x1 - 2, z1 = z1 - 2, h = percentile(heights, 0.6), tallest = tallest,
					color = Color3.fromHex(best):Lerp(HAZE, 0.55) })
			end
		end
	end

	local blockModel = Instance.new("Model")
	blockModel.Name = "Blocks"
	blockModel.Parent = root
	local strips = 0
	local function strip(cx, cz, w, d, y, warm)
		local s = part({ Name = "Windows", Size = Vector3.new(w + 0.3, 3, d + 0.3), CFrame = CFrame.new(cx, y, cz), Color = STRIP_DAY,
			Material = Enum.Material.Glass, Parent = blockModel })
		s:SetAttribute("NightColor", if warm then WARM else COOL)
		strips += 1
	end
	for i, b in ipairs(blocks) do
		local cx, cz, w, d = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2, b.x1 - b.x0, b.z1 - b.z0
		part({ Name = "Block", Size = Vector3.new(w, b.h, d), CFrame = CFrame.new(cx, FLOOR + b.h / 2, cz), Color = b.color, Parent = blockModel })
		if b.h >= STRIP_MIN then strip(cx, cz, w, d, FLOOR + b.h * 0.6, i % 2 == 0) end
		local t = b.tallest
		if t.size.Y > b.h * 1.5 and t.size.Y > 50 then
			local tw, td = t.size.X * 1.2, t.size.Z * 1.2
			part({ Name = "Tower", Size = Vector3.new(tw, t.size.Y, td), CFrame = CFrame.new(t.pos.X, FLOOR + t.size.Y / 2, t.pos.Z),
				Color = t.color:Lerp(HAZE, 0.45), Parent = blockModel })
			strip(t.pos.X, t.pos.Z, tw, td, FLOOR + t.size.Y * 0.75, i % 2 == 1)
		end
	end

	-- the horizon hills, while the part budget allows (biggest first)
	local hills = city:FindFirstChild("Hills")
	if hills then
		local list = hills:GetChildren()
		table.sort(list, function(a, b) return a.Size.X > b.Size.X end)
		local count = 0
		for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
		local hillModel = Instance.new("Model")
		hillModel.Name = "Hills"
		hillModel.Parent = root
		for _, h in ipairs(list) do
			if count >= MAX_PARTS then break end
			h:Clone().Parent = hillModel
			count += 1
		end
	end

	root.Parent = folder
	local parts = 0
	for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return #blocks .. " blocks, " .. strips .. " window strips, " .. parts .. " parts"
end

return ProGymFarCity
