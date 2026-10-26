-- PlaytimeService (26 Oct, retention): the playtime gifts (Config.Playtime). Counts each player's minutes played today
-- (data.playtime = { day, seconds, claimed }: the UTC day, seconds played that day, gifts already paid that day) and pays
-- the next gift by itself once its minutes are reached and the tutorial is done. Remote "Playtime" (server -> client only):
-- "Gift" { index, text, nextText?, nextMinutes? } for the popup.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Playtime = require(Config.Playtime)
local Economy = require(Config.Economy)
local Onboarding = require(Config.Onboarding)
local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)

local PlaytimeService = {}

local remote: RemoteEvent
local lastSave = {} -- [player] = os.clock()

local function today(): number
	return Economy.Day(os.time())
end

local function stateOf(data)
	local p = type(data.playtime) == "table" and data.playtime or {}
	local day = today()
	if p.day ~= day then return { day = day, seconds = 0, claimed = 0 } end
	return { day = day, seconds = math.max(0, tonumber(p.seconds) or 0), claimed = math.max(0, math.floor(tonumber(p.claimed) or 0)) }
end

local function tutorialDone(data): boolean
	local step = type(data.onboarding) == "table" and data.onboarding.tutorialStep or Onboarding.Done
	return (tonumber(step) or Onboarding.Done) >= Onboarding.Done
end

local function canRoll(data): boolean
	return (data.growthSpurts or 0) >= 1
end

local function coinsFor(gift, data): number
	return Economy.Reward(data.growthSpurts, gift.coins or 0, gift.floor)
end

-- pays gift `index` (saved first, so it is never paid twice)
local function pay(player, data, state, index: number)
	local gift = Playtime.Gifts[index]
	state.claimed = index
	PlayerData.SetTable(player, "playtime", state)
	lastSave[player] = os.clock()
	local coins = nil
	if gift.item then
		PlayerData.AddItem(player, gift.item, 1)
	elseif gift.roll and canRoll(data) then
		local ok, TrainerService = pcall(require, script.Parent.TrainerService)
		if ok and TrainerService.AddFreeRolls then
			TrainerService.AddFreeRolls(player, 1)
		else
			coins = coinsFor(gift, data)
		end
	else
		coins = coinsFor(gift, data)
	end
	if coins then PlayerData.AddCoins(player, coins) end
	local nextGift = Playtime.Gifts[index + 1]
	remote:FireClient(player, "Gift", {
		index = index, total = #Playtime.Gifts,
		text = Playtime.Describe(gift, coins, canRoll(data)),
		nextText = nextGift and Playtime.Describe(nextGift, coinsFor(nextGift, data), canRoll(data)) or nil,
		nextMinutes = nextGift and math.max(1, math.ceil(nextGift.minutes - state.seconds / 60)) or nil,
	})
	Analytics.Event(player, "PlaytimeGift", index)
end

local function tick(player, dt: number)
	local data = PlayerData.Get(player)
	if not data then return end
	local state = stateOf(data)
	state.seconds += dt
	local nextGift = Playtime.Gifts[state.claimed + 1]
	if nextGift and state.seconds >= nextGift.minutes * 60 and tutorialDone(data) then
		pay(player, data, state, state.claimed + 1)
		return
	end
	if os.clock() - (lastSave[player] or 0) >= Playtime.SaveEvery or type(data.playtime) ~= "table" or data.playtime.day ~= state.day then
		PlayerData.SetTable(player, "playtime", state)
		lastSave[player] = os.clock()
	else
		data.playtime.seconds = state.seconds -- (kept in memory between saves; saved with the rest of the data)
	end
end

function PlaytimeService.Start()
	remote = ReplicatedStorage.Remotes:FindFirstChild("Playtime") :: RemoteEvent
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Playtime"
		remote.Parent = ReplicatedStorage.Remotes
	end
	Players.PlayerRemoving:Connect(function(player) lastSave[player] = nil end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Playtime.TickSeconds)
			local now = os.clock()
			local dt = math.min(now - last, Playtime.TickSeconds * 3)
			last = now
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(tick, player, dt)
				if not ok then warn("[PlaytimeService] " .. tostring(err)) end
			end
		end
	end)
end

return PlaytimeService
