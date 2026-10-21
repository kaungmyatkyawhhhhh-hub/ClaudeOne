-- (prompt 12) The Robux prices the Store got from Roblox (StoreClient fills it when the info arrives); the offer cards
-- (OfferClient) read it, so a card never shows a different price than the Store. Until Roblox answers: Config.Monetization's.
local ShopPrices = {}

local prices = {} -- [item key] = Robux

function ShopPrices.Set(key: string, price: any)
	if type(price) == "number" then prices[key] = price end
end

function ShopPrices.Get(item): number?
	return prices[item.key] or item.price
end

return ShopPrices
