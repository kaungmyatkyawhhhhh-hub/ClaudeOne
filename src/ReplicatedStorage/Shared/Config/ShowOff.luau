-- Showing off: wall leaderboards (one column per muscle group, crown for #1), the statue of the strongest player
-- in the entrance hall, emotes, and the membership card (Bronze -> Diamond).
local ShowOff = {}

-- Leaderboards (OrderedDataStores, shared by every server).
ShowOff.Leaderboard = {
	Refresh = 120,  -- seconds between updates
	Top = 5,        -- rows per group
	-- the board on the front wall above the front desk (center, size in studs)
	BoardCenter = Vector3.new(20.75, 9.2, -4.1),
	BoardSize = Vector2.new(10.5, 5),
}

-- Score so a Growth Spurt always ranks above any level from an earlier spurt.
function ShowOff.GroupScore(growthSpurts, groupLevel)
	return (growthSpurts or 0) * 10000 + math.floor(groupLevel)
end
function ShowOff.TotalScore(growthSpurts, levelSum)
	return (growthSpurts or 0) * 1000000 + math.floor(levelSum)
end
function ShowOff.SplitGroupScore(score)
	return score // 10000, score % 10000 -- growthSpurts, level
end

-- The statue of the strongest player (highest total score), in the entrance hall.
ShowOff.Statue = {
	Spot = Vector3.new(-7, 0.1, 3), -- the back-left corner (by the gym doorway): in full view as you come in, never in the camera's face
	Scale = 1, -- same size as the player it shows (height comes from their Growth Spurts)
	Material = Enum.Material.Marble,
	Color = Color3.fromHex("#C9C6BF"),
}

-- Poses (the emote system). The bodybuilding poses are PoseData entries (ReplicatedStorage.PoseData): the server sets the
-- character attribute "Pose" and every client poses that character (PoseController); it is held until the player moves or
-- jumps. muscles = what the pose shows off (the PUMPED pulse on the pose hit, and the judges' score on the posing stage).
-- The two timed gestures (high five, shake chug) are small client-side poses (EmoteClient): pose = its function name.
ShowOff.Emotes = {
	{ id = "FrontDoubleBiceps", name = "Front double biceps", poseData = "FrontDoubleBiceps", muscles = { "Biceps", "Triceps", "FrontDelts", "SideDelts" } },
	{ id = "FrontLatSpread", name = "Front lat spread", poseData = "FrontLatSpread", muscles = { "Lats", "Obliques", "SideDelts", "Traps" } },
	{ id = "SideChest", name = "Side chest", poseData = "SideChest", muscles = { "MidChest", "UpperChest", "Biceps", "Quads" } },
	{ id = "AbsAndThigh", name = "Abs and thigh", poseData = "AbsAndThigh", muscles = { "Abs", "Obliques", "Quads", "Forearms" } },
	{ id = "MostMuscular", name = "Most muscular", poseData = "MostMuscular", muscles = { "Traps", "UpperChest", "MidChest", "FrontDelts" } },
	{ id = "BackDoubleBiceps", name = "Back double biceps", poseData = "BackDoubleBiceps", muscles = { "Lats", "Rhomboids", "Traps", "LowerBack", "RearDelts" } },
	{ id = "HighFive", name = "High five", pose = "HighFive", seconds = 1.6 },
}
ShowOff.PoseMaxSeconds = 45 -- a held pose lets go by itself after this long
-- the judges on the posing stage score a pose held for Delay seconds; Margin = studs around the stage that still count
ShowOff.PoseJudge = { Delay = 0.9, Margin = 3 }
-- the pose NPC regulars strike now and then (names from PoseData)
ShowOff.NpcPoses = { "FrontDoubleBiceps", "FrontLatSpread", "SideChest", "AbsAndThigh", "MostMuscular", "BackDoubleBiceps" }
ShowOff.EmoteById = {}
for _, emote in ipairs(ShowOff.Emotes) do ShowOff.EmoteById[emote.id] = emote end
-- not in the menu: played automatically when drinking a shake
ShowOff.EmoteById.Chug = { id = "Chug", name = "Shake chug", pose = "Chug", seconds = 1.4 }

ShowOff.HighFive = { Range = 7, Window = 2.5 } -- studs, seconds between the two high fives

-- Membership card tiers by lifetime reps.
ShowOff.Membership = {
	{ id = "Bronze", reps = 0, color = Color3.fromHex("#B08D57") },
	{ id = "Silver", reps = 500, color = Color3.fromHex("#C0C4CA") },
	{ id = "Gold", reps = 2500, color = Color3.fromHex("#E8C21C") },
	{ id = "Platinum", reps = 10000, color = Color3.fromHex("#D8DEE6") },
	{ id = "Diamond", reps = 30000, color = Color3.fromHex("#9FD8F0") },
}

-- Tier (and the next tier, or nil) for a rep count.
function ShowOff.Tier(totalReps)
	local current, nextTier = ShowOff.Membership[1], nil
	for i, tier in ipairs(ShowOff.Membership) do
		if (totalReps or 0) >= tier.reps then
			current = tier
			nextTier = ShowOff.Membership[i + 1]
		end
	end
	return current, nextTier
end

return ShowOff
