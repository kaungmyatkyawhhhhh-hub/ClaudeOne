-- GYM ARC pose library. Degrees: CFrame.Angles(x, y, z) per Motor6D, as a rotation about the joint
-- in the PARENT part's axes (+X right, +Y up, -Z front). Joints not listed = 0 (rest). Root rotates the whole body
-- (BackDoubleBiceps turns around).
-- Tuned against poses/preview_poses.png on the Robloxian 2.0 body with big muscles (7 Oct), so the arms clear the delts and
-- lats. Signs, measured in game (19 Oct): the angles apply Z first, then Y, then X; on a hanging arm / leg X+ swings it
-- FORWARD (the old note said back), Y turns it about the vertical (toward the chest: Right +, Left -), Z raises it sideways
-- (Right +, Left -); Elbow X+ bends the forearm forward, Elbow Z bends it up (Right +, Left -); Knee X- bends the shin back;
-- Ankle X- points the toes down (heel up); Neck Y+ turns the head toward the character's left.
-- The four flex poses (FrontDoubleBiceps, SideChest, AbsAndThigh, BackDoubleBiceps) were redone 19 Oct against the owner's
-- reference photos (body position only), measured at look 0 and the mass monster: no hand or forearm inside the head, every
-- foot on the floor (the raised heels on the toes). Wider bodies spread their own shoulders, so the arms open out with size.
return {
	Relaxed = {
		RightShoulder = {0, 0, 8},
		LeftShoulder = {0, 0, -8},
		RightElbow = {8, 0, 0},
		LeftElbow = {8, 0, 0},
	},
	-- facing front: upper arms out just above the shoulders, elbows a little back, fists at head height curled in; feet a bit
	-- wide, toes out, knees almost straight
	FrontDoubleBiceps = {
		Waist = {6, 0, 0},
		Neck = {-2, 0, 0},
		RightShoulder = {7, 0, 72},
		LeftShoulder = {7, 0, -72},
		RightElbow = {-8, 0, 96},
		LeftElbow = {-8, 0, -96},
		RightWrist = {0, 0, 28},
		LeftWrist = {0, 0, -28},
		RightHip = {0, -12, 10},
		LeftHip = {0, 12, -10},
		RightKnee = {-4, 0, 0},
		LeftKnee = {-4, 0, 0},
		RightAnkle = {2, 12, -10},
		LeftAnkle = {2, -12, 10},
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
	-- turned 70 degrees (the right side to the camera), the chest twisted back toward it, head to the camera; the front (right)
	-- forearm flat across the stomach, the back (left) hand gripping its wrist; the front knee bent in, on its toes
	SideChest = {
		Root = {0, 70, 0},
		Waist = {-4, -22, 0},
		Neck = {0, -40, 0},
		RightShoulder = {0, 95, 4},
		RightElbow = {92, 0, 0},
		LeftShoulder = {30, 0, 80},
		LeftElbow = {20, 0, 0},
		RightHip = {32, 0, -10},
		RightKnee = {-20, 0, 0},
		RightAnkle = {-30, 0, 0},
	},
	-- hands behind the head, elbows out to the sides; a small crunch, chin a little down; the right leg forward, straight, foot
	-- flat
	AbsAndThigh = {
		Waist = {-10, 0, 0},
		Neck = {8, 0, 0},
		RightShoulder = {20, 30, 145},
		LeftShoulder = {20, -30, -145},
		RightElbow = {0, 0, 120},
		LeftElbow = {0, 0, -120},
		RightHip = {12, 0, 4},
		RightAnkle = {-12, 0, 0},
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
	-- from behind: the front double biceps arms, a slight arch, the left leg back on its toes
	BackDoubleBiceps = {
		Root = {0, 180, 0},
		Waist = {8, 0, 0},
		Neck = {-6, 0, 0},
		RightShoulder = {7, 0, 72},
		LeftShoulder = {7, 0, -72},
		RightElbow = {-8, 0, 96},
		LeftElbow = {-8, 0, -96},
		RightWrist = {0, 0, 28},
		LeftWrist = {0, 0, -28},
		RightHip = {0, 0, 6},
		LeftHip = {-14, 0, -6},
		LeftKnee = {-12, 0, 0},
		LeftAnkle = {10, 0, 0},
	},
}
