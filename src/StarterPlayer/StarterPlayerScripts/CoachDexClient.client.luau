-- CoachDexClient (owner, 14-15 Oct): Coach Dex on YOUR screen. He has no animation track (GymGoerService.makeCoach); this
-- poses him on his joints every frame (Motor6D.Transform, client only, so each player sees him look at themselves):
--   * leaning on his counter: the waist bent forward, forearms on the counter top, head up toward the room
--   * never fully still: breathing (chest and shoulders rise), a slow weight shift, and every ~10 s a shoulder roll /
--     neck crack
--   * head tracking: while you're within LOOK studs his head (and a little of his upper body) turns to stare at you and
--     follows you, clamped to MAX_YAW left / right and MAX_PITCH up / down; out of range it eases back over ~0.5 s
--   * a quick nod when you come within NOD studs; a pointing "listen up" with his right arm when you talk to him
--   * culled: further than FAR studs from the camera or off screen, he isn't posed (he keeps his last pose)
-- (prompt 51) the PUMP SHOP's shopkeeper (tag "PumpShopClerk", PumpShopService) gets the same lean, idle and look; he
-- points when you open the shop at his counter (its ShopPrompt).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- degrees: the lean on the counter, fists down on it (tuned in Studio, 15 Oct: a deeper lean showed the top of the torso mesh)
local POSE = { Lean = 14, Shoulder = 38, Elbow = 18 }
local LOOK, NOD = 15, 8         -- studs
local MAX_YAW, MAX_PITCH = 70, 30
local TRACK_SPEED, RETURN_SPEED = 6, 6 -- exponential smoothing per second (back to forward in ~0.5 s)
local FAR = 100                 -- studs from the camera: not posed further away
local NOD_TIME, POINT_TIME = 0.6, 1.8
local rad, Angles = math.rad, CFrame.Angles

local TAGS = { "Coach", "PumpShopClerk" }
local npcs = {} -- [model] = { model, root, joints, yaw, pitch, near, nodAt, pointAt, nextFlex, flexAt, flexKind, phase }

local function joint(model, part, name)
	local p = model:FindFirstChild(part)
	local m = p and p:FindFirstChild(name)
	-- (a Motor6D, or an AnimationConstraint on the newer avatar joints: both have Transform)
	return if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then m else nil
end

-- his joints (found again whenever the server rebuilds his body: ApplyBody replaces the parts and their joints)
local function findJoints(model)
	return {
		Waist = joint(model, "UpperTorso", "Waist"), Neck = joint(model, "Head", "Neck"),
		RS = joint(model, "RightUpperArm", "RightShoulder"), LS = joint(model, "LeftUpperArm", "LeftShoulder"),
		RE = joint(model, "RightLowerArm", "RightElbow"), LE = joint(model, "LeftLowerArm", "LeftElbow"),
		RH = joint(model, "RightUpperLeg", "RightHip"), LH = joint(model, "LeftUpperLeg", "LeftHip"),
	}
end

local function track(model)
	if not model:IsA("Model") or npcs[model] then return end
	local root = model:FindFirstChild("HumanoidRootPart") or model:WaitForChild("HumanoidRootPart", 10)
	if not root then return end
	npcs[model] = {
		model = model, root = root, joints = {},
		yaw = 0, pitch = 0, near = false, nodAt = -math.huge, pointAt = -math.huge, flexAt = -math.huge,
		nextFlex = os.clock() + 8 + math.random() * 4, flexKind = 1, phase = math.random() * 10,
	}
end
for _, tag in ipairs(TAGS) do
	for _, model in ipairs(CollectionService:GetTagged(tag)) do task.spawn(track, model) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model) task.spawn(track, model) end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model) npcs[model] = nil end)
end

-- talking to him (or opening the PUMP SHOP at the shopkeeper's counter): the pointing gesture
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local atCounter = prompt.Name == "ShopPrompt" and prompt.Parent ~= nil and CollectionService:HasTag(prompt.Parent, "PumpShopCounter")
	for model, c in pairs(npcs) do
		if prompt:IsDescendantOf(model) or (atCounter and CollectionService:HasTag(model, "PumpShopClerk")) then c.pointAt = os.clock() end
	end
end)

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
-- 0 -> 1 -> 0 over a gesture's time (eased in and out)
local function envelope(since: number, length: number): number
	if since < 0 or since > length then return 0 end
	local t = since / length
	return smoothstep(math.min(t / 0.25, 1)) * smoothstep(math.min((1 - t) / 0.3, 1))
end

local function set(m: any, cf: CFrame)
	if m then m.Transform = cf end
end

local function pose(c, dt: number, camera: Camera)
	if not c.model.Parent then return end
	local rootPos = c.root.Position
	-- culled: far away or off screen
	if (camera.CFrame.Position - rootPos).Magnitude > FAR then return end
	local _, onScreen = camera:WorldToViewportPoint(rootPos + Vector3.new(0, 2, 0))
	if not onScreen then return end

	local now = os.clock()
	local t = now + c.phase
	if not c.joints.Waist or not c.joints.Waist.Parent or not c.joints.Neck or not c.joints.Neck.Parent then c.joints = findJoints(c.model) end
	local root = c.model:FindFirstChild("HumanoidRootPart")
	if root and root ~= c.root then c.root = root end
	local J = c.joints

	-- where you are, in his own space
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local targetYaw, targetPitch, speed = 0, 0, RETURN_SPEED
	if head then
		local coachHead = c.model:FindFirstChild("Head")
		local from = if coachHead then coachHead.Position else rootPos + Vector3.new(0, 3, 0)
		local offset = head.Position - from
		local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		local near = flatDistance <= LOOK
		if near then
			local d = c.root.CFrame:VectorToObjectSpace(offset)
			targetYaw = math.clamp(math.deg(math.atan2(-d.X, -d.Z)), -MAX_YAW, MAX_YAW)
			targetPitch = math.clamp(math.deg(math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))), -MAX_PITCH, MAX_PITCH)
			speed = TRACK_SPEED
		end
		-- a nod when you come close
		local close = flatDistance <= NOD
		if close and not c.near then c.nodAt = now end
		c.near = close
	end
	local a = 1 - math.exp(-dt * speed)
	c.yaw += (targetYaw - c.yaw) * a
	c.pitch += (targetPitch - c.pitch) * a

	-- idle: breathing, a slow weight shift, now and then a shoulder roll / neck crack
	local breath = math.sin(t * 2.1)
	local shift = math.sin(t * 0.45)
	if now >= c.nextFlex then
		c.flexAt, c.flexKind = now, if c.flexKind == 1 then 2 else 1
		c.nextFlex = now + 9 + math.random() * 3
	end
	local flex = envelope(now - c.flexAt, 1.3)
	local roll = if c.flexKind == 1 then flex else 0       -- both shoulders up and back
	local crack = if c.flexKind == 2 then flex else 0      -- the head tips to one side and back
	local nod = envelope(now - c.nodAt, NOD_TIME)
	local point = envelope(now - c.pointAt, POINT_TIME)

	-- the lean, with a quarter of the turn in the upper body
	local lean = POSE.Lean - 1.5 * breath - 4 * roll
	set(J.Waist, Angles(rad(-lean), rad(c.yaw * 0.25 + 2 * shift), rad(1.5 * shift)))
	-- the head: up again against the lean, then the look, the nod and the neck crack
	local neckPitch = POSE.Lean * 0.75 + c.pitch - 16 * nod
	set(J.Neck, Angles(rad(neckPitch + breath), rad(c.yaw * 0.75), rad(14 * crack)))
	-- the arms on the counter (the shoulders lift with each breath and in the roll); the right one points while you talk
	local lift = 2 * breath + 10 * roll
	local rightShoulder = Angles(rad(POSE.Shoulder + lift), 0, rad(-4 * roll))
	local rightElbow = Angles(rad(POSE.Elbow), 0, 0)
	if point > 0 then
		rightShoulder = rightShoulder:Lerp(Angles(rad(POSE.Lean + 95), rad(c.yaw * 0.5), rad(8)), point)
		rightElbow = rightElbow:Lerp(Angles(rad(8), 0, 0), point)
	end
	set(J.RS, rightShoulder)
	set(J.RE, rightElbow)
	set(J.LS, Angles(rad(POSE.Shoulder + lift), 0, rad(4 * roll)))
	set(J.LE, Angles(rad(POSE.Elbow), 0, 0))
	-- the weight shift in the legs
	set(J.RH, Angles(0, 0, rad(1.5 * shift)))
	set(J.LH, Angles(0, 0, rad(1.5 * shift)))
end

RunService.Stepped:Connect(function(_, dt)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	for model, c in pairs(npcs) do
		if model.Parent then pose(c, dt, camera) else npcs[model] = nil end
	end
end)
