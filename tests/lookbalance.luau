local H = require("./harness")
local M = H.module("ReplicatedStorage/Shared/Config/Muscles")
local LB = H.module("ReplicatedStorage/Shared/Config/LookBalance")

print("Look balance cap")
local function all(value)
	local raw = {}
	for _, muscle in ipairs(M.List) do raw[muscle.id] = value end
	return raw
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- level 0 and a balanced body are never capped
local shown, info = LB.Apply(all(0))
local zero = true
for _, muscle in ipairs(M.List) do zero = zero and shown[muscle.id] == 0 and not info[muscle.id].capped end
H.check(zero, "level 0: every muscle looks flat, nothing capped")

shown, info = LB.Apply(all(0.6))
local same = true
for _, muscle in ipairs(M.List) do same = same and near(shown[muscle.id], 0.6) and not info[muscle.id].capped end
H.check(same, "a balanced body looks exactly as trained")

-- a balanced mass monster isn't capped either (progress, not raw g: every muscle has its own monster size)
local monster = {}
for _, muscle in ipairs(M.List) do monster[muscle.id] = M.MonsterG(muscle.id) end
shown, info = LB.Apply(monster)
same = true
for _, muscle in ipairs(M.List) do same = same and near(shown[muscle.id], monster[muscle.id], 1e-4) and not info[muscle.id].capped end
H.check(same, "a balanced mass monster is not capped")

-- only Chest trained: held at Back + 0.20, the hint names Back
local chestOnly = all(0)
chestOnly.UpperChest, chestOnly.MidChest = 1, 1
shown, info = LB.Apply(chestOnly)
H.check(near(shown.MidChest, 0.2, 1e-3) and near(shown.UpperChest, 0.2, 1e-3), "only Chest maxed: its look is held at Back + 0.20")
H.check(info.MidChest.capped and info.MidChest.rule.name == "Back", "it shows as capped by Back")
H.check(not info.Lats.capped and shown.Lats == 0, "the untrained partners stay as they are")

-- train Back: Chest's look rises with it (until the next partner, the legs, holds it)
local last, smooth = LB.Apply(chestOnly).MidChest, true
for step = 1, 20 do
	local raw = table.clone(chestOnly)
	raw.Lats, raw.Rhomboids = step / 40, step / 40 -- Back 0 .. 0.5
	shown = LB.Apply(raw)
	if shown.MidChest < last - 1e-9 or shown.MidChest - last > 0.04 then smooth = false end
	last = shown.MidChest
end
H.check(smooth, "as Back is trained, Chest's look rises smoothly (never jumps, never drops)")
local withBack = table.clone(chestOnly)
withBack.Lats, withBack.Rhomboids = 1, 1
shown, info = LB.Apply(withBack)
H.check(near(shown.MidChest, 0.3, 1e-3) and info.MidChest.rule.name == "Legs", "with Back trained the whole-body rule holds Chest at the legs + 0.30")

-- the lowest cap wins, and the rule order doesn't matter (caps come from RAW values)
local mixed = all(0.3)
mixed.Biceps, mixed.Forearms, mixed.Quads, mixed.UpperChest = 1, 1, 0.9, 0.8
local a = LB.Apply(mixed)
local reversed = {}
for i = #LB.Rules, 1, -1 do table.insert(reversed, LB.Rules[i]) end
local saved = LB.Rules
LB.Rules = reversed
local b = LB.Apply(mixed)
LB.Rules = saved
same = true
for _, muscle in ipairs(M.List) do same = same and near(a[muscle.id], b[muscle.id]) end
H.check(same, "the result doesn't depend on the rule order")
-- forearms: arms rule avg(Biceps 1, Triceps 0.3) + 0.25 = 0.9, whole body: legs avg 0.45 + 0.30 = 0.75 -> the lower one
H.check(near(a.Forearms, 0.75, 1e-3) and near(a.Biceps, 0.5, 1e-3), "each muscle takes the lowest of its caps (Forearms 0.75 by the legs, Biceps 0.5 by Triceps)")

-- the displayed look is never above the raw look, and the smooth min never snaps
local never = true
for _, muscle in ipairs(M.List) do never = never and a[muscle.id] <= mixed[muscle.id] + 1e-9 end
H.check(never, "the displayed look is never above the trained look")
H.check(near(LB.SmoothMin(0.1, 0.9, 0.05), 0.1) and near(LB.SmoothMin(0.9, 0.1, 0.05), 0.1)
	and LB.SmoothMin(0.5, 0.5, 0.05) < 0.5 and LB.SmoothMin(0.5, 0.5, 0.05) > 0.48, "smooth min: the smaller value, blended where they meet")
H.done()
