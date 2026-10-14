local H = require("./harness")
local T = H.module("ReplicatedStorage/Shared/Config/Trainers")
print("Trainers")
H.check(#T.List == 4, "four trainers")
local kinds = {}
for _, t in T.List do
	H.check(t.price > 0 and t.coachName and t.perkText and t.look and t.look.skin and t.look.shirt and t.look.pants and t.look.faceTexture, t.id .. " is complete (skin, clothes, face)")
	for k in t.perk do kinds[k] = true end
end
H.check(kinds.gains and kinds.regen and kinds.coins and kinds.pump, "one perk each: EXP, refill, coins, pump")
H.check(T.ById.RookieCoach.perk.gains == 1.05 and T.ById.CardioCoach.perk.regen == 1.1 and T.ById.MoneyCoach.perk.coins == 1.05, "perk sizes as in the brief")
print("Slots")
H.check(T.SlotsFor(false) == 1 and T.SlotsFor(true) == 2, "1 slot, 2 with the pass")
local list = T.CleanEquipped({ "PumpCoach", "RookieCoach", "PumpCoach", "Nope" }, { "PumpCoach", "RookieCoach" }, 1)
H.check(#list == 1 and list[1] == "PumpCoach", "only as many as the slots")
list = T.CleanEquipped({ "PumpCoach", "PumpCoach", "RookieCoach", "MoneyCoach" }, { "PumpCoach", "RookieCoach" }, 2)
H.check(#list == 2 and list[2] == "RookieCoach", "no doubles, only owned ones")
H.check(#T.CleanEquipped(nil, nil, 2) == 0, "bad data: nothing")
print("Cheers")
H.check(#T.Cheers >= 3 and T.CheerCooldown > 0 and T.RenderDistance > 0, "cheers, cooldown and render distance set")
H.done()
