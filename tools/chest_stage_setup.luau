-- chest_stage_setup (21 Oct, owner's prompt 9 part 3 "fuller chest", together with prompt 15's back): run in Studio (Edit
-- mode) AFTER importing the 14 torso stage OBJs from Downloads/gym_arc_meshes_lowpoly_chestfix/other_player_stages with
-- File > Import 3D into the Workspace (made by tools/chest_lowpoly.py: the trapsback torso of prompt 15 + the fuller chest
-- on the front; they replace the trapsback files, which never need importing). Same steps as tools/torso_back_stage_setup;
-- then tools/quad_fix_patch_config.py with that folder's bounds.json and --with-g000.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the fixed meshes' bounding-box sizes (part-local studs, from bounds.json)
local SIZES = {
	BS_Torso_Back_g000 = Vector3.new(2.0214, 1.8143, 0.6154),
	BS_Torso_Back_g020 = Vector3.new(2.1653, 1.8658, 0.6346),
	BS_Torso_Back_g040 = Vector3.new(2.3081, 1.9196, 0.6513),
	BS_Torso_Back_g060 = Vector3.new(2.4547, 1.9756, 0.6726),
	BS_Torso_Back_g080 = Vector3.new(2.6043, 2.0337, 0.7052),
	BS_Torso_Back_g100 = Vector3.new(2.7538, 2.0938, 0.7371),
	BS_Torso_Back_gmon = Vector3.new(3.1296, 2.3609, 0.8616),
	BS_Torso_Front_g000 = Vector3.new(2.0215, 1.8142, 0.6016),
	BS_Torso_Front_g020 = Vector3.new(2.1366, 1.8658, 0.6256),
	BS_Torso_Front_g040 = Vector3.new(2.2521, 1.9196, 0.6878),
	BS_Torso_Front_g060 = Vector3.new(2.3659, 1.9756, 0.7563),
	BS_Torso_Front_g080 = Vector3.new(2.4829, 2.0337, 0.8272),
	BS_Torso_Front_g100 = Vector3.new(2.6084, 2.0938, 0.8975),
	BS_Torso_Front_gmon = Vector3.new(2.9201, 2.3609, 1.1414),
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
