-- Coins outside of reps: the login streak calendar, offline coins, re-racking loose plates, DNA tokens at the front desk, and
-- rush hour. All paid out on the server (RetentionService). Tune the numbers here.
local Economy = {}

-- Login streak (owner's feature run, task 2; replaces the old automatic streak): a 7-day calendar. Join each UTC day and
-- press Claim for that day's reward (a popup on join, or the Daily pill). Missing a day starts again at day 1; after day 7
-- the calendar starts over. Day 7 is the big one: coins, a DNA token and (the first time) the "Dedicated" title.
Economy.Login = {
	Coins = { 25, 35, 50, 70, 90, 120, 300 }, -- day 1..7
	Day7DnaTokens = 1,
}

-- Offline coins: for time away, capped.
Economy.Offline = {
	CoinsPerMinute = 0.5,
	CapHours = 8,
	MinMinutes = 10,        -- shorter breaks give nothing
}

-- Loose plates around the gym: re-rack them for coins.
Economy.Rerack = {
	Coins = 5,
	MaxLoose = 3,
	SpawnEvery = 90,        -- seconds between new loose plates (if fewer than MaxLoose)
	-- floor spots (x, z) near the benches and racks where someone "left" a plate
	Spots = {
		Vector2.new(-10, -61), Vector2.new(20.5, -60), Vector2.new(-24.5, -37), Vector2.new(-24.5, -50),
		Vector2.new(-11, -24), Vector2.new(-11, -40), Vector2.new(22, -42), Vector2.new(6, -58),
	},
	Weights = { 10, 25, 35, 45 }, -- plates from ReplicatedStorage.GymAssets
}

-- DNA tokens can be bought with coins at the front desk.
Economy.DnaTokenCost = 400

-- Rush hour: every 30 minutes (on the clock, the same on every server) the gym is busy for a few minutes.
Economy.RushHour = {
	EveryMinutes = 30,
	LengthMinutes = 3,
	Coins = 2,              -- x coins per rep during rush hour
}

-- Day number (UTC) for a unix time.
function Economy.Day(now)
	return math.floor((now or os.time()) / 86400)
end

-- The calendar day to claim today (1..7), or nil when today's reward is already claimed. lastDay = the day number of the
-- last claim (0 = never), calendarDay = the calendar day claimed then.
function Economy.LoginDay(lastDay, calendarDay, today)
	if lastDay == today then return nil end
	if lastDay == today - 1 then return (calendarDay or 0) % #Economy.Login.Coins + 1 end
	return 1 -- first claim ever, or a missed day: back to day 1
end

-- The reward for a calendar day: coins, DNA tokens.
function Economy.LoginReward(calendarDay)
	local coins = Economy.Login.Coins[calendarDay] or Economy.Login.Coins[1]
	local tokens = calendarDay == #Economy.Login.Coins and Economy.Login.Day7DnaTokens or 0
	return coins, tokens
end

function Economy.OfflineCoins(secondsAway)
	local minutes = secondsAway / 60
	if minutes < Economy.Offline.MinMinutes then return 0 end
	minutes = math.min(minutes, Economy.Offline.CapHours * 60)
	return math.floor(minutes * Economy.Offline.CoinsPerMinute)
end

-- Rush hour window for a unix time: returns active, secondsLeft (if active) or secondsUntil (if not).
function Economy.RushHourAt(now)
	local period = Economy.RushHour.EveryMinutes * 60
	local length = Economy.RushHour.LengthMinutes * 60
	local into = (now or os.time()) % period
	if into < length then return true, length - into end
	return false, period - into
end

return Economy
