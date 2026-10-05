-- TownService: the town hub outside the entrance hall is built in Studio (Workspace.Town, made with
-- tools/builders/Town.luau; layout in Config.Town). This service only wires its prompts: the clothing store
-- counter's Shop opens the store screen (WardrobeClient), the posing stage's Pose opens the Emotes panel.
-- The entrance doors slide on each client (TownClient); the beach gym's machines run through MachineService.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local TownService = {}

local function wire(town, promptName, eventName)
	local prompt = town:FindFirstChild(promptName, true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn("[TownService] Missing " .. promptName .. " in Workspace.Town")
		return
	end
	Guard.OnTriggered(prompt, function(player)
		Remotes.PlayerEvent:FireClient(player, eventName, {})
	end)
end

function TownService.Start()
	local town = Workspace:WaitForChild("Town", 10)
	if not town then
		warn("[TownService] Workspace.Town is missing: build it in Studio with tools/builders/Town.luau")
		return
	end
	wire(town, "ShopPrompt", "OpenClothingStore")
	wire(town, "PosePrompt", "OpenEmotes")
end

return TownService
