-- GymLighting builder (run once in Studio after Gyms; see tools/bake.md). The lighting pass for both gyms (owner,
-- 9 Oct: "make the gym lighting better"). The old setup was flat and muddy: weak wide pendants drowned by fill lights,
-- black brick walls, and the pro gym's spotlights washed out by its fills (their pools never showed).
-- What it does (running it again gives the same result):
--   Starter gym: pendants brighter and tighter (real warm pools on the floor, every third one casts shadows), the fill
--   lights dimmer and less orange, the high windows let in more daylight, the neon sign's spill kept subtle. New warm
--   wall washers (small black can lights on a bracket) graze the brick on the west and back walls, and three more
--   pendants light the centre aisle and the leg machines. Built in StarterGym.LightingPass.
--   Pro gym: spotlights brighter and tighter (pools over every machine, every third one casts shadows), fills and the
--   ceiling light bars turned down so the pools read; neutral wall washers light the east and back walls (ProGym.LightingPass).
-- Gyms.Build() runs it at the end. Lighting itself (Lighting service, post effects) is not touched.
local Workspace = game:GetService("Workspace")

local GymLighting = {}

local M = Enum.Material
local rad = math.rad
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local WARM = rgb(255, 201, 138) -- the pendants' warm bulb light (#FFC98A)
local FILL = rgb(255, 228, 196)
local WASH_WARM = rgb(255, 190, 130)
local WASH_NEUTRAL = rgb(255, 236, 214)
local FIXTURE = rgb(26, 26, 28)

GymLighting.Starter = {
	Pendant = { Brightness = 9, Range = 24, Angle = 90, ShadowEvery = 3 },
	Fill = { Brightness = 0.6, Range = 24, Color = FILL },
	Window = { Brightness = 2, Range = 20, Angle = 50 },
	Sign = { Brightness = 1.4, Range = 10 },
	Wash = { Brightness = 3, Range = 16, Angle = 100, Color = WASH_WARM },
	-- wall washers: on the west wall (x -44) between the high windows, on the back wall (z -89) clear of the windows
	-- and the GYM ARC sign. The east side is the glass wall to the pro gym.
	WestZ = { -8, -25, -45, -65, -84 },
	BackX = { -24, -13, 16, 26 },
	ExtraPendants = { Vector3.new(0, 10.6, -34), Vector3.new(0, 10.6, -52), Vector3.new(16, 10.6, -54) },
}
GymLighting.Pro = {
	Spot = { Brightness = 7, Range = 22, Angle = 60, ShadowEvery = 3 },
	Fill = { Brightness = 0.55, Color = rgb(255, 232, 205) },
	Bar = { Brightness = 0.6, Range = 16, Angle = 100 },
	Wash = { Brightness = 2.5, Range = 18, Angle = 90, Color = WASH_NEUTRAL },
	EastZ = { -15.5, -29.5, -43.5, -57.5, -71.5, -85.5 }, -- halfway between the wall's LED seams
	BackX = { 51, 59, 67, 75, 83, 91, 99, 107 },
}

local function part(parent, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.Metal
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- A wall washer: a plate on the wall, a short arm, a can tilted down toward the wall and a glowing lens; the SpotLight
-- shines from the lens along the can. `wallPoint` is on the wall's inner face, `normal` points into the room.
local function washer(parent, wallPoint: Vector3, normal: Vector3, spec)
	local m = Instance.new("Model")
	m.Name = "WallWasher"
	local base = CFrame.lookAt(wallPoint, wallPoint + normal) -- -Z = into the room
	part(m, "Plate", Vector3.new(0.5, 0.7, 0.08), base * CFrame.new(0, 0, -0.04), FIXTURE)
	part(m, "Arm", Vector3.new(0.12, 0.12, 0.9), base * CFrame.new(0, 0, -0.5), FIXTURE)
	local canPos = (base * CFrame.new(0, 0, -1)).Position
	local aim = (-normal * 0.35 + Vector3.new(0, -1, 0)).Unit -- down, grazing the wall
	local axis = CFrame.lookAt(canPos, canPos + aim) * CFrame.Angles(0, rad(90), 0) -- local +X along the aim
	part(m, "Can", Vector3.new(0.7, 0.45, 0.45), axis, FIXTURE, M.Metal, Enum.PartType.Cylinder)
	local lens = part(m, "Lens", Vector3.new(0.04, 0.36, 0.36), axis * CFrame.new(0.36, 0, 0), spec.Color, M.Neon, Enum.PartType.Cylinder)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Right
	light.Brightness, light.Range, light.Angle, light.Color, light.Shadows = spec.Brightness, spec.Range, spec.Angle, spec.Color, false
	light.Parent = lens
	m.PrimaryPart = m.Plate
	m.Parent = parent
	return m
end

local function freshFolder(parent, name)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function starter(Workspace, GymKit)
	local S = GymLighting.Starter
	local room = Workspace.Gym.StarterGym
	local pass = freshFolder(room, "LightingPass")
	-- pendants (the ones the Gyms builder made and the extra ones below), in a stable order for the shadow pattern
	local count = 0
	local function tunePendant(pendant)
		local bulb = pendant:FindFirstChild("Bulb")
		local spot = bulb and bulb:FindFirstChildOfClass("SpotLight")
		if not spot then return end
		count += 1
		spot.Brightness, spot.Range, spot.Angle, spot.Color = S.Pendant.Brightness, S.Pendant.Range, S.Pendant.Angle, WARM
		spot.Shadows = count % S.Pendant.ShadowEvery == 1
	end
	local pendants = room:FindFirstChild("Pendants", true)
	if pendants then for _, pendant in ipairs(pendants:GetChildren()) do tunePendant(pendant) end end
	local extra = Instance.new("Folder")
	extra.Name = "ExtraPendants"
	extra.Parent = pass
	for _, at in ipairs(S.ExtraPendants) do tunePendant(GymKit.pendant(extra, at, 16, false)) end
	for _, d in ipairs(room:GetDescendants()) do
		if d:IsA("PointLight") and d.Parent and d.Parent.Name == "Fill" then
			d.Brightness, d.Range, d.Color = S.Fill.Brightness, S.Fill.Range, S.Fill.Color
		elseif d:IsA("SurfaceLight") and d.Parent and d.Parent.Name == "Window" then
			d.Brightness, d.Range, d.Angle = S.Window.Brightness, S.Window.Range, S.Window.Angle
		elseif d:IsA("SurfaceLight") and d.Parent and d.Parent.Name == "NeonSignBack" then
			d.Brightness, d.Range = S.Sign.Brightness, S.Sign.Range
		end
	end
	local washers = Instance.new("Folder")
	washers.Name = "WallWashers"
	washers.Parent = pass
	for _, z in ipairs(S.WestZ) do washer(washers, Vector3.new(-44, 14.6, z), Vector3.new(1, 0, 0), S.Wash) end
	for _, x in ipairs(S.BackX) do washer(washers, Vector3.new(x, 14.6, -89), Vector3.new(0, 0, 1), S.Wash) end
	return count
end

local function pro(Workspace)
	local P = GymLighting.Pro
	local room = Workspace.ProGym
	local pass = freshFolder(room, "LightingPass")
	local spots = 0
	local spotFolder = room:FindFirstChild("Spotlights")
	if spotFolder then
		for _, fixture in ipairs(spotFolder:GetChildren()) do
			local lens = fixture:FindFirstChild("Lens")
			local light = lens and lens:FindFirstChildOfClass("SpotLight")
			if light then
				spots += 1
				light.Brightness, light.Range, light.Angle = P.Spot.Brightness, P.Spot.Range, P.Spot.Angle
				light.Shadows = spots % P.Spot.ShadowEvery == 1
			end
		end
	end
	for _, d in ipairs(room:GetDescendants()) do
		if d:IsA("PointLight") and d.Parent and d.Parent.Name == "FillLight" then
			d.Brightness, d.Color = P.Fill.Brightness, P.Fill.Color
		elseif d:IsA("SurfaceLight") and d.Parent and d.Parent.Name == "LightBar" then
			d.Brightness, d.Range, d.Angle = P.Bar.Brightness, P.Bar.Range, P.Bar.Angle
		end
	end
	local washers = Instance.new("Folder")
	washers.Name = "WallWashers"
	washers.Parent = pass
	for _, z in ipairs(P.EastZ) do washer(washers, Vector3.new(112.85, 16.4, z), Vector3.new(-1, 0, 0), P.Wash) end
	for _, x in ipairs(P.BackX) do washer(washers, Vector3.new(x, 16.4, -88.85), Vector3.new(0, 0, 1), P.Wash) end
	return spots
end

function GymLighting.Build(ws)
	ws = ws or Workspace
	local GymKit = require(script.Parent.GymKit)
	-- remove test lights from the tuning session if any are left
	for _, root in ipairs({ ws.Gym, ws.ProGym }) do
		local test = root:FindFirstChild("_WashTest")
		if test then test:Destroy() end
	end
	local pendants = starter(ws, GymKit)
	local spots = pro(ws)
	return ("starter pendants %d, pro spots %d"):format(pendants, spots)
end

return GymLighting
