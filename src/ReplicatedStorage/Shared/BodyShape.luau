-- BodyShape: body helpers shared by BodyService (characters), MirrorService (the before/after rigs) and the statue.
-- The muscles are EditableMesh muscles (MuscleRig, MuscleClient); this module only holds the height base and
-- the joint helpers for rigs that are anchored as a whole (statue, preview rigs), the golden ratio proportions and the
-- body widths.
local Body = require(script.Parent.Config.Body)

local BodyShape = {}

BodyShape.BaseHeight = 60      -- inches that equal a height scale of 1

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
	-- accessories whose joint isn't there (Roblox rebuilds them a moment after a body part is swapped): place each
	-- handle on the body attachment with the same name as one of its own attachments
	for _, accessory in ipairs(model:GetChildren()) do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") and not placed[handle] then
			for _, own in ipairs(handle:GetChildren()) do
				if own:IsA("Attachment") then
					local target = nil
					for _, part in ipairs(model:GetChildren()) do
						local found = part:IsA("BasePart") and part:FindFirstChild(own.Name)
						if found and found:IsA("Attachment") then target = found break end
					end
					if target then
						handle.CFrame = target.WorldCFrame * own.CFrame:Inverse()
						break
					end
				end
			end
		end
	end
end

-- One Y value of an instance remapped once: the value we set is remembered (attribute <key>Y, the original in <key>BaseY).
-- If the current value is no longer the one we set, Roblox rebuilt it (a rescale / a new description): it is the new base.
-- Returns base, new when it was (re)applied now; nil when it is already done.
local function remapY(target: Instance, key: string, current: number, map: (number) -> number): (number?, number?)
	local done = target:GetAttribute(key .. "Y")
	if type(done) == "number" and math.abs(current - done) < 1e-4 then return nil, nil end
	local new = map(current)
	target:SetAttribute(key .. "BaseY", current)
	target:SetAttribute(key .. "Y", new)
	return current, new
end

-- The Y an attachment had before the proportions (its base, or the current value if not applied yet).
local function baseY(attachment: Instance?): number
	if not attachment or not attachment:IsA("Attachment") then return 0 end
	local base = attachment:GetAttribute("PropBaseY")
	local done = attachment:GetAttribute("PropY")
	if type(base) == "number" and type(done) == "number" and math.abs(attachment.Position.Y - done) < 1e-4 then return base end
	return attachment.Position.Y
end

-- Reshape one body part in height: its size and every attachment on it (rig joints and accessories) through `map`
-- (part-local Y -> new Y). Returns whether its size was (re)applied now, and whether anything was.
local function reshape(part: BasePart, sizeMap: (number) -> number, map: (number) -> number): (boolean, boolean)
	local base = remapY(part, "Prop", part.Size.Y, sizeMap)
	if base then part.Size = Vector3.new(part.Size.X, part:GetAttribute("PropY"), part.Size.Z) end
	local any = base ~= nil
	for _, attachment in ipairs(part:GetChildren()) do
		if attachment:IsA("Attachment") then
			local _, y = remapY(attachment, "Prop", attachment.Position.Y, map)
			if y then
				attachment.Position = Vector3.new(attachment.Position.X, y, attachment.Position.Z)
				any = true
			end
		end
	end
	return base ~= nil, any
end

-- Golden ratio proportions (Config.Body.Proportions) on an R15 Robloxian rig: legs and the LowerTorso below the navel
-- taller, the rest of the torso up to the neck shorter, the same total height. Safe to call again (only re-applies what
-- Roblox rebuilt). Joints follow the moved attachments (Motor6D C0/C1 are synced too); when the legs were reshaped now, the
-- Humanoid's HipHeight grows by what the legs gained, so the feet stay on the floor. solve = place every part from its
-- joints afterwards (rigs that aren't simulated: anchored NPCs, statue, preview rigs). Returns the HipHeight change.
function BodyShape.ApplyProportions(model: Model, solve: boolean?): number
	local P = Body.Proportions
	local lower, upper = model:FindFirstChild("LowerTorso"), model:FindFirstChild("UpperTorso")
	if not (lower and lower:IsA("BasePart") and upper and upper:IsA("BasePart")) then return 0 end
	local function times(k: number) return function(y: number) return y * k end end

	-- the LowerTorso: below the navel stretched, above it shrunk (its mesh takes the overall new height)
	local lowerDone = lower:GetAttribute("PropY")
	local h = if type(lowerDone) == "number" and math.abs(lower.Size.Y - lowerDone) < 1e-4 then lower:GetAttribute("PropBaseY") else lower.Size.Y
	local bottom = -h / 2
	local navel = math.min(bottom + P.Navel * h / P.LowerTorsoRef, h / 2)
	local newH = (navel - bottom) * P.Stretch + (h / 2 - navel) * P.Shrink
	local function lowerMap(y: number): number
		local up = if y <= navel then (y - bottom) * P.Stretch else (navel - bottom) * P.Stretch + (y - navel) * P.Shrink
		return -newH / 2 + up
	end
	-- (the leg chain below the root, before: for the HipHeight change)
	local rightUpper, rightLower = model:FindFirstChild("RightUpperLeg"), model:FindFirstChild("RightLowerLeg")
	local rootY, hipY = baseY(lower:FindFirstChild("RootRigAttachment")), baseY(lower:FindFirstChild("RightHipRigAttachment"))
	local thigh = rightUpper and (baseY(rightUpper:FindFirstChild("RightHipRigAttachment")) - baseY(rightUpper:FindFirstChild("RightKneeRigAttachment"))) or 0
	local shin = rightLower and (baseY(rightLower:FindFirstChild("RightKneeRigAttachment")) - baseY(rightLower:FindFirstChild("RightAnkleRigAttachment"))) or 0

	local _, lowerAny = reshape(lower, function() return newH end, lowerMap)
	local _, upperAny = reshape(upper, times(P.Shrink), times(P.Shrink))
	local changed, legsNow = lowerAny or upperAny, false
	for _, name in ipairs({ "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local sizeNow, any = reshape(part, times(P.Stretch), times(P.Stretch))
			changed = changed or any
			if sizeNow and name == "RightUpperLeg" then legsNow = true end
		end
	end
	if not changed then return 0 end

	-- Motor6D rigs place parts from C0/C1, not the attachments
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local a0 = joint.Part0:FindFirstChild(joint.Name .. "RigAttachment")
			local a1 = joint.Part1:FindFirstChild(joint.Name .. "RigAttachment")
			if a0 and a0:IsA("Attachment") then joint.C0 = a0.CFrame end
			if a1 and a1:IsA("Attachment") then joint.C1 = a1.CFrame end
		end
	end

	local delta = 0
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if legsNow then
		delta = (lowerMap(rootY) - lowerMap(hipY)) - (rootY - hipY) + (thigh + shin) * (P.Stretch - 1)
		if humanoid then humanoid.HipHeight += delta end
	end
	if solve then BodyShape.SolveJoints(model) end
	return delta
end

-- One X or Z value scaled by a factor that can change over time: the original is remembered (<key>Base) with the value we
-- set (<key>). If the current value is no longer ours, Roblox rebuilt it and it is the new original. Returns the new value,
-- or nil when nothing changes.
local function scaleAxis(target: Instance, key: string, current: number, factor: number): number?
	local base, set = target:GetAttribute(key .. "Base"), target:GetAttribute(key)
	local ours = type(base) == "number" and type(set) == "number" and math.abs(current - set) < 1e-4
	if not ours then base = current end
	local new = (base :: number) * factor
	if ours and math.abs(new - current) < 1e-5 then return nil end
	target:SetAttribute(key .. "Base", base)
	target:SetAttribute(key, new)
	return new
end

-- Widen one body part and every attachment on it (X and Z).
local function widenPart(part: BasePart, fx: number, fz: number): boolean
	local changed = false
	local x = scaleAxis(part, "WidX", part.Size.X, fx)
	local z = scaleAxis(part, "WidZ", part.Size.Z, fz)
	if x or z then
		part.Size = Vector3.new(x or part.Size.X, part.Size.Y, z or part.Size.Z)
		changed = true
	end
	for _, attachment in ipairs(part:GetChildren()) do
		if attachment:IsA("Attachment") then
			local p = attachment.Position
			local ax = scaleAxis(attachment, "WidX", p.X, fx)
			local az = scaleAxis(attachment, "WidZ", p.Z, fz)
			if ax or az then
				attachment.Position = Vector3.new(ax or p.X, p.Y, az or p.Z)
				changed = true
			end
		end
	end
	return changed
end

-- Body widths (Config.Body.Widths, computed by BodyService.WidthFactors): factors = { shoulders (the UpperTorso width, frame
-- included), hips (LowerTorso), arms, legs (limb width and thickness), depth (the torso front to back) }. Safe to call every
-- second: only what changed (or Roblox rebuilt) is touched; Motor6D rigs get their joints synced.
function BodyShape.ApplyWidths(model: Model, factors: { [string]: number })
	local changed = false
	local function widen(name: string, fx: number, fz: number)
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") and widenPart(part, fx, fz) then changed = true end
	end
	widen("UpperTorso", factors.shoulders, factors.depth)
	widen("LowerTorso", factors.hips, factors.depth)
	for _, side in ipairs({ "Right", "Left" }) do
		widen(side .. "UpperArm", factors.arms, factors.arms)
		widen(side .. "LowerArm", factors.arms, factors.arms)
		widen(side .. "UpperLeg", factors.legs, factors.legs)
		widen(side .. "LowerLeg", factors.legs, factors.legs)
	end
	if not changed then return end
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local a0 = joint.Part0:FindFirstChild(joint.Name .. "RigAttachment")
			local a1 = joint.Part1:FindFirstChild(joint.Name .. "RigAttachment")
			if a0 and a0:IsA("Attachment") then joint.C0 = a0.CFrame end
			if a1 and a1:IsA("Attachment") then joint.C1 = a1.CFrame end
		end
	end
end

return BodyShape
