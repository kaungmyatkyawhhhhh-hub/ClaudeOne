local H = require("./harness")
local Seasons = H.module("ReplicatedStorage/Shared/Config/Seasons")
local Titles = H.module("ReplicatedStorage/Shared/Config/Titles")
local function at(y, m, d) return os.time({ year = y, month = m, day = d, hour = 12 }) end
print("Seasons")
H.check(Seasons.Active(at(2026, 10, 5)) == nil, "Oct 5: no season")
H.check(Seasons.Active(at(2026, 10, 20)).id == "Halloween", "Oct 20: Halloween")
H.check(Seasons.Active(at(2026, 11, 2)).id == "Halloween", "Nov 2: still Halloween")
H.check(Seasons.Active(at(2026, 11, 3)) == nil, "Nov 3: over")
H.check(Seasons.Active(at(2026, 12, 24)).id == "Winter", "Dec 24: Winter")
H.check(Seasons.Active(at(2027, 1, 3)).id == "Winter", "Jan 3: Winter (wraps New Year)")
H.check(Seasons.Active(at(2027, 1, 7)) == nil, "Jan 7: over")
H.check(Seasons.Active(at(2027, 7, 1)).id == "Summer", "Jul 1: Summer")
for _, s in Seasons.List do
	local t = Titles.ById[Seasons.TitleId(s.id)]
	H.check(t ~= nil, s.id .. " title exists")
	H.check(Titles.Check(t, { data = { seasons = { [s.id] = s.title.reps } } }), s.id .. " title unlocks at " .. s.title.reps)
	H.check(not Titles.Check(t, { data = { seasons = {} } }), s.id .. " title locked at 0")
end
H.done()
