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
local Gyms = require(script.Parent.Gyms) -- (the gyms' size: the gym fronts, parapets and roofs follow it)
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
	local paved = {
		{ -194, 218, 16, 54 },     -- Main Street, sidewalks, the shop frontage
		{ -40, 96, -76, 18 },      -- gyms + forecourt
		{ -194, -40, 0, 18 },      -- building rows south of Main Street
		{ 96, 218, 0, 18 },
		{ -194, 218, 54, 94 },     -- north building rows + side streets
		{ -54, -34, 50, 150 },     -- avenues
		{ 34, 54, 50, 150 },
		{ -34, 34, 50, 92 },       -- plaza
		{ -152, -54, 92, 145 },    -- parking
		{ 54, 218, 92, 116 },      -- sports court + east buildings
		{ 54, 114, 116, 145 },
		{ -194, 218, 145, 168 },   -- Beach Road
	}
	for _, r in ipairs(paved) do
		terrain:FillBlock(CFrame.new((r[1] + r[2]) / 2, -7.2, (r[3] + r[4]) / 2), Vector3.new(r[2] - r[1], 10, r[4] - r[3]), M.Pavement)
	end
	-- the park: flat lawn level with the paths (surface ~0)
	local park = Town.Park
	terrain:FillBlock(CFrame.new((park.MinX + park.MaxX) / 2, -6.1, (park.MinZ + park.MaxZ) / 2), Vector3.new(park.MaxX - park.MinX, 8, park.MaxZ - park.MinZ), M.LeafyGrass)
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
	-- last: nothing may stick up through the gyms, streets or paving (big hill balls and lawn bumps reach far), so clear
	-- everything above the ground there and lay the flat underlay again
	for _, r in ipairs(paved) do
		local cx, cz, w, d = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2, r[2] - r[1], r[4] - r[3]
		terrain:FillBlock(CFrame.new(cx, 20, cz), Vector3.new(w, 44, d), M.Air)
		terrain:FillBlock(CFrame.new(cx, -7.2, cz), Vector3.new(w, 10, d), M.Pavement)
	end
	-- the beach stays flat sand (nothing from the hills or patches may poke through the beach areas)
	local bx0, bx1, bz0, bz1 = beach.MinX - 18, beach.MaxX + 18, beach.MinZ, shore - 14
	terrain:FillBlock(CFrame.new((bx0 + bx1) / 2, 18, (bz0 + bz1) / 2), Vector3.new(bx1 - bx0, 44, bz1 - bz0), M.Air)
	terrain:FillBlock(CFrame.new((bx0 + bx1) / 2, -6, (bz0 + bz1) / 2), Vector3.new(bx1 - bx0, 8, bz1 - bz0), M.Sand)
	terrain:FillBlock(CFrame.new((park.MinX + park.MaxX) / 2, 20, (park.MinZ + park.MaxZ) / 2), Vector3.new(park.MaxX - park.MinX, 40, park.MaxZ - park.MinZ), M.Air)
	terrain:FillBlock(CFrame.new((park.MinX + park.MaxX) / 2, -6.1, (park.MinZ + park.MaxZ) / 2), Vector3.new(park.MaxX - park.MinX, 8, park.MaxZ - park.MinZ), M.LeafyGrass)
end

local JOINT = hex("#A29B8F")
local YELLOW = hex("#E3C35A")

-- Sidewalk slab (top at 0.35) with paving joints across its long direction.
local function sidewalk(parent, x0, x1, z0, z1)
	if x1 - x0 < 0.5 or z1 - z0 < 0.5 then return end
	local w, d, cx, cz = x1 - x0, z1 - z0, (x0 + x1) / 2, (z0 + z1) / 2
	p(parent, "Sidewalk", Vector3.new(w, 0.6, d), CFrame.new(cx, 0.05, cz), C.Sidewalk, M.Concrete, true)
	if w >= d then
		for x = x0 + 6, x1 - 1, 6 do p(parent, "Joint", Vector3.new(0.06, 0.02, d), CFrame.new(x, 0.36, cz), JOINT) end
	else
		for z = z0 + 6, z1 - 1, 6 do p(parent, "Joint", Vector3.new(w, 0.02, 0.06), CFrame.new(cx, 0.36, z), JOINT) end
	end
end

-- Road: asphalt (top at 0.05) with a curb strip on both long edges and lane markings. `lanes` = 2 or 4.
-- `gaps` = list of positions along the road where markings stop (crosswalks, side roads).
local function road(parent, x0, x1, z0, z1, lanes, gaps)
	local w, d, cx, cz = x1 - x0, z1 - z0, (x0 + x1) / 2, (z0 + z1) / 2
	local alongX = w >= d
	p(parent, "Asphalt", Vector3.new(w, 0.4, d), CFrame.new(cx, -0.15, cz), C.Asphalt, M.Asphalt, true)
	local length, width = alongX and w or d, alongX and d or w
	local start = alongX and x0 or z0
	local function at(along, across) -- along the road, across from its center line
		if alongX then return CFrame.new(along, 0.06, cz + across) end
		return CFrame.new(cx + across, 0.06, along) * CFrame.Angles(0, math.pi / 2, 0)
	end
	local function free(along)
		for _, g in ipairs(gaps or {}) do if math.abs(along - g) < 7 then return false end end
		return true
	end
	for _, side in ipairs({ -1, 1 }) do
		p(parent, "Curb", alongX and Vector3.new(length, 0.7, 0.4) or Vector3.new(0.4, 0.7, length), at(start + length / 2, side * (width / 2 - 0.2)) * CFrame.new(0, 0.04, 0) * (alongX and CFrame.new() or CFrame.Angles(0, -math.pi / 2, 0)), C.Curb, M.Concrete, true)
	end
	for along = start + 4, start + length - 4, 8 do
		if free(along) then
			if lanes == 4 then
				-- double yellow center line + white lane dashes
				for _, off in ipairs({ -0.25, 0.25 }) do p(parent, "CenterLine", Vector3.new(8, 0.02, 0.18), at(along, off), YELLOW) end
				for _, side in ipairs({ -1, 1 }) do p(parent, "Dash", Vector3.new(4, 0.02, 0.25), at(along, side * width / 4), C.Stripe) end
			else
				p(parent, "Dash", Vector3.new(4, 0.02, 0.25), at(along, 0), C.Stripe)
			end
		end
	end
end

-- Zebra crossing across a road (stripes run along the road direction).
local function crosswalk(parent, cx, cz, length, alongX)
	for i = -3, 3 do
		if alongX then
			p(parent, "Crosswalk", Vector3.new(0.9, 0.02, length - 1.2), CFrame.new(cx + i * 1.5, 0.06, cz), C.Stripe)
		else
			p(parent, "Crosswalk", Vector3.new(length - 1.2, 0.02, 0.9), CFrame.new(cx, 0.06, cz + i * 1.5), C.Stripe)
		end
	end
end

-- A small street tree in a pit with an iron grate.
local function streetTree(parent, position, kind, seed)
	p(parent, "TreeGrate", Vector3.new(2.6, 0.05, 2.6), CFrame.new(position + Vector3.new(0, 0.37, 0)), C.Iron, M.DiamondPlate)
	p(parent, "TreeSoil", Vector3.new(2.2, 0.04, 2.2), CFrame.new(position + Vector3.new(0, 0.36, 0)), hex("#3B2A1E"), M.Ground)
	if kind == "palm" then
		TownKit.palm(parent, position + Vector3.new(0, 0.35, 0), 1, seed)
	elseif kind == "cypress" then
		TownKit.cypress(parent, position + Vector3.new(0, 0.35, 0), 1)
	else
		TownKit.roundTree(parent, position + Vector3.new(0, 0.35, 0), 0.95, seed)
	end
end

local function buildStreets()
	local street = Instance.new("Folder")
	street.Name = "Street"
	street.Parent = folder
	local s, br, sw = Town.Street, Town.BeachRoad, Town.SideSidewalk
	local avenueX = {}
	for _, a in ipairs(Town.Avenues) do table.insert(avenueX, { a.X - a.Width / 2, a.X + a.Width / 2 }) end
	-- spans of x between the avenues (the north sidewalk of Main Street and the south one of Beach Road stop at them)
	local function splitX(x0, x1)
		local spans, cur = {}, x0
		for _, a in ipairs(avenueX) do
			table.insert(spans, { cur, a[1] })
			cur = a[2]
		end
		table.insert(spans, { cur, x1 })
		return spans
	end

	-- Main Street: 4 lanes, wide sidewalks, a paved frontage strip in front of the shops
	road(street, s.MinX, s.MaxX, s.MinZ, s.MaxZ, 4, Town.Crosswalks)
	sidewalk(street, s.MinX, s.MaxX, s.MinZ - s.Sidewalk, s.MinZ)
	for _, span in ipairs(splitX(s.MinX, s.MaxX)) do
		sidewalk(street, span[1], span[2], s.MaxZ, s.MaxZ + s.Sidewalk)
		-- frontage paving up to the shop fronts (z 50..54), except in front of the plaza (it has its own)
		local a, b = span[1], span[2]
		if not (a < 0 and b > 0) then
			p(street, "FrontPaving", Vector3.new(b - a - 8, 0.4, 4), CFrame.new((a + b) / 2, 0, s.MaxZ + s.Sidewalk + 2), C.Paving, M.Pavement, true)
		end
	end
	for _, cx in ipairs(Town.Crosswalks) do crosswalk(street, cx, (s.MinZ + s.MaxZ) / 2, s.MaxZ - s.MinZ, true) end

	-- Beach Road: 2 lanes along the beach, sidewalks both sides
	road(street, br.MinX, br.MaxX, br.MinZ, br.MaxZ, 2, Town.BeachRoadCrosswalks)
	sidewalk(street, br.MinX, br.MaxX, br.MaxZ, br.MaxZ + br.Sidewalk)
	for _, span in ipairs(splitX(br.MinX, br.MaxX)) do sidewalk(street, span[1], span[2], br.MinZ - br.Sidewalk, br.MinZ) end
	for _, cx in ipairs(Town.BeachRoadCrosswalks) do crosswalk(street, cx, (br.MinZ + br.MaxZ) / 2, br.MaxZ - br.MinZ, true) end

	-- Avenues from Main Street to Beach Road; sidewalks open where a side street joins
	for i, a in ipairs(avenueX) do
		road(street, a[1], a[2], s.MaxZ, br.MinZ, 2, { s.MaxZ + 3, br.MinZ - 3, 83 })
		local outer = i == 1 and -1 or 1 -- the side street joins on the outer side
		for _, side in ipairs({ -1, 1 }) do
			local x0 = side < 0 and a[1] - sw or a[2]
			local x1 = x0 + sw
			if side == outer then
				sidewalk(street, x0, x1, s.MaxZ + s.Sidewalk, 74)
				sidewalk(street, x0, x1, 92, br.MinZ - br.Sidewalk)
			else
				sidewalk(street, x0, x1, s.MaxZ + s.Sidewalk, br.MinZ - br.Sidewalk)
			end
		end
		crosswalk(street, (a[1] + a[2]) / 2, s.MaxZ + s.Sidewalk + 4, a[2] - a[1], false)
		crosswalk(street, (a[1] + a[2]) / 2, br.MinZ - br.Sidewalk - 4, a[2] - a[1], false)
	end

	-- side streets behind the shop rows
	for i, ss in ipairs(Town.SideStreets) do
		road(street, ss.MinX, ss.MaxX, ss.MinZ, ss.MaxZ, 2, { i == 1 and -60 or 60 })
		local x0, x1 = i == 1 and ss.MinX or ss.MinX + sw, i == 1 and ss.MaxX - sw or ss.MaxX
		sidewalk(street, x0, x1, ss.MinZ - sw, ss.MinZ)
		sidewalk(street, x0, x1, ss.MaxZ, ss.MaxZ + sw)
		crosswalk(street, i == 1 and -60 or 60, (ss.MinZ + ss.MaxZ) / 2, ss.MaxZ - ss.MinZ, true)
	end

	-- lamps and street trees: one every 12 studs along each sidewalk, alternating lamp / tree
	local function nearAvenue(x, margin)
		for _, a in ipairs(avenueX) do if x > a[1] - margin and x < a[2] + margin then return true end end
		return false
	end
	local function nearCross(x, list)
		for _, cx in ipairs(list) do if math.abs(x - cx) < 6 then return true end end
		return false
	end
	local k = 0
	for x = s.MinX + 10, s.MaxX - 10, 12 do
		k += 1
		if not nearCross(x, Town.Crosswalks) then
			-- south sidewalk (gym side): lamps only (the gym fronts have their own planters)
			if k % 2 == 0 then TownKit.lamp(street, Vector3.new(x, 0.35, s.MinZ - 1), Vector3.new(0, 0, 1)) end
			if not nearAvenue(x, 4) then
				if k % 2 == 1 then
					TownKit.lamp(street, Vector3.new(x, 0.35, s.MaxZ + 1), Vector3.new(0, 0, -1))
				elseif x < -36 or x > 36 then
					streetTree(street, Vector3.new(x, 0, s.MaxZ + 3), "round", k)
				end
			end
		end
	end
	k = 0
	for x = br.MinX + 10, br.MaxX - 10, 12 do
		k += 1
		if not nearCross(x, Town.BeachRoadCrosswalks) then
			-- beach side: lamps and palms; town side: lamps
			if k % 2 == 0 then
				TownKit.lamp(street, Vector3.new(x, 0.35, br.MaxZ + 1), Vector3.new(0, 0, -1))
			else
				streetTree(street, Vector3.new(x, 0, br.MaxZ + 3), "palm", k)
			end
			if k % 2 == 1 and not nearAvenue(x, 4) then TownKit.lamp(street, Vector3.new(x, 0.35, br.MinZ - 1), Vector3.new(0, 0, 1)) end
		end
	end
	for _, a in ipairs(avenueX) do
		k = 0
		for z = s.MaxZ + 14, br.MinZ - 12, 12 do
			k += 1
			if z < 72 or z > 94 then
				if k % 2 == 0 then
					TownKit.lamp(street, Vector3.new(a[1] - 1, 0.35, z), Vector3.new(1, 0, 0))
					TownKit.lamp(street, Vector3.new(a[2] + 1, 0.35, z + 6), Vector3.new(-1, 0, 0))
				else
					streetTree(street, Vector3.new(a[1] - 2.2, 0, z), "cypress", k)
					streetTree(street, Vector3.new(a[2] + 2.2, 0, z + 6), "cypress", k)
				end
			end
		end
	end
	for i, ss in ipairs(Town.SideStreets) do
		k = 0
		local x0, x1 = i == 1 and ss.MinX + 14 or ss.MinX + 16, i == 1 and ss.MaxX - 16 or ss.MaxX - 14
		for x = x0, x1, 12 do
			k += 1
			if math.abs(x - (i == 1 and -60 or 60)) > 6 then
				if k % 2 == 0 then
					TownKit.lamp(street, Vector3.new(x, 0.35, ss.MaxZ + 1), Vector3.new(0, 0, -1))
				else
					TownKit.lamp(street, Vector3.new(x, 0.35, ss.MinZ - 1), Vector3.new(0, 0, 1))
				end
			end
		end
	end

	-- the roads end in planted islands with trees at both ends of town (hills beyond)
	for _, r in ipairs({ { s.MinX + 3, (s.MinZ + s.MaxZ) / 2, s.MaxZ - s.MinZ }, { s.MaxX - 3, (s.MinZ + s.MaxZ) / 2, s.MaxZ - s.MinZ },
		{ br.MinX + 3, (br.MinZ + br.MaxZ) / 2, br.MaxZ - br.MinZ }, { br.MaxX - 3, (br.MinZ + br.MaxZ) / 2, br.MaxZ - br.MinZ } }) do
		TownKit.planter(street, CFrame.new(r[1], 0, r[2]), 4, r[3] - 2, "bush")
		TownKit.oak(street, Vector3.new(r[1] + (r[1] < 0 and -10 or 10), 0, r[2]), 1.2)
	end
	-- bus stops on Main Street and Beach Road, hydrants, bins, benches, bike racks along the sidewalks
	TownKit.busStop(street, look(Vector3.new(-122, 0.35, s.MaxZ + 2.6), Vector3.new(-122, 0, 0)))
	TownKit.busStop(street, look(Vector3.new(150, 0.35, s.MaxZ + 2.6), Vector3.new(150, 0, 0)))
	TownKit.busStop(street, look(Vector3.new(-80, 0.35, br.MinZ - 2.4), Vector3.new(-80, 0, 300)))
	for _, x in ipairs({ -150, -98, -64, 64, 104, 132, 186 }) do TownKit.bin(street, CFrame.new(x + 3, 0.35, s.MaxZ + 4.6)) end
	for _, x in ipairs({ -140, -70, 70, 140 }) do TownKit.hydrant(street, CFrame.new(x, 0.35, s.MinZ - 4.6)) end
	for _, x in ipairs({ -160, -100, 120, 176 }) do TownKit.bench(street, look(Vector3.new(x, 0.35, s.MaxZ + 4.6), Vector3.new(x, 0, 300))) end
	for _, x in ipairs({ -30, 30, 150, -150 }) do TownKit.bench(street, look(Vector3.new(x, 0.35, br.MaxZ + 3.6), Vector3.new(x, 0, 0))) end
	TownKit.bikeRack(street, CFrame.new(-140, 0.35, s.MaxZ + 3.6), 4)
	TownKit.bike(street, CFrame.new(-140.6, 0.35, s.MaxZ + 3.6), hex("#E86A6A"))
	TownKit.bikeRack(street, CFrame.new(90, 0.35, br.MinZ - 2.8), 4)
	-- signposts at the main corners
	TownKit.signpost(street, CFrame.new(-38 + 2, 0.35, s.MaxZ + 4), {
		{ text = "Smoothies", yaw = 180 }, { text = "Parking", yaw = -140 }, { text = "Skate park", yaw = -115 }, { text = "Beach", yaw = -90 },
	})
	TownKit.signpost(street, CFrame.new(38 - 2, 0.35, s.MaxZ + 4), {
		{ text = "Gear & Fits", yaw = 0 }, { text = "Sports court", yaw = -40 }, { text = "Posing stage", yaw = -65 }, { text = "Beach gym", yaw = -90 },
	})
	TownKit.signpost(street, CFrame.new(6, 0.35, br.MinZ - 3), {
		{ text = "Beach gym", yaw = -90 }, { text = "Skate park", yaw = 180 }, { text = "Posing stage", yaw = 0 }, { text = "Gym", yaw = 90 },
	})
end

------------------------------------------------------------------------
-- Gym forecourt + exteriors
------------------------------------------------------------------------
local function buildGymFront()
	-- a Persistent model (not a Folder): the menu shot looks at the gym front, so it must always be streamed in
	local front = Instance.new("Model")
	front.Name = "GymFront"
	front.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
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
		TownKit.nightLight(downlight)
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
	local G, S, P = Gyms.Map, Gyms.Starter, Gyms.Pro
	local roofX = G(Vector3.new(-20, 0, 0)).X
	local roof = look(Vector3.new(roofX, S.Height + 4, -3.6), Vector3.new(roofX, S.Height + 4, 40))
	for _, x in ipairs({ -5, 5 }) do p(front, "RoofSignLeg", Vector3.new(0.3, 3.4, 0.3), roof * CFrame.new(x, -1.6, 0.4), hex("#1C1C1E"), M.Metal) end
	p(front, "RoofSignBack", Vector3.new(13, 3.2, 0.4), roof * CFrame.new(0, 1.2, 0.2), hex("#1C1C1E"), M.Metal)
	local rb, rl = Kit.sign(front, "RoofSign", Vector3.new(12.4, 2.6, 0.1), roof * CFrame.new(0, 1.2, -0.05), "GYM ARC", C.White, hex("#1C1C1E"), 40)
	rl.FontFace = Theme.Fonts.SemiBold
	local rg = Instance.new("SurfaceLight")
	rg.Face = Enum.NormalId.Back
	rg.Color, rg.Brightness, rg.Range, rg.Shadows = hex("#FFF2DD"), 0.8, 8, false
	rg.Parent = rb
	-- the PRO sign on the pro gym front (LED letters on dark glass)
	local proX = G(Vector3.new(66, 0, 0)).X
	local pro = look(Vector3.new(proX, P.Height - 3.5, -2.8), Vector3.new(proX, P.Height - 3.5, 40))
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
	parapet(S.MinX - 1.5, -2.9, S.MaxX + 1, S.MinZ - 1.1, S.Height + 1, hex("#8C4A3A"))
	parapet(-11, 14.1, 11, -2.9, 14, hex("#8C4A3A"))
	parapet(Gyms.SharedX + 0.5, -2.9, P.MaxX + 1.5, P.MinZ - 1.1, P.Height + 1, hex("#16171A"))
	for _, x in ipairs({ S.MinX - 0.5, -11.5, 11.5, S.MaxX - 0.3 }) do
		cyl(front, "Drainpipe", S.Height + 1, 0.4, CFrame.new(x, (S.Height + 1) / 2, -2.6) * up, hex("#3A3A3D"), M.Metal)
		p(front, "Shoe", Vector3.new(0.6, 0.3, 0.8), CFrame.new(x, 0.35, -2.4), hex("#3A3A3D"), M.Metal)
	end
	for _, designX in ipairs({ -25, -13, 13, 25, 46, 58, 70, 82, 90 }) do
		local x = G(Vector3.new(designX, 0, 0)).X
		local lampCF = CFrame.new(x, if x > Gyms.SharedX then P.Height - 5.5 else 9.6, -2.75)
		p(front, "WallLightArm", Vector3.new(0.12, 0.12, 0.6), lampCF, hex("#1C1C1E"), M.Metal)
		local shade = p(front, "WallLight", Vector3.new(0.7, 0.4, 0.5), lampCF * CFrame.new(0, -0.15, 0.3), x > Gyms.SharedX and C.Chalk or C.Warm, M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color, light.Brightness, light.Range, light.Angle, light.Shadows = x > Gyms.SharedX and hex("#DCE6FF") or C.Warm, 1, 12, 80, false
		light.Parent = shade
		TownKit.nightLight(shade, x > Gyms.SharedX and C.Chalk or C.Warm)
	end
	-- planters by the entrance, a bike rack with a couple of bikes, benches, trees in planters along the front
	for _, x in ipairs({ -8, 8 }) do TownKit.planter(front, CFrame.new(x, 0.2, 16.5), 3, 3, "bush") end
	TownKit.bikeRack(front, CFrame.new(-17, 0.2, 9) * CFrame.Angles(0, rad(90), 0), 5)
	TownKit.bike(front, CFrame.new(-17.6, 0.2, 7.8) * CFrame.Angles(0, rad(90), 0), hex("#2E6E8E"))
	TownKit.bike(front, CFrame.new(-17.6, 0.2, 10.2) * CFrame.Angles(0, rad(90), 0), hex("#B5654A"))
	TownKit.bench(front, look(Vector3.new(-28, 0.2, 8), Vector3.new(-28, 0, -20)))
	TownKit.bench(front, look(Vector3.new(24, 0.2, 8), Vector3.new(24, 0, -20)))
	for _, designX in ipairs({ -32, -4 - 20, 18, 30, 44, 58, 72, 86 }) do
		local x = math.floor(G(Vector3.new(designX, 0, 0)).X + 0.5)
		if math.abs(x) > 14 then
			TownKit.planter(front, CFrame.new(x, 0.2, 2.6), 3.2, 3.2, x % 2 == 0 and "flowers" or "bush")
		end
	end
	for _, designX in ipairs({ 50, 64, 78, 92 }) do TownKit.cypress(front, Vector3.new(G(Vector3.new(designX, 0, 0)).X, 0.2, 12), 1.1) end
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
	local S, P = Gyms.Starter, Gyms.Pro
	-- a roof point from the first layout's coordinates (Gyms.Map), on top of whichever gym it is over
	local function onRoof(x, z, lift)
		local at = Gyms.Map(Vector3.new(x, 0, z))
		return CFrame.new(at.X, (if at.X > Gyms.SharedX then P.Height else S.Height) + 1 + (lift or 0), at.Z)
	end
	seams(S.MinX - 1, S.MaxX + 1, S.MinZ - 1, -3, S.Height + 1, hex("#55524D"))
	seams(Gyms.SharedX + 0.5, P.MaxX + 1, P.MinZ - 1, -3, P.Height + 1, hex("#26272A"))
	local function acUnit(cf)
		p(roof, "AcUnit", Vector3.new(4, 2.4, 3), cf * CFrame.new(0, 1.2, 0), hex("#C9C6BF"), M.Metal, true)
		cyl(roof, "AcFan", 0.1, 2.2, cf * CFrame.new(-0.8, 2.45, 0) * up, hex("#4A4C50"), M.DiamondPlate)
		cyl(roof, "AcFan", 0.1, 2.2, cf * CFrame.new(1.0, 2.45, 0) * up, hex("#4A4C50"), M.DiamondPlate)
		p(roof, "AcGrille", Vector3.new(3.8, 1.6, 0.05), cf * CFrame.new(0, 1.1, -1.52), hex("#9E9B94"), M.DiamondPlate)
		p(roof, "AcPipe", Vector3.new(0.3, 0.3, 3), cf * CFrame.new(1.6, 0.3, 3), C.Iron, M.Metal)
	end
	for _, spot in ipairs({ { -28, -60 }, { -28, -48 }, { 26, -66 }, { 84, -60 }, { 84, -48 } }) do
		acUnit(onRoof(spot[1], spot[2]))
	end
	-- skylights over the starter gym (glass hipped boxes with frames)
	for _, spot in ipairs({ { -8, -24 }, { 10, -24 }, { -8, -44 }, { 10, -44 } }) do
		local cf = onRoof(spot[1], spot[2])
		p(roof, "SkylightCurb", Vector3.new(8.4, 0.8, 4.4), cf * CFrame.new(0, 0.4, 0), hex("#8C4A3A"), M.Concrete, true)
		p(roof, "SkylightGlass", Vector3.new(8, 1, 4), cf * CFrame.new(0, 1.3, 0), hex("#9DB3BE"), M.Glass, false, { Transparency = 0.3, Reflectance = 0.2 })
		for x = -4, 4, 2 do p(roof, "SkylightBar", Vector3.new(0.12, 1.05, 4.05), cf * CFrame.new(x, 1.3, 0), C.Iron, M.Metal) end
	end
	-- exhaust fans and a roof hatch
	for _, spot in ipairs({ { 20, -40 }, { -18, -12 }, { 50, -20 } }) do
		local cf = onRoof(spot[1], spot[2])
		cyl(roof, "FanBase", 0.8, 2.2, cf * CFrame.new(0, 0.4, 0) * up, hex("#9E9B94"), M.Metal, true)
		cyl(roof, "FanHood", 0.6, 2.6, cf * CFrame.new(0, 1.2, 0) * up, hex("#B8B5AE"), M.Metal)
		cyl(roof, "FanCap", 0.3, 1.2, cf * CFrame.new(0, 1.65, 0) * up, hex("#B8B5AE"), M.Metal)
	end
	p(roof, "Hatch", Vector3.new(3, 1, 3), onRoof(-30, -20, 0.5), hex("#8C4A3A"), M.Concrete, true)
	p(roof, "HatchLid", Vector3.new(3.2, 0.2, 3.2), onRoof(-30, -20, 1.1), C.Iron, M.Metal)
	-- solar panels on the pro gym (tilted rows on frames)
	for row = 0, 3 do
		for col = 0, 4 do
			local base = onRoof(46 + col * 8, -30 - row * 7)
			local cf = base * CFrame.Angles(rad(-20), 0, 0)
			p(roof, "SolarFrame", Vector3.new(0.2, 1.4, 0.2), base * CFrame.new(-3, 0.7, 1.4), C.Iron, M.Metal)
			p(roof, "SolarFrame", Vector3.new(0.2, 1.4, 0.2), base * CFrame.new(3, 0.7, 1.4), C.Iron, M.Metal)
			p(roof, "SolarPanel", Vector3.new(7, 0.15, 4), cf * CFrame.new(0, 1.3, 0), hex("#1E2A44"), M.Glass, false, { Reflectance = 0.25 })
			p(roof, "SolarEdge", Vector3.new(7.1, 0.12, 4.1), cf * CFrame.new(0, 1.22, 0), hex("#C9CCD2"), M.Metal)
		end
	end
end

------------------------------------------------------------------------
-- Plaza (open square across from the gym), park, parking lot, sports court
------------------------------------------------------------------------
local function hedge(parent, a, b)
	-- a low trimmed hedge from a to b (on the ground), as a row of overlapping clumps on a soil strip
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	p(parent, "HedgeSoil", Vector3.new(1.8, 0.4, len), cf * CFrame.new(0, 0.2, 0), hex("#3B2A1E"), M.Ground)
	for t = 0, len, 1.6 do
		ball(parent, "Hedge", Vector3.new(2.2, 1.8, 2.2), cf * CFrame.new(0, 1.0, -len / 2 + t), (math.floor(t) % 3 == 0) and C.Leaf3 or C.Leaf1, M.LeafyGrass)
	end
end

local function buildPlaza()
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = folder
	local pz = Town.Plaza
	local cx, cz = (pz.MinX + pz.MaxX) / 2, (pz.MinZ + pz.MaxZ) / 2
	local w, d = pz.MaxX - pz.MinX, pz.MaxZ - pz.MinZ
	p(plaza, "Paving", Vector3.new(w, 0.4, d), CFrame.new(cx, 0.0, cz), C.Paving, M.Pavement, true)
	-- border band, a grid of darker bands, and a big inlaid compass ring in the middle
	for _, side in ipairs({ -1, 1 }) do
		p(plaza, "Border", Vector3.new(w, 0.02, 1.2), CFrame.new(cx, 0.21, cz + side * (d / 2 - 0.8)), C.PavingDark, M.Pavement)
		p(plaza, "Border", Vector3.new(1.2, 0.02, d), CFrame.new(cx + side * (w / 2 - 0.8), 0.21, cz), C.PavingDark, M.Pavement)
	end
	for x = pz.MinX + 8.5, pz.MaxX - 8, 8.5 do p(plaza, "Band", Vector3.new(0.4, 0.02, d - 2), CFrame.new(x, 0.205, cz), C.PavingDark, M.Pavement) end
	for _, r in ipairs({ 13, 9 }) do
		cyl(plaza, "Ring", 0.03, r * 2, CFrame.new(cx, 0.2, cz) * up, C.PavingDark, M.Pavement)
		cyl(plaza, "RingInner", 0.035, r * 2 - 1.2, CFrame.new(cx, 0.2, cz) * up, C.Paving, M.Pavement)
	end
	for i = 0, 7 do
		local a = i * math.pi / 4
		p(plaza, "CompassPoint", Vector3.new(0.6, 0.04, i % 2 == 0 and 8 or 5), CFrame.new(cx, 0.21, cz) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(i % 2 == 0 and 4 or 2.5)), C.Brass, M.Metal)
	end
	TownKit.clockPost(plaza, Vector3.new(cx, 0.2, cz))
	-- corner trees in planters, string lights between poles at the corners
	local corners = { { pz.MinX + 4, pz.MinZ + 4.5 }, { pz.MaxX - 4, pz.MinZ + 4.5 }, { pz.MinX + 4, pz.MaxZ - 4.5 }, { pz.MaxX - 4, pz.MaxZ - 4.5 } }
	local tops = {}
	for i, c in ipairs(corners) do
		TownKit.planter(plaza, CFrame.new(c[1], 0.2, c[2]), 4.5, 4.5, nil)
		TownKit.roundTree(plaza, Vector3.new(c[1], 1.6, c[2]), 1.15, i)
		local px = c[1] + (c[1] < cx and 3 or -3)
		cyl(plaza, "LightPole", 11, 0.3, CFrame.new(px, 5.7, c[2]) * up, C.Iron, M.Metal, true)
		ball(plaza, "PoleFinial", Vector3.new(0.45, 0.45, 0.45), CFrame.new(px, 11.3, c[2]), C.Brass, M.Metal)
		tops[i] = Vector3.new(px, 10.8, c[2])
	end
	TownKit.stringLights(plaza, tops[1], tops[4], 18)
	TownKit.stringLights(plaza, tops[2], tops[3], 18)
	TownKit.stringLights(plaza, tops[1], tops[2], 16)
	TownKit.stringLights(plaza, tops[3], tops[4], 16)
	-- benches along the sides facing in, flower planters between them, a cart or two, bins, a bike rack
	for _, side in ipairs({ -1, 1 }) do
		local x = cx + side * (w / 2 - 3)
		for i, z in ipairs({ pz.MinZ + 13, pz.MinZ + 21, pz.MinZ + 29 }) do
			TownKit.bench(plaza, look(Vector3.new(x, 0.2, z), Vector3.new(cx, 0, z)))
			if i < 3 then TownKit.planter(plaza, CFrame.new(x - side * 0.4, 0.2, z + 4), 2.2, 3, "flowers") end
		end
	end
	TownKit.cart(plaza, look(Vector3.new(cx - 16, 0.2, pz.MinZ + 7), Vector3.new(cx - 16, 0, 0)), hex("#7CC6A5"), hex("#F29E6B"))
	TownKit.cart(plaza, look(Vector3.new(cx + 17, 0.2, pz.MaxZ - 9), Vector3.new(cx, 0, cz)), hex("#6FA8DC"), hex("#F2C14E"))
	TownKit.bin(plaza, CFrame.new(cx - 9, 0.2, pz.MinZ + 2.5))
	TownKit.bin(plaza, CFrame.new(cx + 9, 0.2, pz.MaxZ - 2.5))
	TownKit.bikeRack(plaza, CFrame.new(cx + 22, 0.2, pz.MinZ + 3), 5)
	TownKit.bike(plaza, CFrame.new(cx + 21.4, 0.2, pz.MinZ + 3), hex("#2E6E8E"))
end

local function buildPark()
	local park = Instance.new("Folder")
	park.Name = "Park"
	park.Parent = folder
	local pk = Town.Park
	local cx = (pk.MinX + pk.MaxX) / 2
	local fz = 118 -- fountain center
	local pathColor, edge = hex("#D8C9AE"), hex("#B5AA98")
	-- paths: north-south through the middle, east-west to both avenues, a ring around the fountain (the ring and the
	-- four straights are merged into one part so no slabs overlap)
	local straights = {
		TownKit.path(park, { Vector3.new(cx, 0.05, pk.MinZ - 0.5), Vector3.new(cx, 0.05, fz - 14) }, 5, pathColor, edge),
		TownKit.path(park, { Vector3.new(cx, 0.05, fz + 14), Vector3.new(cx, 0.05, pk.MaxZ + 0.5) }, 5, pathColor, edge),
		TownKit.path(park, { Vector3.new(pk.MinX - 0.5, 0.05, fz), Vector3.new(cx - 14, 0.05, fz) }, 4.5, pathColor, edge),
		TownKit.path(park, { Vector3.new(cx + 14, 0.05, fz), Vector3.new(pk.MaxX + 0.5, 0.05, fz) }, 4.5, pathColor, edge),
	}
	TownKit.pathRing(park, Vector3.new(cx, 0.05, fz), 14, 4.5, pathColor, straights)
	-- the fountain on a round paved pad
	cyl(park, "FountainPad", 0.3, 19, CFrame.new(cx, 0.05, fz) * up, C.Paving, M.Pavement, true)
	TownKit.fountain(park, CFrame.new(cx, 0.2, fz))
	for i = 0, 3 do
		local a = rad(45 + i * 90)
		local pos = Vector3.new(cx + math.cos(a) * 17.5, 0.05, fz + math.sin(a) * 17.5)
		TownKit.bench(park, look(pos, Vector3.new(cx, 0, fz)))
	end
	-- lamps by the paths
	for _, spot in ipairs({ { cx - 3.6, 100 }, { cx + 3.6, 138 }, { -24, fz - 3.4 }, { 24, fz + 3.4 } }) do
		TownKit.lamp(park, Vector3.new(spot[1], 0.05, spot[2]), Vector3.new(cx - spot[1], 0, fz - spot[2]).Unit)
	end
	-- playground (north-east): soft rubber ground with a border, slide, swings, climbing dome, benches for parents
	local pg = CFrame.new(20, 0, 133)
	p(park, "PlayGround", Vector3.new(24, 0.3, 18), pg * CFrame.new(0, 0.1, 0), hex("#C7643F"), M.Rubber, true)
	p(park, "PlayGroundInlay", Vector3.new(10, 0.05, 6), pg * CFrame.new(-4, 0.27, -3), hex("#2E8A6E"), M.Rubber)
	for _, side in ipairs({ -1, 1 }) do
		p(park, "PlayBorder", Vector3.new(24.6, 0.5, 0.3), pg * CFrame.new(0, 0.25, side * 9.1), hex("#F2C14E"), M.Plastic)
		p(park, "PlayBorder", Vector3.new(0.3, 0.5, 18.6), pg * CFrame.new(side * 12.15, 0.25, 0), hex("#F2C14E"), M.Plastic)
	end
	TownKit.slide(park, pg * CFrame.new(-6, 0.25, 2) * CFrame.Angles(0, math.pi, 0), hex("#F2C14E"))
	TownKit.swings(park, pg * CFrame.new(5, 0.25, 4))
	TownKit.climber(park, pg * CFrame.new(5, 0.25, -4))
	TownKit.bench(park, look(Vector3.new(20, 0.05, 121.5), Vector3.new(20, 0, 140)))
	-- picnic area (north-west): tables under trees
	for i, spot in ipairs({ { -24, 128 }, { -14, 136 }, { -26, 139 } }) do
		TownKit.picnicTable(park, CFrame.new(spot[1], 0.05, spot[2]) * CFrame.Angles(0, rad(i * 25), 0), i == 2 and hex("#7CC6A5") or nil)
	end
	TownKit.oak(park, Vector3.new(-18, 0, 131), 1.2, 41)
	TownKit.oak(park, Vector3.new(-29, 0, 132), 1.0, 42)
	-- south quarters: flower beds, trees, bushes, rocks
	for _, q in ipairs({ { -20, 104 }, { 20, 104 } }) do
		TownKit.flowers(park, Vector3.new(q[1], 0.05, q[2]), 3.5, 24, q[1] > 0 and 7 or 8)
		cyl(park, "BedEdge", 0.35, 8, CFrame.new(q[1], 0.12, q[2]) * up, edge, M.Concrete)
		cyl(park, "BedSoil", 0.37, 7.4, CFrame.new(q[1], 0.12, q[2]) * up, hex("#3B2A1E"), M.Ground)
		TownKit.oak(park, Vector3.new(q[1] + (q[1] > 0 and 9 or -9), 0, q[2] + 5), 1.1, math.floor(q[1]))
		TownKit.bush(park, Vector3.new(q[1] + (q[1] > 0 and -6 or 6), 0, q[2] - 6), 1.1)
		TownKit.roundTree(park, Vector3.new(q[1] + (q[1] > 0 and 10 or -10), 0, q[2] - 7), 1.0)
	end
	TownKit.rock(park, Vector3.new(-30, -0.3, 110), 0.8)
	TownKit.rock(park, Vector3.new(29, -0.3, 96), 0.7)
	-- low hedges along the park edges, open where the paths come in
	hedge(park, Vector3.new(pk.MinX + 1, 0, pk.MinZ + 1), Vector3.new(cx - 4, 0, pk.MinZ + 1))
	hedge(park, Vector3.new(cx + 4, 0, pk.MinZ + 1), Vector3.new(pk.MaxX - 1, 0, pk.MinZ + 1))
	hedge(park, Vector3.new(pk.MinX + 1, 0, pk.MaxZ - 1), Vector3.new(cx - 4, 0, pk.MaxZ - 1))
	hedge(park, Vector3.new(cx + 4, 0, pk.MaxZ - 1), Vector3.new(pk.MaxX - 1, 0, pk.MaxZ - 1))
	TownKit.bin(park, CFrame.new(cx + 4.5, 0.05, 96))
	TownKit.bin(park, CFrame.new(-10, 0.05, fz + 4))
end

local CAR_COLORS = { hex("#D7262E"), hex("#2E6E8E"), hex("#F2EEE6"), hex("#3C5A48"), hex("#F2C14E"), hex("#2B2B2B"), hex("#9FB6C2"), hex("#E59A7A") }

local function buildParking()
	local lot = Instance.new("Folder")
	lot.Name = "Parking"
	lot.Parent = folder
	local pk = Town.Parking
	local x0, x1, z0, z1 = pk.MinX - 2, pk.MaxX + 4, pk.MinZ - 4, pk.MaxZ + 3 -- slab reaches the sidewalks
	p(lot, "Asphalt", Vector3.new(x1 - x0, 0.4, z1 - z0), CFrame.new((x0 + x1) / 2, -0.15, (z0 + z1) / 2), hex("#34353A"), M.Asphalt, true)
	-- two rows of stalls facing a middle aisle; white lines, wheel stops, parked cars in most stalls
	local rng = Random.new(21)
	local stallW = 6
	local rows = { { z = pk.MinZ + 6.5, facing = 1 }, { z = pk.MaxZ - 6.5, facing = -1 } }
	for _, row in ipairs(rows) do
		for x = pk.MinX + 4, pk.MaxX - 4, stallW do
			p(lot, "StallLine", Vector3.new(0.25, 0.02, 12), CFrame.new(x, 0.06, row.z), C.Stripe)
			local stallX = x + stallW / 2
			if stallX < pk.MaxX - 4 then
				p(lot, "WheelStop", Vector3.new(3.4, 0.35, 0.5), CFrame.new(stallX, 0.2, row.z - row.facing * 5), hex("#B9B2A6"), M.Concrete, true)
				-- about half the stalls taken, cars a bit smaller than the stall (a clear gap to the lines and their neighbours)
				if rng:NextNumber() < 0.45 then
					local cf = CFrame.new(stallX + rng:NextNumber(-0.3, 0.3), 0.05, row.z + rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, row.facing > 0 and math.pi or 0, 0) * CFrame.Angles(0, rad(rng:NextNumber(-3, 3)), 0)
					TownKit.car(lot, cf, CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]):ScaleTo(0.85)
				end
			end
		end
	end
	-- aisle arrows (pointing +X) and a planted island with trees and a lamp at each end of the rows. The head is two
	-- mirrored right-triangle wedges lying flat: a symmetric triangle whose base sits on the shaft's end and whose tip
	-- points ahead (one wedge alone made a half head pointing back at the shaft).
	local function arrowHead(baseX, z, length, width)
		for _, side in ipairs({ 1, -1 }) do
			local cf = CFrame.fromMatrix(Vector3.new(baseX + length / 2, 0.06, z + side * width / 4), Vector3.new(0, -side, 0), Vector3.new(0, 0, side))
			local head = Kit.wedge(lot, "ArrowHead", Vector3.new(0.02, width / 2, length), cf, C.Stripe, M.SmoothPlastic)
			head.CanCollide, head.CanQuery, head.CanTouch, head.CastShadow = false, false, false, false
		end
	end
	for _, x in ipairs({ -130, -104, -78 }) do
		p(lot, "Arrow", Vector3.new(4, 0.02, 0.5), CFrame.new(x, 0.06, (pk.MinZ + pk.MaxZ) / 2), C.Stripe)
		arrowHead(x + 2, (pk.MinZ + pk.MaxZ) / 2, 1.6, 1.6)
	end
	for _, row in ipairs(rows) do
		for _, x in ipairs({ pk.MinX + 1.5, pk.MaxX - 1 }) do
			TownKit.planter(lot, CFrame.new(x, 0.05, row.z), 3, 11, nil)
			TownKit.roundTree(lot, Vector3.new(x, 1.45, row.z), 0.9)
		end
		TownKit.lamp(lot, Vector3.new((pk.MinX + pk.MaxX) / 2, 0.05, row.z + row.facing * 6.6), Vector3.new(0, 0, row.facing))
	end
	-- curb + hedge around the lot (open at the entrance from the side street)
	local entranceX = -104
	hedge(lot, Vector3.new(x0 + 1, 0, z1 - 1), Vector3.new(x1 - 1, 0, z1 - 1))
	hedge(lot, Vector3.new(x0 + 1, 0, z0 + 6), Vector3.new(x0 + 1, 0, z1 - 2))
	hedge(lot, Vector3.new(x0 + 2, 0, z0 + 1), Vector3.new(entranceX - 7, 0, z0 + 1))
	hedge(lot, Vector3.new(entranceX + 7, 0, z0 + 1), Vector3.new(x1 - 2, 0, z0 + 1))
	-- driveway across the sidewalk, a pay station, a parking sign on a pole
	p(lot, "Driveway", Vector3.new(12, 0.62, 5), CFrame.new(entranceX, 0.07, z0 - 2.5), hex("#34353A"), M.Asphalt, true)
	local pay = CFrame.new(entranceX + 8, 0.05, z0 + 3)
	p(lot, "PayStation", Vector3.new(1.4, 4, 1), pay * CFrame.new(0, 2, 0), hex("#3C5A48"), M.Metal, true)
	p(lot, "PayScreen", Vector3.new(1, 0.7, 0.06), pay * CFrame.new(0, 3.2, -0.52), hex("#0E1114"), M.Glass)
	p(lot, "PayHood", Vector3.new(1.6, 0.2, 1.4), pay * CFrame.new(0, 4.1, -0.1), hex("#2B2B2B"), M.Metal)
	p(lot, "PaySlot", Vector3.new(0.6, 0.08, 0.06), pay * CFrame.new(0, 2.5, -0.52), hex("#C9CCD2"), M.Metal)
	cyl(lot, "SignPole", 8, 0.3, CFrame.new(entranceX - 8, 4.05, z0 + 1) * up, C.Iron, M.Metal, true)
	local signCF = look(Vector3.new(entranceX - 8, 7.4, z0 + 0.8), Vector3.new(entranceX - 8, 7.4, 0))
	p(lot, "SignFrame", Vector3.new(2.6, 2.6, 0.2), signCF * CFrame.new(0, 0, 0.12), C.White, M.Metal)
	local _, label = Kit.sign(lot, "ParkingSign", Vector3.new(2.3, 2.3, 0.1), signCF, "P", C.White, hex("#2E6E8E"), 60)
	label.FontFace = Theme.Fonts.SemiBold
end

local function buildSportsCourt()
	local court = Instance.new("Folder")
	court.Name = "SportsCourt"
	court.Parent = folder
	local sc = Town.SportsCourt
	local cx, cz = (sc.MinX + sc.MaxX) / 2, (sc.MinZ + sc.MaxZ) / 2
	local w, d = sc.MaxX - sc.MinX, sc.MaxZ - sc.MinZ
	-- surround paving, then the court: green apron, blue playing area, white lines
	p(court, "Apron", Vector3.new(w + 10, 0.4, d + 8), CFrame.new(cx, 0, cz + 1), C.Paving, M.Pavement, true)
	p(court, "CourtBase", Vector3.new(w, 0.42, d), CFrame.new(cx, 0.01, cz), hex("#3E7D5A"), M.SmoothPlastic, true)
	local pw, pd = 26, d - 8
	p(court, "CourtPlay", Vector3.new(pw, 0.02, pd), CFrame.new(cx, 0.225, cz), hex("#2E6E8E"), M.SmoothPlastic)
	local function line(size, cf) p(court, "Line", size, cf, C.White, M.SmoothPlastic) end
	for _, s in ipairs({ -1, 1 }) do
		line(Vector3.new(pw, 0.03, 0.3), CFrame.new(cx, 0.23, cz + s * pd / 2))
		line(Vector3.new(0.3, 0.03, pd), CFrame.new(cx + s * pw / 2, 0.23, cz))
		-- key (painted box) under each hoop
		p(court, "Key", Vector3.new(8, 0.025, 9), CFrame.new(cx, 0.232, cz + s * (pd / 2 - 4.5)), hex("#D7262E"), M.SmoothPlastic)
		cyl(court, "FreeThrow", 0.03, 8, CFrame.new(cx, 0.234, cz + s * (pd / 2 - 9)) * up, C.White, M.SmoothPlastic)
		cyl(court, "FreeThrowIn", 0.035, 7.4, CFrame.new(cx, 0.235, cz + s * (pd / 2 - 9)) * up, hex("#2E6E8E"), M.SmoothPlastic)
		TownKit.hoop(court, look(Vector3.new(cx, 0.2, cz + s * (pd / 2 + 1.2)), Vector3.new(cx, 0.2, cz)))
	end
	line(Vector3.new(pw, 0.03, 0.3), CFrame.new(cx, 0.23, cz))
	cyl(court, "CenterCircle", 0.03, 8, CFrame.new(cx, 0.234, cz) * up, C.White, M.SmoothPlastic)
	cyl(court, "CenterIn", 0.035, 7.4, CFrame.new(cx, 0.235, cz) * up, hex("#2E6E8E"), M.SmoothPlastic)
	ball(court, "Basketball", Vector3.new(1, 1, 1), CFrame.new(cx + 6, 0.73, cz - 3), hex("#E8761C"), M.SmoothPlastic)
	-- see-through fence with a gate facing the side street
	local function fence(a, b)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0)
		p(court, "FenceMesh", Vector3.new(len, 7, 0.08), cf * CFrame.new(0, 3.7, 0), hex("#8A8E94"), M.DiamondPlate, true, { Transparency = 0.7 })
		p(court, "FenceRail", Vector3.new(len, 0.15, 0.15), cf * CFrame.new(0, 7.2, 0), hex("#2E6E8E"), M.Metal)
		for t = 0, len, 4 do p(court, "FencePost", Vector3.new(0.2, 7.4, 0.2), cf * CFrame.new(-len / 2 + t, 3.7, 0), hex("#2E6E8E"), M.Metal, true) end
	end
	local fx0, fx1, fz0, fz1 = sc.MinX - 1, sc.MaxX + 1, sc.MinZ - 1, sc.MaxZ + 1
	fence(Vector3.new(fx0, 0.2, fz0), Vector3.new(cx - 3, 0.2, fz0))
	fence(Vector3.new(cx + 3, 0.2, fz0), Vector3.new(fx1, 0.2, fz0))
	fence(Vector3.new(fx0, 0.2, fz1), Vector3.new(fx1, 0.2, fz1))
	fence(Vector3.new(fx0, 0.2, fz0), Vector3.new(fx0, 0.2, fz1))
	fence(Vector3.new(fx1, 0.2, fz0), Vector3.new(fx1, 0.2, fz1))
	-- bleachers on the west side (3 tiers of planks on a steel frame), a ball rack, a water fountain, a scoreboard
	local bl = CFrame.new(sc.MinX + 5, 0.2, cz) * CFrame.Angles(0, rad(90), 0)
	for tier = 0, 2 do
		p(court, "BleacherSeat", Vector3.new(16, 0.3, 1.2), bl * CFrame.new(0, 1 + tier * 1.1, -tier * 1.3), C.Wood, M.WoodPlanks, true)
		p(court, "BleacherStep", Vector3.new(16, 0.2, 1.0), bl * CFrame.new(0, 0.5 + tier * 1.1, -tier * 1.3 + 0.9), hex("#9EA2A8"), M.Metal)
	end
	for _, x in ipairs({ -7.5, 0, 7.5 }) do
		p(court, "BleacherFrame", Vector3.new(0.3, 3.4, 0.3), bl * CFrame.new(x, 1.7, -2.6), hex("#9EA2A8"), M.Metal, true)
		p(court, "BleacherBrace", Vector3.new(0.25, 0.25, 4), bl * CFrame.new(x, 0.4, -1.3), hex("#9EA2A8"), M.Metal)
	end
	local rack = CFrame.new(sc.MaxX - 3, 0.2, sc.MinZ + 4)
	for _, z in ipairs({ -1, 1 }) do p(court, "RackRail", Vector3.new(3, 0.12, 0.12), rack * CFrame.new(0, 1.2, z * 0.5), C.Iron, M.Metal) end
	for _, x in ipairs({ -1.4, 1.4 }) do p(court, "RackLeg", Vector3.new(0.12, 1.2, 1.2), rack * CFrame.new(x, 0.6, 0), C.Iron, M.Metal, true) end
	for i = 0, 2 do ball(court, "Ball", Vector3.new(0.9, 0.9, 0.9), rack * CFrame.new(-1 + i, 1.65, 0), hex("#E8761C"), M.SmoothPlastic) end
	GymKit.waterFountain(court, CFrame.new(sc.MaxX - 2.5, 0.2, cz + 10) * CFrame.Angles(0, rad(-90), 0))
	local board = look(Vector3.new(cx, 0.2, sc.MaxZ - 0.5), Vector3.new(cx, 0.2, cz))
	for _, x in ipairs({ -3.6, 3.6 }) do p(court, "BoardLeg", Vector3.new(0.3, 9, 0.3), board * CFrame.new(x, 4.5, 0.3), C.Iron, M.Metal, true) end
	p(court, "BoardBack", Vector3.new(8.4, 3.4, 0.4), board * CFrame.new(0, 8.6, 0.2), hex("#1E1E22"), M.Metal)
	local _, score = Kit.sign(court, "Scoreboard", Vector3.new(7.8, 2.8, 0.1), board * CFrame.new(0, 8.6, -0.05), "Home  0 : 0  Guest", hex("#F2C14E"), hex("#141416"), 40)
	score.FontFace = Theme.Fonts.SemiBold
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
	-- the back faces the side street: windows, a service door with a canopy, a lamp, crates and bins
	local back = cf * CFrame.new(0, 0, d) * CFrame.Angles(0, math.pi, 0)
	TownKit.plainFacade(m, back, w - 2, 1, { trim = hex("#F7F2E8") }, true)
	p(m, "BackBand", Vector3.new(w, 0.5, 0.3), back * CFrame.new(0, 8.4, -0.15), hex("#F7F2E8"), M.Concrete)
	TownKit.crates(m, back * CFrame.new(-w / 2 + 3, 0, -1.6))
	TownKit.bin(m, back * CFrame.new(-w / 2 + 6.5, 0, -1))
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

-- Quarter pipe: riders come from local -Z; the curve starts flat at the pivot and rises toward +Z (radius R, up to 80
-- degrees), then a deck with metal coping. Built from slices. Each side is a solid cheek whose top edge follows the
-- curve exactly (per slice a block up to the slice's low end and a wedge from there to its high end), so the side
-- reads as one smooth curved wall (the old side walls were stacked boxes that looked like stairs).
local CHEEK = hex("#A6A29A")
local function quarterPipe(m, cf, width, radius)
	local slices = 10
	local maxAngle = rad(80)
	local cheekX = width / 2 + 0.2 -- flush against the transition's sides
	for i = 0, slices - 1 do
		local a0, a1 = (i / slices) * maxAngle, ((i + 1) / slices) * maxAngle
		local z0, y0 = radius * math.sin(a0), radius - radius * math.cos(a0)
		local z1, y1 = radius * math.sin(a1), radius - radius * math.cos(a1)
		local len = math.sqrt((z1 - z0) ^ 2 + (y1 - y0) ^ 2)
		local am = (a0 + a1) / 2
		p(m, "Transition", Vector3.new(width, 0.5, len + 0.15), cf * CFrame.new(0, (y0 + y1) / 2, (z0 + z1) / 2) * CFrame.Angles(-am, 0, 0) * CFrame.new(0, -0.25, 0), CONCRETE, M.Concrete, true)
		for _, side in ipairs({ -1, 1 }) do
			if y0 > 0.01 then p(m, "Cheek", Vector3.new(0.4, y0, z1 - z0), cf * CFrame.new(side * cheekX, y0 / 2, (z0 + z1) / 2), CHEEK, M.Concrete, true) end
			local w = Kit.wedge(m, "Cheek", Vector3.new(0.4, y1 - y0, z1 - z0), cf * CFrame.new(side * cheekX, y0 + (y1 - y0) / 2, (z0 + z1) / 2), CHEEK, M.Concrete)
			w.CastShadow = true
		end
	end
	local topY, topZ = radius - radius * math.cos(maxAngle), radius * math.sin(maxAngle)
	-- deck on a solid block (as wide as the cheeks, so the sides are one flat wall), coping on the lip, a rail at the back
	p(m, "DeckBlock", Vector3.new(width + 0.8, topY, 3.6), cf * CFrame.new(0, topY / 2, topZ + 1.8), CHEEK, M.Concrete, true)
	p(m, "Deck", Vector3.new(width + 0.8, 0.4, 3.6), cf * CFrame.new(0, topY + 0.2, topZ + 1.8), CONCRETE, M.Concrete, true)
	cyl(m, "Coping", width, 0.35, cf * CFrame.new(0, topY + 0.25, topZ + 0.1), COPING, M.Metal)
	p(m, "DeckRail", Vector3.new(width, 0.12, 0.12), cf * CFrame.new(0, topY + 3, topZ + 3.5), C.Iron, M.Metal)
	for x = -width / 2 + 0.3, width / 2 - 0.3, 3 do p(m, "DeckPost", Vector3.new(0.15, 2.8, 0.15), cf * CFrame.new(x, topY + 1.6, topZ + 3.5), C.Iron, M.Metal, true) end
end

-- A grind rail from a to b (floor points) at `height`. The round bar is tagged "GrindRail": SkateClient lets a board ride
-- along it (the bar's axis is its local X, its length Size.X).
local function grindRail(m, a, b, height)
	local mid = (a + b) / 2
	local bar = cyl(m, "Rail", (b - a).Magnitude, 0.3, CFrame.lookAt(mid + Vector3.new(0, height, 0), b + Vector3.new(0, height, 0)) * CFrame.Angles(0, rad(90), 0), COPING, M.Metal, true)
	CollectionService:AddTag(bar, "GrindRail")
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
	label.FontFace = Theme.Fonts.Bold -- (Oswald: the game never uses Montserrat)
	label.TextScaled = true
	label.Rotation = -6
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = hex("#1E1E22"), 4
	stroke.Parent = label
	return wallPart
end

-- painted floor disc in a bumper color with a thin white ring and hub (slightly different heights: nothing flickers)
local function paintedDisc(m, cf, diameter, color)
	cyl(m, "PaintRing", 0.05, diameter + 0.5, cf * CFrame.new(0, 0.325, 0) * up, C.White, M.SmoothPlastic)
	cyl(m, "Paint", 0.05, diameter, cf * CFrame.new(0, 0.36, 0) * up, color, M.SmoothPlastic)
	cyl(m, "PaintHub", 0.05, diameter * 0.28, cf * CFrame.new(0, 0.395, 0) * up, C.White, M.SmoothPlastic)
end

-- a kicker: a wedge rising toward local +Z (ride in from -Z, launch off the +Z edge) with a metal lip and a back panel
local function kicker(m, cf, width, length, height)
	local w = Kit.wedge(m, "Kicker", Vector3.new(width, height, length), cf * CFrame.new(0, 0.3 + height / 2, 0), CONCRETE, M.Concrete)
	w.CastShadow = true
	p(m, "KickerLip", Vector3.new(width + 0.08, 0.12, 0.3), cf * CFrame.new(0, 0.3 + height - 0.04, length / 2 - 0.15), COPING, M.Metal)
	p(m, "KickerBack", Vector3.new(width, height, 0.25), cf * CFrame.new(0, 0.3 + height / 2, length / 2 + 0.125), CHEEK, M.Concrete, true)
end

-- a ledge along local X: concrete block with a steel edge on its -Z side and a painted stripe on both faces
local function ledge(m, cf, length, stripe)
	p(m, "Ledge", Vector3.new(length, 1.4, 2), cf * CFrame.new(0, 1, 0), hex("#C9C4BA"), M.Concrete, true)
	p(m, "LedgeEdge", Vector3.new(length, 0.15, 0.2), cf * CFrame.new(0, 1.72, -1), COPING, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		p(m, "LedgeStripe", Vector3.new(length - 0.4, 0.28, 0.04), cf * CFrame.new(0, 0.85, s * 1.02), stripe, M.SmoothPlastic)
	end
end

-- The skate park (Config.Town.SkatePark, 84 x 64 since 8 Oct). Local layout around the centre: x -42..42, z -32..32;
-- the main gate is in the middle of the -Z side (Beach Road), a side gate in the middle of the +X side (beach gym).
-- West: a big quarter pipe. Back: a half pipe. Front east: a quarter pipe. Middle: a fun box with a rail on top, two
-- ledges, a kicker, a manual pad, painted discs. Grindable ("GrindRail"): a long rail, a low beginner rail, the fun box
-- rail and a flat bar.
local function buildSkatePark()
	local spec = Town.SkatePark
	local c, s = spec.Center, spec.Size
	local m = model(folder, "SkatePark", CFrame.new(c))
	local base = CFrame.new(c.X, 0, c.Z)
	local function at(x, z) return base * CFrame.new(x, 0, z) end
	local function ground(x, z) return (base * CFrame.new(x, 0.3, z)).Position end
	p(m, "Slab", Vector3.new(s.X, 0.5, s.Z), base * CFrame.new(0, 0.05, 0), CONCRETE, M.Concrete, true)
	for x = -s.X / 2 + 6, s.X / 2 - 1, 6 do p(m, "SlabJoint", Vector3.new(0.08, 0.02, s.Z), base * CFrame.new(x, 0.31, 0), hex("#9A968E")) end
	-- quarter pipes (each rises toward its fence) and the half pipe at the back (two facing quarter pipes)
	quarterPipe(m, base * CFrame.new(-32, 0.3, 0) * CFrame.Angles(0, rad(-90), 0), 18, 5.5)
	quarterPipe(m, base * CFrame.new(33, 0.3, -18) * CFrame.Angles(0, rad(90), 0), 12, 4.5)
	local hp = base * CFrame.new(8, 0.3, 22)
	quarterPipe(m, hp * CFrame.new(-5, 0, 0) * CFrame.Angles(0, rad(-90), 0), 12, 5.5)
	quarterPipe(m, hp * CFrame.new(5, 0, 0) * CFrame.Angles(0, rad(90), 0), 12, 5.5)
	-- fun box: flat top with ramps on two sides (wedges rise toward the box) and a rail across it
	local fb = base * CFrame.new(-6, 0.3, -8)
	p(m, "FunBoxTop", Vector3.new(8, 1.6, 6), fb * CFrame.new(0, 0.8, 0), CONCRETE, M.Concrete, true)
	Kit.wedge(m, "FunBoxRamp", Vector3.new(6, 1.6, 4), fb * CFrame.new(-6, 0.8, 0) * CFrame.Angles(0, rad(90), 0), CONCRETE, M.Concrete)
	Kit.wedge(m, "FunBoxRamp", Vector3.new(6, 1.6, 4), fb * CFrame.new(6, 0.8, 0) * CFrame.Angles(0, rad(-90), 0), CONCRETE, M.Concrete)
	for _, z in ipairs({ -3, 3 }) do p(m, "FunBoxEdge", Vector3.new(8, 0.15, 0.15), fb * CFrame.new(0, 1.62, z), COPING, M.Metal) end
	grindRail(m, (fb * CFrame.new(-3, 0, 0)).Position + Vector3.new(0, 1.6, 0), (fb * CFrame.new(3, 0, 0)).Position + Vector3.new(0, 1.6, 0), 1)
	-- rails: a long one (20 studs) and a low beginner rail
	grindRail(m, ground(-28, 12), ground(-8, 12), 1.6)
	grindRail(m, ground(6, -24), ground(22, -24), 1)
	-- flat bar along z (two posts, a long round bar, end caps)
	local bar = at(30, 12)
	for _, z in ipairs({ -3.5, 3.5 }) do
		p(m, "BarPost", Vector3.new(0.25, 1.1, 0.25), bar * CFrame.new(0, 0.85, z), C.Iron, M.Metal, true)
		p(m, "BarFoot", Vector3.new(0.7, 0.1, 0.7), bar * CFrame.new(0, 0.35, z), C.Iron, M.Metal)
	end
	CollectionService:AddTag(cyl(m, "FlatBar", 8.6, 0.28, bar * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, rad(90), 0), COPING, M.Metal, true), "GrindRail")
	for _, z in ipairs({ -4.3, 4.3 }) do cyl(m, "BarCap", 0.12, 0.34, bar * CFrame.new(0, 1.5, z) * CFrame.Angles(0, rad(90), 0), C.Iron, M.Metal) end
	-- ledges, a kicker toward the east quarter pipe, a manual pad (low, long, coping on both long edges)
	ledge(m, at(18, 6), 10, hex("#E86A6A"))
	ledge(m, at(-14, 2), 10, hex("#7CC6A5"))
	kicker(m, at(12, -10) * CFrame.Angles(0, rad(90), 0), 3.2, 3.6, 1.2)
	local pad = at(-30, -22) * CFrame.Angles(0, rad(90), 0)
	p(m, "ManualPad", Vector3.new(9, 0.9, 3.2), pad * CFrame.new(0, 0.75, 0), CONCRETE, M.Concrete, true)
	for _, side in ipairs({ -1, 1 }) do p(m, "PadCoping", Vector3.new(9.08, 0.14, 0.18), pad * CFrame.new(0, 1.22, side * 1.55), COPING, M.Metal) end
	p(m, "PadStripe", Vector3.new(9.02, 0.2, 3.22), pad * CFrame.new(0, 0.5, 0), hex("#2E6E8E"), M.Concrete)
	-- painted floor discs in the open spots
	paintedDisc(m, at(-22, -12), 7, hex("#7CC6A5"))
	paintedDisc(m, at(0, 6), 7, hex("#F2C14E"))
	paintedDisc(m, at(24, -6), 6, hex("#E86A6A"))
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
	graffiti(m, look(Vector3.new(c.X - 24, 0.3, z1 - 1.5), Vector3.new(c.X - 24, 0.3, z0)), 16, 6, "RIDE ON", artColors)
	graffiti(m, look(Vector3.new(x0 + 1.5, 0.3, c.Z + 22), Vector3.new(x1, 0.3, c.Z + 22)), 12, 5, "GYM ARC", { artColors[4], artColors[2], artColors[1] })
	for _, x in ipairs({ -16, 16 }) do TownKit.bench(m, look(Vector3.new(c.X + x, 0.3, z0 + 2), Vector3.new(c.X + x, 0.3, c.Z))) end
	for _, corner in ipairs({ { x0 + 1, z0 + 1 }, { x1 - 1, z0 + 1 }, { x0 + 1, z1 - 1 }, { x1 - 1, z1 - 1 } }) do
		cyl(m, "FloodPole", 12, 0.4, CFrame.new(corner[1], 6.3, corner[2]) * up, C.Iron, M.Metal, true)
		local head = p(m, "Floodlight", Vector3.new(1.6, 0.6, 1), CFrame.lookAt(Vector3.new(corner[1], 12.4, corner[2]), c + Vector3.new(0, 0, 0)), hex("#2B2B2B"), M.Metal)
		local lens = p(m, "FloodLens", Vector3.new(1.3, 0.4, 0.1), head.CFrame * CFrame.new(0, 0, -0.52), hex("#FFF2DD"), M.Glass)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Color, light.Brightness, light.Range, light.Angle, light.Shadows = hex("#FFF2DD"), 1.6, 56, 75, false
		light.Parent = lens
		TownKit.nightLight(lens, hex("#FFF2DD"))
	end
	return m
end

------------------------------------------------------------------------
-- Beach, beach gym, posing stage
------------------------------------------------------------------------
-- A wooden boardwalk from a to b on the sand (planks across, rope posts along both edges).
local function boardwalk(parent, a, b, width)
	width = width or 6
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z))
	for t = 0.55, len - 0.5, 1.2 do
		p(parent, "Plank", Vector3.new(width, 0.25, 1.1), cf * CFrame.new(0, 0.3, -t), C.Wood, M.WoodPlanks, true)
	end
	for _, side in ipairs({ -1, 1 }) do
		p(parent, "Stringer", Vector3.new(0.3, 0.3, len), cf * CFrame.new(side * (width / 2 - 0.4), 0.1, -len / 2), C.WoodDark, M.Wood)
		if len > 12 then
			for t = 2, len - 2, 5 do p(parent, "RopePost", Vector3.new(0.35, 2, 0.35), cf * CFrame.new(side * (width / 2 + 0.2), 1, -t), C.WoodDark, M.Wood, true) end
			p(parent, "Rope", Vector3.new(0.12, 0.12, len - 4), cf * CFrame.new(side * (width / 2 + 0.2), 1.7, -len / 2), hex("#C9B48A"), M.Fabric)
		end
	end
end

local function lifeguardTower(parent, cf)
	for _, o in ipairs({ { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } }) do
		p(parent, "Stilt", Vector3.new(0.4, 6, 0.4), cf * CFrame.new(o[1], 3, o[2]) * CFrame.Angles(rad(o[2] * 2), 0, rad(-o[1] * 2)), C.White, M.Wood, true)
	end
	p(parent, "TowerDeck", Vector3.new(5, 0.4, 5), cf * CFrame.new(0, 6.2, 0), C.WoodDark, M.WoodPlanks, true)
	p(parent, "Cabin", Vector3.new(3.6, 3.2, 3), cf * CFrame.new(0, 8, 0.6), hex("#E86A6A"), M.Wood, true)
	p(parent, "CabinWindow", Vector3.new(2.8, 1.2, 0.1), cf * CFrame.new(0, 8.6, -0.92), hex("#A8C0CC"), M.Glass)
	Kit.wedge(parent, "CabinRoof", Vector3.new(4.2, 1.2, 2), cf * CFrame.new(0, 10.2, -0.3) * CFrame.Angles(0, math.pi, 0), C.White, M.Wood)
	Kit.wedge(parent, "CabinRoof", Vector3.new(4.2, 1.2, 2), cf * CFrame.new(0, 10.2, 1.7), C.White, M.Wood)
	for x = -2.3, 2.3, 0.8 do p(parent, "DeckRail", Vector3.new(0.1, 1.2, 0.1), cf * CFrame.new(x, 7, -2.4), C.White, M.Wood) end
	p(parent, "DeckRailTop", Vector3.new(5, 0.12, 0.12), cf * CFrame.new(0, 7.6, -2.4), C.White, M.Wood)
	for i = 0, 6 do p(parent, "LadderRung", Vector3.new(1.2, 0.12, 0.12), cf * CFrame.new(0, 0.6 + i * 0.85, 3.4 - i * 0.3), C.White, M.Wood) end
	cyl(parent, "FlagPole", 5, 0.12, cf * CFrame.new(2.2, 9.5, 2.2) * up, C.White, M.Metal)
	p(parent, "Flag", Vector3.new(1.8, 1.1, 0.05), cf * CFrame.new(3.1, 11.4, 2.2), hex("#E86A6A"), M.Fabric)
end

local function beachShower(parent, cf)
	p(parent, "ShowerBase", Vector3.new(3, 0.3, 3), cf * CFrame.new(0, 0.15, 0), C.Wood, M.WoodPlanks, true)
	cyl(parent, "ShowerPole", 7, 0.3, cf * CFrame.new(0, 3.8, 0) * up, hex("#C9CCD2"), M.Metal, true)
	p(parent, "ShowerArm", Vector3.new(0.15, 0.15, 1.4), cf * CFrame.new(0, 7.1, -0.7), hex("#C9CCD2"), M.Metal)
	cyl(parent, "ShowerHead", 0.2, 0.7, cf * CFrame.new(0, 6.95, -1.3) * up, hex("#C9CCD2"), M.Metal)
	p(parent, "ShowerTap", Vector3.new(0.3, 0.2, 0.3), cf * CFrame.new(0, 3.2, -0.25), hex("#2E6E8E"), M.Metal)
end

-- beach palms { x, z, scale }; four moved out of the bigger skate park on 8 Oct (PALM_MOVES: old spot -> new spot)
local PALMS = {
	{ -168, 178, 1.1 }, { -171, 200, 0.95 }, { -170, 222, 1.2 }, { -73, 177, 1.15 }, { -72, 194, 0.9 }, { -48, 186, 1.05 },
	{ -64, 226, 1.2 }, { -44, 244, 0.95 }, { 74, 178, 1.1 }, { 82, 196, 1.0 }, { 96, 232, 1.15 }, { 128, 180, 1.05 },
	{ 136, 214, 0.95 }, { 190, 182, 1.2 }, { 196, 206, 1.0 }, { 178, 236, 1.1 }, { -116, 248, 1.0 }, { -150, 246, 1.15 },
}
local PALM_MOVES = {
	{ Vector3.new(-162, 0, 196), Vector3.new(-171, 0, 200) }, { Vector3.new(-86, 0, 178), Vector3.new(-73, 0, 177) },
	{ Vector3.new(-80, 0, 192), Vector3.new(-72, 0, 194) }, { Vector3.new(-120, 0, 240), Vector3.new(-116, 0, 248) },
}

local function buildBeach()
	local beach = Instance.new("Folder")
	beach.Name = "Beach"
	beach.Parent = folder
	-- boardwalks connect Beach Road, the skate park, the beach gym and the posing stage
	for _, bw in ipairs(Town.Boardwalks) do boardwalk(beach, bw[1], bw[2], 6) end
	-- palms in groups (never in a grid), different heights (none inside the skate park's footprint)
	for i, palm in ipairs(PALMS) do TownKit.palm(beach, Vector3.new(palm[1], 0, palm[2]), palm[3], i) end
	-- umbrellas with towels and beach chairs, in two relaxed groups near the water
	local umbrellaColors = { { hex("#E86A6A"), hex("#F7F2E8") }, { hex("#6FA8DC"), hex("#F7F2E8") }, { hex("#F2C14E"), hex("#F7F2E8") }, { hex("#7CC6A5"), hex("#F7F2E8") } }
	for i, spot in ipairs({ { 132, 242 }, { 146, 248 }, { 160, 240 }, { 176, 250 }, { -82, 246 }, { -66, 252 }, { 78, 250 }, { -172, 244 } }) do
		local cf = CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, rad(i * 17), 0)
		local colors = umbrellaColors[(i - 1) % 4 + 1]
		TownKit.umbrella(beach, cf, colors[1], colors[2])
		TownKit.towel(beach, cf * CFrame.new(-2.2, 0, 1) * CFrame.Angles(0, rad(10 * i), 0), colors[1], hex("#F7F2E8"))
		TownKit.beachChair(beach, cf * CFrame.new(2.4, 0, 0.5) * CFrame.Angles(0, rad(180 + 8 * i), 0), umbrellaColors[(i % 4) + 1][1])
	end
	lifeguardTower(beach, CFrame.new(154, 0, 230) * CFrame.Angles(0, math.pi, 0))
	lifeguardTower(beach, CFrame.new(-74, 0, 236) * CFrame.Angles(0, math.pi + rad(10), 0))
	-- volleyball: posts, a see-through net with a top band, a ball and court lines
	local vb = CFrame.new(166, 0, 200)
	for _, x in ipairs({ -8, 8 }) do cyl(beach, "NetPost", 7, 0.3, vb * CFrame.new(x, 3.5, 0) * up, C.White, M.Metal, true) end
	p(beach, "Net", Vector3.new(16, 2.6, 0.06), vb * CFrame.new(0, 4.6, 0), C.White, M.Fabric, false, { Transparency = 0.6 })
	p(beach, "NetBand", Vector3.new(16, 0.25, 0.08), vb * CFrame.new(0, 5.95, 0), C.White, M.Fabric)
	ball(beach, "Volleyball", Vector3.new(0.9, 0.9, 0.9), vb * CFrame.new(3, 0.45, -4), hex("#F2C14E"), M.SmoothPlastic)
	for _, z in ipairs({ -10, 10 }) do p(beach, "CourtLine", Vector3.new(16, 0.03, 0.15), vb * CFrame.new(0, 0.05, z), C.White, M.SmoothPlastic) end
	for _, x in ipairs({ -8, 8 }) do p(beach, "CourtLine", Vector3.new(0.15, 0.03, 20), vb * CFrame.new(x, 0.05, 0), C.White, M.SmoothPlastic) end
	for _, x in ipairs({ -4, 4 }) do TownKit.bench(beach, look(Vector3.new(166 + x, 0, 186), Vector3.new(166 + x, 0, 200))) end
	-- surfboards in a rack and stuck in the sand, beach showers by the road
	local rack = CFrame.new(186, 0, 226) * CFrame.Angles(0, rad(-20), 0)
	for _, x in ipairs({ -2, 2 }) do p(beach, "RackPost", Vector3.new(0.3, 3.2, 0.3), rack * CFrame.new(x, 1.6, 0), C.WoodDark, M.Wood, true) end
	p(beach, "RackBar", Vector3.new(4.6, 0.25, 0.25), rack * CFrame.new(0, 3.1, 0), C.WoodDark, M.Wood)
	local boardColors = { hex("#6FA8DC"), hex("#F2C14E"), hex("#E86A6A") }
	for i = 0, 2 do TownKit.surfboard(beach, rack * CFrame.new(-1.4 + i * 1.4, 0, 0.5) * CFrame.Angles(rad(-12), 0, 0), boardColors[i + 1]) end
	TownKit.surfboard(beach, CFrame.new(-58, -0.8, 240) * CFrame.Angles(rad(6), rad(30), rad(-8)), hex("#7CC6A5"))
	TownKit.surfboard(beach, CFrame.new(140, -0.8, 232) * CFrame.Angles(rad(-5), rad(-20), rad(7)), hex("#E86A6A"))
	beachShower(beach, CFrame.new(-30, 0, 170))
	beachShower(beach, CFrame.new(140, 0, 170))
	-- rocks and shoreline detail (driftwood, shells, a sand castle)
	for i, r in ipairs({ { 192, 256, 1.4 }, { 197, 252, 1 }, { -166, 256, 1.2 }, { -160, 259, 0.8 }, { 60, 258, 0.9 }, { -100, 257, 1.1 } }) do
		TownKit.rock(beach, Vector3.new(r[1], -0.4, r[2]), r[3], i)
	end
	cyl(beach, "Driftwood", 4.5, 0.5, CFrame.new(110, 0.1, 252) * CFrame.Angles(0, rad(25), 0), hex("#B9A587"), M.Wood)
	cyl(beach, "Driftwood", 3.2, 0.4, CFrame.new(-136, 0.1, 250) * CFrame.Angles(0, rad(-40), 0), hex("#B9A587"), M.Wood)
	for i = 0, 13 do ball(beach, "Shell", Vector3.new(0.35, 0.2, 0.35), CFrame.new(-150 + i * 25, 0.05, 254 + (i % 3)), hex("#F2E4D6"), M.SmoothPlastic) end
	local castle = CFrame.new(88, 0, 246)
	p(beach, "SandCastle", Vector3.new(2.4, 1.2, 2.4), castle * CFrame.new(0, 0.6, 0), C.Sand, M.Sand)
	for _, o in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do cyl(beach, "Turret", 1.8, 0.7, castle * CFrame.new(o[1], 0.9, o[2]) * up, C.Sand, M.Sand) end
	p(beach, "Bucket", Vector3.new(0.8, 0.9, 0.8), castle * CFrame.new(2.4, 0.45, 1), hex("#E86A6A"), M.Plastic)
end

------------------------------------------------------------------------
-- Beach gym: an open-air gym spread over the sand in four zones around two crossing walkways
--   south-west: shaded machines (two slatted pergolas)      south-east: free weights on rubber mats
--   north-west: shade sails over machines + tires/ropes/sled  north-east: calisthenics
-- Shade roofs sit 15+ studs up and don't collide, so they never push the camera in.
------------------------------------------------------------------------
local BAMBOO, BAMBOO_DARK, LASHING = hex("#C9B27A"), hex("#9C8656"), hex("#7A6440")

local function bambooPost(m, base, height)
	cyl(m, "Post", height, 0.7, base * CFrame.new(0, height / 2, 0) * up, BAMBOO, M.Wood, true)
	for y = 2.5, height - 1, 2.8 do cyl(m, "Node", 0.2, 0.8, base * CFrame.new(0, y, 0) * up, BAMBOO_DARK, M.Wood) end
	cyl(m, "Lashing", 0.6, 0.82, base * CFrame.new(0, height - 0.6, 0) * up, LASHING, M.Fabric)
	p(m, "Footing", Vector3.new(1.4, 0.5, 1.4), base * CFrame.new(0, 0.1, 0), hex("#B5AA98"), M.Concrete, true)
end

-- Slatted pergola, w (x) by d (z), roof at `height`
local function pergola(m, center, w, d, height)
	for _, dx in ipairs({ -w / 2, w / 2 }) do
		for _, dz in ipairs({ -d / 2, d / 2 }) do bambooPost(m, center * CFrame.new(dx, 0, dz), height) end
	end
	for _, dz in ipairs({ -d / 2, d / 2 }) do cyl(m, "Beam", w + 1.4, 0.6, center * CFrame.new(0, height + 0.1, dz), BAMBOO, M.Wood) end
	for x = -w / 2 + 0.6, w / 2 - 0.5, 1.5 do
		cyl(m, "RoofSlat", d + 1.6, 0.35, center * CFrame.new(x, height + 0.55, 0) * CFrame.Angles(0, rad(90), 0), (math.floor(x) % 2 == 0) and BAMBOO or BAMBOO_DARK, M.Wood)
	end
	-- a light canvas strip over every other gap for shade, and lanterns hanging from the beams
	for x = -w / 2 + 1.35, w / 2 - 1, 3 do
		p(m, "Canvas", Vector3.new(1.2, 0.05, d), center * CFrame.new(x, height + 0.78, 0), hex("#F2EADB"), M.Fabric)
	end
end

-- Two triangular shade sails between four tall poles (taut, slightly tilted)
local function shadeSails(m, center, w, d, height)
	local corners = {
		center * CFrame.new(-w / 2, 0, -d / 2), center * CFrame.new(w / 2, 0, -d / 2),
		center * CFrame.new(w / 2, 0, d / 2), center * CFrame.new(-w / 2, 0, d / 2),
	}
	local heights = { height + 2, height, height + 2, height }
	for i, c in ipairs(corners) do
		cyl(m, "SailPole", heights[i] + 0.5, 0.5, c * CFrame.new(0, (heights[i] + 0.5) / 2, 0) * up, hex("#E8E2D6"), M.Metal, true)
		p(m, "PoleFoot", Vector3.new(1.2, 0.5, 1.2), c * CFrame.new(0, 0.1, 0), hex("#B5AA98"), M.Concrete, true)
		ball(m, "PoleCap", Vector3.new(0.6, 0.6, 0.6), c * CFrame.new(0, heights[i] + 0.6, 0), C.White, M.Metal)
	end
	-- each sail is two wedges forming a triangle between three pole tops
	local function sail(a, b, c, color)
		-- right-angle split: triangle (a, b, c) drawn as one WedgePart pair is complex; use a thin fabric quad strip fan
		for t = 0, 0.9, 0.1 do
			local p0 = a:Lerp(b, t)
			local p1 = a:Lerp(c, t)
			local q0 = a:Lerp(b, t + 0.1)
			local q1 = a:Lerp(c, t + 0.1)
			local mid = (p0 + p1 + q0 + q1) / 4
			local along = (q0 + q1) / 2 - (p0 + p1) / 2
			local across = ((q0 - q1) + (p0 - p1)) / 2
			local normal = along:Cross(across).Unit
			local cf = CFrame.fromMatrix(mid, across.Unit, normal, along.Unit)
			p(m, "Sail", Vector3.new(across.Magnitude, 0.05, along.Magnitude + 0.05), cf, color, M.Fabric)
		end
	end
	local tops = {}
	for i, c in ipairs(corners) do tops[i] = (c * CFrame.new(0, heights[i] - 0.2, 0)).Position end
	sail(tops[2], tops[1], tops[3], hex("#F2EADB"))
	sail(tops[4], tops[3], tops[1], hex("#E59A7A"))
end

-- an area sign with a title and a lock rule (AreaSignsClient shows the rule only while the area is locked)
local function areaSign(m, cf, size, title, gym)
	local board = p(m, "AreaSign", size, cf, hex("#5E4632"), M.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(0.94, 0.9)
	titleLabel.Position = UDim2.fromScale(0.03, 0.05)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = C.White
	titleLabel.FontFace = Theme.Fonts.SemiBold
	titleLabel.TextScaled = true
	titleLabel.Parent = gui
	local rule = titleLabel:Clone()
	rule.Name = "Rule"
	rule.Text = ""
	rule.TextColor3 = hex("#E8DCC4")
	rule.FontFace = Theme.Fonts.Regular
	rule.Visible = false
	rule.Parent = gui
	board:SetAttribute("Gym", gym)
	board:SetAttribute("Title", title)
	CollectionService:AddTag(board, "AreaSign")
	return board
end

local function tire(m, cf, size)
	cyl(m, "Tire", 1.2 * size, 5 * size, cf * CFrame.new(0, 0.6 * size, 0) * up, hex("#1E1E20"), M.Rubber, true)
	cyl(m, "TireTread", 1.0 * size, 5.15 * size, cf * CFrame.new(0, 0.6 * size, 0) * up, hex("#2A2A2D"), M.Rubber)
	cyl(m, "TireHole", 1.25 * size, 2.4 * size, cf * CFrame.new(0, 0.6 * size, 0) * up, hex("#D9C79A"), M.Sand)
end

local function plyoBox(m, cf, h)
	p(m, "PlyoBox", Vector3.new(2.4, h, 2), cf * CFrame.new(0, h / 2, 0), hex("#B8875A"), M.WoodPlanks, true)
	for _, y in ipairs({ 0.06, h - 0.06 }) do p(m, "PlyoEdge", Vector3.new(2.45, 0.12, 2.05), cf * CFrame.new(0, y, 0), hex("#8A6A4A"), M.Wood) end
	p(m, "PlyoHandle", Vector3.new(0.8, 0.3, 0.05), cf * CFrame.new(0, h * 0.7, -1.01), hex("#5E4632"), M.Wood)
end

local function buildBeachGym()
	local spec = Town.BeachGym
	local center, size = spec.Center, spec.Size
	local m = model(folder, "BeachGym", CFrame.new(center))
	local x0, x1, z0, z1 = center.X - size.X / 2, center.X + size.X / 2, center.Z - size.Z / 2, center.Z + size.Z / 2
	local wx, wz = 0, center.Z -- the two walkways cross at (0, center.Z)

	-- walkways: boardwalk north-south through the entrance and east-west between the skate park and the stage
	boardwalk(m, Vector3.new(wx, 0, z0), Vector3.new(wx, 0, z1), 5)
	boardwalk(m, Vector3.new(x0, 0, wz), Vector3.new(wx - 2.5, 0, wz), 5)
	boardwalk(m, Vector3.new(wx + 2.5, 0, wz), Vector3.new(x1, 0, wz), 5)

	-- entrance arch at the south end with the area sign
	local gate = CFrame.new(wx, 0, z0 + 1)
	for _, x in ipairs({ -4, 4 }) do bambooPost(m, gate * CFrame.new(x, 0, 0), 11) end
	cyl(m, "ArchBeam", 10, 0.7, gate * CFrame.new(0, 11, 0), BAMBOO, M.Wood)
	cyl(m, "ArchBeam", 10, 0.5, gate * CFrame.new(0, 10, 0), BAMBOO_DARK, M.Wood)
	local signCF = look(Vector3.new(wx, 8.4, z0 + 0.7), Vector3.new(wx, 8.4, z0 - 30))
	p(m, "SignFrame", Vector3.new(7.6, 2.2, 0.2), signCF * CFrame.new(0, 0, 0.12), BAMBOO_DARK, M.Wood)
	for _, x in ipairs({ -2.5, 2.5 }) do p(m, "SignRope", Vector3.new(0.1, 1.3, 0.1), signCF * CFrame.new(x, 1.6, 0.1), LASHING, M.Fabric) end
	areaSign(m, signCF, Vector3.new(7.2, 1.9, 0.15), "Beach gym", "Beach")

	-- rope fence around the gym, open at the four walkway ends
	local function ropeFence(a, b)
		local len = (b - a).Magnitude
		if len < 2 then return end
		local cf = CFrame.lookAt(a, b)
		for t = 0, len, 4 do p(m, "FencePost", Vector3.new(0.4, 2.4, 0.4), cf * CFrame.new(0, 1.2, -t), C.WoodDark, M.Wood, true) end
		p(m, "FenceRope", Vector3.new(0.14, 0.14, len), cf * CFrame.new(0, 2.0, -len / 2), hex("#C9B48A"), M.Fabric)
		p(m, "FenceRope", Vector3.new(0.14, 0.14, len), cf * CFrame.new(0, 1.1, -len / 2), hex("#C9B48A"), M.Fabric)
	end
	ropeFence(Vector3.new(x0, 0, z0), Vector3.new(wx - 5, 0, z0))
	ropeFence(Vector3.new(wx + 5, 0, z0), Vector3.new(x1, 0, z0))
	ropeFence(Vector3.new(x0, 0, z1), Vector3.new(wx - 4, 0, z1))
	ropeFence(Vector3.new(wx + 4, 0, z1), Vector3.new(x1, 0, z1))
	ropeFence(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, wz - 4))
	ropeFence(Vector3.new(x0, 0, wz + 4), Vector3.new(x0, 0, z1))
	ropeFence(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, wz - 4))
	ropeFence(Vector3.new(x1, 0, wz + 4), Vector3.new(x1, 0, z1))
	-- flags at the corners
	for i, c in ipairs({ { x0 + 1, z0 + 1 }, { x1 - 1, z0 + 1 }, { x0 + 1, z1 - 1 }, { x1 - 1, z1 - 1 } }) do
		cyl(m, "FlagPole", 16, 0.25, CFrame.new(c[1], 8, c[2]) * up, C.White, M.Metal, true)
		local flag = p(m, "Flag", Vector3.new(3.6, 2.2, 0.05), CFrame.new(c[1] + 1.9, 14.8, c[2]), ({ hex("#1F5FBF"), hex("#D7262E"), hex("#E8C21C"), hex("#2E9E4F") })[i], M.Fabric)
		local fgui = Instance.new("SurfaceGui")
		fgui.Face = Enum.NormalId.Front
		fgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		fgui.PixelsPerStud = 40
		fgui.Parent = flag
		local ft = Instance.new("TextLabel")
		ft.Size = UDim2.fromScale(1, 1)
		ft.BackgroundTransparency = 1
		ft.Text = "GYM ARC"
		ft.TextColor3 = i == 3 and hex("#1E1E22") or C.White
		ft.FontFace = Theme.Fonts.SemiBold
		ft.TextScaled = true
		ft.Parent = fgui
	end

	-- the beach machines: 3 of each, one of each kind under every shade, all facing the sea
	local beachMachines = {}
	for _, machine in ipairs(Machines.List) do
		if machine.gym == "Beach" then table.insert(beachMachines, machine) end
	end
	local builders = {
		BeachCurl = GymKit.Pro.BicepCurl, BeachRaise = GymKit.Pro.LateralRaise, BeachShrug = GymKit.Pro.Shrugs,
	}
	local function machineRow(rowCenter)
		for index, machine in ipairs(beachMachines) do
			local x = rowCenter.X + (index - 2) * 8
			local built = builders[machine.id] and builders[machine.id](m, CFrame.new(x, 0.25, rowCenter.Z))
			if built then
				built.Name = machine.id
				built:SetAttribute("MachineId", machine.id)
				local prompt = built:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then prompt.ObjectText = machine.name end
			end
		end
		-- a rubber mat under the row
		p(m, "Mat", Vector3.new(26, 0.2, 10), CFrame.new(rowCenter.X, 0.08, rowCenter.Z + 0.8), hex("#2A2A2E"), M.Rubber, true)
	end
	-- south-west: two slatted pergolas
	local swX = (x0 + wx - 2.5) / 2
	for _, z in ipairs({ z0 + 9, z0 + 23 }) do
		pergola(m, CFrame.new(swX, 0, z + 0.8), 28, 11, 15)
		machineRow(Vector3.new(swX, 0, z))
	end
	-- north-west: shade sails over the third row, then the tire / rope / sled area on open sand
	local nwRow = wz + 9
	shadeSails(m, CFrame.new(swX, 0, nwRow + 0.8), 28, 12, 15)
	machineRow(Vector3.new(swX, 0, nwRow))
	local sled = CFrame.new(swX, 0, z1 - 5)
	p(m, "SledTurf", Vector3.new(26, 0.12, 3.6), sled * CFrame.new(0, 0.06, 0), hex("#3E7D5A"), M.Grass, true)
	for x = -12, 12, 4 do p(m, "TurfLine", Vector3.new(0.15, 0.02, 3.6), sled * CFrame.new(x, 0.13, 0), C.White, M.SmoothPlastic) end
	local s = sled * CFrame.new(-9, 0.12, 0)
	p(m, "SledBase", Vector3.new(3, 0.3, 2.4), s * CFrame.new(0, 0.3, 0), hex("#2B2B2B"), M.Metal, true)
	for _, z in ipairs({ -1, 1 }) do p(m, "SledRunner", Vector3.new(3.4, 0.2, 0.25), s * CFrame.new(0, 0.1, z), hex("#9EA2A8"), M.Metal) end
	for _, x in ipairs({ -0.9, 0.9 }) do cyl(m, "SledHorn", 1.6, 0.3, s * CFrame.new(x, 1.2, 0) * up, hex("#9EA2A8"), M.Metal) end
	GymKit.plate(m, 45, s * CFrame.new(-0.9, 0.95, 0) * CFrame.Angles(0, 0, rad(90)))
	p(m, "SledStrap", Vector3.new(4, 0.08, 0.3), s * CFrame.new(3.4, 0.4, 0), hex("#1F5FBF"), M.Fabric)
	-- tires, battle ropes, plyo boxes, a sledgehammer
	tire(m, CFrame.new(-14, 0, z1 - 13), 1.1)
	tire(m, CFrame.new(-8.5, 0, z1 - 10) * CFrame.Angles(0, 0, rad(4)), 0.9)

	p(m, "HammerHandle", Vector3.new(0.2, 3.6, 0.2), CFrame.new(-5.2, 1.6, z1 - 14) * CFrame.Angles(0, 0, rad(-20)), hex("#8A6A4A"), M.Wood)
	p(m, "HammerHead", Vector3.new(0.7, 0.6, 1.2), CFrame.new(-5.8, 3.3, z1 - 14) * CFrame.Angles(0, 0, rad(-20)), hex("#2B2B2B"), M.Metal)
	for i, z in ipairs({ wz + 19, wz + 22 }) do
		local anchor = CFrame.new(x0 + 3, 0, z)
		cyl(m, "RopeAnchor", 1.4, 0.8, anchor * CFrame.new(0, 0.7, 0) * up, C.Iron, M.Metal, true)
		for k = 0, 8 do
			cyl(m, "Rope", 1.5, 0.35, anchor * CFrame.new(1.3 + k * 1.35, 0.3, math.sin(k * 1.2 + i) * 0.6) * CFrame.Angles(0, rad(math.cos(k + i) * 25), 0), hex("#C9B48A"), M.Fabric)
		end
	end
	for i, h in ipairs({ 1.6, 2.2, 2.8 }) do plyoBox(m, CFrame.new(-33 + i * 3, 0, z1 - 1.8) * CFrame.Angles(0, rad(i * 7), 0), h) end

	-- south-east: free weights on rubber mats (2 squat racks, 2 benches, dumbbells, kettlebells, plate trees)
	local se = CFrame.new((wx + 2.5 + x1) / 2, 0, (z0 + wz - 2.5) / 2)
	p(m, "FreeWeightMat", Vector3.new(56, 0.2, 26), se * CFrame.new(0, 0.08, 0), hex("#2A2A2E"), M.Rubber, true)
	for x = -24, 24, 6 do p(m, "MatJoint", Vector3.new(0.06, 0.02, 26), se * CFrame.new(x, 0.19, 0), hex("#1A1A1C")) end
	local racks, benches = {}, {}
	for i, x in ipairs({ -20, -8 }) do racks[i] = GymKit.SquatRack(m, se * CFrame.new(x, 0.2, 4)) end
	for i, x in ipairs({ 6, 16 }) do benches[i] = GymKit.FlatBench(m, se * CFrame.new(x, 0.2, 3)) end
	GymKit.dumbbellRack(m, se * CFrame.new(10, 0.2, -9.5), 12)
	GymKit.plateTree(m, se * CFrame.new(-14, 0.2, -8))
	GymKit.plateTree(m, se * CFrame.new(24, 0.2, 8))
	for i = 0, 5 do GymKit.kettlebell(m, se * CFrame.new(-4 + i * 1.3, 0.2, -10), 0.7 + (i % 3) * 0.15) end
	GymKit.bench(m, se * CFrame.new(-24, 0.2, -9), 6)
	-- north-east: calisthenics (2 pull-up bars you can use, plus dip bars, monkey bars, rings, parallettes)
	local ne = CFrame.new((wx + 2.5 + x1) / 2, 0, (wz + 2.5 + z1) / 2)
	p(m, "CaliMat", Vector3.new(56, 0.2, 26), ne * CFrame.new(0, 0.08, 0), hex("#3A2E26"), M.Rubber, true)
	GymKit.PullUpBar(m, ne * CFrame.new(-20, 0.2, -4))
	GymKit.PullUpBar(m, ne * CFrame.new(-10, 0.2, -4))
	local steel = hex("#3A3C40")
	-- dip bars
	local dip = ne * CFrame.new(1, 0.2, -5)
	for _, x in ipairs({ -1.1, 1.1 }) do
		for _, z in ipairs({ -1.6, 1.6 }) do cyl(m, "DipPost", 4, 0.3, dip * CFrame.new(x, 2, z) * up, steel, M.Metal, true) end
		cyl(m, "DipBar", 3.6, 0.25, dip * CFrame.new(x, 4, 0) * CFrame.Angles(0, rad(90), 0), C.Chrome or hex("#C9CCD2"), M.Metal)
	end
	-- monkey bars: two ladders' worth of posts and rungs across the top
	local mb = ne * CFrame.new(14, 0.2, -4)
	for _, x in ipairs({ -6, 6 }) do
		for _, z in ipairs({ -1.2, 1.2 }) do cyl(m, "MonkeyPost", 8.4, 0.35, mb * CFrame.new(x, 4.2, z) * up, steel, M.Metal, true) end
	end
	for _, z in ipairs({ -1.2, 1.2 }) do cyl(m, "MonkeyRail", 12.6, 0.3, mb * CFrame.new(0, 8.3, z), steel, M.Metal) end
	for x = -5.4, 5.4, 1.2 do cyl(m, "MonkeyRung", 2.4, 0.2, mb * CFrame.new(x, 8.3, 0) * CFrame.Angles(0, rad(90), 0), hex("#C9CCD2"), M.Metal) end
	-- gymnastic rings on a frame
	local rg = ne * CFrame.new(-4, 0.2, 7)
	for _, x in ipairs({ -3, 3 }) do
		p(m, "RingLeg", Vector3.new(0.35, 11, 0.35), rg * CFrame.new(x, 5.3, -1.6) * CFrame.Angles(rad(12), 0, 0), steel, M.Metal, true)
		p(m, "RingLeg", Vector3.new(0.35, 11, 0.35), rg * CFrame.new(x, 5.3, 1.6) * CFrame.Angles(rad(-12), 0, 0), steel, M.Metal, true)
	end
	cyl(m, "RingBeam", 6.6, 0.4, rg * CFrame.new(0, 10.6, 0), steel, M.Metal)
	for _, x in ipairs({ -0.9, 0.9 }) do
		p(m, "RingStrap", Vector3.new(0.12, 4.4, 0.05), rg * CFrame.new(x, 8.3, 0), hex("#1E1E22"), M.Fabric)
		for k = 0, 7 do
			local a0, a1 = k / 8 * math.pi * 2, (k + 1) / 8 * math.pi * 2
			local p0, p1 = Vector3.new(math.cos(a0) * 0.45, math.sin(a0) * 0.45, 0), Vector3.new(math.cos(a1) * 0.45, math.sin(a1) * 0.45, 0)
			p(m, "Ring", Vector3.new(0.14, 0.14, (p1 - p0).Magnitude + 0.04), rg * CFrame.new(x, 5.6, 0) * CFrame.lookAt((p0 + p1) / 2, p1), hex("#C9A04B"), M.Wood)
		end
	end
	-- parallettes and a low bar
	for i = 0, 1 do
		local pl = ne * CFrame.new(10 + i * 3, 0.2, 7)
		for _, z in ipairs({ -0.8, 0.8 }) do p(m, "ParaFoot", Vector3.new(0.3, 0.6, 0.3), pl * CFrame.new(0, 0.3, z), steel, M.Metal) end
		cyl(m, "ParaBar", 1.9, 0.22, pl * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, rad(90), 0), hex("#B8875A"), M.Wood)
	end
	-- wall bars (a tall ladder frame) and an incline sit-up bench
	local wb = ne * CFrame.new(-18, 0.2, 9)
	for _, x in ipairs({ -2.6, 2.6 }) do p(m, "WallBarPost", Vector3.new(0.4, 9, 0.4), wb * CFrame.new(x, 4.5, 0), hex("#B8875A"), M.Wood, true) end
	for y = 0.8, 8.4, 0.8 do cyl(m, "WallBarRung", 5.2, 0.22, wb * CFrame.new(0, y, 0), hex("#C9A04B"), M.Wood) end
	p(m, "WallBarTop", Vector3.new(5.8, 0.4, 0.5), wb * CFrame.new(0, 9.1, 0), hex("#8A6A4A"), M.Wood)
	local sit = ne * CFrame.new(-10, 0.2, 8) * CFrame.Angles(0, rad(90), 0)
	p(m, "SitUpPad", Vector3.new(1.4, 0.35, 5), sit * CFrame.new(0, 1.4, 0) * CFrame.Angles(rad(-15), 0, 0), hex("#1E1E22"), M.Leather, true)
	p(m, "SitUpFrame", Vector3.new(0.3, 0.3, 5.2), sit * CFrame.new(0, 0.9, 0) * CFrame.Angles(rad(-15), 0, 0), steel, M.Metal)
	p(m, "SitUpLeg", Vector3.new(0.3, 2.2, 0.3), sit * CFrame.new(0, 1.1, -2.2), steel, M.Metal, true)
	p(m, "SitUpLeg", Vector3.new(0.3, 0.9, 0.3), sit * CFrame.new(0, 0.45, 2.2), steel, M.Metal, true)
	cyl(m, "FootRoller", 1.4, 0.45, sit * CFrame.new(0, 2.5, -2.4), hex("#1E1E22"), M.Rubber)
	for _, x in ipairs({ 18, 24 }) do cyl(m, "LowBarPost", 4.2, 0.35, ne * CFrame.new(x, 2.3, 8) * up, steel, M.Metal, true) end
	cyl(m, "LowBar", 6.4, 0.24, ne * CFrame.new(21, 4.2, 8), hex("#C9CCD2"), M.Metal)

	-- around the zones: palms, a water cooler, towel racks, benches facing the sea
	for i, spot in ipairs({ { 4.8, 186 }, { 4.8, 228 }, { 65.8, 186 }, { 65.8, 226 } }) do
		TownKit.palm(m, Vector3.new(spot[1], 0, spot[2]), 0.9 + (i % 3) * 0.1, 60 + i)
	end
	GymKit.waterFountain(m, CFrame.new(wx + 5, 0, wz + 8) * CFrame.Angles(0, rad(-90), 0))
	GymKit.towelRack(m, CFrame.new(wx + 4.8, 0, z0 + 23) * CFrame.Angles(0, rad(90), 0))
	for _, x in ipairs({ x1 - 10, x1 - 22 }) do TownKit.bench(m, look(Vector3.new(x, 0, z1 - 2.5), Vector3.new(x, 0, z1 + 30))) end
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
	-- each spec: x (center), w, floors, shop, and which side walls can be seen (left/right are the building's own sides)
	local function row(list, z, facing, back)
		for _, spec in ipairs(list) do
			i += 1
			local pos = Vector3.new(spec.x, 0, z)
			local cf = look(pos, pos + facing)
			TownKit.building(bg, "Building", cf, {
				w = spec.w, d = 16, floors = spec.floors, palette = TownKit.Palette[(i % #TownKit.Palette) + 1],
				shop = spec.shop and shops[(i % #shops) + 1] or nil, balconies = i % 2 == 0,
				roof = ({ "ac", "tank", "rail" })[(i % 3) + 1], seed = i,
				back = back, left = spec.left, right = spec.right,
			})
		end
	end
	local s = Town.Street
	local south = s.MinZ - s.Sidewalk - 0.5   -- fronts at the back of Main Street's south sidewalk, facing north
	local north = s.MaxZ + s.Sidewalk + 4     -- fronts behind the shop frontage paving, facing south
	row({ { x = -51, w = 16, floors = 3, shop = true, left = true }, { x = -69, w = 18, floors = 4, shop = true }, { x = -87.5, w = 17, floors = 2, shop = true },
		{ x = -106.5, w = 19, floors = 5 }, { x = -124.5, w = 16, floors = 3, shop = true }, { x = -143, w = 19, floors = 2, shop = true },
		{ x = -163, w = 19, floors = 4 }, { x = -184, w = 21, floors = 3 } }, south, Vector3.new(0, 0, 1), true)
	row({ { x = 106, w = 16, floors = 3, shop = true, right = true }, { x = 124, w = 18, floors = 4, shop = true }, { x = 142.5, w = 17, floors = 2, shop = true },
		{ x = 161, w = 18, floors = 5 }, { x = 180, w = 18, floors = 3, shop = true }, { x = 199, w = 18, floors = 2 } }, south, Vector3.new(0, 0, 1), true)
	row({ { x = -62.5, w = 15, floors = 2, shop = true, right = true }, { x = -103.5, w = 19, floors = 3, shop = true }, { x = -123.5, w = 19, floors = 4 },
		{ x = -143.5, w = 19, floors = 3, shop = true }, { x = -164, w = 20, floors = 2, shop = true }, { x = -185, w = 20, floors = 4 } },
		north, Vector3.new(0, 0, -1), true)
	row({ { x = 62.5, w = 15, floors = 3, shop = true, left = true }, { x = 103.5, w = 19, floors = 2, shop = true }, { x = 123.5, w = 19, floors = 4, shop = true },
		{ x = 143.5, w = 19, floors = 3 }, { x = 164, w = 20, floors = 5, shop = true }, { x = 185, w = 20, floors = 3 }, { x = 206, w = 20, floors = 2 } },
		north, Vector3.new(0, 0, -1), true)
	-- a block north of the east side street, facing it (backs to the lawn)
	row({ { x = 125, w = 19, floors = 3, shop = true, left = true }, { x = 144.5, w = 19, floors = 2, shop = true }, { x = 164, w = 19, floors = 4 },
		{ x = 184, w = 19, floors = 3, shop = true }, { x = 204, w = 20, floors = 2 } }, 96, Vector3.new(0, 0, -1), true)
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
			TownKit.flowers(green, Vector3.new(pos.X, ground(pos.X, pos.Z) - 0.05, pos.Z), 1.6, 6)
		end
		for _ = 1, lawn.rocks or 1 do
			local pos = Vector3.new(rng:NextNumber(lawn.MinX + 2, lawn.MaxX - 2), -0.3, rng:NextNumber(lawn.MinZ + 2, lawn.MaxZ - 2))
			TownKit.rock(green, pos, rng:NextNumber(0.6, 1.1))
		end
	end
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
	buildPark()
	buildParking()
	buildSportsCourt()
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

-- Rebuilds the gyms' OUTSIDE in the saved place after the gyms changed size (Gyms builder; 8 Oct night): Town.GymFront
-- (run GymFrontPoster after it for its poster box), Town.GymRoofs and the boundary walls (Town.Bounds), and clears the
-- terrain and the lawns' trees / rocks out of the bigger footprint. The rest of the town keeps its hand fixes. Command
-- bar, with the builders in ServerStorage._Builders:  require(game.ServerStorage._Builders.Town).RebuildGymExterior()
function Builder.RebuildGymExterior()
	folder = Workspace:FindFirstChild("Town")
	assert(folder, "Workspace.Town is missing: run Town.Build first")
	for _, name in ipairs({ "GymFront", "GymRoofs" }) do
		local old = folder:FindFirstChild(name)
		if old then old:Destroy() end
	end
	for _, part in ipairs(folder:GetChildren()) do
		if part.Name == "Boundary" then part:Destroy() end
	end
	buildGymFront()
	buildGymRoofs()
	buildBoundary()
	local S, P = Gyms.Starter, Gyms.Pro
	local minX, maxX, minZ, maxZ = S.MinX - 3, P.MaxX + 3, S.MinZ - 3, -2.5
	Workspace.Terrain:FillBlock(CFrame.new((minX + maxX) / 2, 15, (minZ + maxZ) / 2), Vector3.new(maxX - minX, 30, maxZ - minZ), M.Air)
	local removed = 0
	local greenery = folder:FindFirstChild("Greenery")
	for _, item in ipairs(greenery and greenery:GetChildren() or {}) do
		local at = if item:IsA("Model") then item:GetPivot().Position elseif item:IsA("BasePart") then item.Position else nil
		if at and at.X > minX - 2 and at.X < maxX + 2 and at.Z > minZ - 2 and at.Z < maxZ then
			item:Destroy()
			removed += 1
		end
	end
	return removed
end

-- Rebuilds ONLY the skate park in the saved place (the rest of the town keeps its hand fixes): replaces
-- Workspace.Town.SkatePark, re-lays the two boardwalks to its gates (Config.Town.Boardwalks 2 and 4) and moves the palms
-- that stood where the bigger park is (PALM_MOVES). Command bar, with the builders in ServerStorage._Builders:
--   require(game.ServerStorage._Builders.Town).RebuildSkatePark()
local BOARDWALK_PARTS = { Plank = true, Stringer = true, RopePost = true, Rope = true }
function Builder.RebuildSkatePark()
	folder = Workspace:FindFirstChild("Town")
	assert(folder, "Workspace.Town is missing: run Town.Build first")
	local old = folder:FindFirstChild("SkatePark")
	if old then old:Destroy() end
	local beach = folder:FindFirstChild("Beach")
	if beach then
		-- the old boardwalks on the two skate park paths (Beach Road -> main gate, side gate -> beach gym), with any length
		local function onPath(position)
			return (math.abs(position.X + 122) < 4 and position.Z > 160 and position.Z < 192)
				or (math.abs(position.Z - 206) < 4 and position.X > -100 and position.X < -34)
		end
		for _, part in ipairs(beach:GetChildren()) do
			if part:IsA("BasePart") and BOARDWALK_PARTS[part.Name] and onPath(part.Position) then part:Destroy() end
		end
		for _, index in ipairs({ 2, 4 }) do
			local bw = Town.Boardwalks[index]
			boardwalk(beach, bw[1], bw[2], 6)
		end
		for _, item in ipairs(beach:GetChildren()) do
			if item:IsA("Model") and item.Name == "Palm" then
				local at = item:GetPivot().Position * Vector3.new(1, 0, 1)
				for _, move in ipairs(PALM_MOVES) do
					if (at - move[1]).Magnitude < 1.5 then item:PivotTo(item:GetPivot() + (move[2] - move[1])) end
				end
			end
		end
	end
	return buildSkatePark()
end

return Builder
