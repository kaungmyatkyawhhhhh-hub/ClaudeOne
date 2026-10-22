-- PumpShopRedesign builder (prompt 51, 23 Oct; run once in Studio, Edit mode): the PUMP SHOP's room rebuilt around ONE
-- counter in the middle of the back wall, and the outside polished. Works on the saved Workspace.Town.PumpShop: prompt
-- 23's shell, facade, storefront, roof, lot and park stay as they are (tools/builders/PumpShop.luau made them).
-- Backup before: ServerStorage.PumpShopBackup_23Oct.PumpShop (the whole model, its counter tag taken off).
--   * Taken out: Interior, Supplements (the old SPECIALS counter and its prompt), Gear, DnaLab, Apparel, WindowDisplays.
--   * Floor: dark slate, gold inlay lines along the aisle (door -> counter, 13 studs wide), a gold medallion.
--   * Walls: cream above a black wainscot with a gold rail, the back wall black, a gold LED strip round the ceiling edge,
--     warm ceiling cans (soft light cones under the counter's), two fill panels.
--   * Back wall: "PUMP SHOP" in gold, the trophy shelf (the 4 specials on gold plinths, lit, icon plaques), two menu boards
--     (each special, its effect and time, from Config.Boosts), low cabinets.
--   * Interior.Counter (a Model): black, glass front with lit tubs inside, black marble top with a gold edge. The top is the
--     tagged part (PumpShopCounter: PumpShopService puts the ShopPrompt on it). Props: register, bell, THANKS! jar, tub
--     with a scoop, shaker. Interior.ClerkSpot behind it (PumpShopService puts the shopkeeper there).
--   * Side walls: 3 tall shelf units each (5 shelves of tubs and shakers in the boost icon colours, glowing gold edges, a
--     gold header board, a light inside).
--   * Front left (south): GEAR (window platform with 2 mannequins, the Champion belt on a gold pedestal under a spotlight,
--     a pegboard of belts / straps / wraps / sleeves, a small stand). Front right (north): DNA LAB (glass case with a
--     glowing helix, teal light, a lab bench with flasks, a test tube rack and a microscope).
--   * Middle: 2 low islands (a Mass Gainer pyramid with a BEST SELLER tag; a slowly turning giant Elite Pre-Workout tub
--     with Whey stacks and a NEW! tag).
--   * Motion (TownClient): models tagged "ShopSpin" turn (attribute SpinSpeed, degrees a second); lights and neon parts
--     tagged "ShopPulse" pulse.
--   * Outside: the chalkboard says NEW: ELITE PRE-WORKOUT; a shaker on the mural; the 2 south street trees 1.2 studs out.
-- Small props: anchored, no collision, no shadow, not queryable.
-- Usage (command bar): require(game.ServerStorage._Builders.PumpShopRedesign).Build()   (or paste the body into the bar)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)

local PumpShopRedesign = {}

-- the room (inner faces): back wall x -99, storefront x -63, north wall z 98, south wall z 140; the door at z 115..123
local BX, FX = -99, -63
local NZ, SZ = 98, 140
local CZ = 119
local FLOOR = 0.4
local CEIL = 16

local function hex(value) return Color3.fromHex(value) end
local GOLD = hex("#F6C75A")
local GOLD_LIGHT = hex("#FFF3C4")
local GOLD_DARK = hex("#C98A12")
local BLACK = hex("#1B1B1F")
local GRAPHITE = hex("#26262B")
local INK = hex("#141417")
local CREAM = hex("#EFE6D6")
local STEEL = hex("#C9CCD2")
local RED = hex("#B3262D")
local WARM = hex("#FFE6B8")
local TEAL = hex("#36E0E0")
local GOLD_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, GOLD_LIGHT),
	ColorSequenceKeypoint.new(0.5, GOLD),
	ColorSequenceKeypoint.new(1, GOLD_DARK),
})
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local CHALK = Font.fromEnum(Enum.Font.PermanentMarker)
local METAL = Enum.Material.Metal

-- the boost icons (Downloads\gym_arc_boost_icons) as tubs: hero = body, label band, lid; small = one colour and a lid
local SKU = {
	MassGainer = { body = "#F2C230", band = "#2B2B30", top = "#F2C230", main = "#F2C230", lid = "#2B2B30" },
	ElitePreWorkout = { body = "#9B3FE0", band = "#2B2B30", top = "#F2C230", main = "#9B3FE0", lid = "#F2C230" },
	WheyIsolate = { body = "#F4F4F4", band = "#2EC8E6", top = "#F4F4F4", main = "#2EC8E6", lid = "#F4F4F4" },
	BcaaRecovery = { body = "#F4F4F4", band = "#4CD98A", top = "#4CD98A", main = "#4CD98A", lid = "#F4F4F4" },
	Creatine = { body = "#F4F4F4", band = "#E0302E", top = "#2B2B30", main = "#E0302E", lid = "#2B2B30" },
	ProteinPowder = { body = "#F4F4F4", band = "#3A8BFF", top = "#2B2B30", main = "#3A8BFF", lid = "#2B2B30" },
	PreWorkout = { body = "#F5B21E", band = "#2B2B30", top = "#F2C230", main = "#F5B21E", lid = "#2B2B30" },
	Supplements = { body = "#F4F4F4", band = "#F5A623", top = "#F4F4F4", main = "#F5A623", lid = "#F4F4F4" },
}
local SHAKERS = { "#2F8FE8", "#9B3FE0", "#E0302E", "#2B2B30", "#F2C230" }
local SPECIALS = { "MassGainer", "ElitePreWorkout", "WheyIsolate", "BcaaRecovery" }

------------------------------------------------------------------------
-- Part helpers (as in the PumpShop builder)
------------------------------------------------------------------------
local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in pairs(props or {}) do p[key] = value end
	p.Parent = parent
	return p
end
local function deco(parent, name, size, cframe, color, material, props)
	local p = part(parent, name, size, cframe, color, material, props)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	return p
end
local function neon(parent, name, size, cframe, color)
	return deco(parent, name, size, cframe, color, Enum.Material.Neon)
end
-- an upright cylinder (height along Y) centred on `position`
local function cylinder(parent, name, height, diameter, position, color, material, collide)
	local p = deco(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color,
		material or Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	if collide then p.CanCollide, p.CanQuery = true, true end
	return p
end
local function ball(parent, name, diameter, position, color, material)
	return deco(parent, name, Vector3.one * diameter, CFrame.new(position), color, material, { Shape = Enum.PartType.Ball })
end

local function pointLight(holder, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Range, l.Brightness, l.Color, l.Shadows = range, brightness, color, false
	l.Parent = holder
	return l
end
local function spotLight(holder, face, color, range, brightness, angle)
	local s = Instance.new("SpotLight")
	s.Face, s.Range, s.Brightness, s.Angle, s.Color, s.Shadows = face, range, brightness, angle, color, false
	s.Parent = holder
	return s
end
local function surfaceLight(holder, face, color, range, brightness, angle)
	local s = Instance.new("SurfaceLight")
	s.Face, s.Range, s.Brightness, s.Angle, s.Color, s.Shadows = face, range, brightness, angle, color, false
	s.Parent = holder
	return s
end

-- text on a face of a part (gold gradient unless opts.color)
local function label(board, face, text, opts)
	opts = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.pps or 30
	gui.LightInfluence = opts.lightInfluence or 0
	gui.Brightness = opts.brightness or 1.3
	gui.MaxDistance = opts.maxDistance or 120
	gui.Parent = board
	local text_ = Instance.new("TextLabel")
	text_.BackgroundTransparency = 1
	text_.AnchorPoint = Vector2.new(0.5, 0.5)
	text_.Position = UDim2.fromScale(0.5, 0.5)
	text_.Size = UDim2.fromScale(opts.width or 0.92, opts.height or 0.8)
	text_.Text = text
	text_.TextScaled = true -- (world-space sign)
	text_.TextColor3 = opts.color or Color3.new(1, 1, 1)
	text_.FontFace = opts.font or FONT
	text_.Parent = gui
	if not opts.color then
		local gradient = Instance.new("UIGradient")
		gradient.Color = GOLD_SEQ
		gradient.Rotation = 90
		gradient.Parent = text_
	end
	if opts.stroke ~= 0 then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = opts.stroke or 2
		stroke.Parent = text_
	end
	return gui
end
-- a board facing `toward` (its Front face), text on the front (and the back when twoSided)
local function sign(parent, name, size: Vector2, position: Vector3, toward: Vector3, text, opts)
	opts = opts or {}
	local board = deco(parent, name, Vector3.new(size.X, size.Y, opts.depth or 0.3), CFrame.lookAt(position, position + toward), opts.back or BLACK)
	label(board, Enum.NormalId.Front, text, opts)
	if opts.twoSided then label(board, Enum.NormalId.Back, text, opts) end
	return board
end
-- a thin frame round a rectangle in the plane of `cf` (its X and Y axes)
local function frame(parent, cf: CFrame, width, height, thick, color, material)
	local function make(n, s, c) return deco(parent, n, s, c, color, material or Enum.Material.Neon) end
	make("FrameTop", Vector3.new(width + thick, thick, thick), cf * CFrame.new(0, height / 2, 0))
	make("FrameBottom", Vector3.new(width + thick, thick, thick), cf * CFrame.new(0, -height / 2, 0))
	make("FrameLeft", Vector3.new(thick, height, thick), cf * CFrame.new(-width / 2, 0, 0))
	make("FrameRight", Vector3.new(thick, height, thick), cf * CFrame.new(width / 2, 0, 0))
end
-- a ceiling sign on two chains
local function hangingSign(parent, name, at: Vector3, toward: Vector3, width, text, opts)
	local board = sign(parent, name, Vector2.new(width, 1.5), at, toward, text, opts)
	frame(parent, board.CFrame, width + 0.1, 1.6, 0.14, opts.frameColor or GOLD)
	for _, dx in ipairs({ -1, 1 }) do
		local top = (board.CFrame * CFrame.new(dx * (width / 2 - 0.6), 0.8, 0)).Position
		local length = CEIL - top.Y
		deco(parent, "Chain", Vector3.new(0.1, length, 0.1), CFrame.new(top + Vector3.new(0, length / 2, 0)), STEEL, METAL)
	end
	return board
end

-- a tub standing on `bottom` (the boost icon colours)
local function tub(parent, sku, bottom: Vector3, height, diameter, hero)
	local s = SKU[sku]
	local up = Vector3.yAxis
	if hero then
		cylinder(parent, "Tub", height * 0.86, diameter, bottom + up * height * 0.43, hex(s.body))
		cylinder(parent, "Band", height * 0.38, diameter * 1.03, bottom + up * height * 0.45, hex(s.band))
		cylinder(parent, "Lid", height * 0.16, diameter * 1.05, bottom + up * height * 0.92, hex(s.top))
	else
		cylinder(parent, "Tub", height * 0.86, diameter, bottom + up * height * 0.43, hex(s.main))
		cylinder(parent, "Lid", height * 0.16, diameter * 1.05, bottom + up * height * 0.92, hex(s.lid))
	end
end
local function shaker(parent, bottom: Vector3, height, color)
	cylinder(parent, "Shaker", height * 0.78, height * 0.5, bottom + Vector3.yAxis * height * 0.39, color)
	cylinder(parent, "ShakerCap", height * 0.18, height * 0.53, bottom + Vector3.yAxis * height * 0.86, INK)
	cylinder(parent, "ShakerSpout", height * 0.08, height * 0.14, bottom + Vector3.new(height * 0.1, height * 0.98, 0), INK)
end

-- a person-shaped mannequin (blocks), feet at `feet`, facing `facing`
local function mannequin(parent, feet: Vector3, facing: Vector3, shorts: Color3, top: Color3, extras)
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local skin = hex("#D9D4CC")
	local base = CFrame.lookAt(feet, feet + facing)
	local function block(name, size, offset, color, material)
		return deco(model, name, size, base * CFrame.new(offset), color, material or Enum.Material.SmoothPlastic)
	end
	block("Stand", Vector3.new(2, 0.25, 2), Vector3.new(0, 0.125, 0), GOLD_DARK, METAL)
	block("Pole", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 0.85, 0), STEEL, METAL)
	block("LeftLeg", Vector3.new(0.9, 2.4, 0.9), Vector3.new(-0.55, 2.65, 0), skin)
	block("RightLeg", Vector3.new(0.9, 2.4, 0.9), Vector3.new(0.55, 2.65, 0), skin)
	block("Shorts", Vector3.new(2.3, 1.2, 1.05), Vector3.new(0, 3.55, 0), shorts, Enum.Material.Fabric)
	block("Torso", Vector3.new(2.6, 2.6, 1.2), Vector3.new(0, 5.35, 0), top, Enum.Material.Fabric)
	block("Chest", Vector3.new(2.9, 1.2, 1.3), Vector3.new(0, 6.05, 0), top, Enum.Material.Fabric)
	block("LeftArm", Vector3.new(0.9, 2.5, 0.9), Vector3.new(-1.85, 5.25, 0), skin)
	block("RightArm", Vector3.new(0.9, 2.5, 0.9), Vector3.new(1.85, 5.25, 0), skin)
	block("Head", Vector3.new(1.1, 1.2, 1.1), Vector3.new(0, 7.35, 0), skin)
	if extras.belt then
		block("Belt", Vector3.new(2.75, 0.8, 1.35), Vector3.new(0, 4.4, 0), extras.belt, Enum.Material.Leather)
		block("Buckle", Vector3.new(0.7, 0.5, 0.1), Vector3.new(0, 4.4, -0.72), GOLD, METAL)
	end
	if extras.wraps then
		for _, x in ipairs({ -1.85, 1.85 }) do block("Wrap", Vector3.new(1.0, 0.5, 1.0), Vector3.new(x, 4.3, 0), extras.wraps, Enum.Material.Fabric) end
	end
	if extras.sleeves then
		for _, x in ipairs({ -0.55, 0.55 }) do block("KneeSleeve", Vector3.new(1.0, 0.9, 1.0), Vector3.new(x, 2.3, 0), extras.sleeves, Enum.Material.Fabric) end
	end
	model.Parent = parent
	return model
end

-- a ceiling can light (black can, warm lens, spotlight down); `cone` = width of a soft light cone to the floor (haze)
local function can(parent, at: Vector3, range, brightness, angle, color, cone)
	local c = deco(parent, "CeilingCan", Vector3.new(1, 0.3, 1), CFrame.new(at), BLACK, METAL)
	neon(parent, "CanLens", Vector3.new(0.7, 0.05, 0.7), CFrame.new(at - Vector3.new(0, 0.17, 0)), color or WARM)
	spotLight(c, Enum.NormalId.Bottom, color or WARM, range, brightness, angle)
	if cone then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, -0.2, 0)
		a0.Parent = c
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -(at.Y - FLOOR - 0.6), 0)
		a1.Parent = c
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 0.8, cone
		beam.FaceCamera = true
		beam.Segments = 1
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(color or WARM)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) })
		beam.Parent = c
	end
	return c
end

------------------------------------------------------------------------
-- Room: floor, walls, ceiling strip, fill lights
------------------------------------------------------------------------
local function buildRoom(shop, inside)
	local room = Instance.new("Folder")
	room.Name = "Room"
	local floor = shop.Building:FindFirstChild("Floor")
	if floor then
		floor.Color = hex("#2A2724")
		floor.Material = Enum.Material.Slate
	end
	-- gold inlay: the aisle's edges from the door to the counter, a line in front of the counter, a medallion
	local inlayY = FLOOR + 0.015
	for _, z in ipairs({ 112.5, 125.5 }) do
		deco(room, "Inlay", Vector3.new(23.4, 0.04, 0.25), CFrame.new(-75.1, inlayY, z), GOLD_DARK, METAL)
	end
	deco(room, "Inlay", Vector3.new(0.25, 0.04, 26), CFrame.new(-86.8, inlayY, CZ), GOLD_DARK, METAL)
	cylinder(room, "MedallionRing", 0.04, 5, Vector3.new(-75, inlayY, CZ), GOLD_DARK, METAL)
	cylinder(room, "Medallion", 0.05, 4.5, Vector3.new(-75, FLOOR + 0.02, CZ), hex("#2A2724"), Enum.Material.Slate)
	cylinder(room, "MedallionCore", 0.06, 1.2, Vector3.new(-75, FLOOR + 0.025, CZ), GOLD_DARK, METAL)

	-- side walls: cream above a black wainscot and a gold rail
	for _, side in ipairs({ { z = NZ, dir = 1 }, { z = SZ, dir = -1 } }) do
		local length = FX - BX - 0.4
		local cx = (FX + BX) / 2
		deco(room, "WallPanel", Vector3.new(length, CEIL - FLOOR, 0.12), CFrame.new(cx, (FLOOR + CEIL) / 2, side.z + side.dir * 0.06), CREAM)
		deco(room, "Wainscot", Vector3.new(length, 3.4, 0.2), CFrame.new(cx, FLOOR + 1.7, side.z + side.dir * 0.2), BLACK)
		deco(room, "Rail", Vector3.new(length, 0.25, 0.32), CFrame.new(cx, FLOOR + 3.5, side.z + side.dir * 0.22), GOLD_DARK, METAL)
	end
	-- the back wall: black
	deco(room, "BackPanel", Vector3.new(0.2, CEIL - FLOOR, SZ - NZ), CFrame.new(BX + 0.1, (FLOOR + CEIL) / 2, CZ), hex("#1C1B1F"))
	-- the gold LED strip round the ceiling edge
	local y = CEIL - 0.15
	neon(room, "CeilingLED", Vector3.new(FX - BX - 0.6, 0.15, 0.15), CFrame.new((FX + BX) / 2, y, NZ + 0.3), GOLD)
	neon(room, "CeilingLED", Vector3.new(FX - BX - 0.6, 0.15, 0.15), CFrame.new((FX + BX) / 2, y, SZ - 0.3), GOLD)
	neon(room, "CeilingLED", Vector3.new(0.15, 0.15, SZ - NZ - 0.6), CFrame.new(BX + 0.3, y, CZ), GOLD)
	neon(room, "CeilingLED", Vector3.new(0.15, 0.15, SZ - NZ - 0.6), CFrame.new(FX - 0.6, y, CZ), GOLD)
	-- two warm fill panels over the aisle (no dark corners)
	for _, x in ipairs({ -70, -81 }) do
		local panel = neon(room, "FillPanel", Vector3.new(3, 0.1, 3), CFrame.new(x, CEIL - 0.07, CZ), hex("#FFF4DE"))
		deco(room, "FillFrame", Vector3.new(3.4, 0.06, 3.4), CFrame.new(x, CEIL - 0.03, CZ), GOLD_DARK, METAL)
		pointLight(panel, WARM, 28, 1.15)
	end
	-- the cans: over the counter (with soft light cones), the islands, the Champion pedestal
	for _, z in ipairs({ 112, 126 }) do can(room, Vector3.new(-89.5, CEIL - 0.15, z), 16, 2, 70, WARM, 5) end
	can(room, Vector3.new(-91.5, CEIL - 0.15, CZ), 16, 2.4, 60, WARM, 5)
	for _, z in ipairs({ 106.5, 131.5 }) do can(room, Vector3.new(-80, CEIL - 0.15, z), 17, 1.8, 55, WARM) end
	room.Parent = inside
end

------------------------------------------------------------------------
-- Side walls: 3 tall shelf units each
------------------------------------------------------------------------
-- base: on the floor against the wall, LookVector into the room (local +Z = toward the wall)
local function shelfUnit(parent, base: CFrame, header: string, rows, seed)
	local unit = Instance.new("Model")
	unit.Name = "ShelfUnit"
	local W, H, D = 6, 11.6, 2.4
	local function at(x, y, z) return base * CFrame.new(x, y, z) end
	deco(unit, "Back", Vector3.new(W, H, 0.2), at(0, H / 2, -0.2), BLACK)
	for _, sx in ipairs({ -1, 1 }) do
		part(unit, "Side", Vector3.new(0.25, H, D), at(sx * (W / 2 + 0.125), H / 2, -D / 2), BLACK)
	end
	local top = deco(unit, "Top", Vector3.new(W + 0.5, 0.3, D + 0.2), at(0, H + 0.15, -D / 2), BLACK)
	deco(unit, "TopTrim", Vector3.new(W + 0.5, 0.14, 0.12), at(0, H + 0.15, -D - 0.06), GOLD_DARK, METAL)
	surfaceLight(top, Enum.NormalId.Bottom, WARM, 13, 1.3, 110)
	sign(unit, "Header", Vector2.new(W - 0.4, 1.0), at(0, H + 0.85, -D + 0.25).Position, base.LookVector, header,
		{ back = BLACK, depth = 0.2, pps = 40, height = 0.78, stroke = 1.5 })
	for i, sku in ipairs(rows) do
		local y = 0.5 + (i - 1) * 2.15
		deco(unit, "Shelf", Vector3.new(W, 0.2, D - 0.2), at(0, y - 0.1, -D / 2 - 0.05), GRAPHITE)
		neon(unit, "ShelfGlow", Vector3.new(W - 0.1, 0.08, 0.06), at(0, y - 0.06, -D + 0.12), GOLD)
		for j = -1.5, 1.5 do
			local pos = at(j * 1.45, y, -D / 2 - 0.1).Position
			if sku == "Shake" then
				shaker(unit, pos, 1.6, hex(SHAKERS[(seed + i + math.floor(j + 1.5)) % #SHAKERS + 1]))
			else
				tub(unit, sku, pos, 1.45, 1.15)
			end
		end
	end
	unit.Parent = parent
end

local function buildShelves(inside)
	local shelves = Instance.new("Folder")
	shelves.Name = "Shelves"
	local north = {
		{ x = -79.4, header = "PROTEIN", rows = { "WheyIsolate", "ProteinPowder", "WheyIsolate", "ProteinPowder", "Shake" } },
		{ x = -86, header = "PRE-WORKOUT", rows = { "ElitePreWorkout", "PreWorkout", "ElitePreWorkout", "PreWorkout", "Creatine" } },
		{ x = -92.6, header = "RECOVERY", rows = { "BcaaRecovery", "Supplements", "BcaaRecovery", "Creatine", "Supplements" } },
	}
	local south = {
		{ x = -79.4, header = "MASS", rows = { "MassGainer", "ProteinPowder", "MassGainer", "MassGainer", "WheyIsolate" } },
		{ x = -86, header = "SHAKES", rows = { "Shake", "Shake", "Shake", "Shake", "Shake" } },
		{ x = -92.6, header = "VITAMINS", rows = { "Supplements", "BcaaRecovery", "Supplements", "Creatine", "Supplements" } },
	}
	for i, u in ipairs(north) do
		shelfUnit(shelves, CFrame.lookAt(Vector3.new(u.x, FLOOR, NZ), Vector3.new(u.x, FLOOR, NZ + 1)), u.header, u.rows, i)
	end
	for i, u in ipairs(south) do
		shelfUnit(shelves, CFrame.lookAt(Vector3.new(u.x, FLOOR, SZ), Vector3.new(u.x, FLOOR, SZ - 1)), u.header, u.rows, i + 3)
	end
	shelves.Parent = inside
end

------------------------------------------------------------------------
-- Back wall: PUMP SHOP sign, trophy shelf, menu boards, cabinets
------------------------------------------------------------------------
local function effectText(item)
	local short = string.gsub(item.short or "", "^%+100%% ", "2x ")
	return short .. "  ·  " .. string.upper(item.duration or "")
end

-- a menu board facing the room (+X): a title, then a row per special (icon, chunky name, gold effect line)
local function menuBoard(parent, name, center: Vector3, ids)
	local W, H = 8, 5.6
	local board = deco(parent, name, Vector3.new(W, H, 0.2), CFrame.lookAt(center, center + Vector3.xAxis), hex("#121214"))
	frame(parent, board.CFrame * CFrame.new(0, 0, -0.1), W + 0.1, H + 0.1, 0.16, GOLD_DARK, METAL)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.MaxDistance = 120
	gui.Parent = board
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 18), UDim.new(0, 18)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
	padding.Parent = root
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 44)
	title.Text = "SPECIALS"
	title.TextScaled = true
	title.FontFace = FONT
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = root
	local gradient = Instance.new("UIGradient")
	gradient.Color = GOLD_SEQ
	gradient.Rotation = 90
	gradient.Parent = title
	local rule = Instance.new("Frame")
	rule.Position = UDim2.fromOffset(0, 50)
	rule.Size = UDim2.new(1, 0, 0, 3)
	rule.BackgroundColor3 = GOLD_DARK
	rule.BorderSizePixel = 0
	rule.Parent = root
	for i, id in ipairs(ids) do
		local item = Boosts.ById[id]
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, 62 + (i - 1) * 98)
		row.Size = UDim2.new(1, 0, 0, 92)
		row.Parent = root
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(86, 86)
		icon.Position = UDim2.fromOffset(0, 2)
		icon.Image = item.icon
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = row
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(98, 4)
		nameLabel.Size = UDim2.new(1, -98, 0, 46)
		nameLabel.Text = string.upper(item.name)
		nameLabel.TextScaled = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.FontFace = FONT
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Parent = row
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Parent = nameLabel
		local effect = Instance.new("TextLabel")
		effect.BackgroundTransparency = 1
		effect.Position = UDim2.fromOffset(98, 54)
		effect.Size = UDim2.new(1, -98, 0, 32)
		effect.Text = effectText(item)
		effect.TextScaled = true
		effect.TextXAlignment = Enum.TextXAlignment.Left
		effect.FontFace = FONT
		effect.TextColor3 = GOLD
		effect.Parent = row
	end
	return board
end

-- a small black plaque with the item's icon and name (on the trophy shelf's edge)
local function plaque(parent, center: Vector3, id)
	local item = Boosts.ById[id]
	local board = deco(parent, "Plaque", Vector3.new(2.4, 0.55, 0.06), CFrame.lookAt(center, center + Vector3.xAxis), INK)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.Parent = board
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(40, 40)
	icon.Position = UDim2.fromOffset(6, 2)
	icon.Image = item.icon
	icon.Parent = gui
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(50, 6)
	text.Size = UDim2.new(1, -56, 1, -12)
	text.Text = string.upper(item.name)
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.FontFace = FONT
	text.TextColor3 = GOLD
	text.Parent = gui
	return board
end

local function buildBackWall(inside)
	local wall = Instance.new("Folder")
	wall.Name = "BackWall"
	local x = BX + 1 -- the units' middle line (2 deep against the wall)
	-- the trophy unit: closed cabinet, an open shelf of tubs, the trophy niche (the 4 specials on gold plinths)
	local Z0, Z1 = 113.5, 124.5
	local W = Z1 - Z0
	part(wall, "Cabinet", Vector3.new(2, 3.8, W), CFrame.new(x, FLOOR + 1.9, CZ), BLACK)
	deco(wall, "CabinetTrim", Vector3.new(2.05, 0.1, W + 0.05), CFrame.new(x, FLOOR + 3.85, CZ), GOLD_DARK, METAL)
	for _, z in ipairs({ CZ - 2.75, CZ + 2.75 }) do
		deco(wall, "Handle", Vector3.new(0.12, 0.9, 0.12), CFrame.new(x + 1.05, FLOOR + 2.6, z), GOLD, METAL)
	end
	for i, id in ipairs(SPECIALS) do
		local z = Z0 + 1.4 + (i - 1) * 2.75
		for _, dz in ipairs({ -0.6, 0.6 }) do tub(wall, id, Vector3.new(x + 0.1, FLOOR + 3.9, z + dz), 1.1, 0.9) end
	end
	part(wall, "TrophyShelf", Vector3.new(2, 0.25, W), CFrame.new(x, FLOOR + 7.1, CZ), BLACK)
	neon(wall, "TrophyShelfGlow", Vector3.new(0.06, 0.08, W - 0.2), CFrame.new(x + 1.02, FLOOR + 7.15, CZ), GOLD)
	deco(wall, "NicheBack", Vector3.new(0.1, 3.4, W), CFrame.new(BX + 0.25, FLOOR + 8.9, CZ), hex("#2A2116"))
	for _, z in ipairs({ Z0 - 0.15, Z1 + 0.15 }) do
		part(wall, "UnitSide", Vector3.new(2.2, 10.6, 0.3), CFrame.new(x, FLOOR + 5.3, z), BLACK)
	end
	local niche = part(wall, "NicheTop", Vector3.new(2.2, 0.4, W + 0.6), CFrame.new(x, FLOOR + 10.8, CZ), BLACK)
	neon(wall, "NicheTopTrim", Vector3.new(0.12, 0.12, W + 0.6), CFrame.new(x + 1.12, FLOOR + 10.8, CZ), GOLD)
	local strip = neon(wall, "NicheLight", Vector3.new(0.12, 0.08, W - 0.4), CFrame.new(x + 0.7, FLOOR + 10.55, CZ), hex("#FFF4DE"))
	surfaceLight(strip, Enum.NormalId.Bottom, hex("#FFF0C8"), 7, 3, 120)
	local _ = niche
	for i, id in ipairs(SPECIALS) do
		local z = Z0 + 1.4 + (i - 1) * 2.75
		cylinder(wall, "Plinth", 0.35, 1.6, Vector3.new(x, FLOOR + 7.4, z), GOLD, METAL)
		tub(wall, id, Vector3.new(x, FLOOR + 7.58, z), 2.2, 1.6, true)
		plaque(wall, Vector3.new(x + 1.06, FLOOR + 7.1, z), id)
	end
	-- PUMP SHOP above it, gold letters, a gold frame
	local board = sign(wall, "BackSign", Vector2.new(16, 2.4), Vector3.new(BX + 0.45, FLOOR + 12.6, CZ), Vector3.xAxis, "PUMP SHOP",
		{ back = INK, depth = 0.3, pps = 30, stroke = 3, height = 0.86, brightness = 1.6 })
	frame(wall, board.CFrame * CFrame.new(0, 0, -0.16), 16.2, 2.6, 0.18, GOLD)
	-- the menu boards and the low cabinets under them
	menuBoard(wall, "MenuBoard", Vector3.new(BX + 0.4, FLOOR + 8.2, 130.5), { "MassGainer", "ElitePreWorkout" })
	menuBoard(wall, "MenuBoard", Vector3.new(BX + 0.4, FLOOR + 8.2, 107.5), { "WheyIsolate", "BcaaRecovery" })
	for _, z in ipairs({ 107.5, 130.5 }) do
		part(wall, "LowCabinet", Vector3.new(2, 3.4, 8), CFrame.new(x, FLOOR + 1.7, z), BLACK)
		deco(wall, "LowCabinetTrim", Vector3.new(2.05, 0.1, 8.05), CFrame.new(x, FLOOR + 3.45, z), GOLD_DARK, METAL)
		for k = -1, 1 do
			if k == 0 then
				tub(wall, if z > CZ then "MassGainer" else "WheyIsolate", Vector3.new(x, FLOOR + 3.5, z), 1.5, 1.2)
			else
				shaker(wall, Vector3.new(x, FLOOR + 3.5, z + k * 2.6), 1.6, hex(SHAKERS[k + 3]))
			end
		end
	end
	wall.Parent = inside
end

------------------------------------------------------------------------
-- The counter (the hero) and its props
------------------------------------------------------------------------
local function buildCounter(inside)
	local counter = Instance.new("Model")
	counter.Name = "Counter"
	local cx = -90
	local Z0, Z1 = 109, 129
	local LEN = Z1 - Z0
	local TOP = FLOOR + 3.7 -- the top surface (like Coach Dex's counter)
	part(counter, "Plinth", Vector3.new(3, 0.5, LEN), CFrame.new(cx - 0.1, FLOOR + 0.25, CZ), BLACK)
	neon(counter, "ToeGlow", Vector3.new(0.06, 0.1, LEN - 0.6), CFrame.new(cx + 1.42, FLOOR + 0.3, CZ), GOLD)
	part(counter, "Back", Vector3.new(0.3, 2.85, LEN), CFrame.new(cx - 1.65, FLOOR + 0.5 + 1.425, CZ), BLACK)
	for _, z in ipairs({ Z0 + 0.15, Z1 - 0.15 }) do
		part(counter, "End", Vector3.new(3.6, 2.85, 0.3), CFrame.new(cx, FLOOR + 0.5 + 1.425, z), BLACK)
	end
	part(counter, "Glass", Vector3.new(0.15, 2.85, LEN - 0.6), CFrame.new(cx + 1.6, FLOOR + 0.5 + 1.425, CZ), hex("#CFE3EC"), Enum.Material.Glass,
		{ Transparency = 0.62 })
	for _, z in ipairs({ 114, CZ, 124 }) do
		deco(counter, "Post", Vector3.new(0.3, 2.85, 0.3), CFrame.new(cx + 1.7, FLOOR + 0.5 + 1.425, z), BLACK)
		deco(counter, "PostTrim", Vector3.new(0.05, 2.85, 0.12), CFrame.new(cx + 1.87, FLOOR + 0.5 + 1.425, z), GOLD, METAL)
	end
	deco(counter, "BottomRail", Vector3.new(0.12, 0.12, LEN), CFrame.new(cx + 1.75, FLOOR + 0.56, CZ), GOLD_DARK, METAL)
	-- inside the glass: a shelf, two rows of tubs, a warm strip under the top
	deco(counter, "InnerShelf", Vector3.new(2.6, 0.15, LEN - 0.8), CFrame.new(cx, FLOOR + 1.9, CZ), GRAPHITE)
	local n = 0
	for z = Z0 + 1.2, Z1 - 1.1, 1.6 do
		n += 1
		tub(counter, SPECIALS[n % 4 + 1], Vector3.new(cx + 0.6, FLOOR + 0.5, z), 1.2, 1.0)
		tub(counter, SPECIALS[(n + 2) % 4 + 1], Vector3.new(cx + 0.6, FLOOR + 1.975, z), 1.15, 0.95)
	end
	local strip = neon(counter, "InnerLight", Vector3.new(0.1, 0.08, LEN - 1), CFrame.new(cx + 1.3, TOP - 0.42, CZ), hex("#FFF4DE"))
	surfaceLight(strip, Enum.NormalId.Bottom, hex("#FFF0C8"), 4, 2, 120)
	-- the top (the shop's tagged counter part): black marble, gold edges
	local top = part(counter, "Top", Vector3.new(4, 0.35, LEN + 0.6), CFrame.new(cx, TOP - 0.175, CZ), INK, Enum.Material.Marble)
	top:SetAttribute("Section", "Supplements")
	CollectionService:AddTag(top, "PumpShopCounter")
	deco(counter, "TopEdge", Vector3.new(0.18, 0.42, LEN + 0.7), CFrame.new(cx + 2.05, TOP - 0.175, CZ), GOLD, METAL)
	for _, z in ipairs({ Z0 - 0.36, Z1 + 0.36 }) do
		deco(counter, "TopEnd", Vector3.new(4.1, 0.42, 0.14), CFrame.new(cx, TOP - 0.175, z), GOLD, METAL)
	end
	-- props (the middle stays clear: the shopkeeper leans on it)
	local function on(x, z) return Vector3.new(x, TOP, z) end
	-- register (customer screen toward the room)
	local reg = on(cx - 0.3, 125.4)
	deco(counter, "Register", Vector3.new(1.5, 0.5, 1.6), CFrame.new(reg + Vector3.new(0, 0.25, 0)), INK)
	deco(counter, "RegisterKeys", Vector3.new(0.7, 0.12, 1.2), CFrame.new(reg + Vector3.new(-0.35, 0.55, 0)) * CFrame.Angles(0, 0, math.rad(12)), GRAPHITE)
	deco(counter, "RegisterScreen", Vector3.new(0.12, 0.75, 1.2), CFrame.new(reg + Vector3.new(-0.55, 1.0, 0)) * CFrame.Angles(0, 0, math.rad(-15)), INK)
	neon(counter, "RegisterGlow", Vector3.new(0.05, 0.6, 1.05), CFrame.new(reg + Vector3.new(-0.47, 1.0, 0)) * CFrame.Angles(0, 0, math.rad(-15)), hex("#36C2C2"))
	deco(counter, "RegisterPole", Vector3.new(0.1, 0.6, 0.1), CFrame.new(reg + Vector3.new(0.55, 0.8, 0)), STEEL, METAL)
	local pole = deco(counter, "CustomerScreen", Vector3.new(0.1, 0.45, 0.9), CFrame.lookAt(reg + Vector3.new(0.62, 1.2, 0), reg + Vector3.new(5, 1.2, 0)), INK)
	label(pole, Enum.NormalId.Front, "THANK YOU", { color = GOLD, pps = 60, stroke = 0, height = 0.6 })
	-- bell
	local bell = on(cx + 1.1, 115.7)
	cylinder(counter, "BellBase", 0.1, 0.75, bell + Vector3.new(0, 0.05, 0), INK)
	deco(counter, "Bell", Vector3.new(0.6, 0.5, 0.6), CFrame.new(bell + Vector3.new(0, 0.1, 0)), GOLD, METAL, { Shape = Enum.PartType.Ball })
	deco(counter, "BellButton", Vector3.new(0.12, 0.18, 0.12), CFrame.new(bell + Vector3.new(0, 0.42, 0)), GOLD_DARK, METAL)
	-- THANKS! jar (no money: a few gold stars)
	local jar = on(cx + 1, 113.4)
	cylinder(counter, "Jar", 1.3, 0.95, jar + Vector3.new(0, 0.65, 0), hex("#DDF2F8"), Enum.Material.Glass).Transparency = 0.55
	cylinder(counter, "JarLid", 0.15, 1.0, jar + Vector3.new(0, 1.37, 0), GOLD, METAL)
	for k = 0, 2 do ball(counter, "JarStar", 0.32, jar + Vector3.new(0.12 * (k - 1), 0.25 + k * 0.08, 0.2 * (k - 1)), GOLD, METAL) end
	local jarLabel = deco(counter, "JarLabel", Vector3.new(0.75, 0.42, 0.04), CFrame.lookAt(jar + Vector3.new(0.5, 0.7, 0), jar + Vector3.new(5, 0.7, 0)), hex("#F4F1EA"))
	label(jarLabel, Enum.NormalId.Front, "THANKS!", { color = RED, pps = 80, stroke = 0, height = 0.8 })
	-- open tub of whey with a scoop
	local scoopTub = on(cx + 0.2, 122.4)
	cylinder(counter, "OpenTub", 1.25, 1.15, scoopTub + Vector3.new(0, 0.625, 0), hex(SKU.WheyIsolate.body))
	cylinder(counter, "OpenTubBand", 0.48, 1.18, scoopTub + Vector3.new(0, 0.6, 0), hex(SKU.WheyIsolate.band))
	cylinder(counter, "Powder", 0.04, 1.02, scoopTub + Vector3.new(0, 1.2, 0), hex("#F1ECE2"))
	deco(counter, "ScoopHandle", Vector3.new(0.12, 1.0, 0.12), CFrame.new(scoopTub + Vector3.new(0.2, 1.45, 0.15)) * CFrame.Angles(math.rad(20), 0, math.rad(-25)), hex("#2EC8E6"))
	cylinder(counter, "Lid", 0.16, 1.2, scoopTub + Vector3.new(0, 0.08, -1.25), hex(SKU.WheyIsolate.top))
	-- shaker
	shaker(counter, on(cx + 0.9, 111.2), 1.4, hex("#9B3FE0"))
	-- the bounding box faces the room (GoTo puts the guide's spot in front of it)
	counter.WorldPivot = CFrame.lookAt(Vector3.new(cx, FLOOR + 2, CZ), Vector3.new(cx + 10, FLOOR + 2, CZ))
	counter.Parent = inside
	-- where the shopkeeper stands (PumpShopService), facing the door
	part(inside, "ClerkSpot", Vector3.new(2, 0.2, 2), CFrame.lookAt(Vector3.new(-92.8, FLOOR + 0.1, CZ), Vector3.new(-80, FLOOR + 0.1, CZ)), Color3.new(1, 1, 1),
		nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }):SetAttribute("Section", "Supplements")
end

------------------------------------------------------------------------
-- Front corners: GEAR (south, the door's left) and DNA LAB (north, the door's right)
------------------------------------------------------------------------
local function buildGear(inside)
	local gear = Instance.new("Model")
	gear.Name = "GearCorner"
	-- the window platform with two mannequins (seen from the street and the door)
	part(gear, "Platform", Vector3.new(2.6, 0.8, 12), CFrame.new(-64.6, FLOOR + 0.4, 133.5), BLACK)
	deco(gear, "PlatformTrim", Vector3.new(0.12, 0.12, 12), CFrame.new(-65.95, FLOOR + 0.8, 133.5), GOLD_DARK, METAL)
	local look = Vector3.new(1, 0, -0.7).Unit
	mannequin(gear, Vector3.new(-64.6, FLOOR + 0.8, 130.2), look, BLACK, RED, { belt = hex("#2B2B30") })
	mannequin(gear, Vector3.new(-64.6, FLOOR + 0.8, 136.6), look, hex("#2B2B30"), BLACK, { belt = hex("#9BA1AA"), wraps = RED, sleeves = INK })
	-- the Champion belt on a gold pedestal, under a narrow spotlight
	local p = Vector3.new(-70.5, FLOOR, 134)
	local facing = (Vector3.new(-62, FLOOR, 126) - p).Unit
	cylinder(gear, "PedestalBase", 0.5, 4.2, p + Vector3.new(0, 0.25, 0), BLACK, nil, true)
	cylinder(gear, "Pedestal", 2.2, 3, p + Vector3.new(0, 1.6, 0), BLACK, nil, true)
	for _, y in ipairs({ 0.55, 2.65 }) do cylinder(gear, "PedestalRing", 0.12, 3.12, p + Vector3.new(0, y, 0), GOLD, METAL) end
	cylinder(gear, "PedestalTop", 0.25, 3.4, p + Vector3.new(0, 2.825, 0), GOLD, METAL)
	deco(gear, "Cushion", Vector3.new(2.4, 0.4, 1.8), CFrame.lookAt(p + Vector3.new(0, 3.15, 0), p + Vector3.new(0, 3.15, 0) + facing), hex("#5A1418"), Enum.Material.Fabric)
	local belt = Instance.new("Model")
	belt.Name = "ChampionBelt"
	local ring = CFrame.lookAt(p + Vector3.new(0, 3.95, 0), p + Vector3.new(0, 3.95, 0) + facing) * CFrame.Angles(math.rad(-25), 0, 0)
	local R = 1.05
	for i = 0, 15 do
		local a = i * math.pi / 8
		deco(belt, "BeltPiece", Vector3.new(0.14, 0.85, 0.44), ring * CFrame.Angles(0, a, 0) * CFrame.new(R, 0, 0), GOLD, METAL)
	end
	deco(belt, "Buckle", Vector3.new(0.14, 0.8, 0.95), ring * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(R + 0.1, 0, 0), GOLD_LIGHT, METAL)
	deco(belt, "BuckleInset", Vector3.new(0.06, 0.4, 0.5), ring * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(R + 0.2, 0, 0), INK)
	belt.Parent = gear
	local plaqueAt = p + Vector3.new(0, 1.8, 0) + facing * 1.53
	sign(gear, "ChampionPlaque", Vector2.new(1.9, 0.55), plaqueAt, facing, "CHAMPION", { back = INK, depth = 0.06, pps = 60, stroke = 1, height = 0.75 })
	can(gear, Vector3.new(-70.5, CEIL - 0.15, 134), 18, 4, 30, hex("#FFF0C8"), 3.5)
	-- the pegboard on the south wall: belts (basic black, pro red, elite silver), straps, a shelf of wraps and sleeves
	local wallZ = SZ - 0.35
	deco(gear, "Pegboard", Vector3.new(9.8, 4.8, 0.2), CFrame.new(-71, FLOOR + 7.6, wallZ), hex("#2A2622"))
	frame(gear, CFrame.new(-71, FLOOR + 7.6, wallZ - 0.12), 9.8, 4.8, 0.14, GOLD_DARK, METAL)
	local items = {
		{ x = -67.2, kind = "Belt", color = "#2B2B30" }, { x = -69.1, kind = "Straps", color = "#2B2B30" },
		{ x = -71, kind = "Belt", color = "#B3262D" }, { x = -72.9, kind = "Straps", color = "#B3262D" },
		{ x = -74.8, kind = "Belt", color = "#9BA1AA" },
	}
	for _, item in ipairs(items) do
		local hook = Vector3.new(item.x, FLOOR + 9.4, wallZ - 0.45)
		deco(gear, "Hook", Vector3.new(0.12, 0.12, 0.7), CFrame.new(hook), STEEL, METAL)
		if item.kind == "Belt" then
			deco(gear, "Belt", Vector3.new(1.3, 2.9, 0.2), CFrame.new(hook + Vector3.new(0, -1.5, -0.15)), hex(item.color), Enum.Material.Leather)
			deco(gear, "Buckle", Vector3.new(0.8, 0.45, 0.1), CFrame.new(hook + Vector3.new(0, -2.5, -0.3)), GOLD, METAL)
		else
			for _, dx in ipairs({ -0.25, 0.25 }) do
				deco(gear, "Strap", Vector3.new(0.35, 2.4, 0.12), CFrame.new(hook + Vector3.new(dx, -1.25, -0.12)), hex(item.color), Enum.Material.Fabric)
			end
		end
	end
	deco(gear, "PegShelf", Vector3.new(9.4, 0.18, 1.0), CFrame.new(-71, FLOOR + 4.6, wallZ - 0.6), BLACK)
	for k = 0, 3 do
		local at = Vector3.new(-67.5 - k * 2.3, FLOOR + 4.69, wallZ - 0.6)
		if k % 2 == 0 then
			cylinder(gear, "KneeSleeve", 1.1, 0.8, at + Vector3.new(0, 0.55, 0), hex(if k == 0 then "#2B2B30" else "#B3262D"), Enum.Material.Fabric)
		else
			for _, dx in ipairs({ -0.35, 0.35 }) do
				deco(gear, "WrapRoll", Vector3.new(0.6, 0.55, 0.55), CFrame.new(at + Vector3.new(dx, 0.28, 0)), hex(if k == 1 then "#B3262D" else "#F2C230"), Enum.Material.Fabric,
					{ Shape = Enum.PartType.Cylinder })
			end
		end
	end
	-- a small round stand with wraps, straps and a sleeve
	local stand = Vector3.new(-70.2, FLOOR, 128.4)
	cylinder(gear, "StandBase", 0.2, 1.6, stand + Vector3.new(0, 0.1, 0), BLACK)
	cylinder(gear, "StandPole", 2.6, 0.25, stand + Vector3.new(0, 1.5, 0), GOLD_DARK, METAL)
	cylinder(gear, "StandTop", 0.2, 2.4, stand + Vector3.new(0, 2.9, 0), BLACK, nil, true)
	local onStand = stand + Vector3.new(0, 3.0, 0)
	deco(gear, "WrapRoll", Vector3.new(0.6, 0.55, 0.55), CFrame.new(onStand + Vector3.new(0.4, 0.28, -0.4)), RED, Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder })
	deco(gear, "WrapRoll", Vector3.new(0.6, 0.55, 0.55), CFrame.new(onStand + Vector3.new(-0.4, 0.28, -0.5)), BLACK, Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder })
	deco(gear, "FoldedStraps", Vector3.new(0.9, 0.18, 0.5), CFrame.new(onStand + Vector3.new(0.1, 0.09, 0.5)), hex("#2B2B30"), Enum.Material.Fabric)
	cylinder(gear, "KneeSleeve", 0.9, 0.7, onStand + Vector3.new(-0.5, 0.45, 0.35), RED, Enum.Material.Fabric)
	hangingSign(gear, "GearSign", Vector3.new(-70.5, CEIL - 3, 133.5), Vector3.xAxis, 5, "GEAR",
		{ back = INK, twoSided = true, pps = 30, height = 0.78, depth = 0.2 })
	gear.Parent = inside
end

local function buildDnaLab(inside)
	local lab = Instance.new("Model")
	lab.Name = "DnaLab"
	local c = Vector3.new(-69.5, FLOOR, 105)
	-- the floor ring under the case
	cylinder(lab, "FloorRing", 0.03, 6.4, c + Vector3.new(0, 0.015, 0), TEAL, Enum.Material.Neon)
	cylinder(lab, "FloorDisc", 0.05, 6, c + Vector3.new(0, 0.025, 0), hex("#16232A"), Enum.Material.Marble)
	-- the glass case
	part(lab, "CaseBase", Vector3.new(3.2, 1.4, 3.2), CFrame.new(c + Vector3.new(0, 0.7, 0)), BLACK)
	deco(lab, "CaseTrim", Vector3.new(3.3, 0.1, 3.3), CFrame.new(c + Vector3.new(0, 1.42, 0)), GOLD_DARK, METAL)
	part(lab, "CaseGlass", Vector3.new(3, 4.6, 3), CFrame.new(c + Vector3.new(0, 3.75, 0)), hex("#DDF6FF"), Enum.Material.Glass, { Transparency = 0.72 })
	deco(lab, "CaseTop", Vector3.new(3.3, 0.35, 3.3), CFrame.new(c + Vector3.new(0, 6.22, 0)), BLACK)
	local glowTop = neon(lab, "CaseGlow", Vector3.new(2.8, 0.06, 2.8), CFrame.new(c + Vector3.new(0, 6.02, 0)), TEAL)
	CollectionService:AddTag(glowTop, "ShopPulse")
	-- the helix (turns slowly, glows and pulses; TownClient)
	local helix = Instance.new("Model")
	helix.Name = "Helix"
	local core = deco(helix, "Core", Vector3.new(0.2, 4, 0.2), CFrame.new(c + Vector3.new(0, 3.85, 0)), TEAL, Enum.Material.SmoothPlastic, { Transparency = 1 })
	local light = pointLight(core, TEAL, 16, 1.6)
	CollectionService:AddTag(light, "ShopPulse")
	for i = 0, 10 do
		local y = 1.95 + i * 0.38
		local a = i * math.rad(36)
		local offset = Vector3.new(math.cos(a), 0, math.sin(a)) * 0.75
		local mid = c + Vector3.new(0, y, 0)
		ball(helix, "Base", 0.34, mid + offset, TEAL, Enum.Material.Neon)
		ball(helix, "Base", 0.34, mid - offset, hex("#B9FFF8"), Enum.Material.Neon)
		deco(helix, "Rung", Vector3.new(1.4, 0.07, 0.07), CFrame.new(mid) * CFrame.Angles(0, -a, 0), hex("#8FE9E4"))
	end
	helix.PrimaryPart = core
	helix.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	helix:SetAttribute("SpinSpeed", 24)
	CollectionService:AddTag(helix, "ShopSpin")
	helix.Parent = lab
	-- the lab bench on the north wall: flasks, a test tube rack, a microscope
	local bz = NZ + 1.2
	part(lab, "Bench", Vector3.new(9, 3, 2), CFrame.new(-69, FLOOR + 1.5, bz), BLACK)
	deco(lab, "BenchTop", Vector3.new(9.2, 0.25, 2.2), CFrame.new(-69, FLOOR + 3.12, bz), hex("#EEF3F5"))
	neon(lab, "BenchToe", Vector3.new(8.8, 0.1, 0.06), CFrame.new(-69, FLOOR + 0.2, bz + 1.02), TEAL)
	local top = FLOOR + 3.25
	for k, color in ipairs({ "#36E0E0", "#B07CFF", "#4CD98A" }) do
		local f = Vector3.new(-65.5 - k * 1.2, top, bz + 0.1)
		cylinder(lab, "Flask", 0.8, 0.85, f + Vector3.new(0, 0.4, 0), hex("#DDF6FF"), Enum.Material.Glass).Transparency = 0.6
		cylinder(lab, "FlaskLiquid", 0.5, 0.7, f + Vector3.new(0, 0.27, 0), hex(color), Enum.Material.Neon)
		cylinder(lab, "FlaskNeck", 0.55, 0.3, f + Vector3.new(0, 1.05, 0), hex("#DDF6FF"), Enum.Material.Glass).Transparency = 0.5
	end
	local rack = Vector3.new(-70.6, top, bz)
	deco(lab, "TubeRack", Vector3.new(1.8, 0.35, 0.5), CFrame.new(rack + Vector3.new(0, 0.5, 0)), STEEL, METAL)
	deco(lab, "TubeRackBase", Vector3.new(1.8, 0.1, 0.6), CFrame.new(rack + Vector3.new(0, 0.05, 0)), STEEL, METAL)
	for k, color in ipairs({ "#36E0E0", "#F6C75A", "#B07CFF", "#4CD98A" }) do
		cylinder(lab, "TestTube", 0.9, 0.2, rack + Vector3.new(-0.9 + k * 0.36, 0.5, 0), hex(color), Enum.Material.Neon)
	end
	local scope = Vector3.new(-72.8, top, bz)
	deco(lab, "ScopeBase", Vector3.new(0.7, 0.15, 0.9), CFrame.new(scope + Vector3.new(0, 0.075, 0)), BLACK)
	deco(lab, "ScopeArm", Vector3.new(0.18, 1.1, 0.25), CFrame.new(scope + Vector3.new(0, 0.6, -0.3)), BLACK)
	deco(lab, "ScopeTube", Vector3.new(0.26, 0.75, 0.26), CFrame.new(scope + Vector3.new(0, 1.05, 0)) * CFrame.Angles(math.rad(-20), 0, 0), STEEL, METAL)
	deco(lab, "ScopeStage", Vector3.new(0.6, 0.06, 0.5), CFrame.new(scope + Vector3.new(0, 0.5, 0.05)), INK)
	-- a wall shelf of bottles over the bench
	deco(lab, "WallShelf", Vector3.new(8, 0.15, 0.8), CFrame.new(-69, FLOOR + 6.6, NZ + 0.55), BLACK)
	neon(lab, "WallShelfGlow", Vector3.new(7.9, 0.06, 0.05), CFrame.new(-69, FLOOR + 6.55, NZ + 0.96), TEAL)
	for k = 0, 4 do
		local b = Vector3.new(-66 - k * 1.5, FLOOR + 6.68, NZ + 0.55)
		cylinder(lab, "Bottle", 0.9, 0.45, b + Vector3.new(0, 0.45, 0), hex(if k % 2 == 0 then "#36C2C2" else "#8E5CF0"), Enum.Material.Glass).Transparency = 0.25
		cylinder(lab, "BottleCap", 0.18, 0.3, b + Vector3.new(0, 0.99, 0), STEEL, METAL)
	end
	hangingSign(lab, "DnaSign", Vector3.new(-69.5, CEIL - 3, 105), Vector3.xAxis, 5.6, "DNA LAB",
		{ back = hex("#0E1E22"), color = hex("#7FFFF8"), twoSided = true, pps = 30, height = 0.75, depth = 0.2, frameColor = TEAL })
	lab.Parent = inside
end

------------------------------------------------------------------------
-- The two islands in the middle (the aisle between them stays clear)
------------------------------------------------------------------------
local function island(parent, center: Vector3)
	part(parent, "Island", Vector3.new(6, 2, 4), CFrame.new(center + Vector3.new(0, 1, 0)), BLACK)
	deco(parent, "IslandTop", Vector3.new(6.2, 0.2, 4.2), CFrame.new(center + Vector3.new(0, 2.1, 0)), INK, Enum.Material.Marble)
	for _, dz in ipairs({ -2.1, 2.1 }) do
		deco(parent, "IslandEdge", Vector3.new(6.3, 0.12, 0.12), CFrame.new(center + Vector3.new(0, 2.15, dz)), GOLD_DARK, METAL)
	end
	for _, dx in ipairs({ -3.1, 3.1 }) do
		deco(parent, "IslandEdge", Vector3.new(0.12, 0.12, 4.3), CFrame.new(center + Vector3.new(dx, 2.15, 0)), GOLD_DARK, METAL)
	end
	neon(parent, "IslandToe", Vector3.new(0.06, 0.1, 3.6), CFrame.new(center + Vector3.new(3.02, 0.15, 0)), GOLD)
	return center + Vector3.new(0, 2.2, 0) -- the top surface
end
local function tag(parent, at: Vector3, text, back, color)
	deco(parent, "TagStalk", Vector3.new(0.1, 1.0, 0.1), CFrame.new(at + Vector3.new(0, 0.5, 0)), GOLD_DARK, METAL)
	local cf = CFrame.lookAt(at + Vector3.new(0, 1.35, 0), at + Vector3.new(10, 1.35, 0)) * CFrame.Angles(math.rad(-18), 0, 0)
	local board = deco(parent, "Tag", Vector3.new(2.5, 0.8, 0.08), cf, back)
	frame(parent, cf, 2.55, 0.85, 0.08, GOLD, METAL)
	label(board, Enum.NormalId.Front, text, { color = color, pps = 60, stroke = 1.5, height = 0.75 })
end

local function buildIslands(inside)
	local islands = Instance.new("Folder")
	islands.Name = "Islands"
	-- north: a Mass Gainer pyramid (3x3, 2x2, 1), BEST SELLER
	local a = Instance.new("Model")
	a.Name = "BestSeller"
	local topA = island(a, Vector3.new(-80, FLOOR, 106.5))
	local px, pz = -80.9, 106.5
	for layer, n in ipairs({ 3, 2, 1 }) do
		for i = 1, n do
			for j = 1, n do
				local x = px + (i - (n + 1) / 2) * 1.05
				local z = pz + (j - (n + 1) / 2) * 1.05
				tub(a, "MassGainer", Vector3.new(x, topA.Y + (layer - 1) * 1.2, z), 1.2, 1.0, layer == 3)
			end
		end
	end
	tag(a, Vector3.new(-77.6, topA.Y, 106.5), "BEST SELLER", RED, Color3.new(1, 1, 1))
	a.Parent = islands
	-- south: the giant Elite Pre-Workout tub turning on a gold plinth, Whey stacks at the corners, NEW!
	local b = Instance.new("Model")
	b.Name = "NewIn"
	local topB = island(b, Vector3.new(-80, FLOOR, 131.5))
	local center = Vector3.new(-80.6, topB.Y, 131.5)
	cylinder(b, "SpinPlinth", 0.4, 2.7, center + Vector3.new(0, 0.2, 0), GOLD, METAL)
	local spin = Instance.new("Model")
	spin.Name = "SpinTub"
	local body = cylinder(spin, "Tub", 2.3, 2.2, center + Vector3.new(0, 0.4 + 1.15, 0), hex(SKU.ElitePreWorkout.body))
	cylinder(spin, "Band", 0.95, 2.26, center + Vector3.new(0, 0.4 + 1.2, 0), hex(SKU.ElitePreWorkout.band))
	cylinder(spin, "Lid", 0.42, 2.32, center + Vector3.new(0, 0.4 + 2.4, 0), hex(SKU.ElitePreWorkout.top))
	for _, dir in ipairs({ Vector3.xAxis, -Vector3.xAxis }) do
		local at = center + Vector3.new(0, 0.4 + 1.2, 0) + dir * 1.15
		local board = deco(spin, "TubLabel", Vector3.new(1.6, 0.8, 0.02), CFrame.lookAt(at, at + dir), INK, nil, { Transparency = 1 })
		label(board, Enum.NormalId.Front, "ELITE", { pps = 60, stroke = 1.5, height = 0.8 })
	end
	spin.PrimaryPart = body
	spin.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	spin:SetAttribute("SpinSpeed", 18)
	CollectionService:AddTag(spin, "ShopSpin")
	spin.Parent = b
	for _, dx in ipairs({ -2, 1.2 }) do
		for _, dz in ipairs({ -1.4, 1.4 }) do
			local s = Vector3.new(-80 + dx, topB.Y, 131.5 + dz)
			tub(b, "WheyIsolate", s + Vector3.new(-0.3, 0, 0), 1.1, 0.9)
			tub(b, "WheyIsolate", s + Vector3.new(0.3, 0, 0), 1.1, 0.9)
			tub(b, "WheyIsolate", s + Vector3.new(0, 1.1, 0), 1.1, 0.9, true)
		end
	end
	tag(b, Vector3.new(-77.6, topB.Y, 131.5), "NEW!", hex("#5B1F8F"), GOLD_LIGHT)
	b.Parent = islands
	islands.Parent = inside
end

------------------------------------------------------------------------
-- Outside touches: the chalkboard, a shaker on the mural
------------------------------------------------------------------------
local function polishOutside(shop)
	local lot = shop:FindFirstChild("Lot")
	if lot then
		-- the two street trees on the south side: their crowns came 0.8 studs through the wall into the room
		for _, c in ipairs(lot:GetChildren()) do
			if c.Name == "RoundTree" and c:IsA("Model") and c:GetPivot().Position.Z < 144 then c:PivotTo(c:GetPivot() + Vector3.new(0, 0, 1.2)) end
			if c.Name == "TreeGrate" and c:IsA("BasePart") and c.Position.Z < 144 then c.Position += Vector3.new(0, 0, 1.2) end
		end
		for _, d in ipairs(lot:GetDescendants()) do
			if d:IsA("TextLabel") and d.Parent and d.Parent.Name == "Chalk" then d.Text = "NEW:\nELITE\nPRE-WORKOUT" end
		end
	end
	local mural = shop:FindFirstChild("Windows") and shop.Windows:FindFirstChild("Mural")
	local root = mural and mural:FindFirstChildOfClass("SurfaceGui") and mural:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("Frame")
	if root and not root:FindFirstChild("Shaker") then
		local function shape(name, center: Vector2, size: Vector2, color, radius, z)
			local f = Instance.new("Frame")
			f.Name = name
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromOffset(center.X, center.Y)
			f.Size = UDim2.fromOffset(size.X, size.Y)
			f.Rotation = 8
			f.BackgroundColor3 = color
			f.BorderSizePixel = 0
			f.ZIndex = z
			local corner = Instance.new("UICorner")
			corner.CornerRadius = radius
			corner.Parent = f
			f.Parent = root
			return f
		end
		-- a black and gold shaker bottle low on the right, outlined in black
		local at = Vector2.new(282, 330)
		shape("ShakerOutline", at, Vector2.new(52, 92), Color3.new(0, 0, 0), UDim.new(0, 12), 6)
		local body = shape("Shaker", at + Vector2.new(0, 6), Vector2.new(42, 70), hex("#1E1E22"), UDim.new(0, 10), 7)
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = 3
		stroke.Parent = body
		shape("ShakerBand", at + Vector2.new(-1, 8), Vector2.new(40, 16), GOLD, UDim.new(0, 3), 8)
		shape("ShakerCap", at + Vector2.new(-4, -36), Vector2.new(40, 16), GOLD_DARK, UDim.new(0, 5), 8)
		shape("ShakerSpout", at + Vector2.new(-6, -48), Vector2.new(12, 12), RED, UDim.new(0, 3), 8)
	end
end

------------------------------------------------------------------------
function PumpShopRedesign.Build()
	local shop = workspace.Town:FindFirstChild("PumpShop")
	assert(shop, "Workspace.Town.PumpShop is missing")
	assert(game:GetService("ServerStorage"):FindFirstChild("PumpShopBackup_23Oct"), "copy the shop to ServerStorage.PumpShopBackup_23Oct first")
	local before = 0
	for _, d in ipairs(shop:GetDescendants()) do if d:IsA("BasePart") then before += 1 end end
	-- the old room goes (the backup has it)
	for _, name in ipairs({ "Interior", "Supplements", "Gear", "DnaLab", "Apparel", "WindowDisplays" }) do
		local old = shop:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local inside = Instance.new("Folder")
	inside.Name = "Interior"
	inside.Parent = shop
	for _, step in ipairs({ buildRoom, buildShelves, buildBackWall, buildCounter, buildGear, buildDnaLab, buildIslands }) do
		local holder = Instance.new("Folder")
		if step == buildRoom then step(shop, holder) else step(holder) end
		for _, child in ipairs(holder:GetChildren()) do child.Parent = inside end
		holder:Destroy()
		task.wait()
	end
	polishOutside(shop)
	local after, lights = 0, 0
	for _, d in ipairs(shop:GetDescendants()) do
		if d:IsA("BasePart") then after += 1 elseif d:IsA("Light") then lights += 1 end
	end
	return string.format("PUMP SHOP redesigned: %d -> %d parts, %d lights", before, after, lights)
end

return PumpShopRedesign
