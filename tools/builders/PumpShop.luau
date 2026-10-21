-- PumpShop builder (prompt 19, 21 Oct; v3 prompt 23, 21 Oct: "too big, ugly, doesn't fit the town"; run once in Studio,
-- Edit mode): the PUMP SHOP as a corner sports-supplement store in the town hub, on the old parking lot between the gyms.
-- The parking lot is NOT deleted: it is in ServerStorage.PumpShopBackup (move it back to Workspace.Town to undo). A rebuild
-- moves the previous shop there too (PumpShop_old), it never deletes it. The street lamps and bus stop the first shop had
-- moved to the backup (they stood on the sidewalks) go back to Workspace.Town.Street.
-- Builds Workspace.Town.PumpShop (38 x 44 studs, 2 storeys, about the size of the neighbouring town buildings):
--   * Outside: deep red brick with cream trim like the neighbours (corner pilasters, a floor band, a cornice, a parapet,
--     window sills and lintels, drainpipes). Ground floor (front, +X): a black storefront with two big display windows, a
--     glass double door (open), a black and gold striped awning, wall lamps. Above the awning ON the facade: a lit black
--     "PUMP SHOP" sign board with gold letters and three gooseneck lamps, and a hanging blade sign with a dumbbell that sticks
--     out from the corner. Upper floor: normal windows on every side (curtains). North wall (facing the spawn side): a big
--     painted mural (an original flexing arm in a red circle with a dumbbell, "GET PUMPED"; drawn with a SurfaceGui, no
--     image). Roof: parapet, two AC units, a water tank, a hatch.
--   * Inside (ground floor): warm wood floor, cream walls with a wood wainscot, warm lights; the 4 sections, each a counter
--     (tag PumpShopCounter, attribute Section) with a hanging sign, an accent color, a display behind it and a ClerkSpot
--     (PumpShopService puts a clerk there): SUPPLEMENTS and GEAR on the back wall, DNA LAB and APPAREL on the side walls; a
--     shake fridge between them, a podium with a giant tub in the middle. Behind the windows (seen from the street):
--     mannequins in tank tops and lifting belts, and a stack of tubs with a NEW PRE-WORKOUT poster.
--   * Around it: paving with planters, a bench, a chalkboard A-frame ("NEW: PRE-WORKOUT"), a bike rack, trees, a WELCOME mat;
--     the sidewalk gap left by the old driveway is filled. The freed west half of the lot is a small park (lawn, a round
--     plaza with a tree and benches, a path, trees, bushes, flowers, a lamp; town models cloned from Town.Street / Greenery).
--   * Entrance: an invisible part on the paving in front of the doors (the HUD's PUMP SHOP button lands here)
-- Usage (command bar): require(game.ServerStorage._Builders.PumpShop).Build()   (or paste the body into the bar)
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local PumpShop = {}

local X0, X1 = -100, -62  -- back wall, front (the storefront faces +X, the east road)
local Z0, Z1 = 97, 141    -- north wall (the mural side), south wall
local CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2
local FLOOR = 0.4         -- the shop floor's top
local STOREY = 16         -- ground floor height (the upper floor's slab on top)
local TOP = 30.8          -- the walls' top (the roof at 29, a parapet above)
local LOT = { x0 = -152, x1 = -54, z0 = 92, z1 = 145 } -- the old parking lot between the sidewalks

local GOLD = Color3.fromHex("#F6C75A")
local GOLD_LIGHT = Color3.fromHex("#FFF3C4")
local GOLD_DARK = Color3.fromHex("#C98A12")
local BRICK = Color3.fromHex("#7A2E26")
local CREAM = Color3.fromHex("#F7F2E8")
local BLACK = Color3.fromHex("#1B1B1F")
local GRAPHITE = Color3.fromHex("#26262B")
local GRAPHITE_LIGHT = Color3.fromHex("#3A3A42")
local INK = Color3.fromHex("#141417")
local STEEL = Color3.fromHex("#C9CCD2")
local RED = Color3.fromHex("#B3262D")
local WARM = Color3.fromHex("#FFE6B8")
local PAVING = Color3.fromHex("#C4BDB1")
local GOLD_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, GOLD_LIGHT),
	ColorSequenceKeypoint.new(0.5, GOLD),
	ColorSequenceKeypoint.new(1, GOLD_DARK),
})
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local CHALK = Font.fromEnum(Enum.Font.PermanentMarker)

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
-- small props / trim: no shadow, no collision, no queries
local function deco(parent, name, size, cframe, color, material, props)
	local p = part(parent, name, size, cframe, color, material, props)
	p.CastShadow = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end
local function neon(parent, name, size, cframe, color)
	return deco(parent, name, size, cframe, color, Enum.Material.Neon)
end
-- an upright cylinder (height along Y)
local function cylinder(parent, name, height, diameter, position, color, material, collide)
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color,
		material or Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CastShadow = false })
	if not collide then
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	end
	return p
end

-- text on a face of a part (gold gradient unless opts.color)
local function label(board, face, text, opts)
	opts = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.pps or 12 -- (low: TextScaled stops at 100 px, so big signs need few pixels per stud)
	gui.LightInfluence = opts.lightInfluence or 0
	gui.Brightness = opts.brightness or 1.3
	gui.Parent = board
	local text_ = Instance.new("TextLabel")
	text_.BackgroundTransparency = 1
	text_.AnchorPoint = Vector2.new(0.5, 0.5)
	text_.Position = UDim2.fromScale(0.5, 0.5)
	text_.Size = UDim2.fromScale(opts.width or 0.92, opts.height or 0.8)
	text_.Text = text
	text_.TextScaled = true
	text_.Rotation = opts.rotation or 0
	text_.TextColor3 = if opts.color then opts.color else Color3.new(1, 1, 1)
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
	local board = deco(parent, name, Vector3.new(size.X, size.Y, opts.depth or 0.4), CFrame.lookAt(position, position + toward), opts.back or BLACK,
		opts.material or Enum.Material.SmoothPlastic)
	label(board, Enum.NormalId.Front, text, opts)
	if opts.twoSided then label(board, Enum.NormalId.Back, text, opts) end
	return board
end

-- a thin frame around a rectangle (in the plane of `cf`, its X and Y axes)
local function frame(parent, cf: CFrame, width, height, thick, color, material)
	local make = if material then function(n, s, c) return deco(parent, n, s, c, color, material) end else function(n, s, c) return neon(parent, n, s, c, color) end
	make("FrameTop", Vector3.new(width + thick, thick, thick), cf * CFrame.new(0, height / 2, 0))
	make("FrameBottom", Vector3.new(width + thick, thick, thick), cf * CFrame.new(0, -height / 2, 0))
	make("FrameLeft", Vector3.new(thick, height, thick), cf * CFrame.new(-width / 2, 0, 0))
	make("FrameRight", Vector3.new(thick, height, thick), cf * CFrame.new(width / 2, 0, 0))
end

local function pointLight(holder, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Range = range or 20
	l.Brightness = brightness or 1.3
	l.Shadows = false
	l.Color = color or WARM
	l.Parent = holder
	return l
end

local function spotLight(holder, face, color, range, brightness, angle)
	local s = Instance.new("SpotLight")
	s.Face = face
	s.Range = range
	s.Brightness = brightness
	s.Angle = angle or 60
	s.Color = color
	s.Shadows = false
	s.Parent = holder
	return s
end

-- a window on an outside wall. `at` = the window centre on the wall's outer face; `out` = the wall's outward normal.
-- A cream frame and sill, a lintel, a mullion and curtains (upper floor), or a warm lit pane (shop floor).
local CURTAINS = { "#E8DCC4", "#C98A12", "#8E1F25", "#5A6E5A" }
local windowCount = 0
local function window(parent, at: Vector3, out: Vector3, w, h, lit)
	windowCount += 1
	local cf = CFrame.lookAt(at, at + out) -- (-Z = out)
	deco(parent, "WindowFrame", Vector3.new(w + 0.6, h + 0.6, 0.12), cf * CFrame.new(0, 0, -0.06), CREAM, Enum.Material.Concrete)
	deco(parent, "Window", Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, -0.14), if lit then Color3.fromHex("#F2D49A") else Color3.fromHex("#5F7480"),
		if lit then Enum.Material.SmoothPlastic else Enum.Material.Glass, { Reflectance = if lit then 0 else 0.15 })
	deco(parent, "Mullion", Vector3.new(0.14, h, 0.06), cf * CFrame.new(0, 0, -0.2), CREAM, Enum.Material.SmoothPlastic)
	deco(parent, "Sill", Vector3.new(w + 1, 0.25, 0.55), cf * CFrame.new(0, -h / 2 - 0.4, -0.25), CREAM, Enum.Material.Concrete)
	deco(parent, "Lintel", Vector3.new(w + 0.8, 0.45, 0.3), cf * CFrame.new(0, h / 2 + 0.5, -0.12), CREAM, Enum.Material.Concrete)
	if not lit then
		local curtain = Color3.fromHex(CURTAINS[windowCount % #CURTAINS + 1])
		for _, dx in ipairs({ -1, 1 }) do
			deco(parent, "Curtain", Vector3.new(w * 0.22, h - 0.2, 0.05), cf * CFrame.new(dx * w * 0.36, 0, -0.17), curtain, Enum.Material.Fabric)
		end
	end
end

-- a person-shaped mannequin (blocks) in shorts, a tank top and (optional) a lifting belt
local function mannequin(parent, feet: Vector3, facing: Vector3, shorts: Color3, top: Color3, belt: Color3?)
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local skin = Color3.fromHex("#D9D4CC")
	local base = CFrame.lookAt(feet, feet + facing)
	local function block(name, size, offset, color, material)
		return deco(model, name, size, base * CFrame.new(offset), color, material or Enum.Material.SmoothPlastic)
	end
	block("Stand", Vector3.new(2.2, 0.3, 2.2), Vector3.new(0, 0.15, 0), GOLD_DARK, Enum.Material.Metal)
	block("Pole", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 0.9, 0), STEEL, Enum.Material.Metal)
	block("LeftLeg", Vector3.new(0.9, 2.4, 0.9), Vector3.new(-0.55, 2.7, 0), skin)
	block("RightLeg", Vector3.new(0.9, 2.4, 0.9), Vector3.new(0.55, 2.7, 0), skin)
	block("Shorts", Vector3.new(2.3, 1.2, 1.05), Vector3.new(0, 3.6, 0), shorts, Enum.Material.Fabric)
	block("Torso", Vector3.new(2.6, 2.6, 1.2), Vector3.new(0, 5.4, 0), top, Enum.Material.Fabric)
	block("Chest", Vector3.new(2.9, 1.2, 1.3), Vector3.new(0, 6.1, 0), top, Enum.Material.Fabric)
	if belt then
		block("Belt", Vector3.new(2.75, 0.8, 1.35), Vector3.new(0, 4.45, 0), belt, Enum.Material.Leather)
		block("Buckle", Vector3.new(0.7, 0.5, 0.1), Vector3.new(0, 4.45, -0.72), GOLD, Enum.Material.Metal)
	end
	block("LeftArm", Vector3.new(0.9, 2.5, 0.9), Vector3.new(-1.85, 5.3, 0), skin)
	block("RightArm", Vector3.new(0.9, 2.5, 0.9), Vector3.new(1.85, 5.3, 0), skin)
	block("Head", Vector3.new(1.1, 1.2, 1.1), Vector3.new(0, 7.4, 0), skin)
	model.Parent = parent
	return model
end

-- a supplement tub (body, a white label band, a lid)
local function tub(parent, position: Vector3, height, diameter, color, lidColor)
	cylinder(parent, "Tub", height, diameter, position, color)
	cylinder(parent, "Label", height * 0.42, diameter * 1.02, position + Vector3.new(0, height * 0.02, 0), Color3.fromHex("#F2F2F2"))
	cylinder(parent, "Lid", height * 0.16, diameter * 1.04, position + Vector3.new(0, height * 0.58, 0), lidColor or INK)
end

-- product colors (a fixed pattern, so rebuilds look the same)
local PRODUCT_COLORS = { "#E8343C", "#F6C75A", "#3F8CFF", "#36C26B", "#8E5CF0", "#F0882A", "#2B2B30", "#36C2C2" }
local function productColor(i) return Color3.fromHex(PRODUCT_COLORS[(i - 1) % #PRODUCT_COLORS + 1]) end

-- The mural (SurfaceGui on a flat part): black wall, gold border, "GET PUMPED", a red circle with a gold flexing arm
-- (outlined in black) and a dumbbell. Canvas 320 x 440 px (16 x 22 studs at 20 px per stud).
local function mural(board: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.5
	gui.Brightness = 1.2
	gui.Parent = board
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromHex("#1E1E22")
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = gui
	local function shape(name, center: Vector2, size: Vector2, rotation, color, radius, z)
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(center.X, center.Y)
		f.Size = UDim2.fromOffset(size.X, size.Y)
		f.Rotation = rotation or 0
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.ZIndex = z or 1
		if radius then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = radius
			corner.Parent = f
		end
		f.Parent = root
		return f
	end
	local ROUND = UDim.new(0.5, 0)
	-- sun rays behind the circle
	for i = 0, 11 do
		local ray = shape("Ray", Vector2.new(160, 250), Vector2.new(18, 420), i * 15, RED, nil, 1)
		ray.BackgroundTransparency = 0.72
	end
	local circle = shape("Circle", Vector2.new(160, 250), Vector2.new(236, 236), 0, RED, ROUND, 2)
	local ring = Instance.new("UIStroke")
	ring.Color = GOLD
	ring.Thickness = 7
	ring.Parent = circle
	-- the arm: each piece drawn twice, a black outline copy (bigger) under the gold piece
	local pieces = {
		{ "Shoulder", Vector2.new(66, 318), Vector2.new(104, 104), 0, ROUND },
		{ "UpperArm", Vector2.new(140, 318), Vector2.new(176, 72), -6, ROUND },
		{ "Bicep", Vector2.new(132, 284), Vector2.new(124, 80), -12, ROUND },
		{ "Elbow", Vector2.new(214, 308), Vector2.new(74, 74), 0, ROUND },
		{ "Forearm", Vector2.new(228, 242), Vector2.new(66, 158), 10, ROUND },
		{ "Fist", Vector2.new(244, 164), Vector2.new(86, 76), 10, UDim.new(0, 26) },
		{ "Thumb", Vector2.new(212, 180), Vector2.new(30, 54), -32, ROUND },
	}
	for _, p in ipairs(pieces) do
		shape(p[1] .. "Outline", p[2], p[3] + Vector2.new(12, 12), p[4], Color3.new(0, 0, 0), p[5], 3)
	end
	for _, p in ipairs(pieces) do
		local f = shape(p[1], p[2], p[3], p[4], GOLD, p[5], 4)
		local gradient = Instance.new("UIGradient")
		gradient.Color = GOLD_SEQ
		gradient.Rotation = 70
		gradient.Parent = f
	end
	-- a shine on the bicep, knuckle lines, a vein
	shape("Shine", Vector2.new(120, 272), Vector2.new(60, 16), -14, Color3.new(1, 1, 1), ROUND, 5).BackgroundTransparency = 0.45
	for i = -1, 1 do
		shape("Knuckle", Vector2.new(258 + i * 4, 150 + i * 18), Vector2.new(30, 4), 10, Color3.fromHex("#7A5208"), ROUND, 5)
	end
	shape("Vein", Vector2.new(232, 252), Vector2.new(5, 70), 8, Color3.fromHex("#B07A12"), ROUND, 5)
	-- the dumbbell at the bottom
	local db = Vector2.new(160, 404)
	shape("BarOutline", db, Vector2.new(214, 20), -8, Color3.new(0, 0, 0), ROUND, 6)
	shape("Bar", db, Vector2.new(206, 12), -8, STEEL, ROUND, 7)
	for _, side in ipairs({ -1, 1 }) do
		for i, s in ipairs({ { 26, 70, 62 }, { 20, 52, 86 } }) do
			local c = db + Vector2.new(side * s[3] * math.cos(math.rad(-8)), side * s[3] * math.sin(math.rad(-8)))
			shape("PlateOutline", c, Vector2.new(s[1] + 10, s[2] + 10), -8, Color3.new(0, 0, 0), UDim.new(0, 8), 6)
			shape("Plate", c, Vector2.new(s[1], s[2]), -8, if i == 1 then GRAPHITE_LIGHT else GOLD_DARK, UDim.new(0, 6), 7)
		end
	end
	-- the title
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 14)
	title.Size = UDim2.fromOffset(292, 100)
	title.Text = "GET\nPUMPED"
	title.TextScaled = true
	title.FontFace = FONT
	title.TextColor3 = Color3.new(1, 1, 1)
	title.ZIndex = 8
	title.Parent = root
	local gradient = Instance.new("UIGradient")
	gradient.Color = GOLD_SEQ
	gradient.Rotation = 90
	gradient.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Parent = title
	-- the gold border
	local border = Instance.new("Frame")
	border.BackgroundTransparency = 1
	border.Position = UDim2.fromOffset(6, 6)
	border.Size = UDim2.new(1, -12, 1, -12)
	border.ZIndex = 9
	border.Parent = root
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = GOLD
	borderStroke.Thickness = 6
	borderStroke.Parent = border
end

-- a clone of a town model (from Town.Street / Town.Greenery / Town.Plaza), placed with its pivot at `cf`
local function townModel(name: string, cf: CFrame, parent: Instance)
	local town = workspace.Town
	local source = nil
	for _, folderName in ipairs({ "Street", "Greenery", "Plaza" }) do
		local folder = town:FindFirstChild(folderName)
		source = folder and folder:FindFirstChild(name)
		if source then break end
	end
	if not source then return nil end
	local copy = source:Clone()
	local pivot = source:GetPivot()
	-- keep the model's own height above the ground (its pivot's y)
	copy:PivotTo(CFrame.new(cf.X, pivot.Y, cf.Z) * cf.Rotation)
	copy.Parent = parent
	return copy
end

function PumpShop.Build()
	local town = workspace:FindFirstChild("Town")
	assert(town, "Workspace.Town is missing")
	local backup = ServerStorage:FindFirstChild("PumpShopBackup") or Instance.new("Folder")
	backup.Name = "PumpShopBackup"
	backup.Parent = ServerStorage
	-- the parking lot steps aside (kept, not deleted)
	local parking = town:FindFirstChild("Parking")
	if parking then parking.Parent = backup end
	-- the previous shop goes to the backup (replacing an older backup copy)
	local old = town:FindFirstChild("PumpShop")
	if old then
		local older = backup:FindFirstChild("PumpShop_old")
		if older then older:Destroy() end
		old.Name = "PumpShop_old"
		old.Parent = backup
		-- (its counters lose their tag, or PumpShopService would count them as counters too)
		for _, d in ipairs(old:GetDescendants()) do
			if CollectionService:HasTag(d, "PumpShopCounter") then
				CollectionService:RemoveTag(d, "PumpShopCounter")
				d:SetAttribute("WasPumpShopCounter", true)
			end
		end
	end
	-- the street lamps and bus stop the first shop moved away stand on the sidewalks: back to Town.Street
	local street = town:FindFirstChild("Street")
	if street then
		for _, item in ipairs(backup:GetChildren()) do
			if item:GetAttribute("FromFolder") == "Town.Street" then
				item:SetAttribute("FromFolder", nil)
				item.Parent = street
			end
		end
		-- the sidewalk and curb gap where the parking lot's driveway was
		if not street:FindFirstChild("SidewalkFill") then
			part(street, "SidewalkFill", Vector3.new(12, 0.6, 4), CFrame.new(-104, 0.05, 90), Color3.fromHex("#B9B2A6"), Enum.Material.Concrete)
			part(street, "CurbFill", Vector3.new(12, 0.78, 0.4), CFrame.new(-104, -0.02, 87.8), Color3.fromHex("#9C978E"), Enum.Material.Concrete)
		end
	end

	local shop = Instance.new("Model")
	shop.Name = "PumpShop"
	shop.Parent = town
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = shop
		return f
	end
	local width, depth = Z1 - Z0, X1 - X0

	--------------------------------------------------------------------
	-- Shell: floor, brick walls, the upper floor's slab, roof, cream trim
	--------------------------------------------------------------------
	local shell = folder("Building")
	part(shell, "Floor", Vector3.new(depth, 0.4, width), CFrame.new(CX, 0.2, CZ), Color3.fromHex("#A57A4E"), Enum.Material.WoodPlanks)
	local wallH = TOP - FLOOR
	local sides = {
		back = { size = Vector3.new(1, wallH, width), pos = Vector3.new(X0 + 0.5, FLOOR + wallH / 2, CZ), out = -Vector3.xAxis },
		north = { size = Vector3.new(depth, wallH, 1), pos = Vector3.new(CX, FLOOR + wallH / 2, Z0 + 0.5), out = -Vector3.zAxis },
		south = { size = Vector3.new(depth, wallH, 1), pos = Vector3.new(CX, FLOOR + wallH / 2, Z1 - 0.5), out = Vector3.zAxis },
	}
	for name, s in pairs(sides) do
		part(shell, name .. "Wall", s.size, CFrame.new(s.pos), BRICK, Enum.Material.Brick)
	end
	local upperH = TOP - (FLOOR + STOREY)
	part(shell, "FrontUpper", Vector3.new(1, upperH, width), CFrame.new(X1 - 0.5, FLOOR + STOREY + upperH / 2, CZ), BRICK, Enum.Material.Brick)
	part(shell, "UpperFloor", Vector3.new(depth - 2, 0.4, width - 2), CFrame.new(CX, FLOOR + STOREY - 0.2, CZ), Color3.fromHex("#F2EEE6"), Enum.Material.SmoothPlastic)
	part(shell, "Roof", Vector3.new(depth - 2, 0.4, width - 2), CFrame.new(CX, 29.2, CZ), Color3.fromHex("#5E5A54"), Enum.Material.Concrete)
	-- cream trim all round: a dark stone base, the floor band, the cornice, the parapet cap, corner pilasters
	local function ring(name, y, height, outset, color, material, front)
		deco(shell, name, Vector3.new(depth + outset * 2, height, 0.3 + outset), CFrame.new(CX, y, Z0 - outset / 2 + 0.1), color, material)
		deco(shell, name, Vector3.new(depth + outset * 2, height, 0.3 + outset), CFrame.new(CX, y, Z1 + outset / 2 - 0.1), color, material)
		deco(shell, name, Vector3.new(0.3 + outset, height, width + outset * 2), CFrame.new(X0 - outset / 2 + 0.1, y, CZ), color, material)
		if front then deco(shell, name, Vector3.new(0.3 + outset, height, width + outset * 2), CFrame.new(X1 + outset / 2 - 0.1, y, CZ), color, material) end
	end
	ring("Base", FLOOR + 0.8, 1.6, 0.3, Color3.fromHex("#3A3632"), Enum.Material.Slate, false)
	ring("FloorBand", FLOOR + STOREY + 0.2, 0.5, 0.3, CREAM, Enum.Material.Concrete, true)
	ring("Cornice", 28.7, 0.9, 0.6, CREAM, Enum.Material.Concrete, true)
	ring("ParapetCap", TOP + 0.15, 0.3, 0.2, CREAM, Enum.Material.Concrete, true)
	for _, x in ipairs({ X0, X1 }) do
		for _, z in ipairs({ Z0, Z1 }) do
			deco(shell, "Pilaster", Vector3.new(1.3, TOP - FLOOR, 1.3), CFrame.new(x, FLOOR + (TOP - FLOOR) / 2, z), CREAM, Enum.Material.Concrete)
		end
	end
	-- drainpipes
	for _, at in ipairs({ Vector3.new(-80.6, 0, Z0 - 0.35), Vector3.new(X1 - 2, 0, Z1 + 0.35), Vector3.new(X0 - 0.35, 0, Z0 + 3) }) do
		deco(shell, "Drainpipe", Vector3.new(0.35, 28, 0.35), CFrame.new(at.X, FLOOR + 14, at.Z), BLACK, Enum.Material.Metal)
	end

	--------------------------------------------------------------------
	-- Windows on every side (upper floor: curtains; ground floor sides: warm lit panes) and the mural
	--------------------------------------------------------------------
	local windows = folder("Windows")
	local upperY = FLOOR + STOREY + 7.6
	for _, z in ipairs({ 102.5, 113.5, 124.5, 135.5 }) do window(windows, Vector3.new(X1, upperY, z), Vector3.xAxis, 3.2, 5, false) end
	for _, z in ipairs({ 102, 113, 125, 136 }) do window(windows, Vector3.new(X0, upperY, z), -Vector3.xAxis, 3.2, 5, false) end
	for _, x in ipairs({ -95, -86, -77, -68 }) do window(windows, Vector3.new(x, upperY, Z1), Vector3.zAxis, 3.2, 5, false) end
	for _, x in ipairs({ -76, -68 }) do window(windows, Vector3.new(x, upperY, Z0), -Vector3.zAxis, 3.2, 5, false) end
	for _, x in ipairs({ -92, -81, -70 }) do window(windows, Vector3.new(x, FLOOR + 7, Z1), Vector3.zAxis, 4, 6.5, true) end
	for _, x in ipairs({ -76, -68 }) do window(windows, Vector3.new(x, FLOOR + 7, Z0), -Vector3.zAxis, 4, 6.5, true) end
	for _, z in ipairs({ 104, 115 }) do window(windows, Vector3.new(X0, FLOOR + 7, z), -Vector3.xAxis, 4, 6.5, true) end
	-- the back door with a small canopy and a lamp
	local backDoor = CFrame.lookAt(Vector3.new(X0 - 0.06, FLOOR + 3.1, 128), Vector3.new(X0 - 10, FLOOR + 3.1, 128))
	deco(windows, "BackDoorFrame", Vector3.new(3.2, 6.6, 0.1), backDoor, CREAM, Enum.Material.Concrete)
	deco(windows, "BackDoor", Vector3.new(2.6, 6, 0.1), backDoor * CFrame.new(0, -0.2, -0.08), Color3.fromHex("#4A4C50"), Enum.Material.Metal)
	deco(windows, "BackCanopy", Vector3.new(4, 0.25, 1.6), backDoor * CFrame.new(0, 3.6, -0.8), BLACK, Enum.Material.Metal)
	local backLamp = neon(windows, "BackLamp", Vector3.new(0.5, 0.7, 0.5), backDoor * CFrame.new(2.1, 2.4, -0.35), WARM)
	pointLight(backLamp, WARM, 10, 0.8)
	-- the mural on the north wall's west half (faces the spawn side)
	local muralPart = deco(windows, "Mural", Vector3.new(16, 22, 0.1), CFrame.lookAt(Vector3.new(-90, FLOOR + 14, Z0 - 0.45), Vector3.new(-90, FLOOR + 14, Z0 - 10)) -- (in front of the floor band),
		Color3.fromHex("#1E1E22"), Enum.Material.SmoothPlastic)
	mural(muralPart)

	--------------------------------------------------------------------
	-- The storefront (+X): black frames, display windows, the open double door, awning, sign board, blade sign, lamps
	--------------------------------------------------------------------
	local front = folder("Storefront")
	local fx = X1 - 0.5
	local doorZ0, doorZ1 = CZ - 4, CZ + 4 -- (8 wide)
	local doorTop = FLOOR + 11
	local glassTop = FLOOR + 12.2
	-- display windows (z: pilaster to door post)
	for _, span in ipairs({ { Z0 + 0.7, doorZ0 - 0.5 }, { doorZ1 + 0.5, Z1 - 0.7 } }) do
		local zc, w = (span[1] + span[2]) / 2, span[2] - span[1]
		part(front, "Kickplate", Vector3.new(0.8, 1.6, w), CFrame.new(fx, FLOOR + 0.8, zc), BLACK, Enum.Material.Metal)
		part(front, "DisplayGlass", Vector3.new(0.2, glassTop - FLOOR - 1.6, w), CFrame.new(fx, (FLOOR + 1.6 + glassTop) / 2, zc), Color3.fromHex("#CFE3EC"),
			Enum.Material.Glass, { Transparency = 0.5, CastShadow = false })
		deco(front, "WindowMullion", Vector3.new(0.4, glassTop - FLOOR - 1.6, 0.3), CFrame.new(fx + 0.1, (FLOOR + 1.6 + glassTop) / 2, zc), BLACK, Enum.Material.Metal)
		neon(front, "SillGlow", Vector3.new(0.15, 0.15, w - 0.4), CFrame.new(fx + 0.45, FLOOR + 1.65, zc), GOLD)
	end
	-- door posts, header, the transom bar and the black fascia up to the floor band
	for _, z in ipairs({ doorZ0 - 0.25, doorZ1 + 0.25 }) do
		part(front, "DoorPost", Vector3.new(0.9, glassTop - FLOOR, 0.6), CFrame.new(fx, (FLOOR + glassTop) / 2, z), BLACK, Enum.Material.Metal)
	end
	deco(front, "DoorHeader", Vector3.new(0.8, glassTop - doorTop, doorZ1 - doorZ0), CFrame.new(fx, (doorTop + glassTop) / 2, CZ), BLACK, Enum.Material.Metal)
	part(front, "Fascia", Vector3.new(1, FLOOR + STOREY - glassTop, width), CFrame.new(fx, (glassTop + FLOOR + STOREY) / 2, CZ), BLACK, Enum.Material.SmoothPlastic)
	deco(front, "FasciaTrim", Vector3.new(0.3, 0.2, width - 1.4), CFrame.new(X1 + 0.05, glassTop + 0.1, CZ), GOLD_DARK, Enum.Material.Metal)
	-- the glass double door, open (leaves swung inside), gold handles
	for _, z in ipairs({ doorZ0 + 0.2, doorZ1 - 0.2 }) do
		deco(front, "DoorLeaf", Vector3.new(3.8, doorTop - FLOOR - 0.2, 0.15), CFrame.new(fx - 2.1, (FLOOR + doorTop) / 2, z), Color3.fromHex("#CFE3EC"), Enum.Material.Glass,
			{ Transparency = 0.45 })
		deco(front, "DoorLeafFrame", Vector3.new(3.8, 0.3, 0.2), CFrame.new(fx - 2.1, FLOOR + 0.3, z), BLACK, Enum.Material.Metal)
		deco(front, "DoorHandle", Vector3.new(0.2, 2.4, 0.2), CFrame.new(fx - 3.6, FLOOR + 4.6, z + (if z < CZ then 0.25 else -0.25)), GOLD, Enum.Material.Metal)
	end
	-- wall lamps by the door
	for _, z in ipairs({ doorZ0 - 0.25, doorZ1 + 0.25 }) do
		local lamp = neon(front, "WallLamp", Vector3.new(0.6, 0.9, 0.6), CFrame.new(X1 + 0.8, FLOOR + 9.3, z), WARM)
		deco(front, "WallLampCap", Vector3.new(0.9, 0.2, 0.9), CFrame.new(X1 + 0.8, FLOOR + 9.85, z), BLACK, Enum.Material.Metal)
		deco(front, "WallLampArm", Vector3.new(0.8, 0.12, 0.12), CFrame.new(X1 + 0.3, FLOOR + 9.8, z), BLACK, Enum.Material.Metal)
		pointLight(lamp, WARM, 12, 1)
	end
	-- the awning: black and gold stripes sloping to the street, a black valance with gold piping, two arms
	local awningZ0, awningZ1 = Z0 + 1.6, Z1 - 1.6
	local stripes = 16
	local stripeW = (awningZ1 - awningZ0) / stripes
	local awningTop = glassTop + 1.9
	for i = 0, stripes - 1 do
		local z = awningZ0 + stripeW * (i + 0.5)
		deco(front, "Awning", Vector3.new(4.8, 0.2, stripeW), CFrame.new(X1 + 2.25, awningTop - 0.82, z) * CFrame.Angles(0, 0, math.rad(-20)),
			if i % 2 == 0 then BLACK else GOLD, Enum.Material.Fabric)
	end
	deco(front, "Valance", Vector3.new(0.15, 0.8, awningZ1 - awningZ0), CFrame.new(X1 + 4.5, awningTop - 2.0, CZ), BLACK, Enum.Material.Fabric)
	deco(front, "ValanceTrim", Vector3.new(0.2, 0.14, awningZ1 - awningZ0), CFrame.new(X1 + 4.52, awningTop - 1.68, CZ), GOLD, Enum.Material.Fabric)
	for _, z in ipairs({ awningZ0, awningZ1 }) do
		deco(front, "AwningArm", Vector3.new(4.8, 0.2, 0.2), CFrame.new(X1 + 2.25, awningTop - 1.05, z) * CFrame.Angles(0, 0, math.rad(-20)), BLACK, Enum.Material.Metal)
	end
	-- the sign board ON the facade, above the awning: gold letters on black, a gold frame, three gooseneck lamps
	local signY = FLOOR + STOREY + 2.7
	local board = sign(front, "ShopSign", Vector2.new(24, 3.6), Vector3.new(X1 + 0.25, signY, CZ), Vector3.xAxis, "PUMP SHOP",
		{ back = BLACK, depth = 0.5, pps = 12, stroke = 2.5, height = 0.86 })
	frame(front, board.CFrame * CFrame.new(0, 0, -0.28), 24.2, 3.8, 0.2, GOLD)
	for _, dz in ipairs({ -8, 0, 8 }) do
		local base = Vector3.new(X1 + 0.1, signY + 2.7, CZ + dz)
		deco(front, "LampArm", Vector3.new(1.6, 0.14, 0.14), CFrame.new(base + Vector3.new(0.8, 0.1, 0)), BLACK, Enum.Material.Metal)
		local shade = deco(front, "LampShade", Vector3.new(0.6, 0.35, 0.8), CFrame.new(base + Vector3.new(1.6, 0, 0)), BLACK, Enum.Material.Metal)
		spotLight(shade, Enum.NormalId.Bottom, Color3.fromHex("#FFE9B8"), 8, 2.2, 75)
		neon(front, "LampBulb", Vector3.new(0.4, 0.06, 0.6), CFrame.new(base + Vector3.new(1.6, -0.2, 0)), WARM)
	end
	-- the blade sign: a black board with a gold dumbbell and "PUMP", hanging from an iron bracket at the north corner
	local bladeZ = Z0 + 2.2
	local bladeC = Vector3.new(X1 + 2.9, FLOOR + STOREY + 1.6, bladeZ)
	deco(front, "BladeBracket", Vector3.new(4.6, 0.25, 0.25), CFrame.new(X1 + 2.3, bladeC.Y + 2.75, bladeZ), BLACK, Enum.Material.Metal)
	for _, dx in ipairs({ -1.4, 1.4 }) do
		deco(front, "BladeHanger", Vector3.new(0.1, 0.6, 0.1), CFrame.new(bladeC + Vector3.new(dx, 2.45, 0)), BLACK, Enum.Material.Metal)
	end
	deco(front, "BladeBoard", Vector3.new(4.2, 4.2, 0.3), CFrame.new(bladeC), BLACK, Enum.Material.SmoothPlastic)
	frame(front, CFrame.new(bladeC), 4.2, 4.2, 0.18, GOLD, Enum.Material.Metal)
	local icon = bladeC + Vector3.new(0, 0.75, 0)
	deco(front, "BladeBar", Vector3.new(2.4, 0.3, 0.42), CFrame.new(icon), GOLD_LIGHT, Enum.Material.Metal)
	for _, dx in ipairs({ -1, 1 }) do
		deco(front, "BladePlate", Vector3.new(0.4, 1.6, 0.46), CFrame.new(icon + Vector3.new(dx * 1.0, 0, 0)), GOLD, Enum.Material.Metal)
		deco(front, "BladePlateSmall", Vector3.new(0.3, 1.1, 0.46), CFrame.new(icon + Vector3.new(dx * 1.35, 0, 0)), GOLD_DARK, Enum.Material.Metal)
	end
	local bladeText = deco(front, "BladeText", Vector3.new(3.6, 1.1, 0.34), CFrame.new(bladeC + Vector3.new(0, -1.2, 0)), BLACK, Enum.Material.SmoothPlastic,
		{ Transparency = 1 })
	label(bladeText, Enum.NormalId.Front, "PUMP", { pps = 30, height = 0.95 })
	label(bladeText, Enum.NormalId.Back, "PUMP", { pps = 30, height = 0.95 })

	--------------------------------------------------------------------
	-- Roof: AC units, a water tank, a hatch, a vent
	--------------------------------------------------------------------
	local roof = folder("Roof")
	local roofTop = 29.4
	for _, z in ipairs({ 106, 111 }) do
		local c = Vector3.new(-88, roofTop + 0.8, z)
		part(roof, "AcUnit", Vector3.new(3, 1.6, 2.4), CFrame.new(c), Color3.fromHex("#C9C6BF"), Enum.Material.Metal, { CastShadow = false })
		cylinder(roof, "AcFan", 0.12, 1.6, c + Vector3.new(0, 0.86, 0), Color3.fromHex("#4A4C50"), Enum.Material.DiamondPlate)
		deco(roof, "AcVent", Vector3.new(0.1, 1, 2), CFrame.new(c + Vector3.new(1.55, 0, 0)), Color3.fromHex("#9E9B94"), Enum.Material.DiamondPlate)
	end
	local tank = Vector3.new(-92, roofTop, 132)
	for _, d in ipairs({ Vector3.new(-1.4, 0, -1.4), Vector3.new(1.4, 0, -1.4), Vector3.new(-1.4, 0, 1.4), Vector3.new(1.4, 0, 1.4) }) do
		deco(roof, "TankLeg", Vector3.new(0.25, 3, 0.25), CFrame.new(tank + d + Vector3.new(0, 1.5, 0)), BLACK, Enum.Material.Metal)
	end
	cylinder(roof, "Tank", 3.6, 4.2, tank + Vector3.new(0, 4.8, 0), Color3.fromHex("#8C6E4F"), Enum.Material.WoodPlanks)
	for _, y in ipairs({ 3.6, 6 }) do cylinder(roof, "Hoop", 0.2, 4.35, tank + Vector3.new(0, y, 0), BLACK, Enum.Material.Metal) end
	cylinder(roof, "TankRoof", 0.5, 4.5, tank + Vector3.new(0, 6.85, 0), BLACK, Enum.Material.Metal)
	cylinder(roof, "TankCap", 0.5, 2.4, tank + Vector3.new(0, 7.3, 0), BLACK, Enum.Material.Metal)
	part(roof, "Hatch", Vector3.new(2.6, 1, 2.6), CFrame.new(-72, roofTop + 0.5, 130), Color3.fromHex("#8E8A82"), Enum.Material.Concrete, { CastShadow = false })
	cylinder(roof, "Vent", 1.8, 0.6, Vector3.new(-72, roofTop + 0.9, 108), STEEL, Enum.Material.Metal)

	--------------------------------------------------------------------
	-- Inside: cream walls, wainscot, ceiling lights
	--------------------------------------------------------------------
	local inside = folder("Interior")
	local innerH = STOREY - 0.4
	local panels = {
		{ cf = CFrame.new(X0 + 1.1, 0, CZ), len = width - 2, alongZ = true },
		{ cf = CFrame.new(CX + 0.4, 0, Z0 + 1.1), len = depth - 2.8, alongZ = false },
		{ cf = CFrame.new(CX + 0.4, 0, Z1 - 1.1), len = depth - 2.8, alongZ = false },
	}
	for _, p in ipairs(panels) do
		local function strip(name, height, y, color, material, thick)
			local s = if p.alongZ then Vector3.new(thick, height, p.len) else Vector3.new(p.len, height, thick)
			deco(inside, name, s, p.cf + Vector3.new(0, y, 0), color, material)
		end
		strip("Wainscot", 3.4, FLOOR + 1.7, Color3.fromHex("#4A3222"), Enum.Material.WoodPlanks, 0.2)
		strip("Rail", 0.3, FLOOR + 3.45, GOLD_DARK, Enum.Material.Metal, 0.35)
		strip("WallPanel", innerH - 3.6, FLOOR + 3.6 + (innerH - 3.6) / 2, Color3.fromHex("#EDE6D8"), Enum.Material.SmoothPlastic, 0.12)
	end
	for _, x in ipairs({ -88, -72 }) do
		for _, z in ipairs({ 107, 119, 131 }) do
			local fixture = neon(inside, "CeilingLight", Vector3.new(5, 0.15, 1.3), CFrame.new(x, FLOOR + STOREY - 0.48, z), Color3.new(1, 0.98, 0.94))
			deco(inside, "LightFrame", Vector3.new(5.5, 0.12, 1.8), CFrame.new(x, FLOOR + STOREY - 0.42, z), GOLD_DARK, Enum.Material.Metal)
			pointLight(fixture, WARM, 22, 1.5)
		end
	end
	-- the middle: a round podium with a giant tub under a spotlight
	local podium = Vector3.new(CX + 1, FLOOR, CZ)
	cylinder(inside, "Podium", 1.2, 6.4, podium + Vector3.new(0, 0.6, 0), GRAPHITE, Enum.Material.SmoothPlastic, true)
	cylinder(inside, "PodiumRim", 0.25, 6.7, podium + Vector3.new(0, 1.25, 0), GOLD_DARK, Enum.Material.Metal)
	tub(inside, podium + Vector3.new(0, 3.6, 0), 4.6, 3.4, Color3.fromHex("#8E5CF0"), GOLD)
	local podiumLabel = sign(inside, "PodiumLabel", Vector2.new(2.2, 1.3), podium + Vector3.new(1.76, 3.65, 0), Vector3.xAxis, "MAX\nGAINS",
		{ back = Color3.fromHex("#F2F2F2"), color = Color3.fromHex("#5B2FB0"), pps = 30, depth = 0.05, height = 0.9, stroke = 0 })
	podiumLabel.Transparency = 1
	local spot = deco(inside, "PodiumSpot", Vector3.new(1, 0.4, 1), CFrame.new(podium + Vector3.new(0, STOREY - 0.6, 0)), BLACK, Enum.Material.Metal)
	spotLight(spot, Enum.NormalId.Bottom, Color3.fromHex("#FFF0C8"), 18, 2.5, 35)
	-- the shake fridge on the back wall between SUPPLEMENTS and GEAR
	local fridge = CFrame.lookAt(Vector3.new(X0 + 2.5, FLOOR, CZ), Vector3.new(X0 + 10, FLOOR, CZ)) -- (-Z = into the room)
	part(inside, "Fridge", Vector3.new(6, 9, 2.4), fridge * CFrame.new(0, 4.5, 0), Color3.fromHex("#E9EDF2"), Enum.Material.SmoothPlastic, { CastShadow = false })
	neon(inside, "FridgeInside", Vector3.new(5, 7, 0.1), fridge * CFrame.new(0, 4.6, -1.25), Color3.fromHex("#BFF5FF"))
	for row = 0, 2 do
		deco(inside, "FridgeShelf", Vector3.new(5, 0.12, 1.2), fridge * CFrame.new(0, 1.6 + row * 2.3, -1.85), STEEL, Enum.Material.Metal)
		for i = -2, 2 do
			cylinder(inside, "Bottle", 1.4, 0.6, (fridge * CFrame.new(i * 0.95, 2.35 + row * 2.3, -1.9)).Position, productColor(i + row * 3 + 3))
		end
	end
	for _, dx in ipairs({ -1, 1 }) do
		deco(inside, "FridgeSide", Vector3.new(0.3, 9, 1.3), fridge * CFrame.new(dx * 2.85, 4.5, -1.85), Color3.fromHex("#E9EDF2"), Enum.Material.SmoothPlastic)
	end
	deco(inside, "FridgeTop", Vector3.new(6, 0.9, 1.3), fridge * CFrame.new(0, 8.55, -1.85), Color3.fromHex("#E9EDF2"), Enum.Material.SmoothPlastic)
	deco(inside, "FridgeGlass", Vector3.new(5.5, 7.6, 0.1), fridge * CFrame.new(0, 4.6, -2.5), Color3.fromHex("#DDF6FF"), Enum.Material.Glass, { Transparency = 0.7 })
	sign(inside, "FridgeSign", Vector2.new(5.6, 0.8), (fridge * CFrame.new(0, 8.55, -2.55)).Position, fridge.LookVector, "COLD SHAKES",
		{ back = Color3.fromHex("#1F5FBF"), color = Color3.new(1, 1, 1), pps = 30, depth = 0.1, stroke = 0 })
	-- plants in the back corners
	for _, z in ipairs({ Z0 + 2.4, Z1 - 2.4 }) do
		local c = Vector3.new(X0 + 2.4, FLOOR, z)
		cylinder(inside, "Pot", 1.6, 1.8, c + Vector3.new(0, 0.8, 0), Color3.fromHex("#B5654A"), Enum.Material.Concrete)
		deco(inside, "Plant", Vector3.new(2.6, 3, 2.6), CFrame.new(c + Vector3.new(0, 3, 0)), Color3.fromHex("#3D8A3A"), Enum.Material.Grass, { Shape = Enum.PartType.Ball })
	end

	--------------------------------------------------------------------
	-- The four sections: counter (in front of a wall, facing the room), sign, display, clerk spot, accent color
	--------------------------------------------------------------------
	local sections = {
		{ id = "Supplements", label = "SUPPLEMENTS", pos = Vector3.new(X0 + 8.5, 0, CZ - 11), facing = Vector3.xAxis, accent = Color3.fromHex("#FF7A3D") },
		{ id = "Gear", label = "GEAR", pos = Vector3.new(X0 + 8.5, 0, CZ + 11), facing = Vector3.xAxis, accent = GOLD },
		{ id = "DnaLab", label = "DNA LAB", pos = Vector3.new(CX + 5, 0, Z0 + 8.5), facing = Vector3.zAxis, accent = Color3.fromHex("#36E0E0") },
		{ id = "Apparel", label = "APPAREL", pos = Vector3.new(CX + 5, 0, Z1 - 8.5), facing = -Vector3.zAxis, accent = Color3.fromHex("#FF5FA2") },
	}
	local W, CW = 12, 10 -- display and counter width
	for _, s in ipairs(sections) do
		local model = Instance.new("Model")
		model.Name = s.id
		local face = CFrame.lookAt(s.pos, s.pos + s.facing) -- (-Z = toward the room)
		local function at(offset: Vector3) return face * CFrame.new(offset) end
		local counter = part(model, "Counter", Vector3.new(CW, 3.6, 3), at(Vector3.new(0, FLOOR + 1.8, 0)), GRAPHITE, Enum.Material.SmoothPlastic)
		counter:SetAttribute("Section", s.id)
		CollectionService:AddTag(counter, "PumpShopCounter")
		deco(model, "CounterTop", Vector3.new(CW + 0.4, 0.3, 3.4), at(Vector3.new(0, FLOOR + 3.75, 0)), Color3.fromHex("#E9E4DA"), Enum.Material.Marble)
		deco(model, "CounterEdge", Vector3.new(CW + 0.5, 0.2, 0.2), at(Vector3.new(0, FLOOR + 3.55, -1.65)), GOLD_DARK, Enum.Material.Metal)
		neon(model, "CounterStripe", Vector3.new(CW - 1, 0.2, 0.1), at(Vector3.new(0, FLOOR + 2.7, -1.55)), s.accent)
		neon(model, "ToeLight", Vector3.new(CW - 0.5, 0.15, 0.1), at(Vector3.new(0, FLOOR + 0.25, -1.55)), s.accent)
		local counterFront = deco(model, "CounterFront", Vector3.new(CW - 2, 1.1, 0.05), at(Vector3.new(0, FLOOR + 1.6, -1.53)), BLACK, Enum.Material.SmoothPlastic,
			{ Transparency = 1 })
		counterFront.CFrame = CFrame.lookAt(counterFront.Position, counterFront.Position + face.LookVector) -- (its Front face to the room)
		label(counterFront, Enum.NormalId.Front, s.label, { pps = 30, color = s.accent })
		deco(model, "Till", Vector3.new(1.4, 0.7, 1.1), at(Vector3.new(CW / 2 - 1.4, FLOOR + 4.25, 0.3)), INK, Enum.Material.SmoothPlastic)
		neon(model, "TillScreen", Vector3.new(1.1, 0.6, 0.1), at(Vector3.new(CW / 2 - 1.4, FLOOR + 4.9, 0.6)) * CFrame.Angles(math.rad(-15), 0, 0), s.accent)
		part(model, "ClerkSpot", Vector3.new(2, 0.2, 2), at(Vector3.new(0, FLOOR + 0.1, 3.4)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
			{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }):SetAttribute("Section", s.id)
		-- the hanging sign
		local signPart = sign(model, "SectionSign", Vector2.new(W - 2, 2.4), at(Vector3.new(0, FLOOR + 11.6, 1)).Position, face.LookVector, s.label,
			{ back = INK, twoSided = true })
		frame(model, signPart.CFrame, W - 1.7, 2.7, 0.2, s.accent)
		for _, dx in ipairs({ -1, 1 }) do
			deco(model, "Chain", Vector3.new(0.12, 2.9, 0.12), signPart.CFrame * CFrame.new(dx * (W / 2 - 2), 2.75, 0), STEEL, Enum.Material.Metal)
		end
		-- the display against the wall, framed in the accent color, lit
		local wall = at(Vector3.new(0, 0, 7))
		deco(model, "Display", Vector3.new(W, 9, 0.6), wall * CFrame.new(0, FLOOR + 5.5, 0.3), INK, Enum.Material.SmoothPlastic)
		frame(model, wall * CFrame.new(0, FLOOR + 5.5, 0), W, 9, 0.25, s.accent)
		local glow = neon(model, "DisplayGlow", Vector3.new(W - 1, 0.2, 0.2), wall * CFrame.new(0, FLOOR + 9.6, -0.3), s.accent)
		pointLight(glow, s.accent, 10, 1)
		if s.id == "Supplements" then
			for row = 0, 2 do
				deco(model, "Shelf", Vector3.new(W - 1, 0.25, 1.4), wall * CFrame.new(0, FLOOR + 2.3 + row * 2.7, -0.6), STEEL, Enum.Material.Metal)
				for i = -2, 2 do
					local pos = (wall * CFrame.new(i * 2.1, FLOOR + 3.25 + row * 2.7, -0.6)).Position
					if (i + row) % 2 == 0 then
						tub(model, pos, 1.5, 1.3, productColor(i + row + 5), if row == 1 then GOLD else INK)
					else
						cylinder(model, "Shaker", 1.6, 0.85, pos, productColor(i + row + 5))
						cylinder(model, "ShakerCap", 0.3, 0.9, pos + Vector3.new(0, 0.95, 0), INK)
					end
				end
			end
		elseif s.id == "Gear" then
			deco(model, "Pegboard", Vector3.new(W - 1, 5, 0.25), wall * CFrame.new(0, FLOOR + 6.6, -0.1), Color3.fromHex("#5A3D2B"), Enum.Material.WoodPlanks)
			for i = -2, 2 do
				local hook = wall * CFrame.new(i * 2.1, FLOOR + 8.6, -0.7)
				deco(model, "Hook", Vector3.new(0.2, 0.2, 0.7), hook, STEEL, Enum.Material.Metal)
				local colors = { "#2B2B30", "#B3262D", "#E8B23A" }
				deco(model, if i % 2 == 0 then "Belt" else "Strap", Vector3.new(if i % 2 == 0 then 1.3 else 0.5, 3.2, 0.25), hook * CFrame.new(0, -1.7, -0.2),
					Color3.fromHex(colors[(i + 3) % 3 + 1]), Enum.Material.Leather)
				if i % 2 == 0 then deco(model, "Buckle", Vector3.new(0.9, 0.5, 0.1), hook * CFrame.new(0, -2.4, -0.4), GOLD, Enum.Material.Metal) end
			end
			deco(model, "LowShelf", Vector3.new(W - 1, 0.25, 1.4), wall * CFrame.new(0, FLOOR + 2.3, -0.6), STEEL, Enum.Material.Metal)
			for i = -1, 1 do
				cylinder(model, "KneeSleeve", 1.3, 1.1, (wall * CFrame.new(i * 3, FLOOR + 3.1, -0.6)).Position, Color3.fromHex(if i == 0 then "#B3262D" else "#2B2B30"),
					Enum.Material.Fabric)
			end
		elseif s.id == "Apparel" then
			local tops = { { "#B3262D", "#1E1E22" }, { "#1F5FBF", "#D9A82E" } }
			for i, pair in ipairs(tops) do
				mannequin(model, (wall * CFrame.new((i - 1.5) * 5, FLOOR, -2.6)).Position, face.LookVector, Color3.fromHex(pair[2]), Color3.fromHex(pair[1]))
			end
		elseif s.id == "DnaLab" then
			deco(model, "LabBench", Vector3.new(W - 1, 0.35, 1.6), wall * CFrame.new(0, FLOOR + 3, -0.6), Color3.fromHex("#E9EDF2"), Enum.Material.SmoothPlastic)
			for i = -2, 2 do
				local pos = (wall * CFrame.new(i * 2.1, FLOOR + 5.2, -0.7)).Position
				cylinder(model, "SampleTube", 3.6, 0.9, pos, Color3.fromHex(if i % 2 == 0 then "#36C2C2" else "#8E5CF0"), Enum.Material.Neon)
				cylinder(model, "TubeGlass", 3.8, 1.1, pos, Color3.fromHex("#DDF6FF"), Enum.Material.Glass).Transparency = 0.7
				cylinder(model, "TubeCap", 0.35, 1.15, pos + Vector3.new(0, 2, 0), STEEL, Enum.Material.Metal)
			end
		end
		model.Parent = shop
	end

	--------------------------------------------------------------------
	-- Behind the display windows (seen from the street): mannequins with gear, a stack of tubs and a poster
	--------------------------------------------------------------------
	local display = folder("WindowDisplays")
	for _, span in ipairs({ { Z0 + 1.5, CZ - 5.5 }, { CZ + 5.5, Z1 - 1.5 } }) do
		local zc, w = (span[1] + span[2]) / 2, span[2] - span[1]
		part(display, "Platform", Vector3.new(3.4, 1, w), CFrame.new(X1 - 2.6, FLOOR + 0.5, zc), GRAPHITE, Enum.Material.SmoothPlastic)
		deco(display, "PlatformTrim", Vector3.new(3.5, 0.15, w + 0.1), CFrame.new(X1 - 2.6, FLOOR + 1.05, zc), GOLD_DARK, Enum.Material.Metal)
		local spotlight = deco(display, "WindowSpot", Vector3.new(0.8, 0.3, 0.8), CFrame.new(X1 - 3, FLOOR + STOREY - 0.55, zc), BLACK, Enum.Material.Metal)
		spotLight(spotlight, Enum.NormalId.Bottom, Color3.fromHex("#FFF0C8"), 16, 2.2, 70)
	end
	local north = (Z0 + 1.5 + CZ - 5.5) / 2
	mannequin(display, Vector3.new(X1 - 2.6, FLOOR + 1, north - 3.4), Vector3.xAxis, Color3.fromHex("#1E1E22"), Color3.fromHex("#B3262D"), Color3.fromHex("#2B2B30"))
	mannequin(display, Vector3.new(X1 - 2.6, FLOOR + 1, north + 3.4), Vector3.xAxis, Color3.fromHex("#D9A82E"), Color3.fromHex("#1F5FBF"), Color3.fromHex("#B3262D"))
	local south = (CZ + 5.5 + Z1 - 1.5) / 2
	local stack = { { -3, 0 }, { -1.6, 0 }, { -0.2, 0 }, { -2.3, 1 }, { -0.9, 1 }, { -1.6, 2 } }
	for i, s in ipairs(stack) do
		tub(display, Vector3.new(X1 - 2.6, FLOOR + 1.85 + s[2] * 1.75, south + s[1] - 1.5), 1.7, 1.35, productColor(i), if s[2] == 2 then GOLD else INK)
	end
	local poster = sign(display, "Poster", Vector2.new(3.2, 4), Vector3.new(X1 - 2.2, FLOOR + 3.3, south + 3.4), Vector3.xAxis, "NEW\nPRE-\nWORKOUT",
		{ back = RED, color = GOLD_LIGHT, pps = 30, depth = 0.15, height = 0.9 })
	deco(display, "PosterFrame", Vector3.new(0.12, 4.3, 3.5), CFrame.new(X1 - 2.32, FLOOR + 3.3, south + 3.4), GOLD_DARK, Enum.Material.Metal)
	poster.Name = "Poster"
	for i = 0, 1 do
		cylinder(display, "Shaker", 1.5, 0.8, Vector3.new(X1 - 2.4, FLOOR + 1.75, south + 1.4 + i * 1), productColor(i + 3))
	end

	--------------------------------------------------------------------
	-- Around the shop: paving, WELCOME mat, planters, bench, chalkboard, bike rack, trees, bin; the entrance spot
	--------------------------------------------------------------------
	local around = folder("Lot")
	local paveX0 = -104
	part(around, "Paving", Vector3.new(LOT.x1 - paveX0, 0.3, LOT.z1 - LOT.z0), CFrame.new((paveX0 + LOT.x1) / 2, 0.18, (LOT.z0 + LOT.z1) / 2), PAVING,
		Enum.Material.Concrete)
	local mat = deco(around, "WelcomeMat", Vector3.new(3, 0.08, 7), CFrame.new(X1 + 1.8, 0.36, CZ), Color3.fromHex("#1B1B1F"), Enum.Material.Fabric)
	label(mat, Enum.NormalId.Top, "WELCOME", { rotation = 90, width = 2.1, height = 0.38, pps = 30, stroke = 0 })
	for _, z in ipairs({ Z0 + 3, Z1 - 3 }) do
		local c = Vector3.new(X1 + 4.6, 0, z)
		part(around, "Planter", Vector3.new(3, 1.8, 3), CFrame.new(c + Vector3.new(0, 1.23, 0)), BLACK, Enum.Material.SmoothPlastic, { CastShadow = false })
		deco(around, "PlanterRim", Vector3.new(3.3, 0.2, 3.3), CFrame.new(c + Vector3.new(0, 2.2, 0)), GOLD_DARK, Enum.Material.Metal)
		deco(around, "Bush", Vector3.new(3.2, 2.8, 3.2), CFrame.new(c + Vector3.new(0, 3.3, 0)), Color3.fromHex("#3D8A3A"), Enum.Material.Grass,
			{ Shape = Enum.PartType.Ball })
		for i = 0, 2 do
			deco(around, "Flower", Vector3.new(0.6, 0.6, 0.6), CFrame.new(c + Vector3.new(math.cos(i * 2.1) * 1.2, 4.2, math.sin(i * 2.1) * 1.2)),
				Color3.fromHex(if i == 1 then "#F6C75A" else "#E8343C"), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
		end
	end
	-- the chalkboard A-frame by the door (both sides: NEW: PRE-WORKOUT)
	local chalk = Vector3.new(X1 + 4, 0.35, CZ - 7.5)
	for _, side in ipairs({ 1, -1 }) do
		local boardCf = CFrame.new(chalk + Vector3.new(side * 0.55, 1.75, 0)) * CFrame.Angles(0, 0, math.rad(side * 14))
		local board_ = deco(around, "Chalkboard", Vector3.new(0.15, 3.4, 2.4), boardCf, Color3.fromHex("#2E3A33"), Enum.Material.Slate)
		deco(around, "ChalkFrame", Vector3.new(0.12, 3.6, 2.6), boardCf * CFrame.new(-side * 0.05, 0, 0), Color3.fromHex("#8C6E4F"), Enum.Material.Wood)
		local gui = label(board_, if side == 1 then Enum.NormalId.Right else Enum.NormalId.Left, "NEW:\nPRE-\nWORKOUT",
			{ color = Color3.fromHex("#F2F2EA"), font = CHALK, pps = 40, stroke = 0, height = 0.85, width = 0.85, lightInfluence = 0.6 })
		gui.Name = "Chalk"
	end
	-- a bench against the south window, a bin, a bike rack on the north side, trees on the south side
	townModel("Bench", CFrame.lookAt(Vector3.new(X1 + 1.6, 0, Z1 - 7.5), Vector3.new(X1 + 10, 0, Z1 - 7.5)), around)
	townModel("Bin", CFrame.new(X1 + 5.2, 0, CZ + 7.5), around)
	townModel("BikeRack", CFrame.new(-70, 0, LOT.z0 + 2.4), around)
	townModel("Bike", CFrame.new(-70.6, 0, LOT.z0 + 2.4), around)
	for _, x in ipairs({ -92, -74 }) do
		deco(around, "TreeGrate", Vector3.new(3, 0.06, 3), CFrame.new(x, 0.36, LOT.z1 - 2), Color3.fromHex("#4A4C50"), Enum.Material.DiamondPlate)
		townModel("RoundTree", CFrame.new(x, 0, LOT.z1 - 2), around)
	end
	part(shop, "Entrance", Vector3.new(4, 0.2, 4), CFrame.new(X1 + 6, 0.4, CZ), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

	--------------------------------------------------------------------
	-- The freed west half of the lot: a small park (lawn, a path, a round plaza with a tree and benches, trees, bushes)
	--------------------------------------------------------------------
	local park = folder("Park")
	local px0, px1 = LOT.x0, paveX0
	local pcx, pcz = (px0 + px1) / 2, (LOT.z0 + LOT.z1) / 2
	part(park, "Lawn", Vector3.new(px1 - px0, 0.3, LOT.z1 - LOT.z0), CFrame.new(pcx, 0.15, pcz), Color3.fromHex("#6E9F55"), Enum.Material.Grass)
	part(park, "Path", Vector3.new(px1 - px0, 0.32, 4), CFrame.new(pcx, 0.18, CZ), PAVING, Enum.Material.Concrete)
	part(park, "PathNorth", Vector3.new(4, 0.32, CZ - LOT.z0), CFrame.new(pcx, 0.18, (LOT.z0 + CZ) / 2), PAVING, Enum.Material.Concrete)
	cylinder(park, "Plaza", 0.34, 16, Vector3.new(pcx, 0.18, CZ), PAVING, Enum.Material.Concrete, true)
	cylinder(park, "PlazaRing", 0.36, 16.6, Vector3.new(pcx, 0.17, CZ), Color3.fromHex("#A8957B"), Enum.Material.Pavement, true)
	cylinder(park, "TreeBed", 0.8, 4.4, Vector3.new(pcx, 0.6, CZ), Color3.fromHex("#B5AA98"), Enum.Material.Concrete, true)
	cylinder(park, "TreeSoil", 0.1, 3.8, Vector3.new(pcx, 1.02, CZ), Color3.fromHex("#3B2A1E"), Enum.Material.Ground)
	local centerTree = townModel("Oak", CFrame.new(pcx, 0, CZ), park)
	if centerTree then centerTree:PivotTo(centerTree:GetPivot() + Vector3.new(0, 0.8, 0)) end
	for i, a in ipairs({ 30, 150, 270 }) do
		local r = math.rad(a)
		local pos = Vector3.new(pcx + math.cos(r) * 6, 0, CZ + math.sin(r) * 6)
		townModel("Bench", CFrame.lookAt(pos, Vector3.new(pcx, 0, CZ)), park) -- (facing the tree)
		if i == 2 then townModel("StreetLamp", CFrame.new(pos + Vector3.new(-3, 0, 2)), park) end
	end
	for _, spec in ipairs({
		{ "Oak", -146, 100 }, { "RoundTree", -112, 100 }, { "RoundTree", -146, 138 }, { "Oak", -114, 137 },
		{ "Bush", X0 - 3, 101 }, { "Bush", X0 - 3, 110 }, { "Bush", X0 - 3, 133 }, { "Bush", -136, 96 }, { "Bush", -120, 141 },
		{ "Flowers", -133, 110 }, { "Flowers", -122, 127 }, { "Flowers", -139, 125 }, { "Rock", -144, 120 },
	}) do
		townModel(spec[1], CFrame.new(spec[2], 0, spec[3]), park)
	end

	local parts = 0
	for _, d in ipairs(shop:GetDescendants()) do
		if d:IsA("BasePart") then parts += 1 end
	end
	return "PUMP SHOP (v3) built: " .. parts .. " parts"
end

return PumpShop
