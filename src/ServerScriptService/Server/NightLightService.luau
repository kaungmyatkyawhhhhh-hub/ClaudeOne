--!strict
-- NightLightService: outdoor lamps (street lamps, wall lamps, string lights, floodlights) are parts tagged "NightLight"
-- by the Studio builders. By day they are plain frosted glass with their lights off; at night (Lighting.ClockTime
-- before 6:00 or after 18:00) they glow (Neon, NightColor attribute) and their lights switch on. Runs on the server so
-- everyone sees the same thing; it only changes looks when the time of day crosses dusk/dawn.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local NightLightService = {}

local TAG = "NightLight"
local DUSK, DAWN = 18, 6

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= DUSK or t < DAWN
end

local night: boolean? = nil

local function apply(part: Instance, on: boolean)
	if not part:IsA("BasePart") then return end
	local nightColor = part:GetAttribute("NightColor")
	local dayColor = part:GetAttribute("DayColor")
	if on then
		part.Material = Enum.Material.Neon
		if typeof(nightColor) == "Color3" then part.Color = nightColor end
	else
		part.Material = Enum.Material.SmoothPlastic
		if typeof(dayColor) == "Color3" then part.Color = dayColor end
	end
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Light") then child.Enabled = on end
	end
end

local function update()
	local now = isNight()
	if now == night then return end
	night = now
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do apply(part, now) end
end

function NightLightService.Start()
	update()
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(update)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(part)
		apply(part, night == true)
	end)
end

return NightLightService
