-- Body Alters (prompt 21): the ladder, the goal, what an alter keeps, the bonus, the skins.
local H = require("./harness")
local Alters = H.module("ReplicatedStorage/Shared/Config/Alters")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local GrowthSpurts = H.module("ReplicatedStorage/Shared/Config/GrowthSpurts")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
local Titles = H.module("ReplicatedStorage/Shared/Config/Titles")
local Auras = H.module("ReplicatedStorage/Shared/Config/Auras")
print("Body Alters")
H.check(#Alters.List == 30, "30 alters")
for tier = 1, 6 do
	local n = 0
	for _, alter in Alters.List do if alter.tier == tier then n += 1 end end
	H.check(n == 5, "tier " .. tier .. " has 5 alters")
end
H.check(Alters.LastAvailable() == 5, "only the Human tier has textures (5)")
for _, alter in Alters.List do
	H.check(alter.textures ~= nil or alter.placeholder ~= nil, alter.id .. " has textures or a placeholder color")
end
H.check(Alters.TierOf(0) == 0 and Alters.TierOf(1) == 1 and Alters.TierOf(5) == 1 and Alters.TierOf(6) == 2, "tiers")
H.check(Alters.SkinName(3) == "Alter_Tanned" and Alters.SkinName(0) == nil and Alters.SkinName(6) == nil, "skin names")
H.check(math.abs(Alters.Bonus(2) - 1.3) < 1e-9 and Alters.Bonus(0) == 1, "the bonus stacks 15% per alter")
for n = 2, 30 do H.check(Alters.Goal(n) > Alters.Goal(n - 1), "goal " .. n .. " is higher") end
-- keep 25% of the EXP
local entry = { level = 200, xp = 13 }
local kept = Alters.Kept(entry)
H.check(math.abs(Muscles.EntryXp(kept) - Muscles.EntryXp(entry) * 0.25) < 1e-6, "an alter keeps 25% of the EXP")
H.check(kept.xp >= 0 and kept.xp < Muscles.XpToNext(kept.level), "kept xp is below the next level")
-- ready only at 7'0", with every group at the goal, and only up to the last alter with textures
local function save(spurts, level, highest)
	local data = { growthSpurts = spurts, muscles = {}, alter = { highest = highest, equipped = highest } }
	for _, m in Muscles.List do data.muscles[m.id] = { level = level, xp = 0 } end
	return data
end
local maxS = GrowthSpurts.MaxSpurts()
local function ready(data) return Alters.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts)).ready end
H.check(ready(save(maxS, 1000, 0)), "7'0\" and past the goal: ready")
H.check(not ready(save(maxS - 1, 1000, 0)), "not before 7'0\"")
H.check(not ready(save(maxS, Alters.Goal(1) - 1, 0)), "not below the goal")
H.check(not ready(save(maxS, 5000, 5)), "not past the last alter with textures (Coming soon)")
H.check(Alters.State({}).highest == 0, "an old save starts at Natural")
-- tier rewards exist
for tier, reward in Alters.TierRewards do
	H.check(Titles.ById[reward.title] ~= nil, "tier " .. tier .. " title " .. reward.title)
	H.check(Auras.ById[reward.aura] ~= nil, "tier " .. tier .. " aura " .. reward.aura)
end
H.check(Titles.Check(Titles.ById.AlterHuman, { data = { alter = { highest = 5 } } }), "Peak Human at alter 5")
H.check(not Titles.Check(Titles.ById.AlterHuman, { data = { alter = { highest = 4 } } }), "...not at 4")
H.done()
