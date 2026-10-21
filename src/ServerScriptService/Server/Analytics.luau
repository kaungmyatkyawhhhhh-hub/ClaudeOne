-- Analytics: Roblox AnalyticsService onboarding funnel, so the Creator Dashboard shows where new players quit.
-- (owner, 15 Oct) The steps are a FIXED list with unique numbered names, never built from Config.Onboarding: adding a
-- tutorial step on 14 Oct (Skate) shifted every number after it, so the dashboard showed "First Growth Spurt" on both
-- step 13 (really "Tutorial done") and step 14. Add new steps only at the END of this list.
-- Each step is logged once per player EVER and in order: the highest step logged is saved (data.analytics.funnel) and a
-- step is only logged when its number is higher. A tutorial step counts when it is COMPLETED (reaching step n completes
-- step n-1); skipping the tutorial logs "Tutorial finished or skipped" without the skipped steps. The first Growth Spurt
-- also sends a custom event with the minutes since first join. Calls are protected: analytics can never break gameplay.
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IS_STUDIO = game:GetService("RunService"):IsStudio()

local Config = ReplicatedStorage.Shared.Config
local Onboarding = require(Config.Onboarding)
local GrowthSpurts = require(Config.GrowthSpurts)
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)

local Analytics = {}

-- step number = position; `tutorial` = the Config.Onboarding step id whose COMPLETION this is
local FUNNEL = {
	{ name = "01. Joined (new player)" },
	{ name = "02. Genetics kept" },
	{ name = "03. Tutorial: walked to the Flat Bench", tutorial = "GoBench" },
	{ name = "04. Tutorial: first rep", tutorial = "FirstLift" },
	{ name = "05. Tutorial: stamina ran low", tutorial = "Stamina" },
	{ name = "06. Tutorial: drank the free shake", tutorial = "Shake" },
	{ name = "07. Tutorial: got on the Squat Rack", tutorial = "GoSquat" },
	{ name = "08. Tutorial: 3 squats", tutorial = "SquatLift" },
	{ name = "09. Tutorial: opened Stats", tutorial = "OpenStats" },
	{ name = "10. Tutorial: talked to Coach Dex", tutorial = "Coach" },
	{ name = "11. Tutorial: saw the Growth Spurt goal", tutorial = "Goal" },
	{ name = "12. Tutorial: skate tip", tutorial = "Skate" },
	{ name = "13. Tutorial finished or skipped" },
	{ name = "14. Growth Spurt goal reached" },
	{ name = "15. First Growth Spurt done" },
}
local NUMBER = {}           -- [name] = step number
local BY_TUTORIAL = {}      -- [Onboarding step id] = step number
for index, step in ipairs(FUNNEL) do
	NUMBER[step.name] = index
	if step.tutorial then BY_TUTORIAL[step.tutorial] = index end
end
Analytics.Funnel = FUNNEL
local TUTORIAL_DONE, GOAL_REACHED, FIRST_SPURT = 13, 14, 15

-- (prompt 11, 21 Oct) The way from "tutorial finished" to the goal in more detail, as its own Roblox funnel (the 15 steps
-- above stay as they are, so the onboarding funnel stays comparable): 13, 13a goal 25%, 13b 50%, 13c 75%, 14.
local SPURT_FUNNEL = "FirstGrowthSpurt"
local SPURT_STEPS = { "13. Tutorial finished or skipped", "13a. Growth Spurt goal 25%", "13b. Growth Spurt goal 50%",
	"13c. Growth Spurt goal 75%", "14. Growth Spurt goal reached" }
local SPURT_STEP_OF = { [25] = 2, [50] = 3, [75] = 4 }
local function spurtStep(player, step: number)
	pcall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, player, SPURT_FUNNEL, tostring(player.UserId), step, SPURT_STEPS[step])
	if IS_STUDIO then print("[Analytics] " .. SPURT_FUNNEL .. " step " .. SPURT_STEPS[step]) end
end

local tracked = {} -- [player] = data (players still in the funnel this session)

local function saved(data): number
	if type(data.analytics) ~= "table" then data.analytics = { funnel = 0 } end
	return tonumber(data.analytics.funnel) or 0
end

-- log step `number` once ever, only past the highest step already logged (in order; a skipped step stays unlogged)
local function log(player, number: number)
	local data = tracked[player]
	if not data or not FUNNEL[number] or number <= saved(data) then return end
	data.analytics.funnel = number -- (saved with the rest of the data)
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, number, FUNNEL[number].name)
	if IS_STUDIO then print("[Analytics] funnel step " .. FUNNEL[number].name) end
	if number == TUTORIAL_DONE then spurtStep(player, 1) elseif number == GOAL_REACHED then spurtStep(player, #SPURT_STEPS) end
end

-- Called when a player's data has loaded.
function Analytics.Joined(player, data)
	local step = data.onboarding and data.onboarding.tutorialStep or Onboarding.Done
	-- a player who already had their first Growth Spurt is out of the funnel
	if (data.growthSpurts or 0) > 0 then return end
	tracked[player] = data
	log(player, 1)
	if data.onboarding and data.onboarding.geneticsRevealed then log(player, 2) end
	if step >= Onboarding.Done then log(player, TUTORIAL_DONE) end
end

function Analytics.GeneticsKept(player)
	log(player, 2)
end

-- The tutorial reached step `step` (Config.Onboarding index, or Onboarding.Done). Reaching step n completes the steps
-- before it; Done completes all of them unless `skipped`.
function Analytics.TutorialStep(player, step, skipped: boolean?)
	local last = if step >= Onboarding.Done then (if skipped then 0 else #Onboarding.Steps) else step - 1
	for index = 1, math.min(last, #Onboarding.Steps) do
		local number = BY_TUTORIAL[Onboarding.Steps[index].id]
		if number then log(player, number) end
	end
	if step >= Onboarding.Done then log(player, TUTORIAL_DONE) end
end

-- the Growth Spurt goal is reached (checked every few seconds for players still in the funnel)
local function goalReached(data): boolean
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, Machines.TrainableMuscles(data.growthSpurts))
	return progress.ready == true
end

-- (prompt 11) the first Growth Spurt's goal bar passed 25 / 50 / 75% (SpurtMilestoneService): steps 13a / 13b / 13c
function Analytics.SpurtMilestone(player, percent: number)
	local data = tracked[player]
	local step = SPURT_STEP_OF[percent]
	if not data or not step or saved(data) >= GOAL_REACHED then return end
	if type(data.analytics.milestone) == "number" and data.analytics.milestone >= percent then return end -- (once ever)
	data.analytics.milestone = percent
	spurtStep(player, step)
end

-- (prompt 21) one custom event with a value (e.g. "BodyAlter", the alter number)
function Analytics.Event(player, name: string, value: number?)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
end

-- (prompt 12) The shop funnel, so the dashboard shows where buyers drop off: "Shop_Opened", "Offer_Shown_<offer>" and
-- "Offer_Tapped_<offer>" (the client asks through PlayerAction "ShopEvent"; only these names, and each at most once per
-- ShopEventGap seconds per player, so a script can't flood the dashboard) and "Product_Bought_<key>" (MonetizationService,
-- after the receipt is given and saved; the value is the Robux spent).
local OFFERS = { Stamina = true, ShakeOut = true, AfterSpurt = true, FinishFaster = true }
local ShopEventGap = 3
local lastShopEvent = {} -- [player] = { [name] = os.clock() }
function Analytics.ShopEvent(player, info)
	if type(info) ~= "table" then return end
	local name
	if info.event == "ShopOpened" then
		name = "Shop_Opened"
	elseif (info.event == "OfferShown" or info.event == "OfferTapped") and type(info.offer) == "string" and OFFERS[info.offer] then
		name = (if info.event == "OfferShown" then "Offer_Shown_" else "Offer_Tapped_") .. info.offer
	else
		return
	end
	local last = lastShopEvent[player] or {}
	lastShopEvent[player] = last
	if last[name] and os.clock() - last[name] < ShopEventGap then return end
	last[name] = os.clock()
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, 1)
	if IS_STUDIO then print("[Analytics] " .. name) end
end

-- (prompt 39) the unlock guides: "Guide_<shown|done|skip|timeout>_<id>" and taps on a locked menu tile
-- "Locked_Tap_<tile>" (the value = the player's LVL), spaced like the shop events
function Analytics.GuideEvent(player, name: string, value: number?)
	local last = lastShopEvent[player] or {}
	lastShopEvent[player] = last
	if last[name] and os.clock() - last[name] < ShopEventGap then return end
	last[name] = os.clock()
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
	if IS_STUDIO then print("[Analytics] " .. name .. " " .. tostring(value or 1)) end
end

function Analytics.ProductBought(player, key: string, robux: number?)
	local name = "Product_Bought_" .. key
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, robux or 0)
	if IS_STUDIO then print("[Analytics] " .. name .. " " .. tostring(robux)) end
end

-- After every Growth Spurt; only the first one counts.
function Analytics.GrowthSpurt(player, data)
	if data.growthSpurts ~= 1 then return end
	log(player, GOAL_REACHED) -- (it had to be reached to grow)
	log(player, FIRST_SPURT)
	local minutes = data.meta and data.meta.firstJoin and data.meta.firstJoin > 0 and (os.time() - data.meta.firstJoin) / 60 or 0
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, "FirstGrowthSpurt", math.floor(minutes + 0.5))
	tracked[player] = nil
end

task.spawn(function()
	while true do
		task.wait(5)
		for player, data in pairs(tracked) do
			if player.Parent and data.growthSpurts == 0 and saved(data) < GOAL_REACHED then
				local ok, ready = pcall(goalReached, data)
				if ok and ready then log(player, GOAL_REACHED) end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	tracked[player] = nil
	lastShopEvent[player] = nil
end)

return Analytics
