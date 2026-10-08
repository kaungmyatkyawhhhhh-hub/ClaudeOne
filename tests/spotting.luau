local H = require("./harness")
local Spotting = H.module("ReplicatedStorage/Shared/Config/Spotting")
local Machines = H.module("ReplicatedStorage/Shared/Config/Machines")

local function near(a, b) return math.abs(a - b) < 1e-9 end

print("Boost table (owner's numbers)")
local base = { 1.10, 1.20, 1.30, 1.40, 1.50 }
for count = 1, 5 do
	H.check(near(Spotting.BoostFor(count, 0), base[count]), count .. " spotters, none clicking = x" .. base[count])
	H.check(near(Spotting.BoostFor(count, count), base[count] + 0.15), count .. " spotters, all clicking = x" .. base[count] + 0.15)
end
H.check(near(Spotting.BoostFor(2, 1), 1.20 + 0.15 * 0.5), "2 spotters, 1 clicking = x1.275 (shared by the fraction)")
H.check(Spotting.BoostFor(0, 0) == 1, "no spotters = x1")

print("Spot types")
for _, machine in Machines.List do
	if machine.trains == "Stamina" then
		H.check(machine.spotType == nil, machine.id .. " (cardio) can't be spotted")
	else
		H.check(machine.spotType == "hands" or machine.spotType == "hype", machine.id .. " has a spot type")
	end
end
for _, id in { "FlatBench", "InclineBench", "SquatRack", "OverheadPress" } do
	H.check(Machines.ById[id].spotType == "hands", id .. " is hands-on")
end
H.check(Machines.ById.BicepCurl.spotType == "hype", "curls are hype")

print("Hands spots by count")
H.check(#Spotting.HandsSlots == Spotting.MaxSpotters, "a layout for every count up to the max")
for count, slots in Spotting.HandsSlots do H.check(#slots == count, count .. " spotters, " .. count .. " spots") end
H.check(Spotting.HandsSlots[1][1] == "Spot_Middle", "1 = middle")
H.check(table.find(Spotting.HandsSlots[3], "Spot_Middle") ~= nil, "3 = left, right and middle")
H.check(table.find(Spotting.HandsSlots[4], "Spot_Middle") == nil, "4 = two each side, no middle")

-- taps: { at = seconds } -> a fresh record, counted taps, clicking at the end
local function run(times)
	local record = { taps = {}, recent = {}, clickingUntil = 0 }
	local counted = 0
	for _, t in times do
		if Spotting.Tap(record, t) then counted += 1 end
	end
	return record, counted
end
local function human(rate, seconds, start)
	local list, t = {}, start or 0
	math.randomseed(7)
	while t < (start or 0) + seconds do
		table.insert(list, t)
		t += (1 / rate) * (0.75 + math.random() * 0.5) -- uneven, like a finger
	end
	return list
end

print("PUSH taps")
local taps = human(5, 2)
local record = run(taps)
local last = taps[#taps]
H.check(last < record.clickingUntil, "5 uneven taps a second = clicking")
H.check(not (last + Spotting.ClickHold + 0.01 < record.clickingUntil), "clicking stops about 1 s after the last tap")
local slow = human(2, 3)
record = run(slow)
H.check(not (slow[#slow] < record.clickingUntil), "2 taps a second is not clicking")
local spam = human(20, 1)
local _, counted = run(spam)
H.check(counted <= Spotting.MaxTapsPerSecond + 1, "20 taps a second: at most ~8 count (" .. counted .. ")")
local even = {}
for i = 0, 30 do table.insert(even, i * 0.15) end -- an auto-clicker: exactly every 0.15 s
record, counted = run(even)
H.check(not (even[#even] < record.clickingUntil), "perfectly even taps never count as clicking")
H.check(counted < Spotting.EvenTaps, "perfectly even taps stop counting (" .. counted .. " counted)")
H.done()
