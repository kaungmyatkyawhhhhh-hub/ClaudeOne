local H = require("./harness")
local M = H.module("ReplicatedStorage/Shared/Config/Muscles")
local LB = H.module("ReplicatedStorage/Shared/Config/LookBalance")
local Bulge = H.module("ReplicatedStorage/Shared/Config/MuscleBulge")

print("Look balance cap (inside each group, in studs)")
local function all(value)
	local raw = {}
	for _, muscle in ipairs(M.List) do raw[muscle.id] = value end
	return raw
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- level 0 and a balanced body are never capped (whatever each muscle's natural size)
local shown, info = LB.Apply(all(0))
local ok = true
for _, muscle in ipairs(M.List) do ok = ok and shown[muscle.id] == 0 and not info[muscle.id].capped end
H.check(ok, "level 0: every muscle flat, nothing capped")
for _, level in ipairs({ 0.3, 1, 1.6 }) do
	shown, info = LB.Apply(all(level))
	ok = true
	for _, muscle in ipairs(M.List) do ok = ok and near(shown[muscle.id], level) and not info[muscle.id].capped end
	H.check(ok, "a balanced body at look " .. level .. " looks exactly as trained (Lats are not held by Lower Back)")
end

-- only Upper Chest maxed: held at Mid Chest (0) + 0.15 studs, the hint names Mid Chest
local upper = all(0)
upper.UpperChest = 1
shown, info = LB.Apply(upper)
local studs = LB.Studs("UpperChest", shown.UpperChest)
H.check(studs > 0.15 - 1e-6 and studs < 0.15 + LB.Smooth * Bulge.UpperChest + 1e-6, "only Upper Chest maxed: it sticks out about Mid Chest + 0.15 studs")
H.check(info.UpperChest.capped and info.UpperChest.rule.name == "Mid Chest", "it shows as capped by Mid Chest")
H.check(not info.MidChest.capped and shown.MidChest == 0, "Mid Chest stays as trained")

-- both chest muscles maxed: no cap; other groups don't matter (Back untrained)
local chest = all(0)
chest.UpperChest, chest.MidChest = 1, 1
shown, info = LB.Apply(chest)
H.check(near(shown.UpperChest, 1) and near(shown.MidChest, 1) and not info.UpperChest.capped, "both chest muscles maxed: the chest looks full, Back doesn't hold it")

-- only Biceps maxed: held by its smallest groupmate (Triceps / Forearms at 0) + 0.15 studs
local biceps = all(0)
biceps.Biceps = 1
shown, info = LB.Apply(biceps)
H.check(near(LB.Studs("Biceps", shown.Biceps), 0.15, LB.Smooth * Bulge.Biceps) and info.Biceps.capped, "only Biceps maxed: held at its smallest groupmate + 0.15 studs")

-- big muscles: the ratio rule (x1.5) takes over once the groupmate is big
local delts = all(0)
delts.FrontDelts, delts.SideDelts, delts.RearDelts = 1.6, 0.9, 0.9
shown = LB.Apply(delts)
local mate = math.min(LB.Studs("SideDelts", 0.9), LB.Studs("RearDelts", 0.9))
H.check(near(LB.Studs("FrontDelts", shown.FrontDelts), math.max(mate + 0.15, mate * 1.5), LB.Smooth * Bulge.FrontDelts + 1e-6), "Front Delts far ahead: held at max(groupmate + 0.15, groupmate x 1.5) studs")

-- as Mid Chest grows, Upper Chest's held look rises smoothly (never jumps, never drops)
local last, smooth = LB.Apply(upper).UpperChest, true
for step = 1, 40 do
	local raw = table.clone(upper)
	raw.MidChest = step / 40
	shown = LB.Apply(raw)
	if shown.UpperChest < last - 1e-9 or shown.UpperChest - last > 0.08 then smooth = false end
	last = shown.UpperChest
end
H.check(smooth and near(last, 1), "training Mid Chest lifts Upper Chest smoothly to its full look")

-- never above the trained look, and the soft cap is continuous at the cap
local mixed = all(0.4)
mixed.Quads, mixed.Lats, mixed.Abs = 1.4, 1.2, 1.1
shown = LB.Apply(mixed)
ok = true
for _, muscle in ipairs(M.List) do ok = ok and shown[muscle.id] <= mixed[muscle.id] + 1e-9 end
H.check(ok, "the displayed look is never above the trained look")
H.check(LB.SoftCap(0.5, 0.6, 0.05) == 0.5 and near(LB.SoftCap(0.6, 0.6, 0.05), 0.6) and LB.SoftCap(5, 0.6, 0.05) < 0.65 + 1e-9
	and LB.SoftCap(0.601, 0.6, 0.05) > 0.6, "soft cap: exact below the cap, eases into it above (no snap)")
H.done()
