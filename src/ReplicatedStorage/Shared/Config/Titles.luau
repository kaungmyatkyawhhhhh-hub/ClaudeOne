-- Titles are kept forever and never purchasable. One is equipped above your head.
-- Adding a title = adding an entry. Conditions are data, checked on the server by Titles.Check.
--   stat:      data.stats[stat] (or session stat) >= min
--   spurts:    Growth Spurts >= min
--   height:    height in inches >= min
--   ratio:     group level >= factor x (other group | average of the other groups), and >= minLevel
--   balanced:  all groups within `spread` (fraction) of each other, all >= minLevel
--   allGroups: every group >= minLevel
--   overall:   overall genetics grade == grade
--   maxedGrade: a group with this genetics grade has reached the mastery mark (130% of the Growth Spurt goal; there is no level cap)
--   legend:    finished legend `id`'s challenge (Config.Legends adds these automatically)
--   season:    `min` reps during seasonal event `id` (Config.Seasons adds these automatically)
--   never:     not obtainable yet (shows as ??? in the book)
-- badgeId: optional Roblox badge awarded with the title (create the badge on the website, paste the id).
local Muscles = require(script.Parent.Muscles)
local function exp(level) return Muscles.FormatExp(Muscles.Shown(level)) .. " exp" end -- levels are shown as EXP

local Titles = {}

-- Display colors live in Shared.UI.Theme.Rarity.
Titles.Rarities = {
	Common = { order = 1 },
	Uncommon = { order = 2 },
	Rare = { order = 3 },
	Epic = { order = 4 },
	Legendary = { order = 5 },
	Secret = { order = 6 },
}

Titles.List = {
	{ id = "BeginnerGains", name = "Beginner Gains", rarity = "Common", category = "Activity",
		description = "Do your first rep.", condition = { type = "stat", stat = "totalReps", min = 1 } },
	{ id = "GymRat", name = "Gym Rat", rarity = "Uncommon", category = "Activity",
		description = "Do 1,000 reps.", condition = { type = "stat", stat = "totalReps", min = 1000 } },
	{ id = "LockIn", name = "Lock In", rarity = "Rare", category = "Trend",
		description = "Do 50 reps in one set.", condition = { type = "stat", stat = "bestSet", min = 50 } },
	{ id = "GlowUp", name = "Glow Up", rarity = "Epic", category = "Trend",
		description = "Get every muscle to " .. exp(25) .. ".", condition = { type = "allGroups", minLevel = 25 } },
	{ id = "SkippedLegDay", name = "Skipped Leg Day", rarity = "Uncommon", category = "Physique",
		description = "Chest at least twice as strong as your legs.", condition = { type = "ratio", group = "Chest", versus = "Legs", factor = 2, minLevel = 15 } },
	{ id = "ChickenLegs", name = "Chicken Legs", rarity = "Uncommon", category = "Physique",
		description = "Arms at least twice as strong as your legs.", condition = { type = "ratio", group = "Arms", versus = "Legs", factor = 2, minLevel = 15 } },
	{ id = "BoulderShoulders", name = "Boulder Shoulders", rarity = "Rare", category = "Physique",
		description = "Shoulders 1.5x stronger than your other groups.", condition = { type = "ratio", group = "Shoulders", versus = "Others", factor = 1.5, minLevel = 20 } },
	{ id = "GreekStatue", name = "Greek Statue", rarity = "Epic", category = "Physique",
		description = "Every group within 10% of each other, every muscle " .. exp(30) .. "+.", condition = { type = "balanced", spread = 0.1, minLevel = 30 } },
	{ id = "AestheticsGod", name = "Aesthetics God", rarity = "Legendary", category = "Physique",
		description = "Every muscle at " .. exp(45) .. " or higher.", condition = { type = "allGroups", minLevel = 45 }, badgeId = nil },
	{ id = "LateBloomer", name = "Late Bloomer", rarity = "Rare", category = "Growth Spurt",
		description = "Do your first Growth Spurt.", condition = { type = "spurts", min = 1 } },
	{ id = "Skyscraper", name = "Skyscraper", rarity = "Legendary", category = "Growth Spurt",
		description = "Grow to 7'0\".", condition = { type = "height", min = 84 }, badgeId = nil },
	{ id = "GeneticFreak", name = "Genetic Freak", rarity = "Epic", category = "Genetics",
		description = "Have an S overall genetics grade.", condition = { type = "overall", grade = "S" } },
	{ id = "HardGainer", name = "Hard Gainer", rarity = "Uncommon", category = "Genetics",
		description = "Have a D overall genetics grade.", condition = { type = "overall", grade = "D" } },
	{ id = "DefiedGenetics", name = "Defied Genetics", rarity = "Legendary", category = "Genetics",
		description = "Take a muscle group with a D grade to 130% of the Growth Spurt goal.", condition = { type = "maxedGrade", grade = "D" }, badgeId = nil },
	{ id = "Spotter", name = "Spotter", rarity = "Rare", category = "Social",
		description = "Spot other lifters for 10 reps.", condition = { type = "stat", stat = "spotReps", min = 10 } },
	{ id = "GymBuddy", name = "Gym Buddy", rarity = "Uncommon", category = "Social",
		description = "Do 100 reps while someone lifts nearby.", condition = { type = "stat", stat = "togetherReps", min = 100 } },
	{ id = "IronGrip", name = "Iron Grip", rarity = "Rare", category = "Social",
		description = "Win 10 arm wrestling matches.", condition = { type = "stat", stat = "armWins", min = 10 } },
	{ id = "NoDaysOff", name = "No Days Off", rarity = "Secret", category = "Secret",
		description = "Do 500 reps in one visit.", condition = { type = "stat", stat = "sessionReps", min = 500 } },
}

-- One title per legend NPC (Config.Legends), earned by finishing that legend's challenge.
local Legends = require(script.Parent.Legends)
for _, legend in ipairs(Legends.List) do
	table.insert(Titles.List, {
		id = Legends.TitleId(legend.id), name = legend.title, rarity = "Epic", category = "Legend",
		description = "Finish " .. legend.name .. "'s challenge.", condition = { type = "legend", id = legend.id },
	})
end

-- One title per seasonal event (Config.Seasons), earned by lifting during that event.
local Seasons = require(script.Parent.Seasons)
for _, season in ipairs(Seasons.List) do
	table.insert(Titles.List, {
		id = Seasons.TitleId(season.id), name = season.title.name, rarity = "Epic", category = "Seasonal",
		description = "Do " .. season.title.reps .. " reps during " .. season.name .. ".",
		condition = { type = "season", id = season.id, min = season.title.reps },
	})
end

Titles.ById = {}
for _, title in ipairs(Titles.List) do
	Titles.ById[title.id] = title
end

-- ctx = { data, groups = { [groupId] = level }, cap, heightInches, goalGroups = { [groupId] = goal level }, session = {} }
function Titles.Check(title, ctx)
	local c = title.condition
	local data = ctx.data
	if c.type == "stat" then
		local value = (data.stats and data.stats[c.stat]) or (ctx.session and ctx.session[c.stat]) or 0
		return value >= c.min
	elseif c.type == "spurts" then
		return data.growthSpurts >= c.min
	elseif c.type == "height" then
		return ctx.heightInches >= c.min
	elseif c.type == "ratio" then
		local level = ctx.groups[c.group]
		if level < c.minLevel then return false end
		local other
		if c.versus == "Others" then
			local sum, n = 0, 0
			for id, value in pairs(ctx.groups) do
				if id ~= c.group then sum += value n += 1 end
			end
			other = sum / n
		else
			other = ctx.groups[c.versus]
		end
		return level >= c.factor * math.max(other, 1)
	elseif c.type == "balanced" or c.type == "allGroups" then
		local low, high = math.huge, 0
		for _, value in pairs(ctx.groups) do
			low = math.min(low, value)
			high = math.max(high, value)
		end
		if low < c.minLevel then return false end
		return c.type == "allGroups" or (high - low) <= high * c.spread
	elseif c.type == "overall" then
		return data.genetics.overall == c.grade
	elseif c.type == "season" then
		return data.seasons ~= nil and (data.seasons[c.id] or 0) >= c.min
	elseif c.type == "legend" then
		return data.legends ~= nil and data.legends.met[c.id] == true
	elseif c.type == "maxedGrade" then
		for groupId, grade in pairs(data.genetics.grades) do
			if grade == c.grade and (ctx.goalGroups[groupId] or 0) >= ctx.mastery then return true end
		end
		return false
	end
	return false
end

return Titles
