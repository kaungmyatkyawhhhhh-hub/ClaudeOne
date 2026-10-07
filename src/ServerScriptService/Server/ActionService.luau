-- Player intents outside of machines (Growth Spurt, titles, genetics, tutorial). Every action is
-- validated here; the client only asks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)
local Analytics = require(script.Parent.Analytics)
local BodyService = require(script.Parent.BodyService)
local TitleService = require(script.Parent.TitleService)
local Titles = require(Config.Titles)
local Onboarding = require(Config.Onboarding)

local Remotes = ReplicatedStorage.Remotes

local ActionService = {}
local handlers = {}

handlers.GrowthSpurt = function(player)
	if PlayerData.GrowthSpurt(player) then
		local data = PlayerData.Get(player)
		Analytics.GrowthSpurt(player, data)
		BodyService.Rebuild(player)
		TitleService.Check(player)
		Remotes.PlayerEvent:FireClient(player, "GrowthSpurt", {
			spurts = data.growthSpurts,
			height = GrowthSpurts.GetHeight(data.growthSpurts),
			bonus = GrowthSpurts.GetBonus(data.growthSpurts),
		})
	end
end

handlers.EquipTitle = function(player, titleId)
	if titleId == nil or (type(titleId) == "string" and Titles.ById[titleId]) then
		TitleService.Equip(player, titleId)
	end
end

-- Genetics: reroll uses the free reroll first, then a DNA Token (validated in PlayerData).
handlers.Reroll = function(player)
	if PlayerData.RerollGenetics(player) then
		TitleService.Check(player)
		Remotes.PlayerEvent:FireClient(player, "Rerolled", {})
	end
end

-- The player has seen their genetics reveal (first join).
handlers.GeneticsSeen = function(player)
	PlayerData.SetFlag(player, "geneticsRevealed", true)
	Analytics.GeneticsKept(player)
end

-- Tutorial: the client reports the step it reached (validated in PlayerData).
handlers.TutorialStep = function(player, step)
	local before = PlayerData.Get(player) and PlayerData.Get(player).onboarding.tutorialStep
	if PlayerData.SetTutorialStep(player, step) then
		Analytics.TutorialStep(player, step)
		-- a step's gift (e.g. the free shake) is given once, when the step is reached the normal way (one step after the last):
		-- a client that jumps straight to a gift step does not get it
		local def = Onboarding.Steps[step]
		if def and def.gift and def.gift.shakes and step == before + 1 then
			PlayerData.AddShakes(player, def.gift.shakes)
		end
	end
end

-- Settings menu: { music = 0-1, effects = 0-1, gainNumbers = "On" | "Minimal" | "Off", repFlash = "On" | "Off",
-- pumpHintSeen = true } (PlayerData validates)
handlers.SetSettings = function(player, settings)
	if type(settings) == "table" then
		PlayerData.SetSettings(player, settings)
	end
end

-- Other services add handlers.
function ActionService.Register(action, handler)
	handlers[action] = handler
end

function ActionService.Start()
	PlayerData.Loaded:Connect(Analytics.Joined) -- onboarding funnel (new players only)
	-- menus, settings, tutorial steps, shakes: plenty for a real player, not for a spam script
	Guard.Remote(Remotes.PlayerAction, "PlayerAction", 8, 15, function(player, action, arg)
		local handler = type(action) == "string" and handlers[action]
		if handler then handler(player, arg) end
	end)
end

return ActionService
