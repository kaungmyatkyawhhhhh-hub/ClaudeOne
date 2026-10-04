local H = require("./harness")
local Legends = H.module("ReplicatedStorage/Shared/Config/Legends")
local Titles = H.module("ReplicatedStorage/Shared/Config/Titles")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")
print("Legends")
H.check(#Legends.List == 8, "8 legends from the brief")
for _, l in Legends.List do
	local t = Titles.ById[Legends.TitleId(l.id)]
	H.check(t ~= nil and t.name == l.title, l.name .. " has a title")
	H.check(Titles.Check(t, { data = { legends = { met = { [l.id] = true } } } }), l.name .. " title unlocks when met")
	H.check(not Titles.Check(t, { data = { legends = { met = {} } } }), l.name .. " title locked otherwise")
	H.check(l.quest.count and l.quest.count > 0, l.name .. " quest has a goal")
	for _, m in l.quest.machines or {} do H.check(Machines.ById[m] ~= nil, l.name .. " machine " .. m) end
end
local seen = {}
for _, t in Titles.List do H.check(not seen[t.id], "title id unique " .. t.id); seen[t.id] = true end
H.done()
