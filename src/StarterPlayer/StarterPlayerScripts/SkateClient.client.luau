-- SkateClient: the Skate button in the right column, shown only outdoors in the town hub (Config.Town). Tapping it
-- asks the server for the board (SkateService validates and builds it). Riding (momentum, carving, braking, ollies) and the
-- skater pose are below; steering is the normal movement controls, so phones use the usual thumbstick.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared.Config.Town)
local Theme = require(Shared.UI.Theme)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Horizontal = Enum.FillDirection.Horizontal

local button = Theme.Button("Secondary", {
	Name = "Skate",
	Size = UDim2.fromOffset(132, Theme.MinTouch), -- a small button at the top of the column (not a full-width panel)
	Visible = false,
}, {
	Theme.Pad("S"),
	Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center),
})
button:SetAttribute("KeepWidth", true)
RightColumn.Add(button, 0, true) -- top of the idle group: hidden while lifting
local label = Theme.Text({ LayoutOrder = 1, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 1, 0), Parent = button })

local function skating()
	return player:GetAttribute("Skating") == true
end

local function refresh()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local outdoors = root ~= nil and not UIBus.MenuOpen and Town.IsOutdoors(root.Position)
	button.Visible = outdoors or skating()
	label.Text = skating() and "Stop skating" or "Skate"
end

button.Activated:Connect(function()
	Remotes.PlayerAction:FireServer("Skate", not skating())
	Audio.PlayUI("Click")
end)
player:GetAttributeChangedSignal("Skating"):Connect(refresh)

task.spawn(function()
	while true do
		task.wait(0.5)
		refresh()
	end
end)

local function angleTo(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

------------------------------------------------------------------------
-- RIDING (my own board). The board has momentum: holding a direction pushes you up to the top speed and the board CARVES
-- toward it (it can't snap around: the faster you go, the wider the turn); letting go coasts and slowly rolls to a stop;
-- holding the opposite way brakes. Jump = ollie. Downhill speeds you up, uphill slows you down, a wall stops you.
-- How: the Humanoid stands still (WalkSpeed 0) but still reports what the player asks for (MoveDirection, from keys, the
-- phone thumbstick or a gamepad, whatever Roblox's control scripts use); a LinearVelocity on the root rolls the board along its
-- heading (horizontal only, so gravity and jumping stay the Humanoid's).
------------------------------------------------------------------------
local RIDE = {
	Push = 16,      -- studs/s² while pushing
	Coast = 2.2,    -- studs/s² rolling friction when you let go
	Brake = 26,     -- studs/s² holding the opposite way
	Slope = 0.9,    -- how much hills speed you up / slow you down
	TurnSlow = 7,   -- radians/s the board can turn when nearly stopped
	TurnFast = 2.1, -- radians/s at top speed (wide carves)
	MinSpeed = 0.4,
}

local ride = nil -- { heading, speed, walkSpeed, slowFor, pushing, mover }

-- the direction the player is asking for, flat in the world (nil when the stick / keys are idle)
local function inputDirection(humanoid): Vector3?
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if move.Magnitude < 0.15 then return nil end
	return move.Unit
end

local function headingVector(heading: number): Vector3
	return Vector3.new(-math.sin(heading), 0, -math.cos(heading))
end

local function startRide(humanoid, root)
	local look = root.CFrame.LookVector
	ride = {
		heading = math.atan2(-look.X, -look.Z),
		speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude,
		walkSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else 16,
		slowFor = 0,
		pushing = false,
	}
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	local attachment = Instance.new("Attachment")
	attachment.Name = "SkateAttachment"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "SkateMover"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.xAxis
	mover.SecondaryTangentAxis = Vector3.zAxis
	mover.MaxForce = 60000
	mover.PlaneVelocity = Vector2.zero
	mover.Parent = root
	ride.mover, ride.attachment = mover, attachment
end

local function stopRide()
	if not ride then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = ride.walkSpeed
	end
	if ride.mover then ride.mover:Destroy() end
	if ride.attachment then ride.attachment:Destroy() end
	ride = nil
	player:SetAttribute("SkatePushing", nil)
end

RunService:BindToRenderStep("SkateRide", Enum.RenderPriority.Input.Value + 1, function(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not skating() or not humanoid or not root or humanoid.Health <= 0 then
		stopRide()
		return
	end
	if not ride or not ride.mover.Parent then
		stopRide()
		startRide(humanoid, root)
	end
	dt = math.min(dt, 0.1)
	local top = player:GetAttribute("SkateSpeed")
	top = if type(top) == "number" then top else 32
	local want = inputDirection(humanoid)
	local forward = headingVector(ride.heading)
	ride.pushing = false
	if want then
		local agree = want:Dot(forward)
		if agree < -0.55 and ride.speed > 3 then
			-- holding the opposite way: brake (the board keeps pointing where it goes)
			ride.speed = math.max(ride.speed - RIDE.Brake * dt, 0)
		else
			-- carve toward the input: the turn rate falls with speed
			local rate = RIDE.TurnSlow + (RIDE.TurnFast - RIDE.TurnSlow) * math.clamp(ride.speed / top, 0, 1)
			local delta = angleTo(ride.heading, math.atan2(-want.X, -want.Z))
			ride.heading += math.clamp(delta, -rate * dt, rate * dt)
			if agree > 0.3 and ride.speed < top then
				ride.speed = math.min(ride.speed + RIDE.Push * dt, top)
				ride.pushing = true
			end
		end
	else
		ride.speed = math.max(ride.speed - RIDE.Coast * dt, 0)
	end
	-- hills: going down speeds you up, climbing slows you down
	local velocity = root.AssemblyLinearVelocity
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		ride.speed = math.clamp(ride.speed - velocity.Y * RIDE.Slope * dt, 0, top * 1.35)
	end
	-- a wall (or anything solid) stops the board instead of letting it push on forever
	forward = headingVector(ride.heading)
	local actual = (velocity * Vector3.new(1, 0, 1)):Dot(forward)
	if ride.speed > 6 and actual < ride.speed * 0.45 then
		ride.slowFor += dt
		if ride.slowFor > 0.25 then
			ride.speed = math.max(actual, 0)
			ride.slowFor = 0
		end
	else
		ride.slowFor = 0
	end
	-- apply: face the board's heading and roll at our speed
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, ride.heading, 0)
	if ride.speed < RIDE.MinSpeed then ride.speed = 0 end
	humanoid.WalkSpeed = 0
	local roll = forward * ride.speed
	ride.mover.PlaneVelocity = Vector2.new(roll.X, roll.Z)
	if (player:GetAttribute("SkatePushing") == true) ~= ride.pushing then
		player:SetAttribute("SkatePushing", ride.pushing or nil)
	end
end)

------------------------------------------------------------------------
-- THE SKATER'S POSE, for every player you can see on a board (only on this client; set on the joints' Transforms after the
-- run animation, like the emote poses). Regular stance: body side-on to the board (chest to the right of travel, left foot
-- forward), knees bent and deeper at speed, arms out for balance, head looking down the board. Pushing: the back foot steps
-- off and sweeps the ground. Carving: the rider leans onto the toes or heels and the board tilts with them. Ollie: the nose
-- pops up and the knees tuck. Joint signs (measured in Studio): Root/Waist +X leans back, hip +X brings the thigh forward,
-- knee -X bends, shoulder +Z (right) / -Z (left) raises the arm to the side, elbow +X bends.
------------------------------------------------------------------------
local rad, Angles = math.rad, CFrame.Angles
local JOINTS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RHip = { "RightUpperLeg", "RightHip" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
	RAnkle = { "RightFoot", "RightAnkle" },
	LAnkle = { "LeftFoot", "LeftAnkle" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	RWrist = { "RightHand", "RightWrist" },
	LWrist = { "LeftHand", "LeftWrist" },
}
local function set(character, key, cframe)
	local spec = JOINTS[key]
	local part = character:FindFirstChild(spec[1])
	local m = part and part:FindFirstChild(spec[2])
	if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then m.Transform = cframe end
end
local function boardJoint(character)
	local board = character:FindFirstChild("Skateboard")
	local deck = board and board:FindFirstChild("Deck")
	return deck and deck:FindFirstChild("BoardJoint")
end

local poses = setmetatable({}, { __mode = "k" }) -- [character] = smoothed values (weak: a character that is gone must not be kept alive)
local function follow(value, target, rate, dt)
	return value + (target - value) * math.min(1, dt * rate)
end

local function pose(other, character, root, dt)
	local s = poses[character]
	if not s then
		s = { speed = 0, carve = 0, crouch = 0, push = 0, pushPhase = 0, air = 0, pop = 0, lastYaw = nil }
		poses[character] = s
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = (velocity * Vector3.new(1, 0, 1)).Magnitude
	-- turn rate from the heading change (AutoRotate is off while skating, so angular velocity isn't reliable)
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local turn = if s.lastYaw then angleTo(s.lastYaw, yaw) / math.max(dt, 1 / 240) else 0
	s.lastYaw = yaw
	local top = other:GetAttribute("SkateSpeed")
	top = if type(top) == "number" then top else 32
	-- pushing: told by the rider's own client, or guessed from speeding up (other players)
	local pushing = other:GetAttribute("SkatePushing") == true
	if other ~= player and not pushing then
		pushing = speed > s.speed + 4 * dt and speed < top * 0.97 and speed > 0.5
	end
	s.speed = follow(s.speed, speed, 6, dt)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local airborne = (humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air) or math.abs(velocity.Y) > 6
	s.air = follow(s.air, if airborne then 1 else 0, 10, dt)
	-- the ollie pop: a quick nose-up when the board leaves the ground going up
	if airborne and velocity.Y > 8 and s.pop <= 0 then s.pop = 1 end
	s.pop = math.max(s.pop - dt * 3.2, 0)
	s.push = follow(s.push, if pushing and not airborne then 1 else 0, 8, dt)
	if s.push > 0.05 then s.pushPhase = (s.pushPhase + dt * 1.6) % 1 end
	s.carve = follow(s.carve, math.clamp(-turn * 0.16, -1, 1) * math.clamp(speed / 12, 0, 1), 7, dt)
	s.crouch = follow(s.crouch, math.clamp(speed / top, 0, 1), 3, dt)

	local tuck = s.air * 0.6
	local knee = rad(22) + rad(16) * s.crouch + rad(38) * tuck
	local flex = knee * 0.5
	-- the pelvis drops so the feet stay on the deck while the knees bend
	local thigh = character:FindFirstChild("LeftUpperLeg")
	local shin = character:FindFirstChild("LeftLowerLeg")
	local l1 = if thigh then thigh.Size.Y else 1.3
	local l2 = if shin then shin.Size.Y else 1.1
	local drop = l1 * (1 - math.cos(flex)) + l2 * (1 - math.cos(knee - flex))
	-- carving leans onto the toes (turning toward the chest, i.e. right) or onto the heels
	local lean = s.carve * rad(16)
	set(character, "Root", CFrame.new(0, -drop, 0) * Angles(0, rad(-90), 0) * Angles(-lean - rad(6), 0, 0)) -- (= rootPitch below)
	-- the upper body twists back a little toward the nose; the head looks down the board
	set(character, "Waist", Angles(rad(4), rad(18), 0))
	set(character, "Neck", Angles(0, rad(62), 0))
	-- legs: spread along the board (left/front foot over the front truck, right/back foot over the tail)
	local spread = rad(13)
	local rootPitch = -lean - rad(6)
	local frontHip = flex + lean + rad(6)
	set(character, "LHip", Angles(frontHip, 0, -spread))
	-- the back leg pushes: steps down beside the board, sweeps back along the ground, comes back up
	local phase = s.pushPhase * 2 * math.pi
	local sweep = math.sin(phase)
	local down = math.max(0, math.sin(phase + 0.6))
	local backHip = flex + lean + rad(6) - s.push * (rad(18) * sweep + rad(8))
	local backKnee = knee * (1 - s.push * 0.75 * down)
	local frontKnee = knee + s.push * rad(20) * down -- the front knee bends more while the back foot reaches down
	set(character, "RHip", Angles(backHip, 0, spread + s.push * rad(6)))
	set(character, "RKnee", Angles(-backKnee, 0, 0))
	set(character, "LKnee", Angles(-frontKnee, 0, 0))
	-- feet flat on the deck: the ankles undo the pelvis, hip and knee angles (they all turn the same way)
	set(character, "LAnkle", Angles(-(rootPitch + frontHip - frontKnee), 0, 0))
	set(character, "RAnkle", Angles(-(rootPitch + backHip - backKnee), 0, 0))
	-- arms out for balance (more in turns and in the air), elbows soft
	local balance = rad(38) + math.abs(s.carve) * rad(18) + s.air * rad(22)
	set(character, "LShoulder", Angles(rad(8), 0, -balance - s.carve * rad(10)))
	set(character, "RShoulder", Angles(-rad(8), 0, balance - s.carve * rad(10)))
	set(character, "LElbow", Angles(rad(18), 0, 0))
	set(character, "RElbow", Angles(rad(18), 0, 0))
	set(character, "LWrist", CFrame.identity)
	set(character, "RWrist", CFrame.identity)
	-- the board tilts with the carve and pops its nose on an ollie
	local joint = boardJoint(character)
	if joint then
		local pop = if s.pop > 0 then math.sin((1 - s.pop) * math.pi) else 0
		joint.Transform = CFrame.new(0, s.air * 0.08, 0) * Angles(lean * 0.6, 0, rad(16) * pop)
	end
end

local function clearPose(character)
	poses[character] = nil
	for key in pairs(JOINTS) do set(character, key, CFrame.identity) end
end

-- The speed zoom is an OFFSET we add to whatever field of view the camera has (menus, pose punches, machines change it too):
-- we only ever add or take back our own part, and never pull the camera to a remembered value.
local fovOffset = 0
RunService.Stepped:Connect(function(_, dt)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if other:GetAttribute("Skating") == true and character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then pose(other, character, root, dt) end
		elseif character and poses[character] then
			clearPose(character)
		end
	end
	-- a little more field of view at speed for me
	local camera = workspace.CurrentCamera
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if camera then
		local want = 0
		if mine and skating() then
			local speed = (mine.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			want = math.clamp((speed - 16) * 0.4, 0, 8)
		end
		local nextOffset = fovOffset + (want - fovOffset) * math.min(1, dt * 4)
		if math.abs(nextOffset - fovOffset) > 0.001 then
			camera.FieldOfView += nextOffset - fovOffset
			fovOffset = nextOffset
		end
	end
end)
