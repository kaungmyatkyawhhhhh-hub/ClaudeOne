-- Coins outside of reps (numbers in Config.Economy): the daily streak and offline coins (paid once per join),
-- loose plates to re-rack, DNA tokens for coins at the front desk, and rush hour every 30 minutes.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Economy = require(Config.Economy)
local Machines = require(Config.Machines)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)
local BoostService = require(script.Parent.BoostService)

local Remotes = ReplicatedStorage.Remotes

local RetentionService = {}

local welcomed = {} -- [player] = true once this join's streak/offline coins are paid
local rng = Random.new()

local function event(player, kind, info)
	Remotes.PlayerEvent:FireClient(player, kind, info or {})
end

------------------------------------------------------------------------
-- Daily streak + offline coins (once per join)
------------------------------------------------------------------------
local function welcome(player, data)
	if welcomed[player] then return end
	welcomed[player] = true
	local now = os.time()
	local today = Economy.Day(now)

	local daily = data.daily
	local streak, claimed = Economy.NextStreak(daily.lastDay, daily.streak, today)
	local streakCoins, streakToken = 0, false
	if claimed then
		streakCoins = Economy.StreakCoins(streak)
		streakToken = streak % Economy.Daily.TokenEvery == 0
		PlayerData.SetTable(player, "daily", { lastDay = today, streak = streak, best = math.max(daily.best or 0, streak) })
		PlayerData.AddCoins(player, streakCoins)
		if streakToken then PlayerData.AddDnaTokens(player, 1) end
	end

	local offlineCoins = 0
	local lastSeen = data.meta.lastSeen or 0
	if lastSeen > 0 and data.meta.sessions > 1 then
		offlineCoins = Economy.OfflineCoins(now - lastSeen)
		if offlineCoins > 0 then PlayerData.AddCoins(player, offlineCoins) end
	end

	PlayerData.SetTable(player, "welcome", { offlineCoins = offlineCoins, streakCoins = streakCoins, streakToken = streakToken })
end

------------------------------------------------------------------------
-- Loose plates
------------------------------------------------------------------------
local loose = {} -- [spotIndex] = part

local function plateFolder()
	local folder = Workspace:FindFirstChild("LoosePlates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LoosePlates"
		folder.Parent = Workspace
	end
	return folder
end

local function spawnPlate()
	local free = {}
	for i in ipairs(Economy.Rerack.Spots) do
		if not (loose[i] and loose[i].Parent) then table.insert(free, i) end
	end
	local count = #Economy.Rerack.Spots - #free
	if #free == 0 or count >= Economy.Rerack.MaxLoose then return end
	local index = free[rng:NextInteger(1, #free)]
	local spot = Economy.Rerack.Spots[index]
	local weights = Economy.Rerack.Weights
	local weight = weights[rng:NextInteger(1, #weights)]
	local assets = ReplicatedStorage:FindFirstChild("GymAssets")
	local template = assets and assets.Plates:FindFirstChild("Plate" .. weight)
	local model = template and template:Clone() or Instance.new("Model")
	model.Name = "LoosePlate"
	local spec = Machines.Plates[weight]
	-- lying flat on the floor (the plate's axis pointing up), number side up, at a random turn
	model:PivotTo(CFrame.new(spot.X, 0.15 + spec.thickness / 2, spot.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(90)))
	local face = model:FindFirstChild("FaceRight")
	local label = face and face:FindFirstChildWhichIsA("SurfaceGui")
	if label then label.Enabled = true end
	local plate = model:FindFirstChild("Body") or model:FindFirstChildWhichIsA("BasePart")
	if not plate then return end
	plate.CanQuery = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Re-rack"
	prompt.ObjectText = "+" .. Economy.Rerack.Coins .. " coins"
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = plate
	local claimed = false
	Guard.OnTriggered(prompt, function(player)
		if claimed or not PlayerData.Get(player) then return end
		claimed = true
		PlayerData.AddCoins(player, Economy.Rerack.Coins)
		event(player, "Reracked", { coins = Economy.Rerack.Coins })
		model:Destroy()
		loose[index] = nil
	end)

	model.Parent = plateFolder()
	loose[index] = model
end

------------------------------------------------------------------------
-- DNA tokens at the front desk
------------------------------------------------------------------------
local lastBuy = {}
local function setupFrontDesk()
	local desk = Workspace:FindFirstChild("FrontDesk", true)
	if not desk then return end
	local holder, biggest = nil, 0
	for _, part in ipairs(desk:GetDescendants()) do
		if part:IsA("BasePart") and part.Size.Magnitude > biggest then holder, biggest = part, part.Size.Magnitude end
	end
	if not holder then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyDnaToken"
	prompt.ActionText = "Buy DNA token"
	prompt.ObjectText = Economy.DnaTokenCost .. " coins"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.6 -- a short hold, so nobody buys one by accident
	prompt.Parent = holder
	Guard.OnTriggered(prompt, function(player)
		local now = os.clock()
		if now - (lastBuy[player] or 0) < 1 then return end
		lastBuy[player] = now
		if PlayerData.SpendCoins(player, Economy.DnaTokenCost) then
			PlayerData.AddDnaTokens(player, 1)
			event(player, "DnaTokenBought", {})
		else
			event(player, "DnaTokenBought", { failed = true })
		end
	end)
end

------------------------------------------------------------------------
-- Rush hour
------------------------------------------------------------------------
local function rushHourLoop()
	local wasActive = false
	while true do
		local active, seconds = Economy.RushHourAt(os.time())
		if active and not wasActive then
			BoostService.SetGlobal("RushHour", { coins = Economy.RushHour.Coins, untilTime = Workspace:GetServerTimeNow() + seconds })
			for _, player in ipairs(Players:GetPlayers()) do event(player, "RushHour", { active = true }) end
		elseif not active and wasActive then
			BoostService.SetGlobal("RushHour", nil)
			for _, player in ipairs(Players:GetPlayers()) do event(player, "RushHour", { active = false }) end
		end
		wasActive = active
		task.wait(2)
	end
end

function RetentionService.Start()
	PlayerData.Loaded:Connect(function(player, data)
		welcome(player, data)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.Get(player)
		if data then welcome(player, data) end
	end
	Players.PlayerRemoving:Connect(function(player)
		welcomed[player] = nil
		lastBuy[player] = nil
	end)

	setupFrontDesk()
	task.spawn(rushHourLoop)
	task.spawn(function()
		spawnPlate()
		while true do
			task.wait(Economy.Rerack.SpawnEvery)
			spawnPlate()
		end
	end)
end

return RetentionService
