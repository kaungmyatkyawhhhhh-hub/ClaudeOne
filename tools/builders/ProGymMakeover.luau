-- ProGymMakeover (prompt 50, 23 Oct): rearranges Workspace.ProGym into clear zones and gives it the black + gold makeover.
-- Run once in Studio: require(this).Run(). The whole Pro Gym was copied to ServerStorage.ProGymBackup_23Oct first; what
-- this takes out (a 5th treadmill, the old spotlights over the old machine spots, spare zone signs, the old cardio group)
-- goes to ServerStorage.ProGymRemoved_23Oct.
--   * Every machine is a REAL Pro machine: the starter-config copies that only had the Pro skin (FlatBench, 2 SquatRack,
--     Deadlift, HackSquat, LegPress, the cardio Treadmills, the DBCurl dumbbell spots) get their Pro MachineId (ProFlatBench
--     ...: the Pro tiers, the +10%) and move to ProGym.ProMachines. The sub-muscle machines (gym = "Pro") stay as they are.
--   * Layout (the hall is x 46..152, z -88..-5; the door from the Starter Gym is on the west wall at z -13):
--       ENTRANCE (south-west): the reception desk, a PRO GYM sign wall behind it, benches, the water fountain, plants; the
--         PRO RECORDS board stays on the front wall above.
--       CARDIO (south strip): 4 Pro Treadmills, the bike and the rower in one row facing the street windows; TVs above.
--       MAIN AISLE: z -14..-26, the whole width.
--       MACHINES (one row facing the aisle): LEGS (2 Hack Squats, 2 Leg Presses), BACK (Pull-Up Bar, Barbell Row,
--         2 Deadlifts), ABS (Crunch Bench).
--       FREE WEIGHTS (west-back, black rubber, in front of the long mirror): 3 benches, 3 squat racks + the overhead press,
--         the two dumbbell racks (8 Pro spots), plate trees, chalk.
--       ELITE (east-back): the 11 sub-muscle machines in rows by body part, under a GYM ARC mural.
--       STRETCH (along the east wall mirrors): the stretching mat, the arm wrestle table, the towel rack.
--   * Look: black rubber mats in the training zones with thin gold lines round them, a dark polished floor in the aisles,
--     the wall LED strips warm gold, a gold trim line, hanging warm lamps over every zone (4 with shadows), black + gold
--     zone signs, the mural. Every new part: Anchored, no collisions (except the desk and the sign wall), no shadows.
local ProGymMakeover = {}

local SS = game:GetService("ServerStorage")
local N, S, E, W = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)
local GOLD = Color3.fromHex("#F6C75A")
local GOLD_DARK = Color3.fromHex("#C9A13A")
local INK = Color3.fromHex("#0B0B0D")
local FLOOR_TOP = 0.15

local made, removed
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = p.Parent or made
	return p
end

-- moves a model so its bounding box centre is at (x, z) (height kept) and its front (pivot look) faces `face`
local function place(model: Model, x: number, z: number, face: Vector3)
	local pivot = model:GetPivot()
	local box = model:GetBoundingBox()
	local o = pivot:PointToObjectSpace(box.Position)
	local rot = CFrame.lookAt(Vector3.zero, face)
	local d = rot:VectorToWorldSpace(Vector3.new(o.X, 0, o.Z))
	model:PivotTo(CFrame.new(x - d.X, pivot.Y, z - d.Z) * rot)
end
local function shift(model: Instance, dx: number, dz: number)
	model:PivotTo(CFrame.new(dx, 0, dz) * model:GetPivot())
end

-- a flat mat (rubber) with thin gold lines round it
local function mat(name: string, x0: number, z0: number, x1: number, z1: number)
	local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, math.abs(x1 - x0), math.abs(z1 - z0)
	part({ Name = name .. "Mat", Size = Vector3.new(w, 0.08, d), CFrame = CFrame.new(cx, FLOOR_TOP + 0.04, cz), Material = Enum.Material.Rubber,
		Color = Color3.fromHex("#121315") })
	local y, t = FLOOR_TOP + 0.09, 0.16
	for _, line in ipairs({ { cx, z0, w, t }, { cx, z1, w, t }, { x0, cz, t, d }, { x1, cz, t, d } }) do
		part({ Name = name .. "Line", Size = Vector3.new(line[3], 0.02, line[4]), CFrame = CFrame.new(line[1], y, line[2]), Material = Enum.Material.Neon, Color = GOLD })
	end
end

-- a hanging warm lamp: a rod, a black shade with a gold rim and a warm glowing underside with a light
local function lamp(x: number, z: number, shadows: boolean?)
	part({ Name = "LampRod", Size = Vector3.new(0.12, 2.4, 0.12), CFrame = CFrame.new(x, 16.4, z), Material = Enum.Material.Metal, Color = INK })
	part({ Name = "LampShade", Size = Vector3.new(1.8, 0.7, 1.8), CFrame = CFrame.new(x, 15, z), Material = Enum.Material.Metal, Color = INK })
	part({ Name = "LampRim", Size = Vector3.new(1.86, 0.08, 1.86), CFrame = CFrame.new(x, 15.33, z), Material = Enum.Material.Neon, Color = GOLD })
	local glow = part({ Name = "LampGlow", Size = Vector3.new(1.4, 0.06, 1.4), CFrame = CFrame.new(x, 14.63, z), Material = Enum.Material.Neon,
		Color = Color3.fromHex("#FFE2B0") })
	local light = Instance.new("SpotLight")
	light.Face, light.Angle, light.Range, light.Brightness = Enum.NormalId.Bottom, 100, 22, 1.5
	light.Color, light.Shadows = Color3.fromHex("#FFD9A6"), shadows == true
	light.Parent = glow
end

-- a black + gold zone sign (an old ZoneSign model, restyled), hanging over (x, z), readable from both sides
local SIGN_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local function zoneSign(sign: Model, text: string, x: number, z: number)
	place(sign, x, z, S)
	sign:PivotTo(sign:GetPivot() + Vector3.new(0, 15.6 - sign:GetBoundingBox().Position.Y, 0))
	for _, d in ipairs(sign:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "Frame" then d.Color, d.Material = GOLD_DARK, Enum.Material.Metal
			elseif d.Name == "Panel" then d.Color = INK end
			d.CastShadow = false
		elseif d:IsA("TextLabel") then
			d.Text, d.TextColor3, d.FontFace = text, GOLD, SIGN_FONT
		end
	end
end

-- a SurfaceGui with lines of text on a part's front face
local function signText(p: BasePart, lines, pixelsPerStud: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, pixelsPerStud or 40, 0
	gui.Parent = p
	for _, line in ipairs(lines) do
		local label = Instance.new(line.image and "ImageLabel" or "TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position, label.Size = line.pos, line.size
		if line.image then
			label.Image, label.ImageColor3, label.ScaleType = line.image, line.color, Enum.ScaleType.Fit
		else
			label.Text, label.TextColor3, label.TextScaled, label.FontFace = line.text, line.color, true, line.font or SIGN_FONT
			if line.stroke then
				local stroke = Instance.new("UIStroke")
				stroke.Color, stroke.Thickness = line.stroke, line.strokeSize or 4
				stroke.Parent = label
			end
		end
		label.Parent = gui
	end
	return gui
end

function ProGymMakeover.Run()
	local pg = workspace.ProGym
	assert(SS:FindFirstChild("ProGymBackup_23Oct"), "copy the Pro Gym to ServerStorage.ProGymBackup_23Oct first")
	assert(not pg:FindFirstChild("Makeover"), "already made over")
	made = Instance.new("Folder")
	made.Name = "Makeover"
	made.Parent = pg
	removed = SS:FindFirstChild("ProGymRemoved_23Oct") or Instance.new("Folder")
	removed.Name = "ProGymRemoved_23Oct"
	removed.Parent = SS
	local M, P, props = pg.Machines, pg.ProMachines, pg.Props
	local function all(folder, name)
		local list = {}
		for _, c in ipairs(folder:GetChildren()) do if c.Name == name then table.insert(list, c) end end
		return list
	end

	-- 1) every machine a real Pro machine
	local function toPro(model: Model, proId: string)
		model:SetAttribute("MachineId", proId)
		model:SetAttribute("Pro", nil)
		model.Name = proId
		model.Parent = P
		return model
	end
	local benches = { P.ProFlatBench, toPro(M.FlatBench, "ProFlatBench"), P.ProInclineBench }
	local racks = { P.ProSquatRack }
	for _, rack in ipairs(all(M, "SquatRack")) do table.insert(racks, toPro(rack, "ProSquatRack")) end
	local deadlifts = { P.ProDeadlift, toPro(M.Deadlift, "ProDeadlift") }
	local hacks = { P.ProHackSquat, toPro(M.HackSquat, "ProHackSquat") }
	local presses = { P.ProLegPress, toPro(M.LegPress, "ProLegPress") }
	local cardio = props.Cardio
	local treadmills = { P.ProTreadmill }
	for i, t in ipairs(all(cardio, "Treadmill")) do
		if i <= 3 then table.insert(treadmills, toPro(t, "ProTreadmill")) else t.Parent = removed end -- (one row of 4)
	end
	local bike, rower = cardio:FindFirstChild("Bike"), cardio:FindFirstChild("Rower")
	if bike then bike.Parent = props end
	if rower then rower.Parent = props end
	cardio.Parent = removed
	-- the Starter dumbbell spots (DBCurl, Gym = Pro) become Pro spots (ProDBCurl, DumbbellSet = Pro)
	local oldRack = props.DumbbellRack
	local oldSpots = {}
	for i = 1, 4 do
		local spot = M:FindFirstChild("DumbbellSpot" .. i)
		if spot then
			spot:SetAttribute("MachineId", "ProDBCurl")
			spot:SetAttribute("DumbbellSet", "Pro")
			spot:SetAttribute("Gym", nil)
			spot.Name = "ProDumbbellSpot" .. (i + 4)
			spot.Parent = P
			table.insert(oldSpots, spot)
		end
	end
	local proSpots = {}
	for i = 1, 4 do table.insert(proSpots, P:FindFirstChild("ProDumbbellSpot" .. i)) end

	-- 2) the layout
	-- CARDIO: one row facing the street windows
	local row = { bike, treadmills[1], treadmills[2], treadmills[3], treadmills[4], rower }
	for i, model in ipairs(row) do
		if model then place(model, 67 + (i - 1) * 6, -9.5, S) end
	end
	-- MACHINES row facing the main aisle
	place(hacks[1], 70, -32, S); place(hacks[2], 77, -32, S)
	place(presses[1], 84, -32, S); place(presses[2], 91, -32, S)
	place(P.ProPullUpBar, 103, -32, S); place(P.ProBarbellRow, 113.5, -32, S)
	place(deadlifts[1], 123.5, -32, S); place(deadlifts[2], 133, -32, S) -- (8 studs wide each)
	place(P.ProCrunchBench, 142.5, -32, S)
	-- FREE WEIGHTS facing the long mirror on the back wall
	place(benches[1], 60, -54, N); place(benches[2], 72, -54, N); place(benches[3], 84, -54, N)
	place(racks[1], 56, -68, N); place(racks[2], 66, -68, N); place(racks[3], 76, -68, N)
	place(P.ProOverheadPress, 88, -68, N)
	-- the two dumbbell racks side by side (each with its 4 spots)
	local function moveRack(rack, spots, x)
		local dx = x - rack:GetBoundingBox().Position.X
		shift(rack, dx, 0)
		for _, spot in ipairs(spots) do shift(spot, dx, 0) end
	end
	moveRack(oldRack, oldSpots, 66)
	moveRack(P.ProDumbbellRack, proSpots, 86)
	-- ELITE: the sub-muscle machines in rows by body part, facing the room
	local elite = {
		{ "Shrugs", "ReverseFly", "LateralRaise" },
		{ "BicepCurl", "TricepPushdown", "Dips" },
		{ "LegCurl", "CalfRaise", "HipThrust" },
		{ "CableWoodchop", "HangingLegRaise" },
	}
	for r, names in ipairs(elite) do
		for c, name in ipairs(names) do
			local model = M:FindFirstChild(name)
			if model then place(model, 115 + (c - 1) * 10.5 + (if #names == 2 then 5 else 0), -52 - (r - 1) * 11, S) end
		end
	end
	-- STRETCH along the east wall mirrors
	place(props.StretchingArea, 147.5, -62, N) -- (its long side along the wall)
	place(pg.Feature_ArmWrestle.ArmWrestleTablePro, 147.5, -81, W)
	place(props.TowelRack, 150.5, -46, W)

	-- 3) props
	local lockers = all(props, "Lockers")
	table.sort(lockers, function(a, b) return a:GetBoundingBox().Position.X > b:GetBoundingBox().Position.X end) -- (the long one first)
	place(lockers[1], 104, -5.6, N)
	if lockers[2] then place(lockers[2], 114.5, -5.6, N) end
	local benchesProps = all(props, "Bench")
	local benchSpots = { { 53, -6.2 }, { 128, -6.2 }, { 138, -6.2 } }
	for i, b in ipairs(benchesProps) do if benchSpots[i] then place(b, benchSpots[i][1], benchSpots[i][2], N) end end
	place(props.WaterFountain, 61.5, -5.4, N)
	local plants = all(props, "Plant")
	local plantSpots = { { 47.5, -6 }, { 47, -31 }, { 48, -86.5 }, { 108, -86.5 } }
	for i, p in ipairs(plants) do if plantSpots[i] then place(p, plantSpots[i][1], plantSpots[i][2], N) end end
	local trees = all(props, "PlateTree")
	if trees[1] then place(trees[1], 98, -54, N) end
	if trees[2] then place(trees[2], 98, -68, N) end
	place(props.ChalkBowl, 94, -61, N)
	local chalk2 = props.ChalkBowl:Clone()
	chalk2.Parent = props
	place(chalk2, 51, -61, N)
	-- the TVs above the cardio row (on the front wall, facing in)
	local tvs = pg.Decor:GetChildren()
	local tvX = { 86, 93 }
	local n = 0
	for _, tv in ipairs(tvs) do
		if tv.Name == "WallTV" then
			n += 1
			if tvX[n] then
				place(tv, tvX[n], -4.75, N)
				tv:PivotTo(tv:GetPivot() + Vector3.new(0, 11 - tv:GetBoundingBox().Position.Y, 0))
			end
		end
	end

	-- 4) zone signs (7 restyled, the rest out)
	local signs = {}
	for _, s in ipairs(props:GetChildren()) do if s.Name == "ZoneSign" then table.insert(signs, s) end end
	for _, s in ipairs(pg.ZoneSignsEast:GetChildren()) do if s.Name == "ZoneSign" then table.insert(signs, s) end end
	local zones = { { "CARDIO", 79, -12 }, { "LEGS", 80.5, -32 }, { "BACK", 118, -32 }, { "ABS", 142.5, -32 }, { "FREE WEIGHTS", 72, -61 },
		{ "ELITE", 126, -46.5 }, { "STRETCH", 147.8, -50 } }
	for i, s in ipairs(signs) do
		local z = zones[i]
		if z then zoneSign(s, z[1], z[2], z[3]) else s.Parent = removed end
	end

	-- 5) the old spotlights over the old machine spots go; new lamps over every zone
	for _, name in ipairs({ "Spotlights", "SpotlightsEast" }) do
		local f = pg:FindFirstChild(name)
		if f then f.Parent = removed end
	end
	for _, x in ipairs({ 70, 79, 88, 97 }) do lamp(x, -10) end -- cardio
	for i, x in ipairs({ 70, 80, 90, 104, 114, 124, 134, 142 }) do lamp(x, -32, i == 3 or i == 6) end -- machines
	for _, z in ipairs({ -54, -68, -82 }) do for _, x in ipairs({ 58, 72, 86 }) do lamp(x, z, x == 72 and z == -68) end end -- free weights
	for _, z in ipairs({ -52, -63, -74, -85 }) do for _, x in ipairs({ 118, 133 }) do lamp(x, z) end end -- elite
	for _, z in ipairs({ -60, -78 }) do lamp(147.5, z) end -- stretch
	for _, x in ipairs({ 52, 60 }) do lamp(x, -20, x == 52) end -- entrance

	-- 6) the floor and the walls
	for _, floor in ipairs({ pg.Shell.Floor, pg.ShellEast.Floor }) do
		floor.Material, floor.Color, floor.Reflectance = Enum.Material.SmoothPlastic, Color3.fromHex("#1C1C20"), 0.06 -- (the aisles: dark, polished)
	end
	mat("Cardio", 63, -5.2, 100, -14)
	mat("Machines", 65, -26.5, 146, -37.8)
	mat("FreeWeights", 47, -45, 105, -88.5)
	mat("Elite", 109, -45, 141.5, -88.5)
	-- STRETCH: a warm rubber mat (its east side is the wall) and the yoga mats in gold so the corner reads
	local stretchMat = part({ Name = "StretchMat", Size = Vector3.new(10.5, 0.08, 43.5), CFrame = CFrame.new(147.75, 0.19, -66.75), Material = Enum.Material.Rubber,
		Color = Color3.fromHex("#2A2420") })
	local _ = stretchMat
	for _, line in ipairs({ { 147.75, -45, 10.5, 0.16 }, { 147.75, -88.5, 10.5, 0.16 }, { 142.5, -66.75, 0.16, 43.5 } }) do
		part({ Name = "StretchLine", Size = Vector3.new(line[3], 0.02, line[4]), CFrame = CFrame.new(line[1], 0.24, line[2]), Material = Enum.Material.Neon, Color = GOLD })
	end
	for _, p in ipairs(props.StretchingArea:GetDescendants()) do
		if p:IsA("BasePart") and (p.Name == "Mat" or p.Name == "RolledEnd") then p.Color = Color3.fromHex("#B8862B") end
	end
	-- the wall LED strips warm gold (inside only), and a gold trim line round the back and east walls
	for _, shell in ipairs({ pg.Shell, pg.ShellEast }) do
		for _, p in ipairs(shell:GetChildren()) do
			if p:IsA("BasePart") and (p.Name:find("^LedStrip") or p.Name:find("^LedSeam")) then p.Color = GOLD end
		end
	end
	part({ Name = "TrimBack", Size = Vector3.new(106, 0.14, 0.06), CFrame = CFrame.new(99, 9.7, -88.95), Material = Enum.Material.Neon, Color = GOLD })
	part({ Name = "TrimEast", Size = Vector3.new(0.06, 0.14, 83), CFrame = CFrame.new(153.4, 9.7, -46.5), Material = Enum.Material.Neon, Color = GOLD })

	-- 7) the entrance: the reception desk and the PRO GYM sign wall behind it
	local desk = part({ Name = "FrontDesk", Size = Vector3.new(10, 3.4, 2.6), CFrame = CFrame.lookAt(Vector3.new(56, FLOOR_TOP + 1.7, -24), Vector3.new(56, FLOOR_TOP + 1.7, -23)),
		Material = Enum.Material.SmoothPlastic, Color = INK, CanCollide = true })
	part({ Name = "FrontDeskTop", Size = Vector3.new(10.4, 0.22, 3), CFrame = CFrame.new(56, FLOOR_TOP + 3.51, -24), Material = Enum.Material.Metal, Color = GOLD_DARK })
	part({ Name = "FrontDeskLine", Size = Vector3.new(10.02, 0.12, 0.04), CFrame = CFrame.new(56, FLOOR_TOP + 2.6, -22.69), Material = Enum.Material.Neon, Color = GOLD })
	signText(desk, { { text = "WELCOME TO THE PRO GYM", color = GOLD, pos = UDim2.fromScale(0.5, 0.42), size = UDim2.fromScale(0.86, 0.32) } })
	local wall = part({ Name = "SignWall", Size = Vector3.new(15, 9.5, 0.6), CFrame = CFrame.lookAt(Vector3.new(56, FLOOR_TOP + 4.75, -31), Vector3.new(56, FLOOR_TOP + 4.75, -30)),
		Material = Enum.Material.SmoothPlastic, Color = INK, CanCollide = true })
	for _, edge in ipairs({ { 0, 4.55, 14.6, 0.16 }, { 0, -4.55, 14.6, 0.16 }, { -7.3, 0, 0.16, 9.2 }, { 7.3, 0, 0.16, 9.2 } }) do
		part({ Name = "SignWallFrame", Size = Vector3.new(edge[3], edge[4], 0.05), CFrame = wall.CFrame * CFrame.new(edge[1], edge[2], -0.33), Material = Enum.Material.Neon, Color = GOLD })
	end
	signText(wall, {
		{ image = "rbxassetid://97319043121415", color = GOLD, pos = UDim2.fromScale(0.5, 0.25), size = UDim2.fromScale(0.3, 0.3) }, -- (the flexing arm)
		{ text = "PRO GYM", color = GOLD, stroke = Color3.fromHex("#7A1414"), strokeSize = 6, pos = UDim2.fromScale(0.5, 0.58), size = UDim2.fromScale(0.86, 0.3) },
		{ text = "GYM ARC", color = Color3.fromHex("#F4F4F2"), pos = UDim2.fromScale(0.5, 0.82), size = UDim2.fromScale(0.5, 0.12) },
	}, 30)

	-- 8) the mural over the ELITE corner (back wall): black, gold and red, our own
	local mural = part({ Name = "Mural", Size = Vector3.new(34, 7.4, 0.25), CFrame = CFrame.lookAt(Vector3.new(130.5, 12.6, -88.75), Vector3.new(130.5, 12.6, -87.75)),
		Material = Enum.Material.SmoothPlastic, Color = INK })
	for _, edge in ipairs({ { 0, 3.6, 33.6, 0.14 }, { 0, -3.6, 33.6, 0.14 }, { -16.9, 0, 0.14, 7.2 }, { 16.9, 0, 0.14, 7.2 } }) do
		part({ Name = "MuralFrame", Size = Vector3.new(edge[3], edge[4], 0.05), CFrame = mural.CFrame * CFrame.new(edge[1], edge[2], -0.15), Material = Enum.Material.Neon, Color = GOLD })
	end
	signText(mural, {
		{ image = "rbxassetid://97319043121415", color = Color3.fromHex("#E53935"), pos = UDim2.fromScale(0.12, 0.5), size = UDim2.fromScale(0.16, 0.8) },
		{ text = "GYM ARC", color = GOLD, stroke = Color3.fromHex("#7A1414"), strokeSize = 8, pos = UDim2.fromScale(0.5, 0.42), size = UDim2.fromScale(0.62, 0.56),
			font = Font.fromEnum(Enum.Font.LuckiestGuy) },
		{ text = "ELITE  ·  NO LIMITS", color = Color3.fromHex("#F4F4F2"), pos = UDim2.fromScale(0.5, 0.82), size = UDim2.fromScale(0.5, 0.16) },
		{ image = "rbxassetid://122080504295664", color = Color3.fromHex("#E53935"), pos = UDim2.fromScale(0.88, 0.5), size = UDim2.fromScale(0.16, 0.8) },
	}, 24)

	-- every machine and dumbbell spot in the hall says Gym = "Pro" (GO TO "Gym:Pro" and the dumbbell GO TO read it)
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("Machine")) do
		if m:IsA("Model") and m:IsDescendantOf(pg) then m:SetAttribute("Gym", "Pro") end
	end

	-- 9) the gym-goers' spots follow the layout
	local spotMoves = { Pose = { { 147.8, -62 } }, Chat = { { 100, -41.5 }, { 62, -41.5 } }, Rest = { { 53, -8.6 } }, Water = { { 61.5, -8 } } }
	local used = {}
	for _, s in ipairs(workspace.Gym.NpcSpots:GetDescendants()) do
		if s:IsA("BasePart") and s:GetAttribute("Gym") == "Pro" then
			local kind = s:GetAttribute("Kind")
			used[kind] = (used[kind] or 0) + 1
			local to = spotMoves[kind] and spotMoves[kind][used[kind]]
			if to then s.CFrame = CFrame.new(to[1], s.Position.Y, to[2]) * s.CFrame.Rotation end
		end
	end
	return "done"
end

return ProGymMakeover
