-- Social: the workout-together bonus, arm wrestling and crews. Tune the numbers here. (Spotting: Config.Spotting.)
local Social = {}

-- Lifting near other lifters.
Social.Together = {
	GainsBoost = 1.1,
	Range = 30,         -- studs between two lifters
}

-- Arm wrestling table (right side of the gym). Strength comes from these muscles.
Social.ArmWrestle = {
	TableSpot = Vector3.new(13.4, 0.1, -18.1), -- by the front desk (bigger gym, 8 Oct night)
	Muscles = { "Biceps", "Forearms", "FrontDelts" },
	PushPerTap = 0.035,     -- meter moved per tap at strength 1 (the meter goes from -1 to 1)
	LevelForDouble = 40,    -- average level of the muscles above that doubles your push
	MaxTapsPerSecond = 14,  -- faster taps are ignored (no auto-clickers)
	Countdown = 3,
	MaxSeconds = 12,        -- after this, whoever is ahead wins
	WaitForOpponent = 8,    -- seconds alone before a practice opponent sits down
	WinCoins = 15,
	LoseCoins = 5,
	PracticeWinCoins = 8,
	-- practice opponents (original characters)
	Rookies = {
		{ name = "Rocco", skin = "#C68642", shirt = "#1F5FBF", pants = "#1E1E22" },
		{ name = "Tess", skin = "#F1C27D", shirt = "#2E9E4F", pants = "#2B2B2B" },
		{ name = "Big Lou", skin = "#8D5524", shirt = "#D7262E", pants = "#1E1E22" },
	},
	RookieTapsPerSecond = { 5, 8 },   -- random in this range each match
	RookieStrength = { 0.85, 1.05 },  -- x the player's strength
}

-- Crews: small groups with a name and a short tag shown above members' heads. Saved across servers.
Social.Crew = {
	MaxMembers = 8,
	NameLength = { 3, 20 },
	TagLength = { 2, 4 },   -- letters and numbers only
	CreateCost = 0,         -- coins
	Refresh = 120,          -- seconds between crew score / top crews updates
}

-- Strength for arm wrestling from a player's muscle data.
function Social.Strength(muscleData)
	local sum = 0
	for _, id in ipairs(Social.ArmWrestle.Muscles) do
		sum += (muscleData[id] and muscleData[id].level or 0)
	end
	local average = sum / #Social.ArmWrestle.Muscles
	return 1 + average / Social.ArmWrestle.LevelForDouble
end

return Social
