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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Machines = require(Config.Machines)
local Poses = require(Config.Poses)
local Muscles = require(Config.Muscles)
local Stamina = require(Config.Stamina)
local Gains = require(Config.Gains)
local GrowthSpurts = require(Config.GrowthSpurts)
local CoachNotes = require(Config.CoachNotes)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

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

-- every part of the plates (plate models, sleeves) rides with the bar
local function trackPlate(model, plate)
	if plate:IsA("BasePart") and barRest[model] then
		plateOffsets[plate] = barRest[model]:ToObjectSpace(plate.CFrame)
	end
end

local function loadPart(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	return model:FindFirstChild(machine and machine.load or "Bar")
end

-- [model] = { low = CFrame, high = CFrame }: the lowest and highest the bar has been while someone lifts on it
-- (the gain popup keeps clear of the whole path, not just where the bar is at lockout)
local barTravel = {}

local function placeBar(model, cframe)
	loadPart(model).CFrame = cframe
	local travel = barTravel[model]
	if not travel then
		barTravel[model] = { low = cframe, high = cframe }
	elseif cframe.Y < travel.low.Y then
		travel.low = cframe
	elseif cframe.Y > travel.high.Y then
		travel.high = cframe
	end
	for _, plate in ipairs(model.Plates:GetDescendants()) do
		local offset = plateOffsets[plate]
		if offset then plate.CFrame = cframe * offset end
	end
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
	local lift = Vector3.new(0, 1.6 * (1 - depth), 0)
	for part, cframe in pairs(rest) do
		local block = part.Parent and part.Parent.Name:match("^StackBlock(%d+)$") and part.Parent or part
		local index = tonumber(block.Name:match("^StackBlock(%d+)$") or "0")
		local lifted = part.Name == "TopPlate" or (index >= 1 and index <= count)
		part.CFrame = lifted and (cframe + lift) or cframe
	end
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

-- Pull-up: lockout = chin over the bar, bottom = dead hang. The body rises on the root.
POSE_ANIMS.PullUp = function(character, d, jitter)
	local rise = limbLength(character, "RightUpperArm", "RightLowerArm") * 0.35 * (1 - d)
	setJoint(character, "Root", CFrame.new(0, rise, 0))
	sideArms(character, 0, rad(95 + 70 * d), rad(120 * (1 - d)), jitter)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", Angles(rad(10), 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(-rad(50), 0, 0))
	end
end

-- Crunch: lying, plate held on the chest, knees up; lockout = curled up.
POSE_ANIMS.Crunch = function(character, d, jitter)
	setJoint(character, "Waist", Angles(-rad(40 * (1 - d)) - jitter * 0.3, 0, 0))
	frontArms(character, rad(40), rad(10), rad(110), 0)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", Angles(rad(55), 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(-rad(95), 0, 0))
		setJoint(character, side[1] .. "Ankle", Angles(rad(40), 0, 0))
	end
end

-- Pro gym poses (first pass, same helpers and angle conventions as the starter lifts above).
-- Dips: body sinks between the bars, elbows bend back, knees tucked.
POSE_ANIMS.Dip = function(character, d, jitter)
	setJoint(character, "Root", CFrame.new(0, -0.8 * d, 0))
	frontArms(character, -rad(10 + 30 * d) + jitter, rad(12), rad(90 * d), 0)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", Angles(rad(20), 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(-rad(70), 0, 0))
	end
end

-- Lateral raise: arms out to the sides up to shoulder height at lockout, elbows soft.
POSE_ANIMS.LateralRaise = function(character, d, jitter)
	sideArms(character, rad(5), rad(15 + 72 * (1 - d)), rad(12), jitter)
end

-- Reverse fly: bent over, arms swing out and back.
POSE_ANIMS.ReverseFly = function(character, d, jitter)
	lowerBody(character, rad(15), rad(40))
	setJoint(character, "Waist", Angles(-rad(10), 0, 0))
	frontArms(character, rad(50) + jitter, rad(15 + 65 * (1 - d)), rad(12), 0)
end

-- Shrugs: arms hang, shoulders lift at lockout.
POSE_ANIMS.Shrug = function(character, d, jitter)
	local lift = 0.28 * (1 - d) + jitter * 0.1
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Shoulder", CFrame.new(0, lift, 0) * Angles(0, 0, side[2] * rad(8)))
		setJoint(character, side[1] .. "Elbow", CFrame.identity)
	end
end

-- Leg curl: face down; heels curl toward the glutes at lockout, arms hold the pad overhead.
POSE_ANIMS.LegCurl = function(character, d, jitter)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Knee", Angles(-rad(20 + 100 * (1 - d)) - jitter, 0, 0))
	end
	frontArms(character, rad(165), rad(12), rad(20), 0)
end

-- Hip thrust: face up on the pad, knees bent; hips extend at lockout, flex at the bottom.
POSE_ANIMS.HipThrust = function(character, d, jitter)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", Angles(rad(10 + 60 * d) + jitter, 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(-rad(90), 0, 0))
	end
	frontArms(character, rad(10), rad(35), 0, 0)
end

-- Calf raise: up on the toes at lockout, hands on the handles.
POSE_ANIMS.CalfRaise = function(character, d, jitter)
	setJoint(character, "Root", CFrame.new(0, 0.35 * (1 - d), 0))
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Ankle", Angles(-rad(35 * (1 - d)) - jitter, 0, 0))
	end
	frontArms(character, rad(70), rad(10), rad(30), 0)
end

-- Bicep curl: curled up at lockout, arms long at the bottom.
POSE_ANIMS.BicepCurl = function(character, d, jitter)
	frontArms(character, rad(5), rad(10), rad(30 + 110 * (1 - d)), jitter)
end

-- Tricep pushdown: arms straight down at lockout, elbows bend up at the bottom, leaning in a little.
POSE_ANIMS.TricepPushdown = function(character, d, jitter)
	setJoint(character, "Waist", Angles(-rad(10), 0, 0))
	frontArms(character, rad(10), rad(6), rad(10 + 90 * d), jitter)
end

-- Hanging leg raise: arms overhead on the bar, legs come up at lockout.
POSE_ANIMS.LegRaise = function(character, d, jitter)
	sideArms(character, 0, rad(165), 0, 0)
	for _, side in ipairs(SIDES) do
		setJoint(character, side[1] .. "Hip", Angles(rad(15 + 75 * (1 - d)) + jitter, 0, 0))
		setJoint(character, side[1] .. "Knee", Angles(-rad(20), 0, 0))
	end
end

-- Cable woodchop: twist from high on one side (bottom) to low across the body (lockout).
POSE_ANIMS.Woodchop = function(character, d, jitter)
	setJoint(character, "Waist", Angles(0, rad(-50 + 100 * d), 0))
	frontArms(character, rad(30 + 50 * d) + jitter, rad(20), rad(10), 0)
end

-- Sled push (winter): leaning into the sled's handles, legs driving in a lunge that switches each rep.
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
	anim(character, depth, jitter)
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
	for index, entry in ipairs(machine.muscles) do
		local amount = FEEL.PumpPerRep * (index == 1 and 1 or 0.5)
		for _, partName in ipairs(Muscles.Body[entry.id].pump) do
			local part = character:FindFirstChild(partName)
			if part then
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
	for _, entry in ipairs(machine.muscles) do
		for _, partName in ipairs(Muscles.Body[entry.id].pump) do
			local part = character:FindFirstChild(partName)
			if part then
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
	CharWidth = 15,   -- px per character at the Popup text size (Montserrat SemiBold), for the clear-spot check
	BarGap = 0.3,     -- studs kept clear around the bar and its plates (all along its path)
	ScreenMargin = 8, -- px from the screen edges
}
local activePopup = nil -- { billboard, attachment }

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
		local travel = barTravel[model] or { low = load.CFrame, high = load.CFrame }
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
		Parent = player:WaitForChild("PlayerGui"),
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

------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal
local Left, Right = Enum.HorizontalAlignment.Left, Enum.HorizontalAlignment.Right

local gui = Theme.ScreenGui({
	Name = "MachineHud",
	Enabled = false,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
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
	coinLabel.Text = tostring(ClientData.Get().coins)
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

local function isMaxed(machine)
	local data = ClientData.Get()
	return data.muscles[machine.muscles[1].id].level >= GrowthSpurts.GetLevelCap(data.growthSpurts)
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
	tierLabel.Text = (tier.weight > 0 and "lb · " or "") .. "tier " .. viewTier .. " of " .. #machine.tiers
	setStepButton(minusButton, viewTier > 1)
	setStepButton(plusButton, viewTier < maxView)
	drawBarbell(tier)

	musclesLabel.Visible = not locked
	unlockButton.Visible = viewTier > unlocked and levelOk
	needsLabel.Visible = not levelOk
	if locked and levelOk then
		-- Can't afford yet: faded button with gray text.
		costLabel.Text = tostring(tier.cost)
		local affordable = canUnlock(machine, tier)
		local ink = affordable and Colors.Text or Colors.Muted
		unlockButton.BackgroundTransparency = affordable and Theme.Alpha.Primary or 0.92
		unlockText.TextColor3 = ink
		costLabel.TextColor3 = ink
		tintIcon(unlockIcon, ink)
	elseif not levelOk then
		needsLabel.Text = "Needs " .. main.name .. " level " .. tier.unlockLevel
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
	if isMaxed(machine) then return "maxed" end
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

local function flashLevel(name, level)
	flashToken += 1
	local token = flashToken
	levelFlash.Text = name .. " · " .. Muscles.FormatExp(Muscles.Shown(level)) .. " exp"
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
	local xp = Gains.PerRep(ClientData.Get(), machine, state.tier, player:GetAttribute("GainsBoost"), quality)
	local shown = math.max(1, Muscles.ShownXp(xp[main] or 0))
	current.setGain = (current.setGain or 0) + shown
	local mode = gainNumbersMode()
	local showSet = mode ~= "Off" -- On and Minimal
	local showRep = mode == "On"
	if character and state.big and showSet then
		-- BIG REP: gold and bigger; Minimal still shows it
		gainPopup(character, "BIG REP +" .. shown, POPUP.SetScale * 1.1, machineModel, Colors.Gold)
		Audio.Play2D("BigRep")
	elseif character and setDone and showSet then
		local group = Muscles.GroupById[Muscles.ById[main].group]
		gainPopup(character, "Set done · +" .. current.setGain .. " " .. group.name, POPUP.SetScale, machineModel)
	elseif character and not setDone and showRep then
		gainPopup(character, "+" .. shown, 1, machineModel, state.pumped and Colors.Gold or nil)
	end
	if setDone then current.setGain = 0 end
	flashMuscles() -- the secondary muscles get a flash of the HUD's muscle list instead of popups

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
	end
end

-- Arms are posed before physics so they override animations...
RunService.Stepped:Connect(function()
	local now = os.clock()
	for model in pairs(barRest) do
		local character = userCharacter(model)
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
			animate(model, character, depth, state and state.shake and phase == "press")
			posed[model] = character
			if model:GetAttribute("Stack") then placeStack(model, depth) end
		elseif posed[model] then
			resetPose(posed[model])
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
	end
end)

local function setupMachine(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	-- no timeout: with Workspace streaming a machine can arrive late (it runs in its own thread)
	local bar = model:WaitForChild(machine and machine.load or "Bar")
	local plates = model:WaitForChild("Plates")
	if not bar or not plates then return end
	barRest[model] = bar.CFrame
	for _, plate in ipairs(plates:GetDescendants()) do trackPlate(model, plate) end
	plates.DescendantAdded:Connect(function(plate) trackPlate(model, plate) end)
	plates.DescendantRemoving:Connect(function(plate) plateOffsets[plate] = nil end)
	model:GetAttributeChangedSignal("Reps"):Connect(function()
		-- our own reps start instantly on tap; other lifters start when the server counts them
		if model:GetAttribute("UserId") ~= player.UserId then
			startRep(model, model:GetAttribute("Tier"), false)
		end
	end)
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
	barTravel[model] = nil -- measure this lift's bar path fresh
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
	for _, entry in ipairs(machine.muscles) do
		table.insert(names, Muscles.ById[entry.id].name)
	end
	musclesLabel.Text = table.concat(names, " · ")
	refreshCoins()
	refreshStamina()
	refreshReps()
	refreshTier()
	setNote(isMaxed(machine) and "maxed" or "firstSet")

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
	local leveled, maxed = false, false
	-- the main muscle gets the small "Level 12" flash (with a sparkle burst); secondary muscles only flash the HUD
	-- muscle list. Maxed muscles get a corner note.
	local mainId = current and current.machine.muscles[1].id
	for muscleId, level in pairs(result.levels or {}) do
		local name = Muscles.ById[muscleId].name
		if result.maxed and result.maxed[muscleId] then
			Notify.Show(name .. " maxed")
			maxed = true
		else
			if muscleId == mainId then flashLevel(name, level) end
			leveled = true
		end
	end
	-- one sound per rep, however many muscles levelled; early levels come fast, so the ding is spaced out
	if maxed then
		Audio.Play2D("Maxed")
	elseif leveled and os.clock() - lastLevelSound > 1.5 then
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
	return machine.name .. " · next " .. Machines.WeightText(nextTier) .. " at " .. main.name .. " " .. nextTier.unlockLevel
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
