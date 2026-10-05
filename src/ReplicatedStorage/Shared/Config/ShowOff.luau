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
	Spot = Vector3.new(-7, 0.1, 8.5),
	Scale = 1.35,
	Material = Enum.Material.Marble,
	Color = Color3.fromHex("#C9C6BF"),
}

-- Emotes: played for everyone to see. pose = a client pose function name (EmoteClient).
ShowOff.Emotes = {
	{ id = "DoubleBiceps", name = "Double biceps", pose = "DoubleBiceps", seconds = 3 },
	{ id = "LatSpread", name = "Lat spread", pose = "LatSpread", seconds = 3 },
	{ id = "HighFive", name = "High five", pose = "HighFive", seconds = 1.6 },
}
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
