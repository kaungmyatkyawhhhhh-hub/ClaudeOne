-- Boosts in the inventory (owner, prompt 14, 21 Oct): consumables the player owns and uses from the Inventory's Boosts
-- tab, from a Tool in their backpack (EQUIP), or the Protein Shake from the quick button by the stamina bar. No shop for
-- them yet. ItemService runs them; every number to tune is here.
--   id            saved key: data.items[id] = how many you own, data.boostLeft[id] = seconds of the boost still to run
--   effects       multiply with every other boost through BoostService ("Item_<id>"): gains = muscle EXP per rep
--                 (Growth Spurt progress is the muscles' EXP, so "spurt progress" is an EXP boost too), regen = stamina refill
--   seconds       how long one use runs; using it again ADDS this much, up to Boosts.MaxSeconds
--   refill        share of max stamina given right away
--   shake = true  the Protein Shake keeps the old Energy Shake's effect exactly: full stamina + Config/Stamina.Shake
--                 (+50% EXP for 30 s, stacking to 90 s), the chug and the "ShakeDrunk" event (the tutorial waits for it)
-- Boost time counts down only while you're in the game (saved when you leave, like the smoothie bar's).
-- icon / color: placeholders (a Config/UI icon in a colored tile) until the owner's art.
local Boosts = {}

Boosts.MaxSeconds = 60 * 60 -- one boost holds at most 60 min
Boosts.MaxCount = 99        -- most of one item in the inventory
Boosts.UseCooldown = 1      -- seconds between two uses (any item)
Boosts.DrinkSeconds = 1     -- (prompt 28b) a held boost: the drink takes this long, the item counts at its end
Boosts.HotbarSlots = 9      -- a new item type goes in the hotbar by itself only while a slot is free
Boosts.SaveEvery = 5        -- seconds between updates of the saved time left
Boosts.MaxChips = 4         -- active boost timers shown by the stamina bar at once (the rest: "+2")

Boosts.Items = {
	{ id = "Shake", short = "+50% EXP", name = "Protein Shake", shake = true, icon = "cup-soda", color = "#8E5CF0",
		text = "Fills your stamina and gives +50% EXP.", duration = "30 s" },
	{ id = "CoconutWater", short = "+50% STAMINA REGEN", name = "Coconut Water", refill = 0.5, seconds = 2 * 60, effects = { regen = 1.5 }, icon = "heart-pulse", color = "#3F8CFF",
		text = "Refills half your stamina, then stamina refills 50% faster.", duration = "2 min" },
	{ id = "Creatine", short = "+25% EXP", name = "Creatine", seconds = 10 * 60, effects = { gains = 1.25 }, icon = "zap", color = "#E8343C",
		text = "+25% EXP on every rep.", duration = "10 min" },
	{ id = "ProteinPowder", short = "+25% PROGRESS", name = "Protein Powder", seconds = 10 * 60, effects = { gains = 1.25 }, icon = "arrow-big-up", color = "#F0882A",
		text = "+25% Growth Spurt progress.", duration = "10 min" },
	{ id = "Supplements", short = "+10% GAINS", name = "Supplements", seconds = 15 * 60, effects = { gains = 1.1 }, icon = "heart-pulse", color = "#36C26B",
		text = "+10% to all training gains.", duration = "15 min" },
	-- (prompt 19, sold in the PUMP SHOP) reps go 25% faster: the rep animation and the auto-rep pace
	{ id = "PreWorkout", short = "+25% REP SPEED", name = "Pre-Workout", seconds = 5 * 60, effects = { repSpeed = 1.25 }, icon = "timer", color = "#36C2C2",
		text = "+25% rep speed.", duration = "5 min" },
	-- (prompt 31) the PUMP SHOP's specials: stronger, rarer, pricier (all numbers here and in Config/PumpShop)
	{ id = "MassGainer", short = "+50% PROGRESS", name = "Mass Gainer", seconds = 10 * 60, effects = { gains = 1.5 }, icon = "arrow-big-up", color = "#C98A12",
		text = "+50% Growth Spurt and alter progress.", duration = "10 min", special = true },
	{ id = "ElitePreWorkout", short = "+50% REP SPEED", name = "Elite Pre-Workout", seconds = 10 * 60, effects = { repSpeed = 1.5 }, icon = "timer", color = "#AA50FF",
		text = "+50% rep speed.", duration = "10 min", special = true },
	{ id = "WheyIsolate", short = "+50% EXP", name = "Whey Isolate", seconds = 15 * 60, effects = { gains = 1.5 }, icon = "zap", color = "#F5BE28",
		text = "+50% EXP on every rep.", duration = "15 min", special = true },
	{ id = "BcaaRecovery", short = "+100% STAMINA REGEN", name = "BCAA Recovery", seconds = 15 * 60, effects = { regen = 2 }, icon = "heart-pulse", color = "#3CC8B4",
		text = "Stamina refills twice as fast.", duration = "15 min", special = true },
	-- (prompt 60) from the STARTER PACK only (never sold on its own): 2x EXP for 30 minutes when you use it
	{ id = "StarterBoost", short = "2x EXP", name = "2x EXP Boost", seconds = 30 * 60, effects = { gains = 2 }, icon = "zap", color = "#F6C75A",
		text = "Double EXP on every rep.", duration = "30 min", special = true },
}
-- (owner, 22 Oct) item pictures (Downloads\gym_arc_reward_icons, uploaded to the Myanmar Builders Club group): with one,
-- the item shows its picture everywhere instead of the line icon in a coloured tile (Pieces.Icon / Kit.IconTile take a
-- picture's id). "" = not uploaded yet: the line icon stays.
-- (prompt 47, 22 Oct: the owner's new boost icons, Downloads\gym_arc_boost_icons, in the group; one per item id)
Boosts.Art = {
	Shake = "rbxassetid://129050154863447", -- protein_shake.png
	ProteinPowder = "rbxassetid://133862686508046", -- protein_powder.png
	Creatine = "rbxassetid://117668276542516", -- creatine.png
	PreWorkout = "rbxassetid://94468652154061", -- pre_workout.png
	Supplements = "rbxassetid://82069287679166", -- supplements.png
	CoconutWater = "rbxassetid://95025554736760", -- coconut_water.png
	MassGainer = "rbxassetid://137700404645036", -- mass_gainer.png
	ElitePreWorkout = "rbxassetid://107384756746794", -- elite_pre_workout.png
	WheyIsolate = "rbxassetid://116352481754144", -- whey_isolate.png
	BcaaRecovery = "rbxassetid://108996566644383", -- bcaa.png
}
Boosts.ById = {}
for _, item in ipairs(Boosts.Items) do
	Boosts.ById[item.id] = item
	local art = Boosts.Art[item.id]
	if art and art ~= "" then item.icon = art end
end

-- Extra items on login calendar days (Config/Economy.Login), so players meet the new boosts.
Boosts.LoginItems = { [2] = { CoconutWater = 1 }, [5] = { Creatine = 1 } }

-- Seconds left after one more use when `left` seconds were still running.
function Boosts.Extend(item, left: number): number
	return math.min(math.max(left, 0) + (item.seconds or 0), Boosts.MaxSeconds)
end

-- "9:42"
function Boosts.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Boosts
