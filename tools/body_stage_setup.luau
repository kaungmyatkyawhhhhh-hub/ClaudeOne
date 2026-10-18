-- body_stage_setup (19 Oct, prompts 4, 7, 8: traps yoke, round delts, full back, adductors): run in Studio (Edit mode) AFTER
-- importing the 48 fixed stage OBJs (Downloads/gym_arc_meshes_lowpoly_backfix/other_player_stages: torso, upper arms and thighs,
-- made by tools/quad_fix_lowpoly.py from tools/reshape_stage_corrections; the g000 stages didn't change) with File > Import 3D
-- into the Workspace. Each template in ReplicatedStorage.BodyStages takes its imported mesh (ApplyMesh) and new size, the
-- imported copy is deleted; returns 'name old new' lines for Config/StageMeshBackup. Then run tools/quad_fix_patch_config.py
-- with that folder's bounds.json and push Config/BodyStages.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the fixed meshes' bounding-box sizes (part-local studs, from bounds.json)
local SIZES = {
	BS_LeftArm_Arm_g020 = Vector3.new(0.7019, 1.0643, 0.8645),
	BS_LeftArm_Arm_g040 = Vector3.new(0.7372, 1.0929, 0.9378),
	BS_LeftArm_Arm_g060 = Vector3.new(0.7964, 1.1347, 1.0245),
	BS_LeftArm_Arm_g080 = Vector3.new(0.8692, 1.1806, 1.1159),
	BS_LeftArm_Arm_g100 = Vector3.new(0.9449, 1.2302, 1.2063),
	BS_LeftArm_Arm_gmon = Vector3.new(1.3393, 1.4520, 1.8408),
	BS_LeftLeg_Shorts_g020 = Vector3.new(0.7390, 0.5196, 0.8729),
	BS_LeftLeg_Shorts_g040 = Vector3.new(0.7643, 0.5236, 0.9033),
	BS_LeftLeg_Shorts_g060 = Vector3.new(0.7903, 0.5277, 0.9398),
	BS_LeftLeg_Shorts_g080 = Vector3.new(0.8238, 0.5317, 0.9788),
	BS_LeftLeg_Shorts_g100 = Vector3.new(0.8628, 0.5358, 1.0220),
	BS_LeftLeg_Shorts_gmon = Vector3.new(1.1629, 0.5578, 1.2764),
	BS_LeftLeg_Skin_g020 = Vector3.new(0.7782, 0.7733, 0.8569),
	BS_LeftLeg_Skin_g040 = Vector3.new(0.8561, 0.7760, 0.9222),
	BS_LeftLeg_Skin_g060 = Vector3.new(0.9412, 0.7786, 0.9923),
	BS_LeftLeg_Skin_g080 = Vector3.new(1.0261, 0.7813, 1.0666),
	BS_LeftLeg_Skin_g100 = Vector3.new(1.1098, 0.7840, 1.1376),
	BS_LeftLeg_Skin_gmon = Vector3.new(1.7164, 0.8047, 1.6104),
	BS_RightArm_Arm_g020 = Vector3.new(0.6981, 1.0649, 0.8629),
	BS_RightArm_Arm_g040 = Vector3.new(0.7369, 1.0940, 0.9320),
	BS_RightArm_Arm_g060 = Vector3.new(0.8028, 1.1351, 1.0182),
	BS_RightArm_Arm_g080 = Vector3.new(0.8789, 1.1808, 1.1040),
	BS_RightArm_Arm_g100 = Vector3.new(0.9532, 1.2303, 1.1899),
	BS_RightArm_Arm_gmon = Vector3.new(1.3433, 1.4519, 1.7937),
	BS_RightLeg_Shorts_g020 = Vector3.new(0.7390, 0.5196, 0.8723),
	BS_RightLeg_Shorts_g040 = Vector3.new(0.7644, 0.5237, 0.9046),
	BS_RightLeg_Shorts_g060 = Vector3.new(0.7908, 0.5277, 0.9397),
	BS_RightLeg_Shorts_g080 = Vector3.new(0.8238, 0.5317, 0.9799),
	BS_RightLeg_Shorts_g100 = Vector3.new(0.8628, 0.5358, 1.0228),
	BS_RightLeg_Shorts_gmon = Vector3.new(1.1262, 0.5574, 1.2752),
	BS_RightLeg_Skin_g020 = Vector3.new(0.7801, 0.7733, 0.8589),
	BS_RightLeg_Skin_g040 = Vector3.new(0.8599, 0.7760, 0.9233),
	BS_RightLeg_Skin_g060 = Vector3.new(0.9368, 0.7787, 0.9953),
	BS_RightLeg_Skin_g080 = Vector3.new(1.0233, 0.7814, 1.0626),
	BS_RightLeg_Skin_g100 = Vector3.new(1.1133, 0.7841, 1.1341),
	BS_RightLeg_Skin_gmon = Vector3.new(1.6935, 0.8129, 1.6599),
	BS_Torso_Back_g020 = Vector3.new(2.1547, 1.8450, 0.6489),
	BS_Torso_Back_g040 = Vector3.new(2.2899, 1.8970, 0.6759),
	BS_Torso_Back_g060 = Vector3.new(2.4204, 1.9490, 0.7075),
	BS_Torso_Back_g080 = Vector3.new(2.5519, 2.0010, 0.7501),
	BS_Torso_Back_g100 = Vector3.new(2.6943, 2.0530, 0.7936),
	BS_Torso_Back_gmon = Vector3.new(3.0462, 2.1985, 1.1731),
	BS_Torso_Front_g020 = Vector3.new(2.1228, 1.8337, 0.6116),
	BS_Torso_Front_g040 = Vector3.new(2.2246, 1.8605, 0.6604),
	BS_Torso_Front_g060 = Vector3.new(2.3236, 1.8955, 0.7152),
	BS_Torso_Front_g080 = Vector3.new(2.4254, 1.9305, 0.7727),
	BS_Torso_Front_g100 = Vector3.new(2.5356, 1.9656, 0.8311),
	BS_Torso_Front_gmon = Vector3.new(2.8127, 2.0676, 1.0322),
}

local templates = ReplicatedStorage:WaitForChild("BodyStages")
local found, lines, missing = {}, {}, {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("MeshPart") then
		local name = if SIZES[d.Name] then d.Name elseif d.Parent and SIZES[d.Parent.Name] then d.Parent.Name else nil
		if name and not found[name] then found[name] = d end
	end
end
for name, size in pairs(SIZES) do
	local imported, template = found[name], templates:FindFirstChild(name)
	if not imported or not template then
		table.insert(missing, name)
		continue
	end
	local old = template.MeshId
	template:ApplyMesh(imported)
	template.Size = size
	table.insert(lines, name .. " " .. old .. " " .. template.MeshId)
	local holder = if imported.Parent and imported.Parent ~= workspace and imported.Parent:IsA("Model") then imported.Parent else imported
	holder:Destroy()
end
table.sort(lines)
return table.concat(lines, "\n") .. (if #missing > 0 then "\nMISSING: " .. table.concat(missing, ", ") else "")
