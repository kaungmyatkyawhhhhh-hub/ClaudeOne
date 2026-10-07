-- limb_stages_setup: run ONCE in Studio's command bar (Edit mode) after importing the 28 forearm / calf stage meshes.
-- Makes the templates ReplicatedStorage.LimbStages.<file name> that Shared.LimbStages clones on every character.
-- For each stage in Config.LimbStages it takes, in this order:
--   1. a MeshPart already in ReplicatedStorage.LimbStages with that name (kept),
--   2. a MeshPart anywhere in Workspace whose name is the stage's file name (e.g. "RightLowerArm__Forearms__g040"; what you
--      get when you drag the bulk-imported meshes from the Asset Manager into the place), moved into the folder,
--   3. the stage's `id` in Config.LimbStages (a Mesh asset id), made into a MeshPart.
-- Then: File > Save to Roblox. Without all 28 templates the game keeps the old EditableMesh forearms / calves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")
local Config = require(ReplicatedStorage.Shared.Config.LimbStages)

local folder = ReplicatedStorage:FindFirstChild("LimbStages") or Instance.new("Folder")
folder.Name = "LimbStages"
folder.Parent = ReplicatedStorage

local function findInWorkspace(name)
	for _, item in ipairs(workspace:GetDescendants()) do
		if item:IsA("MeshPart") and (item.Name == name or (item.Parent and item.Parent.Name == name)) then return item end
	end
	return nil
end

local made, missing = 0, {}
for _, mesh in pairs(Config.Meshes) do
	for _, stage in ipairs(mesh.stages) do
		if folder:FindFirstChild(stage.file) then continue end
		local part = findInWorkspace(stage.file)
		if not part and stage.id ~= 0 then
			local ok, result = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromAssetId(stage.id)) end)
			if ok then part = result end
		end
		if part then
			local model = part.Parent
			part.Name = stage.file
			part.Anchored = true
			part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
			part.Massless = true
			part.TextureID = ""
			part.Parent = folder
			if model and model:IsA("Model") and #model:GetChildren() == 0 then model:Destroy() end
			made += 1
		else
			table.insert(missing, stage.file)
		end
	end
end
print(string.format("[LimbStages] %d templates made, %d in the folder, %d missing%s", made, #folder:GetChildren(), #missing,
	#missing > 0 and (": " .. table.concat(missing, ", ")) or ""))
