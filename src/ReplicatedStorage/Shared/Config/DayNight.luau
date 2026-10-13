-- Day / night in town (owner's feature run, task 7C). One shared clock: the server stores when the current day started
-- (Workspace attribute DayStart, server time) and every client works out the same time of day from it, so the sky moves
-- smoothly on every screen without the server sending the time each frame (DayNightClient sets Lighting.ClockTime).
-- At night the street lamps, shop windows and gym / shop signs light up (NightLightService; tags NightLight, NightWindow,
-- NightSign). Gym interiors keep their own lighting: only the OUTDOOR ambient changes (Lighting.Ambient, the indoor fill,
-- stays), and no new shadow lights are added (none of the night lights cast shadows).
local DayNight = {}

DayNight.Length = 20 * 60  -- seconds for a full day (day + night)
DayNight.DayShare = 0.7    -- share of the cycle that is daytime (06:00 to 18:00), so it's light most of the time
DayNight.StartHour = 9     -- the time of day when a server starts
DayNight.Dawn, DayNight.Dusk = 6, 18 -- lamps, windows and signs are on from Dusk to Dawn
DayNight.NightOutdoorAmbient = Color3.fromHex("#2E3550") -- the outdoor fill at night (cool and dark, never black)
DayNight.AmbientFade = 1.5 -- hours around dawn / dusk over which the outdoor fill blends
DayNight.WindowLitShare = 0.6 -- share of the town buildings' windows that light up at night (picked once by the builder)

-- Time of day (0..24 hours) `elapsed` seconds into the cycle that began at StartHour. Daytime (Dawn..Dusk) takes
-- DayShare of the cycle, the night the rest.
function DayNight.ClockFromElapsed(elapsed: number): number
	local dayHours = DayNight.Dusk - DayNight.Dawn
	local nightHours = 24 - dayHours
	local daySeconds = DayNight.Length * DayNight.DayShare
	local nightSeconds = DayNight.Length - daySeconds
	-- seconds since dawn at the start
	local startIntoDay = (DayNight.StartHour - DayNight.Dawn) / dayHours * daySeconds
	local t = (elapsed + startIntoDay) % DayNight.Length
	if t < daySeconds then
		return DayNight.Dawn + t / daySeconds * dayHours
	end
	return (DayNight.Dusk + (t - daySeconds) / nightSeconds * nightHours) % 24
end

function DayNight.IsNight(clock: number): boolean
	return clock >= DayNight.Dusk or clock < DayNight.Dawn
end

-- How much "night" the outdoor fill shows (0 = day, 1 = full night), blending over AmbientFade hours around dusk and dawn.
function DayNight.NightAmount(clock: number): number
	local f = DayNight.AmbientFade
	local function ramp(x) return math.clamp(x, 0, 1) end
	if clock >= DayNight.Dawn and clock < DayNight.Dusk then
		-- daytime: fading out of the night after dawn, into it before dusk
		return math.max(ramp(1 - (clock - DayNight.Dawn) / f), ramp(1 - (DayNight.Dusk - clock) / f)) * 0.5
	end
	-- night: half at dusk / dawn, full in the middle
	local fromDusk = (clock - DayNight.Dusk) % 24
	local toDawn = (DayNight.Dawn - clock) % 24
	return 0.5 + 0.5 * ramp(math.min(fromDusk, toDawn) / f)
end

-- The time of day now. Studio: the Workspace attribute TestClock (hours) holds the clock there, to check day and night.
function DayNight.Now(serverTime: number): number
	if game:GetService("RunService"):IsStudio() then
		local test = workspace:GetAttribute("TestClock")
		if type(test) == "number" then return test % 24 end
	end
	local start = workspace:GetAttribute("DayStart")
	if type(start) ~= "number" then return DayNight.StartHour end
	return DayNight.ClockFromElapsed(serverTime - start)
end

return DayNight
