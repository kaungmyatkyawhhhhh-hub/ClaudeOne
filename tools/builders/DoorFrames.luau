-- DoorFrames: puts a slim dark metal frame (top, bottom, both sides) around each sliding glass leaf of the gym entrance
-- (Workspace.Gym.Entrance.DoorGlass), tagged "SlidingDoor" with the leaf's SlideX so the frame slides with the glass and
-- the open leaf keeps its edge frame. Run once in Studio (Edit mode); safe to run again (it replaces old frames).
local CollectionService = game:GetService("CollectionService")
local entrance = workspace.Gym.Entrance
for _, old in ipairs(entrance:GetChildren()) do
	if old.Name == "DoorLeafFrame" then old:Destroy() end
end
local function bar(leaf, size, offset)
	local p = Instance.new("Part")
	p.Name = "DoorLeafFrame"
	p.Size = size
	p.CFrame = leaf.CFrame * CFrame.new(offset)
	p.Color = Color3.fromRGB(28, 28, 30)
	p.Material = Enum.Material.Metal
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	local slide = leaf:GetAttribute("SlideX")
	if slide then p:SetAttribute("SlideX", slide) end
	p.Parent = entrance
	CollectionService:AddTag(p, "SlidingDoor")
end
for _, leaf in ipairs(entrance:GetChildren()) do
	if leaf.Name == "DoorGlass" and leaf:IsA("BasePart") then
		local w, h = leaf.Size.X, leaf.Size.Y
		local t, d = 0.16, 0.2
		bar(leaf, Vector3.new(w + t, t, d), Vector3.new(0, h / 2, 0))   -- top
		bar(leaf, Vector3.new(w + t, t, d), Vector3.new(0, -h / 2, 0))  -- bottom
		bar(leaf, Vector3.new(t, h + t, d), Vector3.new(w / 2, 0, 0))   -- right edge
		bar(leaf, Vector3.new(t, h + t, d), Vector3.new(-w / 2, 0, 0))  -- left edge
	end
end
