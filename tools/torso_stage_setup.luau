-- torso_stage_setup (19 Oct, owner: "make the upper traps way bigger"): run in Studio (Edit mode) AFTER importing the 12
-- torso stage OBJs from Downloads/gym_arc_meshes_lowpoly_trapsbig/other_player_stages with File > Import 3D into the
-- Workspace. Same steps as tools/body_stage_setup; then tools/quad_fix_patch_config.py with that folder's bounds.json.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the fixed meshes' bounding-box sizes (part-local studs, from bounds.json)
local SIZES = {
	BS_Torso_Back_g020 = Vector3.new(2.1547, 1.8971, 0.6468),
	BS_Torso_Back_g040 = Vector3.new(2.2899, 2.0011, 0.6742),
	BS_Torso_Back_g060 = Vector3.new(2.4204, 2.1051, 0.7058),
	BS_Torso_Back_g080 = Vector3.new(2.5519, 2.2091, 0.7485),
	BS_Torso_Back_g100 = Vector3.new(2.6943, 2.3131, 0.7912),
	BS_Torso_Back_gmon = Vector3.new(3.0462, 2.7373, 1.0727),
	BS_Torso_Front_g020 = Vector3.new(2.1228, 1.8627, 0.6231),
	BS_Torso_Front_g040 = Vector3.new(2.2246, 1.9350, 0.6833),
	BS_Torso_Front_g060 = Vector3.new(2.3236, 2.0073, 0.7496),
	BS_Torso_Front_g080 = Vector3.new(2.4254, 2.0797, 0.8178),
	BS_Torso_Front_g100 = Vector3.new(2.5356, 2.1520, 0.8877),
	BS_Torso_Front_gmon = Vector3.new(2.8127, 2.4507, 1.1469),
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
