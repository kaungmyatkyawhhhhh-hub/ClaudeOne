-- Coins outside of reps: the login streak calendar, offline coins, re-racking loose plates and rush hour. All paid out on the server (RetentionService). Tune the numbers here.
local Economy = {}

-- Login streak (owner's feature run, task 2; replaces the old automatic streak): a 7-day calendar. Join each UTC day and
-- press Claim for that day's reward (a popup on join, or the Daily pill). Missing a day starts again at day 1; after day 7
-- the calendar starts over. Day 7 is the big one: the most coins, a DNA token and (the first time) the "Dedicated" title.
-- Day 4 also gives a DNA token (owner, 14 Oct: an allowed DNA token source, see Config/DNA; keep it).
Economy.Login = {
	Coins = { 25, 35, 50, 70, 90, 120, 300 }, -- day 1..7
	DnaTokens = { [4] = 1, [7] = 1 },         -- DNA tokens on top of that day's coins
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

-- Rush hour: every 30 minutes (on the clock, the same on every server) the gym is busy for a few minutes.
Economy.RushHour = {
	EveryMinutes = 30,
	LengthMinutes = 3,
	Coins = 2,              -- x coins per rep during rush hour
}

-- (prompt 61) `minutes` of coins at a player's stage (spurts = their Growth Spurts): the BASE coins a minute
-- (Config/PumpShop.CoinsPerMinute: no passes, trainers, auras, rush hour or events, so boosts never change a price or a
-- reward's size), rounded like the shop's prices. The UI always shows the real number, never "minutes".
function Economy.Minutes(spurts: number?, minutes: number): number
	local PumpShop = require(script.Parent.PumpShop)
	return PumpShop.Round(minutes * PumpShop.Rate(spurts))
end

-- (prompt 61) Rewards grow with the player: minutes of coins at their stage (Economy.Minutes). The old fixed amount of
-- each reward is its floor: a reward never pays less than it did before. Economy.Reward(spurts, minutes, floor).
Economy.Rewards = {
	Login = { 2, 2, 3, 4, 5, 6, 15 },  -- days 1..7 (Economy.Login.Coins are the floors; the DNA tokens stay as they are)
	DailyQuest = 3, DailyBonus = 10,   -- each daily quest; all of them done
	CoachFirst = 1, CoachLast = 5,     -- Coach Dex's quests, in their order: the first ones 1 min up to 5 for the late ones
	CoachRepeat = 4,                   -- his repeatable quests (after the chain)
	Posing = { 8, 5, 3 }, PosingEnter = 1, -- posing show: 1st / 2nd / 3rd, everyone else
	Rivals = { Benny = 5, Coral = 8, Dante = 12 },
	Legend = 3, Guide = 1,
	OfflineShare = 0.02,               -- offline coins a minute = 2% of the stage's coins a minute (at least the old 0.5)
	Rerack = 0.1, Spot = 0.1, ArmWin = 0.5, ArmLose = 0.15,
	GroupGift = 15, RebalanceGift = 5,
}

-- (prompt 61) every coin multiplier together (2x Coins pass, VIP, trainers, auras, rush hour, events, boosts) is capped at
-- this, in ONE place: BoostService.Coins (the coins every rep pays). Stats shows "COIN BOOST x5.2" / "x8 (MAX)".
Economy.CoinBoostCap = 8

function Economy.Reward(spurts: number?, minutes: number, floor: number?): number
	return math.max(floor or 0, Economy.Minutes(spurts, minutes))
end

-- Day number (UTC) for a unix time.
function Economy.Day(now)
	return math.floor((now or os.time()) / 86400)
end

-- (26 Oct) The streak survives this many missed UTC days. The UTC day turns over at 4-5 PM in the US, so a kid playing every
-- afternoon can skip a whole UTC day without missing a real day (claim Mon 4:30 PM PDT, play Tue 7 PM PDT = 2 UTC days later).
Economy.StreakGraceDays = 1

-- Does a claim on `today` continue the streak from a claim on `lastDay`?
function Economy.ContinuesStreak(lastDay, today): boolean
	return lastDay ~= nil and lastDay > 0 and lastDay < today and today - lastDay <= 1 + Economy.StreakGraceDays
end

-- The calendar day to claim today (1..7), or nil when today's reward is already claimed. lastDay = the day number of the
-- last claim (0 = never), calendarDay = the calendar day claimed then.
function Economy.LoginDay(lastDay, calendarDay, today)
	if lastDay == today then return nil end
	if Economy.ContinuesStreak(lastDay, today) then return (calendarDay or 0) % #Economy.Login.Coins + 1 end
	return 1 -- first claim ever, or a missed day: back to day 1
end

-- The reward for a calendar day: coins (prompt 61: at the player's stage), DNA tokens.
function Economy.LoginReward(calendarDay, spurts: number?)
	local day = if Economy.Login.Coins[calendarDay] then calendarDay else 1
	return Economy.Reward(spurts, Economy.Rewards.Login[day], Economy.Login.Coins[day]), Economy.Login.DnaTokens[calendarDay] or 0
end

-- (prompt 61) a minute away pays OfflineShare of the stage's coins a minute (never less than the old CoinsPerMinute)
function Economy.OfflineCoins(secondsAway, spurts: number?)
	local minutes = secondsAway / 60
	if minutes < Economy.Offline.MinMinutes then return 0 end
	minutes = math.min(minutes, Economy.Offline.CapHours * 60)
	local rate = math.max(Economy.Offline.CoinsPerMinute, Economy.Rewards.OfflineShare * require(script.Parent.PumpShop).Rate(spurts))
	return math.floor(minutes * rate)
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
