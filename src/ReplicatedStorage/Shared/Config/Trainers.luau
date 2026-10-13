-- Personal trainers (owner's feature run, task 7B; instead of pets. Plates the gym cat stays a gym NPC, not a follower).
-- A trainer is a normal-size coach (original look, clipboard in hand) who follows you and stands beside your machine while
-- you train. Hire one with coins at a Trainer Desk at the front of each gym (TrainerService checks it), equip / unequip in
-- the Trainers panel (TrainerClient), saved per player (data.trainers). 1 slot; the Extra Trainer pass (Monetization,
-- off for now) gives a 2nd slot and the perks stack.
-- Every client draws every trainer itself (TrainerFollowClient) from the player attribute "Trainers" (the equipped ids):
-- plain parts and the character's own meshes only (no EditableMesh), other players' trainers hidden past RenderDistance.
local Trainers = {}

-- perk: gains = EXP x, regen = stamina refill x, coins = coins x, pump = the Pump meter fills this much faster and PUMPED
-- lasts this much longer (Gains.Pump). Looks: catalog clothing / hair ids are Roblox-made items (tools/builders/NPCs).
Trainers.List = {
	{ id = "RookieCoach", name = "Rookie Coach", coachName = "Coach Sam", price = 300, perk = { gains = 1.05 }, perkText = "+5% EXP",
		look = { skin = "#F1C27D", hair = 13477818, shirt = 382537702, pants = 382538503 }, color = "#2E9E4F" },
	{ id = "CardioCoach", name = "Cardio Coach", coachName = "Coach Nia", price = 450, perk = { regen = 1.1 }, perkText = "+10% stamina refill",
		look = { skin = "#8D5524", hair = 62724852, shirt = 4047886060, pants = 382537950 }, color = "#1F5FBF" },
	{ id = "MoneyCoach", name = "Money Coach", coachName = "Coach Lou", price = 600, perk = { coins = 1.05 }, perkText = "+5% coins",
		look = { skin = "#E0AC69", hair = 4637254498, shirt = 144076436, pants = 382537569 }, color = "#E8C21C" },
	{ id = "PumpCoach", name = "Pump Coach", coachName = "Coach Rex", price = 800, perk = { pump = 1.25 }, perkText = "Pump fills 25% faster and lasts 25% longer",
		look = { skin = "#C68642", hair = 376524487, shirt = 382538059, pants = 144076760 }, color = "#D7262E" },
}
Trainers.ById = {}
for _, trainer in ipairs(Trainers.List) do Trainers.ById[trainer.id] = trainer end

Trainers.Slots = 1                -- trainers following you at once
Trainers.ExtraSlotPass = "ExtraTrainer" -- the pass that adds a slot (Config.Monetization; off while monetization is off)
Trainers.DeskDistance = 8         -- how close to a Trainer Desk you must be to hire
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
