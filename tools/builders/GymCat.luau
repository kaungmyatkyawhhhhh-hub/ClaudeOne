-- GymCat builder (run once in Studio; see tools/bake.md): Plates the gym cat lying on its round bed, ONE model so the two
-- always move together (owner, 8 Oct night): Workspace.NPCs.GymCat = the bed (Bed: cushion, rim, inner pillow) + the cat
-- (body, tucked paws, the head group "HeadGroup" with the face, the tail). Spot: the starter gym's front-right corner,
-- just west of the towel rack along the front wall, out of the walkway to the pro gym door and away from machines.
-- Tag "GymCat", Pet prompt "PetPrompt" (StaminaService wires it). Client idle (ShakeClient): the tail wags (its rest
-- CFrame is the Tail's BaseCFrame attribute) and the head slowly looks around (HeadGroup's BaseCFrame attribute).
-- Running it again replaces the old cat (and removes any leftover separate CatBed).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stamina = require(ReplicatedStorage.Shared.Config.Stamina)

local GymCat = {}

-- the bed's centre on the floor; the cat faces into the room (-Z). Local axes: the cat's head is toward local -X.
GymCat.Spot = Vector3.new(37.6, 0.15, -6.5)
local BED = CFrame.new(GymCat.Spot) * CFrame.Angles(0, math.rad(-90), 0)

local up = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up
local function part(model, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then p.Shape = shape end
	p.CFrame = BED * offset
	p.Parent = model
	return p
end

function GymCat.Build(Workspace)
	local npcs = Workspace:FindFirstChild("NPCs") or Instance.new("Folder")
	npcs.Name = "NPCs"
	npcs.Parent = Workspace
	local old = npcs:FindFirstChild("GymCat")
	if old then old:Destroy() end
	-- the old separate bed (Gyms builder, before 8 Oct night)
	local gym = Workspace:FindFirstChild("Gym")
	local room = gym and gym:FindFirstChild("StarterGym")
	local props = room and room:FindFirstChild("Props")
	local oldBed = props and props:FindFirstChild("CatBed")
	if oldBed then oldBed:Destroy() end

	local model = Instance.new("Model")
	model.Name = "GymCat"
	-- the bed: a soft cushion, a raised rim and an inner pillow the cat lies on
	local bed = Instance.new("Model")
	bed.Name = "Bed"
	bed.Parent = model
	local base = part(bed, "Cushion", Vector3.new(0.35, 2.4, 2.4), CFrame.new(0, 0.18, 0) * up, Color3.fromHex("#6B4F3A"), Enum.Material.Fabric, Enum.PartType.Cylinder)
	base.CanCollide = true
	part(bed, "Rim", Vector3.new(0.55, 2.7, 2.7), CFrame.new(0, 0.28, 0) * up, Color3.fromHex("#4A3628"), Enum.Material.Fabric, Enum.PartType.Cylinder)
	part(bed, "Inner", Vector3.new(0.5, 2.0, 2.0), CFrame.new(0, 0.33, 0) * up, Color3.fromHex("#7A5C44"), Enum.Material.Fabric, Enum.PartType.Cylinder)
	local top = 0.58 -- the pillow's top, above the bed's centre

	-- the cat, lying down (loaf): body low on the pillow, paws tucked forward, head up
	local fur = Color3.fromHex("#3A3A3E")
	local light = Color3.fromHex("#D9D4CB")
	local body = part(model, "Body", Vector3.new(1.45, 0.55, 0.85), CFrame.new(0.1, top + 0.27, 0), fur)
	part(model, "Chest", Vector3.new(0.4, 0.5, 0.66), CFrame.new(-0.55, top + 0.27, 0), light)
	for _, z in ipairs({ 0.2, -0.2 }) do
		part(model, "Paw", Vector3.new(0.38, 0.14, 0.17), CFrame.new(-0.82, top + 0.07, z), fur)
		part(model, "PawTip", Vector3.new(0.1, 0.12, 0.15), CFrame.new(-1.02, top + 0.07, z), light)
		part(model, "Haunch", Vector3.new(0.6, 0.38, 0.12), CFrame.new(0.45, top + 0.2, z * 2.2), fur)
	end
	-- the head (and its face) as one group, so the client can turn it as a whole
	local head = Instance.new("Model")
	head.Name = "HeadGroup"
	head.Parent = model
	local skull = part(head, "Head", Vector3.new(0.58, 0.52, 0.6), CFrame.new(-0.82, top + 0.78, 0), fur)
	part(head, "Muzzle", Vector3.new(0.2, 0.2, 0.32), CFrame.new(-1.12, top + 0.7, 0), light)
	part(head, "Nose", Vector3.new(0.05, 0.06, 0.08), CFrame.new(-1.23, top + 0.76, 0), Color3.fromHex("#C98A8A"))
	part(head, "EarL", Vector3.new(0.12, 0.26, 0.2), CFrame.new(-0.82, top + 1.12, 0.18) * CFrame.Angles(0, 0, math.rad(10)), fur)
	part(head, "EarR", Vector3.new(0.12, 0.26, 0.2), CFrame.new(-0.82, top + 1.12, -0.18) * CFrame.Angles(0, 0, math.rad(10)), fur)
	part(head, "EyeL", Vector3.new(0.06, 0.08, 0.08), CFrame.new(-1.11, top + 0.86, 0.14), Color3.fromHex("#E8C21C"))
	part(head, "EyeR", Vector3.new(0.06, 0.08, 0.08), CFrame.new(-1.11, top + 0.86, -0.14), Color3.fromHex("#E8C21C"))
	head.PrimaryPart = skull
	-- the neck pivot (where the head turns from)
	head.WorldPivot = BED * CFrame.new(-0.6, top + 0.55, 0)
	head:SetAttribute("BaseCFrame", head.WorldPivot)
	-- the tail curls along the side of the body on the pillow
	local tail = part(model, "Tail", Vector3.new(0.9, 0.13, 0.13), CFrame.new(0.95, top + 0.12, 0.35) * CFrame.Angles(0, math.rad(-35), 0), fur)
	tail:SetAttribute("BaseCFrame", tail.CFrame)
	model.PrimaryPart = body
	body.CanCollide = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pet"
	prompt.ObjectText = Stamina.Cat.Name
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Name = "PetPrompt"
	prompt.Parent = skull
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- Workspace streaming: always on every client
	CollectionService:AddTag(model, "GymCat")
	model.Parent = npcs
	return model
end

return GymCat
