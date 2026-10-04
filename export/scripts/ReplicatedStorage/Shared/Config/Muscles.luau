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

-- XP needed to go from `level` to `level + 1` (1525 XP from 0 to 50).
function Muscles.XpToNext(level)
	return 6 + level
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

return Muscles
