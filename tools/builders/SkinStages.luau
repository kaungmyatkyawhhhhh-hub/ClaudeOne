-- SkinStages builder (run once in Studio's command bar, see tools/bake.md): ReplicatedStorage.SkinStages with one
-- SurfaceAppearance per skin texture stage (Stage1..Stage5, Config.SkinStages ids). A game script can't set a
-- SurfaceAppearance's maps, so they are made here and MuscleRig clones them onto the skin (tinted with SurfaceAppearance.Color).
-- Re-running replaces the folder.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Kit)
local SkinStages = require(ReplicatedStorage.Shared.Config.SkinStages)

local Builder = {}

function Builder.Build()
	local folder = Kit.fresh(ReplicatedStorage, "Folder", "SkinStages")
	for _, stage in ipairs(SkinStages.List) do
		local sa = Instance.new("SurfaceAppearance")
		sa.Name = stage.name
		sa.ColorMap = stage.color
		sa.NormalMap = stage.normal
		sa.RoughnessMap = stage.roughness
		sa.AlphaMode = Enum.AlphaMode.Overlay
		sa.Parent = folder
	end
	return folder
end

return Builder
