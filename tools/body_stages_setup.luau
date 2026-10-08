-- body_stages_setup: run ONCE in Studio's command bar (Edit mode) after importing Downloads\other_player_stages\*.obj with
-- Import 3D. Makes the templates ReplicatedStorage.BodyStages.<object name> that Shared.BodyStages clones on other
-- characters. It takes every MeshPart named "BS_..." wherever the importer put it (Workspace or anywhere else), moves it
-- into the folder (anchored, no collision / query / touch / shadow, no texture) and removes the emptied import models.
-- It also reports: missing objects, sizes that don't match Config.BodyStages (a wrong import scale), and which way the
-- importer turned the meshes (Config.BodyStages.ImportTurn must undo it). Then: File > Save to Roblox.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.BodyStages)

local folder = ReplicatedStorage:FindFirstChild("BodyStages") or Instance.new("Folder")
folder.Name = "BodyStages"
folder.Parent = ReplicatedStorage

-- where the imported torso halves sit relative to each other tells the turn: in the files the front half is at -Z
local found = {}
local models = {}
for _, root in ipairs({ workspace, ReplicatedStorage, game:GetService("ServerStorage") }) do
	for _, item in ipairs(root:GetDescendants()) do
		-- (the importer names the MeshPart after the OBJ object, or wraps it in a Model with that name)
		local name = if item:IsA("MeshPart") then (if string.sub(item.Name, 1, 3) == "BS_" then item.Name
			elseif item.Parent and string.sub(item.Parent.Name, 1, 3) == "BS_" then item.Parent.Name else nil) else nil
		if name and item.Parent ~= folder and not found[name] then
			item.Name = name
			found[name] = item
			local model = item:FindFirstAncestorWhichIsA("Model")
			if model then models[model] = true end
		end
	end
end
local turn = "unknown"
local front, back = found["BS_Torso_Front_g000"], found["BS_Torso_Back_g000"]
if front and back then
	local dz = front.Position.Z - back.Position.Z
	local dx = front.Position.X - back.Position.X
	turn = if math.abs(dz) >= math.abs(dx) then (if dz < 0 then "none (front at -Z)" else "180 degrees (front at +Z)")
		else "90 degrees (front along X): tell Claude"
end

local made, missing, badSize = 0, {}, {}
for _, region in ipairs(Config.Regions) do
	for _, stage in ipairs(region.stages) do
		for _, object in pairs(stage.objects) do
			local part = found[object.file]
			if part then
				part.Anchored = true
				part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
				part.Massless = true
				part.TextureID = ""
				part.Color = Color3.new(1, 1, 1)
				part.CFrame = CFrame.new()
				part.Parent = folder
				made += 1
				local m, s = part.MeshSize, object.size
				local okSize = math.abs(m.Y - s.Y) < 0.02 and math.abs(math.max(m.X, m.Z) - math.max(s.X, s.Z)) < 0.02
				if not okSize then table.insert(badSize, string.format("%s mesh %s config %s", object.file, tostring(m), tostring(s))) end
			elseif not folder:FindFirstChild(object.file) then
				table.insert(missing, object.file)
			end
		end
	end
end
for model in pairs(models) do
	if model.Parent and #model:GetDescendants() == 0 then model:Destroy() end
end
print(string.format("[BodyStages] %d templates moved, %d in the folder, %d missing%s", made, #folder:GetChildren(), #missing,
	#missing > 0 and (": " .. table.concat(missing, ", ")) or ""))
print("[BodyStages] import turn: " .. turn)
if #badSize > 0 then print("[BodyStages] sizes that don't match (import scale?):\n  " .. table.concat(badSize, "\n  ")) end
