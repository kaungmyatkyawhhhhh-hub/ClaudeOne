-- Playtime gifts (26 Oct, retention): gifts for the minutes you've played TODAY (UTC day, saved, so rejoining never resets
-- them and a short visit tomorrow starts a new set). Each gift is claimed by itself when its time comes (after the tutorial)
-- with a reward popup that says what the next one is, so there is always a reason to play a little longer.
-- PlaytimeService pays; PlaytimeClient shows the popups. `coins` = minutes of coins at the player's stage (Economy.Reward,
-- `floor` = never less), `item` = a Config.Boosts id into the inventory, `roll` = a free trainer roll (coins instead before
-- trainers open at Growth Spurt 1).
local Playtime = {}

Playtime.Gifts = {
	{ minutes = 3, coins = 2, floor = 50 },
	{ minutes = 8, item = "Shake" },
	{ minutes = 15, coins = 4, floor = 100 },
	{ minutes = 25, item = "Creatine" },
	{ minutes = 40, coins = 8, floor = 250 },
	{ minutes = 60, roll = true, coins = 10, floor = 300 },
}

Playtime.TickSeconds = 10 -- how often the server adds play time (and checks for a gift)
Playtime.SaveEvery = 60   -- seconds between saves of the counter (a gift saves at once)

-- What a gift gives, in words ("Protein Shake", "Free trainer roll", "+120 coins"), for the popups.
function Playtime.Describe(gift, coins: number?, canRoll: boolean?): string
	if gift.item then
		local item = require(script.Parent.Boosts).ById[gift.item]
		return if item then item.name else gift.item
	end
	if gift.roll and canRoll then return "Free trainer roll" end
	return "+" .. tostring(coins or 0) .. " coins"
end

-- (owner, 26 Oct: "when they r doing tutorials give them boosts like new player boost so they grind hard") NEW PLAYER
-- BOOST: gains and coins x for the first Minutes of play (data.playtime.total; from the first second, tutorial included;
-- put back on a rejoin for what's left). PlaytimeService, BoostService source "NewPlayer".
Playtime.NewPlayer = { gains = 2, coins = 2, minutes = 15 }

return Playtime
