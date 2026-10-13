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
-- names anywhere). picture = the portrait (Config/UI.Trainers). look = what the follower wears so he matches his picture:
-- skin, shirt (torso + upper arms painted), pants, hair color and a hat built from parts by TrainerService
-- ("cap" / "headband" / "visor" / "headphones") in hatColor. (name / coachName are kept for the code only.)
Trainers.List = {
	{ id = "RookieCoach", name = "Rookie Coach", coachName = "Coach Sam", price = 300, perk = { gains = 1.05 }, perkText = "+5% EXP", perkShort = "+5% EXP",
		picture = "trainer_exp", look = { skin = "#EED3B6", shirt = "#E5413F", pants = "#2B2B30", hair = "#5A3A26", hat = "cap", hatColor = "#D9302E" }, color = "#E5413F" },
	{ id = "CardioCoach", name = "Cardio Coach", coachName = "Coach Nia", price = 450, perk = { regen = 1.1 }, perkText = "+10% stamina refill", perkShort = "+10% Stamina",
		picture = "trainer_stamina", look = { skin = "#C89A70", shirt = "#5CC46B", pants = "#2B2B30", hair = "#4A3426", hat = "headband", hatColor = "#F4F1EA" }, color = "#5CC46B" },
	{ id = "MoneyCoach", name = "Money Coach", coachName = "Coach Lou", price = 600, perk = { coins = 1.05 }, perkText = "+5% coins", perkShort = "+5% Coins",
		picture = "trainer_coins", look = { skin = "#EED3B6", shirt = "#F2C64A", pants = "#2B2B30", hair = "#7A5A3A", hat = "visor", hatColor = "#E2B85A" }, color = "#F2C64A" },
	{ id = "PumpCoach", name = "Pump Coach", coachName = "Coach Rex", price = 800, perk = { pump = 1.25 }, perkText = "Pump fills 25% faster and lasts 25% longer", perkShort = "+25% Pump",
		picture = "trainer_pump", look = { skin = "#EED3B6", shirt = "#A06BE6", pants = "#2B2B30", hair = "#1E1E22", hat = "headphones", hatColor = "#1E1E22" }, color = "#A06BE6" },
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
Trainers.CheerCooldown = 9        -- seconds between two cheers from the same trainer
Trainers.CheerChance = 0.35       -- chance to cheer on a rep once the cooldown is over
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
