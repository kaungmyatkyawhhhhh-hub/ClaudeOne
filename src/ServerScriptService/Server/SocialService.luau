-- The workout-together bonus (numbers in Config.Social), and the rep hook for spotting (SpotService, the owner's
-- spotting redo of 8 Oct night: it replaced the old "Spot" prompt that lived here).
-- Together: lifting while another player lifts nearby gives a small bonus and counts toward Gym Buddy.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Social = require(ReplicatedStorage.Shared.Config.Social)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local SpotService = require(script.Parent.SpotService)

local Remotes = ReplicatedStorage.Remotes

local SocialService = {}

local together = {}  -- [player] = true while the together bonus is on

local function event(player, kind, info)
	if player and player.Parent then Remotes.PlayerEvent:FireClient(player, kind, info or {}) end
end

local function lifterOf(model)
	local userId = model:GetAttribute("UserId")
	return userId and Players:GetPlayerByUserId(userId) or nil
end

-- Called by MachineService for every validated rep.
function SocialService.OnRep(player, _machineId)
	SpotService.OnRep(player)
	if together[player] then
		local data = PlayerData.Get(player)
		if data then
			PlayerData.SetStat(player, "togetherReps", (data.stats.togetherReps or 0) + 1)
		end
	end
end

local function tick()
	-- together bonus: two lifters near each other
	local lifters = {}
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		local lifter = lifterOf(model)
		if lifter then table.insert(lifters, { player = lifter, position = model:GetPivot().Position }) end
	end
	local now = {}
	for i, a in ipairs(lifters) do
		for j, b in ipairs(lifters) do
			if i ~= j and (a.position - b.position).Magnitude <= Social.Together.Range then
				now[a.player] = true
			end
		end
	end
	for player in pairs(together) do
		if not now[player] then
			together[player] = nil
			if player.Parent then BoostService.SetPlayer(player, "Together", nil) end
		end
	end
	for player in pairs(now) do
		if not together[player] then
			together[player] = true
			BoostService.SetPlayer(player, "Together", { gains = Social.Together.GainsBoost })
			event(player, "TogetherStarted", {})
		end
	end
end

function SocialService.Start()
	SpotService.Start()
	Players.PlayerRemoving:Connect(function(player)
		together[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			tick()
		end
	end)
end

return SocialService
