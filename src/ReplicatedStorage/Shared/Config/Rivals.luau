-- NPC rivals (owner's feature run, task 6): one named rival per gym, original characters. They train on their gym's
-- machines like the other regulars (GymGoerService; tag GymNpc, attribute Gym). Talk to one (prompt "Challenge") for a
-- short challenge card, accept, then beat his record: a full set on his lift at a heavier weight, or an arm wrestling
-- match against him (pick him at any arm wrestling table). RivalService checks it all on the server.
-- Gyms already open by Growth Spurt (beach at 1, pro at 3 since prompt 58), so a rival is an EXTRA goal: beating one gives coins and a
-- title and points you to the next rival; it never opens a gym. The numbers rise in the order the gyms open:
-- starter < beach < pro.
-- Size: every rival has ONE size, set when he is built (look.scale here; Dante: GymGoerService's giant, 8'0"), and
-- NpcService.FreezeScale stops any rescale after that (no growing or shrinking near players or while training).
local Rivals = {}

Rivals.PromptDistance = 8
Rivals.SetReps = 10      -- a lift challenge needs a full set: this many reps in a row at the same weight
Rivals.SetGap = 15       -- seconds: a longer pause between two reps starts a new set
Rivals.LoseLineEvery = 30 -- seconds: the "come back stronger" line at most this often
Rivals.BubbleSeconds = 4.5 -- how long a rival's line shows above his head
Rivals.HoldSeconds = 10    -- a rival stops walking and faces you this long when you open his card

-- challenge.kind: "lift" = SetReps reps in a row on machineId at MORE than record lb (copies of the machine in other
-- gyms count, they share the MachineId); "arm" = win an arm wrestling match against him (strength / taps as
-- Social.ArmWrestle.Npcs).
-- look: how the builder (tools/builders/Rivals) dresses him; Roblox-made catalog items (same ids as tools/builders/NPCs).
Rivals.List = {
	{
		id = "Benny", name = "Benny", gym = "Starter", gymName = "Starter gym",
		look = { skin = "#E0AC69", hair = 376524487, shirt = 382538059, pants = 382538503, width = 1.15,
			spot = Vector3.new(4, 0.15, -30) },
		challenge = { kind = "lift", machineId = "FlatBench", record = 95 },
		reward = { coins = 150, title = "BeatBenny" },
		lines = {
			intro = "Think you can out-bench me? Show me a full set.",
			win = "Not bad, rookie. Not bad at all!",
			lose = "Close one! Come back stronger.",
			beaten = "You got me fair and square. Rematch soon?",
		},
		next = "Next rival: Coral at the beach gym (opens at Growth Spurt 1).",
	},
	{
		id = "Coral", name = "Coral", gym = "Beach", gymName = "Beach gym",
		look = { skin = "#C68642", hair = 16630147, shirt = 382537702, pants = 382537806, width = 1.1,
			spot = Vector3.new(14, 0.3, 192) },
		challenge = { kind = "arm", strength = 1.25, taps = { 8, 9.5 } },
		reward = { coins = 300, title = "BeatCoral" },
		lines = {
			intro = "Grip strength rules the beach. Arm wrestle me!",
			win = "Wow, what a grip! You earned that one.",
			lose = "Good try! Train those forearms and come back.",
			beaten = "Ready for a rematch anytime.",
		},
		next = "Next rival: Dante in the pro gym (opens at Growth Spurt 3).",
	},
	{
		id = "Dante", name = "Dante", gym = "Pro", gymName = "Pro gym",
		-- (already in the place: the pro gym's 8'0" giant, GymGoerService)
		challenge = { kind = "lift", machineId = "SquatRack", record = 315 },
		reward = { coins = 600, title = "BeatDante" },
		lines = {
			intro = "Everyone starts tiny. Even me. Can you out-squat me?",
			win = "Whoa. You're the real deal now.",
			lose = "Come back stronger. I'll be right here.",
			beaten = "Respect. Keep growing.",
		},
		next = "You beat every rival in town!",
	},
}
Rivals.ById = {}
for _, rival in ipairs(Rivals.List) do Rivals.ById[rival.id] = rival end

-- The NpcService.Build spec for a rival's look. The ONE place his size comes from: the builder makes him with it, and the
-- arm wrestling copy that sits down at a table uses it too (same height, width and clothes).
function Rivals.BuildSpec(rival): any
	local look = rival.look
	if not look then return nil end
	return {
		name = rival.name, skin = look.skin, shirtId = look.shirt, pantsId = look.pants, hairIds = { look.hair },
		scale = { height = look.height or 1, width = look.width or 1, depth = look.depth or look.width or 1, head = 1 },
	}
end

-- The arm wrestling opponent id for a rival ("Rival_Coral"), and back.
function Rivals.ArmId(rival): string return "Rival_" .. rival.id end
function Rivals.FromArmId(id): any
	return type(id) == "string" and Rivals.ById[(string.match(id, "^Rival_(.+)$") or "")] or nil
end

-- Does this finished set beat the rival's record? (lift challenges)
function Rivals.BeatsLift(rival, machineId: string, weight: number, reps: number): boolean
	local c = rival.challenge
	return c.kind == "lift" and machineId == c.machineId and reps >= Rivals.SetReps and weight > c.record
end

-- The challenge in one short line for the card.
function Rivals.ChallengeText(rival, machineName: string?): string
	local c = rival.challenge
	if c.kind == "arm" then return "Win an arm wrestling match against " .. rival.name .. ". Sit at an arm wrestling table and pick " .. rival.name .. "." end
	return "Do a full set (" .. Rivals.SetReps .. " reps) on the " .. (machineName or c.machineId) .. " with more than " .. c.record .. " lb."
end

return Rivals
