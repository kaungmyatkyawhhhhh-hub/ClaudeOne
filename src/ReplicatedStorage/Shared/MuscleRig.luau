-- MuscleRig: muscle v7 on one character / rig (client side; every client builds the muscles of every character it can see).
--
-- Each muscle's outline stays on the skin and only the bulge rises (EditableMesh, SetPosition: vertex = base + (max - base) * g,
-- g = the muscle's level over its max level). The mesh data is in part-local studs (origin = the body part's position), so a
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
--   rig:Destroy()
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MuscleMeshes = require(script.Parent.MuscleMeshes)
local Muscles = require(script.Parent.Config.Muscles)
local Body = require(script.Parent.Config.Body)

local MuscleRig = {}
MuscleRig.__index = MuscleRig

local VERTEX_BUDGET = 6000 -- vertex updates per frame, for all rigs together
local BUILD_MS = 0.004     -- seconds of mesh building per frame per build (time, not a call count: fast PCs build quicker)
local MAX_BUILDS = 3       -- units built at once (CreateMeshPartAsync waits 0.3-1s on the engine; side by side the waits overlap)
local BUILD_CHECK = 250    -- API calls between clock checks
local MIN_SHOW = 0.02      -- below this growth a muscle is hidden inside the body
local TWEEN = 0.4          -- seconds a growth change takes
local PUMPED = 1.04
local PUMP_STEP = 0.03     -- the small pulse
local PULSE_TIME = 0.55
local MIN_CHANGE = 0.0015
local MARBLE = Color3.fromHex("#C9C6BF")
local HIGHLIGHT = Color3.fromRGB(255, 45, 95) -- the stats hover highlight (neon red-pink)
local REALLOCATE_EVERY = 0.4

-- The snatched-waist torso is a unit of its own (two meshes) applied to the real UpperTorso / LowerTorso (MeshPart:ApplyMesh),
-- so the character keeps its own clothing on it. Units are built in this order of importance: for your own character the
-- waist first, then the muscles; for everyone else the chest/abs unit first (so a crowd shows something).
local SNATCHED_UNIT = { id = "Snatched", cost = 2, muscles = {}, groups = { { part = "UpperTorso" }, { part = "LowerTorso" } } }
local OWN_ORDER = { Snatched = 1, TorsoFront = 2, UpperArms = 3, UpperLegs = 4, TorsoBack = 5, Forearms = 6, Calves = 7 }
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
		priority = opts.priority or 0,
		style = opts.style or {},
		target = {},   -- [muscleId] = g the muscle is heading to
		from = {},     -- [muscleId] = g the tween started from
		t0 = {},       -- [muscleId] = tween start time
		current = {},  -- [muscleId] = g now (after the tween)
		pumped = false,
		pulses = {},
		pulseAmounts = {},
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
	if group.colors then
		local skin, shorts, top = colorsOf(self)
		local white = Color3.new(1, 1, 1)
		pcall(function()
			-- under clothing the vertex colors stay white (they would tint the clothing image); the inner part's Color is the skin
			mesh:SetColor(group.colors[1], if template then white else skin)
			mesh:SetColor(group.colors[2], if template then white else shorts)
			mesh:SetColor(group.colors[3], if template then white else top)
		end)
	end
	if self.marble then
		part.Color, part.Material = MARBLE, Enum.Material.Marble
		template = nil
	elseif group.snatched or template then
		part.Color, part.Material = body.Color, body.Material
	else
		part.Color, part.Material = Color3.new(1, 1, 1), Enum.Material.Plastic
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
		local g = math.clamp(targets[id] or 0, 0, 1.12)
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

-- amount = how much bigger the muscle gets at the peak of the pulse (default 3%; the pose hit uses 4%)
function MuscleRig.Pulse(self, ids: { string }, amount: number?)
	local now = os.clock()
	for _, id in ipairs(ids) do
		self.pulses[id] = now
		self.pulseAmounts[id] = amount
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
		local t = (os.clock() - pulseStart) / PULSE_TIME
		if t < 1 then pulse = 1 + (self.pulseAmounts[id] or PUMP_STEP) * math.sin(t * math.pi) end
	end
	return math.min(g * (self.pumped and PUMPED or 1) * pulse, 1.12)
end

local function applyRange(group, range, g: number)
	local data, mesh, ids = group.data, group.mesh, group.vertexIds
	local base, delta, hide, hideDelta = data.base, data.delta, data.hide, data.hideDelta
	local first, last = range.first, range.first + range.count - 1
	if range.shorts then
		for i = first, last do mesh:SetPosition(ids[i], base[i] + delta[i] * g) end
	else
		local s = math.clamp(g / MIN_SHOW, 0, 1)
		for i = first, last do mesh:SetPosition(ids[i], hide[i] + hideDelta[i] * s + delta[i] * g) end
	end
	group.applied[range] = g
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
	local data = MuscleMeshes.LoadGroup(group.def)
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
		local white = Color3.new(1, 1, 1)
		local skinId, shortsId, topId = mesh:AddColor(white, 1), mesh:AddColor(white, 1), mesh:AddColor(white, 1)
		group.glowId = mesh:AddColor(HIGHLIGHT, 1)
		group.colors = { skinId, shortsId, topId }
		group.faceIds = table.create(data.triCount)
		local vertexIds = table.create(data.verts)
		local uvIds = table.create(data.verts)
		for i = 1, data.verts do
			-- built in the MAX shape (the biggest bounds); the real growth is applied below
			vertexIds[i] = mesh:AddVertex(data.base[i] + data.delta[i])
			uvIds[i] = mesh:AddUV(data.uv[i]) -- the clothing template coordinates (Shirt / Pants)
			tick()
		end
		local tris, kinds = data.tris, data.faceKind
		local kindColor = { skinId, shortsId, topId }
		for f = 1, data.triCount do
			local a, b, c = tris[f * 3 - 2] + 1, tris[f * 3 - 1] + 1, tris[f * 3] + 1
			local face = mesh:AddTriangle(vertexIds[a], vertexIds[b], vertexIds[c])
			group.faceIds[f] = face
			mesh:SetFaceUVs(face, { uvIds[a], uvIds[b], uvIds[c] })
			local color = kindColor[kinds[f]]
			mesh:SetFaceColors(face, { color, color, color })
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
	-- the muscle ids this merged mesh holds (the stats highlight lights them up)
	local ids = {}
	for _, range in ipairs(data.ranges) do table.insert(ids, range.id) end
	part:SetAttribute("MuscleName", table.concat(ids, ","))
	attach(self, part, body, group.def.part .. "Muscles")
	meshOf[part] = mesh
	sizeParts(group)
	recolor(self, group)
	-- start every muscle at its current growth
	for _, range in ipairs(data.ranges) do applyRange(group, range, currentShown(self, range.id)) end
	return true
end

-- The snatched-waist torso (muscle v8 body/): shown INSTEAD of the real UpperTorso / LowerTorso (they are hidden on this
-- client only), dressed like the muscles in the character's own Shirt / Pants. It never changes shape, so after it is built
-- it only follows the body. (MeshPart:ApplyMesh onto the real part was tried: the part then loses its clothing.)
local function buildSnatched(self, state, group): boolean
	local body = self.model:FindFirstChild(group.def.part)
	if not body or not body:IsA("BasePart") then return false end
	local data = MuscleMeshes.LoadSnatched(group.def.part)
	if not data then return false end
	local mesh = newMesh()
	if not mesh then return false end
	local ok, err = pcall(function()
		local ids, uvs = {}, {}
		for i, position in ipairs(data.verts) do
			ids[i] = mesh:AddVertex(position)
			uvs[i] = mesh:AddUV(data.uv[i])
		end
		local tris = data.tris
		for k = 1, #tris, 3 do
			local a, b, c = tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1
			local face = mesh:AddTriangle(ids[a], ids[b], ids[c])
			mesh:SetFaceUVs(face, { uvs[a], uvs[b], uvs[c] })
		end
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
	group.mesh, group.part, group.cloth, group.template, group.data, group.vertexIds, group.colors, group.body = nil, nil, nil, nil, nil, nil, nil, nil
	group.applied = {}
	group.lit = nil
	group.glowOn, group.glowShades = nil, nil
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
	for id in pairs(state.unit.muscles) do
		if (self.target[id] or 0) >= MIN_SHOW or (self.current[id] or 0) >= MIN_SHOW then return true end
	end
	return false
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
		if now - started > PULSE_TIME then self.pulses[id] = nil end
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
				-- under layered clothing the muscles hide (the snatched torso stays)
				local hidden = not group.snatched and self.covered and self.covered[body.Name] == true or false
				if group.part.Transparency ~= (hidden and 1 or 0) then
					group.part.Transparency = hidden and 1 or 0
					if group.cloth then group.cloth.Transparency = hidden and 1 or CLOTH_TRANSPARENCY end
				end
				-- apply the muscles that changed (within the frame budget)
				for _, range in ipairs(if group.data then group.data.ranges else {}) do
					local shown = currentShown(self, range.id)
					local last = group.applied[range]
					if (last == nil or math.abs(shown - last) > MIN_CHANGE) and (budget - used > 0 or used == 0) then
						applyRange(group, range, shown)
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
	if self.folder then self.folder:Destroy() end
end

-- The stats hover highlight: every muscle id in `set` (a table { [id] = true }, or nil to clear) is painted neon red on the
-- character `model` (only the meshes that are built). Cheap enough to do on hover.
-- The neon glow keeps its shape: Neon material is emissive and flat, so the shading is baked into the lit faces. Each face gets
-- the neon color scaled by how much it faces a fixed light (front, a little from above), in  steps, so the
-- muscle reads as a glowing 3D shape and not a solid slab.
local GLOW_SHADES = 12
local GLOW_LIGHT = Vector3.new(-0.2, 0.7, -0.7).Unit
local function glowFaces(group, range)
	local mesh, data = group.mesh, group.data
	if not group.glowShades then
		group.glowShades = {}
		for step = 1, GLOW_SHADES do
			local k = 0.38 + 0.62 * (step - 1) / (GLOW_SHADES - 1)
			group.glowShades[step] = mesh:AddColor(Color3.new(math.min(HIGHLIGHT.R * k * 1.0, 1), HIGHLIGHT.G * k, HIGHLIGHT.B * k), 1)
		end
	end
	local g = group.applied[range] or 1
	local base, delta, tris = data.base, data.delta, data.tris
	for f = range.triFirst, range.triFirst + range.triCount - 1 do
		local a, b, c = tris[f * 3 - 2] + 1, tris[f * 3 - 1] + 1, tris[f * 3] + 1
		local pa, pb, pc = base[a] + delta[a] * g, base[b] + delta[b] * g, base[c] + delta[c] * g
		local normal = (pb - pa):Cross(pc - pa)
		local shade = 0.5
		if normal.Magnitude > 1e-9 then
			normal = normal.Unit
			-- outward = away from the part centre
			if normal:Dot((pa + pb + pc) / 3) < 0 then normal = -normal end
			shade = math.clamp(0.5 + 0.5 * normal:Dot(GLOW_LIGHT), 0, 1)
		end
		local id = group.glowShades[1 + math.floor(shade * (GLOW_SHADES - 1) + 0.5)]
		mesh:SetFaceColors(group.faceIds[f], { id, id, id })
	end
end

function MuscleRig.SetHighlight(model: Model, set: { [string]: boolean }?)
	for rig in pairs(active) do
		if rig.model == model then
			for _, state in ipairs(rig.units) do
				for _, group in ipairs(state.groups) do
					if group.mesh and group.faceIds and group.part then
						-- which muscles of this mesh are lit now
						local anyLit = false
						for _, range in ipairs(group.data.ranges) do
							if set ~= nil and set[range.id] == true then anyLit = true end
						end
						if anyLit then
							-- the lit muscles glow: the part turns Neon (emissive, so the vertex colors show at full strength and the
							-- scene's bloom picks them up), the lit faces get the neon color, every other muscle on the part is dimmed so
							-- the glow stands out, the clothing layer steps aside and a pulsing light spills the glow around
							pcall(function()
								local dim = Color3.new(0.34, 0.31, 0.31)
								for _, id in ipairs(group.colors) do group.mesh:SetColor(id, dim) end
								for _, range in ipairs(group.data.ranges) do
									local lit = set[range.id] == true
									if lit ~= (group.lit and group.lit[range] or false) or not group.glowOn then
										group.lit = group.lit or {}
										group.lit[range] = lit
										local normal = if range.shorts then group.colors[2] elseif group.def.part == "UpperTorso" then group.colors[3] else group.colors[1]
										if lit then
											glowFaces(group, range)
										else
											for f = range.triFirst, range.triFirst + range.triCount - 1 do
												group.mesh:SetFaceColors(group.faceIds[f], { normal, normal, normal })
											end
										end
									end
								end
							end)
							if not group.glowOn then
								group.glowOn = true
								group.part.Material = Enum.Material.Neon
								group.part.Color = Color3.new(1, 1, 1)
								if group.cloth then group.cloth.Transparency = 1 end
								local light = Instance.new("PointLight")
								light.Name = "HighlightGlow"
								light.Color = HIGHLIGHT
								light.Range = 5
								light.Brightness = 0.8
								light.Shadows = false
								light.Parent = group.part
								TweenService:Create(light, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Brightness = 1.6, Range = 7 }):Play()
							end
						elseif group.glowOn then
							-- back to normal: faces, colors, material, clothing
							group.glowOn = false
							local light = group.part:FindFirstChild("HighlightGlow")
							if light then light:Destroy() end
							pcall(function()
								for _, range in ipairs(group.data.ranges) do
									if group.lit and group.lit[range] then
										local normal = if range.shorts then group.colors[2] elseif group.def.part == "UpperTorso" then group.colors[3] else group.colors[1]
										for f = range.triFirst, range.triFirst + range.triCount - 1 do
											group.mesh:SetFaceColors(group.faceIds[f], { normal, normal, normal })
										end
									end
								end
							end)
							group.lit = nil
							recolor(rig, group)
							if group.cloth then group.cloth.Transparency = CLOTH_TRANSPARENCY end
						end
					end
				end
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
		top = Body.TopColor(source:GetAttribute("Top")),
		shirt = if shirt and shirt.ShirtTemplate ~= "" then shirt.ShirtTemplate else nil,
		pants = if pants and pants.PantsTemplate ~= "" then pants.PantsTemplate else nil,
	}
end

return MuscleRig
