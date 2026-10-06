--!strict
-- BodyThickness: gradual, per-body-part muscle growth for any R15 rig (players, mirror rigs, statue, NPCs).
--  * Every R15 part grows its THICKNESS (X and Z, never its length) from the levels of its own muscles. Level 0 = the
--    avatar exactly as it is; every level-up adds a little (an ease-out curve, no steps or tiers).
--  * Part.Size, the attachments on that part (rig and accessory attachments) and the joints that use them are scaled
--    together from the ORIGINAL sizes (captured once, never compounded), so nothing gaps, floats or overlaps, and hats,
--    hair and accessories stay attached. Works on any avatar (blocky, rounded, layered clothing).
--  * Controller:Set tweens to new targets (the server batches a whole rig into one update ~20 times a second while
--    it moves); Controller:Pulse is the small pump on every 10th level. Controller:Restore puts the originals back
--    (used before a height change: Roblox rescales parts from its own original sizes).
local RunService = game:GetService("RunService")

local BodyThickness = {}

-- Biggest extra thickness at the Growth Spurt goal (0.45 = +45%).
local ARM_LEG = 0.45
local HAND = 0.30
local TORSO_WIDTH, TORSO_DEPTH = 0.40, 0.35
local WAIST_WIDTH, WAIST_DEPTH = 0.10, 0.14
local PUMP = 0.03          -- every 10th level: grow 3%, then settle
local EASE_POWER = 2       -- ease-out: 1 - (1 - t)^2
local STEP_EVERY = 1 / 20  -- seconds between rig updates while moving

-- Which part groups each muscle feeds (for the pump pulse).
BodyThickness.MusclePartKinds = {
	UpperChest = { "UpperTorso" }, MidChest = { "UpperTorso" }, Lats = { "UpperTorso" }, Traps = { "UpperTorso" },
	Rhomboids = { "UpperTorso" }, LowerBack = { "UpperTorso" }, SideDelts = { "UpperTorso" },
	FrontDelts = { "UpperTorso" },
	Abs = { "LowerTorso" }, Obliques = { "LowerTorso" },
	Biceps = { "UpperArm" }, Triceps = { "UpperArm" }, RearDelts = { "UpperArm" },
	Forearms = { "LowerArm", "Hand" },
	Quads = { "UpperLeg" }, Hamstrings = { "UpperLeg" }, Glutes = { "UpperLeg" },
	Calves = { "LowerLeg" },
}

local SIDES = { "Left", "Right" }

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ EASE_POWER
end

-- Parts a muscle's pulse grows, with both sides ("UpperArm" -> LeftUpperArm, RightUpperArm).
function BodyThickness.PulseParts(muscleId: string): { string }
	local out = {}
	for _, kind in ipairs(BodyThickness.MusclePartKinds[muscleId] or {}) do
		if kind == "UpperTorso" or kind == "LowerTorso" then
			table.insert(out, kind)
		else
			for _, side in ipairs(SIDES) do table.insert(out, side .. kind) end
		end
	end
	return out
end

-- Average of the muscles' progress toward the goal (each 0..1).
local function score(levels: { [string]: number }, ids: { string }, goal: number): number
	local total = 0
	for _, id in ipairs(ids) do total += math.clamp((levels[id] or 0) / goal, 0, 1) end
	return total / #ids
end

-- Per-part targets { [partName] = { x = widthFactor, z = depthFactor } } from the muscle levels
-- ({ [muscleId] = level }) and the Growth Spurt goal level.
function BodyThickness.Targets(levels: { [string]: number }, goal: number): { [string]: { x: number, z: number } }
	goal = math.max(goal, 1)
	local out = {}
	local torso = score(levels, { "UpperChest", "MidChest", "Lats", "Traps", "Rhomboids", "LowerBack" }, goal)
	local delts = score(levels, { "SideDelts", "FrontDelts" }, goal)
	local core = score(levels, { "Abs", "Obliques" }, goal)
	-- side delts widen the top of the body: they count a quarter toward the width
	out.UpperTorso = { x = 1 + TORSO_WIDTH * ease(torso * 0.75 + delts * 0.25), z = 1 + TORSO_DEPTH * ease(torso) }
	out.LowerTorso = { x = 1 + WAIST_WIDTH * ease(core), z = 1 + WAIST_DEPTH * ease(core) }
	local arm = ease(score(levels, { "Biceps", "Triceps", "RearDelts" }, goal))
	local fore = ease(score(levels, { "Forearms" }, goal))
	local thigh = ease(score(levels, { "Quads", "Hamstrings", "Glutes" }, goal))
	local calf = ease(score(levels, { "Calves" }, goal))
	for _, side in ipairs(SIDES) do
		out[side .. "UpperArm"] = { x = 1 + ARM_LEG * arm, z = 1 + ARM_LEG * arm }
		out[side .. "LowerArm"] = { x = 1 + ARM_LEG * fore, z = 1 + ARM_LEG * fore }
		out[side .. "Hand"] = { x = 1 + HAND * fore, z = 1 + HAND * fore }
		out[side .. "UpperLeg"] = { x = 1 + ARM_LEG * thigh, z = 1 + ARM_LEG * thigh }
		out[side .. "LowerLeg"] = { x = 1 + ARM_LEG * calf, z = 1 + ARM_LEG * calf }
	end
	return out
end

-- The same level for every muscle (NPC presets and the statue): level = share of the goal (0..1).
function BodyThickness.Uniform(share: number): { [string]: { x: number, z: number } }
	local levels = {}
	for id in pairs(BodyThickness.MusclePartKinds) do levels[id] = share * 1000 end
	return BodyThickness.Targets(levels, 1000)
end

------------------------------------------------------------------------
-- Controller: one per rig
------------------------------------------------------------------------
type Factor = { x: number, z: number }
type Base = { part: BasePart, size: Vector3, atts: { { att: Attachment, cf: CFrame } } }
type Controller = {
	model: Model,
	base: { [string]: Base },
	joints: { { joint: JointInstance, a0: Attachment, a1: Attachment, partName: string } },
	cur: { [string]: Factor },
	from: { [string]: Factor },
	to: { [string]: Factor },
	startTime: number,
	duration: number,
	pulses: { [string]: number }, -- partName -> start time of its pulse
	conn: RBXScriptConnection?,
	lastStep: number,
}

local Controller: any = {}
Controller.__index = Controller

type JointInstance = Motor6D | Weld

local function scaledPartNames(): { string }
	local names = { "UpperTorso", "LowerTorso" }
	for _, side in ipairs(SIDES) do
		for _, kind in ipairs({ "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg" }) do table.insert(names, side .. kind) end
	end
	return names
end
local PART_NAMES = scaledPartNames()

-- Remember the rig's current sizes and attachment positions as "normal" (call when the rig is at its normal
-- thickness: after the height has settled). Also finds the joints and accessory welds that follow those attachments.
function Controller.Capture(self: Controller)
	self.base = {}
	for _, name in ipairs(PART_NAMES) do
		local part = self.model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local atts = {}
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Attachment") then table.insert(atts, { att = child, cf = child.CFrame }) end
			end
			self.base[name] = { part = part, size = part.Size, atts = atts }
			if not self.cur[name] then self.cur[name] = { x = 1, z = 1 } end
		end
	end
	self.joints = {}
	for _, item in ipairs(self.model:GetDescendants()) do
		if item:IsA("Motor6D") and item.Part0 and item.Part1 then
			local a0 = item.Part0:FindFirstChild(item.Name .. "RigAttachment")
			local a1 = item.Part1:FindFirstChild(item.Name .. "RigAttachment")
			if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") and (self.base[item.Part0.Name] or self.base[item.Part1.Name]) then
				table.insert(self.joints, { joint = item, a0 = a0, a1 = a1, partName = item.Part0.Name })
			end
		elseif item:IsA("Weld") and item.Part0 and item.Part1 and self.base[item.Part0.Name] then
			-- an accessory: its handle attachment matches an attachment on the body part
			for _, own in ipairs(item.Part1:GetChildren()) do
				local target = if own:IsA("Attachment") then item.Part0:FindFirstChild(own.Name) else nil
				if target and target:IsA("Attachment") and own:IsA("Attachment") then
					table.insert(self.joints, { joint = item, a0 = target, a1 = own, partName = item.Part0.Name })
					break
				end
			end
		end
	end
end

local function pulseAmount(self: Controller, name: string, now: number): number
	local started = self.pulses[name]
	if not started then return 0 end
	local t = now - started
	if t < 0.15 then return t / 0.15 end
	if t < 0.55 then return 1 - (t - 0.15) / 0.4 end
	self.pulses[name] = nil
	return 0
end

-- Apply the current factors (plus any pump) to the rig.
local function render(self: Controller)
	local now = os.clock()
	local hipSpread = 1
	do
		local leg = self.cur.LeftUpperLeg
		hipSpread = leg and leg.x or 1
	end
	for name, info in pairs(self.base) do
		local factor = self.cur[name] or { x = 1, z = 1 }
		local pump = 1 + PUMP * pulseAmount(self, name, now)
		local fx, fz = factor.x * pump, factor.z * pump
		info.part.Size = Vector3.new(info.size.X * fx, info.size.Y, info.size.Z * fz)
		for _, entry in ipairs(info.atts) do
			local pos = entry.cf.Position
			local ax = fx
			-- the hips sit further apart on a wider waist so thick thighs don't overlap
			if name == "LowerTorso" and string.find(entry.att.Name, "Hip", 1, true) then ax = math.max(fx, hipSpread) end
			entry.att.CFrame = entry.cf - pos + Vector3.new(pos.X * ax, pos.Y, pos.Z * fz)
		end
	end
	for _, item in ipairs(self.joints) do
		local joint: any = item.joint
		joint.C0 = item.a0.CFrame
		joint.C1 = item.a1.CFrame
	end
end

local function lerpFactor(a: Factor, b: Factor, t: number): Factor
	return { x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t }
end

local function stop(self: Controller)
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
end

local function step(self: Controller)
	local now = os.clock()
	if now - self.lastStep < STEP_EVERY then return end
	self.lastStep = now
	if not self.model.Parent then
		stop(self)
		return
	end
	local t = self.duration > 0 and math.clamp((now - self.startTime) / self.duration, 0, 1) or 1
	-- a smooth ease-in-out so each level-up eases in and out
	local eased = t * t * (3 - 2 * t)
	for name, target in pairs(self.to) do
		self.cur[name] = lerpFactor(self.from[name] or target, target, eased)
	end
	render(self)
	if t >= 1 and next(self.pulses) == nil then stop(self) end
end

local function run(self: Controller)
	if not self.conn then
		self.lastStep = 0
		self.conn = RunService.Heartbeat:Connect(function() step(self) end)
	end
end

-- Tween to new targets (nil entries = normal) over `duration` seconds (0 = right now).
function Controller.Set(self: Controller, targets: { [string]: Factor }?, duration: number)
	self.from, self.to = {}, {}
	for name in pairs(self.base) do
		local current = self.cur[name] or { x = 1, z = 1 }
		self.from[name] = { x = current.x, z = current.z }
		local target = targets and targets[name] or { x = 1, z = 1 }
		self.to[name] = { x = target.x, z = target.z }
	end
	self.startTime = os.clock()
	self.duration = duration
	if duration <= 0 then
		for name, target in pairs(self.to) do self.cur[name] = { x = target.x, z = target.z } end
		render(self)
	else
		run(self)
	end
end

-- The small pump: the part grows a little, then settles.
function Controller.Pulse(self: Controller, partNames: { string })
	local now = os.clock()
	for _, name in ipairs(partNames) do
		if self.base[name] then self.pulses[name] = now end
	end
	run(self)
end

-- Put the rig's original sizes, attachments and joints back and forget the factors.
function Controller.Restore(self: Controller)
	stop(self)
	self.pulses = {}
	for name in pairs(self.cur) do self.cur[name] = { x = 1, z = 1 } end
	self.from, self.to = {}, {}
	render(self)
end

function Controller.Destroy(self: Controller)
	stop(self)
end

function BodyThickness.New(model: Model): any
	local self = setmetatable({
		model = model, base = {}, joints = {}, cur = {}, from = {}, to = {}, startTime = 0, duration = 0,
		pulses = {}, conn = nil, lastStep = 0,
	}, Controller) :: any
	self:Capture()
	return self
end

-- One-shot for rigs that never change (mirror rigs, statue, NPC presets): capture and apply right away.
function BodyThickness.Snap(model: Model, targets: { [string]: Factor }?)
	local controller: any = BodyThickness.New(model)
	controller:Set(targets, 0)
	controller:Destroy()
end

return BodyThickness
