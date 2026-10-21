-- Unlock guides and locked menu buttons (prompt 39, 22 Oct; the gameplay plan's "Introduce features slowly"). Every line
-- the players read is here, so the owner can edit it.
--  * Locks: the side menu tiles that open later. They always show; locked = dimmed, grey, a small gold padlock. A tap
--    shakes it and says WHEN it opens and teases WHAT's inside (a toast). When it opens: the padlock pops off, the tile
--    gets the gold NEW glow until it's tapped once, and its guide plays.
--  * Guides: Coach Dex's dialog (the tutorial's box) with 1-3 short lines, then it points at the thing: a menu tile
--    (`tile`: a gold glow + bouncing arrow on it, the rest of the screen dims a little; done when tapped) or a place
--    (`place`: the gold path, a gold marker with its name, and a gold GO TO button that teleports; done when there).
--    A first-time guide finished pays `reward` coins. Each plays once per player (saved); `every` = once per Growth Spurt /
--    per alter instead (a short reminder), only after the guide named in `after` has played.
--  * Rules (GuideClient): never while on a machine, in a posing show, rolling trainers, in a menu or the tutorial; one at a
--    time, the rest queued, at least Gap seconds apart (Big ones BigGap); a SKIP pill; done by itself after Timeout s.
--    Settings "Show Tips" Off = no guides (the locks stay).
-- Conditions (`need`, any ONE of them is enough): spurts = n (Growth Spurts done), level = n (LVL: the average muscle
-- level, the top bar's), reps = n (total reps: the clock for the "a few minutes in" unlocks), heavier = true (a heavier
-- weight unlocked on any machine), ready = "spurt" | "alter" (a Growth Spurt / Body Alter ready now), alterTier = true
-- (the next alter starts a new tier).
-- Places: "Gym:Beach" / "Gym:Pro" (the gym: its nearest machine), "Tag:<tag>" (the nearest model with that tag:
-- TrainerDesk = the Trainer Agency, ArmWrestleTable, PumpShopCounter), "Stage" (the posing stage), "Coach".
local Guides = {}

Guides.Gap = 30      -- seconds between two guides
Guides.BigGap = 60   -- a big unlock guide (a place or a reward) at most once a minute
Guides.Timeout = 40  -- a guide finishes by itself after this
Guides.StartDelay = 8 -- seconds of play before the first guide (after the menu / a respawn)

-- the side menu tiles that open later (SideMenu ids). `when` is the condition in words; `progress` = show "54% there"
-- toward that Growth Spurt.
Guides.Locks = {
	{ tile = "Store", need = { spurts = 1 }, when = "Growth Spurt 1", progress = 1, tease = "Rare stuff. Only for lifters who make it." },
	{ tile = "Emotes", need = { spurts = 1 }, when = "Growth Spurt 1", progress = 1, tease = "Hit the stage. Flex in front of the whole server." },
	{ tile = "Crew", need = { spurts = 1 }, when = "Growth Spurt 1", progress = 1, tease = "Team up, win shows together, climb the crew board." },
	{ tile = "Trainers", need = { spurts = 2 }, when = "Growth Spurt 2", progress = 2, tease = "Real coaches who train you while you train. Some are legendary..." },
	{ tile = "Genetics", need = { level = 5, spurts = 1 }, when = "LVL 5", tease = "Your DNA is hiding something. Find out what you were born for." },
	{ tile = "Inventory", need = { reps = 60, spurts = 1 }, when = "a few minutes", tease = "Boosts, gear and secret drops go here." },
}
Guides.LockByTile = {}
for _, lock in ipairs(Guides.Locks) do Guides.LockByTile[lock.tile] = lock end

-- The guides, in the order they're checked. `lines` = Coach Dex's pages (1-3); `tile` / `place` = what it points at;
-- `label` = the name over a place; `reward` = coins for finishing a first-time guide; `big` = counts as a big unlock.
Guides.List = {
	-- events
	{ id = "SpurtReady", need = { ready = "spurt" }, big = true, reward = 25, tile = "GrowthSpurt",
		lines = { "You can GROWTH SPURT! Grow taller, get stronger gains and open new gyms.", "Tap TAP TO GROW when you're ready." } },
	{ id = "SpurtReadyAgain", need = { ready = "spurt" }, every = "spurt", after = "SpurtReady", tile = "GrowthSpurt",
		lines = { "Your next Growth Spurt is ready. Tap TAP TO GROW!" } },
	{ id = "AlterReady", need = { ready = "alter" }, big = true, reward = 25, tile = "GrowthSpurt",
		lines = { "You've hit 7'0\". Now you can BODY ALTER: a whole new skin, +15% gains, forever.", "Tap ALTER NOW when you're ready." } },
	{ id = "AlterTier", need = { alterTier = true }, every = "alter", after = "AlterReady", tile = "GrowthSpurt",
		lines = { "A new alter tier is waiting. Tap ALTER NOW to see what you become." } },
	{ id = "HeavierWeight", need = { heavier = true }, reward = 25,
		lines = { "A heavier weight just opened! Heavier lifts give more EXP every rep.", "Pick it on the machine's weight bar." } },
	-- Growth Spurt 1
	{ id = "BeachGym", need = { spurts = 1 }, big = true, reward = 25, place = "Gym:Beach", label = "BEACH GYM",
		lines = { "The BEACH GYM is open! New machines out in the sun.", "Let's go take a look." } },
	{ id = "Store", need = { spurts = 1 }, tile = "Store", reward = 25,
		lines = { "The SHOP is open: auras, boosts and coins." } },
	{ id = "Emotes", need = { spurts = 1 }, tile = "Emotes", reward = 25,
		lines = { "POSES are open! Learn flexes and show off your muscles." } },
	{ id = "PosingStage", need = { spurts = 1 }, big = true, reward = 25, place = "Stage", label = "POSING STAGE",
		lines = { "Posing shows are open! Get on the stage when a show starts and flex for the judges." } },
	{ id = "Crew", need = { spurts = 1 }, tile = "Crew", reward = 25,
		lines = { "CREWS are open! Team up with friends and climb the crew board together." } },
	-- a few minutes in
	{ id = "Inventory", need = { reps = 60, spurts = 1 }, tile = "Inventory", reward = 25,
		lines = { "Your INVENTORY is open. Boosts and gear you get go here." } },
	{ id = "Genetics", need = { level = 5, spurts = 1 }, tile = "Genetics", reward = 25,
		lines = { "GENETICS are open! See what your body was born for, and reroll with DNA tokens." } },
	{ id = "Spotting", need = { reps = 400 }, reward = 25,
		lines = { "Tip: walk up to someone lifting and tap SPOT to help them. You both lift harder." } },
	-- Growth Spurt 2
	{ id = "ProGym", need = { spurts = 2 }, big = true, reward = 25, place = "Gym:Pro", label = "PRO GYM",
		lines = { "The PRO GYM is open! Heavy machines for serious lifters." } },
	{ id = "Trainers", need = { spurts = 2 }, tile = "Trainers", reward = 25,
		lines = { "TRAINERS are open! Real coaches who boost your gains while you train." } },
	{ id = "TrainerAgency", need = { spurts = 2 }, big = true, place = "Tag:TrainerDesk", label = "TRAINER AGENCY",
		lines = { "Roll for trainers at the Trainer Agency desk. Some are legendary..." } },
	{ id = "ArmWrestle", need = { spurts = 2 }, big = true, reward = 25, place = "Tag:ArmWrestleTable", label = "ARM WRESTLING",
		lines = { "Arm wrestling is open! Sit at a table and challenge anyone in the server." } },
	-- later
	{ id = "Auras", need = { spurts = 3 }, tile = "Inventory", reward = 25,
		lines = { "You earned your first AURA! Wear it in Inventory > Looks." } },
	{ id = "PumpShop", need = { spurts = 3 }, big = true, place = "Tag:PumpShopCounter", label = "PUMP SHOP",
		lines = { "The PUMP SHOP sells boosts for coins. Stock up before a big session." } },
}
Guides.ById = {}
for _, guide in ipairs(Guides.List) do Guides.ById[guide.id] = guide end

-- The things `need` reads, from a player's data (the server's or the client's copy).
local Muscles = require(script.Parent.Muscles)
function Guides.Level(data): number
	local total, count = 0, 0
	for _, muscle in ipairs(Muscles.List) do
		local entry = data.muscles and data.muscles[muscle.id]
		if entry then
			total += Muscles.ExactLevel(entry)
			count += 1
		end
	end
	return if count > 0 then math.floor(total / count) else 0
end
function Guides.Heavier(data): boolean
	for _, progress in pairs(data.machines or {}) do
		if type(progress) == "table" and (tonumber(progress.unlocked) or 1) >= 2 then return true end
	end
	return false
end

-- Is `need` met? (state = { spurtReady, alterReady, alterTier } for the "ready" checks, worked out by the caller)
function Guides.Met(need, data, state): boolean
	if not need or type(data) ~= "table" then return false end
	state = state or {}
	if need.spurts and (data.growthSpurts or 0) >= need.spurts then return true end
	if need.level and Guides.Level(data) >= need.level then return true end
	if need.reps and (data.stats and data.stats.totalReps or 0) >= need.reps then return true end
	if need.heavier and Guides.Heavier(data) then return true end
	if need.ready == "spurt" and state.spurtReady then return true end
	if need.ready == "alter" and state.alterReady then return true end
	if need.alterTier and state.alterTier then return true end
	return false
end

-- The id a guide is saved under: "SpurtReadyAgain:3" for an `every` one (the spurt / alter it's for), else its id.
function Guides.SaveId(guide, data): string
	if guide.every == "spurt" then return guide.id .. ":" .. tostring((data.growthSpurts or 0) + 1) end
	if guide.every == "alter" then
		local highest = type(data.alter) == "table" and data.alter.highest or 0
		return guide.id .. ":" .. tostring(highest + 1)
	end
	return guide.id
end

-- the locked toast's lines: "LOCKED · Unlocks at Growth Spurt 1" and the tease (+ "Growth Spurt 1 · 54% there")
function Guides.LockedLines(lock, data, share: number?): (string, string)
	local title = "LOCKED · Unlocks " .. (if lock.when == "a few minutes" then "in a few minutes" else "at " .. lock.when)
	local sub = lock.tease
	if lock.progress and share and (data.growthSpurts or 0) == lock.progress - 1 then
		sub ..= "  (" .. lock.when .. " · " .. math.floor(share * 100) .. "% there)"
	end
	return title, sub
end

return Guides
