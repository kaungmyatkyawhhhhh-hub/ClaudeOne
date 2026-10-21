local H = require("./harness")
local T = H.module("ReplicatedStorage/Shared/Config/Trainers")
print("Trainers")
H.check(#T.List == 8 and #T.Rarities == 8, "eight trainers, eight rarities")
local total = 0
for _, r in T.Rarities do total += r.chance end
H.check(math.abs(total - 100) < 1e-9, "the chances add up to 100% (" .. total .. ")")
for i, t in T.List do
	H.check(t.rarity == T.Rarities[i].id and T.ByRarity[t.rarity] == t, t.id .. " is the " .. T.Rarities[i].id .. " one")
	H.check(t.name and t.perkText and t.look and t.look.skin and t.look.faceTexture and (t.look.pants or t.look.shorts) and next(t.perk) ~= nil, t.id .. " is complete")
end
H.check(T.ById.RookieCoach.perk.gains == 0.05 and T.ById.CardioCoach.perk.coins == 0.10, "Common +5% EXP, Uncommon +10% coins")
H.check(T.ById.MoneyCoach.perk.gains == 0.15 and T.ById.MoneyCoach.perk.maxStamina == 0.10, "Rare +15% EXP +10% max stamina")
H.check(T.ById.PumpCoach.perk.gains == 0.25 and T.ById.PumpCoach.perk.coins == 0.25, "Epic +25% EXP and coins")
H.check(T.ById.AeonCoach.perk.gains == 1.5 and T.ById.AeonCoach.perk.progress == 0.5, "Eternal +150% and +50% progress")
H.check(T.ById.AtlasCoach.look.aura and T.ById.BlazeCoach.look.aura and T.ById.ShadeCoach.look.aura and T.ById.AeonCoach.look.aura, "the rare ones have auras")
H.check(T.RarityById.Secret.hidden == true, "Secret is hidden until owned")

print("Rolls")
-- the boundaries of the odds
H.check(T.Roll(0, 0) == "Common" and T.Roll(0.4999, 0) == "Common" and T.Roll(0.5, 0) == "Uncommon", "0-50% Common, then Uncommon")
H.check(T.Roll(0.9999999, 0) == "Eternal", "the last 0.05% is Eternal")
-- pity: 99 low rolls, the 100th is an Epic
local pity, last = 0, nil
for _ = 1, T.Pity - 1 do last, pity = T.Roll(0.1, pity) end
H.check(last == "Common" and pity == T.Pity - 1, "99 commons in a row: pity 99")
last, pity = T.Roll(0.1, pity)
H.check(last == "Epic" and pity == 0, "the 100th is an Epic and the pity resets")
local _, p2 = T.Roll(0.999, 40)
H.check(p2 == 0, "a natural Epic or better resets the pity too")
-- the odds over many rolls (with pity) are close to the config
math.randomseed(7)
local rng = { NextNumber = function() return math.random() end }
local counts = {}
pity = 0
local N = 400000
for _ = 1, N do
	local r
	r, pity = T.Roll(rng:NextNumber(), pity)
	counts[r] = (counts[r] or 0) + 1
end
for _, r in T.Rarities do
	local share = (counts[r.id] or 0) / N * 100
	local ok = math.abs(share - r.chance) <= math.max(0.35, r.chance * 0.15)
	H.check(ok, string.format("%-9s %.3f%% (config %g%%)", r.id, share, r.chance))
end

print("Price and pacing (minutes of coins at your stage per roll: " .. T.RollMinutes .. ")")
H.check(T.RollPrice(57) >= T.MinPrice and T.RollPrice(328) % 5 == 0, "prices round to 5 and never below the minimum")
-- average minutes of coins until the first of each rarity (or better), with pity, no auto-delete refunds
local runs = 20000
local function avgRollsTo(index)
	local sum = 0
	for _ = 1, runs do
		local p, n = 0, 0
		while true do
			n += 1
			local r
			r, p = T.Roll(rng:NextNumber(), p)
			if T.RarityById[r].index >= index then break end
		end
		sum += n
	end
	return sum / runs
end
for _, spec in { { "Epic", 15, 25 }, { "Legendary", 40, 75 }, { "Mythic", 150, 280 }, { "Secret", 500, 1100 }, { "Eternal", 2000, 4500 } } do
	local rolls = avgRollsTo(T.RarityById[spec[1]].index)
	local minutes = rolls * T.RollMinutes
	H.check(minutes >= spec[2] and minutes <= spec[3], string.format("first %s or better: %.0f rolls, %.0f min (%.1f h)", spec[1], rolls, minutes, minutes / 60))
end

print("Slots")
H.check(T.SlotsFor(false, 0, 0) == 1 and T.SlotsFor(false, 2, 0) == 2 and T.SlotsFor(false, 6, 1) == 3 and T.SlotsFor(true, 6, 1) == 4, "1, 2 at spurt 2, 3 at the first alter, +1 pass")
local list = T.CleanEquipped({ "PumpCoach", "PumpCoach", "RookieCoach@g", "Nope" }, { PumpCoach = 1 }, { RookieCoach = 1 }, 4)
H.check(#list == 2 and list[1] == "PumpCoach" and list[2] == "RookieCoach@g", "only as many copies as you own (duplicates need copies)")
list = T.CleanEquipped({ "PumpCoach", "PumpCoach" }, { PumpCoach = 2 }, {}, 4)
H.check(#list == 2, "two copies can fill two slots")
H.check(#T.CleanEquipped({ "PumpCoach", "RookieCoach" }, { PumpCoach = 1, RookieCoach = 1 }, {}, 1) == 1, "never more than the slots")
H.check(#T.CleanEquipped(nil, nil, nil, 2) == 0, "bad data: nothing")

print("Boosts")
local b = T.Bonus({ "PumpCoach", "RookieCoach@g" })
H.check(math.abs(b.gains - (0.25 + 0.075)) < 1e-9 and math.abs(b.coins - 0.25) < 1e-9, "boosts add up, Golden is 1.5x")
b = T.Bonus({ "AeonCoach@g", "AeonCoach@g", "AeonCoach@g", "AeonCoach@g" })
H.check(b.gains == T.BoostCap and b.progress <= T.BoostCap, "the total is capped at +" .. (T.BoostCap * 100) .. "%")
H.check(T.PerkText(T.ById.PumpCoach, true) == "+38% EXP and coins", "Golden perk text: " .. T.PerkText(T.ById.PumpCoach, true))

print("Old saves")
local m = T.Migrate({ owned = { "RookieCoach", "PumpCoach" }, equipped = { "PumpCoach" } })
H.check(m.owned.RookieCoach == 1 and m.owned.PumpCoach == 1 and m.equipped[1] == "PumpCoach" and m.pity == 0, "a list of hired coaches becomes one of each")
m = T.Migrate({ owned = { RookieCoach = 3 }, golden = { PumpCoach = 1 }, pity = 12 })
H.check(m.owned.RookieCoach == 3 and m.golden.PumpCoach == 1 and m.pity == 12, "a new save stays as it is")

print("Following")
H.check(#T.Cheers >= 3 and T.CheerCooldown > 0 and T.RenderDistance > 0, "cheers, cooldown and render distance set")
H.done()
