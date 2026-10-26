-- BeachSkateUpgrade (owner, 26 Oct: "make the beach gym way better and skatepark too"). Decoration on top of the two builds,
-- one Model each: Workspace.Town.BeachGym.Upgrade and Workspace.Town.SkatePark.Upgrade (delete one to undo it). Run in
-- Studio (edit mode): Upgrade.Run(). Running it again rebuilds both.
--   Beach gym: timber edging and gold lines on the mats, tiki torches (fire + a soft light, no shadows), festoon lights
--   round the flag poles, a big BEACH GYM board on the entrance arch, surfboard racks and umbrellas + loungers on free sand.
--   Skate park: the ramp sides painted (teal / orange / violet / red, one colour a ramp), a dark plaza with a white outline
--   and coloured corners in the middle, bulbs along the fence, two strings of lights between the floodlights, a SKATE PARK
--   arch over the entrance.
-- Nothing added collides, is hit by rays or touches (CanCollide / CanQuery / CanTouch off), so machines, skating, walking
-- and the camera work as before. The only change to existing parts: the skate ramps' Cheek / DeckBlock colours (the old
-- colour is kept in their "OrigColor" attribute; the whole builds before this are in ServerStorage.*Backup_26Oct).
local Upgrade = {}

local root = nil

local function hex(h) return Color3.fromHex(h) end

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
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

-- nothing of anyone else's in this box (props only go on free sand)
local function isFree(cf, size)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root, workspace.Terrain }
	return #workspace:GetPartBoundsInBox(cf, size, params) == 0
end

-- a string of bulbs hanging from a to b (sags `sag` studs in the middle)
local WARM = { "#FFD27A", "#FFE9B0", "#FF9E5E", "#FFD27A", "#7FE0D8", "#F56FA1" }
local function festoon(a, b, sag, every, colors)
	local len = (b - a).Magnitude
	local function at(t) return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0) end
	local segs = math.max(4, math.floor(len / 6))
	for i = 0, segs - 1 do
		local p0, p1 = at(i / segs), at((i + 1) / segs)
		part({ Name = "Wire", Size = Vector3.new(0.08, 0.08, (p1 - p0).Magnitude), CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
			Color = hex("#1E1E22") })
	end
	local n = math.max(2, math.floor(len / every))
	for i = 1, n - 1 do
		part({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Position = at(i / n) - Vector3.new(0, 0.3, 0),
			Color = hex(colors[(i - 1) % #colors + 1]), Material = Enum.Material.Neon })
	end
end

-- a board with big gold words on both faces (the game's gold gradient)
local function signBoard(cf, size, text, board, edge)
	local b = part({ Name = "SignBoard", Size = size, CFrame = cf, Color = hex(board), Material = Enum.Material.Wood })
	part({ Name = "SignEdge", Size = size + Vector3.new(0.4, 0.4, -0.1), CFrame = cf, Color = hex(edge), Material = Enum.Material.Neon })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Words" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.2
		gui.Parent = b
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = text
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.08, 0)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
		pad.Parent = label
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex("#FFF3C4")), ColorSequenceKeypoint.new(0.5, hex("#F6C75A")),
			ColorSequenceKeypoint.new(1, hex("#C98A12")) })
		grad.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 5
		stroke.Color = hex("#2A1A08")
		stroke.Parent = label
	end
	return b
end

------------------------------------------------------------------------
-- Beach gym
------------------------------------------------------------------------
local function torch(x, z)
	local y = groundY(x, z)
	part({ Name = "TorchPole", Size = Vector3.new(0.5, 6, 0.5), CFrame = CFrame.new(x, y + 3, z), Color = hex("#8A6238"), Material = Enum.Material.Wood })
	for _, h in ipairs({ 1.4, 3.1, 4.8 }) do
		part({ Name = "TorchBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 0.64, 0.64),
			CFrame = CFrame.new(x, y + h, z) * CFrame.Angles(0, 0, math.rad(90)), Color = hex("#4E3522"), Material = Enum.Material.Wood })
	end
	local cup = part({ Name = "TorchCup", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 1.1, 1.1),
		CFrame = CFrame.new(x, y + 6.4, z) * CFrame.Angles(0, 0, math.rad(90)), Color = hex("#2B2B2B"), Material = Enum.Material.Metal })
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 3, 6
	fire.Color, fire.SecondaryColor = hex("#FF8A2A"), hex("#FFD36B")
	fire.Parent = cup
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Shadows = 14, 1.3, false
	light.Color = hex("#FFB45E")
	light.Parent = cup
end

local BOARDS = { { "#FF6B4A", "#FFFFFF" }, { "#2EC4B6", "#FFE9B0" }, { "#FFD23F", "#FF6B4A" }, { "#7B61FF", "#FFFFFF" } }
local function surfRack(x, z)
	local y = groundY(x, z)
	for _, dx in ipairs({ -4.6, 4.6 }) do
		part({ Name = "RackPost", Size = Vector3.new(0.5, 4.6, 0.5), CFrame = CFrame.new(x + dx, y + 2.3, z), Color = hex("#8A6238"), Material = Enum.Material.Wood })
	end
	part({ Name = "RackBar", Size = Vector3.new(9.8, 0.4, 0.5), CFrame = CFrame.new(x, y + 4.3, z), Color = hex("#6E4C2C"), Material = Enum.Material.Wood })
	local tilt = math.rad(18)
	for i, dx in ipairs({ -3.3, -1.1, 1.1, 3.3 }) do
		local base = Vector3.new(x + dx, y, z - 1.25)
		local center = base + Vector3.new(0, math.cos(tilt), math.sin(tilt)) * 3.5
		local cf = CFrame.new(center) * CFrame.Angles(tilt, 0, 0)
		local board = part({ Name = "Surfboard", Size = Vector3.new(2, 7, 0.3), CFrame = cf, Color = hex(BOARDS[i][1]) })
		Instance.new("SpecialMesh", board).MeshType = Enum.MeshType.Sphere
		local stripe = part({ Name = "SurfStripe", Size = Vector3.new(0.3, 6.3, 0.34), CFrame = cf, Color = hex(BOARDS[i][2]) })
		Instance.new("SpecialMesh", stripe).MeshType = Enum.MeshType.Sphere
	end
end

local UMBRELLAS = { { "#FF6B4A", "#FFF6E8" }, { "#2EC4B6", "#FFF6E8" }, { "#FFD23F", "#FF6B4A" }, { "#7B61FF", "#FFF6E8" } }
local function umbrella(x, z, colors)
	local y = groundY(x, z)
	part({ Name = "UmbrellaPole", Size = Vector3.new(0.3, 7.4, 0.3), CFrame = CFrame.new(x, y + 3.7, z) * CFrame.Angles(0, 0, math.rad(6)),
		Color = hex("#F2EEE6"), Material = Enum.Material.Metal })
	for i, layer in ipairs({ { 8, 6.9 }, { 5.6, 7.2 }, { 3.2, 7.5 } }) do
		part({ Name = "Canopy", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, layer[1], layer[1]),
			CFrame = CFrame.new(x - 0.4, y + layer[2], z) * CFrame.Angles(0, 0, math.rad(90)), Color = hex(colors[(i - 1) % 2 + 1]),
			Material = Enum.Material.Fabric })
	end
	part({ Name = "Finial", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Position = Vector3.new(x - 0.4, y + 7.8, z),
		Color = hex("#F2EEE6") })
	-- two loungers with towels
	for _, side in ipairs({ -1, 1 }) do
		local lx = x + side * 2.2
		local cf = CFrame.new(lx, y + 0.9, z + 0.5)
		part({ Name = "Lounger", Size = Vector3.new(1.9, 0.25, 5.2), CFrame = cf, Color = hex("#F2EEE6") })
		part({ Name = "LoungerBack", Size = Vector3.new(1.9, 0.25, 2), CFrame = cf * CFrame.new(0, 0.7, 2.7) * CFrame.Angles(math.rad(-40), 0, 0),
			Color = hex("#F2EEE6") })
		for _, leg in ipairs({ { -0.8, -2.3 }, { 0.8, -2.3 }, { -0.8, 2.3 }, { 0.8, 2.3 } }) do
			part({ Name = "LoungerLeg", Size = Vector3.new(0.15, 0.8, 0.15), CFrame = cf * CFrame.new(leg[1], -0.45, leg[2]), Color = hex("#C9CCD2"),
				Material = Enum.Material.Metal })
		end
		part({ Name = "Towel", Size = Vector3.new(1.6, 0.06, 3.6), CFrame = cf * CFrame.new(0, 0.16, -0.5), Color = hex(colors[1]),
			Material = Enum.Material.Fabric })
	end
end

local function beachGym()
	local gym = workspace.Town.BeachGym
	local old = gym:FindFirstChild("Upgrade")
	if old then old:Destroy() end
	root = Instance.new("Model")
	root.Name = "Upgrade"
	root:SetAttribute("Note", "tools/builders/BeachSkateUpgrade (26 Oct): decoration only, delete to undo")
	root.Parent = gym

	-- timber edging and a gold inset line on every mat
	for _, mat in ipairs(gym:GetChildren()) do
		if mat:IsA("BasePart") and (mat.Name == "Mat" or mat.Name == "FreeWeightMat" or mat.Name == "CaliMat") then
			local sx, sz = mat.Size.X, mat.Size.Z
			local top = mat.Size.Y / 2
			for _, e in ipairs({ { 0, sz / 2 + 0.35, sx + 1.4, 0.7 }, { 0, -sz / 2 - 0.35, sx + 1.4, 0.7 },
				{ sx / 2 + 0.35, 0, 0.7, sz }, { -sx / 2 - 0.35, 0, 0.7, sz } }) do
				part({ Name = "Edging", Size = Vector3.new(e[3], 0.45, e[4]), CFrame = mat.CFrame * CFrame.new(e[1], top + 0.05 - 0.225 + 0.2, e[2]),
					Color = hex("#B8935F"), Material = Enum.Material.WoodPlanks })
			end
			local inset = 1.2
			for _, l in ipairs({ { 0, sz / 2 - inset, sx - 2 * inset, 0.35 }, { 0, -sz / 2 + inset, sx - 2 * inset, 0.35 },
				{ sx / 2 - inset, 0, 0.35, sz - 2 * inset }, { -sx / 2 + inset, 0, 0.35, sz - 2 * inset } }) do
				part({ Name = "MatLine", Size = Vector3.new(l[3], 0.04, l[4]), CFrame = mat.CFrame * CFrame.new(l[1], top + 0.02, l[2]),
					Color = hex("#F6C75A") })
			end
		end
	end

	-- tiki torches outside the corners of the two big mats
	local spots = {}
	for _, mat in ipairs(gym:GetChildren()) do
		if mat:IsA("BasePart") and (mat.Name == "FreeWeightMat" or mat.Name == "CaliMat") then
			for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
				local p = mat.CFrame * Vector3.new(c[1] * (mat.Size.X / 2 + 1.6), 0, c[2] * (mat.Size.Z / 2 + 1.6))
				table.insert(spots, p)
			end
		end
	end
	for _, p in ipairs(spots) do
		if isFree(CFrame.new(p.X, 3.5, p.Z), Vector3.new(1, 6, 1)) then torch(p.X, p.Z) end
	end

	-- festoon lights round the four flag poles (the front split at the entrance arch)
	local poles = {}
	for _, p in ipairs(gym:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "FlagPole" then table.insert(poles, p) end
	end
	local function corner(sx, sz)
		for _, p in ipairs(poles) do
			if math.sign(p.Position.X - 16) == sx and math.sign(p.Position.Z - 206) == sz then return Vector3.new(p.Position.X, 10.5, p.Position.Z) end
		end
		return nil
	end
	local fl, fr, bl, br = corner(-1, -1), corner(1, -1), corner(-1, 1), corner(1, 1)
	local arch = gym:FindFirstChild("ArchBeam")
	if fl and fr and bl and br then
		festoon(bl, br, 1.6, 3.2, WARM)
		festoon(fl, bl, 1.2, 3.2, WARM)
		festoon(fr, br, 1.2, 3.2, WARM)
		if arch then
			local half = arch.Size.X / 2
			festoon(fl, Vector3.new(arch.Position.X - half, 11.2, fl.Z), 1, 3.2, WARM)
			festoon(Vector3.new(arch.Position.X + half, 11.2, fr.Z), fr, 1.4, 3.2, WARM)
		else
			festoon(fl, fr, 1.6, 3.2, WARM)
		end
	end

	-- the big BEACH GYM board standing on the entrance arch
	if arch then
		local top = 0
		for _, b in ipairs(gym:GetChildren()) do
			if b.Name == "ArchBeam" and b:IsA("BasePart") then top = math.max(top, b.Position.Y + b.Size.Y / 2) end
		end
		signBoard(CFrame.new(arch.Position.X, top + 1.9, arch.Position.Z), Vector3.new(15, 3.6, 0.5), "BEACH GYM", "#3A2A1C", "#FFB45E")
	end

	-- surfboard racks and umbrellas on free sand round the gym
	local racks = 0
	for _, c in ipairs({ { 22, 244 }, { 46, 244 }, { -12, 244 }, { 62, 244 }, { 78, 230 } }) do
		if racks < 2 and isFree(CFrame.new(c[1], groundY(c[1], c[2]) + 4.5, c[2]), Vector3.new(11, 8, 4)) then
			surfRack(c[1], c[2])
			racks += 1
		end
	end
	local umbrellas = 0
	for _, c in ipairs({ { -50, 190 }, { 80, 190 }, { -50, 214 }, { 80, 214 }, { 34, 252 }, { 6, 252 }, { 58, 252 }, { -52, 236 } }) do
		if umbrellas < 4 and isFree(CFrame.new(c[1], groundY(c[1], c[2]) + 4.5, c[2]), Vector3.new(9, 8, 8)) then
			umbrellas += 1
			umbrella(c[1], c[2], UMBRELLAS[umbrellas])
		end
	end
	return { parts = #root:GetDescendants(), racks = racks, umbrellas = umbrellas, torches = #spots }
end

------------------------------------------------------------------------
-- Skate park
------------------------------------------------------------------------
local RAMP_COLORS = { "#23A6A0", "#F08A24", "#8B5CF6", "#E5484D" }

local function skatePark()
	local park = workspace.Town.SkatePark
	local old = park:FindFirstChild("Upgrade")
	if old then old:Destroy() end
	root = Instance.new("Model")
	root.Name = "Upgrade"
	root:SetAttribute("Note", "tools/builders/BeachSkateUpgrade (26 Oct): decoration only, delete to undo")
	root.Parent = park
	local slab = park:FindFirstChild("Slab")
	local slabTop = slab.Position.Y + slab.Size.Y / 2

	-- the ramp sides: one colour a ramp (nearest deck)
	local decks = {}
	for _, d in ipairs(park:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "Deck" then table.insert(decks, d) end
	end
	table.sort(decks, function(a, b) return a.Position.X < b.Position.X end)
	for _, p in ipairs(park:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Cheek" or p.Name == "DeckBlock") then
			local best, bestD = 1, math.huge
			for i, d in ipairs(decks) do
				local dist = ((p.Position - d.Position) * Vector3.new(1, 0, 1)).Magnitude
				if dist < bestD then best, bestD = i, dist end
			end
			if p:GetAttribute("OrigColor") == nil then p:SetAttribute("OrigColor", p.Color) end
			p.Color = hex(RAMP_COLORS[(best - 1) % #RAMP_COLORS + 1])
		end
	end

	-- the dark plaza in the middle (the painted circles are lifted onto it so they still show)
	local cx, cz, sx, sz = -122, 199, 50, 40
	part({ Name = "Plaza", Size = Vector3.new(sx, 0.04, sz), CFrame = CFrame.new(cx, slabTop + 0.02, cz), Color = hex("#5B636E"),
		Material = Enum.Material.Concrete })
	for _, l in ipairs({ { 0, sz / 2, sx, 0.5 }, { 0, -sz / 2, sx, 0.5 }, { sx / 2, 0, 0.5, sz }, { -sx / 2, 0, 0.5, sz } }) do
		part({ Name = "PlazaLine", Size = Vector3.new(l[3], 0.05, l[4]), CFrame = CFrame.new(cx + l[1], slabTop + 0.03, cz + l[2]), Color = hex("#F2EEE6") })
	end
	for i, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, z = cx + c[1] * (sx / 2 - 2.5), cz + c[2] * (sz / 2 - 2.5)
		local color = hex(RAMP_COLORS[i])
		part({ Name = "PlazaCorner", Size = Vector3.new(4, 0.06, 0.8), CFrame = CFrame.new(x - c[1] * 0.0, slabTop + 0.035, z + c[2] * 1.6), Color = color })
		part({ Name = "PlazaCorner", Size = Vector3.new(0.8, 0.06, 4), CFrame = CFrame.new(x + c[1] * 1.6, slabTop + 0.035, z), Color = color })
	end
	for _, p in ipairs(park:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Paint" or p.Name == "PaintRing" or p.Name == "PaintHub") then
			local r = p.CFrame
			local halfY = math.abs(r.RightVector.Y) * p.Size.X / 2 + math.abs(r.UpVector.Y) * p.Size.Y / 2 + math.abs(r.LookVector.Y) * p.Size.Z / 2
			local need = slabTop + 0.06 + (if p.Name == "Paint" then 0 elseif p.Name == "PaintRing" then 0.01 else 0.02)
			if p.Position.Y + halfY < need then p.CFrame = p.CFrame + Vector3.new(0, need - (p.Position.Y + halfY), 0) end
		end
	end

	-- bulbs along the top of the fence
	local colors = { "#FFD27A", "#23A6A0", "#F08A24", "#8B5CF6", "#E5484D" }
	local k = 0
	for _, rail in ipairs(park:GetChildren()) do
		if rail:IsA("BasePart") and rail.Name == "FenceRail" then
			local long = if rail.Size.X >= rail.Size.Z then rail.CFrame.RightVector * rail.Size.X else rail.CFrame.LookVector * rail.Size.Z
			local n = math.floor(long.Magnitude / 4)
			for i = 0, n do
				k += 1
				local p = rail.Position - long / 2 + long * (i / math.max(n, 1))
				part({ Name = "FenceBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), Position = p + Vector3.new(0, rail.Size.Y / 2 + 0.25, 0),
					Color = hex(colors[k % #colors + 1]), Material = Enum.Material.Neon })
			end
		end
	end

	-- two strings of lights crossing between the floodlights
	local lamps = {}
	for _, f in ipairs(park:GetChildren()) do
		if f:IsA("BasePart") and f.Name == "Floodlight" then table.insert(lamps, Vector3.new(f.Position.X, f.Position.Y - 1.6, f.Position.Z)) end
	end
	if #lamps == 4 then
		table.sort(lamps, function(a, b) return a.X + a.Z * 0.001 < b.X + b.Z * 0.001 end)
		-- lamps[1], lamps[2] = west pair, lamps[3], lamps[4] = east pair (each sorted by z)
		festoon(lamps[1], lamps[4], 3, 3.6, colors)
		festoon(lamps[2], lamps[3], 3, 3.6, colors)
	end

	-- the SKATE PARK arch over the entrance (the widest gap in the fence on the road side)
	local south = {}
	for _, p in ipairs(park:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "FencePost" and p.Position.Z < 176 then table.insert(south, p.Position.X) end
	end
	table.sort(south)
	local gapA, gapB = nil, nil
	for i = 1, #south - 1 do
		if south[i + 1] - south[i] > 4 and (not gapA or south[i + 1] - south[i] > gapB - gapA) then gapA, gapB = south[i], south[i + 1] end
	end
	local ax0, ax1 = gapA or -127, gapB or -117
	local az = 174
	for _, x in ipairs({ ax0, ax1 }) do
		part({ Name = "ArchPost", Size = Vector3.new(0.9, 9.5, 0.9), CFrame = CFrame.new(x, slabTop + 4.75, az), Color = hex("#2B2C2F"), Material = Enum.Material.Metal })
		part({ Name = "ArchPostLight", Size = Vector3.new(0.3, 8.6, 0.95), CFrame = CFrame.new(x, slabTop + 4.6, az), Color = hex("#23A6A0"), Material = Enum.Material.Neon })
	end
	local mid = (ax0 + ax1) / 2
	local width = math.max(ax1 - ax0 + 3, 12)
	signBoard(CFrame.new(mid, slabTop + 10.3, az), Vector3.new(width, 3.2, 0.5), "SKATE PARK", "#1E1F24", "#F08A24")
	return { parts = #root:GetDescendants(), gap = string.format("%s..%s", tostring(gapA), tostring(gapB)), lamps = #lamps }
end

function Upgrade.Run()
	return { beach = beachGym(), skate = skatePark() }
end

return Upgrade
