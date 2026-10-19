-- Personal trainers (owner's feature run, task 7B; instead of pets. Plates the gym cat stays a gym NPC, not a follower).
-- A trainer is a normal-size coach (original look, clipboard in hand) who follows you and stands beside your machine while
-- you train. Hire one with coins by tapping his tile in the Trainers window, anywhere (the Trainer Desks at the front of
-- each gym open the same window); equip / unequip there too (TrainerClient), saved per player (data.trainers). 1 slot;
-- the Extra Trainer pass (Monetization, id 2032496303) gives a 2nd slot and the perks stack.
-- Every client draws every trainer itself (TrainerFollowClient) from the player attribute "Trainers" (the equipped ids):
-- plain parts and the character's own meshes only (no EditableMesh), other players' trainers hidden past RenderDistance.
local Trainers = {}

-- perk: gains = EXP x, regen = stamina refill x, coins = coins x, pump = the Pump meter fills this much faster and PUMPED
-- lasts this much longer (Gains.Pump). perkShort = the tile's line (owner's UI v2, mockup 06: perk and price only, no
-- names anywhere). picture = the portrait (Config/UI.Trainers).
-- look (owner, 14 Oct: real gym coaches, built from a HumanoidDescription by TrainerService):
--   skin, hairIds (Roblox's own free catalog hair, none = buzz / bald), faceTexture (the image of one of Roblox's own
--   faces, worn on a classic head: TrainerService), shirt / pants = our own clothing templates (images, Downloads-free, no brands; drawn by
--   scratchpad trainer_clothes.py: tracksuit, tank, polo, stringer, joggers, shorts; his skin color is painted under the
--   clothes, so the images have no see-through parts: TrainerFollowClient hides the muscle stages' skin layer), muscle = how built he looks (the
--   static muscle stages, share of the goal: 1 = fit; the Pump coach the biggest), extras = small part-built props
--   ("whistle", "headband", "bottle", "cap", "clipboard", "belt", "wraps"), extraColor = their color.
-- heightInches (owner, 19 Oct): his height, the players' height system (inches; 60 = 5'0"; GrowthSpurts caps players at 84 = 7'0"):
-- 1st in the shop 5'0", 2nd 5'5", 3rd 6'0", 4th 6'6". TrainerService scales his whole rig (NpcService.ApplyBody), widths kept.
Trainers.List = {
	{ id = "RookieCoach", name = "Rookie Coach", coachName = "Coach Sam", heightInches = 60, price = 300, perk = { gains = 1.05 }, perkText = "+5% EXP", perkShort = "+5% EXP",
		picture = "trainer_exp", color = "#E5413F",
		look = { skin = "#F1C9A5", hairIds = { 376548738 }, faceTexture = "rbxassetid://26424652", -- Brown Charmer Hair, Know-It-All Grin
			shirt = "rbxassetid://102959678094397", pants = "rbxassetid://72439591969493", muscle = 0.9,
			extras = { "whistle" }, extraColor = "#C8262C", tint = "#C8262C" } },
	{ id = "CardioCoach", name = "Cardio Coach", coachName = "Coach Nia", heightInches = 65, price = 450, perk = { regen = 1.1 }, perkText = "+10% stamina refill", perkShort = "+10% Stamina",
		picture = "trainer_stamina", color = "#5CC46B",
		look = { skin = "#8D5A3C", hairIds = { 451220849 }, faceTexture = "rbxassetid://7074749", -- Lavender Updo, Chill
			shirt = "rbxassetid://75627226847033", pants = "rbxassetid://132200798598308", muscle = 0.7,
			extras = { "headband", "bottle" }, extraColor = "#F4F1EA", tint = "#2FAE55" } },
	{ id = "MoneyCoach", name = "Money Coach", coachName = "Coach Lou", heightInches = 72, price = 600, perk = { coins = 1.05 }, perkText = "+5% coins", perkShort = "+5% Coins",
		picture = "trainer_coins", color = "#F2C64A",
		look = { skin = "#E0AC7E", faceTexture = "rbxassetid://144080495", -- Smile (a buzz cut under the cap)
			shirt = "rbxassetid://115347278747243", pants = "rbxassetid://82450924223675", muscle = 0.8,
			extras = { "cap", "clipboard" }, extraColor = "#16161A", tint = "#E0B23A" } },
	{ id = "PumpCoach", name = "Pump Coach", coachName = "Coach Rex", heightInches = 78, price = 800, perk = { pump = 1.25 }, perkText = "Pump fills 25% faster and lasts 25% longer", perkShort = "+25% Pump",
		picture = "trainer_pump", color = "#A06BE6",
		look = { skin = "#5C3A21", faceTexture = "rbxassetid://83017053", -- bald, Man Face
			shirt = "rbxassetid://102922865828545", pants = "rbxassetid://92479669230797", muscle = 1.8,
			extras = { "belt", "wraps" }, extraColor = "#7A3FC8", tint = "#7A3FC8" } },
}
Trainers.ById = {}
for _, trainer in ipairs(Trainers.List) do Trainers.ById[trainer.id] = trainer end

Trainers.Slots = 1                -- trainers following you at once
Trainers.ExtraSlotPass = "ExtraTrainer" -- the pass that adds a slot (Config.Monetization; off while monetization is off)
Trainers.DeskDistance = 8         -- the Trainer Desk prompt's reach (it opens the Trainers window)
Trainers.RenderDistance = 90      -- other players' trainers past this many studs aren't drawn
Trainers.FollowBehind = 3         -- studs behind you...
Trainers.FollowSide = 2.6         -- ...and to the side (slot 1 right, slot 2 left)
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

-- Slots a player has (1, or 2 with the Extra Trainer pass).
function Trainers.SlotsFor(hasPass: boolean): number
	return Trainers.Slots + (hasPass and 1 or 0)
end

-- The equipped list cleaned up: only owned, known ids, no doubles, at most `slots`.
function Trainers.CleanEquipped(equipped, owned, slots: number)
	local list, seen = {}, {}
	local ownedSet = {}
	for _, id in ipairs(type(owned) == "table" and owned or {}) do ownedSet[id] = true end
	for _, id in ipairs(type(equipped) == "table" and equipped or {}) do
		if #list >= slots then break end
		if Trainers.ById[id] and ownedSet[id] and not seen[id] then
			table.insert(list, id)
			seen[id] = true
		end
	end
	return list
end

return Trainers
