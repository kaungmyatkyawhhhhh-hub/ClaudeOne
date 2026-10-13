-- Rivals builder (run once in Studio, Edit mode; see tools/bake.md): the NPC rivals Benny (starter gym) and Coral (beach
-- gym) as real R15 characters in Workspace.NPCs (tag "GymNpc", attribute Gym), built from Config/Rivals (BuildSpec: his
-- look and his ONE size). GymGoerService walks them between their gym's machines like the other regulars; RivalService
-- gives them the Challenge prompt. Dante (pro gym) is already there (tools/builders/NPCs).
-- Run it again after tools/builders/NPCs or BeachNPCs: those clear every NPC with a Gym attribute.
-- Usage: require(game.ServerStorage._Builders.Rivals).Build()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local NpcService = require(ServerScriptService.Server.NpcService)
local Rivals = require(ReplicatedStorage.Shared.Config.Rivals)

local Builder = {}

function Builder.Build()
	local npcs = Workspace:FindFirstChild("NPCs")
	local built = {}
	for _, rival in ipairs(Rivals.List) do
		local spec = Rivals.BuildSpec(rival)
		if spec then
			if npcs then
				for _, child in ipairs(npcs:GetChildren()) do
					if child.Name == rival.name and child:GetAttribute("Gym") == rival.gym then child:Destroy() end
				end
			end
			spec.tag, spec.animated = "GymNpc", true
			local at = rival.look.spot
			local model = NpcService.Build(spec, CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
			model:SetAttribute("Gym", rival.gym)
			table.insert(built, rival.name .. " (" .. rival.gym .. ")")
		end
	end
	return "built " .. table.concat(built, ", ")
end

return Builder
