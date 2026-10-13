-- Shakes & meals (owner's feature run, task 5): timed boosts bought with coins at the smoothie bar in the pro gym, a cart
-- in the starter gym and a coconut cart at the beach gym (MealService, MealClient; carts from tools/builders/SmoothieCarts).
-- One boost of each kind at a time: buying it again adds its time, up to MaxStack x its duration. Boosts PAUSE when you
-- leave and pick up where they were when you come back (the time left is saved).
-- effects (multiply with every other boost through BoostService): gains = EXP, regen = stamina refill, cardio = treadmill
-- distance. (The Energy Shakes in your bag are a different thing: an instant refill, Config.Stamina.Shake. To keep them
-- apart the bar's items use their own icon (a cup with a straw, or a bowl) in their own color, never the shaker icon.)
local Meals = {}

Meals.MaxStack = 3 -- a boost holds at most this many purchases' worth of time

Meals.Items = {
	{ id = "ProteinShake", name = "Protein Shake", price = 60, seconds = 5 * 60, effects = { gains = 1.2 },
		text = "+20% EXP for 5 min", color = "#E8DCC8", icon = "Cup" },
	{ id = "EnergySmoothie", name = "Energy Smoothie", price = 50, seconds = 5 * 60, effects = { regen = 1.5 },
		text = "Stamina refills 50% faster for 5 min", color = "#F2A33A", icon = "Cup" },
	{ id = "ChickenRice", name = "Chicken & Rice", price = 90, seconds = 10 * 60, effects = { gains = 1.1, regen = 1.1 },
		text = "+10% EXP and +10% stamina refill for 10 min", color = "#F4F1EA", icon = "Bowl" },
	{ id = "CoconutWater", name = "Coconut Water", price = 40, seconds = 5 * 60, effects = { cardio = 1.5 },
		text = "Run 50% farther on the treadmill for 5 min", color = "#9BD48A", icon = "Cup" },
}
Meals.ById = {}
for _, item in ipairs(Meals.Items) do Meals.ById[item.id] = item end

-- What each stall sells (a stall is a part with the attribute MealShop = its id).
Meals.Shops = {
	SmoothieBar = { name = "Smoothie bar", items = { "ProteinShake", "EnergySmoothie", "ChickenRice" } },  -- pro gym
	StarterCart = { name = "Smoothie cart", items = { "ProteinShake", "EnergySmoothie", "ChickenRice" } }, -- starter gym
	CoconutCart = { name = "Coconut cart", items = { "CoconutWater", "EnergySmoothie" } },                -- beach gym only
}

Meals.PromptDistance = 8
Meals.DrinkSeconds = 2 -- how long the character holds the shaker
Meals.SaveEvery = 5      -- seconds between updates of the saved time left

-- Seconds left after buying `item` when `left` seconds were still running (capped at MaxStack purchases).
function Meals.Extend(item, left: number): number
	return math.min(math.max(left, 0) + item.seconds, item.seconds * Meals.MaxStack)
end

-- Can it be bought again with `left` seconds still running? Only when the whole drink's time fits under the cap (so a
-- purchase never pays for time that would be thrown away). Otherwise the shop shows FULL.
function Meals.CanBuy(item, left: number): boolean
	return math.max(left, 0) + item.seconds <= item.seconds * Meals.MaxStack + 1
end

-- "4:32"
function Meals.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Meals
