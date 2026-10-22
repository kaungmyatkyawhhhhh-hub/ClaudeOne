-- Personal trainers (owner's feature run, task 7B; instead of pets). Since prompt 24 (21 Oct) they come from coin ROLLS at the
-- Trainer Agency (the desks at the front of each gym), like eggs in pet games: coins only (never Robux, no Robux luck), the
-- odds always shown, a pity counter. Everything about trainers is in this module.
-- A trainer is a coach who follows you and stands beside your machine while you train. Every client draws every trainer
-- itself (TrainerFollowClient) from the player attribute "Trainers" (the equipped entries, "PumpCoach,RookieCoach@g").
-- Saved per player (data.trainers, TrainerService; prompt 33): { copies = { copy }, equipped = { copy uid }, discovered,
-- nextUid, rolls, pity, autoDelete = { [rarity] = true }, bonus = { gains, coins, maxStamina, progress } (the equipped total,
-- written by TrainerService: Config.GrowthSpurts / Config.Alters and PlayerData read it) }. Trainers.Migrate reads every
-- older version.
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
	{ id = "Eternal", name = "Eternal", chance = 0.035, color = "#FFF3C4", color2 = "#F6C75A", reveal = "cosmic", announce = "banner", hidden = true }, -- (owner, 22 Oct: hidden until owned, like Secret)
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
-- the hood hides it), outfit (prompt 34: { shirt, pants = images made for the muscle stage meshes by
-- tools/trainer_outfits.py, sleeves = "none" | "short" | "long", legs = "shorts" | "long", shoes = a shoes-only classic Pants image for the feet, shirtColor / pantsColor = the images'
-- colors, for the elbow / knee balls under a sleeve or pants leg }, worn
-- by the muscle pieces themselves, Shared/Outfit; no shirt = bare: they show their muscles), muscle (the static muscle
-- stages, share of the goal), extras (part-built props, TrainerService: headband, bottle, cap, clipboard, chalk, cape, hood,
-- deephood, hoodback, crown, laurel, shoulderpads, shoes, buzzcut, beard, ponytail), gear (prompt 34: the planner's gear
-- meshes, Shared/Gear, fitted to the body: { kind = "Belt" | "Waistband" | "Wraps" | "Cuffs" | "Sleeves" | "Straps" | "Whistle", color,
-- trim, metal (a color), shiny = all metal }), extraColor, aura (TrainerAura preset), marble ({ color, variant }: a marble body, Atlas: white with gold veins,
-- Materials below), material (the classic head's material).
-- heightInches: the players' height system (60 = 5'0"; trainers may pass the players' 7'0" cap, up to MaxHeightInches);
-- TrainerService scales the rig, the widths with it (frame / shoulderBonus / widths = { hips, arms, legs, depth } on top).
-- idle: his stance while standing (TrainerFollowClient): crossed, hips, clipboard, chalk (claps chalk off, cracks his neck),
-- boxer (bounces on her toes, shadow-boxes), watch (arms crossed, turns his head to watch you), flex (a front double biceps
-- every ~8 s). line: what he says when you equip him (lines = several, said one after another, the later ones once a
-- session). pose: his roll reveal pose (PoseData, or "Crossed" / "Guard": tools/trainer_photos.luau). icon / art: the
-- rendered pictures (portrait, reveal), made in Studio from a fixed camera (tools/trainer_photos.luau + tools/trainer_icons.py);
-- nil = the 3D portrait (Shared.UI.TrainerPortrait).
-- (owner, 22 Oct) For a while there were NO pictures of trainers (the account got a warning and a ban for body pictures):
-- every trainer showed as his live 3D rig. (prompt 47, 22 Oct) The owner uploaded the planner's portraits himself, to
-- the Myanmar Builders Club group (Downloads\gym_arc_trainer_portraits): they're used again, set below by Portraits.
-- Never upload trainer pictures from here; the old ones to archive are in the vault note "GYM ARC - Uploaded images 21-22 Oct".
Trainers.MaxHeightInches = 90
Trainers.SilhouetteIcon = nil -- (owner, 22 Oct: no picture; the 3D rig in black instead)

-- (owner, 22 Oct) A chance as the players see it: always a percentage, never "1 in 1000". 1% and up as a whole number
-- ("50%", Common's 50.215 too), below 1% up to 3 decimals without trailing zeros ("0.6%", "0.15%", "0.035%").
function Trainers.ChanceText(chance: number): string
	if chance >= 1 then return string.format("%d%%", math.floor(chance + 0.5)) end
	local text = string.format("%.3f", chance):gsub("0+$", ""):gsub("%.$", "")
	return text .. "%"
end

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
		look = { skin = "#F1C9A5", hairIds = { 376548738 }, faceTexture = "rbxassetid://26424652", -- Brown Charmer Hair, Know-It-All Grin
			outfit = { shirt = "rbxassetid://139862937769412", pants = "rbxassetid://110347260992708", sleeves = "long", legs = "long", shoes = "rbxassetid://134411403634005", shirtColor = "#C8262C", pantsColor = "#1E1E22" },
			muscle = 0.9, extras = {}, gear = { { kind = "Whistle", color = "#C8262C" }, { kind = "Sneakers", color = "#C8262C" } }, extraColor = "#C8262C", tint = "#C8262C" } },
	-- (owner, prompt 25: +15% stamina regen on top of the coins, the old Cardio Coach's refill)
	{ id = "CardioCoach", rarity = "Uncommon", name = "Coach Nia", heightInches = 65, perk = { coins = 0.10, staminaRegen = 0.15 },
		perkText = "+10% coins, +15% stamina regen", picture = "trainer_stamina", idle = "hips", pose = "AbsAndThigh", line = "Drink water, then go!",
		look = { skin = "#8D5A3C", hairIds = { 451220849 }, faceTexture = "rbxassetid://7074749", -- Lavender Updo, Chill
			outfit = { shirt = "rbxassetid://122244133593957", pants = "rbxassetid://122244133593957", sleeves = "none", legs = "shorts", shoes = "rbxassetid://130682660705057", shirtColor = "#2FAE55", pantsColor = "#2FAE55" },
			muscle = 0.7, extras = { "headband", "bottle" }, gear = { { kind = "Whistle", color = "#2FAE55" }, { kind = "Sneakers", color = "#2FAE55" } }, extraColor = "#F4F1EA", tint = "#2FAE55" } },
	{ id = "MoneyCoach", rarity = "Rare", name = "Coach Lou", heightInches = 72, frame = "Wide", perk = { gains = 0.15, maxStamina = 0.10 },
		perkText = "+15% EXP, +10% max stamina", picture = "trainer_coins", idle = "clipboard", pose = "SideChest", line = "Form first, then weight.",
		look = { skin = "#E0AC7E", faceTexture = "rbxassetid://144080495", -- Smile (a buzz cut under the cap)
			outfit = { shirt = "rbxassetid://71165572097233", pants = "rbxassetid://110347260992708", sleeves = "short", legs = "long", shoes = "rbxassetid://73930285993287", shirtColor = "#E8C21C", pantsColor = "#1E1E22" },
			muscle = 0.8, extras = { "cap", "clipboard" }, gear = { { kind = "Whistle", color = "#16161A" }, { kind = "Sneakers", color = "#E8C21C" } }, extraColor = "#16161A", tint = "#E0B23A" } },
	{ id = "PumpCoach", rarity = "Epic", name = "Coach Rex", heightInches = 78, frame = "VTaper", shoulderBonus = 1.1, perk = { gains = 0.25, coins = 0.25 },
		perkText = "+25% EXP and coins", picture = "trainer_pump", idle = "crossed", pose = "FrontLatSpread", line = "Time to grow!",
		look = { skin = "#5C3A21", faceTexture = "rbxassetid://83017053", -- bald, Man Face
			outfit = { shirt = "rbxassetid://106691440081103", pants = "rbxassetid://110347260992708", sleeves = "none", legs = "shorts", shoes = "rbxassetid://101444393193455", shirtColor = "#7A3FC8", pantsColor = "#1E1E22" },
			muscle = 1.8, extras = {}, gear = { { kind = "Whistle", color = "#7A3FC8" }, { kind = "Belt" }, { kind = "Wraps", color = "#7A3FC8" }, { kind = "Sneakers", color = "#7A3FC8" } },
			extraColor = "#7A3FC8", tint = "#7A3FC8" } },
	-- 5) LEGENDARY: a veteran powerlifting coach, 6'9", very wide and thick (huge traps, thick waist, big forearms), a grey
	-- short beard and buzz cut; a black sleeveless hoodie with gold trim, a thick leather belt, chalk on his hands, wrist wraps
	{ id = "AtlasCoach", rarity = "Legendary", name = "Duke Ironside", heightInches = 81, frame = "Wide", shoulderBonus = 1.12,
		widths = { hips = 1.2, arms = 1.16, legs = 1.1, depth = 1.12 },
		perk = { gains = 0.40, coins = 0.40, progress = 0.10 }, perkText = "+40% EXP and coins, +10% progress",
		idle = "chalk", pose = "MostMuscular", line = "Lock in. No excuses.",
		look = { skin = "#D29A72", faceTexture = "rbxassetid://83017053", -- Man Face, under a grey beard
			outfit = { shirt = "rbxassetid://92310450517732", pants = "rbxassetid://92310450517732", sleeves = "none", legs = "shorts", shirtColor = "#16161A", pantsColor = "#16161A" },
			muscle = 2.4, hair = "#8E8E94", extras = { "buzzcut", "beard", "hoodback", "chalk", "shoes" },
			gear = { { kind = "Belt", color = "#2A1A10", trim = "#F6C75A" }, { kind = "Wraps", color = "#16161A", trim = "#F6C75A" },
				{ kind = "Sneakers", color = "#16161A", trim = "#F6C75A" } },
			extraColor = "#F6C75A", tint = "#F6C75A",
			aura = "duke" } },
	-- 6) MYTHIC: an energetic strongwoman coach, 6'10", athletic and very muscular, a long high ponytail; a red and purple
	-- tracksuit top tied at the waist over a black training top, red knee sleeves, lightning bolts on the sleeves
	{ id = "BlazeCoach", rarity = "Mythic", name = "Volta", heightInches = 82, frame = "VTaper", shoulderBonus = 1.12,
		widths = { hips = 1.04, arms = 1.05, legs = 1.14, depth = 1.04 },
		perk = { gains = 0.70, coins = 0.70, progress = 0.20 }, perkText = "+70% EXP and coins, +20% progress",
		idle = "boxer", pose = "Guard", line = "Faster! Stronger! Again!",
		look = { skin = "#A86B45", faceTexture = "rbxassetid://7074749", -- Chill
			outfit = { shirt = "rbxassetid://140621946283610", pants = "rbxassetid://140621946283610", sleeves = "none", legs = "shorts", shirtColor = "#141418", pantsColor = "#141418" },
			muscle = 2.5, hair = "#2A1A14", extras = { "ponytail", "shoes" },
			gear = { { kind = "Belt", color = "#16161A", trim = "#D8283E" }, { kind = "Sleeves", color = "#D8283E", trim = "#8A3AD0" },
				{ kind = "Sneakers", color = "#16161A", trim = "#D8283E" } },
			extraColor = "#D8283E", extraColor2 = "#8A3AD0", tint = "#E8345A",
			aura = "volta" } },
	-- 7) SECRET: a mysterious mass monster, 7'2", a deep black hood hiding the face in shadow with two calm glowing white eyes;
	-- a black outfit with faint purple seams. "???" (a black silhouette) on the odds lists until you own him
	{ id = "ShadeCoach", rarity = "Secret", name = "The Shadow", heightInches = 86, frame = "VTaper", shoulderBonus = 1.25,
		widths = { hips = 1.1, arms = 1.12, legs = 1.12, depth = 1.12 },
		perk = { gains = 1.10, coins = 1.10, progress = 0.30 }, perkText = "+110% EXP and coins, +30% progress",
		idle = "watch", pose = "Crossed", line = "...", lines = { "...", "Train." },
		look = { skin = "#7A5A48", faceTexture = nil,
			outfit = { shirt = "rbxassetid://105247065422618", pants = "rbxassetid://105247065422618", sleeves = "long", legs = "shorts", shirtColor = "#0E0E11", pantsColor = "#0E0E11" },
			muscle = 3.0, extras = { "deephood", "shoes" }, gear = { { kind = "Sneakers", color = "#0E0E11", trim = "#6E3FB0", sole = "#2A2A30" } }, extraColor = "#0E0E11", extraColor2 = "#6E3FB0", tint = "#6E3FB0",
			aura = "shadow" } },
	-- 8) ETERNAL: a living statue, the top rank: 7'6", the biggest, golden ratio proportions at mass monster size, polished
	-- white marble skin with gold veins (marble: the statue's marble with our MaterialVariant), a gold laurel wreath, white and gold training shorts,
	-- gold wrist cuffs, bare feet
	{ id = "AeonCoach", rarity = "Eternal", name = "Atlas", heightInches = 90, frame = "VTaper", shoulderBonus = 1.3,
		widths = { hips = 1.06, arms = 1.12, legs = 1.12, depth = 1.12 },
		perk = { gains = 1.50, coins = 1.50, progress = 0.50 }, perkText = "+150% EXP and coins, +50% progress",
		idle = "flex", pose = "FrontDoubleBiceps", line = "Strength is forever.",
		look = { skin = "#F7F3EC", faceTexture = "rbxassetid://7074749", -- Chill (calm, like a statue)
			marble = { color = "#F7F3EC", variant = "GymArc_GoldVeinMarble" }, material = "Marble",
			outfit = { pants = "rbxassetid://112751620100083", legs = "shorts", pantsColor = "#F4F1EA" },
			muscle = 3.2, extras = { "laurel" }, gear = { { kind = "Cuffs", color = "#F6C75A", trim = "#FFF3C4", shiny = true }, { kind = "Waistband", color = "#F6C75A", shiny = true },
				{ kind = "Sneakers", color = "#F7F3EC", trim = "#F6C75A" } },
			extraColor = "#F6C75A", tint = "#FFF3C4", aura = "atlas" } },
}
Trainers.ById = {}
Trainers.ByRarity = {}
-- (prompt 47) the owner's portraits (group images): icon = waist-up (tiles, chips), art = full body (the roll reveal)
Trainers.Portraits = {
	RookieCoach = { icon = "rbxassetid://85368805560994", art = "rbxassetid://127629178928260" }, -- 01_coach_sam
	CardioCoach = { icon = "rbxassetid://136952307979554", art = "rbxassetid://113229850140237" }, -- 02_coach_nia
	MoneyCoach = { icon = "rbxassetid://136196635327153", art = "rbxassetid://90927356355240" }, -- 03_coach_lou
	PumpCoach = { icon = "rbxassetid://115354782548847", art = "rbxassetid://105901662457784" }, -- 04_coach_rex
	AtlasCoach = { icon = "rbxassetid://119463367552625", art = "rbxassetid://79742447995436" }, -- 05_duke_ironside
	BlazeCoach = { icon = "rbxassetid://113071892213133", art = "rbxassetid://80006635174776" }, -- 06_volta
	ShadeCoach = { icon = "rbxassetid://94430068464539", art = "rbxassetid://85156645624080" }, -- 07_the_shadow
	AeonCoach = { icon = "rbxassetid://78669611530685", art = "rbxassetid://80184899472119" }, -- 08_atlas
}
for index, trainer in ipairs(Trainers.List) do
	local portrait = Trainers.Portraits[trainer.id]
	if portrait then trainer.icon, trainer.art = portrait.icon, portrait.art end
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
-- Equipped entries (what every client reads from the player attribute "Trainers"): "PumpCoach" = BASE, "PumpCoach@3" = his
-- 3rd stage (BEAST-MODE). (Old saves: "PumpCoach@g" = a Golden = IRON-BORN.)
function Trainers.Entry(id: string, stage: number?): string
	stage = math.clamp(math.floor(tonumber(stage) or 1), 1, #Trainers.Stages)
	return if stage <= 1 then id else id .. "@" .. stage
end
-- -> id (nil = not a trainer), stage (1 = BASE)
function Trainers.ParseEntry(entry: string): (string?, number)
	if type(entry) ~= "string" then return nil, 1 end
	local id, tag = string.match(entry, "^([%w_]+)@?(%w*)$")
	if not id or not Trainers.ById[id] then return nil, 1 end
	if tag == "g" then return id, 2 end
	local stage = tonumber(tag) or 1
	return id, math.clamp(math.floor(stage), 1, #Trainers.Stages)
end

------------------------------------------------------------------------
-- (prompt 33, 22 Oct) LEVELS and EVOLUTIONS. They replace Golden (anyone who made a Golden has that trainer as IRON-BORN).
-- Every trainer you own is its own copy with its own stage and level:
--   copy = { u = a number unique for you, id = the trainer, s = stage (1 BASE .. 5 LIMITLESS), l = level (1-20), x = EXP into it }
-- * Levels: the EQUIPPED (following) trainers gain trainer EXP from your reps (RepXp: more on heavier weights); every level
--   adds LevelBonus to that trainer's boost (Lv 20 = +20%). Lv 1 -> 20 again at every stage.
-- * Evolutions: 3 copies of the same trainer at the same stage -> 1 at the next stage (x2 the boost each stage), keeping the
--   highest level of the 3. No level needed. One LIMITLESS = 81 BASE copies.
-- * A player only knows the names of the stages they've reached (discovered); the next one is "???" until then.
------------------------------------------------------------------------
-- color = the stage's bright color (border, name); base = the tile's dark base; hex = the hex mesh tint
Trainers.Stages = {
	{ id = "Base", name = "BASE", mult = 1, color = "#5A9BFF", base = "#0B1638", hex = "#2C4F9A", from = "FROM ROLLS" },
	{ id = "IronBorn", name = "IRON-BORN", mult = 2, color = "#FF8A2A", base = "#2A1006", hex = "#8A3A12", from = "3x BASE" },
	{ id = "BeastMode", name = "BEAST-MODE", mult = 4, color = "#6BFF4F", base = "#062010", hex = "#1F7A2A", from = "3x IRON-BORN" },
	{ id = "Colossus", name = "COLOSSUS", mult = 8, color = "#5CC8FF", base = "#061A36", hex = "#1F5A9A", from = "3x BEAST-MODE" },
	{ id = "Limitless", name = "LIMITLESS", mult = 16, color = "#E070FF", base = "#1A0830", hex = "#6A2A9A", from = "3x COLOSSUS", rainbow = true },
}
-- (prompt 47) the planner's backgrounds (group images): hex = the tile's base (dark hue, hex mesh, glow), evo = the stage's
-- effect layered on top (BASE: the radial light rays)
Trainers.StageArt = {
	Base = { hex = "rbxassetid://98357224346088", evo = "rbxassetid://86921753694454" },
	IronBorn = { hex = "rbxassetid://87942072991382", evo = "rbxassetid://101316695673258" },
	BeastMode = { hex = "rbxassetid://88569472894025", evo = "rbxassetid://121075153778167" },
	Colossus = { hex = "rbxassetid://135689867753297", evo = "rbxassetid://85358058900127" },
	Limitless = { hex = "rbxassetid://87579663515335", evo = "rbxassetid://78744780144225" },
}
Trainers.StageById = {}
for index, stage in ipairs(Trainers.Stages) do
	stage.index = index
	Trainers.StageById[stage.id] = stage
end
Trainers.EvolveCount = 3          -- copies of the same trainer at the same stage that make one of the next
Trainers.MaxLevel = 20
Trainers.LevelBonus = 0.01        -- +1% of his boost per level
Trainers.MaxCopies = 400          -- trainers kept (a roll past this pays out like an auto-deleted one)
Trainers.FollowerScalePerStage = 0.03 -- the follower is 3% bigger per stage
Trainers.FlushSeconds = 10        -- trainer EXP is saved this often (and on every level up)

-- Trainer EXP from `level` to the next one, at a stage. Lv 1 -> 20 in about 20-30 minutes of reps at BASE (tests/trainers),
-- a bit slower at higher stages.
function Trainers.LevelXp(level: number, stage: number?): number
	return math.floor((100 + 20 * level) * (1 + 0.2 * ((stage or 1) - 1)) + 0.5)
end
-- Trainer EXP from one rep at a weight tier (its gains multiplier: x1 empty bar ... x21.7 the top Pro tier)
function Trainers.RepXp(gains: number?): number
	return 2 * math.sqrt(math.max(tonumber(gains) or 1, 0))
end

local function cleanCopy(c)
	if type(c) ~= "table" or type(c.id) ~= "string" or not Trainers.ById[c.id] or type(c.u) ~= "number" then return nil end
	return {
		u = math.floor(c.u), id = c.id,
		s = math.clamp(math.floor(tonumber(c.s) or 1), 1, #Trainers.Stages),
		l = math.clamp(math.floor(tonumber(c.l) or 1), 1, Trainers.MaxLevel),
		x = math.max(0, tonumber(c.x) or 0),
	}
end

-- The saved state, from any version: { copies, equipped = { u }, discovered = { [stage id] = true }, nextUid, rolls, pity,
-- autoDelete, bonus }. Before prompt 33: owned = { [id] = count } (before prompt 24: a list of ids), golden = { [id] = count }
-- (each Golden -> one IRON-BORN), equipped = { "PumpCoach" | "PumpCoach@g" }.
function Trainers.Migrate(t)
	t = type(t) == "table" and t or {}
	local copies, nextUid = {}, math.max(1, math.floor(tonumber(t.nextUid) or 1))
	local equipped = {}
	local function add(id, stage)
		local copy = { u = nextUid, id = id, s = stage, l = 1, x = 0 }
		nextUid += 1
		table.insert(copies, copy)
		return copy
	end
	-- (an old save may also get an empty `copies` from the data template: the old counts win while it's empty)
	local function hasOld()
		for _, key in ipairs({ "owned", "golden" }) do
			if type(t[key]) == "table" and next(t[key]) ~= nil then return true end
		end
		return false
	end
	if type(t.copies) == "table" and (#t.copies > 0 or not hasOld()) then
		local seen = {}
		for _, raw in ipairs(t.copies) do
			local copy = cleanCopy(raw)
			if copy and not seen[copy.u] then
				seen[copy.u] = true
				table.insert(copies, copy)
				nextUid = math.max(nextUid, copy.u + 1)
			end
		end
		for _, u in ipairs(type(t.equipped) == "table" and t.equipped or {}) do
			if type(u) == "number" and seen[u] then table.insert(equipped, u) end
		end
	else
		local owned = t.owned
		if type(owned) == "table" and #owned > 0 then
			local map = {}
			for _, id in ipairs(owned) do
				if Trainers.ById[id] then map[id] = (map[id] or 0) + 1 end
			end
			owned = map
		end
		-- (in the trainers' list order, so the uids come out the same every time)
		for _, trainer in ipairs(Trainers.List) do
			for _ = 1, math.min(math.floor(tonumber(type(owned) == "table" and owned[trainer.id]) or 0), Trainers.MaxCopies) do add(trainer.id, 1) end
			for _ = 1, math.min(math.floor(tonumber(type(t.golden) == "table" and t.golden[trainer.id]) or 0), Trainers.MaxCopies) do add(trainer.id, 2) end
		end
		local used = {}
		for _, entry in ipairs(type(t.equipped) == "table" and t.equipped or {}) do
			local id, stage = Trainers.ParseEntry(entry)
			for _, copy in ipairs(copies) do
				if id and copy.id == id and copy.s == stage and not used[copy.u] then
					used[copy.u] = true
					table.insert(equipped, copy.u)
					break
				end
			end
		end
	end
	local discovered = { Base = true }
	if type(t.discovered) == "table" then
		for id in pairs(t.discovered) do
			if Trainers.StageById[id] then discovered[id] = true end
		end
	end
	for _, copy in ipairs(copies) do discovered[Trainers.Stages[copy.s].id] = true end
	return {
		copies = copies, equipped = equipped, discovered = discovered, nextUid = nextUid,
		rolls = tonumber(t.rolls) or 0, pity = tonumber(t.pity) or 0,
		autoDelete = type(t.autoDelete) == "table" and t.autoDelete or {},
		bonus = type(t.bonus) == "table" and t.bonus or nil,
	}
end

-- [u] = copy
function Trainers.CopyByUid(state): { [number]: any }
	local map = {}
	for _, copy in ipairs(state.copies) do map[copy.u] = copy end
	return map
end

-- The equipped list cleaned up: copies you still have, each once, at most `slots`; -> uids, copies
function Trainers.CleanEquipped(state, slots: number): ({ number }, { any })
	local map = Trainers.CopyByUid(state)
	local uids, list, used = {}, {}, {}
	for _, u in ipairs(state.equipped or {}) do
		if #uids >= slots then break end
		local copy = map[u]
		if copy and not used[u] then
			used[u] = true
			table.insert(uids, u)
			table.insert(list, copy)
		end
	end
	return uids, list
end

-- A copy's boost multiplier: its stage times its level bonus
function Trainers.CopyMultiplier(copy): number
	local stage = Trainers.Stages[copy.s or 1] or Trainers.Stages[1]
	return stage.mult * (1 + Trainers.LevelBonus * (copy.l or 1))
end

-- The total boost of the equipped copies, each kind capped: { gains, coins, maxStamina, staminaRegen, progress } (0.25 = +25%)
function Trainers.Bonus(copies)
	local total = { gains = 0, coins = 0, maxStamina = 0, staminaRegen = 0, progress = 0 }
	for _, copy in ipairs(copies or {}) do
		local trainer = Trainers.ById[copy.id]
		if trainer then
			local m = Trainers.CopyMultiplier(copy)
			for kind, amount in pairs(trainer.perk) do total[kind] = (total[kind] or 0) + amount * m end
		end
	end
	for kind, amount in pairs(total) do total[kind] = math.min(amount, Trainers.BoostCap) end
	return total
end

-- One copy's boost as lines: { { kind, pct } } in the order EXP, coins, progress, max stamina, stamina regen
function Trainers.PerkLines(trainer, copy): { { kind: string, pct: number } }
	local m = if copy then Trainers.CopyMultiplier(copy) else 1
	local out = {}
	for _, kind in ipairs({ "gains", "coins", "progress", "maxStamina", "staminaRegen" }) do
		local amount = trainer.perk[kind]
		if amount then table.insert(out, { kind = kind, pct = math.floor(amount * m * 100 + 0.5) }) end
	end
	return out
end

-- The perk line of a trainer (a copy: with its stage and level)
function Trainers.PerkText(trainer, copy): string
	if not copy then return trainer.perkText end
	local names = { gains = "EXP", coins = "coins", progress = "progress", maxStamina = "max stamina", staminaRegen = "stamina regen" }
	local parts = {}
	for _, line in ipairs(Trainers.PerkLines(trainer, copy)) do table.insert(parts, "+" .. line.pct .. "% " .. names[line.kind]) end
	return table.concat(parts, ", ")
end

-- The other copies a copy evolves with: the same trainer at the same stage (it first), -> list (up to EvolveCount)
function Trainers.EvolveSet(state, copy): { any }
	local set = { copy }
	if copy.s >= #Trainers.Stages then return set end
	local equippedSet = {}
	for _, u in ipairs(state.equipped or {}) do equippedSet[u] = true end
	local others = {}
	for _, c in ipairs(state.copies) do
		if c ~= copy and c.u ~= copy.u and c.id == copy.id and c.s == copy.s then table.insert(others, c) end
	end
	-- (the ones not following you first, then the highest levels)
	table.sort(others, function(a, b)
		local ea, eb = equippedSet[a.u] == true, equippedSet[b.u] == true
		if ea ~= eb then return not ea end
		if a.l ~= b.l then return a.l > b.l end
		return a.u < b.u
	end)
	for _, c in ipairs(others) do
		if #set >= Trainers.EvolveCount then break end
		table.insert(set, c)
	end
	return set
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
