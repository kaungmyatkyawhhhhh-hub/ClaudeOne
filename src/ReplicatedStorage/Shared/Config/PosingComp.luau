-- Posing Competition (owner's feature run, task 1): a round on the posing stage on the beach (Config.Town.Stage) every
-- Interval seconds. Everyone in the server is told when it starts; whoever stands on the stage when the countdown ends is in.
-- Three poses: tap the pose button when the ring closes, then hold the pose until the judges score it. Score per pose =
-- muscle size + balance between the groups + timing, shown as the judges' card (1 to 10) above each contestant. Players
-- watching vote during the last pose. Top 3 stand on the podium; the winner gets "Posing Champion" and the statue.
-- (PosingCompService on the server, PosingCompClient on every client, stage pieces from tools/builders/PosingComp.)
local PosingComp = {}

PosingComp.Interval = 12 * 60   -- seconds from one round's start to the next
PosingComp.FirstDelay = 3 * 60  -- seconds after the server starts before the first round's countdown
PosingComp.Countdown = 60       -- seconds of "Posing Competition starts in ..." before the round
PosingComp.MaxPlayers = 6       -- contestants (players + NPCs) on stage at most
PosingComp.MinPlayers = 2       -- fewer contestants than this: NPC bodybuilders join (so a solo player can still compete)
PosingComp.NpcFillTo = 3        -- ...until there are this many contestants
PosingComp.StageMargin = 1      -- studs around the stage top that still count as "on the stage"

-- The three poses of a round (ids from Config.ShowOff.Emotes).
PosingComp.Poses = { "FrontDoubleBiceps", "FrontLatSpread", "MostMuscular" }

-- One pose: the ring closes over CueTime, tap when it closes. Then hold until the judges score it HoldTime later.
PosingComp.Intro = 4        -- seconds between "contestants, take your marks" and the first pose
PosingComp.CueTime = 2.4    -- seconds the timing ring takes to close
PosingComp.Perfect = 0.2    -- seconds either side of the ring closing that count as a perfect tap
PosingComp.Good = 0.55      -- ...a good tap
PosingComp.LateLimit = 1.2  -- after the ring closed, a tap this late still poses (no timing bonus); later = missed (auto pose)
PosingComp.HoldTime = 3     -- seconds from the ring closing to the judges' score; moving before it = the hold bonus is lost
PosingComp.ScoreShow = 2.5  -- seconds the score cards stay up
PosingComp.Gap = 1.5        -- seconds between the cards going down and the next pose
PosingComp.MaxPing = 0.3    -- seconds of network delay forgiven on a tap (the server times every tap)
PosingComp.Timing = { Perfect = 1, Good = 0.6, Late = 0.15, Missed = 0 } -- timing value of each tap
PosingComp.HoldLost = 0.5   -- timing value x this if the pose was let go before the judges scored it

-- Score of one pose (0..1, shown as a card from 1 to 10 in halves).
PosingComp.Weights = { Size = 0.55, Balance = 0.25, Timing = 0.2 }
PosingComp.SizeFull = 1     -- average muscle look (Muscles.LookG: 1 = the full aesthetic look) that counts as full size
-- Balance: 1 when every muscle group looks the same size, 0 when the smallest group is BalanceZero x the biggest or less.
PosingComp.BalanceZero = 0.25

-- Audience vote during the last pose (players not on the stage, within VoteRange studs of it).
PosingComp.VoteRange = 150
PosingComp.VotePoints = 0.5 -- points added to the contestant's total per vote (the total is the sum of the 3 cards)
PosingComp.VoteMax = 2      -- most points votes can add

-- Results: the podium (top 3) for PodiumTime seconds, coins, the title for the winner (Config.Titles "PosingChampion").
PosingComp.PodiumTime = 10
PosingComp.Coins = { 150, 90, 50 } -- 1st, 2nd, 3rd
PosingComp.EnterCoins = 10        -- every other contestant who finished the round

-- NPC bodybuilders who fill the stage (original characters). share = how grown they are (Muscles.LookG, 1 = the full look);
-- skill = their timing value range per pose.
PosingComp.Npcs = {
	{ name = "Marco Vance", skin = "#C68642", shorts = "Navy", share = 0.45, skill = { 0.3, 0.8 } },
	{ name = "Jade Rivers", skin = "#F1C27D", shorts = "Red", share = 0.6, skill = { 0.4, 0.9 } },
	{ name = "Theo Banks", skin = "#8D5524", shorts = "Black", share = 0.75, skill = { 0.5, 1 } },
	{ name = "Kai Summers", skin = "#E0AC69", shorts = "Teal", share = 0.35, skill = { 0.2, 0.7 } },
	{ name = "Nina Cruz", skin = "#A0662F", shorts = "Gray", share = 0.55, skill = { 0.3, 0.9 } },
}

-- Sounds (Config.Sounds slots; the owner picks the ids).
PosingComp.Sounds = { Start = "PosingStart", Cue = "PosingCue", Score = "PosingScore", Win = "PosingWin" }

-- One pose's score (0..1) from the size, balance and timing values (each 0..1).
function PosingComp.PoseScore(size, balance, timing)
	local w = PosingComp.Weights
	return math.clamp(w.Size * size + w.Balance * balance + w.Timing * timing, 0, 1)
end

-- The judges' card for a 0..1 score: 1 to 10 in halves.
function PosingComp.Card(score)
	return math.floor((1 + 9 * score) * 2 + 0.5) / 2
end

-- Timing value of a tap `offset` seconds from the ring closing (nil = no tap).
function PosingComp.TapValue(offset)
	if offset == nil then return PosingComp.Timing.Missed end
	local a = math.abs(offset)
	if a <= PosingComp.Perfect then return PosingComp.Timing.Perfect, "Perfect" end
	if a <= PosingComp.Good then return PosingComp.Timing.Good, "Good" end
	if offset < 0 then return PosingComp.Timing.Late, "Early" end
	if offset <= PosingComp.LateLimit then return PosingComp.Timing.Late, "Late" end
	return PosingComp.Timing.Missed, "Missed"
end

-- Size and balance values (0..1) from a body's per-muscle looks ({ [muscleId] = look g }) and the muscle groups.
function PosingComp.SizeAndBalance(looks, groups)
	local total, count = 0, 0
	local low, high = math.huge, 0
	for _, group in ipairs(groups) do
		local sum, n = 0, 0
		for _, muscle in ipairs(group.muscles) do
			sum += looks[muscle.id] or 0
			n += 1
		end
		local avg = n > 0 and sum / n or 0
		total += sum
		count += n
		low = math.min(low, avg)
		high = math.max(high, avg)
	end
	local size = math.clamp((count > 0 and total / count or 0) / PosingComp.SizeFull, 0, 1)
	local balance = 0
	if high > 0.001 then
		balance = math.clamp((low / high - PosingComp.BalanceZero) / (1 - PosingComp.BalanceZero), 0, 1)
	end
	return size, balance
end

-- Points the audience votes add to a total.
function PosingComp.VoteBonus(votes)
	return math.min(PosingComp.VoteMax, (votes or 0) * PosingComp.VotePoints)
end

return PosingComp
