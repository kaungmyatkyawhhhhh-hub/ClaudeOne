--[[
	BuildingSkin (client)
	Paints every tower with generated PBR facade textures (FacadeTex ->
	EditableImage -> tiled Texture): colour, emissive (lit rooms glow), normal,
	roughness and metalness. The part-built window strips, panes, mullions and
	ledges it replaces are removed locally, which also takes ~25k parts out of
	the scene.

	If runtime images aren't available (e.g. the place hasn't allowed the
	Mesh / Image APIs) nothing changes and the part facades stay.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacadeTex = require(Shared:WaitForChild("FacadeTex"))

local BuildingSkin = {}

local REMOVE = { WinLit = true, Pane = true, Fin = true, Ledge = true }
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

type Maps = { color: any, emissive: any }
type Surface = { normal: any, rough: any, metal: any }

local keepAlive: { any } = {}

local function image(buf: buffer): any
	local N = FacadeTex.SIZE
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(N, N) })
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(N, N), buf)
	table.insert(keepAlive, img)
	return Content.fromObject(img)
end

local function buildLibrary(): ({ [string]: Maps }, { [string]: Surface })
	local moods: { [string]: Maps } = {}
	local surfaces: { [string]: Surface } = {}
	for style in FacadeTex.STYLES do
		local n, r, m = FacadeTex.surface(style)
		surfaces[style] = { normal = image(n), rough = image(r), metal = image(m) }
		for _, warm in { true, false } do
			for _, busy in { true, false } do
				local c, e = FacadeTex.generate(style, warm, busy)
				moods[style .. tostring(warm) .. tostring(busy)] = { color = image(c), emissive = image(e) }
				task.wait() -- spread the work over frames
			end
		end
	end
	return moods, surfaces
end

function BuildingSkin.apply(city: Instance): boolean
	local ok, moods, surfaces = pcall(buildLibrary)
	if not ok then
		warn("[CityLegends] Facade textures unavailable, keeping part facades:", moods)
		return false
	end

	local towers: { BasePart } = {}
	local remove: { Instance } = {}
	for _, d in city:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Tower" and d:GetAttribute("Style") then
				table.insert(towers, d)
			elseif REMOVE[d.Name] then
				table.insert(remove, d)
			end
		end
	end

	local rng = Random.new(4242)
	for i, tower in towers do
		local style = tower:GetAttribute("Style") :: string
		local module = (tower:GetAttribute("Module") :: number?) or 7
		local warm = tower:GetAttribute("Warm") == true
		local busy = tower:GetAttribute("Busy") == true
		local skip = tower:GetAttribute("SkipFace") :: Vector3?
		local maps = moods[style .. tostring(warm) .. tostring(busy)]
		local surf = surfaces[style]
		if maps and surf then
			local offsetU = rng:NextNumber(0, FacadeTex.tileStudsU(module))
			for _, face in FACES do
				local normal = tower.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))
				if not (skip and normal:Dot(skip) > 0.9) then
					local tex = Instance.new("Texture")
					tex.Face = face
					tex.ColorMapContent = maps.color
					tex.EmissiveMaskContent = maps.emissive
					tex.EmissiveStrength = 1.4
					tex.EmissiveTint = Color3.new(1, 1, 1)
					tex.NormalMapContent = surf.normal
					tex.RoughnessMapContent = surf.rough
					tex.MetalnessMapContent = surf.metal
					tex.StudsPerTileU = FacadeTex.tileStudsU(module)
					tex.StudsPerTileV = FacadeTex.tileStudsV()
					tex.OffsetStudsU = offsetU
					tex.Parent = tower
				end
			end
			-- the texture carries the look now; a plain matte core avoids glass refraction artefacts
			tower.Material = Enum.Material.SmoothPlastic
			tower.Reflectance = 0
		end
		if i % 60 == 0 then
			task.wait()
		end
	end

	for i, p in remove do
		p:Destroy()
		if i % 2000 == 0 then
			task.wait()
		end
	end
	-- drop the now-empty facade LOD groups so the LOD system ignores them
	for _, d in city:GetDescendants() do
		if d:IsA("Model") and d.Name == "Facade" and #d:GetChildren() == 0 then
			d:Destroy()
		end
	end
	return true
end

return BuildingSkin
