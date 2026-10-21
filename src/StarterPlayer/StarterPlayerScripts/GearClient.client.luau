-- GearClient (prompt 34): keeps every gear piece (Shared/Gear: belts, wraps, knee sleeves, straps, the coaches' whistles)
-- fitted to the body this client SEES. The server welds the gear on from the plain body parts; here it is re-fitted to the
-- muscle stage meshes (other players, trainers) or your own live muscle meshes, so a belt sits round a mass monster's
-- waist as well as a beginner's. About twice a second; a piece whose body didn't change is skipped (Gear.Fit's key).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage.Shared.Gear)

while true do
	task.wait(0.5)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then pcall(Gear.Fit, character) end
	end
	local trainers = workspace:FindFirstChild("LocalTrainers")
	if trainers then
		for _, model in ipairs(trainers:GetChildren()) do
			if model:IsA("Model") then pcall(Gear.Fit, model) end
		end
	end
end
