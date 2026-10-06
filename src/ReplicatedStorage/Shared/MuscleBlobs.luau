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

local MuscleBlobs = {}

-- Part sizes (studs, height scale 1) the blob numbers below were written for.
local REF = {
	UpperTorso = Vector3.new(2, 1.6, 1),
	LowerTorso = Vector3.new(2, 0.4, 1),
	UpperArm = Vector3.new(1, 1.2, 1),
	LowerArm = Vector3.new(1, 1.1, 1),
	UpperLeg = Vector3.new(1, 1.2, 1),
	LowerLeg = Vector3.new(1, 1.1, 1),
}

local MIN_SIZE = 0.05
local SPECK = 0.04        -- size of a level-0 blob, as a share of its full size
local PUMP_STEP = 0.03    -- every 10th level: grow 3%, then settle
local GROWTH_POWER = 1.35 -- small levels stay sunk in (no lonely bumps), the shape fills out later
local PUMPED = 1.05       -- the PUMPED state: a little bigger
local STEP_EVERY = 1 / 20 -- seconds between updates while something moves

-- Blob = { muscle, part, pos = (x, y, z), size = (dx, dy, dz), mirror = true (torso pairs: also at -x) or side = true
-- (limbs: on the Left and Right part, x pointing outward), cover = "skin" | "top" | "shorts" }.
-- Front is -Z, back +Z, up +Y, the character's right is +X.
local B = {}
local function blob(muscle: string, part: string, x: number, y: number, z: number, dx: number, dy: number, dz: number, kind: string, cover: string)
	table.insert(B, { muscle = muscle, part = part, pos = Vector3.new(x, y, z), size = Vector3.new(dx, dy, dz), kind = kind, cover = cover })
end
-- torso pairs (mirror) and limbs (side)
local function pair(muscle: string, part: string, x: number, y: number, z: number, dx: number, dy: number, dz: number, cover: string?) blob(muscle, part, x, y, z, dx, dy, dz, "mirror", cover or "top") end
local function limb(muscle: string, part: string, x: number, y: number, z: number, dx: number, dy: number, dz: number, cover: string?) blob(muscle, part, x, y, z, dx, dy, dz, "side", cover or "skin") end

-- Pecs: a big shelf with a clear split in the middle
pair("UpperChest", "UpperTorso", 0.44, 0.44, -0.34, 0.76, 0.5, 0.62)
pair("UpperChest", "UpperTorso", 0.78, 0.42, -0.26, 0.6, 0.48, 0.54)
pair("MidChest", "UpperTorso", 0.46, 0.12, -0.36, 0.8, 0.56, 0.62)
pair("MidChest", "UpperTorso", 0.82, 0.14, -0.26, 0.58, 0.52, 0.52)
pair("MidChest", "UpperTorso", 0.56, 0.0, -0.34, 0.62, 0.34, 0.46)
-- Traps: rising from the neck to the shoulders (clear of the neck)
pair("Traps", "UpperTorso", 0.62, 0.74, 0.14, 0.64, 0.46, 0.54)
pair("Traps", "UpperTorso", 0.92, 0.7, 0.1, 0.54, 0.38, 0.5)
-- Lats: flaring out for the V-taper
pair("Lats", "UpperTorso", 0.74, 0.0, 0.34, 0.7, 1.0, 0.5)
pair("Lats", "UpperTorso", 0.9, -0.28, 0.3, 0.56, 0.8, 0.46)
pair("Lats", "UpperTorso", 0.94, 0.08, 0.2, 0.42, 0.9, 0.42)
-- Rhomboids / upper back: two stacked blobs per side along the spine
pair("Rhomboids", "UpperTorso", 0.3, 0.38, 0.36, 0.58, 0.54, 0.4)
pair("Rhomboids", "UpperTorso", 0.32, 0.0, 0.36, 0.56, 0.5, 0.4)
-- Lower back: two columns along the spine
pair("LowerBack", "UpperTorso", 0.26, -0.5, 0.35, 0.44, 0.8, 0.36)
pair("LowerBack", "LowerTorso", 0.28, 0.0, 0.35, 0.48, 0.38, 0.36, "shorts")
-- Abs: small rounded blobs in two columns with gaps between them
for row = 0, 2 do
	pair("Abs", "UpperTorso", 0.19, -0.14 - row * 0.24, -0.4, 0.3, 0.22, 0.28)
end
-- Obliques: at the sides
pair("Obliques", "UpperTorso", 0.9, -0.34, -0.1, 0.4, 0.66, 0.5)
-- Glutes
pair("Glutes", "LowerTorso", 0.4, -0.12, 0.3, 0.85, 0.55, 0.6, "shorts")
-- Delts: three big round blobs cap the shoulder (on the upper arm)
limb("FrontDelts", "UpperArm", 0.04, 0.4, -0.3, 0.98, 0.84, 0.76)
limb("SideDelts", "UpperArm", 0.24, 0.44, 0.0, 1.3, 1.0, 1.0)
limb("RearDelts", "UpperArm", 0.04, 0.4, 0.3, 0.98, 0.82, 0.74)
-- Biceps: stacked blobs with a peak
limb("Biceps", "UpperArm", 0.0, 0.2, -0.24, 1.0, 0.58, 0.64)
limb("Biceps", "UpperArm", 0.0, -0.06, -0.2, 0.92, 0.58, 0.6)
limb("Biceps", "UpperArm", 0.0, -0.3, -0.14, 0.84, 0.5, 0.52)
-- Triceps: the horseshoe on the back of the arm
limb("Triceps", "UpperArm", 0.26, 0.14, 0.26, 0.7, 0.74, 0.56)
limb("Triceps", "UpperArm", -0.26, 0.14, 0.26, 0.7, 0.74, 0.56)
limb("Triceps", "UpperArm", 0.0, -0.16, 0.28, 0.78, 0.62, 0.54)
-- Forearms: thick near the elbow
limb("Forearms", "LowerArm", 0.0, 0.24, -0.04, 1.0, 0.64, 0.92)
limb("Forearms", "LowerArm", 0.0, -0.06, 0.0, 0.88, 0.64, 0.82)
-- Quads: a teardrop above the knee, the middle, and the sweep on the outside
limb("Quads", "UpperLeg", 0.0, -0.3, -0.22, 0.86, 0.56, 0.56, "shorts")
limb("Quads", "UpperLeg", 0.04, 0.08, -0.2, 0.98, 0.92, 0.6, "shorts")
limb("Quads", "UpperLeg", 0.32, 0.0, -0.1, 0.66, 1.02, 0.58, "shorts")
-- Hamstrings
limb("Hamstrings", "UpperLeg", 0.2, 0.05, 0.24, 0.7, 0.96, 0.56, "shorts")
limb("Hamstrings", "UpperLeg", -0.2, 0.05, 0.24, 0.7, 0.96, 0.56, "shorts")
-- Calves: a diamond
limb("Calves", "LowerLeg", 0.2, 0.14, 0.24, 0.66, 0.72, 0.56)
limb("Calves", "LowerLeg", -0.2, 0.14, 0.24, 0.66, 0.72, 0.56)

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
	refName: string,
	blob: Part,
	weld: Weld,
	pos: Vector3,
	size: Vector3,
	cover: string,
	tone: number,
	hidden: boolean,
}

local Controller: any = {}
Controller.__index = Controller

local function sideName(part: string, side: string): string
	return side .. part
end

local function makeBlob(model: Model, folder: Folder, partName: string, spec: any, name: string, mirrorX: number, castShadow: boolean, static: boolean): Entry?
	local part = model:FindFirstChild(partName)
	if not part or not part:IsA("BasePart") then return nil end
	local blob = Instance.new("Part")
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
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = blob
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1 = part, blob
	weld.Parent = blob
	blob.Parent = folder
	return {
		muscle = spec.muscle,
		partName = partName,
		refName = spec.part,
		blob = blob,
		weld = weld,
		-- torso blobs sit a little deeper and bigger so neighbours merge into one smooth mass
		pos = Vector3.new(spec.pos.X * mirrorX, spec.pos.Y, spec.pos.Z * (spec.kind == "mirror" and 0.9 or 1)),
		size = spec.size * (spec.kind == "mirror" and 1.12 or 1),
		cover = spec.cover,
		tone = (spec.pos.X * 7.3 + spec.pos.Y * 3.1 + spec.pos.Z * 5.7 + mirrorX) % 1,
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
	local shadow = options.castShadow == true
	local counter = 0
	for _, spec in ipairs(B) do
		local list: { { part: string, mirror: number } } = {}
		if spec.kind == "mirror" then
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
		local ref = REF[entry.refName] or part.Size
		local sizeVec = part.Size / ref
		local g = self.cur[entry.muscle] or 0
		if g <= 0.001 then
			if not entry.hidden then
				entry.hidden = true
				entry.blob.Transparency = 1
			end
		else
			local f = (SPECK + (1 - SPECK) * g ^ GROWTH_POWER) * (1 + PUMP_STEP * pulseAmount(self, entry.muscle, now)) * pumpedScale
			local size = entry.size * sizeVec * f
			entry.blob.Size = Vector3.new(math.max(size.X, MIN_SIZE), math.max(size.Y, MIN_SIZE), math.max(size.Z, MIN_SIZE))
			if entry.hidden then
				entry.hidden = false
				entry.blob.Transparency = 0
			end
		end
		entry.weld.C0 = CFrame.new(entry.pos * sizeVec)
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
function Controller.Dress(self: any, style: { skin: Color3, top: Color3?, shorts: Color3, topKind: string?, keepParts: boolean? })
	local model: Model = self.model
	local key = tostring(style.skin) .. tostring(style.top) .. tostring(style.shorts) .. tostring(style.topKind) .. tostring(style.keepParts)
	if not style.keepParts then
		for _, name in ipairs({ "UpperTorso", "LowerTorso", "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" }) do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") and part.Color ~= style.skin then part.Color = style.skin end
			if part and part:IsA("BasePart") then
				part.Material = Enum.Material.SmoothPlastic
				part.Reflectance = 0.02
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
		local tone = 1 + ((entry.tone or 0) - 0.5) * 0.05
		color = Color3.new(math.clamp(color.R * tone, 0, 1), math.clamp(color.G * tone, 0, 1), math.clamp(color.B * tone, 0, 1))
		if entry.blob.Color ~= color then entry.blob.Color = color end
		entry.blob.Material = Enum.Material.SmoothPlastic
		entry.blob.Reflectance = 0.02
	end
end

function Controller.Destroy(self: any)
	stop(self)
	if self.folder then self.folder:Destroy() end
end

return MuscleBlobs
