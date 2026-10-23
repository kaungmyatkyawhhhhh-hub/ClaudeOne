-- GymMoodClient (prompt 58, 23 Oct): a gym's own slight colour mood, only while the camera is inside it (one extra
-- ColorCorrection in Lighting, "GymMood", that fades in and out; neutral everywhere else, so the town and the other gyms
-- keep their look). Cheap: one position check every half second and a short tween.
--   Pro Gym: a slight cool, clean white (no orange tint).
--   Powerlifting Gym: raw and heavy: a little less colour, a little more contrast.
--   (prompt 62) The Pro Gym also thins the haze (the Atmosphere's Density / Haze) while you're inside, so the city below its
--   windows (BackdropClient) reads clearly instead of a grey void; the town's own haze comes back when you leave.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- box = x0, x1, z0, z1, top y
local MOODS = {
	{ box = { 44.5, 154, -90, -4, 20 }, tint = Color3.fromHex("#F1F5FF"), contrast = 0.05, saturation = -0.04, brightness = 0.01, density = 0.12, haze = 0.4 }, -- the Pro Gym
	{ box = { -175, -65, -97, -3, 34 }, tint = Color3.fromHex("#F6F7F8"), contrast = 0.08, saturation = -0.12, brightness = 0 }, -- the Powerlifting Gym
}
local NEUTRAL = { tint = Color3.new(1, 1, 1), contrast = 0, saturation = 0, brightness = 0 }

local effect = Instance.new("ColorCorrectionEffect")
effect.Name = "GymMood"
effect.Parent = Lighting

-- the town's own haze (read once), put back outside a gym that changes it
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local baseDensity = atmosphere and atmosphere.Density
local baseHaze = atmosphere and atmosphere.Haze

local current = nil
while true do
	local camera = Workspace.CurrentCamera
	local p = camera and camera.CFrame.Position
	local mood = NEUTRAL
	if p then
		for _, m in ipairs(MOODS) do
			local b = m.box
			if p.X > b[1] and p.X < b[2] and p.Z > b[3] and p.Z < b[4] and p.Y < b[5] then mood = m break end
		end
	end
	if mood ~= current then
		current = mood
		TweenService:Create(effect, TweenInfo.new(0.8), { TintColor = mood.tint, Contrast = mood.contrast, Saturation = mood.saturation,
			Brightness = mood.brightness }):Play()
		if atmosphere then
			TweenService:Create(atmosphere, TweenInfo.new(1.2), { Density = mood.density or baseDensity, Haze = mood.haze or baseHaze }):Play()
		end
	end
	task.wait(0.5)
end
