-- The town around the gyms (built in Studio with tools/builders/Town.luau; this is its layout). y = 0 is the ground,
-- +Z is north toward the sea. The gyms sit south of Main Street (starter gym x -37..37 with its entrance hall out to
-- z = 13.5, pro gym x 37..94). North of Main Street two avenues lead up to Beach Road; between them the open plaza and
-- the park, west of them the smoothie bar, shops, a side street and the parking lot, east of them Gear & Fits, shops, a
-- side street, the sports court and more buildings. North of Beach Road the beach: skate park (west), the beach gym
-- (middle), the posing stage and the volleyball court (east), then the sea. Studs.
local Town = {}

-- Everything walkable (invisible walls stop players leaving).
Town.Bounds = { MinX = -176, MaxX = 200, MinZ = -80, MaxZ = 262 }

-- Outdoor area where skating is allowed (north of the gym fronts; buildings excluded, see IsOutdoors).
Town.SkateArea = { MinX = -174, MaxX = 198, MinZ = -2, MaxZ = 258 }

-- Roads: asphalt rectangles; every road has sidewalks of `Sidewalk` width along its long sides.
Town.Street = { MinX = -190, MaxX = 214, MinZ = 24, MaxZ = 44, Sidewalk = 6 }      -- Main Street (4 lanes wide)
Town.BeachRoad = { MinX = -190, MaxX = 214, MinZ = 150, MaxZ = 162, Sidewalk = 5 }
Town.Avenues = { { X = -44, Width = 12 }, { X = 44, Width = 12 } }                -- Main Street <-> Beach Road
Town.SideStreets = {                                                              -- east-west lanes behind the shops
	{ MinX = -190, MaxX = -50, MinZ = 78, MaxZ = 88 },
	{ MinX = 50, MaxX = 214, MinZ = 78, MaxZ = 88 },
}
Town.SideSidewalk = 4                                                             -- avenues and side streets
Town.Crosswalks = { -44, 0, 44, 120 }                                            -- x of each Main Street crosswalk
Town.BeachRoadCrosswalks = { -122, -44, 0, 44, 112 }

Town.Forecourt = { MinX = -40, MaxX = 96, MinZ = -3, MaxZ = 18 }                -- paving in front of both gyms
Town.Hall = { Center = Vector3.new(0, 0, 5), Size = Vector3.new(22, 14, 17) }  -- the gym's entrance hall
Town.EntranceDoor = Vector3.new(0, 0, 12.9)                                     -- the glass doors that slide open
Town.Plaza = { MinX = -34, MaxX = 34, MinZ = 50, MaxZ = 92 }                    -- open paved square
Town.Park = { MinX = -34, MaxX = 34, MinZ = 92, MaxZ = 145 }                    -- grass, paths, fountain, playground
Town.Parking = { MinX = -150, MaxX = -58, MinZ = 96, MaxZ = 142 }
Town.SportsCourt = { MinX = 60, MaxX = 110, MinZ = 96, MaxZ = 140 }
Town.SmoothieBar = { Center = Vector3.new(-82, 0, 63), Size = Vector3.new(22, 12, 18) }
Town.ClothingStore = { Center = Vector3.new(82, 0, 63), Size = Vector3.new(22, 12, 18) }
Town.Beach = { MinX = -176, MaxX = 200, MinZ = 167 }
Town.SkatePark = { Center = Vector3.new(-122, 0, 206), Size = Vector3.new(84, 0, 64) } -- x -164..-80, z 174..238
Town.BeachGym = { Center = Vector3.new(16, 0, 206), Size = Vector3.new(104, 0, 66) } -- open-air zones on the sand
Town.Stage = { Center = Vector3.new(112, 0, 214), Size = Vector3.new(16, 2, 12) }
Town.Boardwalks = {                                                              -- { from, to } on the sand, 6 wide
	{ Vector3.new(0, 0, 165), Vector3.new(0, 0, 175) },        -- Beach Road -> beach gym entrance
	{ Vector3.new(-122, 0, 165), Vector3.new(-122, 0, 175) },  -- Beach Road -> skate park gate
	{ Vector3.new(112, 0, 165), Vector3.new(112, 0, 187) },    -- Beach Road -> posing stage crowd
	{ Vector3.new(-79, 0, 206), Vector3.new(-37, 0, 206) },    -- skate park side gate -> beach gym
	{ Vector3.new(68, 0, 206), Vector3.new(103, 0, 206) },     -- beach gym -> posing stage
}
Town.Sea = { MinZ = 262, MaxZ = 5000 }                                           -- terrain water to the horizon

-- Grass areas inside the town that get gentle bumps, trees, bushes, flowers and rocks.
Town.Lawns = {
	{ MinX = -176, MaxX = -154, MinZ = 94, MaxZ = 143, bumps = 4, trees = 5, flowers = 4, rocks = 2 },
	{ MinX = 114, MaxX = 200, MinZ = 116, MaxZ = 143, bumps = 6, trees = 8, flowers = 6, rocks = 3 },
	{ MinX = -176, MaxX = -42, MinZ = -76, MaxZ = -2, bumps = 8, trees = 18, flowers = 8, rocks = 4 },
	{ MinX = 98, MaxX = 200, MinZ = -76, MaxZ = -2, bumps = 8, trees = 15, flowers = 7, rocks = 4 },
}

-- Is a position outdoors in the hub (not inside a building)?
function Town.IsOutdoors(position)
	local a = Town.SkateArea
	if position.X < a.MinX or position.X > a.MaxX or position.Z < a.MinZ or position.Z > a.MaxZ then return false end
	for _, building in ipairs({ Town.SmoothieBar, Town.ClothingStore, Town.Hall }) do
		local half = building.Size / 2
		local d = position - building.Center
		if math.abs(d.X) <= half.X and math.abs(d.Z) <= half.Z then return false end
	end
	return true
end

return Town
