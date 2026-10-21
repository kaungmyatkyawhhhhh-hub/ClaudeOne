-- GoTo (22 Oct, owner: "GO TO buttons teleport"): where a GO TO target is and the spot just in front of it. Shared by the
-- client's glowing path (Shared/UI/GuidePath, which had this logic) and the server's teleport (GoToService), so both pick
-- the same machine and the same spot.
--   GoTo.Valid(target) -> boolean                         target = a MachineId or "Coach" (the Coach NPC, tagged "Coach")
--   GoTo.Find(target, from: Vector3, spurts: number) -> Model?
--       the gym has several of each machine: the nearest one nobody is using (any one if all are busy), only in gyms the
--       player has opened (spurts = their Growth Spurts); a dumbbell exercise = any dumbbell Train spot
--   GoTo.Spot(model) -> Vector3   on the floor, just outside the machine on the side facing the middle of its gym
local CollectionService = game:GetService("CollectionService")

local Machines = require(script.Parent.Config.Machines)

local GoTo = {}

GoTo.Approach = 2.5 -- studs outside the machine's box

function GoTo.Valid(target: any): boolean
	return target == "Coach" or (type(target) == "string" and Machines.ById[target] ~= nil)
end

function GoTo.Find(target: string, from: Vector3, spurts: number): Model?
	if target == "Coach" then
		return CollectionService:GetTagged("Coach")[1]
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
	local center = gymCenter(boxCFrame.Position, model.Parent) or boxCFrame.Position
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
