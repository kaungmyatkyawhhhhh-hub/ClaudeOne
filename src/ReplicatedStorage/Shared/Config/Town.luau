-- The town around the gyms (built in Studio with tools/builders/Town.luau; this is its layout). y = 0 is the ground,
-- +Z is north toward the sea. The gyms sit south of the main street: the starter gym (x -37..37) with its entrance hall
-- sticking out to z = 13.5, and the pro gym (x 37..94). Across the street: the plaza, the smoothie bar (west) and the
-- Gear & Fits clothing store (east); further north the skate park (north-west) and the beach (north-east) with the
-- beach gym and the posing stage, then the sea. Background buildings line the street on both sides; hills with trees
-- surround everything, so there is no world edge in sight. Studs.
local Town = {}

-- Everything walkable outside (invisible walls stop players leaving).
Town.Bounds = { MinX = -142, MaxX = 178, MinZ = -80, MaxZ = 122 }

-- Outdoor area where skating is allowed (everything north of the gym fronts; buildings excluded, see IsOutdoors).
Town.SkateArea = { MinX = -140, MaxX = 176, MinZ = -2, MaxZ = 121 }

Town.Street = { MinX = -150, MaxX = 186, MinZ = 24, MaxZ = 34 } -- asphalt; 4-stud sidewalks on both sides
Town.Crosswalks = { 0, 66 }                                     -- x of each crosswalk
Town.Forecourt = { MinX = -40, MaxX = 96, MinZ = -3, MaxZ = 20 } -- paving in front of both gyms
Town.Hall = { Center = Vector3.new(0, 0, 5), Size = Vector3.new(22, 14, 17) } -- the gym's entrance hall
Town.EntranceDoor = Vector3.new(0, 0, 12.9)                      -- the glass doors that slide open
Town.Plaza = { MinX = -20, MaxX = 20, MinZ = 38, MaxZ = 70 }
Town.Boardwalk = { MinX = 4, MaxX = 10, MinZ = 70, MaxZ = 80 }    -- plaza -> beach
Town.SmoothieBar = { Center = Vector3.new(-36, 0, 52), Size = Vector3.new(22, 12, 18) }
Town.ClothingStore = { Center = Vector3.new(36, 0, 52), Size = Vector3.new(22, 12, 18) }
Town.SkatePark = { Center = Vector3.new(-45, 0, 92), Size = Vector3.new(50, 0, 44) }
Town.Beach = { MinX = 0, MaxX = 150, MinZ = 66 }
Town.BeachGym = { Center = Vector3.new(22, 0, 84) }              -- the shade structure; machines face the sea (+Z)
Town.Stage = { Center = Vector3.new(60, 0, 104), Size = Vector3.new(16, 2, 12) }
Town.Sea = { MinZ = 122, MaxZ = 1400 }                           -- terrain water to the horizon

-- Grass areas inside the town that get gentle bumps, trees, bushes, flowers and rocks.
Town.Lawns = {
	{ MinX = -140, MaxX = -74, MinZ = 56, MaxZ = 118, bumps = 10, trees = 6, flowers = 6, rocks = 3 },
	{ MinX = -18, MaxX = -1, MinZ = 72, MaxZ = 116, bumps = 4, trees = 2, flowers = 4, rocks = 1 },
	{ MinX = 152, MaxX = 176, MinZ = 56, MaxZ = 118, bumps = 5, trees = 4, flowers = 3, rocks = 2 },
	{ MinX = -140, MaxX = -40, MinZ = -76, MaxZ = 2, bumps = 8, trees = 6, flowers = 4, rocks = 2 },
	{ MinX = 98, MaxX = 176, MinZ = -76, MaxZ = 2, bumps = 8, trees = 6, flowers = 3, rocks = 2 },
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
