-- ProGymPolish (run once in Studio, Edit mode; safe to re-run): fixes the pro gym's "weird" floor, lighting and windows.
--  * floor: charcoal rubber (not a glossy black slab) with a faint tile grid
--  * podium rim: a coloured neon ring instead of a white blown-out disc
--  * spotlights: softer, warmer; invisible ceiling fill lights so nothing is pitch black
--  * front windows: lighter, less tinted glass and dark gunmetal mullions (they were chalk-white bars on night-blue glass)
local pg = workspace.ProGym
local shell = pg.Shell

local floor = shell:FindFirstChild("Floor")
if floor then
	floor.Material = Enum.Material.Rubber
	floor.Color = Color3.fromRGB(48, 48, 54)
	floor.Reflectance = 0
	local old = pg:FindFirstChild("FloorTiles")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "FloorTiles"
	folder.Parent = pg
	local top = floor.Position.Y + floor.Size.Y / 2
	local minX, maxX = floor.Position.X - floor.Size.X / 2, floor.Position.X + floor.Size.X / 2
	local minZ, maxZ = floor.Position.Z - floor.Size.Z / 2, floor.Position.Z + floor.Size.Z / 2
	local function seam(size, position)
		local p = Instance.new("Part")
		p.Name = "TileSeam"
		p.Size = size
		p.Position = position
		p.Color = Color3.fromRGB(30, 30, 34)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Parent = folder
	end
	local x = minX + 4
	while x < maxX do
		seam(Vector3.new(0.08, 0.02, maxZ - minZ), Vector3.new(x, top + 0.01, (minZ + maxZ) / 2))
		x += 4
	end
	local z = minZ + 4
	while z < maxZ do
		seam(Vector3.new(maxX - minX, 0.02, 0.08), Vector3.new((minX + maxX) / 2, top + 0.01, z))
		z += 4
	end
end

local podium = shell:FindFirstChild("Podium") or pg:FindFirstChild("Podium", true)
if podium then
	for _, name in ipairs({ "Rim", "RimLow" }) do
		local part = podium:FindFirstChild(name)
		if part then part.Color = Color3.fromRGB(35, 95, 215) end
	end
end

local spotlights = pg:FindFirstChild("Spotlights")
if spotlights then
	for _, light in ipairs(spotlights:GetDescendants()) do
		if light:IsA("SpotLight") then
			light.Brightness = 2.4
			light.Color = Color3.fromRGB(255, 241, 222)
		end
	end
end

local oldFill = pg:FindFirstChild("FillLights")
if oldFill then oldFill:Destroy() end
local fill = Instance.new("Folder")
fill.Name = "FillLights"
fill.Parent = pg
for _, x in ipairs({ 50, 65, 80 }) do
	for _, z in ipairs({ -20, -40, -60 }) do
		local p = Instance.new("Part")
		p.Name = "FillLight"
		p.Size = Vector3.new(1, 1, 1)
		p.Position = Vector3.new(x, 11, z)
		p.Transparency = 1
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		local light = Instance.new("PointLight")
		light.Brightness = 0.9
		light.Range = 30
		light.Color = Color3.fromRGB(255, 236, 214)
		light.Shadows = false
		light.Parent = p
		p.Parent = fill
	end
end

for _, part in ipairs(shell:GetChildren()) do
	if part.Name == "CurtainGlass" then
		part.Color = Color3.fromRGB(150, 185, 210)
		part.Transparency = 0.55
	elseif part.Name == "CurtainMullion" or part.Name == "CurtainRail" then
		part.Color = Color3.fromRGB(40, 42, 48)
	end
end
