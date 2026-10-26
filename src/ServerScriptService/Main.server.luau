local Players = game:GetService("Players")

-- Soft shutdown (ShutdownService): a holding server only sends its players back to the updated game; nothing else runs
-- there (no data is loaded, so no session lock is taken).
local ShutdownService = require(script.Parent.Server.ShutdownService)
if ShutdownService.IsHoldingServer() then
	ShutdownService.StartHolding()
	return
end
ShutdownService.Start()

-- (owner, 26 Oct: "put the builds from scripts like the city into Studio") The Pro Gym city lives in Workspace.Backdrops in
-- Studio, so it can be seen and edited there. At game start it moves into ReplicatedStorage.Backdrops, where
-- BackdropClient takes it from and draws it only while the camera is near the Pro Gym (phones elsewhere never draw it).
do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local shown = workspace:FindFirstChild("Backdrops")
	if shown then
		local store = ReplicatedStorage:FindFirstChild("Backdrops")
		if not store then
			store = Instance.new("Folder")
			store.Name = "Backdrops"
			store.Parent = ReplicatedStorage
		end
		for _, child in ipairs(shown:GetChildren()) do child.Parent = store end
		shown:Destroy()
	end
end

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
local OPTIONAL_SERVICES = { "BoostService", "QuestService", "MuscleOfTheDayService", "StaminaService", "RetentionService",
	"SocialService", "ArmWrestleService", "LegendService", "ShowOffService",
	"MonetizationService", "ProGymService", "CrewService", "SeasonService",
	"TownService", "CosmeticService", "SkateService", "MirrorService", "GymGoerService", "NightLightService",
	"AccessoryService", "PosingCompService", "DailyService", "LeaderboardService", "MealService", "RivalService", "TrainerService", "GroupGiftService", "AuraService", "BetaBadgeService", "ItemService", "PumpShopService", "SpurtMilestoneService", "ScreamService", "GoToService", "PowerliftingService", "StyleService", "AdminService", "PlaytimeService", "FriendService", "NotifyService" }
for _, name in ipairs(OPTIONAL_SERVICES) do
	task.spawn(function()
		local ok, err = pcall(function()
			require(script.Parent.Server[name]).Start()
		end)
		if not ok then warn("[Main] " .. name .. " failed to start: " .. tostring(err)) end
	end)
end

-- (26 Oct, server memory up 218%) a player who left: their character is destroyed once their save has had time to finish,
-- so everything connected to it (the services' per-character connections hold the player) is freed
Players.PlayerRemoving:Connect(function(player)
	task.delay(15, function()
		local character = player.Character
		if character then character:Destroy() end -- (also when Roblox already took it out of the world: that doesn't free it)
	end)
end)

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
