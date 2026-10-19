-- legs_stage_setup (19 Oct, owner: "remove that ball bump on the inner quads"): run in Studio (Edit mode) AFTER importing the
-- 24 thigh stage OBJs from Downloads/gym_arc_meshes_lowpoly_innerfix/other_player_stages (skin + shorts, made by
-- tools/quad_fix_stage_corrections + tools/quad_fix_lowpoly.py from the original low-poly thighs: the quad fix, no inner quad /
-- hamstring growth, the adductor fill) with File > Import 3D into the Workspace. Same steps as tools/body_stage_setup; then
-- tools/quad_fix_patch_config.py with that folder's bounds.json.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- the fixed meshes' bounding-box sizes (part-local studs, from bounds.json)
local SIZES = {
	BS_LeftLeg_Shorts_g020 = Vector3.new(0.7391, 0.5196, 0.8729),
	BS_LeftLeg_Shorts_g040 = Vector3.new(0.7643, 0.5236, 0.9033),
	BS_LeftLeg_Shorts_g060 = Vector3.new(0.7903, 0.5277, 0.9398),
	BS_LeftLeg_Shorts_g080 = Vector3.new(0.8238, 0.5317, 0.9788),
	BS_LeftLeg_Shorts_g100 = Vector3.new(0.8628, 0.5358, 1.0220),
	BS_LeftLeg_Shorts_gmon = Vector3.new(1.1629, 0.5578, 1.2764),
	BS_LeftLeg_Skin_g020 = Vector3.new(0.7675, 0.7729, 0.8310),
	BS_LeftLeg_Skin_g040 = Vector3.new(0.8350, 0.7744, 0.8781),
	BS_LeftLeg_Skin_g060 = Vector3.new(0.9058, 0.7760, 0.9335),
	BS_LeftLeg_Skin_g080 = Vector3.new(0.9741, 0.7776, 0.9885),
	BS_LeftLeg_Skin_g100 = Vector3.new(1.0441, 0.7792, 1.0431),
	BS_LeftLeg_Skin_gmon = Vector3.new(1.4662, 0.7914, 1.4696),
	BS_RightLeg_Shorts_g020 = Vector3.new(0.7390, 0.5196, 0.8723),
	BS_RightLeg_Shorts_g040 = Vector3.new(0.7644, 0.5237, 0.9046),
	BS_RightLeg_Shorts_g060 = Vector3.new(0.7908, 0.5277, 0.9397),
	BS_RightLeg_Shorts_g080 = Vector3.new(0.8238, 0.5317, 0.9799),
	BS_RightLeg_Shorts_g100 = Vector3.new(0.8628, 0.5358, 1.0228),
	BS_RightLeg_Shorts_gmon = Vector3.new(1.1262, 0.5574, 1.2752),
	BS_RightLeg_Skin_g020 = Vector3.new(0.7676, 0.7728, 0.8307),
	BS_RightLeg_Skin_g040 = Vector3.new(0.8340, 0.7744, 0.8749),
	BS_RightLeg_Skin_g060 = Vector3.new(0.9005, 0.7760, 0.9313),
	BS_RightLeg_Skin_g080 = Vector3.new(0.9713, 0.7775, 0.9893),
	BS_RightLeg_Skin_g100 = Vector3.new(1.0456, 0.7791, 1.0442),
	BS_RightLeg_Skin_gmon = Vector3.new(1.4560, 0.7962, 1.4983),
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
