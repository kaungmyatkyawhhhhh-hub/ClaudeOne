-- Seasonal events: decorations in the starter gym, a coin bonus, and a title for lifting during the event.
-- Dates are UTC month/day and repeat every year. Studio testing: set a string attribute "ForceSeason" on
-- Workspace (e.g. "Halloween") before pressing Play. Adding an event = adding an entry (+ its decor in SeasonService).
local Seasons = {}

Seasons.List = {
	{ id = "Halloween", name = "Halloween Gym", from = { 10, 15 }, to = { 11, 2 }, coins = 1.25,
		title = { name = "Pumpkin Spice Swole", reps = 200 } },
	{ id = "Winter", name = "Winter Lifts", from = { 12, 10 }, to = { 1, 6 }, coins = 1.25,
		title = { name = "Snow Plow", reps = 200 } },
	{ id = "Summer", name = "Summer Shred", from = { 6, 15 }, to = { 8, 31 }, coins = 1.25,
		title = { name = "Beach Ready", reps = 200 } },
}

Seasons.ById = {}
for _, season in ipairs(Seasons.List) do Seasons.ById[season.id] = season end

local function key(month, day)
	return month * 100 + day
end

-- The season running at unix time `now` (nil if none). Windows may wrap over New Year.
function Seasons.Active(now)
	local date = os.date("!*t", now or os.time())
	local today = key(date.month, date.day)
	for _, season in ipairs(Seasons.List) do
		local from, to = key(season.from[1], season.from[2]), key(season.to[1], season.to[2])
		local inside
		if from <= to then
			inside = today >= from and today <= to
		else
			inside = today >= from or today <= to
		end
		if inside then return season end
	end
	return nil
end

-- Title id for a season (titles live in Config.Titles with condition { type = "season", id = seasonId }).
function Seasons.TitleId(seasonId)
	return "Season" .. seasonId
end

return Seasons
