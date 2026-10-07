-- GYM ARC pose library. Degrees: CFrame.Angles(x, y, z) per Motor6D, as a rotation about the joint
-- in the PARENT part's axes (+X right, +Y up, -Z front). Joints not listed = 0 (rest). Root rotates the whole body
-- (BackDoubleBiceps turns around).
-- Tuned against poses/preview_poses.png on the Robloxian 2.0 body with big muscles (7 Oct), so the arms clear the delts and
-- lats. Signs, measured in game: Shoulder X+ swings the arm BACK, Shoulder Y turns it toward the chest (Right +, Left -),
-- Shoulder Z raises it sideways (Right +, Left -); Elbow X+ bends the forearm forward, Elbow Z bends it up (Right +, Left -);
-- Neck Y+ turns the head toward the character's left.
return {
	Relaxed = {
		RightShoulder = {0, 0, 8},
		LeftShoulder = {0, 0, -8},
		RightElbow = {8, 0, 0},
		LeftElbow = {8, 0, 0},
	},
	-- elbows at shoulder height, forearms straight up (a clear 90 degree bend), fists turned in a little
	FrontDoubleBiceps = {
		Waist = {4, 0, 0},
		Neck = {-4, 0, 0},
		RightShoulder = {0, 0, 82},
		LeftShoulder = {0, 0, -82},
		RightElbow = {0, 0, 108},
		LeftElbow = {0, 0, -108},
		RightWrist = {0, 0, 15},
		LeftWrist = {0, 0, -15},
		RightHip = {0, 0, 8},
		LeftHip = {0, 0, -8},
	},
	-- fists on the waist, elbows flared out
	FrontLatSpread = {
		Waist = {3, 0, 0},
		RightShoulder = {8, 0, 48},
		LeftShoulder = {8, 0, -48},
		RightElbow = {15, 0, -105},
		LeftElbow = {15, 0, 105},
		RightHip = {0, 0, 7},
		LeftHip = {0, 0, -7},
	},
	-- turned side-on to the camera, the near arm across the chest, the far arm gripping its wrist; head back to the camera
	SideChest = {
		Root = {0, -45, 0},
		Waist = {0, -8, 0},
		Neck = {0, 42, 0},
		RightShoulder = {50, 70, 10},
		RightElbow = {75, 0, 0},
		LeftShoulder = {25, -80, -20},
		LeftElbow = {95, 0, 0},
		LeftHip = {14, 0, 0},
		LeftKnee = {-26, 0, 0},
		LeftAnkle = {14, 0, 0},
	},
	-- hands behind the head, elbows up and wide (clear of the delts), one leg forward, abs crunched
	AbsAndThigh = {
		Waist = {-12, 0, 0},
		RightShoulder = {40, 0, 135},
		LeftShoulder = {40, 0, -135},
		RightElbow = {0, 0, 140},
		LeftElbow = {0, 0, -140},
		RightHip = {-18, 0, 6},
		RightAnkle = {10, 0, 0},
	},
	-- the crab: crunched forward, shoulders rolled in, forearms curled in front of the abs with the fists together
	MostMuscular = {
		Root = {-6, 0, 0},
		Waist = {-30, 0, 0},
		Neck = {14, 0, 0},
		RightShoulder = {8, 85, 34},
		LeftShoulder = {8, -85, -34},
		RightElbow = {95, 0, 0},
		LeftElbow = {95, 0, 0},
		RightHip = {10, 0, 16},
		LeftHip = {10, 0, -16},
		RightKnee = {-22, 0, 0},
		LeftKnee = {-22, 0, 0},
		RightAnkle = {12, 0, -10},
		LeftAnkle = {12, 0, 10},
	},
	-- from behind: the same arms as the front double biceps, one leg back on its toes
	BackDoubleBiceps = {
		Root = {0, 180, 0},
		Waist = {4, 0, 0},
		RightShoulder = {0, 0, 82},
		LeftShoulder = {0, 0, -82},
		RightElbow = {0, 0, 108},
		LeftElbow = {0, 0, -108},
		RightHip = {-10, 0, 6},
		RightKnee = {-22, 0, 0},
		RightAnkle = {14, 0, 0},
	},
}
