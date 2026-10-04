-- Muscle of the Day: one muscle group trains at 2x gains for the whole (UTC) day, the same for every server.
-- It is shown on the chalkboard by the front desk. Shared so the client's gain popups match the server.
local Muscles = require(script.Parent.Muscles)

local MuscleOfTheDay = {}

MuscleOfTheDay.Multiplier = 2
MuscleOfTheDay.Seed = 3 -- shifts which group starts the cycle

-- Unix time -> group id. `now` defaults to os.time().
function MuscleOfTheDay.GroupId(now)
	local day = math.floor((now or os.time()) / 86400)
	local groups = Muscles.Groups
	return groups[(day + MuscleOfTheDay.Seed) % #groups + 1].id
end

-- Multiplier for one muscle right now (2 for the day's group, otherwise 1).
function MuscleOfTheDay.MultiplierFor(muscleId, now)
	local group = Muscles.GroupById[MuscleOfTheDay.GroupId(now)]
	for _, muscle in ipairs(group.muscles) do
		if muscle.id == muscleId then return MuscleOfTheDay.Multiplier end
	end
	return 1
end

-- Seconds until the next group starts.
function MuscleOfTheDay.SecondsLeft(now)
	now = now or os.time()
	return 86400 - now % 86400
end

return MuscleOfTheDay
