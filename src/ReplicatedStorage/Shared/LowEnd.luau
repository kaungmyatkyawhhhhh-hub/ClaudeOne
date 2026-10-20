-- LowEnd: is this a low-end device? (client side; owner, 20 Oct: lag on phones)
--   LowEnd.IsLowEnd()  -- the frame rate stayed under LOW_FPS for LOW_FOR seconds in a row this session, or the player set
--                         Roblox's graphics quality to 1-LOW_QUALITY by hand
--   LowEnd.IsPhone()   -- the phone layout (MachineHud.LayoutMode: a small screen or touch without a keyboard)
-- Studio: Workspace attribute "TestLowEnd" = true makes IsLowEnd true (Studio's own frame rate is no guide, so the frame rate
-- rule is off there).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MachineHud = require(script.Parent.UI.MachineHud)

local LowEnd = {}

local LOW_FPS, LOW_FOR = 40, 5
local LOW_QUALITY = 3

local slow = false
if RunService:IsClient() then
	local frames, elapsed, slowSeconds = 0, 0, 0
	local watch
	watch = RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed < 1 then return end
		slowSeconds = if frames / elapsed < LOW_FPS then slowSeconds + 1 else 0
		frames, elapsed = 0, 0
		if slowSeconds >= LOW_FOR and not RunService:IsStudio() then
			slow = true
			watch:Disconnect()
		end
	end)
end

function LowEnd.IsLowEnd(): boolean
	if RunService:IsStudio() and Workspace:GetAttribute("TestLowEnd") == true then return true end
	if slow then return true end
	local ok, quality = pcall(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel end)
	return ok and quality ~= Enum.SavedQualitySetting.Automatic and quality.Value <= LOW_QUALITY
end

function LowEnd.IsPhone(): boolean
	return (MachineHud.LayoutMode()) == "phone"
end

return LowEnd
