-- PumpShop builder (prompt 19, 21 Oct; run once in Studio, Edit mode): the PUMP SHOP building in the town hub, on the old
-- parking lot between the gyms (on the way from the gyms to the Beach Gym). The parking lot is NOT deleted: it is moved to
-- ServerStorage.PumpShopBackup (move it back to Workspace.Town to undo; the street lamps and bus stop that stood on its edge
-- are there too, with the attribute FromFolder = "Town.Street").
-- Builds Workspace.Town.PumpShop:
--   * a 64 x 68 stud store: graphite walls, a glass front with open doors facing the street (+X), a lit "PUMP SHOP" sign
--     on the roof (Black + Gold), ceiling lights (no shadows)
--   * 4 sections, each a counter (tag PumpShopCounter, attribute Section) with a sign over it and a ClerkSpot behind it
--     (PumpShopService puts a clerk there): SUPPLEMENTS (tubs and shakers on shelves), GEAR (belts, wraps and straps on
--     wall hooks), APPAREL (mannequins in shorts and tank tops), DNA LAB (glowing sample tubes)
--   * an empty corner with a "COMING SOON" sign: room for the 5th section, ALTERS
--   * Entrance: an invisible part on the pavement in front of the doors (the HUD's PUMP SHOP button lands here)
-- Usage (command bar): require(game.ServerStorage._Builders.PumpShop).Build()   (or paste the body into the bar)
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local PumpShop = {}

local CENTER = Vector3.new(-104, 0, 118)  -- floor centre (the old parking lot)
local SIZE = Vector3.new(64, 22, 68)      -- x (depth, front at +X), wall height, z (width)
local GOLD = Color3.fromHex("#F6C75A")
local GOLD_DARK = Color3.fromHex("#C98A12")
local GRAPHITE = Color3.fromHex("#26262B")
local GRAPHITE_LIGHT = Color3.fromHex("#3A3A42")

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in pairs(props or {}) do p[key] = value end
	p.Parent = parent
	return p
end

local function cylinder(parent, name, height, diameter, position, color, material)
	return part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color,
		material or Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CastShadow = false })
end

local function sign(parent, name, size, cframe, text, textColor, back)
	local board = part(parent, name, size, cframe, back or GRAPHITE, Enum.Material.SmoothPlastic, { CastShadow = false })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 12 -- (low: TextScaled stops at 100 px, so big signs need few pixels per stud)
		gui.LightInfluence = 0
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = textColor or GOLD
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 2
		stroke.Parent = label
	end
	return board
end

local function light(parent, position, range, brightness)
	local holder = part(parent, "CeilingLight", Vector3.new(6, 0.3, 1.2), CFrame.new(position), Color3.new(1, 1, 1), Enum.Material.Neon, { CastShadow = false })
	local l = Instance.new("PointLight")
	l.Range = range or 26
	l.Brightness = brightness or 1.3
	l.Shadows = false
	l.Color = Color3.fromHex("#FFF3DC")
	l.Parent = holder
	return holder
end

-- a person-shaped mannequin (blocks) wearing shorts and a tank top
local function mannequin(parent, feet: Vector3, facing: Vector3, shorts: Color3, top: Color3?)
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local skin = Color3.fromHex("#D9D4CC")
	local base = CFrame.lookAt(feet, feet + facing)
	local function block(name, size, offset, color)
		return part(model, name, size, base * CFrame.new(offset), color, Enum.Material.SmoothPlastic, { CastShadow = false })
	end
	block("Stand", Vector3.new(2.4, 0.3, 2.4), Vector3.new(0, 0.15, 0), GRAPHITE)
	block("Pole", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 0.9, 0), Color3.fromHex("#C9CCD2"))
	block("LeftLeg", Vector3.new(0.9, 2.4, 0.9), Vector3.new(-0.55, 2.7, 0), skin)
	block("RightLeg", Vector3.new(0.9, 2.4, 0.9), Vector3.new(0.55, 2.7, 0), skin)
	block("Shorts", Vector3.new(2.3, 1.2, 1.05), Vector3.new(0, 3.6, 0), shorts)
	block("Torso", Vector3.new(2.6, 2.6, 1.2), Vector3.new(0, 5.4, 0), top or skin)
	block("LeftArm", Vector3.new(0.8, 2.5, 0.8), Vector3.new(-1.75, 5.3, 0), skin)
	block("RightArm", Vector3.new(0.8, 2.5, 0.8), Vector3.new(1.75, 5.3, 0), skin)
	block("Head", Vector3.new(1.1, 1.2, 1.1), Vector3.new(0, 7.3, 0), skin)
	model.Parent = parent
	return model
end

function PumpShop.Build()
	local town = workspace:FindFirstChild("Town")
	assert(town, "Workspace.Town is missing")
	-- the parking lot steps aside (kept, not deleted)
	local parking = town:FindFirstChild("Parking")
	if parking then
		local backup = ServerStorage:FindFirstChild("PumpShopBackup") or Instance.new("Folder")
		backup.Name = "PumpShopBackup"
		backup.Parent = ServerStorage
		parking.Parent = backup
	end
	-- street lamps and the bus stop that stood on the lot's edge (inside the new walls) go to the backup too
	local backup = ServerStorage:FindFirstChild("PumpShopBackup")
	local street = town:FindFirstChild("Street")
	if backup and street then
		for _, item in ipairs(street:GetChildren()) do
			if item.Name ~= "StreetLamp" and item.Name ~= "BusStop" then continue end -- (the pavement around it stays)
			local ok, pivot = pcall(function() return item:GetPivot().Position end)
			if ok and pivot.X > CENTER.X - SIZE.X / 2 - 1 and pivot.X < CENTER.X + SIZE.X / 2 + 1 and pivot.Z > CENTER.Z - SIZE.Z / 2 - 1
				and pivot.Z < CENTER.Z + SIZE.Z / 2 + 1 then
				item:SetAttribute("FromFolder", "Town.Street")
				item.Parent = backup
			end
		end
	end
	local old = town:FindFirstChild("PumpShop")
	if old then old:Destroy() end
	local shop = Instance.new("Model")
	shop.Name = "PumpShop"

	local floorY = 0.4
	local x0, x1 = CENTER.X - SIZE.X / 2, CENTER.X + SIZE.X / 2 -- back wall, front
	local z0, z1 = CENTER.Z - SIZE.Z / 2, CENTER.Z + SIZE.Z / 2
	local h = SIZE.Y
	local structure = Instance.new("Folder")
	structure.Name = "Building"
	structure.Parent = shop

	-- floor (dark polished concrete with a gold runner to the counters), walls, roof
	part(structure, "Floor", Vector3.new(SIZE.X, 0.4, SIZE.Z), CFrame.new(CENTER.X, 0.2, CENTER.Z), Color3.fromHex("#2E2E33"), Enum.Material.Concrete)
	part(structure, "Runner", Vector3.new(SIZE.X - 8, 0.05, 6), CFrame.new(CENTER.X + 4, floorY + 0.03, CENTER.Z), GOLD_DARK, Enum.Material.Fabric, { CastShadow = false })
	part(structure, "BackWall", Vector3.new(1, h, SIZE.Z), CFrame.new(x0 + 0.5, floorY + h / 2, CENTER.Z), GRAPHITE, Enum.Material.Concrete)
	part(structure, "LeftWall", Vector3.new(SIZE.X, h, 1), CFrame.new(CENTER.X, floorY + h / 2, z0 + 0.5), GRAPHITE, Enum.Material.Concrete)
	part(structure, "RightWall", Vector3.new(SIZE.X, h, 1), CFrame.new(CENTER.X, floorY + h / 2, z1 - 0.5), GRAPHITE, Enum.Material.Concrete)
	part(structure, "Roof", Vector3.new(SIZE.X + 2, 1, SIZE.Z + 2), CFrame.new(CENTER.X, floorY + h + 0.5, CENTER.Z), Color3.fromHex("#1B1B1F"), Enum.Material.Concrete)
	part(structure, "Ceiling", Vector3.new(SIZE.X - 2, 0.2, SIZE.Z - 2), CFrame.new(CENTER.X, floorY + h - 0.1, CENTER.Z), Color3.fromHex("#2A2A30"),
		Enum.Material.SmoothPlastic, { CastShadow = false })

	-- the glass front with open doors in the middle (a 14-stud gap), gold frames
	local doorGap = 14
	local side = (SIZE.Z - doorGap) / 2
	for _, dz in ipairs({ -1, 1 }) do
		local zc = CENTER.Z + dz * (doorGap / 2 + side / 2)
		part(structure, "Glass", Vector3.new(0.3, h - 2, side), CFrame.new(x1 - 0.5, floorY + (h - 2) / 2 + 1, zc), Color3.fromHex("#9FC4D8"), Enum.Material.Glass,
			{ Transparency = 0.6, CastShadow = false })
		part(structure, "GlassBase", Vector3.new(0.8, 1, side), CFrame.new(x1 - 0.5, floorY + 0.5, zc), GRAPHITE_LIGHT, Enum.Material.Metal)
		for i = 0, 3 do
			local z = zc - side / 2 + i * side / 3
			part(structure, "Mullion", Vector3.new(0.6, h, 0.5), CFrame.new(x1 - 0.5, floorY + h / 2, z), GOLD_DARK, Enum.Material.Metal)
		end
	end
	part(structure, "DoorHeader", Vector3.new(0.8, 3, doorGap), CFrame.new(x1 - 0.5, floorY + h - 1.5, CENTER.Z), GOLD_DARK, Enum.Material.Metal)
	-- the open door leaves, swung inside
	for _, dz in ipairs({ -1, 1 }) do
		part(structure, "DoorLeaf", Vector3.new(6, h - 4, 0.25), CFrame.new(x1 - 4, floorY + (h - 4) / 2, CENTER.Z + dz * (doorGap / 2 - 0.3)), Color3.fromHex("#9FC4D8"),
			Enum.Material.Glass, { Transparency = 0.55, CastShadow = false, CanCollide = false })
	end
	-- the pavement and the entrance (teleport) spot in front of the doors
	part(structure, "Pavement", Vector3.new(22, 0.3, SIZE.Z), CFrame.new(x1 + 11, 0.15, CENTER.Z), Color3.fromHex("#8C8C92"), Enum.Material.Concrete)
	part(shop, "Entrance", Vector3.new(4, 0.2, 4), CFrame.new(x1 + 6, 0.4, CENTER.Z), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

	-- the roof sign: PUMP SHOP in gold on graphite, a neon gold underline and two flood lights
	local signY = floorY + h + 5
	local board = sign(structure, "RoofSign", Vector3.new(1, 8, 44), CFrame.new(x1 - 3, signY, CENTER.Z) * CFrame.Angles(0, math.rad(-90), 0), "PUMP SHOP")
	board.CFrame = CFrame.lookAt(Vector3.new(x1 - 3, signY, CENTER.Z), Vector3.new(x1 + 10, signY, CENTER.Z)) -- (front face to the street)
	board.Size = Vector3.new(44, 8, 1)
	part(structure, "SignGlow", Vector3.new(0.4, 0.5, 42), CFrame.new(x1 - 2.4, signY - 4.6, CENTER.Z), GOLD, Enum.Material.Neon, { CastShadow = false })
	for _, dz in ipairs({ -1, 1 }) do
		local flood = part(structure, "SignLight", Vector3.new(1, 1, 1), CFrame.new(x1 + 1, signY - 6, CENTER.Z + dz * 14), GRAPHITE_LIGHT, Enum.Material.Metal)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Top
		spot.Range = 16
		spot.Brightness = 3
		spot.Angle = 70
		spot.Color = Color3.fromHex("#FFE9B8")
		spot.Shadows = false
		spot.Parent = flood
	end

	-- ceiling lights
	for ix = -1, 1 do
		for iz = -1, 1 do
			light(structure, Vector3.new(CENTER.X + ix * 18, floorY + h - 0.4, CENTER.Z + iz * 20))
		end
	end

	-- the four sections: [Section] = counter position (in front of a wall), facing the room
	local sections = {
		{ id = "Supplements", label = "SUPPLEMENTS", pos = Vector3.new(x0 + 9, 0, CENTER.Z - 16), facing = Vector3.xAxis },
		{ id = "Gear", label = "GEAR", pos = Vector3.new(x0 + 9, 0, CENTER.Z + 16), facing = Vector3.xAxis },
		{ id = "Apparel", label = "APPAREL", pos = Vector3.new(CENTER.X + 6, 0, z1 - 9), facing = -Vector3.zAxis },
		{ id = "DnaLab", label = "DNA LAB", pos = Vector3.new(CENTER.X + 6, 0, z0 + 9), facing = Vector3.zAxis },
	}
	for _, s in ipairs(sections) do
		local folder = Instance.new("Model")
		folder.Name = s.id
		folder.Parent = shop
		local face = CFrame.lookAt(s.pos, s.pos + s.facing) -- (-Z of this frame = toward the room)
		local function at(offset: Vector3) return face * CFrame.new(offset) end
		-- the counter (graphite with a gold top edge)
		local counter = part(folder, "Counter", Vector3.new(12, 3.6, 3), at(Vector3.new(0, floorY + 1.8, 0)), GRAPHITE, Enum.Material.SmoothPlastic)
		counter:SetAttribute("Section", s.id)
		CollectionService:AddTag(counter, "PumpShopCounter")
		part(folder, "CounterTop", Vector3.new(12.4, 0.3, 3.4), at(Vector3.new(0, floorY + 3.75, 0)), GOLD_DARK, Enum.Material.Metal)
		-- where the clerk stands (behind the counter, facing the room)
		part(folder, "ClerkSpot", Vector3.new(2, 0.2, 2), at(Vector3.new(0, floorY + 0.1, 3.4)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
			{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }):SetAttribute("Section", s.id)
		-- the hanging section sign
		local signPart = sign(folder, "SectionSign", Vector3.new(14, 3, 0.4), at(Vector3.new(0, floorY + 13, 1)), s.label)
		signPart.CFrame = CFrame.lookAt(signPart.Position, signPart.Position - face.LookVector * -1)
		-- the display behind the clerk (against the wall)
		local wall = at(Vector3.new(0, 0, 7))
		part(folder, "Display", Vector3.new(16, 10, 1), wall * CFrame.new(0, floorY + 5, 0.5), GRAPHITE_LIGHT, Enum.Material.SmoothPlastic)
		if s.id == "Supplements" then
			for row = 0, 2 do
				part(folder, "Shelf", Vector3.new(15, 0.3, 1.6), wall * CFrame.new(0, floorY + 2.5 + row * 3, -0.6), Color3.fromHex("#C9CCD2"), Enum.Material.Metal)
				for i = -3, 3 do
					local colors = { "#E8343C", "#F6C75A", "#3F8CFF", "#36C26B", "#8E5CF0", "#F0882A" }
					local c = Color3.fromHex(colors[(i + row) % #colors + 1])
					local pos = (wall * CFrame.new(i * 2, floorY + 3.5 + row * 3, -0.6)).Position
					if (i + row) % 2 == 0 then
						cylinder(folder, "Tub", 1.6, 1.4, pos, c)
						cylinder(folder, "Lid", 0.25, 1.45, pos + Vector3.new(0, 0.9, 0), Color3.fromHex("#1E1E22"))
					else
						cylinder(folder, "Shaker", 1.8, 0.9, pos, c)
					end
				end
			end
		elseif s.id == "Gear" then
			for i = -3, 3 do
				local hook = wall * CFrame.new(i * 2, floorY + 7, -0.8)
				part(folder, "Hook", Vector3.new(0.2, 0.2, 0.8), hook, Color3.fromHex("#C9CCD2"), Enum.Material.Metal)
				local colors = { "#2B2B30", "#B3262D", "#E8B23A" }
				-- belts (wide bands) and wraps / straps (thin) hanging under the hooks
				part(folder, if i % 2 == 0 then "Belt" else "Strap", Vector3.new(if i % 2 == 0 then 1.4 else 0.5, 3.2, 0.25), hook * CFrame.new(0, -1.7, -0.2),
					Color3.fromHex(colors[(i + 3) % 3 + 1]), Enum.Material.Leather, { CastShadow = false })
			end
			-- knee sleeves on a low shelf
			part(folder, "LowShelf", Vector3.new(15, 0.3, 1.6), wall * CFrame.new(0, floorY + 2.5, -0.6), Color3.fromHex("#C9CCD2"), Enum.Material.Metal)
			for i = -2, 2 do
				cylinder(folder, "KneeSleeve", 1.2, 1.1, (wall * CFrame.new(i * 3, floorY + 3.3, -0.6)).Position, Color3.fromHex(if i % 2 == 0 then "#2B2B30" else "#B3262D"),
					Enum.Material.Fabric)
			end
		elseif s.id == "Apparel" then
			local tops = { { "#B3262D", "#1E1E22" }, { "#1F5FBF", "#D9A82E" }, { "#D9A82E", "#6B3FA0" } }
			for i, pair in ipairs(tops) do
				mannequin(folder, (wall * CFrame.new((i - 2) * 5, floorY, -3)).Position, -wall.LookVector * -1, Color3.fromHex(pair[2]), Color3.fromHex(pair[1]))
			end
		elseif s.id == "DnaLab" then
			for i = -3, 3 do
				local pos = (wall * CFrame.new(i * 2, floorY + 5, -0.8)).Position
				cylinder(folder, "SampleTube", 4, 1, pos, Color3.fromHex(if i % 2 == 0 then "#36C2C2" else "#8E5CF0"), Enum.Material.Neon)
				cylinder(folder, "TubeCap", 0.4, 1.1, pos + Vector3.new(0, 2.2, 0), Color3.fromHex("#C9CCD2"), Enum.Material.Metal)
			end
		end
	end

	-- room for the 5th section (ALTERS, later): an empty corner by the front with a sign
	local soon = sign(shop, "AltersSoon", Vector3.new(10, 2.4, 0.4), CFrame.new(x1 - 12, floorY + 9, z0 + 1.2), "ALTERS · COMING SOON", Color3.fromHex("#B8B8C4"))
	soon.Name = "AltersSoon"

	shop.Parent = town
	return "PUMP SHOP built at " .. tostring(CENTER)
end

return PumpShop
