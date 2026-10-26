local H = require("./harness")
local P = H.module("ReplicatedStorage/Shared/Config/PosingComp")
local ShowOff = H.module("ReplicatedStorage/Shared/Config/ShowOff")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local GrowthSpurts = H.module("ReplicatedStorage/Shared/Config/GrowthSpurts")

print("Schedule and poses")
H.check(P.Interval == 300, "a show every 5 minutes")
H.check(P.JoinWindow < P.Interval, "the join window fits between shows")
for _, id in P.Poses do
	local emote = ShowOff.EmoteById[id]
	H.check(emote ~= nil and emote.poseData ~= nil, id .. " is a held pose")
end
H.check(P.Intro + #P.Poses * P.PoseTime + P.ScoreShow + P.PodiumTime < 60, "a division takes under 60 s")

print("Divisions")
-- (26 Oct: Growth Spurts are 4 inches, 4'0" -> 6'0": two spurts a division)
H.check(P.DivisionFor(48).id == "Bantam" and P.DivisionFor(52).id == "Bantam", "4'0\" and 4'4\" = Bantam")
H.check(P.DivisionFor(56).id == "Middle" and P.DivisionFor(60).id == "Middle", "4'8\" and 5'0\" = Middle")
H.check(P.DivisionFor(64).id == "Heavy" and P.DivisionFor(68).id == "Heavy", "5'4\" and 5'8\" = Heavy")
H.check(P.DivisionFor(84).id == "Open", "7'0\" = Open")
for spurts = 0, GrowthSpurts.MaxSpurts() do
	H.check(P.DivisionFor(GrowthSpurts.GetHeight(spurts)) ~= nil, "every height has a division (spurt " .. spurts .. ")")
end

print("Show ladder")
H.check(P.ShowFor(0) == nil, "no show before the first Growth Spurt")
H.check(P.ShowFor(1).id == "Local" and P.ShowFor(2).id == "Regional" and P.ShowFor(4).id == "National", "Local / Regional / National")
H.check(P.ShowFor(5).id == "ProQualifier" and P.ShowFor(GrowthSpurts.MaxSpurts()).id == "Universe", "Pro Card Qualifier, Universe at 7'0\"")
for _, show in P.Shows do
	H.check(show.coins[1] > show.coins[2] and show.coins[2] > show.coins[3] and show.coins[3] > show.enter, show.name .. ": 1st > 2nd > 3rd > the rest")
end

print("Judging")
local w = P.Weights
H.check(w.Size + w.Balance + w.Presence == 100, "out of 100")
local best = P.Score(1, 1, 84, 1, P.AlterFull)
H.check(best.total == 100, "the biggest, balanced, 7'0\" with every alter = 100")
-- (prompt 21) at 7'0" stage presence comes from the alter number; divisions by alter tier
H.check(P.Score(1, 1, 84, 1, 0).presence < P.Score(1, 1, 84, 1, 5).presence, "a higher alter = more stage presence")
H.check(P.DivisionFor(84, 0).id == "Open" and P.DivisionFor(84, 1).id == "Alter1" and P.DivisionFor(84, 6).id == "Alter6", "7'0\" divisions by alter tier")
H.check(P.DivisionFor(68, 1).id == "Heavy", "below 6'0\" the alter doesn't matter")
local small = P.Score(0.4, 1, 54, 0.4)
H.check(small.size == w.Size, "the biggest in a small division gets full size points")
local behind = P.Score(0.2, 1, 54, 0.4)
H.check(behind.size < small.size, "smaller than the division's best = fewer size points")
H.check(behind.total == behind.size + behind.balance + behind.presence, "the breakdown adds up")

print("Size and balance")
local function looks(value, overrides)
	local t = {}
	for _, m in Muscles.List do t[m.id] = value end
	for id, v in overrides or {} do t[id] = v end
	return t
end
local size, balance = P.SizeAndBalance(looks(1), Muscles.Groups)
H.check(size == 1 and balance == 1, "full look, even = 1, 1")
size, balance = P.SizeAndBalance(looks(0), Muscles.Groups)
H.check(size == 0 and balance == 0, "nothing grown = 0, 0")
local lopsided = {}
for _, m in Muscles.Groups[1].muscles do lopsided[m.id] = 1 end
size, balance = P.SizeAndBalance(looks(0.1, lopsided), Muscles.Groups)
H.check(balance == 0, "one big group, the rest tiny = no balance")

print("NPCs")
H.check(#P.Npcs >= P.NpcFillTo - 1, "enough NPC competitors for a solo player")
for _, division in P.Divisions do
	local range = P.NpcShare[division.id]
	H.check(range ~= nil and range[1] <= range[2] and P.NpcHeight[division.id] ~= nil, division.name .. " has NPC sizes")
end
H.done()
