-- MachineClient: lift input, machine HUD, and all lifting game feel (motion, sounds,
-- gains, pump, particles). Effects play instantly on tap; the server validates and applies gains.
-- Reps run on their own at a slow pace; tapping (a tap anywhere that isn't a button, a click, Space) makes them faster and
-- fills the PUMP meter above the machine panel (full = PUMPED: x2 gains, faster reps, a glow). About 1 in 12 reps is a BIG REP (x3, gold).
-- Nobody is ever punished for not tapping.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- WaitForChild in short timed waits: waits as long as needed, never an "Infinite yield possible" warning
local function waitFor(parent: Instance, name: string): Instance
	local child = parent:FindFirstChild(name)
	while not child do
		child = parent:WaitForChild(name, 5)
	end
	return child
end

local Shared = waitFor(ReplicatedStorage, "Shared")
waitFor(Shared, "Config") -- (the requires below read Shared.Config; no local: this script is at Luau's 200 top-level locals)
local Machines = require(Shared.Config.Machines)
local Poses = require(Shared.Config.Poses)
local Muscles = require(Shared.Config.Muscles)
local Stamina = require(Shared.Config.Stamina)
local Gains = require(Shared.Config.Gains)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local CoachNotes = require(Shared.Config.CoachNotes)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local Audio = require(Shared.Audio)
local MuscleRig = require(Shared.MuscleRig)
local UIBus = require(Shared.UI.UIBus)
local Remotes = waitFor(ReplicatedStorage, "Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing

-- Game feel tuning
local FEEL = {
	Lower = 0.6,            -- seconds, ease-in-out
	Press = 0.35,           -- seconds, ease-out
	Hold = 0.1,             -- pause at lockout
	HeavyPerTier = 0.035,   -- each tier above the first is this much slower
	LowStamina = 0.4,       -- below this: arm shake + slower press
	LowPressMult = 1.4,
	ShakeDegrees = 3,
	SweatBelow = 0.25,
	BufferWindow = 0.25,    -- a tap this close to the end of a rep queues the next one
	HeavyTier = 7,          -- stronger FOV punch + plate jiggle from this tier up
	FovPunch = 1.2,         -- every rep: a small camera punch at lockout
	FovPunchHeavy = 2.5,
	FovPunchBig = 4,        -- BIG REP
	SetSize = 10,           -- "set complete" beat every this many reps
	SetBreak = 4,           -- seconds without a rep starts a new set
	BreathChance = 0.5,     -- soft exhale at lockout, only on heavy tiers or low stamina
	BreathMinGap = 2,       -- never on back-to-back reps
	ClankDeeperPerTier = 0.035,
	PumpPerRep = 0.02,
	PumpMax = 0.1,
	PumpBounce = 0.035,
	PumpHold = 1.5,         -- seconds before the pump starts to settle
	PumpDecay = 0.02,       -- per second
	NoteEvery = 3,          -- coach note changes at most every this many sets
}

local STAMINA_SEGMENTS = 10
local STAMINA_LOW = 0.15 -- segments turn soft light red below this
local SEGMENT_BACK = 0.85 -- empty segments: faint white

local PARTICLE_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local PARTICLE_DROP = "rbxasset://textures/particles/sparkles_main.dds"

local current = nil -- local session: { model, machine, reps, setsSinceNote, repEnd, queued, ... }

------------------------------------------------------------------------
-- Sounds
------------------------------------------------------------------------
-- All sounds go through Shared.Audio (Config.Sounds has every id). Machine sounds are 3D at the bar.
local function barOf(model)
	return model:FindFirstChild("Bar") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

------------------------------------------------------------------------
-- Rep motion (runs for every machine in use, so everyone sees everyone lift)
------------------------------------------------------------------------
local barRest = {}      -- [model] = racked bar CFrame
local plateOffsets = {} -- [plate] = offset from the racked bar
local repState = {}     -- [model] = { start, lower, press, hold, shake, tier, lockedOut }
local posed = {}        -- [model] = character currently posed

-- Heavier tiers are a little slower (capped, so tier 12 is still snappy); PUMPED reps are faster.
local function repDurations(tier, lowStamina, pumped)
	local heavy = 1 + FEEL.HeavyPerTier * math.min((tier or 1) - 1, 6)
	local speed = pumped and Gains.Pump.Speed or 1
	return FEEL.Lower * heavy * speed, FEEL.Press * heavy * speed * (lowStamina and FEEL.LowPressMult or 1), FEEL.Hold * speed
end

local function startRep(model, tier, lowStamina, pumped)
	local lower, press, hold = repDurations(tier, lowStamina, pumped)
	repState[model] = { start = os.clock(), lower = lower, press = press, hold = hold, shake = lowStamina, tier = tier or 1 }
	return lower + press + hold
end

-- Returns depth (0 = locked out, 1 = bar at chest) and the phase name.
local function repDepth(state, now)
	local t = now - state.start
	if t < state.lower then
		return TweenService:GetValue(t / state.lower, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), "lower"
	end
	t -= state.lower
	if t < state.press then
		return 1 - TweenService:GetValue(t / state.press, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), "press"
	end
	t -= state.press
	if t < state.hold then
		return 0, "hold"
	end
	return 0, "done"
end

-- Bar bookkeeping in one table (this script is near Luau's 200 top-level locals):
--   moving[model] = { part, ... }: the plates and rides that follow the bar (rebuilt when they change)
--   travel[model] = { low = CFrame, high = CFrame }: the lowest and highest the bar has been while someone lifts on it
--     (the gain popup keeps clear of the whole path, not just where the bar is at lockout)
--   near(position, distance): is it close enough to the camera to animate? (client performance, Machines.ClientCull)
local bars = { moving = {}, travel = {}, placed = {}, T = setmetatable({}, { __mode = "k" }), restSize = {} }
-- A joint's two frames (C0 on Part0, C1 on Part1), for Motor6Ds and for AnimationConstraints (newer rigs: their two
-- attachments); both move Part1 to Part0 * C0 * Transform * C1:Inverse().
function bars.c0(joint): CFrame
	if joint:IsA("Motor6D") then return joint.C0 end
	return joint.Attachment0 and joint.Attachment0.CFrame or CFrame.identity
end
function bars.c1(joint): CFrame
	if joint:IsA("Motor6D") then return joint.C1 end
	return joint.Attachment1 and joint.Attachment1.CFrame or CFrame.identity
end
function bars.near(position: Vector3, distance: number): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= distance
end
-- true when a point (with `margin` studs around it) is in front of the camera and inside the screen (a little beyond its
-- edges, so a lifter walking into view is already animated)
function bars.onScreen(position: Vector3, margin: number): boolean
	local camera = workspace.CurrentCamera
	if not camera then return true end
	local toPoint = position - camera.CFrame.Position
	if toPoint.Magnitude <= margin then return true end
	if toPoint:Dot(camera.CFrame.LookVector) < -margin then return false end
	local point = camera:WorldToViewportPoint(position)
	local size = camera.ViewportSize
	local slack = math.max(size.X, size.Y) * 0.25
	return point.X > -slack and point.X < size.X + slack and point.Y > -slack and point.Y < size.Y + slack
end

-- true when a body part has muscle meshes standing in for it (MuscleRig: "<part>Muscles..." in the MuscleMeshes folder): its
-- own size must not pump (it is hidden or covered, and every size change makes the muscle meshes re-process: 20+ ms a frame
-- while lifting, measured 8 Oct); the meshes pump themselves (the rep flash's pulse)
function bars.hasMuscleMesh(character, partName: string): boolean
	local folder = character:FindFirstChild("MuscleMeshes")
	if not folder then return false end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("MeshPart") and string.sub(child.Name, 1, #partName) == partName and not string.find(child.Name, "Stage$") then return true end
	end
	return false
end

-- every part of the plates (plate models, sleeves) rides with the bar
local function trackPlate(model, plate)
	if plate:IsA("BasePart") and barRest[model] then
		plateOffsets[plate] = barRest[model]:ToObjectSpace(plate.CFrame)
		bars.moving[model], bars.placed[model] = nil, nil
	end
end

local function loadPart(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	return model:FindFirstChild(machine and machine.load or "Bar")
end

-- (the bar and its plates move in one BulkMoveTo call, and not at all when the bar hasn't moved: a plate is ~10 parts)
local function placeBar(model, cframe)
	if bars.placed[model] == cframe then return end
	bars.placed[model] = cframe
	local bar = loadPart(model)
	local travel = bars.travel[model]
	if not travel then
		bars.travel[model] = { low = cframe, high = cframe }
	elseif cframe.Y < travel.low.Y then
		travel.low = cframe
	elseif cframe.Y > travel.high.Y then
		travel.high = cframe
	end
	local parts = bars.moving[model]
	if not parts then
		parts = {}
		for _, plate in ipairs(model.Plates:GetDescendants()) do
			if plateOffsets[plate] then table.insert(parts, plate) end
		end
		local rides = model:FindFirstChild("Rides")
		if rides then
			for _, part in ipairs(rides:GetDescendants()) do
				if plateOffsets[part] then table.insert(parts, part) end
			end
		end
		bars.moving[model] = parts
	end
	local list, cframes = { bar }, { cframe }
	for _, part in ipairs(parts) do
		local offset = plateOffsets[part]
		if offset and part.Parent then
			table.insert(list, part)
			table.insert(cframes, cframe * offset)
		end
	end
	workspace:BulkMoveTo(list, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Weight stack machines (pro gym): the selected blocks (1..StackCount, top down) and the pin rise with each rep.
local stackRest = {} -- [model] = { [part] = rest CFrame }
local function placeStack(model, depth)
	local rest = stackRest[model]
	if not rest then
		rest = {}
		for i = 1, model:GetAttribute("StackBlocks") or 12 do
			local block = model:FindFirstChild("StackBlock" .. i)
			if block then
				rest[block] = block.CFrame
				for _, child in ipairs(block:GetChildren()) do
					if child:IsA("BasePart") then rest[child] = child.CFrame end
				end
			end
		end
		local top = model:FindFirstChild("TopPlate")
		if top then rest[top] = top.CFrame end
		stackRest[model] = rest
	end
	local count = model:GetAttribute("StackCount") or 1
	local key = count + depth * 0.001
	if bars.placed[model] == key then return end
	bars.placed[model] = key
	local lift = Vector3.new(0, 1.6 * (1 - depth), 0)
	local list, cframes = {}, {}
	for part, cframe in pairs(rest) do
		local block = part.Parent and part.Parent.Name:match("^StackBlock(%d+)$") and part.Parent or part
		local index = tonumber(block.Name:match("^StackBlock(%d+)$") or "0")
		local lifted = part.Name == "TopPlate" or (index >= 1 and index <= count)
		table.insert(list, part)
		table.insert(cframes, lifted and (cframe + lift) or cframe)
	end
	workspace:BulkMoveTo(list, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Who is on a machine: a player (UserId attribute) or an NPC gym-goer ("Occupant" ObjectValue).
local function userCharacter(model)
	local userId = model:GetAttribute("UserId")
	local user = userId and Players:GetPlayerByUserId(userId)
	if user then return user.Character end
	local occupant = model:FindFirstChild("Occupant")
	return occupant and occupant:IsA("ObjectValue") and occupant.Value or nil
end

-- R15 joints by name: { part, joint } (a Motor6D, or an AnimationConstraint on newer avatars: both have Transform)
local JOINTS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	RHip = { "RightUpperLeg", "RightHip" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
	RAnkle = { "RightFoot", "RightAnkle" },
	LAnkle = { "LeftFoot", "LeftAnkle" },
}
local SIDES = { { "R", 1 }, { "L", -1 } }
local TWIST = math.rad(-90) -- turns the upper arm so the elbow bends up (overhead/back grips); measured in playtest
local rad, cos = math.rad, math.cos
local Angles = CFrame.Angles

local function setJoint(character, key, cframe)
	local spec = JOINTS[key]
	local part = character:FindFirstChild(spec[1])
	local motor = part and part:FindFirstChild(spec[2])
	if motor then motor.Transform = cframe end
	local record = bars.T[character]
	if not record then
		record = {}
		bars.T[character] = record
	end
	record[key] = cframe
end

local function resetPose(character)
	for key in pairs(JOINTS) do
		setJoint(character, key, CFrame.identity)
	end
end

local function limbLength(character, upper, lower)
	local u, l = character:FindFirstChild(upper), character:FindFirstChild(lower)
	return u and l and (u.Size.Y + l.Size.Y) or 2
end

-- Arms in the body's front plane (flex forward, then flare out), elbows bend forward.
local function frontArms(character, flex, flare, bend, jitter)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Shoulder", Angles(flex + jitter, 0, side[2] * flare))
		setJoint(character, side[1] .. "Elbow", Angles(bend - jitter * 0.5, 0, 0))
	end
end

-- Arms out to the sides with the upper arm twisted, so the elbows bend up/down.
local function sideArms(character, forward, raise, bend, jitter)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Shoulder", Angles(forward, 0, 0) * Angles(0, 0, side[2] * (raise + jitter)) * Angles(0, side[2] * TWIST, 0))
		setJoint(character, side[1] .. "Elbow", Angles(bend - jitter * 0.5, 0, 0))
	end
end

-- Knees bend `bend`, hips hinge `hinge`; the root drops so the feet stay planted.
local function lowerBody(character, bend, hinge)
	local legLength = limbLength(character, "RightUpperLeg", "RightLowerLeg") / 2
	local drop = 2 * legLength * (1 - cos(bend))
	setJoint(character, "Root", CFrame.new(0, -drop, 0) * Angles(-hinge, 0, 0))
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", Angles(bend + hinge, 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(-2 * bend, 0, 0))
		setJoint(character, side[1] .. "Ankle", Angles(bend, 0, 0))
	end
end

-- Two-joint leg IK: bends each leg (hip + knee, in the body's front plane) so its ankle reaches `target` (world), knees
-- pointing forward; works for every body size. ankle = extra ankle angle (toes).
-- lowerFrame = where the LowerTorso will be this frame (when the Root joint moves it too), else its current CFrame.
function bars.legIK(character, target: Vector3, ankle: number, lowerFrame: CFrame?)
	local lower = character:FindFirstChild("LowerTorso")
	if not lower then return end
	local frame = lowerFrame or lower.CFrame
	for _, side in ipairs(SIDES) do
		local long = side[1] == "R" and "Right" or "Left"
		local thigh, shin, foot = character:FindFirstChild(long .. "UpperLeg"), character:FindFirstChild(long .. "LowerLeg"), character:FindFirstChild(long .. "Foot")
		local hip = thigh and thigh:FindFirstChild(long .. "Hip")
		local knee = shin and shin:FindFirstChild(long .. "Knee")
		local ankleJoint = foot and foot:FindFirstChild(long .. "Ankle")
		if not (hip and knee and ankleJoint) then continue end
		local a = (bars.c1(hip).Position - bars.c0(knee).Position).Magnitude
		local b = (bars.c1(knee).Position - bars.c0(ankleJoint).Position).Magnitude
		local t = frame:PointToObjectSpace(target) - bars.c0(hip).Position
		local d = math.clamp(math.sqrt(t.Y * t.Y + t.Z * t.Z), math.abs(a - b) + 0.05, a + b - 0.01)
		local phi = math.atan2(-t.Z, -t.Y) -- from straight down toward the front
		local inner = math.acos(math.clamp((a * a + b * b - d * d) / (2 * a * b), -1, 1))
		local lift = math.acos(math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1))
		setJoint(character, side[1] .. "Hip", Angles(phi + lift, 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(-(math.pi - inner), 0, 0))
		setJoint(character, side[1] .. "Ankle", Angles(ankle, 0, 0))
	end
end

-- Machine parts that move with the lifter besides the bar, plates and stack (per pose, every frame; put back when they
-- leave): bars.props[pose](model, character), their rest CFrames in bars.propRest[model][part].
bars.props, bars.propRest = {}, {}
function bars.restOf(model, names)
	local rest = bars.propRest[model]
	if not rest then
		rest = {}
		bars.propRest[model] = rest
	end
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and table.find(names, part.Name) and not rest[part] then rest[part] = part.CFrame end
	end
	return rest
end
function bars.resetProps(model)
	for inst, rest in pairs(bars.propRest[model] or {}) do
		if inst.Parent then
			if inst:IsA("Model") then
				inst:PivotTo(rest)
			else
				inst.CFrame = rest
				if bars.restSize[inst] then inst.Size = bars.restSize[inst] end
			end
		end
	end
end

-- One function per pose. depth: 0 = top of the rep (lockout), 1 = the stretched end.
local POSE_ANIMS = {}

-- Bench: arms straight up at lockout; at the bottom upper arms flare out, forearms vertical.
POSE_ANIMS.BenchPress = function(character, d, jitter)
	frontArms(character, rad(90 * (1 - d)), rad(70 * d), rad(90 * d), jitter)
end
POSE_ANIMS.InclinePress = POSE_ANIMS.BenchPress

-- Overhead press: lockout straight overhead; bottom = bar at chin height, just in front.
-- (With raised arms, a negative "forward" angle moves the hands to the front.)
POSE_ANIMS.OverheadPress = function(character, d, jitter)
	sideArms(character, -rad(10 + 35 * d), rad(170 - 90 * d), rad(110 * d), jitter)
end

-- Squat: bar on the upper back, sit down until the thighs are about parallel.
POSE_ANIMS.Squat = function(character, d, jitter)
	lowerBody(character, rad(62 * d), 0)
	setJoint(character, "Waist", Angles(-rad(25 * d), 0, 0))
	sideArms(character, rad(10), rad(35), rad(125), jitter * 0.5)
end

-- Deadlift: hinge at the hips with soft knees; arms hang straight down.
POSE_ANIMS.Deadlift = function(character, d, jitter)
	local hinge, extra = rad(50 * d), rad(15 * d)
	lowerBody(character, rad(22 * d), hinge)
	setJoint(character, "Waist", Angles(-extra, 0, 0))
	frontArms(character, hinge + extra, rad(8), 0, jitter)
end

-- Barbell row: stay bent over; lockout = bar at the stomach, bottom = arms hanging.
POSE_ANIMS.BarbellRow = function(character, d, jitter)
	local hinge, extra = rad(45), rad(10)
	lowerBody(character, rad(15), hinge)
	setJoint(character, "Waist", Angles(-extra, 0, 0))
	frontArms(character, hinge + extra - rad(75 * (1 - d)), rad(10), rad(95 * (1 - d)), jitter)
end

-- Pull-up: lockout = chin up to the bar, bottom = dead hang. The body rises on the root; the hands stay on the bar
-- ("Bar"), a little wider than the shoulders, elbows out to the sides.
POSE_ANIMS.PullUp = function(character, d, jitter, model)
	local arm = bars.arm(character, "R")
	local reach = arm and (arm.a + arm.b) or 2
	bars.base(character, CFrame.new(0, reach * 0.55 * (1 - d), 0) * Angles(-rad(4) * (1 - d) + jitter * 0.2, 0, 0))
	bars.legs(character, rad(10), -rad(50), 0)
	local _, frame = bars.frames(character)
	local bar = model and model:FindFirstChild("Bar")
	if not (frame and bar and bar:IsA("BasePart")) then return end
	local axis = bar.CFrame.XVector
	for _, side in ipairs(SIDES) do
		local sideArm = bars.arm(character, side[1])
		if sideArm then
			local s = (frame * bars.c0(sideArm.shoulder)).Position + frame.RightVector * side[2] * reach * 0.2
			bars.armIK(character, side[1], frame, bar.Position + axis * (s - bar.Position):Dot(axis), bars.bodyDir(frame, side[1], Vector3.new(1, 0, -0.3)))
		end
	end
end

-- Leg press: reclined on the seat; lockout = legs long toward the sled, bottom = knees to the chest. The hands hold the
-- side handles. (The sled follows the feet along its rail.)
POSE_ANIMS.LegPress = function(character, d, jitter)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", Angles(rad(104 + 40 * d) + jitter * 0.3, 0, side[2] * rad(6)))
		setJoint(character, side[1] .. "Knee", Angles(-rad(6 + 96 * d), 0, 0))
		setJoint(character, side[1] .. "Ankle", Angles(rad(4 + 26 * d), 0, 0))
	end
	frontArms(character, rad(18), rad(28), rad(25), 0)
end

-- Hack squat: leaning back on the pad, hands on the shoulder-pad handles; sit down until the thighs are about
-- parallel. (The carriage follows the shoulders along its rail.)
POSE_ANIMS.HackSquat = function(character, d, jitter)
	lowerBody(character, rad(66 * d), -rad(12))
	frontArms(character, rad(145) + jitter * 0.5, rad(22), rad(125), 0)
end

-- Crunch: lying, the plate flat on the chest (follow "Chest") with the arms crossed over it, ankles hooked between the
-- foot rollers (leg IK, any body size); lockout = curled up.
POSE_ANIMS.Crunch = function(character, d, jitter, model)
	setJoint(character, "Waist", Angles(-rad(40 * (1 - d)) - jitter * 0.3, 0, 0))
	frontArms(character, rad(70), -rad(38), rad(125), 0)
	local rollers = {}
	for _, part in ipairs(model and model:GetChildren() or {}) do
		if part.Name == "FootRoller" then table.insert(rollers, part.Position) end
	end
	if #rollers < 2 then return end
	local target = (rollers[1] + rollers[2]) / 2
	-- slide the body along the bench toward the rollers (Root joint) until the legs reach them with the knees bent
	local root, lower = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("LowerTorso")
	local rootJoint = lower and lower:FindFirstChild("Root")
	local thigh, shin, foot = character:FindFirstChild("RightUpperLeg"), character:FindFirstChild("RightLowerLeg"), character:FindFirstChild("RightFoot")
	local hip, knee, ankle = thigh and thigh:FindFirstChild("RightHip"), shin and shin:FindFirstChild("RightKnee"), foot and foot:FindFirstChild("RightAnkle")
	if not (root and rootJoint and hip and knee and ankle) then return end
	local reach = ((bars.c1(hip).Position - bars.c0(knee).Position).Magnitude + (bars.c1(knee).Position - bars.c0(ankle).Position).Magnitude) * 0.62 -- (knees well up)
	local base = root.CFrame * bars.c0(rootJoint) * bars.c1(rootJoint):Inverse()
	local hipAt = base:PointToWorldSpace(Vector3.new(0, bars.c0(hip).Position.Y, bars.c0(hip).Position.Z))
	local feet = base:VectorToWorldSpace(Vector3.new(0, -1, 0))
	local offset = hipAt - target
	local along = offset:Dot(feet)
	local disc = along * along - (offset:Dot(offset) - reach * reach)
	local slide = if disc >= 0 then math.clamp(-along - math.sqrt(disc), 0, 2.5) else 0
	local move = CFrame.new(0, -slide, 0)
	setJoint(character, "Root", move)
	bars.legIK(character, target, rad(35), root.CFrame * bars.c0(rootJoint) * move * bars.c1(rootJoint):Inverse())
end

-- Pro gym poses. Free handles (cables, shrug levers, the pec deck) follow the hands (bars.props); fixed grips (the dip
-- handles, the hanging bar) hold the hands (arm IK). Contract poses (Config.Poses contract): d = 1 relaxed (also at rest),
-- 0 contracted.

-- Root / Waist (and the legs) are set every frame, identity unless given, so nothing of the idle animation mixes in.
function bars.base(character, root, waist)
	setJoint(character, "Root", root or CFrame.identity)
	setJoint(character, "Waist", waist or CFrame.identity)
end
function bars.legs(character, hip, knee, ankle)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", Angles(hip, 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(knee, 0, 0))
		setJoint(character, side[1] .. "Ankle", Angles(ankle, 0, 0))
	end
end

-- Where the LowerTorso and UpperTorso are this frame: from the root part and the Root / Waist transforms just set.
function bars.frames(character)
	local root, lower, upper = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("LowerTorso"), character:FindFirstChild("UpperTorso")
	local rootJoint, waist = lower and lower:FindFirstChild("Root"), upper and upper:FindFirstChild("Waist")
	if not (root and rootJoint and waist) then return nil, nil end
	local record = bars.T[character] or {}
	local lowerFrame = root.CFrame * bars.c0(rootJoint) * (record.Root or CFrame.identity) * bars.c1(rootJoint):Inverse()
	return lowerFrame, lowerFrame * bars.c0(waist) * (record.Waist or CFrame.identity) * bars.c1(waist):Inverse()
end

-- One arm: its shoulder and elbow joints, the upper arm length (a) and forearm + hand length to the hand's centre (b).
function bars.arm(character, side)
	local long = side == "R" and "Right" or "Left"
	local upperArm, lowerArm, hand = character:FindFirstChild(long .. "UpperArm"), character:FindFirstChild(long .. "LowerArm"), character:FindFirstChild(long .. "Hand")
	local shoulder = upperArm and upperArm:FindFirstChild(long .. "Shoulder")
	local elbow = lowerArm and lowerArm:FindFirstChild(long .. "Elbow")
	local wrist = hand and hand:FindFirstChild(long .. "Wrist")
	if not (shoulder and elbow and wrist) then return nil end
	local boneA = bars.c0(elbow).Position - bars.c1(shoulder).Position -- shoulder -> elbow, in the upper arm's space
	local boneB = bars.c0(wrist).Position - bars.c1(elbow).Position    -- elbow -> wrist, in the forearm's space
	return {
		shoulder = shoulder, elbow = elbow,
		a = boneA.Magnitude,
		b = boneB.Magnitude + bars.c1(wrist).Position.Magnitude,
		-- (the bones don't run straight down their parts on every body: the Robloxian upper arm's elbow sits ~36 degrees
		-- off its axis, so the IK turns each part by its own bone direction)
		boneA = boneA.Unit, boneB = boneB.Unit,
	}
end

-- The turn (in a part's own space) that takes its -Y axis onto the bone direction `bone`.
function bars.boneTurn(bone: Vector3): CFrame
	local down = Vector3.new(0, -1, 0)
	local axis = down:Cross(bone)
	if axis.Magnitude < 1e-4 then return CFrame.identity end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(down:Dot(bone), -1, 1)))
end

-- Two-joint arm IK: the hand's centre goes to `target` (world), the elbow bends toward `pole` (a world direction); lift
-- raises the shoulder (studs along the torso's up: shrugs). frame = the UpperTorso this frame (bars.frames).
function bars.armIK(character, side, frame, target, pole, lift)
	local arm = bars.arm(character, side)
	if not arm then return end
	local liftOffset = frame.UpVector * (lift or 0)
	local shoulderFrame = frame * bars.c0(arm.shoulder)
	local s = shoulderFrame.Position + liftOffset
	local a, b = arm.a, arm.b
	local toTarget = target - s
	local d = math.clamp(toTarget.Magnitude, math.abs(a - b) + 0.02, a + b - 0.005)
	local dir = if toTarget.Magnitude > 1e-4 then toTarget.Unit else -frame.UpVector
	local bendSide = pole - dir * pole:Dot(dir)
	if bendSide.Magnitude < 1e-3 then bendSide = -frame.LookVector - dir * (-frame.LookVector):Dot(dir) end
	bendSide = bendSide.Unit
	local cosA = math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1)
	local u = (dir * cosA + bendSide * math.sqrt(1 - cosA * cosA)).Unit -- shoulder -> elbow
	local f = (s + dir * d - (s + u * a)).Unit -- elbow -> hand
	local w = f - u * f:Dot(u) -- the way the forearm folds (the arm's local -Z)
	w = if w.Magnitude > 1e-4 then w.Unit else -bendSide
	local x = u:Cross(w)
	local armRotation = CFrame.fromMatrix(Vector3.zero, x, -u, -w) * bars.boneTurn(arm.boneA):Inverse()
	local shoulderTransform = CFrame.new(shoulderFrame:VectorToObjectSpace(liftOffset))
		* shoulderFrame.Rotation:Inverse() * armRotation * bars.c1(arm.shoulder).Rotation
	setJoint(character, side .. "Shoulder", shoulderTransform)
	local elbowFrame = shoulderFrame * shoulderTransform * bars.c1(arm.shoulder):Inverse() * bars.c0(arm.elbow)
	local forearmRotation = CFrame.fromMatrix(Vector3.zero, x, -f, x:Cross(-f)) * bars.boneTurn(arm.boneB):Inverse()
	setJoint(character, side .. "Elbow", elbowFrame.Rotation:Inverse() * forearmRotation * bars.c1(arm.elbow).Rotation)
end

-- A direction in the torso's space (x outward for the arm on `side`, y up, z back).
function bars.bodyDir(frame, side, v)
	local sign = side == "R" and 1 or -1
	return frame:VectorToWorldSpace(Vector3.new(v.X * sign, v.Y, v.Z))
end
-- Each hand to body-space point v from its own shoulder (in arm lengths, x outward), elbows toward pole (body space).
function bars.reachBoth(character, frame, v, pole, lift)
	for _, side in ipairs(SIDES) do
		local arm = bars.arm(character, side[1])
		if arm then
			local s = (frame * bars.c0(arm.shoulder)).Position + frame.UpVector * (lift or 0)
			local target = s + bars.bodyDir(frame, side[1], v) * (arm.a + arm.b)
			bars.armIK(character, side[1], frame, target, bars.bodyDir(frame, side[1], pole), lift)
		end
	end
end
-- Both hands on one grip: its centre is body-space point v from between the shoulders (arm lengths, x = the body's
-- right), the hands `width` x the shoulder spacing apart. On a broad chest with short arms the grip is drawn in toward
-- the chest until both arms reach it.
function bars.gripBoth(character, frame, v, width, pole)
	local r, l = bars.arm(character, "R"), bars.arm(character, "L")
	if not (r and l) then return end
	local sr, sl = (frame * bars.c0(r.shoulder)).Position, (frame * bars.c0(l.shoulder)).Position
	local reach = math.min(r.a + r.b, l.a + l.b) * 0.97
	local half = frame.RightVector * ((sr - sl).Magnitude / 2 * width)
	local center
	for _ = 1, 14 do
		center = (sr + sl) / 2 + frame:VectorToWorldSpace(v * (r.a + r.b))
		if (center + half - sr).Magnitude <= reach and (center - half - sl).Magnitude <= reach then break end
		v *= 0.92
	end
	bars.armIK(character, "R", frame, center + half, bars.bodyDir(frame, "R", pole))
	bars.armIK(character, "L", frame, center - half, bars.bodyDir(frame, "L", pole))
end

-- Dips: held up on the handles (the hands stay on them); the body sinks between them leaning forward a little, knees
-- bent with the feet back. Lockout = arms straight (not a contract pose: it starts at the top).
POSE_ANIMS.Dip = function(character, d, jitter, model)
	local arm = bars.arm(character, "R")
	local reach = arm and (arm.a + arm.b) or 2
	bars.base(character, CFrame.new(0, -reach * 0.42 * d, 0) * Angles(-rad(14) * d + jitter * 0.3, 0, 0))
	bars.legs(character, -rad(6), -rad(80), rad(20))
	local _, frame = bars.frames(character)
	if not (frame and model) then return end
	for _, side in ipairs(SIDES) do
		local sideArm = bars.arm(character, side[1])
		local best, bestScore = nil, -math.huge
		for _, part in ipairs(model:GetChildren()) do
			if part.Name == "Handle" and part:IsA("BasePart") then
				local score = (part.Position - frame.Position):Dot(frame.RightVector) * side[2]
				if score > bestScore then best, bestScore = part, score end
			end
		end
		if best and sideArm then
			local s = (frame * bars.c0(sideArm.shoulder)).Position
			local axis = best.CFrame.XVector
			local half = best.Size.X / 2 - 0.3
			local t = math.clamp((s - best.Position):Dot(axis), -half, half)
			bars.armIK(character, side[1], frame, best.Position + axis * t, bars.bodyDir(frame, side[1], Vector3.new(0.25, 0, 1)))
		end
	end
end

-- Lateral raise: arms from the sides up and out to shoulder height, elbows soft.
POSE_ANIMS.LateralRaise = function(character, d, jitter)
	local c = 1 - d
	bars.base(character)
	bars.legs(character, 0, 0, 0)
	local _, frame = bars.frames(character)
	if not frame then return end
	local v = Vector3.new(0.22, -0.96, -0.16):Lerp(Vector3.new(0.97, -0.12 + jitter, -0.18), c).Unit * 0.96
	bars.reachBoth(character, frame, v, Vector3.new(0, -1, 0.35))
end

-- Reverse fly on the pec deck: seated, chest on the pad; arms straight ahead (relaxed) sweep out to the sides.
POSE_ANIMS.ReverseFly = function(character, d, jitter)
	local c = 1 - d
	bars.base(character)
	bars.legs(character, rad(90), -rad(90), 0)
	local _, frame = bars.frames(character)
	if not frame then return end
	local v = Vector3.new(0.1, -0.08, -1):Lerp(Vector3.new(0.96, -0.08 + jitter, 0.24), c).Unit * 0.95
	bars.reachBoth(character, frame, v, Vector3.new(0, -1, 0))
end

-- Shrugs: arms hang straight holding the grips; the shoulders lift.
POSE_ANIMS.Shrug = function(character, d, jitter)
	local c = 1 - d
	bars.base(character)
	bars.legs(character, 0, 0, 0)
	local _, frame = bars.frames(character)
	local torso = character:FindFirstChild("UpperTorso")
	if not (frame and torso) then return end
	bars.reachBoth(character, frame, Vector3.new(0.2, -0.97, -0.06), Vector3.new(0, 0, 1), torso.Size.Y * 0.17 * c + jitter * 0.05)
end

-- Hip thrust: upper back on the pad, feet flat on the plate; the body turns about the upper back, so the hips sink at
-- rest and the bridge is straight at the top. The hip pad rides on the hips (bars.props.HipThrust).
POSE_ANIMS.HipThrust = function(character, d, jitter, model)
	local root, lower, upper = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("LowerTorso"), character:FindFirstChild("UpperTorso")
	local rootJoint, waist = lower and lower:FindFirstChild("Root"), upper and upper:FindFirstChild("Waist")
	if not (root and rootJoint and waist) then return end
	local toUpper = bars.c0(rootJoint) * bars.c1(rootJoint):Inverse() * bars.c0(waist) * bars.c1(waist):Inverse()
	local back = bars.c0(rootJoint):PointToObjectSpace((toUpper * CFrame.new(0, upper.Size.Y * 0.15, upper.Size.Z / 2)).Position)
	bars.base(character, CFrame.new(back) * Angles(-rad(40) * d - jitter * 0.2, 0, 0) * CFrame.new(-back))
	local lowerFrame, frame = bars.frames(character)
	local thigh = character:FindFirstChild("RightUpperLeg")
	local hipJoint = thigh and thigh:FindFirstChild("RightHip")
	if lowerFrame and hipJoint then
		local hipAt = (lowerFrame * bars.c0(hipJoint)).Position
		local feetward = -root.CFrame.UpVector
		feetward = Vector3.new(feetward.X, 0, feetward.Z)
		local floor = (model and model:GetPivot().Position.Y or 0) + 0.26 + 0.25
		local target = Vector3.new(hipAt.X, floor, hipAt.Z) + (if feetward.Magnitude > 1e-3 then feetward.Unit else Vector3.zero) * thigh.Size.Y * 0.95
		bars.legIK(character, target, -rad(10), lowerFrame)
	end
	-- the hands hold the hip roller, one each side of the hips
	if frame and lowerFrame then
		local roller = lowerFrame * CFrame.new(0, 0, -(lower.Size.Z / 2 + 0.25))
		for _, side in ipairs(SIDES) do
			bars.armIK(character, side[1], frame, (roller * CFrame.new(side[2] * 0.85, 0, 0)).Position, bars.bodyDir(frame, side[1], Vector3.new(1, 0, 0.6)))
		end
	end
end

-- Biceps curl: the bar from the thighs up to the shoulders, elbows at the sides.
POSE_ANIMS.BicepCurl = function(character, d, jitter)
	local c = 1 - d
	bars.base(character)
	bars.legs(character, 0, 0, 0)
	local _, frame = bars.frames(character)
	if not frame then return end
	local v = Vector3.new(0, -0.9, -0.24):Lerp(Vector3.new(0, -0.22 + jitter, -0.48), c)
	bars.gripBoth(character, frame, v, 0.75, Vector3.new(0.05, -1, 0.6))
end

-- Triceps pushdown: leaning in a little, elbows pinned back; the rope from chest height down to the thighs.
POSE_ANIMS.TricepPushdown = function(character, d, jitter)
	local c = 1 - d
	bars.base(character, nil, Angles(-rad(12), 0, 0))
	bars.legs(character, 0, 0, 0)
	local _, frame = bars.frames(character)
	if not frame then return end
	local v = Vector3.new(0, -0.42, -0.5):Lerp(Vector3.new(0, -0.93 + jitter, -0.22), c)
	bars.gripBoth(character, frame, v, 0.4, Vector3.new(0, 0, 1))
end

-- Hanging leg raise: hanging from the bar (the hands stay on it), legs straight down at rest, up to level at the top.
POSE_ANIMS.LegRaise = function(character, d, jitter, model)
	local c = 1 - d
	bars.base(character, Angles(rad(7) * c, 0, 0))
	bars.legs(character, rad(88) * c + jitter, -rad(4 + 14 * c), rad(8) * c)
	local _, frame = bars.frames(character)
	local bar = model and model:FindFirstChild("HangBar")
	if not (frame and bar) then return end
	local axis = bar.CFrame.XVector
	for _, side in ipairs(SIDES) do
		local arm = bars.arm(character, side[1])
		if arm then
			local s = (frame * bars.c0(arm.shoulder)).Position + frame.RightVector * side[2] * (arm.a + arm.b) * 0.12
			bars.armIK(character, side[1], frame, bar.Position + axis * (s - bar.Position):Dot(axis), bars.bodyDir(frame, side[1], Vector3.new(1, 0, 0.4)))
		end
	end
end

-- Cable woodchop: side-on to the tower (on the left); from high on the left, turned toward the pulley, down across the
-- body to the right hip, the hips turning with it.
POSE_ANIMS.Woodchop = function(character, d, jitter)
	local c = 1 - d
	local twist = rad(50) - rad(100) * c
	bars.base(character, Angles(0, twist * 0.35, 0), Angles(0, twist * 0.65, 0))
	bars.legs(character, 0, 0, 0)
	local _, frame = bars.frames(character)
	if not frame then return end
	-- (the handle stays in front of the turned chest: both arms reach it)
	local v = Vector3.new(0, 0.5, -0.55):Lerp(Vector3.new(0, -0.62 + jitter, -0.45), c)
	bars.gripBoth(character, frame, v, 0.18, Vector3.new(0, -1, 0.3))
end

-- Free handles: a handle model goes to a world point (oriented by its Axis and the torso), then every link (cable,
-- lever, swing arm) is stretched to where its handle is now. Rest places are remembered (bars.resetProps).
function bars.remember(model, inst)
	local rest = bars.propRest[model]
	if not rest then
		rest = {}
		bars.propRest[model] = rest
	end
	if rest[inst] == nil then
		if inst:IsA("Model") then
			rest[inst] = inst:GetPivot()
		else
			rest[inst] = inst.CFrame
			bars.restSize[inst] = inst.Size
		end
	end
end
function bars.placeHandle(model, name, position, torso)
	local h = model:FindFirstChild(name)
	if not (h and h:IsA("Model")) then return end
	bars.remember(model, h)
	local along = if h:GetAttribute("Axis") == "Forward" then torso.LookVector else torso.RightVector
	along = Vector3.new(along.X, 0, along.Z)
	if along.Magnitude < 1e-3 then along = Vector3.xAxis end
	h:PivotTo(CFrame.fromMatrix(position, along.Unit, Vector3.yAxis))
end
function bars.updateLinks(model)
	local pivot = model:GetPivot()
	for _, part in ipairs(model:GetChildren()) do
		local to = part:IsA("BasePart") and part:GetAttribute("To")
		local handle = to and model:FindFirstChild(to)
		local fromLocal = part:GetAttribute("From")
		if handle and handle:IsA("Model") and typeof(fromLocal) == "Vector3" then
			bars.remember(model, part)
			local from = pivot:PointToWorldSpace(fromLocal)
			local offset = (handle:GetAttribute("CablePoint") or Vector3.zero) + (part:GetAttribute("ToOffset") or Vector3.zero)
			local point = handle:GetPivot():PointToWorldSpace(offset)
			if part:GetAttribute("Level") then point = Vector3.new(point.X, from.Y, point.Z) end
			if part:GetAttribute("Drop") then from = Vector3.new(point.X, from.Y, point.Z) end
			local span = point - from
			if span.Magnitude > 0.02 then
				part.Size = Vector3.new(part.Size.X, part.Size.Y, span.Magnitude)
				part.CFrame = CFrame.lookAt((from + point) / 2, point, if math.abs(span.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis)
			end
		end
	end
end
function bars.grip(hand) return (hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.1, 0)).Position end
-- the handle(s) into the hands: one in each ("HandleR" / "HandleL") or one held by both ("HandleBoth")
function bars.handsTo(model, character, both)
	local torso, r, l = character:FindFirstChild("UpperTorso"), character:FindFirstChild("RightHand"), character:FindFirstChild("LeftHand")
	if not (torso and r and l) then return end
	if both then
		bars.placeHandle(model, "HandleBoth", (bars.grip(r) + bars.grip(l)) / 2, torso.CFrame)
	else
		bars.placeHandle(model, "HandleR", bars.grip(r), torso.CFrame)
		bars.placeHandle(model, "HandleL", bars.grip(l), torso.CFrame)
	end
	bars.updateLinks(model)
end
bars.props.LateralRaise = function(model, character) bars.handsTo(model, character, false) end
bars.props.Shrug = bars.props.LateralRaise
bars.props.BicepCurl = function(model, character) bars.handsTo(model, character, true) end
bars.props.TricepPushdown = bars.props.BicepCurl
bars.props.Woodchop = bars.props.BicepCurl
-- the pec deck's chest pad slides to the chest (below the shoulders, so the arms pass over it)
bars.props.ReverseFly = function(model, character)
	local torso = character:FindFirstChild("UpperTorso")
	if torso then
		bars.placeHandle(model, "ChestPad", (torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.22, -(torso.Size.Z / 2 + 0.16))).Position, torso.CFrame)
	end
	bars.handsTo(model, character, false)
end
-- the hip thrust's roller lies across the front of the hips
bars.props.HipThrust = function(model, character)
	local lower, torso = character:FindFirstChild("LowerTorso"), character:FindFirstChild("UpperTorso")
	if not (lower and torso) then return end
	bars.placeHandle(model, "HandleBoth", (lower.CFrame * CFrame.new(0, 0, -(lower.Size.Z / 2 + 0.25))).Position, torso.CFrame)
	bars.updateLinks(model)
end

-- Leg curl: face down; heels curl toward the glutes at lockout, hands on the handles in front of the head. The ankle
-- roller and its lever ride on the back of the ankles and swing up with the shins (bars.props.LegCurl).
POSE_ANIMS.LegCurl = function(character, d, jitter)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", CFrame.identity)
		setJoint(character, side[1] .. "Knee", Angles(-rad(10 + 105 * (1 - d)) - jitter, 0, 0))
		setJoint(character, side[1] .. "Ankle", Angles(rad(25), 0, 0))
	end
	frontArms(character, rad(150), rad(4), rad(30), 0)
end
bars.props.LegCurl = function(model, character)
	local rest = bars.restOf(model, { "AnkleRoller", "RollerArm" })
	local right, left = character:FindFirstChild("RightLowerLeg"), character:FindFirstChild("LeftLowerLeg")
	if not (right and left) then return end
	local axes = right.CFrame
	local frame = CFrame.fromMatrix((right.Position + left.Position) / 2, axes.XVector, axes.YVector, axes.ZVector)
	local length, depth = right.Size.Y, right.Size.Z
	for part in pairs(rest) do
		if part.Name == "AnkleRoller" then
			-- on the back of the ankles (the shin's +Z is the back of the leg; face down that is up)
			part.CFrame = frame * CFrame.new(0, -length * 0.4, depth / 2 + math.min(part.Size.Y, part.Size.Z) / 2)
		else
			-- the lever: from the roller along the back of the shin toward the knee pivot
			part.CFrame = frame * CFrame.new(0, -length * 0.4 + part.Size.Y / 2, depth / 2 + 0.12)
		end
	end
end

-- Calf raise: standing on the step, shoulders under the pads, hands gripping the pads; up on the toes at lockout. The
-- pads and their arm sit on the shoulders and rise with them (bars.props.CalfRaise), whatever the body's height.
POSE_ANIMS.CalfRaise = function(character, d, jitter)
	setJoint(character, "Root", CFrame.new(0, 0.35 * (1 - d), 0))
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Ankle", Angles(-rad(35 * (1 - d)) - jitter, 0, 0))
	end
	frontArms(character, rad(30), -rad(6), rad(140), 0) -- (elbows down, hands up at the pads)
end
bars.props.CalfRaise = function(model, character)
	local rest = bars.restOf(model, { "ShoulderPad", "Arm", "ArmLink" })
	local torso = character:FindFirstChild("UpperTorso")
	if not torso then return end
	local padBottom = math.huge
	for part, cframe in pairs(rest) do
		if part.Name == "ShoulderPad" then padBottom = math.min(padBottom, cframe.Position.Y - part.Size.Y / 2) end
	end
	if padBottom == math.huge then return end
	local shoulderTop = torso.CFrame:PointToWorldSpace(Vector3.new(0, torso.Size.Y / 2, 0)).Y
	local lift = Vector3.new(0, shoulderTop - padBottom, 0)
	for part, cframe in pairs(rest) do part.CFrame = cframe + lift end
end

-- Sled push (winter): leaning into the sled's handles, legs driving in a lunge that switches each rep.
-- Treadmill belts: while someone runs on one (the machine's UserId attribute), its slats slide back along the belt at the
-- tier's speed and wrap around, and a pro treadmill's readout (Screen.Readout) counts speed / time / distance for the run
-- (client only, looks only).
task.spawn(function()
	local CollectionService = game:GetService("CollectionService")
	local offsets = {} -- [model] = studs travelled
	local runs = {} -- [model] = { time, miles, shown } for the readout
	local function readout(model, mph, seconds, miles)
		local screen = model:FindFirstChild("Screen")
		local gui = screen and screen:FindFirstChild("Readout")
		if not gui then return end
		local cells = {}
		for _, cell in ipairs(gui:GetChildren()) do
			if cell:IsA("Frame") then table.insert(cells, cell) end
		end
		local values = { string.format("%.1f", mph), string.format("%02d:%02d", seconds // 60 % 100, seconds % 60), string.format("%.2f", miles) }
		for i, cell in ipairs(cells) do
			local label = cell:FindFirstChildOfClass("TextLabel")
			if label and values[i] then label.Text = values[i] end
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		for model, run in pairs(runs) do
			if not model.Parent or not model:GetAttribute("UserId") then
				runs[model] = nil
				if model.Parent then readout(model, 0, 0, 0) end
			end
		end
		for _, model in ipairs(CollectionService:GetTagged("Machine")) do
			if model:GetAttribute("MachineId") ~= "Treadmill" or not model:GetAttribute("UserId") then continue end
			local mph = Machines.ById.Treadmill.tiers[model:GetAttribute("Tier") or 1].weight
			local run = runs[model] or { time = 0, miles = 0, shown = -1 }
			runs[model] = run
			run.time += dt
			run.miles += mph * dt / 3600
			if math.floor(run.time) ~= run.shown then -- (once a second)
				run.shown = math.floor(run.time)
				readout(model, mph, run.shown, run.miles)
			end
			local belt, slats = model:FindFirstChild("Belt"), model:FindFirstChild("Slats")
			local tier = Machines.ById.Treadmill.tiers[model:GetAttribute("Tier") or 1]
			if not (belt and slats and tier) then continue end
			local length = belt.Size.Z
			offsets[model] = ((offsets[model] or 0) + dt * tier.weight * Machines.Cardio.BeltScroll) % length
			for i, slat in ipairs(slats:GetChildren()) do
				local z = ((i - 1) * length / #slats:GetChildren() + offsets[model]) % length - length / 2
				slat.CFrame = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + slat.Size.Y / 2, z)
			end
		end
	end)
end)

-- Treadmill run: one stride per rep (d 0 -> 1 -> 0), legs and arms swinging in opposite pairs, a small bounce. The body
-- stays on the belt (only the joints move; the root bobs up and down).
POSE_ANIMS.Run = function(character, d, jitter)
	local s = d * 2 - 1 -- -1 .. 1: which leg is forward
	setJoint(character, "Root", CFrame.new(0, 0.12 * math.abs(s), 0) * Angles(-rad(6), 0, 0))
	for _, side in ipairs(SIDES) do
		local swing = s * side[2]
		setJoint(character, side[1] .. "Hip", Angles(rad(38) * swing + rad(10), 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(-rad(20 + 45 * math.max(-swing, 0)), 0, 0))
		setJoint(character, side[1] .. "Ankle", Angles(rad(10) * swing, 0, 0))
		setJoint(character, side[1] .. "Shoulder", Angles(-rad(35) * swing + jitter, 0, -side[2] * rad(6)))
		setJoint(character, side[1] .. "Elbow", Angles(rad(85), 0, 0))
	end
end

POSE_ANIMS.SledPush = function(character, d, jitter)
	setJoint(character, "Root", CFrame.new(0, -0.3, 0) * Angles(-rad(35), 0, 0))
	frontArms(character, rad(80) + jitter, rad(10), rad(20 + 25 * d), 0)
	local drive = rad(45 * (1 - d))
	setJoint(character, "RHip", Angles(rad(25) + drive, 0, 0))
	setJoint(character, "RKnee", Angles(-rad(40) - drive, 0, 0))
	setJoint(character, "LHip", Angles(rad(25) - drive * 0.6, 0, 0))
	setJoint(character, "LKnee", Angles(-rad(20), 0, 0))
end

local function poseFor(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	return machine and machine.pose or "BenchPress"
end

local function animate(model, character, depth, shake)
	local jitter = shake and rad(FEEL.ShakeDegrees) * math.sin(os.clock() * 45) or 0
	local anim = POSE_ANIMS[poseFor(model)] or POSE_ANIMS.BenchPress
	anim(character, depth, jitter, model)
end

-- Where the plates ride while someone is on the machine.
local function followCFrame(model, character)
	local follow = (Poses[poseFor(model)] or {}).follow or "Hands"
	if follow == "Hands" then
		local right, left = character:FindFirstChild("RightHand"), character:FindFirstChild("LeftHand")
		if right and left then
			return CFrame.new((right.Position + left.Position) / 2) * barRest[model].Rotation
		end
	elseif follow == "Back" then
		local torso = character:FindFirstChild("UpperTorso")
		if torso then
			return torso.CFrame * CFrame.new(0, torso.Size.Y * 0.42, torso.Size.Z * 0.65)
		end
	elseif follow == "Rail" then
		-- the load slides along the machine's rail to the lifter's feet (leg press) or shoulders (hack squat)
		local axis = model:GetAttribute("RailAxis")
		local rest = barRest[model]
		if typeof(axis) ~= "Vector3" or not rest then return nil end
		axis = model:GetPivot():VectorToWorldSpace(axis).Unit
		local anchor
		if model:GetAttribute("RailAnchor") == "Shoulders" then
			local torso = character:FindFirstChild("UpperTorso")
			anchor = torso and (torso.CFrame * CFrame.new(0, torso.Size.Y / 2, 0)).Position
		else
			local right, left = character:FindFirstChild("RightFoot"), character:FindFirstChild("LeftFoot")
			anchor = right and left and (right.Position + left.Position) / 2
		end
		if not anchor then return nil end
		local t = (anchor - rest.Position):Dot(axis) + (model:GetAttribute("RailOffset") or 0)
		t = math.clamp(t, model:GetAttribute("RailMin") or -3, model:GetAttribute("RailMax") or 0)
		return rest + axis * t
	elseif follow == "Chest" then
		-- flat on the chest: the handle points out of the chest, so the plate's face lies on it
		local torso = character:FindFirstChild("UpperTorso")
		if torso then
			return torso.CFrame * CFrame.new(0, torso.Size.Y * 0.05, -(torso.Size.Z / 2 + 0.12)) * Angles(0, rad(90), 0)
		end
	elseif follow == "Hips" then
		local hips = character:FindFirstChild("LowerTorso")
		if hips then
			return hips.CFrame * CFrame.new(0, -hips.Size.Y * 0.5 - 0.8, -0.4) * Angles(0, rad(90), 0)
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Pump: trained parts swell a little each rep, bounce, then slowly settle
------------------------------------------------------------------------
local pumped = {} -- [part] = { base, amount, bounce, last }

local function pump(character, machine)
	if machine.trains == "Stamina" then return end -- (cardio trains stamina, not a muscle)
	local root = character:FindFirstChild("HumanoidRootPart")
	if character ~= player.Character and not (root and bars.near(root.Position, Machines.ClientCull.PumpDistance) and bars.onScreen(root.Position, 4)) then return end
	for index, entry in ipairs(machine.muscles) do
		local amount = FEEL.PumpPerRep * (index == 1 and 1 or 0.5)
		for _, partName in ipairs(Muscles.Body[entry.id].pump) do
			local part = character:FindFirstChild(partName)
			if part and not bars.hasMuscleMesh(character, partName) then
				local state = pumped[part] or { base = part:GetAttribute("BaseSize") or part.Size, amount = 0, bounce = 0 }
				state.amount = math.min(state.amount + amount, FEEL.PumpMax)
				state.bounce = FEEL.PumpBounce
				state.last = os.clock()
				pumped[part] = state
			end
		end
	end
end

-- PUMPED: one big swell + bounce on the trained parts (scale only, no extra parts)
local function pumpBurst(character, machine)
	if machine.trains == "Stamina" then return end
	for _, entry in ipairs(machine.muscles) do
		for _, partName in ipairs(Muscles.Body[entry.id].pump) do
			local part = character:FindFirstChild(partName)
			if part and not bars.hasMuscleMesh(character, partName) then
				local state = pumped[part] or { base = part:GetAttribute("BaseSize") or part.Size, amount = 0, bounce = 0 }
				state.amount = FEEL.PumpMax
				state.bounce = FEEL.PumpBounce * 3
				state.last = os.clock()
				pumped[part] = state
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for part, state in pairs(pumped) do
		if not part.Parent then
			pumped[part] = nil
			continue
		end
		state.bounce *= math.exp(-dt * 10)
		if now - state.last > FEEL.PumpHold then
			state.amount = math.max(0, state.amount - FEEL.PumpDecay * dt)
		end
		-- grow from the server's muscle-scaled size (BodyService), so the two never fight
		local base = part:GetAttribute("BaseSize") or state.base
		local s = state.amount + state.bounce
		if state.amount <= 0 and state.bounce < 0.001 then
			part.Size = base
			pumped[part] = nil
		else
			part.Size = base * Vector3.new(1 + s, 1 + s * 0.4, 1 + s)
		end
	end
end)

------------------------------------------------------------------------
-- Particles
------------------------------------------------------------------------
local function chalkPuff(character, count)
	for _, handName in ipairs({ "RightHand", "LeftHand" }) do
		local hand = character:FindFirstChild(handName)
		if hand then
			local attachment = New("Attachment", { Parent = hand })
			local emitter = New("ParticleEmitter", {
				Texture = PARTICLE_SMOKE,
				Color = ColorSequence.new(Colors.Chalk),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.4) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.6, 1.1),
				Speed = NumberRange.new(1.5, 4),
				SpreadAngle = Vector2.new(180, 180),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-60, 60),
				Drag = 4,
				Rate = 0,
				LightInfluence = 0.3,
				Parent = attachment,
			})
			emitter:Emit(count)
			Debris:AddItem(attachment, 1.5)
		end
	end
end

local sweatEmitter = nil
local function setSweat(on)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if on and head and not (sweatEmitter and sweatEmitter.Parent) then
		local attachment = New("Attachment", { Name = "Sweat", Position = Vector3.new(0, 0.3, -0.4), Parent = head })
		sweatEmitter = New("ParticleEmitter", {
			Texture = PARTICLE_DROP,
			Color = ColorSequence.new(Colors.Chalk),
			Size = NumberSequence.new(0.15),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.6, 0.9),
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -14, 0),
			Rate = 6,
			LightInfluence = 0.5,
			Parent = attachment,
		})
	end
	if sweatEmitter then
		sweatEmitter.Enabled = on
	end
end

------------------------------------------------------------------------
-- 3D gain popup: ONE at a time, just to the side of the chest. Per rep "+12" (the main muscle's gain, no name);
-- every set "Set done · +120 Chest", slightly bigger. A new popup replaces the old one (never stacked).
-- Settings → Gain numbers: On (both), Minimal (set popups only), Off (none).
------------------------------------------------------------------------
local POPUP = {
	Side = 1.2,       -- studs beside the chest edge, times the body's height scale
	Low = 1.4,        -- studs lower for the "below the chest" spots
	Far = 3,          -- studs beside the chest edge for the last-resort spots
	Float = 1,        -- studs it floats up while fading
	SetScale = 1.25,  -- set popups are slightly bigger
	Height = 40,      -- px
	CharWidth = 15,   -- px per character at the Popup text size (Oswald), for the clear-spot check
	BarGap = 0.3,     -- studs kept clear around the bar and its plates (all along its path)
	ScreenMargin = 8, -- px from the screen edges
}
local activePopup = nil -- { billboard, attachment }

-- The rep flash (Settings "Rep flash", default On): the muscles a rep trained glow warm for a moment, the main one
-- strongest (each muscle's machine share, secondaries at least FLASH_MIN_WEIGHT); BIG REP / PUMPED flash harder.
local FLASH_MIN_WEIGHT = 0.35
local function repFlash(character, machine, strong: boolean)
	local weights = {}
	for _, muscle in ipairs(machine.muscles) do
		weights[muscle.id] = math.max(muscle.share or 1, FLASH_MIN_WEIGHT)
	end
	UIBus.RepFlash:Fire(weights, strong) -- the body-map widget flashes the same muscles
	local settings = ClientData.Get().settings
	if settings and settings.repFlash == "Off" then return end
	MuscleRig.Flash(character, weights, strong)
end

local function gainNumbersMode(): string -- "On" | "Minimal" | "Off"
	local settings = ClientData.Get().settings
	local mode = settings and settings.gainNumbers
	return (mode == "Minimal" or mode == "Off") and mode or "On"
end

local function clearPopup()
	if activePopup then
		activePopup.billboard:Destroy()
		activePopup.attachment:Destroy()
		activePopup = nil
	end
end

-- Screen rectangle (minX, minY, maxX, maxY) of a part's box.
local function screenRect(camera, part)
	local half = part.Size / 2
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				local p = camera:WorldToViewportPoint(part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z)))
				minX, minY, maxX, maxY = math.min(minX, p.X), math.min(minY, p.Y), math.max(maxX, p.X), math.max(maxY, p.Y)
			end
		end
	end
	return minX, minY, maxX, maxY
end

-- Where the popup goes: the first spot beside the chest whose on-screen box (including where it floats to) stays on
-- screen and misses the head and the bar's whole path (rack to bottom of the rep, thickened by the plates). If no
-- spot is fully clear, the one with the least overlap. Returns the camera-space offset (x > 0 = camera right).
local function popupSpot(character, torso, model, anchorWorld, textWidth, scale, bodyScale)
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local edge = torso.Size.X / 2
	local near, far, low = edge + POPUP.Side * bodyScale, edge + POPUP.Far * bodyScale, POPUP.Low * bodyScale
	local spots = {}
	for _, y in ipairs({ 0, -low, -2 * low }) do
		for _, x in ipairs({ near, -near, far, -far }) do table.insert(spots, { x = x, y = y }) end
	end
	local head = character:FindFirstChild("Head")
	local hx0, hy0, hx1, hy1
	if head and head:IsA("BasePart") then hx0, hy0, hx1, hy1 = screenRect(camera, head) end
	-- the bar (or cable load) as sample points along its longest axis, across its travel; points near the ends get
	-- the plates' radius as margin, the middle only the bar's own thickness
	local samples = {} -- { Vector2 point, pad px }
	local load = model and loadPart(model)
	if load and load:IsA("BasePart") then
		local size = load.Size
		local axis = (size.X >= size.Y and size.X >= size.Z) and Vector3.xAxis or (size.Y >= size.Z and Vector3.yAxis or Vector3.zAxis)
		local length = (size * axis).Magnitude
		local across = size - size * axis
		local thickness = math.max(across.X, across.Y, across.Z)
		local plateRadius = 0
		local plates = model:FindFirstChild("Plates")
		for _, plate in ipairs(plates and plates:GetChildren() or {}) do
			if plate:IsA("BasePart") then
				plateRadius = math.max(plateRadius, math.max(plate.Size.X, plate.Size.Y, plate.Size.Z) / 2)
			end
		end
		local travel = bars.travel[model] or { low = load.CFrame, high = load.CFrame }
		local tanHalf = math.tan(math.rad(camera.FieldOfView) / 2)
		for _, t in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
			local cf = travel.low:Lerp(travel.high, t)
			for i = 0, 16 do
				local along = (i / 16 - 0.5) * length
				local p = camera:WorldToViewportPoint(cf:PointToWorldSpace(axis * along))
				if p.Z > 0 then
					local pxPerStud = viewport.Y / (2 * p.Z * tanHalf)
					local radius = math.abs(along) > length * 0.2 and math.max(plateRadius, thickness / 2) or thickness / 2
					table.insert(samples, { Vector2.new(p.X, p.Y), (radius + POPUP.BarGap) * pxPerStud })
				end
			end
		end
	end
	local w, h = (textWidth + 8) * scale, POPUP.Height * scale
	local right, up = camera.CFrame.RightVector, camera.CFrame.UpVector
	local best, bestScore = spots[1], math.huge
	for _, spot in ipairs(spots) do
		local world = anchorWorld + right * spot.x + up * spot.y
		local p = camera:WorldToViewportPoint(world)
		local top = camera:WorldToViewportPoint(world + Vector3.new(0, POPUP.Float, 0)) -- where it floats to
		if p.Z > 0 then
			local x0 = spot.x > 0 and p.X or p.X - w
			local x1 = x0 + w
			local y0, y1 = math.min(p.Y, top.Y) - h / 2, math.max(p.Y, top.Y) + h / 2
			local score = 0
			if x0 < POPUP.ScreenMargin or x1 > viewport.X - POPUP.ScreenMargin
				or y0 < POPUP.ScreenMargin or y1 > viewport.Y - POPUP.ScreenMargin then
				score += 1000
			end
			if hx0 and not (x1 < hx0 or x0 > hx1 or y1 < hy0 or y0 > hy1) then score += 100 end
			for _, sample in ipairs(samples) do
				local q, pad = sample[1], sample[2]
				if q.X > x0 - pad and q.X < x1 + pad and q.Y > y0 - pad and q.Y < y1 + pad then score += 1 end
			end
			if score == 0 then return spot end
			if score < bestScore then best, bestScore = spot, score end
		end
	end
	return best
end

local function gainPopup(character, text, scale, model, color)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then return end
	clearPopup()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local heightValue = humanoid and humanoid:FindFirstChild("BodyHeightScale")
	local bodyScale = if heightValue and heightValue:IsA("NumberValue") then heightValue.Value else 1
	local attachment = New("Attachment", { Position = Vector3.new(0, torso.Size.Y * 0.2, 0), Parent = torso })
	local spot = popupSpot(character, torso, model, attachment.WorldPosition, #text * POPUP.CharWidth, scale, bodyScale)
	local onRight = spot.x > 0
	local billboard = New("BillboardGui", {
		Adornee = attachment,
		Size = UDim2.fromOffset(320, POPUP.Height),
		-- the text starts at the anchor and grows away from the body
		SizeOffset = Vector2.new(onRight and 0.5 or -0.5, 0),
		StudsOffset = Vector3.new(spot.x, spot.y, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = waitFor(player, "PlayerGui"),
	})
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(onRight and 0 or 1, 0.5), -- the pop-in grows from the body side
		Position = UDim2.fromScale(onRight and 0 or 1, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = billboard,
	})
	local popScale = New("UIScale", { Scale = 0, Parent = holder })
	local label = Theme.Text({
		Text = text,
		Font = "SemiBold",
		TextSize = "Popup",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = onRight and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
		TextColor3 = color or Colors.Text,
		Parent = holder,
	})
	local stroke = Theme.TextShadow(label, 0.45)
	local popup = { billboard = billboard, attachment = attachment }
	activePopup = popup

	Theme.Tween(popScale, { Scale = scale }, Theme.Motion.Time * 1.4, Theme.Motion.Bounce)
	task.delay(Theme.Motion.Time * 1.4, function()
		if activePopup ~= popup then return end -- already replaced
		local fade = Theme.Motion.Time * 2.4
		Theme.Tween(billboard, { StudsOffsetWorldSpace = Vector3.new(0, POPUP.Float, 0) }, fade)
		Theme.Tween(label, { TextTransparency = 1 }, fade)
		Theme.Tween(stroke, { Transparency = 1 }, fade)
		task.delay(fade, function()
			if activePopup == popup then clearPopup() end
		end)
	end)
end

-- EXP popups (Settings "Show EXP popups", default On): every rep a small popup per trained muscle around you, the muscle's
-- icon chip (its group color) + the real EXP it gained ("+112", "+1.2K"). Main muscle bigger and warm red-orange,
-- secondaries smaller and green, PUMPED / BIG REP gold. Each pops in with a small bounce, drifts up and out at a random
-- angle and fades over EXP_POP.Life. At most EXP_POP.Max on screen: on fast reps the oldest go first. Client only (the
-- same numbers the server applies: Gains.PerRep), so no extra network traffic.
local ExpPops = {} -- (one local: this script is near Luau's 200-locals limit)
do
	local HudIcons = require(Shared.Config.HudIcons)
	local EXP_POP = {
		Max = 8,
		Life = 0.8,
		Rise = 1.5,    -- studs up over its life
		Spread = 1.3,  -- studs out to the side over its life
		Main = { TextSize = "Popup", Color = Color3.fromRGB(255, 122, 72), Chip = 20, Width = 130 },
		Helper = { TextSize = "Medium", Color = Color3.fromRGB(112, 224, 132), Chip = 14, Width = 100 },
	}
	local expPops = {} -- live popups, oldest first: { billboard }
	local function dropExpPop(pop)
		local index = table.find(expPops, pop)
		if index then table.remove(expPops, index) end
		if pop.billboard then pop.billboard:Destroy() end
	end
	local function expPopup(torso: BasePart, muscleId: string, amount: number, main: boolean, gold: boolean, order: number)
		while #expPops >= EXP_POP.Max do dropExpPop(expPops[1]) end
		local style = if main then EXP_POP.Main else EXP_POP.Helper
		local muscle = Muscles.ById[muscleId]
		local group = HudIcons.MuscleGroups[muscle and muscle.group or ""]
		-- where it starts and where it drifts: around the chest, a random way out (alternating sides)
		local side = if order % 2 == 0 then 1 else -1
		local angle = math.rad(math.random(15, 70))
		local start = Vector3.new(side * (torso.Size.X * 0.55 + math.random() * 0.3), torso.Size.Y * (0.1 + math.random() * 0.3), 0)
		local drift = Vector3.new(side * math.cos(angle) * EXP_POP.Spread, math.sin(angle) * EXP_POP.Spread * 0.4 + EXP_POP.Rise, 0)
		local billboard = New("BillboardGui", {
			Adornee = torso,
			Size = UDim2.fromOffset(style.Width, Theme.TextSize[style.TextSize] + 10),
			StudsOffset = start,
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 80,
			ResetOnSpawn = false,
			Parent = waitFor(player, "PlayerGui"),
		})
		local holder = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = billboard },
			{ Theme.List(Enum.FillDirection.Horizontal, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
		local pop = New("UIScale", { Scale = 0.3, Parent = holder })
		local chip = New("Frame", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(style.Chip, style.Chip),
			BackgroundColor3 = group and group.accent or HudIcons.DefaultAccent,
			Parent = holder,
		}, { Theme.Round("Round"), New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.45, Thickness = 1.5 }) })
		local label = Theme.Text({
			LayoutOrder = 2,
			Text = "+" .. Muscles.FormatExpShort(amount),
			Font = "SemiBold",
			TextSize = style.TextSize,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextColor3 = if gold then Colors.Gold else style.Color,
			Parent = holder,
		})
		local stroke = Theme.TextShadow(label, 0.4)
		-- Studio test hook: Workspace attribute "TestPopupSlow" = n makes them live n times longer (for screenshots)
		local slow = if RunService:IsStudio() then workspace:GetAttribute("TestPopupSlow") else nil
		local life = EXP_POP.Life * (if type(slow) == "number" and slow > 0 then slow else 1)
		local entry = { billboard = billboard }
		table.insert(expPops, entry)
		-- pop in with a bounce, drift up and out, fade in the second half
		Theme.Tween(pop, { Scale = 1 }, 0.18, Theme.Motion.Bounce)
		TweenService:Create(billboard, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = start + drift }):Play()
		task.delay(life * 0.45, function()
			if not billboard.Parent then return end
			local fade = TweenInfo.new(life * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
			TweenService:Create(chip, fade, { BackgroundTransparency = 1 }):Play()
			local chipStroke = chip:FindFirstChildOfClass("UIStroke")
			if chipStroke then TweenService:Create(chipStroke, fade, { Transparency = 1 }):Play() end
		end)
		task.delay(life, function() dropExpPop(entry) end)
	end
	-- All of one rep's popups (xp = Gains.PerRep: raw xp per muscle).
	function ExpPops.Show(character, machine, xp, gold: boolean)
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if not torso or not torso:IsA("BasePart") then return end
		for index, entry in ipairs(machine.muscles) do
			local amount = Muscles.ShownXp(xp[entry.id] or 0)
			if amount >= 1 then expPopup(torso, entry.id, amount, index == 1, gold and index == 1, index) end
		end
	end
	function ExpPops.On(): boolean
		local settings = ClientData.Get().settings
		return not (settings and settings.expPopups == "Off")
	end
	
end

------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal
local Left, Right = Enum.HorizontalAlignment.Left, Enum.HorizontalAlignment.Right

local gui = Theme.ScreenGui({
	Name = "MachineHud",
	Enabled = false,
	DisplayOrder = 5,
	Parent = waitFor(player, "PlayerGui"),
})

local column = New("Frame", {
	Name = "Column",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	Theme.List(Vertical, "M", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
	New("UIPadding", { PaddingBottom = UDim.new(0, Spacing.XS) }),
})

-- phones: the thumbstick and jump button are hidden while lifting, so the panel sits left and leaves the right side
-- to the quest panel (top right)
do
	local columnList = column:FindFirstChildOfClass("UIListLayout")
	local columnPad = column:FindFirstChildOfClass("UIPadding")
	Theme.OnCompactChanged(function(isCompact)
		columnList.HorizontalAlignment = isCompact and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
		columnPad.PaddingLeft = UDim.new(0, isCompact and Spacing.M or 0)
	end)
end
local function box(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	return New("Frame", props, children)
end

local function iconSlot(order, icon, scale)
	return box({ LayoutOrder = order, Size = UDim2.fromScale(1, scale or 1) }, { Theme.Aspect(1, Enum.DominantAxis.Height), icon })
end

-- Compact stack: tape, panel, coach note.
local stackSlot = box({
	Name = "Stack",
	LayoutOrder = 1,
	Size = UDim2.fromScale(0.6, 0.32),
	Parent = column,
}, { Theme.Aspect(3.4), Theme.Limit(Vector2.new(540, 160), Vector2.new(680, 200)) })

-- Invisible button under the stack so taps on the HUD don't count as lifts.
New("TextButton", {
	Name = "TapBlocker",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 1,
	Parent = stackSlot,
})

local HIDDEN_OFFSET = UDim2.fromOffset(0, 320) -- the panel waits below the screen edge
local stack = New("Frame", {
	Name = "Group",
	Size = UDim2.fromScale(1, 1),
	Position = HIDDEN_OFFSET,
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = stackSlot,
}, {
	Theme.List(Vertical, "S", Left, Enum.VerticalAlignment.Bottom),
	New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.XS), PaddingRight = UDim.new(0, Spacing.XS), PaddingBottom = UDim.new(0, Spacing.XS) }),
})

local tapeRow = box({ Name = "TitleRow", LayoutOrder = 1, Size = UDim2.fromScale(1, 0.16), ZIndex = 3, Parent = stack })
local titleLabel = Theme.Text({
	Name = "MachineName",
	Font = "SemiBold",
	TextSize = "Body",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, Spacing.S, 1, 0),
	Size = UDim2.fromScale(0.6, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = tapeRow,
})
Theme.TextShadow(titleLabel)

local panel = Theme.Panel({
	Name = "Panel",
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0.64),
	ZIndex = 2,
	Parent = stack,
}, {
	Theme.Pad("M"),
	Theme.List(Horizontal, "S", Left),
})

local noteRow = box({ Name = "NoteRow", LayoutOrder = 3, Size = UDim2.fromScale(1, 0.12), Parent = stack },
	{ New("UIPadding", { PaddingLeft = UDim.new(0, Spacing.L) }) })
local noteLabel = Theme.Text({
	Name = "CoachNote",
	Font = "Regular",
	TextSize = "Small",
	TextColor3 = Colors.Muted,
	Size = UDim2.fromScale(0.85, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = noteRow,
})
Theme.TextShadow(noteLabel)

---------------------------------------------------------------- weight selector
local weightSection = box({ Name = "Weight", LayoutOrder = 1, Size = UDim2.fromScale(0.34, 1), Parent = panel },
	{ Theme.List(Horizontal, "S") })

local function stepButton(name, order, icon)
	return Theme.Button("Secondary", { Name = name, LayoutOrder = order, Size = UDim2.fromScale(1, 0.56), Parent = weightSection }, {
		Theme.Aspect(1, Enum.DominantAxis.Height),
		Theme.Limit(Vector2.new(Theme.MinTouch, Theme.MinTouch), Vector2.new(math.huge, math.huge)),
		Theme.Pad("M"),
		icon,
	})
end
local minusButton = stepButton("Minus", 1, Icons.Minus(Colors.Text))
local weightColumn = box({ LayoutOrder = 2, Size = UDim2.fromScale(0.38, 1), Parent = weightSection }, { Theme.List(Vertical, "XS") })
local plusButton = stepButton("Plus", 3, Icons.Plus(Colors.Text))

local weightNumber = Theme.Text({ LayoutOrder = 1, Font = "SemiBold", TextSize = "Huge", Size = UDim2.fromScale(1, 0.56), Parent = weightColumn })
local tierLabel = Theme.Text({ LayoutOrder = 2, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.fromScale(1, 0.24), Parent = weightColumn })

---------------------------------------------------------------- barbell + muscles / unlock
local barSection = box({ Name = "Barbell", LayoutOrder = 2, Size = UDim2.fromScale(0.25, 1), Parent = panel },
	{ Theme.List(Vertical, "XS") })
local barbell = box({ Name = "Graphic", LayoutOrder = 1, Size = UDim2.fromScale(1, 0.4), Parent = barSection })
local barInfo = box({ Name = "Info", LayoutOrder = 2, Size = UDim2.fromScale(1, 0.56), Parent = barSection })

local musclesLabel = Theme.Text({
	Font = "Regular",
	TextSize = "Small",
	TextColor3 = Colors.Muted,
	Size = UDim2.fromScale(1, 1),
	TextWrapped = true,
	Parent = barInfo,
})
local needsLabel = Theme.Text({
	Font = "Regular",
	TextSize = "Small",
	TextColor3 = Colors.NeedsWork,
	Size = UDim2.fromScale(1, 1),
	TextWrapped = true,
	Visible = false,
	Parent = barInfo,
})
local unlockButton = Theme.Button("Primary", {
	Name = "Unlock",
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Parent = barInfo,
}, {
	Theme.Limit(Vector2.new(0, Theme.MinTouch), Vector2.new(math.huge, math.huge)),
	Theme.List(Horizontal, "XS"),
	Theme.Pad("S"),
})
local unlockText = Theme.Text({ LayoutOrder = 1, Text = "Unlock", Font = "SemiBold", TextSize = "Body", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Parent = unlockButton })
local unlockIcon = iconSlot(2, Icons.Plate(Colors.Text))
unlockIcon.Parent = unlockButton
local costLabel = Theme.Text({ LayoutOrder = 3, Font = "SemiBold", TextSize = "Body", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Parent = unlockButton })

local barPlates = {} -- plate frames in the HUD barbell (for the heavy-rep jiggle)

-- Side view of a loaded barbell; each plate in its weight's color (Machines.Plates).
local function drawBarbell(tier)
	barbell:ClearAllChildren()
	table.clear(barPlates)
	Theme.List(Horizontal, nil).Parent = barbell
	local order = 0
	local function piece(width, height, color, extra)
		order += 1
		return box({ LayoutOrder = order, Size = UDim2.fromScale(width, height), BackgroundTransparency = 0, BackgroundColor3 = color, Parent = barbell }, extra)
	end
	local function plates(list)
		for _, lb in ipairs(list) do
			local spec = Machines.Plates[lb]
			local bumper = Theme.Bumper[spec and spec.color or "White"] or Theme.Bumper.White
			local height = spec and spec.diameter / 2.3 * 0.95 or 0.6
			table.insert(barPlates, piece(0.05, height, bumper.Fill, { Theme.Round("Segment"), Theme.Stroke(bumper.Rim, Theme.IconStroke) }))
		end
	end
	local reversed = {}
	for i = #tier.plates, 1, -1 do table.insert(reversed, tier.plates[i]) end

	piece(0.06, 0.1, Colors.Muted)   -- sleeve end
	plates(reversed)
	piece(0.025, 0.36, Colors.Muted) -- collar
	local shaft = piece(0, 0.07, Colors.Muted)
	New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = shaft })
	piece(0.025, 0.36, Colors.Muted)
	plates(tier.plates)
	piece(0.06, 0.1, Colors.Muted)
end

---------------------------------------------------------------- reps + stamina
local staminaSection = box({ Name = "Stamina", LayoutOrder = 3, Size = UDim2.fromScale(0.22, 1), Parent = panel },
	{ Theme.List(Vertical, "XS", Left) })
local repsLabel = Theme.Text({ LayoutOrder = 1, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 0.3), TextXAlignment = Enum.TextXAlignment.Left, Parent = staminaSection })
local repsScale = New("UIScale", { Parent = repsLabel })
Theme.Text({ LayoutOrder = 2, Text = "Stamina", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.fromScale(1, 0.26), TextXAlignment = Enum.TextXAlignment.Left, Parent = staminaSection })
local segmentRow = box({ LayoutOrder = 3, Size = UDim2.fromScale(1, 0.32), Parent = staminaSection }, { Theme.List(Horizontal, "XS", Left) })
local segmentBacks, segments = {}, {}
for i = 1, STAMINA_SEGMENTS do
	segmentBacks[i] = box({ LayoutOrder = i, Size = UDim2.fromScale(0, 1), BackgroundTransparency = SEGMENT_BACK, BackgroundColor3 = Colors.Text, Parent = segmentRow },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	segments[i] = box({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Colors.Text, Parent = segmentBacks[i] },
		{ Theme.Round("Segment") })
end

---------------------------------------------------------------- coins + exit
local endSection = box({ Name = "End", LayoutOrder = 4, Size = UDim2.fromScale(0.13, 1), Parent = panel },
	{ Theme.List(Vertical, "S", Right) })
local coinRow = box({ LayoutOrder = 1, Size = UDim2.fromScale(1, 0.3), Parent = endSection }, { Theme.List(Horizontal, "XS", Right) })
iconSlot(1, Icons.Plate(), 0.6).Parent = coinRow
local coinLabel = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(0.6, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = coinRow })
local exitButton = Theme.Button("Secondary", { Name = "Exit", LayoutOrder = 2, Size = UDim2.fromScale(1, 0.5), Parent = endSection }, {
	Theme.Limit(Vector2.new(Theme.MinTouch, Theme.MinTouch), Vector2.new(math.huge, math.huge)),
	Theme.Text({ Text = "Exit", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(0.8, 0.6), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }),
})

------------------------------------------------------------------------
-- HUD state
------------------------------------------------------------------------
local viewTier = 1
local lastStamina = nil
local baseFov = nil

local function progressFor(machineId)
	local progress = ClientData.Get().machines[machineId]
	return progress and progress.unlocked or 1, progress and progress.selected or 1
end

local function mainLevel(machine)
	return ClientData.Get().muscles[machine.muscles[1].id].level
end

-- The tier this player lifts right now (selected, but never above what the level allows; same as the server).
local function liftTier(machine)
	return Machines.LiftTier(machine, ClientData.Get().machines[machine.id], mainLevel(machine))
end

local function staminaRatio()
	local max = player:GetAttribute("MaxStamina") -- Iron Lungs
	return math.clamp(ClientData.Get().stamina / (type(max) == "number" and max or Stamina.Max), 0, 1)
end

local function refreshCoins()
	coinLabel.Text = Muscles.FormatExp(ClientData.Get().coins)
end

local function staminaColor(ratio)
	return ratio < STAMINA_LOW and Colors.NeedsWork or Colors.Text
end

local function refreshStamina()
	local ratio = staminaRatio()
	local filled = ratio * STAMINA_SEGMENTS
	local color = staminaColor(ratio)
	for i, fill in ipairs(segments) do
		Theme.Tween(fill, { Size = UDim2.fromScale(math.clamp(filled - (i - 1), 0, 1), 1), BackgroundColor3 = color }, Theme.Motion.PressTime * 2)
	end
	-- the segment that just drained flashes
	if lastStamina and ClientData.Get().stamina < lastStamina then
		local back = segmentBacks[math.clamp(math.floor(filled) + 1, 1, STAMINA_SEGMENTS)]
		back.BackgroundTransparency = 0.35
		Theme.Tween(back, { BackgroundTransparency = SEGMENT_BACK }, Theme.Motion.Time * 1.6)
	end
	lastStamina = ClientData.Get().stamina
	if current then setSweat(ratio < FEEL.SweatBelow) end
end

local function refreshReps()
	repsLabel.Text = "Reps ×" .. (current and current.reps or 0)
end

local function bounceReps()
	repsScale.Scale = 1.3
	Theme.Tween(repsScale, { Scale = 1 }, Theme.Motion.Time * 1.4, Theme.Motion.Bounce)
end

-- Every rep: the muscle list ("Mid Chest · Front Delts · Triceps") brightens to white, then settles back to gray.
local function flashMuscles()
	musclesLabel.TextColor3 = Colors.Text
	Theme.Tween(musclesLabel, { TextColor3 = Colors.Muted }, Theme.Motion.Time * 2)
end

local function jigglePlates()
	for i, plate in ipairs(barPlates) do
		plate.Rotation = (i % 2 == 0 and 1 or -1) * 8
		Theme.Tween(plate, { Rotation = 0 }, Theme.Motion.Time * 1.4, Theme.Motion.Bounce)
	end
end

local function canUnlock(machine, tier)
	return mainLevel(machine) >= tier.unlockLevel and ClientData.Get().coins >= tier.cost
end

-- Recolor a line icon (lines are filled frames, outlines are strokes).
local function tintIcon(icon, color)
	for _, part in ipairs(icon:GetDescendants()) do
		if part:IsA("UIStroke") then
			part.Color = color
		elseif part:IsA("Frame") and part.BackgroundTransparency < 1 then
			part.BackgroundColor3 = color
		end
	end
end

-- Unavailable step buttons keep their space so nothing shifts.
local function setStepButton(button, shown)
	button.BackgroundTransparency = shown and Theme.Alpha.Panel or 1
	button.Active = shown
	button:FindFirstChildOfClass("UIStroke").Enabled = shown
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("Frame") then child.Visible = shown end
	end
	-- the soft shadow (Theme.AddDepth) too, or a ghost outline stays where the button was
	local depth = button:FindFirstChild("Depth")
	if depth then
		for _, shadow in ipairs(depth:GetChildren()) do
			if shadow:IsA("Frame") then shadow.Visible = shown end
		end
	end
end

local function refreshTier()
	if not current then return end
	local machine = current.machine
	local unlocked = progressFor(machine.id)
	local maxView = math.min(#machine.tiers, unlocked + 1)
	viewTier = math.clamp(viewTier, 1, maxView)

	local tier = machine.tiers[viewTier]
	local main = Muscles.ById[machine.muscles[1].id]
	local levelOk = mainLevel(machine) >= tier.unlockLevel
	-- bought tiers still need the level (again after a Growth Spurt)
	local locked = viewTier > unlocked or not levelOk
	weightNumber.Text = tier.label or tostring(tier.weight)
	weightNumber.TextColor3 = locked and Colors.Muted or Colors.Text
	tierLabel.Text = (if tier.unit then tier.unit .. " · " elseif tier.weight > 0 then "lb · " else "") .. "tier " .. viewTier .. " of " .. #machine.tiers
	setStepButton(minusButton, viewTier > 1)
	setStepButton(plusButton, viewTier < maxView)
	drawBarbell(tier)

	musclesLabel.Visible = not locked
	unlockButton.Visible = viewTier > unlocked and levelOk
	needsLabel.Visible = not levelOk
	if locked and levelOk then
		-- Can't afford yet: faded button with gray text.
		costLabel.Text = Muscles.FormatExp(tier.cost)
		local affordable = canUnlock(machine, tier)
		local ink = affordable and Colors.Text or Colors.Muted
		unlockButton.BackgroundTransparency = affordable and Theme.Alpha.Primary or 0.92
		unlockText.TextColor3 = ink
		costLabel.TextColor3 = ink
		tintIcon(unlockIcon, ink)
	elseif not levelOk then
		needsLabel.Text = "Needs " .. main.name .. " " .. Muscles.FormatExp(Muscles.Shown(tier.unlockLevel)) .. " exp"
	end
end

local function setNote(category)
	local lines = CoachNotes[category]
	local line = lines[math.random(#lines)]
	if #lines > 1 then
		while line == current.lastNote do line = lines[math.random(#lines)] end
	end
	current.lastNote = line
	current.setsSinceNote = 0
	Theme.Tween(noteLabel, { TextTransparency = 1 }, Theme.Motion.PressTime).Completed:Connect(function()
		noteLabel.Text = line
		Theme.Tween(noteLabel, { TextTransparency = 0 })
	end)
end

local function noteSituation()
	local machine = current.machine
	if staminaRatio() < FEEL.LowStamina then return "lowStamina" end
	local unlocked = progressFor(machine.id)
	local nextTier = machine.tiers[unlocked + 1]
	if nextTier and canUnlock(machine, nextTier) then return "unlockReady" end
	if liftTier(machine) < Machines.UsableTier(machine, ClientData.Get().machines[machine.id], mainLevel(machine)) then return "tooLight" end
	return "general"
end

local function fovPunch(amount)
	local camera = Workspace.CurrentCamera
	baseFov = baseFov or camera.FieldOfView
	camera.FieldOfView = baseFov + (amount or FEEL.FovPunch)
	Theme.Tween(camera, { FieldOfView = baseFov }, Theme.Motion.Time)
end

------------------------------------------------------------------------
-- PUMP meter: a slim segmented bar above the machine panel (bottom center, right of the machine name), so it never
-- sits on the phone thumbstick (bottom left) or the jump button (bottom right). There is no Lift button: tapping
-- anywhere that isn't a button (phone), clicking or Space (PC) counts as a tap. Visible only on a machine.
------------------------------------------------------------------------
local Pump = Gains.Pump
local PUMP_SEGMENTS = 10
local tryLift -- defined with the lifting code below

local pumpBar = box({
	Name = "PumpBar",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -Spacing.S, 1, 0),
	Size = UDim2.fromScale(0.46, 1),
	ZIndex = 3,
	Parent = tapeRow,
}, { Theme.List(Horizontal, "S", Right, Enum.VerticalAlignment.Center) })
local pumpLabel = Theme.Text({
	LayoutOrder = 1,
	Text = "Pump",
	Font = "SemiBold",
	TextSize = "Small",
	Size = UDim2.new(0.34, 0, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = pumpBar,
})
Theme.TextShadow(pumpLabel)
-- a dark backing behind the segments; it gets a gold border that glows while PUMPED
local pumpBack = box({
	LayoutOrder = 2,
	Size = UDim2.new(0.62, 0, 0, 14),
	BackgroundTransparency = Theme.Alpha.Panel,
	BackgroundColor3 = Colors.Panel,
	Parent = pumpBar,
}, { Theme.Round("Segment"), New("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }) })
local pumpGlow = New("UIStroke", { Color = Colors.Gold, Thickness = 1.5, Transparency = 1, Parent = pumpBack })
local pumpRow = box({ Size = UDim2.fromScale(1, 1), Parent = pumpBack }, { Theme.List(Horizontal, "XS") })
local pumpSegments = {}
for i = 1, PUMP_SEGMENTS do
	local back = box({ LayoutOrder = i, Size = UDim2.fromScale(0, 1), BackgroundTransparency = SEGMENT_BACK, BackgroundColor3 = Colors.Text, Parent = pumpRow },
		{ Theme.Round("Segment"), New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	pumpSegments[i] = box({ Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = Colors.Text, Parent = back }, { Theme.Round("Segment") })
end
titleLabel.Size = UDim2.fromScale(0.5, 1) -- the machine name keeps the left half

-- one-time hint for players who haven't pumped yet ("Tap to pump"), just above the bar; saved once seen
local pumpHint = Theme.Text({
	Text = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and "Tap to pump" or "Tap to pump (click or Space)",
	Font = "SemiBold",
	TextSize = "Small",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -Spacing.S, 0, -Spacing.XS),
	Size = UDim2.new(0.46, 0, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Right,
	Visible = false,
	Parent = tapeRow,
})
Theme.TextShadow(pumpHint)
local hintTaps = 0
local function hidePumpHint(save)
	if not pumpHint.Visible then return end
	pumpHint.Visible = false
	if save then Remotes.PlayerAction:FireServer("SetSettings", { pumpHintSeen = true }) end
end


-- Client prediction of the server's meter (MachineService): instant on tap, corrected by the player attributes.
local pumpMeter, pumpLastTap, pumpSettled = 0, 0, os.clock()
local tapTimes = {} -- recent tap clocks (the same rate limit as the server, so the prediction never runs ahead)

local function serverNow()
	return Workspace:GetServerTimeNow()
end
local function pumpedLeft()
	local untilTime = player:GetAttribute("PumpedUntil")
	return type(untilTime) == "number" and math.max(0, untilTime - serverNow()) or 0
end
local function isPumped()
	return pumpedLeft() > 0
end

local glows = {} -- Highlights on the trained parts while PUMPED
local function setPumpGlow(on)
	for _, glow in ipairs(glows) do glow:Destroy() end
	table.clear(glows)
	local character = player.Character
	if not on or not character or not current then return end
	local seen = {}
	for _, entry in ipairs(current.machine.muscles) do
		for _, partName in ipairs(Muscles.Body[entry.id].pump) do
			local part = character:FindFirstChild(partName)
			if part and not seen[part] then
				seen[part] = true
				table.insert(glows, New("Highlight", {
					Adornee = part,
					FillColor = Colors.Gold,
					FillTransparency = 0.8,
					OutlineColor = Colors.Gold,
					OutlineTransparency = 0.55,
					DepthMode = Enum.HighlightDepthMode.Occluded,
					Parent = part,
				}))
			end
		end
	end
end

local wasPumped = false
local function refreshPump(now)
	local left = pumpedLeft()
	local pumped = left > 0
	if pumped ~= wasPumped then
		wasPumped = pumped
		if pumped then
			pumpMeter = 0
			Audio.Play2D("PumpFull")
			fovPunch(FEEL.FovPunchBig)
			if player.Character then
				chalkPuff(player.Character, 16)
				if current then pumpBurst(player.Character, current.machine) end
			end
		end
		setPumpGlow(pumped)
		pumpLabel.Text = pumped and "PUMPED  x2" or "Pump"
		pumpLabel.TextColor3 = pumped and Colors.Gold or Colors.Text
		pumpGlow.Transparency = pumped and 0.15 or 1
	end
	-- drain while not tapping (same rule as the server)
	local from = math.max(pumpSettled, pumpLastTap + Pump.DrainDelay)
	if not pumped and now > from and pumpMeter > 0 then
		pumpMeter = math.max(0, pumpMeter - Pump.DrainPerSecond * (now - from))
	end
	pumpSettled = now
	local fill = pumped and (left / Pump.Duration) or pumpMeter
	local color = pumped and Colors.Gold or Colors.Text
	for i, segment in ipairs(pumpSegments) do
		segment.Size = UDim2.fromScale(math.clamp(fill * PUMP_SEGMENTS - (i - 1), 0, 1), 1)
		segment.BackgroundColor3 = color
	end
	if pumped then
		local pulse = 0.75 + 0.1 * math.sin(now * 8)
		pumpLabel.Text = "PUMPED " .. math.ceil(left) .. "s"
		pumpGlow.Transparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(now * 6))
		for _, glow in ipairs(glows) do glow.FillTransparency = pulse end
	end
end

-- One tap: counts toward the meter (rate limited like the server) and tells the server.
local function registerTap()
	local now = os.clock()
	for i = #tapTimes, 1, -1 do
		if now - tapTimes[i] > 1 then table.remove(tapTimes, i) end
	end
	if #tapTimes >= Pump.TapsPerSecond then return end
	table.insert(tapTimes, now)
	pumpLastTap = now
	if not isPumped() then
		pumpMeter = math.min(1, pumpMeter + 1 / Pump.TapsToFill)
	end
	Remotes.MachineAction:FireServer("Tap")
	-- the button breathes with every tap
	pumpLabel.TextSize = Theme.TextSize.Small + 2
	if pumpHint.Visible then
		hintTaps += 1
		if hintTaps >= 3 then hidePumpHint(true) end
	end
	Theme.Tween(pumpLabel, { TextSize = Theme.TextSize.Small }, Theme.Motion.PressTime * 2)
end

-- the server's meter wins when they drift (e.g. taps lost on a slow connection)
player:GetAttributeChangedSignal("PumpMeter"):Connect(function()
	local server = player:GetAttribute("PumpMeter")
	if type(server) == "number" and math.abs(server - pumpMeter) > 0.2 then pumpMeter = server end
end)

------------------------------------------------------------------------
-- Big moments: level-up flash, NEW PR banner (both small, never full screen)
------------------------------------------------------------------------
local levelFlash = Theme.Text({
	Name = "LevelFlash",
	Text = "",
	Font = "SemiBold",
	TextSize = "Large",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -Spacing.S, 0, -24), -- above the pump hint
	Size = UDim2.new(0.5, 0, 0, 28),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextTransparency = 1,
	ZIndex = 4,
	Parent = tapeRow,
})
local levelFlashStroke = Theme.TextShadow(levelFlash)
local levelFlashScale = New("UIScale", { Parent = levelFlash })
local flashToken = 0

local function sparkleBurst(character, color)
	local torso = character and character:FindFirstChild("UpperTorso")
	if not torso then return end
	local attachment = New("Attachment", { Parent = torso })
	local emitter = New("ParticleEmitter", {
		Texture = PARTICLE_DROP,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		Rate = 0,
		LightEmission = 0.6,
		Parent = attachment,
	})
	emitter:Emit(18)
	Debris:AddItem(attachment, 1.2)
end

local function flashLevel(name, level, text: string?)
	flashToken += 1
	local token = flashToken
	levelFlash.Text = text or (name .. " · " .. Muscles.FormatExp(Muscles.Shown(level)) .. " exp")
	levelFlash.TextTransparency = 0
	levelFlashStroke.Transparency = Theme.Alpha.TextShadow
	levelFlashScale.Scale = 0.6
	Theme.Tween(levelFlashScale, { Scale = 1 }, Theme.Motion.Time * 1.4, Theme.Motion.Bounce)
	task.delay(1.2, function()
		if token ~= flashToken then return end
		Theme.Tween(levelFlash, { TextTransparency = 1 }, Theme.Motion.Time * 2)
		Theme.Tween(levelFlashStroke, { Transparency = 1 }, Theme.Motion.Time * 2)
	end)
	sparkleBurst(player.Character, Colors.Text)
end

local prBanner = Theme.Panel({
	Name = "PersonalRecord",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 84),
	Size = UDim2.fromOffset(240, 58),
	Visible = false,
	ZIndex = 5,
	Parent = gui,
}, { Theme.List(Vertical, "XS"), Theme.Pad("S") })
local prTitle = Theme.Text({ LayoutOrder = 1, Text = "NEW PR", Font = "SemiBold", TextSize = "Large", TextColor3 = Colors.Gold, Size = UDim2.new(1, 0, 0, 24), Parent = prBanner })
local prInfo = Theme.Text({ LayoutOrder = 2, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), Parent = prBanner })
local prToken = 0

local function showPersonalRecord(weightText)
	if not current then return end
	prToken += 1
	local token = prToken
	prTitle.Text = "NEW PR"
	prInfo.Text = current.machine.name .. " · " .. weightText
	prBanner.Visible = true
	prBanner.Position = UDim2.new(0.5, 0, 0, 60)
	Theme.Tween(prBanner, { Position = UDim2.new(0.5, 0, 0, 84) }, Theme.Motion.Time * 1.4, Theme.Motion.Bounce)
	Theme.Fade(prBanner, true)
	Audio.Play2D("PersonalRecord")
	fovPunch(FEEL.FovPunchBig)
	sparkleBurst(player.Character, Colors.Gold)
	task.delay(2.6, function()
		if token ~= prToken then return end
		local tween = Theme.Fade(prBanner, false)
		if tween then
			tween.Completed:Connect(function()
				if token == prToken then prBanner.Visible = false end
			end)
		end
	end)
end

------------------------------------------------------------------------
-- Lifting (local player)
------------------------------------------------------------------------
local lastOutOfStaminaSound = 0
local function outOfStamina()
	refreshStamina()
	for _, back in ipairs(segmentBacks) do
		back.BackgroundColor3, back.BackgroundTransparency = Colors.NeedsWork, 0.4
		Theme.Tween(back, { BackgroundColor3 = Colors.Text, BackgroundTransparency = SEGMENT_BACK }, Theme.Motion.Time * 2)
	end
	Notify.Show("Out of stamina. Catch your breath.", nil, "stamina")
	-- one breath per empty-tank moment, not one per tap
	if os.clock() - lastOutOfStaminaSound > 2.5 then
		lastOutOfStaminaSound = os.clock()
		Audio.Play2D("OutOfStamina")
	end
end

-- auto = started by the slow automatic pace (no tap): no out-of-stamina warning, it just waits for the refill
local function beginRep(auto)
	if not current then return end
	local data = ClientData.Get()
	if data.stamina < current.machine.staminaCost then
		if not auto then outOfStamina() end
		return
	end
	local now = os.clock()
	if current.lastLockout and now - current.lastLockout > FEEL.SetBreak then
		current.reps = 0
		current.setGain = 0 -- a new set: the "Set done" total starts over too
		refreshReps()
		current.setsSinceNote += 1
		if current.setsSinceNote >= FEEL.NoteEvery then
			setNote(noteSituation())
		end
	end
	local duration = startRep(current.model, liftTier(current.machine), staminaRatio() < FEEL.LowStamina, isPumped())
	-- this rep's BIG REP roll came with the last rep's result
	repState[current.model].big = current.nextBig
	repState[current.model].pumped = isPumped()
	current.nextBig = false
	current.repEnd = now + duration
	Remotes.MachineAction:FireServer("Lift")
end

-- A tap: fills the PUMP meter, and starts the next rep now (or right after the current one).
function tryLift()
	if not current then return end
	registerTap()
	local now = os.clock()
	if current.repEnd and now < current.repEnd then
		current.queued = true
		return
	end
	beginRep()
end

-- The slow automatic pace: a rep starts on its own a little after the last one ends.
RunService.Heartbeat:Connect(function()
	if not current then return end
	local now = os.clock()
	refreshPump(now)
	if current.repEnd and now < current.repEnd + Gains.AutoRepGap then return end
	if current.queued then return end
	if ClientData.Get().stamina < current.machine.staminaCost then return end
	beginRep(true)
end)

-- The local player's lockout: count the rep and fire all the feedback.
local function localLockout(state)
	local machine, machineModel = current.machine, current.model
	local character = player.Character
	current.lastLockout = os.clock()
	current.reps += 1
	refreshReps()
	bounceReps()
	Audio.Play2D("RepTick")

	local setDone = current.reps % FEEL.SetSize == 0
	-- the main muscle's gain (same boosts as the server, incl. PUMPED/BIG REP), rounded the way it's shown; the set
	-- popup adds these up
	local main = machine.muscles[1].id
	local quality = (state.pumped and Gains.Pump.Multiplier or 1) * (state.big and Gains.BigRep.Multiplier or 1)
	local cardio = machine.trains == "Stamina" -- (the treadmill trains stamina: its numbers are the distance run)
	local xp = if cardio then {} else Gains.PerRep(ClientData.Get(), machine, state.tier, player:GetAttribute("GainsBoost"), quality)
	local shown = if cardio then machine.tiers[state.tier].weight * Machines.Cardio.MetersPerMph else math.max(1, Muscles.ShownXp(xp[main] or 0))
	current.setGain = (current.setGain or 0) + shown
	local mode = gainNumbersMode()
	local showSet = mode ~= "Off" -- On and Minimal
	local showRep = mode == "On"
	-- (a BIG REP on the last rep of a set still ends in the "Set done" popup: its total already includes the big rep)
	if character and cardio then
		if setDone and showSet then
			gainPopup(character, "Set done · " .. Muscles.FormatExp(current.setGain) .. " m run", POPUP.SetScale, machineModel)
		elseif not setDone and showRep then
			gainPopup(character, "+" .. Muscles.FormatExp(shown) .. " m", 1, machineModel)
		end
	elseif character and setDone and showSet then
		local group = Muscles.GroupById[Muscles.ById[main].group]
		gainPopup(character, "Set done · +" .. Muscles.FormatExp(current.setGain) .. " " .. group.name, POPUP.SetScale, machineModel)
		if state.big then Audio.Play2D("BigRep") end
	elseif character and state.big and showSet then
		-- BIG REP: gold and bigger; Minimal still shows it
		gainPopup(character, "BIG REP +" .. Muscles.FormatExp(shown), POPUP.SetScale * 1.1, machineModel, Colors.Gold)
		Audio.Play2D("BigRep")
	elseif character and not setDone and showRep and not ExpPops.On() then
		gainPopup(character, "+" .. Muscles.FormatExp(shown), 1, machineModel, state.pumped and Colors.Gold or nil)
	end
	-- the per-rep EXP popups, one per trained muscle (every rep, the set's last one too)
	if character and not cardio and showRep and ExpPops.On() then
		ExpPops.Show(character, machine, xp, state.pumped or state.big)
	end
	if setDone then current.setGain = 0 end
	flashMuscles() -- the secondary muscles get a flash of the HUD's muscle list instead of popups
	if character and not cardio then repFlash(character, machine, state.big or state.pumped) end

	-- every rep a small camera punch; heavy tiers and BIG REPs hit harder
	fovPunch(state.big and FEEL.FovPunchBig or (state.tier >= FEEL.HeavyTier and FEEL.FovPunchHeavy or FEEL.FovPunch))
	if state.big then chalkPuff(character, 14) end
	if state.tier >= FEEL.HeavyTier or state.big then
		jigglePlates()
	end

	current.repsSinceBreath = (current.repsSinceBreath or 0) + 1
	local straining = state.tier >= FEEL.HeavyTier or staminaRatio() < FEEL.LowStamina
	if straining and current.repsSinceBreath >= FEEL.BreathMinGap and math.random() < FEEL.BreathChance then
		current.repsSinceBreath = 0
		local head = character and character:FindFirstChild("Head")
		if head then Audio.PlayAt("Breath", head) end
	end

	if setDone then
		Audio.Play2D("SetComplete")
		if character then chalkPuff(character, 20) end
	end
end

-- { [muscle id] = share } a machine trains (none for the treadmill: it trains stamina)
function bars.trainingShares(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	if not machine or machine.trains == "Stamina" then return nil end
	local shares = {}
	for _, muscle in ipairs(machine.muscles) do shares[muscle.id] = muscle.share or 1 end
	return shares
end

-- Lockout for any lifter (everyone hears the clank and sees the pump).
local function onLockout(model, character, state)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	-- deeper for heavier tiers; Audio adds the random +-5%
	local pitch = 1 - FEEL.ClankDeeperPerTier * (state.tier - 1)
	local bar = barOf(model)
	Audio.PlayAt("Clank", bar, { pitch = pitch })
	if state.tier >= FEEL.HeavyTier then Audio.PlayAt("PlateKnock", bar, { pitch = pitch }) end
	if machine then pump(character, machine) end
	if current and model == current.model then
		localLockout(state)
	elseif machine and machine.trains ~= "Stamina" then
		MuscleRig.Flash(character, nil, state.big) -- (their training tint's rep pulse)
	end
end

-- Arms are posed before physics so they override animations...
RunService.Stepped:Connect(function()
	local now = os.clock()
	for model in pairs(barRest) do
		local character = userCharacter(model)
		-- someone else's lift far from the camera or off the screen: not animated (the bar waits on the rack), so a busy gym
		-- costs nothing
		if character and character ~= player.Character
			and not (bars.near(barRest[model].Position, Machines.ClientCull.AnimateDistance) and bars.onScreen(barRest[model].Position, 6)) then
			character = nil
			repState[model] = nil
		end
		if character then
			local state = repState[model]
			local depth, phase = 0, nil
			if state then
				depth, phase = repDepth(state, now)
				if (phase == "hold" or phase == "done") and not state.lockedOut then
					state.lockedOut = true
					onLockout(model, character, state)
				end
				if phase == "done" then
					repState[model] = nil
					if current and model == current.model and current.queued then
						current.queued = false
						beginRep()
					end
				end
			end
			-- contract poses rest relaxed: a rep goes relaxed -> contracted -> relaxed (Config.Poses contract)
			if (Poses[poseFor(model)] or {}).contract then depth = 1 - depth end
			-- Studio test hook: Workspace attribute "TestPoseDepth" (0..1) freezes every pose at that depth (after the flip: 1 = relaxed)
			if RunService:IsStudio() and type(workspace:GetAttribute("TestPoseDepth")) == "number" then depth = workspace:GetAttribute("TestPoseDepth") end
			animate(model, character, depth, state and state.shake and phase == "press")
			if posed[model] ~= character then
				-- the training tint (cool blue on the muscles this machine trains) for as long as they're on it
				if posed[model] then MuscleRig.SetTraining(posed[model], nil) end
				MuscleRig.SetTraining(character, bars.trainingShares(model))
			end
			posed[model] = character
			if model:GetAttribute("Stack") then placeStack(model, depth) end
		elseif posed[model] then
			MuscleRig.SetTraining(posed[model], nil)
			resetPose(posed[model])
			bars.resetProps(model)
			posed[model] = nil
			repState[model] = nil
			if model:GetAttribute("Stack") then
				placeStack(model, 0.999)
			else
				placeBar(model, barRest[model])
			end
		end
	end
end)

-- ...and the bar rides in the hands after physics has moved them.
RunService.Heartbeat:Connect(function()
	for model, character in pairs(posed) do
		local cframe = model.Parent and followCFrame(model, character)
		if cframe then
			placeBar(model, cframe)
		end
		local props = bars.props[poseFor(model)]
		if props and model.Parent then props(model, character) end
	end
end)

local function setupMachine(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	local loadName = machine and machine.load or "Bar"
	-- The load part comes with the model; "Plates" is made by MachineService when the server starts, and with Workspace
	-- streaming a machine's children can arrive late. Set up once both are there, without yielding: a machine whose
	-- Plates never comes (e.g. the server failed to start) just stays idle, with no infinite-yield warning.
	local ready = false
	local watch
	local function trySetup()
		if ready then return end
		local bar, plates = model:FindFirstChild(loadName), model:FindFirstChild("Plates")
		if not bar or not plates then return end
		ready = true
		if watch then watch:Disconnect() end
		barRest[model] = bar.CFrame
		for _, plate in ipairs(plates:GetDescendants()) do trackPlate(model, plate) end
		-- the sled / carriage parts that move with the load (leg press, hack squat)
		local rides = model:FindFirstChild("Rides")
		if rides then
			for _, part in ipairs(rides:GetDescendants()) do trackPlate(model, part) end
		end
		plates.DescendantAdded:Connect(function(plate) trackPlate(model, plate) end)
		plates.DescendantRemoving:Connect(function(plate)
			plateOffsets[plate] = nil
			bars.moving[model], bars.placed[model] = nil, nil
		end)
		model:GetAttributeChangedSignal("Reps"):Connect(function()
			-- our own reps start instantly on tap; other lifters start when the server counts them
			if model:GetAttribute("UserId") ~= player.UserId then
				startRep(model, model:GetAttribute("Tier"), false)
			end
		end)
	end
	watch = model.ChildAdded:Connect(trySetup)
	trySetup()
end

for _, model in ipairs(CollectionService:GetTagged("Machine")) do task.spawn(setupMachine, model) end
CollectionService:GetInstanceAddedSignal("Machine"):Connect(setupMachine)

------------------------------------------------------------------------
-- Input + session
------------------------------------------------------------------------
-- Tap/click anywhere that isn't UI lifts. Space / gamepad A also lift.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not current then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		tryLift()
	end
end)

-- Auto Lift pass: while it's switched on, keep lifting (same path as a tap, so it looks and sounds the same).
task.spawn(function()
	while true do
		task.wait(0.15)
		if current and player:GetAttribute("Pass_AutoLift") and player:GetAttribute("AutoLiftOn") then
			local data = ClientData.Get()
			if data.stamina >= current.machine.staminaCost then tryLift() end
		end
	end
end)

local function onLiftAction(_, state)
	if state == Enum.UserInputState.Begin then tryLift() end
	return Enum.ContextActionResult.Sink
end

-- Getting on a machine: turn the (normal, player-controlled) camera once to a 3/4 view from the open-room side, so
-- the lift is in view instead of whatever angle you walked in with (e.g. behind the squat rack's plates).
local CAMERA_VIEW = { Distance = 10, Height = 4, Angles = { 35, -35, 0, 60, -60 } }
local function frameCamera(model)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or camera.CameraType ~= Enum.CameraType.Custom then return end
	-- the open side of the room: toward the middle of the machines around this one
	local here = model:GetPivot().Position
	local sum, count = Vector3.zero, 0
	for _, other in ipairs(CollectionService:GetTagged("Machine")) do
		if other:IsA("Model") and other ~= model and (other:GetPivot().Position - here).Magnitude < 60 then
			sum += other:GetPivot().Position
			count += 1
		end
	end
	if count == 0 then return end
	local toRoom = (sum / count - here) * Vector3.new(1, 0, 1)
	if toRoom.Magnitude < 1 then return end
	toRoom = toRoom.Unit
	local focus = root.Position + Vector3.new(0, 1, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, model }
	-- first angle with a clear line from the lifter to the camera (else the clearest one)
	local best, bestClear = nil, -1
	for _, angle in ipairs(CAMERA_VIEW.Angles) do
		local dir = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(toRoom)
		local offset = dir * CAMERA_VIEW.Distance + Vector3.new(0, CAMERA_VIEW.Height, 0)
		local hit = Workspace:Raycast(focus, offset, params)
		local clear = hit and (hit.Position - focus).Magnitude or offset.Magnitude
		if clear > bestClear then best, bestClear = focus + offset, clear end
		if not hit then break end
	end
	-- the default camera keeps its own zoom; it only takes the direction from this
	if best then camera.CFrame = CFrame.lookAt(best, focus) end
end

local function open(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	if not machine then return end
	-- repEnd = now: the first automatic rep starts after the normal short gap (time to see the HUD slide up)
	current = { model = model, machine = machine, reps = 0, setsSinceNote = 0, promptConnections = {}, nextBig = false,
		repEnd = os.clock() }
	pumpMeter, pumpLastTap, pumpSettled = 0, 0, os.clock()
	wasPumped = false
	pumpLabel.Text, pumpLabel.TextColor3 = "Pump", Colors.Text
	pumpGlow.Transparency = 1
	bars.travel[model] = nil -- measure this lift's bar path fresh
	-- the lifter never sees this machine's prompts (e.g. "Spot · Help them lift" on their own machine), only on this
	-- client, so other players still get them; the server's next change after Exit replaces this local value
	for _, prompt in ipairs(model:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = false
			table.insert(current.promptConnections, prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				if prompt.Enabled then prompt.Enabled = false end
			end))
		end
	end
	local unlockedNow, selected = progressFor(machine.id)
	current.knownUnlocked = unlockedNow
	viewTier = selected
	baseFov = Workspace.CurrentCamera.FieldOfView
	lastStamina = nil

	titleLabel.Text = machine.name
	local names = {}
	for _, entry in ipairs(Machines.SharePercents(machine)) do
		table.insert(names, Muscles.ById[entry.id].name .. " " .. entry.pct .. "%")
	end
	musclesLabel.Text = if machine.trains == "Stamina" then "Stamina" else table.concat(names, " · ")
	refreshCoins()
	refreshStamina()
	refreshReps()
	refreshTier()
	setNote("firstSet")

	gui.Enabled = true
	SideMenu.SetTraining(true)
	Audio.PlayAt("BarRattle", barOf(model))
	stack.Position = HIDDEN_OFFSET
	Theme.Tween(stack, { Position = UDim2.new() }) -- slides up
	local settings = ClientData.Get().settings
	hintTaps = 0
	pumpHint.Visible = not (settings and settings.pumpHintSeen) -- once per player, gone after a few taps

	ContextActionService:BindActionAtPriority("MachineLift", onLiftAction, false,
		Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	-- chalk up as you grab the bar (hands need a frame to reach it)
	task.delay(0.15, function()
		if current and player.Character then chalkPuff(player.Character, 12) end
		if current and current.model == model then frameCamera(model) end
	end)
end

local function close()
	if current then
		-- racking the bar: a rattle, plus a rubber floor thud on lifting platforms
		local model = current.model
		Audio.PlayAt("BarRattle", barOf(model))
		if model:FindFirstChild("Platform") then Audio.PlayAt("FloorThud", barOf(model)) end
		for _, connection in ipairs(current.promptConnections) do connection:Disconnect() end
		-- The server re-enables the Use prompt just before it sends Exit, and the guard above already caught that change
		-- and switched it back off, so set the server's state here: Use = free again, Spot = nobody to spot.
		local free = model:GetAttribute("UserId") == nil
		for _, prompt in ipairs(model:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") then
				prompt.Enabled = prompt.Name ~= "SpotPrompt" and free
			end
		end
	end
	current = nil
	setPumpGlow(false)
	prBanner.Visible = false
	hidePumpHint(false)
	SideMenu.SetTraining(false)
	setSweat(false)
	if baseFov then Workspace.CurrentCamera.FieldOfView = baseFov end
	ContextActionService:UnbindAction("MachineLift")
	Theme.Tween(stack, { Position = HIDDEN_OFFSET }).Completed:Connect(function()
		if not current then gui.Enabled = false end
	end)
end

local function stepTier(delta)
	if not current then return end
	local unlocked, selected = progressFor(current.machine.id)
	local target = viewTier + delta
	if target < 1 or target > math.min(#current.machine.tiers, unlocked + 1) then return end
	viewTier = target
	Audio.PlayAt("PlateSlide", barOf(current.model)) -- plates on/off the bar
	local levelOk = mainLevel(current.machine) >= current.machine.tiers[viewTier].unlockLevel
	if viewTier <= unlocked and levelOk and viewTier ~= selected then
		Remotes.MachineAction:FireServer("SelectTier", viewTier)
	end
	refreshTier()
end

minusButton.Activated:Connect(function() stepTier(-1) end)
plusButton.Activated:Connect(function() stepTier(1) end)
exitButton.Activated:Connect(function()
	Remotes.MachineAction:FireServer("Leave")
end)
unlockButton.Activated:Connect(function()
	if not current then return end
	local tier = current.machine.tiers[viewTier]
	if viewTier > progressFor(current.machine.id) and canUnlock(current.machine, tier) then
		Remotes.MachineAction:FireServer("UnlockTier", viewTier)
	end
end)

Remotes.MachineState.OnClientEvent:Connect(function(state, model)
	if state == "Enter" then
		open(model)
	elseif state == "Exit" then
		close()
	end
end)

local lastLevelSound = 0
Remotes.RepResult.OnClientEvent:Connect(function(result)
	if result.noStamina then
		outOfStamina()
		return
	end
	if current then current.nextBig = result.nextBig == true end
	if result.pr and current then showPersonalRecord(result.pr) end
	if type(result.staminaUp) == "number" then
		flashLevel(nil, nil, "Max stamina · " .. Muscles.FormatExp(result.staminaUp))
		Audio.Play2D("LevelUp")
		lastLevelSound = os.clock()
	end
	local leveled = false
	-- the main muscle gets the small level-up flash (with a sparkle burst, now in EXP); secondary muscles only flash the HUD
	-- muscle list. (There is no level cap, so no muscle ever "maxes".)
	local mainId = current and current.machine.muscles[1].id
	for muscleId, level in pairs(result.levels or {}) do
		local name = Muscles.ById[muscleId].name
		if muscleId == mainId then flashLevel(name, level) end
		leveled = true
	end
	-- one sound per rep, however many muscles levelled; early levels come fast, so the ding is spaced out
	if leveled and os.clock() - lastLevelSound > 1.5 then
		lastLevelSound = os.clock()
		Audio.Play2D("LevelUp")
	end
end)

------------------------------------------------------------------------
-- Machine prompts: each machine's prompt shows this player's next weight and what it needs (local text only)
------------------------------------------------------------------------
local function promptText(machine)
	local data = ClientData.Get()
	local progress = data.machines[machine.id]
	local level = data.muscles[machine.muscles[1].id].level
	local usable = Machines.UsableTier(machine, progress, level)
	local nextTier = machine.tiers[usable + 1]
	if not nextTier then return machine.name .. " · max weight" end
	local main = Muscles.ById[machine.muscles[1].id]
	if level >= nextTier.unlockLevel then
		local bought = (progress and progress.unlocked or 1) > usable
		return machine.name .. " · " .. Machines.WeightText(nextTier)
			.. (bought and " is ready" or (" unlocks for " .. nextTier.cost .. " coins"))
	end
	return machine.name .. " · next " .. Machines.WeightText(nextTier) .. " at " .. main.name .. " " .. Muscles.FormatExp(Muscles.Shown(nextTier.unlockLevel)) .. " exp"
end

local function refreshPrompts()
	if not ClientData.Get().muscles then return end
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		local machine = Machines.ById[model:GetAttribute("MachineId")]
		if machine then
			for _, prompt in ipairs(model:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") and prompt.Name ~= "SpotPrompt" then prompt.ObjectText = promptText(machine) end
			end
		end
	end
end
task.spawn(function()
	while true do
		pcall(refreshPrompts)
		task.wait(2)
	end
end)

ClientData.Changed:Connect(function(path)
	local key = path[1]
	if key == "stamina" then
		if current then refreshStamina() end
	elseif key == "coins" then
		refreshCoins()
		refreshTier()
	elseif key == "machines" or key == "muscles" then
		-- heavier plates bought on this machine
		if key == "machines" and current and path[2] == current.machine.id then
			local unlocked = progressFor(current.machine.id)
			if current.knownUnlocked and unlocked > current.knownUnlocked then
				Audio.PlayAt("TierUnlocked", barOf(current.model))
			end
			current.knownUnlocked = unlocked
		end
		refreshTier()
	end
end)
