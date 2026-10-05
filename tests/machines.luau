local fs = require("@lune/fs")
local H = require("./harness")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
local Poses = H.module("ReplicatedStorage/Shared/Config/Poses")
local Muscles = H.module("ReplicatedStorage/Shared/Config/Muscles")
local client = fs.readFile(require("@lune/process").cwd .. "/src/StarterPlayerScripts/MachineClient.client.luau")
local builder = fs.readFile(require("@lune/process").cwd .. "/tools/builders/ProGym.luau")
print("Machines")
local pro = 0
for _, m in Machines.List do
	H.check(Poses[m.pose] ~= nil, m.id .. " pose " .. m.pose .. " exists")
	H.check(client:find("POSE_ANIMS%." .. m.pose .. " =") ~= nil, m.id .. " has a client animation")
	H.check(type(m.tiers) == "table" and #m.tiers == 8, m.id .. " has 8 tiers")
	for _, e in m.muscles do H.check(Muscles.ById[e.id] ~= nil and Muscles.Body[e.id] ~= nil, m.id .. " muscle " .. e.id) end
	if m.gym == "Pro" then
		pro += 1
		H.check(m.layout == "Center", m.id .. " stacks plates centered")
		H.check((Poses[m.pose].follow or "Hands") == "None", m.id .. " keeps hands free")
	end
end
H.check(pro == 11, "11 pro machines (" .. pro .. ")")
local all = Machines.TrainableMuscles(2)
H.check(all.Calves and all.Obliques, "Calves and Obliques trainable at Growth Spurt 2")
local starter = Machines.TrainableMuscles(1)
H.check(not starter.Calves and not starter.Obliques, "...but not before")
H.check(builder:find('BUILDERS%.HangingLegRaise') ~= nil, "hanging leg raise has its bar")
H.done()
