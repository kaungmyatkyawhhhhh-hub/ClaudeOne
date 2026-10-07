-- Where the body goes on each machine, relative to the machine's pivot (machines face +Z).
--   Lie:   body = exact HumanoidRootPart CFrame.
--   Stand: position on the floor + yaw; height comes from the character's hip height.
--   Hang:  like Stand, but the height is set so straight arms reach barHeight.
-- follow = what carries the plates while lifting: "Hands", "Back", "Hips", "None" or "Rail" (the load slides along the
-- machine's rail to the lifter's feet / shoulders: model attributes RailAxis, RailAnchor, RailOffset, RailMin, RailMax).
local FACE_FORWARD = 180 -- yaw that faces the character toward +Z

local Poses = {
	BenchPress = {
		kind = "Lie",
		body = CFrame.lookAt(Vector3.new(0, 2.35, -0.9), Vector3.new(0, 3.35, -0.9), Vector3.new(0, 0, -1)),
		exit = Vector3.new(3, 0, 0.5),
		follow = "Hands",
	},
	InclinePress = {
		kind = "Lie",
		-- reclined 30 degrees on the back pad, head toward the rack
		body = CFrame.new(0, 3.2, -0.6) * CFrame.Angles(math.rad(30), 0, 0)
			* CFrame.lookAt(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, -1)),
		exit = Vector3.new(3, 0, 0.5),
		follow = "Hands",
	},
	Squat = { kind = "Stand", position = Vector3.new(0, 0.25, 0.4), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, 4), follow = "Back" },
	Deadlift = { kind = "Stand", position = Vector3.new(0, 0.25, 0.75), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, 4), follow = "Hands" },
	OverheadPress = { kind = "Stand", position = Vector3.new(0, 0.25, 0.4), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, 4), follow = "Hands" },
	BarbellRow = { kind = "Stand", position = Vector3.new(0, 0.25, 0.75), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, 4), follow = "Hands" },
	PullUp = { kind = "Hang", position = Vector3.new(0, 0, 0), barHeight = 9, yaw = FACE_FORWARD, exit = Vector3.new(0, 0, 3.5), follow = "Hips" },
	-- Leg press: reclined 50 degrees on the seat, legs toward the sled (the sled rides the rail to the feet).
	LegPress = {
		kind = "Lie",
		body = CFrame.lookAt(Vector3.new(0, 2.0, -0.6), Vector3.new(0, 2.766, 0.043), Vector3.new(0, 0.643, -0.766)),
		exit = Vector3.new(2.8, 0, -0.6),
		follow = "Rail",
	},
	-- Hack squat: standing on the platform, back on the pad, shoulders under the pads (the carriage rides with them).
	HackSquat = { kind = "Stand", position = Vector3.new(0, 0.55, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, 3), follow = "Rail" },
	Crunch = {
		kind = "Lie",
		body = CFrame.lookAt(Vector3.new(0, 2.35, -0.6), Vector3.new(0, 3.35, -0.6), Vector3.new(0, 0, -1)),
		exit = Vector3.new(3, 0, 0.5),
		follow = "Hands",
	},

	-- Pro gym (built by ProGymService: the lifter stands at the pivot facing +Z, the stack is in front)
	Dip = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	LateralRaise = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	ReverseFly = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	Shrug = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	CalfRaise = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	BicepCurl = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	TricepPushdown = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	Woodchop = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	LegCurl = {
		kind = "Lie",
		-- face down on the pad, head toward the stack
		body = CFrame.lookAt(Vector3.new(0, 2.3, 0), Vector3.new(0, 1.3, 0), Vector3.new(0, 0, 1)),
		exit = Vector3.new(3, 0, 0), follow = "None",
	},
	HipThrust = {
		kind = "Lie",
		-- face up, shoulders on the pad
		body = CFrame.lookAt(Vector3.new(0, 2.1, 0), Vector3.new(0, 3.1, 0), Vector3.new(0, 0, 1)),
		exit = Vector3.new(3, 0, 0), follow = "None",
	},
	-- Treadmill: on the belt (its top 0.69 above the floor), facing the console (local -Z); off behind it.
	Run = { kind = "Stand", position = Vector3.new(0, 0.69, 0.3), yaw = 0, exit = Vector3.new(0, 0, 4.5), follow = "None" },
	SledPush = { kind = "Stand", position = Vector3.new(0, 0.1, 0), yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
	LegRaise = { kind = "Hang", position = Vector3.new(0, 0, 0), barHeight = 9, yaw = FACE_FORWARD, exit = Vector3.new(0, 0, -3), follow = "None" },
}

return Poses
