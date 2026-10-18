-- quad_fix_stage_setup (19 Oct, owner's bug "inner quad bulge"): run in Studio (Edit mode) AFTER importing the 24 fixed
-- thigh stage OBJs (Downloads\gym_arc_meshes_lowpoly_quadfix\other_player_stages, made by tools/quad_fix_lowpoly.py; the
-- g000 stages didn't change) with File > Import 3D into the Workspace. For each imported mesh: the template in
-- ReplicatedStorage.BodyStages takes its mesh (ApplyMesh: a script can't write MeshId) and its new bounding-box size,
-- then the imported copy is deleted. Returns "name old new" lines for Config/StageMeshBackup. Also run
-- tools/quad_fix_patch_config.py (the new centres / sizes in Config/BodyStages) and push that file.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the fixed meshes' bounding-box sizes (part-local studs, from bounds.json)
local SIZES = {
	BS_LeftLeg_Shorts_g020 = Vector3.new(0.7391, 0.5196, 0.8729),
	BS_LeftLeg_Shorts_g040 = Vector3.new(0.7643, 0.5236, 0.9033),
	BS_LeftLeg_Shorts_g060 = Vector3.new(0.7903, 0.5277, 0.9398),
	BS_LeftLeg_Shorts_g080 = Vector3.new(0.8238, 0.5317, 0.9788),
	BS_LeftLeg_Shorts_g100 = Vector3.new(0.8628, 0.5358, 1.0220),
	BS_LeftLeg_Shorts_gmon = Vector3.new(1.1629, 0.5578, 1.2764),
	BS_LeftLeg_Skin_g020 = Vector3.new(0.7782, 0.7733, 0.8569),
	BS_LeftLeg_Skin_g040 = Vector3.new(0.8561, 0.7760, 0.9222),
	BS_LeftLeg_Skin_g060 = Vector3.new(0.9412, 0.7787, 0.9923),
	BS_LeftLeg_Skin_g080 = Vector3.new(1.0261, 0.7813, 1.0666),
	BS_LeftLeg_Skin_g100 = Vector3.new(1.1098, 0.7840, 1.1376),
	BS_LeftLeg_Skin_gmon = Vector3.new(1.7164, 0.8047, 1.6104),
	BS_RightLeg_Shorts_g020 = Vector3.new(0.7390, 0.5196, 0.8723),
	BS_RightLeg_Shorts_g040 = Vector3.new(0.7644, 0.5237, 0.9046),
	BS_RightLeg_Shorts_g060 = Vector3.new(0.7908, 0.5277, 0.9397),
	BS_RightLeg_Shorts_g080 = Vector3.new(0.8238, 0.5317, 0.9799),
	BS_RightLeg_Shorts_g100 = Vector3.new(0.8628, 0.5358, 1.0228),
	BS_RightLeg_Shorts_gmon = Vector3.new(1.1262, 0.5574, 1.2752),
	BS_RightLeg_Skin_g020 = Vector3.new(0.7801, 0.7733, 0.8589),
	BS_RightLeg_Skin_g040 = Vector3.new(0.8599, 0.7760, 0.9233),
	BS_RightLeg_Skin_g060 = Vector3.new(0.9368, 0.7787, 0.9954),
	BS_RightLeg_Skin_g080 = Vector3.new(1.0233, 0.7814, 1.0626),
	BS_RightLeg_Skin_g100 = Vector3.new(1.1133, 0.7841, 1.1341),
	BS_RightLeg_Skin_gmon = Vector3.new(1.6935, 0.8130, 1.6598),
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
return table.concat(lines, "
") .. (if #missing > 0 then "
MISSING: " .. table.concat(missing, ", ") else "")
