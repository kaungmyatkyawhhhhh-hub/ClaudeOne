-- BodyShape: how big a body looks from its muscle levels. Used by BodyService (everyone's character), MirrorService
-- (the before/after rigs) and the "you grew" moment, so all three always agree.
-- Growth comes in clear steps, not tiny invisible increments: each group grows one step every 1/Steps of the way to
-- the next Growth Spurt goal. A Growth Spurt resets the muscles (and so the size) and keeps the height.
--   * whole body: wider and deeper (Humanoid width/depth scales) from the average step of all 6 groups
--   * per group: its own parts get thicker (chest/back = torso, arms, legs...), on top of that
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Muscles = require(Config.Muscles)
local GrowthSpurts = require(Config.GrowthSpurts)

local BodyShape = {}

BodyShape.Steps = 5            -- visible size steps per Growth Spurt (step 0 .. Steps)
BodyShape.MaxGrowth = 0.42     -- extra part thickness at the top step (times each part's weight below)
BodyShape.Bulk = { Width = 0.25, Depth = 0.3 } -- whole-body width/depth added at the top average step
BodyShape.BaseHeight = 60      -- inches that equal a height scale of 1

-- Which parts each group thickens, as (width X, depth Z) weights.
BodyShape.GroupParts = {
	Chest = { UpperTorso = Vector2.new(0.35, 0.9) },
	Back = { UpperTorso = Vector2.new(0.8, 0.35) },
	Shoulders = { UpperTorso = Vector2.new(0.3, 0), RightUpperArm = Vector2.new(0.6, 0.6), LeftUpperArm = Vector2.new(0.6, 0.6) },
	Arms = {
		RightUpperArm = Vector2.new(1, 1), LeftUpperArm = Vector2.new(1, 1),
		RightLowerArm = Vector2.new(0.8, 0.8), LeftLowerArm = Vector2.new(0.8, 0.8),
	},
	Legs = {
		RightUpperLeg = Vector2.new(1, 1), LeftUpperLeg = Vector2.new(1, 1),
		RightLowerLeg = Vector2.new(0.8, 0.8), LeftLowerLeg = Vector2.new(0.8, 0.8),
	},
	Core = { LowerTorso = Vector2.new(0.9, 0.8) },
}

-- { [groupId] = step 0..Steps } from data (muscles + growthSpurts): the top step at the next Growth Spurt goal.
function BodyShape.GroupSteps(data)
	local cap = GrowthSpurts.GetGoal(data.growthSpurts or 0)
	local steps = {}
	for _, group in ipairs(Muscles.Groups) do
		local share = math.clamp(Muscles.GetGroupLevel(data.muscles, group.id) / cap, 0, 1)
		steps[group.id] = math.floor(share * BodyShape.Steps + 1e-6)
	end
	return steps
end

-- Whole-body width and depth multipliers (1 = no growth).
function BodyShape.BulkScales(steps)
	local total, count = 0, 0
	for _, step in pairs(steps) do
		total += step
		count += 1
	end
	local share = count > 0 and total / (count * BodyShape.Steps) or 0
	-- whole steps only, so the body changes in visible jumps
	share = math.floor(share * BodyShape.Steps + 1e-6) / BodyShape.Steps
	return 1 + BodyShape.Bulk.Width * share, 1 + BodyShape.Bulk.Depth * share
end

-- { [partName] = Vector2(width, depth) } thickness multipliers per body part.
function BodyShape.PartScales(steps)
	local scales = {}
	for groupId, parts in pairs(BodyShape.GroupParts) do
		local growth = BodyShape.MaxGrowth * (steps[groupId] or 0) / BodyShape.Steps
		for partName, weight in pairs(parts) do
			scales[partName] = (scales[partName] or Vector2.new(1, 1)) + weight * growth
		end
	end
	return scales
end

local PART_NAMES = {}
for _, parts in pairs(BodyShape.GroupParts) do
	for name in pairs(parts) do PART_NAMES[name] = true end
end

local function scaleOffset(cframe, sx, sz)
	local p = cframe.Position
	return CFrame.new(p.X * sx, p.Y, p.Z * sz) * cframe.Rotation
end

-- Remember an R15 model's unthickened sizes, joint offsets and attachment positions (call after any height/width
-- rescale has settled). Returns a body record for Apply.
function BodyShape.Capture(model)
	local body = { model = model, parts = {}, joints = {}, attachments = {}, applied = {} }
	for name in pairs(PART_NAMES) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			body.parts[part] = part.Size
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Attachment") then body.attachments[child] = child.CFrame end
			end
		end
	end
	for _, motor in ipairs(model:GetDescendants()) do
		if motor:IsA("Motor6D") then body.joints[motor] = { C0 = motor.C0, C1 = motor.C1 } end
	end
	return body
end

-- Thicken the captured parts to `scales` (BodyShape.PartScales), moving joints and attachments with them so limbs
-- and accessories stay connected. Returns true if anything changed.
function BodyShape.Apply(body, scales)
	local changed = false
	for part, original in pairs(body.parts) do
		local s = scales[part.Name] or Vector2.new(1, 1)
		local last = body.applied[part]
		if not last or (last - s).Magnitude > 0.004 then
			body.applied[part] = s
			changed = true
			part.Size = Vector3.new(original.X * s.X, original.Y, original.Z * s.Y)
			for attachment, cframe in pairs(body.attachments) do
				if attachment.Parent == part then attachment.CFrame = scaleOffset(cframe, s.X, s.Y) end
			end
		end
	end
	if changed then
		for motor, original in pairs(body.joints) do
			if motor.Parent then
				local s0 = body.applied[motor.Part0] or Vector2.new(1, 1)
				local s1 = body.applied[motor.Part1] or Vector2.new(1, 1)
				motor.C0 = scaleOffset(original.C0, s0.X, s0.Y)
				motor.C1 = scaleOffset(original.C1, s1.X, s1.Y)
			end
		end
	end
	return changed
end

-- Older rigs (and BuildRigFromAttachments) join the body with Motor6Ds; newer avatars and rigs from
-- Players:CreateHumanoidModelFromDescription use AnimationConstraints between the rig attachments instead. Both have a
-- Transform, so poses work the same way. This builds Motor6Ds only for an old-style rig that has neither yet.
function BodyShape.EnsureJoints(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and not model:FindFirstChildWhichIsA("Motor6D", true) and not model:FindFirstChildWhichIsA("AnimationConstraint", true) then
		pcall(function() humanoid:BuildRigFromAttachments() end)
	end
end

-- A joint as { part0, part1, offset0, offset1, transform } (part1 = part0 * offset0 * transform * offset1:Inverse()),
-- for Motor6Ds/Welds and for attachment-based constraints (AnimationConstraint, RigidConstraint).
local function jointInfo(joint)
	if (joint:IsA("Motor6D") or joint:IsA("Weld")) and joint.Part0 and joint.Part1 then
		return joint.Part0, joint.Part1, joint.C0, joint.C1, joint:IsA("Motor6D") and joint.Transform or CFrame.identity
	end
	if joint:IsA("AnimationConstraint") or joint:IsA("RigidConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		local p0, p1 = a0 and a0.Parent, a1 and a1.Parent
		if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
			return p0, p1, a0.CFrame, a1.CFrame, joint:IsA("AnimationConstraint") and joint.Transform or CFrame.identity
		end
	end
	return nil
end

-- Place every part of a rig from its joints, starting at the HumanoidRootPart (for rigs that are anchored as a
-- whole, e.g. statues and preview rigs, where physics never solves the joints). Uses each joint's Transform, so set a
-- pose first. Accessory welds/constraints are followed too.
function BodyShape.SolveJoints(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return end
	BodyShape.EnsureJoints(model)
	local joints = {}
	for _, joint in ipairs(model:GetDescendants()) do
		local p0, p1, c0, c1, transform = jointInfo(joint)
		if p0 then table.insert(joints, { p0, p1, c0, c1, transform }) end
	end
	local placed = { [root] = true }
	local progress = true
	while progress do
		progress = false
		for _, j in ipairs(joints) do
			local p0, p1, c0, c1, transform = j[1], j[2], j[3], j[4], j[5]
			if placed[p0] and not placed[p1] then
				p1.CFrame = p0.CFrame * c0 * transform * c1:Inverse()
				placed[p1] = true
				progress = true
			elseif placed[p1] and not placed[p0] then
				p0.CFrame = p1.CFrame * c1 * transform:Inverse() * c0:Inverse()
				placed[p0] = true
				progress = true
			end
		end
	end
end

return BodyShape
