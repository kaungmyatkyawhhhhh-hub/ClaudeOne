-- ProGym builder (run once in Studio; see tools/bake.md): the pro gym room 150 studs south of the starter gym, its 11
-- machines, spotlights and the two doors (starter gym right wall <-> pro gym left wall). Output: Workspace.ProGymBuild.
-- ProGymService wires the doors (prompts "ProGymDoorPrompt" and "StarterDoorPrompt"); MachineService runs the
-- machines (tag "Machine", MachineId attribute, Use prompt, "Bar" weight stack).
-- BuildMachine is also used by the Town builder for the beach gym.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Machines = require(ReplicatedStorage.Shared.Config.Machines)

local ProGym = {}

ProGym.CENTER = Vector3.new(0, 0.1, -150) -- floor top at the middle of the room
ProGym.SIZE = Vector3.new(60, 14, 46)      -- width (x), height, depth (z)
ProGym.STARTER_DOOR = Vector3.new(27.85, 0.1, -16)

local hex, part = Kit.hex, Kit.part
local COLORS = {
	Wall = hex("#1B1B1E"), Floor = hex("#141416"), Ceiling = hex("#101012"),
	Steel = hex("#9EA2A8"), Pad = hex("#1E1E22"), Rubber = hex("#222226"),
	Neon = hex("#DCE6FF"), Light = hex("#EAF0FF"),
}

local function buildRoom(folder)
	local room = Instance.new("Model")
	room.Name = "ProGym"
	room.Parent = folder
	local c, s = ProGym.CENTER, ProGym.SIZE
	part(room, "Floor", Vector3.new(s.X, 1, s.Z), CFrame.new(c - Vector3.new(0, 0.5, 0)), COLORS.Floor, Enum.Material.Rubber)
	part(room, "Ceiling", Vector3.new(s.X + 2, 1, s.Z + 2), CFrame.new(c + Vector3.new(0, s.Y + 0.5, 0)), COLORS.Ceiling, Enum.Material.Concrete)
	local h = s.Y / 2
	part(room, "BackWall", Vector3.new(s.X + 2, s.Y, 1), CFrame.new(c + Vector3.new(0, h, -s.Z / 2 - 0.5)), COLORS.Wall, Enum.Material.Concrete)
	part(room, "FrontWall", Vector3.new(s.X + 2, s.Y, 1), CFrame.new(c + Vector3.new(0, h, s.Z / 2 + 0.5)), COLORS.Wall, Enum.Material.Concrete)
	part(room, "LeftWall", Vector3.new(1, s.Y, s.Z), CFrame.new(c + Vector3.new(-s.X / 2 - 0.5, h, 0)), COLORS.Wall, Enum.Material.Concrete)
	part(room, "RightWall", Vector3.new(1, s.Y, s.Z), CFrame.new(c + Vector3.new(s.X / 2 + 0.5, h, 0)), COLORS.Wall, Enum.Material.Concrete)
	-- neon LED strips along the bottom and top of every wall (no shadows, no collisions)
	local strip = { CanCollide = false, CastShadow = false, CanQuery = false }
	for _, y in ipairs({ 0.35, s.Y - 1.2 }) do
		part(room, "LedStrip", Vector3.new(s.X, 0.12, 0.12), CFrame.new(c + Vector3.new(0, y, -s.Z / 2 + 0.1)), COLORS.Neon, Enum.Material.Neon, strip)
		part(room, "LedStrip", Vector3.new(s.X, 0.12, 0.12), CFrame.new(c + Vector3.new(0, y, s.Z / 2 - 0.1)), COLORS.Neon, Enum.Material.Neon, strip)
		part(room, "LedStrip", Vector3.new(0.12, 0.12, s.Z), CFrame.new(c + Vector3.new(-s.X / 2 + 0.1, y, 0)), COLORS.Neon, Enum.Material.Neon, strip)
		part(room, "LedStrip", Vector3.new(0.12, 0.12, s.Z), CFrame.new(c + Vector3.new(s.X / 2 - 0.1, y, 0)), COLORS.Neon, Enum.Material.Neon, strip)
	end
	-- soft fill so the room is never pitch black between the spotlight pools
	for _, x in ipairs({ -15, 15 }) do
		local fill = part(room, "Fill", Vector3.new(1, 0.2, 1), CFrame.new(c + Vector3.new(x, s.Y - 0.2, 0)), COLORS.Ceiling, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 1 })
		local light = Instance.new("PointLight")
		light.Brightness, light.Range, light.Color, light.Shadows = 0.6, 30, COLORS.Light, false
		light.Parent = fill
	end
	local sign = Kit.sign(room, "ProGymSign", Vector3.new(14, 2.6, 0.2), CFrame.lookAt(c + Vector3.new(0, s.Y - 3, -s.Z / 2 + 0.15), c + Vector3.new(0, s.Y - 3, 0)), "PRO GYM", COLORS.Neon, COLORS.Wall, 50)
	sign.CanCollide = false
end

-- Machines: lifter at the pivot facing local +Z; the stack stands in front
local function stackFrame(model, pivot, z)
	part(model, "PostL", Vector3.new(0.3, 7, 0.3), pivot * CFrame.new(-0.95, 3.5, z), COLORS.Steel, Enum.Material.Metal)
	part(model, "PostR", Vector3.new(0.3, 7, 0.3), pivot * CFrame.new(0.95, 3.5, z), COLORS.Steel, Enum.Material.Metal)
	part(model, "Beam", Vector3.new(2.2, 0.3, 0.3), pivot * CFrame.new(0, 7, z), COLORS.Steel, Enum.Material.Metal)
	part(model, "Cable", Vector3.new(0.06, 5.4, 0.06), pivot * CFrame.new(0, 4.2, z - 0.1), hex("#2B2B2B"), Enum.Material.SmoothPlastic, { CanCollide = false })
	-- the weight stack pin: plates hang here (MachineService puts them on, centered)
	return part(model, "Bar", Vector3.new(1.7, 0.25, 0.25), pivot * CFrame.new(0, 1.4, z), COLORS.Steel, Enum.Material.Metal, { CanCollide = false })
end

local function sidePin(model, pivot)
	part(model, "PinPost", Vector3.new(0.3, 1.6, 0.3), pivot * CFrame.new(2.4, 0.8, 0), COLORS.Steel, Enum.Material.Metal)
	return part(model, "Bar", Vector3.new(1.2, 0.2, 0.2), pivot * CFrame.new(2.4, 1.5, 0), COLORS.Steel, Enum.Material.Metal, { CanCollide = false })
end

local BUILDERS = {}
BUILDERS.Dips = function(model, pivot)
	for _, x in ipairs({ -1.15, 1.15 }) do
		part(model, "Post", Vector3.new(0.3, 3.2, 0.3), pivot * CFrame.new(x, 1.6, 1.1), COLORS.Steel, Enum.Material.Metal)
		part(model, "Post", Vector3.new(0.3, 3.2, 0.3), pivot * CFrame.new(x, 1.6, -0.9), COLORS.Steel, Enum.Material.Metal)
		part(model, "Handle", Vector3.new(0.25, 0.25, 2.4), pivot * CFrame.new(x, 3.2, 0.1), COLORS.Steel, Enum.Material.Metal)
	end
	sidePin(model, pivot)
end
BUILDERS.LegCurl = function(model, pivot)
	part(model, "Pad", Vector3.new(1.6, 0.45, 5), pivot * CFrame.new(0, 1.55, 0), COLORS.Pad)
	part(model, "Support", Vector3.new(0.5, 1.3, 3), pivot * CFrame.new(0, 0.7, 0), COLORS.Steel, Enum.Material.Metal)
	stackFrame(model, pivot, 3.6)
end
BUILDERS.HipThrust = function(model, pivot)
	part(model, "Pad", Vector3.new(3, 0.6, 1.2), pivot * CFrame.new(0, 1.5, 1.6), COLORS.Pad)
	part(model, "Support", Vector3.new(2.6, 1.2, 0.8), pivot * CFrame.new(0, 0.6, 1.6), COLORS.Steel, Enum.Material.Metal)
	sidePin(model, pivot)
end
BUILDERS.HangingLegRaise = function(model, pivot)
	for _, x in ipairs({ -1.7, 1.7 }) do
		part(model, "Post", Vector3.new(0.3, 9.6, 0.3), pivot * CFrame.new(x, 4.8, 0), COLORS.Steel, Enum.Material.Metal)
	end
	part(model, "HangBar", Vector3.new(3.7, 0.2, 0.2), pivot * CFrame.new(0, 9, 0), COLORS.Steel, Enum.Material.Metal)
	sidePin(model, pivot)
end
BUILDERS.CalfRaise = function(model, pivot)
	part(model, "Step", Vector3.new(2.2, 0.3, 1.2), pivot * CFrame.new(0, 0.25, 0.6), COLORS.Rubber, Enum.Material.Rubber)
	stackFrame(model, pivot, 2.2)
end

-- One machine model (any gym): base, frame, "Bar", Use prompt, MachineId, tag "Machine".
function ProGym.BuildMachine(machine, pivot, parent)
	local model = Instance.new("Model")
	model.Name = machine.id
	part(model, "Base", Vector3.new(4.2, 0.1, 5.2), pivot * CFrame.new(0, 0.05, 0.5), COLORS.Rubber, Enum.Material.Rubber)
	local builder = BUILDERS[machine.id]
	if builder then builder(model, pivot) else stackFrame(model, pivot, 2.2) end
	model.WorldPivot = pivot
	Kit.prompt(model:FindFirstChild("Base"), "ProximityPrompt", "Use", machine.name, 8)
	model:SetAttribute("MachineId", machine.id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	CollectionService:AddTag(model, "Machine")
	return model
end

local function buildMachines(folder)
	local c, s = ProGym.CENTER, ProGym.SIZE
	local pro = {}
	for _, machine in ipairs(Machines.List) do
		if machine.gym == "Pro" then table.insert(pro, machine) end
	end
	-- back row (6) faces into the room; front row (5) faces back toward it
	local backZ, frontZ = c.Z - s.Z / 2 + 5, c.Z + s.Z / 2 - 7
	for index, machine in ipairs(pro) do
		local pivot
		if index <= 6 then
			pivot = CFrame.new(Vector3.new(-25 + (index - 1) * 10, c.Y, backZ)) -- facing +Z
		else
			pivot = CFrame.new(Vector3.new(-20 + (index - 7) * 10, c.Y, frontZ)) * CFrame.Angles(0, math.pi, 0) -- facing -Z
		end
		ProGym.BuildMachine(machine, pivot, folder)
		-- a spotlight pool over the machine; only every third casts shadows (phones)
		local fixture = part(folder, "Spot_" .. machine.id, Vector3.new(1.4, 0.3, 1.4), CFrame.new(pivot.Position + Vector3.new(0, s.Y - 0.3, 0)) * pivot.Rotation * CFrame.new(0, 0, 1),
			hex("#2B2B2B"), Enum.Material.Metal, { CanCollide = false })
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Brightness, light.Range, light.Angle, light.Color = 3, 22, 70, COLORS.Light
		light.Shadows = index % 3 == 1
		light.Parent = fixture
	end
end

local function door(parent, name, center, facing, title, subtitle)
	local model = Instance.new("Model")
	model.Name = name
	local look = CFrame.lookAt(center, center + facing)
	part(model, "DoorFrameTop", Vector3.new(5.4, 0.4, 0.5), look * CFrame.new(0, 8.4, 0), COLORS.Steel, Enum.Material.Metal)
	part(model, "DoorFrameL", Vector3.new(0.4, 8.4, 0.5), look * CFrame.new(-2.5, 4.2, 0), COLORS.Steel, Enum.Material.Metal)
	part(model, "DoorFrameR", Vector3.new(0.4, 8.4, 0.5), look * CFrame.new(2.5, 4.2, 0), COLORS.Steel, Enum.Material.Metal)
	local panel = part(model, "DoorPanel", Vector3.new(4.6, 8.2, 0.2), look * CFrame.new(0, 4.1, 0.05), hex("#141416"), Enum.Material.SmoothPlastic)
	part(model, "DoorLight", Vector3.new(4.6, 0.12, 0.12), look * CFrame.new(0, 8.05, -0.2), COLORS.Neon, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
	Kit.sign(model, "DoorSign", Vector3.new(5, 1.3, 0.15), look * CFrame.new(0, 9.5, -0.1), title, nil, COLORS.Wall, 50)
	Kit.prompt(panel, name .. "Prompt", "Enter", subtitle, 8)
	model.Parent = parent
end

function ProGym.Build(Workspace)
	local folder = Kit.fresh(Workspace, "Folder", "ProGymBuild")
	buildRoom(folder)
	buildMachines(folder)
	local unlock = Machines.GymUnlock.Pro or 2
	-- starter gym, right wall: faces into the starter gym (-X); pro gym, left wall: faces into the pro gym (+X)
	door(folder, "ProGymDoor", ProGym.STARTER_DOOR, Vector3.new(-1, 0, 0), "Pro gym", "Pro gym · Growth Spurt " .. unlock)
	door(folder, "StarterDoor", ProGym.CENTER + Vector3.new(-ProGym.SIZE.X / 2 + 0.15, 0, 0), Vector3.new(1, 0, 0), "Starter gym", "Back to the starter gym")
	return folder
end

return ProGym
