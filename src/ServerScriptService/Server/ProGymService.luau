-- The pro gym (opens at Growth Spurt 2): built from code at server start, away from the starter gym and reached
-- through a door on the starter gym's right wall (and back through an exit door). Dark walls and floor, neon LED
-- strips, a spotlight pool over every machine. The 11 machines (Config.Machines, gym = "Pro") are normal machine
-- models (tag "Machine", MachineId attribute, Use prompt, "Bar" weight stack), so MachineService runs them.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Machines = require(Config.Machines)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local ProGymService = {}

local CENTER = Vector3.new(0, 0.1, -150) -- floor top at the middle of the room
local SIZE = Vector3.new(60, 14, 46)      -- width (x), height, depth (z)
local COLORS = {
	Wall = Color3.fromHex("#1B1B1E"), Floor = Color3.fromHex("#141416"), Ceiling = Color3.fromHex("#101012"),
	Steel = Color3.fromHex("#9EA2A8"), Pad = Color3.fromHex("#1E1E22"), Rubber = Color3.fromHex("#222226"),
	Neon = Color3.fromHex("#DCE6FF"), Light = Color3.fromHex("#EAF0FF"),
}
-- the starter gym door (on its right wall) and where you arrive coming back
local STARTER_DOOR = Vector3.new(27.85, 0.1, -16)
local STARTER_ARRIVE = CFrame.lookAt(Vector3.new(24, 0.1, -16), Vector3.new(0, 0.1, -16))
local PRO_ARRIVE = CFrame.lookAt(CENTER + Vector3.new(-26, 0, 0), CENTER + Vector3.new(0, 0, 0))

local folder

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

local function sign(parent, name, size, cframe, text, textColor)
	local board = part(parent, name, size, cframe, COLORS.Wall, Enum.Material.SmoothPlastic, { CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Theme.Colors.Text
	label.FontFace = Theme.Fonts.SemiBold
	label.TextScaled = true -- sign on a wall: the only kind of screen text that may scale
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
	pad.Parent = label
	return board, label
end

------------------------------------------------------------------------
-- Room
------------------------------------------------------------------------
local function buildRoom()
	local room = Instance.new("Model")
	room.Name = "ProGym"
	room.Parent = folder
	local c, s = CENTER, SIZE
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

	-- "PRO GYM" sign on the back wall (the game's wordmark style, like GYM ARC)
	sign(room, "ProGymSign", Vector3.new(14, 2.6, 0.2), CFrame.lookAt(c + Vector3.new(0, s.Y - 3, -s.Z / 2 + 0.15), c + Vector3.new(0, s.Y - 3, 0)), "PRO GYM", COLORS.Neon)
	return room
end

------------------------------------------------------------------------
-- Machines (lifter at the pivot, facing local +Z; the stack stands in front)
------------------------------------------------------------------------
local function stackFrame(model, pivot, z)
	part(model, "PostL", Vector3.new(0.3, 7, 0.3), pivot * CFrame.new(-0.95, 3.5, z), COLORS.Steel, Enum.Material.Metal)
	part(model, "PostR", Vector3.new(0.3, 7, 0.3), pivot * CFrame.new(0.95, 3.5, z), COLORS.Steel, Enum.Material.Metal)
	part(model, "Beam", Vector3.new(2.2, 0.3, 0.3), pivot * CFrame.new(0, 7, z), COLORS.Steel, Enum.Material.Metal)
	part(model, "Cable", Vector3.new(0.06, 5.4, 0.06), pivot * CFrame.new(0, 4.2, z - 0.1), Color3.fromHex("#2B2B2B"), Enum.Material.SmoothPlastic, { CanCollide = false })
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
		-- handles at about hand height of a standing lifter (the dip pose then lowers the body)
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

-- Performance (phones): only every third spotlight casts shadows; the light pools are the same for all of them.
local SHADOW_EVERY = 3
local builtCount = 0

local function buildMachine(machine, pivot, parent, withSpotlight)
	builtCount += 1
	parent = parent or folder
	local model = Instance.new("Model")
	model.Name = machine.id
	part(model, "Base", Vector3.new(4.2, 0.1, 5.2), pivot * CFrame.new(0, 0.05, 0.5), COLORS.Rubber, Enum.Material.Rubber)
	local builder = BUILDERS[machine.id]
	if builder then
		builder(model, pivot)
	else
		stackFrame(model, pivot, 2.2)
	end
	model.WorldPivot = pivot
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use"
	prompt.ObjectText = machine.name
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:FindFirstChild("Base")
	model:SetAttribute("MachineId", machine.id)
	model.Parent = parent

	if withSpotlight == false then
		CollectionService:AddTag(model, "Machine")
		return model
	end
	-- a spotlight pool over the machine
	local fixture = part(folder, "Spot_" .. machine.id, Vector3.new(1.4, 0.3, 1.4), CFrame.new(pivot.Position + Vector3.new(0, SIZE.Y - 0.3, 0)) * pivot.Rotation * CFrame.new(0, 0, 1),
		Color3.fromHex("#2B2B2B"), Enum.Material.Metal, { CanCollide = false })
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness, light.Range, light.Angle, light.Color = 3, 22, 70, COLORS.Light
	light.Shadows = builtCount % SHADOW_EVERY == 1
	light.Parent = fixture

	CollectionService:AddTag(model, "Machine") -- MachineService sets up the prompt and plates from here
	return model
end

-- Other areas (the beach gym) build their machines the same way: (machine config, pivot CFrame, parent). No spotlight.
function ProGymService.BuildMachine(machine, pivot, parent)
	return buildMachine(machine, pivot, parent, false)
end

local function buildMachines()
	local pro = {}
	for _, machine in ipairs(Machines.List) do
		if machine.gym == "Pro" then table.insert(pro, machine) end
	end
	-- back row (6) faces into the room; front row (5) faces back toward it
	local backZ, frontZ = CENTER.Z - SIZE.Z / 2 + 5, CENTER.Z + SIZE.Z / 2 - 7
	for index, machine in ipairs(pro) do
		local pivot
		if index <= 6 then
			local x = -25 + (index - 1) * 10
			pivot = CFrame.new(Vector3.new(x, CENTER.Y, backZ)) -- facing +Z
		else
			local x = -20 + (index - 7) * 10
			pivot = CFrame.new(Vector3.new(x, CENTER.Y, frontZ)) * CFrame.Angles(0, math.pi, 0) -- facing -Z
		end
		buildMachine(machine, pivot)
	end
end

------------------------------------------------------------------------
-- Doors
------------------------------------------------------------------------
local lastUse = {}

local function teleport(player, cframe)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or humanoid.Sit or root.Anchored then return false end
	character:PivotTo(cframe + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	return true
end

local function door(parent, center, facing, title, subtitle, onUse)
	local look = CFrame.lookAt(center, center + facing)
	part(parent, "DoorFrameTop", Vector3.new(5.4, 0.4, 0.5), look * CFrame.new(0, 8.4, 0), COLORS.Steel, Enum.Material.Metal)
	part(parent, "DoorFrameL", Vector3.new(0.4, 8.4, 0.5), look * CFrame.new(-2.5, 4.2, 0), COLORS.Steel, Enum.Material.Metal)
	part(parent, "DoorFrameR", Vector3.new(0.4, 8.4, 0.5), look * CFrame.new(2.5, 4.2, 0), COLORS.Steel, Enum.Material.Metal)
	local panel = part(parent, "DoorPanel", Vector3.new(4.6, 8.2, 0.2), look * CFrame.new(0, 4.1, 0.05), Color3.fromHex("#141416"), Enum.Material.SmoothPlastic)
	part(parent, "DoorLight", Vector3.new(4.6, 0.12, 0.12), look * CFrame.new(0, 8.05, -0.2), COLORS.Neon, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
	sign(parent, "DoorSign", Vector3.new(5, 1.3, 0.15), look * CFrame.new(0, 9.5, -0.1), title) -- front face looks into the room
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = subtitle
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel
	Guard.OnTriggered(prompt, function(player)
		local now = os.clock()
		if now - (lastUse[player] or 0) < 1.5 then return end
		lastUse[player] = now
		onUse(player)
	end)
	return prompt
end

local function buildDoors()
	local unlock = Machines.GymUnlock.Pro or 2
	-- starter gym, right wall: faces into the starter gym (-X)
	door(folder, STARTER_DOOR, Vector3.new(-1, 0, 0), "Pro gym", "Pro gym · Growth Spurt " .. unlock, function(player)
		local data = PlayerData.Get(player)
		if not data then return end
		if data.growthSpurts < unlock then
			Remotes.PlayerEvent:FireClient(player, "ProGymLocked", { spurts = unlock })
			return
		end
		if teleport(player, PRO_ARRIVE) then
			Remotes.PlayerEvent:FireClient(player, "ProGymEntered", {})
		end
	end)
	-- pro gym, left wall: faces into the pro gym (+X)
	door(folder, CENTER + Vector3.new(-SIZE.X / 2 + 0.15, 0, 0), Vector3.new(1, 0, 0), "Starter gym", "Back to the starter gym", function(player)
		teleport(player, STARTER_ARRIVE)
	end)
end

function ProGymService.Start()
	folder = Instance.new("Folder")
	folder.Name = "ProGymBuild"
	folder.Parent = Workspace
	buildRoom()
	buildMachines()
	buildDoors()
	Players.PlayerRemoving:Connect(function(player) lastUse[player] = nil end)
end

return ProGymService
