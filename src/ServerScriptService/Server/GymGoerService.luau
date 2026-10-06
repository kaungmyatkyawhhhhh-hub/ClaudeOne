-- GymGoerService: the gym regulars (Workspace.NPCs, tag "GymNpc", attribute Gym = "Starter" | "Pro"; built in Studio
-- with tools/builders/NPCs.luau) actually work out. Each runs a small loop on the server:
--   pick something to do -> walk there (PathfindingService, walk/idle animations) -> do it -> pick again
--   * train: a free machine in their gym that no player is on, near, or walking toward; 2-3 sets of 6-10 reps with
--     the same rep animation players get (MachineService.NpcLift), resting between sets. Pro regulars lift heavy.
--   * drink water at the fountain, or chat with another regular (they face each other), or stand and rest.
-- A player who walks up to a machine an NPC is using gets it: the NPC finishes the rep and steps off (and tapping Use
-- takes it at once, see MachineService). Coach Dex and visiting legends stand still but play an idle animation and
-- turn toward the nearest player.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Machines = require(ReplicatedStorage.Shared.Config.Machines)
local BodyService = require(script.Parent.BodyService)
local NpcService = require(script.Parent.NpcService)
local Poses = require(ReplicatedStorage.Shared.Config.Poses)
local MachineService = require(script.Parent.MachineService)

local GymGoerService = {}

local ANIM = {
	Idle = "rbxassetid://507766388", -- Roblox default R15 idle
	Walk = "rbxassetid://507777826", -- Roblox default R15 walk
}
local WALK_SPEED = 9
local PLAYER_NEAR = 9        -- studs: a machine with a player this close is not free
local PLAYER_HEADING = 22    -- studs: ...or a player this close and walking toward it
local YIELD_AFTER = 1.2      -- seconds a player has to stand by an NPC's machine before it steps off
local LOOK_RANGE = 14        -- Coach and legends turn toward players this close

local reserved = {} -- [machine model] = npc walking to it
local rng = Random.new()

------------------------------------------------------------------------
-- Animation helpers
------------------------------------------------------------------------
local function animator(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	return humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
end

local function loadTracks(npc)
	local anim = animator(npc)
	local tracks = {}
	if not anim then return tracks end
	for name, id in pairs(ANIM) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function() return anim:LoadAnimation(a) end)
		if ok and track then
			track.Looped = true
			track.Priority = name == "Walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle
			tracks[name] = track
		end
	end
	return tracks
end

local function play(state, name)
	for key, track in pairs(state.tracks) do
		if key == name then
			if not track.IsPlaying then track:Play(0.25) end
		elseif track.IsPlaying then
			track:Stop(0.25)
		end
	end
end

------------------------------------------------------------------------
-- Where things are
------------------------------------------------------------------------
local function gymMachines(gym)
	local list = {}
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		local machine = Machines.ById[model:GetAttribute("MachineId")]
		if machine and model:IsA("Model") then
			local proGym = Workspace:FindFirstChild("ProGym")
			local inPro = proGym ~= nil and model:IsDescendantOf(proGym)
			local inStarter = model:IsDescendantOf(Workspace:FindFirstChild("Gym") or proGym or Workspace)
			local beachGym = Workspace:FindFirstChild("Town") and Workspace.Town:FindFirstChild("BeachGym")
			local inBeach = beachGym ~= nil and model:IsDescendantOf(beachGym)
			if (gym == "Pro" and inPro) or (gym == "Starter" and inStarter and not inPro) or (gym == "Beach" and inBeach) then
				table.insert(list, model)
			end
		end
	end
	return list
end

local function spots(kind, gym)
	local list = {}
	local beach = Workspace:FindFirstChild("Town") and Workspace.Town:FindFirstChild("BeachGym")
	local folders = {}
	local starterSpots = Workspace:FindFirstChild("Gym") and Workspace.Gym:FindFirstChild("NpcSpots")
	local beachSpots = beach and beach:FindFirstChild("NpcSpots")
	if starterSpots then table.insert(folders, starterSpots) end
	if beachSpots then table.insert(folders, beachSpots) end
	for _, folder in ipairs(folders) do
		for _, spot in ipairs(folder:GetChildren()) do
			if spot:GetAttribute("Kind") == kind and spot:GetAttribute("Gym") == gym then table.insert(list, spot) end
		end
	end
	return list
end

-- Is a player on, near, or walking toward this machine?
local function playerWants(model)
	local here = model:GetPivot().Position
	if model:GetAttribute("UserId") then return true end
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local offset = (here - root.Position) * Vector3.new(1, 0, 1)
			local distance = offset.Magnitude
			if distance < PLAYER_NEAR then return true end
			local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			if distance < PLAYER_HEADING and velocity.Magnitude > 4 and velocity.Unit:Dot(offset.Unit) > 0.8 then return true end
		end
	end
	return false
end

------------------------------------------------------------------------
-- Walking
------------------------------------------------------------------------
local function setWalking(npc, on)
	local root = npc:FindFirstChild("HumanoidRootPart")
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end
	root.Anchored = not on
	humanoid.PlatformStand = false
	humanoid.WalkSpeed = WALK_SPEED
	if on then
		-- the server owns the NPC's physics
		pcall(function() root:SetNetworkOwner(nil) end)
	end
end

-- Walks to a point (pathfinding, straight line as a fallback). Returns true when it arrived.
local function walkTo(state, target)
	local npc, humanoid = state.npc, state.humanoid
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	setWalking(npc, true)
	play(state, "Walk")
	local points = { target }
	local path = PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 6 })
	local ok = pcall(function() path:ComputeAsync(root.Position, target) end)
	if ok and path.Status == Enum.PathStatus.Success then
		points = {}
		for _, waypoint in ipairs(path:GetWaypoints()) do table.insert(points, waypoint.Position) end
	end
	for _, point in ipairs(points) do
		humanoid:MoveTo(point)
		local reached = false
		local connection = humanoid.MoveToFinished:Connect(function(r) reached = r or true end)
		local started = os.clock()
		while not reached and os.clock() - started < 6 do
			task.wait(0.1)
			if not npc.Parent then connection:Disconnect() return false end
		end
		connection:Disconnect()
	end
	play(state, "Idle")
	local arrived = ((root.Position - target) * Vector3.new(1, 0, 1)).Magnitude < 4
	setWalking(npc, false)
	return arrived
end

local function faceToward(npc, point)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local flat = Vector3.new(point.X, root.Position.Y, point.Z)
	if (flat - root.Position).Magnitude > 0.1 then npc:PivotTo(CFrame.lookAt(root.Position, flat)) end
end

------------------------------------------------------------------------
-- Activities
------------------------------------------------------------------------
local function train(state)
	local gym = state.gym
	local options = {}
	for _, model in ipairs(gymMachines(gym)) do
		if MachineService.IsFree(model) and not reserved[model] and not playerWants(model) then table.insert(options, model) end
	end
	if #options == 0 then return false end
	local model = options[rng:NextInteger(1, #options)]
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	reserved[model] = state.npc
	-- walk to where players step off it
	local approach = model:GetPivot() * CFrame.new(Poses[machine.pose].exit)
	local arrived = walkTo(state, approach.Position)
	reserved[model] = nil
	if not arrived or playerWants(model) or not MachineService.IsFree(model) then return false end
	-- pro regulars lift heavy, starter regulars lift moderate
	local tiers = #machine.tiers
	local tier = gym == "Pro" and rng:NextInteger(tiers - 3, tiers) or rng:NextInteger(3, math.max(4, math.floor(tiers / 2)))
	play(state, nil)
	if not MachineService.NpcEnter(state.npc, model, tier) then return false end
	state.machine = model
	local yieldSince = nil
	for _ = 1, rng:NextInteger(2, 3) do
		for _ = 1, rng:NextInteger(6, 10) do
			if state.machine ~= model then return true end -- a player took it (MachineService stepped us off)
			MachineService.NpcLift(state.npc, model)
			task.wait(gym == "Pro" and 1.5 or 1.3)
			-- a player standing by the machine gets it
			if playerWants(model) then
				yieldSince = yieldSince or os.clock()
				if os.clock() - yieldSince > YIELD_AFTER then break end
			else
				yieldSince = nil
			end
		end
		if yieldSince then break end
		task.wait(rng:NextNumber(4, 7)) -- rest between sets, still on the machine
		if state.machine ~= model then return true end
	end
	if state.machine == model then
		MachineService.NpcLeave(state.npc, model)
		state.machine = nil
	end
	return true
end

local function goToSpot(state, kind)
	local list = spots(kind, state.gym)
	if #list == 0 then return false end
	local spot = list[rng:NextInteger(1, #list)]
	local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
	if not walkTo(state, spot.Position + offset) then return false end
	faceToward(state.npc, spot.Position + Vector3.new(0, 0, -3))
	play(state, "Idle")
	task.wait(rng:NextNumber(4, 8))
	return true
end

-- Chat: two free regulars of the same gym meet at a chat spot and face each other.
local function chat(state, all)
	local partner = nil
	for _, other in ipairs(all) do
		if other ~= state and other.gym == state.gym and other.free and not other.machine then
			partner = other
			break
		end
	end
	local list = spots("Chat", state.gym)
	if not partner or #list == 0 then return false end
	local spot = list[rng:NextInteger(1, #list)].Position
	state.free, partner.free = false, false
	partner.busyUntil = os.clock() + 20
	local a, b = spot + Vector3.new(-1.6, 0, 0), spot + Vector3.new(1.6, 0, 0)
	task.spawn(function()
		walkTo(partner, b)
		faceToward(partner.npc, a)
		play(partner, "Idle")
	end)
	walkTo(state, a)
	faceToward(state.npc, b)
	play(state, "Idle")
	task.wait(rng:NextNumber(8, 12))
	partner.busyUntil = 0
	partner.free = true
	return true
end

local function loop(state, all)
	task.wait(rng:NextNumber(0.5, 4)) -- don't all start at once
	while state.npc.Parent do
		if os.clock() < (state.busyUntil or 0) then
			task.wait(1)
		else
			state.free = false
			local roll = rng:NextNumber()
			local done
			if roll < 0.62 then
				done = train(state)
			elseif roll < 0.78 then
				done = goToSpot(state, "Water")
			elseif roll < 0.92 then
				done = chat(state, all)
			else
				done = goToSpot(state, "Rest")
			end
			state.free = true
			task.wait(done and rng:NextNumber(1, 3) or 2)
		end
	end
end

------------------------------------------------------------------------
-- Coach and legends: idle animation + turn toward the nearest player
------------------------------------------------------------------------
local function lookAtPlayers(npc)
	-- only the idle animation runs here; the turn toward the player is done on each client every frame (NpcLookClient),
	-- because a server-side turn only updates a few times a second and looks laggy
	local tracks = loadTracks(npc)
	if tracks.Idle then tracks.Idle:Play() end
end

-- The regulars show what to aim for: every NPC has the Robloxian 2.0 body (NpcService) and muscle blobs grown to a preset
-- (pro gym big, starter gym medium), keeping their own clothes and hair.
local NPC_GROWTH = { Starter = 0.5, Pro = 0.9, Beach = 0.6 }
local function dressNpc(npc, gym)
	NpcService.ApplyBody(npc) -- the Robloxian 2.0 body first (the NPCs are baked into the place)
	-- regulars never fall over or ragdoll (they were getting stuck in FallingDown/GettingUp after the body swap)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum then
		for _, state in ipairs({ Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.Physics }) do hum:SetStateEnabled(state, false) end
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "UpperTorso" and part.Name ~= "LowerTorso" then part.CanCollide = false end
		end
	end
	-- the clients draw the muscles from this number (muscle v7), grown to the gym's preset
	npc:SetAttribute("MuscleG", BodyService.EncodeShare(NPC_GROWTH[gym] or NPC_GROWTH.Starter))
end

function GymGoerService.Start()
	local npcs = Workspace:WaitForChild("NPCs", 10)
	if not npcs then return end
	local all = {}
	for _, npc in ipairs(CollectionService:GetTagged("GymNpc")) do
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		if humanoid and npc:GetAttribute("Gym") then
			task.spawn(pcall, dressNpc, npc, npc:GetAttribute("Gym"))
			local state = { npc = npc, humanoid = humanoid, gym = npc:GetAttribute("Gym"), tracks = loadTracks(npc), free = true }
			table.insert(all, state)
		end
	end
	MachineService.OnNpcEvicted(function(npc)
		for _, state in ipairs(all) do
			if state.npc == npc then state.machine = nil end
		end
	end)
	for _, state in ipairs(all) do task.spawn(loop, state, all) end
	for _, coach in ipairs(CollectionService:GetTagged("Coach")) do task.spawn(pcall, dressNpc, coach, "Pro"); lookAtPlayers(coach) end
	CollectionService:GetInstanceAddedSignal("Legend"):Connect(lookAtPlayers)
end

return GymGoerService
