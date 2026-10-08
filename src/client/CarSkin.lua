--[[
	CarSkin (client)
	Replaces the part-built bodywork of a car with its generated meshes
	(CarMesh -> EditableMesh -> MeshPart): one MeshPart per material layer
	(paint, accent, black trim, chrome, glass, LED lamps, tail lamps, plate,
	interior) plus real wheels: tyre + spoked rim spinning on the wheel
	joint, and a brake caliper on a steering knuckle (it steers but does not
	spin).

	Meshes are generated once per car design and cloned, so a city of traffic
	costs one set per design. Traffic uses the lighter "lite" versions.

	Imported models: if ReplicatedStorage has a "CarModels" folder holding a
	model named after a car id (made by tools/make_glb.py and brought in with
	Studio's 3D Importer), that car uses those MeshParts instead of runtime
	meshes. The "Mark_*" parts in it give the car's frame and scale, so it
	doesn't matter where the importer put it. Player cars, the garage and the
	cutscene prefer imported models; traffic keeps the cheap runtime "lite"
	meshes and falls back to the imported ones when runtime meshes are not
	allowed. With neither, apply() returns false and the part bodies stay.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarMesh = require(Shared:WaitForChild("CarMesh"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))
local Cars = require(Shared:WaitForChild("Cars"))

local CarSkin = {}

type Template = { part: MeshPart, offset: CFrame }
type GenericWheel = { x: number, parts: { Template } }
type Imported = {
	body: { [string]: Template },
	wheel: { [string]: Template },
	plate: CFrame?,
	exhausts: { Vector3 },
	-- set for any other car model (Creator Store, bought, hand-made): parts keep
	-- their own look and each corner's wheel parts ride on our wheel
	generic: { [string]: GenericWheel }?,
}
type Look = { material: Enum.Material, color: Color3?, reflectance: number, transparency: number, shadow: boolean }

local TRIM = Color3.fromRGB(16, 16, 18)
local LOOKS: { [string]: Look } = {
	Paint = { material = Enum.Material.SmoothPlastic, reflectance = 0.2, transparency = 0, shadow = true },
	Accent = { material = Enum.Material.SmoothPlastic, reflectance = 0.2, transparency = 0, shadow = true },
	Trim = { material = Enum.Material.SmoothPlastic, color = TRIM, reflectance = 0.05, transparency = 0, shadow = true },
	Chrome = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(196, 200, 208), reflectance = 0.45, transparency = 0, shadow = false },
	Glass = { material = Enum.Material.Glass, color = Color3.fromRGB(12, 16, 22), reflectance = 0.25, transparency = 0.25, shadow = false },
	Lamp = { material = Enum.Material.Neon, color = Color3.fromRGB(236, 243, 255), reflectance = 0, transparency = 0, shadow = false },
	Tail = { material = Enum.Material.Neon, color = Color3.fromRGB(150, 0, 6), reflectance = 0, transparency = 0, shadow = false },
	Drl = { material = Enum.Material.Neon, reflectance = 0, transparency = 0, shadow = false },
	Plate = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(232, 232, 228), reflectance = 0, transparency = 0, shadow = false },
	Interior = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(22, 22, 26), reflectance = 0, transparency = 0, shadow = false },
	Tire = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(20, 20, 22), reflectance = 0, transparency = 0, shadow = true },
	Rim = { material = Enum.Material.SmoothPlastic, reflectance = 0.3, transparency = 0, shadow = true },
	Caliper = { material = Enum.Material.SmoothPlastic, reflectance = 0.1, transparency = 0, shadow = false },
}

local bodyCache: { [string]: { [string]: Template } | false } = {}
local bodyMeta: { [string]: { [string]: any } } = {}
local importCache: { [string]: Imported | false } = {}
local wheelCache: { [string]: { [string]: Template } | false } = {}
local keepAlive: { any } = {} -- EditableMeshes must stay alive while their MeshParts render
local warned = false

local function build(layer: CarMesh.Layer): Template
	local minV = Vector3.one * math.huge
	local maxV = -Vector3.one * math.huge
	for _, v in layer.verts do
		minV = minV:Min(v)
		maxV = maxV:Max(v)
	end
	local center = (minV + maxV) / 2
	local em = AssetService:CreateEditableMesh()
	local vids = table.create(#layer.verts, 0)
	local nids = table.create(#layer.verts, 0)
	for i, v in layer.verts do
		vids[i] = em:AddVertex(v - center)
		nids[i] = em:AddNormal(layer.normals[i])
	end
	local tris = layer.tris
	for i = 1, #tris, 3 do
		local a, b, c = tris[i], tris[i + 1], tris[i + 2]
		local face = em:AddTriangle(vids[a], vids[b], vids[c])
		em:SetFaceNormals(face, { nids[a], nids[b], nids[c] })
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	part.Size = (maxV - minV):Max(Vector3.one * 0.05)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	table.insert(keepAlive, em)
	return { part = part, offset = CFrame.new(center) }
end

local function fail(err: any)
	if not warned then
		warned = true
		warn("[CityLegends] Runtime car meshes unavailable (allow Mesh / Image APIs, or import CarModels):", err)
	end
end

local function bodyFor(id: string, class: string, lite: boolean): { [string]: Template }?
	local key = id .. (if lite then "/lite" else "")
	local cached = bodyCache[key]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local ok, result = pcall(function()
		local layers, meta = CarMesh.build(id, class, CarBuilder.getDims(class, id) :: any, lite)
		bodyMeta[key] = meta
		local out = {}
		for name, layer in layers do
			out[name] = build(layer)
		end
		return out
	end)
	if ok then
		bodyCache[key] = result
		return result
	end
	bodyCache[key] = false
	fail(result)
	return nil
end

local function wheelFor(style: string, R: number, width: number, rimFrac: number, lite: boolean): { [string]: Template }?
	local key = string.format("%s/%.3f/%.3f/%.3f/%s", style, R, width, rimFrac, tostring(lite))
	local cached = wheelCache[key]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local ok, result = pcall(function()
		local out = {}
		for name, layer in CarMesh.wheel(style, R, width, rimFrac, lite) do
			out[name] = build(layer)
		end
		return out
	end)
	if ok then
		wheelCache[key] = result
		return result
	end
	wheelCache[key] = false
	fail(result)
	return nil
end

-- Imported model for a car (see header), read once
local readGeneric: (src: Instance, dims: { [string]: number }) -> Imported -- defined below
local MARK_REF = 4 -- Mark_RefX / Mark_RefZ sit this many studs from Mark_Origin
local function readImported(src: Instance): Imported
	local function mark(name: string): Vector3?
		local m = src:FindFirstChild(name, true)
		return if m and m:IsA("BasePart") then m.Position else nil
	end
	local o, rx, rz = mark("Mark_Origin"), mark("Mark_RefX"), mark("Mark_RefZ")
	if not (o and rx and rz) then
		local spec = Cars.get((src:GetAttribute("CarId") :: string?) or src.Name)
		return readGeneric(src, CarBuilder.getDims(spec.Class, spec.Id) :: any)
	end
	local ex, ez = rx - o, rz - o
	local scale = MARK_REF / ex.Magnitude
	local frame = CFrame.fromMatrix(o, ex.Unit, ez.Unit:Cross(ex.Unit), ez.Unit)
	local function local_(p: Vector3): Vector3
		return frame:PointToObjectSpace(p) * scale
	end
	local hubW = mark("Mark_Hub")
	local hub = if hubW then local_(hubW) else Vector3.zero
	local out: Imported = { body = {}, wheel = {}, exhausts = {} }
	for _, d in src:GetDescendants() do
		if not d:IsA("MeshPart") or d.Name:sub(1, 5) == "Mark_" then
			continue
		end
		local rel = frame:ToObjectSpace(d.CFrame)
		local isWheel = d.Name:sub(1, 5) == "Wheel"
		local part = d:Clone()
		part:ClearAllChildren() -- importer SurfaceAppearances etc.; LOOKS styles the parts
		part.Size = d.Size * scale
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.RenderFidelity = Enum.RenderFidelity.Automatic
		local pos = rel.Position * scale - (if isWheel then hub else Vector3.zero)
		local t = { part = part, offset = CFrame.new(pos) * rel.Rotation }
		if isWheel then
			out.wheel[d.Name:sub(6)] = t
		else
			out.body[d.Name] = t
		end
	end
	local plate = mark("Mark_Plate")
	if plate then
		local p = local_(plate)
		out.plate = CFrame.lookAt(p, p + Vector3.zAxis)
	end
	local i = 1
	while true do
		local e = mark("Mark_Exhaust" .. i)
		if not e then
			break
		end
		table.insert(out.exhausts, local_(e))
		i += 1
	end
	if next(out.body) == nil then
		error("no body parts")
	end
	return out
end

--[[
	Any other car model (Toolbox / Creator Store, bought, made in Blender):
	  * forward = its VehicleSeat (A-Chassis "DriveSeat"), else its PrimaryPart,
	    else the longest side. Set a Reverse = true attribute on the model if
	    it comes out backwards.
	  * wheels = the FL / FR / RL / RR children of a "Wheels" folder (A-Chassis),
	    else parts named wheel / tire / tyre / rim, split into four corners
	  * scaled so its wheelbase matches ours; its wheels spin on our wheels
	  * only visible parts are used, and only their looks are copied (mesh,
	    colour, material, textures): scripts and everything else stay behind
]]
local KEEP_CHILD = { SurfaceAppearance = true, SpecialMesh = true, Decal = true, Texture = true }
local function visualClone(d: BasePart, scale: number): BasePart
	local p = d:Clone()
	for _, c in p:GetChildren() do
		if not KEEP_CHILD[c.ClassName] then
			c:Destroy()
		end
	end
	p.Size = d.Size * scale
	local sm = p:FindFirstChildOfClass("SpecialMesh")
	if sm then
		if sm.MeshType == Enum.MeshType.FileMesh then
			sm.Scale *= scale -- file meshes don't follow the part size
		end
		sm.Offset *= scale
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return p
end

function readGeneric(src: Instance, dims: { [string]: number }): Imported
	local visible: { BasePart } = {}
	for _, d in src:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.98 and not d:IsA("Seat") and not d:IsA("VehicleSeat") then
			table.insert(visible, d)
		end
	end
	if #visible == 0 then
		error("no visible parts")
	end
	local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in visible do
		minV = minV:Min(d.Position)
		maxV = maxV:Max(d.Position)
	end
	-- forward direction
	local seat = src:FindFirstChildWhichIsA("VehicleSeat", true)
	local primary = if src:IsA("Model") then src.PrimaryPart else nil
	local f: Vector3
	if seat then
		f = seat.CFrame.LookVector
	elseif primary then
		f = primary.CFrame.LookVector
	else
		local ext = maxV - minV
		f = if ext.X > ext.Z then Vector3.xAxis else -Vector3.zAxis
	end
	f = Vector3.new(f.X, 0, f.Z)
	if f.Magnitude < 1e-3 then
		error("can't tell which way the car faces")
	end
	f = f.Unit
	if src:GetAttribute("Reverse") == true then
		f = -f
	end
	local right = f:Cross(Vector3.yAxis)

	-- wheel groups
	type Group = { parts: { BasePart }, center: Vector3 }
	local groups: { Group } = {}
	local inWheel: { [BasePart]: boolean } = {}
	local function centerOf(list: { BasePart }): Vector3
		local a, b = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, d in list do
			a = a:Min(d.Position - d.Size / 2)
			b = b:Max(d.Position + d.Size / 2)
		end
		return (a + b) / 2
	end
	local wheelsNode = src:FindFirstChild("Wheels", true)
	if wheelsNode then
		for _, c in wheelsNode:GetChildren() do
			local list: { BasePart } = {}
			for _, d in visible do
				if d == c or d:IsDescendantOf(c) then
					table.insert(list, d)
				end
			end
			if #list > 0 then
				table.insert(groups, { parts = list, center = if c:IsA("BasePart") then c.Position else centerOf(list) })
			end
		end
	end
	if #groups ~= 4 then
		groups = {}
		local cand: { BasePart } = {}
		for _, d in visible do
			local n = d.Name:lower()
			if n:find("wheel") or n:find("tire") or n:find("tyre") or n:find("rim") then
				table.insert(cand, d)
			end
		end
		if #cand >= 4 then
			local c0 = centerOf(cand)
			local quads: { [string]: { BasePart } } = {}
			for _, d in cand do
				local rel = d.Position - c0
				local key = (if rel:Dot(f) > 0 then "F" else "R") .. (if rel:Dot(right) > 0 then "R" else "L")
				quads[key] = quads[key] or {}
				table.insert(quads[key], d)
			end
			for _, list in quads do
				table.insert(groups, { parts = list, center = centerOf(list) })
			end
		end
	end
	if #groups ~= 4 then
		error("couldn't find 4 wheels: put them in a 'Wheels' folder as FL, FR, RL, RR")
	end
	for _, g in groups do
		for _, d in g.parts do
			inWheel[d] = true
		end
	end
	local mid = Vector3.zero
	for _, g in groups do
		mid += g.center / 4
	end
	local frontZ, rearZ, nf, nr = 0, 0, 0, 0
	for _, g in groups do
		local a = (g.center - mid):Dot(f)
		if a > 0 then
			frontZ += a
			nf += 1
		else
			rearZ += a
			nr += 1
		end
	end
	if nf ~= 2 or nr ~= 2 then
		error("wheels are not two at the front and two at the back")
	end
	local wheelbase = (frontZ - rearZ) / 2
	local scale = math.clamp(dims.wb / math.max(wheelbase, 1e-3), 0.02, 50)
	-- ground frame: its wheel centres land at our wheel height
	local origin = Vector3.new(mid.X, mid.Y - dims.wheelR / scale, mid.Z)
	local frame = CFrame.lookAt(origin, origin + f)
	local function tmpl(d: BasePart, about: Vector3): Template
		local rel = frame:ToObjectSpace(d.CFrame)
		return { part = visualClone(d, scale) :: any, offset = CFrame.new(rel.Position * scale - about) * rel.Rotation }
	end
	local out: Imported = { body = {}, wheel = {}, exhausts = {}, generic = {} }
	local k = 0
	for _, d in visible do
		if not inWheel[d] then
			k += 1
			out.body["Part" .. k] = tmpl(d, Vector3.zero)
		end
	end
	local generic = out.generic :: { [string]: GenericWheel }
	for _, g in groups do
		local c = frame:PointToObjectSpace(g.center) * scale
		local key = (if c.Z < 0 then "F" else "R") .. (if c.X < 0 then "L" else "R")
		local parts = {}
		for _, d in g.parts do
			table.insert(parts, tmpl(d, c))
		end
		generic[key] = { x = c.X, parts = parts }
	end
	return out
end

local function importedFor(id: string): Imported?
	local cached = importCache[id]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local folder = ReplicatedStorage:FindFirstChild("CarModels", true) -- anywhere in ReplicatedStorage
	local src = if folder then folder:FindFirstChild(id, true) else nil
	local result: Imported? = nil
	if src then
		local ok, res = pcall(readImported, src)
		if ok then
			result = res
		else
			warn("[CityLegends] CarModels/" .. id .. " could not be used:", res)
		end
	end
	importCache[id] = result or false
	return result
end

-- Build the meshes ahead of time (loading screen): every traffic design plus the given full ones
function CarSkin.preload(fullIds: { string }?)
	for _, spec in Cars.List do
		bodyFor(spec.Id, spec.Class, true)
		task.wait()
	end
	local full: { string } = fullIds or {}
	for _, id in full do
		local spec = Cars.get(id)
		if not importedFor(spec.Id) then
			bodyFor(spec.Id, spec.Class, false)
			task.wait()
		end
	end
end

-- The knuckle joint for a wheel joint (steer only), if the car is skinned
function CarSkin.knuckleFor(wheelMotor: Motor6D): Motor6D?
	local root = wheelMotor.Part0
	if not root then
		return nil
	end
	return root:FindFirstChild("Knuckle_" .. wheelMotor.Name:sub(7)) :: Motor6D?
end

local function place(t: Template, name: string, look: Look, color: Color3, cf: CFrame, weldTo: BasePart, parent: Instance, scale: number?): MeshPart
	local p = t.part:Clone()
	local k = scale or 1
	p.Name = name
	p.Material = look.material
	p.Color = look.color or color
	p.Reflectance = look.reflectance
	p.Transparency = look.transparency
	p.CastShadow = look.shadow
	if k ~= 1 then
		p.Size *= k
		p.CFrame = cf * CFrame.new(t.offset.Position * k) * t.offset.Rotation
	else
		p.CFrame = cf * t.offset
	end
	p.Parent = parent
	local w = Instance.new("WeldConstraint")
	w.Part0 = weldTo
	w.Part1 = p
	w.Parent = p
	return p
end

--[[
	destroyReplaced: true for local-only models (traffic, cutscene, garage
	preview) - the old bodywork is deleted. For replicated player cars it is
	hidden with LocalTransparencyModifier instead.
	lite: lighter meshes (traffic)
]]
function CarSkin.apply(model: Model, destroyReplaced: boolean?, lite: boolean?): boolean
	if model:GetAttribute("Skinned") then
		return true
	end
	local id = model:GetAttribute("CarId")
	local class = model:GetAttribute("Class")
	local root = model.PrimaryPart
	if type(id) ~= "string" or type(class) ~= "string" or not root then
		return false
	end
	local liteMode = lite == true
	-- imported models first for the cars you look at; runtime lite meshes first for traffic
	local imported = if liteMode then nil else importedFor(id)
	local body = if imported then imported.body else bodyFor(id, class, liteMode)
	if not body then
		imported = importedFor(id)
		body = if imported then imported.body else nil
	end
	if not body then
		return false
	end
	local meta = if imported then { plate = imported.plate, exhausts = imported.exhausts } else bodyMeta[id .. (if liteMode then "/lite" else "")]
	local spec = Cars.get(id)
	local dims = CarBuilder.getDims(class, id)
	local design = CarMesh.design(id, class, dims :: any)
	local height = (model:GetAttribute("Height") :: number?) or dims.H
	local groundCF = root.CFrame * CFrame.new(0, -height / 2, 0)

	-- paint comes from the built car (traffic gets random colours)
	local paintSrc = model:FindFirstChild("DoorL") or model:FindFirstChild("Tail")
	local paint = if paintSrc and paintSrc:IsA("BasePart") then paintSrc.Color else spec.Color
	local accent = spec.Accent or Color3.fromRGB(18, 18, 20)

	local skin = Instance.new("Model")
	skin.Name = "Skin"
	skin.Parent = model
	local drl = if design.drl then Color3.fromRGB(design.drl[1], design.drl[2], design.drl[3]) else Color3.new(1, 1, 1)
	local generic = if imported then imported.generic else nil
	for name, t in body do
		if generic then
			local p = t.part:Clone()
			p.Name = "Skin" .. name
			p.CFrame = groundCF * t.offset
			p.Parent = skin
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
			continue
		end
		local base = name:match("^%a+") or name -- "Paint2" is the second half of a big layer
		local look = LOOKS[base] or LOOKS.Paint
		local color = if base == "Accent" then accent elseif base == "Drl" then drl else paint
		local p = place(t, "Skin" .. name, look, color, groundCF, root, skin)
		if base == "Tail" then
			p:SetAttribute("TailLight", true)
		end
	end

	-- licence plate text (the plate itself is part of the mesh)
	if meta and meta.plate and not liteMode then
		local plate = Instance.new("Part")
		plate.Name = "PlateText"
		plate.Size = Vector3.new(1.16, 0.36, 0.02)
		plate.Transparency = 1
		plate.CanCollide = false
		plate.CanQuery = false
		plate.CanTouch = false
		plate.Massless = true
		plate.CastShadow = false
		plate.CFrame = groundCF * (meta.plate :: CFrame) -- front face looks out of the car
		plate.Parent = skin
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = plate
		weld.Parent = plate
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(232, 72)
		sg.LightInfluence = 1
		sg.MaxDistance = 90
		sg.Parent = plate
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(20, 26, 60)
		local plateText = model:GetAttribute("Plate")
		text.Text = if type(plateText) == "string" then plateText else "CTYLGND"
		text.Parent = sg
	end

	-- exhaust tips in root space (Driving puts the backfire flames there)
	if meta and meta.exhausts then
		for i, p in meta.exhausts :: { Vector3 } do
			model:SetAttribute("Exhaust" .. i, p - Vector3.new(0, height / 2, 0))
		end
	end

	-- wheels
	local rim = Color3.fromRGB(design.rim[1], design.rim[2], design.rim[3])
	local caliper = Color3.fromRGB(design.caliper[1], design.caliper[2], design.caliper[3])
	for _, j in root:GetChildren() do
		if not (j:IsA("Motor6D") and j.Name:sub(1, 6) == "Wheel_") then
			continue
		end
		local tire = j.Part1
		if not tire then
			continue
		end
		local R = (j:GetAttribute("Radius") :: number?) or dims.wheelR
		local front = j:GetAttribute("Front") == true
		if generic then
			-- the model's own wheel for this corner, spinning with ours (kept at its own track width)
			local gw = generic[(if front then "F" else "R") .. (if j.C0.Position.X < 0 then "L" else "R")]
			if gw then
				local base = tire.CFrame * CFrame.new(gw.x - j.C0.Position.X, 0, 0)
				for i, t in gw.parts do
					local p = t.part:Clone()
					p.Name = "SkinWheel" .. i
					p.CFrame = base * t.offset
					p.Parent = skin
					local w = Instance.new("WeldConstraint")
					w.Part0 = tire
					w.Part1 = p
					w.Parent = p
				end
			end
			continue
		end
		-- imported wheels were exported at the front radius: scale to this one
		local wheel = if imported and next(imported.wheel) then imported.wheel else wheelFor(design.wheel, R, dims.wheelW, design.rimFrac, liteMode)
		local wheelScale = if imported and wheel == imported.wheel then R / dims.wheelR else 1
		if not wheel then
			break
		end
		local rest = root.CFrame * j.C0
		local left = j.C0.Position.X < 0
		local turn = if left then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		local spinCF = tire.CFrame * turn
		-- knuckle: follows steering only, carries the caliper
		local knuckle = Instance.new("Part")
		knuckle.Name = "Knuckle" .. j.Name:sub(6)
		knuckle.Size = Vector3.one * 0.2
		knuckle.Transparency = 1
		knuckle.CanCollide = false
		knuckle.CanQuery = false
		knuckle.CanTouch = false
		knuckle.Massless = true
		knuckle.CFrame = rest
		knuckle.Parent = skin
		local km = Instance.new("Motor6D")
		km.Name = "Knuckle" .. j.Name:sub(6)
		km.Part0 = root
		km.Part1 = knuckle
		km.C0 = j.C0
		km.Parent = root
		for name, t in wheel do
			local base = name:match("^%a+") or name
			local look = LOOKS[base] or LOOKS.Rim
			if base == "Caliper" then
				-- sit the caliper towards the middle of the car
				local towards = (if front then 1 else -1) * (if left then -1 else 1)
				local cf = rest * turn * (if towards < 0 then CFrame.Angles(math.rad(-86), 0, 0) else CFrame.new())
				place(t, "SkinCaliper", look, caliper, cf, knuckle, skin, wheelScale)
			else
				place(t, "Skin" .. name, look, if base == "Rim" then rim else look.color or rim, spinCF, tire, skin, wheelScale)
			end
		end
	end

	-- hide the part bodywork
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Ext") and d.Name ~= "Underglow" then
			local isWheel = d.Name:sub(1, 5) == "Wheel" and d.Parent == model
			if destroyReplaced and not isWheel and not d:FindFirstChildWhichIsA("Light") then
				d:Destroy()
			elseif destroyReplaced then
				d.Transparency = 1
			else
				d.LocalTransparencyModifier = 1
			end
		end
	end
	model:SetAttribute("Skinned", true)
	return true
end

return CarSkin
