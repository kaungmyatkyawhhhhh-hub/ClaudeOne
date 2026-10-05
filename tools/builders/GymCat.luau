-- GymCat builder (run once in Studio; see tools/bake.md): Plates the gym cat by the cat bed, built from simple parts
-- (tag "GymCat", Pet prompt "PetPrompt"; the tail's rest CFrame is its BaseCFrame attribute for the client wag).
-- Output: Workspace.NPCs.GymCat. StaminaService wires the prompt; ShakeClient wags the tail.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stamina = require(ReplicatedStorage.Shared.Config.Stamina)

local GymCat = {}

local CAT_SPOT = CFrame.new(25.4, 0.1, -8.6) * CFrame.Angles(0, math.rad(-90), 0) -- in front of the cat bed, facing the room

local function part(model, name, size, offset, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	if shape then p.Shape = shape end
	p.CFrame = CAT_SPOT * offset
	p.Parent = model
	return p
end

function GymCat.Build(Workspace)
	local npcs = Workspace:FindFirstChild("NPCs") or Instance.new("Folder")
	npcs.Name = "NPCs"
	npcs.Parent = Workspace
	local old = npcs:FindFirstChild("GymCat")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "GymCat"
	local fur = Color3.fromHex("#3A3A3E")
	local light = Color3.fromHex("#D9D4CB")
	local body = part(model, "Body", Vector3.new(1.5, 0.7, 0.8), CFrame.new(0, 0.75, 0), fur)
	part(model, "Chest", Vector3.new(0.45, 0.55, 0.62), CFrame.new(-0.62, 0.72, 0), light)
	local head = part(model, "Head", Vector3.new(0.6, 0.55, 0.6), CFrame.new(-0.95, 1.2, 0), fur)
	part(model, "Muzzle", Vector3.new(0.2, 0.22, 0.32), CFrame.new(-1.27, 1.12, 0), light)
	part(model, "EarL", Vector3.new(0.12, 0.26, 0.2), CFrame.new(-0.95, 1.55, 0.18) * CFrame.Angles(0, 0, math.rad(10)), fur)
	part(model, "EarR", Vector3.new(0.12, 0.26, 0.2), CFrame.new(-0.95, 1.55, -0.18) * CFrame.Angles(0, 0, math.rad(10)), fur)
	part(model, "EyeL", Vector3.new(0.06, 0.08, 0.08), CFrame.new(-1.26, 1.28, 0.14), Color3.fromHex("#E8C21C"))
	part(model, "EyeR", Vector3.new(0.06, 0.08, 0.08), CFrame.new(-1.26, 1.28, -0.14), Color3.fromHex("#E8C21C"))
	for i, x in ipairs({ -0.5, 0.5 }) do
		for j, z in ipairs({ 0.25, -0.25 }) do
			part(model, "Leg" .. i .. j, Vector3.new(0.18, 0.45, 0.18), CFrame.new(x, 0.22, z), fur)
		end
	end
	local tail = part(model, "Tail", Vector3.new(0.9, 0.14, 0.14), CFrame.new(1.15, 1.05, 0) * CFrame.Angles(0, 0, math.rad(35)), fur)
	tail:SetAttribute("BaseCFrame", tail.CFrame)
	model.PrimaryPart = body
	body.CanCollide = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pet"
	prompt.ObjectText = Stamina.Cat.Name
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Name = "PetPrompt"
	prompt.Parent = head
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- Workspace streaming: always on every client
	CollectionService:AddTag(model, "GymCat")
	model.Parent = npcs
	return model
end

return GymCat
