-- StarterLayout builder (prompt 26, 21 Oct): the starter gym re-laid out so it feels open and organised, like a real gym.
-- Run ONCE in Studio (Edit mode) on the 21 Oct starter gym (done 21 Oct; the first run moved the west wall's rotated
-- parts and the wall decor by hand afterwards, fixed here); each step can be run on its own:
--   local B = require(game.ServerStorage._Builders.StarterLayout)
--   B.Backup()      -- ServerStorage.StarterGymBackup: a copy of everything this changes (tags removed: WasTags attribute)
--   B.Room()        -- the room 30 studs wider to the west (88 -> 118 x 85, +34%) and the ceiling 16 -> 18 (as the pro gym);
--                      the front wall, door, glass wall to the pro gym and the back (mirror) wall stay where they were
--   B.Exterior()    -- the building outside: parapets / coping / drainpipe / roof units follow, trees moved off the new wing
--   B.Machines()    -- zones in straight rows, duplicates removed (2 Flat Benches, 2 Squat Racks, 1 of everything else)
--   B.Props()       -- front strip, lounge corner, stretch corner, dumbbells on the mirror wall; loose props removed
--   B.Lights()      -- one grid of pendants at one height over the training rows, fewer lamps, fill lights re-gridded
--   B.Signs()       -- hanging zone signs (black + gold), the COACH DEX hanging sign replaced by a sign on the desk
-- Layout (x: west -74 .. east 44, the door at x 0 on the front wall z -4, the mirror wall z -89):
--   FRONT strip z -4 .. -18: desk + Coach Dex (right of the door), Trainer Agency (left), lounge corner (west: arm
--     wrestling, smoothie cart, a bench), the path to the pro gym's glass door (z -12.6) kept clear.
--   Main aisle x -6 .. 6 from the door to the dumbbells, 12 studs; 8+ studs between all rows.
--   FREE WEIGHTS (west, facing into the room): racks x -67, benches x -51, platforms x -35.
--   CABLES + ARMS x -20 (pushdown, curl, woodchop).
--   MACHINES (east, facing the aisle): rows x 12 and x 27.
--   CARDIO: one straight row by the glass wall x 41.
--   DUMBBELLS: the rack and its train spots along the mirror wall (back centre). STRETCH / RECOVERY: back-left corner.
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local DX = -30                 -- the west wall moves this far
local OLD_WEST, NEW_WEST = -44, -74
local RAISE = 2                -- ceiling 16 -> 18
local CEIL = 16

local function gym() return Workspace.Gym.StarterGym end
-- a part's size along world X (rotated wall pieces: Size.X is not the world width)
local function extentX(p)
	local r, s = p.CFrame, p.Size
	return math.abs(r.XVector.X) * s.X + math.abs(r.YVector.X) * s.Y + math.abs(r.ZVector.X) * s.Z
end
local function backupFolder()
	local f = ServerStorage:FindFirstChild("StarterGymBackup")
	if not f then
		f = Instance.new("Folder")
		f.Name = "StarterGymBackup"
		f.Parent = ServerStorage
	end
	return f
end

-- tags off (a backup must never be found by MachineService & co), remembered as an attribute
local function untag(root)
	for _, d in ipairs(root:GetDescendants()) do
		local tags = CollectionService:GetTags(d)
		if #tags > 0 then
			d:SetAttribute("WasTags", table.concat(tags, ","))
			for _, t in ipairs(tags) do CollectionService:RemoveTag(d, t) end
		end
	end
	local tags = CollectionService:GetTags(root)
	if #tags > 0 then
		root:SetAttribute("WasTags", table.concat(tags, ","))
		for _, t in ipairs(tags) do CollectionService:RemoveTag(root, t) end
	end
end

-- removed things go to StarterGymBackup.Removed (never destroyed)
local function remove(inst)
	local f = backupFolder():FindFirstChild("Removed") or Instance.new("Folder")
	f.Name = "Removed"
	f.Parent = backupFolder()
	untag(inst)
	inst.Parent = f
end

------------------------------------------------------------------------
function Builder.Backup()
	local f = backupFolder()
	if f:FindFirstChild("Before") then return "already backed up" end
	local before = Instance.new("Folder")
	before.Name = "Before"
	for _, inst in ipairs({ Workspace.Gym.StarterGym, Workspace.Gym.Machines, Workspace.Gym.NpcSpots, Workspace.Town.GymFront, Workspace.Town:FindFirstChild("GymRoofs"),
		Workspace:FindFirstChild("ArmWrestleTable"), Workspace:FindFirstChild("LeaderboardWall") }) do
		if inst then
			local c = inst:Clone()
			untag(c)
			c:SetAttribute("WasAt", inst:GetFullName())
			c.Parent = before
		end
	end
	before.Parent = f
	return "backed up"
end

------------------------------------------------------------------------
-- The room
------------------------------------------------------------------------
local function grow(part, dy)
	-- taller by dy, bottom stays
	part.Size += Vector3.new(0, dy, 0)
	part.CFrame += Vector3.new(0, dy / 2, 0)
end
local function extendWest(part, by)
	-- a part along X: its west end moves `by` (negative) further west, its east end stays
	part.Size += Vector3.new(math.abs(by), 0, 0)
	part.CFrame += Vector3.new(by / 2, 0, 0)
end

function Builder.Room()
	local sg = gym()
	if sg:GetAttribute("LayoutV2Room") then return "room already done" end
	local shell = sg.Shell
	local new = {}
	-- 1) the height: everything at the ceiling goes up, walls and anything hanging from the ceiling grow
	local WINDOW = { Window = true, WindowFrame = true, Mullion = true, StreetWindow = true }
	for _, d in ipairs(sg:GetDescendants()) do
		if d:IsA("BasePart") and not WINDOW[d.Name] then
			local bottom = d.Position.Y - d.Size.Y / 2
			local top = d.Position.Y + d.Size.Y / 2
			if bottom >= CEIL - 1.6 or (d.Name == "Vent" and bottom >= CEIL - 2.4) then
				d.CFrame += Vector3.new(0, RAISE, 0)                -- ceiling, beams, pipes, ducts, vents, mounts, cornice
			elseif top >= CEIL - 0.6 and (d.Size.Y >= 6 or (d.Size.X < 0.6 and d.Size.Z < 0.6)) then
				grow(d, RAISE)                                       -- walls (full height) and cords / chains / cables
			end
		end
	end
	-- 2) the west wall and everything on it moves west: whole models first (mirrors, posters, fans, speakers, washers),
	--    then the shell's own parts (the wall, its windows, skirting, cornice)
	local moved = {}
	for _, folder in ipairs({ sg.WallDecor, sg:FindFirstChild("LightingPass"), sg:FindFirstChild("Decor") }) do
		for _, m in ipairs(folder and folder:GetDescendants() or {}) do
			-- (the folders sit inside the StarterGym model: only the folder's own children / grandchildren count)
			if m:IsA("Model") and (m.Parent == folder or m.Parent.Parent == folder) then
				local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
				local ex = ok and (math.abs(cf.XVector.X) * size.X + math.abs(cf.YVector.X) * size.Y + math.abs(cf.ZVector.X) * size.Z) or 99
				if ok and cf.X < OLD_WEST + 4 and cf.X > OLD_WEST - 2 and ex < 4 then
					m:PivotTo(m:GetPivot() + Vector3.new(DX, 0, 0))
					for _, d in ipairs(m:GetDescendants()) do moved[d] = true end
				end
			elseif m:IsA("BasePart") and (m.Parent == folder or m.Parent.Parent == folder) and math.abs(m.Position.X - OLD_WEST) < 3 and extentX(m) < 4 then
				m.CFrame += Vector3.new(DX, 0, 0)
				moved[m] = true
			end
		end
	end
	for _, d in ipairs(shell:GetDescendants()) do
		if d:IsA("BasePart") and not moved[d] and math.abs(d.Position.X - OLD_WEST) < 1.6 and extentX(d) < 3 then
			d.CFrame += Vector3.new(DX, 0, 0)
		end
	end
	-- 3) parts across the room (floor, slab, ceiling, beams, back wall, front / back skirting and cornice, floor seams
	--    along X) reach the new west wall
	for _, d in ipairs(shell:GetChildren()) do
		if d:IsA("BasePart") then
			local minX = d.Position.X - d.Size.X / 2
			local alongX = d.Size.X > d.Size.Z
			if alongX and math.abs(minX - (OLD_WEST - 0.5)) < 1.6 and d.Size.X > 5 and not d.Name:find("FrontWall") and not d.Name:find("Window")
				and not d.Name:find("Mullion") and d.Name ~= "OutsideSill" and d.Name ~= "StreetWindow" then
				extendWest(d, DX)
			end
		end
	end
	-- 4) floor seams along Z for the new part of the floor
	local seam = nil
	for _, d in ipairs(shell:GetChildren()) do
		if d.Name == "Seam" and d.Size.Z > 50 then seam = d break end
	end
	if seam then
		for _, x in ipairs({ -44, -52, -60, -68 }) do
			local s = seam:Clone()
			s.CFrame = CFrame.new(x, seam.Position.Y, seam.Position.Z)
			s.Parent = shell
		end
	end
	-- 5) the new front wall: x -74.5 .. -45 with two street windows (copies of the window at x -38)
	local windowParts = {}
	for _, d in ipairs(shell:GetChildren()) do
		if d:IsA("BasePart") and d.Position.Z > -4.8 and d.Position.Z < -2 and d.Position.X > -41.6 and d.Position.X < -34.4
			and (d.Name == "WindowFrame" or d.Name == "Mullion" or d.Name == "StreetWindow" or d.Name == "OutsideSill" or (d.Name == "FrontWall" and d.Size.X < 8)) then
			table.insert(windowParts, d)
		end
	end
	for _, shift in ipairs({ -15, -28 }) do
		for _, d in ipairs(windowParts) do
			local c = d:Clone()
			c.CFrame += Vector3.new(shift, 0, 0)
			c.Parent = shell
		end
	end
	local wallTemplate = nil
	for _, d in ipairs(shell:GetChildren()) do
		if d.Name == "FrontWall" and d.Size.Y >= CEIL and math.abs(d.Position.X + 43) < 1 then wallTemplate = d end
	end
	if wallTemplate then
		for _, span in ipairs({ { -74.5, -69.5 }, { -62.5, -56.5 }, { -49.5, -45 } }) do
			local w = wallTemplate:Clone()
			w.Size = Vector3.new(span[2] - span[1], wallTemplate.Size.Y, wallTemplate.Size.Z)
			w.CFrame = CFrame.new((span[1] + span[2]) / 2, wallTemplate.Position.Y, wallTemplate.Position.Z)
			w.Parent = shell
		end
	end
	-- 6) a window on the new part of the back wall (a copy of the one at x -34)
	for _, d in ipairs(shell:GetChildren()) do
		if d:IsA("BasePart") and d.Position.Z < -89 and d.Position.X > -38 and d.Position.X < -30 and d.Position.Y > 11
			and (d.Name == "Window" or d.Name == "WindowFrame" or d.Name == "Mullion") then
			local c = d:Clone()
			c.CFrame += Vector3.new(-26, 0, 0)
			c.Parent = shell
		end
	end
	-- 7) one more duct line (with its vents and strap) over the new wing
	for _, d in ipairs(shell:GetChildren()) do
		if d:IsA("BasePart") and math.abs(d.Position.X + 25) < 1.2 and (d.Name == "Duct" or d.Name == "Vent" or d.Name == "DuctStrap") then
			local c = d:Clone()
			c.CFrame += Vector3.new(-30, 0, 0)
			c.Parent = shell
		end
	end
	-- 8) the ground under the new wing: terrain cleared from 8 studs under the floor up (it rose to ~2 studs, and the
	--    grass blades of terrain just under the thin floor showed through it)
	Workspace.Terrain:FillBlock(CFrame.new(-59.5, 6, -46.5), Vector3.new(29, 28, 85), Enum.Material.Air)
	sg:SetAttribute("LayoutV2Room", true)
	return "room done"
end

------------------------------------------------------------------------
-- Outside
------------------------------------------------------------------------
function Builder.Exterior()
	local front = Workspace.Town.GymFront
	if front:GetAttribute("LayoutV2") then return "exterior already done" end
	for _, d in ipairs(front:GetDescendants()) do
		if d:IsA("BasePart") then
			local minX = d.Position.X - d.Size.X / 2
			local overStarter = d.Position.X < 45 and d.Position.Z < -1 and d.Position.Z > -92
			if (d.Name == "Parapet" or d.Name == "Coping") and overStarter and d.Position.Y < 19 then
				d.CFrame += Vector3.new(0, RAISE, 0)
				if math.abs(d.Position.X + 45.5) < 1 and d.Size.Z > 50 then
					d.CFrame += Vector3.new(DX, 0, 0)              -- the west parapet
				elseif d.Size.X > 80 then
					extendWest(d, DX)                               -- front and back parapets, coping
				end
			elseif (d.Name == "RoofSign" or d.Name == "RoofSignBack") then
				d.CFrame += Vector3.new(0, RAISE, 0)
			elseif (d.Name == "Drainpipe" or d.Name == "Shoe") and math.abs(d.Position.X + 44.5) < 1 then
				d.CFrame += Vector3.new(DX, 0, 0)
			end
		end
	end
	local roofs = Workspace.Town:FindFirstChild("GymRoofs")
	if roofs then
		local unit = nil
		for _, d in ipairs(roofs:GetChildren()) do
			local pos = d:IsA("Model") and d:GetPivot().Position or (d:IsA("BasePart") and d.Position)
			if pos and pos.X < 44 and pos.Y < 20 then
				if d:IsA("Model") then d:PivotTo(d:GetPivot() + Vector3.new(0, RAISE, 0)) else d.CFrame += Vector3.new(0, RAISE, 0) end
				if d.Name == "AcUnit" and not unit then unit = d end
			end
		end
		if unit then
			local c = unit:Clone()
			if c:IsA("Model") then c:PivotTo(c:GetPivot() + Vector3.new(-62 - c:GetPivot().X, 0, 0)) else c.CFrame += Vector3.new(-62 - c.Position.X, 0, 0) end
			c.Parent = roofs
		end
	end
	-- trees on the new wing's ground move further west
	local greenery = Workspace.Town:FindFirstChild("Greenery")
	for _, tree in ipairs(greenery and greenery:GetChildren() or {}) do
		if tree:IsA("Model") then
			local p = tree:GetPivot().Position
			if p.X > -86 and p.X < -40 and p.Z > -96 and p.Z < 0 then
				tree:PivotTo(tree:GetPivot() + Vector3.new(-86 - p.X - 6, 0, 0))
			end
		end
	end
	front:SetAttribute("LayoutV2", true)
	return "exterior done"
end

------------------------------------------------------------------------
-- Machines
------------------------------------------------------------------------
local EAST, WEST, NORTH = Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)
-- id, how many to keep, then where: { x, z, facing } per copy
Builder.Plan = {
	-- free weights: racks against the west wall, benches, platforms (all facing into the room)
	{ "SquatRack", { -67, -26, EAST }, { -67, -44, EAST } },
	{ "OverheadPress", { -67, -62, EAST } },
	{ "FlatBench", { -51, -24, EAST }, { -51, -38, EAST } },
	{ "InclineBench", { -51, -52, EAST } },
	{ "Deadlift", { -35, -26, EAST } },
	{ "BarbellRow", { -35, -42, EAST } },
	-- cables + arms
	{ "TricepPushdown", { -20, -26, EAST } },
	{ "BicepCurl", { -20, -36, EAST } },
	{ "CableWoodchop", { -20, -46, EAST } },
	-- machines (facing the aisle)
	{ "LegPress", { 12, -24, WEST } },
	{ "HackSquat", { 12, -34, WEST } },
	{ "LegCurl", { 12, -44, WEST } },
	{ "CalfRaise", { 12, -54, WEST } },
	{ "HipThrust", { 12, -64, WEST } },
	{ "CrunchBench", { 12, -74, WEST } },
	{ "ReverseFly", { 27, -24, WEST } },
	{ "LateralRaise", { 27, -34, WEST } },
	{ "Shrugs", { 27, -44, WEST } },
	{ "Dips", { 27, -54, WEST } },
	{ "HangingLegRaise", { 27, -64, WEST } },
	{ "PullUpBar", { 27, -75, WEST } },
}
-- the cardio row by the glass wall (Props.Cardio children), facing north along the glass
Builder.Cardio = { Treadmill = { { 41, -24 }, { 41, -33 }, { 41, -42 } }, Bike = { { 41, -50 }, { 41, -56 } }, Rower = { { 41, -64 } } }
-- the dumbbell train spots in front of the rack on the mirror wall (rack at x 0)
Builder.DumbbellSpots = { { -9, -80 }, { -5.5, -80 }, { -2, -80 }, { 2, -80 }, { 5.5, -80 }, { 9, -80 } }

local function place(model, x, z, facing)
	local pivot = model:GetPivot()
	local pos = Vector3.new(x, pivot.Y, z)
	model:PivotTo(CFrame.lookAt(pos, pos + facing))
end

function Builder.Machines()
	local machines = Workspace.Gym.Machines
	if machines:GetAttribute("LayoutV2") then return "machines already done" end
	local byId = {}
	for _, m in ipairs(machines:GetChildren()) do
		local id = m:GetAttribute("MachineId")
		if id and not m.Name:find("DumbbellSpot") then
			byId[m.Name] = byId[m.Name] or {}
			table.insert(byId[m.Name], m)
		end
	end
	local report = {}
	for _, entry in ipairs(Builder.Plan) do
		local list = byId[entry[1]] or {}
		-- keep the copies with a starter "Gym" attribute last-resort order: the first found
		for i, m in ipairs(list) do
			local spot = entry[i + 1]
			if spot then
				place(m, spot[1], spot[2], spot[3])
			else
				remove(m)
				table.insert(report, "removed " .. m.Name)
			end
		end
		if #list < #entry - 1 then table.insert(report, "MISSING " .. entry[1]) end
	end
	-- anything left that the plan doesn't name stays where it is (reported)
	for name in pairs(byId) do
		local known = false
		for _, entry in ipairs(Builder.Plan) do if entry[1] == name then known = true end end
		if not known then table.insert(report, "NOT IN PLAN " .. name) end
	end
	-- cardio
	local cardio = gym().Props:FindFirstChild("Cardio")
	if cardio then
		local used = {}
		for _, c in ipairs(cardio:GetChildren()) do
			local spots = Builder.Cardio[c.Name]
			if spots and c:IsA("Model") then
				used[c.Name] = (used[c.Name] or 0) + 1
				local s = spots[used[c.Name]]
				if s then place(c, s[1], s[2], NORTH) end
			end
		end
	end
	-- dumbbell train spots in front of the mirror-wall rack, facing the mirror
	local i = 0
	for _, m in ipairs(machines:GetChildren()) do
		if m.Name:find("DumbbellSpot") then
			i += 1
			local s = Builder.DumbbellSpots[i]
			if s then place(m, s[1], s[2], NORTH) end
		end
	end
	machines:SetAttribute("LayoutV2", true)
	return table.concat(report, ", ")
end

------------------------------------------------------------------------
-- Props
------------------------------------------------------------------------
-- moves a model so the centre of its bounding box lands on x, z (height unchanged)
local function moveModel(m, x, z)
	if not m then return end
	local cf = if m:IsA("Model") then m:GetBoundingBox() else m.CFrame
	local delta = Vector3.new(x - cf.X, 0, z - cf.Z)
	if m:IsA("Model") then m:PivotTo(m:GetPivot() + delta) else m.CFrame += delta end
end

function Builder.Props()
	local sg = gym()
	if sg:GetAttribute("LayoutV2Props") then return "props already done" end
	local props = sg.Props
	local report = {}
	-- loose props that don't do anything: removed
	for _, name in ipairs({ "GymBag", "FloorMat" }) do
		for _, m in ipairs(props:GetChildren()) do
			if m.Name == name then remove(m) table.insert(report, "removed " .. name) end
		end
	end
	-- benches to sit on: one stays in the lounge, the other goes
	local benches = {}
	for _, m in ipairs(props:GetChildren()) do if m.Name == "Bench" then table.insert(benches, m) end end
	if benches[1] then moveModel(benches[1], -64, -6) end
	for i = 2, #benches do remove(benches[i]) table.insert(report, "removed a bench") end
	-- dumbbells on the mirror wall (back centre), plate trees beside the rack
	moveModel(props:FindFirstChild("DumbbellRack"), 0, -86.5)
	local trees = {}
	for _, m in ipairs(props:GetChildren()) do if m.Name == "PlateTree" then table.insert(trees, m) end end
	if trees[1] then moveModel(trees[1], -9.5, -86) end
	if trees[2] then moveModel(trees[2], 9.5, -86) end
	-- chalk bowls by the racks
	local bowls = {}
	for _, m in ipairs(props:GetChildren()) do if m.Name == "ChalkBowl" then table.insert(bowls, m) end end
	if bowls[1] then moveModel(bowls[1], -59, -35) end
	if bowls[2] then moveModel(bowls[2], -59, -53) end
	-- stretch / recovery: the back-left corner (mats, foam rollers, kettlebells, the stability ball)
	moveModel(props:FindFirstChild("StretchingArea"), -62, -80)
	-- the lounge corner (front-left): the smoothie cart and arm wrestling, out of the training rows
	local cart = sg:FindFirstChild("Feature_SmoothieBar") and sg.Feature_SmoothieBar:FindFirstChild("SmoothieCart")
	moveModel(cart, -46, -9)
	moveModel(Workspace:FindFirstChild("ArmWrestleTable"), -57, -12)
	-- the free-standing whiteboard in the room goes on the west wall
	local board = sg.Decor:FindFirstChild("Whiteboard")
	if board then remove(board) table.insert(report, "removed the standing whiteboard") end
	-- the regulars' spots: chat by the lounge and the stretch corner, rest on the lounge bench, water at the fountain
	local spots = Workspace.Gym:FindFirstChild("NpcSpots")
	if spots then
		local chats = {}
		for _, p in ipairs(spots:GetChildren()) do
			if p:IsA("BasePart") and p.Position.X < 45 then
				if p.Name == "Chat" then table.insert(chats, p)
				elseif p.Name == "Rest" then p.Position = Vector3.new(-64, p.Position.Y, -8)
				end
			end
		end
		if chats[1] then chats[1].Position = Vector3.new(-50, chats[1].Position.Y, -15) end
		if chats[2] then chats[2].Position = Vector3.new(-56, chats[2].Position.Y, -72) end
	end
	sg:SetAttribute("LayoutV2Props", true)
	return table.concat(report, ", ")
end

------------------------------------------------------------------------
-- Lights
------------------------------------------------------------------------
Builder.PendantX = { -59, -28, 0, 20, 36 }
Builder.PendantZ = { -24, -42, -60, -78 }
Builder.FillX = { -58, -28, 2, 30 }
Builder.FillZ = { -20, -46, -72 }

function Builder.Lights()
	local sg = gym()
	if sg:GetAttribute("LayoutV2Lights") then return "lights already done" end
	local pendants = sg.Pendants:GetChildren()
	local template = pendants[1]
	-- the extra pendants (LightingPass) go; the pendants are re-made as one grid at one height
	local extra = sg:FindFirstChild("LightingPass") and sg.LightingPass:FindFirstChild("ExtraPendants")
	if extra then remove(extra) end
	local keep = template:Clone()
	for _, p in ipairs(pendants) do remove(p) end
	local n = 0
	for _, z in ipairs(Builder.PendantZ) do
		for _, x in ipairs(Builder.PendantX) do
			n += 1
			local p = keep:Clone()
			p:PivotTo(p:GetPivot() + (Vector3.new(x, p:GetPivot().Y, z) - p:GetPivot().Position))
			-- (two of them cast shadows, as before: the rest don't)
			for _, d in ipairs(p:GetDescendants()) do
				if d:IsA("Light") then d.Shadows = (n == 7 or n == 14) end
			end
			p.Parent = sg.Pendants
		end
	end
	-- fill lights: a grid over the bigger room
	local fills = sg.FillLights:GetChildren()
	local fillTemplate = fills[1]:Clone()
	for _, f in ipairs(fills) do remove(f) end
	for _, z in ipairs(Builder.FillZ) do
		for _, x in ipairs(Builder.FillX) do
			local f = fillTemplate:Clone()
			f.Position = Vector3.new(x, fillTemplate.Position.Y, z)
			f.Parent = sg.FillLights
		end
	end
	sg:SetAttribute("LayoutV2Lights", true)
	return "pendants " .. n .. ", fills " .. #Builder.FillX * #Builder.FillZ
end

------------------------------------------------------------------------
-- Signs
------------------------------------------------------------------------
Builder.Zones = {
	{ "FREE WEIGHTS", -51, -18 },
	{ "CABLES + ARMS", -20, -20 },
	{ "MACHINES", 19.5, -18 },
	{ "CARDIO", 41, -19 },
	{ "DUMBBELLS", 0, -76 },
	{ "STRETCH", -62, -72 },
}

function Builder.Signs()
	local sg = gym()
	if sg:GetAttribute("LayoutV2Signs") then return "signs already done" end
	local folder = sg:FindFirstChild("ZoneSigns") or Instance.new("Folder")
	folder.Name = "ZoneSigns"
	folder.Parent = sg
	local source = Workspace.ProGym.Props:FindFirstChild("ZoneSign")
	for _, z in ipairs(Builder.Zones) do
		local sign = source:Clone()
		sign.Name = "ZoneSign"
		-- black + gold for the starter gym: a bigger dark panel, a brass frame, gold letters
		for _, d in ipairs(sign:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name == "Panel" then
					d.Size = Vector3.new(6.4, 1.6, d.Size.Z)
					d.Color = Color3.fromHex("#141417")
				elseif d.Name == "Frame" then
					d.Size = Vector3.new(6.6, 1.8, d.Size.Z)
					d.Color = Color3.fromHex("#C98A12")
				elseif d.Name == "Cable" then
					d.Size = Vector3.new(d.Size.X, 3.4, d.Size.Z)
				end
			elseif d:IsA("TextLabel") then
				d.Text = z[1]
				d.TextColor3 = Color3.fromHex("#F6C75A")
			end
		end
		-- hung at y 15.4, the panel facing the door (letters on both sides), two cables up to the ceiling at 18
		local side = -1
		for _, d in ipairs(sign:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name == "Cable" then
					d.CFrame = CFrame.new(z[2] + side * 3, 15.4 + 0.9 + d.Size.Y / 2, z[3])
					side = 1
				else
					d.CFrame = CFrame.new(z[2], 15.4, z[3])
				end
			end
		end
		sign.Parent = folder
	end
	-- the hanging COACH DEX sign (seen from behind it was a big dark board in the way): off; the name goes on the desk
	local booth = sg.Props:FindFirstChild("CoachBooth")
	local coachSign = booth and booth:FindFirstChild("CoachSign")
	local desk = sg.Props:FindFirstChild("FrontDesk")
	local counter = desk and desk:FindFirstChild("Counter")
	if coachSign and counter then
		local face = coachSign:FindFirstChild("Face")
		local gui = face and face:FindFirstChildOfClass("SurfaceGui")
		local plate = Instance.new("Part")
		plate.Name = "CoachNameplate"
		plate.Anchored, plate.CanCollide, plate.CanQuery, plate.CastShadow = true, false, false, false
		plate.Material = Enum.Material.SmoothPlastic
		plate.Color = Color3.fromHex("#141417")
		plate.Size = Vector3.new(5.6, 1.1, 0.1)
		-- on the counter's front (the side facing into the room, away from the front wall)
		plate.CFrame = CFrame.new(counter.Position.X, counter.Position.Y + 0.6, counter.Position.Z - counter.Size.Z / 2 - 0.06)
		local trim = Instance.new("Part")
		trim.Name = "CoachNameplateTrim"
		trim.Anchored, trim.CanCollide, trim.CanQuery, trim.CastShadow = true, false, false, false
		trim.Material = Enum.Material.Metal
		trim.Color = Color3.fromHex("#C98A12")
		trim.Size = Vector3.new(5.8, 1.3, 0.06)
		trim.CFrame = plate.CFrame * CFrame.new(0, 0, 0.04)
		trim.Parent = booth
		if gui then
			local g = gui:Clone()
			g.Face = Enum.NormalId.Front
			g.Parent = plate
		end
		plate.Parent = booth
		remove(coachSign)
	end
	sg:SetAttribute("LayoutV2Signs", true)
	return "signs done"
end

return Builder
