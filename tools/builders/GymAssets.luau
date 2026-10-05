-- GymAssets builder (run once in Studio; see tools/bake.md): templates that are cloned at runtime and by the other
-- builders, saved in ReplicatedStorage.GymAssets:
--   Plates.Plate55 ... Plate5   one model per weight (Machines.Plates): flat faces with a recessed inner face, a raised
--                               outer rim, an inset ring, a metal hub with a hole, and the weight number on both faces
--                               (SurfaceGuis "LabelRight"/"LabelLeft", off by default: whoever places the plate turns
--                               on the face people see). The plate's axis is the model's X axis, centered at the pivot.
--   BarSleeve                   chrome sleeve + collar for one end of a barbell (MachineService puts them on bars)
-- Uses CSG (GeometryService), so it must run in Studio. Re-running replaces the folder.
local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local Machines = require(ReplicatedStorage.Shared.Config.Machines)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local Builder = {}

local STEEL = Color3.fromHex("#C9CCD2")
local HOLE = Color3.fromHex("#141416")

local function cylinder(length, diameter, cframe)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, diameter, diameter)
	p.CFrame = cframe
	p.Anchored = true
	return p
end

-- Body with both faces recessed inside the rim and a thin groove ring on each face.
local function plateBody(spec, color, material)
	local d, t = spec.diameter, spec.thickness
	local body = cylinder(t, d, CFrame.new())
	local cutters = {}
	local recess = math.min(0.04, t * 0.15)
	for _, side in ipairs({ 1, -1 }) do
		-- recessed face inside the rim
		table.insert(cutters, cylinder(recess * 2, d * 0.84, CFrame.new(side * t / 2, 0, 0)))
	end
	local ok, result = pcall(function()
		return GeometryService:SubtractAsync(body, cutters, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic })
	end)
	local main = (ok and result and result[1]) or body
	-- groove ring: a slightly darker thin ring sitting in the recessed face (separate thin parts, cheap)
	main.Name = "Body"
	main.Color = color
	main.Material = material
	if main:IsA("PartOperation") then main.UsePartColor = true end
	return main, recess
end

local function label(body, face, text, color, diameter)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	gui.Enabled = false
	gui.Parent = body
	local textLabel = Instance.new("TextLabel")
	textLabel.AnchorPoint = Vector2.new(0.5, 0)
	textLabel.Position = UDim2.fromScale(0.5, 0.035)
	textLabel.Size = UDim2.fromScale(0.5, 0.16)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.FontFace = Theme.Fonts.SemiBold
	textLabel.TextScaled = true -- world-space label on a plate face
	textLabel.Parent = gui
	local lb = textLabel:Clone()
	lb.Name = "Unit"
	lb.Text = "LB"
	lb.Position = UDim2.fromScale(0.5, 0.845)
	lb.Size = UDim2.fromScale(0.3, 0.1)
	lb.Parent = gui
	return gui
end

local function buildPlate(weight, spec)
	local model = Instance.new("Model")
	model.Name = "Plate" .. weight
	local bumper = Theme.Bumper[spec.color] or Theme.Bumper.Black
	local isSteel = spec.color == "Steel"
	local body, recess = plateBody(spec, bumper.Fill, isSteel and Enum.Material.Metal or Enum.Material.SmoothPlastic)
	body.Anchored = true
	body.CanCollide, body.CanQuery, body.CanTouch = false, false, false
	body.Parent = model
	local d, t = spec.diameter, spec.thickness
	-- inset ring: a thin darker ring in the recessed face, both sides
	for _, side in ipairs({ 1, -1 }) do
		local ring = cylinder(0.012, d * 0.62, CFrame.new(side * (t / 2 - recess + 0.006), 0, 0))
		ring.Name = "InsetRing"
		ring.Color = bumper.Rim
		ring.Material = body.Material
		ring.Parent = model
		local inner = cylinder(0.014, d * 0.58, CFrame.new(side * (t / 2 - recess + 0.007), 0, 0))
		inner.Name = "InsetFace"
		inner.Color = bumper.Fill
		inner.Material = body.Material
		inner.Parent = model
	end
	local hub = cylinder(t + 0.05, math.max(0.34, d * 0.2), CFrame.new())
	hub.Name = "Hub"
	hub.Color = STEEL
	hub.Material = Enum.Material.Metal
	hub.Reflectance = 0.2
	hub.Parent = model
	local hole = cylinder(t + 0.07, 0.2, CFrame.new())
	hole.Name = "Hole"
	hole.Color = HOLE
	hole.Material = Enum.Material.SmoothPlastic
	hole.Parent = model
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
		end
	end
	body.CastShadow = true
	local textColor = bumper.Text == Theme.Colors.Ink and Color3.fromHex("#1A1A1C") or Color3.fromHex("#F4F1EA")
	-- SurfaceGuis don't draw on unions: each face gets a thin invisible part to carry its label
	for _, side in ipairs({ { Enum.NormalId.Right, 1 }, { Enum.NormalId.Left, -1 } }) do
		local face = Instance.new("Part")
		face.Name = "Face" .. side[1].Name
		face.Size = Vector3.new(0.01, d * 0.84, d * 0.84)
		face.CFrame = CFrame.new(side[2] * (t / 2 - recess + 0.02), 0, 0)
		face.Transparency = 1
		face.Anchored = true
		face.CanCollide, face.CanQuery, face.CanTouch, face.CastShadow = false, false, false, false
		face.Parent = model
		label(face, side[1], tostring(weight), textColor, d)
	end
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
