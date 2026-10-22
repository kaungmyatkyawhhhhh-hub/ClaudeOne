-- GoTo (22 Oct, owner: "GO TO buttons teleport"): where a GO TO target is and the spot just in front of it. Shared by the
-- client's glowing path (Shared/UI/GuidePath, which had this logic) and the server's teleport (GoToService), so both pick
-- the same machine and the same spot.
--   GoTo.Valid(target) -> boolean                         target = a MachineId or "Coach" (the Coach NPC, tagged "Coach")
--   GoTo.Find(target, from: Vector3, spurts: number | data) -> Model?   (pass the player's data: a gym kept open from
--       before a ladder change counts, Machines.GymLevel; prompt 58)
--       the gym has several of each machine: the nearest one nobody is using (any one if all are busy), only in gyms the
--       player has opened (spurts = their Growth Spurts); a dumbbell exercise = any dumbbell Train spot
--   GoTo.Spot(model) -> Vector3   on the floor, just outside the machine on the side facing the middle of its gym
-- (prompt 39) Places too, for the unlock guides: "Gym:<Beach|Pro|Powerlifting>" (the nearest free machine in that gym, once it's open),
-- "Tag:<tag>" (the nearest model with that tag: TrainerDesk = the Trainer Agency, ArmWrestleTable, PumpShopCounter; a
-- tagged part counts as its model) and "Stage" (the posing stage: GoTo.Point gives its spot, there's no model).
local CollectionService = game:GetService("CollectionService")

local Machines = require(script.Parent.Config.Machines)

local GoTo = {}

GoTo.Approach = 2.5 -- studs outside the machine's box

local PLACE_TAGS = { TrainerDesk = true, ArmWrestleTable = true, PumpShopCounter = true }

function GoTo.Valid(target: any): boolean
	if type(target) ~= "string" then return false end
	if target == "Coach" or target == "Stage" or Machines.ById[target] ~= nil then return true end
	local gym = string.match(target, "^Gym:(%a+)$")
	if gym then return Machines.GymUnlock[gym] ~= nil end
	local tag = string.match(target, "^Tag:(%a+)$")
	return tag ~= nil and PLACE_TAGS[tag] == true
end

-- (prompt 39) a target with no model: its spot on the floor (the posing stage: in front of it), else nil
function GoTo.Point(target: string): Vector3?
	if target == "Stage" then
		local Town = require(script.Parent.Config.Town)
		local stage = Town.Stage
		return stage.Center - Vector3.new(0, 0, stage.Size.Z / 2 + 4)
	end
	return nil
end

function GoTo.Find(target: string, from: Vector3, spurts: any): Model?
	if type(spurts) == "table" then spurts = Machines.GymLevel(spurts) end
	spurts = tonumber(spurts) or 0
	if target == "Coach" then
		return CollectionService:GetTagged("Coach")[1]
	end
	local nearest = function(models)
		local best, bestScore = nil, math.huge
		for _, model in ipairs(models) do
			local busy = model:GetAttribute("UserId") ~= nil or model:FindFirstChild("Occupant") ~= nil
			local score = (model:GetPivot().Position - from).Magnitude + (if busy then 1000 else 0)
			if score < bestScore then best, bestScore = model, score end
		end
		return best
	end
	local gym = string.match(target, "^Gym:(%a+)$")
	if gym then
		if (Machines.GymUnlock[gym] or math.huge) > spurts then return nil end
		local list = {}
		for _, model in ipairs(CollectionService:GetTagged("Machine")) do
			if model:IsA("Model") and model:GetAttribute("Gym") == gym then table.insert(list, model) end
		end
		return nearest(list)
	end
	local tag = string.match(target, "^Tag:(%a+)$")
	if tag then
		local list = {}
		for _, tagged in ipairs(CollectionService:GetTagged(tag)) do
			local model = if tagged:IsA("Model") then tagged else tagged:FindFirstAncestorWhichIsA("Model")
			if model and model:IsDescendantOf(workspace) then table.insert(list, model) end
		end
		return nearest(list)
	end
	local machine = Machines.ById[target]
	local best, bestScore = nil, math.huge
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		-- (prompt 32) a dumbbell exercise: any dumbbell Train spot (it becomes the exercise you pick) in a gym you've opened
		local match = if machine and machine.dumbbell
			then model:GetAttribute("Dumbbell") == true and (Machines.GymUnlock[model:GetAttribute("Gym")] or 0) <= spurts
			else model:GetAttribute("MachineId") == target and (not machine or Machines.GymOpenAt(machine, model) <= spurts)
		if model:IsA("Model") and match then
			local busy = model:GetAttribute("UserId") ~= nil or model:FindFirstChild("Occupant") ~= nil
			local score = (model:GetPivot().Position - from).Magnitude + (busy and 1000 or 0)
			if score < bestScore then best, bestScore = model, score end
		end
	end
	return best
end

-- The middle of the gym the target is in (machines in the same room, within 60 studs of it).
local function gymCenter(near: Vector3, room: Instance?): Vector3?
	local sum, count = Vector3.zero, 0
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:IsA("Model") and (not room or model.Parent == room) then
			local position = model:GetPivot().Position
			if (position - near).Magnitude < 60 then
				sum += position
				count += 1
			end
		end
	end
	return if count > 0 then sum / count else nil
end

-- From the machine's prompt, head toward the middle of the gym until leaving the machine's box, then a bit more.
function GoTo.Spot(model: Model): Vector3
	local boxCFrame, size = model:GetBoundingBox()
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true) -- Use or Spot: both sit on the same part
	local holder = prompt and prompt.Parent
	local start = (holder and holder:IsA("BasePart") and holder.Position)
		or (holder and holder:IsA("Attachment") and holder.WorldPosition)
		or boxCFrame.Position
	-- (a desk or a table has no machines in its own folder: then the machines near it, so the spot is on the room side,
	-- never through the wall behind it)
	local center = gymCenter(boxCFrame.Position, model.Parent) or gymCenter(boxCFrame.Position, nil) or boxCFrame.Position
	local localStart = boxCFrame:PointToObjectSpace(start)
	local localDir = boxCFrame:VectorToObjectSpace((center - start) * Vector3.new(1, 0, 1))
	if localDir.Magnitude < 0.01 then localDir = Vector3.new(0, 0, -1) end
	localDir = localDir.Unit
	local half = size / 2
	local exit = math.huge
	for _, axis in ipairs({ "X", "Z" }) do
		local d = localDir[axis]
		if math.abs(d) > 1e-4 then
			local bound = if d > 0 then half[axis] else -half[axis]
			exit = math.min(exit, (bound - localStart[axis]) / d)
		end
	end
	if exit == math.huge then exit = 0 end
	local localPoint = localStart + localDir * (math.max(exit, 0) + GoTo.Approach)
	local world = boxCFrame:PointToWorldSpace(localPoint)
	local floorY = boxCFrame.Position.Y - half.Y
	return Vector3.new(world.X, floorY, world.Z)
end

return GoTo
