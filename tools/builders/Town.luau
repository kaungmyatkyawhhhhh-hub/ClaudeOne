-- Town builder (run once in Studio; see tools/bake.md): the town hub outside the entrance hall (layout in
-- Config.Town): ground, street and sidewalks, the gym's outside sign, sliding glass entrance doors (tag "SlidingDoor"),
-- the smoothie bar (moves the shake machine in), the clothing store (counter prompt "ShopPrompt"), the skate park, the
-- beach with the beach gym (3 machines) and the posing stage (prompt "PosePrompt"), a hedge boundary and a city
-- backdrop, and the sea (terrain water). Output: Workspace.Town. TownService wires the prompts.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Town = require(Config.Town)
local Machines = require(Config.Machines)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local Kit = require(script.Parent.Kit)
local ProGym = require(script.Parent.ProGym)

local Builder = {}

local function hex(value) return Color3.fromHex(value) end
local COLORS = {
	Grass = hex("#5E7F45"), Asphalt = hex("#2E2E31"), Line = hex("#E9E4D8"), Sidewalk = hex("#B9B5AC"),
	Curb = hex("#8E8A82"), Plaza = hex("#A39D92"), Sand = hex("#E2CC9B"), Wood = hex("#8A6A4A"), Hedge = hex("#3F5E33"),
	Trunk = hex("#6E5136"), Leaf = hex("#4F7A3A"), Steel = hex("#9EA2A8"), Dark = hex("#1E1E22"), White = hex("#F4F1EA"),
	Stucco = hex("#E9E2D6"), Charcoal = hex("#2E2E33"), Concrete = hex("#9C9C98"), Canvas = hex("#F2EEE4"),
	Brick = hex("#8C4A3A"), Neon = hex("#FF4D4D"),
}
local GROUND_TOP = 0.05

local folder

local part, prop, wedge, cylinder, sign = Kit.part, Kit.prop, Kit.wedge, Kit.cylinder, Kit.sign

-- A cframe at `position` whose front face (-Z, where sign text is drawn) turns toward `toward` (the reader).
local function facing(position, toward)
	return CFrame.lookAt(position, toward)
end

------------------------------------------------------------------------
-- Ground, street, sidewalks, plaza
------------------------------------------------------------------------
local function buildGround()
	-- one big grass plate under everything (hides the grey baseplate); the gyms' own floors sit above it
	-- it ends at the shoreline (Town.Sea.MinZ): past it is the terrain sea
	local grassMinZ = -320
	local grassLength = Town.Sea.MinZ - grassMinZ
	part(folder, "Grass", Vector3.new(700, 1, grassLength), CFrame.new(0, GROUND_TOP - 0.5, grassMinZ + grassLength / 2), COLORS.Grass, Enum.Material.Grass)
	local street = Town.Street
	local width = Town.Bounds.MaxX - Town.Bounds.MinX
	local streetDepth = street.MaxZ - street.MinZ
	part(folder, "Street", Vector3.new(width, 0.2, streetDepth), CFrame.new(0, 0.1, (street.MinZ + street.MaxZ) / 2), COLORS.Asphalt, Enum.Material.Asphalt)
	-- dashed center line
	for x = Town.Bounds.MinX + 4, Town.Bounds.MaxX - 4, 8 do
		if math.abs(x) > 6 then
			prop(folder, "Dash", Vector3.new(4, 0.02, 0.35), CFrame.new(x, 0.21, (street.MinZ + street.MaxZ) / 2), COLORS.Line, Enum.Material.SmoothPlastic)
		end
	end
	-- crosswalk from the gym doors to the plaza
	for i = 0, 5 do
		prop(folder, "Crosswalk", Vector3.new(1.2, 0.02, streetDepth - 1), CFrame.new(-4.5 + i * 1.8, 0.21, (street.MinZ + street.MaxZ) / 2), COLORS.Line, Enum.Material.SmoothPlastic)
	end
	-- sidewalks (south: in front of the gym; north: in front of the shops) with curbs
	local southDepth = street.MinZ - 13.5
	part(folder, "SidewalkSouth", Vector3.new(width, 0.3, southDepth), CFrame.new(0, 0.15, 13.5 + southDepth / 2), COLORS.Sidewalk, Enum.Material.Concrete)
	part(folder, "SidewalkNorth", Vector3.new(width, 0.3, 6), CFrame.new(0, 0.15, street.MaxZ + 3), COLORS.Sidewalk, Enum.Material.Concrete)
	prop(folder, "Curb", Vector3.new(width, 0.32, 0.4), CFrame.new(0, 0.16, street.MinZ + 0.2), COLORS.Curb, Enum.Material.Concrete)
	prop(folder, "Curb", Vector3.new(width, 0.32, 0.4), CFrame.new(0, 0.16, street.MaxZ - 0.2), COLORS.Curb, Enum.Material.Concrete)
	-- plaza between the shops, the skate park and the beach
	local plazaFrom, plazaTo = street.MaxZ + 6, 66
	part(folder, "Plaza", Vector3.new(width, 0.2, plazaTo - plazaFrom), CFrame.new(0, 0.1, (plazaFrom + plazaTo) / 2), COLORS.Plaza, Enum.Material.Pavement)
end

------------------------------------------------------------------------
-- The gym from outside: sign over the doors, sliding doors
------------------------------------------------------------------------
local function buildGymFront()
	-- neon "GYM ARC" over the entrance, on the outside of the hall's front wall (z = 13.5)
	local board = sign(folder, "GymSignOutside", Vector3.new(12, 2.6, 0.3), facing(Vector3.new(0, 10.4, 14.2), Vector3.new(0, 10.4, 40)), "GYM ARC", COLORS.Neon)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color, light.Brightness, light.Range, light.Shadows = COLORS.Neon, 1.2, 10, false
	light.Parent = board
	-- awning over the doors
	prop(folder, "Awning", Vector3.new(10, 0.3, 3), CFrame.new(0, 8.8, 15.2), COLORS.Charcoal, Enum.Material.Metal)

	-- the glass doors slide open when someone walks up (TownClient animates them; they never block)
	local entrance = Workspace:FindFirstChild("Gym") and Workspace.Gym:FindFirstChild("StarterGym")
	entrance = entrance and entrance:FindFirstChild("Entrance")
	if not entrance then return end
	for _, piece in ipairs(entrance:GetChildren()) do
		if piece:IsA("BasePart") and (piece.Name == "DoorGlass" or piece.Name == "PushBar" or piece.Name == "DoorDivider") then
			piece.CanCollide = false
			-- left half slides left, right half slides right; the middle divider goes with the left door
			local side = (piece.Name == "DoorDivider" or piece.Position.X < 0) and -1 or 1
			piece:SetAttribute("SlideX", side * 3.4)
			CollectionService:AddTag(piece, "SlidingDoor")
		end
	end
end

------------------------------------------------------------------------
-- Buildings (smoothie bar, clothing store): walls with a doorway facing the street (-Z), roof, sign, light
------------------------------------------------------------------------
local function building(name, spec, wallColor, wallMaterial, signText, signColor)
	local model = Instance.new("Model")
	model.Name = name
	local c, s = spec.Center, spec.Size
	local halfX, halfZ = s.X / 2, s.Z / 2
	part(model, "Floor", Vector3.new(s.X, 0.3, s.Z), CFrame.new(c.X, 0.15, c.Z), hex("#3A3530"), Enum.Material.WoodPlanks)
	part(model, "BackWall", Vector3.new(s.X, s.Y, 1), CFrame.new(c.X, s.Y / 2, c.Z + halfZ - 0.5), wallColor, wallMaterial)
	part(model, "WallL", Vector3.new(1, s.Y, s.Z), CFrame.new(c.X - halfX + 0.5, s.Y / 2, c.Z), wallColor, wallMaterial)
	part(model, "WallR", Vector3.new(1, s.Y, s.Z), CFrame.new(c.X + halfX - 0.5, s.Y / 2, c.Z), wallColor, wallMaterial)
	-- front wall with a 6-stud doorway in the middle
	local door, doorHeight = 6, 9
	local side = (s.X - door) / 2
	local frontZ = c.Z - halfZ + 0.5
	part(model, "FrontL", Vector3.new(side, s.Y, 1), CFrame.new(c.X - door / 2 - side / 2, s.Y / 2, frontZ), wallColor, wallMaterial)
	part(model, "FrontR", Vector3.new(side, s.Y, 1), CFrame.new(c.X + door / 2 + side / 2, s.Y / 2, frontZ), wallColor, wallMaterial)
	part(model, "Header", Vector3.new(door, s.Y - doorHeight, 1), CFrame.new(c.X, doorHeight + (s.Y - doorHeight) / 2, frontZ), wallColor, wallMaterial)
	-- shop windows either side of the door
	for _, dx in ipairs({ -1, 1 }) do
		prop(model, "Window", Vector3.new(side - 3, 4, 0.2), CFrame.new(c.X + dx * (door / 2 + side / 2), 4.5, frontZ - 0.55), hex("#9FB7C4"), Enum.Material.Glass, { Transparency = 0.45 })
	end
	part(model, "Roof", Vector3.new(s.X + 1, 1, s.Z + 1), CFrame.new(c.X, s.Y + 0.5, c.Z), COLORS.Charcoal, Enum.Material.Concrete)
	sign(model, "Sign", Vector3.new(s.X * 0.6, 2.2, 0.3), facing(Vector3.new(c.X, s.Y - 1.4, frontZ - 0.7), Vector3.new(c.X, s.Y - 1.4, frontZ - 40)), signText, signColor)
	local lamp = prop(model, "Lamp", Vector3.new(1.2, 0.3, 1.2), CFrame.new(c.X, s.Y - 0.3, c.Z), COLORS.Dark, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = hex("#FFD7A8"), 1.2, 22, false
	light.Parent = lamp
	model.Parent = folder
	return model, frontZ
end

local function buildSmoothieBar()
	local spec = Town.SmoothieBar
	local model = building("SmoothieBar", spec, COLORS.Stucco, Enum.Material.Plaster, "Smoothie bar", hex("#7BD389"))
	local c, s = spec.Center, spec.Size
	local backZ = c.Z + s.Z / 2 - 1
	-- counter along the back wall, stools in front, a menu board
	part(model, "Counter", Vector3.new(14, 3.4, 2.4), CFrame.new(c.X, 1.85, backZ - 4), hex("#3B3B40"), Enum.Material.Wood)
	prop(model, "CounterTop", Vector3.new(14.4, 0.25, 2.8), CFrame.new(c.X, 3.65, backZ - 4), COLORS.White, Enum.Material.Marble)
	for i = -2, 2 do
		local x = c.X + i * 2.8
		cylinder(model, "StoolLeg", 2.4, 0.3, CFrame.new(x, 1.35, backZ - 6.8) * CFrame.Angles(0, 0, math.rad(90)), COLORS.Steel, Enum.Material.Metal)
		cylinder(model, "StoolSeat", 0.3, 1.3, CFrame.new(x, 2.6, backZ - 6.8) * CFrame.Angles(0, 0, math.rad(90)), hex("#7BD389"), Enum.Material.SmoothPlastic)
	end
	sign(model, "Menu", Vector3.new(8, 3.2, 0.2), facing(Vector3.new(c.X, 8, backZ - 0.15), Vector3.new(c.X, 8, backZ - 30)),
		"Energy shakes · +50% gains", COLORS.White, hex("#2B2B2B"))
	-- the shake machine moves here from beside the gym door (its Buy prompt comes with it)
	local machine = Workspace:FindFirstChild("ShakeMachine", true)
	if machine and machine:IsA("Model") then
		local cf, size = machine:GetBoundingBox()
		local target = Vector3.new(c.X + 5, 0.3 + size.Y / 2, backZ - 1.6)
		machine:PivotTo(machine:GetPivot() + (target - cf.Position))
	end
end

local function buildClothingStore()
	local spec = Town.ClothingStore
	local model = building("ClothingStore", spec, COLORS.Charcoal, Enum.Material.Concrete, "Gear and fits", COLORS.White)
	local c, s = spec.Center, spec.Size
	local backZ = c.Z + s.Z / 2 - 1
	local counter = part(model, "Counter", Vector3.new(8, 3.4, 2.4), CFrame.new(c.X, 1.85, backZ - 4), hex("#1E1E22"), Enum.Material.Wood)
	prop(model, "CounterTop", Vector3.new(8.4, 0.25, 2.8), CFrame.new(c.X, 3.65, backZ - 4), hex("#C9C2B5"), Enum.Material.Wood)
	-- displays: belts and headbands on stands, shakers on a shelf (decoration in the item colors)
	local shelfZ = backZ - 0.6
	part(model, "Shelf", Vector3.new(10, 0.3, 1.2), CFrame.new(c.X - 6, 6, shelfZ), hex("#C9C2B5"), Enum.Material.Wood)
	for i, color in ipairs({ "#F4F1EA", "#E86FA3", "#1E1E22", "#7BD389" }) do
		cylinder(model, "ShakerDisplay", 1.2, 0.6, CFrame.new(c.X - 9.5 + i * 2, 6.75, shelfZ) * CFrame.Angles(0, 0, math.rad(90)), hex(color), Enum.Material.SmoothPlastic)
	end
	for i, color in ipairs({ "#1E1E22", "#6B4428", "#B3262D" }) do
		local x = c.X + 2 + i * 2.6
		cylinder(model, "Stand", 4, 0.25, CFrame.new(x, 2.15, backZ - 9) * CFrame.Angles(0, 0, math.rad(90)), COLORS.Steel, Enum.Material.Metal)
		cylinder(model, "BeltDisplay", 0.7, 1.8, CFrame.new(x, 4.2, backZ - 9), hex(color), Enum.Material.Fabric)
	end
	-- the counter's Shop prompt opens the store screen (WardrobeClient)
	Kit.prompt(counter, "ShopPrompt", "Shop", "Gear and fits", 9)
end

------------------------------------------------------------------------
-- Street furniture and trees
------------------------------------------------------------------------
local function tree(position, scale)
	scale = scale or 1
	part(folder, "Trunk", Vector3.new(1, 6 * scale, 1), CFrame.new(position + Vector3.new(0, 3 * scale, 0)), COLORS.Trunk, Enum.Material.Wood)
	local leaves = prop(folder, "Leaves", Vector3.new(6, 5, 6) * scale, CFrame.new(position + Vector3.new(0, 7.5 * scale, 0)), COLORS.Leaf, Enum.Material.Grass)
	leaves.Shape = Enum.PartType.Ball
end

local function bench(position, yaw)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	part(folder, "BenchSeat", Vector3.new(5, 0.3, 1.4), base * CFrame.new(0, 1.6, 0), COLORS.Wood, Enum.Material.WoodPlanks)
	prop(folder, "BenchBack", Vector3.new(5, 1.2, 0.25), base * CFrame.new(0, 2.5, 0.6), COLORS.Wood, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -2, 2 }) do
		prop(folder, "BenchLeg", Vector3.new(0.25, 1.5, 1.2), base * CFrame.new(x, 0.75, 0), COLORS.Dark, Enum.Material.Metal)
	end
end

local function streetLamp(position)
	cylinder(folder, "LampPost", 9, 0.35, CFrame.new(position + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), COLORS.Dark, Enum.Material.Metal)
	prop(folder, "LampHead", Vector3.new(1, 0.5, 1), CFrame.new(position + Vector3.new(0, 9.1, 0)), hex("#FFE6BF"), Enum.Material.Neon)
end

local function buildFurniture()
	for _, x in ipairs({ -60, -36, -14, 14, 36, 60 }) do
		streetLamp(Vector3.new(x, GROUND_TOP, 19.5))
	end
	for _, x in ipairs({ -12, 12 }) do
		bench(Vector3.new(x, GROUND_TOP, 44), 180)
	end
	for _, spot in ipairs({ Vector3.new(-8, 0, 58), Vector3.new(8, 0, 58), Vector3.new(-58, 0, 42), Vector3.new(58, 0, 42), Vector3.new(-66, 0, 60), Vector3.new(66, 0, 60) }) do
		tree(spot + Vector3.new(0, GROUND_TOP, 0))
	end
end

------------------------------------------------------------------------
-- Skate park: concrete pad, kickers, funbox, rail, a quarter pipe along the north edge
------------------------------------------------------------------------
local function buildSkatePark()
	local spec = Town.SkatePark
	local c, s = spec.Center, spec.Size
	local model = Instance.new("Model")
	model.Name = "SkatePark"
	part(model, "Pad", Vector3.new(s.X, 0.35, s.Z), CFrame.new(c.X, 0.175, c.Z), COLORS.Concrete, Enum.Material.Concrete)
	-- kicker ramps (rise toward +Z / -Z)
	wedge(model, "Kicker", Vector3.new(6, 1.6, 5), CFrame.new(c.X - 14, 0.35 + 0.8, c.Z - 8), COLORS.Concrete)
	wedge(model, "Kicker", Vector3.new(6, 1.6, 5), CFrame.new(c.X + 14, 0.35 + 0.8, c.Z - 8), COLORS.Concrete)
	-- funbox: a flat top with ramps on both ends
	part(model, "Funbox", Vector3.new(8, 1.5, 6), CFrame.new(c.X, 0.35 + 0.75, c.Z + 2), COLORS.Concrete, Enum.Material.Concrete)
	wedge(model, "FunboxRamp", Vector3.new(8, 1.5, 4), CFrame.new(c.X, 0.35 + 0.75, c.Z - 3) , COLORS.Concrete)
	wedge(model, "FunboxRamp", Vector3.new(8, 1.5, 4), CFrame.new(c.X, 0.35 + 0.75, c.Z + 7) * CFrame.Angles(0, math.pi, 0), COLORS.Concrete)
	cylinder(model, "Coping", 8, 0.25, CFrame.new(c.X, 1.85, c.Z - 1) * CFrame.Angles(0, 0, 0), COLORS.Steel, Enum.Material.Metal)
	-- grind rail
	cylinder(model, "Rail", 12, 0.3, CFrame.new(c.X - 12, 1.7, c.Z + 6), COLORS.Steel, Enum.Material.Metal, true)
	for _, dx in ipairs({ -5, 0, 5 }) do
		prop(model, "RailPost", Vector3.new(0.25, 1.4, 0.25), CFrame.new(c.X - 12 + dx, 1.05, c.Z + 6), COLORS.Steel, Enum.Material.Metal)
	end
	-- quarter pipe: an arc of planks rising toward the north edge, a deck on top
	local radius, width, segments, maxAngle = 6, 24, 7, math.rad(80)
	local baseZ = c.Z + s.Z / 2 - radius - 3
	for i = 1, segments do
		local a0, a1 = maxAngle * (i - 1) / segments, maxAngle * i / segments
		local p0 = Vector3.new(0, radius * (1 - math.cos(a0)), radius * math.sin(a0))
		local p1 = Vector3.new(0, radius * (1 - math.cos(a1)), radius * math.sin(a1))
		local mid = (p0 + p1) / 2
		local tilt = (a0 + a1) / 2
		local normal = Vector3.new(0, math.cos(tilt), -math.sin(tilt))
		local center = Vector3.new(c.X, 0.35, baseZ) + mid - normal * 0.3
		part(model, "QuarterPipe", Vector3.new(width, 0.6, (p1 - p0).Magnitude + 0.05), CFrame.new(center) * CFrame.Angles(-tilt, 0, 0), COLORS.Concrete, Enum.Material.Concrete)
	end
	local topY = 0.35 + radius * (1 - math.cos(maxAngle))
	local topZ = baseZ + radius * math.sin(maxAngle)
	part(model, "Deck", Vector3.new(width, 0.6, 3), CFrame.new(c.X, topY - 0.3, topZ + 1.5), COLORS.Concrete, Enum.Material.Concrete)
	part(model, "DeckWall", Vector3.new(width, topY, 1), CFrame.new(c.X, topY / 2, topZ + 3.2), COLORS.Concrete, Enum.Material.Concrete)
	cylinder(model, "Coping", width, 0.3, CFrame.new(c.X, topY, topZ), COLORS.Steel, Enum.Material.Metal)
	sign(model, "Sign", Vector3.new(10, 2, 0.3), facing(Vector3.new(c.X, topY + 2.5, topZ + 3.4), Vector3.new(c.X, topY + 2.5, topZ - 30)), "Skate park", COLORS.White)
	model.Parent = folder
end

------------------------------------------------------------------------
-- Beach: sand, sea, palms, umbrellas; the beach gym canopy with 3 machines; the posing stage
------------------------------------------------------------------------
local function palm(position)
	local height = 9
	for i = 0, 3 do
		cylinder(folder, "PalmTrunk", height / 4 + 0.1, 0.7 - i * 0.08,
			CFrame.new(position + Vector3.new(i * 0.35, height / 8 + i * height / 4, 0)) * CFrame.Angles(0, 0, math.rad(90 - i * 4)), COLORS.Trunk, Enum.Material.Wood)
	end
	local top = position + Vector3.new(1.4, height, 0)
	for k = 0, 5 do
		local yaw = math.rad(k * 60)
		prop(folder, "PalmLeaf", Vector3.new(0.2, 1.2, 4.5), CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, -0.6, 2) * CFrame.Angles(math.rad(25), 0, 0), COLORS.Leaf, Enum.Material.Grass)
	end
end

local function umbrella(position, color)
	cylinder(folder, "UmbrellaPole", 6, 0.2, CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)), COLORS.White, Enum.Material.Metal)
	cylinder(folder, "UmbrellaTop", 0.4, 6, CFrame.new(position + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Fabric)
	prop(folder, "Towel", Vector3.new(2.4, 0.05, 4.4), CFrame.new(position + Vector3.new(1.8, 0.25, 0.5)), color, Enum.Material.Fabric)
end

local function buildBeach()
	local spec = Town.Beach
	local c, s = spec.Center, spec.Size
	part(folder, "Sand", Vector3.new(s.X, 0.3, s.Z), CFrame.new(c.X, 0.15, c.Z), COLORS.Sand, Enum.Material.Sand)
	-- the sea along the whole north edge, out to the horizon. The Baseplate is cut at the shoreline (it would hide the
	-- water); a shallow sand shelf by the beach (water ~1.5 studs deep, up to the boundary), then deep water.
	local shore = Town.Sea.MinZ
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") and baseplate.Position.Z + baseplate.Size.Z / 2 > shore then
		local minZ = baseplate.Position.Z - baseplate.Size.Z / 2
		baseplate.Size = Vector3.new(baseplate.Size.X, baseplate.Size.Y, shore - minZ)
		baseplate.CFrame = CFrame.new(baseplate.Position.X, baseplate.Position.Y, (minZ + shore) / 2)
	end
	pcall(function()
		local terrain, width = Workspace.Terrain, 2048
		terrain:FillBlock(CFrame.new(0, 0, shore + 450), Vector3.new(width, 40, 900), Enum.Material.Air) -- clears older water
		terrain:FillBlock(CFrame.new(0, -6, shore + 12), Vector3.new(width, 9, 24), Enum.Material.Sand)
		terrain:FillBlock(CFrame.new(0, -12, shore + 462), Vector3.new(width, 8, 876), Enum.Material.Sand)
		terrain:FillBlock(CFrame.new(0, -0.75, shore + 12), Vector3.new(width, 1.5, 24), Enum.Material.Water)
		terrain:FillBlock(CFrame.new(0, -4, shore + 462), Vector3.new(width, 8, 876), Enum.Material.Water)
	end)
	for _, spot in ipairs({ Vector3.new(12, 0.3, 70), Vector3.new(68, 0.3, 72), Vector3.new(66, 0.3, 112), Vector3.new(14, 0.3, 116) }) do
		palm(spot)
	end
	umbrella(Vector3.new(36, 0.3, 114), hex("#1F5FBF"))
	umbrella(Vector3.new(26, 0.3, 112), hex("#D7262E"))
	umbrella(Vector3.new(44, 0.3, 116), hex("#E8C21C"))
end

local function buildBeachGym()
	local center = Town.BeachGym.Center
	local model = Instance.new("Model")
	model.Name = "BeachGym"
	part(model, "Floor", Vector3.new(18, 0.2, 10), CFrame.new(center.X, 0.4, center.Z), hex("#2A2A2E"), Enum.Material.Rubber)
	for _, dx in ipairs({ -8.5, 8.5 }) do
		for _, dz in ipairs({ -4.5, 4.5 }) do
			part(model, "Post", Vector3.new(0.5, 9, 0.5), CFrame.new(center.X + dx, 4.5, center.Z + dz), COLORS.Wood, Enum.Material.Wood)
		end
	end
	prop(model, "Canopy", Vector3.new(19, 0.3, 11), CFrame.new(center.X, 9.1, center.Z) * CFrame.Angles(math.rad(-4), 0, 0), COLORS.Canvas, Enum.Material.Fabric)
	sign(model, "Sign", Vector3.new(12, 1.4, 0.3), facing(Vector3.new(center.X, 8.2, center.Z - 5.2), Vector3.new(center.X, 8.2, center.Z - 40)),
		"Beach gym · opens at Growth Spurt " .. Machines.GymUnlock.Beach, COLORS.White, hex("#2B2B2B"))
	model.Parent = folder
	-- three machines facing the sea (+Z), built like the pro gym's cable stacks
	local beach = {}
	for _, machine in ipairs(Machines.List) do
		if machine.gym == "Beach" then table.insert(beach, machine) end
	end
	for index, machine in ipairs(beach) do
		local x = center.X + (index - (#beach + 1) / 2) * 5.5
		local pivot = CFrame.new(Vector3.new(x, 0.5, center.Z - 2)) -- lifter facing +Z, stack in front
		ProGym.BuildMachine(machine, pivot, model)
	end
end

local function buildStage()
	local spec = Town.Stage
	local c, s = spec.Center, spec.Size
	local model = Instance.new("Model")
	model.Name = "PosingStage"
	local top = 0.3 + s.Y
	local stage = part(model, "Stage", Vector3.new(s.X, s.Y, s.Z), CFrame.new(c.X, 0.3 + s.Y / 2, c.Z), COLORS.Wood, Enum.Material.WoodPlanks)
	for i = 1, 3 do
		local h = s.Y * i / 4
		part(model, "Step", Vector3.new(6, h, 1.2), CFrame.new(c.X, 0.3 + h / 2, c.Z - s.Z / 2 - (4 - i) * 1.2 + 0.6), COLORS.Wood, Enum.Material.WoodPlanks)
	end
	local backZ = c.Z + s.Z / 2 - 0.3
	part(model, "Backdrop", Vector3.new(s.X, 10, 0.6), CFrame.new(c.X, top + 5, backZ), hex("#2B2B2B"), Enum.Material.Fabric)
	sign(model, "Sign", Vector3.new(10, 1.8, 0.2), facing(Vector3.new(c.X, top + 8, backZ - 0.45), Vector3.new(c.X, top + 8, backZ - 40)), "Posing stage", COLORS.White, hex("#2B2B2B"))
	for _, dx in ipairs({ -5, 5 }) do
		local fixture = prop(model, "StageLight", Vector3.new(1, 0.6, 1), CFrame.new(c.X + dx, top + 9.5, backZ - 1.5), COLORS.Dark, Enum.Material.Metal)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color, light.Brightness, light.Range, light.Angle, light.Shadows = hex("#FFF2DD"), 2, 16, 60, false
		light.Parent = fixture
	end
	-- "Pose" opens the Emotes panel (EmoteClient); posing itself is just the normal emotes, seen by everyone
	Kit.prompt(stage, "PosePrompt", "Pose", "Posing stage", 10)
	model.Parent = folder
end

------------------------------------------------------------------------
-- Boundary (low hedge + invisible walls) and a simple city skyline behind it (placeholder art)
------------------------------------------------------------------------
local function buildBoundary()
	local b = Town.Bounds
	local width, depth = b.MaxX - b.MinX, b.MaxZ - b.MinZ
	local function wall(size, cframe)
		part(folder, "Boundary", size, cframe, COLORS.Hedge, Enum.Material.Grass, { Transparency = 1, CastShadow = false, CanQuery = false })
	end
	wall(Vector3.new(1, 40, depth + 40), CFrame.new(b.MinX, 20, (b.MinZ + b.MaxZ) / 2 + 10))
	wall(Vector3.new(1, 40, depth + 40), CFrame.new(b.MaxX, 20, (b.MinZ + b.MaxZ) / 2 + 10))
	wall(Vector3.new(width, 40, 1), CFrame.new(0, 20, b.MinZ))
	wall(Vector3.new(width, 40, 1), CFrame.new(0, 20, Town.Sea.MinZ + 18)) -- out in the water
	-- the visible hedge (stops short of the beach so the sea stays open)
	for _, x in ipairs({ b.MinX, b.MaxX }) do
		prop(folder, "Hedge", Vector3.new(1.6, 2.6, b.MaxZ - 8 - b.MinZ), CFrame.new(x, 1.3, (b.MinZ + b.MaxZ - 8) / 2), COLORS.Hedge, Enum.Material.Grass)
	end
	prop(folder, "Hedge", Vector3.new(width, 2.6, 1.6), CFrame.new(0, 1.3, b.MinZ), COLORS.Hedge, Enum.Material.Grass)
	-- skyline: plain blocks of different heights outside the hedge
	local palette = { hex("#7B6F66"), hex("#8C4A3A"), hex("#5E6064"), hex("#A39D92"), hex("#6B5A4E") }
	local i = 0
	local function block(x, z, w, d)
		i += 1
		local h = 24 + (i * 17) % 38
		prop(folder, "Skyline", Vector3.new(w, h, d), CFrame.new(x, h / 2, z), palette[i % #palette + 1], Enum.Material.Concrete)
	end
	for z = b.MinZ + 10, b.MaxZ, 22 do
		block(b.MinX - 16, z, 20, 18)
		block(b.MaxX + 16, z, 20, 18)
	end
	for x = b.MinX + 10, b.MaxX - 10, 24 do
		block(x, b.MinZ - 16, 20, 18)
	end
end

function Builder.Build()
	folder = Kit.fresh(Workspace, "Folder", "Town")
	buildGround()
	buildGymFront()
	buildSmoothieBar()
	buildClothingStore()
	buildFurniture()
	buildSkatePark()
	buildBeach()
	buildBeachGym()
	buildStage()
	buildBoundary()
	return folder
end

return Builder
