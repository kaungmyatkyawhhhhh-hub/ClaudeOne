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
Boosts.SaveEvery = 5        -- seconds between updates of the saved time left
Boosts.MaxChips = 4         -- active boost timers shown by the stamina bar at once (the rest: "+2")

Boosts.Items = {
	{ id = "Shake", name = "Protein Shake", shake = true, icon = "cup-soda", color = "#8E5CF0",
		text = "Fills your stamina and gives +50% EXP for 30 s.", duration = "30 s" },
	{ id = "CoconutWater", name = "Coconut Water", refill = 0.5, seconds = 2 * 60, effects = { regen = 1.5 }, icon = "heart-pulse", color = "#3F8CFF",
		text = "Refills half your stamina, then stamina refills 50% faster.", duration = "2 min" },
	{ id = "Creatine", name = "Creatine", seconds = 10 * 60, effects = { gains = 1.25 }, icon = "zap", color = "#E8343C",
		text = "+25% EXP on every rep.", duration = "10 min" },
	{ id = "ProteinPowder", name = "Protein Powder", seconds = 10 * 60, effects = { gains = 1.25 }, icon = "arrow-big-up", color = "#F0882A",
		text = "+25% Growth Spurt progress.", duration = "10 min" },
	{ id = "Supplements", name = "Supplements", seconds = 15 * 60, effects = { gains = 1.1 }, icon = "heart-pulse", color = "#36C26B",
		text = "+10% to all training gains.", duration = "15 min" },
}
Boosts.ById = {}
for _, item in ipairs(Boosts.Items) do Boosts.ById[item.id] = item end

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
