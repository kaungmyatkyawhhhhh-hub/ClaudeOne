-- MuscleBody: the visible muscles. Every body that shows muscles (player characters, the mirror's preview rigs, the
-- statue, NPC lifters) is an R15 model tagged "MuscleBody" with a few attributes (written by the server):
--   MuscleSteps  18 digits (Muscles.List order), each 0..Steps: how big that muscle is (its level toward the Growth
--                Spurt goal, in visible steps)
--   VeinStages   18 digits, 0..3: veins on strong muscles (70%+ of the level cap, 90%+, maxed)
--   BodyLook     "Gym" (tank top + shorts), "Own" (the avatar's own clothes) or "Marble" (the statue)
--   SkinColor / TopColor / BottomColor (Color3), VeinSeed (number, the owner's UserId), PumpedUntil (server time)
-- MuscleClient builds the shapes on each client (only when these change), welded and massless, so they move with the
-- body and never change movement or animations. Shapes are rounded (Ball parts) placed as fractions of each body
-- part's size, so they fit every height. The server-side helpers (BaseDescription, Encode*) live here too.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Muscles = require(Config.Muscles)

local MuscleBody = {}

MuscleBody.Tag = "MuscleBody"
MuscleBody.Steps = 6          -- visible size steps per muscle per Growth Spurt
MuscleBody.MinScale = 0.38    -- shape size at step 0 (mostly inside the body: small and flat)
MuscleBody.MaxVeinParts = 90  -- per body
MuscleBody.Folder = "MuscleParts"

-- One smooth Roblox-made base body for everyone (the "Roblox 2.0" body parts, creator Roblox).
MuscleBody.BaseBody = { Torso = 27112025, RightArm = 27112039, LeftArm = 27112052, LeftLeg = 27112056, RightLeg = 27112068 }

-- Gym look colors (original tank top + shorts, picked from the UserId so everyone looks a bit different)
MuscleBody.TopColors = { Color3.fromHex("#2E6E8E"), Color3.fromHex("#3C5A48"), Color3.fromHex("#C9473F"),
	Color3.fromHex("#E9E4D8"), Color3.fromHex("#2B2B2E"), Color3.fromHex("#D9A23A"), Color3.fromHex("#6C5A9E") }
MuscleBody.BottomColors = { Color3.fromHex("#26272B"), Color3.fromHex("#1E2A3A"), Color3.fromHex("#3A3A3D"), Color3.fromHex("#4A3A2E") }

------------------------------------------------------------------------
-- Shapes. pos / size are fractions of the body part's size (size = at the top step); x is the body's right (mirrored
-- for the left side), -z is the front. region: what covers it in the gym look ("skin", "top" = tank top, "bottom" =
-- shorts). Several balls of one color overlap into one smooth muscle (e.g. the three delt heads into a round cap).
------------------------------------------------------------------------
local SHAPES = {
	-- chest (tank top)
	{ muscle = "MidChest", part = "UpperTorso", side = true, pos = Vector3.new(0.23, 0.08, -0.36), size = Vector3.new(0.42, 0.3, 0.42), rot = Vector3.new(0, 0, 6), region = "top" },
	{ muscle = "UpperChest", part = "UpperTorso", side = true, pos = Vector3.new(0.21, 0.23, -0.33), size = Vector3.new(0.38, 0.2, 0.36), rot = Vector3.new(0, 0, -4), region = "top" },
	-- shoulders: three heads on top of the upper arm
	{ muscle = "FrontDelts", part = "UpperArm", side = true, pos = Vector3.new(0.02, 0.33, -0.22), size = Vector3.new(0.82, 0.52, 0.62), region = "skin" },
	{ muscle = "SideDelts", part = "UpperArm", side = true, pos = Vector3.new(0.2, 0.34, 0), size = Vector3.new(0.72, 0.56, 0.78), region = "skin" },
	{ muscle = "RearDelts", part = "UpperArm", side = true, pos = Vector3.new(0.02, 0.33, 0.22), size = Vector3.new(0.82, 0.52, 0.62), region = "skin" },
	-- back (tank top)
	{ muscle = "Traps", part = "UpperTorso", side = true, pos = Vector3.new(0.15, 0.42, 0.14), size = Vector3.new(0.34, 0.2, 0.42), rot = Vector3.new(0, 0, -22), region = "top" },
	{ muscle = "Lats", part = "UpperTorso", side = true, pos = Vector3.new(0.36, -0.02, 0.2), size = Vector3.new(0.24, 0.6, 0.42), rot = Vector3.new(0, 0, -10), region = "top" },
	{ muscle = "Rhomboids", part = "UpperTorso", side = true, pos = Vector3.new(0.11, 0.16, 0.36), size = Vector3.new(0.2, 0.28, 0.26), region = "top" },
	{ muscle = "LowerBack", part = "UpperTorso", side = true, pos = Vector3.new(0.08, -0.33, 0.36), size = Vector3.new(0.13, 0.36, 0.26), region = "top" },
	-- arms
	{ muscle = "Biceps", part = "UpperArm", side = true, pos = Vector3.new(0, -0.06, -0.22), size = Vector3.new(0.74, 0.66, 0.66), region = "skin" },
	{ muscle = "Triceps", part = "UpperArm", side = true, pos = Vector3.new(0.04, 0.02, 0.22), size = Vector3.new(0.74, 0.7, 0.64), region = "skin" },
	{ muscle = "Forearms", part = "LowerArm", side = true, pos = Vector3.new(0.04, 0.14, -0.08), size = Vector3.new(0.64, 0.74, 0.66), region = "skin" },
	-- core (tank top): a 2 x 3 six-pack and the obliques
	{ muscle = "Abs", part = "UpperTorso", side = true, pos = Vector3.new(0.085, -0.1, -0.4), size = Vector3.new(0.15, 0.12, 0.2), region = "top" },
	{ muscle = "Abs", part = "UpperTorso", side = true, pos = Vector3.new(0.085, -0.23, -0.4), size = Vector3.new(0.15, 0.12, 0.2), region = "top" },
	{ muscle = "Abs", part = "UpperTorso", side = true, pos = Vector3.new(0.085, -0.36, -0.39), size = Vector3.new(0.15, 0.12, 0.2), region = "top" },
	{ muscle = "Obliques", part = "UpperTorso", side = true, pos = Vector3.new(0.33, -0.28, -0.2), size = Vector3.new(0.2, 0.34, 0.32), rot = Vector3.new(0, 0, 8), region = "top" },
	-- legs (shorts over glutes and the upper legs)
	{ muscle = "Glutes", part = "LowerTorso", side = true, pos = Vector3.new(0.2, -0.3, 0.3), size = Vector3.new(0.42, 1.2, 0.52), region = "bottom" },
	{ muscle = "Quads", part = "UpperLeg", side = true, pos = Vector3.new(0.02, 0.1, -0.22), size = Vector3.new(0.84, 0.64, 0.64), region = "bottom" },
	{ muscle = "Hamstrings", part = "UpperLeg", side = true, pos = Vector3.new(0, 0.1, 0.22), size = Vector3.new(0.8, 0.62, 0.62), region = "bottom" },
	{ muscle = "Calves", part = "LowerLeg", side = true, pos = Vector3.new(0, 0.16, 0.22), size = Vector3.new(0.74, 0.66, 0.64), region = "skin" },
}
MuscleBody.Shapes = SHAPES

-- Muscles that get veins (when strong) and the shape they run over. Only on skin (not under clothes).
MuscleBody.Veined = { Forearms = true, Biceps = true, Triceps = true, FrontDelts = true, Calves = true, Abs = true, Obliques = true }

-- Gym look trims: a scoop neckline (skin) front and back, and a waistband.
local TRIMS = {
	{ name = "Neckline", part = "UpperTorso", pos = Vector3.new(0, 0.4, -0.3), size = Vector3.new(0.34, 0.2, 0.34), region = "skin" },
	{ name = "NecklineBack", part = "UpperTorso", pos = Vector3.new(0, 0.42, 0.3), size = Vector3.new(0.3, 0.16, 0.3), region = "skin" },
	{ name = "Waistband", part = "LowerTorso", pos = Vector3.new(0, 0.32, 0), size = Vector3.new(1.05, 0.3, 1.07), region = "band", block = true },
	-- shorts: a hip piece over the lower torso and a band over the top of each thigh (own parts, so the body parts keep
	-- their avatar colors)
	{ name = "ShortsHips", part = "LowerTorso", pos = Vector3.new(0, -0.08, 0), size = Vector3.new(1.04, 1.0, 1.06), region = "bottom", block = true, grow = "Glutes" },
	{ name = "ShortsLegR", part = "RightUpperLeg", pos = Vector3.new(0, 0.12, 0), size = Vector3.new(1.08, 0.72, 1.08), region = "bottom", block = true, grow = "Quads" },
	{ name = "ShortsLegL", part = "LeftUpperLeg", pos = Vector3.new(0, 0.12, 0), size = Vector3.new(1.08, 0.72, 1.08), region = "bottom", block = true, grow = "Quads" },
}

------------------------------------------------------------------------
-- Encoding (server -> attributes)
------------------------------------------------------------------------
-- 18 digits, one per muscle in Muscles.List order.
function MuscleBody.Encode(values)
	local digits = table.create(#Muscles.List)
	for i, muscle in ipairs(Muscles.List) do digits[i] = tostring(math.clamp(math.floor(values[muscle.id] or 0), 0, 9)) end
	return table.concat(digits)
end

function MuscleBody.Decode(text)
	local values = {}
	for i, muscle in ipairs(Muscles.List) do
		values[muscle.id] = tonumber(type(text) == "string" and string.sub(text, i, i) or "") or 0
	end
	return values
end

-- Size steps from muscle levels: the top step at the Growth Spurt goal.
function MuscleBody.StepsFrom(muscleData, goalLevel)
	local steps = {}
	for _, muscle in ipairs(Muscles.List) do
		local level = muscleData[muscle.id] and muscleData[muscle.id].level or 0
		steps[muscle.id] = math.floor(math.clamp(level / math.max(goalLevel, 1), 0, 1) * MuscleBody.Steps + 1e-6)
	end
	return steps
end

-- Vein stages from muscle levels vs the level cap: 70%+ = 1, 90%+ = 2, maxed = 3.
function MuscleBody.VeinsFrom(muscleData, capLevel)
	local stages = {}
	for _, muscle in ipairs(Muscles.List) do
		local level = muscleData[muscle.id] and muscleData[muscle.id].level or 0
		local share = level / math.max(capLevel, 1)
		stages[muscle.id] = (share >= 1 and 3) or (share >= 0.9 and 2) or (share >= 0.7 and 1) or 0
	end
	return stages
end

-- Gym look colors for a user id (stable per player).
function MuscleBody.GymColors(userId)
	local n = math.abs(math.floor(tonumber(userId) or 0))
	return MuscleBody.TopColors[n % #MuscleBody.TopColors + 1], MuscleBody.BottomColors[(n // 7) % #MuscleBody.BottomColors + 1]
end

-- Turns an avatar description into the play body: the smooth base body parts, classic proportions, and (gym look) no
-- shirt/pants/t-shirt or layered clothing, the torso in the tank top color. Head, face, hair, hats and skin stay.
local CLOTHING_ACCESSORIES = {
	[Enum.AccessoryType.TShirt] = true, [Enum.AccessoryType.Shirt] = true, [Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Jacket] = true, [Enum.AccessoryType.Sweater] = true, [Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.DressSkirt] = true, [Enum.AccessoryType.LeftShoe] = true, [Enum.AccessoryType.RightShoe] = true,
}
function MuscleBody.BaseDescription(desc, look, topColor)
	for key, id in pairs(MuscleBody.BaseBody) do desc[key] = id end
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	if look == "Gym" then
		desc.Shirt, desc.Pants, desc.GraphicTShirt = 0, 0, 0
		local ok, accessories = pcall(function() return desc:GetAccessories(true) end)
		if ok and accessories then
			local keep = {}
			for _, accessory in ipairs(accessories) do
				if not CLOTHING_ACCESSORIES[accessory.AccessoryType] then table.insert(keep, accessory) end
			end
			pcall(function() desc:SetAccessories(keep, true) end)
		end
		local skin = desc.HeadColor
		desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin, skin
		desc.TorsoColor = topColor or MuscleBody.TopColors[1]
	end
	return desc
end

-- Gym look: remove classic clothes that aren't part of the description (e.g. NPCs dressed by a builder).
function MuscleBody.StripClothes(model)
	for _, item in ipairs(model:GetChildren()) do
		if item:IsA("Clothing") or item:IsA("ShirtGraphic") then item:Destroy() end
	end
end

------------------------------------------------------------------------
-- Building (client)
------------------------------------------------------------------------
local function bodyPart(model, partName, left)
	if partName == "UpperArm" or partName == "LowerArm" or partName == "UpperLeg" or partName == "LowerLeg" then
		return model:FindFirstChild((left and "Left" or "Right") .. partName)
	end
	return model:FindFirstChild(partName)
end

local function newPart(folder, name, color, material, block)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = block and Enum.PartType.Block or Enum.PartType.Ball
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Parent = folder
	return p
end

-- weld `piece` to `part` at `offset`; anchored (static) bodies just get the part placed there
local function attach(piece, part, offset)
	piece.CFrame = part.CFrame * offset
	if part.Anchored then
		piece.Anchored = true
	else
		local weld = piece:FindFirstChild("MuscleWeld") or Instance.new("Weld")
		weld.Name = "MuscleWeld"
		weld.Part0, weld.Part1 = part, piece
		weld.C0, weld.C1 = offset, CFrame.identity
		weld.Parent = piece
	end
end

local function regionColor(region, spec)
	if spec.look == "Marble" then return spec.skin end
	if spec.look == "Gym" then
		if region == "top" then return spec.top end
		if region == "bottom" then return spec.bottom end
		if region == "band" then return spec.bottom:Lerp(Color3.new(0, 0, 0), 0.35) end
	end
	return spec.skin
end

-- With the avatar's own clothes, muscles under the shirt/pants take the clothes' color when it's known (spec.top /
-- spec.bottom), otherwise they stay inside the clothes (the body part itself grows a little instead).
-- Which of the avatar's own clothes covers a shape: a classic shirt paints the torso and both arms, pants the hips and
-- legs. ("Keep my avatar clothes": covered shapes take the clothes' main color when it's known, otherwise they stay
-- hidden and the body part itself thickens instead, BodyShape.OwnClothesGrowth.)
local function coverOf(shape)
	if shape.region == "top" or shape.part == "UpperArm" or shape.part == "LowerArm" then return "shirt" end
	if shape.region == "bottom" or shape.part == "UpperLeg" or shape.part == "LowerLeg" then return "pants" end
	return nil
end
local function coveredByOwn(shape, spec)
	local cover = coverOf(shape)
	return spec.look == "Own" and ((cover == "shirt" and spec.hasShirt) or (cover == "pants" and spec.hasPants))
end
local function hiddenUnderClothes(shape, spec)
	if not coveredByOwn(shape, spec) then return false end
	local cover = coverOf(shape)
	return not ((cover == "shirt" and spec.topKnown) or (cover == "pants" and spec.bottomKnown))
end
local function shapeColor(shape, spec)
	if coveredByOwn(shape, spec) then return coverOf(shape) == "shirt" and spec.top or spec.bottom end
	return regionColor(shape.region, spec)
end

local function shapeOffset(shape, part, left)
	local s = part:GetAttribute("BaseSize") or part.Size
	if typeof(s) ~= "Vector3" then s = part.Size end
	local x = left and -shape.pos.X or shape.pos.X
	local rot = shape.rot or Vector3.zero
	local rz = left and -rot.Z or rot.Z
	local ry = left and -rot.Y or rot.Y
	return CFrame.new(x * s.X, shape.pos.Y * s.Y, shape.pos.Z * s.Z) * CFrame.Angles(math.rad(rot.X), math.rad(ry), math.rad(rz)), s
end

-- Build or update the muscles on `model`. spec = { steps, veins, look, skin, top, bottom, seed, pumped, hasShirt,
-- hasPants, material, instant }. Returns the folder.
function MuscleBody.Apply(model, spec)
	local folder = model:FindFirstChild(MuscleBody.Folder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = MuscleBody.Folder
		folder.Parent = model
	end
	local material = spec.look == "Marble" and Enum.Material.Marble or Enum.Material.SmoothPlastic
	-- shapes
	for index, shape in ipairs(SHAPES) do
		for _, left in ipairs(shape.side and { false, true } or { false }) do
			local part = bodyPart(model, shape.part, left)
			local name = "M" .. index .. (left and "L" or "R")
			local piece = folder:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				local hidden = hiddenUnderClothes(shape, spec)
				if not piece then
					piece = newPart(folder, name, shapeColor(shape, spec), material)
					piece:SetAttribute("Muscle", shape.muscle)
				end
				local offset, partSize = shapeOffset(shape, part, left)
				local step = spec.steps[shape.muscle] or 0
				local scale = MuscleBody.MinScale + (1 - MuscleBody.MinScale) * step / MuscleBody.Steps
				local size = Vector3.new(shape.size.X * partSize.X, shape.size.Y * partSize.Y, shape.size.Z * partSize.Z) * scale
				piece.Color = shapeColor(shape, spec)
				piece.Material = material
				piece.Transparency = hidden and 1 or 0
				attach(piece, part, offset)
				if spec.instant or piece.Size.Magnitude < 0.2 then
					piece.Size = size
				elseif (piece.Size - size).Magnitude > 0.005 then
					TweenService:Create(piece, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size }):Play()
				end
				piece:SetAttribute("Step", step)
			elseif piece then
				piece:Destroy()
			end
		end
	end
	-- gym look trims
	for _, trim in ipairs(TRIMS) do
		local part = model:FindFirstChild(trim.part)
		local piece = folder:FindFirstChild(trim.name)
		if spec.look == "Gym" and part and part:IsA("BasePart") then
			piece = piece or newPart(folder, trim.name, regionColor(trim.region, spec), material, trim.block)
			piece.Color = regionColor(trim.region, spec)
			local s = part:GetAttribute("BaseSize") or part.Size
			if typeof(s) ~= "Vector3" then s = part.Size end
			-- shorts grow with the muscle under them (so leg size still shows through the clothes)
			local g = trim.grow and (1 + 0.32 * (spec.steps[trim.grow] or 0) / MuscleBody.Steps) or 1
			piece.Size = Vector3.new(trim.size.X * s.X * g, trim.size.Y * s.Y, trim.size.Z * s.Z * g)
			attach(piece, part, CFrame.new(trim.pos.X * s.X, trim.pos.Y * s.Y, trim.pos.Z * s.Z))
		elseif piece then
			piece:Destroy()
		end
	end
	MuscleBody.ApplyVeins(model, folder, spec)
	return folder
end

------------------------------------------------------------------------
-- Veins: thin, slightly raised curved strands (chains of short cylinders) over the shape's surface, with gentle
-- branches. The pattern comes from the seed (the owner's UserId), so it's the same every session and different per
-- player; left and right use the same pattern with a small jitter, so they're similar but not mirror copies.
------------------------------------------------------------------------
local VEIN_TINT = Color3.fromHex("#5C6E8A")
local STRANDS = { 1, 2, 2 }       -- strands per shape side, by stage (a branch is added at stage 3)
local THICKNESS = { 0.026, 0.031, 0.036 }
local CONTRAST = { 0.09, 0.13, 0.17 }
local SEGMENTS = 4
local PER_SHAPE = 9 -- vein parts per shape side at most

local function veinColor(spec, stage, pumped)
	if spec.look == "Marble" then return spec.skin:Lerp(Color3.fromHex("#8F8A82"), 0.45) end -- carved line
	local c = CONTRAST[stage] + (pumped and 0.06 or 0)
	return spec.skin:Lerp(VEIN_TINT, c):Lerp(Color3.new(0, 0, 0), c * 0.35)
end

-- a point on the shape's ellipsoid surface; u = angle around the vertical axis (0 = front), v = -1 (bottom) .. 1 (top)
local function surfacePoint(radii, u, v)
	local ring = math.sqrt(math.max(0, 1 - v * v))
	return Vector3.new(math.sin(u) * ring * radii.X, v * radii.Y, -math.cos(u) * ring * radii.Z) * 1.02
end

local function strand(folder, part, base, radii, rng, points, thickness, color, budget, jitter)
	local made = 0
	local prev = nil
	for i = 1, #points do
		local p = surfacePoint(radii, points[i].u + jitter, points[i].v)
		if prev and budget.left > 0 then
			local a, b = base * prev, base * p
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			if len > 0.02 then
				local seg = Instance.new("Part")
				seg.Name = "Vein"
				seg.Shape = Enum.PartType.Cylinder
				seg.Material = folder:GetAttribute("Marble") and Enum.Material.Marble or Enum.Material.SmoothPlastic
				seg.Color = color
				seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow, seg.Massless = false, false, false, false, true
				seg.Size = Vector3.new(len + thickness * 0.6, thickness, thickness)
				seg:SetAttribute("Thickness", thickness)
				seg.Parent = folder
				-- the cylinder's axis is X: look along the strand, then turn X onto that direction
				attach(seg, part, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0))
				budget.left -= 1
				made += 1
			end
		end
		prev = p
	end
	return made
end

function MuscleBody.ApplyVeins(model, folder, spec)
	local key = (spec.veinKey or "") .. (spec.pumped and "P" or "")
	if folder:GetAttribute("VeinKey") == key then return end
	folder:SetAttribute("VeinKey", key)
	folder:SetAttribute("Marble", spec.look == "Marble" or nil)
	for _, child in ipairs(folder:GetChildren()) do
		if child.Name == "Vein" then child:Destroy() end
	end
	local budget = { left = MuscleBody.MaxVeinParts }
	local seed = math.floor(tonumber(spec.seed) or 1)
	for index, shape in ipairs(SHAPES) do
		local stage = spec.veins[shape.muscle] or 0
		local covered = (spec.look == "Gym" and shape.region ~= "skin") or coveredByOwn(shape, spec)
		if MuscleBody.Veined[shape.muscle] and stage > 0 and not covered then
			for _, left in ipairs(shape.side and { false, true } or { false }) do
				local part = bodyPart(model, shape.part, left)
				local piece = folder:FindFirstChild("M" .. index .. (left and "L" or "R"))
				if part and piece and budget.left > 0 then
					local offset, partSize = shapeOffset(shape, part, left)
					local step = spec.steps[shape.muscle] or 0
					local scale = MuscleBody.MinScale + (1 - MuscleBody.MinScale) * step / MuscleBody.Steps
					local radii = Vector3.new(shape.size.X * partSize.X, shape.size.Y * partSize.Y, shape.size.Z * partSize.Z) * scale / 2
					local thickness = THICKNESS[stage] * (spec.pumped and 1.25 or 1)
					local color = veinColor(spec, stage, spec.pumped)
					-- each shape side gets a small share of the body's budget (so every veined muscle gets some)
					local shapeBudget = { left = math.min(PER_SHAPE, budget.left) }
					local before = shapeBudget.left
					-- same pattern both sides (seeded by muscle + shape), a small jitter on the left
					local rng = Random.new(seed * 31 + index * 7)
					local facing = (left and -1 or 1) -- outer side of a limb
					for s = 1, STRANDS[stage] do
						-- around the front of front muscles, the back of back muscles (calves, triceps); gently curved
						-- strands spread apart around the muscle (never bunched side by side)
						local u0 = (shape.pos.Z > 0 and math.pi or 0) + (s - 1.5) * 0.9 + rng:NextNumber(-0.2, 0.2)
						local points = {}
						local drift = rng:NextNumber(-0.45, 0.45)
						for i = 0, SEGMENTS do
							local t = i / SEGMENTS
							table.insert(points, { u = (u0 + drift * t + math.sin(t * 2.6 + s) * 0.14) * facing, v = 0.6 - t * 1.2 })
						end
						local jitter = left and rng:NextNumber(-0.08, 0.08) or 0
						strand(folder, part, offset, radii, rng, points, thickness, color, shapeBudget, jitter)
						-- a gentle branch off the middle of the first strand (maxed only)
						if s == 1 and stage >= 3 then
							local branch = {}
							local mid = points[math.floor(#points / 2) + 1]
							for i = 0, 3 do
								local t = i / 3
								table.insert(branch, { u = mid.u + (rng:NextNumber(0.25, 0.4) * t) * facing, v = mid.v - t * 0.45 })
							end
							strand(folder, part, offset, radii, rng, branch, thickness * 0.8, color, shapeBudget, jitter)
						end
					end
					budget.left -= before - shapeBudget.left
				end
			end
		end
	end
end

-- Read a model's attributes into a spec (and the clothes it wears).
function MuscleBody.SpecFrom(model)
	local look = model:GetAttribute("BodyLook") or "Gym"
	local skin = model:GetAttribute("SkinColor")
	local top = model:GetAttribute("TopColor")
	local bottom = model:GetAttribute("BottomColor")
	local head = model:FindFirstChild("Head")
	skin = typeof(skin) == "Color3" and skin or (head and head:IsA("BasePart") and head.Color) or Color3.fromHex("#E0B48C")
	if look == "Marble" then skin = Color3.fromHex("#EDEAE3") end
	local veinText = model:GetAttribute("VeinStages") or ""
	return {
		steps = MuscleBody.Decode(model:GetAttribute("MuscleSteps")),
		veins = MuscleBody.Decode(veinText),
		veinKey = tostring(veinText) .. tostring(model:GetAttribute("MuscleSteps")),
		look = look,
		skin = skin,
		top = typeof(top) == "Color3" and top or MuscleBody.TopColors[1],
		bottom = typeof(bottom) == "Color3" and bottom or MuscleBody.BottomColors[1],
		topKnown = typeof(top) == "Color3",
		bottomKnown = typeof(bottom) == "Color3",
		seed = model:GetAttribute("VeinSeed") or 1,
		hasShirt = model:FindFirstChildOfClass("Shirt") ~= nil,
		hasPants = model:FindFirstChildOfClass("Pants") ~= nil,
	}
end

return MuscleBody
