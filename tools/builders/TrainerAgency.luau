-- TrainerAgency builder (prompt 27, 22 Oct; run once in Studio, Edit mode; was prompt 24's lit odds board on posts, see git
-- history). The owner: "it looks ugly and futuristic". ONE Trainer Agency, in the starter gym, made to look like a real
-- gym's personal-training desk, warm and old-school:
--   * the desk's white counter top becomes wood; the dark "PERSONAL TRAINERS" banner on two posts (and its small text) and
--     the neon-framed board above it go (into ServerStorage.AgencyBackup.StarterRemoved, not deleted);
--   * on the wall behind it: a cork board in a wood frame with the 8 trainers' photo cards pinned on it (their portraits,
--     Config/Trainers icon; the Secret one a covered card with "?"), a hand-lettered chalkboard sign "PERSONAL TRAINERS"
--     above it and a framed certificate beside it;
--   * on the counter: a desk lamp with a warm light (no neon), a small plant (the clipboard sign-up sheet, the shaker bottle,
--     the whistle and the stopwatch were already there).
--   * the Agency desks in the Pro gym and the Beach gym go to ServerStorage.AgencyBackup (untagged, "WasTags" attributes):
--     the Agency window works anywhere (the TRAINERS side button), so one stand is enough.
-- Everything new is decoration: anchored, no collisions, no queries, no shadows, flat on its surface.
-- The wall behind the desk is the starter gym's FrontWall (its face at z = -4.0, the desk faces -Z); the cork board sits
-- above the water fountain, over the framed poster (as the old board did) and clear of the lockers and the leaderboard wall.
-- Usage: paste into a ModuleScript and require it from the command bar: require(module).Build()
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Builder = {}

local WALL_Z = -4.0 -- the FrontWall's face behind the starter desk
local WOOD = Color3.fromHex("#8A5A33")
local DARK_WOOD = Color3.fromHex("#4E3220")
local CORK = Color3.fromHex("#C49563")
local SLATE = Color3.fromHex("#26302B")
local CREAM = Color3.fromHex("#F3EBDA")
local CHALK = Color3.fromHex("#EEEDE6")

local function deco(parent, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function surface(part: BasePart, pps: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 1
	gui.MaxDistance = 1000 -- (a SurfaceGui made by a script gets 0 here and doesn't draw)
	gui.Parent = part
	return gui
end

local function label(parent, text, font, color, size, position, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font
	l.TextColor3 = color
	l.TextScaled = true
	l.Size = size
	l.Position = position
	for k, v in pairs(props or {}) do (l :: any)[k] = v end
	l.Parent = parent
	return l
end

local function untag(root: Instance)
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, d in ipairs(all) do
		local tags = CollectionService:GetTags(d)
		if #tags > 0 then
			d:SetAttribute("WasTags", table.concat(tags, ","))
			for _, t in ipairs(tags) do CollectionService:RemoveTag(d, t) end
		end
	end
end

-- a wood frame of 4 strips around a rectangle (center, width, height) in front of the wall at depth z
local function frame(parent, cx, cy, w, h, z, thick, color)
	for _, spec in ipairs({ { 0, h / 2 + thick / 2, w + thick * 2, thick }, { 0, -h / 2 - thick / 2, w + thick * 2, thick },
		{ -w / 2 - thick / 2, 0, thick, h }, { w / 2 + thick / 2, 0, thick, h } }) do
		deco(parent, "Frame", Vector3.new(spec[3], spec[4], 0.14), CFrame.new(cx + spec[1], cy + spec[2], z), color, Enum.Material.Wood)
	end
end

function Builder.Build()
	local Trainers = require(game.ReplicatedStorage.Shared.Config.Trainers)
	local desk = Workspace.Gym.StarterGym.Feature_Trainers.TrainerDesk
	local backup = ServerStorage:FindFirstChild("AgencyBackup") or Instance.new("Folder")
	backup.Name = "AgencyBackup"
	backup.Parent = ServerStorage
	local report = {}

	-- the starter desk as it was (a copy), then the parts that go
	if not backup:FindFirstChild("StarterDeskBefore") then
		local copy = desk:Clone()
		copy.Name = "StarterDeskBefore"
		untag(copy)
		copy.Parent = backup
	end
	local removed = backup:FindFirstChild("StarterRemoved") or Instance.new("Folder")
	removed.Name = "StarterRemoved"
	removed.Parent = backup
	for _, child in ipairs(desk:GetChildren()) do
		if child.Name == "AgencyBoard" or child.Name == "SignBoard" or child.Name == "SignTrim" or child.Name == "Post" or child.Name == "PostFoot" then
			untag(child)
			child.Parent = removed
		end
	end
	-- the other gyms' desks
	for _, gym in ipairs({ Workspace:FindFirstChild("ProGym"), Workspace:FindFirstChild("Town") and Workspace.Town:FindFirstChild("BeachGym") }) do
		local feature = gym and gym:FindFirstChild("Feature_Trainers")
		local other = feature and feature:FindFirstChild("TrainerDesk")
		if other then
			other.Name = gym.Name .. "Desk"
			untag(other)
			other.Parent = backup
			table.insert(report, "moved " .. gym.Name .. " desk to ServerStorage.AgencyBackup")
		end
	end

	-- the counter top: wood
	local top = desk:FindFirstChild("CounterTop")
	if top then top.Material, top.Color = Enum.Material.Wood, WOOD end
	local edge = desk:FindFirstChild("CounterEdge")
	if edge then edge.Material, edge.Color = Enum.Material.Wood, DARK_WOOD end
	local panel = desk:FindFirstChild("FrontPanel")
	if panel then panel.Color = DARK_WOOD end

	local old = desk:FindFirstChild("PTStand")
	if old then old:Destroy() end
	local stand = Instance.new("Folder")
	stand.Name = "PTStand"
	stand.Parent = desk

	-- the cork board with the photo cards
	local CX, CY, CW, CH = -16.6, 7.15, 4.2, 2.6
	local corkZ = WALL_Z - 0.27 -- (in front of the framed poster it covers)
	deco(stand, "Cork", Vector3.new(CW, CH, 0.1), CFrame.new(CX, CY, corkZ), CORK, Enum.Material.Cardboard)
	frame(stand, CX, CY, CW, CH, corkZ - 0.02, 0.14, DARK_WOOD)
	local pinColors = { Color3.fromHex("#D8423A"), Color3.fromHex("#3A7BD8"), Color3.fromHex("#E8B93A"), Color3.fromHex("#3AAA5A") }
	local tilts = { -3, 2, -1.5, 3, 2.5, -2, 1.5, -3 }
	for i, trainer in ipairs(Trainers.List) do
		local rarity = Trainers.RarityById[trainer.rarity]
		local column, row = (i - 1) % 4, (i - 1) // 4
		local x = CX - (column - 1.5) * 0.98 -- (the viewer faces +Z: their left is +X, so the list reads left to right)
		local y = CY + (if row == 0 then 0.58 else -0.58)
		local card = deco(stand, "Photo_" .. trainer.id, Vector3.new(0.82, 1.0, 0.02),
			CFrame.new(x, y, corkZ - 0.065) * CFrame.Angles(0, 0, math.rad(tilts[i])), CREAM, Enum.Material.SmoothPlastic)
		local gui = surface(card, 120)
		local paper = Instance.new("Frame")
		paper.BackgroundColor3 = CREAM
		paper.BorderSizePixel = 0
		paper.Size = UDim2.fromScale(1, 1)
		paper.Parent = gui
		local photo = Instance.new("Frame")
		photo.BorderSizePixel = 0
		photo.Position = UDim2.fromScale(0.07, 0.06)
		photo.Size = UDim2.fromScale(0.86, 0.68)
		photo.ClipsDescendants = true
		photo.Parent = paper
		if rarity.hidden then
			-- the Secret one: a covered card with "?"
			photo.BackgroundColor3 = Color3.fromHex("#141417")
			label(photo, "?", Enum.Font.PermanentMarker, CHALK, UDim2.fromScale(0.7, 0.8), UDim2.fromScale(0.15, 0.1))
		else
			photo.BackgroundColor3 = Color3.fromHex(rarity.color):Lerp(Color3.new(1, 1, 1), 0.45)
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Image = trainer.icon or ""
			image.ScaleType = Enum.ScaleType.Fit
			image.AnchorPoint = Vector2.new(0.5, 1)
			image.Position = UDim2.fromScale(0.5, 1)
			image.Size = UDim2.fromScale(1, 0.95)
			image.Parent = photo
		end
		label(paper, if rarity.hidden then "???" else trainer.name, Enum.Font.PermanentMarker, Color3.fromHex("#2A2420"), UDim2.fromScale(0.9, 0.2),
			UDim2.fromScale(0.05, 0.76))
		-- a push pin at the top
		deco(stand, "Pin", Vector3.new(0.09, 0.09, 0.09), CFrame.new(x, y + 0.44, corkZ - 0.1), pinColors[(i - 1) % 4 + 1], Enum.Material.SmoothPlastic,
			Enum.PartType.Ball)
	end

	-- the chalkboard sign above it
	local SX, SY, SW, SH = CX, 9.25, 3.6, 1.15
	local slateZ = WALL_Z - 0.2
	local slate = deco(stand, "Chalkboard", Vector3.new(SW, SH, 0.08), CFrame.new(SX, SY, slateZ), SLATE, Enum.Material.Slate)
	frame(stand, SX, SY, SW, SH, slateZ - 0.02, 0.12, WOOD)
	local sgui = surface(slate, 100)
	label(sgui, "PERSONAL TRAINERS", Enum.Font.PermanentMarker, CHALK, UDim2.fromScale(0.9, 0.56), UDim2.fromScale(0.05, 0.1))
	label(sgui, "ask at the desk", Enum.Font.PermanentMarker, Color3.fromHex("#F2D27A"), UDim2.fromScale(0.5, 0.24), UDim2.fromScale(0.25, 0.68))

	-- the framed certificate (above the lockers)
	local FX, FY, FW, FH = -13.4, 7.3, 0.95, 0.72
	local paperPart = deco(stand, "Certificate", Vector3.new(FW, FH, 0.03), CFrame.new(FX, FY, WALL_Z - 0.06), CREAM, Enum.Material.SmoothPlastic)
	frame(stand, FX, FY, FW, FH, WALL_Z - 0.07, 0.07, DARK_WOOD)
	local cgui = surface(paperPart, 160)
	label(cgui, "CERTIFIED", Enum.Font.Garamond, Color3.fromHex("#5A4630"), UDim2.fromScale(0.8, 0.16), UDim2.fromScale(0.1, 0.1))
	label(cgui, "PERSONAL TRAINER", Enum.Font.Garamond, Color3.fromHex("#2A2420"), UDim2.fromScale(0.86, 0.22), UDim2.fromScale(0.07, 0.3),
		{ FontFace = Font.new(Font.fromEnum(Enum.Font.Garamond).Family, Enum.FontWeight.Bold) })
	local seal = Instance.new("Frame")
	seal.BackgroundColor3 = Color3.fromHex("#C98A12")
	seal.BorderSizePixel = 0
	seal.AnchorPoint = Vector2.new(0.5, 0.5)
	seal.Position = UDim2.fromScale(0.78, 0.74)
	seal.Size = UDim2.fromScale(0.2, 0.26)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = seal
	seal.Parent = cgui
	local line = Instance.new("Frame")
	line.BackgroundColor3 = Color3.fromHex("#5A4630")
	line.BorderSizePixel = 0
	line.Position = UDim2.fromScale(0.12, 0.8)
	line.Size = UDim2.fromScale(0.45, 0.02)
	line.Parent = cgui

	-- on the counter (its top at y = CounterTop top): a desk lamp with a warm light and a small plant
	local counterY = if top then top.Position.Y + top.Size.Y / 2 else 3.28
	local LX, LZ = -20.35, -6.85
	deco(stand, "LampBase", Vector3.new(0.06, 0.42, 0.42), CFrame.new(LX, counterY + 0.03, LZ) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("#B08A3A"),
		Enum.Material.Metal, Enum.PartType.Cylinder)
	deco(stand, "LampPole", Vector3.new(0.06, 0.95, 0.06), CFrame.new(LX, counterY + 0.5, LZ), Color3.fromHex("#B08A3A"), Enum.Material.Metal)
	deco(stand, "LampArm", Vector3.new(0.06, 0.06, 0.5), CFrame.new(LX, counterY + 0.95, LZ - 0.22), Color3.fromHex("#B08A3A"), Enum.Material.Metal)
	local shade = deco(stand, "LampShade", Vector3.new(0.22, 0.42, 0.42), CFrame.new(LX, counterY + 0.86, LZ - 0.45) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromHex("#2E5A3A"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local bulb = deco(stand, "LampBulb", Vector3.new(0.14, 0.14, 0.14), CFrame.new(LX, counterY + 0.74, LZ - 0.45), Color3.fromHex("#FFE7C2"),
		Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#FFC488")
	light.Brightness = 1.2
	light.Range = 9
	light.Shadows = false
	light.Parent = bulb
	local _ = shade
	local PX, PZ = -14.6, -6.75
	deco(stand, "PlantPot", Vector3.new(0.4, 0.36, 0.36), CFrame.new(PX, counterY + 0.2, PZ) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("#B5603A"),
		Enum.Material.Slate, Enum.PartType.Cylinder)
	deco(stand, "PlantSoil", Vector3.new(0.02, 0.32, 0.32), CFrame.new(PX, counterY + 0.4, PZ) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("#3B2A1E"),
		Enum.Material.Sand, Enum.PartType.Cylinder)
	for i, offset in ipairs({ Vector3.new(0, 0.62, 0), Vector3.new(0.13, 0.52, 0.05), Vector3.new(-0.12, 0.5, -0.06), Vector3.new(0.04, 0.5, 0.14), Vector3.new(-0.05, 0.55, -0.13) }) do
		deco(stand, "Leaf" .. i, Vector3.new(0.26, 0.26, 0.26), CFrame.new(PX + offset.X, counterY + offset.Y, PZ + offset.Z), Color3.fromHex("#3E7D3A"),
			Enum.Material.Grass, Enum.PartType.Ball)
	end
	table.insert(report, "starter PT stand built (" .. #stand:GetChildren() .. " parts)")
	return table.concat(report, "; ")
end

return Builder
