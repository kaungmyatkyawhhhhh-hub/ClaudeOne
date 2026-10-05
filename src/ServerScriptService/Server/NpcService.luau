-- Builds NPCs (the Coach, legends, gym-goers) from a HumanoidDescription: a real R15 character with a small, clean
-- name label above the head and an optional ProximityPrompt. Looks are original characters; clothing and hair can be
-- Roblox-made catalog items (spec.shirtId / pantsId / hairIds), never real people or brands.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage.Shared.UI.Theme)

local NpcService = {}

local folder = nil
local function npcFolder()
	if folder and folder.Parent then return folder end
	folder = Workspace:FindFirstChild("NPCs") or Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = Workspace
	return folder
end

local function color(hex)
	return Color3.fromHex(hex)
end

-- Simple part-built stand-in, only used if Roblox can't build a character (e.g. avatar service down).
local function fallbackModel(spec)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "UpperTorso"
	body.Size = Vector3.new(2, 2.4, 1)
	body.Color = color(spec.shirt or "#2B2B2B")
	body.Anchored = true
	body.CFrame = root.CFrame
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.3, 1.3, 1.3)
	head.Color = color(spec.skin or "#C69C6D")
	head.Anchored = true
	head.CFrame = root.CFrame * CFrame.new(0, 1.9, 0)
	head.Parent = model
	Instance.new("Humanoid").Parent = model
	model.PrimaryPart = root
	return model
end

-- spec: { name, skin = hex, shirt = hex, pants = hex, scale = { height, width, depth, head } (optional),
--         shirtId / pantsId = catalog clothing ids, hairIds = { accessory ids } (optional; when a shirt is given the
--         torso isn't painted with the shirt color),
--         prompt = { action, object, distance } (optional), tag = CollectionService tag (optional),
--         animated = true (only the root is anchored, so clients can pose the joints), noLabel = true (no name) }
-- cframe: where the character stands (feet on the floor at cframe.Position, facing cframe.LookVector).
function NpcService.Build(spec, cframe)
	local model
	local ok = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = color(spec.skin or "#C69C6D")
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
		desc.LeftLegColor, desc.RightLegColor, desc.TorsoColor = color(spec.pants or "#1E1E22"), color(spec.pants or "#1E1E22"), color(spec.shirt or "#2B2B2B")
		if spec.scale then
			desc.HeightScale = spec.scale.height or 1
			desc.WidthScale = spec.scale.width or 1
			desc.DepthScale = spec.scale.depth or 1
			desc.HeadScale = spec.scale.head or 1
		end
		if spec.shirtId then desc.Shirt = spec.shirtId end
		if spec.pantsId then desc.Pants = spec.pantsId end
		if spec.hairIds then
			local ids = {}
			for _, id in ipairs(spec.hairIds) do table.insert(ids, tostring(id)) end
			desc.HairAccessory = table.concat(ids, ",")
		end
		model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		model = fallbackModel(spec)
	end
	model.Name = spec.name

	-- without catalog clothing, the "shirt" is the torso and upper arms painted in the shirt color (short sleeves)
	if not spec.shirtId then
		for _, partName in ipairs({ "UpperTorso", "LowerTorso", "RightUpperArm", "LeftUpperArm" }) do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then part.Color = color(spec.shirt or "#2B2B2B") end
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- animated NPCs only anchor the root, so their joints can still move (clients pose them)
			part.Anchored = not spec.animated or part.Name == "HumanoidRootPart"
			part.CanCollide = part.Name == "HumanoidRootPart" or part.Name == "UpperTorso" or part.Name == "LowerTorso"
		end
	end

	-- stand on the floor
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then model.PrimaryPart = root end
	local hip = humanoid and humanoid.HipHeight or 2
	local rootHalf = root and root.Size.Y / 2 or 1
	model:PivotTo(cframe + Vector3.new(0, hip + rootHalf, 0))

	-- name label: small and clean (fixed 14px Montserrat, so it's never bigger than the HUD), only up close
	local head = model:FindFirstChild("Head")
	if head and not spec.noLabel then
		local label = Instance.new("BillboardGui")
		label.Name = "NameTag"
		label.Size = UDim2.fromOffset(160, 20)
		label.StudsOffset = Vector3.new(0, 1.7, 0)
		label.MaxDistance = 30
		label.LightInfluence = 0
		label.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = spec.name
		text.FontFace = Theme.Fonts.SemiBold
		text.TextSize = Theme.TextSize.Small
		text.TextColor3 = Theme.Colors.Text
		text.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Colors.Shadow
		stroke.Transparency = 0.45
		stroke.Parent = text
	end

	local prompt = nil
	if spec.prompt and root then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = spec.prompt.action or "Talk"
		prompt.ObjectText = spec.prompt.object or spec.name
		prompt.MaxActivationDistance = spec.prompt.distance or 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
	end

	-- Workspace streaming: NPCs (Coach, legends, gym-goers) are always on every client, whole
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	if spec.tag then CollectionService:AddTag(model, spec.tag) end
	model.Parent = npcFolder()
	return model, prompt
end

return NpcService
