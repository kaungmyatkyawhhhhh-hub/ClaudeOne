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
		dnaWeek = { week = 0, bought = 0 }, -- DNA tokens bought with coins this week (each costs 10% more; Config/PumpShop)
		growthSpurts = 0, -- (owner, 9 Oct, release) new players start at Growth Spurt 0 (4'0")
		-- (prompt 58) gyms kept open from before a ladder change ([gym] = true: the Pro Gym for players who trained there when it
		-- opened at Growth Spurt 2; Machines.GymLevel) and the ladder change already applied to this save (PlayerData)
		gymAccess = {},
		gymLadder = 0,
		-- Body Alters (prompt 21, Config.Alters): highest done, the skin worn (any up to highest), the biggest physique ever
		-- (best = { muscles = { [id] = level }, spurts, alter, exp }: the statue and the Total board use it)
		alter = { highest = 0, equipped = 0 },
		titles = { owned = {}, equipped = nil }, -- owned: titleId -> unix time earned
		machines = {}, -- machineId -> { unlocked = highest bought tier, selected = tier index, best = heaviest tier lifted }
		machinesUsed = {}, -- machineId -> true once you did a rep on it (the machine signs' "NEW" tag)
		stats = { totalReps = 0, bestSet = 0, spotReps = 0, togetherReps = 0, armWins = 0, cardioMeters = 0, posingWins = 0, posingEntries = 0, posingTrophies = 0, posingBest = 0, loginWeeks = 0, armKingWins = 0, beatBenny = 0, beatCoral = 0, beatDante = 0 },
		quests = { index = 1, active = nil }, -- index: next Config.Quests slot; active: { id, progress, goal, ready }
		shakes = 0, -- (old: Energy Shakes in the bag; moved to items.Shake on load, prompt 14)
		items = {}, -- boosts in the inventory: [Config.Boosts id] = how many (ItemService)
		boostLeft = {}, -- inventory boosts running: [id] = seconds left (paused while away; ItemService)
		itemsEquipped = {}, -- (prompt 28b) [id] = true in the hotbar / false taken out by the player (kept); nil = never had it
		endlessStamina = 0, -- Endless Stamina seconds left (bought; counts down only while in the game; PlayerData)
		daily = { lastDay = 0, streak = 0, best = 0, calendarDay = 0 }, -- login streak calendar (Config.Economy.Login): last claimed day + calendar day
		-- today's quests (Config.DailyQuests, DailyService): list = { { id, progress, done, claimed } }, groups trained today
		dailyQuests = { day = 0, list = {}, bonus = false, swaps = 0, groups = {} },
		repsToday = { day = 0, count = 0 }, -- reps on the current UTC day (the "Most reps today" board, LeaderboardService)
		trainers = { copies = {}, equipped = {}, discovered = { Base = true }, nextUid = 1, rolls = 0, pity = 0, autoDelete = {} },
		groupGift = { given = false }, -- (owner, 23 Oct) the group perks welcome gift, once (GroupGiftService) -- personal trainers (Config.Trainers, TrainerService; prompt 24: rolls)
		spurtMilestones = { spurt = -1, got = 0 }, -- (prompt 11) the 25 / 50 / 75% Growth Spurt rewards paid for this spurt (SpurtMilestoneService)
		rivals = {}, -- NPC rivals: [rival id] = "active" (challenge accepted) | "beaten" (Config.Rivals, RivalService)
		meals = {}, -- smoothie bar boosts: [item id] = seconds left (paused while away; Config.Meals, MealService)
		seasons = {}, -- seasonId -> reps done during that event (Config.Seasons)
		crew = { id = nil }, -- crew id (records live in the "Crews" DataStore, see CrewService)
		cosmetics = { owned = {}, equipped = {} }, -- clothing store gear (Config.Cosmetics, CosmeticService)
		auras = { owned = {}, equipped = nil }, -- owned: auraId -> unix time (earned / bought); equipped: auraId (Config.Auras, AuraService)
		receipts = {}, -- developer product purchase ids already granted (MonetizationService)
		analytics = { funnel = 0 }, -- the highest onboarding funnel step logged (Analytics: each step once, in order)
		legends = { met = {}, active = nil }, -- met: legendId -> true; active: { id, progress, goal } (Config.Legends)
		welcome = { offlineCoins = 0, streakCoins = 0, streakToken = false }, -- what this join paid out (menu info)
		onboarding = { geneticsRevealed = false, tutorialStep = 1, tutorialVersion = 2 }, -- Config.Onboarding (Done = finished)
		-- (prompt 39) the unlock guides seen (Config/Guides: [save id] = true; "New:<tile>" = its NEW glow tapped);
		-- version 0 = not set up yet (PlayerData: an existing player's already-open features count as seen)
		guides = { seen = {}, version = 0 },
		-- Settings menu: volumes, gain popups On/Minimal/Off, the per-rep EXP popups On/Off; one-time hints; wardrobe top + shorts color
		settings = { music = 1, effects = 1, gainNumbers = "On", repFlash = "On", expPopups = "On", spotRequests = "On", pumpHintSeen = false, menuCollapsed = false, rightCollapsed = false, hints = "On", otherScreams = "On", otherAuras = "On", otherTrainers = "On", lowGraphics = "Off", inventoryTab = "Items", top = "Shirtless", shorts = "Black" },
		meta = { firstJoin = 0, lastSeen = 0, sessions = 0 },
	}
end

return DataTemplate
