-- shoulder_fix_stage_setup (19 Oct, owner's prompts "upper traps missing" + "wide traps and round shoulders"): run in
-- Studio (Edit mode) AFTER importing the 24 fixed torso + upper arm stage OBJs (Downloads\gym_arc_meshes_lowpoly_shoulderfix
-- \other_player_stages, made by tools/quad_fix_lowpoly.py from tools/reshape_stage_corrections; the g000 stages didn't change)
-- with File > Import 3D into the Workspace. Same steps as tools/quad_fix_stage_setup: each template in
-- ReplicatedStorage.BodyStages takes its imported mesh (ApplyMesh) and new size, the imported copy is deleted; returns
-- "name old new" lines for Config/StageMeshBackup. Then run tools/quad_fix_patch_config.py with that folder's bounds.json
-- and push Config/BodyStages.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the fixed meshes' bounding-box sizes (part-local studs, from bounds.json)
local SIZES = {
	BS_LeftArm_Arm_g020 = Vector3.new(0.7091, 1.0674, 0.8913),
	BS_LeftArm_Arm_g040 = Vector3.new(0.7756, 1.1155, 1.0209),
	BS_LeftArm_Arm_g060 = Vector3.new(0.8523, 1.1699, 1.1544),
	BS_LeftArm_Arm_g080 = Vector3.new(0.9314, 1.2275, 1.2848),
	BS_LeftArm_Arm_g100 = Vector3.new(1.0148, 1.2902, 1.4216),
	BS_LeftArm_Arm_gmon = Vector3.new(1.4584, 1.5595, 2.2107),
	BS_RightArm_Arm_g020 = Vector3.new(0.7069, 1.0673, 0.8888),
	BS_RightArm_Arm_g040 = Vector3.new(0.7708, 1.1147, 1.0165),
	BS_RightArm_Arm_g060 = Vector3.new(0.8508, 1.1705, 1.1466),
	BS_RightArm_Arm_g080 = Vector3.new(0.9314, 1.2278, 1.2770),
	BS_RightArm_Arm_g100 = Vector3.new(1.0168, 1.2903, 1.4047),
	BS_RightArm_Arm_gmon = Vector3.new(1.5105, 1.5594, 2.1673),
	BS_Torso_Back_g020 = Vector3.new(2.1547, 1.8450, 0.6489),
	BS_Torso_Back_g040 = Vector3.new(2.2899, 1.8970, 0.6759),
	BS_Torso_Back_g060 = Vector3.new(2.4204, 1.9490, 0.7075),
	BS_Torso_Back_g080 = Vector3.new(2.5519, 2.0010, 0.7501),
	BS_Torso_Back_g100 = Vector3.new(2.6943, 2.0530, 0.7936),
	BS_Torso_Back_gmon = Vector3.new(3.0462, 2.1985, 1.1731),
	BS_Torso_Front_g020 = Vector3.new(2.1228, 1.8364, 0.6131),
	BS_Torso_Front_g040 = Vector3.new(2.2246, 1.8705, 0.6635),
	BS_Torso_Front_g060 = Vector3.new(2.3236, 1.9105, 0.7198),
	BS_Torso_Front_g080 = Vector3.new(2.4254, 1.9505, 0.7789),
	BS_Torso_Front_g100 = Vector3.new(2.5356, 1.9905, 0.8387),
	BS_Torso_Front_gmon = Vector3.new(2.8127, 2.1053, 1.0438),
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
