local H = require("./harness")
local T = H.module("ReplicatedStorage/Shared/Config/Trainers")
print("Trainers")
H.check(#T.List == 8 and #T.Rarities == 8, "eight trainers, eight rarities")
local total = 0
for _, r in T.Rarities do total += r.chance end
H.check(math.abs(total - 100) < 1e-9, "the chances add up to 100% (" .. total .. ")")
for i, t in T.List do
	H.check(t.rarity == T.Rarities[i].id and T.ByRarity[t.rarity] == t, t.id .. " is the " .. T.Rarities[i].id .. " one")
	H.check(t.name and t.perkText and t.look and t.look.skin and (t.look.faceTexture or table.find(t.look.extras, "deephood")) and t.look.outfit and t.look.outfit.pants and next(t.perk) ~= nil, t.id .. " is complete")
end
-- (prompt 34) outfits: images on the muscle pieces (never a classic Shirt / Pants), shorts or long legs, real gear meshes
for _, t in T.List do
	local o = t.look.outfit
	H.check(t.look.shirt == nil and t.look.pants == nil and (o.legs == "shorts" or o.legs == "long")
		and (o.shirt == nil or o.sleeves == "none" or o.sleeves == "short" or o.sleeves == "long"), t.id .. " wears an outfit, no classic clothing")
	for _, kind in { "belt", "bigbelt", "wraps", "kneesleeves", "tiedjacket", "shorts", "whistle", "cuffs" } do
		H.check(not table.find(t.look.extras or {}, kind), t.id .. " has no part-built " .. kind)
	end
end
for i = 1, 4 do
	local gear = T.List[i].look.gear or {}
	local whistle = false
	for _, g in gear do whistle = whistle or g.kind == "Whistle" end
	H.check(whistle, T.List[i].id .. " wears a whistle")
end
-- (owner, prompt 27c: the BASE LV 1 boosts by rarity 5, 8, 12, 20, 35, 50, 65, 75%; a max LIMITLESS is x2.2)
local base = { 0.05, 0.08, 0.12, 0.20, 0.35, 0.50, 0.65, 0.75 }
for i, trainer in ipairs(T.List) do
	H.check(math.abs((trainer.perk.gains or trainer.perk.coins) - base[i]) < 1e-9, string.format("%s (%s) BASE +%d%%", trainer.name, trainer.rarity, base[i] * 100))
end
H.check(T.ById.CardioCoach.perk.staminaRegen == 0.12 and math.abs(T.Bonus({ { id = "CardioCoach", s = 1, l = 1 } }).staminaRegen - 0.12) < 1e-9, "Uncommon +12% stamina regen (owner, prompt 25)")
H.check(T.ById.AeonCoach.perk.progress == 0.25, "Eternal +25% progress")
for _, trainer in ipairs(T.List) do
	H.check(T.PerkText(trainer, { id = trainer.id, s = 1, l = 1 }) ~= "" and trainer.perkText:find(tostring(math.floor(trainer.perk[next(trainer.perk)] * 100 + 0.5)) .. "%", 1, true) ~= nil,
		trainer.name .. ": perkText matches the perk")
end
H.check(T.ById.AtlasCoach.look.aura and T.ById.BlazeCoach.look.aura and T.ById.ShadeCoach.look.aura and T.ById.AeonCoach.look.aura, "the rare ones have auras")
H.check(T.RarityById.Secret.hidden == true, "Secret is hidden until owned")
-- (prompt 25) the new 5-8: each taller than the one below, an idle, a line and a reveal pose
H.check(T.ById.AtlasCoach.name == "Duke Ironside" and T.ById.BlazeCoach.name == "Volta" and T.ById.ShadeCoach.name == "The Shadow" and T.ById.AeonCoach.name == "Atlas", "5-8: Duke Ironside, Volta, The Shadow, Atlas")
for i = 2, #T.List do
	H.check(T.List[i].heightInches > T.List[i - 1].heightInches and T.List[i].heightInches <= T.MaxHeightInches, T.List[i].id .. " is taller than the one below (" .. T.List[i].heightInches .. " in)")
	H.check(T.List[i].idle ~= nil and (T.List[i].line ~= nil) and T.List[i].pose ~= nil, T.List[i].id .. " has an idle, a line and a pose")
end
H.check(T.List[8].heightInches == 90 and T.List[7].heightInches == 86, "The Shadow 7'2\", Atlas 7'6\"")
H.check(T.Materials[T.ById.AeonCoach.look.marble.variant] ~= nil, "Atlas's marble material has its maps")

print("Rolls")
-- the boundaries of the odds
H.check(T.Roll(0, 0) == "Common" and T.Roll(0.5021, 0) == "Common" and T.Roll(0.50216, 0) == "Uncommon", "0-50.215% Common, then Uncommon")
H.check(T.Roll(0.99997, 0) == "Eternal" and T.Roll(0.9996, 0) == "Secret", "the last 0.035% is Eternal")
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
-- average minutes of coins until the first of each rarity (or better), with pity, no auto-delete refunds (owner, prompt 25:
-- Mythic ~3-4 h, Secret ~15 h)
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
for _, spec in { { "Epic", 15, 25 }, { "Legendary", 40, 75 }, { "Mythic", 180, 240 }, { "Secret", 780, 1080 }, { "Eternal", 3600, 5400 } } do
	local rolls = avgRollsTo(T.RarityById[spec[1]].index)
	local minutes = rolls * T.RollMinutes
	H.check(minutes >= spec[2] and minutes <= spec[3], string.format("first %s or better: %.0f rolls, %.0f min (%.1f h)", spec[1], rolls, minutes, minutes / 60))
end

print("Slots")
H.check(T.SlotsFor(false, 0, 0) == 1 and T.SlotsFor(false, 2, 0) == 2 and T.SlotsFor(false, 6, 1) == 3 and T.SlotsFor(true, 6, 1) == 4, "1, 2 at spurt 2, 3 at the first alter, +1 pass")
local st = T.Migrate({ copies = { { u = 1, id = "PumpCoach", s = 1, l = 1, x = 0 }, { u = 2, id = "RookieCoach", s = 2, l = 5, x = 0 } },
	equipped = { 1, 1, 2, 99 } })
local uids = T.CleanEquipped(st, 4)
H.check(#uids == 2 and uids[1] == 1 and uids[2] == 2, "equipped copies: each once, only ones you have")
H.check(#T.CleanEquipped(st, 1) == 1, "never more than the slots")
H.check(#T.CleanEquipped(T.Migrate(nil), 2) == 0, "bad data: nothing")

print("Boosts (prompt 33: stage x level; prompt 27c: LIMITLESS x2, LV 20 +10%)")
local b = T.Bonus({ { id = "PumpCoach", s = 1, l = 1 }, { id = "RookieCoach", s = 2, l = 20 } })
H.check(math.abs(b.gains - (0.20 * 1 + 0.05 * 1.25 * 1.1)) < 1e-9, "boosts add up: BASE LV 1 = his boost, x1.25 at IRON-BORN, +10% at LV 20")
H.check(T.Stages[2].mult == 1.25 and T.Stages[3].mult == 1.5 and T.Stages[4].mult == 1.75, "stages spread evenly up to x2")
for _, trainer in ipairs(T.List) do
	local top = 0
	for _, amount in pairs(trainer.perk) do top = math.max(top, amount * T.CopyMultiplier({ id = trainer.id, s = 5, l = 20 })) end
	H.check(top <= 1.65 + 1e-9, string.format("%s at LIMITLESS LV 20: +%d%% (never past +165%%)", trainer.name, math.floor(top * 100 + 0.5)))
end
local atlas = T.CopyMultiplier({ id = "AeonCoach", s = 5, l = 20 }) * T.ById.AeonCoach.perk.gains
H.check(atlas >= 1.5 and atlas <= 1.65 + 1e-9, "one max LIMITLESS Atlas is about +150-165%")
b = T.Bonus({ { id = "AeonCoach", s = 5, l = 20 }, { id = "AeonCoach", s = 5, l = 20 }, { id = "AeonCoach", s = 5, l = 20 }, { id = "AeonCoach", s = 5, l = 20 } })
H.check(b.gains == T.BoostCap and b.progress <= T.BoostCap, "the total is capped at +" .. (T.BoostCap * 100) .. "%")
local lines = T.TotalLines({ { id = "AeonCoach", s = 5, l = 20 }, { id = "AeonCoach", s = 5, l = 20 }, { id = "AeonCoach", s = 5, l = 20 }, { id = "AeonCoach", s = 5, l = 20 } })
H.check(lines[1].pct == 400 and lines[1].capped and lines[#lines].kind == "progress", "the shown total: capped at +400%, biggest first")
H.check(T.PerkText(T.ById.PumpCoach, { id = "PumpCoach", s = 2, l = 10 }) == "+26% EXP, +26% coins", "perk text: " .. T.PerkText(T.ById.PumpCoach, { id = "PumpCoach", s = 2, l = 10 }))
H.check(T.Stages[5].mult == 2 and #T.Stages == 5 and T.EvolveCount == 3, "5 stages x1 .. x2, 3 to evolve")
local m = T.Migrate({ copies = { { u = 1, id = "PumpCoach", s = 1, l = 1 } }, freeRolls = 1, rebalance = 1 })
H.check(m.freeRolls == 1 and m.rebalance == 1 and T.Migrate(nil).rebalance == 0 and T.Migrate(nil).freeRolls == 0, "free rolls and the rebalance flag are kept")
H.check(T.ParseEntry("PumpCoach@3") == "PumpCoach" and select(2, T.ParseEntry("PumpCoach@3")) == 3 and select(2, T.ParseEntry("PumpCoach@g")) == 2
	and select(2, T.ParseEntry("PumpCoach")) == 1 and T.ParseEntry("Nope") == nil and T.Entry("PumpCoach", 1) == "PumpCoach" and T.Entry("PumpCoach", 4) == "PumpCoach@4",
	"entries: PumpCoach@stage (old @g = IRON-BORN)")

print("Evolving")
local e = T.Migrate({ copies = { { u = 1, id = "RookieCoach", s = 1, l = 3 }, { u = 2, id = "RookieCoach", s = 1, l = 9 }, { u = 3, id = "RookieCoach", s = 1, l = 1 },
	{ u = 4, id = "RookieCoach", s = 2, l = 1 }, { u = 5, id = "PumpCoach", s = 1, l = 1 } }, equipped = { 3 } })
local set = T.EvolveSet(e, T.CopyByUid(e)[3])
H.check(#set == 3 and set[1].u == 3 and set[2].u == 2 and set[3].u == 1, "the set: the picked copy, then the best others at the same stage")
H.check(#T.EvolveSet(e, T.CopyByUid(e)[5]) == 1 and #T.EvolveSet(e, T.CopyByUid(e)[4]) == 1, "not enough copies: no set")

print("Levels")
local total, per = 0, 0
for level = 1, T.MaxLevel - 1 do total += T.LevelXp(level, 1) end
-- (a typical BASE player lifts around x3-x4 gains at 1.05 s a rep)
local minutes = total / T.RepXp(3.5) * 1.05 / 60
H.check(minutes >= 18 and minutes <= 32, string.format("Lv 1 -> 20 at BASE in about 20-30 min of reps (%.1f)", minutes))
H.check(T.LevelXp(5, 3) > T.LevelXp(5, 1), "higher stages level a bit slower")

print("Old saves")
local m = T.Migrate({ owned = { "RookieCoach", "PumpCoach" }, equipped = { "PumpCoach" } })
H.check(#m.copies == 2 and T.CopyByUid(m)[m.equipped[1]].id == "PumpCoach" and m.pity == 0, "a list of hired coaches becomes one of each")
m = T.Migrate({ owned = { RookieCoach = 3 }, golden = { PumpCoach = 1 }, equipped = { "PumpCoach@g", "RookieCoach" }, pity = 12, copies = {} })
local golden = T.CopyByUid(m)[m.equipped[1]]
H.check(#m.copies == 4 and golden.id == "PumpCoach" and golden.s == 2 and m.discovered.IronBorn and m.pity == 12,
	"counts become copies, a Golden becomes IRON-BORN (even with an empty copies list from the template)")
m = T.Migrate({ copies = { { u = 7, id = "PumpCoach", s = 9, l = 99, x = -3 } } })
H.check(m.copies[1].s == 5 and m.copies[1].l == T.MaxLevel and m.copies[1].x == 0 and m.nextUid == 8, "bad numbers clamped, the next uid after the highest")

print("Following")
H.check(#T.Cheers >= 3 and T.CheerCooldown > 0 and T.RenderDistance > 0, "cheers, cooldown and render distance set")
H.done()
