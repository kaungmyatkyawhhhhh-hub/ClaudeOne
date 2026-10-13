local H = require("./harness")
local P = H.module("ReplicatedStorage/Shared/Config/PosingComp")
local ShowOff = H.module("ReplicatedStorage/Shared/Config/ShowOff")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")

print("Poses")
for _, id in P.Poses do
	local emote = ShowOff.EmoteById[id]
	H.check(emote ~= nil and emote.poseData ~= nil, id .. " is a held pose")
end

print("Cards")
H.check(P.Card(0) == 1 and P.Card(1) == 10, "cards go from 1 to 10")
H.check(P.Card(0.5) == 5.5, "a middle score is 5.5")
local c = P.Card(0.37)
H.check(c * 2 == math.floor(c * 2), "cards are in halves")
local w = P.Weights
H.check(math.abs(w.Size + w.Balance + w.Timing - 1) < 1e-6, "weights add up to 1")
H.check(P.PoseScore(1, 1, 1) == 1 and P.PoseScore(0, 0, 0) == 0, "score from 0 to 1")

print("Timing")
H.check(P.TapValue(0) == P.Timing.Perfect, "on the cue = perfect")
H.check(P.TapValue(P.Perfect + 0.01) == P.Timing.Good, "a bit off = good")
H.check(P.TapValue(-(P.Good + 0.1)) == P.Timing.Late, "too early = small value")
H.check(P.TapValue(P.LateLimit + 0.1) == P.Timing.Missed, "much too late = missed")
H.check(P.TapValue(nil) == P.Timing.Missed, "no tap = missed")
H.check(P.HoldTime > P.LateLimit, "the judges score after the late window closes")

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
-- a balanced smaller body can beat a lopsided bigger one only on balance, never on size
local s1 = P.SizeAndBalance(looks(0.5), Muscles.Groups)
local s2 = P.SizeAndBalance(looks(0.9), Muscles.Groups)
H.check(s2 > s1, "bigger muscles = more size")

print("Votes")
H.check(P.VoteBonus(0) == 0, "no votes, no bonus")
H.check(P.VoteBonus(1000) == P.VoteMax, "votes are capped")

print("Rewards and NPCs")
H.check(#P.Coins == 3 and P.Coins[1] > P.Coins[2] and P.Coins[2] > P.Coins[3] and P.Coins[3] > P.EnterCoins, "1st > 2nd > 3rd > the rest")
H.check(P.NpcFillTo >= P.MinPlayers and P.NpcFillTo <= P.MaxPlayers, "NPC fill fits the stage")
H.check(#P.Npcs >= P.NpcFillTo - 1, "enough NPC bodybuilders for a solo player")
for _, npc in P.Npcs do
	H.check(npc.share > 0 and npc.share <= 1 and npc.skill[1] <= npc.skill[2], npc.name .. " ok")
end
H.done()
