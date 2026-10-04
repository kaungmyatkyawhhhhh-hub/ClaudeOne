local Players = game:GetService("Players")

local PlayerData = require(script.Parent.Server.PlayerData)
local MachineService = require(script.Parent.Server.MachineService)
local BodyService = require(script.Parent.Server.BodyService)
local ActionService = require(script.Parent.Server.ActionService)
local TitleService = require(script.Parent.Server.TitleService)

PlayerData.Start()
MachineService.Start()
BodyService.Start()
ActionService.Start()
TitleService.Start()

-- Stamina refills on its own
local TICK = 0.25
while true do
	task.wait(TICK)
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.RegenStamina(player, TICK)
	end
end
