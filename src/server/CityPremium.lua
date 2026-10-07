--[[
	CityPremium
	The "ultra" layer on top of the base city:
	  * three landmark towers: Legends Tower (stepped, giant logo crown, searchlights),
	    Twist Tower (rotating glass floor plates) and the Needle (observation tower)
	  * streetscape: tree planters, benches, bins, hydrants, lit bus shelters
	  * steam rising from manholes
	  * harbour water around the island city, a distant skyline across the
	    water, and night clouds
	  * the elevated monorail track that loops the skyline
	Every feature can be switched off in Config.Graphics.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local CityPremium = {}

local G = Config.Graphics
local C = Config.City
local CURB = C.CurbHeight
local HALF_ROAD = C.RoadWidth / 2
local E = C.HalfExtent + HALF_ROAD
local RING = C.OuterRingDepth
local HW = C.HighwayWidth / 2

local GLASS_DARK = Color3.fromRGB(16, 22, 34)
local WARM = Color3.fromRGB(255, 220, 170)
local COOL = Color3.fromRGB(190, 220, 255)

---------------------------------------------------------------------
-- Searchlights (beams are swept by the client, see WorldFx)
---------------------------------------------------------------------
local function searchlight(kit: any, parent: Instance, base: Vector3, phase: number, color: Color3)
	if not G.Searchlights then
		return
	end
	local deco = kit.deco
	local lamp = deco(parent, Vector3.new(3, 1.5, 3), CFrame.new(base), color, Enum.Material.Neon)
	local a0 = Instance.new("Attachment")
	a0.Parent = lamp
	local target = deco(parent, Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(0, 1100, 0)), color, Enum.Material.SmoothPlastic, { transparency = 1 })
	target.Name = "SearchTarget"
	target:SetAttribute("Base", base)
	target:SetAttribute("Phase", phase)
	CollectionService:AddTag(target, "SearchTarget")
	local a1 = Instance.new("Attachment")
	a1.Parent = target
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.6, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = 4
	beam.Width1 = 60
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = lamp
end

---------------------------------------------------------------------
-- Landmarks
---------------------------------------------------------------------
local function plazaGround(kit: any, parent: Instance, cx: number, cz: number, lot: number)
	local deco = kit.deco
	deco(parent, Vector3.new(lot, 0.12, lot), CFrame.new(cx, CURB + 0.06, cz), Color3.fromRGB(58, 58, 64), Enum.Material.Granite)
	-- glowing paving inlay lines
	for _, s in { -1, 1 } do
		deco(parent, Vector3.new(lot - 10, 0.14, 0.4), CFrame.new(cx, CURB + 0.07, cz + s * (lot / 2 - 8)), Config.Theme.Accent, Enum.Material.Neon, { transparency = 0.3 })
		deco(parent, Vector3.new(0.4, 0.14, lot - 10), CFrame.new(cx + s * (lot / 2 - 8), CURB + 0.07, cz), Config.Theme.Accent, Enum.Material.Neon, { transparency = 0.3 })
	end
	-- corner trees
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			kit.tree(parent, Vector3.new(cx + sx * (lot / 2 - 20), CURB, cz + sz * (lot / 2 - 20)))
		end
	end
end

local function logoBand(kit: any, parent: Instance, cx: number, cz: number, w: number, y: number, text: string)
	local band = kit.deco(parent, Vector3.new(w + 0.6, 12, w + 0.6), CFrame.new(cx, y, cz), Color3.fromRGB(8, 8, 12), Enum.Material.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local _, _, label = kit.surfaceText(band, face, text, Color3.new(1, 1, 1), Color3.fromRGB(8, 8, 12), 0, Enum.Font.GothamBlack, Vector2.new(1200, 200))
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Config.Theme.Accent),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Config.Theme.Accent2),
		})
		grad.Parent = label
		CollectionService:AddTag(grad, "AnimatedBoard")
	end
end

local function legendsTower(kit: any, parent: Instance, cx: number, cz: number, lot: number)
	local model = Instance.new("Model")
	model.Name = "LegendsTower"
	model.Parent = parent
	plazaGround(kit, model, cx, cz, lot)
	local pal = kit.randomPalette("glass")
	pal.body = Color3.fromRGB(14, 20, 34)
	pal.warm = false
	pal.lit = 0.62
	local tiers = { { 128, 250 }, { 104, 170 }, { 80, 130 }, { 56, 90 } }
	local y = CURB
	local w = 128
	for idx, t in tiers do
		w = t[1]
		local y1 = y + t[2]
		kit.facadeTier(model, cx, cz, w, w, y, y1, pal, true)
		kit.mk(model, Vector3.new(w + 2, 2, w + 2), CFrame.new(cx, y1 + 1, cz), Color3.fromRGB(20, 20, 24), Enum.Material.Metal)
		kit.neonOutline(model, cx, cz, w + 2, w + 2, y1 + 2.2, if idx % 2 == 1 then Config.Theme.Accent else Config.Theme.Accent2, 0.7)
		-- corner light columns
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				kit.deco(model, Vector3.new(0.6, t[2] - 4, 0.6), CFrame.new(cx + sx * (w / 2 + 0.4), y + t[2] / 2, cz + sz * (w / 2 + 0.4)), Color3.fromRGB(220, 235, 255), Enum.Material.Neon)
			end
		end
		y = y1 + 2
	end
	logoBand(kit, model, cx, cz, w, y + 6, "CITY LEGENDS")
	-- glass crown pyramid
	local cy = y + 12
	for k, cw in { 46, 32, 18 } do
		local h = 16
		kit.deco(model, Vector3.new(cw, h, cw), CFrame.new(cx, cy + h / 2, cz), GLASS_DARK, Enum.Material.Glass, { transparency = 0.2, reflectance = 0.3 })
		local core = kit.deco(model, Vector3.new(cw - 2, h - 1, cw - 2), CFrame.new(cx, cy + h / 2, cz), if k == 2 then Config.Theme.Accent2 else Config.Theme.Accent, Enum.Material.Neon, { transparency = 0.5 })
		if k == 1 then
			kit.addLight("PointLight", core, Config.Theme.Accent, 60, 2)
		end
		kit.neonOutline(model, cx, cz, cw, cw, cy + h, Color3.fromRGB(235, 245, 255), 0.5)
		cy += h
	end
	kit.spire(model, cx, cz, cy, 2.4)
	-- searchlights on the first terrace
	local tw = tiers[1][1]
	local ty = CURB + tiers[1][2] + 3
	for k, o in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		searchlight(kit, model, Vector3.new(cx + o[1] * (tw / 2 - 6), ty, cz + o[2] * (tw / 2 - 6)), k * 1.7, Color3.fromRGB(200, 225, 255))
	end
	kit.lobby(model, cx, cz, 128, 128, CURB, Vector3.new(0, 0, 1), true)
	kit.lobby(model, cx, cz, 128, 128, CURB, Vector3.new(1, 0, 0), true)
end

local function twistTower(kit: any, parent: Instance, cx: number, cz: number, lot: number)
	local model = Instance.new("Model")
	model.Name = "TwistTower"
	model.Parent = parent
	plazaGround(kit, model, cx, cz, lot)
	-- podium
	kit.mk(model, Vector3.new(120, 22, 120), CFrame.new(cx, CURB + 11, cz), Color3.fromRGB(24, 26, 32), Enum.Material.Glass, { reflectance = 0.3 })
	kit.deco(model, Vector3.new(118, 18, 118), CFrame.new(cx, CURB + 10, cz), WARM, Enum.Material.Neon, { transparency = 0.6 })
	kit.neonOutline(model, cx, cz, 121, 121, CURB + 22.4, Config.Theme.Accent2, 0.6)
	local plates = 34
	local step = 15
	local size = 74
	local y = CURB + 22
	for k = 0, plates - 1 do
		local rot = CFrame.Angles(0, math.rad(k * 3.2), 0)
		local cf = CFrame.new(cx, y + step / 2, cz) * rot
		kit.mk(model, Vector3.new(size, step - 0.8, size), cf, Color3.fromRGB(16, 22, 32), Enum.Material.Glass, { reflectance = 0.35, transparency = 0.15 })
		if kit.rng:NextNumber() < 0.8 then
			local frac = k / plates
			local col = WARM:Lerp(COOL, frac)
			kit.deco(model, Vector3.new(size - 3, step - 2.5, size - 3), cf, col, Enum.Material.Neon, { transparency = kit.rng:NextNumber(0.55, 0.75) })
		end
		local slabColor = if k % 4 == 3 then Config.Theme.Accent2 else Color3.fromRGB(30, 30, 34)
		local slabMat = if k % 4 == 3 then Enum.Material.Neon else Enum.Material.Metal
		kit.deco(model, Vector3.new(size + 1, 0.8, size + 1), CFrame.new(cx, y + step - 0.4, cz) * rot, slabColor, slabMat)
		y += step
	end
	kit.spire(model, cx, cz, y, 1.8)
	searchlight(kit, model, Vector3.new(cx + 20, y + 1, cz), 0.5, Config.Theme.Accent2:Lerp(Color3.new(1, 1, 1), 0.4))
	searchlight(kit, model, Vector3.new(cx - 20, y + 1, cz), 3.6, Config.Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.4))
end

local function needle(kit: any, parent: Instance, cx: number, cz: number, lot: number)
	local model = Instance.new("Model")
	model.Name = "Needle"
	model.Parent = parent
	plazaGround(kit, model, cx, cz, lot)
	local concrete = Color3.fromRGB(150, 150, 156)
	local function vcyl(h: number, d: number, y: number, color: Color3, mat: Enum.Material, o: any?): BasePart
		local opts = o or {}
		opts.shape = Enum.PartType.Cylinder
		return kit.mk(model, Vector3.new(h, d, d), CFrame.new(cx, y + h / 2, cz) * CFrame.Angles(0, 0, math.pi / 2), color, mat, opts)
	end
	local shaftH = 340
	vcyl(shaftH, 16, CURB, concrete, Enum.Material.Concrete)
	-- three flared legs
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		local foot = Vector3.new(cx + math.cos(a) * 46, CURB, cz + math.sin(a) * 46)
		local top = Vector3.new(cx + math.cos(a) * 7, CURB + 140, cz + math.sin(a) * 7)
		kit.mk(model, Vector3.new(5, 5, (top - foot).Magnitude), CFrame.lookAt((foot + top) / 2, top), concrete, Enum.Material.Concrete)
		-- neon spine running up the shaft
		local stripPos = Vector3.new(cx + math.cos(a) * 8.1, CURB + shaftH / 2, cz + math.sin(a) * 8.1)
		kit.deco(model, Vector3.new(0.6, shaftH - 10, 0.6), CFrame.new(stripPos), Config.Theme.Accent2, Enum.Material.Neon)
	end
	-- observation pod
	local py = CURB + shaftH
	vcyl(6, 64, py, Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	vcyl(0.6, 65.5, py - 0.3, Config.Theme.Accent, Enum.Material.Neon)
	vcyl(14, 60, py + 6, GLASS_DARK, Enum.Material.Glass, { transparency = 0.25, reflectance = 0.3 })
	local core = vcyl(12, 56, py + 7, WARM, Enum.Material.Neon, { transparency = 0.45, collide = false })
	kit.addLight("PointLight", core, WARM, 60, 1.5)
	vcyl(3, 70, py + 20, Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	vcyl(0.6, 71.5, py + 23, Config.Theme.Accent2, Enum.Material.Neon)
	vcyl(6, 50, py + 23, Color3.fromRGB(32, 32, 36), Enum.Material.Metal)
	vcyl(6, 28, py + 29, Color3.fromRGB(32, 32, 36), Enum.Material.Metal)
	kit.spire(model, cx, cz, py + 35, 2)
	searchlight(kit, model, Vector3.new(cx, py + 26.5, cz + 22), 2.4, Color3.fromRGB(255, 220, 180))
end

-- Called for every city block; returns true if a landmark was built there
function CityPremium.landmark(kit: any, parent: Instance, bi: number, bj: number, cx: number, cz: number, lot: number): boolean
	if not G.Landmarks then
		return false
	end
	local a, b = C.Blocks / 2 - 1, C.Blocks / 2
	if bi == a and bj == a then
		legendsTower(kit, parent, cx, cz, lot)
		return true
	elseif bi == b and bj == b then
		twistTower(kit, parent, cx, cz, lot)
		return true
	elseif bi == b and bj == a then
		needle(kit, parent, cx, cz, lot)
		return true
	end
	return false
end

---------------------------------------------------------------------
-- Streetscape
---------------------------------------------------------------------
local AD_TEXTS = { "ECLIPSE JX", "NIGHT RUN", "MIDNIGHT FM", "CUT UP\nGET PAID", "VORTEX V10", "NEON NIGHTS", "KAIZEN RZ" }

local function busStop(kit: any, parent: Instance, pos: Vector3, outward: Vector3)
	local deco, mk = kit.deco, kit.mk
	local tangent = outward:Cross(Vector3.yAxis)
	local cf = CFrame.lookAt(pos, pos + outward)
	-- outward = towards the road; shelter back wall faces the buildings
	mk(parent, Vector3.new(12, 0.4, 5), cf * CFrame.new(0, 8.6, 0), Color3.fromRGB(26, 26, 30), Enum.Material.Metal, { name = "Shelter" })
	deco(parent, Vector3.new(11.6, 0.15, 0.4), cf * CFrame.new(0, 8.35, -2.2), Color3.fromRGB(255, 235, 210), Enum.Material.Neon)
	for _, sx in { -5.8, 5.8 } do
		deco(parent, Vector3.new(0.35, 8.4, 0.35), cf * CFrame.new(sx, 4.2, 2.2), kit.METAL, Enum.Material.Metal)
	end
	deco(parent, Vector3.new(11.6, 7, 0.2), cf * CFrame.new(0, 4.6, 2.3), Color3.fromRGB(30, 40, 50), Enum.Material.Glass, { transparency = 0.5 })
	local ad = deco(parent, Vector3.new(0.4, 6.5, 3.6), cf * CFrame.new(-6.2, 4.4, 0), Color3.fromRGB(10, 10, 14), Enum.Material.SmoothPlastic)
	local c = kit.pick(kit.NEON_COLORS)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local _, frame, _ = kit.surfaceText(ad, face, kit.pick(AD_TEXTS), Color3.new(1, 1, 1), c, 0, Enum.Font.GothamBlack, Vector2.new(220, 400))
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(c, kit.pick(kit.NEON_COLORS))
		grad.Rotation = 90
		grad.Parent = frame
		CollectionService:AddTag(grad, "AnimatedBoard")
	end
	-- ad panel faces sideways along the street: rotate so Front/Back look along the tangent
	ad.CFrame = CFrame.lookAt(ad.CFrame.Position, ad.CFrame.Position + tangent)
	deco(parent, Vector3.new(7, 0.5, 1.6), cf * CFrame.new(1, 2, 1.4), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	if kit.rng:NextNumber() < 0.5 then
		kit.addLight("PointLight", ad, c, 16, 1.2)
	end
end

function CityPremium.streetscape(kit: any, parent: Instance, cx: number, cz: number, inner: number)
	if not G.StreetDetail then
		return
	end
	local deco, rng = kit.deco, kit.rng
	local folder = kit.lodGroup(parent, "Streetscape", Vector3.new(cx, CURB, cz), 380 + inner / 2)
	for _, edge in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local tangent = edge:Cross(Vector3.yAxis)
		local base = Vector3.new(cx, CURB, cz) + edge * (inner / 2 - 4.5)
		-- tree planters
		for _, t in { -0.4, -0.13, 0.13, 0.4 } do
			local p = base + tangent * (inner * t)
			kit.mk(folder, Vector3.new(4.5, 1.4, 4.5), CFrame.new(p + Vector3.new(0, 0.7, 0)), Color3.fromRGB(46, 46, 50), Enum.Material.Concrete, { name = "Planter" })
			local h = rng:NextNumber(9, 13)
			deco(folder, Vector3.new(0.9, h, 0.9), CFrame.new(p + Vector3.new(0, 1.4 + h / 2, 0)), Color3.fromRGB(48, 34, 26), Enum.Material.Wood, { shadow = true })
			deco(folder, Vector3.one * rng:NextNumber(7, 9), CFrame.new(p + Vector3.new(0, 1.4 + h, 0)), Color3.fromRGB(24, 54, 32), Enum.Material.Grass, { shape = Enum.PartType.Ball, shadow = true })
			deco(folder, Vector3.one * rng:NextNumber(5, 6.5), CFrame.new(p + Vector3.new(rng:NextNumber(-1.5, 1.5), 1.4 + h + 2.5, rng:NextNumber(-1.5, 1.5))), Color3.fromRGB(30, 62, 36), Enum.Material.Grass, { shape = Enum.PartType.Ball, shadow = true })
		end
		-- bench + bin
		local bp = base + tangent * (inner * 0.03)
		local bcf = CFrame.lookAt(bp, bp + edge)
		deco(folder, Vector3.new(6, 0.4, 1.8), bcf * CFrame.new(0, 1.6, 0), Color3.fromRGB(70, 50, 36), Enum.Material.WoodPlanks, { shadow = true })
		deco(folder, Vector3.new(6, 1.6, 0.3), bcf * CFrame.new(0, 2.6, 0.9), Color3.fromRGB(70, 50, 36), Enum.Material.WoodPlanks)
		deco(folder, Vector3.new(5.4, 1.4, 1.2), bcf * CFrame.new(0, 0.7, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
		deco(folder, Vector3.new(2.8, 1.6, 1.6), bcf * CFrame.new(5, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(34, 40, 36), Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
		-- hydrant near the curb
		local hp = Vector3.new(cx, CURB, cz) + edge * (inner / 2 - 1.6) + tangent * (inner * 0.27)
		deco(folder, Vector3.new(2.2, 1, 1), CFrame.new(hp + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(170, 20, 20), Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
		deco(folder, Vector3.one * 1, CFrame.new(hp + Vector3.new(0, 2.3, 0)), Color3.fromRGB(170, 20, 20), Enum.Material.Metal, { shape = Enum.PartType.Ball })
		-- lit bus shelter on some streets
		if rng:NextNumber() < 0.28 then
			busStop(kit, folder, base + tangent * (inner * -0.27) + edge * 1, edge)
		end
	end
end

---------------------------------------------------------------------
-- Environment: steam, water, distant skyline, clouds, monorail track
---------------------------------------------------------------------
local function steamVents(kit: any, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Steam"
	folder.Parent = parent
	local graph = CityLayout.buildGraph()
	local placed = 0
	local tries = 0
	while placed < 18 and tries < 200 do
		tries += 1
		local seg = graph.lanes[kit.rng:NextInteger(1, #graph.lanes)]
		if seg.lane == 2 then
			local pos, dir = CityLayout.sample(seg, seg.length * kit.rng:NextNumber(0.3, 0.7))
			local right = dir:Cross(Vector3.yAxis)
			local p = pos - right * (C.LaneWidth / 2) -- on the lane divider
			kit.deco(folder, Vector3.new(0.12, 3.4, 3.4), CFrame.new(p + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(34, 34, 36), Enum.Material.DiamondPlate, { shape = Enum.PartType.Cylinder })
			local emitter = kit.deco(folder, Vector3.new(1, 1, 1), CFrame.new(p + Vector3.new(0, 0.6, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { transparency = 1 })
			local smoke = Instance.new("Smoke")
			smoke.Color = Color3.fromRGB(205, 205, 220)
			smoke.Opacity = 0.09
			smoke.RiseVelocity = 3.5
			smoke.Size = 7
			smoke.TimeScale = 0.6
			smoke.Parent = emitter
			placed += 1
		end
	end
end

local function water(kit: any, parent: Instance)
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(10, 18, 32)
	terrain.WaterReflectance = 1
	terrain.WaterTransparency = 0.25
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 7
	local o = E + RING
	local far = 1500
	local regions = {
		{ 0, -(o + far / 2), 2 * (o + far), far }, -- north
		{ 0, o + far / 2, 2 * (o + far), far }, -- south
		{ -(o + far / 2), 0, far, 2 * o }, -- west
	}
	for _, r in regions do
		terrain:FillBlock(CFrame.new(r[1], -9, r[2]), Vector3.new(r[3], 14, r[4]), Enum.Material.Water)
	end
	-- quay edge: dark stone lip with a string of promenade lights
	local quay = Instance.new("Folder")
	quay.Name = "Waterfront"
	quay.Parent = parent
	local lights = 0
	for _, side in { { Vector3.new(0, 0, -1), "x" }, { Vector3.new(0, 0, 1), "x" }, { Vector3.new(-1, 0, 0), "z" } } do
		local n = side[1] :: Vector3
		for t = -o + 40, o - 40, 80 do
			local p = n * (o - 2) + (if side[2] == "x" then Vector3.new(t, 0, 0) else Vector3.new(0, 0, t))
			local bulb = kit.deco(quay, Vector3.new(1.2, 1.2, 1.2), CFrame.new(p + Vector3.new(0, CURB + 7, 0)), WARM, Enum.Material.Neon, { shape = Enum.PartType.Ball })
			kit.deco(quay, Vector3.new(0.4, 7, 0.4), CFrame.new(p + Vector3.new(0, CURB + 3.5, 0)), kit.METAL, Enum.Material.Metal)
			lights += 1
			if lights % 3 == 0 then
				kit.addLight("PointLight", bulb, WARM, 20, 1)
			end
		end
	end
end

local function distantSkyline(kit: any, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "DistantSkyline"
	folder.Parent = parent
	local rng = kit.rng
	local o = E + RING
	for _, side in { { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0) }, { Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1) }, { Vector3.new(0, 0, 1), Vector3.new(1, 0, 0) } } do
		local n, t = side[1], side[2]
		for k = -14, 14 do
			local dist = o + 1350 + rng:NextNumber(0, 250)
			local along = k * 150 + rng:NextNumber(-40, 40)
			local h = rng:NextNumber(60, 320)
			local w = rng:NextNumber(50, 110)
			local p = n * dist + t * along
			kit.deco(folder, Vector3.new(w, h, w), CFrame.new(p.X, h / 2 - 2, p.Z), Color3.fromRGB(12, 14, 20), Enum.Material.SmoothPlastic)
			for _ = 1, rng:NextInteger(2, 4) do
				local y = rng:NextNumber(10, h - 6)
				local c = if rng:NextNumber() < 0.6 then WARM else COOL
				local fp = p - n * (w / 2 + 0.1)
				kit.deco(folder, Vector3.new(w * rng:NextNumber(0.3, 0.9), 3, 0.3), CFrame.lookAt(Vector3.new(fp.X, y, fp.Z), Vector3.new(fp.X, y, fp.Z) - n), c, Enum.Material.Neon, { transparency = 0.35 })
			end
			if h > 220 then
				local beacon = kit.deco(folder, Vector3.one * 3, CFrame.new(p.X, h, p.Z), Color3.fromRGB(255, 20, 20), Enum.Material.Neon, { shape = Enum.PartType.Ball })
				CollectionService:AddTag(beacon, "Blink")
			end
		end
	end
end

local function clouds()
	local existing = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local c = existing or Instance.new("Clouds")
	c.Cover = 0.5
	c.Density = 0.45
	c.Color = Color3.fromRGB(70, 60, 110)
	c.Parent = workspace.Terrain
end

local function monorailTrack(kit: any, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Monorail"
	folder.Parent = parent
	local total = CityLayout.monorailLength()
	local segLen = 60
	local count = math.ceil(total / segLen)
	local step = total / count
	local R = E + Config.Monorail.Offset
	local cornerStart = R - Config.Monorail.CornerRadius
	local concrete = Color3.fromRGB(150, 150, 158)
	for k = 0, count - 1 do
		local a = CityLayout.monorailSample(k * step)
		local b = CityLayout.monorailSample((k + 1) * step)
		local cf = CFrame.lookAt((a + b) / 2, b)
		local len = (b - a).Magnitude + 0.4
		kit.mk(folder, Vector3.new(4.2, 2.6, len), cf, concrete, Enum.Material.Concrete, { name = "Guideway" })
		kit.deco(folder, Vector3.new(0.6, 0.2, len), cf * CFrame.new(0, -1.4, 0), Config.Theme.Accent, Enum.Material.Neon)
		for _, sx in { -1, 1 } do
			kit.deco(folder, Vector3.new(0.3, 0.5, len), cf * CFrame.new(sx * 2.2, 0.8, 0), kit.METAL, Enum.Material.Metal)
		end
		-- pillars on the straights, never on a road or the highway
		if k % 2 == 0 then
			local onCorner = math.abs(a.X) > cornerStart - 1 and math.abs(a.Z) > cornerStart - 1
			local overHighway = a.X > cornerStart and math.abs(a.Z) < HW + 20
			if not onCorner and not overHighway then
				local ph = a.Y - 1.3 - CURB
				kit.mk(folder, Vector3.new(ph, 3.6, 3.6), CFrame.new(a.X, CURB + ph / 2, a.Z) * CFrame.Angles(0, 0, math.pi / 2), concrete, Enum.Material.Concrete, { shape = Enum.PartType.Cylinder })
				kit.deco(folder, Vector3.new(7, 2, 5), CFrame.new(a.X, a.Y - 2.3, a.Z) * cf.Rotation, concrete, Enum.Material.Concrete)
			end
		end
	end
end

function CityPremium.environment(kit: any, city: Instance)
	if G.StreetDetail then
		steamVents(kit, city)
	end
	if G.Water then
		water(kit, city)
		distantSkyline(kit, city)
		clouds()
	end
	if G.Monorail then
		monorailTrack(kit, city)
	end
end

return CityPremium
