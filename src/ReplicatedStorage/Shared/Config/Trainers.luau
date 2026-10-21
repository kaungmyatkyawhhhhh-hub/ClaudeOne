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
-- (owner, prompt 25: Mythic 0.6%, Secret 0.15%, Eternal 0.035%, Common takes the difference; tests/trainers measures the
-- times: Mythic ~3-4 h, Secret ~15 h at RollMinutes 1.6)
Trainers.Rarities = {
	{ id = "Common", name = "Common", chance = 50.215, color = "#B9BCC4", reveal = "plain" },
	{ id = "Uncommon", name = "Uncommon", chance = 30, color = "#5CC46B", reveal = "plain" },
	{ id = "Rare", name = "Rare", chance = 12, color = "#3F8CFF", reveal = "plain" },
	{ id = "Epic", name = "Epic", chance = 5, color = "#A06BE6", reveal = "burst" },
	{ id = "Legendary", name = "Legendary", chance = 2, color = "#F6C75A", reveal = "explosion", announce = "chat" },
	{ id = "Mythic", name = "Mythic", chance = 0.6, color = "#E8345A", color2 = "#9A4AD8", reveal = "lightning", announce = "chat" },
	{ id = "Secret", name = "Secret", chance = 0.15, color = "#2A2A30", color2 = "#8E8E9A", reveal = "dark", announce = "banner", hidden = true },
	{ id = "Eternal", name = "Eternal", chance = 0.035, color = "#FFF3C4", color2 = "#F6C75A", reveal = "cosmic", announce = "banner" },
}
Trainers.RarityById = {}
for index, rarity in ipairs(Trainers.Rarities) do
	rarity.index = index
	Trainers.RarityById[rarity.id] = rarity
end

------------------------------------------------------------------------
-- The trainers: one per rarity. perk (while equipped; added up over all equipped trainers, then capped by BoostCap):
--   gains = +EXP share, coins = +coins share, maxStamina = +max stamina share, staminaRegen = +stamina refill speed share,
--   progress = +Growth Spurt / alter progress share (the goal's EXP counts that much more: Config.GrowthSpurts / Config.Alters).
-- 1-4 are the four original coaches (ordered by their old strength: price), 5-8 (prompt 25: Duke Ironside, Volta, The
-- Shadow, Atlas) each more impressive: taller, bigger, more detail and a stronger aura (Shared.VFX.TrainerAura).
-- (5-8 keep their prompt 24 ids, AtlasCoach .. AeonCoach, so saves stay the same: only the names and looks changed.)
-- look: skin, hairIds (Roblox's own free catalog hair), faceTexture (one of Roblox's own faces, on a classic head; nil = none,
-- the hood hides it), shirt / pants (our own clothing templates with the trainer's skin painted under the clothes,
-- tools/trainer_clothes.py; nil = bare: they show their muscles), muscle (the static muscle stages, share of the goal), extras
-- (part-built props, TrainerService: whistle, headband, bottle, cap, clipboard, belt, bigbelt, wraps, chalk, cape, hood,
-- deephood, hoodback, crown, laurel, cuffs, shoulderpads, shorts (look.shorts color, look.shortsTrim), shoes, buzzcut, beard,
-- ponytail, kneesleeves, tiedjacket), extraColor, aura (TrainerAura preset), marble ({ color, variant }: a marble body,
-- Atlas: white with gold veins, Materials below), material (the classic head's material).
-- heightInches: the players' height system (60 = 5'0"; trainers may pass the players' 7'0" cap, up to MaxHeightInches);
-- TrainerService scales the rig, the widths with it (frame / shoulderBonus / widths = { hips, arms, legs, depth } on top).
-- idle: his stance while standing (TrainerFollowClient): crossed, hips, clipboard, chalk (claps chalk off, cracks his neck),
-- boxer (bounces on her toes, shadow-boxes), watch (arms crossed, turns his head to watch you), flex (a front double biceps
-- every ~8 s). line: what he says when you equip him (lines = several, said one after another, the later ones once a
-- session). pose: his roll reveal pose (PoseData, or "Crossed" / "Guard": tools/trainer_photos.luau). icon / art: the
-- rendered pictures (portrait, reveal), made in Studio from a fixed camera (tools/trainer_photos.luau + tools/trainer_icons.py);
-- nil = the 3D portrait (Shared.UI.TrainerPortrait).
Trainers.MaxHeightInches = 90
Trainers.SilhouetteIcon = "rbxassetid://137156947592087" -- (the Secret one before you own him: a black "???" silhouette)

-- The trainers' own materials (look.marble.variant): MaterialVariants in MaterialService, made in Studio by
-- tools/builders/SkinStages BuildTrainerSkins() (a game script can't set the maps). The stage muscle meshes of NPCs take no
-- skin textures, so Atlas is marble the statue's way (MuscleRig marble mode) with this variant on every part.
-- Our own textures: tools/marble_skin.py.
Trainers.Materials = {
	GymArc_GoldVeinMarble = { -- polished white marble with gold veins (Atlas)
		base = "Marble", studsPerTile = 6,
		color = "rbxassetid://105774110488913", normal = "rbxassetid://95563628937342",
		roughness = "rbxassetid://136099375982457", metalness = "rbxassetid://107405359147472",
	},
}
------------------------------------------------------------------------
Trainers.List = {
	{ id = "RookieCoach", rarity = "Common", name = "Coach Sam", heightInches = 60, perk = { gains = 0.05 }, perkText = "+5% EXP",
		picture = "trainer_exp", idle = "crossed", pose = "FrontDoubleBiceps", line = "Let's warm up!",
		icon = "rbxassetid://86466880073442", art = "rbxassetid://125829932471956",
		look = { skin = "#F1C9A5", hairIds = { 376548738 }, faceTexture = "rbxassetid://26424652", -- Brown Charmer Hair, Know-It-All Grin
			shirt = "rbxassetid://102959678094397", pants = "rbxassetid://72439591969493", muscle = 0.9,
			extras = { "whistle" }, extraColor = "#C8262C", tint = "#C8262C" } },
	-- (owner, prompt 25: +15% stamina regen on top of the coins, the old Cardio Coach's refill)
	{ id = "CardioCoach", rarity = "Uncommon", name = "Coach Nia", heightInches = 65, perk = { coins = 0.10, staminaRegen = 0.15 },
		perkText = "+10% coins, +15% stamina regen", picture = "trainer_stamina", idle = "hips", pose = "AbsAndThigh", line = "Drink water, then go!",
		icon = "rbxassetid://129465909046082", art = "rbxassetid://138377614470876",
		look = { skin = "#8D5A3C", hairIds = { 451220849 }, faceTexture = "rbxassetid://7074749", -- Lavender Updo, Chill
			shirt = "rbxassetid://75627226847033", pants = "rbxassetid://132200798598308", muscle = 0.7,
			extras = { "headband", "bottle" }, extraColor = "#F4F1EA", tint = "#2FAE55" } },
	{ id = "MoneyCoach", rarity = "Rare", name = "Coach Lou", heightInches = 72, frame = "Wide", perk = { gains = 0.15, maxStamina = 0.10 },
		perkText = "+15% EXP, +10% max stamina", picture = "trainer_coins", idle = "clipboard", pose = "SideChest", line = "Form first, then weight.",
		icon = "rbxassetid://92192772625761", art = "rbxassetid://131053188064620",
		look = { skin = "#E0AC7E", faceTexture = "rbxassetid://144080495", -- Smile (a buzz cut under the cap)
			shirt = "rbxassetid://115347278747243", pants = "rbxassetid://82450924223675", muscle = 0.8,
			extras = { "cap", "clipboard" }, extraColor = "#16161A", tint = "#E0B23A" } },
	{ id = "PumpCoach", rarity = "Epic", name = "Coach Rex", heightInches = 78, frame = "VTaper", shoulderBonus = 1.1, perk = { gains = 0.25, coins = 0.25 },
		perkText = "+25% EXP and coins", picture = "trainer_pump", idle = "crossed", pose = "FrontLatSpread", line = "Time to grow!",
		icon = "rbxassetid://92179967724810", art = "rbxassetid://122323729220125",
		look = { skin = "#5C3A21", faceTexture = "rbxassetid://83017053", -- bald, Man Face
			shirt = "rbxassetid://102922865828545", pants = "rbxassetid://92479669230797", muscle = 1.8,
			extras = { "belt", "wraps" }, extraColor = "#7A3FC8", tint = "#7A3FC8" } },
	-- 5) LEGENDARY: a veteran powerlifting coach, 6'9", very wide and thick (huge traps, thick waist, big forearms), a grey
	-- short beard and buzz cut; a black sleeveless hoodie with gold trim, a thick leather belt, chalk on his hands, wrist wraps
	{ id = "AtlasCoach", rarity = "Legendary", name = "Duke Ironside", heightInches = 81, frame = "Wide", shoulderBonus = 1.12,
		widths = { hips = 1.2, arms = 1.16, legs = 1.1, depth = 1.12 },
		perk = { gains = 0.40, coins = 0.40, progress = 0.10 }, perkText = "+40% EXP and coins, +10% progress",
		idle = "chalk", pose = "MostMuscular", line = "Lock in. No excuses.",
		icon = "rbxassetid://113681452937688", art = "rbxassetid://115748213011909",
		look = { skin = "#D29A72", faceTexture = "rbxassetid://83017053", -- Man Face, under a grey beard
			shirt = "rbxassetid://78957509596576", pants = "rbxassetid://96180676897868", muscle = 2.4, hair = "#8E8E94",
			extras = { "buzzcut", "beard", "hoodback", "bigbelt", "wraps", "chalk", "shoes" }, extraColor = "#F6C75A", tint = "#F6C75A",
			aura = "duke" } },
	-- 6) MYTHIC: an energetic strongwoman coach, 6'10", athletic and very muscular, a long high ponytail; a red and purple
	-- tracksuit top tied at the waist over a black training top, red knee sleeves, lightning bolts on the sleeves
	{ id = "BlazeCoach", rarity = "Mythic", name = "Volta", heightInches = 82, frame = "VTaper", shoulderBonus = 1.12,
		widths = { hips = 1.04, arms = 1.05, legs = 1.14, depth = 1.04 },
		perk = { gains = 0.70, coins = 0.70, progress = 0.20 }, perkText = "+70% EXP and coins, +20% progress",
		idle = "boxer", pose = "Guard", line = "Faster! Stronger! Again!",
		icon = "rbxassetid://114074076872071", art = "rbxassetid://129640648829938",
		look = { skin = "#A86B45", faceTexture = "rbxassetid://7074749", -- Chill
			shirt = "rbxassetid://111515590905276", pants = "rbxassetid://76817441798210", muscle = 2.5, hair = "#2A1A14",
			extras = { "ponytail", "tiedjacket", "kneesleeves", "shoes" }, extraColor = "#D8283E", extraColor2 = "#8A3AD0", tint = "#E8345A",
			aura = "volta" } },
	-- 7) SECRET: a mysterious mass monster, 7'2", a deep black hood hiding the face in shadow with two calm glowing white eyes;
	-- a black outfit with faint purple seams. "???" (a black silhouette) on the odds lists until you own him
	{ id = "ShadeCoach", rarity = "Secret", name = "The Shadow", heightInches = 86, frame = "VTaper", shoulderBonus = 1.25,
		widths = { hips = 1.1, arms = 1.12, legs = 1.12, depth = 1.12 },
		perk = { gains = 1.10, coins = 1.10, progress = 0.30 }, perkText = "+110% EXP and coins, +30% progress",
		idle = "watch", pose = "Crossed", line = "...", lines = { "...", "Train." },
		icon = "rbxassetid://79347691775252", art = "rbxassetid://97574058899490",
		look = { skin = "#7A5A48", faceTexture = nil,
			shirt = "rbxassetid://97781144083473", pants = "rbxassetid://135148080212416", muscle = 3.0,
			extras = { "deephood", "shoes" }, extraColor = "#0E0E11", extraColor2 = "#6E3FB0", tint = "#6E3FB0",
			aura = "shadow" } },
	-- 8) ETERNAL: a living statue, the top rank: 7'6", the biggest, golden ratio proportions at mass monster size, polished
	-- white marble skin with gold veins (marble: the statue's marble with our MaterialVariant), a gold laurel wreath, white and gold training shorts,
	-- gold wrist cuffs, bare feet
	{ id = "AeonCoach", rarity = "Eternal", name = "Atlas", heightInches = 90, frame = "VTaper", shoulderBonus = 1.3,
		widths = { hips = 1.06, arms = 1.12, legs = 1.12, depth = 1.12 },
		perk = { gains = 1.50, coins = 1.50, progress = 0.50 }, perkText = "+150% EXP and coins, +50% progress",
		idle = "flex", pose = "FrontDoubleBiceps", line = "Strength is forever.",
		icon = "rbxassetid://91786313487049", art = "rbxassetid://75461569868523",
		look = { skin = "#F7F3EC", faceTexture = "rbxassetid://7074749", -- Chill (calm, like a statue)
			marble = { color = "#F7F3EC", variant = "GymArc_GoldVeinMarble" }, material = "Marble",
			muscle = 3.2, shorts = "#F4F1EA", shortsTrim = "#F6C75A",
			extras = { "shorts", "laurel", "cuffs" }, extraColor = "#F6C75A", tint = "#FFF3C4", aura = "atlas" } },
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

-- The total boost of a list of equipped entries, each kind capped: { gains, coins, maxStamina, staminaRegen, progress }
-- (shares, 0.25 = +25%)
function Trainers.Bonus(entries)
	local total = { gains = 0, coins = 0, maxStamina = 0, staminaRegen = 0, progress = 0 }
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
	if p.staminaRegen then table.insert(parts, "+" .. pct(p.staminaRegen) .. " stamina regen") end
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
