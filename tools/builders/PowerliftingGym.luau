-- PowerliftingGym (prompt 58, 23 Oct): Workspace.PowerliftingGym, the gym that opens at Growth Spurt 5. A big old warehouse
-- at the town's north-west edge (behind the Main Street row, west of the starter gym): brick below, dark steel cladding
-- above, a high ceiling on steel beams, a roll-up loading door onto a new alley from Main Street, "POWERLIFTING" painted on
-- the front. Run once: require(this).Run(). Backups: ServerStorage.PowerliftingSiteBackup (the town building taken out for
-- the alley, the trees and rocks that stood on the site, the terrain before).
--   Inside (x -174..-66, z -96..-4, floor 0.15, ceiling 30; aisles 11+ studs for 7'0" players):
--     * WEST: 3 Comp Squat racks + the Strict Press on black rubber, facing the room; the slang banners above them.
--     * EAST: wooden deadlift platforms: 2 Comp Deadlifts, the Block Pull (wooden blocks beside it), the Pendlay Row.
--     * MIDDLE: 2 Comp Benches, the Weighted Pull-Up and the Weighted Crunch.
--     * FRONT: the roll-up door, the heavy dumbbell rack (4 spots, DumbbellSet = "Powerlifting"), plate trees, a bench and
--       a water fountain.
--     * BACK: the raised COMPETITION PLATFORM (Monolift Squat, Comp Bench, Comp Deadlift; attribute Platform = true:
--       the MEET bonus and judge lights), three judges' chairs with their lamps in front of it, the JUDGE LIGHTS panel,
--       the RECORD BOARD (SurfaceGui filled by PowerliftingService) and the PR BELL on the back wall.
--   Look: dark rubber floor, black steel and RED accents (the machines' gold accents turn red, red bumpers: MachineService),
--   bright white high-bay lamps (3 cast shadows), chalk bowls on stands, faint chalk dust in the air, loudspeakers.
--   Machines are copies of the Pro Gym's models (ProGym.ProMachines) re-skinned: their PRO badge and floor glow go.
--   Every decoration part: Anchored, no collisions, no shadows (the walls, floor, stage, steps and racks collide).
local PowerliftingGym = {}

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local N, S, E, W = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)

local X0, X1, Z0, Z1 = -174, -66, -96, -4 -- the inside
local CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2
local H = 30
local FLOOR_TOP = 0.15
local DOOR_X, DOOR_W, DOOR_H = -143, 14, 16

local INK = Color3.fromHex("#141416")
local STEEL = Color3.fromHex("#2B2E31")
local RED = Color3.fromHex("#B3201B")
local BRICK = Color3.fromHex("#6E3B2E")
local CLAD = Color3.fromHex("#3B3F44")
local WHITE = Color3.fromHex("#F2F5FF")
local CHALK = Color3.fromHex("#F2F0EA")
local WOOD = Color3.fromHex("#A9773F")

local root, made
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = p.Parent or made
	return p
end
local function solid(props)
	props.CanCollide, props.CanQuery = true, true
	return part(props)
end
local function folder(name: string, parent: Instance)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- moves a model so its bounding box centre is at (x, z), its pivot at height y (default: kept) and its front faces `face`
local function place(model: Model, x: number, z: number, face: Vector3, y: number?)
	local pivot = model:GetPivot()
	local box = model:GetBoundingBox()
	local o = pivot:PointToObjectSpace(box.Position)
	local rot = CFrame.lookAt(Vector3.zero, face)
	local d = rot:VectorToWorldSpace(Vector3.new(o.X, 0, o.Z))
	model:PivotTo(CFrame.new(x - d.X, y or pivot.Y, z - d.Z) * rot)
end

-- text on a part's front face
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local PAINT = Font.fromEnum(Enum.Font.Bangers)
local function gui(p: BasePart, ppS: number?, face: Enum.NormalId?)
	local g = Instance.new("SurfaceGui")
	g.Face, g.SizingMode, g.PixelsPerStud, g.LightInfluence = face or Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, ppS or 30, 0.6
	g.Parent = p
	return g
end
local function label(parent: Instance, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.TextScaled, l.FontFace, l.TextColor3 = 1, true, FONT, WHITE
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

-- the Pro Gym's machine models, re-skinned: gold accents red, chrome bars worn steel, no PRO badge, no floor glow
local function reskin(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "ProGlow" or d.Name == "ProBadge" then
				d:Destroy()
			elseif d.Name == "ProStitch" then
				d.Color = RED
			elseif d.Material == Enum.Material.Metal and d.Color:ToHex():lower() == "e2b23e" then
				d.Color = RED
			elseif d.Material == Enum.Material.Metal and d.Color:ToHex():lower() == "c9ccd2" then
				d.Color = Color3.fromHex("#9A9DA2")
			end
		end
	end
end

local MACHINES = {
	-- id, Pro template, x, z, facing, on the competition platform
	{ "PLSquat", "ProSquatRack", -164, -80, E }, { "PLSquat", "ProSquatRack", -164, -66, E }, { "PLSquat", "ProSquatRack", -164, -52, E },
	{ "PLPress", "ProOverheadPress", -164, -38, E },
	{ "PLDeadlift", "ProDeadlift", -78, -82, W }, { "PLDeadlift", "ProDeadlift", -78, -68, W }, { "PLBlockPull", "ProDeadlift", -78, -54, W },
	{ "PLRow", "ProBarbellRow", -78, -40, W },
	{ "PLBench", "ProFlatBench", -133, -55, N }, { "PLBench", "ProFlatBench", -112, -55, N },
	{ "PLPullUp", "ProPullUpBar", -133, -36, S }, { "PLCrunch", "ProCrunchBench", -112, -36, S },
	{ "PLMonolift", "ProSquatRack", -139, -87, S, true }, { "PLBench", "ProFlatBench", -126, -87, S, true }, { "PLDeadlift", "ProDeadlift", -113, -87, S, true },
}
local STAGE = { x0 = -151, x1 = -101, z0 = -95.5, z1 = -78, h = 1.5 }

function PowerliftingGym.Run()
	assert(not workspace:FindFirstChild("PowerliftingGym"), "already built")
	local pro = workspace.ProGym
	local backup = SS:FindFirstChild("PowerliftingSiteBackup") or Instance.new("Folder")
	backup.Name = "PowerliftingSiteBackup"
	backup.Parent = SS

	-- 0) the site: the town building where the alley goes, trees and rocks on the site, the terrain
	for _, b in ipairs(workspace.Town.Buildings:GetChildren()) do
		if b:IsA("Model") then
			local p = b:GetBoundingBox().Position
			if p.X > -153.5 and p.X < -132.5 and p.Z > 0 and p.Z < 20 then
				b:SetAttribute("WasIn", "Workspace.Town.Buildings")
				b.Parent = backup
			end
		end
	end
	for _, item in ipairs(workspace.Town.Greenery:GetChildren()) do
		local p = if item:IsA("Model") then item:GetPivot().Position elseif item:IsA("BasePart") then item.Position else nil
		if p and p.X > X0 - 4 and p.X < X1 + 4 and p.Z > Z0 - 4 and p.Z < Z1 + 6 then
			item:SetAttribute("WasIn", "Workspace.Town.Greenery")
			item.Parent = backup
		end
	end
	local T = workspace.Terrain
	local box = Region3int16.new(Vector3int16.new((X0 - 8) // 4, -2, (Z0 - 8) // 4), Vector3int16.new((X1 + 8) // 4, 16, (Z1 + 28) // 4))
	local ok, before = pcall(function() return T:CopyRegion(box) end)
	if ok and before then
		before.Name = "TerrainBefore"
		before:SetAttribute("Corner", Vector3.new((X0 - 8) // 4, -2, (Z0 - 8) // 4))
		before.Parent = backup
	end
	-- (exact voxels: everything from y -4 up is air, ground below; FillBlock left the surface at y 2, over the floor)
	local function flatten(x0, x1, z0, z1)
		local region = Region3.new(Vector3.new(x0, -12, z0), Vector3.new(x1, 60, z1)):ExpandToGrid(4)
		local mats, occ = T:ReadVoxels(region, 4)
		local y0 = region.CFrame.Position.Y - region.Size.Y / 2
		for ix = 1, mats.Size.X do
			for iz = 1, mats.Size.Z do
				for iy = 1, mats.Size.Y do
					local air = y0 + (iy - 1) * 4 >= -4
					mats[ix][iy][iz], occ[ix][iy][iz] = if air then Enum.Material.Air else Enum.Material.Ground, if air then 0 else 1
				end
			end
		end
		T:WriteVoxels(region, 4, mats, occ)
	end
	flatten(X0 - 2, X1 + 2, Z0 - 2, Z1 + 1)
	flatten(DOOR_X - 11, DOOR_X + 11, Z1, 22) -- (the alley)

	root = Instance.new("Model")
	root.Name = "PowerliftingGym"
	local shell = folder("Shell", root)
	made = shell

	-- 1) the shell
	solid({ Name = "Slab", Size = Vector3.new(X1 - X0 + 2, 1, Z1 - Z0 + 2), CFrame = CFrame.new(CX, -0.4, CZ), Material = Enum.Material.Concrete, Color = Color3.fromHex("#5A5C5F") })
	solid({ Name = "Floor", Size = Vector3.new(X1 - X0, 0.1, Z1 - Z0), CFrame = CFrame.new(CX, 0.1, CZ), Material = Enum.Material.Rubber, Color = Color3.fromHex("#19191B") })
	-- walls: brick up to 14, dark steel cladding above with high windows on the long sides
	local function wall(name, cx, cz, sx, sz, y0, y1, material, color)
		return solid({ Name = name, Size = Vector3.new(sx, y1 - y0, sz), CFrame = CFrame.new(cx, (y0 + y1) / 2, cz), Material = material, Color = color })
	end
	local function sideWall(x, name)
		wall(name .. "Brick", x, CZ, 1, Z1 - Z0 + 2, 0, 14, Enum.Material.Brick, BRICK)
		wall(name .. "Clad", x, CZ, 1, Z1 - Z0 + 2, 14, 20, Enum.Material.Metal, CLAD)
		wall(name .. "CladTop", x, CZ, 1, Z1 - Z0 + 2, 26, H, Enum.Material.Metal, CLAD)
		-- piers and frosted windows between 20 and 26
		local z = Z0 - 1
		while z < Z1 + 1 do
			local pier = math.min(4, Z1 + 1 - z)
			wall(name .. "Pier", x, z + pier / 2, 1, pier, 20, 26, Enum.Material.Metal, CLAD)
			z += pier
			if z + 8 <= Z1 + 1 - 2 then
				part({ Name = name .. "Window", Size = Vector3.new(0.3, 6, 8), CFrame = CFrame.new(x, 23, z + 4), Color = Color3.fromHex("#C9D6DF"),
					Transparency = 0.35, Material = Enum.Material.Glass, CanCollide = true })
				z += 8
			else
				wall(name .. "Pier", x, z + (Z1 + 1 - z) / 2, 1, Z1 + 1 - z, 20, 26, Enum.Material.Metal, CLAD)
				z = Z1 + 1
			end
		end
	end
	sideWall(X0 - 0.5, "West")
	sideWall(X1 + 0.5, "East")
	wall("BackBrick", CX, Z0 - 0.5, X1 - X0, 1, 0, 14, Enum.Material.Brick, BRICK)
	wall("BackClad", CX, Z0 - 0.5, X1 - X0, 1, 14, H, Enum.Material.Metal, CLAD)
	-- the front: brick and cladding either side of the loading door, cladding above it
	local dl, dr = DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2
	for _, seg in ipairs({ { X0 - 1, dl }, { dr, X1 + 1 } }) do
		local w, cx = seg[2] - seg[1], (seg[1] + seg[2]) / 2
		wall("FrontBrick", cx, Z1 + 0.5, w, 1, 0, 14, Enum.Material.Brick, BRICK)
		wall("FrontClad", cx, Z1 + 0.5, w, 1, 14, H, Enum.Material.Metal, CLAD)
	end
	wall("DoorHeader", DOOR_X, Z1 + 0.5, DOOR_W, 1, DOOR_H, H, Enum.Material.Metal, CLAD)
	solid({ Name = "Roof", Size = Vector3.new(X1 - X0 + 2, 1, Z1 - Z0 + 2), CFrame = CFrame.new(CX, H + 0.5, CZ), Material = Enum.Material.Metal, Color = Color3.fromHex("#2A2C2F") })
	solid({ Name = "Ceiling", Size = Vector3.new(X1 - X0, 0.2, Z1 - Z0), CFrame = CFrame.new(CX, H - 0.1, CZ), Material = Enum.Material.Metal, Color = Color3.fromHex("#2E3135") })
	for _, x in ipairs({ X0 - 1, X1 + 1 }) do
		part({ Name = "Parapet", Size = Vector3.new(0.8, 1.6, Z1 - Z0 + 2.8), CFrame = CFrame.new(x, H + 1.8, CZ), Material = Enum.Material.Metal, Color = STEEL })
	end
	for _, z in ipairs({ Z0 - 1, Z1 + 1 }) do
		part({ Name = "Parapet", Size = Vector3.new(X1 - X0 + 2.8, 1.6, 0.8), CFrame = CFrame.new(CX, H + 1.8, z), Material = Enum.Material.Metal, Color = STEEL })
	end
	-- steel beams across the hall and columns on the walls
	for z = Z0 + 8, Z1 - 6, 16 do
		part({ Name = "Beam", Size = Vector3.new(X1 - X0, 1.4, 0.7), CFrame = CFrame.new(CX, H - 1, z), Material = Enum.Material.Metal, Color = STEEL })
		part({ Name = "BeamFlange", Size = Vector3.new(X1 - X0, 0.18, 1.3), CFrame = CFrame.new(CX, H - 1.75, z), Material = Enum.Material.Metal, Color = STEEL })
		for _, x in ipairs({ X0 + 0.5, X1 - 0.5 }) do
			part({ Name = "Column", Size = Vector3.new(1, H - 1, 1), CFrame = CFrame.new(x, (H - 1) / 2, z), Material = Enum.Material.Metal, Color = STEEL })
		end
	end
	for x = X0 + 18, X1 - 10, 18 do
		part({ Name = "Purlin", Size = Vector3.new(0.5, 0.6, Z1 - Z0), CFrame = CFrame.new(x, H - 0.5, CZ), Material = Enum.Material.Metal, Color = STEEL })
	end

	-- 2) the loading door: a roll-up drum, the shutter (shown only while the gym is locked for you: PowerliftingClient)
	-- and the invisible Blocker (solid for locked players, PowerliftingClient turns it off for the rest)
	local door = Instance.new("Model")
	door.Name = "LoadingDoor"
	door.Parent = root
	part({ Name = "Drum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(DOOR_W + 1, 1.8, 1.8), CFrame = CFrame.new(DOOR_X, DOOR_H + 0.9, Z1 - 0.6),
		Material = Enum.Material.Metal, Color = STEEL, Parent = door })
	part({ Name = "DoorLip", Size = Vector3.new(DOOR_W, 1, 0.2), CFrame = CFrame.new(DOOR_X, DOOR_H - 0.5, Z1 + 0.2), Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromHex("#8E9196"), Parent = door })
	local shutter = part({ Name = "Shutter", Size = Vector3.new(DOOR_W, DOOR_H - 1, 0.25), CFrame = CFrame.new(DOOR_X, (DOOR_H - 1) / 2, Z1 + 0.3),
		Material = Enum.Material.CorrodedMetal, Color = Color3.fromHex("#8E9196"), Parent = door })
	for y = 1, DOOR_H - 2, 1.2 do
		part({ Name = "Slat", Size = Vector3.new(DOOR_W, 0.12, 0.08), CFrame = CFrame.new(DOOR_X, y, Z1 + 0.46), Material = Enum.Material.Metal, Color = Color3.fromHex("#6E7176"), Parent = shutter })
	end
	local lock = gui(shutter, 24)
	lock.Face = Enum.NormalId.Back -- (the street side)
	label(lock, { Name = "Locked", Text = "LOCKED", TextColor3 = RED, Position = UDim2.fromScale(0.1, 0.32), Size = UDim2.fromScale(0.8, 0.16) })
	solid({ Name = "Blocker", Size = Vector3.new(DOOR_W, DOOR_H, 1.4), CFrame = CFrame.new(DOOR_X, DOOR_H / 2, Z1 + 0.5), Transparency = 1, Parent = door })
	-- the area sign over the door (AreaSignsClient: "Unlocks at Growth Spurt 5" while locked)
	local area = part({ Name = "AreaSign", Size = Vector3.new(16, 3, 0.3), CFrame = CFrame.lookAt(Vector3.new(DOOR_X, DOOR_H + 3.2, Z1 + 1.2), Vector3.new(DOOR_X, DOOR_H + 3.2, Z1 + 5)),
		Color = INK, Parent = door })
	area:SetAttribute("Gym", "Powerlifting")
	area:SetAttribute("Title", "POWERLIFTING GYM")
	CS:AddTag(area, "AreaSign")
	local ag = gui(area, 30)
	ag.LightInfluence = 0
	label(ag, { Name = "Title", Text = "POWERLIFTING GYM", Position = UDim2.fromScale(0.03, 0.05), Size = UDim2.fromScale(0.94, 0.9) })
	label(ag, { Name = "Rule", Text = "Unlocks at Growth Spurt 5", TextColor3 = Color3.fromHex("#FF6B5E"), Visible = false,
		Position = UDim2.fromScale(0.03, 0.62), Size = UDim2.fromScale(0.94, 0.34) })
	CS:AddTag(area, "NightSign")
	-- "POWERLIFTING" painted on the front cladding, and two wall lamps by the door
	local paint = part({ Name = "PaintedSign", Size = Vector3.new(52, 7, 0.05), CFrame = CFrame.lookAt(Vector3.new(-103, 22.5, Z1 + 1.03), Vector3.new(-103, 22.5, Z1 + 5)), Transparency = 1, Parent = shell })
	local pg = gui(paint, 20)
	label(pg, { Text = "POWERLIFTING", FontFace = PAINT, TextColor3 = Color3.fromHex("#F1ECE2"), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.86, 1) })
	label(pg, { Text = "EST. GYM ARC", FontFace = PAINT, TextColor3 = RED, Position = UDim2.fromScale(0.86, 0.3), Size = UDim2.fromScale(0.14, 0.4) })
	CS:AddTag(paint, "NightSign")
	for _, x in ipairs({ dl - 2, dr + 2 }) do
		part({ Name = "WallLampArm", Size = Vector3.new(0.2, 0.2, 1.2), CFrame = CFrame.new(x, 13.5, Z1 + 1.6), Material = Enum.Material.Metal, Color = INK })
		local lamp = part({ Name = "WallLamp", Size = Vector3.new(1.4, 0.6, 1), CFrame = CFrame.new(x, 13.3, Z1 + 2.2), Color = Color3.fromHex("#D9DEE6") })
		lamp:SetAttribute("NightColor", WHITE)
		lamp:SetAttribute("DayColor", Color3.fromHex("#D9DEE6"))
		CS:AddTag(lamp, "NightLight")
		local light = Instance.new("SpotLight")
		light.Face, light.Angle, light.Range, light.Brightness, light.Color, light.Enabled = Enum.NormalId.Bottom, 100, 16, 1.2, WHITE, false
		light.Parent = lamp
	end
	-- the alley from Main Street to the door
	part({ Name = "Alley", Size = Vector3.new(20, 0.2, 24), CFrame = CFrame.new(DOOR_X, 0.05, 9), Material = Enum.Material.Concrete, Color = Color3.fromHex("#6F7174"), CanCollide = true, CanQuery = true })
	for _, x in ipairs({ DOOR_X - 9.6, DOOR_X + 9.6 }) do
		part({ Name = "AlleyCurb", Size = Vector3.new(0.8, 0.4, 24), CFrame = CFrame.new(x, 0.2, 9), Material = Enum.Material.Concrete, Color = Color3.fromHex("#8D8F92") })
	end

	-- 3) machines
	local mfolder = folder("Machines", root)
	local templates = pro.ProMachines
	for _, def in ipairs(MACHINES) do
		local template = templates:FindFirstChild(def[2])
		assert(template, "no template " .. def[2])
		local m = template:Clone()
		m.Name = def[1]
		for name in pairs(m:GetAttributes()) do
			if name ~= "RailAxis" and name ~= "RailMax" and name ~= "RailMin" and name ~= "RailOffset" and name ~= "RailAnchor" and name ~= "SleeveStart" then m:SetAttribute(name, nil) end
		end
		m:SetAttribute("MachineId", def[1])
		m:SetAttribute("Gym", "Powerlifting")
		if def[6] then m:SetAttribute("Platform", true) end
		reskin(m)
		m.Parent = mfolder
		place(m, def[3], def[4], def[5], if def[6] then STAGE.h - 0.05 else nil)
	end
	-- the heavy dumbbell rack on the front wall, east of the door (the Pro rack and its 4 spots, turned round)
	local rack = pro.Props:FindFirstChild("DumbbellRack") and pro.ProMachines:FindFirstChild("ProDumbbellRack") or nil
	if rack then
		local center = rack:GetBoundingBox().Position
		local turn = CFrame.new(Vector3.new(-110, center.Y, Z1 - 1.6)) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-center)
		local r = rack:Clone()
		r.Name = "HeavyDumbbellRack"
		reskin(r)
		r:PivotTo(turn * r:GetPivot())
		r.Parent = mfolder
		for i = 1, 4 do
			local spot = pro.ProMachines:FindFirstChild("ProDumbbellSpot" .. i)
			if spot then
				local s = spot:Clone()
				s.Name = "HeavyDumbbellSpot" .. i
				s:SetAttribute("MachineId", "PLDBCurl")
				s:SetAttribute("DumbbellSet", "Powerlifting")
				s:SetAttribute("Gym", "Powerlifting")
				s:SetAttribute("UserId", nil)
				s:PivotTo(turn * s:GetPivot())
				s.Parent = mfolder
			end
		end
	end

	-- 4) floors under the stations, the competition platform, judges
	made = folder("Props", root)
	for _, def in ipairs(MACHINES) do
		if not def[6] then
			local id = def[1]
			if id == "PLDeadlift" or id == "PLBlockPull" or id == "PLRow" then
				-- a wooden lifting platform with rubber sides (8 x 11)
				part({ Name = "LiftPlatformWood", Size = Vector3.new(4.5, 0.2, 11), CFrame = CFrame.new(def[3], 0.25, def[4]), Material = Enum.Material.WoodPlanks, Color = WOOD, CanCollide = true })
				for _, dx in ipairs({ -3.4, 3.4 }) do
					part({ Name = "LiftPlatformRubber", Size = Vector3.new(2.3, 0.2, 11), CFrame = CFrame.new(def[3] + dx, 0.25, def[4]), Material = Enum.Material.Rubber, Color = INK, CanCollide = true })
				end
			elseif id == "PLSquat" or id == "PLPress" then
				part({ Name = "RackMat", Size = Vector3.new(10, 0.12, 10), CFrame = CFrame.new(def[3], 0.2, def[4]), Material = Enum.Material.Rubber, Color = Color3.fromHex("#0F0F11") })
			end
			if id == "PLBlockPull" then
				for _, dz in ipairs({ -4.6, 4.6 }) do
					part({ Name = "PullBlock", Size = Vector3.new(2.6, 1.2, 1.8), CFrame = CFrame.new(def[3] + 5.4, 0.95, def[4] + dz), Material = Enum.Material.WoodPlanks, Color = WOOD })
				end
			end
		end
	end
	local sx, sz = (STAGE.x0 + STAGE.x1) / 2, (STAGE.z0 + STAGE.z1) / 2
	local stage = solid({ Name = "CompStage", Size = Vector3.new(STAGE.x1 - STAGE.x0, STAGE.h, STAGE.z1 - STAGE.z0), CFrame = CFrame.new(sx, FLOOR_TOP + STAGE.h / 2 - 0.05, sz),
		Material = Enum.Material.SmoothPlastic, Color = INK, Parent = made })
	local _ = stage
	part({ Name = "CompStageEdge", Size = Vector3.new(STAGE.x1 - STAGE.x0 + 0.1, 0.35, 0.1), CFrame = CFrame.new(sx, FLOOR_TOP + STAGE.h - 0.3, STAGE.z1 + 0.02), Color = RED })
	for _, def in ipairs(MACHINES) do
		if def[6] then
			part({ Name = "CompPlatformWood", Size = Vector3.new(11, 0.1, 11), CFrame = CFrame.new(def[3], FLOOR_TOP + STAGE.h, def[4]), Material = Enum.Material.WoodPlanks, Color = WOOD })
		end
	end
	for i, y in ipairs({ 0.5, 1.0 }) do
		solid({ Name = "StageStep", Size = Vector3.new(10, y, 1.4), CFrame = CFrame.new(STAGE.x0 + 6, FLOOR_TOP + y / 2 - 0.05, STAGE.z1 + 0.7 + (2 - i) * 1.4), Color = INK, Parent = made })
		solid({ Name = "StageStep", Size = Vector3.new(10, y, 1.4), CFrame = CFrame.new(STAGE.x1 - 6, FLOOR_TOP + y / 2 - 0.05, STAGE.z1 + 0.7 + (2 - i) * 1.4), Color = INK, Parent = made })
	end
	-- the judges: a chair and a small table with a lamp each, facing the platform
	local judges = folder("Judges", root)
	for i, x in ipairs({ -136, -126, -116 }) do
		local z = -70.5
		part({ Name = "ChairSeat", Size = Vector3.new(2, 0.3, 2), CFrame = CFrame.new(x, 1.9, z), Material = Enum.Material.Fabric, Color = INK, Parent = judges })
		part({ Name = "ChairBack", Size = Vector3.new(2, 2.4, 0.25), CFrame = CFrame.new(x, 3.2, z + 0.9), Material = Enum.Material.Fabric, Color = INK, Parent = judges })
		for _, o in ipairs({ { -0.8, -0.8 }, { 0.8, -0.8 }, { -0.8, 0.8 }, { 0.8, 0.8 } }) do
			part({ Name = "ChairLeg", Size = Vector3.new(0.15, 1.75, 0.15), CFrame = CFrame.new(x + o[1], 0.9, z + o[2]), Material = Enum.Material.Metal, Color = STEEL, Parent = judges })
		end
		part({ Name = "JudgeTable", Size = Vector3.new(2.6, 0.2, 1.6), CFrame = CFrame.new(x, 2.9, z - 2.4), Material = Enum.Material.Wood, Color = Color3.fromHex("#3A2A20"), Parent = judges })
		part({ Name = "JudgeTableLeg", Size = Vector3.new(0.25, 2.8, 0.25), CFrame = CFrame.new(x, 1.5, z - 2.4), Material = Enum.Material.Metal, Color = STEEL, Parent = judges })
		part({ Name = "JudgeLamp" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(x, 3.45, z - 2.6), Color = Color3.fromHex("#3A3A3C"), Parent = judges })
	end
	-- the judge lights panel on the back wall, under the record board
	local panel = part({ Name = "JudgePanel", Size = Vector3.new(13, 4.4, 0.4), CFrame = CFrame.lookAt(Vector3.new(-126, 11.6, Z0 + 0.25), Vector3.new(-126, 11.6, 0)),
		Color = INK, Parent = judges })
	local _2 = panel
	for i, x in ipairs({ -130, -126, -122 }) do
		part({ Name = "JudgeLight" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(2.8, 2.8, 2.8), CFrame = CFrame.new(x, 11.6, Z0 + 0.7), Color = Color3.fromHex("#3A3A3C"), Parent = judges })
	end
	local verdict = part({ Name = "JudgeVerdict", Size = Vector3.new(13, 1.4, 0.1), CFrame = CFrame.lookAt(Vector3.new(-126, 8.9, Z0 + 0.5), Vector3.new(-126, 8.9, 0)), Color = INK, Parent = judges })
	local vg = gui(verdict, 30)
	vg.LightInfluence = 0
	label(vg, { Name = "Text", Text = "", TextColor3 = WHITE, Position = UDim2.fromScale(0, 0.05), Size = UDim2.fromScale(1, 0.9) })

	-- 5) the RECORD BOARD (PowerliftingService fills it): a column per lift, the server record on top, the all-time top 3
	local board = part({ Name = "RecordBoard", Size = Vector3.new(48, 12.5, 0.4), CFrame = CFrame.lookAt(Vector3.new(-126, 21.2, Z0 + 0.25), Vector3.new(-126, 21.2, 0)),
		Color = Color3.fromHex("#0C0C0E"), Parent = made })
	for _, e in ipairs({ { 0, 6.2, 48, 0.14 }, { 0, -6.2, 48, 0.14 }, { -23.95, 0, 0.14, 12.5 }, { 23.95, 0, 0.14, 12.5 } }) do
		part({ Name = "RecordBoardTrim", Size = Vector3.new(e[3], e[4], 0.05), CFrame = board.CFrame * CFrame.new(e[1], e[2], -0.23), Material = Enum.Material.Metal, Color = RED })
	end
	local bg = gui(board, 24)
	bg.LightInfluence = 0.2
	bg.Name = "Board"
	label(bg, { Name = "Title", Text = "RECORD BOARD", TextColor3 = WHITE, Position = UDim2.fromScale(0.02, 0.03), Size = UDim2.fromScale(0.96, 0.13) })
	for i, lift in ipairs({ "Squat", "Bench", "Deadlift" }) do
		local col = Instance.new("Frame")
		col.Name = lift
		col.BackgroundTransparency, col.Position, col.Size = 1, UDim2.fromScale(0.02 + (i - 1) * 0.33, 0.19), UDim2.fromScale(0.3, 0.79)
		col.Parent = bg
		label(col, { Name = "Lift", Text = string.upper(lift), TextColor3 = RED, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.15) })
		label(col, { Name = "ServerTag", Text = "SERVER RECORD", TextColor3 = Color3.fromHex("#9A9DA2"), Position = UDim2.fromScale(0, 0.17), Size = UDim2.fromScale(1, 0.08) })
		label(col, { Name = "Server", Text = "-", TextColor3 = WHITE, Position = UDim2.fromScale(0, 0.26), Size = UDim2.fromScale(1, 0.18) })
		label(col, { Name = "AllTimeTag", Text = "ALL-TIME", TextColor3 = Color3.fromHex("#9A9DA2"), Position = UDim2.fromScale(0, 0.48), Size = UDim2.fromScale(1, 0.08) })
		for place = 1, 3 do
			label(col, { Name = "Top" .. place, Text = place .. ".  -", TextColor3 = Color3.fromHex("#D9DCE0"), TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromScale(0.04, 0.57 + (place - 1) * 0.14), Size = UDim2.fromScale(0.92, 0.12) })
		end
	end
	local flash = part({ Name = "RecordFlash", Size = Vector3.new(48.6, 13.1, 0.1), CFrame = board.CFrame * CFrame.new(0, 0, -0.3), Material = Enum.Material.Neon, Color = Color3.fromHex("#F6C75A"),
		Transparency = 1 })
	local _3 = flash

	-- 6) the PR BELL on the back wall, east of the board, with its sign
	local bell = Instance.new("Model")
	bell.Name = "PRBell"
	bell.Parent = root
	local bx, by, bz = -94, 14, Z0 + 1.6
	part({ Name = "Bracket", Size = Vector3.new(0.4, 0.4, 2.4), CFrame = CFrame.new(bx, by + 2.2, Z0 + 1.1), Material = Enum.Material.Metal, Color = STEEL, Parent = bell })
	part({ Name = "Yoke", Size = Vector3.new(1.6, 0.4, 0.4), CFrame = CFrame.new(bx, by + 2.0, bz), Material = Enum.Material.Metal, Color = STEEL, Parent = bell })
	local swing = Instance.new("Model")
	swing.Name = "Swing"
	swing.Parent = bell
	part({ Name = "BellTop", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(bx, by + 1.2, bz), Material = Enum.Material.Metal, Color = Color3.fromHex("#C9A13A"), Parent = swing })
	part({ Name = "BellBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 2.1, 2.1), CFrame = CFrame.new(bx, by + 0.3, bz) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal, Color = Color3.fromHex("#C9A13A"), Parent = swing })
	part({ Name = "BellLip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.7, 2.7), CFrame = CFrame.new(bx, by - 0.65, bz) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal, Color = Color3.fromHex("#B38B2C"), Parent = swing })
	part({ Name = "Clapper", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(bx, by - 0.9, bz), Material = Enum.Material.Metal, Color = STEEL, Parent = swing })
	part({ Name = "BellGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(4.2, 4.2, 4.2), CFrame = CFrame.new(bx, by + 0.3, bz), Material = Enum.Material.Neon,
		Color = Color3.fromHex("#F6C75A"), Transparency = 1, Parent = bell })
	swing.PrimaryPart = swing:FindFirstChild("BellTop")
	local plaque = part({ Name = "BellSign", Size = Vector3.new(4.6, 1.2, 0.2), CFrame = CFrame.lookAt(Vector3.new(bx, by - 2.2, Z0 + 0.15), Vector3.new(bx, by - 2.2, 0)), Color = INK, Parent = bell })
	label(gui(plaque, 30), { Text = "PR BELL", TextColor3 = RED, Position = UDim2.fromScale(0.05, 0.1), Size = UDim2.fromScale(0.9, 0.8) })
	bell:ScaleTo(1.6)

	-- 7) the slang banners (west wall above the racks, two on the east wall), loudspeakers, chalk stands, plate trees
	local banners = { { "LIFT HEAVY", W, -84 }, { "CHALK UP", W, -66 }, { "NO EGO, JUST WEIGHT", W, -48 }, { "ONE MORE REP", W, -30 },
		{ "LOCK IN", E, -76 }, { "NO DAYS OFF", E, -46 } }
	for _, b in ipairs(banners) do
		local x = if b[2] == W then X0 + 0.15 else X1 - 0.15
		local facing = if b[2] == W then E else W
		local p = part({ Name = "Banner", Size = Vector3.new(7, 11, 0.08), CFrame = CFrame.lookAt(Vector3.new(x, 19.5, b[3]), Vector3.new(x, 19.5, b[3]) + facing),
			Material = Enum.Material.Fabric, Color = INK })
		part({ Name = "BannerRod", Size = Vector3.new(7.6, 0.25, 0.25), CFrame = p.CFrame * CFrame.new(0, 5.6, 0), Material = Enum.Material.Metal, Color = STEEL })
		local g = gui(p, 24)
		local edge = Instance.new("Frame")
		edge.BackgroundColor3, edge.Size, edge.Position = RED, UDim2.fromScale(1, 0.06), UDim2.fromScale(0, 0.9)
		edge.Parent = g
		label(g, { Text = b[1], TextWrapped = true, Position = UDim2.fromScale(0.08, 0.08), Size = UDim2.fromScale(0.84, 0.78) })
	end
	for _, s in ipairs({ { X0 + 1.2, -90, E }, { X0 + 1.2, -10, E }, { X1 - 1.2, -90, W }, { X1 - 1.2, -10, W } }) do
		local cf = CFrame.lookAt(Vector3.new(s[1], 23, s[2]), Vector3.new(s[1], 23, s[2]) + s[3] - Vector3.new(0, 0.4, 0))
		part({ Name = "Speaker", Size = Vector3.new(2, 3, 1.8), CFrame = cf, Color = INK })
		part({ Name = "SpeakerGrille", Size = Vector3.new(1.7, 2.6, 0.05), CFrame = cf * CFrame.new(0, 0, -0.92), Material = Enum.Material.DiamondPlate, Color = Color3.fromHex("#2A2A2D") })
	end
	local chalkBowl = pro.Props:FindFirstChild("ChalkBowl")
	for _, xz in ipairs({ { -153, -59 }, { -89, -61 }, { -122, -45 }, { -96, -86 } }) do
		part({ Name = "ChalkStand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 0.7, 0.7), CFrame = CFrame.new(xz[1], 1.45, xz[2]) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Metal, Color = STEEL, CanCollide = true })
		part({ Name = "ChalkBowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.2, 2.2), CFrame = CFrame.new(xz[1], 3, xz[2]) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Metal, Color = INK })
		part({ Name = "Chalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.9, 1.9), CFrame = CFrame.new(xz[1], 3.28, xz[2]) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Sand, Color = CHALK })
	end
	local _4 = chalkBowl
	local tree = pro.Props:FindFirstChild("PlateTree")
	if tree then
		for _, xz in ipairs({ { -160, -14 }, { -86, -14 }, { -146, -66 } }) do
			local t = tree:Clone()
			t.Parent = made
			reskin(t)
			-- its plates red bumpers like the bars'
			for _, d in ipairs(t:GetDescendants()) do
				local m = d:IsA("BasePart") and d:FindFirstAncestorWhichIsA("Model")
				if m and m ~= t and string.match(m.Name, "^Plate%d") then
					d.Color, d.Material = if d.Name == "Body" then RED else INK, Enum.Material.SmoothPlastic
				end
			end
			place(t, xz[1], xz[2], S)
		end
	end
	local benchProp = pro.Props:FindFirstChild("Bench")
	if benchProp then
		local b = benchProp:Clone()
		b.Parent = made
		place(b, -166, -10, E)
	end
	local fountain = pro.Props:FindFirstChild("WaterFountain")
	if fountain then
		local f = fountain:Clone()
		f.Parent = made
		place(f, X0 + 1.5, -20, E)
	end

	-- 8) light: white high-bay lamps in rows over the whole hall (3 with shadows), daylight from the high windows
	local lights = folder("Lights", root)
	made = lights
	local n = 0
	for _, z in ipairs({ -88, -72, -56, -40, -24, -12 }) do
		for _, x in ipairs({ -158, -139, -120, -101, -82 }) do
			n += 1
			part({ Name = "LampRod", Size = Vector3.new(0.12, 4.2, 0.12), CFrame = CFrame.new(x, H - 3.9, z + 1.2), Material = Enum.Material.Metal, Color = STEEL })
			part({ Name = "LampShade", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 2.8, 2.8), CFrame = CFrame.new(x, H - 6.2, z + 1.2) * CFrame.Angles(0, 0, math.rad(90)),
				Material = Enum.Material.Metal, Color = Color3.fromHex("#5D6166") })
			local glow = part({ Name = "LampGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2.3, 2.3), CFrame = CFrame.new(x, H - 6.9, z + 1.2) * CFrame.Angles(0, 0, math.rad(90)),
				Material = Enum.Material.Neon, Color = WHITE })
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color = 30, 1.15, WHITE
			light.Shadows = (z == -56 and (x == -139 or x == -101)) or (z == -88 and x == -120)
			light.Parent = glow
		end
	end
	-- the competition platform's two spotlights
	for _, x in ipairs({ -134, -118 }) do
		local can = part({ Name = "StageSpot", Size = Vector3.new(1, 0.8, 1), CFrame = CFrame.new(x, H - 2.6, -80), Material = Enum.Material.Metal, Color = INK })
		local light = Instance.new("SpotLight")
		light.Face, light.Angle, light.Range, light.Brightness, light.Color, light.Shadows = Enum.NormalId.Bottom, 60, 34, 1.6, WHITE, false
		light.Parent = can
	end
	-- chalk dust in the air (faint, slow, cheap)
	for _, xz in ipairs({ { -150, -60 }, { -90, -60 }, { -126, -84 } }) do
		local emitterPart = part({ Name = "ChalkDust", Size = Vector3.new(26, 1, 26), CFrame = CFrame.new(xz[1], 9, xz[2]), Transparency = 1 })
		local e = Instance.new("ParticleEmitter")
		e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 3, NumberRange.new(8, 12), NumberRange.new(0.1, 0.4), Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.4) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(1, 1) })
		e.Color, e.LightEmission, e.LightInfluence, e.Drag, e.Acceleration = ColorSequence.new(CHALK), 0.1, 1, 1, Vector3.new(0, -0.04, 0)
		e.Parent = emitterPart
	end

	root.Parent = workspace

	-- 9) the gym-goers' spots (GymGoerService reads Workspace.Gym.NpcSpots)
	local npcSpots = workspace.Gym:FindFirstChild("NpcSpots")
	if npcSpots then
		for _, s in ipairs({ { "Pose", -126, -75.5 }, { "Chat", -122, -24 }, { "Chat", -96, -30 }, { "Rest", -164, -12 }, { "Water", -170, -20 } }) do
			local p = Instance.new("Part")
			p.Name = s[1]
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
			p.Size = Vector3.new(1, 0.2, 1)
			p.CFrame = CFrame.new(s[2], 0.2, s[3])
			p:SetAttribute("Kind", s[1])
			p:SetAttribute("Gym", "Powerlifting")
			p.Parent = npcSpots
		end
	end

	-- 10) the 100 lb bumper plate template (GymAssets.Plates.Plate100: Plate55's build, thicker; red in this gym)
	local plates = game:GetService("ReplicatedStorage"):FindFirstChild("GymAssets") and game.ReplicatedStorage.GymAssets:FindFirstChild("Plates")
	if plates and plates:FindFirstChild("Plate55") and not plates:FindFirstChild("Plate100") then
		local p = plates.Plate55:Clone()
		p.Name = "Plate100"
		local pivot = p:GetPivot()
		local k = 0.28 / 0.2
		for _, d in ipairs(p:GetDescendants()) do
			if d:IsA("BasePart") then
				local o = pivot:PointToObjectSpace(d.Position)
				local thin = d.Name == "FaceLeft" or d.Name == "FaceRight" or d.Name == "Rim" or d.Name == "RimInner"
				if not thin then d.Size = Vector3.new(d.Size.X * k, d.Size.Y, d.Size.Z) end
				d.CFrame = pivot * CFrame.new(o.X * k, o.Y, o.Z) * (pivot:Inverse() * d.CFrame).Rotation
				if d.Name == "Body" or d.Name == "Edge" then d.Color = INK end
			elseif d:IsA("TextLabel") and d.Name == "Weight" then
				d.Text = "100"
			end
		end
		p.Parent = plates
	end
	return "built: " .. #root:GetDescendants() .. " instances, " .. n .. " lamps"
end

return PowerliftingGym
