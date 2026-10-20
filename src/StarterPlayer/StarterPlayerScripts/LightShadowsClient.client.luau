-- LightShadowsClient: the lights' shadows (owner, 20 Oct). In the place only the main lights of each gym cast shadows (the
-- starter gym's and the pro gym's two big spots, the posing stage's spot); every small / accent light has Shadows off. On a
-- phone or a low-end device (Shared.LowEnd: low frame rate, or graphics quality 1-3) every light's shadow is turned off on
-- this client, also for lights that stream in later. Checked every few seconds; once off it stays off for the session.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LowEnd = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LowEnd"))

local CHECK_EVERY = 3

local function off(light: Instance)
	if light:IsA("Light") and light.Shadows then light.Shadows = false end
end

task.spawn(function()
	while not (LowEnd.IsPhone() or LowEnd.IsLowEnd()) do
		task.wait(CHECK_EVERY)
	end
	for _, item in ipairs(Workspace:GetDescendants()) do off(item) end
	Workspace.DescendantAdded:Connect(off)
end)
