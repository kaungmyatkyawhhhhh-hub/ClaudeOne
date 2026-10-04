-- Where the body goes on each machine, relative to the machine's pivot (machines face +Z).
--   Lie:   body = exact HumanoidRootPart CFrame.
--   Stand: position on the floor + yaw; height comes from the character's hip height.
--   Hang:  like Stand, but the height is set so straight arms reach barHeight.
-- follow = what carries the plates while lifting: "Hands", "Back", "Hips" or "None".
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
	Crunch = {
		kind = "Lie",
		body = CFrame.lookAt(Vector3.new(0, 2.35, -0.6), Vector3.new(0, 3.35, -0.6), Vector3.new(0, 0, -1)),
		exit = Vector3.new(3, 0, 0.5),
		follow = "Hands",
	},
}

return Poses
