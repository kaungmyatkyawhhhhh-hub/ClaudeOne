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
	Builder.BuildAlters()
	Builder.BuildTrainerSkins()
	return folder
end

-- (prompt 21) The Body Alter skins next to the stages: one SurfaceAppearance "Alter_<id>" per alter with textures
-- (Config.Alters). Replaces only those, the stages stay as they are.
-- Usage: require(game.ServerStorage._Builders.SkinStages).BuildAlters()
function Builder.BuildAlters()
	local Alters = require(ReplicatedStorage.Shared.Config.Alters)
	local folder = ReplicatedStorage:FindFirstChild("SkinStages")
	assert(folder, "ReplicatedStorage.SkinStages is missing: run Build() first")
	local made = 0
	for _, alter in ipairs(Alters.List) do
		local name = "Alter_" .. alter.id
		local old = folder:FindFirstChild(name)
		if old then old:Destroy() end
		if alter.textures then
			local sa = Instance.new("SurfaceAppearance")
			sa.Name = name
			sa.ColorMap = alter.textures.color
			sa.NormalMap = alter.textures.normal
			sa.RoughnessMap = alter.textures.roughness
			if alter.textures.metalness then sa.MetalnessMap = alter.textures.metalness end -- (26 Oct) Tier 2-3
			sa.AlphaMode = Enum.AlphaMode.Overlay
			sa.Parent = folder
			made += 1
		end
	end
	return made
end

-- (prompt 25) The trainers' own materials (Config/Trainers Materials: Atlas's white marble with gold veins) as
-- MaterialVariants in MaterialService. Replaces only those.
-- Usage: require(game.ServerStorage._Builders.SkinStages).BuildTrainerSkins()
function Builder.BuildTrainerSkins()
	local Trainers = require(ReplicatedStorage.Shared.Config.Trainers)
	local MaterialService = game:GetService("MaterialService")
	local made = 0
	for name, maps in pairs(Trainers.Materials) do
		local old = MaterialService:FindFirstChild(name)
		if old then old:Destroy() end
		local variant = Instance.new("MaterialVariant")
		variant.Name = name
		variant.BaseMaterial = Enum.Material[maps.base]
		variant.ColorMap = maps.color
		variant.NormalMap = maps.normal
		variant.RoughnessMap = maps.roughness
		if maps.metalness then variant.MetalnessMap = maps.metalness end
		variant.StudsPerTile = maps.studsPerTile or 4
		variant.Parent = MaterialService
		made += 1
	end
	return made
end

return Builder
