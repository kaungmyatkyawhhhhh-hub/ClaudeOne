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
-- (owner, 24 Oct: all of Tier 1 = 8 hours) 95 / +10 -> 205 / +25: alter 1 ~1 h 50, 2: ~1 h 15, 3: ~1 h 30,
-- 4: ~1 h 40, 5: ~1 h 55 = ~8 h (estimated from the EXP curve and the 21 Oct times; rerun tests/pacing alters to confirm).
Alters.FirstGoal = 205  -- alter 1 (from 7'0" with the muscles you have when you get there)
Alters.GoalPer = 25     -- each later alter's goal is this much higher
-- (owner, 26 Oct: "make alters take about 25-30 minutes with trainers") each alter's own goal, tuned with trainers in the
-- pacing sim (lune run tests/pacing tunealters 27.5: a player who rolls trainers with their coins, about 27.5 min of play
-- each; a straight +GoalPer can't keep them even). Past the list: the last one + GoalPer per alter.
Alters.Goals = { 237, 413, 494, 526, 553, 581, 623, 653, 674, 689, 709, 748, 774, 787, 801 }
Alters.TargetMinutes = { 75, 115 } -- Tier 1 in about 8 hours

Alters.Tiers = {
	{ id = "Human", name = "Human" },
	{ id = "Stone", name = "Stone" },
	{ id = "Metal", name = "Metal" },
	{ id = "Gem", name = "Gem" },
	{ id = "Elements", name = "Elements" },
	{ id = "Legend", name = "Legend" },
}

-- (prompt 38, 21 Oct) Shredded and Peak: the maps repeated 2x2 inside the image, bumps 1.5x / 2x stronger (Peak 2x color
-- contrast); Vascular keeps its scale (thin veins) with 2.5x bumps and 3x color contrast
-- (Downloads\gym_arc_alters\tier1_human_tiled): the body's UVs spread one texture over 10-14 studs, so the striations and
-- veins came out about twice too big and soft. Old ids: Shredded 119513312479015 / 103766752198769 / 71101897859940,
-- Vascular 103109392852988 / 72861088552312 / 121431954405592, Peak 128233798561844 / 127999198166079 / 89748828998136.
-- (prompt 38b) Peak's normal map re-uploaded as 127542859522710: the first upload (74285776621086) never loaded in game.
-- textures: rbxassetid ids of the color / normal / roughness maps (uploaded 21 Oct); placeholder = the color shown for an
-- alter that has no textures yet (the Alters tab's "Coming soon" card).
-- mean: the color map's average color (its tint math, Alters.Tint); tone: a bronze tan (Alters.Tint) instead of the plain
-- skin tint (prompt 38b).
-- (26 Oct) Tiers 2 and 3 (Stone, Metal): tools/alter_textures.py (Downloads\gym_arc_alters\tier2_stone, tier3_metal),
-- with a metalness map where the material shines. tone = "Raw": the maps are the real colors, no skin tint.
local function t(color, normal, roughness, metalness) return { color = color, normal = normal, roughness = roughness, metalness = metalness } end
local function id(n) return "rbxassetid://" .. n end
Alters.List = {
	-- Tier 1: Human
	{ id = "Pumped", name = "Pumped", tier = 1, textures = t("rbxassetid://72026269031739", "rbxassetid://138975164134801", "rbxassetid://71709604632381"), mean = { 242, 207, 189 } },
	{ id = "Shredded", name = "Shredded", tier = 1, textures = t("rbxassetid://104642189497370", "rbxassetid://117649849113991", "rbxassetid://140178966772946"), mean = { 242, 235, 225 } },
	{ id = "Tanned", name = "Tanned", tier = 1, textures = t("rbxassetid://131732953848262", "rbxassetid://125769271183037", "rbxassetid://86397810143222"), mean = { 194, 136, 94 }, tone = "Tan" },
	{ id = "Vascular", name = "Vascular", tier = 1, textures = t("rbxassetid://120386864458604", "rbxassetid://122654494233325", "rbxassetid://116600013517130"), mean = { 232, 215, 203 } },
	{ id = "Peak", name = "Peak", tier = 1, textures = t("rbxassetid://87366831924259", "rbxassetid://127542859522710", "rbxassetid://71845369454810"), mean = { 178, 123, 80 }, tone = "Tan" },
	-- Tier 2: Stone
	{ id = "Clay", name = "Clay", tier = 2, placeholder = "#A0664A", textures = t(id(103208927128365), id(136027021701036), id(122387739358544)), mean = { 165, 98, 68 }, tone = "Raw" },
	{ id = "Sandstone", name = "Sandstone", tier = 2, placeholder = "#C9A46B", textures = t(id(117662966490292), id(111143229275099), id(102285905430312)), mean = { 210, 175, 122 }, tone = "Raw" },
	{ id = "Granite", name = "Granite", tier = 2, placeholder = "#7D7A78", textures = t(id(114152066626373), id(92860427424693), id(99689363876400)), mean = { 126, 122, 121 }, tone = "Raw" },
	{ id = "Marble", name = "Marble", tier = 2, placeholder = "#E6E2DA", textures = t(id(125633369236681), id(80871636008375), id(122670512763076)), mean = { 230, 227, 221 }, tone = "Raw" },
	{ id = "Obsidian", name = "Obsidian", tier = 2, placeholder = "#1E1A24", textures = t(id(74163280373750), id(128170621754211), id(136816173687866), id(90462650806054)), mean = { 43, 35, 58 }, tone = "Raw" },
	-- Tier 3: Metal
	{ id = "Bronze", name = "Bronze", tier = 3, placeholder = "#B0783C", textures = t(id(134358575784801), id(133985434758558), id(90828296969539), id(83720974094937)), mean = { 165, 114, 58 }, tone = "Raw" },
	{ id = "Iron", name = "Iron", tier = 3, placeholder = "#5E5E62", textures = t(id(85062646070713), id(84994385232743), id(109255323615122), id(120539270404937)), mean = { 75, 75, 78 }, tone = "Raw" },
	{ id = "Steel", name = "Steel", tier = 3, placeholder = "#9AA3AD", textures = t(id(109461347330742), id(119196588974380), id(123975203147889), id(124094158642489)), mean = { 164, 173, 183 }, tone = "Raw" },
	{ id = "Chrome", name = "Chrome", tier = 3, placeholder = "#D9DEE4", textures = t(id(90626623939699), id(112037747861980), id(130908811716029), id(128099095525117)), mean = { 217, 222, 229 }, tone = "Raw" },
	{ id = "Gold", name = "Gold", tier = 3, placeholder = "#F6C75A", textures = t(id(136879292698795), id(118971647256051), id(93359417743460), id(123859532569605)), mean = { 231, 179, 67 }, tone = "Raw" },
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

-- (prompt 38b, owner: "a deep bronze, not orange-red") The tan alters' (Tanned, Peak) color maps are orange-brown; times
-- a light skin tint they came out orange-red, times a dark one muddy. Their tint is worked out from the skin instead: hue
-- moved toward bronze, saturation kept between SatMin and SatMax, a light skin darkened a lot and a dark one only a bit
-- (Depth: { at value <= 0.35, at value >= 0.85 }, the color's brightness times this).
Alters.Tan = { Hue = 31 / 360, HueMove = 0.7, SatMin = 0.36, SatAdd = 0.12, SatMax = 0.5, Depth = { 0.84, 0.6 } }
-- the normal skin stages' color maps' average (Downloads/skin_textures, Stage1-3): what the plain skin is shown as
Alters.NaturalMean = { 243, 236, 226 }

local function meanOf(rgb): Color3 return Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end

-- The bronze a tan alter's body shows (on average) for a skin color.
function Alters.TanColor(skin: Color3): Color3
	local tan = Alters.Tan
	local h, s, v = skin:ToHSV()
	if h > 0.5 then h -= 1 end -- (a reddish hue just under 360 deg: toward bronze the short way)
	h = (h + (tan.Hue - h) * tan.HueMove) % 1
	s = math.clamp(s + tan.SatAdd, tan.SatMin, tan.SatMax)
	local light = math.clamp((v - 0.35) / 0.5, 0, 1)
	v *= tan.Depth[1] + (tan.Depth[2] - tan.Depth[1]) * light
	return Color3.fromHSV(h, s, v)
end

-- The SurfaceAppearance.Color (tint) for alter `id` on a skin color: the skin itself, or for a tan alter the tint that makes
-- its color map average to TanColor.
function Alters.Tint(id: string?, skin: Color3): Color3
	local alter = id and Alters.ById[id]
	if alter and alter.tone == "Raw" then return Color3.new(1, 1, 1) end -- (26 Oct) stone / metal: their own colors
	if not alter or alter.tone ~= "Tan" or not alter.mean then return skin end
	local want, mean = Alters.TanColor(skin), meanOf(alter.mean)
	return Color3.new(math.min(want.R / mean.R, 1), math.min(want.G / mean.G, 1), math.min(want.B / mean.B, 1))
end

-- The plain color that matches alter `id`'s body on a skin color (the head, which wears no alter maps; the elbow / knee
-- balls; the flat skin under a tint): the alter's average over the plain skin's (Natural = the skin).
function Alters.PlainSkin(id: string?, skin: Color3): Color3
	local alter = id and Alters.ById[id]
	if not alter or not alter.mean then return skin end
	local tint, mean, natural = Alters.Tint(id, skin), meanOf(alter.mean), meanOf(Alters.NaturalMean)
	return Color3.new(math.min(tint.R * mean.R / natural.R, 1), math.min(tint.G * mean.G / natural.G, 1), math.min(tint.B * mean.B / natural.B, 1))
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
	local goals = Alters.Goals
	if goals and #goals > 0 then
		if goals[n] then return goals[n] end
		return goals[#goals] + Alters.GoalPer * (n - #goals)
	end
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
