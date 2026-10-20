-- Posing show (owner's feature run, task 1; reworked for prompt 18, 21 Oct: "posing show every 5 minutes", gameplay plan
-- "Posing shows and judging"). A server-wide show every Interval seconds on the beach stage (Config.Town.Stage). Players
-- who have had a Growth Spurt see a small timer; in the last JoinWindow seconds it glows with a JOIN button. Whoever stands
-- on the stage when it ends is in. Contestants are split into divisions by height and each division runs on its own,
-- smallest first: the judges call the poses, everyone hits them together, then the judges score size, balance and
-- stage presence, and the top 3 go on the podium. Nobody is ever pulled out of training.
-- (PosingCompService on the server, PosingCompClient on every client, stage pieces from tools/builders/PosingComp.)
-- NO purchase, aura, pass or boost changes a score: only the saved muscles and the height.
local PosingComp = {}

PosingComp.Interval = 300      -- ShowInterval: seconds from one show's start to the next
PosingComp.FirstDelay = 90     -- seconds after the server starts before the first show
PosingComp.JoinWindow = 30     -- the last seconds before a show: the timer glows gold and shows JOIN
PosingComp.UnlockSpurts = 1    -- Growth Spurts needed to see the timer and to compete
PosingComp.MaxPerDivision = 8  -- contestants (players + NPCs) in one division
PosingComp.MaxPlayers = 6      -- (the marks tools/builders/PosingComp puts on the stage; contestants spread along them)
PosingComp.StageMargin = 1     -- studs around the stage top that still count as "on the stage"
PosingComp.JoinTeleport = 80   -- JOIN from further than this (or from another gym) puts you on the stage; closer = a path

-- Divisions by height (inches, Config.GrowthSpurts heights), smallest first. At 7'0" (prompt 21) by Body Alter tier:
-- "Open" = Natural (no alter yet), then one division per alter tier (Config.Alters.Tiers).
PosingComp.Divisions = {
	{ id = "Bantam", name = "Bantam", maxHeight = 59 },  -- under 5'0"
	{ id = "Middle", name = "Middle", maxHeight = 72 },  -- 5'0" to 6'0"
	{ id = "Heavy", name = "Heavy", maxHeight = 83 },    -- over 6'0"
	{ id = "Open", name = "Open", maxHeight = math.huge, alterTier = 0 }, -- 7'0", Natural
	{ id = "Alter1", name = "Human", maxHeight = math.huge, alterTier = 1 },
	{ id = "Alter2", name = "Stone", maxHeight = math.huge, alterTier = 2 },
	{ id = "Alter3", name = "Metal", maxHeight = math.huge, alterTier = 3 },
	{ id = "Alter4", name = "Gem", maxHeight = math.huge, alterTier = 4 },
	{ id = "Alter5", name = "Elements", maxHeight = math.huge, alterTier = 5 },
	{ id = "Alter6", name = "Legend", maxHeight = math.huge, alterTier = 6 },
}

-- The four poses the judges call, about 5 s each (ids from Config.ShowOff.Emotes).
PosingComp.Poses = { "SideChest", "FrontDoubleBiceps", "BackDoubleBiceps", "AbsAndThigh" }
PosingComp.PoseTime = 5    -- seconds per pose
PosingComp.Intro = 3       -- seconds for "contestants, take your marks"
PosingComp.ScoreShow = 6   -- seconds the judges' panel (every score) stays up
PosingComp.PodiumTime = 8  -- seconds on the podium
PosingComp.Between = 2     -- seconds between two divisions

-- Score out of 100. Size is compared to the best size in the division, so a small player can win their division.
PosingComp.Weights = { Size = 60, Balance = 25, Presence = 15 }
PosingComp.SizeFull = 1          -- (an NPC's size from its share: Muscles.LookG, 1 = the full aesthetic look)
PosingComp.BalanceZero = 0.25    -- balance 1 when every group looks the same size, 0 when the smallest is this x the biggest
PosingComp.PresenceHeight = 84   -- stage presence below 7'0": height / this
-- (prompt 21) at 7'0" stage presence comes from the Body Alter number: AlterBase + the rest by alter / AlterFull
PosingComp.AlterBase = 0.5
PosingComp.AlterFull = 30

-- Show ladder: players compete in the highest show they've unlocked (by Growth Spurts). Only the label, the prizes and
-- the backdrop change for now. coins = 1st / 2nd / 3rd, enter = everyone else who finished; 1st also gets a trophy.
PosingComp.Shows = {
	{ id = "Local", name = "Local Show", fromSpurt = 1, coins = { 150, 90, 60 }, enter = 25 },
	{ id = "Regional", name = "Regional Show", fromSpurt = 2, coins = { 300, 180, 120 }, enter = 50 },
	{ id = "National", name = "National Show", fromSpurt = 4, coins = { 700, 420, 280 }, enter = 100 },
	{ id = "ProQualifier", name = "Pro Card Qualifier", fromSpurt = 5, coins = { 1200, 720, 480 }, enter = 160 },
	{ id = "Universe", name = "Universe Championship", fromSpurt = 6, coins = { 2000, 1200, 800 }, enter = 250 },
}

-- NPC competitors (original characters) so a division never feels empty: with fewer than NpcFillTo contestants, NPCs
-- fill up (at least NpcMin when there are any players). Their size (share, Muscles.LookG) is scaled to the division.
PosingComp.NpcFillTo = 4
PosingComp.NpcMin = 2
PosingComp.NpcShare = { Bantam = { 0.3, 0.6 }, Middle = { 0.6, 1 }, Heavy = { 1, 1.6 }, Open = { 1.6, 2.4 } }
PosingComp.NpcHeight = { Bantam = 54, Middle = 66, Heavy = 78, Open = 84 } -- inches (stage presence)
for tier = 1, 6 do -- (the alter divisions: 7'0" mass monsters, bigger with each tier)
	PosingComp.NpcShare["Alter" .. tier] = { 1.6 + 0.1 * tier, 2.4 + 0.1 * tier }
	PosingComp.NpcHeight["Alter" .. tier] = 84
end
PosingComp.Npcs = {
	{ name = "Marco Vance", skin = "#C68642", shorts = "Navy" },
	{ name = "Jade Rivers", skin = "#F1C27D", shorts = "Red" },
	{ name = "Theo Banks", skin = "#8D5524", shorts = "Black" },
	{ name = "Kai Summers", skin = "#E0AC69", shorts = "Teal" },
	{ name = "Nina Cruz", skin = "#A0662F", shorts = "Gray" },
}

-- Sounds (Config.Sounds slots; the owner picks the ids).
PosingComp.Sounds = { Start = "PosingStart", Cue = "PosingCue", Score = "PosingScore", Win = "PosingWin", Crowd = "CrowdOoh" }

-- The division for a height (inches) and, at 7'0", the Body Alter tier (0 = Natural).
function PosingComp.DivisionFor(height: number, alterTier: number?)
	for _, division in ipairs(PosingComp.Divisions) do
		if height <= division.maxHeight and (division.alterTier == nil or division.alterTier == (alterTier or 0)) then return division end
	end
	return PosingComp.Divisions[#PosingComp.Divisions]
end

-- The highest show a player with `spurts` Growth Spurts has unlocked (nil = none yet).
function PosingComp.ShowFor(spurts: number)
	local pick = nil
	for _, show in ipairs(PosingComp.Shows) do
		if (spurts or 0) >= show.fromSpurt then pick = show end
	end
	return pick
end

-- Size and balance values (0..1) from a body's per-muscle looks ({ [muscleId] = look g }) and the muscle groups.
-- size = the average look (not capped: compared to the division's best).
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
	local size = (count > 0 and total / count or 0) / PosingComp.SizeFull
	local balance = 0
	if high > 0.001 then
		balance = math.clamp((low / high - PosingComp.BalanceZero) / (1 - PosingComp.BalanceZero), 0, 1)
	end
	return size, balance
end

-- The judges' breakdown for one contestant: { size, balance, presence, total } (whole points out of 100).
-- bestSize = the biggest size in the division; alter = the Body Alter number (counts at 7'0").
function PosingComp.Score(size: number, balance: number, height: number, bestSize: number, alter: number?)
	local w = PosingComp.Weights
	local sizePoints = math.floor(w.Size * math.clamp(bestSize > 0 and size / bestSize or 0, 0, 1) + 0.5)
	local balancePoints = math.floor(w.Balance * math.clamp(balance, 0, 1) + 0.5)
	local presence = math.clamp(height / PosingComp.PresenceHeight, 0, 1)
	if height >= PosingComp.PresenceHeight then
		presence = PosingComp.AlterBase + (1 - PosingComp.AlterBase) * math.clamp((alter or 0) / PosingComp.AlterFull, 0, 1)
	end
	local presencePoints = math.floor(w.Presence * presence + 0.5)
	return { size = sizePoints, balance = balancePoints, presence = presencePoints, total = sizePoints + balancePoints + presencePoints }
end

return PosingComp
