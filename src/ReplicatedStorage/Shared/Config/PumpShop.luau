-- PUMP SHOP (owner, prompt 19, 21 Oct): one big store in the town hub that sells everything worth buying with coins.
-- Coins only (no Robux here), no random rolls. Four sections, each with its own counter and clerk: SUPPLEMENTS, GEAR,
-- APPAREL, DNA LAB, ALTERS (prompt 21: the next Body Alter, its goal and bonus; open at 7'0", nothing for sale). PumpShopService (server) sells, PumpShopClient shows the panel.
--
-- HOW THE PRICES WERE CHOSEN: coins per minute of active play, measured with the real formulas (tests/pacing coins, 60
-- simulated players, base rate: no 2x Coins pass, VIP, rush hour or event bonus):
--   Growth Spurt 0: 57 · 1: 110 · 2: 152 · 3: 200 · 4: 220 · 5: 222 · 7'0" max: 328 coins a minute
-- Supplements cost a few minutes of coins at the player's own stage (Minutes x the rate, rounded), so a boost always
-- feels the same. Gear: Basic ~5 min at Growth Spurt 2 (when gear opens), Pro ~20 min at Spurt 3, Elite over an hour of
-- max-stage coins (a long goal for players at 7'0"). Apparel is cosmetic: 3 to 10 minutes at Growth Spurt 2. DNA tokens
-- keep the 25,000 base (Config/DNA) and get 10% dearer for each one bought in the same week.
local PumpShop = {}

PumpShop.CoinsPerMinute = { [0] = 57, [1] = 110, [2] = 152, [3] = 200, [4] = 220, [5] = 222, [6] = 328 } -- [Growth Spurts]

-- Unlocks (gameplay plan "Introduce features slowly"): the shop opens ~8 minutes in (or at the first Growth Spurt) with
-- Supplements only; Gear and Apparel open at Growth Spurt 2.
PumpShop.OpenAfterMinutes = 8
PumpShop.GearAtSpurt = 2
PumpShop.TeleportCooldown = 10 -- seconds between two uses of the Shop window's "Go to Pump Shop" link (prompt 28)
PumpShop.AffordEvery = 5 * 60   -- seconds: at most one "You can afford: ..." toast this often
PumpShop.TryOnSeconds = 12      -- a try-on (apparel) lasts this long, or until the panel closes

PumpShop.Sections = {
	{ id = "Supplements", name = "Supplements", icon = "cup-soda" },
	{ id = "Gear", name = "Gear", icon = "dumbbell", fromSpurt = 2 },
	{ id = "Apparel", name = "Apparel", icon = "star", fromSpurt = 2 },
	{ id = "DnaLab", name = "DNA Lab", icon = "sparkles" },
	{ id = "Alters", name = "Alters", icon = "flame", atMax = true }, -- (prompt 21: at 7'0"; Body Alters are never bought)
}

------------------------------------------------------------------------
-- SUPPLEMENTS: the boost items (Config.Boosts) into the inventory. price = Minutes x the coins a minute at your stage.
------------------------------------------------------------------------
PumpShop.Supplements = {
	{ id = "Shake", minutes = 3 },
	{ id = "CoconutWater", minutes = 3 },
	{ id = "Creatine", minutes = 5 },
	{ id = "ProteinPowder", minutes = 5 },
	{ id = "Supplements", minutes = 4 },
	{ id = "PreWorkout", minutes = 4 },
}
PumpShop.Quantities = { 1, 5, 10 }

local function round(n: number): number
	if n >= 1000 then return math.floor(n / 50 + 0.5) * 50 end
	return math.max(5, math.floor(n / 5 + 0.5) * 5)
end

function PumpShop.Rate(spurts: number?): number
	local s = math.clamp(spurts or 0, 0, 6)
	return PumpShop.CoinsPerMinute[s] or PumpShop.CoinsPerMinute[6]
end

-- The price of one supplement for a player with `spurts` Growth Spurts.
function PumpShop.SupplementPrice(id: string, spurts: number?): number?
	for _, entry in ipairs(PumpShop.Supplements) do
		if entry.id == id then return round(entry.minutes * PumpShop.Rate(spurts)) end
	end
	return nil
end

------------------------------------------------------------------------
-- GEAR: worn on the character (Config.Cosmetics items with a `perk`), a small permanent bonus while worn. Three levels;
-- each level needs the one before. bonus = extra EXP on the machines it helps.
------------------------------------------------------------------------
PumpShop.GearLevels = {
	{ id = "Basic", name = "Basic", bonus = 0.05, price = 750, color = "#2B2B30" },
	{ id = "Pro", name = "Pro", bonus = 0.10, price = 4000, color = "#B3262D" },
	{ id = "Elite", name = "Elite", bonus = 0.15, price = 25000, color = "#C9CCD2" }, -- (prompt 34: silver; gold is for Champion, prompt 31)
}
-- machines = MachineIds it helps; groups = every machine whose main muscle is in these groups
PumpShop.Gear = {
	{ id = "Belt", name = "Lifting Belt", slot = "Waist", style = "Belt", area = "squats and deadlifts",
		machines = { "SquatRack", "Deadlift", "HackSquat", "LegPress", "HipThrust" } },
	{ id = "Wraps", name = "Wrist Wraps", slot = "Wrists", style = "Wraps", area = "pressing",
		machines = { "FlatBench", "InclineBench", "OverheadPress", "Dips", "TricepPushdown" } },
	{ id = "Straps", name = "Lifting Straps", slot = "Hands", style = "Straps", area = "pulling",
		machines = { "Deadlift", "BarbellRow", "PullUpBar", "Shrugs", "BicepCurl", "ReverseFly" } },
	{ id = "Sleeves", name = "Knee Sleeves", slot = "Knees", style = "Sleeves", area = "legs", groups = { "Legs" } },
}

-- The Cosmetics item id of a gear piece at a level ("Belt_Pro").
function PumpShop.GearItemId(gearId: string, levelId: string): string
	return gearId .. "_" .. levelId
end

local LEVEL = {}
for _, level in ipairs(PumpShop.GearLevels) do LEVEL[level.id] = level end
-- The EXP multiplier the worn gear gives on `machine` (1 = none). equipped = cosmetics.equipped ([slot] = item id),
-- mainGroup = the machine's main muscle group id.
function PumpShop.GearMultiplier(equipped, machine, mainGroup: string?): number
	if type(equipped) ~= "table" or not machine then return 1 end
	local total = 1
	for _, gear in ipairs(PumpShop.Gear) do
		local itemId = equipped[gear.slot]
		if type(itemId) == "string" and string.sub(itemId, 1, #gear.id + 1) == gear.id .. "_" then
			local level = LEVEL[string.sub(itemId, #gear.id + 2)]
			local helps = (gear.machines and table.find(gear.machines, machine.id) ~= nil) or (gear.groups and mainGroup ~= nil and table.find(gear.groups, mainGroup) ~= nil)
			if level and helps then total *= 1 + level.bonus end
		end
	end
	return total
end

------------------------------------------------------------------------
-- APPAREL: cosmetic only. kind = "Shorts" / "Top" (body colors, settings.shorts / settings.top) or "Cosmetic"
-- (Config.Cosmetics items: headbands, shakers, gym bags). Try it on before buying.
------------------------------------------------------------------------
PumpShop.Apparel = {
	{ kind = "Shorts", id = "Gold", price = 500 }, { kind = "Shorts", id = "Purple", price = 500 },
	{ kind = "Shorts", id = "Pink", price = 500 }, { kind = "Shorts", id = "Camo", price = 750 },
	{ kind = "Top", id = "TankRed", price = 1000 }, { kind = "Top", id = "TankBlue", price = 1000 },
	{ kind = "Top", id = "TankGold", price = 1500 }, { kind = "Top", id = "TankBlack", price = 1000 },
	{ kind = "Cosmetic", id = "BandRed", price = 400 }, { kind = "Cosmetic", id = "BandGold", price = 600 },
	{ kind = "Cosmetic", id = "ShakerTeal", price = 600 }, { kind = "Cosmetic", id = "ShakerGold", price = 900 },
	{ kind = "Cosmetic", id = "BagBlack", price = 1200 }, { kind = "Cosmetic", id = "BagRed", price = 1200 },
	{ kind = "Cosmetic", id = "BagGold", price = 1500 },
}

------------------------------------------------------------------------
-- DNA LAB
------------------------------------------------------------------------
PumpShop.DnaWeeklyStep = 0.10 -- +10% for each token bought this week (resets every Monday 00:00 UTC)

-- The week number (UTC, weeks start on Monday) for a unix time.
function PumpShop.Week(now: number?): number
	-- (1970-01-01 was a Thursday: +3 days puts the week change on Monday)
	return math.floor(((now or os.time()) / 86400 + 3) / 7)
end

-- The coin price of the next DNA token after `boughtThisWeek` this week.
function PumpShop.DnaPrice(base: number, boughtThisWeek: number?): number
	return round(base * (1 + PumpShop.DnaWeeklyStep) ^ (boughtThisWeek or 0))
end

-- The next DNA token's price for a player's data (data.dnaWeek; another week = back to the base).
function PumpShop.DnaPriceFor(data, base: number): number
	local state = data and data.dnaWeek
	local bought = if type(state) == "table" and state.week == PumpShop.Week() then state.bought or 0 else 0
	return PumpShop.DnaPrice(base, bought)
end

return PumpShop
