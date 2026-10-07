-- 18 muscles in 6 groups. Adding a muscle = adding an entry here.
local Muscles = {}

Muscles.Groups = {
	{ id = "Chest", name = "Chest", muscles = {
		{ id = "UpperChest", name = "Upper Chest" },
		{ id = "MidChest", name = "Mid Chest" },
	} },
	{ id = "Shoulders", name = "Shoulders", muscles = {
		{ id = "FrontDelts", name = "Front Delts" },
		{ id = "SideDelts", name = "Side Delts" },
		{ id = "RearDelts", name = "Rear Delts" },
	} },
	{ id = "Back", name = "Back", muscles = {
		{ id = "Lats", name = "Lats" },
		{ id = "Traps", name = "Traps" },
		{ id = "Rhomboids", name = "Rhomboids" },
		{ id = "LowerBack", name = "Lower Back" },
	} },
	{ id = "Arms", name = "Arms", muscles = {
		{ id = "Biceps", name = "Biceps" },
		{ id = "Triceps", name = "Triceps" },
		{ id = "Forearms", name = "Forearms" },
	} },
	{ id = "Legs", name = "Legs", muscles = {
		{ id = "Quads", name = "Quads" },
		{ id = "Hamstrings", name = "Hamstrings" },
		{ id = "Glutes", name = "Glutes" },
		{ id = "Calves", name = "Calves" },
	} },
	{ id = "Core", name = "Core", muscles = {
		{ id = "Abs", name = "Abs" },
		{ id = "Obliques", name = "Obliques" },
	} },
}

Muscles.List = {}      -- flat list of every muscle
Muscles.ById = {}      -- muscleId -> muscle
Muscles.GroupById = {} -- groupId -> group
for _, group in ipairs(Muscles.Groups) do
	Muscles.GroupById[group.id] = group
	for _, muscle in ipairs(group.muscles) do
		muscle.group = group.id
		table.insert(Muscles.List, muscle)
		Muscles.ById[muscle.id] = muscle
	end
end

-- Where each muscle sits on an R15 body: the part, an offset in that part's space
-- (-Z is the front), which side faces out, and which parts swell when it's pumped.
local ARMS = { "RightUpperArm", "LeftUpperArm" }
Muscles.Body = {
	UpperChest = { part = "UpperTorso", offset = Vector3.new(0, 0.5, -0.55), facing = "Front", pump = { "UpperTorso" } },
	MidChest = { part = "UpperTorso", offset = Vector3.new(0, 0.1, -0.6), facing = "Front", pump = { "UpperTorso" } },
	FrontDelts = { part = "RightUpperArm", offset = Vector3.new(0, 0.35, -0.4), facing = "Front", pump = ARMS },
	SideDelts = { part = "RightUpperArm", offset = Vector3.new(0.4, 0.35, 0), facing = "Front", pump = ARMS },
	RearDelts = { part = "RightUpperArm", offset = Vector3.new(0, 0.35, 0.4), facing = "Back", pump = ARMS },
	Lats = { part = "UpperTorso", offset = Vector3.new(0.7, 0, 0.4), facing = "Back", pump = { "UpperTorso" } },
	Traps = { part = "UpperTorso", offset = Vector3.new(0, 0.8, 0.3), facing = "Back", pump = { "UpperTorso" } },
	Rhomboids = { part = "UpperTorso", offset = Vector3.new(0, 0.2, 0.5), facing = "Back", pump = { "UpperTorso" } },
	LowerBack = { part = "LowerTorso", offset = Vector3.new(0, 0.2, 0.45), facing = "Back", pump = { "LowerTorso" } },
	Biceps = { part = "RightUpperArm", offset = Vector3.new(0, 0, -0.4), facing = "Front", pump = ARMS },
	Triceps = { part = "RightUpperArm", offset = Vector3.new(0, 0, 0.4), facing = "Back", pump = ARMS },
	Forearms = { part = "RightLowerArm", offset = Vector3.new(0, 0, -0.3), facing = "Front", pump = { "RightLowerArm", "LeftLowerArm" } },
	Quads = { part = "RightUpperLeg", offset = Vector3.new(0, 0, -0.45), facing = "Front", pump = { "RightUpperLeg", "LeftUpperLeg" } },
	Hamstrings = { part = "RightUpperLeg", offset = Vector3.new(0, 0, 0.45), facing = "Back", pump = { "RightUpperLeg", "LeftUpperLeg" } },
	Glutes = { part = "LowerTorso", offset = Vector3.new(0, -0.2, 0.5), facing = "Back", pump = { "LowerTorso" } },
	Calves = { part = "RightLowerLeg", offset = Vector3.new(0, 0, 0.4), facing = "Back", pump = { "RightLowerLeg", "LeftLowerLeg" } },
	Abs = { part = "LowerTorso", offset = Vector3.new(0, 0.3, -0.5), facing = "Front", pump = { "LowerTorso" } },
	Obliques = { part = "LowerTorso", offset = Vector3.new(0.6, 0.3, -0.3), facing = "Front", pump = { "LowerTorso" } },
}

-- XP needed to go from `level` to `level + 1` (about one level per rep at the start; 3450 XP from 0 to 50).
function Muscles.XpToNext(level)
	return 20 + 2 * level
end

-- Group level = average of its sub-muscle levels. `muscleData` is data.muscles.
function Muscles.GetGroupLevel(muscleData, groupId)
	local group = Muscles.GroupById[groupId]
	local total = 0
	for _, muscle in ipairs(group.muscles) do
		total += muscleData[muscle.id].level
	end
	return total / #group.muscles
end

------------------------------------------------------------------------
-- EXP: the number everyone SEES. Inside the game a muscle has a level and some xp towards the next level (saves, caps and
-- machines work on levels), but the stats show EXP = every xp the muscle has ever earned, times one constant, so the first
-- Growth Spurt asks for exactly Muscles.FirstSpurtExp (50,000) in every group. A rep's gain popup is the same unit.
--   xp for level L = sum of XpToNext = L*L + 19*L   (also fine for a fractional level)
------------------------------------------------------------------------
Muscles.FirstSpurtExp = 50000 -- EXP a group needs for the first Growth Spurt
Muscles.FirstSpurtLevel = 15  -- = GrowthSpurts stage 1 requiredLevel (tests/muscles checks they agree)

-- xp earned in total to be at `level` (levels may be fractional)
function Muscles.CumXp(level)
	return level * level + 19 * level
end
-- the (fractional) level where the total xp is `xp`
function Muscles.LevelFromXp(xp)
	return (-19 + math.sqrt(361 + 4 * math.max(xp, 0))) / 2
end

-- EXP shown per xp
Muscles.ExpPerXp = Muscles.FirstSpurtExp / Muscles.CumXp(Muscles.FirstSpurtLevel)

-- One muscle's entry ({ level, xp }) as total xp, and as an exact (fractional) level.
function Muscles.EntryXp(entry)
	return entry and (Muscles.CumXp(entry.level) + (entry.xp or 0)) or 0
end
function Muscles.ExactLevel(entry)
	return Muscles.LevelFromXp(Muscles.EntryXp(entry))
end

-- EXP shown for a level (fractional ok) / for an amount of xp (a rep's gain)
function Muscles.Shown(level)
	return math.floor(Muscles.CumXp(level) * Muscles.ExpPerXp + 0.5)
end
function Muscles.ShownXp(xp)
	return math.floor(xp * Muscles.ExpPerXp + 0.5)
end

-- EXP of one muscle, of a group (its muscles ADDED UP: Core = Abs + Obliques), and of the whole body (strength)
function Muscles.MuscleExp(entry)
	return math.floor(Muscles.EntryXp(entry) * Muscles.ExpPerXp + 0.5)
end
function Muscles.GroupExp(muscleData, groupId)
	local group = Muscles.GroupById[groupId]
	local total = 0
	for _, muscle in ipairs(group.muscles) do total += Muscles.EntryXp(muscleData[muscle.id]) end
	return math.floor(total * Muscles.ExpPerXp + 0.5)
end
-- A group's EXP target for a level every one of its muscles should reach (the Growth Spurt goal, quests): the level's
-- EXP times the number of muscles, the same sum the stats show.
function Muscles.GroupShown(groupId, level)
	return Muscles.Shown(level) * #Muscles.GroupById[groupId].muscles
end

------------------------------------------------------------------------
-- The LOOK: how big a muscle is drawn (g: 0 = flat on the skin, 1 = the full aesthetic shape, above 1 = mass monster).
-- r = the muscle's EXP / the EXP of the current Growth Spurt goal (2x = twice the goal's EXP, as the stats show).
-- Reaching the goal does NOT max the look:
--   0 .. AestheticAt x the goal: g rises to 1 (eased out, so the first reps show)
--   AestheticAt .. MonsterAt:    g grows on to the muscle's mass monster size (muscle_v8 manifest mass_monster.g)
--   past MonsterAt:              the look stays at the monster size; the stats keep counting (there is no stat cap)
------------------------------------------------------------------------
Muscles.Look = {
	AestheticAt = 2,
	MonsterAt = 5,
	Ease = 1.6,
	DefaultMonsterG = 1.35,
	-- muscle_v8 manifest mass_monster.g (the aesthetic max update raised them so the monster stays bulky); the meshes that
	-- grow with another muscle (DeltCap with Side Delts, UpperTraps with Traps) have their own size in MuscleData.Index
	MonsterG = {
		UpperChest = 1.522, MidChest = 1.522, FrontDelts = 1.526, SideDelts = 1.5, RearDelts = 1.45, Lats = 1.318,
		Traps = 2.625, Rhomboids = 1.7, LowerBack = 1.647, Biceps = 2.083, Triceps = 2.083, Forearms = 2, Quads = 2.132,
		Hamstrings = 2, Glutes = 1.8, Calves = 1.875, Abs = 1.316, Obliques = 2.909,
	},
}
Muscles.MaxLookG = 2.909 -- the biggest MonsterG

function Muscles.MonsterG(muscleId: string): number
	return Muscles.Look.MonsterG[muscleId] or Muscles.Look.DefaultMonsterG
end

-- g for a muscle at `level` while the Growth Spurt goal is `goalLevel`
function Muscles.LookG(muscleId: string, level: number, goalLevel: number): number
	local look = Muscles.Look
	local r = Muscles.CumXp(math.max(level, 0)) / math.max(Muscles.CumXp(math.max(goalLevel, 1)), 1)
	if r <= look.AestheticAt then
		return 1 - (1 - r / look.AestheticAt) ^ look.Ease
	end
	local monster = Muscles.MonsterG(muscleId)
	local t = math.clamp((r - look.AestheticAt) / (look.MonsterAt - look.AestheticAt), 0, 1)
	return 1 + (monster - 1) * t
end
function Muscles.TotalExp(muscleData)
	local total = 0
	for _, muscle in ipairs(Muscles.List) do total += Muscles.EntryXp(muscleData[muscle.id]) end
	return math.floor(total * Muscles.ExpPerXp + 0.5)
end

-- 12345 -> "12,345"
function Muscles.FormatExp(value)
	local formatted, count = tostring(math.floor(value)), 1
	while count > 0 do
		formatted, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	end
	return formatted
end

-- Total strength: every muscle level added up (used by logic; the stats show Muscles.TotalExp).
function Muscles.TotalStrength(muscleData)
	local total = 0
	for _, muscle in ipairs(Muscles.List) do
		local entry = muscleData[muscle.id]
		total += entry and entry.level or 0
	end
	return total
end

return Muscles
