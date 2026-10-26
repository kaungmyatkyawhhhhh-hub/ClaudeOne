-- NightLamps (owner, 26 Oct: "the beach gym at night becomes too dark", "the skatepark also becomes too dark at night").
-- Run in Studio (edit mode): NightLamps.Run(). Running it again rebuilds them.
--   Beach gym: wooden lamp posts with a lantern round the two big mats (and by the pergola), in BeachGym.NightLamps.
--   Skate park: the 4 floodlights brighter and wider, and a lamp post in the middle of each side (SkatePark.NightLamps).
-- Every lantern bulb is a "NightLight" part (NightLightService): plain by day, glowing with its light on at night. No
-- light casts shadows (phones). Posts only go where nothing else stands; nothing collides except the post itself.
local NightLamps = {}

local function hex(h) return Color3.fromHex(h) end

local root = nil
local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "ClassName" then (p :: any)[k] = v end
	end
	p.Parent = props.Parent or root
	return p
end

local function groundY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return hit and hit.Position.Y or 0
end

local function isFree(x, z, height)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root, workspace.Terrain }
	local y = groundY(x, z)
	return #workspace:GetPartBoundsInBox(CFrame.new(x, y + height / 2 + 0.3, z), Vector3.new(1.4, height, 1.4), params) == 0
end

-- a night bulb (NightLightService): frosted by day, warm neon + its light at night
local function bulb(cf, size, range, brightness, color)
	local b = part({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = cf, Color = hex("#F2EEE6") })
	b:SetAttribute("DayColor", hex("#F2EEE6"))
	b:SetAttribute("NightColor", hex(color))
	b:AddTag("NightLight")
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Shadows, light.Enabled = range, brightness, hex(color), false, false
	light.Parent = b
	return b
end

-- a beach lamp post: a wooden post, a short arm and a lantern (frame + bulb)
local function beachLamp(x, z)
	local y = groundY(x, z)
	local post = part({ Name = "LampPost", Size = Vector3.new(0.6, 9, 0.6), CFrame = CFrame.new(x, y + 4.5, z), Color = hex("#7A5534"), Material = Enum.Material.Wood })
	post.CanCollide = true
	for _, h in ipairs({ 1.2, 4.5, 7.8 }) do
		part({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 0.74, 0.74), CFrame = CFrame.new(x, y + h, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = hex("#4E3522"), Material = Enum.Material.Wood })
	end
	part({ Name = "Cap", Size = Vector3.new(1.6, 0.25, 1.6), CFrame = CFrame.new(x, y + 9.1, z), Color = hex("#4E3522"), Material = Enum.Material.Wood })
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		part({ Name = "LanternFrame", Size = Vector3.new(0.12, 1.3, 0.12), CFrame = CFrame.new(x + c[1] * 0.6, y + 9.9, z + c[2] * 0.6), Color = hex("#2B2B2B"),
			Material = Enum.Material.Metal })
	end
	part({ Name = "LanternTop", Size = Vector3.new(1.5, 0.2, 1.5), CFrame = CFrame.new(x, y + 10.6, z), Color = hex("#2B2B2B"), Material = Enum.Material.Metal })
	bulb(CFrame.new(x, y + 9.9, z), 0.95, 26, 1.9, "#FFC27A")
end

-- a skate park lamp: a dark metal pole with a cool white lamp head
local function skateLamp(x, z)
	local y = groundY(x, z)
	local post = part({ Name = "LampPole", Size = Vector3.new(0.5, 11, 0.5), CFrame = CFrame.new(x, y + 5.5, z), Color = hex("#2B2C2F"), Material = Enum.Material.Metal })
	post.CanCollide = true
	part({ Name = "LampHead", Size = Vector3.new(1.4, 0.5, 1.4), CFrame = CFrame.new(x, y + 11.2, z), Color = hex("#2B2C2F"), Material = Enum.Material.Metal })
	bulb(CFrame.new(x, y + 10.75, z), 0.9, 34, 2.2, "#E8F1FF")
end

local function beachGym()
	local gym = workspace.Town.BeachGym
	local old = gym:FindFirstChild("NightLamps")
	if old then old:Destroy() end
	root = Instance.new("Model")
	root.Name = "NightLamps"
	root.Parent = gym
	local placed = 0
	local spots = {}
	for _, mat in ipairs(gym:GetChildren()) do
		if mat:IsA("BasePart") and (mat.Name == "FreeWeightMat" or mat.Name == "CaliMat") then
			for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { 0, 1 } }) do
				table.insert(spots, mat.CFrame * Vector3.new(c[1] * (mat.Size.X / 2 + 1.6), 0, c[2] * (mat.Size.Z / 2 + 1.6)))
			end
		end
	end
	-- by the pergola's mats (left of the boardwalk)
	for _, p in ipairs({ Vector3.new(-35, 0, 190), Vector3.new(-35, 0, 214), Vector3.new(-4, 0, 176), Vector3.new(-4, 0, 224) }) do table.insert(spots, p) end
	local used = {}
	for _, p in ipairs(spots) do
		local key = math.floor(p.X / 4) .. "," .. math.floor(p.Z / 4)
		if not used[key] then
			used[key] = true
			-- try the spot, then a little to each side
			for _, off in ipairs({ Vector3.zero, Vector3.new(1.5, 0, 0), Vector3.new(-1.5, 0, 0), Vector3.new(0, 0, 1.5), Vector3.new(0, 0, -1.5) }) do
				local q = p + off
				if isFree(q.X, q.Z, 10) then
					beachLamp(q.X, q.Z)
					placed += 1
					break
				end
			end
		end
	end
	return placed
end

local function skatePark()
	local park = workspace.Town.SkatePark
	local old = park:FindFirstChild("NightLamps")
	if old then old:Destroy() end
	root = Instance.new("Model")
	root.Name = "NightLamps"
	root.Parent = park
	-- the floodlights: brighter, wider, reaching the whole slab
	for _, lens in ipairs(park:GetChildren()) do
		if lens.Name == "FloodLens" then
			for _, light in ipairs(lens:GetChildren()) do
				if light:IsA("SpotLight") then
					light.Brightness, light.Range, light.Angle, light.Shadows = 2.8, 60, 120, false
				end
			end
		end
	end
	local placed = 0
	for _, p in ipairs({ Vector3.new(-122, 0, 171.5), Vector3.new(-122, 0, 240.5), Vector3.new(-166.5, 0, 206), Vector3.new(-77.5, 0, 206),
		Vector3.new(-143, 0, 171.5), Vector3.new(-101, 0, 171.5) }) do
		for _, off in ipairs({ Vector3.zero, Vector3.new(2, 0, 0), Vector3.new(-2, 0, 0), Vector3.new(0, 0, 1.5), Vector3.new(0, 0, -1.5) }) do
			local q = p + off
			if isFree(q.X, q.Z, 11) then
				skateLamp(q.X, q.Z)
				placed += 1
				break
			end
		end
	end
	return placed
end

function NightLamps.Run()
	return { beach = beachGym(), skate = skatePark() }
end

return NightLamps
