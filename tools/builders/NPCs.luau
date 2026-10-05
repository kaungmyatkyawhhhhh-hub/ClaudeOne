-- NPCs builder (run once in Studio; see tools/bake.md): the permanent NPCs, built as real R15 characters with
-- ServerScriptService.Server.NpcService (original looks, no catalog items) and saved in Workspace.NPCs:
--   Coach Dex behind the front desk (tag "Coach", prompt "TalkPrompt"; QuestService wires it), and
--   three gym-goers by the dumbbell rack with a dumbbell in each hand (tag "GymGoer", only the root anchored;
--   every client poses them locally in EmoteClient).
-- Visiting legends are NOT here: they come and go, so LegendService still builds them while they visit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NpcService = require(ServerScriptService.Server.NpcService)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)

local Builder = {}

-- In front of the dumbbell rack on the right wall (rack at x = 26, z -30..-20), facing into the room (-X). Kept
-- 4 studs apart, clear of the stretching mat, the arm wrestling table, the dip station and the pro gym door, and out
-- of the walkways (they used to stand shoulder to shoulder across the middle of the gym and blocked the tutorial
-- walk to the Flat Bench).
local FACING = Vector3.new(-1, 0, 0)
local GOERS = {
	{ spot = Vector3.new(23, 0.15, -21), skin = "#E0AC69", shirt = "#2B2B2B", pants = "#1E1E22", width = 1.15 },
	{ spot = Vector3.new(23, 0.15, -25), skin = "#8D5524", shirt = "#F4F1EA", pants = "#2B2B2B", width = 1.25 },
	{ spot = Vector3.new(23, 0.15, -29), skin = "#F1C27D", shirt = "#1F5FBF", pants = "#1E1E22", width = 1.1 },
}

local function dumbbell(hand)
	local model = Instance.new("Model")
	model.Name = "Dumbbell"
	local steel, black = Color3.fromHex("#9EA2A8"), Color3.fromHex("#141414")
	local function piece(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
		p.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0) * offset
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, p
		weld.Parent = p
		return p
	end
	piece("Handle", Vector3.new(0.9, 0.18, 0.18), CFrame.new(), steel, Enum.Material.Metal)
	piece("HeadA", Vector3.new(0.25, 0.55, 0.55), CFrame.new(0.5, 0, 0), black, Enum.Material.SmoothPlastic)
	piece("HeadB", Vector3.new(0.25, 0.55, 0.55), CFrame.new(-0.5, 0, 0), black, Enum.Material.SmoothPlastic)
	model.Parent = hand.Parent
end

function Builder.Build(Workspace)
	local npcs = Workspace:FindFirstChild("NPCs")
	if npcs then
		for _, name in ipairs({ Quests.CoachName, "GymGoer1", "GymGoer2", "GymGoer3" }) do
			local old = npcs:FindFirstChild(name)
			if old then old:Destroy() end
		end
	end
	local _, prompt = NpcService.Build(Quests.CoachLook, Quests.CoachSpot)
	if prompt then prompt.Name = "TalkPrompt" end
	for index, goer in ipairs(GOERS) do
		local spec = {
			name = "GymGoer" .. index, skin = goer.skin, shirt = goer.shirt, pants = goer.pants,
			scale = { height = 1, width = goer.width, depth = 1.1, head = 1 },
			tag = "GymGoer", animated = true, noLabel = true,
		}
		local model = NpcService.Build(spec, CFrame.lookAt(goer.spot, goer.spot + FACING))
		model:SetAttribute("Phase", index * 2.3) -- so they don't move in sync
		for _, handName in ipairs({ "RightHand", "LeftHand" }) do
			local hand = model:FindFirstChild(handName)
			if hand and hand:IsA("BasePart") then dumbbell(hand) end
		end
	end
end

return Builder
