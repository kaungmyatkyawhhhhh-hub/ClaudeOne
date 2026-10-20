-- DumbbellSpots builder (prompt 16, 21 Oct; run in Studio, Edit mode): "Train" spots in front of every gym's dumbbell
-- rack (starter, pro, beach): two rows of three rubber mats, one lifter each (the pro gym: one row of four, its cable
-- towers stand close in front of the rack). Each spot is a small machine model (tag
-- "Machine", attribute Dumbbell = true, MachineId = the exercise it is on now; MachineService turns its prompt into the
-- exercise picker). Inside: the mat (Pad, with the ProximityPrompt), an invisible "Bar" (the machine code's load part)
-- and an empty "Plates" folder. The pivot is on the floor, facing into the room (the rack behind the lifter).
-- Which side of the rack is the room: the side whose spot rows are clear of walls and machines.
-- Usage (command bar): require(game.ServerStorage._Builders.DumbbellSpots).Build()
local CollectionService = game:GetService("CollectionService")

local Builder = {}

local RACKS = {
	{ path = { "Gym", "StarterGym", "Props", "DumbbellRack" }, gym = "Starter", parent = { "Gym", "Machines" } },
	{ path = { "ProGym", "Props", "DumbbellRack" }, gym = "Pro", parent = { "ProGym", "Machines" }, columns = { -5.1, -1.7, 1.7, 5.1 }, rows = { 3.2 } },
	{ path = { "Town", "BeachGym", "DumbbellRack" }, gym = "Beach", parent = { "Town", "BeachGym" } },
}
local COLUMNS = { -3.7, 0, 3.7 } -- across the rack
local ROWS = { 3.2, 6.8 }         -- out from the rack's face
local MAT = Vector3.new(3.1, 0.06, 3.1)

local function find(path)
	local node = workspace
	for _, name in ipairs(path) do
		node = node and node:FindFirstChild(name)
	end
	return node
end

-- how blocked a spot is: parts (not floor, not the rack) in a body-sized box there
local function blocked(at: Vector3, rack: Instance): number
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rack }
	local count = 0
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(at + Vector3.new(0, 3, 0)), Vector3.new(2.6, 5, 2.6), params)) do
		if part.Transparency < 1 and part.Size.Y > 0.4 then count += 1 end
	end
	return count
end

local function floorAt(position: Vector3, rack: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rack }
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
	return hit and hit.Position.Y or position.Y
end

local function spotModel(index: number, gym: string, pivot: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "DumbbellSpot" .. index
	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Size = MAT
	pad.Color = Color3.fromHex("#1E1E22")
	pad.Material = Enum.Material.Rubber
	pad.Anchored, pad.CanCollide, pad.CanQuery, pad.CanTouch, pad.CastShadow = true, false, false, false, false
	pad.CFrame = pivot * CFrame.new(0, MAT.Y / 2, 0)
	pad.Parent = model
	-- a thin gold edge at the front (the room side)
	local edge = Instance.new("Part")
	edge.Name = "Edge"
	edge.Size = Vector3.new(MAT.X, 0.07, 0.12)
	edge.Color = Color3.fromHex("#C98A12")
	edge.Material = Enum.Material.Metal
	edge.Anchored, edge.CanCollide, edge.CanQuery, edge.CanTouch, edge.CastShadow = true, false, false, false, false
	edge.CFrame = pivot * CFrame.new(0, 0.035, MAT.Z / 2 - 0.06)
	edge.Parent = model
	local bar = Instance.new("Part")
	bar.Name = "Bar"
	bar.Size = Vector3.new(0.2, 0.2, 0.2)
	bar.Transparency = 1
	bar.Anchored, bar.CanCollide, bar.CanQuery, bar.CanTouch, bar.CastShadow = true, false, false, false, false
	bar.CFrame = pivot * CFrame.new(0, 3, 0)
	bar.Parent = model
	local plates = Instance.new("Folder")
	plates.Name = "Plates"
	plates.Parent = model
	local holder = Instance.new("Attachment")
	holder.Name = "PromptAt"
	holder.Position = Vector3.new(0, 2.5, 0)
	holder.Parent = pad
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainPrompt"
	prompt.ActionText = "Train"
	prompt.ObjectText = "Dumbbells"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = holder
	model.PrimaryPart = pad
	model.WorldPivot = pivot
	model:SetAttribute("MachineId", "DBCurl")
	model:SetAttribute("Dumbbell", true)
	model:SetAttribute("Gym", gym)
	CollectionService:AddTag(model, "Machine")
	return model
end

function Builder.Build()
	local report = {}
	for _, spec in ipairs(RACKS) do
		local rack = find(spec.path)
		local parent = find(spec.parent)
		if not (rack and parent) then
			table.insert(report, spec.gym .. ": rack or folder missing")
			continue
		end
		for _, child in ipairs(parent:GetChildren()) do
			if child:GetAttribute("Dumbbell") then child:Destroy() end
		end
		local cf, size = rack:GetBoundingBox()
		-- the long side runs along the rack's X or Z (whichever is longer); test both faces
		local along = if size.X >= size.Z then cf.RightVector else cf.LookVector
		local out = Vector3.new(-along.Z, 0, along.X).Unit
		local depth = math.min(size.X, size.Z) / 2
		local best, bestScore = nil, math.huge
		for _, sign in ipairs({ 1, -1 }) do
			local dir = out * sign
			local score = 0
			for _, row in ipairs(spec.rows or ROWS) do
				for _, column in ipairs(spec.columns or COLUMNS) do
					score += blocked(cf.Position + dir * (depth + row) + along * column, rack)
				end
			end
			if score < bestScore then best, bestScore = dir, score end
		end
		local made = 0
		local columns = spec.columns or COLUMNS
		for r, row in ipairs(spec.rows or ROWS) do
			for c, column in ipairs(columns) do
				local at = cf.Position + best * (depth + row) + along * column
				local y = floorAt(at, rack)
				local position = Vector3.new(at.X, y, at.Z)
				-- facing away from the rack (into the room): the model's +Z
				local pivot = CFrame.lookAt(position, position - best)
				made += 1
				spotModel((r - 1) * #columns + c, spec.gym, pivot).Parent = parent
			end
		end
		table.insert(report, string.format("%s: %d spots (blocked parts %d)", spec.gym, made, bestScore))
	end
	return table.concat(report, "; ")
end

return Builder
