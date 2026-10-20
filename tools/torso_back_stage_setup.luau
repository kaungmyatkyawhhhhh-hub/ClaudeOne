-- torso_back_stage_setup (20 Oct, owner's prompt 15 "upper traps texture and back shape"): run in Studio (Edit mode) AFTER
-- importing the 14 torso stage OBJs from Downloads/gym_arc_meshes_lowpoly_trapsback/other_player_stages with File > Import
-- 3D into the Workspace (made by tools/torso_back_lowpoly.py: new back, top cap, texture map; g000 too). Same steps as
-- tools/torso_stage_setup; then tools/quad_fix_patch_config.py with that folder's bounds.json and --with-g000.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the fixed meshes' bounding-box sizes (part-local studs, from bounds.json)
local SIZES = {
	BS_Torso_Back_g000 = Vector3.new(2.0214, 1.8086, 0.6154),
	BS_Torso_Back_g020 = Vector3.new(2.1653, 1.8437, 0.6390),
	BS_Torso_Back_g040 = Vector3.new(2.3081, 1.9061, 0.6588),
	BS_Torso_Back_g060 = Vector3.new(2.4547, 1.9774, 0.6828),
	BS_Torso_Back_g080 = Vector3.new(2.6043, 2.0495, 0.7182),
	BS_Torso_Back_g100 = Vector3.new(2.7538, 2.1216, 0.7533),
	BS_Torso_Back_gmon = Vector3.new(3.1296, 2.4207, 0.9719),
	BS_Torso_Front_g000 = Vector3.new(2.0215, 1.8085, 0.6016),
	BS_Torso_Front_g020 = Vector3.new(2.1366, 1.8436, 0.6137),
	BS_Torso_Front_g040 = Vector3.new(2.2520, 1.8787, 0.6645),
	BS_Torso_Front_g060 = Vector3.new(2.3659, 1.9138, 0.7216),
	BS_Torso_Front_g080 = Vector3.new(2.4829, 1.9488, 0.7809),
	BS_Torso_Front_g100 = Vector3.new(2.6084, 1.9932, 0.8222),
	BS_Torso_Front_gmon = Vector3.new(2.9201, 2.1536, 1.0238),
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
