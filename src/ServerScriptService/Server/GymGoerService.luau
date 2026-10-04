-- NPC gym-goers (original, no names shown): three regulars by the free-weight benches with a dumbbell in each
-- hand. They're "animated" NPCs (only the root anchored); every client poses them locally (EmoteClient), so the
-- curls and flexes cost no network.
local NpcService = require(script.Parent.NpcService)

local GymGoerService = {}

-- Behind the three utility benches in the free-weight zone, facing the door aisle (+Z).
local GOERS = {
	{ spot = Vector3.new(3, 0.15, -28.6), skin = "#E0AC69", shirt = "#2B2B2B", pants = "#1E1E22", width = 1.15 },
	{ spot = Vector3.new(-1, 0.15, -28.6), skin = "#8D5524", shirt = "#F4F1EA", pants = "#2B2B2B", width = 1.25 },
	{ spot = Vector3.new(-5, 0.15, -28.6), skin = "#F1C27D", shirt = "#1F5FBF", pants = "#1E1E22", width = 1.1 },
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

function GymGoerService.Start()
	for index, goer in ipairs(GOERS) do
		local spec = {
			name = "GymGoer" .. index, skin = goer.skin, shirt = goer.shirt, pants = goer.pants,
			scale = { height = 1, width = goer.width, depth = 1.1, head = 1 },
			tag = "GymGoer", animated = true, noLabel = true,
		}
		local cframe = CFrame.lookAt(goer.spot, goer.spot + Vector3.new(0, 0, 1))
		local ok, err = pcall(function()
			local model = NpcService.Build(spec, cframe)
			model:SetAttribute("Phase", index * 2.3) -- so they don't move in sync
			for _, handName in ipairs({ "RightHand", "LeftHand" }) do
				local hand = model:FindFirstChild(handName)
				if hand and hand:IsA("BasePart") then dumbbell(hand) end
			end
		end)
		if not ok then warn("[GymGoerService] " .. tostring(err)) end
	end
end

return GymGoerService
