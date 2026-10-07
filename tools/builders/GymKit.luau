-- GymKit: equipment and props for the gym builders (StarterGym, ProGym). NOT part of the game: builders run once in
-- Studio (tools/bake.md). Every piece is several parts with real detail (frames, pads, trims, feet, bolts), and the
-- same templates are reused everywhere. Plates are clones of ReplicatedStorage.GymAssets.Plates (GymAssets builder).
-- Conventions: a pivot sits on the floor (y = 0); machines face local +Z (the lifter looks toward +Z).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Machines = require(ReplicatedStorage.Shared.Config.Machines)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local GymKit = {}

local hex = Kit.hex
local rad = math.rad

GymKit.C = {
	Brick = hex("#703A2C"), Floor = hex("#2B2B2B"), Frame = hex("#242429"), Chrome = hex("#D6D8DE"),
	Steel = hex("#96969B"), Pad = hex("#221E1E"), Wood = hex("#765236"), Rubber = hex("#202022"),
	Uhmw = hex("#E8E6DF"), Warm = hex("#FFC98A"), Bulb = hex("#FFD9A8"), Dark = hex("#1C1C1E"),
	Chalk = hex("#F2F0EA"), Concrete = hex("#3A3A3D"), ProWall = hex("#1B1B1E"), ProFloor = hex("#18181A"),
	Glass = hex("#BFD6DF"), Led = hex("#DCE6FF"), Red = hex("#D7262E"), Screen = hex("#0E1114"),
}
local C = GymKit.C
local M = Enum.Material

-- p: a part. solid = collides (frames people bump into); otherwise a no-collide, no-shadow prop.
local function p(parent, name, size, cframe, color, material, solid, props)
	local part = (solid and Kit.part or Kit.prop)(parent, name, size, cframe, color, material or M.SmoothPlastic, props)
	if solid then part.CastShadow = true end
	return part
end
GymKit.p = p

local function cyl(parent, name, length, diameter, cframe, color, material, solid)
	local part = p(parent, name, Vector3.new(length, diameter, diameter), cframe, color, material, solid)
	part.Shape = Enum.PartType.Cylinder
	return part
end
GymKit.cyl = cyl

local function ball(parent, name, d, cframe, color, material)
	local part = p(parent, name, Vector3.new(d, d, d), cframe, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function model(parent, name, pivot)
	local m = Instance.new("Model")
	m.Name = name
	m.WorldPivot = pivot
	m.Parent = parent
	return m
end
GymKit.model = model

local function at(pivot, x, y, z, rx, ry, rz)
	return pivot * CFrame.new(x, y, z) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end
GymKit.at = at

-- A plate standing on its edge (axis along `axisCFrame`'s X), label facing outward on `labelSide` (1 = +X, -1 = -X).
function GymKit.plate(parent, weight, axisCFrame, labelSide)
	local template = ReplicatedStorage:FindFirstChild("GymAssets") and ReplicatedStorage.GymAssets.Plates:FindFirstChild("Plate" .. weight)
	if not template then return nil end
	local plate = template:Clone()
	plate:PivotTo(axisCFrame)
	if labelSide then
		local face = plate:FindFirstChild(labelSide > 0 and "FaceRight" or "FaceLeft")
		local gui = face and face:FindFirstChildWhichIsA("SurfaceGui")
		if gui then gui.Enabled = true end
	end
	plate.Parent = parent
	return plate
end

-- A stack of plates on a horn that points along `hornCFrame`'s +X, starting at the horn's base.
function GymKit.loadHorn(parent, hornCFrame, weights)
	local x = 0.05
	for i, w in ipairs(weights) do
		local spec = Machines.Plates[w]
		if spec then
			x += spec.thickness / 2
			GymKit.plate(parent, w, hornCFrame * CFrame.new(x, 0, 0), i == #weights and 1 or nil)
			x += spec.thickness / 2 + 0.03
		end
	end
end

------------------------------------------------------------------------
-- Floor pieces
------------------------------------------------------------------------
-- Lifting platform: wood center with plank seams, rubber sides, steel edge trim. Centered at pivot, w (x) by d (z).
function GymKit.platform(parent, pivot, w, d)
	local m = model(parent, "Platform", pivot)
	local woodW = math.min(3, w * 0.36)
	p(m, "Base", Vector3.new(w, 0.22, d), at(pivot, 0, 0.11, 0), C.Rubber, M.Rubber, true)
	p(m, "Wood", Vector3.new(woodW, 0.24, d - 0.3), at(pivot, 0, 0.12, 0), C.Wood, M.WoodPlanks)
	for i = -1, 1, 2 do
		p(m, "Seam", Vector3.new(0.04, 0.245, d - 0.3), at(pivot, i * woodW / 6, 0.12, 0), hex("#4E3624"), M.Wood)
		p(m, "TrimSide", Vector3.new(0.12, 0.26, d), at(pivot, i * (w / 2 - 0.06), 0.13, 0), C.Steel, M.Metal)
		p(m, "TrimEnd", Vector3.new(w, 0.26, 0.12), at(pivot, 0, 0.13, i * (d / 2 - 0.06)), C.Steel, M.Metal)
	end
	return m
end

function GymKit.floorMat(parent, cframe, w, d, color)
	local m = model(parent, "FloorMat", cframe)
	p(m, "Mat", Vector3.new(w, 0.06, d), cframe * CFrame.new(0, 0.03, 0), color or hex("#232326"), M.Rubber)
	p(m, "Edge", Vector3.new(w + 0.1, 0.04, d + 0.1), cframe * CFrame.new(0, 0.02, 0), hex("#151517"), M.Rubber)
	return m
end

------------------------------------------------------------------------
-- Starter machines (plate-loaded). Key parts keep the positions Config.Poses was measured on.
------------------------------------------------------------------------
local function machineShell(parent, machineId, pivot)
	local machine = Machines.ById[machineId]
	local m = model(parent, machineId, pivot)
	m:SetAttribute("MachineId", machineId)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	CollectionService:AddTag(m, "Machine")
	return m, machine
end

local function promptOn(part, machine)
	return Kit.prompt(part, "ProximityPrompt", "Use", machine.name, 8)
end

local function barbell(m, cframe, length)
	local bar = cyl(m, "Bar", length or 6, 0.22, cframe, C.Chrome, M.Metal) -- the shaft; sleeves + collars go on with the plates
	bar.Reflectance = 0.2
	return bar
end

-- J-hook with a white UHMW liner, on a post face (cframe = where the bar rests)
local function jhook(m, cframe)
	p(m, "JHook", Vector3.new(0.34, 0.5, 0.18), cframe * CFrame.new(0, -0.12, 0.16), C.Frame, M.Metal)
	p(m, "JHookLip", Vector3.new(0.34, 0.3, 0.1), cframe * CFrame.new(0, 0.05, -0.2), C.Frame, M.Metal)
	p(m, "Uhmw", Vector3.new(0.3, 0.05, 0.42), cframe * CFrame.new(0, -0.14, -0.02), C.Uhmw, M.Plastic)
end

-- A post with a foot plate, a cap and a strip of hole dots up its front.
local function post(m, cframe, height, holes)
	p(m, "Post", Vector3.new(0.36, height, 0.36), cframe * CFrame.new(0, height / 2, 0), C.Frame, M.Metal, true)
	p(m, "PostCap", Vector3.new(0.42, 0.06, 0.42), cframe * CFrame.new(0, height + 0.03, 0), hex("#111113"), M.Plastic)
	p(m, "FootPlate", Vector3.new(0.7, 0.08, 0.7), cframe * CFrame.new(0, 0.04, 0), C.Frame, M.Metal)
	if holes then
		for y = 2, height - 1, 0.5 do
			p(m, "Hole", Vector3.new(0.09, 0.09, 0.02), cframe * CFrame.new(0, y, -0.185), hex("#0A0A0B"), M.SmoothPlastic)
		end
	end
end

-- Static plates resting on storage horns (a pair of horns on a post).
local function storageHorns(m, cframe, side, loads)
	for i, weights in ipairs(loads) do
		local horn = cframe * CFrame.new(0, 0.7 + (i - 1) * 1.6, 0)
		cyl(m, "Horn", 1.4, 0.22, horn * CFrame.new(side * 0.7, 0, 0), C.Steel, M.Metal)
		p(m, "HornCollar", Vector3.new(0.12, 0.36, 0.36), horn * CFrame.new(side * 0.06, 0, 0), C.Frame, M.Metal)
		GymKit.loadHorn(m, horn * CFrame.Angles(0, side > 0 and 0 or math.pi, 0), weights)
	end
end

function GymKit.SquatRack(parent, pivot)
	local m, machine = machineShell(parent, "SquatRack", pivot)
	local base = GymKit.platform(m, pivot * CFrame.new(0, 0, 0.6), 6, 6)
	promptOn(base.Base, machine)
	base.Name = "Platform"
	for _, x in ipairs({ -1.9, 1.9 }) do
		post(m, at(pivot, x, 0.24, 1.8), 7.8, true)
		post(m, at(pivot, x, 0.24, -1.0), 7.8, false)
		p(m, "TopSide", Vector3.new(0.34, 0.3, 3.15), at(pivot, x, 8.05, 0.4), C.Frame, M.Metal, true)
		p(m, "BaseRunner", Vector3.new(0.36, 0.22, 3.6), at(pivot, x, 0.35, 0.4), C.Frame, M.Metal, true)
		p(m, "Safety", Vector3.new(0.22, 0.22, 3.3), at(pivot, x, 2.6, 0.4), C.Steel, M.Metal)
		p(m, "SafetyPin", Vector3.new(0.5, 0.1, 0.1), at(pivot, x, 2.6, 1.95), C.Steel, M.Metal)
		jhook(m, at(pivot, x, 5.35, 1.55))
		p(m, "BandPeg", Vector3.new(0.12, 0.12, 0.4), at(pivot, x, 0.6, 2.1), C.Steel, M.Metal)
	end
	p(m, "TopBar", Vector3.new(4.15, 0.3, 0.34), at(pivot, 0, 8.05, 1.8), C.Frame, M.Metal, true)
	p(m, "TopBar", Vector3.new(4.15, 0.3, 0.34), at(pivot, 0, 8.05, -1.0), C.Frame, M.Metal, true)
	cyl(m, "PullUpBar", 4.4, 0.18, at(pivot, 0, 8.4, 2.05), C.Steel, M.Metal)
	p(m, "BackBrace", Vector3.new(4.15, 0.22, 0.3), at(pivot, 0, 0.45, -1.0), C.Frame, M.Metal, true)
	-- plate storage on the back posts
	storageHorns(m, at(pivot, -1.9, 0, -1.0), -1, { { 45, 25 }, { 10, 5 } })
	storageHorns(m, at(pivot, 1.9, 0, -1.0), 1, { { 55, 45 }, { 35 } })
	barbell(m, at(pivot, 0, 5.35, 1.55))
	return m
end

function GymKit.OverheadPress(parent, pivot)
	local m, machine = machineShell(parent, "OverheadPress", pivot)
	local base = GymKit.platform(m, pivot * CFrame.new(0, 0, 0.6), 6, 6)
	base.Name = "Platform"
	promptOn(base.Base, machine)
	for _, x in ipairs({ -1.9, 1.9 }) do
		post(m, at(pivot, x, 0.24, 2.1), 6.8, true)
		p(m, "Foot", Vector3.new(0.5, 0.25, 2.2), at(pivot, x, 0.37, 2.1), C.Frame, M.Metal, true)
		p(m, "FootPad", Vector3.new(0.55, 0.06, 0.4), at(pivot, x, 0.27, 3.1), C.Rubber, M.Rubber)
		jhook(m, at(pivot, x, 5.0, 1.85))
	end
	p(m, "TopBar", Vector3.new(4.15, 0.3, 0.34), at(pivot, 0, 7.05, 2.1), C.Frame, M.Metal, true)
	storageHorns(m, at(pivot, 1.9, 0, 2.1) * CFrame.Angles(0, 0, 0), 1, { { 25, 10 } })
	barbell(m, at(pivot, 0, 5.0, 1.85))
	return m
end

local function floorBar(m, machine, pivot)
	local base = GymKit.platform(m, pivot * CFrame.new(0, 0, 0.6), 8.5, 6)
	base.Name = "Platform"
	promptOn(base.Base, machine)
	for _, x in ipairs({ -3.4, 3.4 }) do
		p(m, "BarJack", Vector3.new(0.4, 0.9, 0.6), at(pivot, x, 0.69, 1.35), C.Frame, M.Metal)
		p(m, "BarJackFoot", Vector3.new(0.6, 0.1, 0.9), at(pivot, x, 0.29, 1.35), C.Frame, M.Metal)
		p(m, "BarJackSaddle", Vector3.new(0.42, 0.12, 0.3), at(pivot, x, 1.18, 1.35), C.Uhmw, M.Plastic)
	end
	-- chalk mark and a small plate stack waiting by the platform
	p(m, "Chalk", Vector3.new(1.2, 0.01, 0.8), at(pivot, -0.4, 0.252, 2.6, 0, 18, 0), C.Chalk, M.Sand, false, { Transparency = 0.55 })
	barbell(m, at(pivot, 0, 1.4, 1.35))
end

function GymKit.Deadlift(parent, pivot)
	local m, machine = machineShell(parent, "Deadlift", pivot)
	floorBar(m, machine, pivot)
	return m
end

function GymKit.BarbellRow(parent, pivot)
	local m, machine = machineShell(parent, "BarbellRow", pivot)
	floorBar(m, machine, pivot)
	return m
end

-- padded bench: leather pad on a board, piping, a steel frame with front/back feet
local function benchPad(m, cframe, length)
	local pad = p(m, "Pad", Vector3.new(1.5, 0.4, length), cframe, C.Pad, M.Leather, true)
	p(m, "PadBoard", Vector3.new(1.4, 0.1, length - 0.1), cframe * CFrame.new(0, -0.24, 0), hex("#3A2A1E"), M.Wood)
	p(m, "Piping", Vector3.new(1.52, 0.04, length + 0.02), cframe * CFrame.new(0, 0.05, 0), hex("#141212"), M.Leather)
	return pad
end

function GymKit.FlatBench(parent, pivot)
	local m, machine = machineShell(parent, "FlatBench", pivot)
	local pad = benchPad(m, at(pivot, 0, 1.6, 0.25), 6.4)
	promptOn(pad, machine)
	p(m, "PadBase", Vector3.new(0.9, 0.2, 6.1), at(pivot, 0, 1.25, 0.25), C.Frame, M.Metal, true)
	p(m, "LegFront", Vector3.new(0.36, 1.05, 0.36), at(pivot, 0, 0.62, 2.9), C.Frame, M.Metal, true)
	p(m, "FootFront", Vector3.new(1.6, 0.2, 0.4), at(pivot, 0, 0.1, 2.9), C.Frame, M.Metal, true)
	p(m, "LegBack", Vector3.new(0.36, 1.05, 0.36), at(pivot, 0, 0.62, -1.4), C.Frame, M.Metal, true)
	p(m, "Rail", Vector3.new(0.36, 0.2, 5.2), at(pivot, 0, 0.1, 0.5), C.Frame, M.Metal, true)
	for _, foot in ipairs({ -0.7, 0.7 }) do
		p(m, "RubberFoot", Vector3.new(0.3, 0.05, 0.3), at(pivot, foot, 0.025, 2.9), C.Rubber, M.Rubber)
	end
	for _, x in ipairs({ -1.9, 1.9 }) do
		post(m, at(pivot, x, 0, -2.3), 4.9, true)
		p(m, "Foot", Vector3.new(0.6, 0.2, 1.8), at(pivot, x, 0.1, -2.3), C.Frame, M.Metal, true)
		jhook(m, at(pivot, x, 4.4, -2.05))
		-- spotter step
		p(m, "SpotterStep", Vector3.new(0.9, 0.12, 0.7), at(pivot, x * 1.25, 0.9, -2.6), hex("#2E2E33"), M.DiamondPlate, true)
	end
	p(m, "Crossbar", Vector3.new(3.45, 0.25, 0.35), at(pivot, 0, 0.32, -2.3), C.Frame, M.Metal, true)
	storageHorns(m, at(pivot, 1.9, 0, -2.3), 1, { { 45 } })
	storageHorns(m, at(pivot, -1.9, 0, -2.3), -1, { { 25, 10 } })
	barbell(m, at(pivot, 0, 4.4, -2.05))
	return m
end

function GymKit.InclineBench(parent, pivot)
	local m, machine = machineShell(parent, "InclineBench", pivot)
	local back = benchPad(m, at(pivot, 0, 2.75, -1.21, 30), 4.2)
	back.Name = "BackPad"
	promptOn(back, machine)
	local seat = benchPad(m, at(pivot, 0, 1.9, 0.9), 1.8)
	seat.Name = "Seat"
	p(m, "BackPost", Vector3.new(0.4, 2.1, 0.4), at(pivot, 0, 1.1, -1.4), C.Frame, M.Metal, true)
	p(m, "Brace", Vector3.new(0.3, 0.3, 2.2), at(pivot, 0, 1.3, -0.3, 30), C.Frame, M.Metal, true)
	p(m, "SeatPost", Vector3.new(0.4, 1.7, 0.4), at(pivot, 0, 0.85, 0.9), C.Frame, M.Metal, true)
	p(m, "Rail", Vector3.new(0.36, 0.2, 5), at(pivot, 0, 0.1, -0.2), C.Frame, M.Metal, true)
	p(m, "FootFront", Vector3.new(1.6, 0.2, 0.4), at(pivot, 0, 0.1, 2.1), C.Frame, M.Metal, true)
	cyl(m, "FootRoller", 1.4, 0.38, at(pivot, 0, 0.75, 2.0), C.Pad, M.Leather)
	p(m, "RollerPost", Vector3.new(0.25, 0.6, 0.25), at(pivot, 0, 0.45, 2.0), C.Frame, M.Metal)
	for _, x in ipairs({ -1.9, 1.9 }) do
		post(m, at(pivot, x, 0, -2.0), 6.2, true)
		p(m, "Foot", Vector3.new(0.6, 0.2, 1.8), at(pivot, x, 0.1, -2.0), C.Frame, M.Metal, true)
		jhook(m, at(pivot, x, 5.1, -1.75))
	end
	p(m, "Crossbar", Vector3.new(3.45, 0.25, 0.35), at(pivot, 0, 0.32, -2.0), C.Frame, M.Metal, true)
	p(m, "TopBar", Vector3.new(4.15, 0.25, 0.35), at(pivot, 0, 6.3, -2.0), C.Frame, M.Metal, true)
	storageHorns(m, at(pivot, -1.9, 0, -2.0), -1, { { 35, 10 } })
	barbell(m, at(pivot, 0, 5.1, -1.75))
	return m
end

function GymKit.CrunchBench(parent, pivot)
	local m, machine = machineShell(parent, "CrunchBench", pivot)
	local pad = benchPad(m, at(pivot, 0, 1.6, 0.25), 6.4)
	promptOn(pad, machine)
	p(m, "PadBase", Vector3.new(0.9, 0.2, 6.1), at(pivot, 0, 1.25, 0.25), C.Frame, M.Metal, true)
	p(m, "LegFront", Vector3.new(1.4, 1.05, 0.36), at(pivot, 0, 0.62, 3.0), C.Frame, M.Metal, true)
	p(m, "LegBack", Vector3.new(1.4, 1.05, 0.36), at(pivot, 0, 0.62, -2.5), C.Frame, M.Metal, true)
	-- foot rollers at the front end
	p(m, "RollerArm", Vector3.new(0.3, 1.2, 0.3), at(pivot, 0, 2.2, 3.0), C.Frame, M.Metal)
	cyl(m, "FootRoller", 1.6, 0.42, at(pivot, 0, 2.55, 3.0), C.Pad, M.Leather)
	cyl(m, "FootRoller", 1.6, 0.42, at(pivot, 0, 2.05, 3.25), C.Pad, M.Leather)
	-- the plate (held on the chest) waits on a small stand beside the bench
	p(m, "PlateStand", Vector3.new(0.5, 0.6, 0.5), at(pivot, 1.8, 0.3, 1.2), C.Frame, M.Metal)
	cyl(m, "Load", 0.9, 0.22, at(pivot, 1.8, 0.75, 1.2), C.Chrome, M.Metal)
	return m
end

function GymKit.PullUpBar(parent, pivot)
	local m, machine = machineShell(parent, "PullUpBar", pivot)
	local mat = p(m, "Platform", Vector3.new(6, 0.25, 5), at(pivot, 0, 0.12, 0), C.Rubber, M.Rubber, true)
	promptOn(mat, machine)
	for _, x in ipairs({ -2.6, 2.6 }) do
		post(m, at(pivot, x, 0.25, 0), 9.35, false)
		p(m, "Foot", Vector3.new(0.6, 0.2, 2.6), at(pivot, x, 0.35, 0), C.Frame, M.Metal, true)
		p(m, "Brace", Vector3.new(0.25, 2.4, 0.25), at(pivot, x, 1.3, 0.8, -35), C.Frame, M.Metal)
		p(m, "Brace", Vector3.new(0.25, 2.4, 0.25), at(pivot, x, 1.3, -0.8, 35), C.Frame, M.Metal)
	end
	cyl(m, "Bar", 5.6, 0.22, at(pivot, 0, 9, 0), C.Chrome, M.Metal)
	p(m, "TopBeam", Vector3.new(5.6, 0.25, 0.3), at(pivot, 0, 9.5, 0), C.Frame, M.Metal)
	-- wide grips with knurling sleeves
	for _, x in ipairs({ -1.6, 1.6 }) do cyl(m, "Grip", 0.8, 0.26, at(pivot, x, 9, 0), hex("#1A1A1A"), M.Rubber) end
	-- plate belt hook (the "Load" the plates hang from) + step box
	p(m, "Peg", Vector3.new(0.5, 0.15, 0.15), at(pivot, 2.95, 3.2, 0), C.Steel, M.Metal)
	local load = cyl(m, "Load", 0.9, 0.22, at(pivot, 3.3, 2.7, 0, 0, 90, 0), C.Chrome, M.Metal)
	load.Name = "Load"
	p(m, "StepBox", Vector3.new(1.6, 1, 1.2), at(pivot, -1.3, 0.75, 1.6), hex("#2A2A2E"), M.Plastic, true)
	p(m, "StepTop", Vector3.new(1.62, 0.06, 1.22), at(pivot, -1.3, 1.27, 1.6), C.Rubber, M.Rubber)
	return m
end

GymKit.Starter = {
	SquatRack = GymKit.SquatRack, OverheadPress = GymKit.OverheadPress, Deadlift = GymKit.Deadlift,
	BarbellRow = GymKit.BarbellRow, FlatBench = GymKit.FlatBench, InclineBench = GymKit.InclineBench,
	CrunchBench = GymKit.CrunchBench, PullUpBar = GymKit.PullUpBar,
}

------------------------------------------------------------------------
-- Pro machines: real machines with a selectorized weight stack. The stack's selector pin is the "Bar" (load part);
-- the model has Stack = true, so MachineService shows the weight by moving the pin instead of hanging plates, and
-- MachineClient lifts the selected blocks on every rep. Blocks are named StackBlock1 (top) ... StackBlock12.
------------------------------------------------------------------------
local STACK_BLOCKS = 12

-- A weight stack tower at `cframe` (floor, facing local +Z toward the lifter). Returns the top pulley position.
------------------------------------------------------------------------
-- Plate-loaded leg machines (Leg Press, Hack Squat). The load part (Sled / Carriage) slides on the machine's rail with the
-- rep (MachineClient follow = "Rail"); everything that moves with it is in the "Rides" folder. Plates go on BarSleeve
-- horns beside it (SleeveStart attribute = where the horns start, from the load's centre, along its X axis).
------------------------------------------------------------------------
-- a part laid in an inclined frame: o = the frame's rotation (model space), size in that frame
local function inclined(m, name, size, pivot, position, o, color, material, solid)
	return p(m, name, size, pivot * CFrame.new(position) * o, color, material, solid)
end

function GymKit.LegPress(parent, pivot)
	local m, machine = machineShell(parent, "LegPress", pivot)
	-- the lifter's hips (Config.Poses.LegPress), the seat back direction u and the sled rail direction f (50 degrees up)
	local hips = Vector3.new(0, 2.0, -0.6)
	local u = Vector3.new(0, 0.643, -0.766)
	local f = Vector3.new(0, 0.766, 0.643)
	local o = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, u) -- Y along the seat back, Z along the rail
	-- base frame on the floor
	for _, x in ipairs({ -1.25, 1.25 }) do
		p(m, "Runner", Vector3.new(0.3, 0.25, 8.2), at(pivot, x, 0.125, 0.6), C.Frame, M.Metal, true)
		p(m, "RunnerFoot", Vector3.new(0.5, 0.06, 0.5), at(pivot, x, 0.03, -3.3), C.Rubber, M.Rubber)
		p(m, "RunnerFoot", Vector3.new(0.5, 0.06, 0.5), at(pivot, x, 0.03, 4.5), C.Rubber, M.Rubber)
	end
	for _, z in ipairs({ -3.2, 0.2, 3.4 }) do
		p(m, "CrossMember", Vector3.new(2.8, 0.22, 0.3), at(pivot, 0, 0.13, z), C.Frame, M.Metal, true)
	end
	-- the seat: a long reclined back pad and a short seat pad under the hips, on a column and a rear post
	local back = inclined(m, "BackPad", Vector3.new(1.7, 3.0, 0.38), pivot, hips - f * 0.72 + u * 1.05, o, C.Pad, M.Leather, true)
	inclined(m, "BackBoard", Vector3.new(1.6, 2.9, 0.1), pivot, hips - f * 0.96 + u * 1.05, o, hex("#3A2A1E"), M.Wood)
	inclined(m, "Piping", Vector3.new(1.72, 3.02, 0.04), pivot, hips - f * 0.55 + u * 1.05, o, hex("#141212"), M.Leather)
	inclined(m, "SeatPad", Vector3.new(1.7, 1.0, 0.38), pivot, hips - f * 0.72 - u * 0.95 + f * 0.12, o * CFrame.Angles(math.rad(-25), 0, 0), C.Pad, M.Leather, true)
	p(m, "SeatColumn", Vector3.new(0.4, 1.5, 0.4), at(pivot, 0, 0.85, -1.15), C.Frame, M.Metal, true)
	p(m, "SeatBracket", Vector3.new(1.0, 0.18, 1.2), at(pivot, 0, 1.6, -1.25), C.Frame, M.Metal, true)
	post(m, at(pivot, 0, 0.25, -3.3), 2.6, false)
	inclined(m, "BackBrace", Vector3.new(0.3, 0.3, 1.4), pivot, Vector3.new(0, 2.55, -2.85), CFrame.Angles(math.rad(35), 0, 0), C.Frame, M.Metal, true)
	-- side handles by the hips
	for _, x in ipairs({ -1.05, 1.05 }) do
		p(m, "HandlePost", Vector3.new(0.18, 1.35, 0.18), at(pivot, x, 0.9, -0.55), C.Frame, M.Metal, true)
		cyl(m, "Handle", 0.9, 0.16, at(pivot, x, 1.62, -0.35, 0, 90, 0), C.Chrome, M.Metal)
		cyl(m, "Grip", 0.5, 0.2, at(pivot, x, 1.62, -0.2, 0, 90, 0), C.Rubber, M.Rubber)
	end
	-- the two guide rails (along f), their posts and end stops
	for _, x in ipairs({ -1.05, 1.05 }) do
		local line = Vector3.new(x, hips.Y, hips.Z) - u * 0.55
		inclined(m, "Rail", Vector3.new(0.22, 0.22, 5.0), pivot, line + f * 3.1, o, C.Chrome, M.Metal, true)
		inclined(m, "RailStop", Vector3.new(0.34, 0.34, 0.2), pivot, line + f * 5.65, o, C.Rubber, M.Rubber)
		local top = line + f * 5.4
		p(m, "RailPost", Vector3.new(0.32, top.Y, 0.32), at(pivot, x, top.Y / 2, top.Z + 0.1), C.Frame, M.Metal, true)
		local low = line + f * 0.7
		p(m, "RailFoot", Vector3.new(0.32, low.Y, 0.32), at(pivot, x, low.Y / 2, low.Z), C.Frame, M.Metal, true)
		inclined(m, "RailBrace", Vector3.new(0.24, 0.24, 3.0), pivot, Vector3.new(x, 1.6, 2.4), CFrame.Angles(math.rad(-38), 0, 0), C.Frame, M.Metal, true)
	end
	p(m, "TopCross", Vector3.new(2.4, 0.26, 0.3), at(pivot, 0, (hips - u * 0.55 + f * 5.4).Y, (hips - u * 0.55 + f * 5.4).Z + 0.1), C.Frame, M.Metal, true)
	-- the sled: the foot platform is the load ("Sled"); its carriage, rollers and heel lip ride with it
	local rest = hips + f * 3.3
	local sled = inclined(m, "Sled", Vector3.new(2.3, 2.0, 0.16), pivot, rest, o, hex("#3A3A3F"), M.DiamondPlate)
	local rides = Instance.new("Folder")
	rides.Name = "Rides"
	rides.Parent = m
	inclined(rides, "SledFrame", Vector3.new(2.4, 2.1, 0.08), pivot, rest + f * 0.12, o, C.Frame, M.Metal)
	inclined(rides, "SledBeam", Vector3.new(2.5, 0.26, 0.4), pivot, rest + f * 0.36, o, C.Frame, M.Metal)
	inclined(rides, "SledBeam", Vector3.new(2.5, 0.26, 0.4), pivot, rest + f * 0.36 - u * 0.8, o, C.Frame, M.Metal)
	inclined(rides, "HeelLip", Vector3.new(2.3, 0.1, 0.28), pivot, rest - u * 1.0 - f * 0.12, o, C.Frame, M.Metal)
	for _, x in ipairs({ -1.05, 1.05 }) do
		inclined(rides, "Roller", Vector3.new(0.34, 0.5, 1.0), pivot, Vector3.new(x, rest.Y, rest.Z) - u * 0.55 + f * 0.1, o, hex("#2E2E33"), M.Metal)
		inclined(rides, "SafetyHandle", Vector3.new(0.12, 0.12, 0.7), pivot, Vector3.new(x * 1.12, rest.Y, rest.Z) - u * 0.9 - f * 0.25, o, C.Chrome, M.Metal)
	end
	promptOn(back, machine)
	m:SetAttribute("SleeveStart", 1.25)
	m:SetAttribute("RailAxis", f)
	m:SetAttribute("RailAnchor", "Feet")
	m:SetAttribute("RailOffset", 0.33)
	m:SetAttribute("RailMin", -2.8)
	m:SetAttribute("RailMax", 0)
	sled.CanQuery = false
	return m
end

function GymKit.HackSquat(parent, pivot)
	local m, machine = machineShell(parent, "HackSquat", pivot)
	-- the lifter stands at the pivot facing +Z, leaning back on the pad; the rail r tilts back 12 degrees, n = the pad's front
	local r = Vector3.new(0, 0.978, -0.208)
	local n = Vector3.new(0, 0.208, 0.978)
	local o = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, r) -- Y along the rail, Z = the pad's front
	-- base and the foot platform (diamond plate, a toe lip)
	for _, x in ipairs({ -1.0, 1.0 }) do
		p(m, "Runner", Vector3.new(0.3, 0.25, 4.6), at(pivot, x, 0.125, -0.5), C.Frame, M.Metal, true)
	end
	p(m, "FootPlatform", Vector3.new(2.6, 0.12, 2.0), at(pivot, 0, 0.49, 0.35), hex("#3A3A3F"), M.DiamondPlate, true)
	p(m, "PlatformFrame", Vector3.new(2.7, 0.3, 2.1), at(pivot, 0, 0.3, 0.35), C.Frame, M.Metal, true)
	p(m, "ToeLip", Vector3.new(2.6, 0.18, 0.12), at(pivot, 0, 0.62, 1.34), C.Frame, M.Metal)
	-- the two rails (along r) from the base to the top, with rear posts and a top bar
	local foot = Vector3.new(0, 0.6, -1.05)
	for _, x in ipairs({ -0.95, 0.95 }) do
		inclined(m, "Rail", Vector3.new(0.22, 7.4, 0.22), pivot, Vector3.new(x, foot.Y, foot.Z) + r * 3.7, o, C.Chrome, M.Metal, true)
		local top = Vector3.new(x, foot.Y, foot.Z) + r * 7.4
		p(m, "RearPost", Vector3.new(0.32, top.Y, 0.32), at(pivot, x, top.Y / 2, top.Z - 0.3), C.Frame, M.Metal, true)
		p(m, "PostFoot", Vector3.new(0.6, 0.08, 0.6), at(pivot, x, 0.04, top.Z - 0.3), C.Frame, M.Metal)
		inclined(m, "RailStop", Vector3.new(0.34, 0.2, 0.34), pivot, Vector3.new(x, foot.Y, foot.Z) + r * 7.45, o, C.Rubber, M.Rubber)
		p(m, "RailBase", Vector3.new(0.4, 0.5, 0.5), at(pivot, x, 0.5, foot.Z), C.Frame, M.Metal, true)
	end
	local topCenter = foot + r * 7.4
	p(m, "TopBar", Vector3.new(2.2, 0.28, 0.32), at(pivot, 0, topCenter.Y, topCenter.Z - 0.3), C.Frame, M.Metal, true)
	p(m, "MidBar", Vector3.new(2.2, 0.24, 0.3), at(pivot, 0, 3.0, topCenter.Z - 0.3), C.Frame, M.Metal, true)
	-- the carriage (the load) at standing shoulder height, with the back pad, shoulder pads, handles and rollers riding on it
	local restPad = Vector3.new(0, 2.5, -0.78) + r * 2.2   -- on the pad's centre line
	local carriage = restPad - n * 0.3
	local load = inclined(m, "Carriage", Vector3.new(2.0, 0.3, 0.3), pivot, carriage, o, C.Frame, M.Metal)
	local rides = Instance.new("Folder")
	rides.Name = "Rides"
	rides.Parent = m
	inclined(rides, "BackPad", Vector3.new(1.5, 3.2, 0.35), pivot, carriage + n * 0.3 - r * 1.45, o, C.Pad, M.Leather)
	inclined(rides, "BackBoard", Vector3.new(1.4, 3.1, 0.1), pivot, carriage + n * 0.08 - r * 1.45, o, hex("#3A2A1E"), M.Wood)
	inclined(rides, "CarriageSpine", Vector3.new(0.3, 3.4, 0.25), pivot, carriage - r * 1.5, o, C.Frame, M.Metal)
	for _, x in ipairs({ -0.55, 0.55 }) do
		inclined(rides, "ShoulderPad", Vector3.new(0.42, 0.38, 1.05), pivot, Vector3.new(x, carriage.Y, carriage.Z) + n * 0.85 + r * 0.32, o, C.Pad, M.Leather)
		inclined(rides, "ShoulderArm", Vector3.new(0.16, 0.16, 0.9), pivot, Vector3.new(x, carriage.Y, carriage.Z) + n * 0.6 + r * 0.55, o, C.Frame, M.Metal)
	end
	for _, x in ipairs({ -0.95, 0.95 }) do
		inclined(rides, "Roller", Vector3.new(0.36, 0.7, 0.36), pivot, Vector3.new(x, carriage.Y, carriage.Z), o, hex("#2E2E33"), M.Metal)
		inclined(rides, "Handle", Vector3.new(0.14, 0.14, 0.6), pivot, Vector3.new(x * 0.95, carriage.Y, carriage.Z) + n * 0.95 + r * 0.05, o, C.Chrome, M.Metal)
	end
	promptOn(m:FindFirstChild("FootPlatform"), machine)
	m:SetAttribute("SleeveStart", 1.2)
	m:SetAttribute("RailAxis", r)
	m:SetAttribute("RailAnchor", "Shoulders")
	m:SetAttribute("RailOffset", -0.15)
	m:SetAttribute("RailMin", -3.2)
	m:SetAttribute("RailMax", 1.2)
	load.CanQuery = false
	return m
end

local function stackTower(m, cframe, height, shroudColor)
	height = height or 8
	p(m, "TowerBase", Vector3.new(2.6, 0.25, 1.6), cframe * CFrame.new(0, 0.12, 0), C.Frame, M.Metal, true)
	for _, x in ipairs({ -1.15, 1.15 }) do
		p(m, "TowerPost", Vector3.new(0.3, height, 0.5), cframe * CFrame.new(x, height / 2, 0), C.Frame, M.Metal, true)
		-- shrouds: dark panels on the sides with a steel edge
		p(m, "Shroud", Vector3.new(0.06, height - 1.5, 1.4), cframe * CFrame.new(x + (x > 0 and 0.2 or -0.2), height / 2 + 0.3, 0), shroudColor or hex("#2B2D31"), M.Metal)
	end
	p(m, "TowerTop", Vector3.new(2.6, 0.35, 1.0), cframe * CFrame.new(0, height + 0.17, 0), C.Frame, M.Metal, true)
	-- guide rods
	for _, x in ipairs({ -0.55, 0.55 }) do
		cyl(m, "GuideRod", height - 0.6, 0.1, cframe * CFrame.new(x, height / 2, 0) * CFrame.Angles(0, 0, rad(90)), C.Chrome, M.Metal)
	end
	-- the stack: 12 blocks, black with a white number strip
	local blockH = 0.26
	for i = 1, STACK_BLOCKS do
		local y = 0.4 + (STACK_BLOCKS - i) * (blockH + 0.02) + blockH / 2
		local block = p(m, "StackBlock" .. i, Vector3.new(1.5, blockH, 0.8), cframe * CFrame.new(0, y, 0), hex("#1E1F22"), M.Metal)
		p(block, "Edge", Vector3.new(1.52, 0.03, 0.82), block.CFrame * CFrame.new(0, blockH / 2 - 0.015, 0), hex("#3A3C40"), M.Metal)
	end
	local topY = 0.4 + STACK_BLOCKS * (blockH + 0.02)
	p(m, "TopPlate", Vector3.new(1.5, 0.12, 0.8), cframe * CFrame.new(0, topY + 0.06, 0), C.Chrome, M.Metal)
	cyl(m, "SelectorRod", topY - 0.2, 0.08, cframe * CFrame.new(0, topY / 2 + 0.3, -0.42) * CFrame.Angles(0, 0, rad(90)), C.Chrome, M.Metal)
	-- the selector pin (load part): a short rod with an orange-free steel knob, starts at block 1
	local pin = cyl(m, "Bar", 1.1, 0.1, cframe * CFrame.new(0, 0.4 + (STACK_BLOCKS - 1) * (blockH + 0.02) + blockH / 2, -0.45) * CFrame.Angles(0, rad(90), 0), C.Steel, M.Metal)
	-- top pulley
	local pulley = cframe * CFrame.new(0, height - 0.2, 0.6)
	cyl(m, "Pulley", 0.2, 0.7, pulley, hex("#3A3C40"), M.Metal)
	p(m, "PulleyHousing", Vector3.new(0.35, 0.8, 0.9), pulley * CFrame.new(0, 0.1, -0.1), C.Frame, M.Metal)
	-- label plate on the tower top (machine name, plain text)
	m:SetAttribute("Stack", true)
	m:SetAttribute("StackBlocks", STACK_BLOCKS)
	m:SetAttribute("StackPitch", blockH + 0.02)
	return pulley, pin
end

local function cable(m, from, to)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	p(m, "Cable", Vector3.new(0.05, 0.05, length), CFrame.lookAt(mid, to), hex("#1A1A1A"), M.SmoothPlastic)
end

local function dHandle(m, cframe)
	p(m, "HandleGrip", Vector3.new(0.5, 0.12, 0.12), cframe, hex("#1A1A1A"), M.Rubber)
	p(m, "HandleFrame", Vector3.new(0.6, 0.06, 0.06), cframe * CFrame.new(0, 0.25, 0), C.Chrome, M.Metal)
	p(m, "HandleSide", Vector3.new(0.06, 0.3, 0.06), cframe * CFrame.new(-0.28, 0.12, 0), C.Chrome, M.Metal)
	p(m, "HandleSide", Vector3.new(0.06, 0.3, 0.06), cframe * CFrame.new(0.28, 0.12, 0), C.Chrome, M.Metal)
end

local function proBase(parent, machineId, pivot)
	local m, machine = machineShell(parent, machineId, pivot)
	local mat = p(m, "Base", Vector3.new(4.6, 0.12, 6.2), at(pivot, 0, 0.06, 0.6), C.Rubber, M.Rubber, true)
	p(m, "BaseTrim", Vector3.new(4.7, 0.08, 6.3), at(pivot, 0, 0.04, 0.6), hex("#3A3C40"), M.Metal)
	promptOn(mat, machine)
	return m, machine
end

-- Cable machines: the lifter stands at the pivot facing the tower 2.6 studs ahead.
local function cableStation(parent, machineId, pivot, handleHeight, handleOffsetX)
	local m = proBase(parent, machineId, pivot)
	local towerCF = at(pivot, 0, 0, 2.8, 0, 180, 0)
	local pulley = stackTower(m, towerCF, 8)
	local low = handleHeight < 3
	local outlet = at(pivot, 0, low and 0.8 or 7.6, 2.2)
	cyl(m, "Pulley", 0.2, 0.55, outlet, hex("#3A3C40"), M.Metal)
	local handle = at(pivot, handleOffsetX or 0, handleHeight, 0.9)
	cable(m, pulley.Position, outlet.Position)
	cable(m, outlet.Position, handle.Position + Vector3.new(0, 0.3, 0))
	dHandle(m, handle)
	return m
end

GymKit.Pro = {}
GymKit.Pro.LateralRaise = function(parent, pivot) return cableStation(parent, "LateralRaise", pivot, 1.2, 0.6) end
GymKit.Pro.ReverseFly = function(parent, pivot) return cableStation(parent, "ReverseFly", pivot, 5.6, 0) end
GymKit.Pro.BicepCurl = function(parent, pivot) return cableStation(parent, "BicepCurl", pivot, 1.6, 0) end
GymKit.Pro.TricepPushdown = function(parent, pivot) return cableStation(parent, "TricepPushdown", pivot, 5.2, 0) end
GymKit.Pro.CableWoodchop = function(parent, pivot) return cableStation(parent, "CableWoodchop", pivot, 6.2, -0.8) end

GymKit.Pro.Shrugs = function(parent, pivot)
	local m = proBase(parent, "Shrugs", pivot)
	stackTower(m, at(pivot, 0, 0, 2.6, 0, 180, 0), 6.5)
	-- shrug handles at the lifter's sides on a lever
	for _, x in ipairs({ -1.25, 1.25 }) do
		p(m, "Lever", Vector3.new(0.2, 0.2, 2.4), at(pivot, x, 2.6, 1.3), C.Frame, M.Metal)
		cyl(m, "Grip", 0.6, 0.22, at(pivot, x, 2.4, 0.2, 0, 0, 90), hex("#1A1A1A"), M.Rubber)
	end
	return m
end

GymKit.Pro.CalfRaise = function(parent, pivot)
	local m = proBase(parent, "CalfRaise", pivot)
	stackTower(m, at(pivot, 0, 0, 2.8, 0, 180, 0), 8)
	p(m, "Step", Vector3.new(2.2, 0.35, 1.2), at(pivot, 0, 0.3, 0.4), hex("#2E2E33"), M.DiamondPlate, true)
	-- shoulder pads on an arm from the tower
	p(m, "Arm", Vector3.new(2.4, 0.25, 0.25), at(pivot, 0, 6.0, 1.2), C.Frame, M.Metal)
	for _, x in ipairs({ -0.6, 0.6 }) do
		p(m, "ShoulderPad", Vector3.new(0.6, 0.35, 0.9), at(pivot, x, 5.75, 0.6), C.Pad, M.Leather)
	end
	p(m, "ArmLink", Vector3.new(0.25, 0.25, 1.6), at(pivot, 0, 6.0, 2.0), C.Frame, M.Metal)
	return m
end

GymKit.Pro.LegCurl = function(parent, pivot)
	local m = proBase(parent, "LegCurl", pivot)
	stackTower(m, at(pivot, 0, 0, 3.6, 0, 180, 0), 7)
	local pad = p(m, "Pad", Vector3.new(1.6, 0.45, 5), at(pivot, 0, 1.55, 0), C.Pad, M.Leather, true)
	p(m, "PadBoard", Vector3.new(1.5, 0.1, 4.9), at(pivot, 0, 1.3, 0), hex("#3A2A1E"), M.Wood)
	p(m, "Frame", Vector3.new(0.5, 1.2, 3.6), at(pivot, 0, 0.7, 0), C.Frame, M.Metal, true)
	p(m, "HandleBar", Vector3.new(1.9, 0.14, 0.14), at(pivot, 0, 1.75, 2.4), C.Chrome, M.Metal)
	cyl(m, "AnkleRoller", 1.6, 0.42, at(pivot, 0, 1.85, -2.6), C.Pad, M.Leather)
	p(m, "RollerArm", Vector3.new(0.25, 1.2, 0.25), at(pivot, 0, 1.3, -2.6), C.Frame, M.Metal)
	cable(m, (at(pivot, 0, 1.3, -2.6)).Position, (at(pivot, 0, 0.6, 3.0)).Position)
	return m
end

GymKit.Pro.HipThrust = function(parent, pivot)
	local m = proBase(parent, "HipThrust", pivot)
	-- shoulder bench, a hip belt over the lap and a plate-loaded pin at the side ("Bar")
	p(m, "Pad", Vector3.new(3, 0.6, 1.2), at(pivot, 0, 1.5, 1.6), C.Pad, M.Leather, true)
	p(m, "Support", Vector3.new(2.6, 1.2, 0.8), at(pivot, 0, 0.6, 1.6), C.Frame, M.Metal, true)
	p(m, "FootPlate", Vector3.new(2.6, 0.12, 1.4), at(pivot, 0, 0.18, -2.0), hex("#2E2E33"), M.DiamondPlate)
	p(m, "PinPost", Vector3.new(0.3, 1.6, 0.3), at(pivot, 2.4, 0.8, 0), C.Frame, M.Metal, true)
	cyl(m, "Bar", 1.2, 0.2, at(pivot, 2.4, 1.5, 0), C.Chrome, M.Metal)
	return m
end

GymKit.Pro.Dips = function(parent, pivot)
	local m = proBase(parent, "Dips", pivot)
	for _, x in ipairs({ -1.15, 1.15 }) do
		post(m, at(pivot, x, 0.12, 1.1), 3.1, false)
		post(m, at(pivot, x, 0.12, -0.9), 3.1, false)
		cyl(m, "Handle", 2.4, 0.24, at(pivot, x, 3.2, 0.1, 0, 90, 0), hex("#1A1A1A"), M.Rubber)
	end
	p(m, "BackPad", Vector3.new(1.4, 1.6, 0.3), at(pivot, 0, 3.6, 1.4), C.Pad, M.Leather)
	p(m, "PinPost", Vector3.new(0.3, 1.6, 0.3), at(pivot, 2.4, 0.8, 0), C.Frame, M.Metal, true)
	cyl(m, "Bar", 1.2, 0.2, at(pivot, 2.4, 1.5, 0), C.Chrome, M.Metal)
	return m
end

GymKit.Pro.HangingLegRaise = function(parent, pivot)
	local m = proBase(parent, "HangingLegRaise", pivot)
	for _, x in ipairs({ -1.7, 1.7 }) do
		post(m, at(pivot, x, 0.12, 0), 9.5, false)
		p(m, "Foot", Vector3.new(0.6, 0.2, 2.6), at(pivot, x, 0.22, 0), C.Frame, M.Metal, true)
	end
	cyl(m, "HangBar", 3.7, 0.22, at(pivot, 0, 9, 0), C.Chrome, M.Metal)
	for _, x in ipairs({ -1.1, 1.1 }) do
		p(m, "Strap", Vector3.new(0.3, 0.9, 0.12), at(pivot, x, 8.5, 0), hex("#141414"), M.Fabric)
	end
	p(m, "PinPost", Vector3.new(0.3, 1.6, 0.3), at(pivot, 2.4, 0.8, 0), C.Frame, M.Metal, true)
	cyl(m, "Bar", 1.2, 0.2, at(pivot, 2.4, 1.5, 0), C.Chrome, M.Metal)
	return m
end

------------------------------------------------------------------------
-- Racks and small equipment
------------------------------------------------------------------------
-- Plate tree: X-shaped feet, a post with 3 pairs of horns, each carrying plates (heaviest low).
function GymKit.plateTree(parent, cframe, loads)
	local m = model(parent, "PlateTree", cframe)
	p(m, "FootA", Vector3.new(3, 0.2, 0.4), cframe * CFrame.new(0, 0.1, 0), C.Frame, M.Metal, true)
	p(m, "FootB", Vector3.new(0.4, 0.2, 3), cframe * CFrame.new(0, 0.1, 0), C.Frame, M.Metal, true)
	for _, x in ipairs({ -1.4, 1.4 }) do p(m, "RubberFoot", Vector3.new(0.3, 0.06, 0.5), cframe * CFrame.new(x, 0.03, 0), C.Rubber, M.Rubber) end
	p(m, "Post", Vector3.new(0.45, 4.4, 0.45), cframe * CFrame.new(0, 2.3, 0), C.Frame, M.Metal, true)
	p(m, "PostCap", Vector3.new(0.5, 0.08, 0.5), cframe * CFrame.new(0, 4.54, 0), hex("#111113"), M.Plastic)
	loads = loads or { { 55, 45 }, { 45, 35 }, { 25, 25 }, { 25, 10 }, { 10, 5 }, { 5, 5 } }
	for i = 1, 6 do
		local y = ({ 1.3, 1.3, 2.6, 2.6, 3.8, 3.8 })[i]
		local side = i % 2 == 1 and 1 or -1
		local horn = cframe * CFrame.new(0, y, 0) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0) * CFrame.Angles(0, 0, rad(8))
		cyl(m, "Horn", 1.3, 0.24, horn * CFrame.new(0.85, 0, 0), C.Steel, M.Metal)
		GymKit.loadHorn(m, horn * CFrame.new(0.25, 0, 0), loads[i] or {})
	end
	return m
end

-- Dumbbell rack: two angled tiers with pairs of round-head dumbbells, heavier toward one end.
function GymKit.dumbbellRack(parent, cframe, length)
	length = length or 9
	local m = model(parent, "DumbbellRack", cframe)
	for _, x in ipairs({ -length / 2 + 0.2, 0, length / 2 - 0.2 }) do
		p(m, "Leg", Vector3.new(0.3, 2.6, 0.3), cframe * CFrame.new(x, 1.3, 0.6), C.Frame, M.Metal, true)
		p(m, "Leg", Vector3.new(0.3, 1.6, 0.3), cframe * CFrame.new(x, 0.8, -0.6), C.Frame, M.Metal, true)
		p(m, "Foot", Vector3.new(0.4, 0.15, 2), cframe * CFrame.new(x, 0.08, 0), C.Frame, M.Metal, true)
	end
	local tiers = { { y = 1.55, z = -0.45, tilt = 12 }, { y = 2.55, z = 0.45, tilt = 12 } }
	for t, tier in ipairs(tiers) do
		local shelf = cframe * CFrame.new(0, tier.y, tier.z) * CFrame.Angles(rad(tier.tilt), 0, 0)
		p(m, "Shelf", Vector3.new(length, 0.12, 0.9), shelf, C.Frame, M.Metal, true)
		p(m, "ShelfLip", Vector3.new(length, 0.2, 0.06), shelf * CFrame.new(0, 0.1, 0.45), C.Frame, M.Metal)
		local count = math.floor(length / 1.1)
		for i = 1, count do
			local x = -length / 2 + 0.55 + (i - 1) * 1.1
			local size = 0.38 + 0.05 * (i + (t - 1) * count) / 2
			local db = shelf * CFrame.new(x, 0.06 + size / 2, 0) * CFrame.Angles(0, rad(90), 0)
			cyl(m, "Handle", 0.9, 0.12, db, C.Chrome, M.Metal)
			cyl(m, "Head", 0.24, size, db * CFrame.new(-0.42, 0, 0), hex("#1B1B1D"), M.Rubber)
			cyl(m, "Head", 0.24, size, db * CFrame.new(0.42, 0, 0), hex("#1B1B1D"), M.Rubber)
		end
	end
	return m
end

function GymKit.kettlebell(parent, cframe, size, accent)
	local m = model(parent, "Kettlebell", cframe)
	ball(m, "Bell", size, cframe * CFrame.new(0, size * 0.45, 0), hex("#1B1B1D"), M.Metal)
	p(m, "Flat", Vector3.new(size * 0.6, 0.04, size * 0.6), cframe * CFrame.new(0, 0.02, 0), hex("#1B1B1D"), M.Metal)
	local handle = cframe * CFrame.new(0, size * 0.95, 0)
	p(m, "Handle", Vector3.new(size * 0.55, 0.1, 0.1), handle * CFrame.new(0, size * 0.2, 0), C.Steel, M.Metal)
	p(m, "HandleSide", Vector3.new(0.1, size * 0.3, 0.1), handle * CFrame.new(-size * 0.25, 0.04, 0), C.Steel, M.Metal)
	p(m, "HandleSide", Vector3.new(0.1, size * 0.3, 0.1), handle * CFrame.new(size * 0.25, 0.04, 0), C.Steel, M.Metal)
	if accent then p(m, "Band", Vector3.new(size * 0.7, 0.05, size * 0.7), cframe * CFrame.new(0, size * 0.62, 0), accent, M.SmoothPlastic) end
	return m
end

function GymKit.foamRoller(parent, cframe)
	local m = model(parent, "FoamRoller", cframe)
	cyl(m, "Roller", 2.2, 0.55, cframe * CFrame.new(0, 0.28, 0), hex("#2A2A2E"), M.Foil)
	cyl(m, "EndCap", 0.04, 0.56, cframe * CFrame.new(1.1, 0.28, 0), hex("#3A3A3E"), M.Plastic)
	cyl(m, "EndCap", 0.04, 0.56, cframe * CFrame.new(-1.1, 0.28, 0), hex("#3A3A3E"), M.Plastic)
	return m
end

function GymKit.yogaMat(parent, cframe, color)
	local m = model(parent, "YogaMat", cframe)
	p(m, "Mat", Vector3.new(2.2, 0.06, 5.4), cframe * CFrame.new(0, 0.03, 0), color or hex("#2F3A36"), M.Rubber)
	cyl(m, "RolledEnd", 2.2, 0.35, cframe * CFrame.new(0, 0.18, -2.7), color or hex("#2F3A36"), M.Rubber)
	return m
end

------------------------------------------------------------------------
-- Cardio
------------------------------------------------------------------------
function GymKit.treadmill(parent, cframe, pro)
	local m = model(parent, "Treadmill", cframe)
	local frame = pro and C.Chrome or C.Frame
	p(m, "Deck", Vector3.new(2.6, 0.6, 6.4), cframe * CFrame.new(0, 0.35, 0), hex("#1F1F22"), M.Metal, true)
	p(m, "Belt", Vector3.new(1.9, 0.05, 5.6), cframe * CFrame.new(0, 0.66, 0.1), hex("#111112"), M.Fabric)
	for _, x in ipairs({ -1.15, 1.15 }) do
		p(m, "SideRail", Vector3.new(0.3, 0.08, 6.2), cframe * CFrame.new(x, 0.69, 0), hex("#3A3C40"), M.DiamondPlate)
		p(m, "Upright", Vector3.new(0.22, 4.2, 0.22), at(cframe, x, 2.55, -2.7, -12, 0, 0), frame, M.Metal, true)
		p(m, "HandRail", Vector3.new(0.14, 0.14, 1.6), cframe * CFrame.new(x, 3.6, -2.0), frame, M.Metal)
	end
	p(m, "MotorHood", Vector3.new(2.6, 0.7, 1), cframe * CFrame.new(0, 0.55, -3.0), hex("#2A2B2E"), M.Plastic, true)
	local console = cframe * CFrame.new(0, 4.6, -3.05) * CFrame.Angles(rad(-25), 0, 0)
	p(m, "Console", Vector3.new(2.6, 1.0, 0.3), console, hex("#202124"), M.Plastic)
	local screen = p(m, "Screen", Vector3.new(1.6, 0.6, 0.05), console * CFrame.new(0, 0.05, 0.16), C.Screen, M.Glass)
	p(m, "ScreenGlow", Vector3.new(1.2, 0.06, 0.02), console * CFrame.new(0, -0.15, 0.19), pro and C.Led or hex("#7FD0A0"), M.Neon)
	screen.Reflectance = 0.2
	p(m, "Bottle", Vector3.new(0.18, 0.5, 0.18), console * CFrame.new(1.1, 0.4, 0.1), hex("#BFD6DF"), M.Glass, false, { Transparency = 0.3 })
	return m
end

function GymKit.bike(parent, cframe)
	local m = model(parent, "Bike", cframe)
	p(m, "BaseFront", Vector3.new(1.8, 0.2, 0.35), cframe * CFrame.new(0, 0.1, -1.5), C.Frame, M.Metal, true)
	p(m, "BaseBack", Vector3.new(1.8, 0.2, 0.35), cframe * CFrame.new(0, 0.1, 1.5), C.Frame, M.Metal, true)
	p(m, "Spine", Vector3.new(0.3, 0.3, 3.2), cframe * CFrame.new(0, 0.35, 0), C.Frame, M.Metal, true)
	cyl(m, "Flywheel", 0.3, 1.6, cframe * CFrame.new(0, 1.1, -1.1), hex("#3A3C40"), M.Metal)
	p(m, "FlywheelCover", Vector3.new(0.4, 1.2, 1.2), cframe * CFrame.new(0, 1.2, -1.2), hex("#2A2B2E"), M.Plastic, true)
	p(m, "SeatPost", Vector3.new(0.25, 2.2, 0.25), at(cframe, 0, 1.4, 0.9, -15, 0, 0), C.Frame, M.Metal)
	p(m, "Seat", Vector3.new(0.7, 0.2, 1), cframe * CFrame.new(0, 2.55, 1.15), C.Pad, M.Leather)
	p(m, "HandlePost", Vector3.new(0.25, 2.6, 0.25), at(cframe, 0, 1.9, -1.3, 15, 0, 0), C.Frame, M.Metal)
	p(m, "Handlebar", Vector3.new(1.6, 0.14, 0.14), cframe * CFrame.new(0, 3.1, -1.6), hex("#1A1A1A"), M.Rubber)
	p(m, "Console", Vector3.new(0.8, 0.5, 0.15), at(cframe, 0, 3.35, -1.75, -30, 0, 0), C.Screen, M.Glass)
	for _, x in ipairs({ -0.45, 0.45 }) do p(m, "Pedal", Vector3.new(0.4, 0.08, 0.25), cframe * CFrame.new(x, 1.05, -0.3), hex("#1A1A1A"), M.Rubber) end
	return m
end

function GymKit.rower(parent, cframe)
	local m = model(parent, "Rower", cframe)
	p(m, "Rail", Vector3.new(0.5, 0.2, 7), cframe * CFrame.new(0, 0.8, 0.5), C.Chrome, M.Metal)
	p(m, "LegBack", Vector3.new(1.4, 0.7, 0.3), cframe * CFrame.new(0, 0.35, 3.8), C.Frame, M.Metal, true)
	cyl(m, "Fan", 0.8, 1.7, cframe * CFrame.new(0, 0.9, -3.4) * CFrame.Angles(0, rad(90), 0), hex("#2A2B2E"), M.Plastic, true)
	p(m, "Seat", Vector3.new(0.9, 0.2, 0.9), cframe * CFrame.new(0, 1.05, 1.2), C.Pad, M.Leather)
	p(m, "FootPlate", Vector3.new(1.4, 0.6, 0.15), at(cframe, 0, 1.0, -1.9, 30, 0, 0), hex("#2E2E33"), M.Plastic)
	p(m, "Handle", Vector3.new(1.3, 0.12, 0.12), cframe * CFrame.new(0, 1.25, -2.6), hex("#1A1A1A"), M.Rubber)
	p(m, "Monitor", Vector3.new(0.7, 0.5, 0.1), at(cframe, 0, 2.1, -2.9, -25, 0, 0), C.Screen, M.Glass)
	p(m, "MonitorArm", Vector3.new(0.1, 1.2, 0.1), cframe * CFrame.new(0, 1.5, -3.0), C.Chrome, M.Metal)
	return m
end

------------------------------------------------------------------------
-- Furniture and wall pieces
------------------------------------------------------------------------
-- Pendant: cord, cap, shade, warm bulb. Same look as the original starter gym pendants.
function GymKit.pendant(parent, position, ceilingY, shadows, color)
	local m = model(parent, "Pendant", CFrame.new(position))
	local cordLength = ceilingY - position.Y - 0.8
	p(m, "Cord", Vector3.new(0.08, cordLength, 0.08), CFrame.new(position + Vector3.new(0, 0.8 + cordLength / 2, 0)), C.Dark)
	p(m, "ShadeCap", Vector3.new(0.7, 0.35, 0.7), CFrame.new(position + Vector3.new(0, 0.7, 0)), C.Dark, M.Metal)
	local shade = cyl(m, "Shade", 1.6, 1.6, CFrame.new(position) * CFrame.Angles(0, 0, rad(90)), C.Dark, M.Metal)
	shade.Size = Vector3.new(0.9, 1.7, 1.7)
	local bulb = ball(m, "Bulb", 0.55, CFrame.new(position - Vector3.new(0, 0.35, 0)), color or C.Bulb, M.Neon)
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Brightness, glow.Range, glow.Color, glow.Shadows = 0.25, 12, C.Warm, false
	glow.Parent = bulb
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Brightness, spot.Range, spot.Angle, spot.Color, spot.Shadows = 3.2, 32, 120, C.Warm, shadows == true
	spot.Parent = bulb
	return m
end

function GymKit.fillLight(parent, position, range, brightness, color)
	local part = p(parent, "Fill", Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), C.Steel, M.SmoothPlastic, false, { Transparency = 1 })
	local light = Instance.new("PointLight")
	light.Brightness, light.Range, light.Color, light.Shadows = brightness or 0.55, range or 18, color or C.Warm, false
	light.Parent = part
	return part
end

-- Framed poster: backing board, frame on four sides, a mat, the text and a small accent bar. Faces local -Z.
function GymKit.poster(parent, cframe, lines, w, h, accent)
	local m = model(parent, "Poster", cframe)
	p(m, "Backing", Vector3.new(w, h, 0.06), cframe, hex("#121214"), M.SmoothPlastic)
	local frame = hex("#2E2A26")
	p(m, "FrameTop", Vector3.new(w + 0.2, 0.12, 0.12), cframe * CFrame.new(0, h / 2, -0.03), frame, M.Wood)
	p(m, "FrameBottom", Vector3.new(w + 0.2, 0.12, 0.12), cframe * CFrame.new(0, -h / 2, -0.03), frame, M.Wood)
	p(m, "FrameLeft", Vector3.new(0.12, h, 0.12), cframe * CFrame.new(-w / 2, 0, -0.03), frame, M.Wood)
	p(m, "FrameRight", Vector3.new(0.12, h, 0.12), cframe * CFrame.new(w / 2, 0, -0.03), frame, M.Wood)
	local board = p(m, "Print", Vector3.new(w - 0.3, h - 0.3, 0.02), cframe * CFrame.new(0, 0, -0.045), hex("#1A1A1C"), M.SmoothPlastic)
	p(m, "Accent", Vector3.new((w - 0.3) * 0.3, 0.07, 0.01), cframe * CFrame.new(-(w - 0.3) * 0.35 + 0.1, -h / 2 + 0.45, -0.06), accent or C.Red, M.SmoothPlastic)
	p(m, "Nail", Vector3.new(0.08, 0.08, 0.08), cframe * CFrame.new(0, h / 2 + 0.25, 0.02), C.Steel, M.Metal)
	p(m, "Wire", Vector3.new(w * 0.5, 0.03, 0.02), cframe * CFrame.new(0, h / 2 + 0.12, 0.03), C.Steel, M.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.8)
	label.Position = UDim2.fromScale(0, 0.04)
	label.BackgroundTransparency = 1
	label.Text = lines
	label.TextColor3 = C.Chalk
	label.FontFace = Theme.Fonts.SemiBold
	label.TextScaled = true -- world-space poster
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0), UDim.new(0.1, 0), UDim.new(0.05, 0)
	pad.Parent = label
	return m
end

-- Wall mirror panel with a metal frame (faces local -Z). Glass reflects a little.
function GymKit.mirror(parent, cframe, w, h)
	local m = model(parent, "MirrorPanel", cframe)
	local glass = p(m, "Mirror", Vector3.new(w, h, 0.08), cframe, hex("#42464A"), M.Glass, false, { Reflectance = 0.35, Transparency = 0.05 })
	glass.CanQuery = false
	local frame = hex("#28282C")
	p(m, "FrameTop", Vector3.new(w + 0.3, 0.18, 0.2), cframe * CFrame.new(0, h / 2, -0.04), frame, M.Metal)
	p(m, "FrameBottom", Vector3.new(w + 0.3, 0.18, 0.2), cframe * CFrame.new(0, -h / 2, -0.04), frame, M.Metal)
	p(m, "FrameLeft", Vector3.new(0.18, h, 0.2), cframe * CFrame.new(-w / 2, 0, -0.04), frame, M.Metal)
	p(m, "FrameRight", Vector3.new(0.18, h, 0.2), cframe * CFrame.new(w / 2, 0, -0.04), frame, M.Metal)
	return m
end

function GymKit.wallClock(parent, cframe)
	local m = model(parent, "WallClock", cframe)
	cyl(m, "Rim", 0.15, 1.9, cframe * CFrame.Angles(0, rad(90), 0), C.Dark, M.Metal)
	cyl(m, "Face", 0.04, 1.65, cframe * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, rad(90), 0), C.Chalk, M.SmoothPlastic)
	for i = 0, 11 do
		local a = rad(i * 30)
		p(m, "Tick", Vector3.new(0.05, i % 3 == 0 and 0.2 or 0.1, 0.02), cframe * CFrame.new(math.sin(a) * 0.68, math.cos(a) * 0.68, -0.09) * CFrame.Angles(0, 0, -a), C.Dark)
	end
	p(m, "HourHand", Vector3.new(0.06, 0.45, 0.02), cframe * CFrame.new(0.1, 0.17, -0.1) * CFrame.Angles(0, 0, rad(-35)), C.Dark)
	p(m, "MinuteHand", Vector3.new(0.04, 0.65, 0.02), cframe * CFrame.new(-0.2, 0.22, -0.11) * CFrame.Angles(0, 0, rad(45)), C.Dark)
	p(m, "Center", Vector3.new(0.08, 0.08, 0.03), cframe * CFrame.new(0, 0, -0.12), C.Red)
	return m
end

function GymKit.wallFan(parent, cframe)
	local m = model(parent, "WallFan", cframe)
	p(m, "Mount", Vector3.new(0.6, 0.6, 0.2), cframe, C.Dark, M.Metal)
	p(m, "Arm", Vector3.new(0.18, 0.18, 0.9), cframe * CFrame.new(0, 0, -0.5), C.Dark, M.Metal)
	local head = cframe * CFrame.new(0, -0.2, -1.05) * CFrame.Angles(rad(-15), 0, 0)
	cyl(m, "Cage", 0.5, 2.2, head * CFrame.Angles(0, rad(90), 0), hex("#2A2A2E"), M.DiamondPlate)
	cyl(m, "Motor", 0.6, 0.7, head * CFrame.new(0, 0, 0.4) * CFrame.Angles(0, rad(90), 0), C.Dark, M.Metal)
	for i = 0, 2 do p(m, "Blade", Vector3.new(0.3, 0.9, 0.03), head * CFrame.Angles(0, 0, rad(i * 120)) * CFrame.new(0, 0.45, -0.05), hex("#3A3A3E"), M.Metal) end
	return m
end

function GymKit.speaker(parent, cframe)
	local m = model(parent, "Speaker", cframe)
	p(m, "Box", Vector3.new(1.2, 1.8, 1.0), cframe, C.Dark, M.SmoothPlastic)
	p(m, "Grille", Vector3.new(1.0, 1.6, 0.04), cframe * CFrame.new(0, 0, -0.51), hex("#2A2A2E"), M.DiamondPlate)
	cyl(m, "Woofer", 0.05, 0.75, cframe * CFrame.new(0, -0.3, -0.54) * CFrame.Angles(0, rad(90), 0), hex("#141414"), M.SmoothPlastic)
	cyl(m, "Tweeter", 0.05, 0.3, cframe * CFrame.new(0, 0.45, -0.54) * CFrame.Angles(0, rad(90), 0), hex("#141414"), M.SmoothPlastic)
	p(m, "Bracket", Vector3.new(0.2, 0.2, 0.6), cframe * CFrame.new(0, 0.95, 0.4), C.Steel, M.Metal)
	return m
end

function GymKit.trashCan(parent, cframe)
	local m = model(parent, "TrashCan", cframe)
	cyl(m, "Can", 2.2, 1.2, cframe * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, rad(90)), hex("#2A2B2E"), M.Metal, true)
	cyl(m, "Rim", 0.1, 1.26, cframe * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, rad(90)), C.Steel, M.Metal)
	cyl(m, "Bag", 0.04, 1.12, cframe * CFrame.new(0, 2.19, 0) * CFrame.Angles(0, 0, rad(90)), hex("#151515"), M.Plastic)
	return m
end

function GymKit.bench(parent, cframe, length)
	local m = model(parent, "Bench", cframe)
	p(m, "Seat", Vector3.new(length, 0.25, 1.3), cframe * CFrame.new(0, 1.55, 0), C.Wood, M.Wood, true)
	for i = -1, 1, 2 do
		p(m, "SeatSlat", Vector3.new(length, 0.02, 0.05), cframe * CFrame.new(0, 1.68, i * 0.32), hex("#4E3624"), M.Wood)
		p(m, "Leg", Vector3.new(0.2, 1.45, 1.1), cframe * CFrame.new(i * (length / 2 - 0.5), 0.72, 0), C.Frame, M.Metal, true)
	end
	p(m, "Stretcher", Vector3.new(length - 1, 0.15, 0.15), cframe * CFrame.new(0, 0.35, 0), C.Frame, M.Metal)
	return m
end

function GymKit.towelRack(parent, cframe)
	local m = model(parent, "TowelRack", cframe)
	for _, x in ipairs({ -1.4, 1.4 }) do
		p(m, "Side", Vector3.new(0.12, 4.2, 0.12), cframe * CFrame.new(x, 2.1, 0), C.Steel, M.Metal, true)
		p(m, "Foot", Vector3.new(0.12, 0.1, 1.4), cframe * CFrame.new(x, 0.05, 0), C.Steel, M.Metal)
	end
	for i, y in ipairs({ 1.2, 2.3, 3.4 }) do
		p(m, "Shelf", Vector3.new(2.9, 0.08, 1.1), cframe * CFrame.new(0, y, 0), C.Steel, M.Metal)
		for j = 0, 2 - (i == 3 and 1 or 0) do
			local towel = cframe * CFrame.new(-0.9 + j * 0.9, y + 0.2, 0)
			p(m, "Towel", Vector3.new(0.8, 0.32, 0.9), towel, i == 2 and hex("#E8E6DF") or hex("#D9D6CE"), M.Fabric)
			p(m, "Fold", Vector3.new(0.82, 0.02, 0.92), towel * CFrame.new(0, 0.05, 0), hex("#C9C6BE"), M.Fabric)
		end
	end
	return m
end

function GymKit.waterFountain(parent, cframe)
	local m = model(parent, "WaterFountain", cframe)
	p(m, "Body", Vector3.new(1.8, 3.2, 1.1), cframe * CFrame.new(0, 1.6, 0), hex("#B8BBC2"), M.Metal, true)
	p(m, "Panel", Vector3.new(1.5, 2.4, 0.04), cframe * CFrame.new(0, 1.5, -0.56), hex("#9EA2A8"), M.DiamondPlate)
	p(m, "Basin", Vector3.new(1.8, 0.2, 1.4), cframe * CFrame.new(0, 3.3, -0.15), C.Chrome, M.Metal)
	p(m, "Bowl", Vector3.new(1.4, 0.05, 1.0), cframe * CFrame.new(0, 3.42, -0.15), hex("#6E7378"), M.Metal)
	p(m, "Spout", Vector3.new(0.12, 0.25, 0.12), cframe * CFrame.new(0.3, 3.55, -0.2), C.Chrome, M.Metal)
	p(m, "Button", Vector3.new(0.3, 0.3, 0.08), cframe * CFrame.new(0.6, 3.1, -0.58), hex("#1F5FBF"), M.SmoothPlastic)
	p(m, "BottleFiller", Vector3.new(1.2, 1.4, 0.4), cframe * CFrame.new(0, 4.6, 0.3), hex("#B8BBC2"), M.Metal)
	p(m, "FillerScreen", Vector3.new(0.6, 0.2, 0.02), cframe * CFrame.new(0, 5.1, 0.09), hex("#7FD0A0"), M.Neon)
	m:SetAttribute("NpcSpot", "Water")
	return m
end

-- Reception desk: a counter with a top, kick plate, a front panel with the GYM ARC sign, and things on top.
function GymKit.frontDesk(parent, cframe, length)
	local m = model(parent, "FrontDesk", cframe)
	length = length or 9
	p(m, "Counter", Vector3.new(length, 3.6, 1.6), cframe * CFrame.new(0, 1.8, 0), hex("#26221F"), M.Wood, true)
	p(m, "Top", Vector3.new(length + 0.3, 0.2, 1.9), cframe * CFrame.new(0, 3.7, 0.05), C.Wood, M.WoodPlanks, true)
	p(m, "Kick", Vector3.new(length, 0.35, 1.5), cframe * CFrame.new(0, 0.17, 0.1), C.Dark, M.Metal)
	p(m, "LowerShelf", Vector3.new(length - 0.4, 0.15, 1.0), cframe * CFrame.new(0, 2.6, 1.1), C.Wood, M.Wood)
	-- slatted front panel
	for i = 0, math.floor(length / 0.6) - 1 do
		p(m, "Slat", Vector3.new(0.36, 3.0, 0.08), cframe * CFrame.new(-length / 2 + 0.3 + i * 0.6, 1.9, -0.84), C.Wood, M.Wood)
	end
	-- sign panel with a soft backlight
	local sign, label = Kit.sign(m, "DeskSign", Vector3.new(3.6, 1.0, 0.1), cframe * CFrame.new(0, 2.1, -0.95) * CFrame.Angles(0, math.pi, 0), "GYM ARC", C.Chalk, hex("#161618"), 60)
	sign.Name = "DeskSign"
	label.FontFace = Theme.Fonts.SemiBold
	p(m, "SignGlow", Vector3.new(3.8, 0.05, 0.05), cframe * CFrame.new(0, 1.55, -0.97), C.Warm, M.Neon)
	-- on top: a register screen, a bell, a stack of towels and a plant
	p(m, "Monitor", Vector3.new(1.3, 0.85, 0.08), at(cframe, -2.4, 4.3, 0.3, -8, 180, 0), hex("#141416"), M.SmoothPlastic)
	p(m, "MonitorStand", Vector3.new(0.12, 0.5, 0.12), cframe * CFrame.new(-2.4, 4.0, 0.35), C.Dark, M.Metal)
	p(m, "Bell", Vector3.new(0.35, 0.2, 0.35), cframe * CFrame.new(1.2, 3.9, -0.3), hex("#C9A64B"), M.Metal)
	for i = 0, 2 do p(m, "Towel", Vector3.new(0.9, 0.18, 0.7), cframe * CFrame.new(2.6, 3.9 + i * 0.19, 0.1), hex("#E8E6DF"), M.Fabric) end
	cyl(m, "PlantPot", 0.6, 0.6, cframe * CFrame.new(-3.6, 4.1, 0) * CFrame.Angles(0, 0, rad(90)), hex("#3A3A3D"), M.Concrete)
	for i = 0, 4 do
		p(m, "Leaf", Vector3.new(0.12, 0.9, 0.35), cframe * CFrame.new(-3.6, 4.6, 0) * CFrame.Angles(rad(math.sin(i) * 25), rad(i * 72), rad(15)), hex("#3E6B3F"), M.Grass)
	end
	return m
end

function GymKit.lockers(parent, cframe, count)
	local m = model(parent, "Lockers", cframe)
	for i = 0, count - 1 do
		local x = -(count - 1) * 0.75 + i * 1.5
		p(m, "Locker", Vector3.new(1.45, 6.4, 1.6), cframe * CFrame.new(x, 3.3, 0), hex("#2A2D31"), M.Metal, true)
		p(m, "Door", Vector3.new(1.3, 6.1, 0.05), cframe * CFrame.new(x, 3.3, -0.82), hex("#33373C"), M.Metal)
		for v = 0, 3 do p(m, "Vent", Vector3.new(0.8, 0.05, 0.02), cframe * CFrame.new(x, 5.8 + v * 0.14, -0.85), hex("#16181A"), M.Metal) end
		p(m, "Handle", Vector3.new(0.08, 0.5, 0.06), cframe * CFrame.new(x + 0.45, 3.4, -0.87), C.Chrome, M.Metal)
		p(m, "NumberPlate", Vector3.new(0.4, 0.2, 0.02), cframe * CFrame.new(x, 5.4, -0.86), C.Chrome, M.Metal)
	end
	p(m, "Plinth", Vector3.new(count * 1.5, 0.15, 1.7), cframe * CFrame.new(0, 0.07, 0), hex("#141416"), M.Metal)
	p(m, "Crown", Vector3.new(count * 1.5 + 0.1, 0.15, 1.75), cframe * CFrame.new(0, 6.55, 0), hex("#141416"), M.Metal)
	return m
end

function GymKit.chalkBowl(parent, cframe)
	local m = model(parent, "ChalkBowl", cframe)
	p(m, "Stand", Vector3.new(0.3, 2.6, 0.3), cframe * CFrame.new(0, 1.3, 0), C.Frame, M.Metal, true)
	p(m, "Base", Vector3.new(1.4, 0.12, 1.4), cframe * CFrame.new(0, 0.06, 0), C.Frame, M.Metal)
	cyl(m, "Bowl", 0.5, 1.5, cframe * CFrame.new(0, 2.85, 0) * CFrame.Angles(0, 0, rad(90)), hex("#2A2B2E"), M.Metal)
	cyl(m, "Chalk", 0.05, 1.3, cframe * CFrame.new(0, 3.08, 0) * CFrame.Angles(0, 0, rad(90)), C.Chalk, M.Sand)
	ball(m, "ChalkBlock", 0.45, cframe * CFrame.new(0.2, 3.12, 0.1), C.Chalk, M.Sand)
	return m
end

function GymKit.gymBag(parent, cframe, color)
	local m = model(parent, "GymBag", cframe)
	cyl(m, "Bag", 1.8, 0.9, cframe * CFrame.new(0, 0.45, 0), color or hex("#1E2A3A"), M.Fabric)
	p(m, "Strap", Vector3.new(1.2, 0.05, 0.12), cframe * CFrame.new(0, 0.92, 0), hex("#141414"), M.Fabric)
	p(m, "Zip", Vector3.new(1.6, 0.03, 0.03), cframe * CFrame.new(0, 0.9, -0.18), C.Steel, M.Metal)
	return m
end

function GymKit.plant(parent, cframe, height)
	local m = model(parent, "Plant", cframe)
	height = height or 4
	cyl(m, "Pot", 1.4, 1.4, cframe * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, rad(90)), hex("#3A3A3D"), M.Concrete, true)
	cyl(m, "Soil", 0.05, 1.25, cframe * CFrame.new(0, 1.41, 0) * CFrame.Angles(0, 0, rad(90)), hex("#2B1F17"), M.Ground)
	for i = 0, 8 do
		local a = i * 40
		p(m, "Leaf", Vector3.new(0.2, height * 0.55, 0.7), cframe * CFrame.new(0, 1.4 + height * 0.25, 0) * CFrame.Angles(0, rad(a), rad(18 + (i % 3) * 8)) * CFrame.new(0, height * 0.12, 0), i % 2 == 0 and hex("#3E6B3F") or hex("#4C7D45"), M.Grass)
	end
	return m
end

return GymKit
