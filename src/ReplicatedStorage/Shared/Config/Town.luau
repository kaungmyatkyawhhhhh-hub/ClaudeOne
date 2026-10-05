-- The town hub outside the gym's entrance hall (built from parts by TownService). North of the entrance doors
-- (z = 13.5): a street running east-west, the smoothie bar (west) and the clothing store (east) across it, then the
-- skate park (north-west) and the beach with the beach gym and the posing stage (north-east), and the sea beyond.
-- Studs; y = 0 is the ground. Moving an area = changing its numbers here.
local Town = {}

-- Everything walkable outside, inside a low hedge (invisible walls stop players leaving).
Town.Bounds = { MinX = -78, MaxX = 78, MinZ = -60, MaxZ = 122 }

-- The outdoor hub area where skating is allowed (north of the entrance hall, buildings excluded).
Town.SkateArea = { MinX = -76, MaxX = 76, MinZ = 14, MaxZ = 121 }

Town.Street = { MinZ = 21, MaxZ = 33 }                      -- asphalt, sidewalks either side
Town.EntranceDoor = Vector3.new(0, 0, 12.9)                  -- the glass doors that now slide open
Town.SmoothieBar = { Center = Vector3.new(-34, 0, 51), Size = Vector3.new(24, 12, 18) }
Town.ClothingStore = { Center = Vector3.new(34, 0, 51), Size = Vector3.new(24, 12, 18) }
Town.SkatePark = { Center = Vector3.new(-38, 0, 90), Size = Vector3.new(48, 0, 44) }
Town.Beach = { Center = Vector3.new(40, 0, 93), Size = Vector3.new(64, 0, 58) }
Town.BeachGym = { Center = Vector3.new(24, 0, 82) }          -- the canopy; 3 machines face the sea (+Z)
Town.Stage = { Center = Vector3.new(52, 0, 100), Size = Vector3.new(16, 2, 12) }
Town.Sea = { MinZ = 122, MaxZ = 170 }                         -- terrain water, knee deep at the shore

-- Is a position in the outdoor skate area (and not inside a building)?
function Town.IsOutdoors(position)
	local a = Town.SkateArea
	if position.X < a.MinX or position.X > a.MaxX or position.Z < a.MinZ or position.Z > a.MaxZ then return false end
	for _, building in ipairs({ Town.SmoothieBar, Town.ClothingStore }) do
		local half = building.Size / 2
		local d = position - building.Center
		if math.abs(d.X) <= half.X and math.abs(d.Z) <= half.Z then return false end
	end
	return true
end

return Town
