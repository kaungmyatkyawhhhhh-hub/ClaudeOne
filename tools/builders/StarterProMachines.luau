-- StarterProMachines builder (prompt 16, 21 Oct; run once in Studio, Edit mode): one copy of every pro gym machine in the
-- starter gym, the same copy system as the beach gym: a clone of the pro gym's model (same MachineId, config, tiers, EXP,
-- so unlocks, the NEW tag and quests are shared) with the model attribute Gym = "Starter" (Machines.GymOpenAt opens it
-- with the starter gym). They stand in two columns in the free middle of the starter gym (between the barbell rows and the
-- stretching area), stacks to the outside and an 8-stud walkway between the lifters.
-- Usage (command bar): require(game.ServerStorage._Builders.StarterProMachines).Build()
local CollectionService = game:GetService("CollectionService")

local Builder = {}

-- MachineId -> { x, z, facing } (facing = where the lifter looks: "W" = -X, "E" = +X)
local SPOTS = {
	Dips = { -11, -63, "W" }, LateralRaise = { -11, -57, "W" }, ReverseFly = { -11, -51, "W" }, Shrugs = { -11, -45, "W" },
	BicepCurl = { -11, -39, "W" }, TricepPushdown = { -11, -33, "W" },
	LegCurl = { 3, -63, "E" }, HipThrust = { 3, -56, "E" }, CalfRaise = { 3, -50, "E" }, HangingLegRaise = { 3, -42, "E" },
	CableWoodchop = { 3, -34, "E" },
}

function Builder.Build()
	local pro = workspace:FindFirstChild("ProGym")
	local folder = workspace.Gym:FindFirstChild("Machines")
	assert(pro and folder, "ProGym or Gym.Machines is missing")
	-- old copies from an earlier run
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Gym") == "Starter" then model:Destroy() end
	end
	local made = {}
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		local id = model:GetAttribute("MachineId")
		local spot = id and SPOTS[id]
		if spot and model:IsDescendantOf(pro) and not made[id] then
			made[id] = true
			local copy = model:Clone()
			copy.Name = id
			copy:SetAttribute("Gym", "Starter")
			copy:SetAttribute("UserId", nil)
			for _, d in ipairs(copy:GetDescendants()) do
				if d.Name == "Occupant" or d.Name == "Plates" then d:Destroy() end
			end
			-- the lifter stands at the pivot facing +Z: turn so they face west / east
			local yaw = if spot[3] == "W" then math.rad(-90) else math.rad(90)
			local y = model:GetPivot().Position.Y
			copy:PivotTo(CFrame.new(spot[1], y, spot[2]) * CFrame.Angles(0, yaw, 0))
			copy.Parent = folder
		end
	end
	local missing = {}
	for id in pairs(SPOTS) do
		if not made[id] then table.insert(missing, id) end
	end
	return "copied " .. #folder:GetChildren() .. " machines in the starter gym; missing: " .. table.concat(missing, ", ")
end

return Builder
