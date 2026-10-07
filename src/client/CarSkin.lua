--[[
	CarSkin (client)
	Swaps the blocky part shell of a car for smooth generated meshes
	(BodyMesh -> EditableMesh -> MeshPart). Lights, wheels, mirrors, spoilers,
	grilles and the whole interior stay as detail parts.

	Meshes are generated once per body style and cloned for every car, so a
	city full of traffic costs only five meshes. If the engine refuses runtime
	meshes (e.g. the place hasn't allowed Mesh APIs) every call simply returns
	false and the cars keep their part bodies.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BodyMesh = require(Shared:WaitForChild("BodyMesh"))
local CarBuilder = require(Shared:WaitForChild("CarBuilder"))

local CarSkin = {}

-- part-shell pieces the meshes replace
local REPLACED = {
	FrontBumper = true, HoodSlope = true, Hood = true, DoorL = true, DoorR = true, Tail = true,
	Ducktail = true, Windshield = true, SideGlassL = true, SideGlassR = true, RearGlass = true,
	Roof = true, SillL = true, SillR = true, APillar = true, CPillar = true, DPillar = true,
	BPillar = true, BeltTrim = true, Arch = true, Seam = true,
}

type Template = { part: MeshPart, center: Vector3 }
type ClassMeshes = { body: Template, glass: Template, roof: Template }

local cache: { [string]: ClassMeshes | false } = {}
local keepAlive: { any } = {} -- EditableMeshes must stay alive while their MeshParts render
local warned = false

local function build(mesh: BodyMesh.Mesh): Template
	local minV = Vector3.one * math.huge
	local maxV = -Vector3.one * math.huge
	for _, v in mesh.verts do
		minV = minV:Min(v)
		maxV = maxV:Max(v)
	end
	local center = (minV + maxV) / 2
	local normals = BodyMesh.normals(mesh)
	local em = AssetService:CreateEditableMesh()
	local vids = table.create(#mesh.verts, 0)
	local nids = table.create(#mesh.verts, 0)
	for i, v in mesh.verts do
		vids[i] = em:AddVertex(v - center)
		nids[i] = em:AddNormal(normals[i])
	end
	for _, t in mesh.tris do
		local face = em:AddTriangle(vids[t[1]], vids[t[2]], vids[t[3]])
		em:SetFaceNormals(face, { nids[t[1]], nids[t[2]], nids[t[3]] })
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	part.Size = maxV - minV
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	table.insert(keepAlive, em)
	return { part = part, center = center }
end

local function templatesFor(class: string): ClassMeshes?
	local cached = cache[class]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local ok, result = pcall(function()
		local geo = BodyMesh.generate(class, CarBuilder.getDims(class) :: any)
		return { body = build(geo.body), glass = build(geo.glass), roof = build(geo.roof) }
	end)
	if ok then
		cache[class] = result
		return result
	end
	cache[class] = false
	if not warned then
		warned = true
		warn("[CityLegends] Smooth car bodies unavailable, using part bodies instead:", result)
	end
	return nil
end

-- Generate every body style up front (call during the loading screen)
function CarSkin.preload()
	for _, class in { "Sedan", "Coupe", "SUV", "Supercar", "Hypercar" } do
		templatesFor(class)
	end
end

function CarSkin.isSupported(): boolean
	for _, v in cache do
		if v then
			return true
		end
	end
	return false
end

--[[
	destroyReplaced: true for local-only models (traffic, cutscene, garage
	preview) - the old shell is deleted. For replicated player cars it is
	hidden with LocalTransparencyModifier instead.
]]
function CarSkin.apply(model: Model, destroyReplaced: boolean?): boolean
	if model:GetAttribute("Skinned") then
		return true
	end
	local class = model:GetAttribute("Class")
	local root = model.PrimaryPart
	if type(class) ~= "string" or not root then
		return false
	end
	local templates = templatesFor(class)
	if not templates then
		return false
	end
	local height = (model:GetAttribute("Height") :: number?) or 4
	local groundCF = root.CFrame * CFrame.new(0, -height / 2, 0)

	local paint = model:FindFirstChild("DoorL") or model:FindFirstChild("Tail")
	local roofSrc = model:FindFirstChild("Roof")
	local paintColor = if paint and paint:IsA("BasePart") then paint.Color else Color3.fromRGB(180, 180, 185)
	local roofColor = if roofSrc and roofSrc:IsA("BasePart") then roofSrc.Color else paintColor

	local function place(t: Template, name: string, color: Color3, material: Enum.Material, reflectance: number, transparency: number)
		local p = t.part:Clone()
		p.Name = name
		p.Color = color
		p.Material = material
		p.Reflectance = reflectance
		p.Transparency = transparency
		p.CFrame = groundCF * CFrame.new(t.center)
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		return p
	end
	place(templates.body, "SkinBody", paintColor, Enum.Material.SmoothPlastic, 0.16, 0)
	place(templates.glass, "SkinGlass", Color3.fromRGB(14, 18, 24), Enum.Material.Glass, 0.3, 0.2)
	place(templates.roof, "SkinRoof", roofColor, Enum.Material.SmoothPlastic, 0.16, 0)

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and REPLACED[d.Name] then
			if destroyReplaced then
				d:Destroy()
			else
				d.LocalTransparencyModifier = 1
			end
		end
	end
	model:SetAttribute("Skinned", true)
	return true
end

return CarSkin
