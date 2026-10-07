local fs = require("@lune/fs")
local H = require("./harness")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
local Poses = H.module("ReplicatedStorage/Shared/Config/Poses")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local client = fs.readFile(require("@lune/process").cwd .. "/src/StarterPlayer/StarterPlayerScripts/MachineClient.client.luau")
local builder = fs.readFile(require("@lune/process").cwd .. "/tools/builders/GymKit.luau")
print("Machines")
local pro = 0
for _, m in Machines.List do
	H.check(Poses[m.pose] ~= nil, m.id .. " pose " .. m.pose .. " exists")
	H.check(client:find("POSE_ANIMS%." .. m.pose .. " =") ~= nil, m.id .. " has a client animation")
	H.check(type(m.tiers) == "table" and #m.tiers == 12, m.id .. " has 12 tiers")
	for i, tier in m.tiers do
		local prev = m.tiers[i - 1]
		if prev then
			H.check(tier.gains > prev.gains and tier.unlockLevel > prev.unlockLevel and tier.weight > prev.weight,
				m.id .. " tier " .. i .. " is heavier, pays more and needs a higher level")
		end
		local perSide = 0
		for _, lb in tier.plates do
			H.check(Machines.Plates[lb] ~= nil, m.id .. " tier " .. i .. " plate " .. lb .. " exists")
			perSide += lb
		end
		if m.tiers == Machines.TierSets.Barbell or m.tiers == Machines.TierSets.HeavyBarbell then
			H.check(45 + 2 * perSide == tier.weight, m.id .. " tier " .. i .. " plates add up to " .. tier.weight)
		end
	end
	for _, e in m.muscles do H.check(Muscles.ById[e.id] ~= nil and Muscles.Body[e.id] ~= nil, m.id .. " muscle " .. e.id) end
	if m.gym == "Pro" then
		pro += 1
		H.check(m.layout == "Center", m.id .. " stacks plates centered")
		H.check((Poses[m.pose].follow or "Hands") == "None", m.id .. " keeps hands free")
		H.check(builder:find("GymKit%.Pro%." .. m.id .. " =") ~= nil, m.id .. " has a machine builder (GymKit.Pro)")
	elseif m.gym == "Starter" then
		H.check(builder:find("function GymKit%." .. m.id .. "%(") ~= nil, m.id .. " has a machine builder (GymKit)")
	end
end
H.check(pro == 11, "11 pro machines (" .. pro .. ")")
local all = Machines.TrainableMuscles(2)
H.check(all.Calves and all.Obliques, "Calves and Obliques trainable at Growth Spurt 2")
local starter = Machines.TrainableMuscles(1)
H.check(not starter.Calves, "...Calves not before")
H.check(Machines.TrainableMuscles(0).Obliques, "Obliques trainable from the start (the Crunch Bench)")
H.check(builder:find('cyl%(m, "HangBar"') ~= nil, "hanging leg raise has its bar")
H.done()
