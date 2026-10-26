-- FavoriteClient (26 Oct, retention): Roblox's own "Favorite this experience?" prompt, once, after the FIRST Growth Spurt
-- (the happiest moment of the first session). It waits until the Growth Spurt moment is over and you're off the machine,
-- with no window open, so it never covers anything. A favourite puts the game on the kid's home page.
local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIBus = require(Shared.UI.UIBus)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DELAY = 12 -- seconds after the spurt (the Growth Spurt moment and its unlock line)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local asked = false

Remotes:WaitForChild("PlayerEvent").OnClientEvent:Connect(function(kind, info)
	if kind ~= "GrowthSpurt" or asked or type(info) ~= "table" or info.spurts ~= 1 then return end
	asked = true
	task.wait(DELAY)
	local deadline = os.clock() + 120
	while (UIBus.Training or UIBus.CoverOpen(playerGui)) and os.clock() < deadline do task.wait(2) end
	pcall(function() AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true) end)
end)
