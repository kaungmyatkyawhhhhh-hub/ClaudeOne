-- MachineClient: lift input, machine HUD, and all lifting game feel (motion, sounds,
-- gains, pump, particles). Effects play instantly on tap; the server validates and applies gains.
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
	HeavyTier = 5,          -- FOV punch + plate jiggle from this tier up
	FovPunch = 2.5,
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
local PLATE_HEIGHT = { [45] = 0.95, [25] = 0.74, [10] = 0.54 }
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

local function repDurations(tier, lowStamina)
	local heavy = 1 + FEEL.HeavyPerTier * ((tier or 1) - 1)
	return FEEL.Lower * heavy, FEEL.Press * heavy * (lowStamina and FEEL.LowPressMult or 1), FEEL.Hold
end

local function startRep(model, tier, lowStamina)
	local lower, press, hold = repDurations(tier, lowStamina)
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

local function trackPlate(model, plate)
	if plate:IsA("BasePart") and barRest[model] then
		plateOffsets[plate] = barRest[model]:ToObjectSpace(plate.CFrame)
	end
end

local function loadPart(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	return model:FindFirstChild(machine and machine.load or "Bar")
end

local function placeBar(model, cframe)
	loadPart(model).CFrame = cframe
	for _, plate in ipairs(model.Plates:GetChildren()) do
		local offset = plateOffsets[plate]
		if offset then plate.CFrame = cframe * offset end
	end
end

local function userCharacter(model)
	local userId = model:GetAttribute("UserId")
	local user = userId and Players:GetPlayerByUserId(userId)
	return user and user.Character
end

-- R15 joints by name: { part, Motor6D }
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
-- 3D gain popups: "+8 MID CHEST" at the muscle
------------------------------------------------------------------------
-- side: 0 = centered on the muscle, -1/1 = nudged left/right so popups don't stack.
local function gainPopup(character, muscleId, xp, scale, side)
	local body = Muscles.Body[muscleId]
	local part = character:FindFirstChild(body.part)
	if not part then return end
	local attachment = New("Attachment", { Position = body.offset, Parent = part })
	local billboard = New("BillboardGui", {
		Adornee = attachment,
		Size = UDim2.fromOffset(200, 34),
		StudsOffset = Vector3.new((side or 0) * 1.6, 0, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local holder = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = billboard })
	local popScale = New("UIScale", { Scale = 0, Parent = holder })
	local label = Theme.Text({
		Text = "+" .. math.max(1, math.floor(xp + 0.5)) .. " " .. Muscles.ById[muscleId].name,
		Font = "SemiBold",
		TextSize = "Popup",
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	local stroke = Theme.TextShadow(label, 0.45)

	Theme.Tween(popScale, { Scale = scale }, Theme.Motion.Time * 1.4, Theme.Motion.Bounce)
	task.delay(Theme.Motion.Time * 1.4, function()
		local fade = Theme.Motion.Time * 2.4
		Theme.Tween(billboard, { StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0) }, fade)
		Theme.Tween(label, { TextTransparency = 1 }, fade)
		Theme.Tween(stroke, { Transparency = 1 }, fade)
		Debris:AddItem(billboard, fade)
		Debris:AddItem(attachment, fade)
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

-- Side view of a loaded barbell; plates take the tier's bumper color.
local function drawBarbell(tier)
	barbell:ClearAllChildren()
	table.clear(barPlates)
	Theme.List(Horizontal, nil).Parent = barbell
	local bumper = Theme.Bumper[tier.color or "White"]
	local order = 0
	local function piece(width, height, color, extra)
		order += 1
		return box({ LayoutOrder = order, Size = UDim2.fromScale(width, height), BackgroundTransparency = 0, BackgroundColor3 = color, Parent = barbell }, extra)
	end
	local function plates(list)
		for _, lb in ipairs(list) do
			table.insert(barPlates, piece(0.055, PLATE_HEIGHT[lb], bumper.Fill, { Theme.Round("Segment"), Theme.Stroke(bumper.Rim, Theme.IconStroke) }))
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

local function jigglePlates()
	for i, plate in ipairs(barPlates) do
		plate.Rotation = (i % 2 == 0 and 1 or -1) * 8
		Theme.Tween(plate, { Rotation = 0 }, Theme.Motion.Time * 1.4, Theme.Motion.Bounce)
	end
end

local function canUnlock(machine, tier)
	local data = ClientData.Get()
	return data.muscles[machine.muscles[1].id].level >= tier.unlockLevel and data.coins >= tier.cost
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
end

local function refreshTier()
	if not current then return end
	local machine = current.machine
	local unlocked = progressFor(machine.id)
	local maxView = math.min(#machine.tiers, unlocked + 1)
	viewTier = math.clamp(viewTier, 1, maxView)

	local tier = machine.tiers[viewTier]
	local locked = viewTier > unlocked
	weightNumber.Text = tier.label or tostring(tier.weight)
	weightNumber.TextColor3 = locked and Colors.Muted or Colors.Text
	tierLabel.Text = (tier.weight > 0 and "lb · " or "") .. "tier " .. viewTier
	setStepButton(minusButton, viewTier > 1)
	setStepButton(plusButton, viewTier < maxView)
	drawBarbell(tier)

	local main = Muscles.ById[machine.muscles[1].id]
	local levelOk = ClientData.Get().muscles[main.id].level >= tier.unlockLevel
	musclesLabel.Visible = not locked
	unlockButton.Visible = locked and levelOk
	needsLabel.Visible = locked and not levelOk
	if locked and levelOk then
		-- Can't afford yet: faded button with gray text.
		costLabel.Text = tostring(tier.cost)
		local affordable = canUnlock(machine, tier)
		local ink = affordable and Colors.Text or Colors.Muted
		unlockButton.BackgroundTransparency = affordable and Theme.Alpha.Primary or 0.92
		unlockText.TextColor3 = ink
		costLabel.TextColor3 = ink
		tintIcon(unlockIcon, ink)
	elseif locked then
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
	local unlocked, selected = progressFor(machine.id)
	local nextTier = machine.tiers[unlocked + 1]
	if nextTier and canUnlock(machine, nextTier) then return "unlockReady" end
	if selected < unlocked then return "tooLight" end
	return "general"
end

local function fovPunch()
	local camera = Workspace.CurrentCamera
	baseFov = baseFov or camera.FieldOfView
	camera.FieldOfView = baseFov + FEEL.FovPunch
	Theme.Tween(camera, { FieldOfView = baseFov }, Theme.Motion.Time)
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

local function beginRep()
	if not current then return end
	local data = ClientData.Get()
	if data.stamina < current.machine.staminaCost then
		outOfStamina()
		return
	end
	local now = os.clock()
	if current.lastLockout and now - current.lastLockout > FEEL.SetBreak then
		current.reps = 0
		refreshReps()
		current.setsSinceNote += 1
		if current.setsSinceNote >= FEEL.NoteEvery then
			setNote(noteSituation())
		end
	end
	local _, selected = progressFor(current.machine.id)
	local duration = startRep(current.model, selected, staminaRatio() < FEEL.LowStamina)
	current.repEnd = now + duration
	Remotes.MachineAction:FireServer("Lift")
end

local function tryLift()
	if not current then return end
	local now = os.clock()
	if current.repEnd and now < current.repEnd then
		if current.repEnd - now <= FEEL.BufferWindow then current.queued = true end
		return
	end
	beginRep()
end

-- The local player's lockout: count the rep and fire all the feedback.
local function localLockout(state)
	local machine = current.machine
	local character = player.Character
	current.lastLockout = os.clock()
	current.reps += 1
	refreshReps()
	bounceReps()
	Audio.Play2D("RepTick")

	local setDone = current.reps % FEEL.SetSize == 0
	if character then
		local xp = Gains.PerRep(ClientData.Get(), machine, state.tier, player:GetAttribute("GainsBoost")) -- same boosts as the server
		for index, entry in ipairs(machine.muscles) do
			local scale = (index == 1 and 1 or 0.72) * (setDone and 1.3 or 1)
			local side = index == 1 and 0 or (index % 2 == 0 and -1 or 1)
			task.delay((index - 1) * 0.1, gainPopup, character, entry.id, xp[entry.id], scale, side)
		end
	end

	if state.tier >= FEEL.HeavyTier then
		fovPunch()
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
		elseif posed[model] then
			resetPose(posed[model])
			posed[model] = nil
			repState[model] = nil
			placeBar(model, barRest[model])
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
	local bar = model:WaitForChild(machine and machine.load or "Bar", 10)
	local plates = model:WaitForChild("Plates", 10)
	if not bar or not plates then return end
	barRest[model] = bar.CFrame
	for _, plate in ipairs(plates:GetChildren()) do trackPlate(model, plate) end
	plates.ChildAdded:Connect(function(plate) trackPlate(model, plate) end)
	plates.ChildRemoved:Connect(function(plate) plateOffsets[plate] = nil end)
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

local function open(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	if not machine then return end
	current = { model = model, machine = machine, reps = 0, setsSinceNote = 0 }
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
	Audio.PlayAt("BarRattle", barOf(model))
	stack.Position = HIDDEN_OFFSET
	Theme.Tween(stack, { Position = UDim2.new() }) -- slides up

	ContextActionService:BindActionAtPriority("MachineLift", onLiftAction, false,
		Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	-- chalk up as you grab the bar (hands need a frame to reach it)
	task.delay(0.15, function()
		if current and player.Character then chalkPuff(player.Character, 12) end
	end)
end

local function close()
	if current then
		-- racking the bar: a rattle, plus a rubber floor thud on lifting platforms
		local model = current.model
		Audio.PlayAt("BarRattle", barOf(model))
		if model:FindFirstChild("Platform") then Audio.PlayAt("FloorThud", barOf(model)) end
	end
	current = nil
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
	if viewTier <= unlocked and viewTier ~= selected then
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
	local leveled, maxed = false, false
	for muscleId, level in pairs(result.levels or {}) do
		local name = Muscles.ById[muscleId].name
		if result.maxed and result.maxed[muscleId] then
			Notify.Show(name .. " maxed")
			maxed = true
		else
			Notify.Show(name .. " level " .. level)
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
