-- ScreamClient (21 Oct; owner, 22 Oct: grunts, no screams): plays the lifting voices ScreamService sends, from the lifter's
-- head (3D, Config/Sounds LiftGrunt: a short range, so only nearby players hear it, quietly). Never the same clip twice in a
-- row; pitch 0.95 - 1.05 (the sound's own variation). Settings "Lifting Voices" Off = none at all here; "Others' Sounds"
-- Off mutes other players' ones (Audio.OthersMuted).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Audio)
local ClientData = require(Shared.ClientData)

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Scream")

local lastIndex = nil -- the clip played last

remote.OnClientEvent:Connect(function(player: Player)
	local settings = ClientData.IsLoaded() and ClientData.Get().settings or {}
	if settings.liftingVoices == "Off" then return end
	local character = player and player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local sound = Audio.PlayAt("LiftGrunt", head, { avoid = lastIndex })
	if sound then lastIndex = sound:GetAttribute("IdIndex") end
end)
