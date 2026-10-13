--!strict
-- NightLightService: runs the town's day / night clock (Config/DayNight; it stores when the day started in the Workspace
-- attribute DayStart, every client turns that into the sky, DayNightClient) and switches the night lights at dusk and dawn:
--   * "NightLight" parts (street lamps, wall lamps, string lights, floodlights): by day plain frosted glass with their
--     lights off; at night they glow (Neon, NightColor attribute) and their lights switch on (none cast shadows)
--   * "NightWindow" parts (shop windows, and the lit share of the town's windows; tools/builders/NightGlow): at night a
--     warm glow (Neon in NightColor), by day back to their DayColor / DayMaterial / DayTransparency
--   * "NightSign" parts or models (gym and shop signs): their SurfaceGuis light themselves at night (LightInfluence 0,
--     a little brighter), so the letters glow without adding a light
-- Runs on the server so everyone sees the same thing; it only changes looks when the clock crosses dusk or dawn.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DayNight = require((ReplicatedStorage :: any).Shared.Config.DayNight)

local NightLightService = {}

local TAG = "NightLight"
local WINDOW_TAG = "NightWindow"
local SIGN_TAG = "NightSign"

local night: boolean? = nil

local function applyLamp(part: Instance, on: boolean)
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

local function applyWindow(part: Instance, on: boolean)
	if not part:IsA("BasePart") then return end
	if on then
		local nightColor = part:GetAttribute("NightColor")
		local nightTransparency = part:GetAttribute("NightTransparency")
		part.Material = Enum.Material.Neon
		if typeof(nightColor) == "Color3" then part.Color = nightColor end
		part.Transparency = type(nightTransparency) == "number" and nightTransparency or 0 -- (shop windows stay see-through)
	else
		local dayColor, dayMaterial, dayTransparency = part:GetAttribute("DayColor"), part:GetAttribute("DayMaterial"), part:GetAttribute("DayTransparency")
		if typeof(dayColor) == "Color3" then part.Color = dayColor end
		if type(dayMaterial) == "string" then
			local ok, material = pcall(function() return (Enum.Material :: any)[dayMaterial] end)
			if ok and material then part.Material = material end
		end
		if type(dayTransparency) == "number" then part.Transparency = dayTransparency end
	end
end

local function applySign(sign: Instance, on: boolean)
	local guis = sign:IsA("SurfaceGui") and { sign } or sign:GetDescendants()
	for _, gui in ipairs(guis) do
		if gui:IsA("SurfaceGui") then
			gui.LightInfluence = on and 0 or 1
			gui.Brightness = on and 1.6 or 1
		end
	end
end

local function update()
	local now = DayNight.IsNight(DayNight.Now(Workspace:GetServerTimeNow()))
	if now == night then return end
	night = now
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do applyLamp(part, now) end
	for _, part in ipairs(CollectionService:GetTagged(WINDOW_TAG)) do applyWindow(part, now) end
	for _, sign in ipairs(CollectionService:GetTagged(SIGN_TAG)) do applySign(sign, now) end
end

function NightLightService.Start()
	-- the clock starts now, at DayNight.StartHour
	if type(Workspace:GetAttribute("DayStart")) ~= "number" then Workspace:SetAttribute("DayStart", Workspace:GetServerTimeNow()) end
	update()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(part) applyLamp(part, night == true) end)
	CollectionService:GetInstanceAddedSignal(WINDOW_TAG):Connect(function(part) applyWindow(part, night == true) end)
	CollectionService:GetInstanceAddedSignal(SIGN_TAG):Connect(function(sign) applySign(sign, night == true) end)
	-- (the clock moves about 1 hour every 35-50 s: checking every 2 s is plenty)
	task.spawn(function()
		while true do
			task.wait(2)
			update()
		end
	end)
	Workspace:GetAttributeChangedSignal("TestClock"):Connect(update)
end

return NightLightService
