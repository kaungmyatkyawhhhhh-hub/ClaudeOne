-- MuscleRig: the muscles (muscle v9 unified) on one character / rig (client side).
--
-- The torso and the upper arms are UNIFIED meshes: one welded EditableMesh per body part that is its whole skin, so any mix of
-- levels is one smooth surface. Per vertex: pos = base + morph * (1 - waistT) + sum(g_m * disp_m) + vein * v (MuscleMeshes);
-- normals come the same way from the data (nbase + sum(g_m * ndisp_m)). The legs, forearms and calves are SHELL meshes
-- (base + (max - base) * g, smooth borders by blend weights). The LowerTorso is the snatched waist. (The package's separate
-- upper traps shell is not used: it floated over the unified torso, which grows the traps itself.)
--
-- COST RULES (8 Oct, the lag pass):
--   * vertices are only written when a look, the pump, the waist, the veins or the torso width actually changed, and only the
--     vertices of the muscle that changed (each muscle's idx list; a running sum per vertex), at most UPDATE_HZ times a
--     second per rig; when nothing changes nothing is written;
--   * the hover highlight and the rep flash are a handful of vertex-color writes per muscle, only while a fade runs;
--   * only YOUR character gets EditableMeshes. Measured in Studio (8 Oct): a play client holds at most 8 EditableMeshes (even
--     empty ones), and a mesh's MeshPart shows nothing once its EditableMesh is gone (no baking, also not via ApplyMesh). Your
--     body uses 7, all from level 0 (torso front + back: 39,600 triangles over the 20,000 limit; two upper arms; two upper
--     legs: they cover the thighs, the plain upper legs are hidden; the waist), so everyone else (players, NPCs, the statue) shows the plain body with the skin stage, and every
--     character's forearms / calves are the static stage meshes (Shared.LimbStages). MuscleClient tracks nobody past ~80 studs.
-- Skin: every skin surface (muscle meshes, the body parts) wears the skin texture stage for its look (Config.SkinStages, a
-- SurfaceAppearance tinted to the skin color), unless the character's own Shirt / Pants covers it. Under a SurfaceAppearance a
-- mesh's vertex colors don't show (measured 8 Oct), so a skinned muscle mesh gets a thin COLOR LAYER: a second MeshPart from
-- the same EditableMesh (no extra budget) a hair bigger, whose vertex colors carry ALPHA: invisible (0) on skin, the gym shorts
-- (1) on the thigh meshes, and the hover / flash tint while one runs (drawn only while it has something to show).
--
--   local rig = MuscleRig.new(model, { static = false, style = { skin, shorts, top, shirt, pants }, marble = false, priority = 100 })
--   rig:SetGrowth({ Biceps = 0.4, ... })   -- tweens ~0.4s
--   rig:Snap(targets)                      -- no tween
--   rig:Pulse({ "Biceps" })                -- the small pump on every 10th level
--   rig:SetPumped(true)                    -- PUMPED: a little bigger
--   rig:SetStyle(style)
--   MuscleRig.SetHighlight(model, { Biceps = true })        -- the red hover tint (only on muscles facing the camera)
--   MuscleRig.Flash(model, { MidChest = 1, Triceps = 0.5 }, big) -- the warm rep flash + a tiny pump
--   rig:Destroy()
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MuscleMeshes = require(script.Parent.MuscleMeshes)
local LimbStages = require(script.Parent.LimbStages)
local Muscles = require(script.Parent.Config.Muscles)
local Body = require(script.Parent.Config.Body)
local SkinStages = require(script.Parent.Config.SkinStages)

local MuscleRig = {}
MuscleRig.__index = MuscleRig

local UPDATE_HZ = 20       -- mesh writes per second per rig, at most (the numbers tween every frame)
-- Writing a mesh is expensive (measured 8 Oct: all 8 meshes in one frame = 90-130 ms): a frame writes at most one unit (a
-- body region: the torso's two halves always together, so their shared edge never cracks), the units take turns.
-- A look only moves once it changed by GROWTH_STEP (every rep adds a little EXP: invisible steps cost a full write each), and
-- a small change is written once instead of tweened; a big one (a Growth Spurt, a test value) still tweens.
local GROWTH_STEP = 0.015
local SNAP_BELOW = 0.05
local SLOW_HZ = 10         -- the rest (parts swapped, sizes, visibility, garments, limb stages) when nothing moves
local BUILD_MS = 0.004     -- seconds of mesh building per frame per build
local MAX_BUILDS = 2       -- units built at once (CreateMeshPartAsync waits on the engine; side by side the waits overlap)
local BUILD_CHECK = 250    -- API calls between clock checks
local MIN_SHOW = 0.02      -- a unit is only built once one of its muscles has at least this much growth
local VEIN_PUMPED = 0.4    -- veins while PUMPED at the full look
local TWEEN = 0.4          -- seconds a growth change takes
local PUMPED = 1.04
local PUMP_STEP = 0.03     -- the small pulse
local PULSE_TIME = 0.55
local MIN_CHANGE = 0.0015
local MARBLE = Color3.fromHex("#C9C6BF")
-- Tints on the muscles (a tint, not paint: the color blended part of the way toward the tint, on the normal lit surface):
--   * Stats hover (red): only the muscles facing the camera;
--   * training (cool light blue, MuscleRig.SetTraining): the whole time you're on a machine, every muscle it trains, main
--     strong / secondaries light, both sides of the body; fades in / out; each rep a quick brighter pulse
--     (MuscleRig.Flash) on top. Blue = training, red = Stats hover (hover wins while both).
local TINT = {
	Highlight = Color3.fromRGB(225, 45, 45),
	Hover = 0.40,
	HighlightIn = 0.15, HighlightOut = 0.2,
	Training = Color3.fromRGB(95, 160, 255), -- (the brief: about 120, 180, 255; a bit deeper so it still reads blue under the warm gym lamps)
	TrainingBright = Color3.fromRGB(185, 220, 255), -- the pulse's color
	TrainMain = 0.55, TrainHelper = 0.30,
	TrainIn = 0.25, TrainOut = 0.4,
	PulseUp = 0.05, PulseDown = 0.15, -- the rep pulse: ~0.2 s
	PulseStrength = 0.6, BigPulse = 1,
	-- the color layer is drawn at REST x its vertex colors (they are written divided by it) and goes to 1 on a pulse: a
	-- brighter tint without writing the mesh
	Rest = 0.88,
	-- the skin stage textures are darker than the flat skin color: the layer's skin is drawn this much darker so an untinted
	-- muscle beside a tinted one matches the textured skin, and the blue reads as blue, not pale
	SkinUnder = 0.8,
	ClothScale = 0.375,
	FacingFull = 0.1, FacingNone = -0.1,
}
-- which body part shows a muscle on characters without muscle meshes (other players, NPCs): the training tint goes there
local BODY_OF = {
	UpperChest = { "UpperTorso" }, MidChest = { "UpperTorso" }, Abs = { "UpperTorso", "LowerTorso" }, Obliques = { "UpperTorso", "LowerTorso" },
	Traps = { "UpperTorso" }, Rhomboids = { "UpperTorso" }, Lats = { "UpperTorso" }, LowerBack = { "LowerTorso" },
	FrontDelts = { "LeftUpperArm", "RightUpperArm" }, SideDelts = { "LeftUpperArm", "RightUpperArm" }, RearDelts = { "LeftUpperArm", "RightUpperArm" },
	Biceps = { "LeftUpperArm", "RightUpperArm" }, Triceps = { "LeftUpperArm", "RightUpperArm" },
	Quads = { "LeftUpperLeg", "RightUpperLeg" }, Hamstrings = { "LeftUpperLeg", "RightUpperLeg" }, Glutes = { "LeftUpperLeg", "RightUpperLeg" },
}
local REALLOCATE_EVERY = 0.4

local OWN_ORDER = { Torso = 1, Snatched = 2, UpperArms = 3, UpperLegs = 4, Forearms = 6, Calves = 7 }

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
-- which classic clothing image covers a body part (its skin texture gives way to the clothing there)
local CLOTHING_OF = {
	UpperTorso = "Shirt", RightUpperArm = "Shirt", LeftUpperArm = "Shirt", RightLowerArm = "Shirt", LeftLowerArm = "Shirt",
	RightHand = "Shirt", LeftHand = "Shirt",
	LowerTorso = "Pants", RightUpperLeg = "Pants", LeftUpperLeg = "Pants", RightLowerLeg = "Pants", LeftLowerLeg = "Pants",
	RightFoot = "Pants", LeftFoot = "Pants",
}

local active: { [any]: boolean } = {}
local meshOf = setmetatable({}, { __mode = "k" }) -- [muscle MeshPart] = its live EditableMesh (a mirror shows the same mesh)

-- Allocator state: how many EditableMeshes are alive, and the most this client allows (learned when a create fails).
local alive = 0
local limit = math.huge
local limitResetAt = 0
local building = 0
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
		target = {}, from = {}, t0 = {}, current = {},
		pumped = false,
		pulses = {}, pulseAmounts = {}, pulseTimes = {},
		highlightSet = nil, highlightAmount = {},
		trainSet = MuscleRig.TrainingOf(model), trainWeights = MuscleRig.TrainingOf(model), trainAmount = 0, pulseStart = nil, pulseStrength = 0, pulse = 0, bodyTint = {},
		tintWasLive = false,
		destroyed = false,
		units = {},
		garments = {},
		hidden = {},      -- [body part] = how many muscle meshes stand in for it (it is see-through while > 0)
		lastWrite = 0,
		skinStage = nil,  -- the stage index the skin shows
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
		for _, group in ipairs(unit.groups) do table.insert(state.groups, { def = group }) end
		table.insert(self.units, state)
	end
	active[self] = true
	self:DressBody()
	return self
end

-- live = gets EditableMeshes: your own character (priority 100+) only
local function isLive(self): boolean
	return self.priority >= 100
end

------------------------------------------------------------------------
-- Colors, the skin texture stage and the body
------------------------------------------------------------------------
local BODY_PARTS = { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" }

local function colorsOf(self)
	local style = self.style
	if self.marble then return Color3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.new(1, 1, 1) end
	local skin = style.skin or Color3.fromHex("#E0A878")
	return skin, style.shorts or Color3.fromHex("#1E1E22"), style.top or skin
end

local function smoothMaterial(material: Enum.Material): Enum.Material
	return if material == Enum.Material.Plastic then Enum.Material.SmoothPlastic else material
end

-- The character's own classic clothing image for a kind ("Shirt" / "Pants"), or nil.
local function templateFor(self, kind: string?): string?
	if self.marble then return nil end
	local template = if kind == "Pants" then self.style.pants else self.style.shirt
	return if type(template) == "string" and template ~= "" then template else nil
end

-- The skin stage templates (ReplicatedStorage.SkinStages.Stage1..5, built in Studio by tools/builders/SkinStages).
local stageFolder = ReplicatedStorage:FindFirstChild("SkinStages")
local function stageTemplate(index: number): SurfaceAppearance?
	if not stageFolder then stageFolder = ReplicatedStorage:FindFirstChild("SkinStages") end
	local template = stageFolder and stageFolder:FindFirstChild("Stage" .. index)
	return if template and template:IsA("SurfaceAppearance") then template else nil
end

-- every stage's textures load at the start, so a stage change never shows a blank (white) skin while its maps load
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("SkinStages", 30)
	if folder and RunService:IsClient() then
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(folder:GetChildren()) end)
	end
end)

-- Puts the skin stage on a part (a clone named "SkinStage", tinted to `color`: SurfaceAppearance.Color is the tint, the
-- part's own Color doesn't show under it), or takes it off (index nil).
local function setSkin(part: BasePart, index: number?, color: Color3)
	local current = part:FindFirstChild("SkinStage")
	if index == nil then
		if current then current:Destroy() end
		return
	end
	if current and current:GetAttribute("Stage") == index then
		if (current :: any).Color ~= color then pcall(function() (current :: any).Color = color end) end
		return
	end
	local template = stageTemplate(index)
	if not template then return end
	local sa = template:Clone()
	sa.Name = "SkinStage"
	sa:SetAttribute("Stage", index)
	pcall(function() (sa :: any).Color = color end)
	sa.Parent = part
	if current then current:Destroy() end
end

-- The body's overall look for the skin stage: the average look up to the full aesthetic size, plus the average way into the
-- mass monster stage (0 .. 2, Config.SkinStages.At).
local function overallLook(self): number
	local grown, monster = 0, 0
	for _, muscle in ipairs(Muscles.List) do
		local g = self.current[muscle.id] or 0
		grown += math.min(g, 1)
		monster += math.clamp((g - 1) / math.max(Muscles.MonsterG(muscle.id) - 1, 0.01), 0, 1)
	end
	return grown / #Muscles.List + monster / #Muscles.List
end

-- The body itself in plain skin color (the muscle meshes use the same color, so they blend in), gym shorts on the hips.
function MuscleRig.DressBody(self)
	if self.keepBody or not self.style.skin then return end
	local model = self.model
	local skin, shorts, top = colorsOf(self)
	local material = self.marble and Enum.Material.Marble or Enum.Material.Plastic
	local function paint(name: string, color: Color3, mat: Enum.Material?)
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("SurfaceAppearance") and child.Name ~= "SkinStage" then child:Destroy() end
			end
			part.Color = self.marble and MARBLE or color
			part.Material = mat or material
		end
	end
	for _, name in ipairs(BODY_PARTS) do paint(name, skin) end
	paint("UpperTorso", top)
	paint("LowerTorso", shorts, self.marble and Enum.Material.Marble or Enum.Material.Fabric)
	self.skinStage = nil -- (the skin pass puts the stage back on)
end

-- The skin texture stage on every skin surface: the body parts (not under the character's own Shirt / Pants, not on NPCs that
-- keep their painted clothes) and the inner muscle parts (whose color is the skin).
local function skinPass(self)
	if self.marble then return end
	local index = SkinStages.Pick(overallLook(self), self.skinStage)
	local skin = colorsOf(self)
	local function skinned(part: BasePart, isSkin: boolean, kind: string?)
		local covered = kind ~= nil and templateFor(self, kind) ~= nil
		setSkin(part, if isSkin and not covered then index else nil, skin)
	end
	local model = self.model
	if not self.keepBody then
		for _, name in ipairs(BODY_PARTS) do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then skinned(part, true, CLOTHING_OF[name]) end
		end
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then skinned(head, true, nil) end
		local torso = model:FindFirstChild("UpperTorso")
		if torso and torso:IsA("BasePart") then skinned(torso, self.style.top == nil, "Shirt") end
	end
	for _, state in ipairs(self.units) do
		for _, group in ipairs(state.groups) do
			local part = group.part
			if part and part.Parent then setSkin(part, if group.skinned then index else nil, skin) end
		end
	end
	-- the forearm / calf stage meshes of other characters
	for _, child in ipairs(self.folder:GetChildren()) do
		if child:IsA("MeshPart") and string.sub(child.Name, -5) == "Stage" then
			skinned(child, true, if string.find(child.Name, "Calves") then "Pants" else "Shirt")
		end
	end
	self.skinStage = index
	self.skinColor = skin
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
		if g.Color ~= shorts then g.Color = shorts end
		local transparency = visible and 0 or 1
		if g.Transparency ~= transparency then g.Transparency = transparency end
		local size = leg.Size
		local length = size.Y * 0.435
		local diameter = math.max(size.X, size.Z) * 1.1
		local want = Vector3.new(length, diameter, diameter)
		if g.Size ~= want then
			g.Size = want
			garment.weld.C0 = CFrame.new(0, size.Y * 0.29, 0) * CFrame.Angles(0, 0, math.pi / 2)
			if self.static then g.CFrame = leg.CFrame * garment.weld.C0 end
		end
	end
end

-- Muscles WEAR THE CHARACTER'S OWN CLOTHING: each mesh is shown by two MeshParts made from the same EditableMesh (no extra
-- budget): the inner part (the bare body: skin with its texture stage, or the game's top / gym-shorts color), a hair smaller,
-- and the outer "Cloth" part (the Shirt / Pants image as TextureID, a tiny bit transparent, so the image's see-through areas
-- show the inner part, like skin under clothing on the real body part).
local function groupScale(group): Vector3
	local ref = group.refSize
	local size = group.body.Size
	return Vector3.new(size.X / ref.X, size.Y / ref.Y, size.Z / ref.Z)
end

local INNER_SCALE = 0.985
local CLOTH_TRANSPARENCY = 0.02
local LAYER_SCALE = 1.004 -- the color layer (header): a hair bigger than the inner part
local LAYER_TRANSPARENCY = 0.02
-- Between tints the layer waits nearly invisible instead of hidden (hiding a part fully and showing it again is a ~50 ms
-- spike each time, measured 8 Oct); it hides fully LAYER_HOLD seconds after the last tint.
local LAYER_IDLE, LAYER_HOLD = 0.99, 3
-- Muscle MeshParts never collide: a Box collision shape, so changing the mesh never makes the engine rebuild a hull for a
-- 20,000-triangle mesh (the parts are welded to a moving character: every vertex write did, ~80 ms a write, measured 8 Oct)
local MESH_PART_OPTIONS = { CollisionFidelity = Enum.CollisionFidelity.Box }

-- A MeshPart made from an EditableMesh draws the mesh scaled by Size / ITS OWN MeshSize, and its MeshSize is the mesh's
-- bounds at the moment that part was made: the inner part was made at the biggest shape, the clothing and color layers
-- later (the real, smaller shape). So each part is sized from its own MeshSize (8 Oct: giving the layers the inner part's
-- Size drew them ~1.7x too big: the gym shorts on the thighs' layer were the "puffy inner tube").
local function sizeParts(group)
	local part, cloth = group.part, group.cloth
	if not part then return end
	local scale = groupScale(group)
	part.Size = part.MeshSize * scale * (if cloth then INNER_SCALE else 1)
	if cloth then cloth.Size = cloth.MeshSize * scale end
	if group.layer then group.layer.Size = group.layer.MeshSize * scale * LAYER_SCALE end
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

-- the clothing part (a second MeshPart made from the same live mesh)
local function makeCloth(self, group, template: string?)
	if group.cloth then
		meshOf[group.cloth] = nil
		group.cloth:Destroy()
		group.cloth = nil
	end
	group.template = template
	local mesh, body = group.mesh, group.body
	if template and mesh and body then
		local ok, cloth = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), MESH_PART_OPTIONS) end)
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

-- true when a muscle group's inner part wears the skin stage (its surface is skin, not under the character's own clothing)
local function skinnedFor(self, group): boolean
	if self.marble or not stageTemplate(1) or group.def.kind == "snatched" then return false end
	if templateFor(self, group.clothingKind) or (self.covered and group.body and self.covered[group.body.Name]) then return false end
	local kind = group.kindIndex or 1
	if self.keepBody then return kind == 1 end
	return kind == 1 or (kind == 3 and self.style.top == nil)
end

-- the color layer (see the header): made from the live mesh, a hair bigger than the inner part
local function makeLayer(self, group)
	local mesh, body = group.mesh, group.body
	if group.layer or group.layerPending or not (mesh and body) then return end
	group.layerPending = true
	local ok, layer = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), MESH_PART_OPTIONS) end)
	group.layerPending = nil
	if ok and layer and group.mesh == mesh and group.skinned and not group.layer then
		layer.Color = Color3.new(1, 1, 1)
		-- (the gym shorts on it are cloth: matte Fabric; SmoothPlastic made them a glossy black plastic. In mirror mode the layer
		-- also covers the thigh skin, which must not look like cloth: SmoothPlastic then)
		layer.Material = if group.hasShorts and not self.mirrorMode then Enum.Material.Fabric else Enum.Material.SmoothPlastic
		layer.Transparency = 1
		attach(self, layer, body, group.def.part .. "Layer")
		group.layer = layer
		sizeParts(group)
	elseif ok and layer then
		layer:Destroy()
	end
end
local function dropLayer(group)
	if group.layer then
		group.layer:Destroy()
		group.layer = nil
	end
end

-- The vertex colors' base (kinds: 1 skin, 2 gym shorts, 3 top) and the inner part's look.
local function recolor(self, group)
	local part, body = group.part, group.body
	if not part or not body then return end
	local template = templateFor(self, group.clothingKind)
	if self.covered and self.covered[body.Name] then template = nil end
	local skin, shorts, top = colorsOf(self)
	local white = Color3.new(1, 1, 1)
	group.skinned = skinnedFor(self, group)
	group.hasShorts = false
	for _, kind in pairs(group.rangeKinds or {}) do
		if kind == 2 then group.hasShorts = true end
	end
	if group.skinned and not group.hasShorts then
		-- the torso / arms: their color layer is OPAQUE (it only shows while tinted, and then it is a whole lit surface:
		-- flat skin + the tint), so every vertex has alpha 1: a transparent overlay vanishes behind Glass (8 Oct) and a
		-- ViewportFrame (the mirror) would draw the skin's own part see-through
		local rest = function(c: Color3) return Color3.new(math.min(c.R / TINT.Rest, 1), math.min(c.G / TINT.Rest, 1), math.min(c.B / TINT.Rest, 1)) end
		group.kindBase, group.kindAlpha = { rest(skin), rest(shorts), rest(skin) }, { 1, 1, 1 }
	elseif group.skinned and self.mirrorMode then
		-- MIRROR MODE (MuscleRig.SetMirrorMode): every vertex opaque. The progress mirror's ViewportFrame draws copies of these
		-- meshes and, unlike the world, it honours vertex alpha even under a SurfaceAppearance: the layer's alpha 0 on skin
		-- made the copies see-through (the "white torso"). The skin's own part ignores vertex colors (its SurfaceAppearance);
		-- the layer then shows flat skin + the shorts on the thighs, and no tint.
		group.kindBase, group.kindAlpha = { skin, shorts, skin }, { 1, 1, 1 }
	elseif group.skinned then
		-- the layer: nothing over the skin, the gym shorts over the shorts meshes
		group.kindBase, group.kindAlpha = { white, shorts, white }, { 0, 1, 0 }
	else
		group.kindBase = { if template then white else skin, if template then white else shorts, if template then white else top }
		group.kindAlpha = { 1, 1, 1 }
	end
	group.shownColors = {}
	group.maskKey = nil
	local mesh = group.mesh
	if mesh then
		pcall(function()
			local function setAll(ids, kind)
				for band = 0, MuscleMeshes.TintBands do
					mesh:SetColor(ids[band], group.kindBase[kind])
					mesh:SetColorAlpha(ids[band], group.kindAlpha[kind])
				end
			end
			for _, ids in pairs(group.colorIds or {}) do setAll(ids, group.kindIndex or 1) end
			if group.baseColorId then
				mesh:SetColor(group.baseColorId, group.kindBase[group.kindIndex or 1])
				mesh:SetColorAlpha(group.baseColorId, group.kindAlpha[group.kindIndex or 1])
			end
			for range, ids in pairs(group.rangeColors or {}) do setAll(ids, group.rangeKinds[range]) end
		end)
	end
	if group.skinned then
		if group.layer then group.layer.Material = if group.hasShorts and not self.mirrorMode then Enum.Material.Fabric else Enum.Material.SmoothPlastic end
		task.spawn(makeLayer, self, group)
	else
		dropLayer(group)
	end
	if self.marble then
		part.Color, part.Material = MARBLE, Enum.Material.Marble
		template = nil
	elseif group.def.kind == "snatched" or group.def.kind == "unified" or group.def.hidePart or template then
		-- it stands in for the body part: the body part's own color and material
		part.Color, part.Material = body.Color, smoothMaterial(body.Material)
		if group.def.kind == "unified" and group.kindIndex == 3 and not template then part.Color = top end
		if (group.def.kind == "unified" and group.kindIndex == 1) or group.def.hidePart then part.Color = skin end
	else
		part.Color, part.Material = Color3.new(1, 1, 1), Enum.Material.SmoothPlastic
	end
	if template ~= group.template or (template and not group.cloth) then
		task.spawn(makeCloth, self, group, template)
	end
	self.skinStage = nil
end

function MuscleRig.SetStyle(self, style)
	self.style = style or {}
	self.dirty = true
	self:DressBody()
	for _, state in ipairs(self.units) do
		for _, group in ipairs(state.groups) do recolor(self, group) end
	end
	self.skinStage = nil
end

------------------------------------------------------------------------
-- Growth numbers
------------------------------------------------------------------------
function MuscleRig.SetGrowth(self, targets: { [string]: number })
	local now = os.clock()
	for _, muscle in ipairs(Muscles.List) do
		local id = muscle.id
		local g = math.clamp(targets[id] or 0, 0, Muscles.MaxLookG)
		if math.abs(g - self.target[id]) >= GROWTH_STEP or (g == 0 and self.target[id] ~= 0) then
			if math.abs(g - self.current[id]) < SNAP_BELOW then
				self.from[id], self.current[id], self.t0[id] = g, g, 0 -- (small: one write, no tween)
			else
				self.from[id] = self.current[id]
				self.t0[id] = now
			end
			self.target[id] = g
			self.dirty = true
		end
	end
end

function MuscleRig.Snap(self, targets: { [string]: number })
	self:SetGrowth(targets)
	for id, g in pairs(self.target) do
		self.from[id], self.current[id], self.t0[id] = g, g, 0
	end
	self.dirty = true
end

function MuscleRig.Pulse(self, ids: { string }, amount: number?, duration: number?)
	local now = os.clock()
	for _, id in ipairs(ids) do
		self.pulses[id] = now
		self.pulseAmounts[id] = amount
		self.pulseTimes[id] = duration
	end
	self.dirty = true
end

function MuscleRig.SetPumped(self, pumped: boolean)
	if self.pumped ~= pumped then self.dirty = true end
	self.pumped = pumped
end

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

local function monsterT(id: string, g: number): number
	return math.clamp((g - 1) / math.max(Muscles.MonsterG(id) - 1, 0.01), 0, 1)
end
local MONSTER_EXTRA = Body.Widths.MassMonster.muscle_extra -- the monster's extra thickness on top of its size

-- The growth one mesh / muscle is drawn at: its g up to the full look; past it toward its own monster size (manifest
-- mass_monster.g by name) with the monster's extra thickness.
local function meshShown(self, key: string, id: string): number
	local g = currentShown(self, id)
	if g <= 1 then return g end
	local t = math.clamp((g - 1) / math.max(Muscles.MonsterG(id) - 1, 0.01), 0, 1.1)
	return (1 + t * (MuscleMeshes.MonsterG(key) - 1)) * (1 + MONSTER_EXTRA * math.min(t, 1))
end

-- the vein amount for a muscle: with the mass monster stage, and briefly while PUMPED at the full look
local function veinFor(self, id: string): number
	local g = self.current[id] or 0
	return math.max(monsterT(id, g), if self.pumped and g >= 1 then VEIN_PUMPED else 0)
end
-- the veins of a unified mesh: one amount for the whole mesh (the most of its muscles)
local function veinOfPiece(self, piece): number
	local v = 0
	for _, muscle in ipairs(piece.muscleNames) do v = math.max(v, veinFor(self, muscle)) end
	return math.floor(v * 50 + 0.5) / 50 -- (in steps: a vein change rewrites the whole mesh)
end

-- The torso width (attributes set by BodyService): every mesh on the UpperTorso is drawn FrameWidth wider at the shoulders,
-- down to WaistWidth at the waist (a V-Taper is a V).
local FRAME_TAPER = { From = -0.3, To = 0.3 }
local function frameTaper(self, part: string, positions: { Vector3 }): { number }?
	local top, waist = self.taperTop or 1, self.taperWaist or 1
	if math.abs(top - waist) < 1e-3 or part ~= "UpperTorso" then return nil end
	local height = MuscleMeshes.Parts.UpperTorso.size.Y
	local taper = table.create(#positions)
	for i, position in ipairs(positions) do
		local t = math.clamp((position.Y / height - FRAME_TAPER.From) / (FRAME_TAPER.To - FRAME_TAPER.From), 0, 1)
		t = t * t * (3 - 2 * t)
		taper[i] = (waist + (top - waist) * t) / top
	end
	return taper
end

-- The waist that tightens: 0 = the wide straight waist of a beginner, 1 = the snatched V; the average growth, eased.
local function waistProgress(self): number
	local total = 0
	for _, muscle in ipairs(Muscles.List) do total += math.min(self.current[muscle.id] or 0, 1) end
	return math.floor(smooth(total / #Muscles.List) * 250 + 0.5) / 250 -- (in steps: a waist change rewrites the whole torso)
end

------------------------------------------------------------------------
-- Writing vertices
------------------------------------------------------------------------
-- A unified piece: each muscle whose drawn g moved adds (g - applied) * disp to its vertices' running sums; those vertices
-- (or all, when the waist / veins / width changed) are written. Returns how many vertices were written.
local function applyUnified(self, group, full: boolean?): number
	local piece, mesh, ids, normalIds = group.piece, group.mesh, group.vertexIds, group.normalIds
	if not (piece and mesh and ids) then return 0 end
	local acc, nacc, applied = group.acc, group.nacc, group.appliedG
	local dirty, list = group.dirty, {}
	local w = waistProgress(self)
	local v = if piece.vein then veinOfPiece(self, piece) else 0
	local all = full == true or w ~= group.appliedW or v ~= group.appliedVein or group.taperChanged
	for _, muscle in ipairs(piece.muscleNames) do
		local g = meshShown(self, muscle, muscle)
		local dg = g - (applied[muscle] or 0)
		if math.abs(dg) > MIN_CHANGE then
			applied[muscle] = g
			local m = piece.muscles[muscle]
			local idx, disp = m.idx, m.disp
			for j = 1, #idx do
				local l = idx[j]
				acc[l] += disp[j] * dg
				if not all and not dirty[l] then dirty[l] = true table.insert(list, l) end
			end
			local nidx, ndisp = m.nidx, m.ndisp
			for j = 1, #nidx do
				local l = nidx[j]
				nacc[l] += ndisp[j] * dg
				if not all and not dirty[l] then dirty[l] = true table.insert(list, l) end
			end
		end
	end
	if all then
		list = table.create(piece.verts)
		for l = 1, piece.verts do list[l] = l end
	end
	if #list == 0 then return 0 end
	local base, morph, vein, nbase, taper = piece.base, piece.morph, piece.vein, piece.nbase, group.taper
	local waistOff = 1 - w
	for _, l in ipairs(list) do
		dirty[l] = nil
		local position = base[l] + acc[l]
		if morph then position += morph[l] * waistOff end
		if v > 0 and vein then position += vein[l] * v end
		if taper then position = Vector3.new(position.X * taper[l], position.Y, position.Z) end
		mesh:SetPosition(ids[l], position)
		if normalIds then
			local n = nbase[l] + nacc[l]
			if n.Magnitude > 1e-6 then mesh:SetNormal(normalIds[l], n.Unit) end
		end
	end
	group.appliedW, group.appliedVein, group.taperChanged = w, v, false
	return #list
end

-- A shell group: every range (mesh) whose g, a blend neighbour's g, the waist (morph) or its veins changed is written.
local function rangeShown(self, range): number
	return meshShown(self, range.key, range.id)
end
local function rangeChanged(self, group, range): boolean
	if group.taperChanged then return true end
	local last = group.applied[range]
	if last == nil or math.abs(rangeShown(self, range) - last) > MIN_CHANGE then return true end
	if group.data.morph and waistProgress(self) ~= group.appliedW[range] then return true end
	local others = group.appliedOthers[range]
	for _, key in ipairs(range.blendKeys) do
		if not others or math.abs(meshShown(self, key, MuscleMeshes.MuscleId(key)) - (others[key] or 0)) > MIN_CHANGE then return true end
	end
	return group.data.vein ~= nil and veinFor(self, range.id) ~= group.appliedVein[range]
end

local function applyRange(self, group, range): number
	local data, mesh, ids, normalIds = group.data, group.mesh, group.vertexIds, group.normalIds
	local base, delta, blends, nbase, ndelta, vein, morph = data.base, data.delta, data.blends, data.nbase, data.ndelta, data.vein, data.morph
	local hug = data.hug
	local taper = group.taper
	local g = rangeShown(self, range)
	local others = {}
	for _, key in ipairs(range.blendKeys) do others[key] = meshShown(self, key, MuscleMeshes.MuscleId(key)) end
	local v = if vein then veinFor(self, range.id) else 0
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
		-- (the shorts: fabric over the muscle, MuscleMeshes.LoadGroup)
		if hug and hug[i] then gv *= hug[i] end
		local position = base[i] + delta[i] * gv
		if morph and morph[i] then position += morph[i] * waistOff end
		if v > 0 then position += vein[i] * v end
		if taper then position = Vector3.new(position.X * taper[i], position.Y, position.Z) end
		mesh:SetPosition(ids[i], position)
		if normalIds then
			local normal = nbase[i] + ndelta[i] * gv
			if normal.Magnitude > 1e-6 then mesh:SetNormal(normalIds[i], normal.Unit) end
		end
	end
	group.applied[range] = g
	group.appliedOthers[range] = others
	group.appliedVein[range] = v
	group.appliedW[range] = w
	return range.count
end

local function applySnatched(self, group)
	local data, mesh, ids = group.snatchedData, group.mesh, group.vertexIds
	if not (data and mesh and ids) then return 0 end
	local w = waistProgress(self)
	for i = 1, #data.verts do
		local max = data.verts[i]
		local position = if data.start then data.start[i] + (max - data.start[i]) * w else max
		mesh:SetPosition(ids[i], position)
	end
	group.morphW = w
	return #data.verts
end

-- true when the group has something to write now
local function groupChanged(self, group): boolean
	local kind = group.def.kind
	if kind == "snatched" then return group.morphW ~= waistProgress(self) end
	if kind == "unified" then
		local piece = group.piece
		if group.taperChanged or waistProgress(self) ~= group.appliedW then return true end
		if piece.vein and veinOfPiece(self, piece) ~= group.appliedVein then return true end
		for _, muscle in ipairs(piece.muscleNames) do
			if math.abs(meshShown(self, muscle, muscle) - (group.appliedG[muscle] or 0)) > MIN_CHANGE then return true end
		end
		return false
	end
	for _, range in ipairs(group.data.ranges) do
		if rangeChanged(self, group, range) then return true end
	end
	return false
end

local function writeGroup(self, group): number
	local kind = group.def.kind
	if kind == "snatched" then return applySnatched(self, group) end
	if kind == "unified" then return applyUnified(self, group) end
	local used = 0
	for _, range in ipairs(group.data.ranges) do
		if rangeChanged(self, group, range) then used += applyRange(self, group, range) end
	end
	group.taperChanged = false
	return used
end

------------------------------------------------------------------------
-- Building one group's mesh
------------------------------------------------------------------------
local function newMesh(): any
	if alive >= limit then return nil end
	local okCreate, mesh = pcall(function() return AssetService:CreateEditableMesh() end)
	if not okCreate or not mesh then
		limit = alive
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

local function hideBody(self, body: BasePart, on: boolean)
	local count = (self.hidden[body] or 0) + (if on then 1 else -1)
	if count <= 0 then
		self.hidden[body] = nil
		if body.Parent then body.Transparency = 0 end
	else
		self.hidden[body] = count
		body.Transparency = 1
	end
end

-- Builds the EditableMesh of one group (returns true when built). Vertices go in at the biggest shape first (so the
-- MeshPart's bounds hold every growth), then the real shape is written.
local function buildGroup(self, state, group): boolean
	local def = group.def
	local body = self.model:FindFirstChild(def.part)
	if not body or not body:IsA("BasePart") then return false end
	local mesh = newMesh()
	if not mesh then return false end
	local calls, sliceStart = 0, os.clock()
	local function tick()
		calls += 1
		if calls % BUILD_CHECK == 0 and os.clock() - sliceStart > BUILD_MS then
			task.wait()
			sliceStart = os.clock()
		end
	end
	local white = Color3.new(1, 1, 1)
	group.taper = nil
	local ok, err = pcall(function()
		if def.kind == "unified" then
			local piece = MuscleMeshes.LoadPiece(def.mesh, def.half)
			group.piece = piece
			group.kindIndex = if def.part == "UpperTorso" then 3 else 1
			group.clothingKind = MuscleMeshes.ByName[def.mesh].clothing
			group.taper = frameTaper(self, def.part, piece.base)
			-- tint colors: each muscle's bands, and one for the vertices no muscle moves
			group.colorIds = {}
			for _, muscle in ipairs(piece.muscleNames) do
				local ids = {}
				for band = 0, MuscleMeshes.TintBands do ids[band] = mesh:AddColor(white, 1) end
				group.colorIds[muscle] = ids
			end
			group.baseColorId = mesh:AddColor(white, 1)
			-- the biggest shape: every muscle at its monster size, the wide waist, the veins
			local big = table.clone(piece.base)
			for _, muscle in ipairs(piece.muscleNames) do
				local m = piece.muscles[muscle]
				local g = MuscleMeshes.MonsterG(muscle) * (1 + MONSTER_EXTRA)
				for j, l in ipairs(m.idx) do big[l] += m.disp[j] * g end
			end
			local ids, uvIds, normalIds = table.create(piece.verts), table.create(piece.verts), table.create(piece.verts)
			for l = 1, piece.verts do
				local p = big[l]
				if piece.morph then p += piece.morph[l] end
				if piece.vein then p += piece.vein[l] end
				if group.taper then p = Vector3.new(p.X * group.taper[l], p.Y, p.Z) end
				ids[l] = mesh:AddVertex(p)
				uvIds[l] = mesh:AddUV(piece.uv[l])
				normalIds[l] = mesh:AddNormal(piece.nbase[l])
				tick()
			end
			local tris, dominant, band = piece.tris, piece.dominant, piece.band
			local function colorOf(l)
				local m = dominant[l]
				return if m then group.colorIds[m][band[l]] else group.baseColorId
			end
			for k = 1, #tris, 3 do
				local a, b, c = tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1
				local face = mesh:AddTriangle(ids[a], ids[b], ids[c])
				mesh:SetFaceUVs(face, { uvIds[a], uvIds[b], uvIds[c] })
				mesh:SetFaceNormals(face, { normalIds[a], normalIds[b], normalIds[c] })
				mesh:SetFaceColors(face, { colorOf(a), colorOf(b), colorOf(c) })
				tick()
			end
			group.vertexIds, group.normalIds = ids, normalIds
			group.acc, group.nacc = table.create(piece.verts, Vector3.zero), table.create(piece.verts, Vector3.zero)
			group.appliedG, group.dirty = {}, {}
			group.appliedW, group.appliedVein = nil, nil
		elseif def.kind == "snatched" then
			local data = MuscleMeshes.LoadSnatched(def.part)
			assert(data, "no snatched " .. def.part)
			group.snatchedData = data
			group.kindIndex, group.clothingKind = 2, "Pants"
			local ids, uvs, normals = {}, {}, {}
			for i = 1, #data.verts do
				ids[i] = mesh:AddVertex(if data.start then data.start[i] else data.verts[i])
				uvs[i] = mesh:AddUV(data.uv[i])
				if data.normals then normals[i] = mesh:AddNormal(data.normals[i]) end
			end
			local tris = data.tris
			for k = 1, #tris, 3 do
				local a, b, c = tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1
				local face = mesh:AddTriangle(ids[a], ids[b], ids[c])
				mesh:SetFaceUVs(face, { uvs[a], uvs[b], uvs[c] })
				if data.normals then mesh:SetFaceNormals(face, { normals[a], normals[b], normals[c] }) end
			end
			group.vertexIds, group.morphW = ids, nil
		else
			local data = MuscleMeshes.LoadGroup(def)
			group.data = data
			group.clothingKind = data.clothing
			group.kindIndex = 1
			group.taper = frameTaper(self, def.part, data.base)
			group.rangeColors, group.rangeKinds = {}, {}
			local rangeOf = table.create(data.verts)
			for _, range in ipairs(data.ranges) do
				local ids = {}
				for band = 0, MuscleMeshes.TintBands do ids[band] = mesh:AddColor(white, 1) end
				group.rangeColors[range] = ids
				group.rangeKinds[range] = if range.shorts then 2 elseif def.part == "UpperTorso" then 3 else 1
				for i = range.first, range.first + range.count - 1 do rangeOf[i] = ids end
			end
			local bands = data.bands
			local vertexIds, uvIds = table.create(data.verts), table.create(data.verts)
			local normalIds = if data.nbase then table.create(data.verts) else nil
			local buildG = table.create(data.verts)
			for _, range in ipairs(data.ranges) do
				local monster = MuscleMeshes.MonsterG(range.key) * (1 + MONSTER_EXTRA)
				for i = range.first, range.first + range.count - 1 do buildG[i] = monster end
			end
			for i = 1, data.verts do
				local built = data.base[i] + data.delta[i] * buildG[i]
				if data.morph and data.morph[i] then built += data.morph[i] end
				if group.taper then built = Vector3.new(built.X * group.taper[i], built.Y, built.Z) end
				vertexIds[i] = mesh:AddVertex(built)
				uvIds[i] = mesh:AddUV(data.uv[i])
				if normalIds then normalIds[i] = mesh:AddNormal((data.nbase[i] + data.ndelta[i]).Unit) end
				tick()
			end
			local tris = data.tris
			for f = 1, data.triCount do
				local a, b, c = tris[f * 3 - 2] + 1, tris[f * 3 - 1] + 1, tris[f * 3] + 1
				local face = mesh:AddTriangle(vertexIds[a], vertexIds[b], vertexIds[c])
				mesh:SetFaceUVs(face, { uvIds[a], uvIds[b], uvIds[c] })
				if normalIds then mesh:SetFaceNormals(face, { normalIds[a], normalIds[b], normalIds[c] }) end
				mesh:SetFaceColors(face, { rangeOf[a][bands[a] or 0], rangeOf[b][bands[b] or 0], rangeOf[c][bands[c] or 0] })
				tick()
			end
			group.vertexIds, group.normalIds = vertexIds, normalIds
			group.applied, group.appliedOthers, group.appliedVein, group.appliedW = {}, {}, {}, {}
		end
	end)
	if not ok then
		warn("[MuscleRig] couldn't build " .. def.part .. ": " .. tostring(err))
		dropMesh(mesh)
		return false
	end
	local okPart, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), MESH_PART_OPTIONS) end)
	if not okPart or not part or self.destroyed or not body.Parent or state.cancelled then
		dropMesh(mesh)
		if okPart and part then part:Destroy() end
		return false
	end
	group.mesh, group.body, group.part = mesh, body, part
	group.refSize = MuscleMeshes.Parts[def.part].size
	group.bodySize = body.Size
	-- the real shape, now
	if def.kind == "unified" then applyUnified(self, group, true) else writeGroup(self, group) end
	local ids = {}
	for muscle in pairs(state.unit.muscles) do table.insert(ids, muscle) end
	part:SetAttribute("MuscleName", table.concat(ids, ","))
	attach(self, part, body, def.part .. (if def.kind == "snatched" then "Snatched" elseif def.half then "Muscles" .. def.half else "Muscles"))
	meshOf[part] = mesh
	sizeParts(group)
	recolor(self, group)
	if def.kind ~= "shell" or def.hidePart then
		group.hides = body
		hideBody(self, body, true)
	end
	return true
end

local function destroyGroup(self, group)
	if group.hides then
		hideBody(self, group.hides, false)
		group.hides = nil
	end
	if group.mesh then dropMesh(group.mesh) end
	dropLayer(group)
	if group.cloth then
		meshOf[group.cloth] = nil
		group.cloth:Destroy()
	end
	if group.part then
		meshOf[group.part] = nil
		group.part:Destroy()
	end
	for key in pairs(group) do
		if key ~= "def" then group[key] = nil end
	end
end

local function destroyUnit(self, state)
	state.cancelled = true
	for _, group in ipairs(state.groups) do destroyGroup(self, group) end
	state.built = false
end

------------------------------------------------------------------------
-- Per-frame update of one rig
------------------------------------------------------------------------
local function wantedUnit(self, state): boolean
	local unit = state.unit
	if not isLive(self) then return false end
	-- (the forearm / calf meshes only when the stage meshes are missing: they don't fit in the client's 8 meshes)
	if unit.liveOnly and LimbStages.IsOn() then return false end
	if unit.alwaysWanted then return true end
	for id in pairs(unit.muscles) do
		if (self.target[id] or 0) >= MIN_SHOW or (self.current[id] or 0) >= MIN_SHOW then return true end
	end
	return false
end

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
		if want > amount then
			amount = math.min(want, amount + dt / TINT.HighlightIn)
		elseif want < amount then
			amount = math.max(want, amount - dt / TINT.HighlightOut)
		end
		if amount <= 0 and want == 0 then
			amounts[id] = nil
		else
			amounts[id] = amount
			if amount ~= want or want > 0 then live = true end
		end
	end
	-- training: fade in / out
	local want = if self.trainSet then 1 else 0
	if self.trainAmount < want then
		self.trainAmount = math.min(want, self.trainAmount + dt / TINT.TrainIn)
	elseif self.trainAmount > want then
		self.trainAmount = math.max(want, self.trainAmount - dt / TINT.TrainOut)
	end
	if self.trainAmount > 0 then live = true end
	if self.trainAmount <= 0 and not self.trainSet then self.trainWeights = nil end
	-- the rep pulse
	self.pulse = 0
	if self.pulseStart then
		local t = (os.clock() - self.pulseStart) / (self.pulseSlow or 1)
		if t < TINT.PulseUp then
			self.pulse = t / TINT.PulseUp
		elseif t < TINT.PulseUp + TINT.PulseDown then
			self.pulse = 1 - (t - TINT.PulseUp) / TINT.PulseDown
		else
			self.pulseStart = nil
		end
		self.pulse *= self.pulseStrength
		live = true
	end
	return live
end

-- a muscle's tint now: its color and strength (0 = none .. 1); the hover red wins over the training blue
local function tintOf(self, id: string, facing: number, clothed: boolean): (Color3, number)
	local cloth = if clothed then TINT.ClothScale else 1
	local h = self.highlightAmount[id] or 0
	if h > 0 and facing > 0 then return TINT.Highlight, h * TINT.Hover * facing * cloth end
	local w = self.trainWeights and self.trainWeights[id]
	if w and self.trainAmount > 0 then
		local p = self.pulse
		return TINT.Training:Lerp(TINT.TrainingBright, p), math.min(1, w * self.trainAmount * (1 + 0.5 * p)) * cloth
	end
	return TINT.Training, 0
end
local function tinted(self, id: string, base: Color3, facing: number, clothed: boolean): Color3
	local color, strength = tintOf(self, id, facing, clothed)
	return if strength > 0 then base:Lerp(color, strength) else base
end

local function facingOf(cf: CFrame, scale: Vector3, center: Vector3, normal: Vector3, cameraPosition: Vector3): number
	local at = cf:PointToWorldSpace(center * scale)
	local toCamera = cameraPosition - at
	local dot = if toCamera.Magnitude > 1e-4 then cf:VectorToWorldSpace(normal):Dot(toCamera.Unit) else 1
	return math.clamp((dot - TINT.FacingNone) / (TINT.FacingFull - TINT.FacingNone), 0, 1)
end

-- One muscle's tint bands: over an opaque base the color blends toward the tint; on the color layer (alpha 0) the tint's own
-- color shows with its strength as alpha (band 0 = none .. the top band = all of it).
-- EVERY change to an EditableMesh (positions, colors, any amount) costs the engine ~40 ms of a frame (measured 8 Oct, even a
-- 2,000 triangle mesh), so tints write the mesh as rarely as possible (tintGroup).
local function writeBands(mesh, ids, base: Color3, alpha: number, color: Color3, strength: number)
	local top = MuscleMeshes.TintBands
	pcall(function()
		for band = 0, top do
			local k = strength * band / top
			if alpha >= 1 then
				mesh:SetColor(ids[band], base:Lerp(color, k))
			else
				mesh:SetColor(ids[band], color)
				mesh:SetColorAlpha(ids[band], k)
			end
		end
	end)
end

-- The tints on the muscle meshes. Three ways, all cheap per frame (a mesh write is ~40 ms: only when WHAT is tinted changes):
--   * a skinned mesh (torso, arms; the thighs while tinted): its OPAQUE color layer, vertex colors = flat skin (and shorts)
--     blended toward the tint by each muscle's weight with a soft edge (bands), written when the tinted set changes (the
--     same machine all the time: once); the fade is the layer's Transparency (fully opaque once in, so it never vanishes
--     behind Glass), the rep pulse its Color (a multiplier: brighter, no write). The thighs' layer carries the gym shorts
--     (see-through skin) the rest of the time: tinted, it goes opaque at once.
--   * an unskinned mesh (under the character's own clothing, marble): its vertex colors, on / off (2 writes, no fade).
local function facingStep(f: number): number
	return if f >= 0.75 then 1 elseif f >= 0.25 then 0.5 else 0
end
local function restColor(c: Color3): Color3
	return Color3.new(math.min(c.R / TINT.Rest, 1), math.min(c.G / TINT.Rest, 1), math.min(c.B / TINT.Rest, 1))
end
local function tintGroup(self, group, cameraPosition: Vector3)
	local part, mesh = group.part, group.mesh
	if not (group.kindBase and part and mesh) then return end
	local cf = part.CFrame
	local meshSize = part.MeshSize
	local scale = if meshSize.Magnitude > 0 then part.Size / meshSize else Vector3.one
	local clothed = group.template ~= nil
	-- the muscles of this mesh: { key, id, color ids, kind, center, normal }
	local list = group.tintList
	if not list then
		list = {}
		if group.colorIds then
			for muscle, ids in pairs(group.colorIds) do
				local m = group.piece.muscles[muscle]
				table.insert(list, { muscle, muscle, ids, group.kindIndex or 1, m.center, m.normal })
			end
		elseif group.rangeColors then
			for _, range in ipairs(group.data.ranges) do
				table.insert(list, { range, range.id, group.rangeColors[range], group.rangeKinds[range], range.center, range.normal })
			end
		end
		group.tintList = list
	end
	local hovering = next(self.highlightAmount) ~= nil
	if group.skinned and group.layer then
		-- which muscles, how strong, which color
		local color, weights, opacity, any = TINT.Training, {}, 0, false
		local key = {}
		if hovering then
			color = TINT.Highlight
			table.insert(key, "H")
			for _, amount in pairs(self.highlightAmount) do opacity = math.max(opacity, amount) end
			for _, item in ipairs(list) do
				local w = 0
				if self.highlightSet and self.highlightSet[item[2]] then
					w = TINT.Hover * facingStep(facingOf(cf, scale, item[5], item[6], cameraPosition))
				end
				weights[item[1]] = w
				any = any or w > 0
				table.insert(key, tostring(w))
			end
		elseif self.trainWeights and self.trainAmount > 0 then
			table.insert(key, "T")
			opacity = self.trainAmount
			for _, item in ipairs(list) do
				local w = self.trainWeights[item[2]] or 0 -- (both sides of the body: no facing)
				weights[item[1]] = w
				any = any or w > 0
				table.insert(key, tostring(w))
			end
		end
		if not any then opacity = 0 end
		if opacity > 0 then
			local maskKey = table.concat(key, ",")
			if maskKey ~= group.maskKey then
				group.maskKey = maskKey
				local skin, shorts = colorsOf(self)
				pcall(function()
					local top = MuscleMeshes.TintBands
					for _, item in ipairs(list) do
						local ids, w = item[3], weights[item[1]]
						local base = if item[4] == 2 then shorts else skin:Lerp(Color3.new(0, 0, 0), 1 - TINT.SkinUnder)
						if item[4] == 2 then w = 0 end -- (the shorts stay shorts)
						for band = 0, top do
							mesh:SetColor(ids[band], restColor(base:Lerp(color, w * band / top)))
							mesh:SetColorAlpha(ids[band], 1)
						end
					end
				end)
			end
		elseif group.maskKey ~= nil then
			-- untinted again: the thighs get their shorts layer back (see-through skin); the torso / arms' layer just hides
			group.maskKey = nil
			if group.hasShorts then
				pcall(function()
					for _, item in ipairs(list) do
						writeBands(mesh, item[3], group.kindBase[item[4]], group.kindAlpha[item[4]], group.kindBase[item[4]], 0)
					end
				end)
			end
		end
		group.layerOpacity = opacity
		group.layerLive = opacity > 0
		-- (the thighs' layer is cloth for the shorts; tinted it is the whole skin surface)
		local material = if group.hasShorts and opacity <= 0 and not self.mirrorMode then Enum.Material.Fabric else Enum.Material.SmoothPlastic
		if group.layer.Material ~= material then group.layer.Material = material end
		-- the pulse: the layer's Color multiplies its vertex colors (written divided by TINT.Rest)
		local gray = if opacity > 0 then TINT.Rest + (1 - TINT.Rest) * self.pulse else 1
		local want = Color3.new(gray, gray, gray)
		if group.layer.Color ~= want then group.layer.Color = want end
		return
	end
	-- unskinned: the vertex colors, on / off
	local live = false
	for _, item in ipairs(list) do
		local key, id, ids, kind = item[1], item[2], item[3], item[4]
		local base, alpha = group.kindBase[kind], group.kindAlpha[kind]
		local color, strength = TINT.Training, 0
		if hovering then
			if self.highlightSet and self.highlightSet[id] and (self.highlightAmount[id] or 0) > 0.5 then
				color, strength = TINT.Highlight, TINT.Hover * facingStep(facingOf(cf, scale, item[5], item[6], cameraPosition)) * (if clothed then TINT.ClothScale else 1)
			end
		elseif self.trainWeights and self.trainWeights[id] and self.trainAmount > 0.5 then
			color, strength = TINT.Training, self.trainWeights[id] * (if clothed then TINT.ClothScale else 1)
		end
		strength = math.floor(strength * 16 + 0.5) / 16
		if strength > 0 then live = true end
		local shown = group.shownColors[key]
		if not shown or shown[1] ~= color or shown[2] ~= strength then
			group.shownColors[key] = { color, strength }
			writeBands(mesh, ids, base, alpha, color, strength)
		end
	end
	group.layerLive = live
end

-- Characters without muscle meshes (other players, NPCs on machines; your own visible body parts): the training tint on
-- the body parts that show the trained muscles, through their skin stage's Color (or the part's Color under clothing).
local function tintBody(self)
	local active = self.trainWeights and self.trainAmount > 0
	local wanted = {}
	if active then
		for id, w in pairs(self.trainWeights) do
			for _, name in ipairs(BODY_OF[id] or {}) do wanted[name] = math.max(wanted[name] or 0, w) end
		end
	end
	local skin = colorsOf(self)
	for name, w in pairs(wanted) do
		local part = self.model:FindFirstChild(name)
		if part and part:IsA("BasePart") and part.Transparency < 1 then
			local sa = part:FindFirstChild("SkinStage")
			local entry = self.bodyTint[part]
			if not entry then
				entry = { base = if sa then skin else part.Color }
				self.bodyTint[part] = entry
			end
			local color = entry.base:Lerp(TINT.Training:Lerp(TINT.TrainingBright, self.pulse), math.min(1, w * self.trainAmount * (1 + 0.5 * self.pulse)))
			if sa then
				if (sa :: any).Color ~= color then (sa :: any).Color = color end
			elseif part.Color ~= color then
				part.Color = color
			end
		end
	end
	for part, entry in pairs(self.bodyTint) do
		if not wanted[part.Name] then
			local sa = part:FindFirstChild("SkinStage")
			if sa then (sa :: any).Color = colorsOf(self) elseif part.Parent then part.Color = entry.base end
			self.bodyTint[part] = nil
		end
	end
end

local function step(self, dt: number)
	local now = os.clock()
	-- (idle bodies cost almost nothing: the vertex checks run only while something moves or changed, the rest at SLOW_HZ)
	local moving = false
	for id, target in pairs(self.target) do
		local t = (now - self.t0[id]) / TWEEN
		if t < 1 then
			self.current[id] = self.from[id] + (target - self.from[id]) * smooth(t)
			moving = true
		elseif self.current[id] ~= target then
			self.current[id] = target
			moving = true
		end
	end
	for id, started in pairs(self.pulses) do
		if now - started > (self.pulseTimes[id] or PULSE_TIME) then self.pulses[id] = nil end
		moving = true
	end
	local slowNow = now - (self.lastSlow or 0) >= 1 / SLOW_HZ
	if slowNow then self.lastSlow = now end
	-- the torso width changed (the frame, a Growth Spurt): every UpperTorso mesh gets the new taper
	local top, waist = self.taperTop or 1, self.taperWaist or 1
	if slowNow then top, waist = self.model:GetAttribute("FrameWidth"), self.model:GetAttribute("WaistWidth") end
	top = if type(top) == "number" then top else 1
	waist = if type(waist) == "number" then waist else 1
	if top ~= (self.taperTop or 1) or waist ~= (self.taperWaist or 1) then
		self.taperTop, self.taperWaist = top, waist
		for _, state in ipairs(self.units) do
			for _, group in ipairs(state.groups) do
				if group.def.part == "UpperTorso" and group.part then
					local positions = if group.piece then group.piece.base elseif group.data then group.data.base else nil
					if positions then
						group.taper = frameTaper(self, "UpperTorso", positions)
						group.taperChanged = true
					end
				end
			end
		end
		self.dirty = true
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
	-- mesh writes: at most UPDATE_HZ a second, only while something moves or changed, only for groups with something to write
	local writeNow = (moving or self.dirty) and now - self.lastWrite >= 1 / UPDATE_HZ
	local checkWrites = writeNow
	local wrote = false
	local pending = false -- (a unit that has something to write but waits for its turn)
	local units = self.units
	local first = ((self.writeCursor or 0) % #units) + 1
	for k = 0, #units - 1 do
		local index = (first + k - 1) % #units + 1
		local state = units[index]
		if slowNow then state.wanted = wantedUnit(self, state) end
		if state.built and (slowNow or writeNow) then
			-- an outfit change can swap the body parts: build again on the new ones
			local stale = false
			for _, group in ipairs(state.groups) do
				if not group.body or group.body.Parent ~= self.model then stale = true end
			end
			if stale then
				destroyUnit(self, state)
				continue
			end
			for _, group in ipairs(state.groups) do
				local body = group.body
				if not (group.part and group.part.Parent and body and body.Parent) then continue end
				local hidden = self.covered and self.covered[body.Name] == true or false
				local want = if hidden then 1 else 0
				if group.part.Transparency ~= want then
					group.part.Transparency = want
					if group.cloth then group.cloth.Transparency = if hidden then 1 else CLOTH_TRANSPARENCY end
					if group.hides then body.Transparency = if hidden then 0 else 1 end
				end
				-- the color layer only draws while it has something to show (the shorts, or a tint)
				if group.layer then
					local opacity = group.layerOpacity or 0
					local layerT = if hidden or not (group.hasShorts or opacity > 0 or os.clock() < (group.layerHoldUntil or 0)) then 1
						elseif opacity > 0 and group.hasShorts then 0
						elseif group.hasShorts then LAYER_TRANSPARENCY
						elseif opacity > 0 then (if opacity >= 0.999 then 0 else 1 - opacity)
							else LAYER_IDLE
					if group.layer.Transparency ~= layerT then group.layer.Transparency = layerT end
				end
				if group.mesh and writeNow and groupChanged(self, group) then
					if wrote and not state.writing then
						pending = true -- (another unit wrote this frame: next frame)
					else
						state.writing = true
						writeGroup(self, group)
						wrote = true
						self.writeCursor = index
					end
				end
				if body.Size ~= group.bodySize then
					group.bodySize = body.Size
					sizeParts(group)
				end
				if self.static and group.part.CFrame ~= body.CFrame then
					group.part.CFrame = body.CFrame
					if group.cloth then group.cloth.CFrame = body.CFrame end
				end
			end
		end
	end
	for _, state in ipairs(units) do state.writing = nil end
	-- (a unit still waiting writes next frame, not after the UPDATE_HZ gap)
	if wrote and not pending then self.lastWrite = now end
	-- nothing moved and nothing was left to write: quiet until the next change
	if checkWrites and not wrote and not pending and not moving then self.dirty = false end
	-- tints: while one shows, and once more after the last one to put the colors back
	local tintLive = updateTintState(self, dt)
	if self.limbs and (moving or self.dirty or tintLive or self.tintWasLive or slowNow) then
		self.limbs:Update(function(id, key) return meshShown(self, key, id) end, {
			skin = (self.style and self.style.skin) or nil, shirt = templateFor(self, "Shirt"), pants = templateFor(self, "Pants"),
		}, function(id, base)
			return tinted(self, id, base, 1, templateFor(self, if id == "Calves" then "Pants" else "Shirt") ~= nil)
		end, self.covered, self.marble)
		for _, child in ipairs(self.folder:GetChildren()) do
			local sa = child:IsA("MeshPart") and child:FindFirstChild("SkinStage")
			if sa and string.sub(child.Name, -5) == "Stage" and (sa :: any).Color ~= child.Color then (sa :: any).Color = child.Color end
		end
	end
	-- (every frame while a tint shows: the fade is the color layer's Transparency, the mesh changes only with the mask)
	if tintLive or self.tintWasLive then
		tintBody(self)
		local camera = workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		for _, state in ipairs(self.units) do
			if state.built then
				for _, group in ipairs(state.groups) do
					tintGroup(self, group, cameraPosition)
					-- (the color layer shows at once when a tint starts, and goes away with it)
					if group.layer and group.body then
						local hidden = self.covered and self.covered[group.body.Name] == true
						local opacity = group.layerOpacity or 0
						local layerT = if hidden or not (group.hasShorts or group.layerLive) then 1
							elseif opacity > 0 and group.hasShorts then 0
							elseif group.hasShorts then LAYER_TRANSPARENCY
							elseif opacity > 0 then (if opacity >= 0.999 then 0 else 1 - opacity)
							else LAYER_IDLE
						if group.layer.Transparency ~= layerT then group.layer.Transparency = layerT end
					end
				end
			end
		end
	end
	self.tintWasLive = tintLive
	-- the skin texture stage (and its color) when the look moved into another stage or the style changed
	if not self.marble and (now - (self.skinCheckedAt or 0) > 0.5 or self.skinStage == nil) then
		self.skinCheckedAt = now
		local index = SkinStages.Pick(overallLook(self), self.skinStage)
		if index ~= self.skinStage or colorsOf(self) ~= self.skinColor or self.skinParts ~= #self.folder:GetChildren() then
			skinPass(self)
			self.skinParts = #self.folder:GetChildren()
		end
	end
	-- the game's gym shorts on the thighs, unless the character wears its own Pants (or layered clothing on the legs)
	if slowNow and not self.keepBody and not self.marble then
		local legsCovered = self.covered and self.covered.RightUpperLeg
		local legsBuilt = false
		for _, state in ipairs(self.units) do
			if state.unit.id == "UpperLegs" and state.built then legsBuilt = true end
		end
		updateGarments(self, templateFor(self, "Pants") == nil and not legsCovered and not legsBuilt)
	end
end

------------------------------------------------------------------------
-- The allocator: which units get a mesh, most important first
------------------------------------------------------------------------
local function allocate()
	if limit == 0 and os.clock() >= limitResetAt then limit = math.huge end
	local jobs = {}
	for rig in pairs(active) do
		if not rig.destroyed and rig.model.Parent then
			for index, state in ipairs(rig.units) do
				if state.wanted or state.built then
					local rank = OWN_ORDER[state.unit.id] or (10 + index)
					local order
					if rig.priority >= 200 then
						order = 200000 - rank
					elseif rig.priority >= 100 then
						order = 100000 - rank
					else
						order = rig.priority * 10 - rank * 100
					end
					table.insert(jobs, { rig = rig, state = state, order = order, cost = state.unit.cost })
				end
			end
		end
	end
	table.sort(jobs, function(a, b) return a.order > b.order end)
	local budget = limit - building
	for _, job in ipairs(jobs) do
		local state = job.state
		local backoff = not state.built and (state.failedAt or 0) > os.clock()
		job.keep = state.wanted and (state.built or not backoff) and budget >= job.cost
		if job.keep then budget -= job.cost end
	end
	for _, job in ipairs(jobs) do
		if job.state.built and not job.keep then destroyUnit(job.rig, job.state) end
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
						if not buildGroup(rig, state, group) then
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
					for _, group in ipairs(state.groups) do destroyGroup(rig, group) end
					state.built = false
					state.failedAt = os.clock() + 3
				end
				state.building = false
				building -= 1
				lastAllocate = 0
				rig.skinStage = nil
				rig.dirty = true
			end)
			if building >= MAX_BUILDS then return end
		end
	end
end

function MuscleRig.Destroy(self)
	self.destroyed = true
	active[self] = nil
	for _, state in ipairs(self.units) do destroyUnit(self, state) end
	if self.limbs then self.limbs:Destroy() end
	for body in pairs(self.hidden) do
		if body.Parent then body.Transparency = 0 end
	end
	table.clear(self.hidden)
	for _, name in ipairs(BODY_PARTS) do
		local part = self.model:FindFirstChild(name)
		local sa = part and part:FindFirstChild("SkinStage")
		if sa then sa:Destroy() end
	end
	for _, name in ipairs({ "Head", "UpperTorso", "LowerTorso" }) do
		local part = self.model:FindFirstChild(name)
		local sa = part and part:FindFirstChild("SkinStage")
		if sa then sa:Destroy() end
	end
	if self.folder then self.folder:Destroy() end
end

-- Mirror mode (the progress mirror, while its reflection is live): opaque vertex colors on the skinned meshes, so the
-- mirror's copies of them draw solid (see recolor). One color write per mesh when it switches.
function MuscleRig.SetMirrorMode(model: Model, on: boolean)
	for rig in pairs(active) do
		if rig.model == model and (rig.mirrorMode == true) ~= on then
			rig.mirrorMode = on
			rig.dirty = true
			for _, state in ipairs(rig.units) do
				for _, group in ipairs(state.groups) do recolor(rig, group) end
			end
		end
	end
end

function MuscleRig.SetHighlight(model: Model, set: { [string]: boolean }?)
	for rig in pairs(active) do
		if rig.model == model then rig.highlightSet = set end
	end
end

-- The training tint (TINT): the muscles a machine trains, { [muscle id] = share } (the first / biggest = main), while
-- this character is on it; nil when they get off. Works on every rig: your muscle meshes, the forearm / calf stages and,
-- on characters without muscle meshes, the body parts.
local trainingOf = setmetatable({}, { __mode = "k" }) -- [model] = weights (a rig made later picks it up)
function MuscleRig.SetTraining(model: Model, shares: { [string]: number }?)
	local weights = nil
	if shares then
		local top = 0
		for _, share in pairs(shares) do top = math.max(top, share) end
		weights = {}
		for id, share in pairs(shares) do
			weights[id] = if share >= top then TINT.TrainMain else TINT.TrainHelper
		end
	end
	trainingOf[model] = weights
	for rig in pairs(active) do
		if rig.model == model then
			rig.trainSet = weights
			if weights then rig.trainWeights = weights end
		end
	end
end
function MuscleRig.TrainingOf(model: Model): any
	return trainingOf[model]
end

-- The rep pulse on top of the training tint (the trained muscles brighten ~0.2 s). `weights` is kept for the callers
-- (the body map uses the same table); `big` = BIG REP / PUMPED, a stronger pulse.
-- Studio test hook: Workspace attribute "TestFlashSlow" = n stretches the pulse n times (for screenshots).
function MuscleRig.Flash(model: Model, weights: { [string]: number }?, big: boolean?)
	for rig in pairs(active) do
		if rig.model == model then
			local slow = if RunService:IsStudio() then workspace:GetAttribute("TestFlashSlow") else nil
			slow = if type(slow) == "number" and slow > 0 then slow else 1
			rig.pulseStart = os.clock()
			rig.pulseSlow = slow
			rig.pulseStrength = if big then TINT.BigPulse else TINT.PulseStrength
		end
	end
end

function MuscleRig.PulseModel(model: Model, ids: { string }, amount: number?)
	for rig in pairs(active) do
		if rig.model == model then rig:Pulse(ids, amount) end
	end
end

-- true when every unit this rig wants has its meshes
function MuscleRig.IsReady(self): boolean
	for _, state in ipairs(self.units) do
		if not state.built and wantedUnit(self, state) then return false end
	end
	return true
end

-- The live EditableMesh behind a muscle MeshPart (nil if it is not one). A second MeshPart made with
-- AssetService:CreateMeshPartAsync(Content.fromObject(mesh), MESH_PART_OPTIONS) shows the same, always up-to-date shape.
function MuscleRig.MeshOf(part: Instance): any
	return meshOf[part]
end

-- how many EditableMeshes this client holds / may hold
function MuscleRig.Budget(): (number, number)
	return alive, limit
end

-- Forearms and calves are the static stage meshes for everyone (the meshes only when the stages are missing).
local function ensureLimbs(rig)
	local want = LimbStages.IsOn()
	if want and not rig.limbs then
		rig.limbs = LimbStages.new(rig.model, rig.folder, rig.static)
	elseif not want and rig.limbs then
		rig.limbs:Destroy()
		rig.limbs = nil
	end
end

RunService.RenderStepped:Connect(function(dt)
	for rig in pairs(active) do
		if rig.model.Parent then
			ensureLimbs(rig)
			step(rig, dt)
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
	local shirt = model:FindFirstChildOfClass("Shirt")
	local pants = model:FindFirstChildOfClass("Pants")
	return {
		skin = skin,
		shorts = Body.ShortsColor(source:GetAttribute("Shorts")),
		top = if shirt and shirt.ShirtTemplate ~= "" then nil else Body.TopColor(source:GetAttribute("Top")),
		shirt = if shirt and shirt.ShirtTemplate ~= "" then shirt.ShirtTemplate else nil,
		pants = if pants and pants.PantsTemplate ~= "" then pants.PantsTemplate else nil,
	}
end

return MuscleRig
