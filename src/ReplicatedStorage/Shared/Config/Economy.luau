-- Coins outside of reps: daily streak, offline coins, re-racking loose plates, DNA tokens at the front desk, and
-- rush hour. All paid out on the server (RetentionService). Tune the numbers here.
local Economy = {}

-- Daily streak: claimed automatically on the first join of each UTC day.
-- Missing days only drops the streak a few days back (not to zero).
Economy.Daily = {
	BaseCoins = 20,
	CoinsPerDay = 5,        -- + this per streak day
	MaxStreakBonus = 30,    -- streak days counted for coins
	DropPerMissedDay = 3,   -- each missed day takes this many days off the streak
	TokenEvery = 7,         -- a DNA token on every 7th streak day
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

-- Streak after a join on `today`, given the last claimed day and streak. Returns newStreak, claimedToday.
function Economy.NextStreak(lastDay, streak, today)
	if lastDay == today then return streak, false end
	if lastDay == today - 1 then return streak + 1, true end
	if lastDay <= 0 then return 1, true end
	local missed = today - lastDay - 1
	return math.max(0, streak - missed * Economy.Daily.DropPerMissedDay) + 1, true
end

function Economy.StreakCoins(streak)
	return Economy.Daily.BaseCoins + Economy.Daily.CoinsPerDay * math.min(streak, Economy.Daily.MaxStreakBonus)
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
