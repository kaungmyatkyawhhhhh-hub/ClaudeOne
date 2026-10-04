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

-- Newer services start one by one in protected calls: if one of them fails, it warns in Output and
-- the rest of the game (saving, machines, titles) keeps running.
local OPTIONAL_SERVICES = { "BoostService", "QuestService", "MuscleOfTheDayService", "StaminaService" }
for _, name in ipairs(OPTIONAL_SERVICES) do
	task.spawn(function()
		local ok, err = pcall(function()
			require(script.Parent.Server[name]).Start()
		end)
		if not ok then warn("[Main] " .. name .. " failed to start: " .. tostring(err)) end
	end)
end

-- Stamina refills on its own (faster on recovery stations and with boosts)
local boostsOk, BoostService = pcall(require, script.Parent.Server.BoostService)
local TICK = 0.25
while true do
	task.wait(TICK)
	for _, player in ipairs(Players:GetPlayers()) do
		local multiplier = 1
		if boostsOk then
			local ok, value = pcall(BoostService.Regen, player)
			if ok then multiplier = value end
		end
		PlayerData.RegenStamina(player, TICK, multiplier)
	end
end
