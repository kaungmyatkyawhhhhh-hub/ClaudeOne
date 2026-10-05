-- Town builder (run once in Studio; see tools/bake.md): the sunny beach-side town around the gyms. Output:
--   Workspace.Town  street + sidewalks + crosswalks, the gym forecourt and gym exteriors, the plaza, the smoothie bar
--                   (with the ShakeMachine), the Gear & Fits clothing store (ShopPrompt), the skate park, the beach,
--                   the beach gym (3 machines + a pull-up bar), the posing stage (PosePrompt), background buildings,
--                   street lamps and props, and the invisible boundary.
--   Terrain         grass/leafy grass/ground with gentle bumps in the town and hills all around, sand and the sea to
--                   the horizon (no flat baseplate edge anywhere). The old Baseplate and flat Grass part are removed.
-- Layout numbers are in Config.Town. Needs GymKit/GymAssets (beach gym machines) and TownKit.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Kit)
local TownKit = require(script.Parent.TownKit)
local GymKit = require(script.Parent.GymKit)
local Town = require(ReplicatedStorage.Shared.Config.Town)
local Stamina = require(ReplicatedStorage.Shared.Config.Stamina)
local Machines = require(ReplicatedStorage.Shared.Config.Machines)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local Builder = {}

local C, p, cyl, ball, model = TownKit.C, TownKit.p, TownKit.cyl, TownKit.ball, TownKit.model
local hex, rad = Kit.hex, math.rad
local M = Enum.Material
local up = CFrame.Angles(0, 0, rad(90))

local folder -- Workspace.Town

local function look(position, toward)
	return CFrame.lookAt(position, Vector3.new(toward.X, position.Y, toward.Z))
end

------------------------------------------------------------------------
-- Terrain
------------------------------------------------------------------------
-- Note: Roblox draws a terrain surface about 2 studs above the filled height (a voxel with occupancy o has its
-- surface at cellCenter + 4o), so every fill below is 2 studs lower than the surface it makes.
local function buildTerrain()
	local terrain = Workspace.Terrain
	for _, name in ipairs({ "Baseplate" }) do
		local old = Workspace:FindFirstChild(name)
		if old then old:Destroy() end
	end
	terrain:Clear()
	-- fresh, sunny greens (the default grass reads yellow in this lighting)
	terrain:SetMaterialColor(M.Grass, hex("#6FA14F"))
	terrain:SetMaterialColor(M.LeafyGrass, hex("#5E9145"))
	terrain:SetMaterialColor(M.Ground, hex("#8A7356"))
	terrain:SetMaterialColor(M.Sand, hex("#E8D8AE"))
	terrain:SetMaterialColor(M.Pavement, hex("#B2AB9F"))
	-- a light, sunny haze at the horizon (the old gray-brown one made a dirty band over the sea)
	local atmosphere = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = hex("#D8E3EC")
		atmosphere.Decay = hex("#9FB4C6")
		atmosphere.Haze = 1.0
	end
	local shore = Town.Sea.MinZ
	-- ground: grass to just under y = 0 everywhere south of the beach (paved parts sit on top at 0..0.4)
	terrain:FillBlock(CFrame.new(0, -10.6, (shore - 1400) / 2 + 2), Vector3.new(7000, 16, 1400 + shore), M.Grass)
	-- patches of leafy grass and bare ground mixed in (thin, at the surface)
	local rng = Random.new(7)
	for _ = 1, 260 do
		local x, z = rng:NextNumber(-700, 700), rng:NextNumber(-700, shore - 30)
		local r = rng:NextNumber(6, 22)
		terrain:FillCylinder(CFrame.new(x, -3.2, z), 1.2, r, rng:NextNumber() < 0.65 and M.LeafyGrass or M.Ground)
	end
	-- under streets, paving and buildings: bare ground (grass blades would poke through thin paving)
	for _, r in ipairs({
		{ -152, 188, 16, 40 }, { -39, 96, -76, 20 }, { -50, 50, 36, 72 }, { -140, 178, 36, 58 },
		{ -134, -40, 0, 20 }, { 94, 172, 0, 20 }, { -72, -18, 68, 116 },
	}) do
		terrain:FillBlock(CFrame.new((r[1] + r[2]) / 2, -4.2, (r[3] + r[4]) / 2), Vector3.new(r[2] - r[1], 4, r[4] - r[3]), M.Pavement)
	end
	-- gentle bumps on the lawns inside the town (never under roads or buildings: those spots are listed in Town.Lawns)
	for _, lawn in ipairs(Town.Lawns) do
		for _ = 1, lawn.bumps do
			local x = rng:NextNumber(lawn.MinX + 4, lawn.MaxX - 4)
			local z = rng:NextNumber(lawn.MinZ + 4, lawn.MaxZ - 4)
			local r = rng:NextNumber(4, 7)
			terrain:FillBall(Vector3.new(x, -r - 2 + rng:NextNumber(0.5, 1.1), z), r, rng:NextNumber() < 0.5 and M.Grass or M.LeafyGrass)
		end
	end
	-- hills all around outside the town (south, east and west), rising with distance
	local b = Town.Bounds
	local function hill(x, z, r, top)
		terrain:FillBall(Vector3.new(x, top - r, z), r, rng:NextNumber() < 0.7 and M.Grass or M.LeafyGrass)
	end
	for x = -460, 460, 60 do
		for z = -420, shore - 60, 60 do
			local outside = x < b.MinX - 25 or x > b.MaxX + 25 or z < b.MinZ - 25
			if outside then
				local dx = math.max(b.MinX - 25 - x, x - (b.MaxX + 25), 0)
				local dz = math.max(b.MinZ - 25 - z, 0)
				local d = math.sqrt(dx * dx + dz * dz)
				local top = math.min(70, 6 + d * 0.22 + rng:NextNumber(-4, 8))
				hill(x + rng:NextNumber(-18, 18), z + rng:NextNumber(-18, 18), rng:NextNumber(40, 70), top)
			end
		end
	end
	-- beach: sand from the plaza edge down into the water, then the sea to the horizon
	local beach = Town.Beach
	terrain:FillBlock(CFrame.new((beach.MinX + beach.MaxX) / 2, -6, (beach.MinZ + shore) / 2), Vector3.new(beach.MaxX - beach.MinX, 8, shore - beach.MinZ), M.Sand)
	-- the sea: water first, then the sand slope and the sea floor (sand replaces water where they meet)
	terrain:FillBlock(CFrame.new(0, -5.6, shore + 2400), Vector3.new(7000, 10, 4800), M.Water) -- water has no offset: surface -0.6
	terrain:FillWedge(CFrame.new(40, -5, shore + 10) * CFrame.Angles(0, math.pi, 0), Vector3.new(7000, 6, 20), M.Sand)
	terrain:FillBlock(CFrame.new(0, -16, shore + 2400), Vector3.new(7000, 8, 4800), M.Sand)
	-- sand along the whole shoreline (the hills meet the sea on a beach, not a cliff of grass)
	terrain:FillBlock(CFrame.new(0, -3.5, shore - 6), Vector3.new(7000, 3, 14), M.Sand)
end

------------------------------------------------------------------------
-- Streets
------------------------------------------------------------------------
local function buildStreets()
	local s = Town.Street
	local x0, x1 = s.MinX, s.MaxX
	local len, mid = x1 - x0, (x0 + x1) / 2
	local street = Instance.new("Folder")
	street.Name = "Street"
	street.Parent = folder
	p(street, "Asphalt", Vector3.new(len, 0.4, s.MaxZ - s.MinZ), CFrame.new(mid, -0.15, (s.MinZ + s.MaxZ) / 2), C.Asphalt, M.Asphalt, true)
	for _, edge in ipairs({ { s.MinZ - 4, s.MinZ }, { s.MaxZ, s.MaxZ + 4 } }) do
		p(street, "Sidewalk", Vector3.new(len, 0.6, 4), CFrame.new(mid, 0.05, (edge[1] + edge[2]) / 2), C.Sidewalk, M.Concrete, true)
		-- paving joints every 4 studs
		for x = x0 + 4, x1 - 1, 4 do p(street, "Joint", Vector3.new(0.06, 0.02, 4), CFrame.new(x, 0.36, (edge[1] + edge[2]) / 2), hex("#A29B8F")) end
	end
	-- paving between the north sidewalk and the shop fronts (split around the plaza, which has its own)
	local pz = Town.Plaza
	for _, span in ipairs({ { x0, pz.MinX }, { pz.MaxX, x1 } }) do
		p(street, "FrontPaving", Vector3.new(span[2] - span[1], 0.4, 6), CFrame.new((span[1] + span[2]) / 2, 0, s.MaxZ + 7), C.Paving, M.Pavement, true)
	end
	p(street, "Curb", Vector3.new(len, 0.7, 0.4), CFrame.new(mid, 0.1, s.MinZ + 0.2), C.Curb, M.Concrete, true)
	p(street, "Curb", Vector3.new(len, 0.7, 0.4), CFrame.new(mid, 0.1, s.MaxZ - 0.2), C.Curb, M.Concrete, true)
	-- lane markings (dashes), crosswalks
	local cz = (s.MinZ + s.MaxZ) / 2
	for x = x0 + 3, x1 - 3, 8 do
		local onCrosswalk = false
		for _, cx in ipairs(Town.Crosswalks) do if math.abs(x - cx) < 6 then onCrosswalk = true end end
		if not onCrosswalk then p(street, "Dash", Vector3.new(4, 0.02, 0.3), CFrame.new(x, 0.06, cz), C.Stripe) end
	end
	for _, cx in ipairs(Town.Crosswalks) do
		for i = -3, 3 do
			p(street, "Crosswalk", Vector3.new(0.9, 0.02, s.MaxZ - s.MinZ - 1.2), CFrame.new(cx + i * 1.5, 0.06, cz), C.Stripe)
		end
	end
	-- street lamps along both sidewalks, evenly spaced, facing the road
	for x = x0 + 8, x1 - 8, 16 do
		TownKit.lamp(street, Vector3.new(x, 0.35, s.MinZ - 0.9), Vector3.new(0, 0, 1))
		TownKit.lamp(street, Vector3.new(x + 8, 0.35, s.MaxZ + 0.9), Vector3.new(0, 0, -1))
	end
	-- the street ends in planted islands with trees at both ends (hills beyond)
	for _, x in ipairs({ x0 + 3, x1 - 3 }) do
		TownKit.planter(street, CFrame.new(x, 0, cz), 4, 10, "bush")
		TownKit.oak(street, Vector3.new(x + (x < 0 and -10 or 10), 0, cz), 1.2)
	end
end

------------------------------------------------------------------------
-- Gym forecourt + exteriors
------------------------------------------------------------------------
local function buildGymFront()
	local front = Instance.new("Folder")
	front.Name = "GymFront"
	front.Parent = folder
	local f = Town.Forecourt
	-- paving (light stone with darker bands) around the entrance hall, never inside it
	local hall = Town.Hall
	local hx0, hx1, hz1 = hall.Center.X - hall.Size.X / 2, hall.Center.X + hall.Size.X / 2, hall.Center.Z + hall.Size.Z / 2
	local function pave(x0, x1, z0, z1)
		p(front, "Paving", Vector3.new(x1 - x0, 0.4, z1 - z0), CFrame.new((x0 + x1) / 2, 0.0, (z0 + z1) / 2), C.Paving, M.Pavement, true)
		for x = x0 + 6, x1 - 1, 6 do p(front, "Band", Vector3.new(0.5, 0.02, z1 - z0), CFrame.new(x, 0.21, (z0 + z1) / 2), C.PavingDark, M.Pavement) end
	end
	pave(f.MinX, hx0, f.MinZ, f.MaxZ)
	pave(hx1, f.MaxX, f.MinZ, f.MaxZ)
	pave(hx0, hx1, hz1, f.MaxZ)
	-- entrance: canopy on two posts over the glass doors, a door mat, a low step and a ramp
	local door = Town.EntranceDoor
	p(front, "EntryPad", Vector3.new(14, 0.25, 5), CFrame.new(door.X, 0.27, door.Z + 3), C.Stone, M.Concrete, true)
	p(front, "Doormat", Vector3.new(6, 0.06, 2.4), CFrame.new(door.X, 0.42, door.Z + 1.6), hex("#2B2B2B"), M.Fabric)
	p(front, "DoormatEdge", Vector3.new(6.2, 0.05, 2.6), CFrame.new(door.X, 0.41, door.Z + 1.6), hex("#151515"), M.Rubber)
	local canopy = CFrame.new(door.X, 9.4, door.Z + 3.6)
	p(front, "CanopyGlass", Vector3.new(12, 0.15, 6.6), canopy, hex("#BFD6DF"), M.Glass, false, { Transparency = 0.45 })
	p(front, "CanopyFrame", Vector3.new(12.3, 0.4, 0.3), canopy * CFrame.new(0, -0.1, 3.3), hex("#1C1C1E"), M.Metal)
	p(front, "CanopyFrame", Vector3.new(12.3, 0.4, 0.3), canopy * CFrame.new(0, -0.1, -3.3), hex("#1C1C1E"), M.Metal)
	for _, x in ipairs({ -6, 6 }) do
		p(front, "CanopyFrame", Vector3.new(0.3, 0.4, 6.6), canopy * CFrame.new(x, -0.1, 0), hex("#1C1C1E"), M.Metal)
		p(front, "CanopyPost", Vector3.new(0.35, 9.2, 0.35), CFrame.new(door.X + x, 4.8, door.Z + 6.6), hex("#1C1C1E"), M.Metal, true)
		local downlight = p(front, "CanopyLight", Vector3.new(0.6, 0.1, 0.6), canopy * CFrame.new(x * 0.5, -0.32, 0), C.Warm, M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color, light.Brightness, light.Range, light.Angle, light.Shadows = C.Warm, 1.2, 14, 90, false
		light.Parent = downlight
	end
	-- the lit GYM ARC sign on the hall front, in a framed backing box
	local signCF = look(Vector3.new(door.X, 11.4, door.Z + 1.6), Vector3.new(door.X, 11.4, door.Z + 40))
	p(front, "SignBox", Vector3.new(13, 2.8, 0.6), signCF * CFrame.new(0, 0, 0.2), hex("#1C1C1E"), M.Metal)
	p(front, "SignFrame", Vector3.new(13.4, 3.2, 0.3), signCF * CFrame.new(0, 0, 0.45), hex("#3A3A3D"), M.Metal)
	local board, label = Kit.sign(front, "GymSign", Vector3.new(12.4, 2.4, 0.1), signCF * CFrame.new(0, 0, -0.12), "GYM ARC", C.Red, hex("#141416"), 50)
	label.FontFace = Theme.Fonts.SemiBold
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Transparency, stroke.Thickness = C.Red, 0.4, 2
	stroke.Parent = label
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Color, glow.Brightness, glow.Range, glow.Shadows = C.Red, 1.2, 10, false
	glow.Parent = board
	-- rooftop sign over the main gym, facing the street
	local roof = look(Vector3.new(-20, 17, -3.6), Vector3.new(-20, 17, 40))
	for _, x in ipairs({ -5, 5 }) do p(front, "RoofSignLeg", Vector3.new(0.3, 3.4, 0.3), roof * CFrame.new(x, -1.6, 0.4), hex("#1C1C1E"), M.Metal) end
	p(front, "RoofSignBack", Vector3.new(13, 3.2, 0.4), roof * CFrame.new(0, 1.2, 0.2), hex("#1C1C1E"), M.Metal)
	local rb, rl = Kit.sign(front, "RoofSign", Vector3.new(12.4, 2.6, 0.1), roof * CFrame.new(0, 1.2, -0.05), "GYM ARC", C.White, hex("#1C1C1E"), 40)
	rl.FontFace = Theme.Fonts.SemiBold
	local rg = Instance.new("SurfaceLight")
	rg.Face = Enum.NormalId.Back
	rg.Color, rg.Brightness, rg.Range, rg.Shadows = hex("#FFF2DD"), 0.8, 8, false
	rg.Parent = rb
	-- the PRO sign on the pro gym front (LED letters on dark glass)
	local pro = look(Vector3.new(66, 12.6, -2.8), Vector3.new(66, 12.6, 40))
	local pb, pl = Kit.sign(front, "ProSign", Vector3.new(16, 2.4, 0.1), pro, "GYM ARC PRO", C.Chalk, hex("#121418"), 40)
	pl.FontFace = Theme.Fonts.SemiBold
	local pg = Instance.new("SurfaceLight")
	pg.Face = Enum.NormalId.Back
	pg.Color, pg.Brightness, pg.Range, pg.Shadows = hex("#DCE6FF"), 1, 10, false
	pg.Parent = pb
	-- roof edge trim (parapets) around both buildings, drainpipes, wall lights
	local function parapet(x0, z0, x1, z1, y, color)
		p(front, "Parapet", Vector3.new(x1 - x0 + 1, 1.2, 0.8), CFrame.new((x0 + x1) / 2, y + 0.6, z0), color, M.Concrete, true)
		p(front, "Parapet", Vector3.new(x1 - x0 + 1, 1.2, 0.8), CFrame.new((x0 + x1) / 2, y + 0.6, z1), color, M.Concrete, true)
		p(front, "Parapet", Vector3.new(0.8, 1.2, z0 - z1), CFrame.new(x0, y + 0.6, (z0 + z1) / 2), color, M.Concrete, true)
		p(front, "Parapet", Vector3.new(0.8, 1.2, z0 - z1), CFrame.new(x1, y + 0.6, (z0 + z1) / 2), color, M.Concrete, true)
		p(front, "Coping", Vector3.new(x1 - x0 + 1.4, 0.2, 1.1), CFrame.new((x0 + x1) / 2, y + 1.3, z0), hex("#CFC6B6"), M.Concrete)
	end
	parapet(-37.5, -2.9, 37, -74.6, 14, hex("#8C4A3A"))
	parapet(-11, 14.1, 11, -2.9, 14, hex("#8C4A3A"))
	parapet(37, -2.9, 94.5, -74.6, 15, hex("#16171A"))
	for _, x in ipairs({ -36.5, -11.5, 11.5, 36.2 }) do
		cyl(front, "Drainpipe", 14, 0.4, CFrame.new(x, 7, -2.6) * up, hex("#3A3A3D"), M.Metal)
		p(front, "Shoe", Vector3.new(0.6, 0.3, 0.8), CFrame.new(x, 0.35, -2.4), hex("#3A3A3D"), M.Metal)
	end
	for _, x in ipairs({ -25, -13, 13, 25, 46, 58, 70, 82, 90 }) do
		local lampCF = CFrame.new(x, 9.6, -2.75)
		p(front, "WallLightArm", Vector3.new(0.12, 0.12, 0.6), lampCF, hex("#1C1C1E"), M.Metal)
		local shade = p(front, "WallLight", Vector3.new(0.7, 0.4, 0.5), lampCF * CFrame.new(0, -0.15, 0.3), x > 37 and C.Chalk or C.Warm, M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color, light.Brightness, light.Range, light.Angle, light.Shadows = x > 37 and hex("#DCE6FF") or C.Warm, 1, 12, 80, false
		light.Parent = shade
	end
	-- planters by the entrance, a bike rack with a couple of bikes, benches, trees in planters along the front
	for _, x in ipairs({ -8, 8 }) do TownKit.planter(front, CFrame.new(x, 0.2, 16.5), 3, 3, "bush") end
	TownKit.bikeRack(front, CFrame.new(-17, 0.2, 9) * CFrame.Angles(0, rad(90), 0), 5)
	TownKit.bike(front, CFrame.new(-17.6, 0.2, 7.8) * CFrame.Angles(0, rad(90), 0), hex("#2E6E8E"))
	TownKit.bike(front, CFrame.new(-17.6, 0.2, 10.2) * CFrame.Angles(0, rad(90), 0), hex("#B5654A"))
	TownKit.bench(front, look(Vector3.new(-28, 0.2, 8), Vector3.new(-28, 0, -20)))
	TownKit.bench(front, look(Vector3.new(24, 0.2, 8), Vector3.new(24, 0, -20)))
	for _, x in ipairs({ -32, -4 - 20, 18, 30, 44, 58, 72, 86 }) do
		if math.abs(x) > 14 then
			TownKit.planter(front, CFrame.new(x, 0.2, 2.6), 3.2, 3.2, x % 2 == 0 and "flowers" or "bush")
		end
	end
	for _, x in ipairs({ 50, 64, 78, 92 }) do TownKit.cypress(front, Vector3.new(x, 0.2, 12), 1.1) end
	TownKit.bin(front, CFrame.new(-12, 0.2, 17.5))
	TownKit.bin(front, CFrame.new(12, 0.2, 17.5))
	TownKit.hydrant(front, CFrame.new(40, 0.35, 19))
end

-- Gym roofs: membrane seams, AC units, skylights, exhaust fans, a hatch; solar panels on the pro gym.
local function buildGymRoofs()
	local roof = Instance.new("Folder")
	roof.Name = "GymRoofs"
	roof.Parent = folder
	local function seams(x0, x1, z0, z1, y, color)
		for x = x0 + 6, x1 - 1, 6 do p(roof, "RoofSeam", Vector3.new(0.12, 0.05, z1 - z0), CFrame.new(x, y + 0.02, (z0 + z1) / 2), color) end
	end
	seams(-37, 37, -74, -3, 14, hex("#55524D"))
	seams(37, 94, -74, -3, 15, hex("#26272A"))
	local function acUnit(cf)
		p(roof, "AcUnit", Vector3.new(4, 2.4, 3), cf * CFrame.new(0, 1.2, 0), hex("#C9C6BF"), M.Metal, true)
		cyl(roof, "AcFan", 0.1, 2.2, cf * CFrame.new(-0.8, 2.45, 0) * up, hex("#4A4C50"), M.DiamondPlate)
		cyl(roof, "AcFan", 0.1, 2.2, cf * CFrame.new(1.0, 2.45, 0) * up, hex("#4A4C50"), M.DiamondPlate)
		p(roof, "AcGrille", Vector3.new(3.8, 1.6, 0.05), cf * CFrame.new(0, 1.1, -1.52), hex("#9E9B94"), M.DiamondPlate)
		p(roof, "AcPipe", Vector3.new(0.3, 0.3, 3), cf * CFrame.new(1.6, 0.3, 3), C.Iron, M.Metal)
	end
	for _, spot in ipairs({ { -28, 14, -60 }, { -28, 14, -48 }, { 26, 14, -66 }, { 84, 15, -60 }, { 84, 15, -48 } }) do
		acUnit(CFrame.new(spot[1], spot[2], spot[3]))
	end
	-- skylights over the starter gym (glass hipped boxes with frames)
	for _, spot in ipairs({ { -8, -24 }, { 10, -24 }, { -8, -44 }, { 10, -44 } }) do
		local cf = CFrame.new(spot[1], 14, spot[2])
		p(roof, "SkylightCurb", Vector3.new(8.4, 0.8, 4.4), cf * CFrame.new(0, 0.4, 0), hex("#8C4A3A"), M.Concrete, true)
		p(roof, "SkylightGlass", Vector3.new(8, 1, 4), cf * CFrame.new(0, 1.3, 0), hex("#9DB3BE"), M.Glass, false, { Transparency = 0.3, Reflectance = 0.2 })
		for x = -4, 4, 2 do p(roof, "SkylightBar", Vector3.new(0.12, 1.05, 4.05), cf * CFrame.new(x, 1.3, 0), C.Iron, M.Metal) end
	end
	-- exhaust fans and a roof hatch
	for _, spot in ipairs({ { 20, 14, -40 }, { -18, 14, -12 }, { 50, 15, -20 } }) do
		local cf = CFrame.new(spot[1], spot[2], spot[3])
		cyl(roof, "FanBase", 0.8, 2.2, cf * CFrame.new(0, 0.4, 0) * up, hex("#9E9B94"), M.Metal, true)
		cyl(roof, "FanHood", 0.6, 2.6, cf * CFrame.new(0, 1.2, 0) * up, hex("#B8B5AE"), M.Metal)
		cyl(roof, "FanCap", 0.3, 1.2, cf * CFrame.new(0, 1.65, 0) * up, hex("#B8B5AE"), M.Metal)
	end
	p(roof, "Hatch", Vector3.new(3, 1, 3), CFrame.new(-30, 14.5, -20), hex("#8C4A3A"), M.Concrete, true)
	p(roof, "HatchLid", Vector3.new(3.2, 0.2, 3.2), CFrame.new(-30, 15.1, -20), C.Iron, M.Metal)
	-- solar panels on the pro gym (tilted rows on frames)
	for row = 0, 3 do
		for col = 0, 4 do
			local cf = CFrame.new(46 + col * 8, 15, -30 - row * 7) * CFrame.Angles(rad(-20), 0, 0)
			p(roof, "SolarFrame", Vector3.new(0.2, 1.4, 0.2), CFrame.new(46 + col * 8 - 3, 15.7, -30 - row * 7 + 1.4), C.Iron, M.Metal)
			p(roof, "SolarFrame", Vector3.new(0.2, 1.4, 0.2), CFrame.new(46 + col * 8 + 3, 15.7, -30 - row * 7 + 1.4), C.Iron, M.Metal)
			p(roof, "SolarPanel", Vector3.new(7, 0.15, 4), cf * CFrame.new(0, 1.3, 0), hex("#1E2A44"), M.Glass, false, { Reflectance = 0.25 })
			p(roof, "SolarEdge", Vector3.new(7.1, 0.12, 4.1), cf * CFrame.new(0, 1.22, 0), hex("#C9CCD2"), M.Metal)
		end
	end
end

------------------------------------------------------------------------
-- Plaza (across the street from the gym)
------------------------------------------------------------------------
local function buildPlaza()
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = folder
	local pz = Town.Plaza
	local cx, cz = (pz.MinX + pz.MaxX) / 2, (pz.MinZ + pz.MaxZ) / 2
	p(plaza, "Paving", Vector3.new(pz.MaxX - pz.MinX, 0.4, pz.MaxZ - pz.MinZ), CFrame.new(cx, 0.0, cz), C.Paving, M.Pavement, true)
	-- a ring pattern around the fountain, and a border band
	for r = 9, 15, 6 do
		cyl(plaza, "Ring", 0.03, r * 2, CFrame.new(cx, 0.2, cz) * up, C.PavingDark, M.Pavement)
		cyl(plaza, "RingInner", 0.035, r * 2 - 1, CFrame.new(cx, 0.2, cz) * up, C.Paving, M.Pavement)
	end
	-- fountain: round basin with a rim, water, a middle tier and a top bowl
	local f = CFrame.new(cx, 0.2, cz)
	cyl(plaza, "Basin", 1.6, 13, f * CFrame.new(0, 0.8, 0) * up, hex("#B5AA98"), M.Concrete, true)
	cyl(plaza, "BasinRim", 0.3, 13.6, f * CFrame.new(0, 1.7, 0) * up, hex("#CFC6B6"), M.Concrete)
	cyl(plaza, "Water", 0.2, 12, f * CFrame.new(0, 1.45, 0) * up, hex("#6FB4C8"), M.Glass, false)
	cyl(plaza, "Column", 3.4, 1.6, f * CFrame.new(0, 3, 0) * up, hex("#CFC6B6"), M.Concrete, true)
	cyl(plaza, "MidBowl", 0.6, 6, f * CFrame.new(0, 4.6, 0) * up, hex("#CFC6B6"), M.Concrete)
	cyl(plaza, "MidWater", 0.1, 5.4, f * CFrame.new(0, 4.92, 0) * up, hex("#6FB4C8"), M.Glass)
	cyl(plaza, "TopColumn", 2, 0.8, f * CFrame.new(0, 5.9, 0) * up, hex("#CFC6B6"), M.Concrete)
	cyl(plaza, "TopBowl", 0.4, 2.6, f * CFrame.new(0, 7, 0) * up, hex("#CFC6B6"), M.Concrete)
	local spray = p(plaza, "Spray", Vector3.new(0.4, 1.2, 0.4), f * CFrame.new(0, 7.8, 0), hex("#BFE3EE"), M.Glass, false, { Transparency = 0.4 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(hex("#DFF3F8"))
	emitter.Size = NumberSequence.new(0.25)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.Speed = NumberRange.new(4, 6)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Rate = 30
	emitter.Parent = spray
	-- benches facing the fountain, trees in planters at the corners, string lights over it all
	for i = 0, 5 do
		local a = rad(i * 60 + 30)
		local pos = Vector3.new(cx + math.cos(a) * 11.5, 0.2, cz + math.sin(a) * 11.5)
		TownKit.bench(plaza, look(pos, Vector3.new(cx + math.cos(a) * 30, 0, cz + math.sin(a) * 30)))
	end
	local corners = { { pz.MinX + 3.5, pz.MinZ + 4 }, { pz.MaxX - 3.5, pz.MinZ + 4 }, { pz.MinX + 3.5, pz.MaxZ - 4 }, { pz.MaxX - 3.5, pz.MaxZ - 4 } }
	for i, c in ipairs(corners) do
		TownKit.planter(plaza, CFrame.new(c[1], 0.2, c[2]), 4.5, 4.5, nil)
		TownKit.roundTree(plaza, Vector3.new(c[1], 1.6, c[2]), 1.1, i)
		-- string light poles
		cyl(plaza, "LightPole", 10, 0.3, CFrame.new(c[1] + (c[1] < cx and 2.6 or -2.6), 5.2, c[2]) * up, C.Iron, M.Metal, true)
	end
	local tops = {}
	for i, c in ipairs(corners) do tops[i] = Vector3.new(c[1] + (c[1] < cx and 2.6 or -2.6), 10, c[2]) end
	TownKit.stringLights(plaza, tops[1], tops[4], 16)
	TownKit.stringLights(plaza, tops[2], tops[3], 16)
	TownKit.stringLights(plaza, tops[1], tops[2], 12)
	TownKit.stringLights(plaza, tops[3], tops[4], 12)
	-- flower beds along the sides, a signpost to everything
	for _, x in ipairs({ pz.MinX + 1.5, pz.MaxX - 1.5 }) do
		for z = pz.MinZ + 12, pz.MaxZ - 12, 8 do TownKit.planter(plaza, CFrame.new(x, 0.2, z), 2.4, 5, "flowers") end
	end
	TownKit.signpost(plaza, CFrame.new(cx + 9, 0.2, pz.MinZ + 3), {
		{ text = "Beach", yaw = -60 }, { text = "Skate park", yaw = -130 }, { text = "Gym", yaw = 90 }, { text = "Smoothies", yaw = 180 },
	})
	TownKit.busStop(plaza, look(Vector3.new(-62, 0.35, Town.Street.MaxZ + 2.6), Vector3.new(-62, 0, 0)))
	TownKit.bin(plaza, CFrame.new(cx - 8, 0.2, pz.MinZ + 2.5))
	-- a boardwalk from the plaza to the beach
	local bw = Town.Boardwalk
	for z = bw.MinZ, bw.MaxZ - 1, 1.2 do
		p(plaza, "Plank", Vector3.new(bw.MaxX - bw.MinX, 0.25, 1.1), CFrame.new((bw.MinX + bw.MaxX) / 2, 0.3, z + 0.55), C.Wood, M.WoodPlanks, true)
	end
	for _, x in ipairs({ bw.MinX, bw.MaxX }) do
		for z = bw.MinZ, bw.MaxZ, 4 do p(plaza, "RopePost", Vector3.new(0.35, 2, 0.35), CFrame.new(x, 1, z), C.WoodDark, M.Wood, true) end
		p(plaza, "Rope", Vector3.new(0.12, 0.12, bw.MaxZ - bw.MinZ), CFrame.new(x, 1.7, (bw.MinZ + bw.MaxZ) / 2), hex("#C9B48A"), M.Fabric)
	end
end

------------------------------------------------------------------------
-- Shops
------------------------------------------------------------------------
-- Shell for a shop: front (local -Z) with two display windows and a glass door, walls, floor, ceiling with lights.
local function shopShell(m, cf, w, d, h, wall, wallMat, floorColor, floorMat)
	p(m, "Floor", Vector3.new(w, 0.3, d), cf * CFrame.new(0, 0.35, d / 2), floorColor, floorMat, true)
	p(m, "Base", Vector3.new(w + 0.4, 1.4, d + 0.4), cf * CFrame.new(0, -0.5, d / 2), hex("#B5AA98"), M.Concrete, true)
	p(m, "BackWall", Vector3.new(w, h, 1), cf * CFrame.new(0, h / 2, d - 0.5), wall, wallMat, true)
	p(m, "WallL", Vector3.new(1, h, d), cf * CFrame.new(-w / 2 + 0.5, h / 2, d / 2), wall, wallMat, true)
	p(m, "WallR", Vector3.new(1, h, d), cf * CFrame.new(w / 2 - 0.5, h / 2, d / 2), wall, wallMat, true)
	p(m, "Ceiling", Vector3.new(w, 0.6, d), cf * CFrame.new(0, h + 0.3, d / 2), hex("#F2EEE6"), M.SmoothPlastic, true)
	p(m, "Roof", Vector3.new(w + 1.2, 0.8, d + 1.2), cf * CFrame.new(0, h + 1, d / 2), hex("#6B6660"), M.Concrete, true)
	p(m, "Cornice", Vector3.new(w + 1.6, 0.6, 0.6), cf * CFrame.new(0, h + 1.4, -0.3), hex("#F7F2E8"), M.Concrete)
	-- front: wall pieces around two windows and the door
	local doorW, winW = 4, (w - 4 - 4) / 2
	for _, side in ipairs({ -1, 1 }) do
		local wx = side * (doorW / 2 + 1 + winW / 2)
		p(m, "FrontPier", Vector3.new(1, h, 1), cf * CFrame.new(side * (w / 2 - 0.5), h / 2, 0.5), wall, wallMat, true)
		p(m, "FrontPier", Vector3.new(1, h, 1), cf * CFrame.new(side * (doorW / 2 + 0.5), h / 2, 0.5), wall, wallMat, true)
		p(m, "WindowSill", Vector3.new(winW, 1.4, 1), cf * CFrame.new(wx, 0.7, 0.5), wall, wallMat, true)
		p(m, "WindowHeader", Vector3.new(winW, h - 8, 1), cf * CFrame.new(wx, 8 + (h - 8) / 2, 0.5), wall, wallMat, true)
		local glass = p(m, "DisplayWindow", Vector3.new(winW, 6.6, 0.15), cf * CFrame.new(wx, 4.7, 0.3), hex("#A8C0CC"), M.Glass, true, { Transparency = 0.6, Reflectance = 0.08 })
		glass.CastShadow = false
		for _, edge in ipairs({ { 0, 8.05, winW + 0.3, 0.25 }, { 0, 1.4, winW + 0.3, 0.25 } }) do
			p(m, "WindowFrame", Vector3.new(edge[3], edge[4], 0.3), cf * CFrame.new(wx + edge[1], edge[2], 0.15), C.Iron, M.Metal)
		end
		p(m, "WindowMullion", Vector3.new(0.18, 6.6, 0.28), cf * CFrame.new(wx, 4.7, 0.15), C.Iron, M.Metal)
	end
	p(m, "DoorHeader", Vector3.new(doorW, h - 8.4, 1), cf * CFrame.new(0, 8.4 + (h - 8.4) / 2, 0.5), wall, wallMat, true)
	for _, side in ipairs({ -1, 1 }) do
		local leaf = p(m, "DoorGlass", Vector3.new(doorW / 2 - 0.15, 8, 0.12), cf * CFrame.new(side * doorW / 4, 4.35, 0.35), hex("#A8C0CC"), M.Glass, false, { Transparency = 0.55 })
		leaf.CanQuery = false
		p(m, "DoorHandle", Vector3.new(0.1, 1.6, 0.15), cf * CFrame.new(side * 0.35, 4.2, 0.2), C.Brass, M.Metal)
		p(m, "DoorFrame", Vector3.new(0.2, 8.2, 0.25), cf * CFrame.new(side * (doorW / 2 - 0.1), 4.35, 0.3), C.Iron, M.Metal)
	end
	p(m, "Threshold", Vector3.new(doorW + 1, 0.15, 1.6), cf * CFrame.new(0, 0.45, -0.3), C.Stone, M.Concrete)
end

local function pendantLight(m, cf, color)
	p(m, "Cord", Vector3.new(0.06, 1.6, 0.06), cf * CFrame.new(0, 0.8, 0), C.Iron)
	local shade = cyl(m, "Shade", 0.8, 1.2, cf * up, color or hex("#2B2B2B"), M.Metal)
	local bulb = ball(m, "Bulb", Vector3.new(0.45, 0.45, 0.45), cf * CFrame.new(0, -0.35, 0), C.Warm, M.Neon)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Color, light.Brightness, light.Range, light.Angle, light.Shadows = C.Warm, 1.6, 16, 110, false
	light.Parent = bulb
	return shade
end

local function stool(m, cf, seatColor)
	cyl(m, "StoolPost", 2.5, 0.25, cf * CFrame.new(0, 1.35, 0) * up, C.Iron, M.Metal, true)
	cyl(m, "StoolBase", 0.15, 1.2, cf * CFrame.new(0, 0.1, 0) * up, C.Iron, M.Metal)
	cyl(m, "FootRing", 0.1, 1.1, cf * CFrame.new(0, 1.0, 0) * up, C.Brass, M.Metal)
	cyl(m, "Seat", 0.35, 1.4, cf * CFrame.new(0, 2.7, 0) * up, seatColor, M.Leather)
end

local function buildSmoothieBar()
	local spec = Town.SmoothieBar
	local w, d, h = spec.Size.X, spec.Size.Z, 11
	local cf = look(Vector3.new(spec.Center.X, 0, spec.Center.Z - d / 2), Vector3.new(spec.Center.X, 0, -100))
	local m = model(folder, "SmoothieBar", cf)
	local wall, mint, cream = hex("#E59A7A"), hex("#7CC6A5"), hex("#F7F2E8")
	shopShell(m, cf, w, d, h, wall, M.Plaster, hex("#E9E2D3"), M.Marble)
	-- exterior: striped awning, lit sign with a smoothie cup, a chalk menu board, patio tables with umbrellas
	TownKit.awning(m, cf * CFrame.new(0, 9.2, -0.1), w - 1, 3, { mint, cream })
	local signCF = cf * CFrame.new(-1.5, h - 0.2, -0.25)
	p(m, "SignBoard", Vector3.new(11, 1.8, 0.3), signCF * CFrame.new(0, 0, 0.1), hex("#2B2B2B"), M.SmoothPlastic)
	local _, label = Kit.sign(m, "Sign", Vector3.new(10, 1.5, 0.1), signCF * CFrame.new(0.6, 0, -0.08), "Smoothie bar", cream, hex("#2B2B2B"), 50)
	label.FontFace = Theme.Fonts.SemiBold
	local cup = signCF * CFrame.new(-5.2, 0, -0.3)
	cyl(m, "SignCup", 1.2, 0.8, cup * up, mint, M.Neon)
	cyl(m, "SignLid", 0.15, 0.9, cup * CFrame.new(0, 0.65, 0) * up, cream, M.Neon)
	p(m, "SignStraw", Vector3.new(0.1, 0.9, 0.1), cup * CFrame.new(0.15, 1.05, 0) * CFrame.Angles(0, 0, rad(-15)), hex("#E86A6A"), M.Neon)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Color, glow.Brightness, glow.Range, glow.Shadows = hex("#DFF5EA"), 0.8, 8, false
	glow.Parent = m:FindFirstChild("SignBoard")
	-- A-frame menu board on the sidewalk
	local board = cf * CFrame.new(5, 0, -3)
	p(m, "AFrameLegA", Vector3.new(2, 3.4, 0.15), board * CFrame.new(0, 1.65, -0.4) * CFrame.Angles(rad(12), 0, 0), C.WoodDark, M.Wood)
	p(m, "AFrameLegB", Vector3.new(2, 3.4, 0.15), board * CFrame.new(0, 1.65, 0.4) * CFrame.Angles(rad(-12), 0, 0), C.WoodDark, M.Wood)
	local _, menuLabel = Kit.sign(m, "AFrameMenu", Vector3.new(1.7, 2.6, 0.05), board * CFrame.new(0, 1.8, -0.5) * CFrame.Angles(rad(12), 0, 0), "Shakes\n" .. Stamina.Shake.Cost .. " coins", cream, hex("#222C26"), 60)
	menuLabel.FontFace = Theme.Fonts.Regular
	for i, x in ipairs({ -7, 0, 7 }) do
		local t = cf * CFrame.new(x, 0, -5.5)
		cyl(m, "TableTop", 0.2, 3, t * CFrame.new(0, 2.7, 0) * up, cream, M.SmoothPlastic, true)
		cyl(m, "TablePost", 2.6, 0.25, t * CFrame.new(0, 1.35, 0) * up, C.Iron, M.Metal, true)
		cyl(m, "TableFoot", 0.15, 1.6, t * CFrame.new(0, 0.42, 0) * up, C.Iron, M.Metal)
		TownKit.umbrella(m, t * CFrame.new(0, 0.35, 0), i % 2 == 0 and mint or hex("#F29E6B"), cream)
		for _, sx in ipairs({ -2, 2 }) do
			local chair = t * CFrame.new(sx, 0.35, 0) * CFrame.Angles(0, rad(sx > 0 and -90 or 90), 0)
			p(m, "ChairSeat", Vector3.new(1.4, 0.2, 1.4), chair * CFrame.new(0, 1.5, 0), mint, M.SmoothPlastic, true)
			p(m, "ChairBack", Vector3.new(1.4, 1.4, 0.15), chair * CFrame.new(0, 2.2, 0.65), mint, M.SmoothPlastic)
			for _, lx in ipairs({ -0.55, 0.55 }) do
				for _, lz in ipairs({ -0.55, 0.55 }) do p(m, "ChairLeg", Vector3.new(0.1, 1.5, 0.1), chair * CFrame.new(lx, 0.75, lz), C.Iron, M.Metal) end
			end
		end
	end
	-- interior: counter along the back with blenders, fruit, cups; menu board; fridge; stools; plants; pendants
	local back = cf * CFrame.new(0, 0.5, d - 5)
	p(m, "Counter", Vector3.new(14, 3.6, 2.2), back * CFrame.new(-1, 1.8, 0), hex("#3C5A48"), M.Wood, true)
	p(m, "CounterTop", Vector3.new(14.4, 0.25, 2.6), back * CFrame.new(-1, 3.72, 0), hex("#F2EEE6"), M.Marble, true)
	for i = 0, 11 do p(m, "CounterSlat", Vector3.new(0.6, 3.2, 0.08), back * CFrame.new(-7.6 + i * 1.2, 1.8, -1.12), hex("#4A6E58"), M.Wood) end
	p(m, "BackCounter", Vector3.new(w - 2, 3.4, 1.6), cf * CFrame.new(0, 2.2, d - 1.8), hex("#3C5A48"), M.Wood, true)
	p(m, "BackCounterTop", Vector3.new(w - 1.8, 0.2, 1.8), cf * CFrame.new(0, 3.95, d - 1.8), hex("#F2EEE6"), M.Marble)
	local fruitColors = { hex("#E86A6A"), hex("#F2C14E"), hex("#7CC6A5"), hex("#C77DD6"), hex("#F29E6B") }
	for i = 0, 2 do
		local bl = back * CFrame.new(-5.5 + i * 2.2, 3.85, 0.3)
		p(m, "BlenderBase", Vector3.new(0.8, 0.7, 0.8), bl * CFrame.new(0, 0.35, 0), hex("#2B2B2B"), M.Metal)
		cyl(m, "BlenderJar", 1.2, 0.7, bl * CFrame.new(0, 1.3, 0) * up, fruitColors[i + 1], M.Glass)
		cyl(m, "BlenderLid", 0.15, 0.75, bl * CFrame.new(0, 1.95, 0) * up, hex("#2B2B2B"), M.Plastic)
	end
	for i = 0, 1 do
		local basket = back * CFrame.new(2 + i * 2.6, 3.85, 0.2)
		cyl(m, "Basket", 0.6, 1.8, basket * CFrame.new(0, 0.3, 0) * up, C.Wood, M.WoodPlanks)
		for j = 0, 6 do ball(m, "Fruit", Vector3.new(0.5, 0.5, 0.5), basket * CFrame.new(math.cos(j) * 0.5, 0.7 + (j % 2) * 0.2, math.sin(j) * 0.5), fruitColors[(j + i) % 5 + 1], M.SmoothPlastic) end
	end
	for i = 0, 4 do cyl(m, "Cup", 0.5, 0.5, back * CFrame.new(-8 + 0.1 * i, 4.1 + i * 0.4, -0.4) * up, hex("#F2EEE6"), M.Plastic) end
	-- the menu: flavors and the price in coins
	local flavors = table.concat(Stamina.Shake.Flavors, " · ")
	local menu, menuText = Kit.sign(m, "ShakeMenu", Vector3.new(10, 3.6, 0.1), cf * CFrame.new(-1, 7.4, d - 1.05) * CFrame.Angles(0, 0, 0), "Energy shakes  ·  " .. Stamina.Shake.Cost .. " coins\nRefill stamina + 50% gains for 30 s\n" .. flavors, cream, hex("#222C26"), 50)
	menuText.FontFace = Theme.Fonts.Regular
	p(m, "MenuFrame", Vector3.new(10.4, 4, 0.1), cf * CFrame.new(-1, 7.4, d - 0.98), C.WoodDark, M.Wood)
	menu.Name = "ShakeMenu"
	-- glass-door fridge with bottles
	local fridge = cf * CFrame.new(w / 2 - 2.2, 0.5, d - 2)
	p(m, "Fridge", Vector3.new(3, 7.2, 2), fridge * CFrame.new(0, 3.6, 0), hex("#C9CCD2"), M.Metal, true)
	p(m, "FridgeGlass", Vector3.new(2.6, 6.2, 0.1), fridge * CFrame.new(0, 3.7, -1.02), hex("#A8C0CC"), M.Glass, false, { Transparency = 0.45 })
	for s = 0, 3 do
		p(m, "FridgeShelf", Vector3.new(2.6, 0.08, 1.6), fridge * CFrame.new(0, 1.2 + s * 1.5, -0.1), hex("#E8E6DF"), M.Metal)
		for b = 0, 4 do cyl(m, "Bottle", 0.9, 0.35, fridge * CFrame.new(-1 + b * 0.5, 1.7 + s * 1.5, -0.4) * up, fruitColors[(b + s) % 5 + 1], M.Glass) end
	end
	local fridgeLight = Instance.new("SurfaceLight")
	fridgeLight.Face = Enum.NormalId.Front
	fridgeLight.Color, fridgeLight.Brightness, fridgeLight.Range = hex("#E9F6FF"), 0.6, 5
	fridgeLight.Parent = m:FindFirstChild("FridgeGlass")
	-- the shake machine (Buy shake prompt: StaminaService puts it on the machine's biggest part)
	local sm = model(m, "ShakeMachine", cf * CFrame.new(5.5, 4.2, d - 1.8))
	local smCF = cf * CFrame.new(5.5, 4.05, d - 1.9)
	p(sm, "Body", Vector3.new(2.6, 3.2, 1.6), smCF * CFrame.new(0, 1.6, 0), hex("#F2EEE6"), M.SmoothPlastic, true)
	p(sm, "Panel", Vector3.new(2.2, 1.0, 0.05), smCF * CFrame.new(0, 2.4, -0.82), hex("#2B2B2B"), M.Glass)
	p(sm, "PanelGlow", Vector3.new(1.6, 0.1, 0.02), smCF * CFrame.new(0, 2.2, -0.86), mint, M.Neon)
	for i = -1, 1 do
		cyl(sm, "Hopper", 0.9, 0.7, smCF * CFrame.new(i * 0.8, 3.65, 0) * up, fruitColors[i + 2], M.Glass)
		p(sm, "Tap", Vector3.new(0.18, 0.35, 0.18), smCF * CFrame.new(i * 0.6, 1.0, -0.9), hex("#9EA2A8"), M.Metal)
	end
	p(sm, "DripTray", Vector3.new(2.2, 0.15, 0.6), smCF * CFrame.new(0, 0.4, -0.95), hex("#9EA2A8"), M.Metal)
	-- bar stools at the counter, plants, pendants, a rug
	for i = -2, 2 do stool(m, back * CFrame.new(-1 + i * 2.6, 0, -2.4), mint) end
	TownKit.planter(m, cf * CFrame.new(-w / 2 + 2, 0.5, 2.5), 1.8, 1.8, "bush")
	TownKit.planter(m, cf * CFrame.new(w / 2 - 2, 0.5, 2.5), 1.8, 1.8, "bush")
	p(m, "Rug", Vector3.new(8, 0.05, 5), cf * CFrame.new(-1, 0.52, 5), hex("#C9B48A"), M.Fabric)
	for i = -1, 1 do pendantLight(m, cf * CFrame.new(-1 + i * 4.5, h - 2, d - 6), mint) end
	-- a small table by the window
	local tcf = cf * CFrame.new(-6, 0.5, 4)
	cyl(m, "CafeTable", 0.18, 2.6, tcf * CFrame.new(0, 2.7, 0) * up, cream, M.Marble, true)
	cyl(m, "CafeTablePost", 2.6, 0.25, tcf * CFrame.new(0, 1.35, 0) * up, C.Iron, M.Metal)
	for _, sx in ipairs({ -1.8, 1.8 }) do stool(m, tcf * CFrame.new(sx, 0, 0), cream) end
	return m
end

-- A simple mannequin (stand, legs, torso, arms, head) dressed in a shirt and shorts color.
local function mannequin(m, cf, shirt, shorts)
	local skin = hex("#E8E2D6")
	cyl(m, "Stand", 0.15, 1.6, cf * CFrame.new(0, 0.08, 0) * up, C.Iron, M.Metal)
	cyl(m, "Rod", 1.8, 0.15, cf * CFrame.new(0, 1.0, 0) * up, C.Iron, M.Metal)
	for _, x in ipairs({ -0.35, 0.35 }) do
		p(m, "Leg", Vector3.new(0.5, 2.0, 0.5), cf * CFrame.new(x, 2.4, 0), skin, M.SmoothPlastic)
		p(m, "Shorts", Vector3.new(0.56, 0.9, 0.56), cf * CFrame.new(x, 3.25, 0), shorts, M.Fabric)
		p(m, "Arm", Vector3.new(0.4, 1.7, 0.4), cf * CFrame.new(x * 3, 4.3, 0) * CFrame.Angles(0, 0, rad(x > 0 and 8 or -8)), skin, M.SmoothPlastic)
		p(m, "Sleeve", Vector3.new(0.46, 0.6, 0.46), cf * CFrame.new(x * 3, 4.95, 0) * CFrame.Angles(0, 0, rad(x > 0 and 8 or -8)), shirt, M.Fabric)
	end
	p(m, "Torso", Vector3.new(1.5, 1.7, 0.8), cf * CFrame.new(0, 4.5, 0), shirt, M.Fabric)
	p(m, "Neck", Vector3.new(0.35, 0.3, 0.35), cf * CFrame.new(0, 5.5, 0), skin, M.SmoothPlastic)
	ball(m, "Head", Vector3.new(0.95, 1.1, 0.95), cf * CFrame.new(0, 6.1, 0), skin, M.SmoothPlastic)
end

local function clothingRack(m, cf, colors)
	for _, x in ipairs({ -2.2, 2.2 }) do
		p(m, "RackPost", Vector3.new(0.12, 5, 0.12), cf * CFrame.new(x, 2.5, 0), C.Brass, M.Metal, true)
		p(m, "RackFoot", Vector3.new(0.12, 0.1, 1.6), cf * CFrame.new(x, 0.05, 0), C.Brass, M.Metal)
	end
	cyl(m, "RackRail", 4.6, 0.1, cf * CFrame.new(0, 5, 0), C.Brass, M.Metal)
	for i = 0, 7 do
		local x = -1.9 + i * 0.55
		p(m, "Hanger", Vector3.new(0.05, 0.3, 0.6), cf * CFrame.new(x, 4.8, 0), hex("#1A1A1A"), M.Plastic)
		p(m, "Shirt", Vector3.new(0.15, 1.9, 1.3), cf * CFrame.new(x, 3.75, 0), colors[(i % #colors) + 1], M.Fabric)
	end
end

local function buildClothingStore()
	local spec = Town.ClothingStore
	local w, d, h = spec.Size.X, spec.Size.Z, 11
	local cf = look(Vector3.new(spec.Center.X, 0, spec.Center.Z - d / 2), Vector3.new(spec.Center.X, 0, -100))
	local m = model(folder, "ClothingStore", cf)
	local wall, sage = hex("#A9B89A"), hex("#3C5A48")
	shopShell(m, cf, w, d, h, wall, M.Plaster, hex("#8A6A4A"), M.WoodPlanks)
	TownKit.awning(m, cf * CFrame.new(0, 9.2, -0.1), w - 1, 3, { sage, hex("#F2EEE6") })
	local signCF = cf * CFrame.new(0, h - 0.2, -0.25)
	p(m, "SignBoard", Vector3.new(12, 1.8, 0.3), signCF * CFrame.new(0, 0, 0.1), hex("#1E1E22"), M.SmoothPlastic)
	local signBoard, label = Kit.sign(m, "Sign", Vector3.new(11.4, 1.5, 0.1), signCF * CFrame.new(0, 0, -0.08), "Gear & Fits", hex("#F2EEE6"), hex("#1E1E22"), 50)
	label.FontFace = Theme.Fonts.SemiBold
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Color, glow.Brightness, glow.Range, glow.Shadows = hex("#FFF2DD"), 0.8, 8, false
	glow.Parent = signBoard
	-- mannequins in the display windows (lit from above)
	local outfits = { { hex("#2E6E8E"), hex("#2B2B2B") }, { hex("#E86A6A"), hex("#3A3A3D") }, { hex("#F2C14E"), hex("#1E2A3A") }, { hex("#3C5A48"), hex("#C9B48A") } }
	local winX = 2 + 1 + (w - 8) / 4
	for i, x in ipairs({ -winX - 1.6, -winX + 1.6, winX - 1.6, winX + 1.6 }) do
		local platform = cf * CFrame.new(x, 0.5, 1.8)
		p(m, "DisplayPlinth", Vector3.new(2.4, 0.6, 2.4), platform * CFrame.new(0, 0.3, 0), hex("#F2EEE6"), M.SmoothPlastic, true)
		mannequin(m, platform * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.pi, 0), outfits[i][1], outfits[i][2])
	end
	for _, x in ipairs({ -winX, winX }) do
		local spot = p(m, "WindowSpot", Vector3.new(0.6, 0.2, 0.6), cf * CFrame.new(x, h - 0.4, 2), C.Warm, M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color, light.Brightness, light.Range, light.Angle, light.Shadows = C.Warm, 2, 14, 70, false
		light.Parent = spot
	end
	-- interior: clothing racks, shelves with folded shirts, a changing room with a curtain, a mirror, the checkout
	local colors = { hex("#2E6E8E"), hex("#E86A6A"), hex("#F2EEE6"), hex("#3C5A48"), hex("#F2C14E"), hex("#1E1E22") }
	clothingRack(m, cf * CFrame.new(-4, 0.5, 8.5) * CFrame.Angles(0, rad(90), 0), colors)
	clothingRack(m, cf * CFrame.new(4, 0.5, 8.5) * CFrame.Angles(0, rad(90), 0), { colors[3], colors[4], colors[5] })
	-- wall shelves with folded shirt stacks (left wall)
	for s = 0, 2 do
		local shelf = cf * CFrame.new(-w / 2 + 1.5, 2.2 + s * 2.1, 10)
		p(m, "Shelf", Vector3.new(1.6, 0.15, 8), shelf, C.Wood, M.Wood, true)
		p(m, "Bracket", Vector3.new(0.1, 0.6, 0.1), shelf * CFrame.new(-0.6, -0.35, -3), C.Iron, M.Metal)
		p(m, "Bracket", Vector3.new(0.1, 0.6, 0.1), shelf * CFrame.new(-0.6, -0.35, 3), C.Iron, M.Metal)
		for i = 0, 4 do
			for k = 0, 2 do
				p(m, "Folded", Vector3.new(1.1, 0.22, 1.2), shelf * CFrame.new(0, 0.2 + k * 0.23, -3 + i * 1.5), colors[(i + s + k) % #colors + 1], M.Fabric)
			end
		end
	end
	-- right wall: shoes and bags on a slatted display
	local slat = cf * CFrame.new(w / 2 - 1.1, 0.5, 10)
	p(m, "SlatWall", Vector3.new(0.2, 7, 8), slat * CFrame.new(0, 4, 0), hex("#2B2B2B"), M.Wood)
	for s = 0, 2 do
		p(m, "SlatShelf", Vector3.new(1.2, 0.1, 7), slat * CFrame.new(-0.6, 2.4 + s * 2, 0), hex("#F2EEE6"), M.SmoothPlastic)
		for i = 0, 3 do
			local item = slat * CFrame.new(-0.6, 2.75 + s * 2, -2.6 + i * 1.7)
			if s == 0 then
				p(m, "Shoe", Vector3.new(0.5, 0.45, 1.1), item * CFrame.new(0, 0, 0.3), colors[(i % #colors) + 1], M.Fabric)
				p(m, "Shoe", Vector3.new(0.5, 0.45, 1.1), item * CFrame.new(0, 0, -0.3), colors[(i % #colors) + 1], M.Fabric)
				p(m, "Sole", Vector3.new(0.55, 0.12, 1.15), item * CFrame.new(0, -0.25, 0), hex("#F2EEE6"), M.Rubber)
			else
				cyl(m, "Bag", 1.2, 0.6, item * CFrame.Angles(0, rad(90), 0), colors[((i + s) % #colors) + 1], M.Fabric)
			end
		end
	end
	-- changing room (back left): two walls, a curtain on a rod, a mirror and a stool inside
	local room = cf * CFrame.new(-w / 2 + 3, 0.5, d - 3)
	p(m, "ChangeWall", Vector3.new(0.3, 8, 4.5), room * CFrame.new(3, 4, 0), hex("#F2EEE6"), M.Wood, true)
	cyl(m, "CurtainRod", 4.6, 0.1, room * CFrame.new(0.6, 8, -2.2), C.Brass, M.Metal)
	for i = 0, 5 do
		p(m, "Curtain", Vector3.new(0.7, 7.4, 0.12), room * CFrame.new(-1.3 + i * 0.75, 4.2, -2.2 + (i % 2) * 0.12), sage, M.Fabric)
	end
	GymKit.mirror(m, room * CFrame.new(0, 3.8, 1.7) * CFrame.Angles(0, math.pi, 0), 2, 5)
	-- full-length mirror on the back wall
	GymKit.mirror(m, cf * CFrame.new(3, 4.4, d - 1.05) * CFrame.Angles(0, math.pi, 0), 3, 7)
	-- checkout counter with a register (ShopPrompt opens the store screen)
	local desk = cf * CFrame.new(w / 2 - 6, 0.5, d - 4.5)
	local counter = p(m, "Counter", Vector3.new(6, 3.6, 2), desk * CFrame.new(0, 1.8, 0), sage, M.Wood, true)
	p(m, "CounterTop", Vector3.new(6.4, 0.2, 2.4), desk * CFrame.new(0, 3.7, 0), hex("#F2EEE6"), M.Marble, true)
	for i = 0, 8 do p(m, "CounterSlat", Vector3.new(0.4, 3.2, 0.08), desk * CFrame.new(-2.6 + i * 0.65, 1.8, -1.02), hex("#4A6E58"), M.Wood) end
	p(m, "Register", Vector3.new(1.4, 0.7, 1), desk * CFrame.new(-1.6, 4.15, 0.2), hex("#2B2B2B"), M.Metal)
	p(m, "RegisterScreen", Vector3.new(1.0, 0.7, 0.08), desk * CFrame.new(-1.6, 4.8, 0.4) * CFrame.Angles(rad(-20), 0, 0), hex("#0E1114"), M.Glass)
	p(m, "CardReader", Vector3.new(0.4, 0.15, 0.6), desk * CFrame.new(-0.4, 3.88, -0.3), hex("#2B2B2B"), M.Plastic)
	p(m, "BagStack", Vector3.new(1.2, 0.5, 0.8), desk * CFrame.new(1.8, 4.05, 0), hex("#C9B48A"), M.Fabric)
	Kit.prompt(counter, "ShopPrompt", "Shop", "Gear & Fits", 10)
	-- rugs, a plant, pendant lights
	p(m, "Rug", Vector3.new(9, 0.05, 6), cf * CFrame.new(0, 0.52, 8.5), hex("#C9B48A"), M.Fabric)
	p(m, "RugBorder", Vector3.new(9.4, 0.04, 6.4), cf * CFrame.new(0, 0.51, 8.5), hex("#5E4632"), M.Fabric)
	TownKit.planter(m, cf * CFrame.new(-w / 2 + 2, 0.5, 2.5), 1.8, 1.8, "bush")
	for i = -1, 1 do pendantLight(m, cf * CFrame.new(i * 5, h - 2, d / 2 + 1), hex("#1E1E22")) end
	return m
end

------------------------------------------------------------------------
-- Skate park
------------------------------------------------------------------------
local CONCRETE = hex("#A8A49C")
local COPING = hex("#C9CCD2")

-- Quarter pipe facing local -Z: curved transition made of slices, a deck on top with metal coping.
-- Quarter pipe: riders come from local -Z; the curve starts flat at the pivot and rises toward +Z (radius R, up to 80
-- degrees), then a deck with metal coping. Built from slices, with side walls filling in under the curve.
local function quarterPipe(m, cf, width, radius)
	local slices = 8
	local maxAngle = rad(80)
	for i = 0, slices - 1 do
		local a0, a1 = (i / slices) * maxAngle, ((i + 1) / slices) * maxAngle
		local z0, y0 = radius * math.sin(a0), radius - radius * math.cos(a0)
		local z1, y1 = radius * math.sin(a1), radius - radius * math.cos(a1)
		local len = math.sqrt((z1 - z0) ^ 2 + (y1 - y0) ^ 2)
		local am = (a0 + a1) / 2
		p(m, "Transition", Vector3.new(width, 0.5, len + 0.15), cf * CFrame.new(0, (y0 + y1) / 2, (z0 + z1) / 2) * CFrame.Angles(-am, 0, 0) * CFrame.new(0, -0.25, 0), CONCRETE, M.Concrete, true)
		for _, side in ipairs({ -1, 1 }) do
			local h = (y0 + y1) / 2
			if h > 0.05 then p(m, "SideWall", Vector3.new(0.4, h, len), cf * CFrame.new(side * (width / 2 - 0.2), h / 2, (z0 + z1) / 2), hex("#A6A29A"), M.Concrete, true) end
		end
	end
	local topY, topZ = radius - radius * math.cos(maxAngle), radius * math.sin(maxAngle)
	-- deck on a solid block, coping on the lip, a rail at the back
	p(m, "DeckBlock", Vector3.new(width, topY, 3.6), cf * CFrame.new(0, topY / 2, topZ + 1.8), hex("#A6A29A"), M.Concrete, true)
	p(m, "Deck", Vector3.new(width, 0.4, 3.6), cf * CFrame.new(0, topY + 0.2, topZ + 1.8), CONCRETE, M.Concrete, true)
	cyl(m, "Coping", width, 0.35, cf * CFrame.new(0, topY + 0.25, topZ + 0.1), COPING, M.Metal)
	p(m, "DeckRail", Vector3.new(width, 0.12, 0.12), cf * CFrame.new(0, topY + 3, topZ + 3.5), C.Iron, M.Metal)
	for x = -width / 2 + 0.3, width / 2 - 0.3, 3 do p(m, "DeckPost", Vector3.new(0.15, 2.8, 0.15), cf * CFrame.new(x, topY + 1.6, topZ + 3.5), C.Iron, M.Metal, true) end
end

local function grindRail(m, a, b, height)
	local mid = (a + b) / 2
	cyl(m, "Rail", (b - a).Magnitude, 0.3, CFrame.lookAt(mid + Vector3.new(0, height, 0), b + Vector3.new(0, height, 0)) * CFrame.Angles(0, rad(90), 0), COPING, M.Metal, true)
	for _, point in ipairs({ a, b, mid }) do
		p(m, "RailPost", Vector3.new(0.25, height, 0.25), CFrame.new(point + Vector3.new(0, height / 2, 0)), C.Iron, M.Metal, true)
		p(m, "RailFoot", Vector3.new(0.7, 0.12, 0.7), CFrame.new(point + Vector3.new(0, 0.06, 0)), C.Iron, M.Metal)
	end
end

local function graffiti(m, cf, w, h, words, colors)
	local wallPart = p(m, "ArtWall", Vector3.new(w, h, 0.8), cf * CFrame.new(0, h / 2, 0), hex("#D8D2C6"), M.Concrete, true)
	p(m, "ArtWallCap", Vector3.new(w + 0.3, 0.3, 1), cf * CFrame.new(0, h + 0.15, 0), hex("#B4B0A8"), M.Concrete)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 1
	gui.Parent = wallPart
	-- color splashes (rounded shapes) behind bold outlined words: original, no brands
	for i = 1, 5 do
		local blob = Instance.new("Frame")
		blob.BackgroundColor3 = colors[(i % #colors) + 1]
		blob.BackgroundTransparency = 0.15
		blob.Size = UDim2.fromScale(0.22 + (i % 3) * 0.06, 0.45 + (i % 2) * 0.2)
		blob.Position = UDim2.fromScale(-0.05 + i * 0.18, 0.1 + (i % 2) * 0.15)
		blob.Rotation = (i * 23) % 40 - 20
		blob.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = blob
		blob.Parent = gui
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.7)
	label.Position = UDim2.fromScale(0.05, 0.15)
	label.BackgroundTransparency = 1
	label.Text = words
	label.TextColor3 = hex("#F7F2E8")
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	label.TextScaled = true
	label.Rotation = -6
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = hex("#1E1E22"), 4
	stroke.Parent = label
	return wallPart
end

local function buildSkatePark()
	local spec = Town.SkatePark
	local c, s = spec.Center, spec.Size
	local m = model(folder, "SkatePark", CFrame.new(c))
	local base = CFrame.new(c.X, 0, c.Z)
	p(m, "Slab", Vector3.new(s.X, 0.5, s.Z), base * CFrame.new(0, 0.05, 0), CONCRETE, M.Concrete, true)
	for x = -s.X / 2 + 6, s.X / 2 - 1, 6 do p(m, "SlabJoint", Vector3.new(0.08, 0.02, s.Z), base * CFrame.new(x, 0.31, 0), hex("#9A968E")) end
	-- quarter pipes at both ends, a half pipe in the back, a fun box with a rail in the middle, ledges, rails
	-- quarter pipes at both ends (each rises toward its fence), a half pipe at the back (two facing quarter pipes)
	quarterPipe(m, base * CFrame.new(-s.X / 2 + 9.5, 0.3, -2) * CFrame.Angles(0, rad(-90), 0), 12, 4.5)
	quarterPipe(m, base * CFrame.new(s.X / 2 - 9, 0.3, -s.Z / 4) * CFrame.Angles(0, rad(90), 0), 10, 4)
	local hp = base * CFrame.new(2, 0.3, s.Z / 2 - 9)
	quarterPipe(m, hp * CFrame.new(-4, 0, 0) * CFrame.Angles(0, rad(-90), 0), 10, 5)
	quarterPipe(m, hp * CFrame.new(4, 0, 0) * CFrame.Angles(0, rad(90), 0), 10, 5)
	-- fun box: flat top with ramps on two sides (wedges rise toward the box) and a rail across it
	local fb = base * CFrame.new(-2, 0.3, -6)
	p(m, "FunBoxTop", Vector3.new(8, 1.6, 6), fb * CFrame.new(0, 0.8, 0), CONCRETE, M.Concrete, true)
	Kit.wedge(m, "FunBoxRamp", Vector3.new(6, 1.6, 4), fb * CFrame.new(-6, 0.8, 0) * CFrame.Angles(0, rad(90), 0), CONCRETE, M.Concrete)
	Kit.wedge(m, "FunBoxRamp", Vector3.new(6, 1.6, 4), fb * CFrame.new(6, 0.8, 0) * CFrame.Angles(0, rad(-90), 0), CONCRETE, M.Concrete)
	for _, z in ipairs({ -3, 3 }) do p(m, "FunBoxEdge", Vector3.new(8, 0.15, 0.15), fb * CFrame.new(0, 1.62, z), COPING, M.Metal) end
	grindRail(m, (fb * CFrame.new(-3, 0, 0)).Position + Vector3.new(0, 1.6, 0), (fb * CFrame.new(3, 0, 0)).Position + Vector3.new(0, 1.6, 0), 1)
	grindRail(m, (base * CFrame.new(-12, 0.3, 10)).Position, (base * CFrame.new(4, 0.3, 10)).Position, 1.6)
	-- ledges: concrete blocks with steel edges
	for i, z in ipairs({ -14, 6 }) do
		local l = base * CFrame.new(10 - i * 4, 0.3, z)
		p(m, "Ledge", Vector3.new(10, 1.4, 2), l * CFrame.new(0, 0.7, 0), hex("#C9C4BA"), M.Concrete, true)
		p(m, "LedgeEdge", Vector3.new(10, 0.15, 0.2), l * CFrame.new(0, 1.42, -1), COPING, M.Metal)
	end
	-- fence with gates (posts, top rail, see-through mesh panels)
	local function fence(x0, z0, x1, z1)
		local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, rad(90), 0)
		p(m, "FenceMesh", Vector3.new(len, 4, 0.08), cf * CFrame.new(0, 2.4, 0), hex("#8A8E94"), M.DiamondPlate, true, { Transparency = 0.65 })
		p(m, "FenceRail", Vector3.new(len, 0.15, 0.15), cf * CFrame.new(0, 4.4, 0), C.Iron, M.Metal)
		for t = 0, len, 4 do p(m, "FencePost", Vector3.new(0.2, 4.6, 0.2), cf * CFrame.new(-len / 2 + t, 2.3, 0), C.Iron, M.Metal, true) end
	end
	local x0, x1, z0, z1 = c.X - s.X / 2, c.X + s.X / 2, c.Z - s.Z / 2, c.Z + s.Z / 2
	fence(x0, z0, c.X - 4, z0)        -- front, with a gate gap in the middle
	fence(c.X + 4, z0, x1, z0)
	fence(x0, z1, x1, z1)
	fence(x0, z0, x0, z1)
	fence(x1, z0, x1, c.Z - 4)        -- side gate toward the beach
	fence(x1, c.Z + 4, x1, z1)
	-- graffiti walls, benches, lights
	local artColors = { hex("#E86A6A"), hex("#F2C14E"), hex("#7CC6A5"), hex("#6FA8DC"), hex("#C77DD6") }
	graffiti(m, look(Vector3.new(c.X - 6, 0.3, z1 - 1.5), Vector3.new(c.X - 6, 0.3, z0)), 16, 6, "RIDE ON", artColors)
	graffiti(m, look(Vector3.new(x0 + 1.5, 0.3, c.Z + 8), Vector3.new(x1, 0.3, c.Z + 8)), 12, 5, "GYM ARC", { artColors[4], artColors[2], artColors[1] })
	for _, z in ipairs({ z0 + 4, z0 + 14 }) do TownKit.bench(m, look(Vector3.new(x1 - 2, 0.3, z), Vector3.new(x0, 0.3, z))) end
	for _, corner in ipairs({ { x0 + 1, z0 + 1 }, { x1 - 1, z0 + 1 }, { x0 + 1, z1 - 1 }, { x1 - 1, z1 - 1 } }) do
		cyl(m, "FloodPole", 12, 0.4, CFrame.new(corner[1], 6.3, corner[2]) * up, C.Iron, M.Metal, true)
		local head = p(m, "Floodlight", Vector3.new(1.6, 0.6, 1), CFrame.lookAt(Vector3.new(corner[1], 12.4, corner[2]), c + Vector3.new(0, 0, 0)), hex("#2B2B2B"), M.Metal)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Color, light.Brightness, light.Range, light.Angle, light.Shadows = hex("#FFF2DD"), 1.6, 40, 70, false
		light.Parent = head
	end
	return m
end

------------------------------------------------------------------------
-- Beach, beach gym, posing stage
------------------------------------------------------------------------
local function buildBeach()
	local beach = Instance.new("Folder")
	beach.Name = "Beach"
	beach.Parent = folder
	local b = Town.Beach
	local shore = Town.Sea.MinZ
	-- palms (different heights), umbrellas with towels and chairs, a lifeguard tower, a volleyball net, surfboards, rocks
	local palms = { { 6, 70, 1 }, { 40, 72, 1.15 }, { 74, 76, 0.95 }, { 118, 72, 1.2 }, { 138, 96, 1.05 }, { 16, 116, 1.1 }, { 108, 118, 0.9 }, { 78, 96, 1.05 } }
	for i, palm in ipairs(palms) do TownKit.palm(beach, Vector3.new(palm[1], 0, palm[2]), palm[3], i) end
	local umbrellaColors = { { hex("#E86A6A"), hex("#F7F2E8") }, { hex("#6FA8DC"), hex("#F7F2E8") }, { hex("#F2C14E"), hex("#F7F2E8") }, { hex("#7CC6A5"), hex("#F7F2E8") } }
	for i, spot in ipairs({ { 32, 112 }, { 44, 114 }, { 82, 112 }, { 96, 114 } }) do
		local cf = CFrame.new(spot[1], 0, spot[2])
		TownKit.umbrella(beach, cf, umbrellaColors[i][1], umbrellaColors[i][2])
		TownKit.towel(beach, cf * CFrame.new(-2.2, 0, 1) * CFrame.Angles(0, rad(10 * i), 0), umbrellaColors[i][1], hex("#F7F2E8"))
		TownKit.beachChair(beach, cf * CFrame.new(2.4, 0, 0.5) * CFrame.Angles(0, rad(180 + 8 * i), 0), umbrellaColors[(i % 4) + 1][1])
	end
	-- lifeguard tower: four stilts, platform with a rail, a small cabin with a roof, a ladder, a flag
	local lg = CFrame.new(124, 0, 108) * CFrame.Angles(0, rad(200), 0)
	for _, o in ipairs({ { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } }) do
		p(beach, "Stilt", Vector3.new(0.4, 6, 0.4), lg * CFrame.new(o[1], 3, o[2]) * CFrame.Angles(rad(o[2] * 2), 0, rad(-o[1] * 2)), C.White, M.Wood, true)
	end
	p(beach, "TowerDeck", Vector3.new(5, 0.4, 5), lg * CFrame.new(0, 6.2, 0), C.WoodDark, M.WoodPlanks, true)
	p(beach, "Cabin", Vector3.new(3.6, 3.2, 3), lg * CFrame.new(0, 8, 0.6), hex("#E86A6A"), M.Wood, true)
	p(beach, "CabinWindow", Vector3.new(2.8, 1.2, 0.1), lg * CFrame.new(0, 8.6, -0.92), hex("#A8C0CC"), M.Glass)
	Kit.wedge(beach, "CabinRoof", Vector3.new(4.2, 1.2, 2), lg * CFrame.new(0, 10.2, -0.3) * CFrame.Angles(0, math.pi, 0), C.White, M.Wood)
	Kit.wedge(beach, "CabinRoof", Vector3.new(4.2, 1.2, 2), lg * CFrame.new(0, 10.2, 1.7), C.White, M.Wood)
	for x = -2.3, 2.3, 0.8 do p(beach, "DeckRail", Vector3.new(0.1, 1.2, 0.1), lg * CFrame.new(x, 7, -2.4), C.White, M.Wood) end
	p(beach, "DeckRailTop", Vector3.new(5, 0.12, 0.12), lg * CFrame.new(0, 7.6, -2.4), C.White, M.Wood)
	for i = 0, 6 do p(beach, "LadderRung", Vector3.new(1.2, 0.12, 0.12), lg * CFrame.new(0, 0.6 + i * 0.85, -3.4 + i * 0.3), C.White, M.Wood) end
	cyl(beach, "FlagPole", 5, 0.12, lg * CFrame.new(2.2, 9.5, 2.2) * up, C.White, M.Metal)
	p(beach, "Flag", Vector3.new(1.8, 1.1, 0.05), lg * CFrame.new(3.1, 11.4, 2.2), hex("#E86A6A"), M.Fabric)
	-- volleyball: posts, a see-through net with a top band, a ball and court lines
	local vb = CFrame.new(98, 0, 86)
	for _, x in ipairs({ -8, 8 }) do
		cyl(beach, "NetPost", 7, 0.3, vb * CFrame.new(x, 3.5, 0) * up, C.White, M.Metal, true)
	end
	p(beach, "Net", Vector3.new(16, 2.6, 0.06), vb * CFrame.new(0, 4.6, 0), C.White, M.Fabric, false, { Transparency = 0.6 })
	p(beach, "NetBand", Vector3.new(16, 0.25, 0.08), vb * CFrame.new(0, 5.95, 0), C.White, M.Fabric)
	ball(beach, "Volleyball", Vector3.new(0.9, 0.9, 0.9), vb * CFrame.new(3, 0.45, -4), hex("#F2C14E"), M.SmoothPlastic)
	for _, z in ipairs({ -8, 8 }) do p(beach, "CourtLine", Vector3.new(16, 0.03, 0.15), vb * CFrame.new(0, 0.05, z), C.White, M.SmoothPlastic) end
	for _, x in ipairs({ -8, 8 }) do p(beach, "CourtLine", Vector3.new(0.15, 0.03, 16), vb * CFrame.new(x, 0.05, 0), C.White, M.SmoothPlastic) end
	-- surfboards in a rack and stuck in the sand
	local rack = CFrame.new(112, 0, 78) * CFrame.Angles(0, rad(-20), 0)
	for _, x in ipairs({ -2, 2 }) do p(beach, "RackPost", Vector3.new(0.3, 3.2, 0.3), rack * CFrame.new(x, 1.6, 0), C.WoodDark, M.Wood, true) end
	p(beach, "RackBar", Vector3.new(4.6, 0.25, 0.25), rack * CFrame.new(0, 3.1, 0), C.WoodDark, M.Wood)
	local boardColors = { hex("#6FA8DC"), hex("#F2C14E"), hex("#E86A6A") }
	for i = 0, 2 do TownKit.surfboard(beach, rack * CFrame.new(-1.4 + i * 1.4, 0, 0.5) * CFrame.Angles(rad(-12), 0, 0), boardColors[i + 1]) end
	TownKit.surfboard(beach, CFrame.new(34, -0.8, 100) * CFrame.Angles(rad(6), rad(30), rad(-8)), hex("#7CC6A5"))
	-- rocks and shoreline detail (driftwood, shells, a sand castle)
	for i, r in ipairs({ { 140, 120, 1.4 }, { 146, 116, 1 }, { 4, 120, 1.2 }, { 8, 123, 0.8 }, { 64, 121, 0.9 } }) do
		TownKit.rock(beach, Vector3.new(r[1], -0.4, r[2]), r[3], i)
	end
	cyl(beach, "Driftwood", 4.5, 0.5, CFrame.new(50, 0.1, 118) * CFrame.Angles(0, rad(25), 0), hex("#B9A587"), M.Wood)
	for i = 0, 9 do ball(beach, "Shell", Vector3.new(0.35, 0.2, 0.35), CFrame.new(20 + i * 11, 0.05, 117 + (i % 3)), hex("#F2E4D6"), M.SmoothPlastic) end
	local castle = CFrame.new(88, 0, 112)
	p(beach, "SandCastle", Vector3.new(2.4, 1.2, 2.4), castle * CFrame.new(0, 0.6, 0), C.Sand, M.Sand)
	for _, o in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		cyl(beach, "Turret", 1.8, 0.7, castle * CFrame.new(o[1], 0.9, o[2]) * up, C.Sand, M.Sand)
	end
end

local function buildBeachGym()
	local center = Town.BeachGym.Center
	local m = model(folder, "BeachGym", CFrame.new(center))
	local base = CFrame.new(center.X, 0, center.Z)
	local bamboo, bambooDark = hex("#C9B27A"), hex("#9C8656")
	-- rubber mats on the sand
	p(m, "Mat", Vector3.new(26, 0.25, 14), base * CFrame.new(0, 0.1, 0), hex("#2A2A2E"), M.Rubber, true)
	for x = -12, 12, 4 do p(m, "MatJoint", Vector3.new(0.06, 0.02, 14), base * CFrame.new(x, 0.24, 0), hex("#1A1A1C")) end
	-- shade structure: bamboo posts with lashings, beams, a slatted roof
	for _, dx in ipairs({ -12.5, -4.2, 4.2, 12.5 }) do
		for _, dz in ipairs({ -6.5, 6.5 }) do
			cyl(m, "Post", 10, 0.6, base * CFrame.new(dx, 5, dz) * up, bamboo, M.Wood, true)
			for _, y in ipairs({ 2.5, 5, 7.5 }) do cyl(m, "Node", 0.2, 0.7, base * CFrame.new(dx, y, dz) * up, bambooDark, M.Wood) end
			cyl(m, "Lashing", 0.5, 0.72, base * CFrame.new(dx, 9.4, dz) * up, hex("#7A6440"), M.Fabric)
		end
	end
	for _, dz in ipairs({ -6.5, 6.5 }) do cyl(m, "Beam", 26.5, 0.5, base * CFrame.new(0, 9.8, dz), bamboo, M.Wood) end
	for x = -13, 13, 1.2 do
		cyl(m, "RoofSlat", 15, 0.32, base * CFrame.new(x, 10.2, 0) * CFrame.Angles(0, rad(90), 0) * CFrame.Angles(0, 0, rad(4)), x % 2.4 < 1.2 and bamboo or bambooDark, M.Wood)
	end
	local sign, label = Kit.sign(m, "Sign", Vector3.new(12, 1.4, 0.3), look(Vector3.new(center.X, 8.6, center.Z - 6.7), Vector3.new(center.X, 8.6, center.Z - 40)),
		"Beach gym · opens at Growth Spurt " .. Machines.GymUnlock.Beach, C.White, hex("#5E4632"), 40)
	label.FontFace = Theme.Fonts.SemiBold
	-- the three beach machines (cable stacks, like the pro gym's) facing the sea, plus a pull-up bar anyone can use
	local beachMachines = {}
	for _, machine in ipairs(Machines.List) do
		if machine.gym == "Beach" then table.insert(beachMachines, machine) end
	end
	local builders = {
		BeachCurl = function(parent, pivot) return GymKit.Pro.BicepCurl(parent, pivot) end,
		BeachRaise = function(parent, pivot) return GymKit.Pro.LateralRaise(parent, pivot) end,
		BeachShrug = function(parent, pivot) return GymKit.Pro.Shrugs(parent, pivot) end,
	}
	for index, machine in ipairs(beachMachines) do
		local x = center.X - 9 + (index - 1) * 6.5
		local built = builders[machine.id] and builders[machine.id](m, CFrame.new(x, 0.25, center.Z - 2))
		if built then
			-- the pro builder named it after the pro machine: make it the beach one
			built.Name = machine.id
			built:SetAttribute("MachineId", machine.id)
			local prompt = built:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then prompt.ObjectText = machine.name end
		end
	end
	GymKit.PullUpBar(m, CFrame.new(center.X + 9.5, 0.25, center.Z - 1))
	-- battle rope on an anchor, kettlebells, a flag
	local anchor = base * CFrame.new(-10, 0.25, 5)
	cyl(m, "RopeAnchor", 1.4, 0.8, anchor * CFrame.new(0, 0.7, 0) * up, C.Iron, M.Metal, true)
	for i = 0, 6 do
		cyl(m, "Rope", 1.4, 0.35, anchor * CFrame.new(1 + i * 1.2, 0.35, math.sin(i * 1.3) * 0.6) * CFrame.Angles(0, rad(math.cos(i) * 25), 0), hex("#C9B48A"), M.Fabric)
	end
	for i = 0, 3 do GymKit.kettlebell(m, base * CFrame.new(10 + i * 1.2, 0.25, 5.4), 0.7 + i * 0.1) end
	cyl(m, "FlagPole", 14, 0.25, base * CFrame.new(-14.5, 7, -7) * up, C.White, M.Metal, true)
	local flag = p(m, "Flag", Vector3.new(3.6, 2.2, 0.05), base * CFrame.new(-12.6, 12.6, -7), hex("#1F5FBF"), M.Fabric)
	local fgui = Instance.new("SurfaceGui")
	fgui.Face = Enum.NormalId.Front
	fgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	fgui.PixelsPerStud = 40
	fgui.Parent = flag
	local ft = Instance.new("TextLabel")
	ft.Size = UDim2.fromScale(1, 1)
	ft.BackgroundTransparency = 1
	ft.Text = "GYM ARC"
	ft.TextColor3 = C.White
	ft.FontFace = Theme.Fonts.SemiBold
	ft.TextScaled = true
	ft.Parent = fgui
	return m
end

local function buildStage()
	local spec = Town.Stage
	local c, s = spec.Center, spec.Size
	local m = model(folder, "PosingStage", CFrame.new(c))
	local base = CFrame.new(c.X, 0, c.Z)
	local top = s.Y + 0.2
	local stage = p(m, "Stage", Vector3.new(s.X, s.Y, s.Z), base * CFrame.new(0, 0.2 + s.Y / 2, 0), hex("#5E4632"), M.WoodPlanks, true)
	p(m, "StageSkirt", Vector3.new(s.X + 0.1, s.Y - 0.2, s.Z + 0.1), base * CFrame.new(0, 0.2 + s.Y / 2 - 0.1, 0), hex("#1E1E22"), M.Fabric)
	p(m, "StageEdge", Vector3.new(s.X + 0.3, 0.2, 0.4), base * CFrame.new(0, top + 0.1, -s.Z / 2), hex("#C9CCD2"), M.Metal)
	for x = -s.X / 2 + 1, s.X / 2 - 1, 2 do
		local light = p(m, "FootLight", Vector3.new(0.5, 0.2, 0.3), base * CFrame.new(x, top + 0.25, -s.Z / 2 + 0.35), C.Warm, M.Neon)
		light.CanCollide = false
	end
	-- steps with handrails
	for i = 1, 3 do
		local h = s.Y * i / 4
		p(m, "Step", Vector3.new(6, h, 1.3), base * CFrame.new(0, 0.2 + h / 2, -s.Z / 2 - (4 - i) * 1.3 + 0.65), hex("#5E4632"), M.WoodPlanks, true)
	end
	for _, x in ipairs({ -3.2, 3.2 }) do
		p(m, "Handrail", Vector3.new(0.15, 0.15, 4.4), base * CFrame.new(x, s.Y + 1.2, -s.Z / 2 - 2) * CFrame.Angles(rad(-25), 0, 0), C.Iron, M.Metal)
		p(m, "HandrailPost", Vector3.new(0.15, 2.6, 0.15), base * CFrame.new(x, 1.5, -s.Z / 2 - 3.8), C.Iron, M.Metal)
	end
	-- backdrop with GYM ARC art: a big framed panel with the title and three plate discs
	local back = base * CFrame.new(0, top, s.Z / 2 - 0.4)
	local panel = p(m, "Backdrop", Vector3.new(s.X - 1, 9, 0.4), back * CFrame.new(0, 4.5, 0), hex("#141416"), M.SmoothPlastic, true)
	p(m, "BackdropFrame", Vector3.new(s.X - 0.6, 9.4, 0.3), back * CFrame.new(0, 4.5, 0.2), hex("#C9CCD2"), M.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	gui.Parent = panel
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.9, 0.35)
	title.Position = UDim2.fromScale(0.05, 0.12)
	title.BackgroundTransparency = 1
	title.Text = "GYM ARC"
	title.TextColor3 = C.White
	title.FontFace = Theme.Fonts.SemiBold
	title.TextScaled = true
	title.Parent = gui
	local sub = title:Clone()
	sub.Text = "Posing stage"
	sub.TextColor3 = hex("#B8B8BE")
	sub.FontFace = Theme.Fonts.Regular
	sub.Size = UDim2.fromScale(0.9, 0.14)
	sub.Position = UDim2.fromScale(0.05, 0.48)
	sub.Parent = gui
	for i, key in ipairs({ "Red", "Blue", "Yellow" }) do
		local disc = Instance.new("Frame")
		disc.Size = UDim2.fromScale(0.14, 0.24)
		disc.Position = UDim2.fromScale(0.15 + (i - 1) * 0.27, 0.68)
		disc.BackgroundColor3 = Theme.Bumper[key].Fill
		disc.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = disc
		local ring = Instance.new("UIStroke")
		ring.Color, ring.Thickness = Theme.Bumper[key].Rim, 6
		ring.Parent = disc
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = disc
		disc.Parent = gui
	end
	-- trusses on both sides and across the top, with spotlights pointing at the stage
	local function truss(a, b)
		local mid, len = (a + b) / 2, (b - a).Magnitude
		local cf = CFrame.lookAt(mid, b)
		for _, o in ipairs({ { -0.4, -0.4 }, { 0.4, -0.4 }, { -0.4, 0.4 }, { 0.4, 0.4 } }) do
			p(m, "TrussChord", Vector3.new(0.12, 0.12, len), cf * CFrame.new(o[1], o[2], 0), hex("#C9CCD2"), M.Metal)
		end
		for t = 0, len - 1, 1.2 do
			p(m, "TrussBrace", Vector3.new(0.08, 1.1, 0.08), cf * CFrame.new(-0.4, 0, -len / 2 + t + 0.6) * CFrame.Angles(rad(45), 0, 0), hex("#C9CCD2"), M.Metal)
			p(m, "TrussBrace", Vector3.new(0.08, 1.1, 0.08), cf * CFrame.new(0.4, 0, -len / 2 + t + 0.6) * CFrame.Angles(rad(-45), 0, 0), hex("#C9CCD2"), M.Metal)
		end
	end
	local hx, frontZ = s.X / 2 + 1, -s.Z / 2 - 1
	local tl, tr = (base * CFrame.new(-hx, 0, frontZ)).Position, (base * CFrame.new(hx, 0, frontZ)).Position
	truss(tl, tl + Vector3.new(0, 14, 0))
	truss(tr, tr + Vector3.new(0, 14, 0))
	truss(tl + Vector3.new(0, 14, 0), tr + Vector3.new(0, 14, 0))
	for i = 0, 3 do
		local x = -s.X / 2 + 2 + i * (s.X - 4) / 3
		local pos = (base * CFrame.new(x, 13.3, frontZ)).Position
		local can = p(m, "StageSpot", Vector3.new(0.9, 0.9, 1.4), CFrame.lookAt(pos, (base * CFrame.new(x * 0.5, top + 3, 0)).Position), hex("#1E1E22"), M.Metal)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Color, spot.Brightness, spot.Range, spot.Angle, spot.Shadows = hex("#FFF2DD"), 2.5, 22, 45, i == 1
		spot.Parent = can
	end
	-- the crowd area: three rows of benches facing the stage
	for row = 0, 2 do
		for _, x in ipairs({ -4.5, 4.5 }) do
			TownKit.bench(m, look((base * CFrame.new(x, 0, -s.Z / 2 - 9 - row * 3.5)).Position, (base * CFrame.new(x, 0, 0)).Position))
		end
	end
	-- "Pose" opens the Emotes panel (EmoteClient); posing itself is just the normal emotes, seen by everyone
	Kit.prompt(stage, "PosePrompt", "Pose", "Posing stage", 10)
	return m
end

------------------------------------------------------------------------
-- Background buildings, greenery, boundary
------------------------------------------------------------------------
local function buildBackground()
	local bg = Instance.new("Folder")
	bg.Name = "Buildings"
	bg.Parent = folder
	local shops = {
		{ name = "Sunny Side Bakery", stripes = { hex("#F2C14E"), hex("#F7F2E8") } },
		{ name = "Wave Books", stripes = { hex("#6FA8DC"), hex("#F7F2E8") } },
		{ name = "Pepper & Pine", stripes = { hex("#3C5A48"), hex("#F7F2E8") } },
		{ name = "Shell Street Cafe", stripes = { hex("#E86A6A"), hex("#F7F2E8") } },
		{ name = "Tide Bikes", stripes = { hex("#2E6E8E"), hex("#F7F2E8") } },
		{ name = "Coral Market", stripes = { hex("#F29E6B"), hex("#F7F2E8") } },
		{ name = "Lighthouse Toys", stripes = { hex("#C77DD6"), hex("#F7F2E8") } },
		{ name = "Breeze Pharmacy", stripes = { hex("#7CC6A5"), hex("#F7F2E8") } },
	}
	local i = 0
	local function row(list, z, facing)
		for _, spec in ipairs(list) do
			i += 1
			local pos = Vector3.new(spec.x, 0, z)
			local cf = look(pos, pos + facing)
			TownKit.building(bg, "Building", cf, {
				w = spec.w, d = 16, floors = spec.floors, palette = TownKit.Palette[(i % #TownKit.Palette) + 1],
				shop = spec.shop and shops[(i % #shops) + 1] or nil, balconies = i % 2 == 0,
				roof = ({ "ac", "tank", "rail" })[(i % 3) + 1], seed = i,
			})
		end
	end
	local south = Town.Street.MinZ - 4 -- the building fronts sit at the back of the south sidewalk
	local north = Town.Street.MaxZ + 4
	row({ { x = -50, w = 14, floors = 3, shop = true }, { x = -66, w = 16, floors = 4, shop = true }, { x = -84, w = 18, floors = 2, shop = true },
		{ x = -103, w = 16, floors = 5 }, { x = -122, w = 16, floors = 3, shop = true } }, south - 0.5, Vector3.new(0, 0, 1))
	row({ { x = 104, w = 16, floors = 3, shop = true }, { x = 122, w = 18, floors = 4, shop = true }, { x = 141, w = 16, floors = 2, shop = true },
		{ x = 159, w = 16, floors = 5 } }, south - 0.5, Vector3.new(0, 0, 1))
	row({ { x = -56, w = 14, floors = 2, shop = true }, { x = -73, w = 16, floors = 3, shop = true }, { x = -92, w = 18, floors = 4 },
		{ x = -111, w = 16, floors = 3, shop = true }, { x = -129, w = 16, floors = 2 } }, north + 0.5, Vector3.new(0, 0, -1))
	row({ { x = 56, w = 14, floors = 3, shop = true }, { x = 73, w = 16, floors = 2, shop = true }, { x = 92, w = 18, floors = 4, shop = true },
		{ x = 111, w = 16, floors = 3 }, { x = 129, w = 16, floors = 5, shop = true }, { x = 148, w = 18, floors = 3 }, { x = 166, w = 14, floors = 2 } },
		north + 0.5, Vector3.new(0, 0, -1))
	-- a distant skyline on the hills (simpler buildings, partly hidden by trees)
	local rng = Random.new(3)
	for k = 1, 22 do
		local a = rng:NextNumber(-1.2, 1.2)
		local d = rng:NextNumber(330, 430)
		local pos = Vector3.new(math.sin(a) * d + 20, 26 + d * 0.06, -math.cos(a) * d - 40)
		TownKit.building(bg, "Distant", look(pos, Vector3.new(20, pos.Y, 30)), {
			w = rng:NextNumber(14, 26), d = 14, floors = rng:NextInteger(2, 5), palette = TownKit.Palette[(k % #TownKit.Palette) + 1], far = true, seed = k,
		})
	end
end

local function buildGreenery()
	local green = Instance.new("Folder")
	green.Name = "Greenery"
	green.Parent = folder
	local rng = Random.new(11)
	-- ground height from the terrain only (never a roof)
	local groundOnly = RaycastParams.new()
	groundOnly.FilterType = Enum.RaycastFilterType.Include
	groundOnly.FilterDescendantsInstances = { Workspace.Terrain }
	local function ground(x, z)
		local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), groundOnly)
		return hit and hit.Position.Y or 0
	end
	-- tree clusters on the hills around the town (varied kinds and sizes)
	local b = Town.Bounds
	for _ = 1, 70 do
		local side = rng:NextInteger(1, 3)
		local x, z
		if side == 1 then
			x, z = rng:NextNumber(b.MinX - 120, b.MaxX + 120), rng:NextNumber(b.MinZ - 120, b.MinZ - 6)
		elseif side == 2 then
			x, z = rng:NextNumber(b.MinX - 120, b.MinX - 6), rng:NextNumber(b.MinZ - 60, Town.Sea.MinZ - 30)
		else
			x, z = rng:NextNumber(b.MaxX + 6, b.MaxX + 120), rng:NextNumber(b.MinZ - 60, Town.Sea.MinZ - 30)
		end
		local y = ground(x, z)
		local kind = rng:NextNumber()
		local scale = rng:NextNumber(0.9, 1.6)
		if kind < 0.45 then
			TownKit.oak(green, Vector3.new(x, y - 0.3, z), scale)
		elseif kind < 0.8 then
			TownKit.roundTree(green, Vector3.new(x, y - 0.3, z), scale)
		else
			TownKit.cypress(green, Vector3.new(x, y - 0.3, z), scale)
		end
	end
	-- inside the town: trees, bushes, flowers and rocks on the lawns
	for _, lawn in ipairs(Town.Lawns) do
		for _ = 1, lawn.trees do
			local pos = Vector3.new(rng:NextNumber(lawn.MinX + 3, lawn.MaxX - 3), 0, rng:NextNumber(lawn.MinZ + 3, lawn.MaxZ - 3))
			local y = ground(pos.X, pos.Z)
			if rng:NextNumber() < 0.5 then TownKit.oak(green, Vector3.new(pos.X, y - 0.2, pos.Z), rng:NextNumber(0.8, 1.2)) else TownKit.roundTree(green, Vector3.new(pos.X, y - 0.2, pos.Z), rng:NextNumber(0.9, 1.3)) end
			TownKit.bush(green, Vector3.new(pos.X + rng:NextNumber(2, 4), y - 0.2, pos.Z + rng:NextNumber(-3, 3)), rng:NextNumber(0.8, 1.2))
		end
		for _ = 1, lawn.flowers do
			local pos = Vector3.new(rng:NextNumber(lawn.MinX + 2, lawn.MaxX - 2), 0, rng:NextNumber(lawn.MinZ + 2, lawn.MaxZ - 2))
			TownKit.flowers(green, Vector3.new(pos.X, ground(pos.X, pos.Z) - 0.05, pos.Z), 1.6, 9)
		end
		for _ = 1, lawn.rocks or 1 do
			local pos = Vector3.new(rng:NextNumber(lawn.MinX + 2, lawn.MaxX - 2), -0.3, rng:NextNumber(lawn.MinZ + 2, lawn.MaxZ - 2))
			TownKit.rock(green, pos, rng:NextNumber(0.6, 1.1))
		end
	end
	-- street props
	TownKit.crates(green, CFrame.new(-45, 0.35, Town.Street.MaxZ + 3.2))
	TownKit.hydrant(green, CFrame.new(-40, 0.35, Town.Street.MinZ - 1.2))
	TownKit.hydrant(green, CFrame.new(120, 0.35, Town.Street.MaxZ + 1.2))
	TownKit.bikeRack(green, CFrame.new(28, 0.35, Town.Street.MaxZ + 3), 4)
	for _, x in ipairs({ -95, -30, 30, 100, 140 }) do TownKit.bin(green, CFrame.new(x, 0.35, Town.Street.MaxZ + 3.2)) end
	for _, x in ipairs({ -60, 96, 150 }) do TownKit.bench(green, look(Vector3.new(x, 0.35, Town.Street.MaxZ + 3), Vector3.new(x, 0, 0))) end
end

local function buildBoundary()
	local b = Town.Bounds
	local function wall(size, cframe)
		local w = p(folder, "Boundary", size, cframe, C.White, M.SmoothPlastic, true, { Transparency = 1 })
		w.CanQuery, w.CastShadow = false, false
	end
	local width, depth = b.MaxX - b.MinX, b.MaxZ - b.MinZ
	wall(Vector3.new(1, 60, depth + 60), CFrame.new(b.MinX, 30, (b.MinZ + b.MaxZ) / 2 + 20))
	wall(Vector3.new(1, 60, depth + 60), CFrame.new(b.MaxX, 30, (b.MinZ + b.MaxZ) / 2 + 20))
	wall(Vector3.new(width, 60, 1), CFrame.new((b.MinX + b.MaxX) / 2, 30, b.MinZ))
	wall(Vector3.new(width + 60, 60, 1), CFrame.new((b.MinX + b.MaxX) / 2, 30, Town.Sea.MinZ + 22)) -- out in the water
end

function Builder.Build()
	-- keep nothing from the old town except what other builders made: the shake machine is rebuilt in the smoothie bar
	folder = Kit.fresh(Workspace, "Folder", "Town")
	buildTerrain()
	buildStreets()
	buildGymFront()
	buildGymRoofs()
	buildPlaza()
	buildSmoothieBar()
	buildClothingStore()
	buildSkatePark()
	buildBeach()
	buildBeachGym()
	buildStage()
	buildBackground()
	buildGreenery()
	buildBoundary()
	-- the entrance hall's glass doors slide open (TownClient); they never block
	local entrance = Workspace:FindFirstChild("Gym") and Workspace.Gym:FindFirstChild("Entrance")
	-- the hall's front wall was one solid part in front of the doors: cut the doorway (7.2 x 8.4) into it
	local wallBack = entrance and entrance:FindFirstChild("WallBack")
	if wallBack and wallBack:IsA("BasePart") and wallBack.Size.X > 20 then
		local cf, size = wallBack.CFrame, wallBack.Size
		local doorW, doorH = 7.2, 8.4
		local side = (size.X - doorW) / 2
		for _, s in ipairs({ -1, 1 }) do
			local piece = wallBack:Clone()
			piece.Name = "WallFront"
			piece.Size = Vector3.new(side, size.Y, size.Z)
			piece.CFrame = cf * CFrame.new(s * (doorW / 2 + side / 2), 0, 0)
			piece.Parent = entrance
		end
		local header = wallBack:Clone()
		header.Name = "WallFront"
		header.Size = Vector3.new(doorW, size.Y - doorH, size.Z)
		header.CFrame = cf * CFrame.new(0, doorH / 2, 0)
		header.Parent = entrance
		wallBack:Destroy()
	end
	-- the door "frame" was one solid slab across the opening: make it a real frame (two jambs and a header)
	local slab = entrance and entrance:FindFirstChild("DoorFrame")
	if slab and slab:IsA("BasePart") and slab.Size.X > 5 then
		local cf, size = slab.CFrame, slab.Size
		for _, s in ipairs({ -1, 1 }) do
			local jamb = slab:Clone()
			jamb.Name = "DoorJamb"
			jamb.Size = Vector3.new(0.35, size.Y, 0.5)
			jamb.CFrame = cf * CFrame.new(s * (size.X / 2 - 0.175), 0, 0)
			jamb.Parent = entrance
		end
		local top = slab:Clone()
		top.Name = "DoorHead"
		top.Size = Vector3.new(size.X, 0.35, 0.5)
		top.CFrame = cf * CFrame.new(0, size.Y / 2 - 0.175, 0)
		top.Parent = entrance
		slab:Destroy()
	end
	for _, piece in ipairs(entrance and entrance:GetChildren() or {}) do
		if piece:IsA("BasePart") and (piece.Name == "DoorGlass" or piece.Name == "PushBar" or piece.Name == "DoorDivider") then
			piece.CanCollide = false
			local side = (piece.Name == "DoorDivider" or piece.Position.X < 0) and -1 or 1
			piece:SetAttribute("SlideX", side * 3.4)
			CollectionService:AddTag(piece, "SlidingDoor")
		end
	end
	return folder
end

return Builder
