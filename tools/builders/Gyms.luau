-- Gyms builder (run once in Studio; see tools/bake.md): the starter gym (about 2x the old room) and the pro gym right
-- next to it, sharing a wall with a big glass window and a glass door. Output:
--   Workspace.Gym.StarterGym   room, zones, props, lights (the entrance hall in Workspace.Gym.Entrance is kept)
--   Workspace.Gym.Machines     18 starter machines (2-3 of each), tag "Machine"
--   Workspace.ProGym           room, 15 machines, lockers, podium, signage, LED + spotlights
--   Workspace.ProGym.GlassDoor the door between the gyms (ProGymService/ProGymClient run it)
--   Workspace.Gym.NpcSpots     points the gym-goer NPCs walk to (water, chat, rest)
-- Starter gym inside: x -36..36, z -73.5..-4 (front wall with the entrance at z -3.5). Pro gym inside: x 37..93.
-- Needs ReplicatedStorage.GymAssets (GymAssets builder) for the plates.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local GymKit = require(script.Parent.GymKit)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local Gyms = {}

local C, p, cyl, at, model = GymKit.C, GymKit.p, GymKit.cyl, GymKit.at, GymKit.model
local hex, rad = Kit.hex, math.rad
local M = Enum.Material

Gyms.Starter = { MinX = -36, MaxX = 36, MinZ = -73.5, MaxZ = -4, Height = 13 }
Gyms.Pro = { MinX = 37, MaxX = 93, MinZ = -73.5, MaxZ = -4, Height = 14 }
Gyms.Door = { Z = -11, Width = 6, Height = 8 } -- the glass door in the shared wall (x = 36.5)

-- yaw that turns local +Z toward a direction (machines: the lifter looks along local +Z; props with their front on
-- local -Z use the opposite one)
local YAW = { East = 90, West = -90, North = 180, South = 0 }

local function face(x, z, yaw)
	return CFrame.new(x, 0, z) * CFrame.Angles(0, rad(yaw or 0), 0)
end

------------------------------------------------------------------------
-- Shell pieces
------------------------------------------------------------------------
local function wallWithWindows(parent, name, from, to, height, color, material, windows)
	-- a straight wall from `from` to `to` (floor points) with optional high windows: { { along, width } }
	local dir = (to - from)
	local length = dir.Magnitude
	local cf = CFrame.lookAt((from + to) / 2, (from + to) / 2 + dir.Unit:Cross(Vector3.yAxis)) -- local X along the wall
	local wall = p(parent, name, Vector3.new(length + 1, height, 1), cf * CFrame.new(0, height / 2, 0), color, material, true)
	for _, win in ipairs(windows or {}) do
		local wcf = cf * CFrame.new(win[1] - length / 2, 10.4, 0)
		local pane = p(parent, "Window", Vector3.new(win[2], 1.9, 1.04), wcf, hex("#E8E2D6"), M.Glass, false, { Transparency = 0.25 })
		p(parent, "WindowFrame", Vector3.new(win[2] + 0.3, 0.15, 1.08), wcf * CFrame.new(0, 1.0, 0), hex("#1C1C1E"), M.Metal)
		p(parent, "WindowFrame", Vector3.new(win[2] + 0.3, 0.15, 1.08), wcf * CFrame.new(0, -1.0, 0), hex("#1C1C1E"), M.Metal)
		for i = -1, 1, 2 do p(parent, "WindowFrame", Vector3.new(0.15, 2.1, 1.08), wcf * CFrame.new(i * win[2] / 2, 0, 0), hex("#1C1C1E"), M.Metal) end
		for i = 1, 2 do p(parent, "Mullion", Vector3.new(0.08, 1.9, 1.06), wcf * CFrame.new(-win[2] / 2 + i * win[2] / 3, 0, 0), hex("#1C1C1E"), M.Metal) end
		-- soft daylight coming in
		local glow = Instance.new("SurfaceLight")
		glow.Face = Enum.NormalId.Back
		glow.Brightness, glow.Range, glow.Angle, glow.Color, glow.Shadows = 0.6, 10, 90, hex("#FFE9C9"), false
		glow.Face = Enum.NormalId.Front
		glow.Parent = pane
	end
	return wall
end

-- Skirting board and a top cornice along a wall's inside face.
local function trims(parent, from, to, inward, height, color)
	local dir = (to - from)
	local cf = CFrame.lookAt((from + to) / 2, (from + to) / 2 + inward)
	local length = dir.Magnitude
	p(parent, "Skirting", Vector3.new(length, 0.35, 0.12), cf * CFrame.new(0, 0.32, -0.06), color or hex("#1A1A1C"), M.Metal)
	p(parent, "Cornice", Vector3.new(length, 0.3, 0.2), cf * CFrame.new(0, height - 0.15, -0.1), color or hex("#1A1A1C"), M.Metal)
end

------------------------------------------------------------------------
-- Starter gym
------------------------------------------------------------------------
local function starterShell(room)
	local S = Gyms.Starter
	local cx, cz = (S.MinX + S.MaxX) / 2, (S.MinZ + S.MaxZ) / 2
	local w, d = S.MaxX - S.MinX, S.MaxZ - S.MinZ
	local shell = Instance.new("Folder")
	shell.Name = "Shell"
	shell.Parent = room
	-- floor: concrete slab, rubber tiles with seams
	p(shell, "Slab", Vector3.new(w + 2, 1, d + 2), CFrame.new(cx, -0.45, cz), C.Concrete, M.Concrete, true)
	p(shell, "Floor", Vector3.new(w, 0.1, d), CFrame.new(cx, 0.1, cz), C.Floor, M.Rubber, true)
	for x = S.MinX + 8, S.MaxX - 1, 8 do p(shell, "Seam", Vector3.new(0.06, 0.01, d), CFrame.new(x, 0.155, cz), hex("#202022")) end
	for z = S.MinZ + 8, S.MaxZ - 1, 8 do p(shell, "Seam", Vector3.new(w, 0.01, 0.06), CFrame.new(cx, 0.155, z), hex("#202022")) end
	-- walls (front wall leaves the entrance gap x -5..5, the east wall is the glass partition)
	local h = S.Height
	wallWithWindows(shell, "WestWall", Vector3.new(S.MinX - 0.5, 0, S.MinZ - 0.5), Vector3.new(S.MinX - 0.5, 0, -3.5), h, C.Brick, M.Brick,
		{ { 10, 5 }, { 26, 5 }, { 42, 5 }, { 58, 5 } })
	wallWithWindows(shell, "BackWall", Vector3.new(S.MinX - 1, 0, S.MinZ - 0.5), Vector3.new(S.MaxX + 1, 0, S.MinZ - 0.5), h, C.Brick, M.Brick,
		{ { 8, 5 }, { 64, 5 } })
	-- front wall (x -37..-5 and 5..37) with big framed street windows, so people outside see into the gym
	local function frontWall(fromX, toX, windows)
		local x = fromX
		table.sort(windows, function(a, b) return a[1] < b[1] end)
		for _, win in ipairs(windows) do
			local left, right = win[1] - win[2] / 2, win[1] + win[2] / 2
			if left > x then p(shell, "FrontWall", Vector3.new(left - x, h, 1), CFrame.new((x + left) / 2, h / 2, -3.5), C.Brick, M.Brick, true) end
			p(shell, "FrontWall", Vector3.new(win[2], 2.2, 1), CFrame.new(win[1], 1.1, -3.5), C.Brick, M.Brick, true)
			p(shell, "FrontWall", Vector3.new(win[2], h - 8.2, 1), CFrame.new(win[1], 8.2 + (h - 8.2) / 2, -3.5), C.Brick, M.Brick, true)
			p(shell, "StreetWindow", Vector3.new(win[2], 6, 0.2), CFrame.new(win[1], 5.2, -3.5), hex("#9DB3BE"), M.Glass, true, { Transparency = 0.55, Reflectance = 0.08 })
			for _, z in ipairs({ -4.05, -2.95 }) do
				p(shell, "WindowFrame", Vector3.new(win[2] + 0.3, 0.3, 0.12), CFrame.new(win[1], 8.2, z), C.Frame, M.Metal)
				p(shell, "WindowFrame", Vector3.new(win[2] + 0.3, 0.3, 0.12), CFrame.new(win[1], 2.2, z), C.Frame, M.Metal)
				p(shell, "WindowFrame", Vector3.new(0.3, 6.3, 0.12), CFrame.new(left, 5.2, z), C.Frame, M.Metal)
				p(shell, "WindowFrame", Vector3.new(0.3, 6.3, 0.12), CFrame.new(right, 5.2, z), C.Frame, M.Metal)
				for i = 1, math.floor(win[2] / 2.2) do
					p(shell, "Mullion", Vector3.new(0.12, 6, 0.1), CFrame.new(left + i * win[2] / (math.floor(win[2] / 2.2) + 1), 5.2, z), C.Frame, M.Metal)
				end
			end
			p(shell, "OutsideSill", Vector3.new(win[2] + 0.6, 0.25, 0.6), CFrame.new(win[1], 2.15, -2.75), hex("#8E8A82"), M.Concrete)
			x = right
		end
		if toX > x then p(shell, "FrontWall", Vector3.new(toX - x, h, 1), CFrame.new((x + toX) / 2, h / 2, -3.5), C.Brick, M.Brick, true) end
	end
	frontWall(-37, -5, { { -31, 6 }, { -19, 6 } })
	frontWall(5, 37, { { 31, 6 } })
	p(shell, "DoorHeader", Vector3.new(10, 4, 1), CFrame.new(0, 11, -3.5), C.Brick, M.Brick, true)
	for _, x in ipairs({ -5.2, 5.2 }) do p(shell, "DoorFrame", Vector3.new(0.4, 9, 1.2), CFrame.new(x, 4.5, -3.5), C.Frame, M.Metal, true) end
	p(shell, "DoorFrame", Vector3.new(10.6, 0.5, 1.2), CFrame.new(0, 9.1, -3.5), C.Frame, M.Metal, true)
	trims(shell, Vector3.new(S.MinX, 0, S.MinZ), Vector3.new(S.MinX, 0, -4), Vector3.new(1, 0, 0), h)
	trims(shell, Vector3.new(S.MinX, 0, S.MinZ), Vector3.new(S.MaxX, 0, S.MinZ), Vector3.new(0, 0, 1), h)
	trims(shell, Vector3.new(S.MinX, 0, -4), Vector3.new(-5.4, 0, -4), Vector3.new(0, 0, -1), h)
	trims(shell, Vector3.new(5.4, 0, -4), Vector3.new(S.MaxX, 0, -4), Vector3.new(0, 0, -1), h)
	-- ceiling with exposed beams, ducts and pipes
	p(shell, "Ceiling", Vector3.new(w + 2, 1, d + 2), CFrame.new(cx, h + 0.5, cz), hex("#2A2826"), M.Concrete, true)
	for z = S.MinZ + 6, S.MaxZ - 2, 8 do
		p(shell, "Beam", Vector3.new(w, 0.9, 0.5), CFrame.new(cx, h - 0.45, z), C.Frame, M.Metal)
		p(shell, "BeamFlange", Vector3.new(w, 0.1, 0.8), CFrame.new(cx, h - 0.9, z), C.Frame, M.Metal)
	end
	for _, x in ipairs({ -20, 4, 26 }) do
		p(shell, "Duct", Vector3.new(2.2, 1.4, d - 2), CFrame.new(x, h - 1.3, cz), hex("#5A5C60"), M.DiamondPlate)
		for z = S.MinZ + 10, S.MaxZ - 4, 12 do p(shell, "Vent", Vector3.new(1.6, 0.1, 1.6), CFrame.new(x, h - 2.05, z), hex("#3A3C40"), M.DiamondPlate) end
		p(shell, "DuctStrap", Vector3.new(2.4, 0.1, 0.2), CFrame.new(x, h - 0.55, cz), C.Frame, M.Metal)
	end
	for _, x in ipairs({ -10, -9.4, 14 }) do
		cyl(shell, "Pipe", d - 2, x == 14 and 0.6 or 0.35, CFrame.new(x, h - 0.6, cz) * CFrame.Angles(0, rad(90), 0), x == 14 and hex("#6B4A3A") or C.Steel, M.Metal)
	end
end

-- The shared wall between the gyms: brick on the starter side, dark concrete on the pro side, a long glass window and
-- the glass door. `build` is the folder to put it in.
local function sharedWall(folder)
	local x, h, minZ = 36.5, 14, Gyms.Starter.MinZ - 0.5
	local doorZ, doorW, doorH = Gyms.Door.Z, Gyms.Door.Width, Gyms.Door.Height
	local glassFrom, glassTo = -17, -70 -- the window spans z -17 .. -70
	local function pier(z0, z1)
		local len, mid = z0 - z1, (z0 + z1) / 2
		p(folder, "PierStarter", Vector3.new(0.5, h, len), CFrame.new(x - 0.25, h / 2, mid), C.Brick, M.Brick, true)
		p(folder, "PierPro", Vector3.new(0.5, h, len), CFrame.new(x + 0.25, h / 2, mid), C.ProWall, M.Concrete, true)
	end
	pier(-3, doorZ + doorW / 2)
	pier(doorZ - doorW / 2, glassFrom)
	pier(glassTo, minZ)
	-- above the door
	local headerH = h - doorH
	p(folder, "DoorHeaderStarter", Vector3.new(0.5, headerH, doorW), CFrame.new(x - 0.25, doorH + headerH / 2, doorZ), C.Brick, M.Brick, true)
	p(folder, "DoorHeaderPro", Vector3.new(0.5, headerH, doorW), CFrame.new(x + 0.25, doorH + headerH / 2, doorZ), C.ProWall, M.Concrete, true)
	-- the window: sill, header, glass and chrome mullions
	local len, mid = glassFrom - glassTo, (glassFrom + glassTo) / 2
	p(folder, "SillStarter", Vector3.new(0.5, 1.2, len), CFrame.new(x - 0.25, 0.6, mid), C.Brick, M.Brick, true)
	p(folder, "SillPro", Vector3.new(0.5, 1.2, len), CFrame.new(x + 0.25, 0.6, mid), C.ProWall, M.Concrete, true)
	p(folder, "SillCap", Vector3.new(1.3, 0.12, len), CFrame.new(x, 1.26, mid), C.Chrome, M.Metal)
	p(folder, "HeaderStarter", Vector3.new(0.5, h - 10.8, len), CFrame.new(x - 0.25, 10.8 + (h - 10.8) / 2, mid), C.Brick, M.Brick, true)
	p(folder, "HeaderPro", Vector3.new(0.5, h - 10.8, len), CFrame.new(x + 0.25, 10.8 + (h - 10.8) / 2, mid), C.ProWall, M.Concrete, true)
	local glass = p(folder, "WindowGlass", Vector3.new(0.25, 9.5, len), CFrame.new(x, 1.32 + 4.75, mid), C.Glass, M.Glass, true, { Transparency = 0.72, Reflectance = 0.08 })
	glass.CastShadow = false
	glass.CanQuery = false
	local n = math.floor(len / 6.6)
	for i = 0, n do
		local z = glassFrom - i * (len / n)
		p(folder, "Mullion", Vector3.new(0.5, 9.6, 0.25), CFrame.new(x, 1.32 + 4.8, z), C.Chrome, M.Metal)
	end
	p(folder, "WindowTopRail", Vector3.new(0.5, 0.2, len), CFrame.new(x, 10.85, mid), C.Chrome, M.Metal)
	-- the door: frame, two glass leaves, a lock panel (both sides) and an invisible blocker the client opens
	local door = model(folder, "GlassDoor", CFrame.new(x, 0, doorZ))
	p(door, "FrameTop", Vector3.new(0.6, 0.35, doorW + 0.4), CFrame.new(x, doorH - 0.17, doorZ), C.Chrome, M.Metal, true)
	for _, s in ipairs({ -1, 1 }) do
		p(door, "FrameSide", Vector3.new(0.6, doorH, 0.25), CFrame.new(x, doorH / 2, doorZ + s * (doorW / 2 + 0.05)), C.Chrome, M.Metal, true)
		local leaf = model(door, s < 0 and "LeafA" or "LeafB", CFrame.new(x, 0, doorZ + s * doorW / 4))
		local pane = p(leaf, "Pane", Vector3.new(0.12, doorH - 0.6, doorW / 2 - 0.1), CFrame.new(x, (doorH - 0.6) / 2 + 0.1, doorZ + s * doorW / 4), C.Glass, M.Glass, false, { Transparency = 0.6, Reflectance = 0.1 })
		pane.CanQuery = false
		p(leaf, "Rail", Vector3.new(0.16, 0.25, doorW / 2 - 0.1), CFrame.new(x, doorH - 0.6, doorZ + s * doorW / 4), C.Chrome, M.Metal)
		p(leaf, "Rail", Vector3.new(0.16, 0.25, doorW / 2 - 0.1), CFrame.new(x, 0.2, doorZ + s * doorW / 4), C.Chrome, M.Metal)
		p(leaf, "PullBar", Vector3.new(0.5, 2.4, 0.1), CFrame.new(x, 3.6, doorZ + s * 0.4), C.Chrome, M.Metal)
		leaf:SetAttribute("Side", s)
	end
	local blocker = p(door, "Blocker", Vector3.new(0.4, doorH, doorW), CFrame.new(x, doorH / 2, doorZ), C.Glass, M.SmoothPlastic, true, { Transparency = 1 })
	blocker.CanQuery = false
	-- lock sign on the starter side: a lock icon and the unlock rule, on a lit panel above the door
	local sign = p(door, "LockSign", Vector3.new(0.12, 1.6, doorW), CFrame.new(x - 0.6, doorH + 1.2, doorZ), hex("#141416"), M.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LockGui"
	gui.Face = Enum.NormalId.Left -- faces the starter gym (-X)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = sign
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.5)
	title.BackgroundTransparency = 1
	title.Text = "PRO GYM"
	title.TextColor3 = C.Chalk
	title.FontFace = Theme.Fonts.SemiBold
	title.TextScaled = true
	title.Parent = gui
	local rule = title:Clone()
	rule.Name = "Rule"
	rule.Position = UDim2.fromScale(0, 0.52)
	rule.Size = UDim2.fromScale(1, 0.36)
	rule.Text = "Unlocks at Growth Spurt 2"
	rule.TextColor3 = hex("#B8B8BE")
	rule.FontFace = Theme.Fonts.Regular
	rule.Parent = gui
	-- the lock: a padlock made of parts on the door glass (shackle + body), on both sides
	for _, s in ipairs({ -1, 1 }) do
		local lockCF = CFrame.new(x + s * 0.12, 4.6, doorZ)
		local lock = model(door, "Lock", lockCF)
		p(lock, "Body", Vector3.new(0.12, 0.7, 0.8), lockCF, hex("#C9A64B"), M.Metal)
		p(lock, "Keyhole", Vector3.new(0.14, 0.22, 0.1), lockCF * CFrame.new(0, -0.05, 0), hex("#1A1A1A"), M.SmoothPlastic)
		p(lock, "ShackleL", Vector3.new(0.08, 0.45, 0.1), lockCF * CFrame.new(0, 0.55, -0.25), C.Steel, M.Metal)
		p(lock, "ShackleR", Vector3.new(0.08, 0.45, 0.1), lockCF * CFrame.new(0, 0.55, 0.25), C.Steel, M.Metal)
		p(lock, "ShackleTop", Vector3.new(0.08, 0.1, 0.6), lockCF * CFrame.new(0, 0.78, 0), C.Steel, M.Metal)
	end
	-- a soft light on the sign
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Left
	light.Brightness, light.Range, light.Angle, light.Color = 0.8, 6, 90, C.Led
	light.Parent = sign
	door:SetAttribute("UnlockSpurts", 2)
	return door
end

local function muscleBoard(parent, cframe)
	local frame = p(parent, "BoardFrame", Vector3.new(5.4, 3.8, 0.1), cframe * CFrame.new(0, 0, 0.03), hex("#5C4028"), M.Wood)
	local board = p(parent, "MuscleOfTheDayBoard", Vector3.new(5, 3.4, 0.15), cframe, hex("#222C26"), M.Slate)
	p(parent, "ChalkTray", Vector3.new(5.2, 0.12, 0.3), cframe * CFrame.new(0, -1.95, -0.15), hex("#5C4028"), M.Wood)
	p(parent, "Chalk", Vector3.new(0.4, 0.08, 0.08), cframe * CFrame.new(1.4, -1.86, -0.18), C.Chalk, M.Sand)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.5
	gui.Parent = board
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.04, 0)
	list.Parent = gui
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.86, 0.2)
	title.BackgroundTransparency = 1
	title.Text = "Muscle of the Day"
	title.TextColor3 = C.Chalk
	title.FontFace = Theme.Fonts.Regular
	title.TextScaled = true
	title.Parent = gui
	local muscle = title:Clone()
	muscle.Name = "Muscle"
	muscle.Size = UDim2.fromScale(0.86, 0.3)
	muscle.Text = "coming soon"
	muscle.FontFace = Theme.Fonts.SemiBold
	muscle.Parent = gui
	return board, frame
end

-- the neon sign above the mirror wall
local function neonSign(parent, cframe, text, color, w, h)
	local back = p(parent, "NeonSignBack", Vector3.new(w, h, 0.2), cframe, hex("#121214"), M.Metal)
	p(parent, "NeonSignFrame", Vector3.new(w + 0.3, h + 0.3, 0.12), cframe * CFrame.new(0, 0, 0.08), hex("#28282C"), M.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 2.5
	gui.Parent = back
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.FontFace = Theme.Fonts.SemiBold
	label.TextScaled = true
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.15, 0), UDim.new(0.15, 0)
	pad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.5
	stroke.Thickness = 2
	stroke.Parent = label
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Brightness, glow.Range, glow.Angle, glow.Color, glow.Shadows = 1, 8, 120, color, false
	glow.Parent = back
	return back
end

local function starterRoom(gym)
	local room = Kit.fresh(gym, "Folder", "StarterGym")
	starterShell(room)
	local S = Gyms.Starter
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = room
	local decor = Instance.new("Folder")
	decor.Name = "WallDecor"
	decor.Parent = room

	-- Reception (front right): desk facing the entrance aisle, towels, cat bed, the Muscle of the Day board
	GymKit.frontDesk(props, face(20, -11, 90), 9)
	GymKit.towelRack(props, face(33.5, -6.5, 180))
	local catBed = model(props, "CatBed", CFrame.new(31.5, 0, -14))
	cyl(catBed, "Cushion", 0.35, 2.4, CFrame.new(31.5, 0.2, -14) * CFrame.Angles(0, 0, rad(90)), hex("#6B4F3A"), M.Fabric)
	cyl(catBed, "Rim", 0.6, 2.7, CFrame.new(31.5, 0.3, -14) * CFrame.Angles(0, 0, rad(90)), hex("#4A3628"), M.Fabric)
	cyl(catBed, "Inner", 0.62, 2.0, CFrame.new(31.5, 0.33, -14) * CFrame.Angles(0, 0, rad(90)), hex("#7A5C44"), M.Fabric)
	muscleBoard(decor, CFrame.lookAt(Vector3.new(12, 6.2, -4.1), Vector3.new(12, 6.2, 0)) * CFrame.Angles(0, math.pi, 0))
	GymKit.plant(props, face(7.5, -5.8), 3.6)
	GymKit.plant(props, face(-7.5, -5.8), 3.6)
	-- welcome strip (front left): water fountain, benches, bag cubbies, trash
	GymKit.waterFountain(props, face(-14, -4.8, 0))
	GymKit.bench(props, face(-24, -5.6, 0), 6)
	GymKit.bench(props, face(-32.5, -10, 90), 5)
	GymKit.trashCan(props, face(-10.5, -5.2))
	GymKit.trashCan(props, face(10.5, -5.2))
	for i, color in ipairs({ hex("#1E2A3A"), hex("#3A2A22"), hex("#2A3A2E") }) do
		GymKit.gymBag(props, face(-26 + i * 1.9, -5.5 + 0.1 * i, 90), color)
	end
	GymKit.wallClock(decor, CFrame.lookAt(Vector3.new(0, 11.2, -4.1), Vector3.new(0, 11.2, -10)))

	-- Free weights (west): power racks and overhead press stands along the wall, lifting platforms beside them
	local machines = Kit.fresh(gym, "Folder", "Machines")
	GymKit.SquatRack(machines, face(-31, -14, YAW.East))
	GymKit.SquatRack(machines, face(-31, -26, YAW.East))
	GymKit.OverheadPress(machines, face(-31, -38, YAW.East))
	GymKit.SquatRack(machines, face(-31, -50, YAW.East))
	GymKit.OverheadPress(machines, face(-31, -62, YAW.East))
	GymKit.Deadlift(machines, face(-17.5, -17, YAW.East))
	GymKit.BarbellRow(machines, face(-17.5, -30, YAW.East))
	GymKit.Deadlift(machines, face(-17.5, -44, YAW.East))
	GymKit.BarbellRow(machines, face(-17.5, -57, YAW.East))
	GymKit.plateTree(props, face(-24, -20, 15))
	GymKit.plateTree(props, face(-24, -44, -10))
	GymKit.plateTree(props, face(-24, -66, 30), { { 45, 45 }, { 55 }, { 35, 25 }, { 25 }, { 10, 10 }, { 5 } })
	GymKit.chalkBowl(props, face(-24, -32))
	GymKit.chalkBowl(props, face(-24, -56))
	GymKit.dumbbellRack(props, face(-21, -71.2, 180), 12)
	for i = 0, 3 do GymKit.kettlebell(props, face(-30 + i * 1.3, -71.6), 0.7 + i * 0.12) end
	-- mirrors and posters on the west wall, between the windows
	for _, z in ipairs({ -20, -44, -68 }) do GymKit.mirror(decor, CFrame.lookAt(Vector3.new(-35.92, 4.3, z), Vector3.new(0, 4.3, z)), 6, 6.5) end
	GymKit.poster(decor, CFrame.lookAt(Vector3.new(-35.9, 5.8, -32), Vector3.new(0, 5.8, -32)), "CHALK UP.\nLOCK IN.", 3, 4)
	GymKit.poster(decor, CFrame.lookAt(Vector3.new(-35.9, 5.8, -56), Vector3.new(0, 5.8, -56)), "ONE\nMORE\nREP.", 3, 4)

	-- Bench row (back): flat and incline benches facing the mirror wall, neon sign above it
	GymKit.FlatBench(machines, face(-12, -66, 0))
	GymKit.InclineBench(machines, face(-5, -66, 0))
	GymKit.FlatBench(machines, face(2, -66, 0))
	GymKit.InclineBench(machines, face(9, -66, 0))
	GymKit.FlatBench(machines, face(16, -66, 0))
	GymKit.mirror(decor, CFrame.lookAt(Vector3.new(2, 4.4, -73.42), Vector3.new(2, 4.4, 0)), 38, 7.4)
	neonSign(decor, CFrame.lookAt(Vector3.new(2, 10.4, -73.35), Vector3.new(2, 10.4, 0)), "GYM ARC", C.Red, 14, 2.6)
	GymKit.floorMat(props, face(2, -66.5), 33, 9, hex("#252527"))

	-- Bodyweight corner (back right): pull-up towers and crunch benches
	GymKit.PullUpBar(machines, face(25.5, -67, 0))
	GymKit.PullUpBar(machines, face(32, -67, 0))
	GymKit.CrunchBench(machines, face(28, -55, YAW.West))
	GymKit.CrunchBench(machines, face(28, -46, YAW.West))
	GymKit.poster(decor, CFrame.lookAt(Vector3.new(29, 6.5, -73.4), Vector3.new(29, 6.5, 0)), "EVERYONE\nSTARTS\nTINY.", 3, 4)

	-- Cardio (east, facing the glass so you can watch the pro gym)
	local cardio = model(props, "Cardio", CFrame.new(27, 0, -29))
	GymKit.treadmill(cardio, face(31.5, -20, YAW.West))
	GymKit.treadmill(cardio, face(31.5, -26, YAW.West))
	GymKit.treadmill(cardio, face(31.5, -32, YAW.West))
	GymKit.bike(cardio, face(24.5, -21, YAW.West))
	GymKit.bike(cardio, face(24.5, -27, YAW.West))
	GymKit.rower(cardio, face(24.5, -35, 0))
	cardio:SetAttribute("Recovery", "Cardio")

	-- Stretching area (middle): mats, foam rollers, kettlebells (a recovery station: stamina refills faster here)
	local stretch = model(props, "StretchingArea", CFrame.new(12, 0, -29))
	p(stretch, "Mat", Vector3.new(12, 0.08, 16), CFrame.new(12, 0.19, -29), hex("#283029"), M.Rubber)
	p(stretch, "MatEdge", Vector3.new(12.3, 0.06, 16.3), CFrame.new(12, 0.18, -29), hex("#151716"), M.Rubber)
	for i, z in ipairs({ -23, -27, -31, -35 }) do
		GymKit.yogaMat(stretch, face(8.5 + (i % 2) * 0.4, z, 90), i % 2 == 0 and hex("#2F3A36") or hex("#3A3530"))
	end
	GymKit.foamRoller(stretch, face(15, -22.5, 10))
	GymKit.foamRoller(stretch, face(15.5, -24.5, -5))
	GymKit.foamRoller(stretch, face(15, -26.5, 0))
	for i = 0, 4 do GymKit.kettlebell(stretch, face(16.5, -31 - i * 1.3), 0.6 + i * 0.1) end
	local ball = p(stretch, "StabilityBall", Vector3.new(2.2, 2.2, 2.2), CFrame.new(14.5, 1.3, -35.5), hex("#4A4C50"), M.SmoothPlastic, true)
	ball.Shape = Enum.PartType.Ball
	stretch:SetAttribute("Recovery", "StretchMat")

	-- walls: posters, speakers, fans
	GymKit.poster(decor, CFrame.lookAt(Vector3.new(-14, 7, -4.1), Vector3.new(-14, 7, -10)), "SHOW UP.\nGET BIG.", 3, 4)
	GymKit.poster(decor, CFrame.lookAt(Vector3.new(24, 7, -4.1), Vector3.new(24, 7, -10)), "REST IS\nPART OF\nTHE PLAN.", 3, 4)
	for _, spot in ipairs({ { -34, -71 }, { 34, -71 }, { -34, -6 }, { 34, -6 } }) do
		GymKit.speaker(decor, CFrame.lookAt(Vector3.new(spot[1], 11, spot[2]), Vector3.new(0, 10, -38)))
	end
	GymKit.wallFan(decor, CFrame.lookAt(Vector3.new(-35.8, 9.5, -8), Vector3.new(0, 9.5, -8)))
	GymKit.wallFan(decor, CFrame.lookAt(Vector3.new(-35.8, 9.5, -72), Vector3.new(0, 9.5, -72)) * CFrame.Angles(0, rad(20), 0))

	-- lights: a warm pendant over every station (every other one casts shadows), fill lights along the walkways
	local lights = Instance.new("Folder")
	lights.Name = "Pendants"
	lights.Parent = room
	local spots = {
		{ -28, -14 }, { -28, -26 }, { -28, -38 }, { -28, -50 }, { -28, -62 },
		{ -16, -17 }, { -16, -30 }, { -16, -44 }, { -16, -57 },
		{ -8.5, -64 }, { 5.5, -64 }, { 16, -64 }, { 28.5, -64 }, { 28, -50 },
		{ 28, -26 }, { 12, -24 }, { 12, -34 }, { 20, -10 }, { -16, -8 }, { 0, -10 },
	}
	for i, spot in ipairs(spots) do
		GymKit.pendant(lights, Vector3.new(spot[1], 9.2, spot[2]), S.Height, i % 2 == 1)
	end
	local fills = Instance.new("Folder")
	fills.Name = "FillLights"
	fills.Parent = room
	for _, x in ipairs({ -24, 0, 24 }) do
		for z = -12, -68, -14 do GymKit.fillLight(fills, Vector3.new(x, 10.5, z), 20, 0.5) end
	end
	return room, machines
end

------------------------------------------------------------------------
-- Pro gym
------------------------------------------------------------------------
local function proShell(room)
	local P = Gyms.Pro
	local cx, cz = (P.MinX + P.MaxX) / 2, (P.MinZ + P.MaxZ) / 2
	local w, d, h = P.MaxX - P.MinX, P.MaxZ - P.MinZ, P.Height
	local shell = Instance.new("Folder")
	shell.Name = "Shell"
	shell.Parent = room
	p(shell, "Slab", Vector3.new(w + 2, 1, d + 2), CFrame.new(cx, -0.45, cz), C.Concrete, M.Concrete, true)
	local floor = p(shell, "Floor", Vector3.new(w, 0.1, d), CFrame.new(cx, 0.1, cz), C.ProFloor, M.SmoothPlastic, true) -- polished concrete look
	floor.Reflectance = 0.03
	for x = P.MinX + 7, P.MaxX - 1, 7 do p(shell, "FloorJoint", Vector3.new(0.05, 0.01, d), CFrame.new(x, 0.155, cz), hex("#0E0E10")) end
	p(shell, "EastWall", Vector3.new(1, h, d + 1), CFrame.new(P.MaxX + 0.5, h / 2, cz), C.ProWall, M.Concrete, true)
	p(shell, "BackWall", Vector3.new(w + 2, h, 1), CFrame.new(cx, h / 2, P.MinZ - 0.5), C.ProWall, M.Concrete, true)
	-- street front: a dark glass curtain wall (x 38..76) with chrome mullions and LED trim, solid where the lockers are
	local glassFrom, glassTo = 38, 76
	p(shell, "FrontWall", Vector3.new(P.MaxX + 1 - glassTo, h, 1), CFrame.new((glassTo + P.MaxX + 1) / 2, h / 2, -3.5), C.ProWall, M.Concrete, true)
	p(shell, "FrontWall", Vector3.new(glassFrom - P.MinX + 1, h, 1), CFrame.new((P.MinX - 1 + glassFrom) / 2, h / 2, -3.5), C.ProWall, M.Concrete, true)
	p(shell, "FrontSpandrel", Vector3.new(glassTo - glassFrom, h - 11, 1), CFrame.new((glassFrom + glassTo) / 2, 11 + (h - 11) / 2, -3.5), C.ProWall, M.Concrete, true)
	p(shell, "FrontBase", Vector3.new(glassTo - glassFrom, 0.8, 1), CFrame.new((glassFrom + glassTo) / 2, 0.4, -3.5), C.ProWall, M.Concrete, true)
	local curtain = p(shell, "CurtainGlass", Vector3.new(glassTo - glassFrom, 10.2, 0.25), CFrame.new((glassFrom + glassTo) / 2, 5.9, -3.5), hex("#1E2A33"), M.Glass, true, { Transparency = 0.35, Reflectance = 0.25 })
	curtain.CastShadow = false
	for x = glassFrom, glassTo, 4 do
		p(shell, "CurtainMullion", Vector3.new(0.3, 10.2, 0.5), CFrame.new(x, 5.9, -3.5), C.Chrome, M.Metal)
	end
	p(shell, "CurtainRail", Vector3.new(glassTo - glassFrom, 0.3, 0.5), CFrame.new((glassFrom + glassTo) / 2, 11, -3.5), C.Chrome, M.Metal)
	p(shell, "CurtainRail", Vector3.new(glassTo - glassFrom, 0.3, 0.5), CFrame.new((glassFrom + glassTo) / 2, 0.8, -3.5), C.Chrome, M.Metal)
	p(shell, "OutsideLed", Vector3.new(P.MaxX - P.MinX + 2, 0.12, 0.12), CFrame.new(cx, h - 0.4, -2.9), C.Led, M.Neon)
	p(shell, "OutsideLed", Vector3.new(P.MaxX - P.MinX + 2, 0.12, 0.12), CFrame.new(cx, 0.35, -2.9), C.Led, M.Neon)
	p(shell, "Ceiling", Vector3.new(w + 2, 1, d + 2), CFrame.new(cx, h + 0.5, cz), hex("#0C0C0E"), M.Concrete, true)
	-- vertical wall panels with LED seams on the east and back walls
	for z = P.MinZ + 7, P.MaxZ - 3, 7 do
		p(shell, "Panel", Vector3.new(0.12, h - 1, 6.7), CFrame.new(P.MaxX - 0.06, h / 2, z - 3.5), hex("#202024"), M.Concrete)
		p(shell, "LedSeam", Vector3.new(0.06, h - 1.5, 0.08), CFrame.new(P.MaxX - 0.1, h / 2, z), C.Led, M.Neon)
	end
	for x = P.MinX + 7, P.MaxX - 3, 7 do
		p(shell, "Panel", Vector3.new(6.7, h - 1, 0.12), CFrame.new(x - 3.5, h / 2, P.MinZ + 0.06), hex("#202024"), M.Concrete)
	end
	-- LED strips along floor and ceiling edges
	for _, y in ipairs({ 0.3, h - 0.6 }) do
		p(shell, "LedStrip", Vector3.new(w, 0.1, 0.1), CFrame.new(cx, y, P.MinZ + 0.15), C.Led, M.Neon)
		p(shell, "LedStrip", Vector3.new(w, 0.1, 0.1), CFrame.new(cx, y, P.MaxZ - 0.15), C.Led, M.Neon)
		p(shell, "LedStrip", Vector3.new(0.1, 0.1, d), CFrame.new(P.MaxX - 0.15, y, cz), C.Led, M.Neon)
	end
	-- ceiling: black grid with linear light bars
	for x = P.MinX + 8, P.MaxX - 4, 8 do
		p(shell, "CeilingRib", Vector3.new(0.4, 0.6, d), CFrame.new(x, h - 0.3, cz), hex("#141416"), M.Metal)
	end
	for z = P.MinZ + 8, P.MaxZ - 4, 10 do
		local bar = p(shell, "LightBar", Vector3.new(w - 6, 0.12, 0.3), CFrame.new(cx, h - 0.66, z), C.Led, M.Neon)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Brightness, light.Range, light.Angle, light.Color, light.Shadows = 0.5, 14, 100, hex("#E6ECFF"), false
		light.Parent = bar
	end
end

local function spotlight(folder, position, shadows)
	local fixture = model(folder, "Spot", CFrame.new(position))
	cyl(fixture, "Can", 0.9, 0.8, CFrame.new(position) * CFrame.Angles(0, 0, rad(90)), hex("#1A1A1C"), M.Metal)
	local lens = cyl(fixture, "Lens", 0.05, 0.6, CFrame.new(position - Vector3.new(0, 0.46, 0)) * CFrame.Angles(0, 0, rad(90)), hex("#EAF0FF"), M.Neon)
	p(fixture, "Stem", Vector3.new(0.12, 0.8, 0.12), CFrame.new(position + Vector3.new(0, 0.8, 0)), hex("#1A1A1C"), M.Metal)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness, light.Range, light.Angle, light.Color, light.Shadows = 4, 20, 55, hex("#EAF0FF"), shadows == true
	-- the lens is turned 90 degrees about Z, so its Left face (-X) is the one pointing down
	light.Face = Enum.NormalId.Left
	light.Parent = lens
	return fixture
end

local function proRoom()
	local P = Gyms.Pro
	local room = Kit.fresh(Workspace, "Model", "ProGym")
	proShell(room)
	local glassWall = Instance.new("Folder")
	glassWall.Name = "GlassWall"
	glassWall.Parent = room
	sharedWall(glassWall)
	local machines = Instance.new("Folder")
	machines.Name = "Machines"
	machines.Parent = room
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = room
	local lights = Instance.new("Folder")
	lights.Name = "Spotlights"
	lights.Parent = room

	-- Heavy free weights right behind the glass, so the starter gym watches the big lifts
	local heavy = {
		{ GymKit.SquatRack, 43.5, -24, YAW.West }, { GymKit.Deadlift, 45, -38, YAW.West },
		{ GymKit.SquatRack, 43.5, -52, YAW.West }, { GymKit.FlatBench, 45, -64, 90 },
	}
	for i, spec in ipairs(heavy) do
		local m = spec[1](machines, face(spec[2], spec[3], spec[4]))
		m:SetAttribute("Pro", true)
		spotlight(lights, Vector3.new(spec[2] - 1, P.Height - 1.4, spec[3]), i % 2 == 1)
	end
	GymKit.plateTree(props, face(48, -31, 20), { { 55, 55 }, { 55, 45 }, { 45, 45 }, { 35, 35 }, { 25, 25 }, { 10, 10 } })
	GymKit.plateTree(props, face(48, -45, -15), { { 55, 55 }, { 55, 45 }, { 45, 45 }, { 35, 35 }, { 25, 25 }, { 10, 10 } })
	GymKit.chalkBowl(props, face(49, -58))

	-- Machine floor: two rows of selectorized machines, facing each other across an aisle
	local rowA = { "LateralRaise", "ReverseFly", "BicepCurl", "TricepPushdown", "CableWoodchop", "Shrugs" }
	local rowB = { "CalfRaise", "LegCurl", "HipThrust", "Dips", "HangingLegRaise" }
	for i, id in ipairs(rowA) do
		local x, z = 58 + (i - 1) * 6.4, -62
		GymKit.Pro[id](machines, face(x, z, 180))
		spotlight(lights, Vector3.new(x, P.Height - 1.4, z + 0.5), i % 3 == 1)
	end
	for i, id in ipairs(rowB) do
		local x, z = 61 + (i - 1) * 6.6, -44
		GymKit.Pro[id](machines, face(x, z, 0))
		spotlight(lights, Vector3.new(x, P.Height - 1.4, z + 0.5), i % 3 == 2)
	end
	GymKit.dumbbellRack(props, face(75, -71.3, 180), 14)
	GymKit.mirror(props, CFrame.lookAt(Vector3.new(75, 4.6, -73.28), Vector3.new(75, 4.6, 0)), 30, 7)

	-- Podium spot (back of the aisle): a round two-step podium under a ring of light, the sign above it
	local podium = model(props, "Podium", CFrame.new(60, 0, -52))
	cyl(podium, "Step1", 0.5, 7, CFrame.new(60, 0.4, -52.5) * CFrame.Angles(0, 0, rad(90)), hex("#202024"), M.Marble, true)
	cyl(podium, "Step2", 0.5, 5, CFrame.new(60, 0.9, -52.5) * CFrame.Angles(0, 0, rad(90)), hex("#2A2A2E"), M.Marble, true)
	cyl(podium, "Rim", 0.06, 5.05, CFrame.new(60, 1.16, -52.5) * CFrame.Angles(0, 0, rad(90)), C.Led, M.Neon)
	cyl(podium, "RimLow", 0.06, 7.05, CFrame.new(60, 0.66, -52.5) * CFrame.Angles(0, 0, rad(90)), C.Led, M.Neon)
	spotlight(lights, Vector3.new(60, P.Height - 1.4, -52.5), true)
	podium:SetAttribute("NpcSpot", "Pose")

	-- Signs: GYM ARC PRO on the east wall (seen through the glass) and over the machine rows
	neonSign(props, CFrame.lookAt(Vector3.new(P.MaxX - 0.3, 9.5, -38), Vector3.new(0, 9.5, -38)), "GYM ARC PRO", C.Led, 20, 3.2)
	neonSign(props, CFrame.lookAt(Vector3.new(70, 11, -73.3), Vector3.new(70, 11, 0)), "PRO", C.Red, 7, 2.2)

	-- Cardio (front, facing the windows of the east wall)
	local cardio = model(props, "Cardio", CFrame.new(70, 0, -12))
	for i = 0, 3 do GymKit.treadmill(cardio, face(56 + i * 4.5, -10, 180), true) end
	GymKit.bike(cardio, face(76, -10, 180))
	GymKit.rower(cardio, face(80.5, -11, 180))
	cardio:SetAttribute("Recovery", "Cardio")
	-- Locker area (front right corner): lockers, benches, towels, a mirror
	GymKit.lockers(props, face(91.9, -16, YAW.East), 7)
	GymKit.lockers(props, face(84, -4.9, 0), 4)
	GymKit.bench(props, face(85, -15, 90), 5)
	GymKit.bench(props, face(85, -21.5, 90), 5)
	GymKit.towelRack(props, face(90.5, -27, YAW.West))
	GymKit.mirror(props, CFrame.lookAt(Vector3.new(92.78, 4.6, -32), Vector3.new(0, 4.6, -32)), 4, 6.5)
	GymKit.waterFountain(props, face(52, -4.8, 0))
	GymKit.plant(props, face(91, -70.5), 5)
	GymKit.plant(props, face(40, -71), 5)
	-- Stretching (back right)
	local stretch = model(props, "StretchingArea", CFrame.new(86, 0, -60))
	p(stretch, "Mat", Vector3.new(11, 0.08, 18), CFrame.new(86.5, 0.19, -58), hex("#1F2421"), M.Rubber)
	for i, z in ipairs({ -52, -56, -60, -64 }) do GymKit.yogaMat(stretch, face(84 + (i % 2) * 0.4, z, 90), hex("#2A2F33")) end
	GymKit.foamRoller(stretch, face(90, -54, 0))
	GymKit.foamRoller(stretch, face(90, -56, 10))
	stretch:SetAttribute("Recovery", "StretchMat")
	-- speakers
	for _, spot in ipairs({ { 39, -71 }, { 91, -71 }, { 91, -6 } }) do
		GymKit.speaker(props, CFrame.lookAt(Vector3.new(spot[1], 11.5, spot[2]), Vector3.new(65, 10, -38)))
	end
	-- soft fill so nothing is pitch black between the pools
	for _, x in ipairs({ 48, 65, 82 }) do
		for z = -12, -68, -18 do GymKit.fillLight(lights, Vector3.new(x, 11, z), 22, 0.35, hex("#DDE6FF")) end
	end
	return room, machines
end

------------------------------------------------------------------------
-- NPC spots
------------------------------------------------------------------------
local function npcSpots(gym)
	local folder = Kit.fresh(gym, "Folder", "NpcSpots")
	local function spot(name, kind, position, gymName)
		local part = p(folder, name, Vector3.new(1, 0.2, 1), CFrame.new(position), C.Steel, M.SmoothPlastic, false, { Transparency = 1 })
		part:SetAttribute("Kind", kind)
		part:SetAttribute("Gym", gymName)
	end
	spot("Water", "Water", Vector3.new(-14, 0.2, -7.5), "Starter")
	spot("Water", "Water", Vector3.new(52, 0.2, -7.5), "Pro")
	spot("Chat", "Chat", Vector3.new(4, 0.2, -18), "Starter")
	spot("Chat", "Chat", Vector3.new(-6, 0.2, -50), "Starter")
	spot("Chat", "Chat", Vector3.new(68, 0.2, -30), "Pro")
	spot("Chat", "Chat", Vector3.new(80, 0.2, -38), "Pro")
	spot("Rest", "Rest", Vector3.new(-24, 0.2, -8), "Starter")
	spot("Rest", "Rest", Vector3.new(85, 0.2, -18), "Pro")
	spot("Pose", "Pose", Vector3.new(60, 1.3, -52.5), "Pro")
	return folder
end

function Gyms.Build()
	local gym = Workspace:FindFirstChild("Gym")
	-- keep the entrance hall: move it out of the old StarterGym folder before replacing that
	local oldRoom = gym:FindFirstChild("StarterGym")
	if oldRoom and oldRoom:FindFirstChild("Entrance") then oldRoom.Entrance.Parent = gym end
	starterRoom(gym)
	proRoom()
	npcSpots(gym)
	local old = Workspace:FindFirstChild("ProGymBuild")
	if old then old:Destroy() end
end

return Gyms
