--!strict
-- Spotting (owner's redo, 8 Oct night; replaces the old Spot prompt on benches / the squat rack). Tune the numbers here.
--  * Click / tap a lifter's body -> a small popup "SPOT" / X. The lifter gets "<name> wants to spot you" with ACCEPT / X
--    (closes after RequestTimeout seconds; the lifter can turn requests off in Settings). Up to MaxSpotters.
--  * Each machine's spot type (Config.Machines spotType): "hands" = spotters stand at the bar (Spot_Left1, Spot_Left2,
--    Spot_Right1, Spot_Right2, Spot_Middle; HandsSlots says which ones for each count) with their hands under the bar,
--    following it every rep; "hype" = a loose half-circle in front of the lifter (Hype_1..5) clapping, pointing and fist
--    pumping. Machines without a spot type (the treadmill) can't be spotted.
--  * Boost (the lifter's gains): Boost[count] by how many spotters, plus ClickBonus x (clicking spotters / spotters).
--    A spotter counts as clicking while they PUSH at ClickRate taps a second or more (until ClickHold seconds after
--    they stop). Anti auto-clicker: at most MaxTapsPerSecond taps count, and perfectly even taps are ignored.
--  * Spotter reward: coins only, every RewardEvery lifter reps (a bit more while clicking).
local Spotting = {}

Spotting.MaxSpotters = 5
Spotting.RequestTimeout = 8      -- seconds the lifter's request card stays up
Spotting.RequestCooldown = 3     -- seconds between two requests from the same player
Spotting.Range = 16              -- studs: how close you must be to ask, and how far a spotter may get before it ends
Spotting.LeaveDistance = 3       -- studs a spotter may move from their spot (walking away / jumping ends spotting)

-- the lifter's gains multiplier by spotter count, and the most clicking can add (shared by the fraction clicking)
Spotting.Boost = { 1.10, 1.20, 1.30, 1.40, 1.50 }
Spotting.ClickBonus = 0.15

Spotting.ClickRate = 3           -- PUSH taps per second to count as clicking
Spotting.ClickWindow = 1         -- seconds the rate is measured over
Spotting.ClickHold = 1           -- seconds clicking stays on after the taps stop
Spotting.MaxTapsPerSecond = 8    -- more taps than this in a second are ignored
Spotting.EvenTaps = 8            -- this many taps in a row ...
Spotting.EvenSpread = 0.004      -- ... whose gaps differ by less than this (seconds) are a machine: ignored

Spotting.RewardEvery = 10        -- lifter reps per spotter payout
Spotting.RewardCoins = 5
Spotting.RewardClickingCoins = 3 -- extra when the spotter was clicking at the payout

-- which "hands" spots are used for 1..5 spotters (2 = left + right, 3 adds the middle, 4 = two each side, 5 adds the middle)
Spotting.HandsSlots = {
	{ "Spot_Middle" },
	{ "Spot_Left1", "Spot_Right1" },
	{ "Spot_Left1", "Spot_Right1", "Spot_Middle" },
	{ "Spot_Left1", "Spot_Left2", "Spot_Right1", "Spot_Right2" },
	{ "Spot_Left1", "Spot_Left2", "Spot_Right1", "Spot_Right2", "Spot_Middle" },
}
Spotting.HypeSlots = { "Hype_1", "Hype_2", "Hype_3", "Hype_4", "Hype_5" }

-- The lifter's gains multiplier for this many spotters, `clicking` of them clicking.
function Spotting.BoostFor(count: number, clicking: number): number
	if count <= 0 then return 1 end
	local n = math.min(count, #Spotting.Boost)
	return Spotting.Boost[n] + Spotting.ClickBonus * (math.min(clicking, count) / count)
end

-- One PUSH tap at time `now` (seconds) for a spotter's record { taps = {}, recent = {}, clickingUntil = 0 } (the server's
-- copy; pure, so tests can feed it exact timings). Returns whether the tap counted. They count as clicking while
-- now < record.clickingUntil.
function Spotting.Tap(record, now: number): boolean
	local taps, recent = record.taps, record.recent
	-- even timing is checked on every tap that arrives (a machine is a machine however fast it goes)
	table.insert(recent, now)
	while #recent > Spotting.EvenTaps do table.remove(recent, 1) end
	if #recent >= Spotting.EvenTaps then
		local low, high = math.huge, -math.huge
		for i = 2, #recent do
			local gap = recent[i] - recent[i - 1]
			low, high = math.min(low, gap), math.max(high, gap)
		end
		if high - low < Spotting.EvenSpread then
			table.clear(taps)
			record.clickingUntil = math.min(record.clickingUntil, now)
			return false
		end
	end
	while taps[1] and now - taps[1] > Spotting.ClickWindow do table.remove(taps, 1) end
	if #taps >= Spotting.MaxTapsPerSecond then return false end -- (faster than a hand: not counted)
	table.insert(taps, now)
	-- ClickRate taps a second = ClickRate gaps inside the window (ClickRate + 1 taps)
	if #taps > Spotting.ClickRate then record.clickingUntil = now + Spotting.ClickHold end
	return true
end

return Spotting
