-- PowerliftingFront (prompt 62, 23 Oct): gives Workspace.PowerliftingGym a real street front on Main Street, lined up with
-- the starter gym's front (both at z -3), so the three gyms read as one gym row (Powerlifting - Starter - Pro). Run once in
-- Edit: require(this).Run(). Before it: ServerStorage.PowerliftingBackup_23Oct_p62 (the whole gym) and
-- ServerStorage.PowerliftingFrontRemoved_23Oct (the 6 Main Street buildings that stood in front of it; this run adds the old
-- front pieces, the alley and the old signs there too).
--   * Front (x -175..-65, outer face z -3): red-brown brick base, a row of 9 tall industrial windows (steel frames, glass
--     that glows at night: NightWindow) between brick piers, steel I-beam columns, a steel beam at y 20, ribbed dark steel
--     above it, the lit POWERLIFTING / GYM ARC sign board (NightSign) with a red neon edge, white industrial wall lamps
--     (NightLight), a steel side door, bollards at the loading door.
--   * Loading door: the same LoadingDoor (Shutter / Blocker / Drum: PowerliftingClient hides the shutter once you've
--     unlocked it, so the door reads rolled up and you see inside). The shutter is clean steel with a black + white
--     "UNLOCKS AT GROWTH SPURT 5" plate and a padlock; a tap on the door shows the locked toast (a ClickDetector on the
--     Blocker, which stands in front of the shutter).
--   * Roof: a sawtooth warehouse roof (6 teeth, north-facing skylight glass), mushroom vents and 2 AC units on the flat
--     strip behind the front parapet. Top at y 35.5 (the Main Street buildings around it reach 31 to 56).
--   * East side wall (seen from the street in the gap to the starter gym): a chalk-white painted barbell mural.
--   * Forecourt: paving like the starter gym's from the wall to the sidewalk; the hydrant moved off the door's path.
-- Every decoration part: Anchored, no collisions, no shadows (the wall pieces, door frame and bollards collide).
local Front = {}

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local FZ = -3 -- the front wall's outer face
local XW, XE = -175, -65
local WALL_Z = FZ - 0.5
local DOOR_X = -143
local JAMB_W = 1.5
local DOOR_L, DOOR_R = DOOR_X - 7 - JAMB_W, DOOR_X + 7 + JAMB_W -- the door frame's outer edges
local SIDE_X, SIDE_W, SIDE_H = -159, 4, 8
local BASE_TOP, BAND_TOP, BEAM_TOP, WALL_TOP = 8, 20, 21.2, 30
local ROOF_TOP = 31

local BRICK = Color3.fromHex("#6E3B2E")
local CLAD = Color3.fromHex("#2E3236")
local STEEL = Color3.fromHex("#1F2226")
local RIB = Color3.fromHex("#3B3F44")
local SHUTTER = Color3.fromHex("#4B5056")
local SLAT = Color3.fromHex("#3A3E43")
local ROOF = Color3.fromHex("#5A5E64") -- (dark grey: #3A3D41 read as black from the street)
local GLASS = Color3.fromHex("#A9BCCB")
local RED = Color3.fromHex("#E0261F")
local WHITE = Color3.fromHex("#F2F5FF")
local CHALK = Color3.fromHex("#F2F0EA")
local CONCRETE = Color3.fromHex("#8D8F92")
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

local made
local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
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
-- a box from corner to corner (x0..x1, y0..y1, z0..z1)
local function box(x0, x1, y0, y1, z0, z1, props)
	props.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	props.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return part(props)
end
local function wall(x0, x1, y0, y1, color, material, name)
	return box(x0, x1, y0, y1, FZ - 1, FZ, { Name = name or "FrontWall", Color = color, Material = material, CanCollide = true, CanQuery = true })
end
local function folder(name: string, parent: Instance)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function new(class, props, children)
	local i = Instance.new(class)
	for k, v in pairs(props) do if k ~= "Parent" then i[k] = v end end
	for _, c in ipairs(children or {}) do c.Parent = i end
	i.Parent = props.Parent
	return i
end
local function vcyl(x, y, z, d, h, props) -- a cylinder standing up
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(h, d, d)
	props.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
	return part(props)
end
local function nightLight(p: BasePart, dayColor: Color3, nightColor: Color3)
	p:SetAttribute("DayColor", dayColor)
	p:SetAttribute("NightColor", nightColor)
	CS:AddTag(p, "NightLight")
end

------------------------------------------------------------------------ the old pieces out
local function clearOld(gym: Model, removed: Folder)
	local keep = folder("OldFront", removed)
	local shell = gym.Shell
	for _, p in ipairs(shell:GetChildren()) do
		local n = p.Name
		if n == "FrontBrick" or n == "FrontClad" or n == "DoorHeader" or n == "PaintedSign" or n == "Alley" or n == "AlleyCurb"
			or ((n == "WallLamp" or n == "WallLampArm") and p.Position.Z > -5) then
			p.Parent = keep
		end
	end
	local sign = gym.LoadingDoor:FindFirstChild("AreaSign")
	if sign then sign.Parent = keep end
end

------------------------------------------------------------------------ the front wall
local function windowAt(x0: number, w: number, y0: number, y1: number)
	local x1 = x0 + w
	-- the sill, the glass (lit at night) and the steel frame + muntins
	box(x0 - 0.2, x1 + 0.2, y0 - 0.5, y0, FZ - 1, FZ + 0.35, { Name = "Sill", Color = CONCRETE, Material = Enum.Material.Concrete })
	local glass = box(x0, x1, y0, y1, WALL_Z - 0.08, WALL_Z + 0.08, { Name = "Glass", Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.5, Reflectance = 0.1 })
	glass:SetAttribute("DayColor", GLASS)
	glass:SetAttribute("DayMaterial", "Glass")
	glass:SetAttribute("DayTransparency", 0.5)
	glass:SetAttribute("NightColor", Color3.fromHex("#C9D4E0"))
	glass:SetAttribute("NightTransparency", 0.75) -- (a faint glow: the platforms and bars inside still show)
	CS:AddTag(glass, "NightWindow")
	local fz0, fz1 = WALL_Z - 0.2, FZ + 0.05
	local t = 0.3
	box(x0, x1, y1 - t, y1, fz0, fz1, { Name = "Frame", Color = STEEL, Material = Enum.Material.Metal })
	box(x0, x1, y0, y0 + t, fz0, fz1, { Name = "Frame", Color = STEEL, Material = Enum.Material.Metal })
	box(x0, x0 + t, y0, y1, fz0, fz1, { Name = "Frame", Color = STEEL, Material = Enum.Material.Metal })
	box(x1 - t, x1, y0, y1, fz0, fz1, { Name = "Frame", Color = STEEL, Material = Enum.Material.Metal })
	local mx = (x0 + x1) / 2
	box(mx - 0.12, mx + 0.12, y0, y1, fz0, fz1 - 0.1, { Name = "Muntin", Color = STEEL, Material = Enum.Material.Metal })
	for _, f in ipairs({ 1 / 3, 2 / 3 }) do
		local y = y0 + (y1 - y0) * f
		box(x0, x1, y - 0.12, y + 0.12, fz0, fz1 - 0.1, { Name = "Muntin", Color = STEEL, Material = Enum.Material.Metal })
	end
end

local function column(x: number)
	box(x - 0.6, x + 0.6, 0, WALL_TOP + 0.6, FZ, FZ + 0.6, { Name = "Column", Color = STEEL, Material = Enum.Material.Metal, CanCollide = true, CanQuery = true })
	-- the flanges (an I-beam from the front)
	box(x - 0.85, x + 0.85, 0, WALL_TOP + 0.6, FZ + 0.6, FZ + 0.75, { Name = "Flange", Color = STEEL, Material = Enum.Material.Metal })
	box(x - 1, x + 1, 0, 0.3, FZ, FZ + 1, { Name = "BasePlate", Color = STEEL, Material = Enum.Material.Metal })
end

local function wallLamp(x: number, y: number)
	box(x - 0.12, x + 0.12, y + 0.6, y + 0.84, FZ + 0.75, FZ + 2.2, { Name = "LampArm", Color = STEEL, Material = Enum.Material.Metal })
	box(x - 0.12, x + 0.12, y + 0.1, y + 0.84, FZ + 2.0, FZ + 2.24, { Name = "LampArm", Color = STEEL, Material = Enum.Material.Metal })
	vcyl(x, y, FZ + 2.12, 1.5, 0.5, { Name = "LampShade", Color = STEEL, Material = Enum.Material.Metal })
	local bulb = part({ Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = CFrame.new(x, y - 0.3, FZ + 2.12),
		Color = Color3.fromHex("#D9DEE6") })
	nightLight(bulb, Color3.fromHex("#D9DEE6"), Color3.fromHex("#FFFFFF"))
	new("SpotLight", { Face = Enum.NormalId.Bottom, Range = 16, Angle = 75, Brightness = 1.4, Color = Color3.fromHex("#F4F7FF"), Shadows = false, Enabled = false,
		Parent = bulb })
end

local function buildFront(gym: Model)
	made = folder("Facade", gym)
	-- brick base (y 0..8), with the side door's opening
	wall(XW, SIDE_X - SIDE_W / 2, 0, BASE_TOP, BRICK, Enum.Material.Brick, "Brick")
	wall(SIDE_X + SIDE_W / 2, DOOR_L, 0, BASE_TOP, BRICK, Enum.Material.Brick, "Brick")
	wall(DOOR_R, XE, 0, BASE_TOP, BRICK, Enum.Material.Brick, "Brick")
	-- the window band (y 8..20): west = one window, then brick over the side door; east = 7 windows between piers
	local winY0, winY1 = BASE_TOP + 0.5, BAND_TOP - 0.4
	wall(XW, XW + 2, BASE_TOP, BAND_TOP, BRICK, Enum.Material.Brick, "Pier")
	windowAt(XW + 2, 7, winY0, winY1)
	wall(XW + 2, XW + 9, BASE_TOP, winY0, BRICK, Enum.Material.Brick, "Pier")
	wall(XW + 2, XW + 9, winY1, BAND_TOP, BRICK, Enum.Material.Brick, "Pier")
	wall(XW + 9, DOOR_L, BASE_TOP, BAND_TOP, BRICK, Enum.Material.Brick, "Pier")
	wall(DOOR_L, DOOR_R, 17.4, BAND_TOP, BRICK, Enum.Material.Brick, "OverDoor")
	local n, w = 7, 7
	local p = ((XE - DOOR_R) - n * w) / (n + 1)
	local piers = {}
	for i = 0, n do
		local x0 = DOOR_R + i * (w + p)
		wall(x0, x0 + p, BASE_TOP, BAND_TOP, BRICK, Enum.Material.Brick, "Pier")
		table.insert(piers, x0 + p / 2)
		if i < n then
			local wx = x0 + p
			wall(wx, wx + w, BASE_TOP, winY0, BRICK, Enum.Material.Brick, "Pier")
			wall(wx, wx + w, winY1, BAND_TOP, BRICK, Enum.Material.Brick, "Pier")
			windowAt(wx, w, winY0, winY1)
		end
	end
	-- the ribbed dark steel above (y 20..30), the beam across at y 20..21.2
	wall(XW, XE, BAND_TOP, WALL_TOP, CLAD, Enum.Material.Metal, "Clad")
	box(XW, XE, BAND_TOP, BEAM_TOP, FZ, FZ + 0.8, { Name = "Beam", Color = STEEL, Material = Enum.Material.Metal })
	box(XW, XE, BEAM_TOP - 0.15, BEAM_TOP, FZ, FZ + 1.0, { Name = "BeamFlange", Color = STEEL, Material = Enum.Material.Metal })
	box(XW, XE, BAND_TOP, BAND_TOP + 0.15, FZ, FZ + 1.0, { Name = "BeamFlange", Color = STEEL, Material = Enum.Material.Metal })
	local SIGN_X0, SIGN_X1 = -146, -78
	for x = XW + 1, XE - 1, 2 do
		if x < SIGN_X0 - 0.5 or x > SIGN_X1 + 0.5 then
			box(x - 0.15, x + 0.15, BEAM_TOP, WALL_TOP, FZ, FZ + 0.3, { Name = "Rib", Color = RIB, Material = Enum.Material.Metal })
		end
	end
	-- the steel columns (I-beams) on the piers and the ends
	column(XW + 0.6)
	column(XW + 10.5)
	for i, x in ipairs(piers) do
		if i > 1 then column(x) end -- (the first pier is the door frame's)
	end
	-- wall lamps: either side of the loading door, over the side door and on every other east column
	wallLamp(DOOR_L - 1.2, 17.6)
	wallLamp(DOOR_R + 1.2, 17.6)
	wallLamp(SIDE_X, 11.2)
	for i = 3, #piers - 1, 2 do wallLamp(piers[i], 17.6) end

	-- the sign: POWER (white) LIFTING (red) big, GYM ARC small under it, on black with a red neon edge (lit at night)
	local board = box(SIGN_X0, SIGN_X1, 22.2, 29.2, FZ + 0.3, FZ + 0.8, { Name = "SignBoard", Color = Color3.fromHex("#0D0D0F") })
	CS:AddTag(board, "NightSign")
	for _, e in ipairs({ { SIGN_X0 - 0.2, SIGN_X1 + 0.2, 29.2, 29.4 }, { SIGN_X0 - 0.2, SIGN_X1 + 0.2, 22.0, 22.2 }, { SIGN_X0 - 0.2, SIGN_X0, 22.2, 29.2 }, { SIGN_X1, SIGN_X1 + 0.2, 22.2, 29.2 } }) do
		box(e[1], e[2], e[3], e[4], FZ + 0.3, FZ + 0.9, { Name = "SignNeon", Color = RED, Material = Enum.Material.Neon })
	end
	local gui = new("SurfaceGui", { Name = "Sign", Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30,
		LightInfluence = 1, Parent = board })
	new("TextLabel", { Name = "Title", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.06), Size = UDim2.fromScale(0.94, 0.62),
		FontFace = HEAVY, TextScaled = true, RichText = true, TextColor3 = WHITE,
		Text = 'POWER<font color="#E0261F">LIFTING</font>', Parent = gui })
	new("Frame", { Name = "LineL", BackgroundColor3 = RED, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.4, 0.83),
		Size = UDim2.fromScale(0.18, 0.025), Parent = gui })
	new("Frame", { Name = "LineR", BackgroundColor3 = RED, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.6, 0.83),
		Size = UDim2.fromScale(0.18, 0.025), Parent = gui })
	new("TextLabel", { Name = "Sub", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.83), Size = UDim2.fromScale(0.18, 0.2),
		FontFace = HEAVY, TextScaled = true, TextColor3 = WHITE, Text = "GYM ARC", Parent = gui })

	-- the loading door's steel frame (collides) and the bollards
	box(DOOR_L, DOOR_L + JAMB_W, 0, 17.4, FZ - 1, FZ + 0.6, { Name = "Jamb", Color = STEEL, Material = Enum.Material.Metal, CanCollide = true, CanQuery = true })
	box(DOOR_R - JAMB_W, DOOR_R, 0, 17.4, FZ - 1, FZ + 0.6, { Name = "Jamb", Color = STEEL, Material = Enum.Material.Metal, CanCollide = true, CanQuery = true })
	box(DOOR_L, DOOR_R, 16, 17.4, FZ - 1, FZ + 0.8, { Name = "Header", Color = STEEL, Material = Enum.Material.Metal, CanCollide = true, CanQuery = true })
	for _, x in ipairs({ DOOR_L - 0.9, DOOR_R + 0.9 }) do
		local b = vcyl(x, 1.6, FZ + 1.4, 0.9, 3.2, { Name = "Bollard", Color = Color3.fromHex("#141416"), Material = Enum.Material.Metal })
		b.CanCollide, b.CanQuery = true, true
		vcyl(x, 2.4, FZ + 1.4, 0.95, 0.4, { Name = "BollardBand", Color = WHITE })
	end

	-- the steel side door (staff door: shut, decoration)
	local sx0, sx1 = SIDE_X - SIDE_W / 2, SIDE_X + SIDE_W / 2
	box(sx0, sx1, 0, SIDE_H, FZ - 0.7, FZ - 0.4, { Name = "SideDoor", Color = SLAT, Material = Enum.Material.Metal, CanCollide = true, CanQuery = true })
	box(sx0 - 0.3, sx0, 0, SIDE_H + 0.3, FZ - 1, FZ + 0.2, { Name = "SideFrame", Color = STEEL, Material = Enum.Material.Metal })
	box(sx1, sx1 + 0.3, 0, SIDE_H + 0.3, FZ - 1, FZ + 0.2, { Name = "SideFrame", Color = STEEL, Material = Enum.Material.Metal })
	box(sx0 - 0.3, sx1 + 0.3, SIDE_H, SIDE_H + 0.3, FZ - 1, FZ + 0.2, { Name = "SideFrame", Color = STEEL, Material = Enum.Material.Metal })
	box(SIDE_X - 0.6, SIDE_X + 0.6, 5, 7, FZ - 0.42, FZ - 0.36, { Name = "WireGlass", Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.3 })
	box(sx1 - 0.9, sx1 - 0.3, 3.6, 3.8, FZ - 0.4, FZ - 0.1, { Name = "Handle", Color = Color3.fromHex("#B8BCC2"), Material = Enum.Material.Metal })
	box(sx0 - 0.6, sx1 + 0.6, 0, 0.3, FZ, FZ + 1.4, { Name = "Step", Color = CONCRETE, Material = Enum.Material.Concrete })
end

------------------------------------------------------------------------ the loading door's shutter
local function padlock(parent: GuiObject)
	local holder = new("Frame", { Name = "Padlock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.07, 0.5),
		Size = UDim2.fromScale(0.16, 0.62), Parent = parent }, { new("UIAspectRatioConstraint", { AspectRatio = 0.8 }) })
	new("Frame", { Name = "Shackle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.62, 0.62),
		Parent = holder }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Color = WHITE, Thickness = 9 }) })
	new("Frame", { Name = "Body", BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, 0.6),
		Parent = holder }, {
		new("UICorner", { CornerRadius = UDim.new(0.15, 0) }),
		new("Frame", { Name = "Keyhole", BackgroundColor3 = Color3.fromHex("#0D0D0F"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.18, 0.3) }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
	})
end

local function restyleDoor(gym: Model, unlockAt: number)
	local door = gym.LoadingDoor
	local shutter = door.Shutter :: BasePart
	local face = Enum.NormalId.Back
	for _, d in ipairs(shutter:GetChildren()) do
		if d:IsA("SurfaceGui") then
			face = d.Face
			d:Destroy()
		end
	end
	shutter.Material, shutter.Color = Enum.Material.Metal, SHUTTER
	for _, slat in ipairs(shutter:GetChildren()) do
		if slat:IsA("BasePart") then slat.Material, slat.Color = Enum.Material.Metal, SLAT end
	end
	part({ Name = "BottomBar", Size = Vector3.new(14, 0.5, 0.3), CFrame = CFrame.new(DOOR_X, 0.35, shutter.Position.Z + 0.2), Color = STEEL, Material = Enum.Material.Metal,
		Parent = shutter })
	if door:FindFirstChild("DoorLip") then door.DoorLip.Material, door.DoorLip.Color = Enum.Material.Metal, STEEL end
	-- the plate: black, white words, a padlock (hidden with the shutter once you've unlocked the gym)
	local gui = new("SurfaceGui", { Name = "LockSign", Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, Parent = shutter })
	local plate = new("Frame", { Name = "Plate", BackgroundColor3 = Color3.fromHex("#0D0D0F"), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.94, 0.32), Parent = gui }, {
		new("UICorner", { CornerRadius = UDim.new(0.08, 0) }),
		new("UIStroke", { Color = WHITE, Thickness = 4, Transparency = 0.2 }),
	})
	padlock(plate)
	-- (fixed text sizes, 40 px a stud: TextScaled wrapped "GROWTH SPURT 5" or shrank it to 8 px)
	new("TextLabel", { Name = "Small", BackgroundTransparency = 1, Position = UDim2.fromScale(0.28, 0.16), Size = UDim2.fromScale(0.68, 0.24), FontFace = HEAVY, TextSize = 28,
		TextColor3 = Color3.fromHex("#BFC3CA"), TextXAlignment = Enum.TextXAlignment.Left, Text = "UNLOCKS AT", Parent = plate })
	new("TextLabel", { Name = "Rule", BackgroundTransparency = 1, Position = UDim2.fromScale(0.28, 0.46), Size = UDim2.fromScale(0.7, 0.3), FontFace = HEAVY, TextSize = 42,
		TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "GROWTH SPURT " .. unlockAt, Parent = plate })
	-- a tap shows the locked toast (PowerliftingClient). On the Blocker: it stands in front of the shutter, so a click
	-- on the door hits it first
	local blocker = door:FindFirstChild("Blocker")
	if blocker and not blocker:FindFirstChildOfClass("ClickDetector") then
		new("ClickDetector", { Name = "Tap", MaxActivationDistance = 40, Parent = blocker })
	end
end

------------------------------------------------------------------------ the sawtooth roof
local function buildRoof(gym: Model)
	made = folder("Roof", gym.Facade)
	local x0, x1 = XW + 0.5, XE - 0.5
	local zBack, zFront = -97, -17
	local teeth, h = 6, 4.5
	local d = (zFront - zBack) / teeth
	for i = 0, teeth - 1 do
		local zN = zBack + i * d
		-- the slope: high at its north edge (the glass side), down to the roof at its south edge
		part({ ClassName = "WedgePart", Name = "Tooth", Size = Vector3.new(x1 - x0, h, d), Color = ROOF, Material = Enum.Material.Metal,
			CFrame = CFrame.new((x0 + x1) / 2, ROOF_TOP + h / 2, zN + d / 2) * CFrame.Angles(0, math.pi, 0) })
		box(x0, x1, ROOF_TOP + h - 0.15, ROOF_TOP + h + 0.15, zN - 0.1, zN + 0.5, { Name = "Ridge", Color = STEEL, Material = Enum.Material.Metal })
		-- the skylight glass on the north face, with mullions
		box(x0 + 1, x1 - 1, ROOF_TOP + 0.4, ROOF_TOP + h - 0.4, zN - 0.12, zN - 0.02, { Name = "Skylight", Color = Color3.fromHex("#9FC3D9"), Material = Enum.Material.Glass,
			Transparency = 0.15, Reflectance = 0.2 })
		for x = x0 + 1, x1 - 1, 9 do
			box(x - 0.15, x + 0.15, ROOF_TOP + 0.4, ROOF_TOP + h - 0.4, zN - 0.2, zN - 0.02, { Name = "Mullion", Color = STEEL, Material = Enum.Material.Metal })
		end
		-- skylight panels lying on the slope (seen from the street and from above)
		local angle = math.atan(h / d)
		local mid = zN + d / 2
		for _, x in ipairs({ -160, -140, -120, -100, -80 }) do
			local cf = CFrame.new(x, ROOF_TOP + h / 2, mid) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 0.08, 0)
			part({ Name = "SlopeSkylight", Size = Vector3.new(8, 0.12, d * 0.55), CFrame = cf, Color = Color3.fromHex("#9FC3D9"), Material = Enum.Material.Glass,
				Transparency = 0.1, Reflectance = 0.25 })
			part({ Name = "SlopeSkylightFrame", Size = Vector3.new(8.6, 0.1, d * 0.6), CFrame = cf * CFrame.new(0, -0.04, 0), Color = STEEL, Material = Enum.Material.Metal })
		end
		-- two mushroom vents on every other slope
		if i % 2 == 0 then
			for _, x in ipairs({ -150 + i * 4, -95 - i * 3 }) do
				local z = zN + d * 0.7
				local y = ROOF_TOP + h * (1 - 0.7)
				vcyl(x, y + 0.9, z, 1.4, 1.8, { Name = "Vent", Color = Color3.fromHex("#8D9196"), Material = Enum.Material.Metal })
				vcyl(x, y + 1.95, z, 2.4, 0.35, { Name = "VentCap", Color = Color3.fromHex("#8D9196"), Material = Enum.Material.Metal })
			end
		end
	end
	-- the flat strip behind the front parapet: 2 AC units
	for _, x in ipairs({ -126, -96 }) do
		local z = -11
		box(x - 2.5, x + 2.5, ROOF_TOP, ROOF_TOP + 2.6, z - 2, z + 2, { Name = "ACUnit", Color = Color3.fromHex("#9AA0A6"), Material = Enum.Material.Metal })
		box(x - 2.3, x + 2.3, ROOF_TOP + 0.4, ROOF_TOP + 2.2, z + 2, z + 2.05, { Name = "ACGrille", Color = Color3.fromHex("#4A4F55"), Material = Enum.Material.DiamondPlate })
		vcyl(x, ROOF_TOP + 2.7, z, 3, 0.2, { Name = "ACFan", Color = Color3.fromHex("#2B2E31"), Material = Enum.Material.Metal })
		box(x - 1.5, x + 1.5, ROOF_TOP + 2.8, ROOF_TOP + 2.85, z - 0.08, z + 0.08, { Name = "ACFanBar", Color = Color3.fromHex("#8D9196"), Material = Enum.Material.Metal })
		box(x - 0.08, x + 0.08, ROOF_TOP + 2.8, ROOF_TOP + 2.85, z - 1.5, z + 1.5, { Name = "ACFanBar", Color = Color3.fromHex("#8D9196"), Material = Enum.Material.Metal })
		box(x + 2.5, x + 6, ROOF_TOP + 0.6, ROOF_TOP + 1.4, z - 0.4, z + 0.4, { Name = "ACDuct", Color = Color3.fromHex("#8D9196"), Material = Enum.Material.Metal })
	end
end

------------------------------------------------------------------------ the chalk mural on the east side wall
local function buildMural(gym: Model)
	made = gym.Facade
	local x = XE + 0.08 -- the east wall's outer face is x -65
	local wallPart = part({ Name = "Mural", Size = Vector3.new(0.05, 12, 34), CFrame = CFrame.new(x, 7, -24), Transparency = 1 })
	local gui = new("SurfaceGui", { Name = "Mural", Face = Enum.NormalId.Right, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 24, Parent = wallPart })
	local function paint(props)
		props.BackgroundColor3 = props.BackgroundColor3 or CHALK
		props.BorderSizePixel = 0
		props.BackgroundTransparency = props.BackgroundTransparency or 0.08
		props.Parent = props.Parent or gui
		return new("Frame", props)
	end
	-- the barbell: bar, collars, plates (big to small, both sides)
	paint({ Name = "Bar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.86, 0.035) })
	for _, side in ipairs({ -1, 1 }) do
		local plates = { { 0.3, 0.62 }, { 0.335, 0.62 }, { 0.37, 0.48 }, { 0.4, 0.34 } }
		for _, p in ipairs(plates) do
			paint({ Name = "Plate", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + side * p[1], 0.6), Size = UDim2.fromScale(0.026, p[2]) },
				nil)
		end
		paint({ Name = "Collar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + side * 0.27, 0.6), Size = UDim2.fromScale(0.012, 0.12) })
	end
	new("TextLabel", { Name = "Words", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.62, 0.22),
		FontFace = HEAVY, TextScaled = true, TextColor3 = CHALK, TextTransparency = 0.08, Text = "CHALK UP. LIFT HEAVY.", Parent = gui })
	-- chalk hand prints and splashes
	local spots = { { 0.08, 0.18, 0.05 }, { 0.12, 0.3, 0.03 }, { 0.9, 0.2, 0.05 }, { 0.86, 0.33, 0.025 }, { 0.2, 0.9, 0.04 }, { 0.78, 0.88, 0.045 }, { 0.6, 0.92, 0.02 } }
	for _, s in ipairs(spots) do
		paint({ Name = "Chalk", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(s[1], s[2]), Size = UDim2.fromScale(s[3], s[3] * 2.8),
			BackgroundTransparency = 0.35 }, nil).Parent = gui
	end
	for _, c in ipairs(gui:GetChildren()) do
		if c.Name == "Chalk" then new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = c }) end
	end
end

-- the east side wall's steel bands (seen down the passage from the street): vertical ribs, so it isn't a blank black wall
local function eastRibs(gym: Model)
	made = gym.Facade
	local x = XE + 0.15
	for z = -95, -5, 3 do
		for _, band in ipairs({ { 14, 20 }, { 26, WALL_TOP } }) do
			box(x - 0.15, x + 0.15, band[1], band[2], z - 0.15, z + 0.15, { Name = "SideRib", Color = RIB, Material = Enum.Material.Metal })
		end
	end
end

-- no terrain (or grass blades) through the new paving: air above it (whole 4-stud voxels: FillBlock left bumps), concrete
-- under it; the paving covers the hole
local function clearTerrain()
	local T = workspace.Terrain
	for _, r in ipairs({ { XW + 1, -48, -2, 18 }, { XE + 1, -48, -96, -4 } }) do
		T:FillRegion(Region3.new(Vector3.new(r[1], -4, r[3]), Vector3.new(r[2], 8, r[4])):ExpandToGrid(4), 4, Enum.Material.Air)
		T:ReplaceMaterial(Region3.new(Vector3.new(r[1], -8, r[3]), Vector3.new(r[2], 0, r[4])):ExpandToGrid(4), 4, Enum.Material.Grass, Enum.Material.Concrete)
	end
end

------------------------------------------------------------------------ the forecourt
local function buildForecourt(gym: Model)
	made = gym.Facade
	-- the same paving as the starter gym's forecourt, from the wall to the sidewalk
	solid({ Name = "Forecourt", Size = Vector3.new((-48) - XW, 0.4, 21), CFrame = CFrame.new((XW + -48) / 2, 0, 7.5), Color = Color3.fromHex("#C9B79C"),
		Material = Enum.Material.Pavement, CastShadow = false })
	-- the side passage to the starter gym (where the mural is): concrete, not dirt
	solid({ Name = "SidePassage", Size = Vector3.new(-46 - XE, 0.4, 94), CFrame = CFrame.new((XE + -46) / 2, 0, -50), Color = Color3.fromHex("#B9B2A6"),
		Material = Enum.Material.Concrete, CastShadow = false })
	-- two planters like the starter gym's, clear of the door and the side door
	for _, x in ipairs({ -118, -84 }) do
		box(x - 2, x + 2, 0, 2.6, FZ + 1.2, FZ + 4.2, { Name = "Planter", Color = Color3.fromHex("#2B2E31"), Material = Enum.Material.Concrete, CanCollide = true, CanQuery = true })
		box(x - 1.7, x + 1.7, 2.6, 3.4, FZ + 1.5, FZ + 3.9, { Name = "Shrub", Color = Color3.fromHex("#3E7A3A"), Material = Enum.Material.Grass })
	end
end

-- (prompt 62 touch-up) the side ribs and the terrain clean-up, on a front built before they were added
function Front.TouchUp()
	local gym = workspace.PowerliftingGym
	if not gym.Facade:FindFirstChild("SideRib") then eastRibs(gym) end
	clearTerrain()
	return "touched up"
end

-- (prompt 62 touch-up) build the roof again (after a change to buildRoof)
function Front.RebuildRoof()
	local gym = workspace.PowerliftingGym
	local old = gym.Facade:FindFirstChild("Roof")
	if old then old:Destroy() end
	buildRoof(gym)
	return "roof rebuilt"
end

function Front.Run()
	local gym = workspace:FindFirstChild("PowerliftingGym")
	assert(gym, "Workspace.PowerliftingGym is missing")
	assert(not gym:FindFirstChild("Facade"), "already built (Workspace.PowerliftingGym.Facade exists)")
	assert(SS:FindFirstChild("PowerliftingBackup_23Oct_p62"), "back up the gym first (ServerStorage.PowerliftingBackup_23Oct_p62)")
	local removed = SS:FindFirstChild("PowerliftingFrontRemoved_23Oct") or folder("PowerliftingFrontRemoved_23Oct", SS)
	local Machines = require(game:GetService("ReplicatedStorage").Shared.Config.Machines)
	clearOld(gym, removed)
	buildFront(gym)
	restyleDoor(gym, Machines.GymUnlock.Powerlifting)
	buildRoof(gym)
	buildMural(gym)
	buildForecourt(gym)
	eastRibs(gym)
	clearTerrain()
	-- the hydrant off the loading door's path; the building west of the front clear of its corner
	local street = workspace.Town:FindFirstChild("Street")
	for _, h in ipairs(street and street:GetChildren() or {}) do
		if h.Name == "Hydrant" and h:IsA("Model") and math.abs(h:GetPivot().X - DOOR_X) < 6 then h:PivotTo(h:GetPivot() + Vector3.new(-14, 0, 0)) end
	end
	for _, b in ipairs(workspace.Town.Buildings:GetChildren()) do
		if b:IsA("Model") then
			local cf, size = b:GetBoundingBox()
			local east = cf.X + size.X / 2
			if east > XW - 1 and east < XW + 3 and cf.Z > 0 and cf.Z < 21 then b:PivotTo(b:GetPivot() + Vector3.new(XW - 0.5 - east, 0, 0)) end
		end
	end
	local count = 0
	for _, d in ipairs(gym.Facade:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
	return "Facade parts: " .. count
end

return Front
