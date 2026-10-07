--[[
	CityBuilder
	Procedurally builds the whole night city on the server:
	  * grid of 4-lane roads with markings, stop lines and crosswalks
	  * sidewalks + towers with lit window bands, neon shop signs, billboards,
	    rooftop aviation lights and parks
	  * street lights and working traffic-light heads at every intersection
	  * a skyline ring around the city
	  * a 6-lane highway that leaves the city, runs through a mountain tunnel
	    (with the CITY LEGENDS sign inside) and ends in a turnaround plaza
	  * night lighting / atmosphere / post-processing
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CityLayout = require(Shared:WaitForChild("CityLayout"))

local CityBuilder = {}

local C = Config.City
local N = C.Blocks
local B = C.BlockSize
local HALF_ROAD = C.RoadWidth / 2
local CURB = C.CurbHeight
local E = C.HalfExtent + HALF_ROAD -- outer edge of the perimeter roads
local RING = C.OuterRingDepth
local HW = C.HighwayWidth / 2
local HWY_X0 = CityLayout.HighwayStartX
local HWY_X1 = HWY_X0 + C.HighwayLength
local TUNNEL_X0 = HWY_X0 + C.TunnelStart
local TUNNEL_X1 = TUNNEL_X0 + C.TunnelLength
local PLAZA_X = HWY_X1 + C.PlazaRadius

local rng = Random.new(20261007)

---------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------
type PartOpts = {
	collide: boolean?,
	transparency: number?,
	reflectance: number?,
	shadow: boolean?,
	shape: Enum.PartType?,
	class: string?,
	name: string?,
}

local function mk(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, o: PartOpts?): BasePart
	local opts: PartOpts = o or {}
	local p: BasePart
	if opts.class == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if opts.shape then
			part.Shape = opts.shape
		end
		p = part
	end
	p.Name = opts.name or "Part"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = opts.transparency or 0
	p.Reflectance = opts.reflectance or 0
	local collide = opts.collide ~= false
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.CastShadow = opts.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- decorative, non-colliding
local function deco(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, o: PartOpts?): BasePart
	local opts: PartOpts = o or {}
	opts.collide = false
	if opts.shadow == nil then
		opts.shadow = false
	end
	return mk(parent, size, cf, color, material, opts)
end

-- Axis aligned slab between two corners, split into tiles (Roblox parts max out at 2048 studs)
local function slab(parent: Instance, x0: number, z0: number, x1: number, z1: number, top: number, thickness: number, color: Color3, material: Enum.Material, o: PartOpts?)
	local maxTile = 1000
	local xa, xb = math.min(x0, x1), math.max(x0, x1)
	local za, zb = math.min(z0, z1), math.max(z0, z1)
	local nx = math.max(1, math.ceil((xb - xa) / maxTile))
	local nz = math.max(1, math.ceil((zb - za) / maxTile))
	local sx, sz = (xb - xa) / nx, (zb - za) / nz
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local cx = xa + sx * (ix + 0.5)
			local cz = za + sz * (iz + 0.5)
			mk(parent, Vector3.new(sx, thickness, sz), CFrame.new(cx, top - thickness / 2, cz), color, material, o)
		end
	end
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function addLight(className: string, parent: Instance, color: Color3, range: number, brightness: number, face: Enum.NormalId?, angle: number?): Light
	local l = Instance.new(className) :: Light
	l.Color = color
	l.Brightness = brightness
	l.Shadows = false
	if l:IsA("PointLight") then
		l.Range = range
	elseif l:IsA("SpotLight") then
		l.Range = range
		l.Face = face or Enum.NormalId.Bottom
		l.Angle = angle or 90
	elseif l:IsA("SurfaceLight") then
		l.Range = range
		l.Face = face or Enum.NormalId.Front
		l.Angle = angle or 90
	end
	l.Parent = parent
	return l
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3, bg: Color3?, bgTransparency: number?, font: Enum.Font?, canvas: Vector2?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 2.2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvas or Vector2.new(600, 200)
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = bg or Color3.new(0, 0, 0)
	frame.BackgroundTransparency = bgTransparency or 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Font = font or Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = textColor:Lerp(Color3.new(1, 1, 1), 0.6)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.4
	stroke.Parent = label
	return gui, frame, label
end

---------------------------------------------------------------------
-- Palette
---------------------------------------------------------------------
local ASPHALT = Color3.fromRGB(30, 30, 34)
local SIDEWALK = Color3.fromRGB(78, 78, 84)
local CURB_COLOR = Color3.fromRGB(110, 110, 116)
local LINE_WHITE = Color3.fromRGB(205, 205, 200)
local LINE_YELLOW = Color3.fromRGB(230, 170, 30)
local STREETLIGHT = Color3.fromRGB(255, 196, 130)
local METAL = Color3.fromRGB(38, 40, 44)

local WINDOW_COLORS = {
	Color3.fromRGB(255, 214, 160),
	Color3.fromRGB(255, 196, 120),
	Color3.fromRGB(255, 230, 190),
	Color3.fromRGB(190, 220, 255),
	Color3.fromRGB(160, 200, 255),
	Color3.fromRGB(230, 240, 255),
}
local NEON_COLORS = {
	Color3.fromRGB(255, 40, 140),
	Color3.fromRGB(0, 230, 255),
	Color3.fromRGB(150, 70, 255),
	Color3.fromRGB(255, 120, 0),
	Color3.fromRGB(40, 255, 140),
	Color3.fromRGB(255, 230, 40),
	Color3.fromRGB(255, 60, 60),
}
local SHOP_NAMES = {
	"NOODLE BAR", "24/7", "HOTEL NOVA", "ARCADE", "SUSHI", "PHARMACY", "NEON CLUB", "PIZZA",
	"MOTEL", "JAZZ", "RAMEN", "CINEMA", "GYM", "CAFE", "TATTOO", "DINER", "KARAOKE", "BARBER",
	"TACOS", "VINYL", "LOUNGE", "BOBA", "GARAGE", "TUNING", "DONUTS",
}
local BILLBOARDS = {
	"CITY LEGENDS", "DRIVE FAST\nLIVE LEGEND", "VORTEX V10", "NIGHT RUN", "ECLIPSE JX", "KAIZEN RZ",
	"MIDNIGHT FM 98.7", "NEON NIGHTS", "PHANTOM W16", "CUT UP\nGET PAID",
}

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

---------------------------------------------------------------------
-- Lighting / atmosphere
---------------------------------------------------------------------
function CityBuilder.setupLighting()
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 0.3
	Lighting.Brightness = 1.2
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(22, 22, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 40, 70)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.25
	Lighting.ColorShift_Top = Color3.fromRGB(90, 70, 160)
	Lighting.ColorShift_Bottom = Color3.fromRGB(20, 20, 40)

	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.StarCount = 5000
	sky.CelestialBodiesShown = true
	sky.MoonAngularSize = 14
	sky.Parent = Lighting

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.32
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(70, 60, 120)
	atmo.Decay = Color3.fromRGB(30, 20, 60)
	atmo.Glare = 0.4
	atmo.Haze = 1.6
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.9
	bloom.Size = 30
	bloom.Threshold = 0.85
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.02
	cc.Contrast = 0.18
	cc.Saturation = 0.2
	cc.TintColor = Color3.fromRGB(235, 232, 255)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting
end

---------------------------------------------------------------------
-- Roads
---------------------------------------------------------------------
local function dashedLine(parent: Instance, a: Vector3, b: Vector3, width: number, dash: number, gap: number, color: Color3)
	local dir = b - a
	local len = dir.Magnitude
	local unit = dir.Unit
	local look = CFrame.lookAt(Vector3.zero, unit)
	local s = gap / 2
	while s + dash <= len do
		local center = a + unit * (s + dash / 2)
		deco(parent, Vector3.new(width, 0.05, dash), CFrame.new(center.X, 0.03, center.Z) * look.Rotation, color, Enum.Material.SmoothPlastic, { reflectance = 0.05 })
		s += dash + gap
	end
end

local function solidLine(parent: Instance, a: Vector3, b: Vector3, width: number, color: Color3)
	local dir = b - a
	local center = (a + b) / 2
	deco(parent, Vector3.new(width, 0.05, dir.Magnitude), CFrame.lookAt(Vector3.new(center.X, 0.03, center.Z), Vector3.new(b.X, 0.03, b.Z)), color, Enum.Material.SmoothPlastic, { reflectance = 0.05 })
end

local function buildRoadMarkings(parent: Instance)
	local marks = folder("Markings", parent)
	-- segments between adjacent intersections
	for i = 0, N do
		for j = 0, N do
			local a = CityLayout.intersectionPos(i, j)
			for k = 1, 2 do -- east and south neighbours only (each road once)
				local ni, nj = i + (if k == 1 then 1 else 0), j + (if k == 2 then 1 else 0)
				if CityLayout.inGrid(ni, nj) then
					local b = CityLayout.intersectionPos(ni, nj)
					local dir = CityLayout.Dirs[k]
					local right = dir:Cross(Vector3.yAxis)
					local s0 = a + dir * (HALF_ROAD + 4)
					local s1 = b - dir * (HALF_ROAD + 4)
					-- double yellow centre line
					solidLine(marks, s0 + right * 0.35, s1 + right * 0.35, 0.3, LINE_YELLOW)
					solidLine(marks, s0 - right * 0.35, s1 - right * 0.35, 0.3, LINE_YELLOW)
					-- lane dividers
					for side = -1, 1, 2 do
						dashedLine(marks, s0 + right * side * C.LaneWidth, s1 + right * side * C.LaneWidth, 0.35, 10, 14, LINE_WHITE)
					end
				end
			end
			-- stop lines + crosswalks on each approach
			for k = 1, 4 do
				local dir = CityLayout.Dirs[k]
				local pi, pj = i - (if k == 1 then 1 elseif k == 3 then -1 else 0), j - (if k == 2 then 1 elseif k == 4 then -1 else 0)
				if CityLayout.inGrid(pi, pj) then
					local right = dir:Cross(Vector3.yAxis)
					local stop = a - dir * (HALF_ROAD + CityLayout.StopLineGap - 0.6)
					local center = stop + right * (HALF_ROAD / 2)
					deco(marks, Vector3.new(HALF_ROAD - 1, 0.05, 1.2), CFrame.lookAt(Vector3.new(center.X, 0.035, center.Z), Vector3.new(center.X, 0.035, center.Z) + dir), LINE_WHITE, Enum.Material.SmoothPlastic)
					-- zebra crossing just inside the intersection box
					local cw = a - dir * (HALF_ROAD - 3)
					for s = -2, 2 do
						local p = cw + right * (s * 9)
						deco(marks, Vector3.new(4, 0.05, 5), CFrame.lookAt(Vector3.new(p.X, 0.035, p.Z), Vector3.new(p.X, 0.035, p.Z) + dir), LINE_WHITE, Enum.Material.SmoothPlastic, { transparency = 0.1 })
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Street furniture
---------------------------------------------------------------------
local function streetLight(parent: Instance, base: Vector3, armDir: Vector3)
	local height = 22
	mk(parent, Vector3.new(height, 0.7, 0.7), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), METAL, Enum.Material.Metal, { shape = Enum.PartType.Cylinder, name = "LampPost" })
	local armEnd = base + Vector3.new(0, height, 0) + armDir * 7
	deco(parent, Vector3.new(0.4, 0.4, 7), CFrame.lookAt((base + Vector3.new(0, height, 0) + armEnd) / 2, armEnd), METAL, Enum.Material.Metal)
	local head = deco(parent, Vector3.new(2.6, 0.5, 1.2), CFrame.lookAt(armEnd - Vector3.new(0, 0.3, 0), armEnd - Vector3.new(0, 0.3, 0) + armDir), METAL, Enum.Material.Metal)
	local lamp = deco(parent, Vector3.new(2.2, 0.15, 1), head.CFrame * CFrame.new(0, -0.3, 0), STREETLIGHT, Enum.Material.Neon)
	addLight("SpotLight", lamp, STREETLIGHT, 46, 2.4, Enum.NormalId.Bottom, 115)
end

local function trafficSignal(parent: Instance, i: number, j: number, k: number)
	-- signal for traffic travelling in direction k into intersection (i, j)
	local center = CityLayout.intersectionPos(i, j)
	local dir = CityLayout.Dirs[k]
	local right = dir:Cross(Vector3.yAxis)
	local axis = if k % 2 == 1 then "X" else "Z"
	local poleBase = center - dir * (HALF_ROAD + 5) + right * (HALF_ROAD + 4) + Vector3.new(0, CURB, 0)
	local poleH = 19
	mk(parent, Vector3.new(poleH, 0.9, 0.9), CFrame.new(poleBase + Vector3.new(0, poleH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(28, 30, 34), Enum.Material.Metal, { shape = Enum.PartType.Cylinder, name = "SignalPole" })
	local armLen = HALF_ROAD + 2
	local armStart = poleBase + Vector3.new(0, poleH - 1, 0)
	local armEnd = armStart - right * armLen
	deco(parent, Vector3.new(0.5, 0.5, armLen), CFrame.lookAt((armStart + armEnd) / 2, armEnd), Color3.fromRGB(28, 30, 34), Enum.Material.Metal)

	-- signal head over the middle of the approach lanes
	for _, off in { HALF_ROAD * 0.55 } do
		local headPos = armStart - right * (armLen - off) - Vector3.new(0, 2.6, 0)
		-- face the oncoming cars (their forward is +dir, so the face looks at -dir)
		local headCF = CFrame.lookAt(headPos, headPos - dir)
		deco(parent, Vector3.new(1.6, 4.8, 1.2), headCF, Color3.fromRGB(18, 18, 20), Enum.Material.SmoothPlastic)
		deco(parent, Vector3.new(2.4, 5.6, 0.15), headCF * CFrame.new(0, 0, 0.65), Color3.fromRGB(12, 12, 12), Enum.Material.SmoothPlastic)
		for idx, state in { "R", "Y", "G" } do
			-- cylinder axis is X: turn it so the round face looks down the road
			local lampCF = headCF * CFrame.new(0, (2 - idx) * 1.5, -0.55) * CFrame.Angles(0, math.pi / 2, 0)
			local lamp = deco(parent, Vector3.new(0.3, 1.05, 1.05), lampCF, Color3.fromRGB(30, 30, 30), Enum.Material.Neon, { shape = Enum.PartType.Cylinder, name = "Lamp" })
			lamp:SetAttribute("I", i)
			lamp:SetAttribute("J", j)
			lamp:SetAttribute("Axis", axis)
			lamp:SetAttribute("State", state)
			CollectionService:AddTag(lamp, "TrafficLamp")
			-- visor
			deco(parent, Vector3.new(1.3, 0.12, 0.7), headCF * CFrame.new(0, (2 - idx) * 1.5 + 0.62, -0.9), Color3.fromRGB(14, 14, 14), Enum.Material.SmoothPlastic)
		end
	end
end

---------------------------------------------------------------------
-- Buildings
---------------------------------------------------------------------
local function building(parent: Instance, cx: number, cz: number, w: number, dpt: number, h: number, base: number, frontNormal: Vector3)
	local model = Instance.new("Model")
	model.Name = "Building"
	model.Parent = parent

	local style = rng:NextInteger(1, 4)
	local bodyColor, bodyMat, refl
	if style == 1 then
		bodyColor, bodyMat, refl = Color3.fromRGB(22, 28, 40), Enum.Material.Glass, 0.25
	elseif style == 2 then
		bodyColor, bodyMat, refl = Color3.fromRGB(58, 55, 52), Enum.Material.Concrete, 0
	elseif style == 3 then
		bodyColor, bodyMat, refl = Color3.fromRGB(34, 34, 40), Enum.Material.SmoothPlastic, 0.08
	else
		bodyColor, bodyMat, refl = Color3.fromRGB(70, 48, 40), Enum.Material.Brick, 0
	end
	local top = base + h
	mk(model, Vector3.new(w, h, dpt), CFrame.new(cx, base + h / 2, cz), bodyColor, bodyMat, { reflectance = refl, name = "Tower" })

	-- Lit window bands
	local floorH = 11
	local floors = math.floor((h - 16) / floorH)
	local litChance = rng:NextNumber(0.35, 0.7)
	local warm = rng:NextNumber() < 0.6
	local faces = {
		{ n = Vector3.new(0, 0, -1), len = w, off = dpt / 2 },
		{ n = Vector3.new(0, 0, 1), len = w, off = dpt / 2 },
		{ n = Vector3.new(-1, 0, 0), len = dpt, off = w / 2 },
		{ n = Vector3.new(1, 0, 0), len = dpt, off = w / 2 },
	}
	for f = 1, floors do
		local y = base + 16 + (f - 0.5) * floorH
		for _, face in faces do
			if rng:NextNumber() < litChance then
				local segs = if style == 2 or style == 4 then 2 else 1
				for _ = 1, segs do
					local bandLen = face.len * rng:NextNumber(0.2, 0.9) / segs
					local slack = face.len - 4 - bandLen
					local along = rng:NextNumber(-slack / 2, slack / 2)
					local color = if warm then WINDOW_COLORS[rng:NextInteger(1, 3)] else WINDOW_COLORS[rng:NextInteger(3, 6)]
					local center = Vector3.new(cx, y, cz) + face.n * (face.off + 0.05)
					local tangent = face.n:Cross(Vector3.yAxis)
					center += tangent * along
					local cf = CFrame.lookAt(center, center + face.n)
					deco(model, Vector3.new(bandLen, 4.2, 0.2), cf, color, Enum.Material.Neon, { transparency = rng:NextNumber(0.15, 0.45) })
				end
			end
		end
	end

	-- Ground floor storefront facing the road
	local tangent = frontNormal:Cross(Vector3.yAxis)
	local frontLen = if math.abs(frontNormal.X) > 0.5 then dpt else w
	local frontOff = if math.abs(frontNormal.X) > 0.5 then w / 2 else dpt / 2
	local shopPos = Vector3.new(cx, base + 5, cz) + frontNormal * (frontOff + 0.1)
	deco(model, Vector3.new(frontLen * 0.85, 8, 0.2), CFrame.lookAt(shopPos, shopPos + frontNormal), Color3.fromRGB(255, 225, 180), Enum.Material.Neon, { transparency = 0.55 })
	local neon = pick(NEON_COLORS)
	local signPos = Vector3.new(cx, base + 12.5, cz) + frontNormal * (frontOff + 0.6) + tangent * rng:NextNumber(-frontLen * 0.2, frontLen * 0.2)
	local sign = deco(model, Vector3.new(math.min(30, frontLen * 0.6), 5, 0.6), CFrame.lookAt(signPos, signPos + frontNormal), Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic)
	surfaceText(sign, Enum.NormalId.Front, pick(SHOP_NAMES), neon, nil, nil, Enum.Font.GothamBlack, Vector2.new(600, 100))
	local signGlow = deco(model, Vector3.new(sign.Size.X + 0.6, 0.25, 0.25), sign.CFrame * CFrame.new(0, -2.8, -0.2), neon, Enum.Material.Neon)
	if rng:NextNumber() < 0.45 then
		addLight("PointLight", signGlow, neon, 26, 1.6)
	end

	-- Neon corner strips on some towers
	if h > 120 and rng:NextNumber() < 0.3 then
		local c = pick(NEON_COLORS)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				deco(model, Vector3.new(0.5, h - 20, 0.5), CFrame.new(cx + sx * (w / 2 + 0.1), base + 20 + (h - 20) / 2, cz + sz * (dpt / 2 + 0.1)), c, Enum.Material.Neon)
			end
		end
	end

	-- Roof: parapet, aviation light, billboard
	mk(model, Vector3.new(w + 1, 2, dpt + 1), CFrame.new(cx, top + 1, cz), Color3.fromRGB(25, 25, 28), Enum.Material.Concrete, { name = "Parapet" })
	if h > 180 then
		local antennaH = rng:NextNumber(15, 45)
		deco(model, Vector3.new(antennaH, 0.8, 0.8), CFrame.new(cx, top + 2 + antennaH / 2, cz) * CFrame.Angles(0, 0, math.pi / 2), METAL, Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
		local beacon = deco(model, Vector3.new(1.6, 1.6, 1.6), CFrame.new(cx, top + 2 + antennaH, cz), Color3.fromRGB(255, 20, 20), Enum.Material.Neon, { shape = Enum.PartType.Ball })
		CollectionService:AddTag(beacon, "Blink")
	end
	if h > 90 and rng:NextNumber() < 0.28 then
		local bw = math.min(w * 0.9, 60)
		local bpos = Vector3.new(cx, top + 2 + 12, cz) + frontNormal * (frontOff * 0.6)
		local board = deco(model, Vector3.new(bw, 20, 1), CFrame.lookAt(bpos, bpos + frontNormal), Color3.fromRGB(8, 8, 10), Enum.Material.SmoothPlastic)
		local c1 = pick(NEON_COLORS)
		local _, frame, _ = surfaceText(board, Enum.NormalId.Front, pick(BILLBOARDS), Color3.new(1, 1, 1), c1, 0, Enum.Font.GothamBlack, Vector2.new(900, 300))
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(c1, pick(NEON_COLORS))
		grad.Rotation = rng:NextInteger(0, 90)
		grad.Parent = frame
		deco(model, Vector3.new(bw + 1, 0.5, 0.5), board.CFrame * CFrame.new(0, -10.3, 0), c1, Enum.Material.Neon)
		for _, sx in { -0.35, 0.35 } do
			deco(model, Vector3.new(0.6, 12, 0.6), board.CFrame * CFrame.new(bw * sx, -14, 1), METAL, Enum.Material.Metal)
		end
	end
	return model
end

local function tree(parent: Instance, pos: Vector3)
	local h = rng:NextNumber(10, 16)
	deco(parent, Vector3.new(h, 1.1, 1.1), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(45, 32, 24), Enum.Material.Wood, { shape = Enum.PartType.Cylinder, shadow = true })
	for _ = 1, 3 do
		local r = rng:NextNumber(6, 9)
		deco(parent, Vector3.one * r, CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), h + rng:NextNumber(-1, 2), rng:NextNumber(-2, 2))), Color3.fromRGB(24, 52, 30), Enum.Material.Grass, { shape = Enum.PartType.Ball, shadow = true })
	end
end

local function park(parent: Instance, cx: number, cz: number, size: number)
	local top = CURB
	mk(parent, Vector3.new(size - 20, 0.3, size - 20), CFrame.new(cx, top + 0.15, cz), Color3.fromRGB(26, 46, 28), Enum.Material.Grass, { collide = true })
	-- cross paths
	deco(parent, Vector3.new(size - 20, 0.35, 8), CFrame.new(cx, top + 0.18, cz), Color3.fromRGB(70, 66, 60), Enum.Material.Pavement)
	deco(parent, Vector3.new(8, 0.35, size - 20), CFrame.new(cx, top + 0.18, cz), Color3.fromRGB(70, 66, 60), Enum.Material.Pavement)
	-- fountain
	mk(parent, Vector3.new(1.5, 30, 30), CFrame.new(cx, top + 0.9, cz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(90, 90, 95), Enum.Material.Marble, { shape = Enum.PartType.Cylinder })
	local water = deco(parent, Vector3.new(0.4, 26, 26), CFrame.new(cx, top + 1.5, cz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 140, 255), Enum.Material.Neon, { shape = Enum.PartType.Cylinder, transparency = 0.45 })
	addLight("PointLight", water, Color3.fromRGB(60, 150, 255), 35, 2)
	deco(parent, Vector3.new(10, 2, 2), CFrame.new(cx, top + 6, cz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 210, 255), Enum.Material.Neon, { shape = Enum.PartType.Cylinder, transparency = 0.3 })
	for _ = 1, 14 do
		local px = cx + rng:NextNumber(-size / 2 + 20, size / 2 - 20)
		local pz = cz + rng:NextNumber(-size / 2 + 20, size / 2 - 20)
		if math.abs(px - cx) > 14 and math.abs(pz - cz) > 14 then
			tree(parent, Vector3.new(px, top + 0.3, pz))
		end
	end
	-- warm path lamps
	for _, off in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local p = Vector3.new(cx + off[1] * size * 0.22, top, cz + off[2] * 7)
		deco(parent, Vector3.new(0.4, 8, 0.4), CFrame.new(p + Vector3.new(0, 4, 0)), METAL, Enum.Material.Metal)
		local bulb = deco(parent, Vector3.new(1.2, 1.2, 1.2), CFrame.new(p + Vector3.new(0, 8.4, 0)), STREETLIGHT, Enum.Material.Neon, { shape = Enum.PartType.Ball })
		addLight("PointLight", bulb, STREETLIGHT, 22, 1.2)
	end
end

-- Fill a rectangular lot area with buildings on a sub-grid
local function fillBuildings(parent: Instance, x0: number, z0: number, x1: number, z1: number, heightFn: (number, number) -> number, cell: number, forcedFront: Vector3?)
	local nx = math.max(1, math.floor((x1 - x0) / cell))
	local nz = math.max(1, math.floor((z1 - z0) / cell))
	local cw = (x1 - x0) / nx
	local cd = (z1 - z0) / nz
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local cx = x0 + cw * (ix + 0.5)
			local cz = z0 + cd * (iz + 0.5)
			local w = cw * rng:NextNumber(0.68, 0.88)
			local dpt = cd * rng:NextNumber(0.68, 0.88)
			local h = heightFn(cx, cz)
			-- storefront faces whichever road is nearest
			local bx = (x0 + x1) / 2
			local bz = (z0 + z1) / 2
			local front
			local dx, dz = cx - bx, cz - bz
			if forcedFront then
				front = forcedFront
			elseif math.abs(dx) / (x1 - x0) > math.abs(dz) / (z1 - z0) then
				front = Vector3.new(if dx >= 0 then 1 else -1, 0, 0)
			else
				front = Vector3.new(0, 0, if dz >= 0 then 1 else -1)
			end
			building(parent, cx, cz, w, dpt, h, CURB, front)
		end
	end
end

local function downtownHeight(x: number, z: number): number
	local dist = Vector2.new(x, z).Magnitude / C.HalfExtent
	local falloff = math.clamp(1 - dist, 0, 1)
	local h = 50 + 330 * falloff ^ 1.5 + rng:NextNumber(0, 90)
	if rng:NextNumber() < 0.12 then
		h += 120 * falloff + 60
	end
	return math.floor(h)
end

---------------------------------------------------------------------
-- City grid
---------------------------------------------------------------------
local function buildBlocks(parent: Instance)
	local blocks = folder("Blocks", parent)
	local inner = B - C.RoadWidth
	for bi = 0, N - 1 do
		for bj = 0, N - 1 do
			local cx = (CityLayout.roadCoord(bi) + CityLayout.roadCoord(bi + 1)) / 2
			local cz = (CityLayout.roadCoord(bj) + CityLayout.roadCoord(bj + 1)) / 2
			local blockFolder = folder(`Block_{bi}_{bj}`, blocks)
			-- raised sidewalk slab (acts as a curb the car slides along)
			mk(blockFolder, Vector3.new(inner, CURB, inner), CFrame.new(cx, CURB / 2, cz), SIDEWALK, Enum.Material.Pavement, { name = "Sidewalk" })
			-- curb edge highlight
			for _, s in { -1, 1 } do
				deco(blockFolder, Vector3.new(inner, CURB + 0.02, 0.8), CFrame.new(cx, CURB / 2, cz + s * (inner / 2 - 0.4)), CURB_COLOR, Enum.Material.Concrete)
				deco(blockFolder, Vector3.new(0.8, CURB + 0.02, inner), CFrame.new(cx + s * (inner / 2 - 0.4), CURB / 2, cz), CURB_COLOR, Enum.Material.Concrete)
			end

			local isPark = rng:NextNumber() < 0.12 and not (bi == N / 2 - 1 and bj == N / 2 - 1)
			local lot = inner - C.SidewalkWidth * 2
			if isPark then
				park(blockFolder, cx, cz, inner)
			else
				local cell = if rng:NextNumber() < 0.25 then lot else lot / 2
				fillBuildings(blockFolder, cx - lot / 2, cz - lot / 2, cx + lot / 2, cz + lot / 2, downtownHeight, cell - 1)
			end

			-- street lights along each edge (arms reach over the road)
			for _, edge in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
				local tangent = edge:Cross(Vector3.yAxis)
				for _, t in { -0.25, 0.25 } do
					local pos = Vector3.new(cx, CURB, cz) + edge * (inner / 2 - 2) + tangent * (inner * t)
					streetLight(blockFolder, pos, edge)
				end
			end
		end
	end
end

local function buildSignals(parent: Instance)
	local signals = folder("TrafficLights", parent)
	for i = 0, N do
		for j = 0, N do
			for k = 1, 4 do
				local dir = CityLayout.Dirs[k]
				-- approach exists if the previous intersection is in the grid
				local pi = i - math.round(dir.X)
				local pj = j - math.round(dir.Z)
				if CityLayout.inGrid(pi, pj) then
					trafficSignal(signals, i, j, k)
				end
			end
		end
	end
end

local function buildRing(parent: Instance)
	local ring = folder("Skyline", parent)
	local function ringHeight(_x: number, _z: number): number
		return math.floor(rng:NextNumber(110, 360))
	end
	-- {x0, z0, x1, z1, storefront direction (towards the city)}
	local regions: { { any } } = {
		{ -E - RING, -E - RING, E + RING, -E, Vector3.new(0, 0, 1) }, -- north
		{ -E - RING, E, E + RING, E + RING, Vector3.new(0, 0, -1) }, -- south
		{ -E - RING, -E, -E, E, Vector3.new(1, 0, 0) }, -- west
		{ E, -E, E + RING, -HW - 16, Vector3.new(-1, 0, 0) }, -- east (north of the highway)
		{ E, HW + 16, E + RING, E, Vector3.new(-1, 0, 0) }, -- east (south of the highway)
	}
	for _, r in regions do
		slab(ring, r[1], r[2], r[3], r[4], CURB, CURB, SIDEWALK, Enum.Material.Pavement)
		fillBuildings(ring, r[1] + 14, r[2] + 14, r[3] - 14, r[4] - 14, ringHeight, 118, r[5])
	end
	-- street lights facing the perimeter roads
	for s = -1, 1, 2 do
		for t = -E + 60, E - 60, 150 do
			streetLight(ring, Vector3.new(t, CURB, s * (E + 3)), Vector3.new(0, 0, -s))
			if math.abs(t) > HW + 30 or s == -1 then
				streetLight(ring, Vector3.new(s * (E + 3), CURB, t), Vector3.new(-s, 0, 0))
			end
		end
	end
	-- invisible boundary walls around the skyline ring (gap on the east for the highway)
	local o = E + RING
	local wallParts = {
		{ -o, -o - 2, o, -o + 2 },
		{ -o, o - 2, o, o + 2 },
		{ -o - 2, -o, -o + 2, o },
		{ o - 2, -o, o + 2, -HW - 6 },
		{ o - 2, HW + 6, o + 2, o },
	}
	for _, w in wallParts do
		slab(ring, w[1], w[2], w[3], w[4], 400, 400, Color3.new(), Enum.Material.SmoothPlastic, { transparency = 1, name = "Boundary" })
	end
end

---------------------------------------------------------------------
-- Highway, mountain, tunnel and plaza
---------------------------------------------------------------------
local function cityLegendsSign(parent: Instance, pos: Vector3, width: number, height: number)
	local sign = deco(parent, Vector3.new(1, height, width), CFrame.new(pos), Color3.fromRGB(6, 6, 10), Enum.Material.SmoothPlastic, { name = "CityLegendsSign" })
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 3
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(1400, math.floor(1400 * height / width))
		gui.Parent = sign
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.9, 0.62)
		label.Position = UDim2.fromScale(0.05, 0.12)
		label.Font = Enum.Font.GothamBlack
		label.Text = "CITY LEGENDS"
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = frame
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Config.Theme.Accent),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Config.Theme.Accent2),
		})
		grad.Parent = label
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.fromScale(0.9, 0.16)
		sub.Position = UDim2.fromScale(0.05, 0.76)
		sub.Font = Enum.Font.GothamBold
		sub.Text = "WELCOME TO THE NIGHT"
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(180, 185, 200)
		sub.Parent = frame
	end
	-- neon frame
	local c1, c2 = Config.Theme.Accent, Config.Theme.Accent2
	deco(parent, Vector3.new(1.4, 0.5, width + 1), CFrame.new(pos + Vector3.new(0, height / 2 + 0.25, 0)), c1, Enum.Material.Neon)
	deco(parent, Vector3.new(1.4, 0.5, width + 1), CFrame.new(pos - Vector3.new(0, height / 2 + 0.25, 0)), c2, Enum.Material.Neon)
	deco(parent, Vector3.new(1.4, height + 1, 0.5), CFrame.new(pos + Vector3.new(0, 0, width / 2 + 0.25)), c2, Enum.Material.Neon)
	deco(parent, Vector3.new(1.4, height + 1, 0.5), CFrame.new(pos - Vector3.new(0, 0, width / 2 + 0.25)), c1, Enum.Material.Neon)
	for _, dx in { -6, 6 } do
		local glow = deco(parent, Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(dx, -height / 2 - 1, 0)), c1, Enum.Material.SmoothPlastic, { transparency = 1 })
		addLight("PointLight", glow, if dx < 0 then c1 else c2, 40, 2.5)
	end
	return sign
end

local function buildHighway(parent: Instance)
	local hwy = folder("Highway", parent)
	-- surrounding terrain
	slab(hwy, E + RING, -1400, PLAZA_X + 400, 1400, -0.3, 4, Color3.fromRGB(18, 26, 18), Enum.Material.Grass)
	-- road surface (inside the skyline ring the city asphalt is already there)
	slab(hwy, E + RING, -HW - 6, HWY_X1 + 10, HW + 6, 0, 2, ASPHALT, Enum.Material.Asphalt)

	-- markings
	local marks = folder("HighwayMarkings", hwy)
	local a = Vector3.new(HWY_X0 + 4, 0, 0)
	local b = Vector3.new(HWY_X1, 0, 0)
	solidLine(marks, a + Vector3.new(0, 0, 0.4), b + Vector3.new(0, 0, 0.4), 0.3, LINE_YELLOW)
	solidLine(marks, a - Vector3.new(0, 0, 0.4), b - Vector3.new(0, 0, 0.4), 0.3, LINE_YELLOW)
	for _, z in { -24, -12, 12, 24 } do
		dashedLine(marks, a + Vector3.new(0, 0, z), b + Vector3.new(0, 0, z), 0.35, 12, 18, LINE_WHITE)
	end
	for _, z in { -HW + 1, HW - 1 } do
		solidLine(marks, a + Vector3.new(0, 0, z), b + Vector3.new(0, 0, z), 0.4, LINE_WHITE)
	end

	-- guard rails + invisible walls
	for _, s in { -1, 1 } do
		local x0 = E + RING
		local len = HWY_X1 - x0
		for part = 0, 1 do
			local cx = x0 + len * (part * 0.5 + 0.25)
			mk(hwy, Vector3.new(len / 2, 1.2, 0.6), CFrame.new(cx, 2.2, s * (HW + 2)), Color3.fromRGB(150, 152, 158), Enum.Material.Metal, { reflectance = 0.2, name = "GuardRail" })
			mk(hwy, Vector3.new(len / 2, 60, 2), CFrame.new(cx, 30, s * (HW + 3)), Color3.new(), Enum.Material.SmoothPlastic, { transparency = 1, name = "Wall" })
		end
		for x = x0 + 10, HWY_X1, 24 do
			if x < TUNNEL_X0 - 4 or x > TUNNEL_X1 + 4 then
				deco(hwy, Vector3.new(0.5, 2.6, 0.5), CFrame.new(x, 1.3, s * (HW + 2.2)), METAL, Enum.Material.Metal)
			end
		end
		-- reflectors (little amber dots)
		for x = x0 + 22, HWY_X1, 48 do
			deco(hwy, Vector3.new(0.4, 0.3, 0.2), CFrame.new(x, 2.2, s * (HW + 1.65)), Color3.fromRGB(255, 160, 40), Enum.Material.Neon)
		end
	end

	-- highway lights (outside the tunnel)
	for x = HWY_X0 + 40, HWY_X1, 160 do
		if x < TUNNEL_X0 - 20 or x > TUNNEL_X1 + 20 then
			streetLight(hwy, Vector3.new(x, 0, -(HW + 5)), Vector3.new(0, 0, 1))
			streetLight(hwy, Vector3.new(x + 80, 0, HW + 5), Vector3.new(0, 0, -1))
		end
	end

	-- overhead gantry sign leaving the city
	local gx = E + RING + 120
	for _, s in { -1, 1 } do
		mk(hwy, Vector3.new(1.2, 26, 1.2), CFrame.new(gx, 13, s * (HW + 4)), METAL, Enum.Material.Metal)
	end
	deco(hwy, Vector3.new(1.4, 1.4, HW * 2 + 10), CFrame.new(gx, 25, 0), METAL, Enum.Material.Metal)
	local gsign = deco(hwy, Vector3.new(0.6, 7, 34), CFrame.new(gx - 0.5, 20, HW / 2), Color3.fromRGB(10, 70, 40), Enum.Material.SmoothPlastic)
	surfaceText(gsign, Enum.NormalId.Left, "TUNNEL  ➜  1 MI", Color3.new(1, 1, 1), Color3.fromRGB(10, 90, 50), 0, Enum.Font.GothamBold, Vector2.new(800, 160))
	local gsign2 = deco(hwy, Vector3.new(0.6, 7, 34), CFrame.new(gx + 0.5, 20, -HW / 2), Color3.fromRGB(10, 70, 40), Enum.Material.SmoothPlastic)
	surfaceText(gsign2, Enum.NormalId.Right, "DOWNTOWN", Color3.new(1, 1, 1), Color3.fromRGB(10, 90, 50), 0, Enum.Font.GothamBold, Vector2.new(800, 160))

	-------------------------------------------------------------
	-- Mountain
	-------------------------------------------------------------
	local rock = Color3.fromRGB(34, 32, 32)
	local mtn = folder("Mountain", hwy)
	local mx = (TUNNEL_X0 + TUNNEL_X1) / 2
	local tunnelH = 22
	for _, s in { -1, 1 } do
		-- main massif on each side of the tunnel
		mk(mtn, Vector3.new(C.TunnelLength, 240, 700), CFrame.new(mx, 100, s * (HW + 4 + 350)), rock, Enum.Material.Slate)
		-- sloped approaches
		-- (a wedge's slope faces local -Z; rotating +90deg about Y points it at -X)
		mk(mtn, Vector3.new(700, 240, 260), CFrame.new(TUNNEL_X0 - 130, 100, s * (HW + 4 + 350)) * CFrame.Angles(0, math.pi / 2, 0), rock, Enum.Material.Slate, { class = "Wedge" })
		mk(mtn, Vector3.new(700, 240, 260), CFrame.new(TUNNEL_X1 + 130, 100, s * (HW + 4 + 350)) * CFrame.Angles(0, -math.pi / 2, 0), rock, Enum.Material.Slate, { class = "Wedge" })
		for _ = 1, 6 do
			local p = Vector3.new(mx + rng:NextNumber(-350, 350), rng:NextNumber(150, 230), s * rng:NextNumber(HW + 120, 600))
			mk(mtn, Vector3.new(rng:NextNumber(120, 240), rng:NextNumber(80, 160), rng:NextNumber(120, 240)), CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), rock, Enum.Material.Slate)
		end
	end
	-- ridge over the tunnel
	mk(mtn, Vector3.new(C.TunnelLength, 200, HW * 2 + 12), CFrame.new(mx, tunnelH + 3 + 100, 0), rock, Enum.Material.Slate)
	mk(mtn, Vector3.new(HW * 2 + 12, 120, 90), CFrame.new(TUNNEL_X0 - 45, tunnelH + 3 + 60, 0) * CFrame.Angles(0, math.pi / 2, 0), rock, Enum.Material.Slate, { class = "Wedge" })
	mk(mtn, Vector3.new(HW * 2 + 12, 120, 90), CFrame.new(TUNNEL_X1 + 45, tunnelH + 3 + 60, 0) * CFrame.Angles(0, -math.pi / 2, 0), rock, Enum.Material.Slate, { class = "Wedge" })

	-------------------------------------------------------------
	-- Tunnel
	-------------------------------------------------------------
	local tunnel = folder("Tunnel", hwy)
	local concrete = Color3.fromRGB(96, 96, 100)
	for _, s in { -1, 1 } do
		mk(tunnel, Vector3.new(C.TunnelLength, tunnelH, 3), CFrame.new(mx, tunnelH / 2, s * (HW + 2.5)), concrete, Enum.Material.Concrete, { name = "TunnelWall" })
		-- lower tiled band
		deco(tunnel, Vector3.new(C.TunnelLength, 6, 0.2), CFrame.new(mx, 4, s * (HW + 0.95)), Color3.fromRGB(190, 192, 196), Enum.Material.SmoothPlastic, { reflectance = 0.15 })
		deco(tunnel, Vector3.new(C.TunnelLength, 0.6, 0.2), CFrame.new(mx, 7.3, s * (HW + 0.9)), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
		-- sodium lamps
		local idx = 0
		for x = TUNNEL_X0 + 10, TUNNEL_X1 - 10, 20 do
			idx += 1
			local lamp = deco(tunnel, Vector3.new(7, 0.7, 1), CFrame.new(x, tunnelH - 3, s * (HW + 0.6)), Color3.fromRGB(255, 160, 60), Enum.Material.Neon)
			if idx % 2 == 0 then
				addLight("PointLight", lamp, Color3.fromRGB(255, 150, 60), 30, 1.6)
			end
		end
	end
	mk(tunnel, Vector3.new(C.TunnelLength, 3, HW * 2 + 8), CFrame.new(mx, tunnelH + 1.5, 0), Color3.fromRGB(40, 40, 44), Enum.Material.Concrete, { name = "TunnelCeiling" })
	-- centre ceiling light strip
	for x = TUNNEL_X0 + 15, TUNNEL_X1 - 15, 30 do
		deco(tunnel, Vector3.new(10, 0.3, 1.2), CFrame.new(x, tunnelH - 0.2, 0), Color3.fromRGB(255, 220, 170), Enum.Material.Neon)
	end
	-- portals
	for _, px in { TUNNEL_X0, TUNNEL_X1 } do
		local facing = if px == TUNNEL_X0 then -1 else 1
		mk(tunnel, Vector3.new(6, 12, HW * 2 + 30), CFrame.new(px + facing * 3, tunnelH + 6, 0), Color3.fromRGB(70, 70, 74), Enum.Material.Concrete, { name = "Portal" })
		for _, s in { -1, 1 } do
			mk(tunnel, Vector3.new(6, tunnelH + 12, 12), CFrame.new(px + facing * 3, (tunnelH + 12) / 2, s * (HW + 9)), Color3.fromRGB(70, 70, 74), Enum.Material.Concrete)
		end
		local plaque = deco(tunnel, Vector3.new(0.5, 6, 56), CFrame.new(px + facing * 6.3, tunnelH + 6, 0), Color3.fromRGB(10, 10, 14), Enum.Material.SmoothPlastic)
		surfaceText(plaque, if facing == -1 then Enum.NormalId.Left else Enum.NormalId.Right, "LEGENDS TUNNEL", Color3.fromRGB(255, 190, 90), nil, nil, Enum.Font.GothamBlack, Vector2.new(1100, 120))
	end

	-- THE sign
	cityLegendsSign(tunnel, Vector3.new(mx, tunnelH - 7.5, 0), 58, 10)

	-------------------------------------------------------------
	-- Turn-around plaza
	-------------------------------------------------------------
	local plaza = folder("Plaza", hwy)
	local R = C.PlazaRadius
	mk(plaza, Vector3.new(2, R * 2, R * 2), CFrame.new(PLAZA_X, -1, 0) * CFrame.Angles(0, 0, math.pi / 2), ASPHALT, Enum.Material.Asphalt, { shape = Enum.PartType.Cylinder })
	mk(plaza, Vector3.new(1.2, 64, 64), CFrame.new(PLAZA_X, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), SIDEWALK, Enum.Material.Pavement, { shape = Enum.PartType.Cylinder, name = "Island" })
	local obelisk = mk(plaza, Vector3.new(6, 70, 6), CFrame.new(PLAZA_X, 35, 0), Color3.fromRGB(14, 14, 18), Enum.Material.Glass, { reflectance = 0.3 })
	for _, s in { -1, 1 } do
		deco(plaza, Vector3.new(0.4, 66, 0.4), CFrame.new(PLAZA_X + s * 3.1, 35, 3.1), Config.Theme.Accent, Enum.Material.Neon)
		deco(plaza, Vector3.new(0.4, 66, 0.4), CFrame.new(PLAZA_X + s * 3.1, 35, -3.1), Config.Theme.Accent2, Enum.Material.Neon)
	end
	addLight("PointLight", obelisk, Config.Theme.Accent, 60, 2)
	local segs = 32
	for k = 0, segs - 1 do
		local a0 = k / segs * math.pi * 2
		local p = Vector3.new(PLAZA_X + math.cos(a0) * (R + 1), 2.2, math.sin(a0) * (R + 1))
		-- leave the mouth open where the highway arrives
		if not (math.cos(a0) < -0.9 and math.abs(math.sin(a0) * R) < HW + 8) then
			local len = 2 * math.pi * (R + 1) / segs + 0.5
			mk(plaza, Vector3.new(len, 1.2, 0.6), CFrame.lookAt(p, p + Vector3.new(-math.sin(a0), 0, math.cos(a0))) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(150, 152, 158), Enum.Material.Metal, { reflectance = 0.2 })
			mk(plaza, Vector3.new(len, 60, 2), CFrame.lookAt(p, p + Vector3.new(-math.sin(a0), 0, math.cos(a0))) * CFrame.Angles(0, math.pi / 2, 0) + Vector3.new(0, 28, 0), Color3.new(), Enum.Material.SmoothPlastic, { transparency = 1 })
		end
	end
	for k = 0, 7 do
		local a0 = k / 8 * math.pi * 2 + 0.2
		streetLight(plaza, Vector3.new(PLAZA_X + math.cos(a0) * (R - 3), 0, math.sin(a0) * (R - 3)), Vector3.new(-math.cos(a0), 0, -math.sin(a0)))
	end
end

---------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------
function CityBuilder.build(): Folder
	CityBuilder.setupLighting()

	local existing = workspace:FindFirstChild("City")
	if existing then
		existing:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local city = Instance.new("Folder")
	city.Name = "City"

	-- one big asphalt ground: every gap between blocks is road
	local ground = folder("Ground", city)
	slab(ground, -E - RING, -E - RING, E + RING, E + RING, 0, 4, ASPHALT, Enum.Material.Asphalt)

	buildRoadMarkings(city)
	buildBlocks(city)
	buildSignals(city)
	buildRing(city)
	buildHighway(city)

	city.Parent = workspace
	city:SetAttribute("Ready", true)
	return city
end

return CityBuilder
