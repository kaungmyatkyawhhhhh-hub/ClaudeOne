local H = require("./harness")
local M = H.module("ReplicatedStorage/Shared/Config/Meals")
print("Items")
for _, id in { "ProteinShake", "EnergySmoothie", "ChickenRice", "CoconutWater" } do
	local item = M.ById[id]
	H.check(item ~= nil and item.price > 0 and item.seconds > 0 and next(item.effects) ~= nil, id .. " is valid")
end
H.check(M.ById.ProteinShake.effects.gains == 1.2 and M.ById.ProteinShake.seconds == 300, "Protein Shake: +20% EXP for 5 min")
H.check(M.ById.EnergySmoothie.effects.regen == 1.5, "Energy Smoothie: stamina refills 50% faster")
local cr = M.ById.ChickenRice
H.check(cr.effects.gains == 1.1 and cr.effects.regen == 1.1 and cr.seconds == 600, "Chicken & Rice: +10% EXP and refill for 10 min")
H.check(M.ById.CoconutWater.effects.cardio ~= nil, "Coconut Water: treadmill distance")
print("Shops")
for shopId, shop in M.Shops do
	for _, id in shop.items do H.check(M.ById[id] ~= nil, shopId .. " sells " .. id) end
end
H.check(table.find(M.Shops.CoconutCart.items, "CoconutWater") and not table.find(M.Shops.SmoothieBar.items, "CoconutWater")
	and not table.find(M.Shops.StarterCart.items, "CoconutWater"), "Coconut Water only at the beach")
print("Stacking")
local p = M.ById.ProteinShake
H.check(M.Extend(p, 0) == 300, "a fresh boost runs its full time")
H.check(M.Extend(p, 100) == 400, "buying again adds time")
H.check(M.Extend(p, 10000) == 300 * M.MaxStack, "capped at MaxStack purchases")
H.check(M.CanBuy(p, 0) and M.CanBuy(p, 600) and not M.CanBuy(p, 605) and not M.CanBuy(p, 898), "buy again only when the whole drink fits under the cap")
H.check(M.Clock(272) == "4:32", "clock")
H.done()
