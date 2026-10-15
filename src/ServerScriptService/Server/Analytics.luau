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
end)

return Analytics
