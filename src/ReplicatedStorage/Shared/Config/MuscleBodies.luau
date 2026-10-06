-- MuscleBodies: the visible muscle tiers. Each tier swaps the five body parts for Marketplace body parts through the
-- player's HumanoidDescription (BodyService), keeping their head, face, hair, accessories, skin color and clothes.
-- Tier 0 = the player's own body (never changes anything). A tier whose ids are all 0 also changes nothing, so the
-- game works the same until the ids are filled in. How to find the ids: PROGRESS.md, "Muscle bodies".
--
-- The tier comes from total muscle progress: the average of all 18 muscles' level toward the next Growth Spurt goal
-- (each muscle counts up to the goal). A Growth Spurt resets the muscles, so it goes back to tier 0.
local MuscleBodies = {}

-- progress needed for tiers 1..4 (0.25 = a quarter of the way to the Growth Spurt goal, 1 = every muscle at the goal)
MuscleBodies.Thresholds = { 0.25, 0.5, 0.75, 1 }

-- Marketplace asset ids per tier (the number in the item's URL: roblox.com/catalog/<id>/...). 0 = keep that part.
MuscleBodies.Tiers = {
	[1] = { Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0 }, -- toned
	[2] = { Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0 }, -- fit
	[3] = { Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0 }, -- muscular
	[4] = { Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0 }, -- maxed
}

-- NPC regulars and the statue (they have no muscle data)
MuscleBodies.NpcTier = { Starter = 2, Pro = 4 }
MuscleBodies.StatueTier = 4

-- How big the gradual muscle growth (Shared.BodyThickness) looks on NPCs and the statue: 0 = normal, 1 = maxed.
MuscleBodies.NpcGrowth = { Starter = 0.5, Pro = 0.9 }
MuscleBodies.StatueGrowth = 1

MuscleBodies.Parts = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

-- Tier 0..4 from data.muscles ({ [muscleId] = { level } }) and the Growth Spurt goal level.
function MuscleBodies.TierFor(muscleData, goal)
	goal = math.max(goal or 1, 1)
	local total, count = 0, 0
	for _, entry in pairs(muscleData or {}) do
		total += math.clamp((entry.level or 0) / goal, 0, 1)
		count += 1
	end
	local progress = count > 0 and total / count or 0
	local tier = 0
	for index, threshold in ipairs(MuscleBodies.Thresholds) do
		if progress >= threshold - 1e-6 then tier = index end
	end
	return tier
end

-- Does this tier have any ids filled in?
function MuscleBodies.HasIds(tier)
	local ids = MuscleBodies.Tiers[tier]
	if not ids then return false end
	for _, part in ipairs(MuscleBodies.Parts) do
		if (ids[part] or 0) > 0 then return true end
	end
	return false
end

-- Put a tier's body parts on a HumanoidDescription (parts with id 0 keep the description's own part).
-- `original` = the avatar's own description, used for parts the tier leaves at 0 and for tier 0.
function MuscleBodies.ApplyTo(desc, tier, original)
	local ids = MuscleBodies.Tiers[tier] or {}
	for _, part in ipairs(MuscleBodies.Parts) do
		local id = ids[part] or 0
		if id > 0 then
			desc[part] = id
		elseif original then
			desc[part] = original[part]
		end
	end
end

return MuscleBodies
