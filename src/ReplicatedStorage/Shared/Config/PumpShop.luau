-- (prompt 31, owner 21 Oct: three shops, each sells its own things; the tabs are always called SUPPLEMENTS / GEAR, plus
-- ALTERS or DNA LAB) PumpShop.Shops below:
--   Coach    COACH DEX at his counter in the Starter Gym (the main shop): normal supplements (+ Shake Bundle and DNA tokens
--            for Robux, prompts 57 / 60), BASIC / PRO belt and wraps (prompt 59), ALTERS
--   Pump     the PUMP SHOP in town (specials only): special supplements (Robux, prompt 57), DNA LAB
--   Coconut  the COCONUT STAND at the beach gym: Coconut Water only (x1 / x5)
-- Apparel is off sale (players keep what they own; PumpShop.Apparel still defines those items).
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

-- (26 Oct: re-measured with tests/pacing coins after the Growth Spurt goals were lowered; was 57/110/152/200/220/222/328)
PumpShop.CoinsPerMinute = { [0] = 55, [1] = 84, [2] = 119, [3] = 179, [4] = 255, [5] = 304, [6] = 328 } -- [Growth Spurts]

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
	{ id = "Style", name = "Style", icon = "sparkles" }, -- (prompt 61: name tag / title / aura / alter colours, Config/Style)
	{ id = "DnaLab", name = "DNA Lab", icon = "sparkles" },
	{ id = "Alters", name = "Alters", icon = "flame", atMax = true }, -- (prompt 21: at 7'0"; Body Alters are never bought)
}
PumpShop.SectionById = {}
for _, section in ipairs(PumpShop.Sections) do PumpShop.SectionById[section.id] = section end

-- (prompt 31) the three shops: their title, tabs, the supplements and gear levels they sell, and how many at once
-- (prompt 57) robux = Robux products (Config.Monetization keys) shown after a shop's supplements / on its DNA LAB tab.
-- (prompt 59) all gear is at Coach Dex (BASIC / PRO); the PUMP SHOP has no GEAR tab.
PumpShop.Shops = {
	Coach = { title = "Coach Dex", tabs = { "Supplements", "Gear", "Alters" },
		supplements = { "Shake", "Creatine", "ProteinPowder", "Supplements", "PreWorkout" }, gear = { "Basic", "Pro" },
		robux = { "ShakePack", "DnaToken", "DnaTokenPack" } },
	Pump = { title = "Pump Shop", tabs = { "Supplements", "Style", "DnaLab" }, -- (prompt 61: STYLE)
		supplements = { "MassGainer", "ElitePreWorkout", "WheyIsolate", "BcaaRecovery" }, gear = {},
		robuxDna = { "DnaToken", "DnaTokenPack" } },
	Coconut = { title = "Coconut Stand", tabs = { "Supplements" }, supplements = { "CoconutWater" }, gear = {}, quantities = { 1, 5 } },
}
-- (prompt 57) the PUMP SHOP's specials cost Robux, not coins: Config.Monetization products "Supp_<id>_1" / "Supp_<id>_5"
-- (x1 / x5). Their coin price below isn't sold any more (PumpShopService refuses it).
PumpShop.RobuxSupplements = { MassGainer = true, ElitePreWorkout = true, WheyIsolate = true, BcaaRecovery = true }
PumpShop.CoachTeleportCooldown = 10 -- seconds between two uses of the Shop window's "Coach Dex" link

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
	-- (prompt 31) the PUMP SHOP's specials
	{ id = "MassGainer", minutes = 14 },
	{ id = "ElitePreWorkout", minutes = 12 },
	{ id = "WheyIsolate", minutes = 16 },
	{ id = "BcaaRecovery", minutes = 12 },
}
PumpShop.Quantities = { 1, 5, 10 }

local function round(n: number): number
	if n >= 1000 then return math.floor(n / 50 + 0.5) * 50 end
	return math.max(5, math.floor(n / 5 + 0.5) * 5)
end
PumpShop.Round = round -- (prompt 61: Config/Economy.Minutes rounds the same way)

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
-- GEAR (prompt 59, owner 23 Oct: "too many gear pieces"): only TWO items, the LIFTING BELT (lower body: legs, back, core)
-- and the WRIST WRAPS (upper body: chest, shoulders, arms). Each has levels; only the best level you own counts (no
-- stacking, no slots to manage: bought = worn). BASIC and PRO are sold by Coach Dex (coins); ELITE and CHAMPION are off
-- sale for now (owners keep theirs: they still work and show in the Inventory). bonus = extra EXP on that half of the body.
-- color = the level's colour on the body and its tiles (prompt 57: Basic brown leather, Pro black + silver, Elite purple +
-- silver, Champion gold, like the pictures).
------------------------------------------------------------------------
PumpShop.GearLevels = {
	{ id = "Basic", name = "Basic", bonus = 0.05, price = 750, color = "#7A4E2C" },
	{ id = "Pro", name = "Pro", bonus = 0.10, price = 4000, color = "#2B2B30" },
	{ id = "Elite", name = "Elite", bonus = 0.15, price = 25000, color = "#8E44E0", offSale = true },
	{ id = "Champion", name = "Champion", bonus = 0.20, price = 150000, color = "#F2C14E", offSale = true },
}
-- half = what it says on the tiles; groups = the muscle groups it helps (a machine counts by its main muscle's group)
PumpShop.Gear = {
	{ id = "Belt", name = "Lifting Belt", short = "Belt", slot = "Waist", style = "Belt", half = "Lower body", groups = { "Legs", "Back", "Core" } },
	{ id = "Wraps", name = "Wrist Wraps", short = "Wraps", slot = "Wrists", style = "Wraps", half = "Upper body", groups = { "Chest", "Shoulders", "Arms" } },
}
-- (prompt 59) taken out of the game: owners got the matching piece at their level, or their coins back, once
-- (PumpShopService, flag cosmetics.gear59). The old ids stay valid in saves until then.
--   { id = "Straps", name = "Lifting Straps", slot = "Hands", style = "Straps" }  -> Wrist Wraps
--   { id = "Sleeves", name = "Knee Sleeves", slot = "Knees", style = "Sleeves" }  -> Lifting Belt
PumpShop.RemovedGear = {
	{ id = "Straps", slot = "Hands", into = "Wraps" },
	{ id = "Sleeves", slot = "Knees", into = "Belt" },
}
-- the pictures (Downloads\gym_arc_gear_icons, uploaded 23 Oct)
PumpShop.GearIcons = {
	Belt_Basic = "rbxassetid://137957055337154", Belt_Pro = "rbxassetid://100507399379128",
	Belt_Elite = "rbxassetid://126157947517117", Belt_Champion = "rbxassetid://113017264592588",
	Wraps_Basic = "rbxassetid://111378028413393", Wraps_Pro = "rbxassetid://84347399168698",
	Wraps_Elite = "rbxassetid://103576228159688", Wraps_Champion = "rbxassetid://84896815397095",
}

-- The Cosmetics item id of a gear piece at a level ("Belt_Pro").
function PumpShop.GearItemId(gearId: string, levelId: string): string
	return gearId .. "_" .. levelId
end

local LEVEL = {}
for index, level in ipairs(PumpShop.GearLevels) do
	LEVEL[level.id] = level
	level.index = index
end
PumpShop.GearLevelById = LEVEL
PumpShop.GearById = {}
for _, gear in ipairs(PumpShop.Gear) do PumpShop.GearById[gear.id] = gear end

-- The best level of a gear piece in `owned` (cosmetics.owned), or nil.
function PumpShop.GearBest(owned, gearId: string)
	if type(owned) ~= "table" then return nil end
	local best = nil
	for _, level in ipairs(PumpShop.GearLevels) do
		if owned[PumpShop.GearItemId(gearId, level.id)] then best = level end
	end
	return best
end

-- The tile text for a level: "+10% LOWER BODY".
function PumpShop.GearBoostText(gear, level): string
	return "+" .. math.floor(level.bonus * 100 + 0.5) .. "% " .. string.upper(gear.half)
end

-- The EXP multiplier gear gives on `machine` (1 = none): the best level OWNED of each piece (worn or not; prompt 59),
-- when the machine's main muscle group (mainGroup) is in that piece's half of the body. cosmetics = data.cosmetics.
function PumpShop.GearMultiplier(cosmetics, machine, mainGroup: string?): number
	if type(cosmetics) ~= "table" or not machine or not mainGroup then return 1 end
	local total = 1
	for _, gear in ipairs(PumpShop.Gear) do
		local level = PumpShop.GearBest(cosmetics.owned, gear.id)
		if level and table.find(gear.groups, mainGroup) then total *= 1 + level.bonus end
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
