-- BeachNPCs builder (run once in Studio, Edit mode): four regulars for the beach gym (tag "GymNpc", attribute Gym = "Beach")
-- and the NpcSpots they walk to (Workspace.Town.BeachGym.NpcSpots). GymGoerService walks them between the beach machines.
-- Clothing and hair are Roblox-made catalog items (same ids as tools/builders/NPCs.luau).
local ServerScriptService = game:GetService("ServerScriptService")
local NpcService = require(ServerScriptService.Server.NpcService)
local Workspace = game:GetService("Workspace")

local goers = {
	{ name = "Kai", skin = "#C68642", hair = 13477818, shirt = 382537702, pants = 382537806, width = 1.1, spot = Vector3.new(-23, 0.3, 188) },
	{ name = "Luna", skin = "#F1C27D", hair = 451220849, shirt = 4047886060, pants = 382537950, width = 1.0, spot = Vector3.new(-8, 0.3, 206) },
	{ name = "Tomas", skin = "#8D5524", hair = 62724852, shirt = 144076358, pants = 382538503, width = 1.15, spot = Vector3.new(22, 0.3, 200) },
	{ name = "Zoe", skin = "#E0AC69", hair = 32278814, shirt = 382538295, pants = 144076760, width = 1.0, spot = Vector3.new(46, 0.3, 198) },
}

local npcs = Workspace:FindFirstChild("NPCs")
if npcs then
	for _, child in ipairs(npcs:GetChildren()) do
		if child:GetAttribute("Gym") == "Beach" then child:Destroy() end
	end
end
for _, goer in ipairs(goers) do
	local spec = {
		name = goer.name, skin = goer.skin, shirtId = goer.shirt, pantsId = goer.pants, hairIds = { goer.hair },
		scale = { height = 1, width = goer.width, depth = goer.width, head = 1 },
		tag = "GymNpc", animated = true,
	}
	local model = NpcService.Build(spec, CFrame.lookAt(goer.spot, goer.spot + Vector3.new(0, 0, -1)))
	model:SetAttribute("Gym", "Beach")
end

local beach = Workspace.Town:FindFirstChild("BeachGym")
if beach then
	local old = beach:FindFirstChild("NpcSpots")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "NpcSpots"
	folder.Parent = beach
	local function spot(kind, position)
		local p = Instance.new("Part")
		p.Name = kind .. "Spot"
		p.Size = Vector3.new(1, 0.2, 1)
		p.Position = position
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p:SetAttribute("Kind", kind)
		p:SetAttribute("Gym", "Beach")
		p.Parent = folder
	end
	spot("Chat", Vector3.new(0, 0.3, 205))
	spot("Chat", Vector3.new(35, 0.3, 205))
	spot("Rest", Vector3.new(-3, 0.3, 188))
	spot("Rest", Vector3.new(60, 0.3, 205))
	spot("Water", Vector3.new(8, 0.3, 175))
end
