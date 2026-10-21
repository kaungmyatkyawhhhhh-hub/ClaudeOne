-- Personal trainers (owner's feature run, task 7B; instead of pets). Since prompt 24 (21 Oct) they come from coin ROLLS at the
-- Trainer Agency (the desks at the front of each gym), like eggs in pet games: coins only (never Robux, no Robux luck), the
-- odds always shown, a pity counter. Everything about trainers is in this module.
-- A trainer is a coach who follows you and stands beside your machine while you train. Every client draws every trainer
-- itself (TrainerFollowClient) from the player attribute "Trainers" (the equipped entries, "PumpCoach,RookieCoach@g").
-- Saved per player (data.trainers, TrainerService): { owned = { [id] = count }, golden = { [id] = count }, equipped = { entry },
-- rolls, pity, autoDelete = { [rarity] = true }, bonus = { gains, coins, maxStamina, progress } (the equipped total,
-- written by TrainerService: Config.GrowthSpurts / Config.Alters and PlayerData read it) }.
local Trainers = {}

------------------------------------------------------------------------
-- Rarities (a 9th rank later = one more entry here: its colors, odds and effects; the rolls, odds list, animation and
-- announcements all read this list). chance in % (they add up to 100). announce = everyone in the server is told
-- ("chat": a chat line + a toast; "banner": a big banner too). reveal = the roll animation's extra beat.
------------------------------------------------------------------------
Trainers.Rarities = {
	{ id = "Common", name = "Common", chance = 50, color = "#B9BCC4", reveal = "plain" },
	{ id = "Uncommon", name = "Uncommon", chance = 30, color = "#5CC46B", reveal = "plain" },
	{ id = "Rare", name = "Rare", chance = 12, color = "#3F8CFF", reveal = "plain" },
	{ id = "Epic", name = "Epic", chance = 5, color = "#A06BE6", reveal = "burst" },
	{ id = "Legendary", name = "Legendary", chance = 2, color = "#F6C75A", reveal = "explosion", announce = "chat" },
	{ id = "Mythic", name = "Mythic", chance = 0.75, color = "#E8345A", color2 = "#9A4AD8", reveal = "lightning", announce = "chat" },
	{ id = "Secret", name = "Secret", chance = 0.2, color = "#2A2A30", color2 = "#8E8E9A", reveal = "dark", announce = "banner", hidden = true },
	{ id = "Eternal", name = "Eternal", chance = 0.05, color = "#FFF3C4", color2 = "#F6C75A", reveal = "cosmic", announce = "banner" },
}
Trainers.RarityById = {}
for index, rarity in ipairs(Trainers.Rarities) do
	rarity.index = index
	Trainers.RarityById[rarity.id] = rarity
end

------------------------------------------------------------------------
-- The trainers: one per rarity. perk (while equipped; added up over all equipped trainers, then capped by BoostCap):
--   gains = +EXP share, coins = +coins share, maxStamina = +max stamina share, progress = +Growth Spurt / alter progress share
--   (the goal's EXP counts that much more: Config.GrowthSpurts / Config.Alters).
-- 1-4 are the four original coaches (ordered by their old strength: price), 5-8 new, each more impressive: taller, bigger,
-- rarer outfits and a rarity aura (Shared.VFX.AuraVFX presets).
-- look: skin, hairIds (Roblox's own free catalog hair), faceTexture (one of Roblox's own faces, on a classic head), shirt /
-- pants (our own clothing templates; nil = bare: the rare ones show their muscles), muscle (the static muscle stages, share of
-- the goal), extras (part-built props: whistle, headband, bottle, cap, clipboard, belt, wraps, cape, hood, crown, shoulderpads,
-- shorts (look.shorts color; the bare-chested rare ones: our clothing templates have a coach's skin painted under them), shoes),
-- extraColor, aura (AuraVFX preset), shine (a soft glow color on the body).
-- heightInches: the players' height system (60 = 5'0"); TrainerService scales the rig, the widths with it (frame / shoulderBonus
-- on top).
------------------------------------------------------------------------
Trainers.List = {
	{ id = "RookieCoach", rarity = "Common", name = "Coach Sam", heightInches = 60, perk = { gains = 0.05 }, perkText = "+5% EXP",
		picture = "trainer_exp",
		look = { skin = "#F1C9A5", hairIds = { 376548738 }, faceTexture = "rbxassetid://26424652", -- Brown Charmer Hair, Know-It-All Grin
			shirt = "rbxassetid://102959678094397", pants = "rbxassetid://72439591969493", muscle = 0.9,
			extras = { "whistle" }, extraColor = "#C8262C", tint = "#C8262C" } },
	{ id = "CardioCoach", rarity = "Uncommon", name = "Coach Nia", heightInches = 65, perk = { coins = 0.10 }, perkText = "+10% coins",
		picture = "trainer_stamina",
		look = { skin = "#8D5A3C", hairIds = { 451220849 }, faceTexture = "rbxassetid://7074749", -- Lavender Updo, Chill
			shirt = "rbxassetid://75627226847033", pants = "rbxassetid://132200798598308", muscle = 0.7,
			extras = { "headband", "bottle" }, extraColor = "#F4F1EA", tint = "#2FAE55" } },
	{ id = "MoneyCoach", rarity = "Rare", name = "Coach Lou", heightInches = 72, frame = "Wide", perk = { gains = 0.15, maxStamina = 0.10 },
		perkText = "+15% EXP, +10% max stamina", picture = "trainer_coins",
		look = { skin = "#E0AC7E", faceTexture = "rbxassetid://144080495", -- Smile (a buzz cut under the cap)
			shirt = "rbxassetid://115347278747243", pants = "rbxassetid://82450924223675", muscle = 0.8,
			extras = { "cap", "clipboard" }, extraColor = "#16161A", tint = "#E0B23A" } },
	{ id = "PumpCoach", rarity = "Epic", name = "Coach Rex", heightInches = 78, frame = "VTaper", shoulderBonus = 1.1, perk = { gains = 0.25, coins = 0.25 },
		perkText = "+25% EXP and coins", picture = "trainer_pump",
		look = { skin = "#5C3A21", faceTexture = "rbxassetid://83017053", -- bald, Man Face
			shirt = "rbxassetid://102922865828545", pants = "rbxassetid://92479669230797", muscle = 1.8,
			extras = { "belt", "wraps" }, extraColor = "#7A3FC8", tint = "#7A3FC8" } },
	{ id = "AtlasCoach", rarity = "Legendary", name = "Coach Atlas", heightInches = 80, frame = "VTaper", shoulderBonus = 1.15,
		perk = { gains = 0.40, coins = 0.40, progress = 0.10 }, perkText = "+40% EXP and coins, +10% progress",
		look = { skin = "#C68642", faceTexture = "rbxassetid://26424652", -- Know-It-All Grin; bare chest, gold belt, wraps and shoulder pads
			muscle = 2.3, shorts = "#1E1E22",
			extras = { "shorts", "shoes", "belt", "wraps", "shoulderpads" }, extraColor = "#F6C75A", tint = "#F6C75A", aura = "golden" } },
	{ id = "BlazeCoach", rarity = "Mythic", name = "Coach Blaze", heightInches = 82, frame = "VTaper", shoulderBonus = 1.2,
		perk = { gains = 0.70, coins = 0.70, progress = 0.20 }, perkText = "+70% EXP and coins, +20% progress",
		look = { skin = "#8D5524", faceTexture = "rbxassetid://83017053", -- Man Face; a red-purple cape
			muscle = 2.7, shorts = "#3A0A1E",
			extras = { "shorts", "shoes", "belt", "wraps", "cape" }, extraColor = "#B01E5A", tint = "#E8345A", aura = "neon" } },
	{ id = "ShadeCoach", rarity = "Secret", name = "Coach Shade", heightInches = 84, frame = "VTaper", shoulderBonus = 1.25,
		perk = { gains = 1.10, coins = 1.10, progress = 0.30 }, perkText = "+110% EXP and coins, +30% progress",
		look = { skin = "#2B2530", faceTexture = "rbxassetid://7074749", -- Chill; a dark figure under a hood, smoke
			muscle = 3.0, shorts = "#141417",
			extras = { "shorts", "shoes", "hood", "wraps" }, extraColor = "#141417", tint = "#4A4A55", aura = "shadow" } },
	{ id = "AeonCoach", rarity = "Eternal", name = "Coach Aeon", heightInches = 84, frame = "VTaper", shoulderBonus = 1.3,
		perk = { gains = 1.50, coins = 1.50, progress = 0.50 }, perkText = "+150% EXP and coins, +50% progress",
		look = { skin = "#F3E9DC", faceTexture = "rbxassetid://144080495", -- Smile; white-gold, a crown and a cape, cosmic glow
			muscle = 3.2, shorts = "#F4F1EA",
			extras = { "shorts", "shoes", "belt", "cape", "crown" }, extraColor = "#F6C75A", tint = "#FFF3C4", aura = "royal", shine = "#FFF3C4" } },
}
Trainers.ById = {}
Trainers.ByRarity = {}
for index, trainer in ipairs(Trainers.List) do
	trainer.index = index
	Trainers.ById[trainer.id] = trainer
	Trainers.ByRarity[trainer.rarity] = trainer
end

------------------------------------------------------------------------
-- Rolls
------------------------------------------------------------------------
Trainers.RollMinutes = 1.6         -- a roll costs this many minutes of coins at your stage (PumpShop.CoinsPerMinute; tests/pacing trainers)
Trainers.MinPrice = 60             -- (never below)
Trainers.MultiRoll = 3             -- Roll x3...
Trainers.MultiRollFromSpurt = 2    -- ...from Growth Spurt 2
Trainers.Pity = 100                -- this many rolls in a row without PityRarity or better: the next one is PityRarity
Trainers.PityRarity = "Epic"
Trainers.AutoStopRarity = "Epic"   -- Auto Roll stops on this or better
Trainers.AutoDeleteRarities = { "Common", "Uncommon" } -- toggles: a duplicate of these turns into coins instead
Trainers.AutoDeleteRefund = 0.1    -- ...this share of the roll price
Trainers.GoldenCount = 5           -- 5 of the same trainer make 1 Golden...
Trainers.GoldenMultiplier = 1.5    -- ...with 1.5x the boost
Trainers.BoostCap = 4              -- the equipped trainers' total boost is capped at +400% (per kind)
Trainers.AnnounceFrom = "Legendary"

-- The price of one roll at a stage (Growth Spurts; 6 = 7'0").
function Trainers.RollPrice(coinsPerMinute: number): number
	return math.max(Trainers.MinPrice, math.floor(coinsPerMinute * Trainers.RollMinutes / 5 + 0.5) * 5)
end

-- One roll. roll01 = a uniform random number in [0, 1); pity = rolls in a row so far without PityRarity or better.
-- Returns the rarity id and the new pity count.
function Trainers.Roll(roll01: number, pity: number): (string, number)
	local pick = Trainers.Rarities[1].id
	local acc = 0
	local x = roll01 * 100
	for _, rarity in ipairs(Trainers.Rarities) do
		acc += rarity.chance
		if x < acc then
			pick = rarity.id
			break
		end
	end
	local floor = Trainers.RarityById[Trainers.PityRarity].index
	if Trainers.RarityById[pick].index < floor and (pity or 0) + 1 >= Trainers.Pity then pick = Trainers.PityRarity end
	local newPity = if Trainers.RarityById[pick].index >= floor then 0 else (pity or 0) + 1
	return pick, newPity
end

------------------------------------------------------------------------
-- Slots: 1 at start, 2 at Growth Spurt 2, 3 at the first Body Alter, +1 with the Extra Trainer pass (Monetization, id
-- 2032496303; player attribute Pass_ExtraTrainer)
------------------------------------------------------------------------
Trainers.ExtraSlotPass = "ExtraTrainer"
Trainers.SlotSteps = { { spurts = 0, slots = 1 }, { spurts = 2, slots = 2 }, { alter = 1, slots = 3 } }
Trainers.MaxSlots = 4

function Trainers.SlotsFor(hasPass: boolean, spurts: number?, alter: number?): number
	local slots = 1
	for _, step in ipairs(Trainers.SlotSteps) do
		if (step.spurts and (spurts or 0) >= step.spurts) or (step.alter and (alter or 0) >= step.alter) then slots = math.max(slots, step.slots) end
	end
	return slots + (hasPass and 1 or 0)
end

------------------------------------------------------------------------
-- Equipped entries: "PumpCoach" or "PumpCoach@g" (Golden)
------------------------------------------------------------------------
function Trainers.Entry(id: string, golden: boolean?): string
	return if golden then id .. "@g" else id
end
function Trainers.ParseEntry(entry: string): (string?, boolean)
	if type(entry) ~= "string" then return nil, false end
	local id, tag = string.match(entry, "^([%w_]+)(@?g?)$")
	if not id or not Trainers.ById[id] then return nil, false end
	return id, tag == "@g"
end

-- The equipped list cleaned up: known entries the player owns enough of (duplicates can fill several slots), at most `slots`.
function Trainers.CleanEquipped(equipped, owned, golden, slots: number)
	local list = {}
	local used = {}
	owned = type(owned) == "table" and owned or {}
	golden = type(golden) == "table" and golden or {}
	for _, entry in ipairs(type(equipped) == "table" and equipped or {}) do
		if #list >= slots then break end
		local id, isGolden = Trainers.ParseEntry(entry)
		if id then
			local have = if isGolden then (tonumber(golden[id]) or 0) else (tonumber(owned[id]) or 0)
			local key = Trainers.Entry(id, isGolden)
			if (used[key] or 0) < have then
				used[key] = (used[key] or 0) + 1
				table.insert(list, key)
			end
		end
	end
	return list
end

-- The total boost of a list of equipped entries, each kind capped: { gains, coins, maxStamina, progress } (shares, 0.25 = +25%)
function Trainers.Bonus(entries)
	local total = { gains = 0, coins = 0, maxStamina = 0, progress = 0 }
	for _, entry in ipairs(entries or {}) do
		local id, isGolden = Trainers.ParseEntry(entry)
		local trainer = id and Trainers.ById[id]
		if trainer then
			for kind, amount in pairs(trainer.perk) do
				total[kind] = (total[kind] or 0) + amount * (if isGolden then Trainers.GoldenMultiplier else 1)
			end
		end
	end
	for kind, amount in pairs(total) do total[kind] = math.min(amount, Trainers.BoostCap) end
	return total
end

-- The perk line of a trainer (Golden: 1.5x)
function Trainers.PerkText(trainer, golden: boolean?): string
	if not golden then return trainer.perkText end
	local parts = {}
	local p = trainer.perk
	local m = Trainers.GoldenMultiplier
	local function pct(x) return string.format("%d%%", math.floor(x * m * 100 + 0.5)) end
	if p.gains and p.coins and p.gains == p.coins then
		table.insert(parts, "+" .. pct(p.gains) .. " EXP and coins")
	else
		if p.gains then table.insert(parts, "+" .. pct(p.gains) .. " EXP") end
		if p.coins then table.insert(parts, "+" .. pct(p.coins) .. " coins") end
	end
	if p.maxStamina then table.insert(parts, "+" .. pct(p.maxStamina) .. " max stamina") end
	if p.progress then table.insert(parts, "+" .. pct(p.progress) .. " progress") end
	return table.concat(parts, ", ")
end

-- (before prompt 24) data.trainers.owned was a list of hired ids: each becomes one of that trainer (same id, now its rarity)
function Trainers.Migrate(t)
	t = type(t) == "table" and t or {}
	local owned = t.owned
	if type(owned) == "table" and #owned > 0 then
		local map = {}
		for _, id in ipairs(owned) do
			if Trainers.ById[id] then map[id] = (map[id] or 0) + 1 end
		end
		owned = map
	end
	return {
		owned = type(owned) == "table" and owned or {},
		golden = type(t.golden) == "table" and t.golden or {},
		equipped = type(t.equipped) == "table" and t.equipped or {},
		rolls = tonumber(t.rolls) or 0,
		pity = tonumber(t.pity) or 0,
		autoDelete = type(t.autoDelete) == "table" and t.autoDelete or {},
		bonus = type(t.bonus) == "table" and t.bonus or nil,
	}
end

------------------------------------------------------------------------
-- Following (TrainerFollowClient)
------------------------------------------------------------------------
Trainers.DeskDistance = 8         -- the Trainer Agency prompt's reach (it opens the Agency window)
Trainers.RenderDistance = 90      -- other players' trainers past this many studs aren't drawn
Trainers.FollowBehind = 3         -- studs behind you...
Trainers.FollowSide = 2.6         -- ...and to the side (slot 1 right, slot 2 left, slots 3 / 4 a row further back)
Trainers.WalkSpeed = 15           -- studs a second (a running player gets caught up faster: CatchUpSpeed)
Trainers.CatchUpSpeed = 26
Trainers.TeleportDistance = 45    -- farther than this from his spot (or stuck for StuckSeconds): he pops back beside you
Trainers.StuckSeconds = 2.5
Trainers.CheerCooldown = 10       -- seconds between two speech bubbles from the same trainer (owner, 14 Oct: at most one per 10 s)
Trainers.CheerChance = 0.35       -- chance to cheer on a rep once the cooldown is over
Trainers.CheerEvery = 3          -- the cheer animation (clap / fist pump) every this many reps
Trainers.FarAnimation = 60       -- other players' trainers past this many studs stand still (no animation)
Trainers.BubbleSeconds = 3
Trainers.ClapSeconds = 1.4
Trainers.Cheers = { "One more rep!", "Push it!", "Good form!", "Breathe out!", "Nice and slow!", "You got this!",
	"Strong!", "Keep it steady!", "Look at you go!", "That's the way!" }
Trainers.SetDoneLines = { "Great set!", "Set done, nice work!", "That's how it's done!" }
Trainers.RecordLines = { "New record!", "Personal best!" }

return Trainers
