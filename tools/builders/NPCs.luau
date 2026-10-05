-- NPCs builder (run once in Studio; see tools/bake.md): the permanent NPCs, built as real R15 characters with
-- ServerScriptService.Server.NpcService and saved in Workspace.NPCs:
--   Coach Dex behind the front desk (tag "Coach", prompt "TalkPrompt"; QuestService wires it), and
--   eight gym-goers (tag "GymNpc", attribute Gym = "Starter" | "Pro"; GymGoerService walks them between machines,
--   the water fountain and each other). Pro gym regulars are bigger and lift heavier.
-- Looks: original characters. Clothing and hair are Roblox-made catalog items (checked with
-- MarketplaceService:GetProductInfo: creator "Roblox"), no real people, no brands.
-- Also moves the gym cat (Workspace.NPCs.GymCat) to its bed by the front desk.
-- Visiting legends are NOT here: they come and go, so LegendService still builds them while they visit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NpcService = require(ServerScriptService.Server.NpcService)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)

local Builder = {}

-- Roblox-made catalog items
local HAIR = {
	Pal = 63690008, Beautiful = 16630147, Lavender = 451220849, BlondeSpiked = 376524487, Golden = 13476917,
	NormalBoy = 13477818, ChestnutBun = 62724852, Trecky = 32278814, ClassicMale = 4637254498,
}
local SHIRT = {
	Teal = 382537702, GreenJersey = 382538059, Motorcycle = 144076358, StripedDenim = 144076436,
	PurpleTeal = 4047886060, GuitarTee = 382538295,
}
local PANTS = {
	JeanShorts = 382537806, JeanShortsShoes = 382537950, BlackJeans = 382537569, BlackJeansSneakers = 382538503,
	DarkGreenJeans = 144076760, ClassicMale = 4637601297,
}

Builder.Goers = {
	-- starter gym regulars
	{ name = "Maya", gym = "Starter", skin = "#F1C27D", hair = HAIR.Lavender, shirt = SHIRT.Teal, pants = PANTS.JeanShortsShoes, width = 1.0, spot = Vector3.new(6, 0.15, -18) },
	{ name = "Theo", gym = "Starter", skin = "#8D5524", hair = HAIR.NormalBoy, shirt = SHIRT.Motorcycle, pants = PANTS.BlackJeansSneakers, width = 1.1, spot = Vector3.new(2, 0.15, -18) },
	{ name = "Rosa", gym = "Starter", skin = "#C68642", hair = HAIR.ChestnutBun, shirt = SHIRT.PurpleTeal, pants = PANTS.JeanShorts, width = 1.0, spot = Vector3.new(-6, 0.15, -48) },
	{ name = "Jun", gym = "Starter", skin = "#E0AC69", hair = HAIR.Trecky, shirt = SHIRT.GuitarTee, pants = PANTS.DarkGreenJeans, width = 1.05, spot = Vector3.new(-6, 0.15, -52) },
	-- pro gym regulars: bigger, lift heavy
	{ name = "Dante", gym = "Pro", skin = "#6B4226", hair = HAIR.ClassicMale, shirt = SHIRT.StripedDenim, pants = PANTS.BlackJeans, width = 1.4, depth = 1.35, height = 1.08, spot = Vector3.new(68, 0.15, -28) },
	{ name = "Kira", gym = "Pro", skin = "#F1C27D", hair = HAIR.Pal, shirt = SHIRT.Teal, pants = PANTS.BlackJeansSneakers, width = 1.25, depth = 1.2, height = 1.04, spot = Vector3.new(68, 0.15, -32) },
	{ name = "Marcus", gym = "Pro", skin = "#8D5524", hair = HAIR.BlondeSpiked, shirt = SHIRT.GreenJersey, pants = PANTS.ClassicMale, width = 1.45, depth = 1.4, height = 1.1, spot = Vector3.new(80, 0.15, -36) },
	{ name = "Ivy", gym = "Pro", skin = "#E0AC69", hair = HAIR.Beautiful, shirt = SHIRT.PurpleTeal, pants = PANTS.JeanShortsShoes, width = 1.2, depth = 1.15, height = 1.05, spot = Vector3.new(80, 0.15, -40) },
}

Builder.Coach = { hair = HAIR.Golden, shirt = SHIRT.GreenJersey, pants = PANTS.BlackJeansSneakers }

function Builder.Build(Workspace)
	local npcs = Workspace:FindFirstChild("NPCs")
	if npcs then
		for _, child in ipairs(npcs:GetChildren()) do
			if child.Name == Quests.CoachName or child.Name:match("^GymGoer") or child:GetAttribute("Gym") then child:Destroy() end
		end
	end
	local coach = table.clone(Quests.CoachLook)
	coach.hairIds = { Builder.Coach.hair }
	coach.shirtId = Builder.Coach.shirt
	coach.pantsId = Builder.Coach.pants
	coach.animated = true
	local _, prompt = NpcService.Build(coach, Quests.CoachSpot)
	if prompt then prompt.Name = "TalkPrompt" end

	for _, goer in ipairs(Builder.Goers) do
		local spec = {
			name = goer.name, skin = goer.skin, shirtId = goer.shirt, pantsId = goer.pants, hairIds = { goer.hair },
			scale = { height = goer.height or 1, width = goer.width or 1, depth = goer.depth or goer.width or 1, head = 1 },
			tag = "GymNpc", animated = true,
		}
		local model = NpcService.Build(spec, CFrame.lookAt(goer.spot, goer.spot + Vector3.new(0, 0, -1)))
		model:SetAttribute("Gym", goer.gym)
	end

	local cat = npcs and npcs:FindFirstChild("GymCat")
	if cat then
		local pivot = cat:GetPivot()
		cat:PivotTo(CFrame.new(31.5, pivot.Position.Y, -14) * CFrame.Angles(0, math.rad(-120), 0))
	end
end

return Builder
