-- GYM ARC procedural poser (LocalScript, StarterPlayerScripts). No Animation Editor / publishing needed.
-- Any character with attribute "Pose" = "<PoseName>" (set by the SERVER) is posed on every client.
-- Pose = "" / nil -> released back to normal animations.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PoseData = require(ReplicatedStorage:WaitForChild("PoseData"))
local BLEND_IN, BLEND_OUT = 0.35, 0.25
local JOINTS = {"Root","Waist","Neck","RightShoulder","RightElbow","RightWrist","LeftShoulder","LeftElbow","LeftWrist",
	"RightHip","RightKnee","RightAnkle","LeftHip","LeftKnee","LeftAnkle"}

local active = {} -- [character] = {motors=, pose=, w=, target=, from=}

local function findMotors(char)
	local m = {}
	for _, d in ipairs(char:GetDescendants()) do
		-- (rigs made from a HumanoidDescription use AnimationConstraints instead of Motor6Ds: same C0 and Transform)
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then m[d.Name] = d end
	end
	return m
end

local function poseCFrame(motor, ang)
	-- rotation is defined in the parent part's axes -> convert into the joint (C0) frame
	local q = motor.C0.Rotation
	return q:Inverse() * CFrame.Angles(math.rad(ang[1]), math.rad(ang[2]), math.rad(ang[3])) * q
end

local function stopTracks(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0.15) end
	end
end

local function refresh(char)
	local name = char:GetAttribute("Pose")
	local st = active[char]
	if name and name ~= "" and PoseData[name] then
		if not st then st = {motors = findMotors(char), w = 0, version = char:GetAttribute("BodyVersion")}; active[char] = st end
		st.pose = PoseData[name]; st.target = 1
		stopTracks(char)
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
local CollectionService = game:GetService("CollectionService")
for _, npc in ipairs(CollectionService:GetTagged("Poser")) do watch(npc) end
CollectionService:GetInstanceAddedSignal("Poser"):Connect(watch)

-- write Transforms after the Animator each frame
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
		for _, jn in ipairs(JOINTS) do
			local m = st.motors[jn]
			local ang = st.pose and st.pose[jn]
			if m and ang then
				m.Transform = m.Transform:Lerp(poseCFrame(m, ang), a)
			end
		end
		if st.target == 0 and st.w <= 0 then active[char] = nil end
	end
end)
