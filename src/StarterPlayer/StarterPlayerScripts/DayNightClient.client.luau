-- DayNightClient (owner's feature run, task 7C): moves the sky. Every client works out the same time of day from the
-- server's DayStart attribute (Config/DayNight) and sets Lighting.ClockTime itself, so the sun and moon glide smoothly
-- without the server sending the time. The outdoor fill (OutdoorAmbient) blends to a cool dark at night; the indoor fill
-- (Ambient) stays, so the gyms keep their own lighting. The lamps, windows and signs are switched by NightLightService.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DayNight = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DayNight"))

local dayOutdoor = Lighting.OutdoorAmbient -- (the place's own daytime value)
local acc = 0

RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end -- (10 updates a second is smooth: an hour of sky takes about 35-50 s)
	acc = 0
	local clock = DayNight.Now(Workspace:GetServerTimeNow())
	Lighting.ClockTime = clock
	Lighting.OutdoorAmbient = dayOutdoor:Lerp(DayNight.NightOutdoorAmbient, DayNight.NightAmount(clock))
end)
