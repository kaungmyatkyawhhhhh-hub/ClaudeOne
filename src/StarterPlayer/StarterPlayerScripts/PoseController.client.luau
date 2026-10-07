-- GYM ARC procedural poser (LocalScript, StarterPlayerScripts). No Animation Editor / publishing needed.
-- Any character with attribute "Pose" = "<PoseName>" (set by the SERVER) is posed on every client.
-- Pose = "" / nil -> released back to normal animations.
--  * While posing, the default animations are off: your own character's Animate script is disabled (and re-enabled on
--    release), and every animation track on a posing character is held at weight 0, so nothing fights the pose.
--  * Every joint is written each frame (joints a pose doesn't list go to rest), after the Animator (PreSimulation).
--  * Studio: Workspace attribute "PoseDebug" = true prints the joints found / missing and any playing tracks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local PoseData = require(ReplicatedStorage:WaitForChild("PoseData"))
local BLEND_IN, BLEND_OUT = 0.35, 0.25
local JOINTS = {"Root","Waist","Neck","RightShoulder","RightElbow","RightWrist","LeftShoulder","LeftElbow","LeftWrist",
	"RightHip","RightKnee","RightAnkle","LeftHip","LeftKnee","LeftAnkle"}
local REST = { 0, 0, 0 }
local player = Players.LocalPlayer

local active = {} -- [character] = {motors=, pose=, w=, target=, version=, animate=}

local function findMotors(char)
	local m = {}
	for _, d in ipairs(char:GetDescendants()) do
		-- (rigs made from a HumanoidDescription use AnimationConstraints instead of Motor6Ds: same C0 and Transform)
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then m[d.Name] = d end
	end
	return m
end

local function debugOn()
	return RunService:IsStudio() and workspace:GetAttribute("PoseDebug") == true
end

local function poseCFrame(motor, ang)
	-- rotation is defined in the parent part's axes -> convert into the joint (C0) frame
	local q = motor.C0.Rotation
	return q:Inverse() * CFrame.Angles(math.rad(ang[1]), math.rad(ang[2]), math.rad(ang[3])) * q
end

local function animatorOf(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum and hum:FindFirstChildOfClass("Animator")
end

local function stopTracks(char)
	local animator = animatorOf(char)
	if animator then
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0.15) end
	end
end

-- your own character's default Animate script is switched off while posing (other players' run on their own clients)
local function setAnimate(char, st, on)
	if char ~= player.Character then return end
	local animate = char:FindFirstChild("Animate")
	if not animate or not animate:IsA("LocalScript") then return end
	if not on then
		if st.animate == nil then st.animate = animate.Enabled end
		animate.Enabled = false
	elseif st.animate ~= nil then
		animate.Enabled = st.animate
		st.animate = nil
	end
end

local function refresh(char)
	local name = char:GetAttribute("Pose")
	local st = active[char]
	if name and name ~= "" and PoseData[name] then
		if not st then st = {motors = findMotors(char), w = 0, version = char:GetAttribute("BodyVersion")}; active[char] = st end
		st.pose = PoseData[name]; st.target = 1
		setAnimate(char, st, false)
		stopTracks(char)
		if debugOn() then
			local found, missing = {}, {}
			for _, jn in ipairs(JOINTS) do table.insert(st.motors[jn] and found or missing, jn) end
			print("[PoseController] " .. char.Name .. " pose " .. name .. " | joints found: " .. table.concat(found, ", ")
				.. " | missing: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
		end
	elseif st then
		st.target = 0
	end
end

local function watch(char)
	char:GetAttributeChangedSignal("Pose"):Connect(function() refresh(char) end)
	char.AncestryChanged:Connect(function(_, parent) if not parent then active[char] = nil end end)
	refresh(char)
end

local function onPlayer(p)
	if p.Character then watch(p.Character) end
	p.CharacterAdded:Connect(watch)
end
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerAdded:Connect(onPlayer)
-- NPCs: tag them "Poser" (CollectionService) or call watch() on them from your NPC code
for _, npc in ipairs(CollectionService:GetTagged("Poser")) do watch(npc) end
CollectionService:GetInstanceAddedSignal("Poser"):Connect(watch)

-- write Transforms after the Animator each frame (PreSimulation runs after animations are stepped)
local lastDebug = 0
RunService.PreSimulation:Connect(function(dt)
	for char, st in pairs(active) do
		-- the body was swapped (outfit change, Growth Spurt rebuild): the joints we cached are gone, find the new ones
		local version = char:GetAttribute("BodyVersion")
		local root = st.motors.Root
		if version ~= st.version or (root and root.Parent == nil) then
			st.motors = findMotors(char)
			st.version = version
		end
		local speed = st.target == 1 and (1 / BLEND_IN) or (1 / BLEND_OUT)
		st.w = math.clamp(st.w + (st.target == 1 and 1 or -1) * dt * speed, 0, 1)
		local a = st.w * st.w * (3 - 2 * st.w) -- smoothstep
		-- while posing, any animation that starts anyway (another player's Animate, an emote) is held at weight 0
		-- (remembered, and put back to full weight when the pose ends)
		local animator = animatorOf(char)
		if st.target == 1 and animator then
			st.muted = st.muted or {}
			for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
				if t.WeightTarget > 0 then
					t:AdjustWeight(0, 0.1)
					st.muted[t] = true
				end
			end
		elseif st.target == 0 and st.muted then
			for t in pairs(st.muted) do
				if t.IsPlaying then t:AdjustWeight(1, BLEND_OUT) end
			end
			st.muted = nil
		end
		for _, jn in ipairs(JOINTS) do
			local m = st.motors[jn]
			if m then
				local ang = (st.pose and st.pose[jn]) or REST
				m.Transform = m.Transform:Lerp(poseCFrame(m, ang), a)
			end
		end
		if debugOn() and char == player.Character and os.clock() - lastDebug > 2 then
			lastDebug = os.clock()
			local animator = animatorOf(char)
			local names = {}
			for _, t in ipairs(animator and animator:GetPlayingAnimationTracks() or {}) do
				table.insert(names, t.Name .. string.format("(%.2f)", t.WeightCurrent))
			end
			print(string.format("[PoseController] weight %.2f, playing tracks: %s", a, #names > 0 and table.concat(names, ", ") or "none"))
		end
		if st.target == 0 and st.w <= 0 then
			setAnimate(char, st, true)
			active[char] = nil
		end
	end
end)
