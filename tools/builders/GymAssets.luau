-- GymAssets builder (run once in Studio; see tools/bake.md): templates that are cloned at runtime and by the other
-- builders, saved in ReplicatedStorage.GymAssets:
--   Plates.Plate55 ... Plate5   one model per weight (Machines.Plates), built like the genetics screen's plates (8 Oct):
--                               a core over a thinner, wider edge (a stepped bevel), a raised rim band on each face, a
--                               chrome hub with a flange and the hole, and printed like a competition bumper plate on each
--                               face: a groove ring, "M WEIGHTS" curved over the hub and upside down under it, the weight
--                               at 9 and 3 o'clock (SurfaceGuis on the thin parts "FaceRight"/"FaceLeft", both always on,
--                               drawn within PRINT_DISTANCE). Axis = the model's X, centered at the pivot. Builder.Replace
--                               swaps every plate already placed in the world for the new ones.
--   BarSleeve                   chrome sleeve + collar for one end of a barbell (MachineService puts them on bars)
-- Runs in Studio (it measures the print font with TextService). Re-running replaces the folder.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Machines = require(ReplicatedStorage.Shared.Config.Machines)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local Builder = {}

local HOLE = Color3.fromHex("#141416")

local function cylinder(length, diameter, cframe)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, diameter, diameter)
	p.CFrame = cframe
	p.Anchored = true
	return p
end

local TextService = game:GetService("TextService")
local CHROME = Color3.fromHex("#D6D8DE")
local PRINT_PPS = 70 -- SurfaceGui pixels per stud on the plate faces
local PRINT_DISTANCE = 40 -- studs: the printing stops drawing past this (performance: each face is its own texture)

-- Each character's box at font size 1, measured once in the print font (so the curved letters sit close together).
local boxCache = {}
local function textBox(str: string): Vector2
	if boxCache[str] then return boxCache[str] end
	local box = Vector2.new(0.55 * #str, 1.25)
	local ok, bounds = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = str
		params.Font = Theme.Fonts.Bold
		params.Size = 100
		params.Width = 2000
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok and bounds then box = Vector2.new(bounds.X / 100, bounds.Y / 100) end
	boxCache[str] = box
	return box
end

-- The printing on one face (a SurfaceGui on a thin invisible part just off the face): the groove ring, the brand curved
-- over the hub and upside down under it, the weight at 9 and 3 o'clock.
local function printFace(model, face, sign, weight, spec, bumper, hub)
	local d, t = spec.diameter, spec.thickness
	local part = Instance.new("Part")
	part.Name = "Face" .. face.Name
	part.Size = Vector3.new(0.01, d, d)
	part.CFrame = CFrame.new(sign * (t / 2 + 0.022), 0, 0)
	part.Transparency = 1
	part.Parent = model
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PRINT_PPS
	gui.LightInfluence = 1
	gui.MaxDistance = PRINT_DISTANCE
	gui.Parent = part
	local canvas = Instance.new("Frame")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.Parent = gui
	local light = bumper.Text == Theme.Colors.Ink -- white / yellow / steel plates print dark
	local ink = if light then Color3.fromHex("#1A1A1C") else Color3.new(1, 1, 1)
	local px = d * PRINT_PPS
	local function ring(scale, color, thickness, transparency)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(scale, scale)
		frame.BackgroundTransparency = 1
		frame.Parent = canvas
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Transparency = color, thickness, transparency
		stroke.Parent = frame
	end
	local ringR = 0.4
	ring(ringR * 2, bumper.Rim, math.max(px * 0.012, 2), 0.1)
	ring(ringR * 2 + 0.02, bumper.Fill:Lerp(Color3.new(1, 1, 1), 0.25), math.max(px * 0.004, 1), 0.4)
	local function print(name, str, x, y, w, h, rotation)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(x, y)
		label.Size = UDim2.fromScale(w, h)
		label.Rotation = rotation
		label.BackgroundTransparency = 1
		label.Text = str
		label.FontFace = Theme.Fonts.Bold
		label.TextScaled = true -- world-space text on a plate face
		label.TextColor3 = ink
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = if light then 1 else 0.8
		label.ZIndex = 3
		label.Parent = canvas
	end
	-- the band between the flange and the groove ring: the brand follows its curve, one letter at a time
	local hubR = hub * 1.45 / 2 / d
	local mid, band = (hubR + ringR) / 2, ringR - hubR
	local letters, total = {}, 0
	for ch in string.gmatch(Machines.Brand, ".") do
		local box = textBox(ch)
		local w = if ch == " " then 0.2 else box.X
		table.insert(letters, { ch = ch, x = w, y = box.Y })
		total += w * 0.9
	end
	local size = math.min(band * 1.05, math.rad(120) * mid / total)
	for _, base in ipairs({ 0, math.pi }) do
		local along = -total * size / 2
		for _, letter in ipairs(letters) do
			local advance = letter.x * 0.9 * size
			local angle = base + (along + advance / 2) / mid
			along += advance
			if letter.ch ~= " " then
				print("Brand", letter.ch, 0.5 + math.sin(angle) * mid, 0.5 - math.cos(angle) * mid, letter.x * size, letter.y * size, math.deg(angle))
			end
		end
	end
	-- the weight at 9 o'clock (upright) and 3 o'clock (turned over), as tall as the brand's letters
	local number = textBox(tostring(weight))
	local numberSize = size * 1.05
	print("Weight", tostring(weight), 0.5 - mid, 0.5, number.X * numberSize, number.Y * numberSize, 0)
	print("Weight", tostring(weight), 0.5 + mid, 0.5, number.X * numberSize, number.Y * numberSize, 180)
end

local function buildPlate(weight, spec)
	local model = Instance.new("Model")
	model.Name = "Plate" .. weight
	local bumper = Theme.Bumper[spec.color] or Theme.Bumper.Black
	local isSteel = spec.color == "Steel"
	local material = isSteel and Enum.Material.Metal or Enum.Material.SmoothPlastic
	local fill = bumper.Fill:Lerp(Color3.new(0, 0, 0), 0.08) -- (a touch deeper, like the genetics plates)
	local d, t = spec.diameter, spec.thickness
	local function disc(name, length, diameter, color, x, mat)
		local part = cylinder(length, diameter, CFrame.new(x or 0, 0, 0))
		part.Name = name
		part.Color = color
		part.Material = mat or material
		part.Parent = model
		return part
	end
	local body = disc("Body", t, d - 0.06, fill)
	disc("Edge", math.max(t - 0.04, t * 0.7), d, fill:Lerp(Color3.new(0, 0, 0), 0.12)) -- the stepped bevel
	for _, sign in ipairs({ 1, -1 }) do
		-- the raised rim band near the edge: a lighter ring with the face color inside it
		disc("Rim", 0.012, d - 0.12, fill:Lerp(Color3.new(1, 1, 1), 0.07), sign * (t / 2 + 0.006))
		disc("RimInner", 0.014, d - 0.28, fill, sign * (t / 2 + 0.007))
	end
	local hub = math.max(0.5, d * 0.3)
	disc("Flange", t + 0.03, math.min(hub * 1.45, d - 0.3), CHROME:Lerp(Color3.new(0, 0, 0), 0.12), 0, Enum.Material.Metal)
	local hubPart = disc("Hub", t + 0.08, hub, CHROME, 0, Enum.Material.Metal)
	hubPart.Reflectance = 0.2
	disc("Hole", t + 0.1, math.max(0.36, hub * 0.6), HOLE, 0, Enum.Material.SmoothPlastic)
	printFace(model, Enum.NormalId.Right, 1, weight, spec, bumper, hub)
	printFace(model, Enum.NormalId.Left, -1, weight, spec, bumper, hub)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
		end
	end
	body.CastShadow = true
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	model:SetAttribute("Weight", weight)
	model:SetAttribute("Thickness", t)
	model:SetAttribute("Diameter", d)
	return model
end

-- One end of a barbell: a thicker chrome sleeve and a collar, along +X from the pivot (pivot = where the collar sits).
local function buildSleeve()
	local model = Instance.new("Model")
	model.Name = "BarSleeve"
	local collar = cylinder(0.18, 0.5, CFrame.new(0.09, 0, 0))
	collar.Name = "Collar"
	collar.Color = Color3.fromHex("#B8BBC2")
	collar.Material = Enum.Material.Metal
	collar.Parent = model
	local sleeve = cylinder(1.75, 0.34, CFrame.new(0.18 + 0.875, 0, 0))
	sleeve.Name = "Sleeve"
	sleeve.Color = Color3.fromHex("#DADDE3")
	sleeve.Material = Enum.Material.Metal
	sleeve.Reflectance = 0.25
	sleeve.Parent = model
	local cap = cylinder(0.06, 0.3, CFrame.new(0.18 + 1.75 + 0.03, 0, 0))
	cap.Name = "EndCap"
	cap.Color = Color3.fromHex("#9EA2A8")
	cap.Material = Enum.Material.Metal
	cap.Parent = model
	for _, part in ipairs(model:GetChildren()) do
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	end
	model.PrimaryPart = collar
	model.WorldPivot = CFrame.new()
	return model
end

-- Swaps every placed plate (a model with a Weight attribute and a Body, outside GymAssets) for a clone of the current
-- template, keeping its name, place and attributes. Returns how many were swapped.
function Builder.Replace(root)
	local plates = ReplicatedStorage:FindFirstChild("GymAssets") and ReplicatedStorage.GymAssets:FindFirstChild("Plates")
	if not plates then return 0 end
	local swapped = 0
	for _, old in ipairs(root:GetDescendants()) do
		local weight = old:IsA("Model") and old:GetAttribute("Weight")
		local template = weight and plates:FindFirstChild("Plate" .. weight)
		if template and old:FindFirstChild("Body") and old.Parent then
			local new = template:Clone()
			new.Name = old.Name
			for key, value in pairs(old:GetAttributes()) do new:SetAttribute(key, value) end
			new:PivotTo(old:GetPivot())
			new.Parent = old.Parent
			old:Destroy()
			swapped += 1
		end
	end
	return swapped
end

function Builder.Build()
	local folder = Kit.fresh(ReplicatedStorage, "Folder", "GymAssets")
	local plates = Instance.new("Folder")
	plates.Name = "Plates"
	plates.Parent = folder
	for weight, spec in pairs(Machines.Plates) do
		buildPlate(weight, spec).Parent = plates
	end
	buildSleeve().Parent = folder
	return folder
end

return Builder
