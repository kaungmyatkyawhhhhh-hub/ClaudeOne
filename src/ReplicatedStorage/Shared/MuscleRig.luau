-- MuscleRig: muscle v7 on one character / rig (client side; every client builds the muscles of every character it can see).
--
-- Each muscle's outline stays on the skin and only the bulge rises (EditableMesh, SetPosition: vertex = base + (max - base) * g,
-- g = the muscle's level over its max level). Smooth borders at uneven levels: a border vertex follows its neighbours by
-- the data's blend weights, and the normals come from the data (nbase / nmax), so the body reads as one surface. The mesh data is in part-local studs (origin = the body part's position), so a
-- muscle mesh is welded to its body part at CFrame.new().
--
-- LIMITS the code works around (measured in Studio: a client may hold only 8 EditableMeshes at once, a mesh holds at most 20,000
-- triangles; a game script cannot give a SurfaceAppearance an image):
--   * the muscles of one body part are MERGED into as few meshes as possible (MuscleMeshes.Units), colored with VERTEX colors
--     (skin / gym shorts / top), so there is no skin texture on the muscles;
--   * a global allocator (below) gives the available meshes to the most important rigs and units first (your own character,
--     then the mirror, then the nearest characters; torso, arms, legs, back, forearms, calves) and takes them back when a more
--     important one needs them. If the client allows more meshes, everything is built.
--   * a muscle is only built when it first has some growth (level 0 = the plain Robloxian 2.0 body, no cost);
--   * vertex updates are spread over frames (a budget) so a level-up on a crowded server doesn't hitch.
--   * without a leg unit the gym shorts are drawn as simple thigh bands (garments); with it they come from the shorts meshes.
--
--   local rig = MuscleRig.new(model, { static = false, style = { skin, shorts, top }, marble = false, priority = 100 })
--   rig:SetGrowth({ Biceps = 0.4, ... })   -- tweens ~0.4s
--   rig:Snap(targets)                      -- no tween
--   rig:Pulse({ "Biceps" })                -- the small pump on every 10th level
--   rig:SetPumped(true)                    -- PUMPED: a little bigger
--   rig:SetStyle(style)
--   MuscleRig.SetHighlight(model, { Biceps = true })        -- the red hover tint (only on muscles facing the camera)
--   MuscleRig.Flash(model, { MidChest = 1, Triceps = 0.5 }, big) -- the warm rep flash + a tiny pump
--   rig:Destroy()
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MuscleMeshes = require(script.Parent.MuscleMeshes)
local LimbStages = require(script.Parent.LimbStages)
local Muscles = require(script.Parent.Config.Muscles)
local Body = require(script.Parent.Config.Body)

local MuscleRig = {}
MuscleRig.__index = MuscleRig

local VERTEX_BUDGET = 6000 -- vertex updates per frame, for all rigs together
local BUILD_MS = 0.004     -- seconds of mesh building per frame per build (time, not a call count: fast PCs build quicker)
local MAX_BUILDS = 3       -- units built at once (CreateMeshPartAsync waits 0.3-1s on the engine; side by side the waits overlap)
local BUILD_CHECK = 250    -- API calls between clock checks
local MIN_SHOW = 0.02      -- a unit is only built once one of its muscles has at least this much growth
local VEIN_PUMPED = 0.4    -- veins (muscle_v8 vein offsets) while PUMPED at max
local TWEEN = 0.4          -- seconds a growth change takes
local PUMPED = 1.04
local PUMP_STEP = 0.03     -- the small pulse
local PULSE_TIME = 0.55
local MIN_CHANGE = 0.0015
local MARBLE = Color3.fromHex("#C9C6BF")
-- Tints on the muscles: the stats hover highlight (red) and the rep flash (warm). Only muscles facing the camera show them
-- (each muscle's average outward normal vs the direction to the camera: full above Facing.Full, gone below Facing.None).
-- A tint is a vertex color on the normal lit material: no Neon, no glow light.
-- A tint, not paint: the skin color is blended part of the way toward the tint color, on the normal lit material, so the
-- muscle's shading, creases and shadows stay visible through it.
local TINT = {
	Highlight = Color3.fromRGB(225, 45, 45), -- red
	Hover = 0.40,                            -- the stats hover: a steady blend toward the red (no pulse: it read as flicker)
	HighlightIn = 0.15, HighlightOut = 0.2,  -- seconds to fade in / out
	Flash = Color3.fromRGB(255, 196, 140),   -- warm white-orange
	FlashIn = 0.08, FlashOut = 0.35,
	FlashStrength = 0.35,                    -- main muscle at the peak (secondaries get their weight of it)
	BigStrength = 0.45, BigOut = 0.55,       -- BIG REP / PUMPED: a little stronger and longer
	ClothScale = 0.375,                      -- over a Shirt / Pants image the tint is this much of it (0.4 -> 0.15)
	FacingFull = 0.1, FacingNone = -0.1,
	Pump = 0.02, PumpTime = 0.2,             -- the tiny pump with each flash (g * 1.02 for 0.2s)
}
-- Below EMERGE growth a muscle shell sinks up to SINK studs under the skin (gone at level 0, rising into place as it grows).
local EMERGE, SINK = 0.12, 0.12
local REALLOCATE_EVERY = 0.4

-- The snatched-waist torso: the upper half rides in the torso-front mesh (MuscleMeshes: one mesh for the front muscles and
-- the torso), the LowerTorso is a unit of its own. Units are built in this order of importance: for your own character the
-- torso first, then the muscles; for everyone else the torso-front unit first (so a crowd shows something).
local SNATCHED_UNIT = { id = "Snatched", cost = 1, muscles = {}, groups = { { part = "LowerTorso" } } }
local OWN_ORDER = { TorsoFront = 1, Snatched = 2, UpperArms = 3, UpperLegs = 4, TorsoBack = 5, Forearms = 6, Calves = 7 }
local OTHER_ORDER = { TorsoFront = 1, Snatched = 2, UpperArms = 3, UpperLegs = 4, TorsoBack = 5, Forearms = 6, Calves = 7 }

-- Layered (3D) clothing can't be painted onto muscles: the muscles of the body parts it covers are hidden under it.
local LAYERED_COVERS = {
	[Enum.AccessoryType.TShirt] = { UpperTorso = true, RightUpperArm = true, LeftUpperArm = true },
	[Enum.AccessoryType.Shirt] = { UpperTorso = true, RightUpperArm = true, LeftUpperArm = true, RightLowerArm = true, LeftLowerArm = true },
	[Enum.AccessoryType.Sweater] = { UpperTorso = true, RightUpperArm = true, LeftUpperArm = true, RightLowerArm = true, LeftLowerArm = true },
	[Enum.AccessoryType.Jacket] = { UpperTorso = true, RightUpperArm = true, LeftUpperArm = true, RightLowerArm = true, LeftLowerArm = true },
	[Enum.AccessoryType.Shorts] = { RightUpperLeg = true, LeftUpperLeg = true },
	[Enum.AccessoryType.DressSkirt] = { RightUpperLeg = true, LeftUpperLeg = true },
	[Enum.AccessoryType.Pants] = { RightUpperLeg = true, LeftUpperLeg = true, RightLowerLeg = true, LeftLowerLeg = true },
}

local active: { [any]: boolean } = {}
local meshOf = setmetatable({}, { __mode = "k" }) -- [muscle MeshPart] = its EditableMesh (so a mirror can show the same live mesh)

-- Allocator state: how many EditableMeshes are alive, and the most this client allows (learned when a create fails).
local alive = 0
local limit = math.huge
local limitResetAt = 0
local building = 0 -- units being built right now
local lastAllocate = 0

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

------------------------------------------------------------------------
-- Rig
------------------------------------------------------------------------
function MuscleRig.new(model: Model, opts: any?)
	opts = opts or {}
	local self = setmetatable({
		model = model,
		static = opts.static == true,
		marble = opts.marble == true,
		keepBody = opts.keepBody == true,
		noSnatch = opts.noSnatch == true,
		priority = opts.priority or 0,
		style = opts.style or {},
		target = {},   -- [muscleId] = g the muscle is heading to
		from = {},     -- [muscleId] = g the tween started from
		t0 = {},       -- [muscleId] = tween start time
		current = {},  -- [muscleId] = g now (after the tween)
		pumped = false,
		pulses = {},
		pulseAmounts = {},
		pulseTimes = {},        -- [muscleId] = pulse duration (default PULSE_TIME)
		highlightSet = nil,     -- { [muscleId] = true } being highlighted
		highlightAmount = {},   -- [muscleId] = 0..1 (eased in / out)
		flashes = {},           -- [muscleId] = { start, strength, inTime, outTime }
		flashAmount = {},       -- [muscleId] = 0..1 this frame
		tintWasLive = false,
		destroyed = false,
		units = {},
		garments = {},
	}, MuscleRig)
	for _, muscle in ipairs(Muscles.List) do
		self.target[muscle.id], self.from[muscle.id], self.t0[muscle.id], self.current[muscle.id] = 0, 0, 0, 0
	end
	local folder = Instance.new("Folder")
	folder.Name = "MuscleMeshes"
	folder.Parent = model
	self.folder = folder
	for _, unit in ipairs(MuscleMeshes.Units) do
		local state = { unit = unit, groups = {}, wanted = false, built = false, building = false }
		for _, group in ipairs(unit.groups) do
			table.insert(state.groups, { def = group, applied = {}, mesh = nil, part = nil })
		end
		table.insert(self.units, state)
	end
	-- the snatched-waist torso (muscle v8): its own unit, wanted always (also at level 0)
	if not opts.noSnatch then
		local state = { unit = SNATCHED_UNIT, groups = {}, wanted = true, built = false, building = false, snatched = true }
		for _, group in ipairs(SNATCHED_UNIT.groups) do
			table.insert(state.groups, { def = group, applied = {}, snatched = true })
		end
		table.insert(self.units, state)
	end
	-- forearms and calves as static stage meshes (when their templates are in the place)
	self.limbs = LimbStages.new(model, folder, self.static)
	active[self] = true
	self:DressBody()
	return self
end

------------------------------------------------------------------------
-- Colors and the body
------------------------------------------------------------------------
local function plain(part: BasePart, color: Color3, material: Enum.Material)
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if sa then sa:Destroy() end
	part.Color = color
	part.Material = material
end

local BODY_PARTS = { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" }

local function colorsOf(self)
	local style = self.style
	if self.marble then return Color3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.new(1, 1, 1) end
	local skin = style.skin or Color3.fromHex("#E0A878")
	return skin, style.shorts or Color3.fromHex("#1E1E22"), style.top or skin
end

-- Muscle meshes use SmoothPlastic where the body is Plastic: Plastic's grain texture follows the mesh UVs, and the muscles'
-- UVs are clothing-template coordinates, so on them the grain shows as a coarse speckle.
local function smoothMaterial(material: Enum.Material): Enum.Material
	return if material == Enum.Material.Plastic then Enum.Material.SmoothPlastic else material
end

-- The body itself in plain skin color (the muscle meshes use the same color, so they blend in), gym shorts on the hips.
function MuscleRig.DressBody(self)
	if self.keepBody or not self.style.skin then return end
	local model = self.model
	local skin, shorts, top = colorsOf(self)
	local material = self.marble and Enum.Material.Marble or Enum.Material.Plastic
	local function paint(name: string, color: Color3, mat: Enum.Material?)
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then plain(part, self.marble and MARBLE or color, mat or material) end
	end
	for _, name in ipairs(BODY_PARTS) do paint(name, skin) end
	paint("UpperTorso", top)
	paint("LowerTorso", shorts, self.marble and Enum.Material.Marble or Enum.Material.Fabric)
end

-- Simple shorts on the thighs for when the shorts meshes (the UpperLegs unit) are not there.
local function ensureGarments(self)
	if self.keepBody or self.marble then return end
	for _, side in ipairs({ "Right", "Left" }) do
		local leg = self.model:FindFirstChild(side .. "UpperLeg")
		if leg and leg:IsA("BasePart") and not self.garments[side] then
			local g = Instance.new("Part")
			g.Name = "ThighShorts"
			g.Shape = Enum.PartType.Cylinder
			g.Massless, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
			g.Material = Enum.Material.Fabric
			g.Anchored = self.static
			local weld = Instance.new("Weld")
			weld.Part0, weld.Part1 = leg, g
			weld.C0 = CFrame.new(0, leg.Size.Y * 0.16, 0) * CFrame.Angles(0, 0, math.pi / 2)
			if not self.static then weld.Parent = g end
			g.Parent = self.folder
			self.garments[side] = { part = g, weld = weld, leg = leg }
		end
	end
end

local function updateGarments(self, visible: boolean)
	-- an outfit or body swap replaces the legs: drop shorts that belong to a leg that is gone (ensureGarments makes new ones)
	for side, garment in pairs(self.garments) do
		if garment.leg.Parent ~= self.model then
			garment.part:Destroy()
			self.garments[side] = nil
		end
	end
	ensureGarments(self)
	local _, shorts = colorsOf(self)
	for _, garment in pairs(self.garments) do
		local g, leg = garment.part, garment.leg
		g.Color = shorts
		g.Transparency = visible and 0 or 1
		local size = leg.Size
		-- the gym shorts cover the top of the thigh down to the shorts line (UpperLeg local Y = +0.088 of 1.3175 tall)
		local length = size.Y * 0.435
		local diameter = math.max(size.X, size.Z) * 1.1 -- a true circle a little wider than the thigh, so the rim is clean
		g.Size = Vector3.new(length, diameter, diameter)
		garment.weld.C0 = CFrame.new(0, size.Y * 0.29, 0) * CFrame.Angles(0, 0, math.pi / 2)
		if self.static then g.CFrame = leg.CFrame * garment.weld.C0 end
	end
end

-- The character's own classic clothing image for a muscle ("Shirt" = torso and arms, "Pants" = legs), or nil.
local function templateFor(self, kind: string?): string?
	if self.marble then return nil end
	local template = if kind == "Pants" then self.style.pants else self.style.shirt
	return if type(template) == "string" and template ~= "" then template else nil
end

-- Muscles (and the snatched torso) WEAR THE CHARACTER'S OWN CLOTHING. Each mesh is shown by two MeshParts made from the same
-- EditableMesh (so no extra mesh budget):
--   * the inner part: the bare body (the body part's own color: skin, or the game's top / gym-shorts color), a hair smaller;
--   * the outer part ("Cloth"): the character's Shirt / Pants image as TextureID, a tiny bit transparent. That makes the
--     image's see-through areas really see-through, so the inner part shows there, exactly like skin shows through clothing
--     on the real body part.
-- (Measured in Studio: a game script can't set a SurfaceAppearance image, an opaque textured EditableMesh part draws the
-- image's see-through areas black, and other people's clothing images can't be loaded into an EditableImage.)
-- Without Shirt / Pants (or under layered clothing) there is no outer part and the vertex colors give skin / shorts / top.
-- the body part's scale against the reference body the mesh data was made for
local function groupScale(group): Vector3
	-- the snatched torso replaces the body part itself: it takes the body part's own scale (Size over its mesh size)
	if group.snatched then return group.body.Size / group.body.MeshSize end
	local ref = group.refSize
	local size = group.body.Size
	return Vector3.new(size.X / ref.X, size.Y / ref.Y, size.Z / ref.Z)
end

local INNER_SCALE = 0.985
local CLOTH_TRANSPARENCY = 0.02

local function sizeParts(group)
	local part, cloth = group.part, group.cloth
	if not part then return end
	local full = part.MeshSize * groupScale(group)
	part.Size = if cloth then full * INNER_SCALE else full
	if cloth then cloth.Size = full end
end

local function attach(self, part: MeshPart, body: BasePart, name: string)
	part.Name = name
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.Massless = true
	part.Anchored = self.static
	part.CFrame = body.CFrame
	if not self.static then
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = body, part
		weld.C0 = CFrame.new()
		weld.Parent = part
	end
	part.Parent = self.folder
end

local function setCloth(self, group, template: string?)
	local mesh, body = group.mesh, group.body
	if template == group.template and (template == nil or group.cloth) then return end
	group.template = template
	if group.cloth then
		meshOf[group.cloth] = nil
		group.cloth:Destroy()
		group.cloth = nil
	end
	if template and mesh and body then
		local ok, cloth = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh)) end)
		if ok and cloth and group.mesh == mesh and group.template == template and not group.cloth then
			cloth.TextureID = template
			cloth.Transparency = CLOTH_TRANSPARENCY
			cloth.Color = Color3.new(1, 1, 1)
			attach(self, cloth, body, group.def.part .. "Cloth")
			meshOf[cloth] = mesh
			group.cloth = cloth
		elseif ok and cloth then
			cloth:Destroy()
		end
	end
	sizeParts(group)
end

local function recolor(self, group)
	local mesh, part, body = group.mesh, group.part, group.body
	if not mesh or not part or not body then return end
	local kind = if group.snatched then (if group.def.part == "LowerTorso" then "Pants" else "Shirt") else (group.data and group.data.clothing)
	local template = templateFor(self, kind)
	if self.covered and self.covered[body.Name] then template = nil end
	if group.rangeColors then
		local skin, shorts, top = colorsOf(self)
		local white = Color3.new(1, 1, 1)
		-- under clothing the vertex colors stay white (they would tint the clothing image); the inner part's Color is the skin
		group.kindBase = { if template then white else skin, if template then white else shorts, if template then white else top }
		group.shownColors = {}
		pcall(function()
			for _, range in ipairs(group.data.ranges) do
				local kind = group.rangeKinds[range]
				local color = group.kindBase[kind]
				for _, id in pairs(group.rangeColors[range]) do mesh:SetColor(id, color) end
				group.shownColors[range] = color
			end
			for _, ids in pairs(group.extraColors or {}) do
				for _, id in pairs(ids) do mesh:SetColor(id, group.kindBase[3]) end
			end
			if group.extraShown then table.clear(group.extraShown) end
		end)
	end
	if self.marble then
		part.Color, part.Material = MARBLE, Enum.Material.Marble
		template = nil
	elseif group.snatched or template then
		part.Color, part.Material = body.Color, smoothMaterial(body.Material)
	else
		part.Color, part.Material = Color3.new(1, 1, 1), Enum.Material.SmoothPlastic
	end
	task.spawn(setCloth, self, group, template)
end

function MuscleRig.SetStyle(self, style)
	self.style = style or {}
	self:DressBody()
	for _, state in ipairs(self.units) do
		for _, group in ipairs(state.groups) do recolor(self, group) end
	end
end

------------------------------------------------------------------------
-- Growth numbers
------------------------------------------------------------------------
function MuscleRig.SetGrowth(self, targets: { [string]: number })
	local now = os.clock()
	for _, muscle in ipairs(Muscles.List) do
		local id = muscle.id
		local g = math.clamp(targets[id] or 0, 0, Muscles.MaxLookG)
		if math.abs(g - self.target[id]) > 0.0005 then
			self.from[id] = self.current[id]
			self.target[id] = g
			self.t0[id] = now
		end
	end
end

function MuscleRig.Snap(self, targets: { [string]: number })
	self:SetGrowth(targets)
	for id, g in pairs(self.target) do
		self.from[id], self.current[id], self.t0[id] = g, g, 0
	end
end

-- amount = how much bigger the muscle gets at the peak of the pulse (default 3%; the pose hit uses 4%); duration in seconds
-- (default PULSE_TIME)
function MuscleRig.Pulse(self, ids: { string }, amount: number?, duration: number?)
	local now = os.clock()
	for _, id in ipairs(ids) do
		self.pulses[id] = now
		self.pulseAmounts[id] = amount
		self.pulseTimes[id] = duration
	end
end

function MuscleRig.SetPumped(self, pumped: boolean)
	self.pumped = pumped
end

------------------------------------------------------------------------
-- Building one group's mesh (an EditableMesh with the merged muscles of one body part)
------------------------------------------------------------------------
local function currentShown(self, id: string): number
	local g = self.current[id] or 0
	local pulseStart = self.pulses[id]
	local pulse = 1
	if pulseStart then
		local t = (os.clock() - pulseStart) / (self.pulseTimes[id] or PULSE_TIME)
		if t < 1 then pulse = 1 + (self.pulseAmounts[id] or PUMP_STEP) * math.sin(t * math.pi) end
	end
	return math.min(g * (self.pumped and PUMPED or 1) * pulse, Muscles.MaxLookG * 1.06)
end

-- How far a muscle is into its mass monster stage (0 at the full aesthetic size, 1 at its monster size).
local function monsterT(id: string, g: number): number
	return math.clamp((g - 1) / math.max(Muscles.MonsterG(id) - 1, 0.01), 0, 1)
end
local MONSTER_EXTRA = Body.Widths.MassMonster.muscle_extra -- the monster's extra thickness on top of its size

-- The growth one MESH is drawn at: its muscle's g up to the full aesthetic size; past it the mesh grows toward its own monster
-- size (manifest mass_monster.g by mesh: the round shoulder caps and the upper traps have their own) and gets the monster's
-- extra thickness.
local function meshShown(self, key: string, id: string): number
	local g = currentShown(self, id)
	if g <= 1 then return g end
	local t = math.clamp((g - 1) / math.max(Muscles.MonsterG(id) - 1, 0.01), 0, 1.1)
	return (1 + t * (MuscleMeshes.MonsterG(key) - 1)) * (1 + MONSTER_EXTRA * math.min(t, 1))
end

-- the vein amount for a muscle: they come in with the mass monster stage (g past 1 toward the muscle's monster size), and
-- briefly while PUMPED at the full aesthetic size
local function veinFor(self, id: string): number
	local g = self.current[id] or 0
	local monster = monsterT(id, g)
	local pumped = if self.pumped and g >= 1 then VEIN_PUMPED else 0
	return math.max(monster, pumped)
end

-- Smooth borders at uneven levels (muscle_v8 blend): a border vertex follows its neighbouring meshes by the data's
-- weights: g_v = (1 - sum of weights) * g_own + sum(weight * g_other); position = base + (max - base) * g_v + vein * v,
-- normal = unit(nbase + (nmax - nbase) * g_v). A muscle at 0 lies flat on the skin, so a 0 next to a max is a smooth slope.
-- The torso width (character attributes set by BodyService): the server widens the UpperTorso part to FrameWidth (the
-- genetics frame times the Growth Spurt shoulder width) and the LowerTorso to WaistWidth (the hips), so every mesh on the
-- UpperTorso is drawn FrameWidth wider; each vertex's X is scaled from the shoulders (full width) down to the waist
-- (WaistWidth, meeting the LowerTorso), so a V-Taper is a V.
local FRAME_TAPER = { From = -0.3, To = 0.3 } -- share of the torso height (centre = 0): the waist .. the shoulders
local function frameTaper(self, group, positions: { Vector3 }): { number }?
	local top, waist = self.taperTop or 1, self.taperWaist or 1
	if math.abs(top - waist) < 1e-3 or group.def.part ~= "UpperTorso" then return nil end
	local height = MuscleMeshes.Parts.UpperTorso.size.Y
	local taper = table.create(#positions)
	for i, position in ipairs(positions) do
		local t = math.clamp((position.Y / height - FRAME_TAPER.From) / (FRAME_TAPER.To - FRAME_TAPER.From), 0, 1)
		t = t * t * (3 - 2 * t)
		taper[i] = (waist + (top - waist) * t) / top
	end
	return taper
end

-- The waist that tightens (muscle_v8 waist morph): 0 = the wide straight waist of a beginner, 1 = the snatched V; the
-- average growth of all muscles (up to the full aesthetic size), eased.
local function waistProgress(self): number
	local total = 0
	for _, muscle in ipairs(Muscles.List) do total += math.min(self.current[muscle.id] or 0, 1) end
	return smooth(total / #Muscles.List)
end

-- How far the barely-grown muscles have risen (changes only below EMERGE): the torso is re-applied when it changes.
local function emergeKey(self): number
	local sum = 0
	for _, muscle in ipairs(Muscles.List) do sum += math.min(self.current[muscle.id] or 0, EMERGE) end
	return sum
end

local function applyRange(self, group, range)
	local data, mesh, ids, normalIds = group.data, group.mesh, group.vertexIds, group.normalIds
	if range.snatched then
		-- the snatched torso in the torso-front mesh: the waist morph (start -> snatched) and the taper, no growth; scaled from
		-- the muscle data's reference to the body's own mesh size (it replaces the body part)
		local w = waistProgress(self)
		local taper, start, scale = group.taper, data.morphStart, group.snatchScale or Vector3.one
		local front, back = data.pushFront, if self.backBuilt then data.pushBack else nil
		local owners = data.owners or {}
		local emerged = {}
		for i = range.first, range.first + range.count - 1 do
			local push = front and front[i] or Vector3.zero
			if back and back[i].Magnitude > push.Magnitude then push = back[i] end
			-- the push grows with the muscle over it, like the shell rises (at level 0 neither: just the smooth torso)
			local owner = owners[i]
			if owner and push.Magnitude > 0 then
				local id = owner[1]
				local e = emerged[id]
				if not e then
					e = math.clamp(currentShown(self, id) / EMERGE, 0, 1)
					e = e * e * (3 - 2 * e)
					emerged[id] = e
				end
				push *= e
			end
			local position = (start[i] + (data.base[i] - start[i]) * w + push) * scale
			if taper then position = Vector3.new(position.X * taper[i], position.Y, position.Z) end
			mesh:SetPosition(ids[i], position)
		end
		group.applied[range] = w
		group.appliedBack = self.backBuilt
		group.appliedEmerge = emergeKey(self)
		return
	end
	local base, delta, blends, nbase, ndelta, vein = data.base, data.delta, data.blends, data.nbase, data.ndelta, data.vein
	local taper = group.taper
	local g = meshShown(self, range.key, range.id)
	local others = {}
	for _, key in ipairs(range.blendKeys) do others[key] = meshShown(self, key, MuscleMeshes.MuscleId(key)) end
	local v = if vein then veinFor(self, range.id) else 0
	local morph = data.morph
	local snapK, skinPos, skinNormal = data.snapK or {}, data.skinPos or {}, data.skinNormal or {}
	local w = waistProgress(self)
	local waistOff = 1 - w
	for i = range.first, range.first + range.count - 1 do
		local gv = g
		local list = blends[i]
		if list then
			local weights, sum = 0, 0
			for _, pair in ipairs(list) do
				weights += pair[2]
				sum += pair[2] * (others[pair[1]] or g)
			end
			gv = (1 - weights) * g + sum
		end
		local position = base[i] + delta[i] * gv
		-- the skin edge blends into the torso surface under it (position and, below, normal)
		local snap = snapK[i]
		if snap then position = position:Lerp(skinPos[i], snap) end
		if morph and morph[i] then position += morph[i] * waistOff end -- (rides the torso's waist morph)
		-- a muscle that has barely grown stays just under the torso (its outline and lighting would show as a line on the flat
		-- body) and rises into place as it grows
		if gv < EMERGE and nbase then
			local e = gv / EMERGE
			position -= nbase[i].Unit * (SINK * (1 - e * e * (3 - 2 * e)))
		end
		if v > 0 then position += vein[i] * v end
		if taper then position = Vector3.new(position.X * taper[i], position.Y, position.Z) end
		mesh:SetPosition(ids[i], position)
		if normalIds then
			local normal = nbase[i] + ndelta[i] * gv
			if normal.Magnitude > 1e-6 then
				normal = normal.Unit
				if snap then normal = normal:Lerp(skinNormal[i], snap) end
				mesh:SetNormal(normalIds[i], normal.Unit)
			end
		end
	end
	group.applied[range] = g
	group.appliedOthers[range] = others
	group.appliedVein[range] = v
	group.appliedW = group.appliedW or {}
	group.appliedW[range] = w
end

-- true when the mesh, a mesh it blends with, or its vein amount changed since it was last applied
local function rangeChanged(self, group, range): boolean
	local last = group.applied[range]
	if range.snatched then
		return last == nil or math.abs(waistProgress(self) - last) > 0.004 or group.appliedBack ~= self.backBuilt
			or math.abs(emergeKey(self) - (group.appliedEmerge or -1)) > 0.01
	end
	if last == nil or math.abs(meshShown(self, range.key, range.id) - last) > MIN_CHANGE then return true end
	if group.data.morph and math.abs(waistProgress(self) - ((group.appliedW and group.appliedW[range]) or -1)) > 0.004 then return true end
	local others = group.appliedOthers[range]
	for _, key in ipairs(range.blendKeys) do
		if not others or math.abs(meshShown(self, key, MuscleMeshes.MuscleId(key)) - (others[key] or 0)) > MIN_CHANGE then return true end
	end
	return group.data.vein ~= nil and veinFor(self, range.id) ~= group.appliedVein[range]
end

local function newMesh(): any
	if alive >= limit then return nil end
	local okCreate, mesh = pcall(function() return AssetService:CreateEditableMesh() end)
	if not okCreate or not mesh then
		-- the client's budget is used up: remember how many fit and let the allocator rearrange
		limit = alive
		-- (a failure with nothing built is probably temporary: look again in a while instead of giving up for the whole session)
		if alive == 0 then limitResetAt = os.clock() + 15 end
		return nil
	end
	alive += 1
	return mesh
end

local function dropMesh(mesh)
	alive = math.max(alive - 1, 0)
	pcall(function() mesh:Destroy() end)
end

-- Returns true when the group was built.
local function buildGroup(self, state, group): boolean
	local body = self.model:FindFirstChild(group.def.part)
	if not body or not body:IsA("BasePart") then return false end
	local data = MuscleMeshes.LoadGroup(group.def, not self.noSnatch)
	local mesh = newMesh()
	if not mesh then return false end
	local calls = 0
	local sliceStart = os.clock()
	local function tick()
		calls += 1
		if calls % BUILD_CHECK == 0 and os.clock() - sliceStart > BUILD_MS then
			task.wait()
			sliceStart = os.clock()
		end
	end
	local ok, err = pcall(function()
		-- a few vertex colors per muscle, one per tint band (MuscleMeshes.TintBands: band 0 = never tinted, the top band = the
		-- full tint), so the highlight / flash fades from the bulge to nothing at the muscle's flat edges with a handful of
		-- SetColor calls; its kind picks the base color: 1 skin, 2 gym shorts, 3 top (the UpperTorso muscles)
		local white = Color3.new(1, 1, 1)
		group.rangeColors, group.rangeKinds = {}, {}
		local rangeOf = table.create(data.verts)
		for _, range in ipairs(data.ranges) do
			local ids = {}
			for band = 0, MuscleMeshes.TintBands do ids[band] = mesh:AddColor(white, 1) end
			group.rangeColors[range] = ids
			group.rangeKinds[range] = if range.shorts then 2 elseif group.def.part == "UpperTorso" then 3 else 1
			for i = range.first, range.first + range.count - 1 do rangeOf[i] = ids end
		end
		local bands = data.bands
		-- the torso (in the torso-front mesh): each vertex takes the tint set of the muscle it lies under, at that muscle's band;
		-- muscles from another mesh (the back) get sets of their own here (group.extraColors)
		if data.owners then
			local setOf = {}
			for _, range in ipairs(data.ranges) do
				if not range.snatched then setOf[range.id] = group.rangeColors[range] end
			end
			group.extraColors, group.extraShown = {}, {}
			bands = table.clone(bands)
			for i, owner in pairs(data.owners) do
				local id = owner[1]
				local ids = setOf[id]
				if not ids then
					ids = {}
					for band = 0, MuscleMeshes.TintBands do ids[band] = mesh:AddColor(white, 1) end
					setOf[id] = ids
					group.extraColors[id] = ids
				end
				rangeOf[i] = ids
				bands[i] = owner[2]
			end
		end
		group.faceIds = table.create(data.triCount)
		local vertexIds = table.create(data.verts)
		local uvIds = table.create(data.verts)
		-- the package's own normals (set, never auto-computed: auto normals make every muscle look like a separate piece)
		local normalIds = if data.nbase then table.create(data.verts) else nil
		group.taper = frameTaper(self, group, data.base)
		local taper = group.taper
		local buildG = table.create(data.verts)
		for _, range in ipairs(data.ranges) do
			local monster = MuscleMeshes.MonsterG(range.key) * (1 + MONSTER_EXTRA)
			for i = range.first, range.first + range.count - 1 do buildG[i] = monster end
		end
		for i = 1, data.verts do
			-- built in the biggest shape (the mass monster size, so its bounds hold every growth); the real growth is applied below
			local built = data.base[i] + data.delta[i] * buildG[i]
			if taper then built = Vector3.new(built.X * taper[i], built.Y, built.Z) end
			vertexIds[i] = mesh:AddVertex(built)
			uvIds[i] = mesh:AddUV(data.uv[i]) -- the clothing template coordinates (Shirt / Pants)
			if normalIds then normalIds[i] = mesh:AddNormal((data.nbase[i] + data.ndelta[i]).Unit) end
			tick()
		end
		group.normalIds = normalIds
		local tris = data.tris
		for f = 1, data.triCount do
			local a, b, c = tris[f * 3 - 2] + 1, tris[f * 3 - 1] + 1, tris[f * 3] + 1
			local face = mesh:AddTriangle(vertexIds[a], vertexIds[b], vertexIds[c])
			group.faceIds[f] = face
			mesh:SetFaceUVs(face, { uvIds[a], uvIds[b], uvIds[c] })
			if normalIds then mesh:SetFaceNormals(face, { normalIds[a], normalIds[b], normalIds[c] }) end
			-- (each corner takes its own vertex's band: the colors blend across the face, a soft edge)
			mesh:SetFaceColors(face, { rangeOf[a][bands[a] or 0], rangeOf[b][bands[b] or 0], rangeOf[c][bands[c] or 0] })
			tick()
		end
		group.vertexIds = vertexIds
	end)
	if not ok then
		warn("[MuscleRig] couldn't build " .. group.def.part .. ": " .. tostring(err))
		dropMesh(mesh)
		return false
	end
	local okPart, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh)) end)
	if not okPart or not part or self.destroyed or not body.Parent or state.cancelled then
		dropMesh(mesh)
		if okPart and part then part:Destroy() end
		return false
	end
	group.mesh, group.data, group.body, group.part = mesh, data, body, part
	group.refSize = MuscleMeshes.Parts[group.def.part].size
	group.bodySize = body.Size
	-- the snatched torso rides in this mesh: it is shown instead of the real body part
	if data.morphStart then
		group.snatchScale = if body:IsA("MeshPart") and body.MeshSize.Magnitude > 0 then body.MeshSize / group.refSize else Vector3.one
		group.hiddenBody = body
		body.Transparency = 1
	end
	-- the muscle ids this merged mesh holds (the stats highlight lights them up)
	local ids = {}
	for _, range in ipairs(data.ranges) do
		if not range.snatched then table.insert(ids, range.id) end
	end
	part:SetAttribute("MuscleName", table.concat(ids, ","))
	attach(self, part, body, group.def.part .. "Muscles")
	meshOf[part] = mesh
	sizeParts(group)
	recolor(self, group)
	-- start every muscle at its current growth
	group.appliedOthers, group.appliedVein = {}, {}
	for _, range in ipairs(data.ranges) do applyRange(self, group, range) end
	return true
end

-- The snatched-waist torso (muscle v8 body/): shown INSTEAD of the real UpperTorso / LowerTorso (they are hidden on this
-- client only), dressed like the muscles in the character's own Shirt / Pants. Its waist morphs from the wide start to
-- the snatched V as the body grows (applySnatched). (MeshPart:ApplyMesh onto the real part was tried: the part then loses
-- its clothing.)
local function snatchedPosition(data, i: number, w: number): Vector3
	local max = data.verts[i]
	return if data.start then data.start[i] + (max - data.start[i]) * w else max
end
local function applySnatched(self, group)
	local data, mesh, ids = group.snatchedData, group.mesh, group.vertexIds
	if not (data and mesh and ids) then return end
	local w = waistProgress(self)
	local taper = group.taper
	for i = 1, #data.verts do
		local position = snatchedPosition(data, i, w)
		if taper then position = Vector3.new(position.X * taper[i], position.Y, position.Z) end
		mesh:SetPosition(ids[i], position)
	end
	group.morphW = w
end
local function buildSnatched(self, state, group): boolean
	local body = self.model:FindFirstChild(group.def.part)
	if not body or not body:IsA("BasePart") then return false end
	local data = MuscleMeshes.LoadSnatched(group.def.part)
	if not data then return false end
	local mesh = newMesh()
	if not mesh then return false end
	local ok, err = pcall(function()
		local ids, uvs, normals = {}, {}, {}
		local taper = frameTaper(self, group, data.verts)
		group.taper = taper
		local w = waistProgress(self)
		for i = 1, #data.verts do
			local position = snatchedPosition(data, i, w)
			if taper then position = Vector3.new(position.X * taper[i], position.Y, position.Z) end
			ids[i] = mesh:AddVertex(position)
			uvs[i] = mesh:AddUV(data.uv[i])
			-- the OBJ's own normals (auto normals on this low-poly torso shade differently from the muscle edges on it)
			if data.normals then normals[i] = mesh:AddNormal(data.normals[i]) end
		end
		local tris = data.tris
		for k = 1, #tris, 3 do
			local a, b, c = tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1
			local face = mesh:AddTriangle(ids[a], ids[b], ids[c])
			mesh:SetFaceUVs(face, { uvs[a], uvs[b], uvs[c] })
			if data.normals then mesh:SetFaceNormals(face, { normals[a], normals[b], normals[c] }) end
		end
		group.vertexIds, group.morphW = ids, w
	end)
	local okPart, part = false, nil
	if ok then okPart, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh)) end) end
	if not ok or not okPart or not part or self.destroyed or not body.Parent or state.cancelled then
		if not ok then warn("[MuscleRig] couldn't build the snatched " .. group.def.part .. ": " .. tostring(err)) end
		dropMesh(mesh)
		if okPart and part then part:Destroy() end
		return false
	end
	group.mesh, group.body, group.part = mesh, body, part
	group.snatchedData = data
	group.refSize = MuscleMeshes.Parts[group.def.part].size
	group.bodySize = body.Size
	attach(self, part, body, group.def.part .. "Snatched")
	meshOf[part] = mesh
	sizeParts(group)
	recolor(self, group)
	group.hiddenBody = body
	body.Transparency = 1
	return true
end

local function destroyGroup(group)
	if group.hiddenBody then
		if group.hiddenBody.Parent then group.hiddenBody.Transparency = 0 end
		group.hiddenBody = nil
	end
	if group.mesh then dropMesh(group.mesh) end
	if group.cloth then
		meshOf[group.cloth] = nil
		group.cloth:Destroy()
	end
	if group.part then
		meshOf[group.part] = nil
		group.part:Destroy()
	end
	group.mesh, group.part, group.cloth, group.template, group.data, group.vertexIds, group.body = nil, nil, nil, nil, nil, nil, nil
	group.normalIds = nil
	group.applied, group.appliedOthers, group.appliedVein = {}, {}, {}
	group.rangeColors, group.rangeKinds, group.kindBase, group.shownColors = nil, nil, nil, nil
	group.extraColors, group.extraShown, group.appliedW = nil, nil, nil
end

local function destroyUnit(state)
	state.cancelled = true
	for _, group in ipairs(state.groups) do destroyGroup(group) end
	state.built = false
end

------------------------------------------------------------------------
-- Per-frame update of one rig
------------------------------------------------------------------------
local function wantedUnit(self, state): boolean
	if state.snatched then return true end
	if state.unit.alwaysWanted and not self.noSnatch then return true end -- (the torso-front unit carries the snatched torso)
	for id in pairs(state.unit.muscles) do
		if (self.target[id] or 0) >= MIN_SHOW or (self.current[id] or 0) >= MIN_SHOW then return true end
	end
	return false
end

-- Eases the highlight amounts and runs the flash envelopes; true while any tint shows.
local function updateTintState(self, dt: number): boolean
	local live = false
	local set, amounts = self.highlightSet, self.highlightAmount
	if set then
		for id in pairs(set) do
			if amounts[id] == nil then amounts[id] = 0 end
		end
	end
	for id, amount in pairs(amounts) do
		local want = if set and set[id] then 1 else 0
		-- from where it is toward the target (and nothing once there: at full it must not dip and climb back every frame)
		if want > amount then
			amount = math.min(want, amount + dt / TINT.HighlightIn)
		elseif want < amount then
			amount = math.max(want, amount - dt / TINT.HighlightOut)
		end
		if amount <= 0 and want == 0 then
			amounts[id] = nil
		else
			amounts[id] = amount
			live = true
		end
	end
	local now = os.clock()
	table.clear(self.flashAmount)
	for id, flash in pairs(self.flashes) do
		local t = now - flash.start
		local v = nil
		if t < flash.inTime then
			v = t / flash.inTime
		elseif t < flash.inTime + flash.outTime then
			v = 1 - (t - flash.inTime) / flash.outTime
		end
		if v then
			self.flashAmount[id] = v * flash.strength
			live = true
		else
			self.flashes[id] = nil
		end
	end
	return live
end

-- The fully tinted color of a muscle (its top tint band): base blended toward the hover red (steady) and the flash warm
-- white, scaled by how much it faces the camera, and much lighter over clothing.
local function tinted(self, id: string, base: Color3, facing: number, clothed: boolean): Color3
	local h = self.highlightAmount[id] or 0
	local f = self.flashAmount[id] or 0
	if h <= 0 and f <= 0 then return base end
	local cloth = if clothed then TINT.ClothScale else 1
	local color = base
	if h > 0 then
		color = color:Lerp(TINT.Highlight, h * TINT.Hover * facing * cloth)
	end
	if f > 0 then color = color:Lerp(TINT.Flash, math.min(f, 1) * facing * cloth) end
	return color
end

local function facingOf(cf: CFrame, scale: Vector3, center: Vector3, normal: Vector3, cameraPosition: Vector3): number
	local at = cf:PointToWorldSpace(center * scale)
	local toCamera = cameraPosition - at
	local dot = if toCamera.Magnitude > 1e-4 then cf:VectorToWorldSpace(normal):Dot(toCamera.Unit) else 1
	return math.clamp((dot - TINT.FacingNone) / (TINT.FacingFull - TINT.FacingNone), 0, 1)
end

-- Sets each muscle's color: its base, tinted by the highlight / flash in proportion to how much it faces the camera.
local function tintGroup(self, group, cameraPosition: Vector3)
	local part, mesh = group.part, group.mesh
	if not (group.rangeColors and group.kindBase and part and mesh) then return end
	local cf = part.CFrame
	local meshSize = part.MeshSize
	local scale = if meshSize.Magnitude > 0 then part.Size / meshSize else Vector3.one
	for _, range in ipairs(group.data.ranges) do
		local kind = group.rangeKinds[range]
		local base = group.kindBase[kind]
		local color = base -- the fully tinted color (the top band); lower bands take part of the tint
		if range.normal and ((self.highlightAmount[range.id] or 0) > 0 or (self.flashAmount[range.id] or 0) > 0) then
			color = tinted(self, range.id, base, facingOf(cf, scale, range.center, range.normal, cameraPosition), group.template ~= nil)
		end
		if group.shownColors[range] ~= color then
			group.shownColors[range] = color
			local ids, top = group.rangeColors[range], MuscleMeshes.TintBands
			pcall(function()
				for band = 0, top do mesh:SetColor(ids[band], base:Lerp(color, band / top)) end
			end)
		end
	end
	-- the torso under muscles of other meshes (the back): their tint sets in this mesh
	if group.extraColors then
		local base = group.kindBase[3]
		for id, ids in pairs(group.extraColors) do
			local facing = group.data.ownerFacing and group.data.ownerFacing[id]
			local color = if facing then tinted(self, id, base, facingOf(cf, scale, facing.center, facing.normal, cameraPosition), group.template ~= nil) else base
			if group.extraShown[id] ~= color then
				group.extraShown[id] = color
				local top = MuscleMeshes.TintBands
				pcall(function()
					for band = 0, top do mesh:SetColor(ids[band], base:Lerp(color, band / top)) end
				end)
			end
		end
	end
end

local function step(self, dt: number, budget: number): number
	local now = os.clock()
	local used = 0
	-- tween the numbers
	for id, target in pairs(self.target) do
		local t = (now - self.t0[id]) / TWEEN
		if t < 1 then
			self.current[id] = self.from[id] + (target - self.from[id]) * smooth(t)
		else
			self.current[id] = target
		end
	end
	for id, started in pairs(self.pulses) do
		if now - started > (self.pulseTimes[id] or PULSE_TIME) then self.pulses[id] = nil end
	end
	-- the torso width changed (the frame, a Growth Spurt, the body growing): every UpperTorso mesh gets the new taper, in place
	local top, waist = self.model:GetAttribute("FrameWidth"), self.model:GetAttribute("WaistWidth")
	top = if type(top) == "number" then top else 1
	waist = if type(waist) == "number" then waist else 1
	if top ~= (self.taperTop or 1) or waist ~= (self.taperWaist or 1) then
		self.taperTop, self.taperWaist = top, waist
		for _, state in ipairs(self.units) do
			if not state.built then continue end
			for _, group in ipairs(state.groups) do
				if group.def.part ~= "UpperTorso" or not group.mesh then continue end
				if group.snatched then
					group.taper = frameTaper(self, group, group.snatchedData.verts)
					group.morphW = nil -- (applied below)
				elseif group.data then
					group.taper = frameTaper(self, group, group.data.base)
					table.clear(group.applied) -- (every range is applied again, within the budget)
				end
			end
		end
	end
	-- layered (3D) clothing: hide the muscles under it (checked about once a second)
	if now - (self.coveredAt or 0) > 1 then
		self.coveredAt = now
		local covered = {}
		for _, item in ipairs(self.model:GetChildren()) do
			local handle = item:IsA("Accessory") and item:FindFirstChild("Handle")
			local covers = handle and handle:FindFirstChildOfClass("WrapLayer") and LAYERED_COVERS[item.AccessoryType]
			if covers then for name in pairs(covers) do covered[name] = true end end
		end
		self.covered = covered
	end
	local backBuilt = false
	for _, state in ipairs(self.units) do
		if state.unit.id == "TorsoBack" and state.built then backBuilt = true end
	end
	self.backBuilt = backBuilt
	for _, state in ipairs(self.units) do
		state.wanted = wantedUnit(self, state)
		if state.built then
			-- an outfit change can swap the body parts: build again on the new ones
			local stale = false
			for _, group in ipairs(state.groups) do
				if not group.body or group.body.Parent ~= self.model then stale = true end
			end
			if stale then
				destroyUnit(state)
				continue
			end
			for _, group in ipairs(state.groups) do
				local body = group.body
				if not (group.part and group.part.Parent and body and body.Parent) then continue end
				-- under layered clothing the muscles hide (the snatched torso stays; when it rides in the torso-front mesh, the real
				-- body part shows again instead)
				local hidden = not group.snatched and self.covered and self.covered[body.Name] == true or false
				if group.part.Transparency ~= (hidden and 1 or 0) then
					group.part.Transparency = hidden and 1 or 0
					if group.cloth then group.cloth.Transparency = hidden and 1 or CLOTH_TRANSPARENCY end
					if group.hiddenBody and group.data and group.data.morphStart then body.Transparency = hidden and 0 or 1 end
				end
				-- the waist morph follows the growth
				if group.snatched and group.mesh and (group.morphW == nil or math.abs(waistProgress(self) - group.morphW) > 0.004) then
					applySnatched(self, group)
				end
				-- apply the muscles that changed (within the frame budget)
				for _, range in ipairs(if group.data then group.data.ranges else {}) do
					if (budget - used > 0 or used == 0) and rangeChanged(self, group, range) then
						applyRange(self, group, range)
						used += range.count
					end
				end
				if body.Size ~= group.bodySize then
					group.bodySize = body.Size
					sizeParts(group)
				end
				if self.static then
					group.part.CFrame = body.CFrame
					if group.cloth then group.cloth.CFrame = body.CFrame end
				end
			end
		end
	end
	-- tints (hover highlight, rep flash): while one shows, and once more after the last one to put the colors back
	local tintLive = updateTintState(self, dt)
	-- forearms and calves (static stage meshes): the stage nearest to the shown look, the clothing, the tints
	if self.limbs then
		local highlight, flash = self.highlightAmount, self.flashAmount
		self.limbs:Update(function(id, key) return meshShown(self, key, id) end, {
			skin = (self.style and self.style.skin) or nil, shirt = templateFor(self, "Shirt"), pants = templateFor(self, "Pants"),
		}, function(id, base)
			return tinted(self, id, base, 1, templateFor(self, if id == "Calves" then "Pants" else "Shirt") ~= nil)
		end, self.covered, self.marble)
	end
	if tintLive or self.tintWasLive then
		local camera = workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		for _, state in ipairs(self.units) do
			if state.built then
				for _, group in ipairs(state.groups) do
					if not group.snatched then tintGroup(self, group, cameraPosition) end
				end
			end
		end
	end
	self.tintWasLive = tintLive
	-- the game's gym shorts on the thighs, unless the character wears its own Pants (or layered clothing on the legs)
	if not self.keepBody and not self.marble then
		local legsCovered = self.covered and self.covered.RightUpperLeg
		updateGarments(self, templateFor(self, "Pants") == nil and not legsCovered)
	end
	return used
end

------------------------------------------------------------------------
-- The allocator: which units get a mesh, most important first
------------------------------------------------------------------------
local function allocate()
	if limit == 0 and os.clock() >= limitResetAt then limit = math.huge end
	-- every wanted unit of every rig, most important first
	local jobs = {}
	for rig in pairs(active) do
		if not rig.destroyed and rig.model.Parent then
			for index, state in ipairs(rig.units) do
				if state.wanted or state.built then
					-- my own character gets its waist, torso, arms, legs and back first; then every nearby character's chest/abs
					-- unit (so a crowd shows something instead of one body hogging the budget), then the rest by distance
					local own = rig.priority >= 100
					local rank = (if own then OWN_ORDER else OTHER_ORDER)[state.unit.id] or (10 + index)
					local order
					if rig.priority >= 200 then
						order = 200000 - rank
					elseif own and rank <= 5 then
						order = 100000 - rank
					elseif rank == 1 then
						order = 50000 + rig.priority
					else
						order = rig.priority * 10 - rank * 500
					end
				table.insert(jobs, { rig = rig, state = state, order = order })
				end
			end
		end
	end
	table.sort(jobs, function(a, b) return a.order > b.order end)
	local budget = limit
	for _, job in ipairs(jobs) do
		local state = job.state
		-- a unit that just failed to build waits out its backoff without holding budget the others could use
		local backoff = not state.built and (state.failedAt or 0) > os.clock()
		local want = state.wanted and not backoff and budget >= state.unit.cost
		if want then budget -= state.unit.cost end
		job.keep = want
	end
	-- take meshes back from units that lost them (so the more important ones can be built)
	for _, job in ipairs(jobs) do
		if job.state.built and not job.keep then destroyUnit(job.state) end
	end
	return jobs
end

local function startBuilds(jobs)
	if building >= MAX_BUILDS then return end
	for _, job in ipairs(jobs) do
		local state, rig = job.state, job.rig
		if job.keep and not state.built and not state.building and not rig.destroyed and (state.failedAt or 0) < os.clock() then
			building += 1
			state.building = true
			state.cancelled = false
			task.spawn(function()
				local allBuilt = true
				local ok, err = pcall(function()
					for _, group in ipairs(state.groups) do
						local built = if group.snatched then buildSnatched(rig, state, group) else buildGroup(rig, state, group)
						if not built then
							allBuilt = false
							break
						end
					end
				end)
				if not ok then
					allBuilt = false
					warn("[MuscleRig] build failed: " .. tostring(err))
				end
				if allBuilt and not state.cancelled then
					state.built = true
				else
					for _, group in ipairs(state.groups) do destroyGroup(group) end
					state.built = false
					state.failedAt = os.clock() + 3 -- try again a little later (the budget may have changed)
				end
				state.building = false
				building -= 1
				lastAllocate = 0 -- start the next unit on the next frame (no waiting for the allocator's tick)
			end)
			if building >= MAX_BUILDS then return end
		end
	end
end

function MuscleRig.Destroy(self)
	self.destroyed = true
	active[self] = nil
	for _, state in ipairs(self.units) do destroyUnit(state) end
	if self.limbs then self.limbs:Destroy() end
	if self.folder then self.folder:Destroy() end
end

-- The stats hover highlight: every muscle id in `set` (a table { [id] = true }, or nil to clear) turns red on the
-- character `model` (only on the muscles facing the camera; it fades in / out). Cheap: one color per muscle.
function MuscleRig.SetHighlight(model: Model, set: { [string]: boolean }?)
	for rig in pairs(active) do
		if rig.model == model then rig.highlightSet = set end
	end
end

-- The rep flash: a quick warm glow on the muscles a rep trained (`weights` = { [muscleId] = 0..1 }, the main muscle 1,
-- secondaries less) with a tiny pump; `big` (BIG REP / PUMPED) makes it stronger and a little longer.
function MuscleRig.Flash(model: Model, weights: { [string]: number }, big: boolean?)
	for rig in pairs(active) do
		if rig.model == model then
			local now = os.clock()
			-- Studio test hook: Workspace attribute "TestFlashSlow" = n makes the flash n times slower (for screenshots)
			local slow = if RunService:IsStudio() then workspace:GetAttribute("TestFlashSlow") else nil
			slow = if type(slow) == "number" and slow > 0 then slow else 1
			for id, weight in pairs(weights) do
				-- a muscle still glowing from the last rep rises again from where it is (no dip back to dark)
				local start = now
				local inTime = TINT.FlashIn * slow
				local last = rig.flashes[id]
				if last then
					local t = now - last.start
					local level = if t < last.inTime then t / last.inTime else math.max(0, 1 - (t - last.inTime) / last.outTime)
					start = now - inTime * level
				end
				rig.flashes[id] = {
					start = start,
					strength = weight * (if big then TINT.BigStrength else TINT.FlashStrength),
					inTime = inTime,
					outTime = (if big then TINT.BigOut else TINT.FlashOut) * slow,
				}
				rig:Pulse({ id }, TINT.Pump * weight * (if big then 1.5 else 1), TINT.PumpTime)
			end
		end
	end
end

-- The small pump on a character's muscles (e.g. the pose hit): ids = muscle ids, amount = +4% is 0.04.
function MuscleRig.PulseModel(model: Model, ids: { string }, amount: number?)
	for rig in pairs(active) do
		if rig.model == model then rig:Pulse(ids, amount) end
	end
end

-- The live EditableMesh behind a muscle MeshPart (nil if it is not one). A second MeshPart made with
-- AssetService:CreateMeshPartAsync(Content.fromObject(mesh)) shows the same, always up-to-date shape without using another
-- of the client's few EditableMeshes (the glass reflection does this).
-- true when every unit this rig wants (the snatched torso and every muscle with growth) has its meshes
function MuscleRig.IsReady(self): boolean
	for _, state in ipairs(self.units) do
		if not state.built and wantedUnit(self, state) then return false end
	end
	return true
end

function MuscleRig.MeshOf(part: Instance): any
	return meshOf[part]
end

-- how many EditableMeshes this client holds / may hold (for tests and the PROGRESS notes)
function MuscleRig.Budget(): (number, number)
	return alive, limit
end

RunService.RenderStepped:Connect(function(dt)
	local budget = VERTEX_BUDGET
	for rig in pairs(active) do
		if rig.model.Parent then
			budget -= step(rig, dt, budget)
		else
			rig:Destroy()
		end
	end
	local now = os.clock()
	if now - lastAllocate > REALLOCATE_EVERY then
		lastAllocate = now
		startBuilds(allocate())
	end
end)

------------------------------------------------------------------------
-- Helpers for the numbers the server publishes (BodyService.PublishData) as attributes
------------------------------------------------------------------------
-- "0.123,0.4,..." (Config.Muscles order) -> { [muscleId] = g }
function MuscleRig.Decode(text: any): { [string]: number }
	local targets = {}
	if type(text) ~= "string" then return targets end
	local index = 0
	for value in string.gmatch(text, "[^,]+") do
		index += 1
		local muscle = Muscles.List[index]
		if muscle then targets[muscle.id] = tonumber(value) or 0 end
	end
	return targets
end

-- The look of a player or rig: skin (the avatar's head color), gym shorts and the optional top, from the attributes on `source`
-- (a Player or a Model). `model` = the character/rig the muscles go on.
function MuscleRig.StyleFrom(source: Instance, model: Model): any
	local head = model:FindFirstChild("Head")
	local skin = source:GetAttribute("SkinColor")
	if typeof(skin) ~= "Color3" then skin = head and head:IsA("BasePart") and head.Color or Color3.fromHex("#E0A878") end
	-- the character's own classic clothing images (muscle v8: the muscles wear them)
	local shirt = model:FindFirstChildOfClass("Shirt")
	local pants = model:FindFirstChildOfClass("Pants")
	return {
		skin = skin,
		shorts = Body.ShortsColor(source:GetAttribute("Shorts")),
		top = if shirt and shirt.ShirtTemplate ~= "" then nil else Body.TopColor(source:GetAttribute("Top")), -- (a worn Shirt: skin under it)
		shirt = if shirt and shirt.ShirtTemplate ~= "" then shirt.ShirtTemplate else nil,
		pants = if pants and pants.PantsTemplate ~= "" then pants.PantsTemplate else nil,
	}
end

return MuscleRig
