-- Seasons builder (run once in Studio; see tools/bake.md): the seasonal decorations, stored as templates in
-- ServerStorage.SeasonDecor.<season id> (Halloween, Winter with the Sled Pull machine, Summer). SeasonService clones the
-- running season's folder into the gym (and tags the sled as a machine), so nothing shows outside its season.
local Builder = {}

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in pairs(props) do p[key] = value end
	p.Parent = parent
	return p
end

local function glow(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, brightness, range, false
	light.Parent = parent
end

-- Each season: a list of floor spots (x, z, y = surface height) and a function that builds one prop there.
local DECOR = {}

DECOR.Halloween = {
	spots = { { 16, 4.1, -8 }, { -6.5, 0.1, -6 }, { 6.5, 0.1, -6 }, { -21, 0.1, -46.5 }, { 21, 0.1, -46.5 }, { -9, 6, -6 } },
	build = function(parent, base)
		local pumpkin = part(parent, { Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5),
			Color = Color3.fromHex("#E8761C"), CFrame = CFrame.new(base + Vector3.new(0, 0.7, 0)) })
		pumpkin.Size = Vector3.new(1.6, 1.25, 1.6)
		part(parent, { Name = "Stem", Size = Vector3.new(0.18, 0.35, 0.18), Color = Color3.fromHex("#3E6B2A"),
			CFrame = CFrame.new(base + Vector3.new(0, 1.45, 0)) })
		glow(pumpkin, Color3.fromHex("#FF9A3C"), 0.8, 8) -- a soft jack-o-lantern glow
	end,
}

DECOR.Winter = {
	spots = { { -6.5, 0.1, -6 }, { 6.5, 0.1, -6 }, { -21, 0.1, -46.5 }, { 21, 0.1, -46.5 } },
	build = function(parent, base)
		local green = Color3.fromHex("#2E5B3A")
		for i, size in ipairs({ 2.6, 2, 1.3 }) do
			part(parent, { Name = "Tree", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, size, size), Color = green,
				CFrame = CFrame.new(base + Vector3.new(0, 0.6 + (i - 1) * 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
		end
		local star = part(parent, { Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45),
			Color = Color3.fromHex("#E8C21C"), Material = Enum.Material.Neon, CFrame = CFrame.new(base + Vector3.new(0, 3.2, 0)) })
		glow(star, Color3.fromHex("#FFE7A8"), 0.6, 8)
		part(parent, { Name = "Snow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3, 3), Color = Color3.fromHex("#F4F1EA"),
			CFrame = CFrame.new(base + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	end,
}

DECOR.Summer = {
	spots = { { -6.5, 0.1, -6 }, { 6.5, 0.1, -6 }, { -21, 0.1, -46.5 }, { 21, 0.1, -46.5 } },
	build = function(parent, base)
		local colors = { "#D7262E", "#F4F1EA", "#1F5FBF", "#E8C21C" }
		local ball = part(parent, { Name = "BeachBall", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2),
			Color = Color3.fromHex(colors[1]), CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) })
		for i = 2, #colors do
			part(parent, { Name = "Stripe", Size = Vector3.new(1.22, 0.25, 1.22), Shape = Enum.PartType.Cylinder,
				Color = Color3.fromHex(colors[i]), CFrame = ball.CFrame * CFrame.Angles(0, math.rad(60 * i), math.rad(90)) })
		end
		part(parent, { Name = "Towel", Size = Vector3.new(2.2, 0.05, 1.2), Color = Color3.fromHex("#1F5FBF"),
			CFrame = CFrame.new(base + Vector3.new(1.8, 0.03, 0)) })
	end,
}

local SLED_PIVOT = CFrame.new(-12, 0.1, -32) -- open floor between the rack area and the free-weight zone, facing +Z
local function buildSled(parent)
	local model = Instance.new("Model")
	model.Name = "SledPull"
	local steel, dark = Color3.fromHex("#9EA2A8"), Color3.fromHex("#1E1E22")
	part(model, { Name = "Turf", Size = Vector3.new(3.5, 0.06, 7), Color = Color3.fromHex("#2E5B3A"), Material = Enum.Material.Grass,
		CFrame = SLED_PIVOT * CFrame.new(0, 0.03, 1.5), CanCollide = false })
	part(model, { Name = "Sled", Size = Vector3.new(2.2, 0.4, 1.6), Color = dark, CFrame = SLED_PIVOT * CFrame.new(0, 0.3, 2.2), CanCollide = true })
	for _, x in ipairs({ -0.85, 0.85 }) do
		part(model, { Name = "Pole", Size = Vector3.new(0.18, 3.2, 0.18), Color = steel, Material = Enum.Material.Metal,
			CFrame = SLED_PIVOT * CFrame.new(x, 1.9, 1.7) * CFrame.Angles(math.rad(-20), 0, 0) })
	end
	-- the plates stack on the sled's pin
	part(model, { Name = "Bar", Size = Vector3.new(1.4, 0.2, 0.2), Color = steel, Material = Enum.Material.Metal,
		CFrame = SLED_PIVOT * CFrame.new(0, 0.9, 2.4) })
	model.WorldPivot = SLED_PIVOT
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Use", "Sled Pull"
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 8, false
	prompt.Parent = model:FindFirstChild("Sled")
	model:SetAttribute("MachineId", "SledPull")
	model.Parent = parent
end

function Builder.Build(_, ServerStorage)
	local old = ServerStorage:FindFirstChild("SeasonDecor")
	if old then old:Destroy() end
	local root = Instance.new("Folder")
	root.Name = "SeasonDecor"
	for seasonId, spec in pairs(DECOR) do
		local folder = Instance.new("Folder")
		folder.Name = seasonId
		for _, spot in ipairs(spec.spots) do
			spec.build(folder, Vector3.new(spot[1], spot[2], spot[3]))
		end
		if seasonId == "Winter" then buildSled(folder) end
		folder.Parent = root
	end
	root.Parent = ServerStorage
	return root
end

return Builder
