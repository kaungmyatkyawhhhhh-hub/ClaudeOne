-- Social: the workout-together bonus, arm wrestling and crews. Tune the numbers here. (Spotting: Config.Spotting.)
local Social = {}

-- Lifting near other lifters.
Social.Together = {
	GainsBoost = 1.1,
	Range = 30,         -- studs between two lifters
}

-- Arm wrestling (owner's feature run, task 3): a table in the starter gym and one in the pro gym (tag "ArmWrestleTable",
-- tools/builders/ArmWrestleTable). Sit down with the machines' OCCUPY prompt. Two players = a match; alone you can pick
-- an NPC opponent (3 levels) or wait for a player. 3-2-1, then tap a big button as fast as you can for up to MaxTime:
-- every tap pushes the bar toward your side, a little harder with bigger biceps and forearms (capped, so tapping skill
-- still decides most matches). Push it all the way, or be ahead when time runs out. All decided on the server.
Social.ArmWrestle = {
	TableSpot = Vector3.new(18, 0.1, -31), -- the starter gym's table: right of the aisle, ~28 studs in from the door (owner, 14 Oct: not at the spawn)
	ProTableSpot = Vector3.new(88, 0.1, -64),  -- the pro gym's table, on the open floor in front of the cable machines
	Muscles = { "Biceps", "Forearms" },        -- strength: their look (forearms = grip)
	PushPerTap = 0.035,     -- bar moved per tap at strength 1 (the bar goes from -1 to 1)
	StrengthBonus = 0.5,    -- at the full look (StrengthLookCap) each tap counts 1 + this
	StrengthLookCap = 1,    -- looks above this add nothing more
	MaxTapsPerSecond = 15,  -- the server ignores faster taps (no auto-clickers)
	Countdown = 3,
	MaxTime = 8,            -- seconds; then whoever is ahead wins
	WinCoins = 15,          -- beating a player
	LoseCoins = 5,          -- everyone who finished a match
	Xp = { Win = 40, Lose = 20 }, -- Biceps / Forearms XP each (much less than a set on a machine)
	-- NPC opponents (original characters). strength x PushPerTap per tap, taps a second (random in the range), coins for a win.
	Npcs = {
		{ id = "Rookie", label = "Easy", name = "Rocco", skin = "#C68642", shirt = "#1F5FBF", pants = "#1E1E22", strength = 0.9, taps = { 5, 7 }, coins = 8 },
		{ id = "Pro", label = "Medium", name = "Tess", skin = "#F1C27D", shirt = "#2E9E4F", pants = "#2B2B2B", strength = 1.15, taps = { 7.5, 9.5 }, coins = 15 },
		{ id = "Champion", label = "Hard", name = "Big Lou", skin = "#8D5524", shirt = "#D7262E", pants = "#1E1E22", strength = 1.35, taps = { 9, 10.5 }, coins = 35, king = true },
	},
	SeatedRootY = 1.6,      -- a seated character's root above the stool's Seat (the NPC opponent sits there too)
	-- the animation (ArmWrestleClient, every client): the clasped hands swing toward the loser's table side
	LiveAngle = 70,         -- degrees from upright at a full bar
	PinAngle = 86,          -- the slam at the end
	AnimateDistance = 70,   -- studs from the camera; farther away the table isn't animated (saves frame time)
}
Social.ArmWrestle.NpcById = {}
for _, npc in ipairs(Social.ArmWrestle.Npcs) do Social.ArmWrestle.NpcById[npc.id] = npc end

-- Crews: small groups with a name and a short tag shown above members' heads. Saved across servers.
Social.Crew = {
	MaxMembers = 8,
	NameLength = { 3, 20 },
	TagLength = { 2, 4 },   -- letters and numbers only
	CreateCost = 0,         -- coins
	Refresh = 120,          -- seconds between crew score / top crews updates
}

-- Arm wrestling strength from a player's muscle looks ({ [muscleId] = look g }, Muscles.LookG: 1 = the full look):
-- 1 at nothing grown, up to 1 + StrengthBonus.
function Social.Strength(looks)
	local cfg = Social.ArmWrestle
	local sum = 0
	for _, id in ipairs(cfg.Muscles) do sum += looks[id] or 0 end
	local average = sum / #cfg.Muscles
	return 1 + cfg.StrengthBonus * math.clamp(average / cfg.StrengthLookCap, 0, 1)
end

return Social
