-- Player intents outside of machines (Growth Spurt, titles, genetics). Every action is
-- validated here; the client only asks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local PlayerData = require(script.Parent.PlayerData)
local BodyService = require(script.Parent.BodyService)
local TitleService = require(script.Parent.TitleService)
local Titles = require(Config.Titles)

local Remotes = ReplicatedStorage.Remotes

local ActionService = {}
local handlers = {}

handlers.GrowthSpurt = function(player)
	if PlayerData.GrowthSpurt(player) then
		local data = PlayerData.Get(player)
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
end

-- Settings menu: { music = 0-1, effects = 0-1 }
handlers.SetSettings = function(player, settings)
	if type(settings) == "table" then
		PlayerData.SetSettings(player, settings.music, settings.effects)
	end
end

-- Other services add handlers.
function ActionService.Register(action, handler)
	handlers[action] = handler
end

function ActionService.Start()
	Remotes.PlayerAction.OnServerEvent:Connect(function(player, action, arg)
		local handler = type(action) == "string" and handlers[action]
		if handler then handler(player, arg) end
	end)
end

return ActionService
