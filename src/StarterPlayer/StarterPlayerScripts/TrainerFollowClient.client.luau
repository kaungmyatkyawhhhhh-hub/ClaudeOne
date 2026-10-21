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
--   * Other players' trainers past RenderDistance aren't drawn; past FarAnimation they stand still (no animation).
--   * (prompt 29, trainer lag) Only ONE trainer follows each player in the world: the rarest equipped one (all of them still
--     give their boosts). Your other equipped trainers are portrait chips in the boosts row (HudBottom.ImageChip). Settings
--     "Others' Trainers" Off, or Low Graphics On, draws no other player's trainer at all. Followers are stepped OWN_HZ (yours)
--     / OTHER_HZ (others) times a second and eased in between (others farther than SNAP_BEYOND just jump); no Humanoid state
--     machine (anchored, moved by PivotTo); the idle poses pause off-screen; auras only within AURA_RANGE studs of the camera
--     and never on Low Graphics (Shared.VFX.TrainerAura keeps each under ~10 particles). One loop for all of them.
--   * Coach idle (owner, 14 Oct: never a stiff stand): a pose drawn on the joints over Roblox's idle: breathing (chest
--     and shoulders rise), a slow weight shift, and his own stance (Config/Trainers idle: arms crossed, clipboard check, hands on
--     hips). While you lift he faces you and every Trainers.CheerEvery reps claps or pumps a fist ("come on!"); speech
--     bubbles at most one per Trainers.CheerCooldown seconds.
--   * (prompt 25) The new trainers' own idles (Config/Trainers idle): Duke claps chalk off his hands and cracks his neck,
--     Volta bounces on her toes and shadow-boxes, The Shadow crosses his arms and slowly turns his head to watch you, Atlas
--     strikes a front double biceps every ~8 s. Their auras (Shared.VFX.TrainerAura). The line a trainer says when you
--     equip him (Config/Trainers line / lines: The Shadow says "..." and, once a session, "Train.").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trainers = require(Shared.Config.Trainers)
local Theme = require(Shared.UI.Theme)
local AuraVFX = require(Shared.VFX.AuraVFX)
local TrainerAura = require(Shared.VFX.TrainerAura)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClientData = require(Shared.ClientData)
local HudBottom = require(Shared.UI.HudBottom)
local Notify = require(Shared.UI.Notify)

local localPlayer = Players.LocalPlayer
local templates = ReplicatedStorage:WaitForChild("TrainerModels", 60)
if not templates then return end -- the trainer service didn't start

-- Roblox's default R15 idle / walk / run (the player rig's own Animate set). Owner, 19 Oct: trainers slid without moving
-- their legs: they're moved by PivotTo (no Humanoid movement), so the speed is measured from the position change and the
-- animation picked from it: idle under IDLE_BELOW studs/s, walk under RUN_FROM, run above; 0.2 s crossfades; the walk / run
-- play at speed / their own pace (WALK_PACE / RUN_PACE studs a second at playback speed 1, x the trainer's size) so the feet
-- don't skate.
local ANIM = { Idle = "rbxassetid://507766388", Walk = "rbxassetid://913402848", Run = "rbxassetid://913376220" }
local IDLE_BELOW, RUN_FROM = 0.5, 12
local WALK_PACE, RUN_PACE = 8, 16
-- each coach's own stance while standing (Config/Trainers idle; drawn over the idle animation, see coachIdle)
local CHALK_EVERY, FLEX_EVERY, FLEX_HOLD = 9, 8, 2.6 -- seconds (Duke's chalk + neck crack, Atlas's double biceps)
local HYPE_SPOTS = { "Hype_5", "Hype_4", "Hype_3", "Hype_2", "Hype_1" } -- tried in this order (spotters fill from Hype_1)
local OWN_HZ, OTHER_HZ, SNAP_BEYOND, AURA_RANGE = 30, 15, 40, 40 -- (prompt 29, see the header)

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

local function bubble(state, text, force: boolean?)
	local head = state.model:FindFirstChild("Head")
	if not head then return end
	-- (owner, 14 Oct: at most one bubble per CheerCooldown seconds, whatever asked for it; prompt 25: the equip line always)
	local now = os.clock()
	if not force and now - (state.lastBubble or -math.huge) < Trainers.CheerCooldown then return end
	state.lastBubble = now
	local entry = state.bubble
	if not entry then
		local bill = Theme.New("BillboardGui", { Name = "TrainerBubble", Adornee = head, Size = UDim2.fromOffset(200, 40), StudsOffset = Vector3.new(0, 2.6, 0),
			AlwaysOnTop = false, MaxDistance = 40, Enabled = false, Parent = state.model })
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
-- (prompt 24) entry = "PumpCoach" or "PumpCoach@g" (Golden: a gold glow on him)
local function makeTrainer(entry: string, slot: number)
	local id, golden = Trainers.ParseEntry(entry)
	local template = id and templates:FindFirstChild(id)
	if not template then return nil end
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then model:Destroy() return nil end
	root.Anchored = true
	-- never in a player's way (owner, 14 Oct): no collisions, no touches, not hit by rays (the camera doesn't zoom in on them)
	local function ghost(part)
		if part:IsA("BasePart") then
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.CollisionGroup = "Trainers"
		end
	end
	-- (owner, 14 Oct: torn-looking clothes) the muscle stages' separate skin layer sits under the clothing mesh and pokes
	-- through it where the muscles bulge (the lats), so it is hidden on trainers
	local function skinLayer(part)
		if part:IsA("BasePart") and part.Name == "Skin" and part.Parent and part.Parent.Parent and part.Parent.Parent.Name == "MuscleMeshes" then
			part.LocalTransparencyModifier = 1
		end
	end
	-- (prompt 34: on every trainer now. Their outfits are fully solid wherever they're worn (tools/trainer_outfits.py), so
	-- the skin layer never has anything to show; a bare chest is the piece itself, not this layer)
	for _, part in ipairs(model:GetDescendants()) do
		ghost(part)
		skinLayer(part)
	end
	model.DescendantAdded:Connect(function(part)
		ghost(part)
		skinLayer(part)
	end)
	if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator", humanoid) end
	-- (prompt 29) no Humanoid physics or states: he is anchored and moved by PivotTo; the Animator still plays
	pcall(function() humanoid.EvaluateStateMachine = false end)
	if golden then
		local glow = Instance.new("Highlight")
		glow.Name = "GoldenGlow"
		glow.FillColor = Color3.fromHex("#F6C75A")
		glow.OutlineColor = Color3.fromHex("#FFF3C4")
		glow.FillTransparency = 0.72
		glow.OutlineTransparency = 0.25
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = model
	end
	-- (the animation tracks are loaded the first time he's in the Workspace: see loadTracks. Loaded while the model was
	-- still outside it they never played, so trainers slid without moving their legs: owner's bug, 19 Oct)
	return {
		id = id, entry = entry, golden = golden, slot = slot, model = model, auraName = Trainers.ById[id].look.aura, root = root, humanoid = humanoid, tracks = {}, playing = nil,
		position = nil, lastProgress = os.clock(), lastCheer = 0, clapUntil = 0, pumpUntil = 0, cheerTurn = 0,
		style = Trainers.ById[id].idle or "crossed", phase = rng:NextNumber() * 10, look = 0,
		rootHeight = humanoid.HipHeight + root.Size.Y / 2,
		scale = math.max((humanoid.HipHeight + root.Size.Y / 2) / 3, 0.5), -- (his size next to a standard 5-stud rig: pace)
	}
end

local function loadTracks(state)
	if state.tracksLoaded or not state.model:IsDescendantOf(Workspace) then return end
	state.tracksLoaded = true
	local animator = state.humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	for name, animId in pairs(ANIM) do
		local a = Instance.new("Animation")
		a.AnimationId = animId
		local ok, track = pcall(function() return animator:LoadAnimation(a) end)
		if ok and track then
			track.Looped = true
			track.Priority = if name == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
			state.tracks[name] = track
		end
	end
end

local function play(state, name, rate: number?)
	loadTracks(state)
	if state.playing ~= name then
		state.playing = name
		for key, track in pairs(state.tracks) do
			if key == name then track:Play(0.2) elseif track.IsPlaying then track:Stop(0.2) end
		end
	end
	-- (the playback speed follows the move speed; frozen far-away trainers stay at 0)
	local track = state.tracks[name]
	if track and not state.frozen then
		local want = rate or 1
		if math.abs(track.Speed - want) > 0.03 then track:AdjustSpeed(want) end
	end
end

local function destroyTrainer(state)
	if state.aura then pcall(function() state.aura:Destroy() end) end
	if state.model then state.model:Destroy() end
end

-- (prompt 25) what he says when you equip him: his line, or his lines one after another (the later ones once a session)
local saidOnce = {}
local function sayLine(state)
	local trainer = Trainers.ById[state.id]
	local lines = trainer.lines or (trainer.line and { trainer.line })
	if not lines then return end
	bubble(state, lines[1], true)
	for i = 2, #lines do
		if not saidOnce[state.id .. i] then
			saidOnce[state.id .. i] = true
			task.delay((i - 1) * (Trainers.BubbleSeconds + 0.4), function()
				if state.model.Parent then bubble(state, lines[i], true) end
			end)
		end
	end
end
local synced = {} -- [player] = true after the first sync (the trainers you join with don't talk)

-- (prompt 34) waits until a trainer's template has fully replicated (TrainerService's "Parts" count; a few seconds at
-- most): a clone made earlier missed body parts, hair and gear
local function waitForTemplate(entry: string)
	local id = Trainers.ParseEntry(entry)
	local template = id and templates:FindFirstChild(id)
	local want = template and template:GetAttribute("Parts")
	local function count()
		local n = 0
		for _, d in ipairs(template:GetDescendants()) do
			if d:IsA("BasePart") then n += 1 end
		end
		return n
	end
	local waited = 0
	while type(want) == "number" and count() < want and waited < 8 do
		waited += task.wait(0.2)
	end
end

-- (prompt 29) other players' trainers: Settings "Others' Trainers" On and Low Graphics Off
local function othersShown(): boolean
	local settings = ClientData.IsLoaded() and ClientData.Get().settings or {}
	return settings.otherTrainers ~= "Off" and settings.lowGraphics ~= "On"
end
local function lowGraphics(): boolean
	local settings = ClientData.IsLoaded() and ClientData.Get().settings or {}
	return settings.lowGraphics == "On"
end
local RARITY_RANK = {}
for index, rarity in ipairs(Trainers.Rarities) do RARITY_RANK[rarity.id] = index end
-- the one that follows: the rarest equipped (Golden first on a tie, then the first slot)
local function bestEntry(list: { string }): string?
	local best, bestRank = nil, -1
	for _, entry in ipairs(list) do
		local id, golden = Trainers.ParseEntry(entry)
		local rank = (RARITY_RANK[Trainers.ById[id].rarity] or 0) * 2 + (if golden then 1 else 0)
		if rank > bestRank then best, bestRank = entry, rank end
	end
	return best
end
-- your other equipped trainers: portrait chips in the boosts row (tap: the name and the boost)
local portraitChips = {}
local function showPortraits(list: { string }, shown: string?)
	local index = 0
	for _, entry in ipairs(list) do
		if entry ~= shown then
			index += 1
			local id, golden = Trainers.ParseEntry(entry)
			local trainer = Trainers.ById[id]
			local chip = portraitChips[index]
			if not chip then
				chip = HudBottom.ImageChip("", 10 + index)
				local slot = index
				chip:OnTap(function()
					local t = portraitChips[slot] and portraitChips[slot].trainer
					if t then Notify.Toast(t.name, t.perkText, "users", Theme.Colors.Gold, "trainerchip" .. slot) end
				end)
				portraitChips[index] = chip
			end
			chip.trainer = trainer
			chip:SetTrainer(trainer.id) -- (owner, 22 Oct: his 3D rig, no picture)
			chip:SetText(if golden then "GOLD" else "")
			chip:SetVisible(true)
		end
	end
	for i = index + 1, #portraitChips do portraitChips[i]:SetVisible(false) end
end

local syncToken = {} -- [player] = the newest sync (an older one still waiting for templates gives way)
local function sync(player)
	local all = {}
	local value = player:GetAttribute("Trainers")
	if type(value) == "string" then
		for entry in string.gmatch(value, "[^,]+") do
			if Trainers.ParseEntry(entry) then table.insert(all, entry) end
		end
	end
	-- (prompt 29) only the rarest one follows in the world; none of another player's when they're switched off
	local best = bestEntry(all)
	local list = if best and (player == localPlayer or othersShown()) then { best } else {}
	if player == localPlayer then showPortraits(all, best) end
	local token = (syncToken[player] or 0) + 1
	syncToken[player] = token
	for _, entry in ipairs(list) do waitForTemplate(entry) end
	if syncToken[player] ~= token or not player.Parent then return end
	local current = followers[player] or {}
	local nextSet = {}
	for slot, entry in ipairs(list) do
		local existing = current[slot]
		if existing and existing.entry == entry then
			nextSet[slot] = existing
			current[slot] = nil
		else
			nextSet[slot] = makeTrainer(entry, slot)
			-- (a trainer you just equipped says his line; one moved to another slot doesn't)
			local moved = false
			for _, old in pairs(current) do
				if old.entry == entry then moved = true end
			end
			if player == localPlayer and synced[player] and nextSet[slot] and not moved then sayLine(nextSet[slot]) end
		end
	end
	for _, state in pairs(current) do destroyTrainer(state) end
	followers[player] = next(nextSet) and nextSet or nil
	synced[player] = true
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
	synced[player] = nil
	syncToken[player] = nil
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
		else
			-- every few reps a cheer: a clap or a fist pump ("come on!"), taking turns
			if w.count % Trainers.CheerEvery == 0 then
				state.cheerTurn += 1
				if state.cheerTurn % 2 == 0 then state.clapUntil = now + Trainers.ClapSeconds else state.pumpUntil = now + Trainers.ClapSeconds end
			end
			if now - state.lastCheer > Trainers.CheerCooldown and rng:NextNumber() < Trainers.CheerChance then
				bubble(state, Trainers.Cheers[rng:NextInteger(1, #Trainers.Cheers)])
				state.lastCheer = now
			end
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
	-- (slot 1 right, 2 left; prompt 24: slots 3 and 4 a row further back)
	local side = if state.slot % 2 == 1 then 1 else -1
	local behind = Trainers.FollowBehind + (if state.slot > 2 then 3.5 else 0)
	local spot = root.Position - root.CFrame.LookVector * behind + root.CFrame.RightVector * side * Trainers.FollowSide
	return spot, root.Position + root.CFrame.LookVector * 6
end

-- (prompt 29) step() sets where he should stand (state.goal); apply() moves him there, eased (alpha < 1) or at once
local function place(state, position: Vector3, face: Vector3)
	local flat = Vector3.new(face.X, position.Y, face.Z)
	if (flat - position).Magnitude < 0.1 then flat = position + state.root.CFrame.LookVector end
	state.goal = CFrame.lookAt(position, flat)
end
local function apply(state, alpha: number)
	local goal = state.goal
	if not goal then return end
	local current = state.root.CFrame
	if (current.Position - goal.Position).Magnitude < 0.002 and current.LookVector:Dot(goal.LookVector) > 0.99999 then return end
	local target = if alpha >= 1 then goal else current:Lerp(goal, alpha)
	state.model:PivotTo(target * current:ToObjectSpace(state.model:GetPivot()))
end

local function step(player, state, root: BasePart, dt: number, now: number)
	local target, face = targetOf(player, state, root)
	local floor = floorAt(target) or (root.Position.Y - 3)
	target = Vector3.new(target.X, floor + state.rootHeight, target.Z)
	local pos = state.position
	local popped = false
	if not pos or (pos - target).Magnitude > Trainers.TeleportDistance or now - state.lastProgress > Trainers.StuckSeconds then
		pos = target
		state.lastProgress = now
		popped = true
		state.snap = true -- (a pop jumps, never eases across the map)
	end
	local before = pos
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
	-- (prompt 25) Volta bounces on her toes while she stands
	local bob = if state.style == "boxer" and state.playing == "Idle" and not state.frozen
		then math.abs(math.sin(now * 6.5 + state.phase)) * 0.13 * (state.scale or 1) else 0
	place(state, pos + Vector3.new(0, bob, 0), face)
	-- the speed he really moved (studs a second, flat), smoothed over a few frames; a pop doesn't count
	local moved = if popped or not moving then 0 else ((pos - before) * Vector3.new(1, 0, 1)).Magnitude / math.max(dt, 1 / 240)
	state.speed = (state.speed or 0) + (moved - (state.speed or 0)) * math.min(dt * 10, 1)
	local speed = state.speed
	local scale = state.scale or 1
	if speed < IDLE_BELOW then
		play(state, "Idle")
	elseif speed < RUN_FROM or not state.tracks.Run then
		play(state, "Walk", math.clamp(speed / (WALK_PACE * scale), 0.3, 2.5))
	else
		play(state, "Run", math.clamp(speed / (RUN_PACE * scale), 0.5, 2.5))
	end
end

-- the clap (arms forward, hands meeting), before physics so it wins over the idle animation (as EmoteClient)
local function clap(state, now)
	local t = now * 9
	local swing = math.rad(25) * (0.5 + 0.5 * math.sin(t))
	for _, side in ipairs({ { "Right", 1 }, { "Left", -1 } }) do
		local arm = state.model:FindFirstChild(side[1] .. "UpperArm")
		local shoulder = arm and arm:FindFirstChild(side[1] .. "Shoulder")
		if shoulder and (shoulder:IsA("Motor6D") or shoulder:IsA("AnimationConstraint")) then
			shoulder.Transform = CFrame.Angles(math.rad(80), 0, 0) * CFrame.Angles(0, 0, side[2] * -swing)
		end
		local lower = state.model:FindFirstChild(side[1] .. "LowerArm")
		local elbow = lower and lower:FindFirstChild(side[1] .. "Elbow")
		if elbow and (elbow:IsA("Motor6D") or elbow:IsA("AnimationConstraint")) then elbow.Transform = CFrame.Angles(math.rad(35), 0, 0) end
	end
end
-- joints by name (cached per trainer: no lookups every frame)
local JOINT_PATH = {
	Waist = { "UpperTorso", "Waist" }, Neck = { "Head", "Neck" },
	RShoulder = { "RightUpperArm", "RightShoulder" }, LShoulder = { "LeftUpperArm", "LeftShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" }, LElbow = { "LeftLowerArm", "LeftElbow" },
	RWrist = { "RightHand", "RightWrist" }, LWrist = { "LeftHand", "LeftWrist" },
}
local function joints(state)
	if state.joints then return state.joints end
	local found = {}
	for key, path in pairs(JOINT_PATH) do
		local part = state.model:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		-- (Motor6D, or the AnimationConstraint joints of newer rigs: both have Transform)
		if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then found[key] = motor end
	end
	state.joints = found
	return found
end
local rad, Angles = math.rad, CFrame.Angles

-- (prompt 25) a PoseData pose on his joints, w = 0..1 (Atlas's double biceps; the same math as Shared.PoseApply, with the
-- joints looked up once)
local poseData = nil
local function strike(state, poseName: string, w: number)
	poseData = poseData or require(ReplicatedStorage:WaitForChild("PoseData"))
	local pose = poseData[poseName]
	if not pose then return end
	if not state.poseJoints then
		state.poseJoints = {}
		for _, joint in ipairs(state.model:GetDescendants()) do
			if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and joint.Name ~= "Root" then state.poseJoints[joint.Name] = joint end
		end
	end
	for name, angles in pairs(pose) do
		local joint = state.poseJoints[name]
		if joint then
			local q = joint.C0.Rotation
			joint.Transform = CFrame.identity:Lerp(q:Inverse() * Angles(rad(angles[1]), rad(angles[2]), rad(angles[3])) * q, w)
		end
	end
end

-- "come on!": the right fist pumps up twice, the left fist at the hip
local function fistPump(state, now)
	local j = joints(state)
	local up = 0.5 + 0.5 * math.sin(now * 12)
	if j.RShoulder then j.RShoulder.Transform = Angles(rad(150 + 15 * up), 0, rad(-10)) end
	if j.RElbow then j.RElbow.Transform = Angles(rad(40 + 50 * (1 - up)), 0, 0) end
	if j.LShoulder then j.LShoulder.Transform = Angles(rad(10), 0, rad(10)) end
	if j.LElbow then j.LElbow.Transform = Angles(rad(70), 0, 0) end
	if j.Waist then j.Waist.Transform = Angles(rad(-4 * up), 0, 0) end
end

-- the coach idle: breathing, a slow weight shift and his stance
local function coachIdle(state, now)
	local j = joints(state)
	local t = now + state.phase
	local breath = math.sin(t * 2.1)          -- ~3 s a breath
	local shift = math.sin(t * 0.45)          -- a slow sway from one foot to the other
	if j.Waist then j.Waist.Transform = Angles(rad(-1.5 - 1.5 * breath), rad(3 * shift), rad(1.5 * shift)) end
	if j.Neck then j.Neck.Transform = Angles(rad(2 * breath), rad(8 * math.sin(t * 0.3)), 0) end
	local lift = rad(2.5 * breath) -- the shoulders rise with each breath
	local style = state.style
	if style == "chalk" then
		-- Duke: hands on his hips; every CHALK_EVERY s he claps the chalk off his hands (a puff), then cracks his neck
		local cycle = math.floor(t / CHALK_EVERY)
		local into = t - cycle * CHALK_EVERY
		if into < 1.2 then
			if state.chalkCycle ~= cycle then
				state.chalkCycle = cycle
				if state.aura and state.aura.Burst then pcall(function() state.aura:Burst("chalk") end) end
			end
			clap(state, now)
			return
		elseif into < 2.6 then
			local k = (into - 1.2) / 1.4
			local tilt = if k < 0.5 then -math.sin(k * 2 * math.pi) else math.sin((k - 0.5) * 2 * math.pi)
			if j.Neck then j.Neck.Transform = Angles(rad(-4), 0, rad(22 * tilt)) end
		end
		style = "hips"
	elseif style == "boxer" then
		-- Volta: guard up, quick jabs left and right, a twist of the waist with each (the bounce is in step)
		local beat = (t * 2.2) % 2
		local right = beat < 1
		local punch = math.max(0, 1 - math.abs((beat % 1) - 0.2) / 0.2) -- (a quick out and back at the start of each beat)
		local function arm(shoulder, elbow, side, out)
			if shoulder then shoulder.Transform = Angles(rad(55 + 33 * out), 0, rad(side * (-28 + 20 * out))) end
			if elbow then elbow.Transform = Angles(rad(115 - 105 * out), 0, 0) end
		end
		arm(j.RShoulder, j.RElbow, 1, if right then punch else 0)
		arm(j.LShoulder, j.LElbow, -1, if right then 0 else punch)
		if j.Waist then j.Waist.Transform = Angles(rad(-4), rad((if right then -1 else 1) * 10 * punch), 0) end
		if j.Neck then j.Neck.Transform = Angles(rad(6), 0, 0) end
		return
	elseif style == "watch" then
		-- The Shadow: arms crossed, his head slowly turning to watch you
		local character = localPlayer.Character
		local head = character and character:FindFirstChild("Head")
		local want = 0
		if head and head:IsA("BasePart") then
			local rel = state.root.CFrame:PointToObjectSpace(head.Position)
			want = math.clamp(math.atan2(-rel.X, -rel.Z), rad(-60), rad(60))
		end
		local dt = math.min(now - (state.lookAt or now), 0.1)
		state.lookAt = now
		state.look += (want - state.look) * math.min(dt * 1.2, 1)
		if j.Neck then j.Neck.Transform = Angles(rad(-3), state.look, 0) end
		style = "crossed"
		if j.Waist then j.Waist.Transform = Angles(rad(-1.5 - 1.5 * breath), 0, 0) end
	elseif style == "flex" then
		-- Atlas: hands on his hips; every FLEX_EVERY s a slow front double biceps (FLEX_HOLD s, blended in and out)
		local into = t % FLEX_EVERY
		if into < FLEX_HOLD then
			local w = math.min(into / 0.5, 1, (FLEX_HOLD - into) / 0.5)
			w = w * w * (3 - 2 * w)
			if w > 0.98 then
				strike(state, "FrontDoubleBiceps", 1)
				return
			end
			-- (blending: the hips stance under it, the pose on top)
			strike(state, "FrontDoubleBiceps", w)
			return
		end
		style = "hips"
	end
	if style == "crossed" then
		-- forearms folded across the chest, each hand in front of the other side (right over left); angles found by
		-- solving the joint chain for those hand spots on the trainer rig
		if j.RShoulder then j.RShoulder.Transform = Angles(rad(65) + lift, rad(30), rad(-60)) end
		if j.LShoulder then j.LShoulder.Transform = Angles(rad(55) + lift, rad(-30), rad(60)) end
		if j.RElbow then j.RElbow.Transform = Angles(rad(40), rad(60), 0) end
		if j.LElbow then j.LElbow.Transform = Angles(rad(40), 0, 0) end
	elseif style == "clipboard" then
		-- reading the clipboard in his right hand, left hand on the hip
		if j.RShoulder then j.RShoulder.Transform = Angles(rad(40) + lift, rad(-15), 0) end
		if j.RElbow then j.RElbow.Transform = Angles(rad(70), 0, 0) end
		if j.LShoulder then j.LShoulder.Transform = Angles(lift, 0, rad(-28)) end
		if j.LElbow then j.LElbow.Transform = Angles(rad(85), rad(40), 0) end
		if j.Neck then j.Neck.Transform = Angles(rad(-14 + 2 * breath), rad(-6), 0) end
	else -- hands on the hips (the bottle in the left hand)
		if j.RShoulder then j.RShoulder.Transform = Angles(lift, 0, rad(28)) end
		if j.LShoulder then j.LShoulder.Transform = Angles(lift, 0, rad(-28)) end
		if j.RElbow then j.RElbow.Transform = Angles(rad(85), rad(-40), 0) end
		if j.LElbow then j.LElbow.Transform = Angles(rad(85), rad(40), 0) end
	end
end

RunService.Stepped:Connect(function()
	local now = os.clock()
	for _, list in pairs(followers) do
		for _, state in pairs(list) do
			if state.model.Parent and not state.frozen and not state.offscreen then
				if now < state.clapUntil then
					clap(state, now)
				elseif now < state.pumpUntil then
					fistPump(state, now)
				elseif state.playing == "Idle" then
					coachIdle(state, now)
				end
			end
		end
	end
end)

local filterAt, machineAt = 0, 0
local othersWere, lowNow = true, false
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	if now - filterAt > 1 then
		filterAt = now
		refreshFilter()
		-- (prompt 29) Settings "Others' Trainers" / Low Graphics changed: other players' trainers come or go
		local shown = othersShown()
		if shown ~= othersWere then
			othersWere = shown
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= localPlayer then task.spawn(sync, other) end
			end
		end
		lowNow = lowGraphics()
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
					state.goal = nil
					state.model.Parent = folder
				end
				-- (prompt 29) stepped OWN_HZ / OTHER_HZ times a second, eased toward his spot every frame in between
				local own = player == localPlayer
				state.acc = (state.acc or 0) + dt
				if not state.goal or state.acc >= 1 / (if own then OWN_HZ else OTHER_HZ) then
					step(player, state, root, state.acc, now)
					state.acc = 0
					if camera then
						local _, onScreen = camera:WorldToViewportPoint(state.root.Position)
						state.offscreen = not onScreen
					end
				end
				local fromEye = (state.root.Position - eye).Magnitude
				apply(state, if state.snap or (not own and fromEye > SNAP_BEYOND) then 1 else 1 - math.exp(-dt * 20))
				state.snap = nil
				-- (prompt 24/25) the rarity aura of the rare ones (Shared.VFX.TrainerAura; any other name is an AuraVFX preset);
				-- prompt 29: only within AURA_RANGE studs of the camera and never on Low Graphics
				local auraOn = state.auraName ~= nil and not lowNow and fromEye <= AURA_RANGE
				if auraOn and not state.aura then
					if TrainerAura.Presets[state.auraName] then
						local ok, handle = pcall(TrainerAura.Build, state.model, state.auraName)
						if ok and handle then state.aura = handle end
					else
						local ok, handle = pcall(AuraVFX.Build, state.model, state.auraName)
						if ok and handle then
							state.aura = handle
							pcall(function() handle:SetPower(0.15) end)
						end
					end
				elseif not auraOn and state.aura then
					pcall(function() state.aura:Destroy() end)
					state.aura = nil
				end
				if state.aura and state.aura.Update and not state.frozen and not state.offscreen then state.aura:Update(now) end
				-- other players' trainers far away stand still: no animation, no pose (owner, 14 Oct: performance)
				local far = player ~= localPlayer and (root.Position - eye).Magnitude > Trainers.FarAnimation
				if far ~= (state.frozen == true) then
					state.frozen = far
					if state.aura then pcall(function() state.aura:SetLOD(if far then 1 else 0) end) end
					for _, track in pairs(state.tracks) do
						if far then track:AdjustSpeed(0) else track:AdjustSpeed(1) end
					end
				end
			elseif state.model.Parent then
				state.model.Parent = nil
				state.playing = nil
			end
		end
	end
end)
