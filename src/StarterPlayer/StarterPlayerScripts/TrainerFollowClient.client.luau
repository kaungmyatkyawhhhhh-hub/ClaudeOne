-- TrainerFollowClient (owner's feature run, task 7B): draws everyone's personal trainers (Config/Trainers) on this
-- client. A player's equipped trainers are in their "Trainers" attribute; each trainer is a local clone of
-- ReplicatedStorage.TrainerModels[id] (plain parts and the character's own meshes, nothing collides).
--   * Following: a few studs behind you and to the side (slot 1 right, slot 2 left), walking (walk / idle animations)
--     and catching up faster when you run. Feet always on the floor (a ray finds it). Farther than TeleportDistance, or
--     stuck behind something for StuckSeconds: he pops back beside you. Never walks through walls (a ray checks).
--   * On a machine: he stands at one of the machine's hype spots (tools/builders/SpotPoints; the last ones, so he isn't
--     in a spotter's way), facing you.
--   * Cheers: during a set a short line in a bubble now and then ("Push it!", CheerCooldown / CheerChance); claps and a
--     "Great set!" line at the end of every set (10 reps), and "New record!" on your personal records.
--   * Other players' trainers past RenderDistance aren't drawn.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trainers = require(Shared.Config.Trainers)
local Theme = require(Shared.UI.Theme)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local localPlayer = Players.LocalPlayer
local templates = ReplicatedStorage:WaitForChild("TrainerModels", 60)
if not templates then return end -- the trainer service didn't start

local ANIM = { Idle = "rbxassetid://507766388", Walk = "rbxassetid://507777826" } -- Roblox's default R15 idle / walk
local HYPE_SPOTS = { "Hype_5", "Hype_4", "Hype_3", "Hype_2", "Hype_1" } -- tried in this order (spotters fill from Hype_1)

local folder = Instance.new("Folder")
folder.Name = "LocalTrainers"
folder.Parent = Workspace

local rng = Random.new()
local followers = {} -- [player] = { [slot] = trainer state }
local machineOf = {} -- [player] = machine model they're on (refreshed a few times a second)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function refreshFilter()
	local list = { folder }
	local npcs = Workspace:FindFirstChild("NPCs")
	if npcs then table.insert(list, npcs) end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(list, p.Character) end
	end
	rayParams.FilterDescendantsInstances = list
end

-- the floor under a point (nil if none within reach)
local function floorAt(point: Vector3): number?
	local hit = Workspace:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
	return hit and hit.Position.Y or nil
end

-- is there room for a standing person at this floor point? (nothing solid in a body-sized box above the floor)
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
local function clearAt(point: Vector3): boolean
	overlap.FilterDescendantsInstances = rayParams.FilterDescendantsInstances
	local floor = floorAt(point)
	if not floor then return false end
	for _, part in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(point.X, floor + 2.9, point.Z), Vector3.new(1.8, 4.6, 1.8), overlap)) do
		if part.CanCollide and part.Transparency < 1 then return false end
	end
	return true
end

local function blocked(from: Vector3, to: Vector3): boolean
	local dir = to - from
	if dir.Magnitude < 0.05 then return false end
	local hit = Workspace:Raycast(from, dir, rayParams)
	return hit ~= nil and hit.Instance.CanCollide
end

local function bubble(state, text)
	local head = state.model:FindFirstChild("Head")
	if not head then return end
	local entry = state.bubble
	if not entry then
		local bill = Theme.New("BillboardGui", { Name = "TrainerBubble", Adornee = head, Size = UDim2.fromOffset(200, 40), StudsOffset = Vector3.new(0, 2.6, 0),
			AlwaysOnTop = false, MaxDistance = 60, Enabled = false, Parent = state.model })
		local box = Theme.Panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY, Parent = bill }, { Theme.Pad("S") })
		local label = Theme.Text({ Text = "", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, Upper = false, Parent = box })
		entry = { gui = bill, label = label, token = 0 }
		state.bubble = entry
	end
	entry.label.Text = text
	entry.gui.Enabled = true
	entry.token += 1
	local token = entry.token
	task.delay(Trainers.BubbleSeconds, function()
		if entry.token == token and entry.gui.Parent then entry.gui.Enabled = false end
	end)
end

------------------------------------------------------------------------
-- Trainers
------------------------------------------------------------------------
local function makeTrainer(id: string, slot: number)
	local template = templates:FindFirstChild(id)
	if not template then return nil end
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then model:Destroy() return nil end
	root.Anchored = true
	local tracks = {}
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	for name, animId in pairs(ANIM) do
		local a = Instance.new("Animation")
		a.AnimationId = animId
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		if ok and track then
			track.Looped = true
			track.Priority = name == "Walk" and Enum.AnimationPriority.Movement or Enum.AnimationPriority.Idle
			tracks[name] = track
		end
	end
	return {
		id = id, slot = slot, model = model, root = root, humanoid = humanoid, tracks = tracks, playing = nil,
		position = nil, lastProgress = os.clock(), lastCheer = 0, clapUntil = 0,
		rootHeight = humanoid.HipHeight + root.Size.Y / 2,
	}
end

local function play(state, name)
	if state.playing == name then return end
	state.playing = name
	for key, track in pairs(state.tracks) do
		if key == name then track:Play(0.2) elseif track.IsPlaying then track:Stop(0.2) end
	end
end

local function destroyTrainer(state)
	if state.model then state.model:Destroy() end
end

local function sync(player)
	local list = {}
	local value = player:GetAttribute("Trainers")
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			if Trainers.ById[id] then table.insert(list, id) end
		end
	end
	local current = followers[player] or {}
	local nextSet = {}
	for slot, id in ipairs(list) do
		local existing = current[slot]
		if existing and existing.id == id then
			nextSet[slot] = existing
			current[slot] = nil
		else
			nextSet[slot] = makeTrainer(id, slot)
		end
	end
	for _, state in pairs(current) do destroyTrainer(state) end
	followers[player] = next(nextSet) and nextSet or nil
end

local function watch(player)
	sync(player)
	player:GetAttributeChangedSignal("Trainers"):Connect(function() sync(player) end)
end
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watch, p) end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
	for _, state in pairs(followers[player] or {}) do destroyTrainer(state) end
	followers[player] = nil
	machineOf[player] = nil
end)

------------------------------------------------------------------------
-- Cheers: reps on the machine a trainer's player is on
------------------------------------------------------------------------
local repWatch = {} -- [player] = { model, connection, count }

local function onRep(player)
	local w = repWatch[player]
	if not w then return end
	w.count += 1
	local setDone = w.count % 10 == 0
	local now = os.clock()
	for _, state in pairs(followers[player] or {}) do
		if setDone then
			state.clapUntil = now + Trainers.ClapSeconds
			bubble(state, Trainers.SetDoneLines[rng:NextInteger(1, #Trainers.SetDoneLines)])
			state.lastCheer = now
		elseif now - state.lastCheer > Trainers.CheerCooldown and rng:NextNumber() < Trainers.CheerChance then
			bubble(state, Trainers.Cheers[rng:NextInteger(1, #Trainers.Cheers)])
			state.lastCheer = now
		end
	end
end

local function setMachine(player, model)
	if machineOf[player] == model then return end
	machineOf[player] = model
	local w = repWatch[player]
	if w and w.connection then w.connection:Disconnect() end
	repWatch[player] = nil
	if model then
		local entry = { model = model, count = 0 }
		-- (your own reps come exactly from RepResult below; for others the machine's rep counter is close enough)
		if player ~= localPlayer then
			entry.connection = model:GetAttributeChangedSignal("Reps"):Connect(function() onRep(player) end)
		end
		repWatch[player] = entry
	end
end

-- your own reps (each accepted rep: cheers, the set count) and personal records (claps and "New record!")
Remotes:WaitForChild("RepResult").OnClientEvent:Connect(function(result)
	if type(result) ~= "table" or result.noStamina then return end
	if not result.pr then
		if repWatch[localPlayer] then onRep(localPlayer) end
		return
	end
	if repWatch[localPlayer] then repWatch[localPlayer].count += 1 end
	for _, state in pairs(followers[localPlayer] or {}) do
		state.clapUntil = os.clock() + Trainers.ClapSeconds
		bubble(state, Trainers.RecordLines[rng:NextInteger(1, #Trainers.RecordLines)])
		state.lastCheer = os.clock()
	end
end)

------------------------------------------------------------------------
-- Moving
------------------------------------------------------------------------
-- A free place by `machine` for trainer `slot`: the machine's hype spots, then a ring around the lifter; only points
-- with room to stand (never inside this machine or the next one), the first free one for slot 1, the next for slot 2.
local function machineSpot(machine, slot: number, root: BasePart, taken: Vector3?): Vector3?
	local function ok(point)
		return clearAt(point) and (not taken or (point - taken).Magnitude > 2.5)
	end
	for _, name in ipairs(HYPE_SPOTS) do
		local spot = machine:FindFirstChild(name, true)
		if spot and spot:IsA("Attachment") and ok(spot.WorldPosition) then return spot.WorldPosition end
	end
	for _, radius in ipairs({ 4, 5.5 }) do
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local point = root.Position + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			if ok(point) then return point end
		end
	end
	return nil
end

-- where trainer `state` of `player` wants to stand, and what he faces
local function targetOf(player, state, root: BasePart): (Vector3, Vector3)
	local machine = machineOf[player]
	if machine and machine.Parent then
		-- (picked once a second or when the machine changes: the box checks aren't free)
		if state.spotFor ~= machine or os.clock() - (state.spotAt or 0) > 1 then
			local other = nil
			for _, s in pairs(followers[player] or {}) do
				if s ~= state and s.slot < state.slot and s.spotFor == machine then other = s.spot end
			end
			state.spot = machineSpot(machine, state.slot, root, other)
			state.spotFor, state.spotAt = machine, os.clock()
		end
		if state.spot then return state.spot, root.Position end
	end
	state.spotFor = nil
	local side = state.slot == 1 and 1 or -1
	local spot = root.Position - root.CFrame.LookVector * Trainers.FollowBehind + root.CFrame.RightVector * side * Trainers.FollowSide
	return spot, root.Position + root.CFrame.LookVector * 6
end

local function place(state, position: Vector3, face: Vector3)
	local flat = Vector3.new(face.X, position.Y, face.Z)
	if (flat - position).Magnitude < 0.1 then flat = position + state.root.CFrame.LookVector end
	state.model:PivotTo(CFrame.lookAt(position, flat) * state.root.CFrame:ToObjectSpace(state.model:GetPivot()))
end

local function step(player, state, root: BasePart, dt: number, now: number)
	local target, face = targetOf(player, state, root)
	local floor = floorAt(target) or (root.Position.Y - 3)
	target = Vector3.new(target.X, floor + state.rootHeight, target.Z)
	local pos = state.position
	if not pos or (pos - target).Magnitude > Trainers.TeleportDistance or now - state.lastProgress > Trainers.StuckSeconds then
		pos = target
		state.lastProgress = now
	end
	local offset = (target - pos) * Vector3.new(1, 0, 1)
	local distance = offset.Magnitude
	local moving = false
	if distance > 0.6 then
		local speed = distance > 10 and Trainers.CatchUpSpeed or Trainers.WalkSpeed
		local move = offset.Unit * math.min(distance, speed * dt)
		local nextPos = pos + move
		local chest = Vector3.new(0, 1, 0)
		if blocked(pos + chest, nextPos + chest) then
			-- a wall or a machine in the way: wait (he pops over after StuckSeconds)
			face = target
		else
			local nextFloor = floorAt(nextPos)
			pos = Vector3.new(nextPos.X, (nextFloor or floor) + state.rootHeight, nextPos.Z)
			moving = true
			face = pos + move
			state.lastProgress = now
		end
	else
		state.lastProgress = now
		pos = Vector3.new(pos.X, target.Y, pos.Z)
	end
	state.position = pos
	place(state, pos, face)
	play(state, moving and "Walk" or "Idle")
end

-- the clap (arms forward, hands meeting), before physics so it wins over the idle animation (as EmoteClient)
local function clap(state, now)
	local t = now * 9
	local swing = math.rad(25) * (0.5 + 0.5 * math.sin(t))
	for _, side in ipairs({ { "Right", 1 }, { "Left", -1 } }) do
		local arm = state.model:FindFirstChild(side[1] .. "UpperArm")
		local shoulder = arm and arm:FindFirstChild(side[1] .. "Shoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			shoulder.Transform = CFrame.Angles(math.rad(80), 0, 0) * CFrame.Angles(0, 0, side[2] * -swing)
		end
		local lower = state.model:FindFirstChild(side[1] .. "LowerArm")
		local elbow = lower and lower:FindFirstChild(side[1] .. "Elbow")
		if elbow and elbow:IsA("Motor6D") then elbow.Transform = CFrame.Angles(math.rad(35), 0, 0) end
	end
end
RunService.Stepped:Connect(function()
	local now = os.clock()
	for _, list in pairs(followers) do
		for _, state in pairs(list) do
			if now < state.clapUntil and state.model.Parent then clap(state, now) end
		end
	end
end)

local filterAt, machineAt = 0, 0
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	if now - filterAt > 1 then
		filterAt = now
		refreshFilter()
	end
	-- who is on which machine (MachineService puts the lifter's UserId on the model)
	if now - machineAt > 0.3 then
		machineAt = now
		local on = {}
		for _, model in ipairs(CollectionService:GetTagged("Machine")) do
			local userId = model:GetAttribute("UserId")
			if userId then on[userId] = model end
		end
		for player in pairs(followers) do setMachine(player, on[player.UserId]) end
	end
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for player, list in pairs(followers) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local show = root ~= nil and humanoid ~= nil and humanoid.Health > 0
			and (player == localPlayer or (root.Position - eye).Magnitude <= Trainers.RenderDistance)
		for _, state in pairs(list) do
			if show and root then
				if state.model.Parent ~= folder then
					state.position = nil -- (pops in beside the player)
					state.model.Parent = folder
				end
				step(player, state, root, dt, now)
			elseif state.model.Parent then
				state.model.Parent = nil
				state.playing = nil
			end
		end
	end
end)
