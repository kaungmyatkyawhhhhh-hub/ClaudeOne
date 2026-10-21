-- Body Alters (owner's gameplay plan "Body Alters", prompt 21, 21 Oct): the endless progression after 7'0". All numbers
-- here. 30 alters in 6 tiers of 5; alter 0 = "Natural" (the normal skin texture stages).
--  * Reaching an alter's goal (every group at `Goal(n)`, like a Growth Spurt goal) lets you ALTER when you choose: every
--    muscle keeps KeepShare of its EXP, height stays, the alter's skin replaces the skin stages at every muscle size, and
--    the gains bonus goes up (BonusPer per alter, stacking; outside Gains.MaxMultiplier, so it always counts).
--  * Finishing a tier (every 5th alter) gives its title, its aura and DNA tokens (TierRewards).
--  * Only alters with textures can be reached (Tier 1 so far: Downloads\gym_arc_alters\tier1_human, made by the planner);
--    the rest show "Coming soon" with a placeholder color until their textures come.
--  * Skins: ReplicatedStorage.SkinStages also holds one SurfaceAppearance per alter with textures ("Alter_<id>", built
--    by tools/builders/SkinStages); MuscleRig uses it instead of the stages when a body's "Alter" attribute names it.
-- Save data: data.alter = { highest = n, equipped = n, best = { muscles = { [id] = level }, spurts, alter, strength } }
-- (equipped = the skin you wear: any alter up to highest; best = the biggest physique ever, for the statue / profile).
local GrowthSpurts = require(script.Parent.GrowthSpurts)
local Muscles = require(script.Parent.Muscles)

local Alters = {}

Alters.KeepShare = 0.25 -- share of each muscle's EXP kept through an alter
Alters.BonusPer = 0.15  -- gains bonus per alter (x1.15, x1.30, x1.45 ...), the HIGHEST alter's, whatever skin you wear

-- The goal for alter n: every group at this level (tuned with tests/pacing alters to TargetMinutes of active play from
-- the previous alter, with KeepShare kept and the bonus so far).
-- Measured 21 Oct (lune run tests/pacing alters, 30 players): alter 1 15.5 min (from a fresh 7'0"), 2: 10.6, 3: 11.1,
-- 4: 11.2, 5: 11.9 (later ones grow to ~16 by alter 10: retune when their textures come).
Alters.FirstGoal = 95  -- alter 1 (from 7'0" with the muscles you have when you get there)
Alters.GoalPer = 10     -- each later alter's goal is this much higher
Alters.TargetMinutes = { 10, 15 } -- about 10-15 minutes per alter

Alters.Tiers = {
	{ id = "Human", name = "Human" },
	{ id = "Stone", name = "Stone" },
	{ id = "Metal", name = "Metal" },
	{ id = "Gem", name = "Gem" },
	{ id = "Elements", name = "Elements" },
	{ id = "Legend", name = "Legend" },
}

-- textures: rbxassetid ids of the color / normal / roughness maps (uploaded 21 Oct); placeholder = the color shown for an
-- alter that has no textures yet (the Alters tab's "Coming soon" card).
local function t(color, normal, roughness) return { color = color, normal = normal, roughness = roughness } end
Alters.List = {
	-- Tier 1: Human
	{ id = "Pumped", name = "Pumped", tier = 1, textures = t("rbxassetid://118652537566937", "rbxassetid://77670612429230", "rbxassetid://109400263905498") },
	{ id = "Shredded", name = "Shredded", tier = 1, textures = t("rbxassetid://119513312479015", "rbxassetid://103766752198769", "rbxassetid://71101897859940") },
	{ id = "Tanned", name = "Tanned", tier = 1, textures = t("rbxassetid://124927923688709", "rbxassetid://95570134134448", "rbxassetid://74028606958342") },
	{ id = "Vascular", name = "Vascular", tier = 1, textures = t("rbxassetid://103109392852988", "rbxassetid://72861088552312", "rbxassetid://121431954405592") },
	{ id = "Peak", name = "Peak", tier = 1, textures = t("rbxassetid://128233798561844", "rbxassetid://127999198166079", "rbxassetid://89748828998136") },
	-- Tier 2: Stone
	{ id = "Clay", name = "Clay", tier = 2, placeholder = "#A0664A" },
	{ id = "Sandstone", name = "Sandstone", tier = 2, placeholder = "#C9A46B" },
	{ id = "Granite", name = "Granite", tier = 2, placeholder = "#7D7A78" },
	{ id = "Marble", name = "Marble", tier = 2, placeholder = "#E6E2DA" },
	{ id = "Obsidian", name = "Obsidian", tier = 2, placeholder = "#1E1A24" },
	-- Tier 3: Metal
	{ id = "Bronze", name = "Bronze", tier = 3, placeholder = "#B0783C" },
	{ id = "Iron", name = "Iron", tier = 3, placeholder = "#5E5E62" },
	{ id = "Steel", name = "Steel", tier = 3, placeholder = "#9AA3AD" },
	{ id = "Chrome", name = "Chrome", tier = 3, placeholder = "#D9DEE4" },
	{ id = "Gold", name = "Gold", tier = 3, placeholder = "#F6C75A" },
	-- Tier 4: Gem
	{ id = "Jade", name = "Jade", tier = 4, placeholder = "#3FA77A" },
	{ id = "Ruby", name = "Ruby", tier = 4, placeholder = "#C21E3A" },
	{ id = "Sapphire", name = "Sapphire", tier = 4, placeholder = "#2752C9" },
	{ id = "Amethyst", name = "Amethyst", tier = 4, placeholder = "#8A4FD8" },
	{ id = "Diamond", name = "Diamond", tier = 4, placeholder = "#CFF3FF" },
	-- Tier 5: Elements
	{ id = "FrostSkin", name = "Frost", tier = 5, placeholder = "#9AD9FF" },
	{ id = "StormSkin", name = "Storm", tier = 5, placeholder = "#5C6FA8" },
	{ id = "Lava", name = "Lava", tier = 5, placeholder = "#E5501E" },
	{ id = "ToxicSkin", name = "Toxic", tier = 5, placeholder = "#6FE83A" },
	{ id = "Plasma", name = "Plasma", tier = 5, placeholder = "#E23FFF" },
	-- Tier 6: Legend
	{ id = "TitanSkin", name = "Titan", tier = 6, placeholder = "#B8322A" },
	{ id = "GalaxySkin", name = "Galaxy", tier = 6, placeholder = "#2B3FA8" },
	{ id = "RoyalSkin", name = "Royal", tier = 6, placeholder = "#FFD36B" },
	{ id = "Eclipse", name = "Eclipse", tier = 6, placeholder = "#120A1E" },
	{ id = "Celestial", name = "Celestial", tier = 6, placeholder = "#F2F6FF" },
}
Alters.Natural = { id = "Natural", name = "Natural", tier = 0, number = 0 }

-- Finishing a tier (its 5th alter): a title (Config/Titles, condition "alter"), an aura (Config/Auras, unlock "alter") and
-- DNA tokens.
Alters.TierRewards = {
	{ title = "AlterHuman", aura = "AlterHuman", dnaTokens = 1 },
	{ title = "AlterStone", aura = "AlterStone", dnaTokens = 1 },
	{ title = "AlterMetal", aura = "AlterMetal", dnaTokens = 2 },
	{ title = "AlterGem", aura = "AlterGem", dnaTokens = 2 },
	{ title = "AlterElements", aura = "AlterElements", dnaTokens = 3 },
	{ title = "AlterLegend", aura = "AlterLegend", dnaTokens = 3 },
}

Alters.ById = { Natural = Alters.Natural }
for index, alter in ipairs(Alters.List) do
	alter.number = index
	Alters.ById[alter.id] = alter
end

-- alter n (0 = Natural)
function Alters.Get(n: number)
	if n <= 0 then return Alters.Natural end
	return Alters.List[n]
end

-- the tier of alter n (0 for Natural); the alter number counts toward the posing show's stage presence
function Alters.TierOf(n: number): number
	if n <= 0 then return 0 end
	return math.ceil(n / 5)
end

-- the SurfaceAppearance name in ReplicatedStorage.SkinStages (nil = the normal skin stages)
function Alters.SkinName(n: number): string?
	local alter = Alters.Get(n)
	return if alter and alter.textures then "Alter_" .. alter.id else nil
end

-- the last alter anyone can reach now (the last one in a row with textures)
function Alters.LastAvailable(): number
	local last = 0
	for index, alter in ipairs(Alters.List) do
		if not alter.textures then break end
		last = index
	end
	return last
end

function Alters.Goal(n: number): number
	return Alters.FirstGoal + Alters.GoalPer * (n - 1)
end

-- the gains multiplier of the highest alter (outside Gains.MaxMultiplier)
function Alters.Bonus(highest: number): number
	return 1 + Alters.BonusPer * math.max(highest or 0, 0)
end

-- data.alter, filled in (old saves have none)
function Alters.State(data)
	local state = type(data) == "table" and data.alter
	if type(state) ~= "table" then return { highest = 0, equipped = 0 } end
	return state
end

-- Progress toward the next alter: { next, required, met, total, groups = { [groupId] = level }, ready, open, locked }
-- open = at 7'0"; locked = the next alter has no textures yet ("Coming soon").
function Alters.Progress(data, groups, trainable)
	local state = Alters.State(data)
	local nextN = (state.highest or 0) + 1
	local required = GrowthSpurts.BoostedLevel(Alters.Goal(nextN), GrowthSpurts.ProgressBoost(data)) -- (prompt 24: trainers' progress boost)
	local result = { next = nextN, required = required, met = 0, total = #groups, groups = {} }
	for _, group in ipairs(groups) do
		local level = GrowthSpurts.GoalLevel(data.muscles, group, trainable)
		result.groups[group.id] = level
		if level >= required then result.met += 1 end
	end
	result.open = GrowthSpurts.IsMaxed(data.growthSpurts)
	result.locked = nextN > Alters.LastAvailable()
	result.ready = result.open and not result.locked and result.met == result.total
	return result
end

-- One muscle entry after an alter: KeepShare of its EXP, as { level, xp }.
function Alters.Kept(entry)
	local xp = Muscles.EntryXp(entry) * Alters.KeepShare
	local level = math.floor(Muscles.LevelFromXp(xp))
	return { level = level, xp = math.max(0, xp - Muscles.CumXp(level)) }
end

-- "Alter 3 · Tanned"
function Alters.Label(n: number): string
	if n <= 0 then return "Natural" end
	return "Alter " .. n .. " · " .. Alters.Get(n).name
end

return Alters
