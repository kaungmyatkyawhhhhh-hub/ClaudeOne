-- PoseApply: puts a PoseData pose on a model's joints once (statue, progress mirror rigs). The live game uses
-- PoseController (blends every character that has the "Pose" attribute); this is the same math for rigs that are anchored
-- as a whole: set the Transforms, then BodyShape.SolveJoints places the parts.
local PoseApply = {}

-- Rotation about the joint in the PARENT part's axes -> into the joint's C0 frame (same as PoseController).
local function poseCFrame(joint, angles)
	local q = joint.C0.Rotation
	return q:Inverse() * CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3])) * q
end

-- pose = a PoseData entry ({ JointName = {x, y, z} degrees }), w = 0..1 how far into the pose.
function PoseApply.Apply(model: Model, pose: { [string]: { number } }, w: number?)
	local amount = w or 1
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then
			local angles = pose[joint.Name]
			if angles then joint.Transform = CFrame.identity:Lerp(poseCFrame(joint, angles), amount) end
		end
	end
end

-- Back to rest.
function PoseApply.Clear(model: Model)
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") or joint:IsA("AnimationConstraint") then joint.Transform = CFrame.identity end
	end
end

return PoseApply
