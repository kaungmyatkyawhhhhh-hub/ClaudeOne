-- Decor builder (run once in Studio; see tools/bake.md): extra decorations, each area's in its own "Decor" folder so it can
-- be deleted in one go. Simple parts, no logos or brands, nothing gameplay uses (no prompts, no collisions on small props).
--   StarterGym.Decor: lockers by the door, a whiteboard with a workout plan, a sign-in clipboard on the front desk
--   ProGym.Decor:     two wall TVs with simple gym graphics, a smoothie counter, a wood lifting platform with a bar
--   Town.Plaza.Decor: a fountain on the plaza's compass rings
-- Needs Kit next to it. Running it again replaces what it built.
local Kit = require(script.Parent.Kit)

local Decor = {}

local hex = Kit.hex
local M = Enum.Material

local function folder(parent)
	local old = parent:FindFirstChild("Decor")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "Decor"
	f.Parent = parent
	return f
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- a decorative part: anchored, no collisions / shadows / touch / queries
local function prop(parent, name, size, cframe, color, material, shape)
	local p = Kit.prop(parent, name, size, cframe, color, material)
	if shape then p.Shape = shape end
	return p
end

-- lines of text on a part's front face (-Z)
local function writing(part, lines, textColor, font, pps)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 60
	gui.LightInfluence = 1
	gui.Parent = part
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.Padding = UDim.new(0, 4)
	list.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop = UDim.new(0.06, 0), UDim.new(0.08, 0)
	pad.Parent = gui
	for i, line in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0.9, 0, 0, if i == 1 then 34 else 24)
		label.Text = line
		label.TextColor3 = textColor
		label.FontFace = font or Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
		label.TextScaled = true -- (world-space text on a board)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = gui
	end
	return gui
end

------------------------------------------------------------------------
-- Starter gym
------------------------------------------------------------------------
function Decor.Starter(gym)
	local decor = folder(gym)
	-- a rolling whiteboard with a workout plan (free floor left of the centre aisle, facing the aisle); on legs with wheels
	local board = model(decor, "Whiteboard")
	local stand = CFrame.lookAt(Vector3.new(-9, 0, -18), Vector3.new(0, 0, -18))
	local at = stand * CFrame.new(0, 4.6, 0)
	for _, x in ipairs({ -2.3, 2.3 }) do
		prop(board, "Leg", Vector3.new(0.12, 4.4, 0.12), stand * CFrame.new(x, 2.4, 0), hex("#B9BCC2"), M.Metal)
		prop(board, "Foot", Vector3.new(0.12, 0.12, 1.4), stand * CFrame.new(x, 0.3, 0), hex("#B9BCC2"), M.Metal)
		for _, z in ipairs({ -0.6, 0.6 }) do
			prop(board, "Wheel", Vector3.new(0.12, 0.24, 0.24), stand * CFrame.new(x, 0.12, z), hex("#1E1E22"), M.Rubber, Enum.PartType.Cylinder)
		end
	end
	prop(board, "Frame", Vector3.new(4.4, 3.0, 0.12), at, hex("#B9BCC2"), M.Metal)
	local face = prop(board, "Board", Vector3.new(4.2, 2.8, 0.06), at * CFrame.new(0, 0, -0.07), hex("#F4F4F2"), M.SmoothPlastic)
	writing(face, { "TODAY'S WORKOUT", "Bench 5 x 5", "Squat 5 x 5", "Rows 3 x 10", "Plank 3 x 45 s", "Drink water!" }, hex("#1F3B73"))
	prop(board, "Tray", Vector3.new(3.6, 0.08, 0.25), at * CFrame.new(0, -1.55, -0.14), hex("#B9BCC2"), M.Metal)
	for i, color in ipairs({ "#1F5FBF", "#D7262E", "#2E9E4F" }) do
		prop(board, "Marker", Vector3.new(0.5, 0.08, 0.08), at * CFrame.new(-1 + i * 0.6, -1.47, -0.18), hex(color), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	-- lockers by the door (front wall, left of the door): three tall lockers with vents, handles and number plates
	local lockers = model(decor, "Lockers")
	local base = CFrame.lookAt(Vector3.new(-11, 0, -4.7), Vector3.new(-11, 0, -10))
	prop(lockers, "Plinth", Vector3.new(2.7, 0.3, 1.1), base * CFrame.new(0, 0.15, 0), hex("#1E1E22"), M.Metal)
	for i = -1, 1 do
		local x = i * 0.88
		prop(lockers, "Body", Vector3.new(0.86, 5.4, 1.0), base * CFrame.new(x, 3.0, 0), hex("#3E5A73"), M.Metal)
		local door = base * CFrame.new(x, 3.0, -0.51)
		prop(lockers, "Door", Vector3.new(0.78, 5.2, 0.04), door, hex("#4C6E8C"), M.Metal)
		for v = 0, 3 do prop(lockers, "Vent", Vector3.new(0.5, 0.04, 0.02), door * CFrame.new(0, 2.2 - v * 0.14, -0.03), hex("#2B3F52"), M.Metal) end
		prop(lockers, "Handle", Vector3.new(0.06, 0.4, 0.06), door * CFrame.new(0.28, 0, -0.06), hex("#C9CCD2"), M.Metal)
		local plate = prop(lockers, "Number", Vector3.new(0.3, 0.18, 0.02), door * CFrame.new(0, 1.6, -0.04), hex("#E9E6DD"), M.SmoothPlastic)
		writing(plate, { tostring(i + 2) }, hex("#26262A"), Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold), 120)
	end
	prop(lockers, "Top", Vector3.new(2.75, 0.12, 1.1), base * CFrame.new(0, 5.75, 0), hex("#2B3F52"), M.Metal)
	-- sign-in clipboard on the front desk, with a pen
	local clip = model(decor, "SignIn")
	local deskTop = CFrame.new(18.2, 5.08, -10.6) * CFrame.Angles(0, math.rad(12), 0)
	prop(clip, "Clipboard", Vector3.new(0.9, 0.04, 1.2), deskTop, hex("#8A6A45"), M.Wood)
	local paper = prop(clip, "Paper", Vector3.new(0.78, 0.01, 1.0), deskTop * CFrame.new(0, 0.025, 0.05), hex("#FAFAF7"), M.SmoothPlastic)
	paper.CFrame = paper.CFrame * CFrame.Angles(math.rad(-90), 0, 0) -- (text on the top face)
	writing(paper, { "SIGN IN", "____________", "____________", "____________" }, hex("#3A3A40"), Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold), 200)
	prop(clip, "ClipBar", Vector3.new(0.4, 0.06, 0.08), deskTop * CFrame.new(0, 0.05, -0.55), hex("#C9CCD2"), M.Metal)
	prop(clip, "Pen", Vector3.new(0.6, 0.05, 0.05), deskTop * CFrame.new(0.6, 0.03, 0.1) * CFrame.Angles(0, math.rad(30), 0), hex("#1F5FBF"), M.SmoothPlastic, Enum.PartType.Cylinder)
	return decor
end

------------------------------------------------------------------------
-- Pro gym
------------------------------------------------------------------------
-- a wall TV with a simple gym graphic (a title and three bars), facing `toward`
local function tv(parent, position, toward, title)
	local m = model(parent, "WallTV")
	local at = CFrame.lookAt(position, toward)
	prop(m, "Bracket", Vector3.new(0.6, 0.6, 0.3), at * CFrame.new(0, 0, 0.2), hex("#26262A"), M.Metal)
	prop(m, "Bezel", Vector3.new(4.2, 2.5, 0.16), at, hex("#121214"), M.SmoothPlastic)
	local screen = prop(m, "Screen", Vector3.new(4.0, 2.3, 0.04), at * CFrame.new(0, 0, -0.09), hex("#0E1A26"), M.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = screen
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = hex("#0E1A26")
	bg.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position, label.Size = UDim2.fromScale(0.06, 0.06), UDim2.fromScale(0.88, 0.22)
	label.Text = title
	label.TextColor3 = hex("#F4F4F2")
	label.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = bg
	for i, spec in ipairs({ { 0.75, "#2E9E4F" }, { 0.5, "#E8C21C" }, { 0.9, "#D7262E" } }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0.1 + (i - 1) * 0.28, 0.9)
		bar.Size = UDim2.fromScale(0.18, 0.55 * spec[1])
		bar.BackgroundColor3 = hex(spec[2])
		bar.BorderSizePixel = 0
		bar.Parent = bg
	end
	return m
end

function Decor.Pro(gym)
	local decor = folder(gym)
	-- two TVs on the east wall, facing into the room (-X)
	tv(decor, Vector3.new(92.75, 8, -52), Vector3.new(80, 8, -52), "LEG DAY")
	tv(decor, Vector3.new(92.75, 8, -24), Vector3.new(80, 8, -24), "PUSH  PULL  LEGS")
	-- smoothie counter by the front wall: a wood-fronted counter with a stone top, two blenders, cups and a menu board
	local bar = model(decor, "SmoothieCounter")
	local base = CFrame.lookAt(Vector3.new(78.5, 0, -5.3), Vector3.new(78.5, 0, -10))
	prop(bar, "Body", Vector3.new(5, 3.2, 1.3), base * CFrame.new(0, 1.6, 0), hex("#2A2B2E"), M.SmoothPlastic)
	for i = -2, 2 do prop(bar, "Slat", Vector3.new(0.8, 2.8, 0.06), base * CFrame.new(i * 0.95, 1.6, -0.68), hex("#7A5236"), M.Wood) end
	prop(bar, "Top", Vector3.new(5.3, 0.16, 1.5), base * CFrame.new(0, 3.28, 0), hex("#D9D6CF"), M.Marble)
	prop(bar, "Kick", Vector3.new(5, 0.25, 1.2), base * CFrame.new(0, 0.12, 0.05), hex("#141416"), M.Rubber)
	for _, x in ipairs({ -1.6, -0.6 }) do
		prop(bar, "BlenderBase", Vector3.new(0.45, 0.35, 0.45), base * CFrame.new(x, 3.53, 0.2), hex("#1E1E22"), M.SmoothPlastic)
		prop(bar, "BlenderJar", Vector3.new(0.7, 0.4, 0.4), base * CFrame.new(x, 4.05, 0.2) * CFrame.Angles(0, 0, math.rad(90)), hex("#BFD6DF"), M.Glass, Enum.PartType.Cylinder).Transparency = 0.35
	end
	for i, color in ipairs({ "#E86FA3", "#F2C14E", "#7CC6A5" }) do
		prop(bar, "Cup", Vector3.new(0.45, 0.24, 0.24), base * CFrame.new(0.6 + i * 0.45, 3.58, -0.2) * CFrame.Angles(0, 0, math.rad(90)), hex(color), M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local menu = prop(bar, "Menu", Vector3.new(3.2, 1.6, 0.08), CFrame.lookAt(Vector3.new(78.5, 6.6, -4.08), Vector3.new(78.5, 6.6, -10)), hex("#1E1E22"), M.SmoothPlastic)
	writing(menu, { "SMOOTHIES", "Berry blast", "Mango sunrise", "Green power" }, hex("#F4F4F2"), Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold), 60)
	-- a wood lifting platform (wood centre, black rubber sides, steel edge) with a loaded bar resting on it
	local platform = model(decor, "Platform")
	local mid = CFrame.new(60, 0.15, -28)
	prop(platform, "Rubber", Vector3.new(8, 0.1, 6), mid * CFrame.new(0, 0.05, 0), hex("#1A1A1C"), M.Rubber)
	prop(platform, "Wood", Vector3.new(3.4, 0.11, 5.9), mid * CFrame.new(0, 0.055, 0), hex("#B98A52"), M.Wood)
	for _, z in ipairs({ -3.02, 3.02 }) do prop(platform, "Trim", Vector3.new(8.04, 0.12, 0.05), mid * CFrame.new(0, 0.06, z), hex("#8E9096"), M.Metal) end
	for _, x in ipairs({ -4.02, 4.02 }) do prop(platform, "Trim", Vector3.new(0.05, 0.12, 6.04), mid * CFrame.new(x, 0.06, 0), hex("#8E9096"), M.Metal) end
	prop(platform, "Bar", Vector3.new(7.2, 0.12, 0.12), mid * CFrame.new(0, 1.25, 0.6), hex("#C9CCD2"), M.Metal, Enum.PartType.Cylinder)
	for _, x in ipairs({ -2.9, 2.9 }) do
		prop(platform, "Plate", Vector3.new(0.2, 2.3, 2.3), mid * CFrame.new(x, 1.25, 0.6), hex("#1F5FBF"), M.Rubber, Enum.PartType.Cylinder)
		prop(platform, "Hub", Vector3.new(0.22, 0.5, 0.5), mid * CFrame.new(x, 1.25, 0.6), hex("#C9CCD2"), M.Metal, Enum.PartType.Cylinder)
	end
	return decor
end

------------------------------------------------------------------------
-- Town plaza
------------------------------------------------------------------------
function Decor.Plaza(plaza)
	local decor = folder(plaza)
	local fountain = model(decor, "Fountain")
	local center = CFrame.new(0, 0.2, 60)
	local radius, sides = 4.2, 12
	local stone, light = hex("#CFC8BB"), hex("#E2DCD0")
	-- the basin: a ring of wall segments with a cap, a water disc inside
	for i = 1, sides do
		local a = (i / sides) * math.pi * 2
		local seg = 2 * radius * math.tan(math.pi / sides) + 0.05
		local at = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		prop(fountain, "BasinWall", Vector3.new(seg, 1.4, 0.6), at * CFrame.new(0, 0.7, 0), stone, M.Concrete)
		prop(fountain, "BasinCap", Vector3.new(seg + 0.1, 0.18, 0.8), at * CFrame.new(0, 1.49, 0), light, M.Marble)
	end
	prop(fountain, "BasinFloor", Vector3.new(0.3, radius * 2, radius * 2), center * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), hex("#7F8C8D"), M.Concrete, Enum.PartType.Cylinder)
	local water = prop(fountain, "Water", Vector3.new(0.1, radius * 2 - 0.6, radius * 2 - 0.6), center * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), hex("#4FB6D8"), M.Glass, Enum.PartType.Cylinder)
	water.Transparency = 0.25
	-- the centre: a pedestal, a bowl, a small top and its water
	prop(fountain, "Pedestal", Vector3.new(2.6, 0.9, 0.9), center * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), stone, M.Concrete, Enum.PartType.Cylinder)
	prop(fountain, "Bowl", Vector3.new(0.4, 3.0, 3.0), center * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)), light, M.Marble, Enum.PartType.Cylinder)
	local top = prop(fountain, "BowlWater", Vector3.new(0.06, 2.6, 2.6), center * CFrame.new(0, 3.42, 0) * CFrame.Angles(0, 0, math.rad(90)), hex("#4FB6D8"), M.Glass, Enum.PartType.Cylinder)
	top.Transparency = 0.25
	prop(fountain, "Finial", Vector3.new(0.6, 0.6, 0.6), center * CFrame.new(0, 3.75, 0), light, M.Marble, Enum.PartType.Ball)
	-- the basin wall is solid (players walk around it, not through it)
	for _, p in ipairs(fountain:GetChildren()) do
		if p.Name == "BasinWall" then p.CanCollide = true end
	end
	return decor
end

function Decor.Build(Workspace)
	Decor.Starter(Workspace.Gym.StarterGym)
	Decor.Pro(Workspace.ProGym)
	Decor.Plaza(Workspace.Town.Plaza)
	return "decor built"
end

return Decor
