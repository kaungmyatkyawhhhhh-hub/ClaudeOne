-- Default save data for a brand-new player. New fields added here are filled
-- into existing saves automatically when they load (see PlayerData reconcile).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage.Shared.Config
local Muscles = require(Config.Muscles)
local Stamina = require(Config.Stamina)

local DataTemplate = {}

function DataTemplate.new()
	local muscles = {}
	for _, muscle in ipairs(Muscles.List) do
		muscles[muscle.id] = { level = 0, xp = 0 }
	end

	return {
		version = 1,
		muscles = muscles,
		stamina = Stamina.Max,
		coins = 0,
		genetics = nil, -- rolled on first join
		freeReroll = true, -- the brief's one free reroll at start
		dnaTokens = 0,
		growthSpurts = 6, -- (owner, 8 Oct) new players start at the max height, 7'0" (the last Growth Spurt in Config.GrowthSpurts; 0 = 4'0")
		titles = { owned = {}, equipped = nil }, -- owned: titleId -> unix time earned
		machines = {}, -- machineId -> { unlocked = highest bought tier, selected = tier index, best = heaviest tier lifted }
		stats = { totalReps = 0, bestSet = 0, spotReps = 0, togetherReps = 0, armWins = 0 },
		quests = { index = 1, active = nil }, -- index: next Config.Quests slot; active: { id, progress, goal, ready }
		shakes = 0, -- Energy Shakes in the bag
		daily = { lastDay = 0, streak = 0, best = 0 }, -- daily streak (Config.Economy)
		seasons = {}, -- seasonId -> reps done during that event (Config.Seasons)
		crew = { id = nil }, -- crew id (records live in the "Crews" DataStore, see CrewService)
		cosmetics = { owned = {}, equipped = {} }, -- clothing store gear (Config.Cosmetics, CosmeticService)
		receipts = {}, -- developer product purchase ids already granted (MonetizationService)
		legends = { met = {}, active = nil }, -- met: legendId -> true; active: { id, progress, goal } (Config.Legends)
		welcome = { offlineCoins = 0, streakCoins = 0, streakToken = false }, -- what this join paid out (menu info)
		onboarding = { geneticsRevealed = false, tutorialStep = 1, tutorialVersion = 2 }, -- Config.Onboarding (Done = finished)
		-- Settings menu: volumes, gain popups On/Minimal/Off; one-time hints; wardrobe top + shorts color
		settings = { music = 1, effects = 1, gainNumbers = "On", repFlash = "On", pumpHintSeen = false, lookCapHintSeen = false, top = "Shirtless", shorts = "Black" },
		meta = { firstJoin = 0, lastSeen = 0, sessions = 0 },
	}
end

return DataTemplate
