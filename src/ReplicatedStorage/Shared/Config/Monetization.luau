-- Gamepasses and developer products (fair, never forced). Everything paid can also be earned for free.
-- HOW TO TURN ON: create each pass/product on the Roblox website (Creator Hub → your experience → Monetization),
-- then paste its id below. Items with id = nil stay hidden; with no ids at all, the Store button never shows.
-- No purchase prompt ever opens by itself, and the Store button only appears after the tutorial plus 5 minutes.
-- Store (owner, 14 Oct): each item has its Store `tab` (Passes / Coins / Boosts), its shop art (`art`, Config/UI.ShopIcons)
-- and a fallback `price` (Robux) shown until Roblox's real price has loaded (or if it can't load). An id of 0 is a
-- placeholder: hidden, with a warning. `store = false` = never in the Store (sold somewhere else). `hidden` = has an id
-- but isn't sold yet, with the reason.
local Monetization = {}
local Products = require(script.Parent.Products)
local function productId(id: number): number? return if id ~= 0 then id else nil end

Monetization.Passes = {
	{ key = "DoubleGains", id = 2032508303, name = "2x EXP", text = "Double all training EXP forever.", price = 249, art = "pass_2x_exp" },
	{ key = "DoubleCoins", id = 2032286316, name = "2x Coins", text = "Double all coins you earn forever.", price = 149, art = "pass_2x_coins" },
	{ key = "VIP", id = 2032988308, name = "VIP", text = "+10% coins, a VIP tag and the Royal aura.", price = 299, art = "pass_vip" },
	{ key = "AuraPack", id = 2033954299, name = "Aura Pack", text = "Unlocks 5 auras: Inferno, Blood Moon, Void, Neon and Galaxy.", price = 199, art = "pass_aura_pack" },
	{ key = "AutoLift", id = 2033558291, name = "Auto Rep", text = "Lifts for you while you're on a machine (toggle it any time).", price = 249, art = "pass_auto_rep" },
	{ key = "ExtraTrainer", id = 2032496303, -- (owner, 13 Oct: the "2nd slot" pass)
		name = "Extra Trainer", text = "A second personal trainer follows you and their perks stack.", price = 99, art = "pass_extra_trainer" },
	-- (no ids yet: not for sale)
	{ key = "IronLungs", id = nil, name = "Iron Lungs", text = "50% more stamina." },
	{ key = "FastRecovery", id = nil, name = "Fast Recovery", text = "Stamina refills 50% faster." },
	{ key = "ShakeFridge", id = nil, name = "Shake Fridge", text = "A free Energy Shake every 10 minutes you play." },
	{ key = "GeneLock", id = nil, name = "Gene Lock", text = "Rerolling keeps your best muscle group's grade." },
}

Monetization.Products = {
	-- (prompt 61) the coin packs grow with the player: coinMinutes of coins at their stage (Config/Economy.Minutes), never less
	-- than `coins` (the old fixed amounts). The server works it out at purchase time; the Store shows that exact number.
	{ key = "CoinsSmall", id = 3718306241, tab = "Coins", name = "Small Coins", text = "A pile of coins. The bigger you are, the more you get.",
		coins = 1000, coinMinutes = 20, price = 25, art = "product_coins_small" },
	{ key = "CoinsMedium", id = 3718306326, tab = "Coins", name = "Medium Coins", text = "A big pile of coins. The bigger you are, the more you get.",
		coins = 5000, coinMinutes = 120, price = 99, art = "product_coins_medium" },
	{ key = "CoinsLarge", id = 3718306360, tab = "Coins", name = "Large Coins", text = "A huge pile of coins. The bigger you are, the more you get.",
		coins = 15000, coinMinutes = 360, price = 249, art = "product_coins_large" },
	{ key = "ShakePack", id = 3718306390, tab = "Boosts", name = "Shake Bundle", text = "3 Energy Shakes.", price = 49, art = "product_shake_bundle" },
	-- (owner, 14 Oct: was "Stamina Refill", same id, renamed in the Creator Hub; MonetizationService / PlayerData)
	{ key = "EndlessStamina", id = 3718306417, tab = "Boosts", name = "Endless Stamina", text = "15 min of stamina that never runs out. Stacks up to 60 min.",
		price = 49, art = "product_endless_stamina" }, -- (prompt 12: was 15 here while Roblox sells it for 49; the Store showed 15 until Roblox's info came)
	{ key = "DnaToken", id = productId(Products.DNAToken), tab = "Boosts", name = "DNA Token", text = "One genetics reroll.", price = 99, art = "product_dna_token" },
	-- (bought from the Quests window only, after picking the quest: store = false keeps it out of the Store)
	{ key = "QuestReroll", id = productId(Products.QuestReroll), name = "Quest Reroll", text = "Swap one daily quest for a new one.", store = false, price = 19 },
	{ key = "ServerBoost", id = nil, tab = "Boosts", name = "Server Boost", text = "2x gains for everyone in the server for 30 minutes. Your name goes on the board." },
	-- (prompt 60) DNA tokens as a pack of 3 (cheaper per token than 3 singles); shown next to the single everywhere tokens are sold
	{ key = "DnaTokenPack", id = productId(0), tab = "Boosts", name = "DNA Token x3", text = "Three genetics rerolls.", dnaTokens = 3, price = 249, art = "product_dna_token" },
	-- (prompt 60) STARTER PACK: once per player (data.starterPack); contents in Monetization.StarterPack
	{ key = "StarterPack", id = productId(0), tab = "Boosts", name = "Starter Pack", text = "Coins, 3 Protein Shakes, a DNA Token, 30 min 2x EXP and the STARTER title.",
		price = 49, art = "product_shake_bundle", once = true },
	-- (prompt 57) the PUMP SHOP's specials, bought there (store = false): x1 and x5 of each (consumable, into the inventory)
	{ key = "Supp_MassGainer_1", id = productId(0), store = false, name = "Mass Gainer", supplement = "MassGainer", count = 1, price = 25 },
	{ key = "Supp_MassGainer_5", id = productId(0), store = false, name = "Mass Gainer x5", supplement = "MassGainer", count = 5, price = 99 },
	{ key = "Supp_ElitePreWorkout_1", id = productId(0), store = false, name = "Elite Pre-Workout", supplement = "ElitePreWorkout", count = 1, price = 25 },
	{ key = "Supp_ElitePreWorkout_5", id = productId(0), store = false, name = "Elite Pre-Workout x5", supplement = "ElitePreWorkout", count = 5, price = 99 },
	{ key = "Supp_WheyIsolate_1", id = productId(0), store = false, name = "Whey Isolate", supplement = "WheyIsolate", count = 1, price = 25 },
	{ key = "Supp_WheyIsolate_5", id = productId(0), store = false, name = "Whey Isolate x5", supplement = "WheyIsolate", count = 5, price = 99 },
	{ key = "Supp_BcaaRecovery_1", id = productId(0), store = false, name = "BCAA Recovery", supplement = "BcaaRecovery", count = 1, price = 25 },
	{ key = "Supp_BcaaRecovery_5", id = productId(0), store = false, name = "BCAA Recovery x5", supplement = "BcaaRecovery", count = 5, price = 99 },
}

-- What the passes do (read by MonetizationService).
Monetization.Effects = {
	DoubleGains = 2,
	DoubleCoins = 2,         -- x coins (2x Coins pass)
	IronLungsMax = 1.5,      -- x max stamina
	FastRecovery = 1.5,      -- x refill speed
	ShakeFridgeMinutes = 10,
	VIPCoins = 1.1,
	ShakePackSize = 3,       -- the Shake Bundle (its Roblox listing says 3)
	ServerBoostGains = 2,
	ServerBoostMinutes = 30,
	EndlessStaminaMinutes = 15,    -- one Endless Stamina purchase (no stamina drain; counts down only while in the game)
	EndlessStaminaMaxMinutes = 60, -- buying again adds time, up to this
}

-- (prompt 60) STARTER PACK: bought once per player (data.starterPack; hidden after). All guaranteed, nothing random.
-- coins = CoinMinutes of coins at the buyer's stage (Config/Economy.Minutes), at least CoinsMin and at most CoinsMax (owner,
-- 23 Oct). The 2x EXP is an inventory item (Config/Boosts "StarterBoost", 30 min when used). Offered once after the first
-- Growth Spurt's celebration (not in the tutorial or the first FirstMinutes), then pinned in the Store until bought.
-- Bought again somehow: its value in coins instead (ValueCoins), no second title.
Monetization.StarterPack = {
	CoinMinutes = 60, CoinsMin = 5000, CoinsMax = 10000,
	Shakes = 3, DnaTokens = 1, BoostItem = "StarterBoost", Title = "Starter",
	FirstMinutes = 5,
}
-- (prompt 61) A coin pack's coins for a player with `spurts` Growth Spurts (the server pays this, the Store shows it).
function Monetization.PackCoins(product, spurts: number?): number
	if not product or not product.coins then return 0 end
	if not product.coinMinutes then return product.coins end
	local Economy = require(script.Parent.Economy)
	return math.max(product.coins, Economy.Minutes(spurts, product.coinMinutes))
end

-- The STARTER PACK's coins for a player with `spurts` Growth Spurts (the server pays this, the Store shows it).
function Monetization.StarterCoins(spurts: number?): number
	local pack = Monetization.StarterPack
	local Economy = require(script.Parent.Economy)
	return math.clamp(Economy.Minutes(spurts, pack.CoinMinutes), pack.CoinsMin, pack.CoinsMax)
end

-- The Store's hero tile shows a small BEST SELLER tag on this item (owner's final kit, mockup 04_store).
Monetization.BestSeller = "AutoLift"
-- (prompt 61) the Store's hero card on PASSES features the first of these you don't own yet (most popular first; edit freely)
Monetization.PopularPasses = { "AutoLift", "DoubleGains", "VIP", "DoubleCoins", "AuraPack", "ExtraTrainer" }

Monetization.PassByKey, Monetization.ProductByKey = {}, {}
for _, pass in ipairs(Monetization.Passes) do Monetization.PassByKey[pass.key] = pass end
for _, product in ipairs(Monetization.Products) do Monetization.ProductByKey[product.key] = product end

-- Is this item for sale in the Store? (a real id, not hidden, not sold elsewhere)
function Monetization.ForSale(item): boolean
	return item.id ~= nil and item.id ~= 0 and not item.hidden and item.store ~= false
end

-- True when at least one item has an id (otherwise the Store stays hidden).
function Monetization.AnyConfigured()
	for _, list in ipairs({ Monetization.Passes, Monetization.Products }) do
		for _, item in ipairs(list) do
			if item.id then return true end
		end
	end
	return false
end

return Monetization
