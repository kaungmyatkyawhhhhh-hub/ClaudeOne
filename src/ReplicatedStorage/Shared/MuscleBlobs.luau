--!strict
-- MuscleBlobs: muscles made of smooth ellipsoid blobs welded to the R15 body parts (the same body for everyone: the
-- Robloxian 2.0 body, Config.Body). Each blob belongs to one muscle and grows with THAT muscle's level: level 0 = the
-- blob is a tiny speck sunk inside the body (the normal look), max = a big aesthetic muscle. Continuous (ease-out), so
-- every level grows it a little; Controller:Set tweens the change, Controller:Pulse is the small pump on every 10th level.
--  * Blobs are non-uniform spheres (SpecialMesh Sphere on a Part sized to the ellipsoid), 2-4 per muscle, overlapping so
--    they read as one smooth mass, symmetrical left/right.
--  * Massless, no collisions/queries/touches, welded; only resized when a level changes. Built once per character.
--  * Positions and sizes are written in studs for the REF part sizes and scaled to the real part size, so they follow
--    the Growth Spurt height.
--  * Colors: skin, top (the upper torso) or shorts (hips + thighs), see Controller:Dress.
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MuscleBlobs = {}

-- Part sizes (studs, height scale 1) the blob numbers below were written for.
local MIN_SIZE = 0.05
local SPECK = 0.04        -- size of a level-0 blob, as a share of its full size
local PUMP_STEP = 0.03    -- every 10th level: grow 3%, then settle
local GROWTH_POWER = 1.0 -- (blobs only show once they pass the surface, see SINK)
local PUMPED = 1.05       -- the PUMPED state: a little bigger
local STEP_EVERY = 1 / 20 -- seconds between updates while something moves

-- Blob spec: wide, shallow, flat ellipsoids that sit ON a body face with their centre INSIDE the part:
--   face "F" (front, -Z), "B" (back, +Z) or "S" (the outer side of a limb); u, v = the centre in that face, w, h = the
--   size in that face (all as fractions of the part's size in those directions); depth = ratio * width (0.4-0.6), so a
--   blob is a flat lens. The centre sits 0.17 depth inside the surface, so at most a third of the blob's thickness shows.
--   rot = degrees of tilt in the face (muscles fanning out). kind: "pair" (torso: u mirrored left/right) or "side"
--   (limbs: on the Right and Left part, u and the side face pointing outward). cover = "skin" | "top" | "shorts".
local B = {}
local DEPTH_RATIO = 0.55
local SINK = 0.17 -- the centre is this share of a blob's depth inside the body surface (so 1/3 of it shows at most)
-- the Robloxian limbs are slimmer than their part boxes: blobs are narrower there and taller (so neighbours overlap by half)
local WIDTH_FACTOR = { UpperArm = 0.95, LowerArm = 0.92, UpperLeg = 0.95, LowerLeg = 1.0 }
local HEIGHT_FACTOR = { UpperArm = 1.6, LowerArm = 1.5, UpperLeg = 1.3, LowerLeg = 1.3 }
local MUSCLE_WIDTH = { UpperChest = 1.2, MidChest = 1.2, Lats = 1.2, FrontDelts = 1.2, RearDelts = 1.2 }
local MUSCLE_HEIGHT = { UpperChest = 1.25, MidChest = 1.25, Lats = 1.1, Rhomboids = 1.2, FrontDelts = 1.3, SideDelts = 1.35, RearDelts = 1.3 }
local function add(kind: string, muscle: string, part: string, face: string, u: number, v: number, w: number, h: number, rot: number?, cover: string?, ratio: number?)
	if face ~= "S" then w *= (WIDTH_FACTOR[part] or 1) * (MUSCLE_WIDTH[muscle] or 1) end
	h *= (HEIGHT_FACTOR[part] or 1) * (MUSCLE_HEIGHT[muscle] or 1)
	table.insert(B, { kind = kind, muscle = muscle, part = part, face = face, u = u, v = v, w = w, h = h, rot = rot or 0, ratio = ratio or DEPTH_RATIO, cover = cover or (kind == "pair" and "top" or "skin") })
end
local function P(muscle, part, face, u, v, w, h, rot, cover, ratio) add("pair", muscle, part, face, u, v, w, h, rot, cover, ratio) end
local function L(muscle, part, face, u, v, w, h, rot, cover, ratio) add("side", muscle, part, face, u, v, w, h, rot, cover, ratio) end

-- Pecs: a wide shelf, fanning toward the shoulder, a clear split in the middle
P("UpperChest", "UpperTorso", "F", 0.2, 0.27, 0.34, 0.2, -6)
P("UpperChest", "UpperTorso", "F", 0.34, 0.25, 0.28, 0.18, -16)
P("UpperChest", "UpperTorso", "F", 0.125, 0.21, 0.2, 0.14, 0)
P("MidChest", "UpperTorso", "F", 0.22, 0.12, 0.38, 0.22, -4)
P("MidChest", "UpperTorso", "F", 0.37, 0.1, 0.28, 0.2, -12)
P("MidChest", "UpperTorso", "F", 0.28, -0.02, 0.34, 0.15, -6)
-- Abs: small rounded blobs in two columns with gaps (sizes and offsets vary a little)
for row = 0, 3 do
	P("Abs", "UpperTorso", "F", 0.1 + 0.004 * (row % 2), -0.1 - 0.1 * row, 0.17 - 0.006 * row, 0.098, 0, nil, 0.65)
end
-- Obliques: at the sides
P("Obliques", "UpperTorso", "F", 0.43, -0.28, 0.13, 0.26, 10)
P("Obliques", "UpperTorso", "F", 0.44, -0.46, 0.11, 0.18, 6)
-- Traps: rising from the neck to the shoulders
P("Traps", "UpperTorso", "B", 0.24, 0.44, 0.26, 0.15, 14)
P("Traps", "UpperTorso", "B", 0.37, 0.4, 0.22, 0.12, 22)
-- Lats: three flat blobs fanning from the armpit to the waist, hugging the torso (the V-taper)
P("Lats", "UpperTorso", "B", 0.3, 0.1, 0.3, 0.36, -24)
P("Lats", "UpperTorso", "B", 0.35, -0.1, 0.26, 0.34, -16)
P("Lats", "UpperTorso", "B", 0.4, -0.28, 0.2, 0.3, -8)
-- Rhomboids / upper back
P("Rhomboids", "UpperTorso", "B", 0.13, 0.3, 0.24, 0.18, 0)
P("Rhomboids", "UpperTorso", "B", 0.12, 0.12, 0.22, 0.2, 4)
-- Lower back: two smooth long ridges along the spine (2 stretched blobs each)
P("LowerBack", "UpperTorso", "B", 0.09, -0.22, 0.12, 0.3, 0)
P("LowerBack", "UpperTorso", "B", 0.1, -0.44, 0.12, 0.28, 0)
-- Glutes (stay inside the shorts)
P("Glutes", "LowerTorso", "B", 0.2, -0.15, 0.36, 1.1, 0, "shorts")
P("Glutes", "LowerTorso", "B", 0.2, -0.45, 0.3, 0.9, 0, "shorts")
-- Delts: three flat round blobs cap the shoulder (on the upper arm)
L("FrontDelts", "UpperArm", "F", 0.08, 0.36, 0.9, 0.34)
L("SideDelts", "UpperArm", "S", 0.0, 0.38, 0.8, 0.36, 0, nil, 0.6)
L("RearDelts", "UpperArm", "B", 0.08, 0.36, 0.9, 0.32)
-- Biceps: stacked, overlapping, with a peak
L("Biceps", "UpperArm", "F", 0.0, 0.17, 0.74, 0.38)
L("Biceps", "UpperArm", "F", 0.0, -0.04, 0.68, 0.36)
L("Biceps", "UpperArm", "F", 0.0, -0.24, 0.6, 0.3)
-- Triceps: the horseshoe on the back of the arm
L("Triceps", "UpperArm", "B", 0.2, 0.1, 0.5, 0.5)
L("Triceps", "UpperArm", "B", -0.2, 0.1, 0.5, 0.5)
L("Triceps", "UpperArm", "B", 0.0, -0.2, 0.6, 0.36)
-- Forearms: thick near the elbow
L("Forearms", "LowerArm", "F", 0.0, 0.2, 0.86, 0.46)
L("Forearms", "LowerArm", "F", 0.0, -0.1, 0.76, 0.44)
L("Forearms", "LowerArm", "B", 0.0, 0.16, 0.74, 0.42)
L("Forearms", "LowerArm", "B", 0.0, -0.12, 0.64, 0.4)
-- Quads: a teardrop above the knee, the middle and the sweep on the outside (under the shorts color)
L("Quads", "UpperLeg", "F", 0.0, -0.28, 0.7, 0.3, 0, "shorts")
L("Quads", "UpperLeg", "F", 0.03, 0.04, 0.76, 0.5, 0, "shorts")
L("Quads", "UpperLeg", "F", 0.26, 0.0, 0.44, 0.62, 6, "shorts")
-- Hamstrings
L("Hamstrings", "UpperLeg", "B", 0.18, 0.05, 0.5, 0.6, 0, "shorts")
L("Hamstrings", "UpperLeg", "B", -0.18, 0.05, 0.5, 0.6, 0, "shorts")
-- Calves: one diamond
L("Calves", "LowerLeg", "B", 0.13, 0.14, 0.56, 0.6)
L("Calves", "LowerLeg", "B", -0.13, 0.14, 0.56, 0.6)

-- The Robloxian meshes do not fill their part boxes, so the real surface is measured once by raycasting the actual body
-- parts: Profiles[key][face] = a 9x9 grid of how far out the mesh surface is, as a share of half the part size along the
-- face's normal (1 = at the box). The same body is used by everyone, so one measurement serves every rig.
local GRID = 9
local Profiles: { [string]: { [string]: { number } } } = {}

local function faceVectors(face: string, sign: number): (Vector3, Vector3)
	if face == "S" then return Vector3.new(sign, 0, 0), Vector3.new(0, 0, 1) end
	return Vector3.new(0, 0, face == "F" and -1 or 1), Vector3.new(1, 0, 0)
end

local function measure(part: BasePart, face: string): { number }?
	if not part:IsDescendantOf(workspace) then return nil end
	local size = part.Size
	local normal, uAxis = faceVectors(face, 1)
	local dimU = face == "S" and size.Z or size.X
	local dimN = face == "S" and size.X or size.Z
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { part }
	local grid = {}
	for iv = 0, GRID - 1 do
		for iu = 0, GRID - 1 do
			local u = iu / (GRID - 1) - 0.5
			local v = iv / (GRID - 1) - 0.5
			local localOrigin = normal * dimN * 1.5 + uAxis * (u * dimU) + Vector3.new(0, v * size.Y, 0)
			local origin = part.CFrame:PointToWorldSpace(localOrigin)
			local direction = part.CFrame:VectorToWorldSpace(-normal * dimN * 3)
			local hit = workspace:Raycast(origin, direction, params)
			local frac = 0.4
			if hit then
				frac = math.clamp(part.CFrame:PointToObjectSpace(hit.Position):Dot(normal) / (0.5 * dimN), 0, 1)
			end
			grid[iv * GRID + iu + 1] = frac
		end
	end
	return grid
end

-- Make sure the profile of a part (all three faces) exists; `part` must be in the Workspace. key = the part name
-- without Left/Right (limbs are measured on the Right part: the outward face is +X there).
local function ensureProfile(key: string, part: BasePart): boolean
	if Profiles[key] then return true end
	local faces = {}
	for _, face in ipairs({ "F", "B", "S" }) do
		local grid = measure(part, face)
		if not grid then return false end
		faces[face] = grid
	end
	Profiles[key] = faces
	return true
end

local function baseName(partName: string): string
	local name = string.gsub(partName, "^Left", "")
	name = string.gsub(name, "^Right", "")
	return name
end

-- How far out the surface is at (u, v) of a face (fractions of the part size, -0.5..0.5), 0..1 of half the normal size.
local function surfaceAt(key: string, face: string, u: number, v: number): number
	local faces = Profiles[key]
	local grid = faces and faces[face]
	if not grid then return 1 end
	local fu = math.clamp(u + 0.5, 0, 1) * (GRID - 1)
	local fv = math.clamp(v + 0.5, 0, 1) * (GRID - 1)
	local u0, v0 = math.floor(fu), math.floor(fv)
	local u1, v1 = math.min(u0 + 1, GRID - 1), math.min(v0 + 1, GRID - 1)
	local au, av = fu - u0, fv - v0
	local function at(iu: number, iv: number): number return grid[iv * GRID + iu + 1] end
	local top = at(u0, v0) * (1 - au) + at(u1, v0) * au
	local bottom = at(u0, v1) * (1 - au) + at(u1, v1) * au
	return top * (1 - av) + bottom * av
end

-- Where a blob goes on a part of size `size`: its full size and its offset from the part (local to the part).
-- sign = +1 for the right/positive side, -1 for the left (u mirrors; the side face points outward).
local function layout(spec: any, sign: number, size: Vector3, partName: string): (Vector3, CFrame)
	local dimU, dimV, dimN, normal, uAxis
	if spec.face == "S" then
		dimU, dimV, dimN = size.Z, size.Y, size.X
		normal, uAxis = Vector3.new(sign, 0, 0), Vector3.new(0, 0, 1)
	else
		dimU, dimV, dimN = size.X, size.Y, size.Z
		normal, uAxis = Vector3.new(0, 0, spec.face == "F" and -1 or 1), Vector3.new(sign, 0, 0)
	end
	local width = spec.w * dimU
	local depth = math.min(spec.ratio * width, dimN * 0.8)
	-- the real surface under the blob (limbs: u points outward on both sides; torso: u mirrors with the side)
	local sample = surfaceAt(baseName(partName), spec.face, spec.kind == "pair" and spec.u * sign or spec.u, spec.v)
	local center = normal * (0.5 * dimN * sample - SINK * depth) + uAxis * (spec.u * dimU) + Vector3.new(0, spec.v * dimV, 0)
	local blobSize = spec.face == "S" and Vector3.new(depth, spec.h * dimV, width) or Vector3.new(width, spec.h * dimV, depth)
	local axis = spec.face == "S" and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
	local rotation = math.rad(spec.rot) * (spec.face == "S" and 1 or sign)
	return blobSize, CFrame.new(center) * CFrame.fromAxisAngle(axis, rotation)
end

MuscleBlobs.Specs = B

-- the muscles the blobs belong to (for building level tables)
MuscleBlobs.Muscles = {}
do
	local seen = {}
	for _, spec in ipairs(B) do
		if not seen[spec.muscle] then
			seen[spec.muscle] = true
			table.insert(MuscleBlobs.Muscles, spec.muscle)
		end
	end
end

-- Growth from a muscle level: 0 at level 0, 1 at the goal, ease-out in between.
function MuscleBlobs.Growth(level: number, goal: number): number
	local t = math.clamp(level / math.max(goal, 1), 0, 1)
	return 1 - (1 - t) ^ 2
end

------------------------------------------------------------------------
-- Controller
------------------------------------------------------------------------
type Entry = {
	muscle: string,
	partName: string,
	blob: BasePart,
	weld: Weld,
	spec: any,
	sign: number,
	cover: string,
	tone: number,
	hidden: boolean,
}

local Controller: any = {}
Controller.__index = Controller

local function sideName(part: string, side: string): string
	return side .. part
end

-- One SurfaceAppearance template (skin_color + skin_roughness) in ReplicatedStorage, cloned onto every blob and body part and
-- tinted to the skin color. One sphere MeshPart template is cloned for every blob (SurfaceAppearance needs a MeshPart).
-- (ColorMap/RoughnessMap can't be written by scripts at runtime, so the template is made once in Studio: tools/builders/SkinSurface.luau)
local function skinTemplate(): SurfaceAppearance?
	local found = ReplicatedStorage:FindFirstChild("SkinSurface")
	if found and found:IsA("SurfaceAppearance") then return found end
	return nil
end

-- A real sphere MeshPart (the only blob shape a SurfaceAppearance can texture). Roblox has no sphere mesh asset, so it is
-- built once from an EditableMesh (needs "Allow Editable Mesh" in the experience's Security settings). If that is off,
-- blobs fall back to plain-colored SpecialMesh spheres and the skin texture is not used anywhere (no mismatched seams).
local sphereTemplate: MeshPart? = nil
local sphereChecked = false
local function sphere(): MeshPart?
	if sphereChecked then return sphereTemplate end
	sphereChecked = true
	local ok, result = pcall(function()
		local em = AssetService:CreateEditableMesh()
		local seg, ring = 20, 12
		local top = em:AddVertex(Vector3.new(0, 0.5, 0))
		local grid = {}
		for r = 1, ring - 1 do
			local phi = math.pi * r / ring
			grid[r] = {}
			for s = 0, seg - 1 do
				local th = 2 * math.pi * s / seg
				grid[r][s] = em:AddVertex(Vector3.new(0.5 * math.sin(phi) * math.cos(th), 0.5 * math.cos(phi), 0.5 * math.sin(phi) * math.sin(th)))
			end
		end
		local bottom = em:AddVertex(Vector3.new(0, -0.5, 0))
		for s = 0, seg - 1 do
			local n = (s + 1) % seg
			em:AddTriangle(top, grid[1][n], grid[1][s])
			em:AddTriangle(bottom, grid[ring - 1][s], grid[ring - 1][n])
		end
		for r = 1, ring - 2 do
			for s = 0, seg - 1 do
				local n = (s + 1) % seg
				em:AddTriangle(grid[r][s], grid[r][n], grid[r + 1][s])
				em:AddTriangle(grid[r][n], grid[r + 1][n], grid[r + 1][s])
			end
		end
		return AssetService:CreateMeshPartAsync(Content.fromObject(em))
	end)
	if ok and result then
		sphereTemplate = result
	else
		warn("[MuscleBlobs] no sphere MeshPart (enable Editable Mesh in the experience's Security settings for the skin texture): " .. tostring(result))
	end
	return sphereTemplate
end

-- Are blobs and body textured? (only with the sphere MeshPart)
local function texturing(): boolean
	return sphere() ~= nil and skinTemplate() ~= nil
end

local function setSkin(part: BasePart, color: Color3, textured: boolean)
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if textured and texturing() then
		if not sa then
			sa = (skinTemplate() :: SurfaceAppearance):Clone()
			sa.Parent = part
		end
		sa.Color = color
	elseif sa then
		sa:Destroy()
	end
	if part.Color ~= color then part.Color = color end
end

local function makeBlob(model: Model, folder: Folder, partName: string, spec: any, name: string, mirrorX: number, castShadow: boolean, static: boolean): Entry?
	local part = model:FindFirstChild(partName)
	if not part or not part:IsA("BasePart") then return nil end
	local template = sphere()
	local blob: BasePart = if template then template:Clone() else Instance.new("Part")
	blob.Name = name
	blob:SetAttribute("MuscleName", spec.muscle) -- for the stats hover highlights
	blob.Size = Vector3.new(MIN_SIZE, MIN_SIZE, MIN_SIZE)
	blob.Massless = true
	blob.CanCollide, blob.CanQuery, blob.CanTouch = false, false, false
	blob.CastShadow = castShadow
	blob.Anchored = static
	blob.Material = Enum.Material.SmoothPlastic -- a soft sheen like the body (set in Dress)
	blob.Color = part.Color
	blob.Transparency = 1
	blob.TopSurface, blob.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if not template then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = blob
	end
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1 = part, blob
	weld.Parent = blob
	blob.Parent = folder
	return {
		muscle = spec.muscle,
		partName = partName,
		blob = blob,
		weld = weld,
		spec = spec,
		sign = mirrorX,
		tone = (#spec.muscle * 0.37 + mirrorX * 0.11 + spec.u * 3.1 + spec.v * 5.3) % 1,
		cover = spec.cover,
			hidden = true,
	}
end

-- opts: castShadow (default false), static (true for anchored rigs: blobs are anchored and placed by CFrame)
function MuscleBlobs.Build(model: Model, opts: any?): any
	local options = opts or {}
	local old = model:FindFirstChild("MuscleBlobs")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "MuscleBlobs"
	local self = setmetatable({
		model = model, folder = folder, entries = {}, byMuscle = {}, cur = {}, from = {}, to = {}, pulses = {},
		startTime = 0, duration = 0, pumped = false, conn = nil, lastStep = 0, static = options.static == true,
		colors = {}, garments = {}, styleKey = "",
	}, Controller)
	-- measure the real body surface once (needs the parts to be in the Workspace)
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" }) do
		local part = model:FindFirstChild((name == "UpperTorso" or name == "LowerTorso") and name or ("Right" .. name))
		if part and part:IsA("BasePart") then ensureProfile(name, part) end
	end
	local shadow = options.castShadow == true
	local counter = 0
	for _, spec in ipairs(B) do
		local list: { { part: string, mirror: number } } = {}
		if spec.kind == "pair" then
			list = { { part = spec.part, mirror = 1 }, { part = spec.part, mirror = -1 } }
		elseif spec.kind == "side" then
			list = { { part = sideName(spec.part, "Right"), mirror = 1 }, { part = sideName(spec.part, "Left"), mirror = -1 } }
		else
			list = { { part = spec.part, mirror = 1 } }
		end
		for _, item in ipairs(list) do
			counter += 1
			local entry = makeBlob(model, folder, item.part, spec, "Blob_" .. spec.muscle .. counter, item.mirror, shadow, self.static)
			if entry then
				table.insert(self.entries, entry)
				self.byMuscle[spec.muscle] = self.byMuscle[spec.muscle] or {}
				table.insert(self.byMuscle[spec.muscle], entry)
				self.cur[spec.muscle] = 0
			end
		end
	end
	folder.Parent = model
	return self
end

local function pulseAmount(self: any, muscle: string, now: number): number
	local started = self.pulses[muscle]
	if not started then return 0 end
	local t = now - started
	if t < 0.15 then return t / 0.15 end
	if t < 0.55 then return 1 - (t - 0.15) / 0.4 end
	self.pulses[muscle] = nil
	return 0
end

local renderGarments: (any) -> () = function() end -- (defined below, with the garments)

-- Write the current growth to the blobs.
local function render(self: any)
	local now = os.clock()
	local pumpedScale = self.pumped and PUMPED or 1
	for _, entry in ipairs(self.entries) do
		local part = entry.weld.Part0
		if not part then continue end
		local fullSize, offset = layout(entry.spec, entry.sign, part.Size, entry.partName)
		local g = self.cur[entry.muscle] or 0
		if g <= 0.001 then
			if not entry.hidden then
				entry.hidden = true
				entry.blob.Transparency = 1
			end
		else
			local f = (SPECK + (1 - SPECK) * g ^ GROWTH_POWER) * (1 + PUMP_STEP * pulseAmount(self, entry.muscle, now)) * pumpedScale
			local size = fullSize * f
			entry.blob.Size = Vector3.new(math.max(size.X, MIN_SIZE), math.max(size.Y, MIN_SIZE), math.max(size.Z, MIN_SIZE))
			if entry.hidden then
				entry.hidden = false
				entry.blob.Transparency = 0
			end
		end
		entry.weld.C0 = offset
		if self.static then entry.blob.CFrame = part.CFrame * entry.weld.C0 end
	end
	renderGarments(self)
end

local function stop(self: any)
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
end

local function step(self: any)
	local now = os.clock()
	if now - self.lastStep < STEP_EVERY then return end
	self.lastStep = now
	if not self.model.Parent then
		stop(self)
		return
	end
	local t = self.duration > 0 and math.clamp((now - self.startTime) / self.duration, 0, 1) or 1
	local eased = t * t * (3 - 2 * t)
	for muscle, target in pairs(self.to) do
		local from = self.from[muscle] or target
		self.cur[muscle] = from + (target - from) * eased
	end
	render(self)
	if t >= 1 and next(self.pulses) == nil then stop(self) end
end

local function run(self: any)
	if not self.conn then
		self.lastStep = 0
		self.conn = RunService.Heartbeat:Connect(function() step(self) end)
	end
end

-- levels: { [muscleId] = level }, goal = the Growth Spurt goal level. Tweens over `duration` seconds (0 = at once).
function Controller.Set(self: any, levels: { [string]: number }, goal: number, duration: number)
	self.from, self.to = {}, {}
	for muscle, g in pairs(self.cur) do
		self.from[muscle] = g
		self.to[muscle] = MuscleBlobs.Growth(levels[muscle] or 0, goal)
	end
	self.startTime = os.clock()
	self.duration = duration
	if duration <= 0 then
		for muscle, target in pairs(self.to) do self.cur[muscle] = target end
		render(self)
	else
		run(self)
	end
end

-- Every muscle at the same share of the goal (0..1): NPC presets and the statue.
function Controller.SetShare(self: any, share: number, duration: number)
	local levels = {}
	for _, muscle in ipairs(MuscleBlobs.Muscles) do levels[muscle] = share * 1000 end
	self:Set(levels, 1000, duration)
end

function Controller.Pulse(self: any, muscles: { string })
	local now = os.clock()
	for _, muscle in ipairs(muscles) do
		if self.byMuscle[muscle] then self.pulses[muscle] = now end
	end
	run(self)
end

function Controller.SetPumped(self: any, pumped: boolean)
	if self.pumped == pumped then return end
	self.pumped = pumped
	render(self)
end

-- Re-write sizes and positions (after a height change, or after SolveJoints moved a static rig's parts).
function Controller.Refresh(self: any)
	render(self)
end

-- Garments: the game's gym shorts and the wardrobe tops are thin welded cylinders around the body parts (the body
-- parts themselves are always plain skin). They are sized from the real part sizes, so they follow the height.
local function garmentSize(kind: string, part: BasePart): (Vector3, CFrame)
	local s = part.Size
	local up = CFrame.Angles(0, 0, math.pi / 2) -- a Cylinder's length runs along X: stand it up
	if kind == "hip" then
		local h = s.Y * 1.25
		return Vector3.new(h, s.X * 1.08, s.Z * 1.08), CFrame.new(0, -s.Y * 0.1, 0) * up
	elseif kind == "leg" then
		local h = s.Y * 0.78
		return Vector3.new(h, s.X * 1.32, s.Z * 1.16), CFrame.new(0, s.Y / 2 - h / 2 + s.Y * 0.03, 0) * up
	elseif kind == "tank" then
		local h = s.Y * 0.98
		return Vector3.new(h, s.X * 1.04, s.Z * 1.06), CFrame.new(0, 0, 0) * up
	else -- "sports": the upper part only
		local h = s.Y * 0.6
		return Vector3.new(h, s.X * 1.04, s.Z * 1.06), CFrame.new(0, s.Y / 2 - h / 2, 0) * up
	end
end

local function clearGarments(self: any)
	for _, g in ipairs(self.garments) do g.blob:Destroy() end
	self.garments = {}
end

local function addGarment(self: any, kind: string, partName: string, color: Color3)
	local part = self.model:FindFirstChild(partName)
	if not part or not part:IsA("BasePart") then return end
	local g = Instance.new("Part")
	g.Name = "Garment_" .. kind
	g.Shape = Enum.PartType.Cylinder
	g.Massless = true
	g.CanCollide, g.CanQuery, g.CanTouch = false, false, false
	g.CastShadow = false
	g.Anchored = self.static
	g.Material = Enum.Material.Fabric
	g.Color = color
	g.TopSurface, g.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1 = part, g
	weld.Parent = g
	g.Parent = self.folder
	table.insert(self.garments, { blob = g, weld = weld, kind = kind, partName = partName })
end

renderGarments = function(self: any)
	for _, g in ipairs(self.garments) do
		local part = g.weld.Part0
		if part then
			local size, c0 = garmentSize(g.kind, part)
			g.blob.Size = size
			g.weld.C0 = c0
			if self.static then g.blob.CFrame = part.CFrame * c0 end
		end
	end
end

-- Paint the body and the blobs. style: skin (Color3), top (Color3 or nil = shirtless), shorts (Color3), topKind
-- ("tank" | "sports"), keepParts (NPCs: leave their painted clothes alone, blobs only).
function Controller.Dress(self: any, style: { skin: Color3, top: Color3?, shorts: Color3, topKind: string?, keepParts: boolean?, plain: boolean? })
	local model: Model = self.model
	local key = tostring(style.skin) .. tostring(style.top) .. tostring(style.shorts) .. tostring(style.topKind) .. tostring(style.keepParts)
	if not style.keepParts then
		for _, name in ipairs({ "UpperTorso", "LowerTorso", "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" }) do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				setSkin(part, style.skin, not style.plain)
				part.Material = Enum.Material.SmoothPlastic
			end
		end
		if self.styleKey ~= key or #self.garments == 0 then
			clearGarments(self)
			addGarment(self, "hip", "LowerTorso", style.shorts)
			addGarment(self, "leg", "RightUpperLeg", style.shorts)
			addGarment(self, "leg", "LeftUpperLeg", style.shorts)
			if style.top then addGarment(self, style.topKind == "sports" and "sports" or "tank", "UpperTorso", style.top) end
			renderGarments(self)
		end
	end
	self.styleKey = key
	for _, entry in ipairs(self.entries) do
		local color = style.skin
		if entry.cover == "top" then color = style.top or style.skin
		elseif entry.cover == "shorts" then color = style.shorts end
		-- a very small tone change per blob (like mottled skin) so the mass reads as flesh, not one flat color
		local tone = 1 + ((entry.tone or 0) - 0.5) * 0.025
		color = Color3.new(math.clamp(color.R * tone, 0, 1), math.clamp(color.G * tone, 0, 1), math.clamp(color.B * tone, 0, 1))
		setSkin(entry.blob, color, not (style.plain or style.keepParts))
		entry.blob.Material = Enum.Material.SmoothPlastic
	end
end

function Controller.Destroy(self: any)
	stop(self)
	if self.folder then self.folder:Destroy() end
end

return MuscleBlobs
