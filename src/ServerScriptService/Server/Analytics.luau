-- Analytics: Roblox AnalyticsService onboarding funnel, so the Creator Dashboard shows where new players quit.
-- Funnel steps (in order): Joined, Genetics kept, the tutorial steps from Config.Onboarding (one each), Tutorial done,
-- First Growth Spurt. Only players who haven't finished the tutorial are in the funnel; each step is sent once per
-- session (Roblox also counts each funnel step once per player). The first Growth Spurt also sends a custom event
-- with the minutes since first join. Calls are protected: analytics can never break gameplay.
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)

local Analytics = {}

-- Funnel step names in order; the step number is the position in this list.
local FUNNEL = { "Joined", "Genetics kept" }
for _, step in ipairs(Onboarding.Steps) do
	table.insert(FUNNEL, "Tutorial: " .. step.id)
end
table.insert(FUNNEL, "Tutorial done")
table.insert(FUNNEL, "First Growth Spurt")
local STEP = {}
for index, name in ipairs(FUNNEL) do STEP[name] = index end
Analytics.Funnel = FUNNEL

local inFunnel = {} -- [player] = { [stepNumber] = true } for players still onboarding
local logged = {}

local function log(player, name)
	local funnel = inFunnel[player]
	local number = STEP[name]
	if not funnel or not number or funnel[number] then return end
	funnel[number] = true
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, number, name)
end

-- Called when a player's data has loaded.
function Analytics.Joined(player, data)
	local step = data.onboarding and data.onboarding.tutorialStep or Onboarding.Done
	if step >= Onboarding.Done and (data.growthSpurts or 0) > 0 then return end -- not a new player
	inFunnel[player] = {}
	log(player, "Joined")
	-- a returning player who stopped mid-tutorial picks up where they were (Roblox ignores repeats)
	if data.onboarding and data.onboarding.geneticsRevealed then log(player, "Genetics kept") end
end

function Analytics.GeneticsKept(player)
	log(player, "Genetics kept")
end

-- The tutorial reached step `step` (Config.Onboarding index, or Onboarding.Done when finished).
function Analytics.TutorialStep(player, step)
	if step >= Onboarding.Done then
		log(player, "Tutorial done")
		return
	end
	-- reaching step n means steps 1..n-1 are done; log every step up to the one reached
	for index = 1, math.min(step, #Onboarding.Steps) do
		log(player, "Tutorial: " .. Onboarding.Steps[index].id)
	end
end

-- After every Growth Spurt; only the first one is logged.
function Analytics.GrowthSpurt(player, data)
	if data.growthSpurts ~= 1 or logged[player] then return end
	logged[player] = true
	log(player, "First Growth Spurt")
	local minutes = data.meta and data.meta.firstJoin and data.meta.firstJoin > 0 and (os.time() - data.meta.firstJoin) / 60 or 0
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, "FirstGrowthSpurt", math.floor(minutes + 0.5))
end

Players.PlayerRemoving:Connect(function(player)
	inFunnel[player], logged[player] = nil, nil
end)

return Analytics
