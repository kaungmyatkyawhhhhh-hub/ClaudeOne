-- BodyShape: body helpers shared by BodyService (characters), MirrorService (the before/after rigs) and the statue.
-- The muscles are EditableMesh muscles (MuscleRig, MuscleClient); this module only holds the height base and
-- the joint helpers for rigs that are anchored as a whole (statue, preview rigs).
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

return BodyShape
