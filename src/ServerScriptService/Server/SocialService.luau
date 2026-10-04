-- Spotting and the workout-together bonus (numbers in Config.Social).
-- Spotting: while someone lifts on a bench or the squat rack, other players see a "Spot" prompt on that machine.
-- The lifter trains harder while spotted; the spotter earns coins per spotted rep and counts toward the Spotter
-- title. The spot ends when either one leaves or the spotter walks away.
-- Together: lifting while another player lifts nearby gives a small bonus and counts toward Gym Buddy.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Social = require(ReplicatedStorage.Shared.Config.Social)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local TitleService = require(script.Parent.TitleService)

local Remotes = ReplicatedStorage.Remotes

local SocialService = {}

local spots = {}     -- [model] = { lifter = Player, spotter = Player }
local together = {}  -- [player] = true while the together bonus is on
local spotPrompts = {} -- [model] = ProximityPrompt

local function event(player, kind, info)
	if player and player.Parent then Remotes.PlayerEvent:FireClient(player, kind, info or {}) end
end

local function lifterOf(model)
	local userId = model:GetAttribute("UserId")
	return userId and Players:GetPlayerByUserId(userId) or nil
end

local function endSpot(model, reason)
	local spot = spots[model]
	if not spot then return end
	spots[model] = nil
	if spot.lifter and spot.lifter.Parent then
		BoostService.SetPlayer(spot.lifter, "Spotted", nil)
		event(spot.lifter, "SpotEnded", { name = spot.spotter.DisplayName, reason = reason })
	end
	event(spot.spotter, "SpotEnded", { name = spot.lifter and spot.lifter.DisplayName or "", reason = reason, spotter = true })
	local prompt = spotPrompts[model]
	if prompt then prompt.Enabled = lifterOf(model) ~= nil end
end

local function isLifting(player)
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == player.UserId then return true end
	end
	return false
end

local function isSpotting(player)
	for _, spot in pairs(spots) do
		if spot.spotter == player then return true end
	end
	return false
end

local function startSpot(model, spotter)
	local lifter = lifterOf(model)
	if not lifter or lifter == spotter or spots[model] then return end
	if isLifting(spotter) or isSpotting(spotter) or not PlayerData.Get(spotter) then return end
	spots[model] = { lifter = lifter, spotter = spotter }
	BoostService.SetPlayer(lifter, "Spotted", { gains = Social.Spot.GainsBoost })
	local prompt = spotPrompts[model]
	if prompt then prompt.Enabled = false end
	event(lifter, "SpotStarted", { name = spotter.DisplayName })
	event(spotter, "SpotStarted", { name = lifter.DisplayName, spotter = true })
end

local function setupMachine(model)
	local machineId = model:GetAttribute("MachineId")
	if not Social.Spot.Machines[machineId] or spotPrompts[model] then return end
	local use = nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name ~= "SpotPrompt" then use = descendant break end
	end
	if not use then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpotPrompt"
	prompt.ActionText = "Spot"
	prompt.ObjectText = "Help them lift"
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = use.Parent
	spotPrompts[model] = prompt
	prompt.Triggered:Connect(function(player) startSpot(model, player) end)
	model:GetAttributeChangedSignal("UserId"):Connect(function()
		if lifterOf(model) then
			prompt.Enabled = spots[model] == nil
		else
			prompt.Enabled = false
			endSpot(model, "lifter left")
		end
	end)
end

-- Called by MachineService for every validated rep.
function SocialService.OnRep(player, _machineId)
	for _, spot in pairs(spots) do
		if spot.lifter == player and spot.spotter.Parent then
			local data = PlayerData.Get(spot.spotter)
			if data then
				PlayerData.AddCoins(spot.spotter, Social.Spot.CoinsPerRep)
				PlayerData.SetStat(spot.spotter, "spotReps", (data.stats.spotReps or 0) + 1)
				TitleService.Check(spot.spotter)
			end
		end
	end
	if together[player] then
		local data = PlayerData.Get(player)
		if data then
			PlayerData.SetStat(player, "togetherReps", (data.stats.togetherReps or 0) + 1)
		end
	end
end

local function rootPosition(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function tick()
	-- spotters who walked away
	for model, spot in pairs(spots) do
		local position = spot.spotter.Parent and rootPosition(spot.spotter)
		if not position or (position - model:GetPivot().Position).Magnitude > Social.Spot.Range + 4 then
			endSpot(model, "spotter walked away")
		end
	end
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
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do setupMachine(model) end
	CollectionService:GetInstanceAddedSignal("Machine"):Connect(setupMachine)
	Players.PlayerRemoving:Connect(function(player)
		together[player] = nil
		for model, spot in pairs(spots) do
			if spot.spotter == player or spot.lifter == player then endSpot(model, "left the game") end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			tick()
		end
	end)
end

return SocialService
