-- GeneticsSet builder (run once in Studio; see tools/bake.md): the dim gym around the genetics stage, built from simple
-- parts. Output: ReplicatedStorage.GeneticsSet (GeneticsClient clones its pieces onto the client-only stage):
--   Room       the gym behind the scene: rubber floor tiles with faint seams, a dark brick back wall with a baseboard,
--              a squat rack, a dumbbell rack and plates leaning on the wall. Pivot = the stage floor point (the
--              platform's top), so GeneticsClient puts it at STAGE_CF * (0, FLOOR_Y, 0).
--   Platform   a wooden olympic lifting platform (light wood centre, black rubber sides, steel edge trim). Pivot = the
--              platform top under the bar's x = 0, X along the bar.
--   HookGrip / HookSleeve   black J-hook stands, pivot = the bar axis they hold (X along the bar). The bar axis is
--              BAR_HEIGHT above the platform top.
--   PlateTree  a short black plate tree for the overall plate: pivot = the plate's centre, X = the plate's axis (its
--              front face), built for a 4-stud plate (GeneticsClient scales it to the plate). Feet are named "Foot".
-- Numbers that must match GeneticsClient: BAR_HEIGHT (= -FLOOR_Y: the S plate's radius + 0.04), the bar radii.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneticsSet = {}

local BAR_HEIGHT = 1.54          -- the bar axis above the platform top
local GROUND = -0.12             -- the gym floor's top (the platform sits on it, its top at 0)
local GRIP_R, SLEEVE_R = 0.19, 0.36
local WALL = 30                  -- the back wall's face, behind the stage (far enough to sit soft in the depth of field)
local HERO_D, HERO_T, HERO_HOLE = 4, 1.1, 0.66

local BLACK = Color3.fromHex("#17171A")
local RUBBER = Color3.fromHex("#1D1D20")
local SEAM = Color3.fromHex("#0F0F11")

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
local function cylinder(parent, name, length, diameter, cf, color, material)
	return part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- a bumper plate seen from far away (blurred): body + a lighter hub
local function farPlate(parent, cf, diameter, color)
	cylinder(parent, "Plate", 0.3, diameter, cf, color, Enum.Material.Rubber)
	cylinder(parent, "Hub", 0.34, diameter * 0.2, cf, Color3.fromHex("#9A9CA2"), Enum.Material.Metal)
end

local function buildRoom(set)
	local room = model(set, "Room")
	-- rubber tiles (6 studs) with faint seams
	part(room, "Ground", Vector3.new(90, 0.5, 64), CFrame.new(0, GROUND - 0.25, 0), RUBBER, Enum.Material.Rubber)
	for z = -30, 30, 6 do
		part(room, "Seam", Vector3.new(90, 0.01, 0.06), CFrame.new(0, GROUND + 0.005, z), SEAM, Enum.Material.Rubber)
	end
	for x = -42, 42, 6 do
		part(room, "Seam", Vector3.new(0.06, 0.01, 64), CFrame.new(x, GROUND + 0.005, 0), SEAM, Enum.Material.Rubber)
	end
	-- the back wall: dark brick, a black rubber baseboard and a thin steel rail at waist height
	part(room, "Wall", Vector3.new(90, 26, 1), CFrame.new(0, GROUND + 13, -WALL - 0.5), Color3.fromHex("#1E1714"), Enum.Material.Brick)
	part(room, "Baseboard", Vector3.new(90, 0.6, 0.12), CFrame.new(0, GROUND + 0.3, -WALL + 0.06), BLACK, Enum.Material.Rubber)
	part(room, "Rail", Vector3.new(90, 0.12, 0.1), CFrame.new(0, GROUND + 3.4, -WALL + 0.05), Color3.fromHex("#3A3C42"), Enum.Material.Metal)

	-- squat rack (left, against the wall) with a loaded bar on its hooks
	local rack = model(room, "SquatRack")
	local rx, rz = -2, -WALL + 3.1
	for _, x in ipairs({ -2.3, 2.3 }) do
		for _, z in ipairs({ -1.3, 1.3 }) do
			part(rack, "Upright", Vector3.new(0.3, 9, 0.3), CFrame.new(rx + x, GROUND + 4.5, rz + z), BLACK, Enum.Material.Metal)
		end
		part(rack, "Foot", Vector3.new(0.4, 0.2, 3.4), CFrame.new(rx + x, GROUND + 0.1, rz), BLACK, Enum.Material.Metal)
		part(rack, "TopSide", Vector3.new(0.3, 0.3, 2.9), CFrame.new(rx + x, GROUND + 9, rz), BLACK, Enum.Material.Metal)
		part(rack, "Safety", Vector3.new(0.18, 0.18, 2.8), CFrame.new(rx + x * 0.94, GROUND + 3, rz + 0.3), Color3.fromHex("#5A5C62"), Enum.Material.Metal)
		part(rack, "Hook", Vector3.new(0.22, 0.35, 0.4), CFrame.new(rx + x * 0.94, GROUND + 4.5, rz + 1.45), BLACK, Enum.Material.Metal)
	end
	for _, z in ipairs({ -1.3, 1.3 }) do
		part(rack, "TopCross", Vector3.new(4.9, 0.3, 0.3), CFrame.new(rx, GROUND + 9, rz + z), BLACK, Enum.Material.Metal)
	end
	cylinder(rack, "PullUpBar", 4.9, 0.14, CFrame.new(rx, GROUND + 8.6, rz + 1.6), Color3.fromHex("#8E9096"), Enum.Material.Metal)
	cylinder(rack, "Bar", 8.4, 0.14, CFrame.new(rx, GROUND + 4.75, rz + 1.45), Color3.fromHex("#9A9CA2"), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		farPlate(rack, CFrame.new(rx + side * 3.0, GROUND + 4.75, rz + 1.45), 3, Color3.fromHex("#1F3F78"))
		farPlate(rack, CFrame.new(rx + side * 3.35, GROUND + 4.75, rz + 1.45), 2.4, Color3.fromHex("#8A7420"))
	end

	-- dumbbell rack (right): two angled tiers of pairs on end frames
	local dumbbells = model(room, "DumbbellRack")
	local dx, dz = 15, -WALL + 2.3
	for _, x in ipairs({ -3.2, 3.2 }) do
		part(dumbbells, "End", Vector3.new(0.25, 2.6, 1.7), CFrame.new(dx + x, GROUND + 1.3, dz), BLACK, Enum.Material.Metal)
	end
	for tier, spec in ipairs({ { y = 1.2, z = 0.45 }, { y = 2.25, z = -0.35 } }) do
		part(dumbbells, "Shelf", Vector3.new(6.2, 0.12, 0.7), CFrame.new(dx, GROUND + spec.y, dz + spec.z) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromHex("#2A2B30"), Enum.Material.Metal)
		for i = 1, 5 do
			local x = dx - 2.6 + (i - 1) * 1.3
			local head = 0.42 + (tier == 1 and (i - 1) * 0.05 or i * 0.03)
			local y = GROUND + spec.y + 0.06 + head / 2
			cylinder(dumbbells, "Handle", 0.9, 0.1, CFrame.new(x, y, dz + spec.z), Color3.fromHex("#8E9096"), Enum.Material.Metal)
			for _, s in ipairs({ -1, 1 }) do
				cylinder(dumbbells, "Head", 0.24, head, CFrame.new(x + s * 0.4, y, dz + spec.z), Color3.fromHex("#202124"), Enum.Material.Rubber)
			end
		end
	end

	-- plates leaning on the wall, between the racks
	local leaning = model(room, "WallPlates")
	for _, spec in ipairs({ { x = -7.6, d = 3, color = "#202124" }, { x = -7.35, d = 3, color = "#7A2228", dz = 0.34 }, { x = 5.5, d = 2.4, color = "#202124" } }) do
		-- face to the room, the top tipped 10 degrees back onto the wall
		local tilt = math.rad(10)
		local cf = CFrame.new(spec.x, GROUND + spec.d / 2 * math.cos(tilt), -WALL + 0.4 + (spec.dz or 0) + spec.d / 2 * math.sin(tilt))
			* CFrame.Angles(-tilt, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		farPlate(leaning, cf, spec.d, Color3.fromHex(spec.color))
	end
	room.WorldPivot = CFrame.new()
end

local function buildPlatform(set)
	local platform = model(set, "Platform")
	local T = -GROUND -- thickness: from the gym floor up to the platform top (0)
	local x0, x1, z0, z1 = -6.5, 9.5, -5, 5
	local woodA, woodB = -3.5, 0.5 -- the wood centre between the rubber sides
	local function slab(name, xa, xb, color, material)
		part(platform, name, Vector3.new(xb - xa, T, z1 - z0 - 0.3), CFrame.new((xa + xb) / 2, -T / 2, 0), color, material)
	end
	slab("RubberLeft", x0 + 0.15, woodA, RUBBER, Enum.Material.Rubber)
	slab("RubberRight", woodB, x1 - 0.15, RUBBER, Enum.Material.Rubber)
	local tones = { "#C99B62", "#BE8F57", "#C6965C", "#B98A52" }
	local plank = (woodB - woodA) / #tones
	for i, tone in ipairs(tones) do
		slab("Wood", woodA + (i - 1) * plank, woodA + i * plank, Color3.fromHex(tone), Enum.Material.Wood)
	end
	-- the steel edge frame
	local trim = Color3.fromHex("#2B2C30")
	part(platform, "Trim", Vector3.new(x1 - x0, T + 0.01, 0.15), CFrame.new((x0 + x1) / 2, -T / 2 + 0.005, z0 + 0.075), trim, Enum.Material.Metal)
	part(platform, "Trim", Vector3.new(x1 - x0, T + 0.01, 0.15), CFrame.new((x0 + x1) / 2, -T / 2 + 0.005, z1 - 0.075), trim, Enum.Material.Metal)
	part(platform, "Trim", Vector3.new(0.15, T + 0.01, z1 - z0 - 0.3), CFrame.new(x0 + 0.075, -T / 2 + 0.005, 0), trim, Enum.Material.Metal)
	part(platform, "Trim", Vector3.new(0.15, T + 0.01, z1 - z0 - 0.3), CFrame.new(x1 - 0.075, -T / 2 + 0.005, 0), trim, Enum.Material.Metal)
	platform.WorldPivot = CFrame.new()
end

-- a J-hook stand under the bar (in the bar's YZ plane; +Z = toward the camera, so the tall back is away from it)
local function buildHook(set, name, r)
	local hook = model(set, name)
	local h = BAR_HEIGHT
	part(hook, "Base", Vector3.new(0.7, 0.06, 1.1), CFrame.new(0, -h + 0.03, 0), BLACK, Enum.Material.Metal)
	part(hook, "Pad", Vector3.new(0.5, 0.03, 0.8), CFrame.new(0, -h + 0.075, 0), RUBBER, Enum.Material.Rubber)
	local top = -r - 0.08
	part(hook, "Upright", Vector3.new(0.22, top - (-h + 0.09), 0.22), CFrame.new(0, (top + (-h + 0.09)) / 2, 0), BLACK, Enum.Material.Metal)
	part(hook, "Saddle", Vector3.new(0.26, 0.08, 2 * r + 0.2), CFrame.new(0, -r - 0.04, 0), BLACK, Enum.Material.Metal)
	part(hook, "Back", Vector3.new(0.26, r + 0.42, 0.08), CFrame.new(0, (-r - 0.08 + 0.34) / 2, -(r + 0.06)), BLACK, Enum.Material.Metal)
	part(hook, "Lip", Vector3.new(0.26, r * 0.7 + 0.08, 0.08), CFrame.new(0, -r - 0.08 + (r * 0.7 + 0.08) / 2, r + 0.06), BLACK, Enum.Material.Metal)
	hook.WorldPivot = CFrame.new()
end

local function buildTree(set)
	local tree = model(set, "PlateTree")
	local floor = -HERO_D / 2 + GROUND
	local postX = -(HERO_T / 2 + 0.35)
	local postTop = 0.5
	part(tree, "Foot", Vector3.new(0.3, 0.16, 2.8), CFrame.new(postX, floor + 0.08, 0), BLACK, Enum.Material.Metal)
	for _, z in ipairs({ -1.25, 1.25 }) do
		part(tree, "Foot", Vector3.new(2.6, 0.16, 0.26), CFrame.new(postX + 0.25, floor + 0.08, z), BLACK, Enum.Material.Metal) -- (reaching out under the plate, so it shows)
	end
	part(tree, "Post", Vector3.new(0.36, postTop - floor - 0.16, 0.36), CFrame.new(postX, (postTop + floor + 0.16) / 2, 0), BLACK, Enum.Material.Metal)
	part(tree, "Cap", Vector3.new(0.42, 0.06, 0.42), CFrame.new(postX, postTop + 0.03, 0), Color3.fromHex("#2B2C30"), Enum.Material.Metal)
	local hornEnd = HERO_T / 2 + 0.22
	cylinder(tree, "Horn", hornEnd - postX, HERO_HOLE * 0.76, CFrame.new((postX + hornEnd) / 2, 0, 0), BLACK, Enum.Material.Metal)
	cylinder(tree, "HornTip", 0.07, HERO_HOLE * 0.86, CFrame.new(hornEnd, 0, 0), Color3.fromHex("#8E9096"), Enum.Material.Metal)
	tree.WorldPivot = CFrame.new()
end

function GeneticsSet.Build()
	local old = ReplicatedStorage:FindFirstChild("GeneticsSet")
	if old then old:Destroy() end
	local set = Instance.new("Folder")
	set.Name = "GeneticsSet"
	buildRoom(set)
	buildPlatform(set)
	buildHook(set, "HookGrip", GRIP_R)
	buildHook(set, "HookSleeve", SLEEVE_R)
	buildTree(set)
	set.Parent = ReplicatedStorage
	local count = 0
	for _, item in ipairs(set:GetDescendants()) do
		if item:IsA("BasePart") then count += 1 end
	end
	return "GeneticsSet: " .. count .. " parts"
end

return GeneticsSet
