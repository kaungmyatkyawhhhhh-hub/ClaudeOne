-- ArmWrestleClient: the arm wrestling animation, on every client (owner, 9 Oct). Both wrestlers (players on the stools,
-- or the practice opponent) lean in with the right elbow on their pad and the hands clasped above the middle of the
-- table, the free hand on the peg. During the match the clasped hands swing toward the loser's table side with the
-- server's meter (the table's AwMeter attribute) and shake with the strain; at the end the winner slams the arm down,
-- holds it, then pumps the fist. Poses are written to the joints' Transform after the Animator (PreSimulation), so the
-- sitting legs keep the normal sit animation; the practice opponent (an anchored-root NPC) gets its sitting legs here.
-- Cheap on slow devices (owner runs ~20 FPS): nothing runs unless someone is at the table and the table is within
-- Config ArmWrestle.AnimateDistance of the camera; joints are cached per character; no searches per frame.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Social")).ArmWrestle

local tbl = Workspace:WaitForChild("ArmWrestleTable", 60)
if not tbl then return end

local UP = Vector3.yAxis
local rad = math.rad
-- table geometry (tools/builders/ArmWrestleTable): the padded top's surface is 3.225 above TableSpot, the elbow pads
-- 0.75 toward each player, the pegs 0.75 to each side of the centre line
local CENTER = Config.TableSpot + Vector3.new(0, 3.225, 0)
local ELBOW_UP = 0.33 -- elbow joint above the surface (on the pad)
local GRIP_ABOVE_SHOULDER = 0.15 -- the clasped hands this far above the wrestlers' shoulders (upright)
local PAD_OUT = 0.75
local PEG_OUT, PEG_UP = 0.75, 0.33
local LEFT_ELBOW = Vector3.new(0.8, 0.3, 1.15) -- the free arm's elbow: left, up, back toward the player
local WAIST = { -14, 0, 0 } -- lean in (degrees about the lower torso's axes)
local NECK = { -14, 0, 0 } -- look down at the hands
local HIP, KNEE = { 90, 0, 0 }, { -90, 0, 0 } -- the practice opponent's sitting legs
local ARM_JOINTS = { "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist" }
local LEG_JOINTS = { "RightHip", "RightKnee", "LeftHip", "LeftKnee" }

local stools = {}
for index = 1, 2 do stools[index] = tbl:WaitForChild("Stool" .. index, 30) end
if not (stools[1] and stools[2]) then return end

-- each side's frame: from its stool toward the table (look = -Z, right = +X)
local frames = {}
for index = 1, 2 do
	local from = Vector3.new(stools[index].Position.X, CENTER.Y, stools[index].Position.Z)
	frames[index] = CFrame.lookAt(CENTER, CENTER + (CENTER - from).Unit)
end
-- + angle = toward seat 1's left (the meter's +1 side: seat 1 pins seat 2's hand there)
local PIN_DIR = -frames[1].RightVector

local rookies = {} -- [side] = model
local function trackRookie(model)
	local side = model:GetAttribute("ArmWrestleSide")
	if side == 1 or side == 2 then rookies[side] = model end
end
for _, model in ipairs(CollectionService:GetTagged("ArmWrestleRookie")) do trackRookie(model) end
CollectionService:GetInstanceAddedSignal("ArmWrestleRookie"):Connect(trackRookie)
CollectionService:GetInstanceRemovedSignal("ArmWrestleRookie"):Connect(function(model)
	for side, m in pairs(rookies) do if m == model then rookies[side] = nil end end
end)

------------------------------------------------------------------------
-- Rigs
------------------------------------------------------------------------
local rigs = {} -- [character] = { joints = { [name] = joint }, root, hand, forearm }

local function rigOf(character)
	local rig = rigs[character]
	if rig and rig.joints.RightShoulder and rig.joints.RightShoulder.Parent then return rig end
	local joints = {}
	for _, d in ipairs(character:GetDescendants()) do
		-- (rigs made from a HumanoidDescription use AnimationConstraints: same C0 / C1 / Transform)
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then joints[d.Name] = d end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and joints.Root and joints.Waist and joints.RightShoulder and joints.RightElbow and joints.RightWrist and joints.LeftShoulder and joints.LeftElbow and joints.LeftWrist) then
		return nil
	end
	-- arm length: shoulder -> elbow -> wrist -> middle of the hand
	local hand = character:FindFirstChild("RightHand")
	local armLength = (joints.RightShoulder.C1.Position - joints.RightElbow.C0.Position).Magnitude
		+ (joints.RightElbow.C1.Position - joints.RightWrist.C0.Position).Magnitude
		+ (hand and hand:IsA("BasePart") and hand.Size.Y * 0.5 or 0.3)
	rig = { joints = joints, root = root, armLength = armLength }
	rigs[character] = rig
	return rig
end

local function release(character)
	local rig = rigs[character]
	rigs[character] = nil
	if not rig then return end
	for _, name in ipairs(ARM_JOINTS) do
		local joint = rig.joints[name]
		if joint and joint.Parent then joint.Transform = CFrame.identity end
	end
	for _, name in ipairs(LEG_JOINTS) do
		local joint = rig.joints[name]
		if joint and joint.Parent then joint.Transform = CFrame.identity end
	end
end

------------------------------------------------------------------------
-- Pose math
------------------------------------------------------------------------
-- rotation about the joint in the PARENT part's axes (same as PoseController / PoseApply)
local function local3(joint, a)
	local q = joint.C0.Rotation
	return q:Inverse() * CFrame.Angles(rad(a[1]), rad(a[2]), rad(a[3])) * q
end

-- where the joint's child part ends up for a Transform
local function child(parentCFrame, joint, transform)
	return parentCFrame * joint.C0 * transform * joint.C1:Inverse()
end

-- the Transform that turns the child part to the world rotation `want`
local function toward(parentCFrame, joint, want)
	return (parentCFrame * joint.C0).Rotation:Inverse() * want * joint.C1.Rotation
end

-- a limb's world rotation: its +Y runs from `to` back to `from` (arms hang along -Y), `side` steers its +X
local function limb(from, to, side)
	local y = (from - to)
	if y.Magnitude < 1e-3 then y = UP else y = y.Unit end
	local x = side - y * side:Dot(y)
	if x.Magnitude < 1e-3 then x = y:Cross(Vector3.zAxis) end
	x = x.Unit
	return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end

-- aims the upper arm at `elbowAt` and the forearm + hand at `handAt`
local function arm(rig, torso, prefix, elbowAt, handAt, side)
	local j = rig.joints
	local shoulder, elbow, wrist = j[prefix .. "Shoulder"], j[prefix .. "Elbow"], j[prefix .. "Wrist"]
	local from = (torso * shoulder.C0).Position
	local t1 = toward(torso, shoulder, limb(from, elbowAt, side))
	shoulder.Transform = t1
	local upper = child(torso, shoulder, t1)
	local elbowPos = (upper * elbow.C0).Position
	local fore = limb(elbowPos, handAt, side)
	local t2 = toward(upper, elbow, fore)
	elbow.Transform = t2
	local lower = child(upper, elbow, t2)
	wrist.Transform = toward(lower, wrist, fore)
end

------------------------------------------------------------------------
-- The match
------------------------------------------------------------------------
local angle = 0 -- degrees, smoothed; + toward seat 1's left
local resultAt = 0
local lastState = "idle"
local posed = {} -- [character] = true (this frame)

-- Pass 1: the body (rookie legs, lean, head). Returns the rig and its UpperTorso CFrame.
local function body(character, side, isRookie, state, now)
	local rig = rigOf(character)
	if not rig then return nil, nil end
	local j = rig.joints
	if isRookie then
		for _, name in ipairs({ "RightHip", "LeftHip" }) do if j[name] then j[name].Transform = local3(j[name], HIP) end end
		for _, name in ipairs({ "RightKnee", "LeftKnee" }) do if j[name] then j[name].Transform = local3(j[name], KNEE) end end
	end
	local lower = child(rig.root.CFrame, j.Root, isRookie and CFrame.identity or j.Root.Transform)
	local strain = state == "live" and math.sin(now * 31 + side) * 1.2 or 0
	local waist = local3(j.Waist, { WAIST[1] + strain, WAIST[2], WAIST[3] })
	j.Waist.Transform = waist
	if j.Neck then j.Neck.Transform = local3(j.Neck, NECK) end
	posed[character] = true
	return rig, child(lower, j.Waist, waist)
end

-- Pass 2: the arms. `grip` = where the clasped hands are this frame (shared by both wrestlers).
local function arms(rig, torso, side, state, winner, now, grip)
	local j = rig.joints
	local f = frames[side]
	local left = -f.RightVector
	local toPlayer = -f.LookVector
	-- the elbow goes toward its pad; small players can't reach it and keep it just above the table edge
	local elbowAt = CENTER + toPlayer * PAD_OUT + UP * ELBOW_UP
	local handAt = grip
	if state == "result" and winner == side and now - resultAt > 0.9 then
		-- fist pump: the upper arm out and up, the forearm straight up, a little bounce
		local shoulderPos = (torso * j.RightShoulder.C0).Position
		local bounce = math.abs(math.sin((now - resultAt) * 7)) * 0.15
		elbowAt = shoulderPos + UP * (0.55 + bounce) + f.RightVector * 0.6 - toPlayer * 0.1
		handAt = elbowAt + UP * 1.2
	end
	arm(rig, torso, "Right", elbowAt, handAt, f.RightVector)
	-- the free hand grips the peg on that side
	local leftElbow = CENTER + left * LEFT_ELBOW.X + UP * LEFT_ELBOW.Y + toPlayer * LEFT_ELBOW.Z
	local peg = CENTER + left * PEG_OUT + UP * PEG_UP
	arm(rig, torso, "Left", leftElbow, peg, f.RightVector)
end

local found = { {}, {} } -- this frame's wrestlers: { rig, torso }

local wrestlers = {} -- last frame's characters
local camera = Workspace.CurrentCamera

RunService.PreSimulation:Connect(function(dt)
	local state = tbl:GetAttribute("AwState") or "idle"
	local c1 = stools[1].Occupant
	local c2 = stools[2].Occupant
	local someone = c1 or c2 or rookies[1] or rookies[2]
	camera = Workspace.CurrentCamera
	local near = camera and (camera.CFrame.Position - CENTER).Magnitude <= Config.AnimateDistance
	if not someone or not near then
		if next(wrestlers) then
			for character in pairs(wrestlers) do release(character) end
			table.clear(wrestlers)
		end
		return
	end

	local now = os.clock()
	if state ~= lastState then
		if state == "result" then resultAt = now end
		lastState = state
	end
	local winner = tbl:GetAttribute("AwWinner") or 0
	local target, rate = 0, 6
	if state == "live" then
		target = (tbl:GetAttribute("AwMeter") or 0) * Config.LiveAngle + math.sin(now * 37) * 1.5
		rate = 10
	elseif state == "result" then
		target = winner == 1 and Config.PinAngle or (winner == 2 and -Config.PinAngle or 0)
		rate = 18
	end
	angle += (target - angle) * (1 - math.exp(-rate * dt))

	table.clear(posed)
	local shoulderY, count = 0, 0
	local meet = CENTER -- where the hands meet over the centre line (moved toward the shorter arm)
	for side = 1, 2 do
		local occupant = stools[side].Occupant
		local character = occupant and occupant.Parent
		local rig, torso = nil, nil
		if character then
			rig, torso = body(character, side, false, state, now)
		elseif rookies[side] and rookies[side].Parent then
			rig, torso = body(rookies[side], side, true, state, now)
		end
		found[side].rig, found[side].torso = rig, torso
		if rig then
			local shoulder = (torso * rig.joints.RightShoulder.C0).Position
			found[side].shoulder = shoulder
			shoulderY += shoulder.Y
			count += 1
		end
	end
	if count == 2 then
		-- split the gap between the shoulders by arm length, so a short arm and a long arm both reach the grip
		local a, b = found[1], found[2]
		local s1 = Vector3.new(a.shoulder.X, CENTER.Y, a.shoulder.Z)
		local s2 = Vector3.new(b.shoulder.X, CENTER.Y, b.shoulder.Z)
		local share = a.rig.armLength / (a.rig.armLength + b.rig.armLength)
		local along = s1:Lerp(s2, share)
		local axis = frames[1].LookVector
		meet = CENTER + axis * (along - CENTER):Dot(axis)
	end
	if count > 0 then
		-- the hands meet a little above the wrestlers' shoulders (averaged, so a small player and a tall one meet
		-- halfway) and swing around a pivot just above the table toward the losing side
		local pivot = meet + UP * ELBOW_UP
		local radius = math.max(shoulderY / count + GRIP_ABOVE_SHOULDER - pivot.Y, 0.5)
		local a = rad(angle)
		local grip = pivot + UP * (radius * math.cos(a)) + PIN_DIR * (radius * math.sin(a))
		for side = 1, 2 do
			local item = found[side]
			if item.rig then arms(item.rig, item.torso, side, state, winner, now, grip) end
		end
	end
	for character in pairs(wrestlers) do
		if not posed[character] then release(character) end
	end
	-- swap the two sets (no new tables per frame)
	wrestlers, posed = posed, wrestlers
end)
