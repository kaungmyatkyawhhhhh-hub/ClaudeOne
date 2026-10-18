-- upper_traps_stage_setup (19 Oct, owner's bug "upper traps missing"): run in Studio (Edit mode) AFTER importing the 12 fixed
-- torso stage OBJs (Downloads\gym_arc_meshes_lowpoly_trapsfix\other_player_stages, made by tools/quad_fix_lowpoly.py from
-- tools/upper_traps_stage_corrections; the g000 stages didn't change) with File > Import 3D into the Workspace. Same steps as
-- tools/quad_fix_stage_setup: each template in ReplicatedStorage.BodyStages takes its imported mesh (ApplyMesh) and new size,
-- the imported copy is deleted; returns "name old new" lines for Config/StageMeshBackup. Then run
-- tools/quad_fix_patch_config.py with this folder's bounds.json and push Config/BodyStages.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the fixed meshes' bounding-box sizes (part-local studs, from bounds.json)
local SIZES = {
	BS_Torso_Back_g020 = Vector3.new(2.1547, 1.8510, 0.6492),
	BS_Torso_Back_g040 = Vector3.new(2.2899, 1.9090, 0.6773),
	BS_Torso_Back_g060 = Vector3.new(2.4204, 1.9669, 0.7099),
	BS_Torso_Back_g080 = Vector3.new(2.5519, 2.0249, 0.7544),
	BS_Torso_Back_g100 = Vector3.new(2.6943, 2.0828, 0.7989),
	BS_Torso_Back_gmon = Vector3.new(3.0462, 2.6573, 1.1893),
	BS_Torso_Front_g020 = Vector3.new(2.1228, 1.8421, 0.6122),
	BS_Torso_Front_g040 = Vector3.new(2.2246, 1.8938, 0.6615),
	BS_Torso_Front_g060 = Vector3.new(2.3236, 1.9456, 0.7168),
	BS_Torso_Front_g080 = Vector3.new(2.4254, 1.9973, 0.7749),
	BS_Torso_Front_g100 = Vector3.new(2.5356, 2.0490, 0.8338),
	BS_Torso_Front_gmon = Vector3.new(2.8127, 2.5629, 1.1171),
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
