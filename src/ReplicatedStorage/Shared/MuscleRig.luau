-- MuscleRig: muscle v7 on one character / rig (client side; every client builds the muscles of every character it can see).
--
-- Each muscle's outline stays on the skin and only the bulge rises (EditableMesh, SetPosition: vertex = base + (max - base) * g,
-- g = the muscle's level over its max level). The mesh data is in part-local studs (origin = the body part's position), so a
-- muscle mesh is welded to its body part at CFrame.new().
--
-- LIMITS the code works around (measured in Studio: a client may hold only 8 EditableMeshes at once, a mesh holds at most 20,000
-- triangles; SurfaceAppearance would ignore vertex colors):
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

local MuscleMeshes = require(script.Parent.MuscleMeshes)
local Muscles = require(script.Parent.Config.Muscles)
local Body = require(script.Parent.Config.Body)

local MuscleRig = {}
MuscleRig.__index = MuscleRig

local VERTEX_BUDGET = 6000 -- vertex updates per frame, for all rigs together
local BUILD_YIELD = 3000   -- API calls between yields while building one mesh
local MIN_SHOW = 0.02      -- below this growth a muscle is hidden inside the body
local TWEEN = 0.4          -- seconds a growth change takes
local PUMPED = 1.04
local PUMP_STEP = 0.03     -- the small pulse
local PULSE_TIME = 0.55
local MIN_CHANGE = 0.0015
local MARBLE = Color3.fromHex("#C9C6BF")
local HIGHLIGHT = Color3.fromRGB(255, 30, 70) -- the stats hover highlight (neon red)
local REALLOCATE_EVERY = 0.4

local active: { [any]: boolean } = {}
local meshOf = setmetatable({}, { __mode = "k" }) -- [muscle MeshPart] = its EditableMesh (so a mirror can show the same live mesh)

-- Allocator state: how many EditableMeshes are alive, and the most this client allows (learned when a create fails).
local alive = 0
local limit = math.huge
local building = false
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

local function recolor(self, group)
	local mesh = group.mesh
	if not mesh or not group.colors then return end
	local skin, shorts, top = colorsOf(self)
	pcall(function()
		mesh:SetColor(group.colors[1], skin)
		mesh:SetColor(group.colors[2], shorts)
		mesh:SetColor(group.colors[3], top)
	end)
	if group.part then
		group.part.Color = self.marble and MARBLE or Color3.new(1, 1, 1)
		if self.marble then group.part.Material = Enum.Material.Marble end
	end
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

function MuscleRig.Pulse(self, ids: { string })
	local now = os.clock()
	for _, id in ipairs(ids) do self.pulses[id] = now end
end

function MuscleRig.SetPumped(self, pumped: boolean)
	self.pumped = pumped
end

------------------------------------------------------------------------
-- Building one group's mesh (an EditableMesh with the merged muscles of one body part)
------------------------------------------------------------------------
local function groupScale(group): Vector3
	local ref = group.refSize
	local size = group.body.Size
	return Vector3.new(size.X / ref.X, size.Y / ref.Y, size.Z / ref.Z)
end

local function currentShown(self, id: string): number
	local g = self.current[id] or 0
	local pulseStart = self.pulses[id]
	local pulse = 1
	if pulseStart then
		local t = (os.clock() - pulseStart) / PULSE_TIME
		if t < 1 then pulse = 1 + PUMP_STEP * math.sin(t * math.pi) end
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

-- Returns true when the group was built.
local function buildGroup(self, state, group): boolean
	local model = self.model
	local body = model:FindFirstChild(group.def.part)
	if not body or not body:IsA("BasePart") then return false end
	local data = MuscleMeshes.LoadGroup(group.def)
	if alive >= limit then return false end
	local okCreate, mesh = pcall(function() return AssetService:CreateEditableMesh() end)
	if not okCreate or not mesh then
		-- the client's budget is used up: remember how many fit and let the allocator rearrange
		limit = math.max(alive, 0)
		return false
	end
	alive += 1
	local calls = 0
	local function tick()
		calls += 1
		if calls % BUILD_YIELD == 0 then task.wait() end
	end
	local ok, err = pcall(function()
		local skinId, shortsId, topId = mesh:AddColor(Color3.new(1, 1, 1), 1), mesh:AddColor(Color3.new(1, 1, 1), 1), mesh:AddColor(Color3.new(1, 1, 1), 1)
		local glowId = mesh:AddColor(HIGHLIGHT, 1)
		group.colors = { skinId, shortsId, topId }
		group.glowId = glowId
		group.faceIds = table.create(data.triCount)
		local vertexIds = table.create(data.verts)
		for i = 1, data.verts do
			-- built in the MAX shape (the biggest bounds); the real growth is applied below
			vertexIds[i] = mesh:AddVertex(data.base[i] + data.delta[i])
			tick()
		end
		local tris, kinds = data.tris, data.faceKind
		local kindColor = { skinId, shortsId, topId }
		for f = 1, data.triCount do
			local a, b, c = tris[f * 3 - 2] + 1, tris[f * 3 - 1] + 1, tris[f * 3] + 1
			local face = mesh:AddTriangle(vertexIds[a], vertexIds[b], vertexIds[c])
			group.faceIds[f] = face
			local color = kindColor[kinds[f]]
			mesh:SetFaceColors(face, { color, color, color })
			tick()
		end
		group.vertexIds = vertexIds
	end)
	if not ok then
		warn("[MuscleRig] couldn't build " .. group.def.part .. ": " .. tostring(err))
		alive -= 1
		pcall(function() mesh:Destroy() end)
		return false
	end
	local okPart, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh)) end)
	if not okPart or not part or self.destroyed or not body.Parent or state.cancelled then
		alive -= 1
		pcall(function() mesh:Destroy() end)
		if okPart and part then part:Destroy() end
		return false
	end
	group.mesh, group.data, group.body, group.part = mesh, data, body, part
	group.refSize = MuscleMeshes.Parts[group.def.part].size
	part.Name = group.def.part .. "Muscles"
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.Massless = true
	part.Anchored = self.static
	part.Material = self.marble and Enum.Material.Marble or Enum.Material.Plastic
	part.Color = self.marble and MARBLE or Color3.new(1, 1, 1)
	part.Size = part.MeshSize * groupScale(group)
	group.bodySize = body.Size
	part.CFrame = body.CFrame
	if not self.static then
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = body, part
		weld.C0 = CFrame.new()
		weld.Parent = part
	end
	-- the muscle ids this merged mesh holds (the stats highlight outlines the whole group's mesh)
	local ids = {}
	for _, range in ipairs(data.ranges) do table.insert(ids, range.id) end
	part:SetAttribute("MuscleName", table.concat(ids, ","))
	meshOf[part] = mesh
	part.Parent = self.folder
	recolor(self, group)
	-- start every muscle at its current growth
	for _, range in ipairs(data.ranges) do applyRange(group, range, currentShown(self, range.id)) end
	return true
end

local function destroyGroup(group)
	if group.mesh then
		alive = math.max(alive - 1, 0)
		pcall(function() group.mesh:Destroy() end)
	end
	if group.part then group.part:Destroy() end
	group.mesh, group.part, group.data, group.vertexIds, group.colors, group.body = nil, nil, nil, nil, nil, nil
	group.applied = {}
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
	local legsBuilt = false
	for _, state in ipairs(self.units) do
		state.wanted = wantedUnit(self, state)
		if state.built then
			if state.unit.id == "UpperLegs" then legsBuilt = true end
			for _, group in ipairs(state.groups) do
				local body = group.body
				if not (group.part and group.part.Parent and body and body.Parent) then continue end
				-- apply the muscles that changed (within the frame budget)
				for _, range in ipairs(group.data.ranges) do
					local shown = currentShown(self, range.id)
					local last = group.applied[range]
					if (last == nil or math.abs(shown - last) > MIN_CHANGE) and (budget - used > 0 or used == 0) then
						applyRange(group, range, shown)
						used += range.count
					end
				end
				if body.Size ~= group.bodySize then
					group.bodySize = body.Size
					group.part.Size = group.part.MeshSize * groupScale(group)
				end
				if self.static then group.part.CFrame = body.CFrame end
			end
		end
	end
	-- simple shorts unless the leg meshes are there
	if not self.keepBody and not self.marble then updateGarments(self, true) end
	return used
end

------------------------------------------------------------------------
-- The allocator: which units get a mesh, most important first
------------------------------------------------------------------------
local function allocate()
	-- every wanted unit of every rig, most important first
	local jobs = {}
	for rig in pairs(active) do
		if not rig.destroyed and rig.model.Parent then
			for index, state in ipairs(rig.units) do
				if state.wanted or state.built then
					-- my own character gets its torso, arms, legs and back first; then every nearby character's chest/abs unit (so a crowd
				-- shows something instead of one body hogging the budget), then the rest by distance
				local order
				if rig.priority >= 200 then
					order = 200000 - index
				elseif rig.priority >= 100 and index <= 4 then
					order = 100000 - index
				elseif index == 1 then
					order = 50000 + rig.priority
				else
					order = rig.priority * 10 - index * 500
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
		local want = state.wanted and budget >= state.unit.cost
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
	if building then return end
	for _, job in ipairs(jobs) do
		local state, rig = job.state, job.rig
		if job.keep and not state.built and not state.building and not rig.destroyed and (state.failedAt or 0) < os.clock() then
			building = true
			state.building = true
			state.cancelled = false
			task.spawn(function()
				local allBuilt = true
				for _, group in ipairs(state.groups) do
					if not buildGroup(rig, state, group) then allBuilt = false break end
				end
				if allBuilt and not state.cancelled then
					state.built = true
				else
					for _, group in ipairs(state.groups) do destroyGroup(group) end
					state.built = false
					state.failedAt = os.clock() + 3 -- try again a little later (the budget may have changed)
				end
				state.building = false
				building = false
			end)
			return
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
function MuscleRig.SetHighlight(model: Model, set: { [string]: boolean }?)
	for rig in pairs(active) do
		if rig.model == model then
			for _, state in ipairs(rig.units) do
				for _, group in ipairs(state.groups) do
					if group.mesh and group.faceIds then
						local skin, shorts, top = colorsOf(rig)
						pcall(function()
							for _, range in ipairs(group.data.ranges) do
								local lit = set ~= nil and set[range.id] == true
								if lit ~= (group.lit and group.lit[range] or false) then
									group.lit = group.lit or {}
									group.lit[range] = lit
									local normal = if range.shorts then group.colors[2] elseif range.id and group.def.part == "UpperTorso" then group.colors[3] else group.colors[1]
									local color = lit and group.glowId or normal
									for f = range.triFirst, range.triFirst + range.triCount - 1 do
										group.mesh:SetFaceColors(group.faceIds[f], { color, color, color })
									end
								end
							end
						end)
					end
				end
			end
		end
	end
end

-- The live EditableMesh behind a muscle MeshPart (nil if it is not one). A second MeshPart made with
-- AssetService:CreateMeshPartAsync(Content.fromObject(mesh)) shows the same, always up-to-date shape without using another
-- of the client's few EditableMeshes (the glass reflection does this).
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
	return {
		skin = skin,
		shorts = Body.ShortsColor(source:GetAttribute("Shorts")),
		top = Body.TopColor(source:GetAttribute("Top")),
	}
end

return MuscleRig
