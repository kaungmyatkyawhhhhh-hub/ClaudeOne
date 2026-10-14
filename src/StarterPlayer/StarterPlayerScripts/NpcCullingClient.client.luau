-- NpcCullingClient: ONE manager for every NPC's visuals on this client (owner, 14 Oct: performance, mobile first). It visits
-- the NPCs in Workspace.NPCs round-robin, at most PER_FRAME a frame (no spikes), each one as often as its tier needs:
--   Near (< 40 studs and on screen)    every 0.1 s: everything on (animations, particles at full rate).
--   Mid  (40 - 100 studs, on screen)   every 0.5 s: animations on, particles at MID_RATE of their rate.
--   Far  (> 100 studs, or off screen)  every 2 s:   animations frozen on their current pose, particles / beams / trails off.
-- Off screen = Camera:WorldToViewportPoint outside the view by more than MARGIN (behind the camera counts as off screen).
-- (Name tags and the RIVAL tag already hide beyond 40 studs on their own: MaxDistance. The body LOD (plain body beyond 60
-- studs) is MuscleClient's. Personal trainers are drawn by TrainerFollowClient, which only draws other players' trainers
-- nearby and never freezes yours. An arm wrestling opponent, tag ArmWrestleRookie, is always Near.)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local NEAR, FAR = 40, 100     -- studs from the camera
local MARGIN = 0.15           -- share of the viewport outside it that still counts as on screen
local INTERVAL = { Near = 0.1, Mid = 0.5, Far = 2 }
local PER_FRAME = 4           -- NPCs updated per frame at most
local MID_RATE = 0.35         -- particle rate share on Mid
local RESCAN = 1              -- seconds between looks for new / removed NPCs
local ALWAYS_NEAR = { "ArmWrestleRookie" } -- tags: never culled (you're with them)

local entries = {}  -- [model] = { model, root, humanoid, tier, nextAt, frozen = { [track] = speed }, fx = { [emitter] = { rate, enabled } } }
local order = {}    -- the round-robin list
local cursor = 0
local lastScan = 0

local function scan()
	local npcs = Workspace:FindFirstChild("NPCs")
	local seen = {}
	for _, model in ipairs(npcs and npcs:GetChildren() or {}) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if humanoid and root and root:IsA("BasePart") then
				seen[model] = true
				if not entries[model] then
					entries[model] = { model = model, root = root, humanoid = humanoid, tier = "Near", nextAt = 0, frozen = {}, fx = {} }
				end
			end
		end
	end
	-- gone (streamed out, a legend that left): forget it (nothing to restore on a model that isn't here)
	for model in pairs(entries) do
		if not seen[model] or not model.Parent then entries[model] = nil end
	end
	table.clear(order)
	for model in pairs(entries) do table.insert(order, model) end
end

local function tierOf(entry, camera: Camera): string
	for _, tag in ipairs(ALWAYS_NEAR) do
		if CollectionService:HasTag(entry.model, tag) then return "Near" end
	end
	local position = entry.root.Position
	local distance = (position - camera.CFrame.Position).Magnitude
	if distance > FAR then return "Far" end
	local point, _ = camera:WorldToViewportPoint(position)
	local view = camera.ViewportSize
	local mx, my = view.X * MARGIN, view.Y * MARGIN
	local onScreen = point.Z > 0 and point.X > -mx and point.X < view.X + mx and point.Y > -my and point.Y < view.Y + my
	if not onScreen and distance > 12 then return "Far" end -- (right next to you it stays: you turn back to it at once)
	return if distance < NEAR then "Near" else "Mid"
end

-- Animations: frozen on Far (speed 0, the pose they're in), back to their speed otherwise.
local function applyAnimations(entry, tier: string)
	local animator = entry.humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	if tier == "Far" then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if not entry.frozen[track] and track.Speed ~= 0 then
				entry.frozen[track] = track.Speed
				track:AdjustSpeed(0)
			end
		end
	else
		for track, speed in pairs(entry.frozen) do
			if track.IsPlaying then track:AdjustSpeed(speed) end
			entry.frozen[track] = nil
		end
	end
end

-- Particles / beams / trails: full on Near, a share of the rate on Mid, off on Far.
local function applyEffects(entry, tier: string)
	for _, item in ipairs(entry.model:GetDescendants()) do
		local isEmitter = item:IsA("ParticleEmitter")
		if isEmitter or item:IsA("Beam") or item:IsA("Trail") then
			local saved = entry.fx[item]
			if not saved then
				saved = { rate = isEmitter and (item :: ParticleEmitter).Rate or 0, enabled = (item :: any).Enabled }
				entry.fx[item] = saved
			end
			if tier == "Far" then
				(item :: any).Enabled = false
			else
				(item :: any).Enabled = saved.enabled
				if isEmitter then (item :: ParticleEmitter).Rate = if tier == "Mid" then saved.rate * MID_RATE else saved.rate end
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local now = os.clock()
	if now - lastScan > RESCAN then
		lastScan = now
		scan()
	end
	local count = #order
	if count == 0 then return end
	local visited, updated = 0, 0
	while visited < count and updated < PER_FRAME do
		cursor = cursor % count + 1
		visited += 1
		local entry = entries[order[cursor]]
		if entry and entry.model.Parent and now >= entry.nextAt then
			updated += 1
			local tier = tierOf(entry, camera)
			if tier ~= entry.tier or tier ~= "Near" then
				applyAnimations(entry, tier)
				applyEffects(entry, tier)
			end
			entry.tier = tier
			entry.nextAt = now + INTERVAL[tier]
		end
	end
end)

-- Studio check: the Workspace attribute NpcCullingStats (any value) prints how many NPCs are in each tier
if RunService:IsStudio() then
	Workspace:GetAttributeChangedSignal("NpcCullingStats"):Connect(function()
		local tiers = { Near = 0, Mid = 0, Far = 0 }
		for _, entry in pairs(entries) do tiers[entry.tier] += 1 end
		print(string.format("[NpcCulling] near %d, mid %d, far %d", tiers.Near, tiers.Mid, tiers.Far))
	end)
end
