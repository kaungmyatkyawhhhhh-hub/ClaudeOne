-- Gamepasses and developer products (fair, never forced). Everything paid can also be earned for free.
-- HOW TO TURN ON: create each pass/product on the Roblox website (Creator Hub → your experience → Monetization),
-- then paste its id below. Items with id = nil stay hidden; with no ids at all, the Store button never shows.
-- No purchase prompt ever opens by itself, and the Store button only appears after the tutorial plus 5 minutes.
local Monetization = {}

Monetization.Passes = {
	{ key = "DoubleGains", id = nil, name = "2x Gains", text = "Every rep gives double gains." },
	{ key = "AutoLift", id = nil, name = "Auto Lift", text = "Lifts for you while you're on a machine (toggle it any time)." },
	{ key = "IronLungs", id = nil, name = "Iron Lungs", text = "50% more stamina." },
	{ key = "FastRecovery", id = nil, name = "Fast Recovery", text = "Stamina refills 50% faster." },
	{ key = "ShakeFridge", id = nil, name = "Shake Fridge", text = "A free Energy Shake every 10 minutes you play." },
	{ key = "GeneLock", id = nil, name = "Gene Lock", text = "Rerolling keeps your best muscle group's grade." },
	{ key = "VIP", id = nil, name = "VIP Gym", text = "+10% coins and a VIP tag on your player card." },
}

Monetization.Products = {
	{ key = "DnaToken", id = nil, name = "DNA Token", text = "One genetics reroll." },
	{ key = "ShakePack", id = nil, name = "Shake Pack", text = "5 Energy Shakes." },
	{ key = "ServerBoost", id = nil, name = "Server Boost", text = "2x gains for everyone in the server for 30 minutes. Your name goes on the board." },
}

-- What the passes do (read by MonetizationService).
Monetization.Effects = {
	DoubleGains = 2,
	IronLungsMax = 1.5,      -- x max stamina
	FastRecovery = 1.5,      -- x refill speed
	ShakeFridgeMinutes = 10,
	VIPCoins = 1.1,
	ShakePackSize = 5,
	ServerBoostGains = 2,
	ServerBoostMinutes = 30,
}

-- The Store button waits until the tutorial is done and this much play time in the session.
Monetization.StoreAfterMinutes = 5

Monetization.PassByKey, Monetization.ProductByKey = {}, {}
for _, pass in ipairs(Monetization.Passes) do Monetization.PassByKey[pass.key] = pass end
for _, product in ipairs(Monetization.Products) do Monetization.ProductByKey[product.key] = product end

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
